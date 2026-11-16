/**
 * Pedaços dos favoritos usados por mais de uma Function (favoritar, desfavoritar, curtir,
 * comentar, os gatilhos e o deleteMyAccount). Precisam do banco, então não ficam em validation.ts.
 *
 * Um favorito é o documento `posts/{uid}__{sessionId}__{highlightId}`, com curtidas em
 * `likes/{uid}` e comentários em `comments/{id}`, e a cópia própria do vídeo e da miniatura em
 * `posts/{id}/` no Storage (D19).
 */
import { FieldValue, type DocumentSnapshot, type Transaction } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";

import { bucket, db } from "../shared/admin";

export const postRef = (postId: string) => db().doc(`posts/${postId}`);

export function postVideoPath(postId: string): string {
  return `posts/${postId}/video.mp4`;
}

export function postThumbnailPath(postId: string): string {
  return `posts/${postId}/thumb.jpg`;
}

/** O id da amizade (D16): os dois uids em ordem, separados por "_". */
export function friendshipId(a: string, b: string): string {
  return a < b ? `${a}_${b}` : `${b}_${a}`;
}

/** Quem favoritou e os amigos dele veem o favorito (R19). */
export async function canSeePost(tx: Transaction, viewer: string, ownerId: string): Promise<boolean> {
  if (viewer === ownerId) return true;
  const friendship = await tx.get(db().doc(`friendships/${friendshipId(viewer, ownerId)}`));
  return friendship.exists && friendship.get("status") === "accepted";
}

/** Nome, @ e foto de quem favoritou ou comentou, copiados no documento (o Firestore não tem JOIN). */
export function profileCopy(user: DocumentSnapshot) {
  return {
    name: (user.get("name") as string | undefined) ?? "",
    username: (user.get("username") as string | undefined) ?? "",
    photoUrl: (user.get("photoUrl") as string | null | undefined) ?? null,
  };
}

/**
 * Apaga o favorito, com as curtidas, os comentários e a cópia do vídeo (R21). Desconta 1 do
 * `favoriteCount` do lance, se ele ainda existe. Seguro repetir: favorito que já não existe não
 * é erro. Devolve se apagou.
 */
export async function deletePost(postId: string): Promise<boolean> {
  const ref = postRef(postId);
  const deleted = await db().runTransaction(async (tx) => {
    const post = await tx.get(ref);
    if (!post.exists) return false;
    const sessionId = post.get("sessionId") as string | undefined;
    const highlightId = post.get("highlightId") as string | undefined;
    if (sessionId && highlightId) {
      const highlightRef = db().doc(`sessions/${sessionId}/highlights/${highlightId}`);
      const highlight = await tx.get(highlightRef);
      if (highlight.exists) tx.update(highlightRef, { favoriteCount: FieldValue.increment(-1) });
    }
    tx.delete(ref);
    return true;
  });

  // Curtidas e comentários (subcoleções) e a cópia do vídeo. Rodam mesmo se o documento já tinha
  // sumido: uma chamada anterior pode ter caído no meio.
  await db().recursiveDelete(ref);
  for (const path of [postVideoPath(postId), postThumbnailPath(postId)]) {
    try {
      await bucket().file(path).delete({ ignoreNotFound: true });
    } catch (e) {
      logger.error("deletePost: o favorito saiu do banco, mas o arquivo ficou no Storage", { path, error: String(e) });
    }
  }
  return deleted;
}

/** Apaga todos os favoritos de [sessionId]/[highlightId] (o lance foi apagado, R21). */
export async function deletePostsOfHighlight(sessionId: string, highlightId: string): Promise<number> {
  const posts = await db()
    .collection("posts")
    .where("sessionId", "==", sessionId)
    .where("highlightId", "==", highlightId)
    .get();
  for (const post of posts.docs) await deletePost(post.id);
  return posts.size;
}

/** Apaga os favoritos de [uids] feitos em lances de [sessionId] (saíram da sessão, R21). */
export async function deletePostsOfLeavers(sessionId: string, uids: string[]): Promise<number> {
  if (uids.length === 0) return 0;
  const leavers = new Set(uids);
  const posts = await db().collection("posts").where("sessionId", "==", sessionId).get();
  const mine = posts.docs.filter((p) => leavers.has(p.get("ownerId") as string));
  for (const post of mine) await deletePost(post.id);
  return mine.length;
}

/**
 * Excluir a conta (R21): os favoritos da pessoa, e as curtidas e os comentários que ela deixou
 * nos favoritos dos outros, descontando os contadores.
 */
export async function deleteFavoritesActivityOf(uid: string): Promise<void> {
  const posts = await db().collection("posts").where("ownerId", "==", uid).get();
  for (const post of posts.docs) await deletePost(post.id);

  const likes = await db().collectionGroup("likes").where("uid", "==", uid).get();
  const comments = await db().collectionGroup("comments").where("authorId", "==", uid).get();
  for (const [snaps, counter] of [
    [likes.docs, "likeCount"],
    [comments.docs, "commentCount"],
  ] as const) {
    for (const snap of snaps) {
      const parent = snap.ref.parent.parent;
      if (!parent || parent.parent.id !== "posts") continue;
      await db().runTransaction(async (tx) => {
        const [item, post] = await tx.getAll(snap.ref, parent);
        if (!item.exists) return;
        if (post.exists) tx.update(parent, { [counter]: FieldValue.increment(-1) });
        tx.delete(snap.ref);
      });
    }
  }
}
