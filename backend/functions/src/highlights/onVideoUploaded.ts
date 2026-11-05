/**
 * onVideoUploaded — função de GATILHO do Storage (R13, D15).
 *
 * Acionada quando um arquivo termina de subir no Storage. Se o caminho for
 * `sessions/{sessionId}/highlights/{highlightId}/video.mp4`, confere formato e
 * tamanho e muda o documento do highlight de `pending` para `uploaded` (ou `failed`
 * se o arquivo for inválido).
 *
 * Gatilhos do Storage podem disparar mais de uma vez para o mesmo upload
 * (docs/arquitetura.md › Criar uma Cloud Function, item 4): por isso a atualização
 * roda em transação e ignora se o highlight já estiver como `uploaded`.
 */
import { FieldValue } from "firebase-admin/firestore";
import { onObjectFinalized } from "firebase-functions/v2/storage";

import { bucket, db } from "../shared/admin";
import { parseHighlightVideoPath, validateUploadedVideo } from "./validation";

export const onVideoUploaded = onObjectFinalized(async (event) => {
  const objectName = event.data.name;
  const location = parseHighlightVideoPath(objectName);
  if (!location) return;

  const check = validateUploadedVideo({
    contentType: event.data.contentType,
    size: event.data.size,
  });

  const highlightRef = db().doc(
    `sessions/${location.sessionId}/highlights/${location.highlightId}`,
  );

  await db().runTransaction(async (tx) => {
    const snap = await tx.get(highlightRef);
    if (!snap.exists) return;

    const currentStatus = snap.get("status") as string | undefined;
    if (currentStatus === "uploaded") {
      // Idempotente: o evento já foi processado antes.
      return;
    }

    if (!check.valid) {
      if (currentStatus !== "failed") {
        tx.update(highlightRef, {
          status: "failed",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    tx.update(highlightRef, {
      status: "uploaded",
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

  if (!check.valid && objectName) {
    await bucket().file(objectName).delete({ ignoreNotFound: true });
  }
});
