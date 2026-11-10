/**
 * saveSession — função CHAMÁVEL, acionada pelo "Salvar sessão" (produto.md › 4.5, estado D).
 *
 * Decisão D15: sessões e highlights são gravados **só** por aqui; as Security Rules
 * continuam fechadas para escrita. A gravação em si não depende desta função (R8): o
 * gesto salva o MP4 na pasta interna do app, e sem internet o app guarda a sessão e
 * tenta de novo sozinho (WorkManager). Por isso ela é **idempotente**: o id da sessão e
 * o de cada highlight nascem no aparelho, e chamar duas vezes não duplica nada (se um
 * reenvio trouxer um lance que faltou na primeira tentativa, apenas o lance faltante
 * é gravado).
 *
 * O que grava, numa transação (ou tudo, ou nada):
 *   sessions/{sessionId}                      → a sessão e seus participantes
 *   sessions/{sessionId}/highlights/{id}      → um documento por lance, `status: pending`
 *   users/{uid}.stats                         → atualiza contadores de sessões e lances
 *
 * Os participantes precisam ser amigos do dono (R10, D16).
 *
 * Se a sessão já foi juntada a outra (D18) e o reenvio trouxer lances novos, eles são
 * gravados na sessão e na principal, para aparecerem no hub.
 *
 * O vídeo NÃO passa por aqui: ele sobe do app direto para o Storage, e o gatilho
 * `onVideoUploaded` marca o highlight como `uploaded` (R13).
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { areFriendsWithAll } from "../friends/friendships";
import { db } from "../shared/admin";
import {
  PREVIEW_MAX,
  highlightThumbnailPath,
  highlightVideoPath,
  mergedIntoOf,
  participantIdsOf,
  previewEntry,
  toDate,
} from "./sessionDocs";
import {
  type HighlightInput,
  SessionValidationError,
  normalizeHighlights,
  normalizeId,
  normalizeLocation,
  normalizeParticipantIds,
  normalizePeriod,
  normalizeSessionName,
} from "./validation";

export { highlightThumbnailPath, highlightVideoPath } from "./sessionDocs";

export interface SaveSessionHighlight {
  /** Id gerado no aparelho. */
  highlightId: string;
  title?: string | null;
  /** Momento do lance dentro da sessão. */
  offsetSeconds: number;
  /** Quanto o trecho tem de fato (~30 s, menos se a sessão era curta — R5). */
  durationSeconds: number;
}

export interface SaveSessionRequest {
  /** Id gerado no aparelho; é o que torna a chamada idempotente. */
  sessionId: string;
  name: string;
  /** ISO 8601. */
  startedAt: string;
  endedAt: string;
  location?: string | null;
  /** Amigos escolhidos; o dono entra sozinho (R9). */
  participantIds?: string[];
  highlights?: SaveSessionHighlight[];
}

export interface SaveSessionResponse {
  sessionId: string;
  /** Onde cada vídeo deve ser enviado no Storage, na ordem em que chegaram. */
  videoPaths: Record<string, string>;
  /** false quando a sessão já existia: a chamada repetiu e a sessão não foi recriada. */
  created: boolean;
}

/** O documento de um lance novo, como fica no Firestore. */
function highlightDoc(
  sessionId: string,
  highlight: HighlightInput,
  savedAt: Date,
  offsetSeconds: number,
  createdBy: string,
  sourceSessionId: string | null,
) {
  const now = FieldValue.serverTimestamp();
  return {
    title: highlight.title,
    offsetSeconds,
    durationSeconds: highlight.durationSeconds,
    savedAt,
    createdBy,
    // O vídeo fica sempre no caminho da sessão onde foi gravado, mesmo depois de juntar (D18).
    videoPath: highlightVideoPath(sourceSessionId ?? sessionId, highlight.highlightId),
    thumbnailPath: highlightThumbnailPath(sourceSessionId ?? sessionId, highlight.highlightId),
    // O vídeo ainda está só no aparelho; o gatilho do Storage marca "uploaded" (R13).
    status: "pending",
    sourceSessionId,
    createdAt: now,
    updatedAt: now,
  };
}

