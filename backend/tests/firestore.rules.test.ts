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
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  where,
} from "firebase/firestore";

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

    // Sessão de quinta: alice (dona) e bob jogaram. A carol não.
    await setDoc(doc(db, "sessions/quinta"), {
      name: "Pelada de quinta",
      ownerId: "alice",
      participantIds: ["alice", "bob"],
      startedAt: new Date("2026-10-15T22:30:00Z"),
      highlightCount: 1,
    });
    await setDoc(doc(db, "sessions/quinta/highlights/lance1"), {
      title: "Lance 1",
      offsetSeconds: 760,
      durationSeconds: 30,
      status: "uploaded",
    });
    // Sessão de outra turma, para a consulta da Início ter o que NÃO devolver.
    await setDoc(doc(db, "sessions/sabado"), {
      name: "Vôlei de sábado",
      ownerId: "carol",
      participantIds: ["carol"],
      startedAt: new Date("2026-10-17T14:00:00Z"),
      highlightCount: 0,
    });
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

describe("sessions/{sessionId} — a sessão só é vista por quem jogou (R11)", () => {
  it("participante lê a sessão", async () => {
    const db = env.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(db, "sessions/quinta")));
  });

  it("quem não participa NÃO lê a sessão", async () => {
    const db = env.authenticatedContext("carol").firestore();
    await assertFails(getDoc(doc(db, "sessions/quinta")));
  });

  it("visitante sem login não lê sessão", async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, "sessions/quinta")));
  });

  it("a consulta da Início devolve só as minhas sessões", async () => {
    const db = env.authenticatedContext("bob").firestore();
    const minhas = query(
      collection(db, "sessions"),
      where("participantIds", "array-contains", "bob"),
      orderBy("startedAt", "desc"),
    );
    const snap = await assertSucceeds(getDocs(minhas));
    expect(snap.docs.map((d) => d.id)).toEqual(["quinta"]);
  });

  it("listar sessions SEM filtrar por participantIds falha", async () => {
    // Por que: as regras valem documento por documento, então a consulta inteira
    // é recusada ao encontrar a sessão de sábado, que não é do bob.
    const db = env.authenticatedContext("bob").firestore();
    await assertFails(getDocs(collection(db, "sessions")));
  });

  it("ninguém grava sessão pelo app (🟡 decisão de escrita em aberto)", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(db, "sessions/nova"), {
      name: "Pelada de sexta",
      ownerId: "alice",
      participantIds: ["alice"],
    }));
  });
});

describe("sessions/{id}/highlights — a permissão vem da sessão", () => {
  it("participante lê os highlights da sessão", async () => {
    const db = env.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(db, "sessions/quinta/highlights/lance1")));
  });

  it("participante lista os highlights em ordem", async () => {
    const db = env.authenticatedContext("alice").firestore();
    const lances = query(
      collection(db, "sessions/quinta/highlights"),
      orderBy("offsetSeconds", "asc"),
    );
    await assertSucceeds(getDocs(lances));
  });

  it("quem não participa NÃO lê os highlights", async () => {
    const db = env.authenticatedContext("carol").firestore();
    await assertFails(getDoc(doc(db, "sessions/quinta/highlights/lance1")));
  });

  it("ninguém grava highlight pelo app (🟡 decisão de escrita em aberto)", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(db, "sessions/quinta/highlights/lance2"), { title: "Lance 2" }),
    );
  });
});

describe("o resto continua bloqueado", () => {
  it("usuário logado não grava em coleções sem regra", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(setDoc(doc(db, "friendships/qualquer"), { uids: ["alice", "bob"] }));
  });

  it("usuário logado não lê coleções sem regra", async () => {
    const db = env.authenticatedContext("alice").firestore();
    await assertFails(getDoc(doc(db, "friendships/qualquer")));
  });
});
