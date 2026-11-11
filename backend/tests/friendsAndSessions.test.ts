/**
 * Ponta a ponta de amizade (D16), edição de sessão (R12) e juntar sessões (D18),
 * batendo nas Functions do Emulator como o app faria.
 *
 * Rode a partir de backend/tests com: npm run test:e2e
 */
import { beforeAll, describe, expect, it } from "vitest";

import {
  type Conta,
  chamar,
  criarPessoa,
  fazerAmigos,
  ler,
  lerComoAdmin,
  lista,
  numero,
  stat,
  texto,
} from "./e2e-helpers";

type Pessoa = Conta & { username: string };

let ana: Pessoa;
let beto: Pessoa;
let caio: Pessoa;
let duda: Pessoa;

const par = (a: Conta, b: Conta) => (a.uid < b.uid ? `${a.uid}_${b.uid}` : `${b.uid}_${a.uid}`);

beforeAll(async () => {
  [ana, beto, caio, duda] = await Promise.all([
    criarPessoa("ana", "Ana Reis"),
    criarPessoa("beto", "Beto Lins"),
    criarPessoa("caio", "Caio Melo"),
    criarPessoa("duda", "Duda Paz"),
  ]);
}, 60_000);

describe("amizade (R15, D16)", () => {
  it("pedido pelo @ fica esperando o aceite", async () => {
    const r = await chamar("sendFriendRequest", ana, { username: `  @${beto.username.toUpperCase()} ` });
    expect(r.status).toBe(200);
    expect(r.result).toEqual({ uid: beto.uid, status: "pending" });

    const f = await ler(`friendships/${par(ana, beto)}`, beto);
    expect(texto(f?.status)).toBe("pending");
    expect(texto(f?.requestedTo)).toBe(beto.uid);
  });

  it("pedir de novo não duplica nem muda nada", async () => {
    const r = await chamar("sendFriendRequest", ana, { username: beto.username });
    expect(r.result?.status).toBe("pending");
  });

  it("quem pediu não aceita o próprio pedido", async () => {
    const r = await chamar("acceptFriendRequest", ana, { uid: beto.uid });
    expect(r.error?.message).toBe("Espere a outra pessoa aceitar o convite.");
  });

  it("uma terceira pessoa não vê o pedido", async () => {
    expect(await ler(`friendships/${par(ana, beto)}`, caio)).toBeNull();
  });

  it("quem recebeu aceita, e os dois ganham um amigo", async () => {
    const r = await chamar("acceptFriendRequest", beto, { uid: ana.uid });
    expect(r.status).toBe(200);
    expect(texto((await ler(`friendships/${par(ana, beto)}`, ana))?.status)).toBe("accepted");
    expect(stat(await ler(`users/${ana.uid}`, ana), "friends")).toBe("1");
    expect(stat(await ler(`users/${beto.uid}`, beto), "friends")).toBe("1");
  });

  it("aceitar de novo não soma o contador duas vezes", async () => {
    await chamar("acceptFriendRequest", beto, { uid: ana.uid });
    expect(stat(await ler(`users/${beto.uid}`, beto), "friends")).toBe("1");
  });

  it("se os dois pedem, a amizade é aceita na hora", async () => {
    await chamar("sendFriendRequest", caio, { username: ana.username });
    const r = await chamar("sendFriendRequest", ana, { username: caio.username });
    expect(r.result?.status).toBe("accepted");
    expect(stat(await ler(`users/${ana.uid}`, ana), "friends")).toBe("2");
  });

  it("recusa @ que não existe, @ inválido e o próprio @", async () => {
    expect((await chamar("sendFriendRequest", ana, { username: "ninguem_aqui_9" })).error?.message)
      .toBe("Não achamos ninguém com esse @.");
    const invalido = await chamar("sendFriendRequest", ana, { username: "a b" });
    expect(invalido.error?.message).toBe("Use só letras sem acento, números, \"_\" e \".\".");
    expect(invalido.error?.details?.field).toBe("username");
    expect((await chamar("sendFriendRequest", ana, { username: ana.username })).error?.message)
      .toBe("Esse @ é o seu.");
  });

  it("desfazer a amizade tira o amigo dos dois", async () => {
    await fazerAmigos(duda, ana);
    expect(stat(await ler(`users/${ana.uid}`, ana), "friends")).toBe("3");
    const r = await chamar("removeFriend", duda, { uid: ana.uid });
    expect(r.status).toBe(200);
    expect(await lerComoAdmin(`friendships/${par(ana, duda)}`)).toBeNull();
    expect(stat(await ler(`users/${ana.uid}`, ana), "friends")).toBe("2");
    expect(stat(await ler(`users/${duda.uid}`, duda), "friends")).toBe("0");
  });

  it("sem login, nada", async () => {
    const r = await chamar("sendFriendRequest", null, { username: beto.username });
    expect(r.error?.message).toBe("Entre na sua conta para adicionar amigos.");
  });
});

