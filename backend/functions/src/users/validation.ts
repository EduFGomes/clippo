/**
 * Regras de validação do perfil, sem dependência do Firebase.
 * Ficam separadas para poder ser testadas sozinhas (validation.test.ts).
 */

export const NAME_MAX = 50;
export const USERNAME_MIN = 3;
export const USERNAME_MAX = 20;

/** Erro de validação com uma mensagem pronta para mostrar ao usuário. */
export class ValidationError extends Error {
  constructor(
    readonly field: "name" | "username" | "birthDate",
    message: string,
  ) {
    super(message);
  }
}

/** Tira espaços das pontas e junta espaços repetidos. */
export function normalizeName(raw: unknown): string {
  if (typeof raw !== "string") throw new ValidationError("name", "Informe seu nome.");
  const name = raw.trim().replace(/\s+/g, " ");
  if (name.length === 0) throw new ValidationError("name", "Informe seu nome.");
  if (name.length > NAME_MAX) {
    throw new ValidationError("name", `O nome pode ter até ${NAME_MAX} caracteres.`);
  }
  return name;
}

/**
 * Normaliza o @usuário: sem "@", minúsculas, sem espaços nas pontas.
 * Permitido: letras a–z, números, "_" e "."; 3 a 20 caracteres;
 * não pode começar nem terminar com "." nem ter ".." seguidos.
 */
export function normalizeUsername(raw: unknown): string {
  if (typeof raw !== "string") throw new ValidationError("username", "Escolha um nome de usuário.");
  const username = raw.trim().replace(/^@/, "").toLowerCase();
  if (username.length < USERNAME_MIN || username.length > USERNAME_MAX) {
    throw new ValidationError(
      "username",
      `O nome de usuário precisa ter de ${USERNAME_MIN} a ${USERNAME_MAX} caracteres.`,
    );
  }
  if (!/^[a-z0-9._]+$/.test(username)) {
    throw new ValidationError("username", "Use só letras sem acento, números, \"_\" e \".\".");
  }
  if (username.startsWith(".") || username.endsWith(".") || username.includes("..")) {
    throw new ValidationError("username", "O ponto não pode ficar no começo, no fim ou repetido.");
  }
  return username;
}

/**
 * Valida a data de nascimento no formato AAAA-MM-DD.
 * Guardada só para estatísticas agregadas (ex.: média de idade); nunca fica visível a outros usuários.
 */
export function normalizeBirthDate(raw: unknown, today: Date = new Date()): string {
  if (typeof raw !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    throw new ValidationError("birthDate", "Informe a data de nascimento.");
  }
  const [y, m, d] = raw.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1, d));
  const valid =
    date.getUTCFullYear() === y && date.getUTCMonth() === m - 1 && date.getUTCDate() === d;
  if (!valid) throw new ValidationError("birthDate", "Data de nascimento inválida.");
  if (date.getTime() > today.getTime() || y < 1900) {
    throw new ValidationError("birthDate", "Data de nascimento inválida.");
  }
  return raw;
}
