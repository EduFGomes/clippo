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

import { STORAGE_REGION } from "../config";
import { bucket, db } from "../shared/admin";
import { parseHighlightVideoPath, validateUploadedVideo } from "./validation";

// Gatilho do Storage: roda na região do bucket, não na das outras funções (config.ts).
export const onVideoUploaded = onObjectFinalized({ region: STORAGE_REGION }, async (event) => {
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

  const sessionRef = db().doc(`sessions/${location.sessionId}`);

  await db().runTransaction(async (tx) => {
    const [snap, sessionSnap] = await tx.getAll(highlightRef, sessionRef);
    if (!snap.exists) return;

    // Sessão juntada a outra (D18): o lance também existe, copiado, na principal.
    const rootId = sessionSnap.get("mergedInto") as string | null | undefined;
    const copyRef = rootId
      ? db().doc(`sessions/${rootId}/highlights/${location.highlightId}`)
      : null;
    const copySnap = copyRef ? await tx.get(copyRef) : null;
    const refs = [
      { ref: highlightRef, status: snap.get("status") as string | undefined },
      ...(copyRef && copySnap?.exists
        ? [{ ref: copyRef, status: copySnap.get("status") as string | undefined }]
        : []),
    ];

    const next = check.valid ? "uploaded" : "failed";
    for (const { ref, status } of refs) {
      // Idempotente: o evento já foi processado antes (ou um envio válido já chegou).
      if (status === "uploaded" || status === next) continue;
      tx.update(ref, { status: next, updatedAt: FieldValue.serverTimestamp() });
    }
  });

  if (!check.valid && objectName) {
    await bucket().file(objectName).delete({ ignoreNotFound: true });
  }
});
