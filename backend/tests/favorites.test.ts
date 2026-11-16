/**
 * Ponta a ponta dos favoritos (R18–R22, D19): favoritar copia o vídeo para posts/{id}/, os
 * amigos de quem favoritou assistem, curtem e comentam pelas Functions e regras do Emulator, e o
 * favorito some junto com o lance ou quando a pessoa sai da sessão.
 *
 * Rode a partir de backend/tests com: npm run test:e2e
 */
import { beforeAll, describe, expect, it } from "vitest";

import { PROJECT, type Conta, chamar, criarPessoa, fazerAmigos, ler, lerComoAdmin, numero, texto } from "./e2e-helpers";

type Pessoa = Conta & { username: string };

const STORAGE = `http://127.0.0.1:9199/v0/b/${PROJECT}.appspot.com/o`;
const SESSAO = "e2e-fav-sessao";
const LANCE = "e2e-fav-lance1";
const LANCE_PENDENTE = "e2e-fav-lance2";
const LANCE_APAGAR = "e2e-fav-lance3";

// ana grava; leo joga junto; bia é amiga do leo e da ana, mas não jogou; caio não é amigo de ninguém.
let ana: Pessoa;
let leo: Pessoa;
let bia: Pessoa;
let caio: Pessoa;

const postDo = (p: Conta, lance: string) => `${p.uid}__${SESSAO}__${lance}`;

/** Põe o MP4 como administrador: o gatilho onVideoUploaded marca o lance `uploaded`. */
async function porVideo(lance: string) {
  const caminho = `sessions/${SESSAO}/highlights/${lance}/video.mp4`;
  const r = await fetch(`${STORAGE}?name=${encodeURIComponent(caminho)}`, {
    method: "POST",
    headers: { Authorization: "Bearer owner", "Content-Type": "video/mp4" },
    body: new Uint8Array([0, 0, 0, 24, 102, 116, 121, 112]),
  });
  expect(r.ok).toBe(true);
}

/** Baixa como a pessoa, pelas regras do Storage. */
async function baixar(conta: Conta, caminho: string) {
  const r = await fetch(`${STORAGE}/${encodeURIComponent(caminho)}?alt=media`, {
    headers: { Authorization: `Firebase ${conta.token}` },
  });
  return r.status;
}

async function existeArquivo(caminho: string) {
  const r = await fetch(`${STORAGE}/${encodeURIComponent(caminho)}`, { headers: { Authorization: "Bearer owner" } });
  return r.ok;
}