describe("editar a sessão depois de salva (R12)", () => {
  const ID = "e2e-editar-01";

  beforeAll(async () => {
    const r = await chamar("saveSession", ana, {
      sessionId: ID,
      name: "Futevôlei",
      startedAt: "2026-11-01T18:00:00.000Z",
      endedAt: "2026-11-01T19:00:00.000Z",
      participantIds: [beto.uid],
      highlights: [{ highlightId: "e2e-ed-lance1", offsetSeconds: 60, durationSeconds: 30 }],
    });
    expect(r.status).toBe(200);
  });

  it("o dono muda nome e local", async () => {
    const r = await chamar("updateSession", ana, { sessionId: ID, name: "  Futevôlei  da praia ", location: "Posto 9" });
    expect(r.status).toBe(200);
    const s = await ler(`sessions/${ID}`, ana);
    expect(texto(s?.name)).toBe("Futevôlei da praia");
    expect(texto(s?.location?.mapValue?.fields?.label)).toBe("Posto 9");
  });

  it("participante não edita", async () => {
    const r = await chamar("updateSession", beto, { sessionId: ID, name: "Outro" });
    expect(r.error?.message).toBe("Só quem gravou a sessão pode editar.");
  });

  it("só adiciona amigos (R10)", async () => {
    const r = await chamar("updateSession", ana, { sessionId: ID, participantIds: [beto.uid, duda.uid] });
    expect(r.error?.message).toBe("Só dá para adicionar os seus amigos.");
  });

  it("adicionar um amigo dá acesso e soma a sessão no perfil dele", async () => {
    const r = await chamar("updateSession", ana, { sessionId: ID, participantIds: [beto.uid, caio.uid] });
    expect(r.status).toBe(200);
    expect(await ler(`sessions/${ID}`, caio)).not.toBeNull();
    const perfil = await ler(`users/${caio.uid}`, caio);
    expect(stat(perfil, "sessions")).toBe("1");
    expect(stat(perfil, "highlights")).toBe("1");
  });

  it("tirar alguém corta o acesso na hora e desconta do perfil", async () => {
    const r = await chamar("updateSession", ana, { sessionId: ID, participantIds: [caio.uid] });
    expect(r.status).toBe(200);
    expect(await ler(`sessions/${ID}`, beto)).toBeNull();
    expect(stat(await ler(`users/${beto.uid}`, beto), "sessions")).toBe("0");
  });

  it("o participante sai sozinho; o dono não", async () => {
    expect((await chamar("leaveSession", caio, { sessionId: ID })).status).toBe(200);
    expect(await ler(`sessions/${ID}`, caio)).toBeNull();
    expect(stat(await ler(`users/${caio.uid}`, caio), "sessions")).toBe("0");
    expect((await chamar("leaveSession", ana, { sessionId: ID })).error?.message)
      .toBe("Quem gravou a sessão não pode sair dela.");
  });
});

