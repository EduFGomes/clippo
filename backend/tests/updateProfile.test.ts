/**
 * Ponta a ponta do updateProfile (tela Perfil): troca de nome e @usuário, a trava do @ único
 * e as cópias do perfil em amizades (D16) e sessões (participantsPreview).
 *
 * Rode a partir de backend/tests com: npm run test:e2e
 */
import { beforeAll, describe, expect, it } from "vitest";

import { type Conta, chamar, criarConta, criarPessoa, fazerAmigos, ler, lerComoAdmin, texto } from "./e2e-helpers";

type Pessoa = Conta & { username: string };

let lia: Pessoa;
let max: Pessoa;
let noa: Pessoa;

const par = (a: Conta, b: Conta) => (a.uid < b.uid ? `${a.uid}_${b.uid}` : `${b.uid}_${a.uid}`);
const sufixo = () => `${Date.now() % 1_000_000}`;
const SESSAO = "e2e-perfil-sessao";

/** O nome/@ copiado na amizade para [quem]. */
async function copiaNaAmizade(a: Pessoa, b: Pessoa, quem: Pessoa) {
  const f = await ler(`friendships/${par(a, b)}`, a);
  const copia = f?.profiles?.mapValue?.fields?.[quem.uid]?.mapValue?.fields;
  return { name: texto(copia?.name), username: texto(copia?.username) };
}

/** Os nomes em participantsPreview, por uid. */
async function nomesNaSessao(conta: Conta) {
  const s = await ler(`sessions/${SESSAO}`, conta);
  const valores = (s?.participantsPreview?.arrayValue?.values ?? []) as any[];
  return Object.fromEntries(
    valores.map((v) => [texto(v.mapValue.fields.uid), texto(v.mapValue.fields.name)]),
  );
}

beforeAll(async () => {
  [lia, max, noa] = await Promise.all([
    criarPessoa("lia", "Lia Souza"),
    criarPessoa("max", "Max Prado"),
    criarPessoa("noa", "Noa Lima"),
  ]);
  await fazerAmigos(lia, max);
  // Pedido pendente: a cópia também precisa mudar.
  const pedido = await chamar("sendFriendRequest", noa, { username: lia.username });
  expect(pedido.status).toBe(200);
  const r = await chamar("saveSession", lia, {
    sessionId: SESSAO,
    name: "Pelada",
    startedAt: "2026-11-03T18:00:00.000Z",
    endedAt: "2026-11-03T19:00:00.000Z",
    participantIds: [max.uid],
    highlights: [],
  });
  expect(r.status).toBe(200);
}, 60_000);

describe("updateProfile", () => {
  it("muda o nome (normalizado) no perfil, na amizade, no pedido e na sessão", async () => {
    const r = await chamar("updateProfile", lia, { name: "  Lia   Souza Reis " });
    expect(r.status).toBe(200);
    expect(r.result).toEqual({ name: "Lia Souza Reis", username: lia.username });

    expect(texto((await ler(`users/${lia.uid}`, lia))?.name)).toBe("Lia Souza Reis");
    expect(await copiaNaAmizade(lia, max, lia)).toEqual({ name: "Lia Souza Reis", username: lia.username });
    expect((await copiaNaAmizade(lia, noa, lia)).name).toBe("Lia Souza Reis");
    const nomes = await nomesNaSessao(max);
    expect(nomes[lia.uid]).toBe("Lia Souza Reis");
    expect(nomes[max.uid]).toBe("Max Prado"); // a cópia do outro não muda
  });

  it("troca o @: libera o antigo, reserva o novo e atualiza a amizade", async () => {
    const antigo = lia.username;
    const novo = `lia.nova${sufixo()}`;
    const r = await chamar("updateProfile", lia, { username: ` @${novo.toUpperCase()} ` });
    expect(r.status).toBe(200);
    expect(r.result?.username).toBe(novo);
    lia = { ...lia, username: novo };

    expect(texto((await ler(`users/${lia.uid}`, lia))?.username)).toBe(novo);
    expect(texto((await ler(`usernames/${novo}`, max))?.uid)).toBe(lia.uid);
    expect(await lerComoAdmin(`usernames/${antigo}`)).toBeNull();
    expect((await copiaNaAmizade(lia, max, lia)).username).toBe(novo);

    // O @ antigo fica livre para outra pessoa e a amizade continua achando a Lia pelo novo.
    expect((await chamar("updateProfile", noa, { username: antigo })).status).toBe(200);
    expect(texto((await ler(`usernames/${antigo}`, lia))?.uid)).toBe(noa.uid);
  });

  it("recusa @ de outra pessoa sem mudar nada", async () => {
    const r = await chamar("updateProfile", lia, { name: "Outra Lia", username: max.username });
    expect(r.error?.message).toBe("Esse nome de usuário já está em uso.");
    expect(r.error?.details?.field).toBe("username");
    const perfil = await ler(`users/${lia.uid}`, lia);
    expect(texto(perfil?.name)).toBe("Lia Souza Reis");
    expect(texto(perfil?.username)).toBe(lia.username);
  });

  it("chamar de novo com o mesmo nome e @ não é erro", async () => {
    const r = await chamar("updateProfile", lia, { name: "Lia Souza Reis", username: lia.username });
    expect(r.status).toBe(200);
    expect(r.result).toEqual({ name: "Lia Souza Reis", username: lia.username });
    expect(texto((await ler(`usernames/${lia.username}`, lia))?.uid)).toBe(lia.uid);
  });

  it("valida como o cadastro, com o campo do erro", async () => {
    const nome = await chamar("updateProfile", lia, { name: "   " });
    expect(nome.error?.message).toBe("Informe seu nome.");
    expect(nome.error?.details?.field).toBe("name");
    const usuario = await chamar("updateProfile", lia, { username: "ra..fa" });
    expect(usuario.error?.message).toBe("O ponto não pode ficar no começo, no fim ou repetido.");
    expect(usuario.error?.details?.field).toBe("username");
    expect((await chamar("updateProfile", lia, {})).error?.message)
      .toBe("Informe o nome ou o nome de usuário.");
  });

  it("sem login ou sem perfil, nada", async () => {
    expect((await chamar("updateProfile", null, { name: "X" })).error?.message)
      .toBe("Entre na sua conta para continuar.");
    const semPerfil = await criarConta("semperfil");
    expect((await chamar("updateProfile", semPerfil, { name: "X" })).error?.message)
      .toBe("Complete seu perfil antes de editar.");
  });
});