/** Espera um gatilho terminar (até ~10 s). */
async function esperar(condicao: () => Promise<boolean>) {
  for (let i = 0; i < 50; i++) {
    if (await condicao()) return;
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error("o gatilho não terminou a tempo");
}

const statusDoLance = async (lance: string) =>
  texto((await lerComoAdmin(`sessions/${SESSAO}/highlights/${lance}`))?.status);

beforeAll(async () => {
  [ana, leo, bia, caio] = await Promise.all([
    criarPessoa("ana", "Ana Lima"),
    criarPessoa("leo", "Leo Dias"),
    criarPessoa("bia", "Bia Prado"),
    criarPessoa("caio", "Caio Nunes"),
  ]);
  await fazerAmigos(ana, leo);
  await fazerAmigos(leo, bia);
  await fazerAmigos(ana, bia);
  const r = await chamar("saveSession", ana, {
    sessionId: SESSAO,
    name: "Pelada secreta",
    startedAt: "2026-11-03T18:00:00.000Z",
    endedAt: "2026-11-03T19:00:00.000Z",
    location: "Quadra do Parque",
    participantIds: [leo.uid],
    highlights: [
      { highlightId: LANCE, offsetSeconds: 60, durationSeconds: 30 },
      { highlightId: LANCE_PENDENTE, offsetSeconds: 120, durationSeconds: 30 },
      { highlightId: LANCE_APAGAR, offsetSeconds: 180, durationSeconds: 30 },
    ],
  });
  expect(r.status).toBe(200);
  await porVideo(LANCE);
  await porVideo(LANCE_APAGAR);
  await esperar(async () => (await statusDoLance(LANCE)) === "uploaded");
  await esperar(async () => (await statusDoLance(LANCE_APAGAR)) === "uploaded");
}, 90_000);

describe("favoritar (R18)", () => {
  it("quem não jogou a sessão não favorita", async () => {
    const r = await chamar("favoriteHighlight", bia, { sessionId: SESSAO, highlightId: LANCE });
    expect(r.status).toBe(403);
  });

  it("lance que ainda não subiu não é favoritado", async () => {
    const r = await chamar("favoriteHighlight", leo, { sessionId: SESSAO, highlightId: LANCE_PENDENTE });
    expect(r.status).toBe(400);
    expect(r.error?.message).toBe("Esse lance ainda está sendo enviado. Favorite depois que ele subir.");
  });

  it("id fora do formato é recusado no campo", async () => {
    const r = await chamar("favoriteHighlight", leo, { sessionId: "x", highlightId: LANCE });
    expect(r.status).toBe(400);
    expect(r.error?.details?.field).toBe("sessionId");
  });

  it("o participante favorita; de novo não duplica; o vídeo é copiado", async () => {
    const primeira = await chamar("favoriteHighlight", leo, { sessionId: SESSAO, highlightId: LANCE });
    expect(primeira.status).toBe(200);
    expect(primeira.result?.postId).toBe(postDo(leo, LANCE));
    const segunda = await chamar("favoriteHighlight", leo, { sessionId: SESSAO, highlightId: LANCE });
    expect(segunda.status).toBe(200);

    const lance = await lerComoAdmin(`sessions/${SESSAO}/highlights/${LANCE}`);
    expect(numero(lance?.favoriteCount)).toBe("1");
    expect(await existeArquivo(`posts/${postDo(leo, LANCE)}/video.mp4`)).toBe(true);
  });

  it("o favorito mostra o lance e quem favoritou, sem a sessão (R20)", async () => {
    const post = await ler(`posts/${postDo(leo, LANCE)}`, leo);
    expect(texto(post?.ownerId)).toBe(leo.uid);
    expect(texto(post?.title)).toBe("Lance 1");
    expect(texto(post?.owner?.mapValue?.fields?.name)).toBe("Leo Dias");
    expect(post?.name).toBeUndefined();
    expect(post?.location).toBeUndefined();
    expect(post?.participantIds).toBeUndefined();
  });
});

describe("quem vê (R19)", () => {
  it("a amiga de quem favoritou lê e assiste, sem ver a sessão", async () => {
    expect(await ler(`posts/${postDo(leo, LANCE)}`, bia)).not.toBeNull();
    expect(await baixar(bia, `posts/${postDo(leo, LANCE)}/video.mp4`)).toBe(200);
    expect(await ler(`sessions/${SESSAO}`, bia)).toBeNull();
    expect(await baixar(bia, `sessions/${SESSAO}/highlights/${LANCE}/video.mp4`)).toBe(403);
  });

  it("quem não é amigo não lê nem assiste", async () => {
    expect(await ler(`posts/${postDo(leo, LANCE)}`, caio)).toBeNull();
    expect(await baixar(caio, `posts/${postDo(leo, LANCE)}/video.mp4`)).toBe(403);
  });
});

describe("curtir e comentar (R19, R22)", () => {
  const post = () => postDo(leo, LANCE);

  it("a amiga curte uma vez só e descurte", async () => {
    expect((await chamar("likePost", bia, { postId: post(), liked: true })).result?.likeCount).toBe(1);
    expect((await chamar("likePost", bia, { postId: post(), liked: true })).result?.likeCount).toBe(1);
    expect(numero((await lerComoAdmin(`posts/${post()}`))?.likeCount)).toBe("1");
    expect((await chamar("likePost", bia, { postId: post(), liked: false })).result?.likeCount).toBe(0);
  });

  it("quem não é amigo não curte nem comenta", async () => {
    expect((await chamar("likePost", caio, { postId: post(), liked: true })).status).toBe(403);
    const r = await chamar("addComment", caio, { postId: post(), commentId: "c-caio01", text: "Oi" });
    expect(r.status).toBe(403);
  });

  it("comentário vazio ou longo demais é recusado no campo, com a mesma frase do app", async () => {
    const vazio = await chamar("addComment", bia, { postId: post(), commentId: "c-bia001", text: "   " });
    expect(vazio.status).toBe(400);
    expect(vazio.error?.details?.field).toBe("text");
    expect(vazio.error?.message).toBe("Escreva um comentário.");
    const longo = await chamar("addComment", bia, { postId: post(), commentId: "c-bia001", text: "a".repeat(301) });
    expect(longo.error?.message).toBe("O comentário pode ter até 300 caracteres.");
  });

  it("a amiga comenta; repetir a chamada não duplica; o autor e quem favoritou apagam", async () => {
    const r = await chamar("addComment", bia, { postId: post(), commentId: "c-bia001", text: "  Que golaço!  " });
    expect(r.status).toBe(200);
    await chamar("addComment", bia, { postId: post(), commentId: "c-bia001", text: "Que golaço!" });
    const comentario = await ler(`posts/${post()}/comments/c-bia001`, ana);
    expect(texto(comentario?.text)).toBe("Que golaço!");
    expect(numero((await lerComoAdmin(`posts/${post()}`))?.commentCount)).toBe("1");

    // A ana vê, mas não apaga o comentário da bia no favorito do leo.
    expect((await chamar("deleteComment", ana, { postId: post(), commentId: "c-bia001" })).status).toBe(403);
    expect((await chamar("deleteComment", leo, { postId: post(), commentId: "c-bia001" })).status).toBe(200);
    expect(numero((await lerComoAdmin(`posts/${post()}`))?.commentCount)).toBe("0");
  });
});

describe("o favorito acompanha o lance (R21)", () => {
  it("renomear o lance troca o título do favorito", async () => {
    expect((await chamar("renameHighlight", ana, { sessionId: SESSAO, highlightId: LANCE, title: "Golaço" })).status).toBe(200);
    expect(texto((await lerComoAdmin(`posts/${postDo(leo, LANCE)}`))?.title)).toBe("Golaço");
  });

  it("desfavoritar apaga o favorito, os comentários e a cópia", async () => {
    await chamar("favoriteHighlight", ana, { sessionId: SESSAO, highlightId: LANCE });
    await chamar("addComment", bia, { postId: postDo(ana, LANCE), commentId: "c-bia002", text: "Top" });
    const r = await chamar("unfavoriteHighlight", ana, { sessionId: SESSAO, highlightId: LANCE });
    expect(r.status).toBe(200);
    expect(await lerComoAdmin(`posts/${postDo(ana, LANCE)}`)).toBeNull();
    expect(await lerComoAdmin(`posts/${postDo(ana, LANCE)}/comments/c-bia002`)).toBeNull();
    expect(await existeArquivo(`posts/${postDo(ana, LANCE)}/video.mp4`)).toBe(false);
    // De novo não é erro.
    expect((await chamar("unfavoriteHighlight", ana, { sessionId: SESSAO, highlightId: LANCE })).status).toBe(200);
  });

  it("o dono apaga o lance: o favorito some junto", async () => {
    expect((await chamar("favoriteHighlight", leo, { sessionId: SESSAO, highlightId: LANCE_APAGAR })).status).toBe(200);
    expect((await chamar("deleteHighlight", ana, { sessionId: SESSAO, highlightId: LANCE_APAGAR })).status).toBe(200);
    await esperar(async () => (await lerComoAdmin(`posts/${postDo(leo, LANCE_APAGAR)}`)) === null);
    await esperar(async () => !(await existeArquivo(`posts/${postDo(leo, LANCE_APAGAR)}/video.mp4`)));
  });

  it("quem favoritou sai da sessão: o favorito dele some", async () => {
    expect(await lerComoAdmin(`posts/${postDo(leo, LANCE)}`)).not.toBeNull();
    expect((await chamar("leaveSession", leo, { sessionId: SESSAO })).status).toBe(200);
    await esperar(async () => (await lerComoAdmin(`posts/${postDo(leo, LANCE)}`)) === null);
    const lance = await lerComoAdmin(`sessions/${SESSAO}/highlights/${LANCE}`);
    expect(numero(lance?.favoriteCount)).toBe("0");
  });
});