describe("juntar sessões: tênis com um celular de cada lado (D18)", () => {
  const A = "e2e-tenis-ana";
  const B = "e2e-tenis-beto";
  let requestId: string;

  beforeAll(async () => {
    // Ana filma atrás dela e inclui o Beto; o Beto filma atrás dele e inclui a Ana.
    const [ra, rb] = await Promise.all([
      chamar("saveSession", ana, {
        sessionId: A,
        name: "Tênis",
        startedAt: "2026-11-02T10:00:00.000Z",
        endedAt: "2026-11-02T11:00:00.000Z",
        participantIds: [beto.uid],
        highlights: [
          { highlightId: "e2e-ta-1", offsetSeconds: 600, durationSeconds: 30 },
          { highlightId: "e2e-ta-2", offsetSeconds: 1800, durationSeconds: 30 },
        ],
      }),
      chamar("saveSession", beto, {
        sessionId: B,
        name: "Tênis do Beto",
        startedAt: "2026-11-02T09:55:00.000Z",
        endedAt: "2026-11-02T11:05:00.000Z",
        participantIds: [ana.uid],
        highlights: [{ highlightId: "e2e-tb-1", offsetSeconds: 900, durationSeconds: 30 }],
      }),
    ]);
    expect(ra.status).toBe(200);
    expect(rb.status).toBe(200);
  });

  it("quem não é dono da principal não pede", async () => {
    const r = await chamar("requestSessionMerge", beto, { intoSessionId: A, fromSessionId: B });
    expect(r.error?.message).toBe("Só quem gravou a sessão pode juntar outra a ela.");
  });

  it("a Ana pede, e só ela e o Beto veem o pedido", async () => {
    const r = await chamar("requestSessionMerge", ana, { intoSessionId: A, fromSessionId: B });
    expect(r.status).toBe(200);
    requestId = r.result.requestId;
    expect(await ler(`sessionMergeRequests/${requestId}`, beto)).not.toBeNull();
    expect(await ler(`sessionMergeRequests/${requestId}`, caio)).toBeNull();
  });

  it("a Ana não aceita o próprio pedido", async () => {
    const r = await chamar("acceptSessionMerge", ana, { requestId });
    expect(r.error?.message).toBe("Só quem gravou a outra sessão pode aceitar.");
  });

  it("o Beto aceita e a sessão A vira o hub com os lances das duas", async () => {
    const r = await chamar("acceptSessionMerge", beto, { requestId });
    expect(r.status).toBe(200);

    const s = await ler(`sessions/${A}`, beto);
    expect(numero(s?.highlightCount)).toBe("3");
    expect(lista(s?.mergedFrom)).toEqual([B]);
    // O início ficou mais cedo (9h55, do Beto), e a duração cobre as duas.
    expect(numero(s?.durationSeconds)).toBe(String(70 * 60));

    const copia = await ler(`sessions/${A}/highlights/e2e-tb-1`, ana);
    expect(texto(copia?.sourceSessionId)).toBe(B);
    expect(texto(copia?.videoPath)).toBe(`sessions/${B}/highlights/e2e-tb-1/video.mp4`);
    expect(numero(copia?.offsetSeconds)).toBe("900");

    // O lance da Ana andou 5 min (300 s) para frente na linha do tempo nova.
    expect(numero((await ler(`sessions/${A}/highlights/e2e-ta-1`, ana))?.offsetSeconds)).toBe("900");
  });

  it("a sessão B fica marcada como juntada e o pedido some", async () => {
    const b = await ler(`sessions/${B}`, beto);
    expect(texto(b?.mergedInto)).toBe(A);
    expect(await lerComoAdmin(`sessionMergeRequests/${requestId}`)).toBeNull();
  });

  it("aceitar de novo não duplica nada", async () => {
    const r = await chamar("acceptSessionMerge", beto, { requestId });
    expect(r.status).toBe(200);
    expect(numero((await ler(`sessions/${A}`, ana))?.highlightCount)).toBe("3");
  });

  it("os dois ficam com uma sessão só no perfil", async () => {
    // Beto: 1 sessão (o tênis); Ana: Futevôlei + tênis.
    const perfilBeto = await ler(`users/${beto.uid}`, beto);
    expect(stat(perfilBeto, "sessions")).toBe("1");
    expect(stat(perfilBeto, "highlights")).toBe("3");
    expect(stat(await ler(`users/${ana.uid}`, ana), "sessions")).toBe("2");
  });

  it("um reenvio da fila do Beto com lance novo chega também no hub", async () => {
    const r = await chamar("saveSession", beto, {
      sessionId: B,
      name: "Tênis do Beto",
      startedAt: "2026-11-02T09:55:00.000Z",
      endedAt: "2026-11-02T11:05:00.000Z",
      participantIds: [ana.uid],
      highlights: [
        { highlightId: "e2e-tb-1", offsetSeconds: 900, durationSeconds: 30 },
        { highlightId: "e2e-tb-2", offsetSeconds: 3000, durationSeconds: 30 },
      ],
    });
    expect(r.status).toBe(200);
    expect(numero((await ler(`sessions/${A}`, ana))?.highlightCount)).toBe("4");
    expect(texto((await ler(`sessions/${A}/highlights/e2e-tb-2`, ana))?.sourceSessionId)).toBe(B);
  });

  it("sessões de jogos diferentes não se juntam", async () => {
    await chamar("saveSession", beto, {
      sessionId: "e2e-outro-dia",
      name: "Outro dia",
      startedAt: "2026-11-03T10:00:00.000Z",
      endedAt: "2026-11-03T11:00:00.000Z",
      participantIds: [ana.uid],
    });
    const r = await chamar("requestSessionMerge", ana, { intoSessionId: A, fromSessionId: "e2e-outro-dia" });
    expect(r.error?.message).toMatch(/^Só dá para juntar sessões gravadas no mesmo jogo/);
  });
});

