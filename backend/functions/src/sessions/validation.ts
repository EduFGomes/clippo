/**
 * Regras de validação da sessão e dos highlights, sem dependência do Firebase.
 * Ficam separadas para poder ser testadas sozinhas (test/sessions.validation.test.ts).
 *
 * O app tem uma cópia destas regras (app/lib/core/validation/input_validation.dart),
 * com as mesmas mensagens. Mudou uma? Mude a outra no mesmo PR (regra 0 do AGENTS.md).
 */

export const SESSION_NAME_MAX = 50;
export const LOCATION_MAX = 60;
export const HIGHLIGHT_TITLE_MAX = 50;

/** Uma sessão não pode durar mais que isso: acima disso é erro de relógio, não jogo. */
export const SESSION_MAX_HOURS = 12;

/** Participantes por sessão, contando o dono (R9). */
export const PARTICIPANTS_MAX = 30;

/** Teto por sessão, para uma chamada não gravar o dia inteiro de uma vez. */
export const HIGHLIGHTS_MAX = 200;

/** Um highlight tem ~30 s (R1); 120 s é folga para mudanças futuras do buffer. */
export const HIGHLIGHT_SECONDS_MAX = 120;

export type SessionField =
  | "sessionId"
  | "name"
  | "location"
  | "startedAt"
  | "endedAt"
  | "participantIds"
  | "highlights";

/** Erro de validação com uma mensagem pronta para mostrar ao usuário. */
export class SessionValidationError extends Error {
  constructor(
    readonly field: SessionField,
    message: string,
  ) {
    super(message);
  }
}

/** Ids gerados pelo app (o mesmo id chegando duas vezes é a mesma sessão). */
const ID_PATTERN = /^[A-Za-z0-9_-]{6,64}$/;

export function normalizeId(raw: unknown, field: SessionField): string {
  if (typeof raw !== "string" || !ID_PATTERN.test(raw)) {
    throw new SessionValidationError(field, "Não foi possível salvar a sessão. Tente de novo.");
  }
  return raw;
}

/** Tira espaços das pontas e junta espaços repetidos. */
export function normalizeSessionName(raw: unknown): string {
  if (typeof raw !== "string") {
    throw new SessionValidationError("name", "Dê um nome para a sessão.");
  }
  const name = raw.trim().replace(/\s+/g, " ");
  if (name.length === 0) {
    throw new SessionValidationError("name", "Dê um nome para a sessão.");
  }
  if (name.length > SESSION_NAME_MAX) {
    throw new SessionValidationError(
      "name",
      `O nome da sessão pode ter até ${SESSION_NAME_MAX} caracteres.`,
    );
  }
  return name;
}

/** O local é opcional: sem GPS e sem digitar, a sessão fica sem local. */
export function normalizeLocation(raw: unknown): string | null {
  if (raw === null || raw === undefined || raw === "") return null;
  if (typeof raw !== "string") {
    throw new SessionValidationError("location", "Esse local não parece válido.");
  }
  const label = raw.trim().replace(/\s+/g, " ");
  if (label.length === 0) return null;
  if (label.length > LOCATION_MAX) {
    throw new SessionValidationError(
      "location",
      `O local pode ter até ${LOCATION_MAX} caracteres.`,
    );
  }
  return label;
}

/** Data e hora em ISO 8601 (o app manda o instante em UTC). */
function parseInstant(raw: unknown, field: SessionField, message: string): Date {
  if (typeof raw !== "string") throw new SessionValidationError(field, message);
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) throw new SessionValidationError(field, message);
  return date;
}

export interface SessionPeriod {
  startedAt: Date;
  endedAt: Date;
  durationSeconds: number;
}

/**
 * Início e fim da gravação. O fim vem depois do início, a sessão não dura mais que
 * [SESSION_MAX_HOURS] e nada acontece no futuro (com folga de 5 min para o relógio
 * do celular estar adiantado).
 */
export function normalizePeriod(
  rawStart: unknown,
  rawEnd: unknown,
  now: Date = new Date(),
): SessionPeriod {
  const startedAt = parseInstant(rawStart, "startedAt", "Confira a data e a hora da sessão.");
  const endedAt = parseInstant(rawEnd, "endedAt", "Confira a data e a hora da sessão.");

  if (endedAt.getTime() <= startedAt.getTime()) {
    throw new SessionValidationError("endedAt", "O fim da sessão precisa vir depois do início.");
  }
  const durationSeconds = Math.round((endedAt.getTime() - startedAt.getTime()) / 1000);
  if (durationSeconds > SESSION_MAX_HOURS * 3600) {
    throw new SessionValidationError(
      "endedAt",
      `Uma sessão pode durar até ${SESSION_MAX_HOURS} horas.`,
    );
  }
  const limit = now.getTime() + 5 * 60 * 1000;
  if (endedAt.getTime() > limit) {
    throw new SessionValidationError("endedAt", "A sessão não pode terminar no futuro.");
  }
  return { startedAt, endedAt, durationSeconds };
}

