/**
 * Teste de ponta a ponta do saveSession, batendo no Emulator como o app faria:
 * cria contas de verdade no Auth, completa os perfis e chama a função.
 *
 * Rode a partir de backend/tests com: npm run test:e2e
 * (o comando compila as Functions, sobe o Emulator, roda e desliga.)
 *
 * Diferente do firestore.rules.test.ts, que só precisa do Firestore, este
 * exercita o caminho inteiro de escrita: Auth → Function → Firestore → regras.
 *
 * Portas e região: backend/firebase.json e functions/src/config.ts.
 */
import { beforeAll, describe, expect, it } from "vitest";

const PROJECT = "demo-clippo";
const REGION = "us-east1";
const AUTH = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1`;
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;
const FIRESTORE = `http://127.0.0.1:8180/v1/projects/${PROJECT}/databases/(default)/documents`;

interface Conta {
  uid: string;
  token: string;
}

interface Resposta {
  status: number;
  result?: { sessionId: string; videoPaths: Record<string, string>; created: boolean };
  error?: { message: string; details?: { field?: string } };
}

/** Cria uma conta no Auth do Emulator e devolve o token, como o app faria. */
async function criarConta(apelido: string): Promise<Conta> {
  const r = await fetch(`${AUTH}/accounts:signUp?key=demo`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: `${apelido}${Date.now()}@clippo.test`,
      password: "senha123",
      returnSecureToken: true,
    }),
  });
  const body = (await r.json()) as { idToken?: string; localId?: string };
  if (!body.idToken || !body.localId) {
    throw new Error(`não consegui criar a conta ${apelido}: ${JSON.stringify(body)}`);
  }
  return { uid: body.localId, token: body.idToken };
}

