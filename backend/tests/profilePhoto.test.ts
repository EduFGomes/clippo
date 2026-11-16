/**
 * Ponta a ponta da foto do perfil (12/11/2026): o app envia para users/{uid}/avatar no Storage
 * (regras de verdade do Emulator) e chama setProfilePhoto, que grava o endereço no perfil e nas
 * cópias (amizade e participantsPreview). Tirar a foto volta para null.
 *
 * Rode a partir de backend/tests com: npm run test:e2e
 */
import { beforeAll, describe, expect, it } from "vitest";

import { PROJECT, type Conta, chamar, criarPessoa, fazerAmigos, ler, texto } from "./e2e-helpers";

type Pessoa = Conta & { username: string };

const BUCKET = `${PROJECT}.appspot.com`;
const STORAGE = `http://127.0.0.1:9199/v0/b/${BUCKET}/o`;
const SESSAO = "e2e-foto-sessao";

let ana: Pessoa;
let leo: Pessoa;

const par = (a: Conta, b: Conta) => (a.uid < b.uid ? `${a.uid}_${b.uid}` : `${b.uid}_${a.uid}`);

/** Envia como o app (SDK do Storage), passando pelas regras do Emulator. */
async function enviarFoto(conta: Conta, dono: string, bytes: number, contentType: string) {
  const r = await fetch(`${STORAGE}?name=${encodeURIComponent(`users/${dono}/avatar`)}`, {
    method: "POST",
    headers: { Authorization: `Firebase ${conta.token}`, "Content-Type": contentType },
    body: new Uint8Array(bytes),
  });
  return r.status;
}

const fotoNoPerfil = async (p: Pessoa) => texto((await ler(`users/${p.uid}`, p))?.photoUrl);

beforeAll(async () => {
  [ana, leo] = await Promise.all([criarPessoa("ana", "Ana Lima"), criarPessoa("leo", "Leo Dias")]);
  await fazerAmigos(ana, leo);
  const r = await chamar("saveSession", ana, {
    sessionId: SESSAO,
    name: "Pelada",
    startedAt: "2026-11-03T18:00:00.000Z",
    endedAt: "2026-11-03T19:00:00.000Z",
    participantIds: [leo.uid],
    highlights: [],
  });
  expect(r.status).toBe(200);
}, 60_000);

describe("setProfilePhoto", () => {
  it("sem foto enviada, recusa no campo da foto", async () => {
    const r = await chamar("setProfilePhoto", ana, {});
    expect(r.status).toBe(400);
    expect(r.error?.details?.field).toBe("photo");
  });

  it("ninguém envia a foto de outra pessoa (regra do Storage)", async () => {
    expect(await enviarFoto(leo, ana.uid, 100, "image/jpeg")).toBe(403);
  });

  it("enviada a foto, grava o endereço no perfil, na amizade e na sessão", async () => {
    expect(await enviarFoto(ana, ana.uid, 2048, "image/jpeg")).toBe(200);
    const r = await chamar("setProfilePhoto", ana, {});
    expect(r.status).toBe(200);
    const url = r.result?.photoUrl as string;
    expect(url).toContain(`/o/${encodeURIComponent(`users/${ana.uid}/avatar`)}?alt=media&token=`);

    expect(await fotoNoPerfil(ana)).toBe(url);
    const amizade = await ler(`friendships/${par(ana, leo)}`, leo);
    expect(texto(amizade?.profiles?.mapValue?.fields?.[ana.uid]?.mapValue?.fields?.photoUrl)).toBe(url);
    const sessao = await ler(`sessions/${SESSAO}`, leo);
    const preview = (sessao?.participantsPreview?.arrayValue?.values ?? []) as any[];
    const dela = preview.find((v) => texto(v.mapValue.fields.uid) === ana.uid);
    expect(texto(dela?.mapValue?.fields?.photoUrl)).toBe(url);

    // O endereço abre a foto (quem recebe o link vê).
    expect((await fetch(url)).status).toBe(200);
  });

  it("tirar a foto apaga e volta para null em todo lugar", async () => {
    const r = await chamar("setProfilePhoto", ana, { remove: true });
    expect(r.status).toBe(200);
    expect(r.result?.photoUrl).toBeNull();
    expect(await fotoNoPerfil(ana)).toBeUndefined();
    const amizade = await ler(`friendships/${par(ana, leo)}`, leo);
    expect(amizade?.profiles?.mapValue?.fields?.[ana.uid]?.mapValue?.fields?.photoUrl?.nullValue).toBe(null);
  });

  it("pedido com remove que não é booleano é recusado", async () => {
    const r = await chamar("setProfilePhoto", ana, { remove: "sim" });
    expect(r.status).toBe(400);
  });
});
