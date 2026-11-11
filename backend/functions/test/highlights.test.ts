import { describe, expect, it } from "vitest";

import {
  HIGHLIGHT_TITLE_MAX,
  HighlightValidationError,
  MAX_VIDEO_BYTES,
  normalizeHighlightRef,
  normalizeHighlightRename,
  parseHighlightVideoPath,
  validateUploadedVideo,
} from "../src/highlights/validation";

describe("parseHighlightVideoPath", () => {
  it("extrai sessionId e highlightId de um caminho válido de video.mp4", () => {
    expect(
      parseHighlightVideoPath("sessions/sessao-0001/highlights/lance-0001/video.mp4"),
    ).toEqual({
      sessionId: "sessao-0001",
      highlightId: "lance-0001",
    });
  });

  it("ignora miniatura, outros arquivos e ids fora do formato", () => {
    expect(
      parseHighlightVideoPath("sessions/sessao-0001/highlights/lance-0001/thumb.jpg"),
    ).toBeNull();
    expect(parseHighlightVideoPath("sessions/curto/highlights/lance-0001/video.mp4")).toBeNull();
    expect(parseHighlightVideoPath("users/alice/avatar.jpg")).toBeNull();
    expect(parseHighlightVideoPath(null)).toBeNull();
    expect(parseHighlightVideoPath(undefined)).toBeNull();
  });
});

describe("validateUploadedVideo", () => {
  it("aceita MP4 não vazio dentro do limite", () => {
    expect(validateUploadedVideo({ contentType: "video/mp4", size: 8_500_000 })).toEqual({
      valid: true,
    });
    expect(
      validateUploadedVideo({
        contentType: "video/mp4; codecs=avc1",
        size: String(MAX_VIDEO_BYTES),
      }),
    ).toEqual({ valid: true });
  });

  it("recusa formato diferente de video/mp4", () => {
    expect(validateUploadedVideo({ contentType: "image/jpeg", size: 1024 }).valid).toBe(false);
    expect(validateUploadedVideo({ contentType: null, size: 1024 }).valid).toBe(false);
  });

  it("recusa vídeo vazio ou maior que 100 MB", () => {
    expect(validateUploadedVideo({ contentType: "video/mp4", size: 0 }).valid).toBe(false);
    expect(validateUploadedVideo({ contentType: "video/mp4", size: -10 }).valid).toBe(false);
    expect(
      validateUploadedVideo({ contentType: "video/mp4", size: MAX_VIDEO_BYTES + 1 }).valid,
    ).toBe(false);
  });
});

// Os mesmos casos de app/test/input_validation_test.dart (validateHighlightRename).
describe("normalizeHighlightRename", () => {
  it("normaliza espaços e aceita até o limite", () => {
    expect(normalizeHighlightRename("  Voleio  do Rafa ")).toBe("Voleio do Rafa");
    expect(normalizeHighlightRename("a".repeat(HIGHLIGHT_TITLE_MAX))).toBe("a".repeat(HIGHLIGHT_TITLE_MAX));
  });

  it("recusa nome vazio, só espaços ou que não é texto", () => {
    for (const ruim of [undefined, null, "", "   ", 42, {}]) {
      expect(() => normalizeHighlightRename(ruim)).toThrowError("Dê um nome ao lance.");
    }
  });

  it("recusa nome acima do limite, apontando o campo", () => {
    try {
      normalizeHighlightRename("a".repeat(HIGHLIGHT_TITLE_MAX + 1));
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(HighlightValidationError);
      expect((e as HighlightValidationError).field).toBe("title");
      expect((e as Error).message).toBe(
        `O nome do lance pode ter até ${HIGHLIGHT_TITLE_MAX} caracteres.`,
      );
    }
  });
});

describe("normalizeHighlightRef", () => {
  it("aceita os ids que o app gera e recusa o resto", () => {
    expect(normalizeHighlightRef("lance-0001", "highlightId")).toBe("lance-0001");
    for (const ruim of ["curto", "../lance-0001", "", null, 7]) {
      expect(() => normalizeHighlightRef(ruim, "sessionId")).toThrowError(
        "Não foi possível renomear o lance. Tente de novo.",
      );
    }
  });
});
