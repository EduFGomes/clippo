import { describe, expect, it } from "vitest";

import {
  PARTICIPANTS_MAX,
  SESSION_NAME_MAX,
  SessionValidationError,
  normalizeHighlights,
  normalizeId,
  normalizeLocation,
  normalizeParticipantIds,
  normalizePeriod,
  normalizeSessionName,
} from "../src/sessions/validation";

// Os mesmos casos de app/test/input_validation_test.dart: as duas regras precisam concordar.
const INICIO = "2026-10-29T22:30:00.000Z";
const FIM = "2026-10-30T00:12:00.000Z"; // 1h42
const AGORA = new Date("2026-10-30T01:00:00.000Z");

describe("nome da sessão", () => {
  it("junta espaços e tira os das pontas", () => {
    expect(normalizeSessionName("  Pelada   de quinta ")).toBe("Pelada de quinta");
  });

  it("recusa vazio e só espaços", () => {
    for (const raw of ["", "   ", null, 42]) {
      expect(() => normalizeSessionName(raw)).toThrow("Dê um nome para a sessão.");
    }
  });

  it("recusa acima do limite", () => {
    expect(() => normalizeSessionName("a".repeat(SESSION_NAME_MAX + 1))).toThrow(
      `O nome da sessão pode ter até ${SESSION_NAME_MAX} caracteres.`,
    );
    expect(normalizeSessionName("a".repeat(SESSION_NAME_MAX))).toHaveLength(SESSION_NAME_MAX);
  });
});

describe("local", () => {
  it("é opcional: sem local vira null", () => {
    for (const raw of [null, undefined, "", "   "]) {
      expect(normalizeLocation(raw)).toBeNull();
    }
  });

  it("normaliza e limita", () => {
    expect(normalizeLocation("  Quadra   do Parque ")).toBe("Quadra do Parque");
    expect(() => normalizeLocation("a".repeat(61))).toThrow("O local pode ter até 60 caracteres.");
  });
});

describe("início e fim", () => {
  it("calcula a duração em segundos", () => {
    const period = normalizePeriod(INICIO, FIM, AGORA);
    expect(period.durationSeconds).toBe(6120);
    expect(period.startedAt.toISOString()).toBe(INICIO);
  });

  it("recusa fim antes ou igual ao início", () => {
    expect(() => normalizePeriod(FIM, INICIO, AGORA)).toThrow(
      "O fim da sessão precisa vir depois do início.",
    );
    expect(() => normalizePeriod(INICIO, INICIO, AGORA)).toThrow(
      "O fim da sessão precisa vir depois do início.",
    );
  });

  it("recusa data que não existe", () => {
    for (const raw of ["ontem", "", 0, null]) {
      expect(() => normalizePeriod(raw, FIM, AGORA)).toThrow("Confira a data e a hora da sessão.");
    }
  });

  it("recusa sessão de mais de 12 horas", () => {
    expect(() => normalizePeriod("2026-10-29T00:00:00Z", "2026-10-29T13:00:00Z", AGORA)).toThrow(
      "Uma sessão pode durar até 12 horas.",
    );
  });

  it("recusa sessão que termina no futuro, mas tolera 5 min de relógio adiantado", () => {
    expect(() => normalizePeriod(INICIO, "2026-10-30T02:00:00Z", AGORA)).toThrow(
      "A sessão não pode terminar no futuro.",
    );
    expect(normalizePeriod(INICIO, "2026-10-30T01:04:00Z", AGORA).durationSeconds).toBeGreaterThan(0);
  });
});

describe("participantes", () => {
  it("o dono entra sempre e vem primeiro (R9)", () => {
    expect(normalizeParticipantIds(["bob"], "alice")).toEqual(["alice", "bob"]);
    expect(normalizeParticipantIds(null, "alice")).toEqual(["alice"]);
  });

  it("não repete ninguém, nem o dono mandado de novo", () => {
    expect(normalizeParticipantIds(["bob", "alice", "bob"], "alice")).toEqual(["alice", "bob"]);
  });

  it("recusa uid que não é texto", () => {
    expect(() => normalizeParticipantIds([42], "alice")).toThrow("Confira quem jogou com você.");
    expect(() => normalizeParticipantIds([""], "alice")).toThrow("Confira quem jogou com você.");
  });

  it("recusa acima do limite", () => {
    const muitos = Array.from({ length: PARTICIPANTS_MAX }, (_, i) => `u${i}`);
    expect(() => normalizeParticipantIds(muitos, "alice")).toThrow(
      `Uma sessão pode ter até ${PARTICIPANTS_MAX} participantes.`,
    );
  });
});

