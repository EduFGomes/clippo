/**
 * acceptFriendRequest — função CHAMÁVEL: "Aceitar" um pedido de amizade (R15, D16).
 *
 * Só quem RECEBEU o pedido aceita. Idempotente: aceitar de novo não soma o contador
 * duas vezes. Os dois ganham +1 em `stats.friends`, na mesma transação.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { friendshipRef } from "./friendships";
import { FRIENDS_MAX, FriendValidationError, normalizeUid } from "./validation";

export interface AcceptFriendRequestRequest {
  /** Quem me mandou o pedido. */
  uid: string;
}

export const acceptFriendRequest = onCall<AcceptFriendRequestRequest, Promise<{ uid: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para aceitar o convite.");
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
    const meRef = db().doc(`users/${uid}`);
    const friendRef = db().doc(`users/${friendUid}`);

    await db().runTransaction(async (tx) => {
      const [snap, meSnap, friendSnap] = await tx.getAll(ref, meRef, friendRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Esse convite não existe mais.");
      }
      if (snap.get("status") === "accepted") return; // idempotente
      if (snap.get("requestedTo") !== uid) {
        // Quem pediu não pode aceitar o próprio pedido.
        throw new HttpsError("permission-denied", "Espere a outra pessoa aceitar o convite.");
      }
      for (const [userSnap, who] of [[meSnap, "Você"], [friendSnap, "Essa pessoa"]] as const) {
        const count = (userSnap.get("stats.friends") as number | undefined) ?? 0;
        if (count >= FRIENDS_MAX) {
          throw new HttpsError(
            "resource-exhausted",
            `${who} já tem ${FRIENDS_MAX} amigos, o máximo do Clippo.`,
          );
        }
      }

      const now = FieldValue.serverTimestamp();
      tx.update(ref, { status: "accepted", acceptedAt: now, updatedAt: now });
      if (meSnap.exists) tx.update(meRef, { "stats.friends": FieldValue.increment(1) });
      if (friendSnap.exists) tx.update(friendRef, { "stats.friends": FieldValue.increment(1) });
    });

    return { uid: friendUid };
  },
);
