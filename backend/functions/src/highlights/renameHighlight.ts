/**
 * renameHighlight — função CHAMÁVEL: o dono da sessão troca o nome de um lance.
 *
 * O lance nasce "Lance N" (o saveSession põe o nome pela posição); só o dono da sessão
 * renomeia, porque o nome aparece para todos os participantes (R11).
 *
 * Segue o padrão de users/completeProfile.ts: (1) quem chamou, (2) valida antes de tocar no
 * banco (highlights/validation.ts), (3) transação, (4) idempotente (o mesmo nome de novo não
 * grava nada), (5) erros em português prontos para a tela.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { logger } from "firebase-functions/v2";
import {
  HighlightValidationError,
  normalizeHighlightRef,
  normalizeHighlightRename,
} from "./validation";

export interface RenameHighlightRequest {
  sessionId: string;
  highlightId: string;
  title: string;
}

export interface RenameHighlightResponse {
  title: string;
}

export const renameHighlight = onCall<RenameHighlightRequest, Promise<RenameHighlightResponse>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para renomear o lance.");
    }

    let sessionId: string;
    let highlightId: string;
    let title: string;
    try {
      sessionId = normalizeHighlightRef(request.data?.sessionId, "sessionId");
      highlightId = normalizeHighlightRef(request.data?.highlightId, "highlightId");
      title = normalizeHighlightRename(request.data?.title);
    } catch (e) {
      if (e instanceof HighlightValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const sessionRef = db().doc(`sessions/${sessionId}`);
    const highlightRef = db().doc(`sessions/${sessionId}/highlights/${highlightId}`);

    await db().runTransaction(async (tx) => {
      const [session, highlight] = await Promise.all([tx.get(sessionRef), tx.get(highlightRef)]);
      if (!session.exists) {
        throw new HttpsError("not-found", "Essa sessão não existe mais.");
      }
      if (session.get("ownerId") !== uid) {
        throw new HttpsError("permission-denied", "Só quem gravou a sessão renomeia os lances.");
      }
      if (!highlight.exists) {
        throw new HttpsError("not-found", "Esse lance não existe mais.");
      }
      // Idempotente: o app pode repetir a chamada (ex.: a conexão caiu na resposta).
      if (highlight.get("title") === title) return;
      tx.update(highlightRef, { title, updatedAt: FieldValue.serverTimestamp() });
    });

    // Os favoritos desse lance (R18) mostram o nome copiado: acompanham a troca. Fora da
    // transação; se falhar, o lance já tem o nome novo e renomear de novo acerta as cópias.
    try {
      const posts = await db()
        .collection("posts")
        .where("sessionId", "==", sessionId)
        .where("highlightId", "==", highlightId)
        .get();
      await Promise.all(posts.docs.filter((p) => p.get("title") !== title).map((p) => p.ref.update({ title })));
    } catch (e) {
      logger.error("renameHighlight: o nome não chegou aos favoritos", { sessionId, highlightId, error: String(e) });
    }

    return { title };
  },
);
