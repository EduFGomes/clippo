import { describe, expect, it } from "vitest";

import {
  COMMENT_MAX,
  COMMENT_MAX_LINES,
  FavoriteValidationError,
  normalizeComment,
  normalizeCommentId,
  normalizeLiked,
  normalizePostId,
  postIdFor,
} from "../src/favorites/validation";
import { friendshipId } from "../src/favorites/posts";

function fieldOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    if (e instanceof FavoriteValidationError) return e.field;
    throw e;
  }
  return undefined;
}

function messageOf(fn: () => unknown): string | undefined {
  try {
    fn();
  } catch (e) {
    if (e instanceof FavoriteValidationError) return e.message;
    throw e;
  }
  return undefined;
}

describe("postIdFor", () => {
  it("um favorito por pessoa e lance", () => {
    expect(postIdFor("alice", "quinta01", "lance01")).toBe("alice__quinta01__lance01");
  });

  it("o id gerado passa na validação", () => {
    const id = postIdFor("Xy9AbCdEfGhIjKlMnOpQrStUvW12", "sessao-0001", "lance-0001");
    expect(normalizePostId(id)).toBe(id);
  });
});

describe("normalizePostId e normalizeCommentId", () => {
  it("recusa vazio, curto, caracteres fora do formato e outro tipo", () => {
    for (const raw of ["", "curto", "a/b/c__d__eeeeee", 42, null, undefined]) {
      expect(fieldOf(() => normalizePostId(raw))).toBe("postId");
    }
    for (const raw of ["", "abc", "com espaço", 7]) {
      expect(fieldOf(() => normalizeCommentId(raw))).toBe("commentId");
    }
    expect(normalizeCommentId("c-12345")).toBe("c-12345");
  });
});

describe("normalizeLiked", () => {
  it("só aceita verdadeiro ou falso", () => {
    expect(normalizeLiked(true)).toBe(true);
    expect(normalizeLiked(false)).toBe(false);
    expect(fieldOf(() => normalizeLiked("true"))).toBe("liked");
    expect(fieldOf(() => normalizeLiked(undefined))).toBe("liked");
  });
});

describe("normalizeComment (R22, espelha validateComment do app)", () => {
  it("tira os espaços das pontas e troca a quebra de linha do Windows", () => {
    expect(normalizeComment("  Que golaço!  ")).toBe("Que golaço!");
    expect(normalizeComment("linha 1\r\nlinha 2")).toBe("linha 1\nlinha 2");
  });

  it("vazio ou só espaços: pede para escrever", () => {
    for (const raw of ["", "   ", "\n\n", null, undefined]) {
      expect(messageOf(() => normalizeComment(raw))).toBe("Escreva um comentário.");
    }
    expect(fieldOf(() => normalizeComment(12))).toBe("text");
  });

  it("até 300 caracteres", () => {
    expect(normalizeComment("a".repeat(COMMENT_MAX))).toHaveLength(COMMENT_MAX);
    expect(messageOf(() => normalizeComment("a".repeat(COMMENT_MAX + 1)))).toBe(
      "O comentário pode ter até 300 caracteres.",
    );
  });

  it("até 6 linhas", () => {
    const six = Array.from({ length: COMMENT_MAX_LINES }, (_, i) => `linha ${i}`).join("\n");
    expect(normalizeComment(six)).toBe(six);
    expect(messageOf(() => normalizeComment(`${six}\nmais uma`))).toBe("O comentário pode ter até 6 linhas.");
  });
});

describe("friendshipId", () => {
  it("os dois uids em ordem, como o D16", () => {
    expect(friendshipId("bob", "alice")).toBe("alice_bob");
    expect(friendshipId("alice", "bob")).toBe("alice_bob");
  });
});
