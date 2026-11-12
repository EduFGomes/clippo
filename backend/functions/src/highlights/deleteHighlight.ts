/**
 * deleteHighlight — função CHAMÁVEL: o dono da sessão apaga um lance para todos (R12).
 *
 * Segue o padrão de users/completeProfile.ts: (1) quem chamou, (2) valida os ids antes de tocar
 * no banco, (3) numa transação apaga o lance e desconta 1 do contador da sessão e do perfil de
 * cada participante, (4) idempotente (lance que já não existe não é erro), (5) erros em
 * português. Depois, fora da transação, apaga o vídeo e a miniatura no Storage; se falhar, o
 * lance já sumiu para todos e só o log registra o arquivo que ficou.
 *
 * Lance que veio de uma sessão juntada (D18, `sourceSessionId`) é da outra pessoa: o dono da
 * principal não apaga.
 */
import { FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { bucket, db } from "../shared/admin";
import {
  highlightThumbnailPath,
  highlightVideoPath,
  mergedIntoOf,
  participantIdsOf,
} from "../sessions/sessionDocs";
import { HighlightValidationError, normalizeHighlightRef } from "./validation";

export const deleteHighlight = onCall<
  { sessionId: string; highlightId: string },
  Promise<{ highlightId: string }>
>(CALLABLE_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Entre na sua conta para apagar o lance.");
  }

  let sessionId: string;
  let highlightId: string;
  try {
    sessionId = normalizeHighlightRef(request.data?.sessionId, "sessionId");
    highlightId = normalizeHighlightRef(request.data?.highlightId, "highlightId");
  } catch (e) {
    if (e instanceof HighlightValidationError) {
      throw new HttpsError("invalid-argument", e.message, { field: e.field });
    }
    throw e;
  }

  const sessionRef = db().doc(`sessions/${sessionId}`);
  const highlightRef = sessionRef.collection("highlights").doc(highlightId);

  const deleted = await db().runTransaction(async (tx) => {
    const [session, highlight] = await tx.getAll(sessionRef, highlightRef);
    if (!session.exists) return false;
    if (session.get("ownerId") !== uid) {
      throw new HttpsError("permission-denied", "Só quem gravou a sessão apaga os lances.");
    }
    if (mergedIntoOf(session)) {
      throw new HttpsError("failed-precondition", "Essa sessão foi juntada a outra. Apague pela principal.");
    }
    if (!highlight.exists) return false;
    const source = highlight.get("sourceSessionId") as string | undefined;
    if (source && source !== sessionId) {
      throw new HttpsError(
        "failed-precondition",
        "Esse lance veio da sessão de outra pessoa. Só ela pode apagar.",
      );
    }

    const participantIds = participantIdsOf(session);
    const userSnaps =
      participantIds.length > 0 ? await tx.getAll(...participantIds.map((id) => db().doc(`users/${id}`))) : [];
    for (const userSnap of userSnaps) {
      if (userSnap.exists) tx.update(userSnap.ref, { "stats.highlights": FieldValue.increment(-1) });
    }
    tx.update(sessionRef, {
      highlightCount: FieldValue.increment(-1),
      updatedAt: FieldValue.serverTimestamp(),
    });
    tx.delete(highlightRef);
    return true;
  });

  if (deleted) {
    for (const path of [highlightVideoPath(sessionId, highlightId), highlightThumbnailPath(sessionId, highlightId)]) {
      try {
        await bucket().file(path).delete({ ignoreNotFound: true });
      } catch (e) {
        logger.error("deleteHighlight: o lance saiu do banco, mas o arquivo ficou no Storage", {
          path,
          error: String(e),
        });
      }
    }
  }

  return { highlightId };
});
