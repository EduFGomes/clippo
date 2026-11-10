/**
 * Regras da amizade (D16 em docs/arquitetura.md), sem dependência do Firebase.
 * Ficam separadas para poderem ser testadas sozinhas (test/friends.validation.test.ts).
 *
 * O @ que a pessoa digita é validado por `normalizeUsername` (users/validation.ts), que
 * tem a cópia no app (app/lib/core/validation/input_validation.dart › validateUsername).
 */

/** Pedidos esperando resposta que uma pessoa pode ter enviado ao mesmo tempo (anti-spam). */
export const PENDING_REQUESTS_MAX = 50;

/** Amigos por pessoa. */
export const FRIENDS_MAX = 500;

export type FriendshipStatus = "pending" | "accepted";

export type FriendField = "uid" | "username";

/** Erro de validação com uma mensagem pronta para mostrar ao usuário. */
export class FriendValidationError extends Error {
  constructor(
    readonly field: FriendField,
    message: string,
  ) {
    super(message);
  }
}

/** Uids do Firebase Auth: letras e números (o Emulator também usa só isso). */
const UID_PATTERN = /^[A-Za-z0-9]{1,128}$/;

/** Confere um uid que veio do app (não é digitado, mas não confiamos nele). */
export function normalizeUid(raw: unknown): string {
  if (typeof raw !== "string" || !UID_PATTERN.test(raw)) {
    throw new FriendValidationError("uid", "Não encontramos essa pessoa.");
  }
  return raw;
}

/**
 * Id do documento da amizade: os dois uids em ordem, separados por "_".
 * Os dois lados chegam no MESMO documento, então não existe pedido duplicado (R15).
 */
export function friendshipId(a: string, b: string): string {
  return a < b ? `${a}_${b}` : `${b}_${a}`;
}

/** Os dois uids na ordem do id. */
export function friendshipUids(a: string, b: string): [string, string] {
  return a < b ? [a, b] : [b, a];
}
