import { describe, expect, it } from "vitest";

import {
  MAX_VIDEO_BYTES,
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
