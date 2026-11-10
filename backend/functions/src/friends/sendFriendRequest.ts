/**
 * sendFriendRequest — função CHAMÁVEL: "Adicionar amigo" pelo @ (D16, R15).
 *
 * O que faz, numa transação:
 *   - ninguém pediu ainda → cria friendships/{par} com `status: pending`;
 *   - eu já tinha pedido → nada muda (idempotente: o app pode repetir a chamada);
 *   - a outra pessoa já tinha me pedido → aceita na hora (os dois querem) e soma +1
 *     em `stats.friends` dos dois;
 *   - já somos amigos → nada muda.
 *
 * Contra spam: no máximo PENDING_REQUESTS_MAX pedidos meus esperando resposta e
 * FRIENDS_MAX amigos por pessoa.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { ValidationError, normalizeUsername } from "../users/validation";
import { friendshipRef, profileCopy } from "./friendships";
import {
  FRIENDS_MAX,
  PENDING_REQUESTS_MAX,
  type FriendshipStatus,
  friendshipUids,
} from "./validation";

export interface SendFriendRequestRequest {
  /** O @ que a pessoa digitou (com ou sem "@"). */
  username: string;
}

export interface SendFriendRequestResponse {
  uid: string;
  status: FriendshipStatus;
}

export const sendFriendRequest = onCall<SendFriendRequestRequest, Promise<SendFriendRequestResponse>>(
  CALLABLE_OPTIONS,
  async (request) => {
    // 1. Quem chamou?
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para adicionar amigos.");
    }

    // 2. Valida o @ antes de tocar no banco (mesma regra do app).
    let username: string;
    try {
      username = normalizeUsername(request.data?.username);
    } catch (e) {
      if (e instanceof ValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: "username" });
      }
      throw e;
    }

    const usernameSnap = await db().doc(`usernames/${username}`).get();
    const friendUid = usernameSnap.get("uid") as string | undefined;
    if (!usernameSnap.exists || !friendUid) {
      throw new HttpsError("not-found", "Não achamos ninguém com esse @.", { field: "username" });
    }
    if (friendUid === uid) {
      throw new HttpsError("invalid-argument", "Esse @ é o seu.", { field: "username" });
    }

    // Anti-spam: contado fora da transação (contagem não entra em transação).
    // Uma corrida aqui deixa passar um pedido a mais, o que não é problema.
    const pending = await db()
      .collection("friendships")
      .where("requestedBy", "==", uid)
      .where("status", "==", "pending")
      .count()
      .get();

    const ref = friendshipRef(uid, friendUid);
    const meRef = db().doc(`users/${uid}`);
    const friendRef = db().doc(`users/${friendUid}`);

    // 3. Lê, decide e grava como uma coisa só.
    const status = await db().runTransaction(async (tx): Promise<FriendshipStatus> => {
      const [snap, meSnap, friendSnap] = await tx.getAll(ref, meRef, friendRef);
      if (!meSnap.exists) {
        throw new HttpsError("failed-precondition", "Complete seu perfil antes de adicionar amigos.");
      }
      if (!friendSnap.exists) {
        throw new HttpsError("not-found", "Não achamos ninguém com esse @.", { field: "username" });
      }

      const now = FieldValue.serverTimestamp();

      if (snap.exists) {
        const current = snap.get("status") as FriendshipStatus;
        // 4. Idempotente: já somos amigos, ou o pedido é meu e continua esperando.
        if (current === "accepted" || snap.get("requestedBy") === uid) return current;

        // A outra pessoa já tinha me pedido: aceitar é o que os dois querem.
        assertRoomForFriend(meSnap.get("stats.friends"), "Você");
        assertRoomForFriend(friendSnap.get("stats.friends"), "Essa pessoa");
        tx.update(ref, { status: "accepted", acceptedAt: now, updatedAt: now });
        tx.update(meRef, { "stats.friends": FieldValue.increment(1) });
        tx.update(friendRef, { "stats.friends": FieldValue.increment(1) });
        return "accepted";
      }

      if (pending.data().count >= PENDING_REQUESTS_MAX) {
        throw new HttpsError(
          "resource-exhausted",
          "Você tem muitos convites esperando resposta. Espere alguém aceitar.",
          { field: "username" },
        );
      }
      assertRoomForFriend(meSnap.get("stats.friends"), "Você");

      tx.set(ref, {
        uids: friendshipUids(uid, friendUid),
        status: "pending",
        requestedBy: uid,
        requestedTo: friendUid,
        profiles: { [uid]: profileCopy(meSnap), [friendUid]: profileCopy(friendSnap) },
        createdAt: now,
        updatedAt: now,
        acceptedAt: null,
      });
      return "pending";
    });

    return { uid: friendUid, status };
  },
);

function assertRoomForFriend(rawCount: unknown, who: "Você" | "Essa pessoa") {
  const count = typeof rawCount === "number" ? rawCount : 0;
  if (count >= FRIENDS_MAX) {
    throw new HttpsError(
      "resource-exhausted",
      `${who} já tem ${FRIENDS_MAX} amigos, o máximo do Clippo.`,
      { field: "username" },
    );
  }
}
