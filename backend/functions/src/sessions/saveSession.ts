/**
 * saveSession — função CHAMÁVEL, acionada pelo "Salvar sessão" (produto.md › 4.5, estado D).
 *
 * Decisão D15: sessões e highlights são gravados **só** por aqui; as Security Rules
 * continuam fechadas para escrita. A gravação em si não depende desta função (R8): o
 * gesto salva o MP4 na pasta interna do app, e sem internet o app guarda a sessão e
 * tenta de novo sozinho (WorkManager). Por isso ela é **idempotente**: o id da sessão e
 * o de cada highlight nascem no aparelho, e chamar duas vezes não duplica nada.
 *
 * O que grava, numa transação (ou tudo, ou nada):
 *   sessions/{sessionId}                      → a sessão e seus participantes
 *   sessions/{sessionId}/highlights/{id}      → um documento por lance, `status: pending`
 *
 * O vídeo NÃO passa por aqui: ele sobe do app direto para o Storage, e um gatilho marca
 * o highlight como `uploaded` (R13).
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { db } from "../shared/admin";
import {
  SessionValidationError,
  normalizeHighlights,
  normalizeId,
  normalizeLocation,
  normalizeParticipantIds,
  normalizePeriod,
  normalizeSessionName,
  participantsAreFriends,
} from "./validation";

/** Até onde a lista da Início mostra avatares sem abrir a sessão (produto.md › 4.2). */
const PREVIEW_MAX = 5;

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
  /** false quando a sessão já existia: a chamada repetiu e nada foi gravado de novo. */
  created: boolean;
}

/** Caminho combinado do vídeo e da miniatura de um lance. */
export function highlightVideoPath(sessionId: string, highlightId: string): string {
  return `sessions/${sessionId}/highlights/${highlightId}/video.mp4`;
}

export function highlightThumbnailPath(sessionId: string, highlightId: string): string {
  return `sessions/${sessionId}/highlights/${highlightId}/thumb.jpg`;
}

export const saveSession = onCall<SaveSessionRequest, Promise<SaveSessionResponse>>(
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

    // 3. Os participantes existem? (e, quando Friendship existir, são amigos do dono — R10)
    const others = participantIds.filter((id) => id !== uid);
    const profiles = others.length === 0
      ? []
      : await db().getAll(...others.map((id) => db().doc(`users/${id}`)));
    if (profiles.some((snap) => !snap.exists)) {
      throw new HttpsError("not-found", "Alguém da lista não está mais no Clippo.", {
        field: "participantIds",
      });
    }
    if (!(await participantsAreFriends(uid, others))) {
      throw new HttpsError("failed-precondition", "Só dá para gravar com os seus amigos.", {
        field: "participantIds",
      });
    }

    // Avatares que a Início mostra sem abrir a sessão. O dono vem primeiro.
    const ownerSnap = await db().doc(`users/${uid}`).get();
    const preview = [
      { uid, name: (ownerSnap.get("name") as string) ?? "", photoUrl: ownerSnap.get("photoUrl") ?? null },
      ...profiles.map((snap) => ({
        uid: snap.id,
        name: (snap.get("name") as string) ?? "",
        photoUrl: snap.get("photoUrl") ?? null,
      })),
    ].slice(0, PREVIEW_MAX);

    // 4. Grava tudo de uma vez.
    const sessionRef = db().doc(`sessions/${sessionId}`);
    const created = await db().runTransaction(async (tx) => {
      const snap = await tx.get(sessionRef);
      if (snap.exists) {
        // Idempotente: a mesma sessão chegando de novo (o app repetiu o envio).
        if (snap.get("ownerId") !== uid) {
          throw new HttpsError("permission-denied", "Essa sessão é de outra pessoa.");
        }
        return false;
      }

      const now = FieldValue.serverTimestamp();
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
        createdAt: now,
        updatedAt: now,
      });

      for (const highlight of highlights) {
        tx.set(sessionRef.collection("highlights").doc(highlight.highlightId), {
          title: highlight.title,
          offsetSeconds: highlight.offsetSeconds,
          durationSeconds: highlight.durationSeconds,
          savedAt: new Date(period.startedAt.getTime() + highlight.offsetSeconds * 1000),
          createdBy: uid,
          videoPath: highlightVideoPath(sessionId, highlight.highlightId),
          thumbnailPath: highlightThumbnailPath(sessionId, highlight.highlightId),
          // O vídeo ainda está só no aparelho; o gatilho do Storage marca "uploaded" (R13).
          status: "pending",
          createdAt: now,
          updatedAt: now,
        });
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
