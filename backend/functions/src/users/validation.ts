/**
 * Regras de validação da conta, do perfil e da sessão, sem dependência do Firebase.
 * Ficam separadas para poder ser testadas sozinhas (validation.test.ts).
 *
 * O app tem uma cópia destas regras (app/lib/core/validation/input_validation.dart),
 * com as mesmas mensagens. Mudou uma? Mude a outra no mesmo PR.
 */

export const NAME_MAX = 50;
export const USERNAME_MIN = 3;
export const USERNAME_MAX = 20;
export const EMAIL_MAX = 254;
export const EMAIL_LOCAL_MAX = 64;
export const SESSION_NAME_MAX = 50;
export const SESSION_LOCATION_MAX = 80;

/** Senha nova: igual a `validateNewPassword` do app (input_validation.dart). */
/** Idade mínima para usar o Clippo (grupo, 12/11/2026). Mesma `minimumAge` do app. */
export const MIN_AGE = 13;

export const PASSWORD_MIN = 8;
export const PASSWORD_MAX = 128;

/**
 * A regra da senha nova no servidor. A senha nunca passa por uma Function (vai direto do app
 * para o Firebase Auth, e a função de bloqueio não a recebe), então quem confere é a política
 * de senha do próprio Auth, aplicada ao projeto por `scripts/apply-password-policy.mjs`.
 *
 * ENFORCE: o Auth recusa criar conta (ou trocar a senha) fora da regra, com o erro
 * `password-does-not-meet-requirements`, que o app traduz. `forceUpgradeOnSignin` desligado:
 * quem criou a conta com a regra antiga (6+) continua entrando com a senha que tem.
 */
export const PASSWORD_POLICY = {
  enforcementState: "ENFORCE",
  forceUpgradeOnSignin: false,
  constraints: {
    requireUppercase: true,
    requireLowercase: true,
    requireNumeric: true,
    requireNonAlphanumeric: false,
    minLength: PASSWORD_MIN,
    maxLength: PASSWORD_MAX,
  },
} as const;

/** Erro de validação com uma mensagem pronta para mostrar ao usuário. */
export class ValidationError extends Error {
  constructor(
    readonly field: "email" | "name" | "username" | "birthDate" | "sessionName" | "sessionLocation",
    message: string,
  ) {
    super(message);
  }
}

/**
 * E-mail: sem espaços nas pontas, minúsculo, no formato nome@dominio.tld.
 * O Firebase Auth aceita endereços como "nome@g"; esta regra não.
 */
const EMAIL_PATTERN =
  /^[a-z0-9._%+-]+@(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/;

export function normalizeEmail(raw: unknown): string {
  if (typeof raw !== "string" || raw.trim().length === 0) {
    throw new ValidationError("email", "Informe seu e-mail.");
  }
  const email = raw.trim().toLowerCase();
  const local = email.split("@")[0];
  const valid =
    email.length <= EMAIL_MAX &&
    local.length <= EMAIL_LOCAL_MAX &&
    EMAIL_PATTERN.test(email) &&
    !local.startsWith(".") &&
    !local.endsWith(".") &&
    !email.includes("..");
  if (!valid) throw new ValidationError("email", "Esse e-mail não parece válido.");
  return email;
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
  // Faz MIN_AGE anos hoje ou antes (dia do aniversário conta, como no app).
  const birthday = Date.UTC(y + MIN_AGE, m - 1, d);
  const todayDay = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate());
  if (birthday > todayDay) {
    throw new ValidationError(
      "birthDate",
      `Você precisa ter pelo menos ${MIN_AGE} anos para usar o Clippo.`,
    );
  }
  return raw;
}

/** Nome da sessão: obrigatório, sem espaços nas pontas nem repetidos, até 50 caracteres. */
export function normalizeSessionName(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new ValidationError("sessionName", "Informe o nome da sessão.");
  }
  const name = raw.trim().replace(/\s+/g, " ");
  if (name.length === 0) {
    throw new ValidationError("sessionName", "Informe o nome da sessão.");
  }
  if (name.length > SESSION_NAME_MAX) {
    throw new ValidationError(
      "sessionName",
      `O nome da sessão pode ter até ${SESSION_NAME_MAX} caracteres.`,
    );
  }
  return name;
}

/** Local da sessão: opcional; quando preenchido, sem espaços repetidos e até 80 caracteres. */
export function normalizeSessionLocation(raw: unknown): string | null {
  if (raw === null || raw === undefined) return null;
  if (typeof raw !== "string") {
    throw new ValidationError(
      "sessionLocation",
      `O local pode ter até ${SESSION_LOCATION_MAX} caracteres.`,
    );
  }
  const location = raw.trim().replace(/\s+/g, " ");
  if (location.length === 0) return null;
  if (location.length > SESSION_LOCATION_MAX) {
    throw new ValidationError(
      "sessionLocation",
      `O local pode ter até ${SESSION_LOCATION_MAX} caracteres.`,
    );
  }
  return location;
}

/** O que o updateProfile recebe já conferido: só os campos que vieram. */
export interface ProfileUpdate {
  name?: string;
  username?: string;
}

/**
 * Pedido do updateProfile: nome e/ou @usuário, com as mesmas regras do cadastro.
 * Campo ausente (undefined ou null) = não mudar. Pelo menos um precisa vir.
 */
export function normalizeProfileUpdate(raw: unknown): ProfileUpdate {
  const data = (typeof raw === "object" && raw !== null ? raw : {}) as Record<string, unknown>;
  const has = (key: string) => data[key] !== undefined && data[key] !== null;
  if (!has("name") && !has("username")) {
    throw new ValidationError("name", "Informe o nome ou o nome de usuário.");
  }
  const update: ProfileUpdate = {};
  if (has("name")) update.name = normalizeName(data.name);
  if (has("username")) update.username = normalizeUsername(data.username);
  return update;
}
