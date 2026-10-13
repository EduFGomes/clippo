/**
 * Testes das regras do Firestore.
 *
 * Rode a partir de backend/tests com: npm test
 * (o comando sobe o Emulator, roda os testes e desliga o Emulator).
 *
 * Regra do time: toda mudança em firestore.rules vem com pelo menos um teste
 * de "pode" e um de "não pode".
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
import { doc, getDoc, setDoc } from "firebase/firestore";

let env: RulesTestEnvironment;

beforeAll(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-clippo",
    firestore: {
      // npm test roda dentro de backend/tests, então as regras ficam uma pasta acima.
      rules: readFileSync(resolve(process.cwd(), "../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8180,
    },
  });
});

afterAll(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // Dados de exemplo gravados "por fora" das regras, como a Function faria.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, "users/alice"), { name: "Alice", username: "alice" });
    await setDoc(doc(db, "usernames/alice"), { uid: "alice" });
    await setDoc(doc(db, "userPrivate/alice"), { birthDate: "2001-02-28" });
  });
});

describe("users/{uid} — perfil público", () => {
  it("usuário logado lê o perfil de outra pessoa", async () => {
    const db = env.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(db, "users/alice")));
  });

  it("visitante sem login não lê perfis", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "users/alice")));
  });

  it("nem o dono grava o próprio perfil pelo app (só a Function)", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(db, "users/alice"), { name: "Outro nome" }));
  });
});

describe("usernames/{username} — trava do @", () => {
  it("usuário logado consulta se um @ existe", async () => {
    const db = env.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(db, "usernames/alice")));
  });

  it("ninguém reserva um @ direto pelo app", async () => {
    const db = env.authenticatedContext("bob").firestore();
    await assertFails(setDoc(doc(db, "usernames/bob"), { uid: "bob" }));
  });
});

describe("userPrivate/{uid} — dados privados", () => {
  it("o dono lê os próprios dados privados", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertSucceeds(getDoc(doc(db, "userPrivate/alice")));
  });

  it("outra pessoa logada NÃO lê a data de nascimento de ninguém", async () => {
    const db = env.authenticatedContext("bob").firestore();
    await assertFails(getDoc(doc(db, "userPrivate/alice")));
  });
});

describe("o resto continua bloqueado", () => {
  it("usuário logado não grava em coleções sem regra", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(db, "sessions/qualquer"), { name: "Pelada de quinta" }));
  });
});
