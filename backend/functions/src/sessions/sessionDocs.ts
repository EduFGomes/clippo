/**
 * Pedaços da sessão usados por mais de uma Function (saveSession, updateSession,
 * leaveSession, acceptSessionMerge). Precisam do banco, então não ficam em validation.ts.
 */
import { Timestamp, type DocumentSnapshot, type Transaction } from "firebase-admin/firestore";

import { db } from "../shared/admin";

/** Até onde a lista da Início mostra avatares sem abrir a sessão (produto.md › 4.2). */
export const PREVIEW_MAX = 5;

export interface PreviewEntry {
  uid: string;
  name: string;
  photoUrl: string | null;
}

export function previewEntry(snap: DocumentSnapshot): PreviewEntry {
  return {
    uid: snap.id,
    name: (snap.get("name") as string | undefined) ?? "",
    photoUrl: (snap.get("photoUrl") as string | null | undefined) ?? null,
  };
}

/** Caminho combinado do vídeo e da miniatura de um lance (D17). */
export function highlightVideoPath(sessionId: string, highlightId: string): string {
  return `sessions/${sessionId}/highlights/${highlightId}/video.mp4`;
}

export function highlightThumbnailPath(sessionId: string, highlightId: string): string {
  return `sessions/${sessionId}/highlights/${highlightId}/thumb.jpg`;
}

/**
 * Os avatares da Início para [participantIds] (os primeiros PREVIEW_MAX, na ordem).
 * Lê os perfis dentro da transação; quem não existe mais fica de fora.
 */
export async function readPreview(tx: Transaction, participantIds: string[]): Promise<PreviewEntry[]> {
  const first = participantIds.slice(0, PREVIEW_MAX);
  if (first.length === 0) return [];
  const snaps = await tx.getAll(...first.map((uid) => db().doc(`users/${uid}`)));
  return snaps.filter((snap) => snap.exists).map(previewEntry);
}

/** Timestamp do Firestore (ou Date) para Date. */
export function toDate(raw: unknown): Date {
  if (raw instanceof Timestamp) return raw.toDate();
  if (raw instanceof Date) return raw;
  return new Date(Number.NaN);
}

/** A sessão foi juntada a outra (D18)? */
export function mergedIntoOf(snap: DocumentSnapshot): string | null {
  const value = snap.get("mergedInto");
  return typeof value === "string" && value.length > 0 ? value : null;
}

/** As sessões juntadas a esta (D18). */
export function mergedFromOf(snap: DocumentSnapshot): string[] {
  const value = snap.get("mergedFrom");
  return Array.isArray(value) ? value.filter((id): id is string => typeof id === "string") : [];
}

export function participantIdsOf(snap: DocumentSnapshot): string[] {
  const value = snap.get("participantIds");
  return Array.isArray(value) ? value.filter((id): id is string => typeof id === "string") : [];
}
