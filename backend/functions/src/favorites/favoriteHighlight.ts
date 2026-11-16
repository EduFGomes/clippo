/**
 * favoriteHighlight — função CHAMÁVEL: um participante favorita um lance (R18). O lance passa a
 * aparecer no perfil dele, para os amigos (R19), com a própria cópia do vídeo (D19).
 *
 * Segue o padrão de users/completeProfile.ts: (1) quem chamou, (2) valida os ids antes de tocar
 * no banco, (3) grava o favorito e soma 1 no `favoriteCount` do lance numa transação, (4)
 * idempotente (o id do favorito é `{uid}__{sessionId}__{highlightId}`: favoritar de novo não
 * duplica), (5) erros em português prontos para a tela.
 *
 * A cópia do vídeo é feita ANTES da transação: assim, quando o favorito aparece para os amigos,
 * o vídeo dele já está lá. Se a transação não gravar, a cópia é apagada.
 */
import { FieldValue, type DocumentSnapshot } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { HighlightValidationError, normalizeHighlightRef } from "../highlights/validation";
import { participantIdsOf } from "../sessions/sessionDocs";
import { bucket, db } from "../shared/admin";
import { postRef, postThumbnailPath, postVideoPath, profileCopy } from "./posts";
import { postIdFor } from "./validation";

export interface FavoriteHighlightRequest {
  sessionId: string;
  highlightId: string;
}

export interface FavoriteHighlightResponse {
  postId: string;
}

/** Recusa o que não pode ser favoritado, com a frase para a tela. */
function checkFavoritable(uid: string, session: DocumentSnapshot, highlight: DocumentSnapshot): void {
  if (!session.exists) {
    throw new HttpsError("not-found", "Essa sessão não existe mais.");
  }
  if (!participantIdsOf(session).includes(uid)) {
    throw new HttpsError("permission-denied", "Só quem participou da sessão favorita os lances.");
  }
  if (!highlight.exists) {
    throw new HttpsError("not-found", "Esse lance não existe mais.");
  }
  const videoPath = highlight.get("videoPath");
  if (highlight.get("status") !== "uploaded" || typeof videoPath !== "string" || videoPath.length === 0) {
    throw new HttpsError("failed-precondition", "Esse lance ainda está sendo enviado. Favorite depois que ele subir.");
  }
}

export const favoriteHighlight = onCall<FavoriteHighlightRequest, Promise<FavoriteHighlightResponse>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para favoritar o lance.");
    }

    let sessionId: string;
    let highlightId: string;
    try {
      sessionId = normalizeHighlightRef(request.data?.sessionId, "sessionId");
      highlightId = normalizeHighlightRef(request.data?.highlightId, "highlightId");
    } catch (e) {
      if (e instanceof HighlightValidationError) {
        throw new HttpsError("invalid-argument", e.message, { field: e.field });
      }
      throw e;
    }

    const postId = postIdFor(uid, sessionId, highlightId);
    const ref = postRef(postId);
    // Idempotente: já favoritado, não copia de novo.
    if ((await ref.get()).exists) return { postId };

    const sessionRef = db().doc(`sessions/${sessionId}`);
    const highlightRef = sessionRef.collection("highlights").doc(highlightId);
    const [session, highlight] = await db().getAll(sessionRef, highlightRef);
    checkFavoritable(uid, session, highlight);

    // A cópia própria do vídeo (D19). A miniatura é opcional: lances antigos não têm.
    const videoPath = postVideoPath(postId);
    try {
      await bucket().file(highlight.get("videoPath") as string).copy(bucket().file(videoPath));
    } catch (e) {
      logger.error("favoriteHighlight: não deu para copiar o vídeo", { postId, error: String(e) });
      throw new HttpsError("unavailable", "O vídeo desse lance não está disponível agora. Tente de novo.");
    }
    let thumbnailPath: string | null = null;
    const sourceThumb = highlight.get("thumbnailPath");
    if (typeof sourceThumb === "string" && sourceThumb.length > 0) {
      try {
        await bucket().file(sourceThumb).copy(bucket().file(postThumbnailPath(postId)));
        thumbnailPath = postThumbnailPath(postId);
      } catch {
        thumbnailPath = null; // sem miniatura, o card mostra o desenho de quadra
      }
    }

    try {
      await db().runTransaction(async (tx) => {
        const [sessionNow, highlightNow, post, me] = await tx.getAll(
          sessionRef,
          highlightRef,
          ref,
          db().doc(`users/${uid}`),
        );
        if (post.exists) return;
        checkFavoritable(uid, sessionNow, highlightNow);
        if (!me.exists) {
          throw new HttpsError("failed-precondition", "Complete seu perfil antes de favoritar.");
        }
        tx.set(ref, {
          ownerId: uid,
          owner: profileCopy(me),
          sessionId,
          highlightId,
          title: (highlightNow.get("title") as string | undefined) ?? "",
          durationSeconds: (highlightNow.get("durationSeconds") as number | undefined) ?? 0,
          playedAt: highlightNow.get("savedAt") ?? null,
          videoPath,
          thumbnailPath,
          likeCount: 0,
          commentCount: 0,
          createdAt: FieldValue.serverTimestamp(),
        });
        tx.update(highlightRef, { favoriteCount: FieldValue.increment(1) });
      });
    } catch (e) {
      // Não gravou (e ninguém gravou ao mesmo tempo): a cópia não serve para nada.
      if (!(await ref.get()).exists) {
        for (const path of [videoPath, postThumbnailPath(postId)]) {
          await bucket().file(path).delete({ ignoreNotFound: true }).catch(() => undefined);
        }
      }
      throw e;
    }

    return { postId };
  },
);
