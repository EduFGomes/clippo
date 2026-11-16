/**
 * likePost — função CHAMÁVEL: curtir ou descurtir um favorito (R19). Quem vê o favorito (quem
 * favoritou e os amigos dele) curte.
 *
 * Padrão de users/completeProfile.ts: quem chamou, valida antes, transação (curtida e
 * `likeCount` juntos), idempotente (curtir duas vezes conta uma: a curtida é `likes/{uid}`),
 * erros em português.
 */
import { FieldValue } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

import { CALLABLE_OPTIONS } from "../config";
import { db } from "../shared/admin";
import { canSeePost, postRef } from "./posts";
import { FavoriteValidationError, normalizeLiked, normalizePostId } from "./validation";

export const likePost = onCall<
  { postId: string; liked: boolean },
  Promise<{ liked: boolean; likeCount: number }>
>(CALLABLE_OPTIONS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Entre na sua conta para curtir.");
  }

  let postId: string;
  let liked: boolean;
  try {
    postId = normalizePostId(request.data?.postId);
    liked = normalizeLiked(request.data?.liked);
  } catch (e) {
    if (e instanceof FavoriteValidationError) {
      throw new HttpsError("invalid-argument", e.message, { field: e.field });
    }
    throw e;
  }

  const ref = postRef(postId);
  const likeRef = ref.collection("likes").doc(uid);
  return db().runTransaction(async (tx) => {
    const [post, like] = await tx.getAll(ref, likeRef);
    if (!post.exists) {
      throw new HttpsError("not-found", "Esse favorito não existe mais.");
    }
    if (!(await canSeePost(tx, uid, post.get("ownerId") as string))) {
      throw new HttpsError("permission-denied", "Só os amigos de quem favoritou veem esse lance.");
    }
    const current = (post.get("likeCount") as number | undefined) ?? 0;
    if (liked === like.exists) return { liked, likeCount: current };
    if (liked) {
      tx.set(likeRef, { uid, createdAt: FieldValue.serverTimestamp() });
    } else {
      tx.delete(likeRef);
    }
    tx.update(ref, { likeCount: FieldValue.increment(liked ? 1 : -1) });
    return { liked, likeCount: Math.max(0, current + (liked ? 1 : -1)) };
  });
});
