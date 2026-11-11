/**
 * deleteSession — função CHAMÁVEL: o dono exclui a sessão para todos (R12).
 *
 * (1) Quem chamou? Só o dono (R9) exclui. (2) Valida o id antes de tocar no banco.
 * (3) Numa transação: apaga os highlights, os pedidos de juntar que falam desta sessão e a
 * própria sessão, e tira 1 sessão e os lances dela do perfil de cada participante. Sem o
 * documento, as regras do Firestore e do Storage já negam tudo a todos (R11). (4) Depois,
 * fora da transação, apaga os vídeos e miniaturas no Storage; se isso falhar, a sessão já não
 * existe para ninguém e só sobra arquivo sem dono, que o log mostra.
 *
 * Idempotente: excluir de novo (ou uma sessão que nunca chegou ao servidor) não é erro.
 *
 * 🟡 Sessão juntada (D18) fica de fora por enquanto: a principal tem lances de outro dono, e a
 * juntada só existe dentro da principal. Excluir as duas precisa de decisão do grupo.
 */
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { bucket, db } from "../shared/admin";
import { mergedFromOf, mergedIntoOf, participantIdsOf } from "./sessionDocs";
import { SessionValidationError, normalizeId, sessionStoragePrefix } from "./validation";

export const deleteSession = onCall<{ sessionId: string }, Promise<{ sessionId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para excluir a sessão.");
    }

    let sessionId: string;
    try {
      sessionId = normalizeId(request.data?.sessionId, "sessionId");
    } catch (e) {
      if (e instanceof SessionValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const sessionRef = db().doc(`sessions/${sessionId}`);
    const requests = db().collection("sessionMergeRequests");

    const deleted = await db().runTransaction(async (tx) => {
      const snap = await tx.get(sessionRef);
      if (!snap.exists) return false;
      if (snap.get("ownerId") !== uid) {
        throw new HttpsError("permission-denied", "Só quem gravou a sessão pode excluir.");
      }
      if (mergedIntoOf(snap)) {
        throw new HttpsError("failed-precondition", "Essa sessão foi juntada a outra. Exclua pela principal.");
      }
      if (mergedFromOf(snap).length > 0) {
        throw new HttpsError(
          "failed-precondition",
          "Essa sessão tem lances de outra sessão juntada e ainda não dá para excluir.",
        );
      }

      // Leituras primeiro (regra da transação do Firestore).
      const participantIds = participantIdsOf(snap);
      const [highlights, asInto, asFrom, userSnaps] = await Promise.all([
        tx.get(sessionRef.collection("highlights")),
        tx.get(requests.where("intoSessionId", "==", sessionId)),
        tx.get(requests.where("fromSessionId", "==", sessionId)),
        participantIds.length > 0
          ? tx.getAll(...participantIds.map((id) => db().doc(`users/${id}`)))
          : Promise.resolve([]),
      ]);

      const highlightCount = (snap.get("highlightCount") as number | undefined) ?? 0;
      for (const userSnap of userSnaps) {
        if (!userSnap.exists) continue;
        tx.update(userSnap.ref, {
          "stats.sessions": FieldValue.increment(-1),
          "stats.highlights": FieldValue.increment(-highlightCount),
        });
      }
      for (const doc of [...highlights.docs, ...asInto.docs, ...asFrom.docs]) tx.delete(doc.ref);
      tx.delete(sessionRef);
      return true;
    });

    if (deleted) {
      try {
        await bucket().deleteFiles({ prefix: sessionStoragePrefix(sessionId) });
      } catch (e) {
        logger.error("deleteSession: a sessão saiu do banco, mas os arquivos ficaram no Storage", {
          sessionId,
          error: String(e),
        });
      }
    }

    return { sessionId };
  },
);
