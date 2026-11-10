/**
 * Ajudantes dos testes de ponta a ponta (Auth → Function → Firestore → regras), batendo
 * no Emulator como o app faria. Portas e região: backend/firebase.json e functions/src/config.ts.
 */
export const PROJECT = "demo-clippo";
export const REGION = "southamerica-east1";
const AUTH = `http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1`;
const FUNCTIONS = `http://127.0.0.1:5001/${PROJECT}/${REGION}`;
const FIRESTORE = `http://127.0.0.1:8180/v1/projects/${PROJECT}/databases/(default)/documents`;

export interface Conta {
  uid: string;
  token: string;
}

export interface Resposta<T = any> {
  status: number;
  result?: T;
  error?: { message: string; status?: string; details?: { field?: string } };
}

/** Cria uma conta no Auth do Emulator e devolve o token, como o app faria. */
export async function criarConta(apelido: string): Promise<Conta> {
  const r = await fetch(`${AUTH}/accounts:signUp?key=demo`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      email: `${apelido}${Date.now()}${Math.floor(Math.random() * 1000)}@clippo.test`,
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

export async function chamar<T = any>(funcao: string, conta: Conta | null, data: unknown): Promise<Resposta<T>> {
  const r = await fetch(`${FUNCTIONS}/${funcao}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      ...(conta ? { Authorization: `Bearer ${conta.token}` } : {}),
    },
    body: JSON.stringify({ data }),
  });
  const body = (await r.json()) as Omit<Resposta<T>, "status">;
  return { status: r.status, ...body };
}

/** Cria conta + perfil completo, com um @ único. Devolve a conta e o @. */
export async function criarPessoa(apelido: string, nome: string): Promise<Conta & { username: string }> {
  const conta = await criarConta(apelido);
  const username = `${apelido}${Date.now() % 1_000_000}${Math.floor(Math.random() * 100)}`.slice(0, 20);
  const r = await chamar("completeProfile", conta, { name: nome, username, birthDate: "2000-01-01" });
  if (r.status !== 200) throw new Error(`completeProfile falhou: ${JSON.stringify(r)}`);
  return { ...conta, username };
}

/** Faz os dois virarem amigos pelas Functions, como o app faria. */
export async function fazerAmigos(a: Conta & { username: string }, b: Conta & { username: string }) {
  const pedido = await chamar("sendFriendRequest", a, { username: b.username });
  if (pedido.status !== 200) throw new Error(`sendFriendRequest falhou: ${JSON.stringify(pedido)}`);
  const aceite = await chamar("acceptFriendRequest", b, { uid: a.uid });
  if (aceite.status !== 200) throw new Error(`acceptFriendRequest falhou: ${JSON.stringify(aceite)}`);
}

/** Lê um documento COMO a pessoa: a API REST do Firestore passa pelas Security Rules. */
export async function ler(caminho: string, conta?: Conta) {
  const r = await fetch(`${FIRESTORE}/${caminho}`, {
    headers: conta ? { Authorization: `Bearer ${conta.token}` } : {},
  });
  if (!r.ok) return null;
  const body = (await r.json()) as { fields?: Record<string, any> };
  return body.fields ?? {};
}

/** Lê ignorando as regras (como administrador do Emulator), para conferir o que foi gravado. */
export async function lerComoAdmin(caminho: string) {
  const r = await fetch(`${FIRESTORE}/${caminho}`, { headers: { Authorization: "Bearer owner" } });
  if (!r.ok) return null;
  const body = (await r.json()) as { fields?: Record<string, any> };
  return body.fields ?? {};
}

/** Apaga tudo do Firestore do Emulator. */
export async function limparFirestore() {
  await fetch(`http://127.0.0.1:8180/emulator/v1/projects/${PROJECT}/databases/(default)/documents`, {
    method: "DELETE",
  });
}

export const texto = (campo: any) => campo?.stringValue as string | undefined;
export const numero = (campo: any) => campo?.integerValue as string | undefined;
export const lista = (campo: any) =>
  ((campo?.arrayValue?.values ?? []) as any[]).map((v) => v.stringValue as string);
export const stat = (perfil: any, nome: string) => numero(perfil?.stats?.mapValue?.fields?.[nome]);