async function chamar(funcao: string, conta: Conta | null, data: unknown): Promise<Resposta> {
  const r = await fetch(`${FUNCTIONS}/${funcao}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(conta ? { Authorization: `Bearer ${conta.token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = (await r.json()) as Omit<Resposta, "status">;
  return { status: r.status, ...body };
}

/** Lê um documento COMO a pessoa: a API REST do Firestore passa pelas Security Rules. */
async function ler(caminho: string, conta?: Conta) {
  const r = await fetch(`${FIRESTORE}/${caminho}`, {
    headers: conta ? { Authorization: `Bearer ${conta.token}` } : {},
  });
  if (!r.ok) return null;
  const body = (await r.json()) as { fields?: Record<string, any> };
  return body.fields ?? {};
}

const texto = (campo: any) => campo?.stringValue as string | undefined;
const numero = (campo: any) => campo?.integerValue as string | undefined;

const SESSAO_ID = "sessao-e2e-0001";

/** O que o app manda no "Salvar sessão", com sujeira de propósito. */
const sessao = (extra: Record<string, unknown> = {}) => ({
  sessionId: SESSAO_ID,
  name: "  Pelada de   quinta ",
  startedAt: "2026-10-29T22:30:00.000Z",
  endedAt: "2026-10-30T00:12:00.000Z",
  location: "  Quadra do Parque ",
  participantIds: [] as string[],
  highlights: [
    // Segundos quebrados: é assim que o corte do buffer devolve.
    { highlightId: "lance-0001", offsetSeconds: 760.4, durationSeconds: 30 },
    {
      highlightId: "lance-0002",
      title: "  Voleio do Rafa ",
      offsetSeconds: 2100,
      durationSeconds: 28,
    },
  ],
  ...extra,
});

let alice: Conta;
let bob: Conta;
let carol: Conta;
let primeiraResposta: Resposta;

beforeAll(async () => {
  // Começa do zero: o id da sessão é fixo e colidiria com a rodada anterior.
  await fetch(`http://127.0.0.1:8180/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, {
    method: "DELETE",
  });

  [alice, bob, carol] = await Promise.all([
    criarConta("alice"),
    criarConta("bob"),
    criarConta("carol"),
  ]);

  await Promise.all([
    chamar("completeProfile", alice, {
      name: "Alice Prado",
      username: `alice${Date.now()}`.slice(0, 20),
      birthDate: "2001-02-28",
    }),
    chamar("completeProfile", bob, {
      name: "Bob Silva",
      username: `bob${Date.now()}`.slice(0, 20),
      birthDate: "2000-05-10",
    }),
  ]);

  primeiraResposta = await chamar("saveSession", alice, sessao({ participantIds: [bob.uid] }));
}, 60_000);

describe("saveSession — a resposta", () => {
  it("salva e avisa que criou", () => {
    expect(primeiraResposta.status).toBe(200);
    expect(primeiraResposta.result?.created).toBe(true);
  });

  it("devolve onde enviar o vídeo de cada lance", () => {
    expect(primeiraResposta.result?.videoPaths).toEqual({
      "lance-0001": `sessions/${SESSAO_ID}/highlights/lance-0001/video.mp4`,
      "lance-0002": `sessions/${SESSAO_ID}/highlights/lance-0002/video.mp4`,
    });
  });
});

describe("saveSession — o que foi gravado", () => {
  it("normaliza o nome e o local que a pessoa digitou", async () => {
    const s = await ler(`sessions/${SESSAO_ID}`, alice);
    expect(texto(s?.name)).toBe("Pelada de quinta");
    expect(texto(s?.location?.mapValue?.fields?.label)).toBe("Quadra do Parque");
  });

  it("calcula a duração no servidor, não confia no app", async () => {
    const s = await ler(`sessions/${SESSAO_ID}`, alice);
    expect(numero(s?.durationSeconds)).toBe("6120");
  });

  it("põe o dono como participante, em primeiro (R9)", async () => {
    const s = await ler(`sessions/${SESSAO_ID}`, alice);
    expect(texto(s?.ownerId)).toBe(alice.uid);
    expect(texto(s?.participantIds?.arrayValue?.values?.[0])).toBe(alice.uid);
    expect(numero(s?.participantCount)).toBe("2");
  });

  it("deixa os avatares prontos para a Início, com o nome de verdade", async () => {
    const s = await ler(`sessions/${SESSAO_ID}`, alice);
    const preview = s?.participantsPreview?.arrayValue?.values ?? [];
    expect(texto(preview[0]?.mapValue?.fields?.name)).toBe("Alice Prado");
    expect(texto(preview[1]?.mapValue?.fields?.name)).toBe("Bob Silva");
  });

  it("conta os lances", async () => {
    const s = await ler(`sessions/${SESSAO_ID}`, alice);
    expect(numero(s?.highlightCount)).toBe("2");
  });

  it("dá nome ao lance sem título e mantém o que foi escrito", async () => {
    const h1 = await ler(`sessions/${SESSAO_ID}/highlights/lance-0001`, alice);
    const h2 = await ler(`sessions/${SESSAO_ID}/highlights/lance-0002`, alice);
    expect(texto(h1?.title)).toBe("Lance 1");
    expect(texto(h2?.title)).toBe("Voleio do Rafa");
  });

  it("arredonda os segundos quebrados do buffer", async () => {
    const h1 = await ler(`sessions/${SESSAO_ID}/highlights/lance-0001`, alice);
    expect(numero(h1?.offsetSeconds)).toBe("760");
    expect(numero(h1?.durationSeconds)).toBe("30");
  });

  it("nasce como pending, esperando o vídeo subir (R13)", async () => {
    const h1 = await ler(`sessions/${SESSAO_ID}/highlights/lance-0001`, alice);
    expect(texto(h1?.status)).toBe("pending");
    expect(texto(h1?.videoPath)).toBe(`sessions/${SESSAO_ID}/highlights/lance-0001/video.mp4`);
  });
});

describe("saveSession — reenvio da fila offline (R13)", () => {
  it("aceitar de novo não duplica nada", async () => {
    const segunda = await chamar("saveSession", alice, sessao({ participantIds: [bob.uid] }));
    expect(segunda.status).toBe(200);
    expect(segunda.result?.created).toBe(false);

    const s = await ler(`sessions/${SESSAO_ID}`, alice);
    expect(numero(s?.highlightCount)).toBe("2");
  });
});

describe("saveSession — o que ele recusa", () => {
  it("sessão sem nome, dizendo qual campo marcar", async () => {
    const r = await chamar("saveSession", alice, sessao({ sessionId: "e2e-sem-nome", name: "  " }));
    expect(r.error?.message).toBe("Dê um nome para a sessão.");
    expect(r.error?.details?.field).toBe("name");
  });

  it("sessão que termina no futuro", async () => {
    const r = await chamar("saveSession", alice, sessao({
      sessionId: "e2e-futuro",
      startedAt: new Date(Date.now() - 600_000).toISOString(),
      endedAt: new Date(Date.now() + 3_600_000).toISOString(),
      highlights: [],
    }));
    expect(r.error?.message).toBe("A sessão não pode terminar no futuro.");
  });

  it("participante que não existe mais", async () => {
    const r = await chamar("saveSession", alice, sessao({
      sessionId: "e2e-fantasma",
      participantIds: ["ninguem-aqui-123"],
    }));
    expect(r.error?.message).toBe("Alguém da lista não está mais no Clippo.");
  });

  it("chamada sem login", async () => {
    const r = await chamar("saveSession", null, sessao({ sessionId: "e2e-sem-login" }));
    expect(r.error?.message).toBe("Entre na sua conta para salvar a sessão.");
  });

  it("tentativa de sobrescrever a sessão de outra pessoa", async () => {
    const r = await chamar("saveSession", bob, sessao());
    expect(r.error?.message).toBe("Essa sessão é de outra pessoa.");
  });

  it("nenhuma mensagem vaza termo técnico", async () => {
    const r = await chamar("saveSession", alice, sessao({ sessionId: "curto" }));
    expect(r.error?.message).not.toMatch(/undefined|Firebase|Exception|invalid|string/i);
  });
});

describe("as Security Rules em cima do que a Function gravou (R11)", () => {
  it("o dono e o participante leem a sessão", async () => {
    expect(await ler(`sessions/${SESSAO_ID}`, alice)).not.toBeNull();
    expect(await ler(`sessions/${SESSAO_ID}`, bob)).not.toBeNull();
  });

  it("quem não jogou não lê a sessão nem os lances", async () => {
    expect(await ler(`sessions/${SESSAO_ID}`, carol)).toBeNull();
    expect(await ler(`sessions/${SESSAO_ID}/highlights/lance-0001`, carol)).toBeNull();
  });

  it("visitante sem login não lê nada", async () => {
    expect(await ler(`sessions/${SESSAO_ID}`)).toBeNull();
  });
});
