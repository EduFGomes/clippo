/**
 * removeFriend — função CHAMÁVEL que apaga a amizade em qualquer estado (D16):
 *   - pedido que eu mandei      → cancela;
 *   - pedido que eu recebi      → recusa (a outra pessoa não é avisada);
 *   - amizade aceita            → desfaz, e os dois perdem 1 em `stats.friends`.
 *
 * Idempotente: se o documento já não existe, não é erro. As sessões antigas não mudam
 * (quem jogou junto continua vendo a sessão, R11).
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { friendshipRef } from "./friendships";
import { FriendValidationError, normalizeUid } from "./validation";

export interface RemoveFriendRequest {
  uid: string;
}

export const removeFriend = onCall<RemoveFriendRequest, Promise<{ uid: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para mexer nos seus amigos.");
    }

    let friendUid: string;
    try {
      friendUid = normalizeUid(request.data?.uid);
    } catch (e) {
      if (e instanceof FriendValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const ref = friendshipRef(uid, friendUid);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      // O id já garante, mas confere: só as duas pessoas mexem na amizade.
      const uids = (snap.get("uids") as string[] | undefined) ?? [];
      if (!uids.includes(uid)) {
        throw new HttpsError("permission-denied", "Essa amizade não é sua.");
      }

      if (snap.get("status") === "accepted") {
        const [meSnap, friendSnap] = await tx.getAll(
          db().doc(`users/${uid}`),
          db().doc(`users/${friendUid}`),
        );
        for (const userSnap of [meSnap, friendSnap]) {
          const count = (userSnap.get("stats.friends") as number | undefined) ?? 0;
          if (userSnap.exists && count > 0) {
            tx.update(userSnap.ref, { "stats.friends": FieldValue.increment(-1) });
          }
        }
      }
      tx.delete(ref);
    });

    return { uid: friendUid };
  },
);
