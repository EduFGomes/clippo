/**
 * Leituras de amizade usadas por outros domínios (ex.: R10 no saveSession e no updateSession).
 */
import type { DocumentSnapshot } from "firebase-admin/firestore";

import { db } from "../shared/admin";
import { friendshipId } from "./validation";

export const friendshipRef = (a: string, b: string) =>
  db().doc(`friendships/${friendshipId(a, b)}`);

/** O pedaço do perfil copiado na amizade, para a lista de amigos não precisar ler `users/`. */
export function profileCopy(snap: DocumentSnapshot) {
  return {
    name: (snap.get("name") as string | undefined) ?? "",
    username: (snap.get("username") as string | undefined) ?? "",
    photoUrl: (snap.get("photoUrl") as string | null | undefined) ?? null,
  };
}

/**
 * R10: todos os [others] são amigos (amizade aceita) de [ownerId]?
 * Uma leitura por pessoa, todas de uma vez.
 */
export async function areFriendsWithAll(ownerId: string, others: string[]): Promise<boolean> {
  const unique = Array.from(new Set(others.filter((uid) => uid !== ownerId)));
  if (unique.length === 0) return true;
  const snaps = await db().getAll(...unique.map((uid) => friendshipRef(ownerId, uid)));
  return snaps.every((snap) => snap.exists && snap.get("status") === "accepted");
}
