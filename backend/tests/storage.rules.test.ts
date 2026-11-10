/**
 * Testes das regras do Storage (D17 em docs/arquitetura.md › Acesso aos vídeos no Storage).
 *
 * Rode a partir de backend/tests com: npm test
 * As regras do Storage leem o Firestore (firestore.get), então os dados de exemplo são
 * gravados no Firestore do Emulator, como o saveSession faria.
 */
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { afterAll, beforeAll, beforeEach, describe, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, setDoc } from "firebase/firestore";
import { deleteObject, getBytes, ref, uploadBytes } from "firebase/storage";

let env: RulesTestEnvironment;

const VIDEO = "sessions/quinta1/highlights/lance01/video.mp4";
const THUMB = "sessions/quinta1/highlights/lance01/thumb.jpg";
const UPLOADED_VIDEO = "sessions/quinta1/highlights/lance02/video.mp4";

const bytes = (n: number) => new Uint8Array(n);
const mp4 = { contentType: "video/mp4" };
const jpeg = { contentType: "image/jpeg" };

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-clippo",
    firestore: {
      rules: readFileSync(resolve(process.cwd(), "../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8180,
    },
    storage: {
      rules: readFileSync(resolve(process.cwd(), "../storage.rules"), "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // alice gravou; bob jogou junto; carol não.
    await setDoc(doc(db, "sessions/quinta1"), {
      ownerId: "alice",
      participantIds: ["alice", "bob"],
    });
    await setDoc(doc(db, "sessions/quinta1/highlights/lance01"), {
      createdBy: "alice",
      status: "pending",
    });
    await setDoc(doc(db, "sessions/quinta1/highlights/lance02"), {
      createdBy: "alice",
      status: "uploaded",
    });
    // Um vídeo que já subiu, para testar o download.
    await uploadBytes(ref(ctx.storage(), UPLOADED_VIDEO), bytes(10), mp4);
  });
});

describe("enviar o vídeo do lance", () => {
  it("quem gravou envia o MP4 de um lance pending", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertSucceeds(uploadBytes(ref(storage, VIDEO), bytes(1024), mp4));
  });

  it("outro participante NÃO envia vídeo no lance de quem gravou", async () => {
    const storage = env.authenticatedContext("bob").storage();
    await assertFails(uploadBytes(ref(storage, VIDEO), bytes(1024), mp4));
  });

  it("sem login, nada sobe", async () => {
    const storage = env.unauthenticatedContext().storage();
    await assertFails(uploadBytes(ref(storage, VIDEO), bytes(1024), mp4));
  });

  it("arquivo que não é MP4 é recusado", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(ref(storage, VIDEO), bytes(1024), { contentType: "text/html" }));
  });

  it("vídeo acima de 100 MB é recusado", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(ref(storage, VIDEO), bytes(100 * 1024 * 1024 + 1), mp4));
  });

  it("lance que já está uploaded não recebe outro vídeo", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(ref(storage, UPLOADED_VIDEO), bytes(1024), mp4));
  });

  it("lance que não existe no Firestore não recebe vídeo", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(
      uploadBytes(ref(storage, "sessions/quinta1/highlights/inventado/video.mp4"), bytes(1024), mp4),
    );
  });
});

describe("enviar a miniatura", () => {
  it("quem gravou envia o JPEG, mesmo com o vídeo já enviado", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertSucceeds(uploadBytes(ref(storage, THUMB), bytes(2048), jpeg));
    await assertSucceeds(
      uploadBytes(ref(storage, "sessions/quinta1/highlights/lance02/thumb.jpg"), bytes(2048), jpeg),
    );
  });

  it("miniatura acima de 1 MB ou que não é JPEG é recusada", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(ref(storage, THUMB), bytes(1024 * 1024 + 1), jpeg));
    await assertFails(uploadBytes(ref(storage, THUMB), bytes(10), { contentType: "image/svg+xml" }));
  });
});

describe("baixar o vídeo (R11)", () => {
  it("participante baixa o vídeo", async () => {
    const storage = env.authenticatedContext("bob").storage();
    await assertSucceeds(getBytes(ref(storage, UPLOADED_VIDEO)));
  });

  it("quem não participa NÃO baixa", async () => {
    const storage = env.authenticatedContext("carol").storage();
    await assertFails(getBytes(ref(storage, UPLOADED_VIDEO)));
  });

  it("sem login, NÃO baixa", async () => {
    const storage = env.unauthenticatedContext().storage();
    await assertFails(getBytes(ref(storage, UPLOADED_VIDEO)));
  });
});

describe("sobrescrever, apagar e outros caminhos", () => {
  it("nem quem gravou apaga o vídeo pelo app", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(deleteObject(ref(storage, UPLOADED_VIDEO)));
  });

  it("caminho fora do combinado é bloqueado", async () => {
    const storage = env.authenticatedContext("alice").storage();
    await assertFails(uploadBytes(ref(storage, "qualquer/coisa.mp4"), bytes(10), mp4));
    await assertFails(
      uploadBytes(ref(storage, "sessions/quinta1/highlights/lance01/outro.mp4"), bytes(10), mp4),
    );
  });
});
