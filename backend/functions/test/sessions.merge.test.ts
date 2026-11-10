import { describe, expect, it } from "vitest";

import {
  SessionValidationError,
  mergeRequestId,
  mergeStatsDeltas,
  mergedParticipants,
  mergedPeriod,
  parseMergeRequestId,
  participantChanges,
  periodsTouch,
} from "../src/sessions/validation";

const at = (hhmm: string) => new Date(`2026-11-09T${hhmm}:00.000Z`);
const periodo = (inicio: string, fim: string) => ({ startedAt: at(inicio), endedAt: at(fim) });

describe("o pedido para juntar sessões (D18)", () => {
  it("o id vai e volta", () => {
    const id = mergeRequestId("sessaoA01", "sessaoB01");
    expect(id).toBe("sessaoA01__sessaoB01");
    expect(parseMergeRequestId(id)).toEqual({ intoSessionId: "sessaoA01", fromSessionId: "sessaoB01" });
  });

  it("id torto é recusado", () => {
    for (const ruim of ["", "sessaoA01", "a__b", "sessaoA01__sessaoB01__x", "../x__sessaoB01", 7]) {
      expect(() => parseMergeRequestId(ruim)).toThrow(SessionValidationError);
    }
  });
});

describe("só junta sessões do mesmo jogo", () => {
  it("duas gravações ao mesmo tempo se encostam", () => {
    expect(periodsTouch(periodo("20:00", "21:00"), periodo("20:05", "21:10"))).toBe(true);
  });

  it("até 30 min de diferença ainda é o mesmo jogo", () => {
    expect(periodsTouch(periodo("20:00", "21:00"), periodo("21:30", "22:00"))).toBe(true);
    expect(periodsTouch(periodo("21:30", "22:00"), periodo("20:00", "21:00"))).toBe(true);
  });

  it("mais que isso, não", () => {
    expect(periodsTouch(periodo("20:00", "21:00"), periodo("21:31", "22:00"))).toBe(false);
  });

  it("o período juntado cobre as duas", () => {
    const p = mergedPeriod(periodo("20:05", "21:00"), periodo("20:00", "21:10"));
    expect(p.startedAt).toEqual(at("20:00"));
    expect(p.endedAt).toEqual(at("21:10"));
    expect(p.durationSeconds).toBe(70 * 60);
  });

  it("participantes das duas, sem repetir, na ordem da principal", () => {
    expect(mergedParticipants(["ana", "beto"], ["beto", "caio"])).toEqual(["ana", "beto", "caio"]);
  });
});

describe("contadores do perfil ao juntar", () => {
  // Tênis: Ana gravou A (3 lances) com Beto; Beto gravou B (2 lances) com Ana e Caio.
  const deltas = mergeStatsDeltas(
    { participantIds: ["ana", "beto"], highlightCount: 3 },
    { participantIds: ["beto", "ana", "caio"], highlightCount: 2 },
  );

  it("quem estava nas duas perde uma sessão e não ganha lance", () => {
    expect(deltas.get("ana")).toEqual({ sessions: -1, highlights: 0 });
    expect(deltas.get("beto")).toEqual({ sessions: -1, highlights: 0 });
  });

  it("quem estava só em B ganha os lances de A", () => {
    expect(deltas.get("caio")).toEqual({ sessions: 0, highlights: 3 });
  });

  it("quem não muda fica de fora", () => {
    const iguais = mergeStatsDeltas(
      { participantIds: ["ana"], highlightCount: 1 },
      { participantIds: ["beto"], highlightCount: 0 },
    );
    expect(iguais.has("ana")).toBe(false);
    expect(iguais.get("beto")).toEqual({ sessions: 0, highlights: 1 });
  });
});

describe("quem entrou e quem saiu (R12)", () => {
  it("separa os dois", () => {
    expect(participantChanges(["ana", "beto", "caio"], ["ana", "caio", "duda"])).toEqual({
      added: ["duda"],
      removed: ["beto"],
    });
  });
});
