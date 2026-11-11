/**
 * leaveSession — função CHAMÁVEL: um participante sai da sessão por conta própria.
 *
 * 🟡 "Participantes podem sair de uma sessão?" ainda é decisão de produto em aberto
 * (produto.md › 5). A função existe para a tela poder usar se o grupo aprovar.
 *
 * O dono não sai (R9); ele pode tirar os outros pelo updateSession. Quem sai perde o
 * acesso à sessão e aos vídeos na hora (R11) e o contador do perfil volta.
 * Idempotente: sair de novo (ou de uma sessão de que já não participa) não é erro.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { mergedFromOf, mergedIntoOf, participantIdsOf, readPreview } from "./sessionDocs";
import { SessionValidationError, normalizeId } from "./validation";

export const leaveSession = onCall<{ sessionId: string }, Promise<{ sessionId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para sair da sessão.");
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

    await leaveSessionAs(uid, sessionId);

    return { sessionId };
  },
);

/**
 * Tira [uid] da sessão [sessionId] (usada pelo leaveSession e pelo deleteMyAccount). Recusa o
 * dono e a sessão juntada a outra; quem já não participa, ou sessão que não existe, não é erro.
 */
export async function leaveSessionAs(uid: string, sessionId: string): Promise<void> {
  const sessionRef = db().doc(`sessions/${sessionId}`);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(sessionRef);
    if (!snap.exists) return;
    if (mergedIntoOf(snap)) {
      throw new HttpsError("failed-precondition", "Essa sessão foi juntada a outra. Saia pela principal.");
    }
    const before = participantIdsOf(snap);
    if (!before.includes(uid)) return;
    if (snap.get("ownerId") === uid) {
      throw new HttpsError("failed-precondition", "Quem gravou a sessão não pode sair dela.");
    }

    const participantIds = before.filter((id) => id !== uid);
    const preview = await readPreview(tx, participantIds);
    const meSnap = await tx.get(db().doc(`users/${uid}`));
    const now = FieldValue.serverTimestamp();

    tx.update(sessionRef, {
      participantIds,
      participantCount: participantIds.length,
      participantsPreview: preview,
      updatedAt: now,
    });
    for (const fromId of mergedFromOf(snap)) {
      tx.update(db().doc(`sessions/${fromId}`), { participantIds, updatedAt: now });
    }
    if (meSnap.exists) {
      const highlightCount = (snap.get("highlightCount") as number | undefined) ?? 0;
      tx.update(meSnap.ref, {
        "stats.sessions": FieldValue.increment(-1),
        "stats.highlights": FieldValue.increment(-highlightCount),
      });
    }
  });
}
