import { describe, expect, it } from "vitest";

import {
  ValidationError,
  normalizeBirthDate,
  normalizeEmail,
  normalizeName,
  normalizeSessionLocation,
  normalizeSessionName,
  normalizeUsername,
} from "../src/users/validation";

describe("normalizeUsername", () => {
  it("tira o @, espaços e deixa minúsculo", () => {
    expect(normalizeUsername("  @Rafa_10 ")).toBe("rafa_10");
  });

  it("aceita ponto no meio", () => {
    expect(normalizeUsername("rafa.silva")).toBe("rafa.silva");
  });

  it.each(["ra", "a".repeat(21), "rafa silva", "rafá", ".rafa", "rafa.", "ra..fa", 42])(
    "recusa %s",
    (value) => {
      expect(() => normalizeUsername(value)).toThrow(ValidationError);
    },
  );
});

describe("normalizeName", () => {
  it("junta espaços repetidos", () => {
    expect(normalizeName("  Rafael   Silva ")).toBe("Rafael Silva");
  });

  it("recusa nome vazio ou longo demais", () => {
    expect(() => normalizeName("   ")).toThrow(ValidationError);
    expect(() => normalizeName("a".repeat(51))).toThrow(ValidationError);
  });
});

describe("normalizeBirthDate", () => {
  const today = new Date(Date.UTC(2026, 9, 13)); // 13/10/2026

  it("aceita uma data válida no passado", () => {
    expect(normalizeBirthDate("2001-02-28", today)).toBe("2001-02-28");
  });

  it.each(["2001-02-30", "2027-01-01", "1899-12-31", "13/10/2001", ""])("recusa %s", (value) => {
    expect(() => normalizeBirthDate(value, today)).toThrow(ValidationError);
  });
});

describe("normalizeEmail", () => {
  it("tira espaços e deixa minúsculo", () => {
    expect(normalizeEmail("  Voce@Email.com ")).toBe("voce@email.com");
  });

  it.each(["rafa+jogo@gmail.com", "a.b_c@sub.dominio.com.br", "x@y.io"])("aceita %s", (value) => {
    expect(normalizeEmail(value)).toBe(value);
  });

  it.each([
    "",
    "   ",
    "capovill@g",
    "sem-arroba.com",
    "nome@dominio",
    "nome@dominio.c",
    "nome @dominio.com",
    ".nome@dominio.com",
    "nome.@dominio.com",
    "no..me@dominio.com",
    "nome@-dominio.com",
    "nome@dominio..com",
    "nome@dominio.c0m",
    `${"a".repeat(65)}@dominio.com`,
    `nome@${"a".repeat(250)}.com`,
    null,
    42,
  ])("recusa %s", (value) => {
    expect(() => normalizeEmail(value)).toThrow(ValidationError);
  });
});

describe("normalizeSessionName", () => {
  it("junta espaços repetidos", () => {
    expect(normalizeSessionName("  Pelada   de quinta ")).toBe("Pelada de quinta");
  });

  it("recusa nome vazio ou longo demais", () => {
    expect(() => normalizeSessionName("   ")).toThrow(ValidationError);
    expect(() => normalizeSessionName("a".repeat(51))).toThrow(ValidationError);
    expect(() => normalizeSessionName(42)).toThrow(ValidationError);
  });
});

describe("normalizeSessionLocation", () => {
  it("aceita vazio devolvendo null e junta espaços repetidos", () => {
    expect(normalizeSessionLocation("")).toBeNull();
    expect(normalizeSessionLocation("   ")).toBeNull();
    expect(normalizeSessionLocation(null)).toBeNull();
    expect(normalizeSessionLocation("  Arena   Society ")).toBe("Arena Society");
  });

  it("recusa local longo demais", () => {
    expect(() => normalizeSessionLocation("a".repeat(81))).toThrow(ValidationError);
    expect(() => normalizeSessionLocation(42)).toThrow(ValidationError);
  });
});
