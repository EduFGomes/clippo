/**
 * updateProfile — função CHAMÁVEL: a pessoa muda o nome e/ou o @usuário na tela Perfil.
 *
 * Mesmo padrão do completeProfile:
 *   1. quem chamou? (precisa estar logado e já ter perfil)
 *   2. valida com as mesmas regras do cadastro (normalizeProfileUpdate → normalizeName/normalizeUsername)
 *   3. numa transação: troca o @ (libera usernames/{antigo}, reserva usernames/{novo}) e grava users/{uid}
 *   4. idempotente: pedir de novo o mesmo nome/@ não é erro e não muda nada
 *
 * Depois da transação, atualiza as CÓPIAS do perfil (D16, e o porquê de participantsPreview em
 * docs/arquitetura.md):
 *   - friendships/{par}.profiles.{uid}  → nome e @ (amizades aceitas e pedidos pendentes)
 *   - sessions/{id}.participantsPreview → nome (só onde a pessoa aparece entre os 5 avatares)
 *
 * Por que fora da transação: uma transação do Firestore tem limite de documentos e trava tudo o que
 * lê; com até 500 amigos e muitas sessões, não cabe. Se a cópia falhar no meio, o perfil já está
 * certo e chamar de novo termina o serviço (só regrava o que ainda está diferente).
 *
 * Custo por chamada: 3 a 4 leituras na transação + 1 leitura por amizade/pedido da pessoa + 1 leitura
 * por sessão em que ela participa; escreve só os documentos cuja cópia mudou (em lotes de 400).
 * Ex.: 50 amigos e 100 sessões ≈ 154 leituras e até 150 escritas — raro (a pessoa muda o nome
 * poucas vezes) e dentro da cota gratuita diária (50 mil leituras, 20 mil escritas).
 */
import { FieldPath, FieldValue, type DocumentReference } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { ValidationError, normalizeProfileUpdate, type ProfileUpdate } from "./validation";

export interface UpdateProfileRequest {
  name?: string | null;
  username?: string | null;
}

export interface UpdateProfileResponse {
  name: string;
  username: string;
}

/** Abaixo do limite de 500 escritas por lote do Firestore, com folga. */
const BATCH_SIZE = 400;

export const updateProfile = onCall<UpdateProfileRequest, Promise<UpdateProfileResponse>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para continuar.");
    }

    let update: ProfileUpdate;
    try {
      update = normalizeProfileUpdate(request.data);
    } catch (e) {
      if (e instanceof ValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const userRef = db().doc(`users/${uid}`);

    const result = await db().runTransaction(async (tx) => {
      const userSnap = await tx.get(userRef);
      if (!userSnap.exists) {
        throw new HttpsError("failed-precondition", "Complete seu perfil antes de editar.");
      }
      const currentName = (userSnap.get("name") as string | undefined) ?? "";
      const currentUsername = (userSnap.get("username") as string | undefined) ?? "";
      const name = update.name ?? currentName;
      const username = update.username ?? currentUsername;

      const usernameChanged = username !== currentUsername;
      const oldUsernameRef = currentUsername ? db().doc(`usernames/${currentUsername}`) : null;
      const newUsernameRef = db().doc(`usernames/${username}`);

      // Todas as leituras antes de qualquer escrita (exigência da transação).
      let oldUsernameSnap = null;
      if (usernameChanged) {
        const [newSnap, oldSnap] = await Promise.all([
          tx.get(newUsernameRef),
          oldUsernameRef ? tx.get(oldUsernameRef) : Promise.resolve(null),
        ]);
        if (newSnap.exists && newSnap.get("uid") !== uid) {
          throw new HttpsError("already-exists", "Esse nome de usuário já está em uso.", {
            field: "username",
          });
        }
        oldUsernameSnap = oldSnap;
      }

      if (!usernameChanged && name === currentName) {
        return { name, username }; // idempotente: nada mudou
      }

      const now = FieldValue.serverTimestamp();
      if (usernameChanged) {
        // Só libera o @ antigo se ele for mesmo desta pessoa.
        if (oldUsernameRef && oldUsernameSnap?.exists && oldUsernameSnap.get("uid") === uid) {
          tx.delete(oldUsernameRef);
        }
        tx.set(newUsernameRef, { uid, createdAt: now });
      }
      tx.update(userRef, { name, username, updatedAt: now });
      return { name, username };
    });

    // Sempre roda (mesmo quando nada mudou agora): termina uma cópia que falhou numa chamada anterior.
    await updateCopies(uid, result.name, result.username);

    return result;
  },
);

/** Regrava nome/@ nas cópias de amizades e sessões. Só escreve onde está diferente. */
async function updateCopies(uid: string, name: string, username: string): Promise<void> {
  const writes: Array<{ ref: DocumentReference; data: [FieldPath, unknown] | Record<string, unknown> }> = [];

  const friendships = await db().collection("friendships").where("uids", "array-contains", uid).get();
  for (const doc of friendships.docs) {
    const copy = doc.get(new FieldPath("profiles", uid)) as { name?: string; username?: string } | undefined;
    if (copy?.name === name && copy?.username === username) continue;
    writes.push({ ref: doc.ref, data: [new FieldPath("profiles", uid), { ...copy, name, username }] });
  }

  const sessions = await db().collection("sessions").where("participantIds", "array-contains", uid).get();
  for (const doc of sessions.docs) {
    const preview = doc.get("participantsPreview");
    if (!Array.isArray(preview)) continue;
    let changed = false;
    const next = preview.map((entry) => {
      if (entry && typeof entry === "object" && entry.uid === uid && entry.name !== name) {
        changed = true;
        return { ...entry, name };
      }
      return entry;
    });
    if (changed) writes.push({ ref: doc.ref, data: { participantsPreview: next } });
  }

  for (let i = 0; i < writes.length; i += BATCH_SIZE) {
    const batch = db().batch();
    for (const { ref, data } of writes.slice(i, i + BATCH_SIZE)) {
      if (Array.isArray(data)) batch.update(ref, data[0], data[1]);
      else batch.update(ref, data);
    }
    await batch.commit();
  }
}