describe("excluir a sessão (R12)", () => {
  const ID = "e2e-excluir-01";
  let antes: { sessoes: number; lances: number };

  beforeAll(async () => {
    const perfil = await ler(`users/${beto.uid}`, beto);
    antes = { sessoes: Number(stat(perfil, "sessions") ?? 0), lances: Number(stat(perfil, "highlights") ?? 0) };
    const r = await chamar("saveSession", ana, {
      sessionId: ID,
      name: "Racha de domingo",
      startedAt: "2026-11-04T10:00:00.000Z",
      endedAt: "2026-11-04T11:00:00.000Z",
      participantIds: [beto.uid],
      highlights: [
        { highlightId: "e2e-ex-lance1", offsetSeconds: 60, durationSeconds: 30 },
        { highlightId: "e2e-ex-lance2", offsetSeconds: 600, durationSeconds: 30 },
      ],
    });
    expect(r.status).toBe(200);
  });

  it("participante não exclui", async () => {
    const r = await chamar("deleteSession", beto, { sessionId: ID });
    expect(r.error?.message).toBe("Só quem gravou a sessão pode excluir.");
    expect(await ler(`sessions/${ID}`, beto)).not.toBeNull();
  });

  it("sem login, não exclui; id torto é recusado antes do banco", async () => {
    expect((await chamar("deleteSession", null, { sessionId: ID })).error?.message)
      .toBe("Entre na sua conta para excluir a sessão.");
    expect((await chamar("deleteSession", ana, { sessionId: "../x" })).error?.status).toBe("INVALID_ARGUMENT");
  });

  it("o dono exclui: some para todos, com os lances, e sai do perfil de quem jogou", async () => {
    const r = await chamar("deleteSession", ana, { sessionId: ID });
    expect(r.status).toBe(200);
    expect(await lerComoAdmin(`sessions/${ID}`)).toBeNull();
    expect(await lerComoAdmin(`sessions/${ID}/highlights/e2e-ex-lance1`)).toBeNull();
    const perfil = await ler(`users/${beto.uid}`, beto);
    expect(Number(stat(perfil, "sessions"))).toBe(antes.sessoes);
    expect(Number(stat(perfil, "highlights"))).toBe(antes.lances);
  });

  it("excluir de novo não é erro", async () => {
    expect((await chamar("deleteSession", ana, { sessionId: ID })).status).toBe(200);
  });

  it("sessão com outra juntada ainda não exclui (D18)", async () => {
    const r = await chamar("deleteSession", ana, { sessionId: "e2e-tenis-ana" });
    expect(r.error?.message).toBe("Essa sessão tem lances de outra sessão juntada e ainda não dá para excluir.");
  });
});
