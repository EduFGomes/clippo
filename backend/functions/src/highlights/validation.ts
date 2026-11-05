/**
 * Regras puras (sem Firebase) para validar o vídeo de um highlight no Storage.
 * Separadas para poderem ser testadas sozinhas em test/highlights.test.ts.
 */

/** Teto para um trecho de ~30 s em MP4 (100 MB dá folga para 1080p). */
export const MAX_VIDEO_BYTES = 100 * 1024 * 1024;

const VIDEO_PATH_PATTERN =
  /^sessions\/([A-Za-z0-9_-]{6,64})\/highlights\/([A-Za-z0-9_-]{6,64})\/video\.mp4$/;

export interface HighlightVideoLocation {
  sessionId: string;
  highlightId: string;
}

/** Extrai `sessionId` e `highlightId` se o caminho for o `video.mp4` de um lance. */
export function parseHighlightVideoPath(
  objectPath: string | undefined | null,
): HighlightVideoLocation | null {
  if (typeof objectPath !== "string") return null;
  const match = VIDEO_PATH_PATTERN.exec(objectPath);
  if (!match) return null;
  return { sessionId: match[1], highlightId: match[2] };
}

export interface UploadedVideoMeta {
  contentType?: string | null;
  size?: number | string | null;
}

export interface VideoValidationResult {
  valid: boolean;
  reason?: string;
}

/** Confere se o arquivo enviado é um MP4 não vazio dentro do limite de tamanho. */
export function validateUploadedVideo(meta: UploadedVideoMeta): VideoValidationResult {
  const contentType = (meta.contentType ?? "").toLowerCase();
  if (!contentType.startsWith("video/mp4")) {
    return { valid: false, reason: "Formato inválido: esperado video/mp4." };
  }
  const bytes = typeof meta.size === "string" ? Number(meta.size) : meta.size;
  if (typeof bytes !== "number" || !Number.isFinite(bytes) || bytes <= 0) {
    return { valid: false, reason: "Arquivo de vídeo vazio." };
  }
  if (bytes > MAX_VIDEO_BYTES) {
    return { valid: false, reason: "Arquivo de vídeo acima do limite de 100 MB." };
  }
  return { valid: true };
}
