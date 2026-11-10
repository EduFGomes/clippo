/**
 * Juntar sessões (D18 em docs/arquitetura.md › Juntar sessões).
 *
 * Caso de uso: tênis, um celular atrás de cada jogador. São duas sessões, cada uma com
 * os seus lances; no fim, viram um hub só.
 *
 * - requestSessionMerge: o dono da sessão principal (A) pede para trazer a sessão B,
 *   de outro dono, da qual ele participa.
 * - acceptSessionMerge: o dono de B aceita; os lances de B são copiados para A.
 * - cancelSessionMerge: qualquer um dos dois desiste ou recusa.
 *
 * Os vídeos NÃO mudam de lugar no Storage: a cópia do lance aponta para o caminho
 * original, e B fica com a mesma lista de participantes que A (as regras do Storage
 * conferem a sessão do caminho).
 */
import { FieldValue, type DocumentSnapshot } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { mergedFromOf, mergedIntoOf, participantIdsOf, readPreview, toDate } from "./sessionDocs";
import {
  HIGHLIGHTS_MAX,
  MERGED_SESSIONS_MAX,
  MERGE_TOLERANCE_MINUTES,
  PARTICIPANTS_MAX,
  SessionValidationError,
  mergeRequestId,
  mergeStatsDeltas,
  mergedParticipants,
  mergedPeriod,
  normalizeId,
  parseMergeRequestId,
  periodsTouch,
} from "./validation";

function periodOf(snap: DocumentSnapshot) {
  return { startedAt: toDate(snap.get("startedAt")), endedAt: toDate(snap.get("endedAt")) };
}

const countOf = (snap: DocumentSnapshot) => (snap.get("highlightCount") as number | undefined) ?? 0;

/**
 * Tudo o que precisa ser verdade para juntar [from] em [into]. Conferido no pedido e de
 * novo no aceite (as sessões podem ter mudado no meio).
 */
function assertCanMerge(into: DocumentSnapshot, from: DocumentSnapshot, requesterUid: string) {
  if (!into.exists || !from.exists) {
    throw new HttpsError("not-found", "Essa sessão não existe mais.");
  }
  if (into.id === from.id) {
    throw new HttpsError("invalid-argument", "Escolha outra sessão para juntar.");
  }
  if (into.get("ownerId") !== requesterUid) {
    throw new HttpsError("permission-denied", "Só quem gravou a sessão pode juntar outra a ela.");
  }
  if (!participantIdsOf(from).includes(requesterUid)) {
    throw new HttpsError("permission-denied", "Você só pode juntar sessões de que participa.");
  }
  if (from.get("ownerId") === requesterUid) {
    // As duas são minhas: não precisa de pedido, e o fluxo de hoje é só entre donos diferentes.
    throw new HttpsError("invalid-argument", "As duas sessões são suas. Escolha a sessão de outra pessoa.");
  }
  if (mergedIntoOf(into) || mergedIntoOf(from)) {
    throw new HttpsError("failed-precondition", "Uma das sessões já foi juntada a outra.");
  }
  if (mergedFromOf(into).includes(from.id)) {
    throw new HttpsError("failed-precondition", "Essas sessões já estão juntas.");
  }
  if (!periodsTouch(periodOf(into), periodOf(from))) {
    throw new HttpsError(
      "failed-precondition",
      `Só dá para juntar sessões gravadas no mesmo jogo (até ${MERGE_TOLERANCE_MINUTES} min de diferença).`,
    );
  }
  const sessions = 2 + mergedFromOf(into).length + mergedFromOf(from).length;
  if (sessions > MERGED_SESSIONS_MAX) {
    throw new HttpsError(
      "failed-precondition",
      `Dá para juntar até ${MERGED_SESSIONS_MAX} sessões numa só.`,
    );
  }
  if (mergedParticipants(participantIdsOf(into), participantIdsOf(from)).length > PARTICIPANTS_MAX) {
    throw new HttpsError(
      "failed-precondition",
      `Juntas, as sessões passariam de ${PARTICIPANTS_MAX} participantes.`,
    );
  }
  if (countOf(into) + countOf(from) > HIGHLIGHTS_MAX) {
    throw new HttpsError(
      "failed-precondition",
      `Juntas, as sessões passariam de ${HIGHLIGHTS_MAX} lances.`,
    );
  }
}

function validationToHttps(e: unknown): never {
  if (e instanceof SessionValidationError) {
    throw new HttpsError("invalid-argument", e.message, { field: e.field });
  }
  throw e;
}

export interface RequestSessionMergeRequest {
  /** A sessão principal, minha. */
  intoSessionId: string;
  /** A sessão de outra pessoa, da qual participo. */
  fromSessionId: string;
}

