/**
 * deleteMyAccount — função CHAMÁVEL: a pessoa exclui a própria conta (LGPD).
 *
 * Não recebe nada digitado: quem chamou é quem sai. Em ordem, e seguro repetir se cair no meio:
 *   1. confere antes de apagar qualquer coisa: sessão juntada (D18) em que ela é dona trava a
 *      exclusão (🟡 a mesma decisão em aberto do deleteSession);
 *   2. as sessões que ela gravou somem para todos, com lances e vídeos (deleteSessionAs);
 *   3. das sessões de outras pessoas, ela sai (leaveSessionAs): os outros continuam com os lances;
 *   4. amizades e pedidos (de amizade e de juntar sessões) dela são apagados, e quem era amigo
 *      perde 1 em `stats.friends`;
 *   5. perfil, @usuário e dados privados (data de nascimento) são apagados;
 *   6. por último, a conta do Firebase Auth.
 */
import { getAuth } from "firebase-admin/auth";
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { deleteSessionAs } from "../sessions/deleteSession";
import { leaveSessionAs } from "../sessions/leaveSession";
import { mergedFromOf, mergedIntoOf } from "../sessions/sessionDocs";
import { bucket, db } from "../shared/admin";

export const deleteMyAccount = onCall<unknown, Promise<{ deleted: true }>>(CALLABLE_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Entre na sua conta para excluí-la.");
  }

  const sessions = await db().collection("sessions").where("participantIds", "array-contains", uid).get();
  const owned = sessions.docs.filter((s) => s.get("ownerId") === uid);

  // 1. Tudo conferido antes de apagar qualquer coisa.
  if (owned.some((s) => mergedIntoOf(s) || mergedFromOf(s).length > 0)) {
    throw new HttpsError(
      "failed-precondition",
      "Você tem sessões juntadas com as de outra pessoa. Por enquanto, a conta não pode ser excluída pelo app.",
    );
  }

  // 2 e 3. Sessões: as minhas somem; das outras eu saio. Juntada a outra (dos outros) sai pela principal.
  for (const s of owned) await deleteSessionAs(uid, s.id);
  for (const s of sessions.docs) {
    if (s.get("ownerId") === uid || mergedIntoOf(s)) continue;
    await leaveSessionAs(uid, s.id);
  }

  // 4. Amizades e pedidos.
  const friendships = await db().collection("friendships").where("uids", "array-contains", uid).get();
  for (const f of friendships.docs) {
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(f.ref);
      if (!snap.exists) return;
      if (snap.get("status") === "accepted") {
        const other = ((snap.get("uids") as string[] | undefined) ?? []).find((id) => id !== uid);
        if (other) {
          const otherSnap = await tx.get(db().doc(`users/${other}`));
          if (otherSnap.exists) tx.update(otherSnap.ref, { "stats.friends": FieldValue.increment(-1) });
        }
      }
      tx.delete(f.ref);
    });
  }
  const requests = await db().collection("sessionMergeRequests").where("uids", "array-contains", uid).get();
  await Promise.all(requests.docs.map((r) => r.ref.delete()));

  // 5. Perfil, @ e dados privados.
  const userRef = db().doc(`users/${uid}`);
  await db().runTransaction(async (tx) => {
    const user = await tx.get(userRef);
    const username = user.get("username") as string | undefined;
    const usernameRef = username ? db().doc(`usernames/${username}`) : null;
    const usernameSnap = usernameRef ? await tx.get(usernameRef) : null;
    if (usernameRef && usernameSnap?.exists && usernameSnap.get("uid") === uid) tx.delete(usernameRef);
    tx.delete(userRef);
    tx.delete(db().doc(`userPrivate/${uid}`));
  });

  // A foto do perfil, se tiver (users/{uid}/avatar no Storage).
  await bucket().file(`users/${uid}/avatar`).delete({ ignoreNotFound: true });

  // 6. A conta.
  try {
    await getAuth().deleteUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== "auth/user-not-found") throw e;
  }

  return { deleted: true };
});
