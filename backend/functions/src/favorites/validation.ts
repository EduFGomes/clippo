/**
 * Regras puras (sem Firebase) dos favoritos (R18–R22 em docs/produto.md). Separadas para poderem
 * ser testadas sozinhas em test/favorites.validation.test.ts.
 *
 * O comentário espelha validateComment em app/lib/core/validation/input_validation.dart: mesmas
 * regras e mensagens (regra 0 do AGENTS.md).
 */

/** Até quantos caracteres um comentário pode ter (R22). */
export const COMMENT_MAX = 300;

/** Até quantas linhas um comentário pode ter (R22). */
export const COMMENT_MAX_LINES = 6;

export type FavoriteField = "postId" | "commentId" | "text" | "liked";

/** Erro de validação com o campo, para o app mostrar a mensagem embaixo dele. */
export class FavoriteValidationError extends Error {
  constructor(
    readonly field: FavoriteField,
    message: string,
  ) {
    super(message);
    this.name = "FavoriteValidationError";
  }
}

/** O id do favorito: `{uid}__{sessionId}__{highlightId}` (um por pessoa e lance: idempotente). */
export function postIdFor(uid: string, sessionId: string, highlightId: string): string {
  return `${uid}__${sessionId}__${highlightId}`;
}

const POST_ID_PATTERN = /^[A-Za-z0-9_-]{14,200}$/;
const COMMENT_ID_PATTERN = /^[A-Za-z0-9_-]{6,64}$/;

export function normalizePostId(raw: unknown): string {
  if (typeof raw !== "string" || !POST_ID_PATTERN.test(raw)) {
    throw new FavoriteValidationError("postId", "Esse favorito não foi encontrado. Tente de novo.");
  }
  return raw;
}

/** O id do comentário vem do app, para repetir a chamada não duplicar o comentário. */
export function normalizeCommentId(raw: unknown): string {
  if (typeof raw !== "string" || !COMMENT_ID_PATTERN.test(raw)) {
    throw new FavoriteValidationError("commentId", "Esse comentário não foi encontrado. Tente de novo.");
  }
  return raw;
}

export function normalizeLiked(raw: unknown): boolean {
  if (typeof raw !== "boolean") {
    throw new FavoriteValidationError("liked", "Não deu para curtir agora. Tente de novo.");
  }
  return raw;
}

/**
 * O texto do comentário (R22): sem espaços nas pontas, quebras de linha do Windows viram "\n",
 * de 1 a COMMENT_MAX caracteres e até COMMENT_MAX_LINES linhas.
 */
export function normalizeComment(raw: unknown): string {
  if (raw !== null && raw !== undefined && typeof raw !== "string") {
    throw new FavoriteValidationError("text", "Escreva um comentário.");
  }
  const text = (raw ?? "").replace(/\r\n?/g, "\n").trim();
  if (text.length === 0) {
    throw new FavoriteValidationError("text", "Escreva um comentário.");
  }
  if (text.length > COMMENT_MAX) {
    throw new FavoriteValidationError("text", `O comentário pode ter até ${COMMENT_MAX} caracteres.`);
  }
  if (text.split("\n").length > COMMENT_MAX_LINES) {
    throw new FavoriteValidationError("text", `O comentário pode ter até ${COMMENT_MAX_LINES} linhas.`);
  }
  return text;
}