describe("highlights", () => {
  const lance = (extra: Record<string, unknown> = {}) => ({
    highlightId: "lance-0001",
    offsetSeconds: 760,
    durationSeconds: 30,
    ...extra,
  });

  it("sessão sem nenhum lance é aceita (R14)", () => {
    expect(normalizeHighlights([], 6120)).toEqual([]);
    expect(normalizeHighlights(null, 6120)).toEqual([]);
  });

  it("título vazio vira 'Lance N' pela posição", () => {
    const [primeiro, segundo] = normalizeHighlights(
      [lance(), lance({ highlightId: "lance-0002", title: "  " })],
      6120,
    );
    expect(primeiro.title).toBe("Lance 1");
    expect(segundo.title).toBe("Lance 2");
  });

  it("mantém o título que a pessoa escreveu", () => {
    expect(normalizeHighlights([lance({ title: "  Voleio  do Rafa " })], 6120)[0].title).toBe(
      "Voleio do Rafa",
    );
  });

  it("recusa lance fora da sessão, com 1 min de folga", () => {
    expect(() => normalizeHighlights([lance({ offsetSeconds: 6200 })], 6120)).toThrow(
      "Confira o momento dos lances.",
    );
    expect(normalizeHighlights([lance({ offsetSeconds: 6150 })], 6120)).toHaveLength(1);
  });

  it("recusa duração zerada, negativa ou absurda", () => {
    for (const d of [0, -1, 121]) {
      expect(() => normalizeHighlights([lance({ durationSeconds: d })], 6120)).toThrow(
        "Confira a duração dos lances.",
      );
    }
  });

  it("recusa dois lances com o mesmo id", () => {
    expect(() => normalizeHighlights([lance(), lance()], 6120)).toThrow(
      "Não foi possível salvar os lances.",
    );
  });

  it("arredonda os segundos que vêm quebrados do buffer", () => {
    const [h] = normalizeHighlights([lance({ offsetSeconds: 760.4, durationSeconds: 29.6 })], 6120);
    expect(h.offsetSeconds).toBe(760);
    expect(h.durationSeconds).toBe(30);
  });
});

describe("id vindo do aparelho", () => {
  it("aceita o que o app gera", () => {
    expect(normalizeId("sessao_2026-10-29_AbC123", "sessionId")).toBe("sessao_2026-10-29_AbC123");
  });

  it("recusa id curto, com espaço, com barra ou que não é texto", () => {
    for (const raw of ["abc", "com espaco", "../outra", "a".repeat(65), null, 7]) {
      expect(() => normalizeId(raw, "sessionId")).toThrow(
        "Não foi possível salvar a sessão. Tente de novo.",
      );
    }
  });
});

describe("mensagens de erro", () => {
  it("dizem qual campo marcar na tela", () => {
    try {
      normalizeSessionName("");
      throw new Error("devia ter recusado");
    } catch (e) {
      expect(e).toBeInstanceOf(SessionValidationError);
      expect((e as SessionValidationError).field).toBe("name");
    }
  });

  it("não vazam jargão técnico", () => {
    const mensagens = [
      () => normalizeSessionName(""),
      () => normalizePeriod("x", FIM, AGORA),
      () => normalizeParticipantIds([42], "alice"),
      () => normalizeHighlights([{ highlightId: "x" }], 10),
    ].map((fn) => {
      try {
        fn();
        return "";
      } catch (e) {
        return (e as Error).message;
      }
    });
    for (const m of mensagens) {
      expect(m).not.toMatch(/undefined|null|Error|Firebase|string/i);
      expect(m.endsWith(".")).toBe(true);
    }
  });
});
