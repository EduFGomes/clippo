/**
 * unfavoriteHighlight — função CHAMÁVEL: quem favoritou desfaz (R21). O favorito some do perfil
 * com as curtidas, os comentários e a cópia do vídeo. O app pergunta antes se houver comentários.
 *
 * Padrão de users/completeProfile.ts: quem chamou, valida os ids, transação (em deletePost),
 * idempotente (favorito que já não existe não é erro), erros em português.
 */
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { HighlightValidationError, normalizeHighlightRef } from "../highlights/validation";
import { deletePost } from "./posts";
import { postIdFor } from "./validation";

export const unfavoriteHighlight = onCall<
  { sessionId: string; highlightId: string },
  Promise<{ postId: string }>
>(CALLABLE_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Entre na sua conta para desfavoritar o lance.");
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

  // O id é o do próprio chamador: ninguém desfavorita o favorito de outra pessoa.
  const postId = postIdFor(uid, sessionId, highlightId);
  await deletePost(postId);
  return { postId };
});
