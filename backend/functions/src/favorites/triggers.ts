/**
 * Gatilhos que fazem o favorito sumir junto (R21). Podem rodar mais de uma vez: apagar um
 * favorito que já sumiu não é erro (deletePost é idempotente).
 *
 * - onHighlightDeleted: o lance foi apagado (deleteHighlight, deleteSession, deleteMyAccount).
 * - onSessionParticipantsChanged: alguém saiu ou foi tirado da sessão (leaveSession,
 *   updateSession, deleteMyAccount): os favoritos dessa pessoa nos lances da sessão somem.
 */
import { onDocumentDeleted, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

import { deletePostsOfHighlight, deletePostsOfLeavers } from "./posts";

export const onHighlightDeleted = onDocumentDeleted(
  "sessions/{sessionId}/highlights/{highlightId}",
  async (event) => {
    const { sessionId, highlightId } = event.params;
    const removed = await deletePostsOfHighlight(sessionId, highlightId);
    if (removed > 0) logger.info("onHighlightDeleted: favoritos apagados", { sessionId, highlightId, removed });
  },
);

export const onSessionParticipantsChanged = onDocumentUpdated("sessions/{sessionId}", async (event) => {
  const ids = (raw: unknown) => (Array.isArray(raw) ? raw.filter((id): id is string => typeof id === "string") : []);
  const before = ids(event.data?.before.get("participantIds"));
  const after = new Set(ids(event.data?.after.get("participantIds")));
  const left = before.filter((uid) => !after.has(uid));
  if (left.length === 0) return;
  const removed = await deletePostsOfLeavers(event.params.sessionId, left);
  if (removed > 0) logger.info("onSessionParticipantsChanged: favoritos apagados", { sessionId: event.params.sessionId, removed });
});
