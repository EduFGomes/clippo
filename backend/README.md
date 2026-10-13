# Clippo — backend (Firebase)

Aqui fica tudo o que roda do lado do servidor do Clippo. **Não existe API própria**: o app fala direto com o Firebase, e este diretório guarda o que protege e complementa isso.

| Caminho | O que é | Dono principal |
|---|---|---|
| `firestore.rules` | Quem pode ler e gravar cada documento do Firestore | Back-end |
| `storage.rules` | Quem pode enviar e baixar vídeos e miniaturas | Back-end |
| `firestore.indexes.json` | Índices das consultas do app | Back-end |
| `functions/` | Cloud Functions em TypeScript (uma pasta por domínio) | Quem pegar cada função |
| `tests/` | Testes das regras no Emulator | Todos que mexem em regras |
| `firebase.json` / `.firebaserc` | Configuração do projeto e dos emuladores | Back-end |

> Estado atual: **tudo bloqueado**. As regras liberam acesso conforme o modelo de dados for definido. As funções ainda são só o esqueleto.

## Pré-requisitos (uma vez por máquina)

1. **Node.js 22** — <https://nodejs.org>
2. **Java 21 ou mais novo** (o Emulator precisa; a Firebase CLI atual recusa versões anteriores) — por exemplo o Temurin: <https://adoptium.net>
3. **Firebase CLI**: `npm install -g firebase-tools`
4. Login (só necessário para o projeto real): `firebase login`

## Rodar tudo localmente (sem gastar nada)

O projeto padrão é `demo-clippo`. Projetos com prefixo `demo-` existem **só no Emulator**: não precisam de conta, cartão nem internet.

```bash
cd backend/functions
npm install
npm run build

cd ..
firebase emulators:start
```

Abra a interface do Emulator em <http://localhost:4000> para ver usuários, documentos, arquivos e logs das funções.

Portas: Auth 9099 · **Firestore 8180** (não a 8080 padrão, que costuma estar ocupada no Windows) · Storage 9199 · Functions 5001 · interface 4000. Se mudar alguma, mude também em `tests/firestore.rules.test.ts` e em `app/lib/core/firebase/firebase_setup.dart`.

`npm test` (em `tests/`) e `firebase emulators:start` não podem rodar ao mesmo tempo: os dois abrem as mesmas portas.

## Rodar os testes das Functions (sem Emulator)

```bash
cd backend/functions
npm test
```

## Rodar os testes das regras

```bash
cd backend/tests
npm install
npm test
```

O `npm test` sobe o Emulator, roda os testes e desliga.

**Regra do time:** toda mudança em `firestore.rules` ou `storage.rules` vem com pelo menos um teste de "pode" e um de "não pode", e passa por revisão de outra pessoa.

## Como escrever uma Cloud Function

1. Escolha o domínio: `users/`, `friends/`, `sessions/`, `highlights/` ou `maintenance/`.
2. Crie um arquivo com o nome da função (ex.: `highlights/onHighlightCreated.ts`).
3. Exporte a função no `index.ts` **do domínio** (não no `src/index.ts`).
4. Use `db()` e `bucket()` de `shared/admin.ts`. Lembre: o Admin SDK **ignora as Security Rules**, então valide tudo o que a função grava.
5. Gatilhos podem rodar mais de uma vez para o mesmo evento: escreva de forma **idempotente**.
6. Nada do caminho crítico do gesto (salvar o highlight em até 3 s) pode depender de uma função: elas podem levar alguns segundos para "acordar".
7. Teste no Emulator antes de abrir o PR.

A região fica em `functions/src/config.ts` e vale para todas as funções.

## Catálogo de funções (rascunho)

Será ajustado quando o modelo de dados estiver definido.

| Função | Gatilho | O que faz | Requisito |
|---|---|---|---|
| `completeProfile` ✅ | Chamada pelo app | Cria `users/{uid}`, reserva `usernames/{username}` e guarda a data de nascimento em `userPrivate/{uid}`, numa transação | Conta e perfil |
| `onHighlightCreated` | Highlight criado no Firestore | Atualiza contadores e avisa os participantes por push | R16, Perfil |
| `onVideoUploaded` | Vídeo chegou no Storage | Confere tamanho/formato; marca o highlight como "enviado" | R13 |
| `acceptFriendInvite` | Chamada pelo app | Grava a amizade nos dois perfis de uma vez | R15 🟡 |
| `deleteMyAccount` | Chamada pelo app | Apaga ou anonimiza os dados da pessoa | LGPD |
| `cleanupOldVideos` | Agendada (todo dia) | Apaga vídeos antigos, se a retenção for ligada | Custo |

Em aberto: validar R10 (participantes são amigos do dono) nas regras ou numa função `createSession`.

## Projeto real e deploy (depois)

Quando o projeto `clippo-dev` existir no console do Firebase:

```bash
cd backend
firebase use --add          # escolha clippo-dev e dê o apelido "dev"
firebase deploy --only firestore:rules,storage   # regras
firebase deploy --only functions                 # funções
```

Antes do primeiro deploy: plano **Blaze** ativo e **alerta de orçamento** configurado no Google Cloud.

## Segurança

- Nunca versione chaves de conta de serviço (`*-adminsdk-*.json`): o `.gitignore` da raiz já bloqueia.
- O `google-services.json` do app **não é segredo**; a proteção vem das regras e do App Check.
- Segredos de funções (se um dia houver) vão no Secret Manager: `firebase functions:secrets:set NOME`.
