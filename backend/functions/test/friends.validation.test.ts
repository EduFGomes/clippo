import { describe, expect, it } from "vitest";

import {
  FriendValidationError,
  friendshipId,
  friendshipUids,
  normalizeUid,
} from "../src/friends/validation";

describe("id da amizade (D16)", () => {
  it("é o mesmo, não importa quem pediu", () => {
    expect(friendshipId("bob", "alice")).toBe("alice_bob");
    expect(friendshipId("alice", "bob")).toBe("alice_bob");
  });

  it("guarda os uids na ordem do id", () => {
    expect(friendshipUids("bob", "alice")).toEqual(["alice", "bob"]);
  });
});

describe("uid que vem do app", () => {
  it("aceita uid do Firebase Auth", () => {
    expect(normalizeUid("Xy12abcDEF34ghiJKL56mnoPQR78")).toBe("Xy12abcDEF34ghiJKL56mnoPQR78");
  });

  it("recusa caminho, vazio e tipo errado", () => {
    for (const ruim of ["", "a/b", "alice_bob", "../users", 42, null, undefined]) {
      expect(() => normalizeUid(ruim)).toThrow(FriendValidationError);
    }
  });

  it("a mensagem não vaza termo técnico", () => {
    expect(() => normalizeUid("a/b")).toThrow("Não encontramos essa pessoa.");
  });
});