export const requestSessionMerge = onCall<RequestSessionMergeRequest, Promise<{ requestId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para juntar sessões.");
    }

    let intoId: string;
    let fromId: string;
    try {
      intoId = normalizeId(request.data?.intoSessionId, "sessionId");
      fromId = normalizeId(request.data?.fromSessionId, "sessionId");
    } catch (e) {
      validationToHttps(e);
    }

    const requestId = mergeRequestId(intoId, fromId);
    const requestRef = db().doc(`sessionMergeRequests/${requestId}`);

    await db().runTransaction(async (tx) => {
      const [into, from, existing] = await tx.getAll(
        db().doc(`sessions/${intoId}`),
        db().doc(`sessions/${fromId}`),
        requestRef,
      );
      assertCanMerge(into, from, uid);
      if (existing.exists) return; // idempotente: o pedido já está esperando

      const otherOwner = from.get("ownerId") as string;
      tx.set(requestRef, {
        uids: [uid, otherOwner],
        intoSessionId: intoId,
        fromSessionId: fromId,
        requestedBy: uid,
        requestedTo: otherOwner,
        intoName: into.get("name") ?? "",
        fromName: from.get("name") ?? "",
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    return { requestId };
  },
);

export const acceptSessionMerge = onCall<{ requestId: string }, Promise<{ sessionId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para juntar sessões.");
    }

    let intoId: string;
    let fromId: string;
    try {
      ({ intoSessionId: intoId, fromSessionId: fromId } = parseMergeRequestId(request.data?.requestId));
    } catch (e) {
      validationToHttps(e);
    }

    const requestRef = db().doc(`sessionMergeRequests/${mergeRequestId(intoId, fromId)}`);
    const intoRef = db().doc(`sessions/${intoId}`);
    const fromRef = db().doc(`sessions/${fromId}`);

    await db().runTransaction(async (tx) => {
      // --- Leituras (todas antes de qualquer escrita) ---
      const [req, into, from] = await tx.getAll(requestRef, intoRef, fromRef);
      if (!req.exists) {
        // Idempotente: o aceite já rodou (o pedido é apagado no fim) ou alguém desistiu.
        if (from.exists && mergedIntoOf(from) === intoId) return;
        throw new HttpsError("not-found", "Esse pedido não existe mais.");
      }
      if (req.get("requestedTo") !== uid || from.get("ownerId") !== uid) {
        throw new HttpsError("permission-denied", "Só quem gravou a outra sessão pode aceitar.");
      }
      assertCanMerge(into, from, req.get("requestedBy") as string);

      const [intoHighlights, fromHighlights] = await Promise.all([
        tx.get(intoRef.collection("highlights")),
        tx.get(fromRef.collection("highlights")),
      ]);

      const intoParticipants = participantIdsOf(into);
      const fromParticipants = participantIdsOf(from);
      const participantIds = mergedParticipants(intoParticipants, fromParticipants);
      const preview = await readPreview(tx, participantIds);

      const deltas = mergeStatsDeltas(
        { participantIds: intoParticipants, highlightCount: countOf(into) },
        { participantIds: fromParticipants, highlightCount: countOf(from) },
      );
      const userSnaps = deltas.size === 0
        ? []
        : await tx.getAll(...Array.from(deltas.keys()).map((id) => db().doc(`users/${id}`)));

      // --- Escritas ---
      const now = FieldValue.serverTimestamp();
      const intoPeriod = periodOf(into);
      const period = mergedPeriod(intoPeriod, periodOf(from));
      const shift = Math.round((intoPeriod.startedAt.getTime() - period.startedAt.getTime()) / 1000);

      // O início pode ter ficado mais cedo: os lances de A mudam de posição no tempo.
      if (shift > 0) {
        for (const h of intoHighlights.docs) {
          tx.update(h.ref, { offsetSeconds: FieldValue.increment(shift), updatedAt: now });
        }
      }

      const intoIds = new Set(intoHighlights.docs.map((h) => h.id));
      let copied = 0;
      for (const h of fromHighlights.docs) {
        if (intoIds.has(h.id)) continue;
        const savedAt = toDate(h.get("savedAt"));
        tx.set(intoRef.collection("highlights").doc(h.id), {
          ...h.data(),
          offsetSeconds: Math.max(0, Math.round((savedAt.getTime() - period.startedAt.getTime()) / 1000)),
          // Se B já tinha lances de outra sessão juntada, eles continuam apontando para a de origem.
          sourceSessionId: (h.get("sourceSessionId") as string | null | undefined) ?? fromId,
          updatedAt: now,
        });
        copied++;
      }

      const intoMergedFrom = mergedFromOf(into);
      const fromMergedFrom = mergedFromOf(from);
      const mergedFrom = Array.from(new Set([...intoMergedFrom, fromId, ...fromMergedFrom]));

      tx.update(intoRef, {
        participantIds,
        participantCount: participantIds.length,
        participantsPreview: preview,
        startedAt: period.startedAt,
        endedAt: period.endedAt,
        durationSeconds: period.durationSeconds,
        highlightCount: countOf(into) + copied,
        mergedFrom,
        updatedAt: now,
      });

      // Todas as sessões que agora apontam para A ficam com a mesma lista (regras do Storage).
      for (const id of mergedFrom) {
        tx.update(db().doc(`sessions/${id}`), {
          participantIds,
          mergedInto: intoId,
          ...(id === fromId ? { mergedFrom: [] } : {}),
          updatedAt: now,
        });
      }

      for (const userSnap of userSnaps) {
        const delta = deltas.get(userSnap.id);
        if (!userSnap.exists || !delta) continue;
        tx.update(userSnap.ref, {
          "stats.sessions": FieldValue.increment(delta.sessions),
          "stats.highlights": FieldValue.increment(delta.highlights),
        });
      }

      tx.delete(requestRef);
    });

    return { sessionId: intoId };
  },
);

export const cancelSessionMerge = onCall<{ requestId: string }, Promise<{ requestId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para mexer nas suas sessões.");
    }

    let requestId: string;
    try {
      const ids = parseMergeRequestId(request.data?.requestId);
      requestId = mergeRequestId(ids.intoSessionId, ids.fromSessionId);
    } catch (e) {
      validationToHttps(e);
    }

    const ref = db().doc(`sessionMergeRequests/${requestId}`);
    await db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return; // idempotente
      const uids = (snap.get("uids") as string[] | undefined) ?? [];
      if (!uids.includes(uid)) {
        throw new HttpsError("permission-denied", "Esse pedido não é seu.");
      }
      tx.delete(ref);
    });

    return { requestId };
  },
);
