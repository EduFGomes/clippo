/**
 * addComment e deleteComment — funções CHAMÁVEIS dos comentários de um favorito (R19, R22).
 *
 * Padrão de users/completeProfile.ts: (1) quem chamou, (2) valida o texto antes de tocar no banco
 * (favorites/validation.ts, espelhado no app), (3) comentário e `commentCount` numa transação,
 * (4) idempotente (o id do comentário vem do app: repetir a chamada não duplica; apagar o que já
 * sumiu não é erro), (5) erros em português prontos para a tela.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { canSeePost, postRef, profileCopy } from "./posts";
import {
  FavoriteValidationError,
  normalizeComment,
  normalizeCommentId,
  normalizePostId,
} from "./validation";

function invalid(e: unknown): never {
  if (e instanceof FavoriteValidationError) {
    throw new HttpsError("invalid-argument", e.message, { field: e.field });
  }
  throw e;
}

export const addComment = onCall<
  { postId: string; commentId: string; text: string },
  Promise<{ commentId: string }>
>(CALLABLE_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Entre na sua conta para comentar.");
  }

  let postId: string;
  let commentId: string;
  let text: string;
  try {
    postId = normalizePostId(request.data?.postId);
    commentId = normalizeCommentId(request.data?.commentId);
    text = normalizeComment(request.data?.text);
  } catch (e) {
    invalid(e);
  }

  const ref = postRef(postId);
  const commentRef = ref.collection("comments").doc(commentId);
  await db().runTransaction(async (tx) => {
    const [post, comment, me] = await tx.getAll(ref, commentRef, db().doc(`users/${uid}`));
    if (!post.exists) {
      throw new HttpsError("not-found", "Esse favorito não existe mais.");
    }
    if (!(await canSeePost(tx, uid, post.get("ownerId") as string))) {
      throw new HttpsError("permission-denied", "Só os amigos de quem favoritou veem esse lance.");
    }
    if (comment.exists) return; // a mesma chamada de novo
    if (!me.exists) {
      throw new HttpsError("failed-precondition", "Complete seu perfil antes de comentar.");
    }
    tx.set(commentRef, {
      authorId: uid,
      author: profileCopy(me),
      text,
      createdAt: FieldValue.serverTimestamp(),
    });
    tx.update(ref, { commentCount: FieldValue.increment(1) });
  });

  return { commentId };
});

export const deleteComment = onCall<{ postId: string; commentId: string }, Promise<{ commentId: string }>>(
  CALLABLE_OPTIONS,
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Entre na sua conta para apagar o comentário.");
    }

    let postId: string;
    let commentId: string;
    try {
      postId = normalizePostId(request.data?.postId);
      commentId = normalizeCommentId(request.data?.commentId);
    } catch (e) {
      invalid(e);
    }

    const ref = postRef(postId);
    const commentRef = ref.collection("comments").doc(commentId);
    await db().runTransaction(async (tx) => {
      const [post, comment] = await tx.getAll(ref, commentRef);
      if (!post.exists || !comment.exists) return;
      // R22: o autor apaga o seu; quem favoritou apaga qualquer comentário do favorito.
      if (comment.get("authorId") !== uid && post.get("ownerId") !== uid) {
        throw new HttpsError("permission-denied", "Só quem escreveu ou quem favoritou apaga o comentário.");
      }
      tx.delete(commentRef);
      tx.update(ref, { commentCount: FieldValue.increment(-1) });
    });

    return { commentId };
  },
);
