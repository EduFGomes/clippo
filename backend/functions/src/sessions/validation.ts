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

/**
 * A pasta da sessão no Storage (vídeos e miniaturas, D17). Com a barra no fim: sem ela, apagar
 * "sessions/abc123" levaria junto "sessions/abc1234…".
 */
export function sessionStoragePrefix(sessionId: string): string {
  return `sessions/${normalizeId(sessionId, "sessionId")}/`;
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
 * Quem é amigo de quem (R10) é conferido no banco — ver `friends/friendships.ts`.
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
 * Mudar a data e o horário de uma sessão salva (updateSession): os lances continuam no mesmo
 * momento dentro da sessão (`offsetSeconds`), então a nova duração precisa ir até o último deles,
 * com a mesma folga de 1 minuto do [normalizeHighlights].
 */
export function checkPeriodFitsHighlights(durationSeconds: number, offsets: number[]): void {
  const last = offsets.reduce((max, offset) => Math.max(max, offset), 0);
  if (last > durationSeconds + 60) {
    throw new SessionValidationError(
      "endedAt",
      "A sessão precisa durar até o último lance. Confira o horário do fim.",
    );
  }
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

// R10 (participantes são amigos do dono) precisa do banco: está em
// friends/friendships.ts › areFriendsWithAll.

// --- Juntar sessões (D18 em docs/arquitetura.md › Juntar sessões) -------------------

/** Quanto as duas gravações podem estar afastadas no tempo e ainda serem "o mesmo jogo". */
export const MERGE_TOLERANCE_MINUTES = 30;

/** Sessões que podem virar uma só (a principal + as juntadas a ela). */
export const MERGED_SESSIONS_MAX = 5;

/** Id do pedido: um por par de sessões, então pedir de novo não duplica. */
export function mergeRequestId(intoSessionId: string, fromSessionId: string): string {
  return `${intoSessionId}__${fromSessionId}`;
}

/** O contrário de [mergeRequestId], validando as duas partes. */
export function parseMergeRequestId(raw: unknown): { intoSessionId: string; fromSessionId: string } {
  const parts = typeof raw === "string" ? raw.split("__") : [];
  if (parts.length !== 2) {
    throw new SessionValidationError("sessionId", "Esse pedido não existe mais.");
  }
  return {
    intoSessionId: normalizeId(parts[0], "sessionId"),
    fromSessionId: normalizeId(parts[1], "sessionId"),
  };
}

/** As duas gravações se encostam no tempo (com [MERGE_TOLERANCE_MINUTES] de folga)? */
export function periodsTouch(
  a: { startedAt: Date; endedAt: Date },
  b: { startedAt: Date; endedAt: Date },
  toleranceMinutes: number = MERGE_TOLERANCE_MINUTES,
): boolean {
  const tolerance = toleranceMinutes * 60 * 1000;
  return (
    a.startedAt.getTime() <= b.endedAt.getTime() + tolerance &&
    b.startedAt.getTime() <= a.endedAt.getTime() + tolerance
  );
}

/** O período que cobre as duas gravações. */
export function mergedPeriod(
  a: { startedAt: Date; endedAt: Date },
  b: { startedAt: Date; endedAt: Date },
): SessionPeriod {
  const startedAt = new Date(Math.min(a.startedAt.getTime(), b.startedAt.getTime()));
  const endedAt = new Date(Math.max(a.endedAt.getTime(), b.endedAt.getTime()));
  return {
    startedAt,
    endedAt,
    durationSeconds: Math.round((endedAt.getTime() - startedAt.getTime()) / 1000),
  };
}

/** A lista de participantes das duas, sem repetir, na ordem da principal. */
export function mergedParticipants(into: string[], from: string[]): string[] {
  return Array.from(new Set([...into, ...from]));
}

export interface StatsDelta {
  sessions: number;
  highlights: number;
}

/**
 * Quanto muda o `stats` de cada pessoa ao juntar B em A.
 *
 * Antes, cada um contava as sessões e os lances das sessões em que estava. Depois,
 * todos estão em uma sessão só (A) com os lances das duas. Quem estava nas duas perde
 * uma sessão; quem estava só em B ganha os lances de A, e vice-versa.
 */
export function mergeStatsDeltas(
  into: { participantIds: string[]; highlightCount: number },
  from: { participantIds: string[]; highlightCount: number },
): Map<string, StatsDelta> {
  const inInto = new Set(into.participantIds);
  const inFrom = new Set(from.participantIds);
  const total = into.highlightCount + from.highlightCount;
  const deltas = new Map<string, StatsDelta>();
  for (const uid of mergedParticipants(into.participantIds, from.participantIds)) {
    const a = inInto.has(uid);
    const b = inFrom.has(uid);
    const delta = {
      sessions: 1 - (a ? 1 : 0) - (b ? 1 : 0),
      highlights: total - (a ? into.highlightCount : 0) - (b ? from.highlightCount : 0),
    };
    if (delta.sessions !== 0 || delta.highlights !== 0) deltas.set(uid, delta);
  }
  return deltas;
}

/** Quem entrou e quem saiu quando o dono muda os participantes (R12). */
export function participantChanges(
  before: string[],
  after: string[],
): { added: string[]; removed: string[] } {
  const was = new Set(before);
  const now = new Set(after);
  return {
    added: after.filter((uid) => !was.has(uid)),
    removed: before.filter((uid) => !now.has(uid)),
  };
}
