/**
 * updateSession — função CHAMÁVEL: o dono edita a sessão depois de salva (R12).
 *
 * Campos opcionais: só muda o que vier no pedido.
 *   - name, location: mesmas regras do saveSession;
 *   - participantIds: a lista inteira, nova. Quem ENTRA precisa ser amigo do dono (R10);
 *     quem sai perde o acesso à sessão e aos vídeos na hora (R11). O dono não sai.
 *
 * Mantém em dia, na mesma transação: avatares da Início, contadores do perfil de quem
 * entrou ou saiu e a lista de participantes das sessões juntadas a esta (D18), que é o
 * que as regras do Storage conferem para liberar os vídeos delas.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { areFriendsWithAll } from "../friends/friendships";
import { db } from "../shared/admin";
import { mergedFromOf, mergedIntoOf, participantIdsOf, readPreview } from "./sessionDocs";
import {
  SessionValidationError,
  normalizeId,
  normalizeLocation,
  normalizeParticipantIds,
  normalizeSessionName,
  participantChanges,
} from "./validation";

export interface UpdateSessionRequest {
  sessionId: string;
  name?: string;
  location?: string | null;
  participantIds?: string[];
}

export const updateSession = onCall<UpdateSessionRequest, Promise<{ sessionId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para editar a sessão.");
    }

    const data = request.data ?? ({} as UpdateSessionRequest);
    let sessionId: string;
    let name: string | undefined;
    let location: string | null | undefined;
    let participantIds: string[] | undefined;
    try {
      sessionId = normalizeId(data.sessionId, "sessionId");
      if (data.name !== undefined) name = normalizeSessionName(data.name);
      if (data.location !== undefined) location = normalizeLocation(data.location);
      if (data.participantIds !== undefined) {
        participantIds = normalizeParticipantIds(data.participantIds, uid);
      }
    } catch (e) {
      if (e instanceof SessionValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const sessionRef = db().doc(`sessions/${sessionId}`);

    // R10 para quem entra: conferido antes da transação (amizade não muda a cada segundo).
    if (participantIds) {
      const before = await sessionRef.get();
      if (before.exists && before.get("ownerId") === uid) {
        const { added } = participantChanges(participantIdsOf(before), participantIds);
        if (added.length > 0) {
          const profiles = await db().getAll(...added.map((id) => db().doc(`users/${id}`)));
          if (profiles.some((snap) => !snap.exists)) {
            throw new HttpsError("not-found", "Alguém da lista não está mais no Clippo.", {
              field: "participantIds",
            });
          }
          if (!(await areFriendsWithAll(uid, added))) {
            throw new HttpsError("failed-precondition", "Só dá para adicionar os seus amigos.", {
              field: "participantIds",
            });
          }
        }
      }
    }

    await db().runTransaction(async (tx) => {
      const snap = await tx.get(sessionRef);
      if (!snap.exists) {
        throw new HttpsError("not-found", "Essa sessão não existe mais.");
      }
      if (snap.get("ownerId") !== uid) {
        throw new HttpsError("permission-denied", "Só quem gravou a sessão pode editar.");
      }
      if (mergedIntoOf(snap)) {
        throw new HttpsError("failed-precondition", "Essa sessão foi juntada a outra. Edite a principal.");
      }

      const now = FieldValue.serverTimestamp();
      const updates: Record<string, unknown> = { updatedAt: now };
      if (name !== undefined) updates.name = name;
      if (location !== undefined) updates.location = location === null ? null : { label: location };

      if (participantIds) {
        const before = participantIdsOf(snap);
        const { added, removed } = participantChanges(before, participantIds);
        if (added.length > 0 || removed.length > 0) {
          const highlightCount = (snap.get("highlightCount") as number | undefined) ?? 0;
          const mergedFrom = mergedFromOf(snap);

          // Leituras primeiro.
          const preview = await readPreview(tx, participantIds);
          const changed = [...added, ...removed];
          const userSnaps = await tx.getAll(...changed.map((id) => db().doc(`users/${id}`)));

          updates.participantIds = participantIds;
          updates.participantCount = participantIds.length;
          updates.participantsPreview = preview;

          for (const userSnap of userSnaps) {
            if (!userSnap.exists) continue;
            const sign = added.includes(userSnap.id) ? 1 : -1;
            tx.update(userSnap.ref, {
              "stats.sessions": FieldValue.increment(sign),
              "stats.highlights": FieldValue.increment(sign * highlightCount),
            });
          }
          // As sessões juntadas a esta seguem a mesma lista (D18).
          for (const fromId of mergedFrom) {
            tx.update(db().doc(`sessions/${fromId}`), { participantIds, updatedAt: now });
          }
        }
      }

      tx.update(sessionRef, updates);
    });

    return { sessionId };
  },
);