/**
 * Participantes: o dono entra sempre (R9), sem repetidos.
 * Quem é amigo de quem ainda não é conferido aqui — ver `participantsAreFriends`.
 */
export function normalizeParticipantIds(raw: unknown, ownerId: string): string[] {
  const list = Array.isArray(raw) ? raw : [];
  for (const uid of list) {
    if (typeof uid !== "string" || uid.length === 0) {
      throw new SessionValidationError("participantIds", "Confira quem jogou com você.");
    }
  }
  const unique = Array.from(new Set<string>([ownerId, ...(list as string[])]));
  if (unique.length > PARTICIPANTS_MAX) {
    throw new SessionValidationError(
      "participantIds",
      `Uma sessão pode ter até ${PARTICIPANTS_MAX} participantes.`,
    );
  }
  return unique;
}

export interface HighlightInput {
  highlightId: string;
  title: string;
  offsetSeconds: number;
  durationSeconds: number;
}

/** Título do lance. Vazio vira "Lance N" — ninguém precisa digitar na quadra. */
function normalizeTitle(raw: unknown, position: number): string {
  if (raw === null || raw === undefined || raw === "") return `Lance ${position}`;
  if (typeof raw !== "string") {
    throw new SessionValidationError("highlights", "Confira o nome dos lances.");
  }
  const title = raw.trim().replace(/\s+/g, " ");
  if (title.length === 0) return `Lance ${position}`;
  if (title.length > HIGHLIGHT_TITLE_MAX) {
    throw new SessionValidationError(
      "highlights",
      `O nome do lance pode ter até ${HIGHLIGHT_TITLE_MAX} caracteres.`,
    );
  }
  return title;
}

function wholeSeconds(raw: unknown): number | null {
  if (typeof raw !== "number" || !Number.isFinite(raw) || raw < 0) return null;
  return Math.round(raw);
}

/**
 * Os lances salvos pelo gesto. Uma sessão pode não ter nenhum (R14 🟡) — a lista
 * vazia é aceita de propósito.
 *
 * `offsetSeconds` é o momento do lance dentro da sessão; ele cabe na duração, com
 * 1 minuto de folga para o arredondamento do corte não barrar o último lance.
 */
export function normalizeHighlights(raw: unknown, durationSeconds: number): HighlightInput[] {
  if (raw === null || raw === undefined) return [];
  if (!Array.isArray(raw)) {
    throw new SessionValidationError("highlights", "Não foi possível salvar os lances.");
  }
  if (raw.length > HIGHLIGHTS_MAX) {
    throw new SessionValidationError(
      "highlights",
      `Uma sessão pode ter até ${HIGHLIGHTS_MAX} lances.`,
    );
  }

  const ids = new Set<string>();
  return raw.map((item, index) => {
    const data = (item ?? {}) as Record<string, unknown>;
    const highlightId = normalizeId(data.highlightId, "highlights");
    if (ids.has(highlightId)) {
      throw new SessionValidationError("highlights", "Não foi possível salvar os lances.");
    }
    ids.add(highlightId);

    const offsetSeconds = wholeSeconds(data.offsetSeconds);
    if (offsetSeconds === null || offsetSeconds > durationSeconds + 60) {
      throw new SessionValidationError("highlights", "Confira o momento dos lances.");
    }

    const clipSeconds = wholeSeconds(data.durationSeconds);
    if (clipSeconds === null || clipSeconds === 0 || clipSeconds > HIGHLIGHT_SECONDS_MAX) {
      throw new SessionValidationError("highlights", "Confira a duração dos lances.");
    }

    return {
      highlightId,
      title: normalizeTitle(data.title, index + 1),
      offsetSeconds,
      durationSeconds: clipSeconds,
    };
  });
}

/**
 * 🟡 R10: os participantes precisam ser amigos do dono.
 *
 * Ainda não dá para conferir: `Friendship` não está modelado e a R15 (amizade com
 * aceite ou não) é decisão aberta do grupo. Quando a coleção existir, implemente aqui
 * e o `saveSession` passa a recusar sozinho — o lugar da chamada já está pronto.
 *
 * Até lá, o que protege é a checagem de que cada participante existe em `users/`.
 */
export async function participantsAreFriends(
  _ownerId: string,
  _participantIds: string[],
): Promise<boolean> {
  return true;
}
