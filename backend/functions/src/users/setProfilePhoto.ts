/**
 * setProfilePhoto — função CHAMÁVEL: a pessoa troca ou tira a foto do perfil (12/11/2026).
 *
 * O app envia a imagem para `users/{uid}/avatar` no Storage (storage.rules: só a própria pessoa,
 * JPEG ou PNG de até 2 MB) e depois chama esta função, que:
 *   1. confere quem chamou e se o perfil existe;
 *   2. confere de novo a foto no Storage (tipo e tamanho, `checkProfilePhoto`); foto fora da
 *      regra é apagada e o pedido recusado;
 *   3. grava `photoUrl` em users/{uid} e nas cópias (amizades e os 5 avatares das sessões),
 *      do mesmo jeito que o updateProfile faz com o nome;
 *   4. `{ remove: true }`: apaga a foto e grava `photoUrl: null`.
 *
 * A URL usa o token de download do Storage: quem tem o link vê a foto. Para foto de perfil,
 * que aparece para todo mundo logado, é aceito (os vídeos continuam sem link, D17). O `v` no fim
 * muda a cada envio, para o celular não mostrar a foto antiga guardada.
 *
 * Idempotente: chamar de novo com a mesma foto regrava o mesmo endereço.
 */
import { randomUUID } from "node:crypto";

import { FieldPath, FieldValue, type DocumentReference } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { bucket, db } from "../shared/admin";
import { ValidationError, checkProfilePhoto, normalizeProfilePhotoRequest } from "./validation";

const BATCH_SIZE = 400;

export const setProfilePhoto = onCall<{ remove?: boolean }, Promise<{ photoUrl: string | null }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para trocar a foto.");
    }

    let remove: boolean;
    try {
      ({ remove } = normalizeProfilePhotoRequest(request.data));
    } catch (e) {
      if (e instanceof ValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const userRef = db().doc(`users/${uid}`);
    if (!(await userRef.get()).exists) {
      throw new HttpsError("failed-precondition", "Complete seu perfil antes de trocar a foto.");
    }

    const file = bucket().file(`users/${uid}/avatar`);
    let photoUrl: string | null = null;
    if (remove) {
      await file.delete({ ignoreNotFound: true });
    } else {
      const [exists] = await file.exists();
      if (!exists) {
        throw new HttpsError("failed-precondition", "A foto não chegou. Tente de novo.", { field: "photo" });
      }
      const [meta] = await file.getMetadata();
      try {
        checkProfilePhoto(Number(meta.size), meta.contentType);
      } catch (e) {
        if (e instanceof ValidationError) {
          await file.delete({ ignoreNotFound: true });
          throw new HttpsError("invalid-argument", e.message, { field: e.field });
        }
        throw e;
      }
      let token = String(meta.metadata?.firebaseStorageDownloadTokens ?? "").split(",")[0];
      if (!token) {
        token = randomUUID();
        await file.setMetadata({ metadata: { firebaseStorageDownloadTokens: token } });
      }
      photoUrl = downloadUrl(file.bucket.name, file.name, token, String(meta.generation ?? ""));
    }

    await userRef.update({ photoUrl, updatedAt: FieldValue.serverTimestamp() });
    await updatePhotoCopies(uid, photoUrl);
    return { photoUrl };
  },
);

/** O endereço que o app abre com NetworkImage. No Emulator, aponta para o Storage dele. */
export function downloadUrl(bucketName: string, path: string, token: string, version: string): string {
  const emulator = process.env.FIREBASE_STORAGE_EMULATOR_HOST;
  const base = emulator
    ? `http://${emulator.replace(/^https?:\/\//, "")}`
    : "https://firebasestorage.googleapis.com";
  const v = version ? `&v=${encodeURIComponent(version)}` : "";
  return `${base}/v0/b/${bucketName}/o/${encodeURIComponent(path)}?alt=media&token=${encodeURIComponent(token)}${v}`;
}

/** Regrava a foto nas cópias de amizades e sessões. Só escreve onde está diferente. */
async function updatePhotoCopies(uid: string, photoUrl: string | null): Promise<void> {
  const writes: Array<{ ref: DocumentReference; data: [FieldPath, unknown] | Record<string, unknown> }> = [];

  const friendships = await db().collection("friendships").where("uids", "array-contains", uid).get();
  for (const doc of friendships.docs) {
    const copy = doc.get(new FieldPath("profiles", uid)) as { photoUrl?: string | null } | undefined;
    if ((copy?.photoUrl ?? null) === photoUrl) continue;
    writes.push({ ref: doc.ref, data: [new FieldPath("profiles", uid), { ...copy, photoUrl }] });
  }

  const sessions = await db().collection("sessions").where("participantIds", "array-contains", uid).get();
  for (const doc of sessions.docs) {
    const preview = doc.get("participantsPreview");
    if (!Array.isArray(preview)) continue;
    let changed = false;
    const next = preview.map((entry) => {
      if (entry && typeof entry === "object" && entry.uid === uid && (entry.photoUrl ?? null) !== photoUrl) {
        changed = true;
        return { ...entry, photoUrl };
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