export const saveSession = onCall<SaveSessionRequest, Promise<SaveSessionResponse>>(
  CALLABLE_OPTIONS,
  async (request) => {
    // 1. Quem chamou?
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para salvar a sessão.");
    }

    // 2. Valida e normaliza tudo ANTES de tocar no banco.
    let sessionId: string;
    let name: string;
    let location: string | null;
    let period: ReturnType<typeof normalizePeriod>;
    let participantIds: string[];
    let highlights: ReturnType<typeof normalizeHighlights>;
    try {
      const data = request.data ?? ({} as SaveSessionRequest);
      sessionId = normalizeId(data.sessionId, "sessionId");
      name = normalizeSessionName(data.name);
      location = normalizeLocation(data.location);
      period = normalizePeriod(data.startedAt, data.endedAt);
      participantIds = normalizeParticipantIds(data.participantIds, uid);
      highlights = normalizeHighlights(data.highlights, period.durationSeconds);
    } catch (e) {
      if (e instanceof SessionValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    // 3. Os participantes existem e são amigos do dono (R10)?
    const others = participantIds.filter((id) => id !== uid);
    const profiles = others.length === 0
      ? []
      : await db().getAll(...others.map((id) => db().doc(`users/${id}`)));
    if (profiles.some((snap) => !snap.exists)) {
      throw new HttpsError("not-found", "Alguém da lista não está mais no Clippo.", {
        field: "participantIds",
      });
    }

    const sessionRef = db().doc(`sessions/${sessionId}`);
    const existing = await sessionRef.get();
    // No reenvio, os participantes já foram conferidos na primeira vez (e o dono pode ter
    // desfeito uma amizade depois): a lista gravada vale, e a do pedido é ignorada.
    if (!existing.exists && !(await areFriendsWithAll(uid, others))) {
      throw new HttpsError("failed-precondition", "Só dá para gravar com os seus amigos.", {
        field: "participantIds",
      });
    }

    // Avatares que a Início mostra sem abrir a sessão. O dono vem primeiro.
    const ownerSnap = await db().doc(`users/${uid}`).get();
    const preview = [previewEntry(ownerSnap), ...profiles.map(previewEntry)].slice(0, PREVIEW_MAX);

    // 4. Grava tudo de uma vez.
    const created = await db().runTransaction(async (tx) => {
      // Todas as leituras da transação precisam vir antes de qualquer escrita.
      const snap = await tx.get(sessionRef);
      const existingHighlightSnaps = highlights.length === 0
        ? []
        : await tx.getAll(...highlights.map((h) => sessionRef.collection("highlights").doc(h.highlightId)));

      const now = FieldValue.serverTimestamp();

      if (snap.exists) {
        // Idempotente: a mesma sessão chegando de novo (o app repetiu o envio).
        if (snap.get("ownerId") !== uid) {
          throw new HttpsError("permission-denied", "Essa sessão é de outra pessoa.");
        }

        const missing = highlights.filter((_, index) => !existingHighlightSnaps[index]?.exists);
        if (missing.length === 0) return false;

        // Juntada a outra (D18)? Os lances novos vão também para a principal.
        const rootId = mergedIntoOf(snap);
        const rootRef = rootId ? db().doc(`sessions/${rootId}`) : null;
        const rootSnap = rootRef ? await tx.get(rootRef) : null;
        const rootHighlightSnaps = rootRef
          ? await tx.getAll(...missing.map((h) => rootRef.collection("highlights").doc(h.highlightId)))
          : [];
        const savedParticipants = participantIdsOf(rootSnap?.exists ? rootSnap : snap);
        const userSnaps = await tx.getAll(...savedParticipants.map((id) => db().doc(`users/${id}`)));

        const sessionStart = toDate(snap.get("startedAt"));
        for (const highlight of missing) {
          const savedAt = new Date(sessionStart.getTime() + highlight.offsetSeconds * 1000);
          tx.set(
            sessionRef.collection("highlights").doc(highlight.highlightId),
            highlightDoc(sessionId, highlight, savedAt, highlight.offsetSeconds, uid, null),
          );
        }
        tx.update(sessionRef, {
          highlightCount: FieldValue.increment(missing.length),
          updatedAt: now,
        });

        if (rootRef && rootSnap?.exists) {
          const rootStart = toDate(rootSnap.get("startedAt"));
          let copied = 0;
          missing.forEach((highlight, index) => {
            if (rootHighlightSnaps[index]?.exists) return;
            const savedAt = new Date(sessionStart.getTime() + highlight.offsetSeconds * 1000);
            const offset = Math.max(0, Math.round((savedAt.getTime() - rootStart.getTime()) / 1000));
            tx.set(
              rootRef.collection("highlights").doc(highlight.highlightId),
              highlightDoc(rootRef.id, highlight, savedAt, offset, uid, sessionId),
            );
            copied++;
          });
          if (copied > 0) {
            tx.update(rootRef, { highlightCount: FieldValue.increment(copied), updatedAt: now });
          }
        }

        for (const userSnap of userSnaps) {
          if (userSnap.exists) {
            tx.update(userSnap.ref, { "stats.highlights": FieldValue.increment(missing.length) });
          }
        }
        return false;
      }

      const userSnaps = await tx.getAll(...participantIds.map((id) => db().doc(`users/${id}`)));

      tx.set(sessionRef, {
        name,
        ownerId: uid,
        participantIds,
        participantsPreview: preview,
        participantCount: participantIds.length,
        startedAt: period.startedAt,
        endedAt: period.endedAt,
        durationSeconds: period.durationSeconds,
        location: location === null ? null : { label: location },
        highlightCount: highlights.length,
        mergedInto: null,
        mergedFrom: [],
        createdAt: now,
        updatedAt: now,
      });

      for (const highlight of highlights) {
        const savedAt = new Date(period.startedAt.getTime() + highlight.offsetSeconds * 1000);
        tx.set(
          sessionRef.collection("highlights").doc(highlight.highlightId),
          highlightDoc(sessionId, highlight, savedAt, highlight.offsetSeconds, uid, null),
        );
      }

      // Atualiza os contadores de perfil (sessões e highlights) de cada participante.
      for (const userSnap of userSnaps) {
        if (!userSnap.exists) continue;
        const updates: Record<string, unknown> = {
          "stats.sessions": FieldValue.increment(1),
        };
        if (highlights.length > 0) {
          updates["stats.highlights"] = FieldValue.increment(highlights.length);
        }
        tx.update(userSnap.ref, updates);
      }

      return true;
    });

    // 5. Devolve onde cada vídeo deve ser enviado.
    const videoPaths: Record<string, string> = {};
    for (const highlight of highlights) {
      videoPaths[highlight.highlightId] = highlightVideoPath(sessionId, highlight.highlightId);
    }
    return { sessionId, videoPaths, created };
  },
);
