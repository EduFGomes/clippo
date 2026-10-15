# Arquitetura

Como o Clippo é construído e como contribuir. O que o app faz está em [produto.md](produto.md); como ele parece, em [design.md](design.md). As regras curtas que valem para todo código (inclusive o escrito por IA) estão no [`AGENTS.md`](../AGENTS.md); instalação e como rodar, no [README da raiz](../README.md).

Este documento registra **as decisões técnicas já tomadas**, o porquê de cada uma e o **modelo de dados atual**. Antes de mudar qualquer item daqui, leve ao grupo.

## Em uma frase

App Flutter que detecta o gesto **no próprio celular** + Firebase (Auth, Firestore, Storage, Cloud Functions) **sem API própria**. As regras de acesso ficam nas Security Rules; o que precisa de validação ou lógica de servidor fica em Cloud Functions.

```
Celular de quem grava                      Firebase (us-east1)                     Outros participantes
┌───────────────────────┐   upload    ┌──────────────────────────────┐   leem   ┌──────────────────┐
│ Câmera → buffer 30 s  │ ──────────► │ Security Rules + App Check   │ ───────► │ app (Início,     │
│ → detector de pose    │             │ Auth · Firestore · Storage   │          │ Sessão, Player)  │
│ → highlight (local)   │             │ Cloud Functions (gatilhos e  │          └──────────────────┘
└───────────────────────┘             │ chamáveis, em backend/)      │
     a partida não sai daqui          └──────────────────────────────┘
```

## Decisões

| # | Decisão | Por quê | O que abrimos mão |
|---|---|---|---|
| D1 | **Detecção do gesto no celular** (modelo de pose pronto + regra geométrica) | R6 e R8 (o buffer não sai do aparelho; não depende de internet); internet ruim na quadra; dados, bateria e privacidade (LGPD) | Modelos pesados de servidor; mudar a regra exige nova versão do app (mitigação: limites ajustáveis remotamente) |
| D2 | **Firebase sem API própria** | 5 pessoas × ~6 h/semana; login, upload offline e sincronização prontos; custo ~zero no MVP | Dependência do Google; regras viram código crítico; Firestore sem JOIN |
| D3 | **Cloud Functions em TypeScript** | Mesmo ambiente das Functions e dos testes de regras; todos os gatilhos disponíveis; mais exemplos | Curva inicial para quem não conhece TS |
| D4 | **Região `us-east1`** para Firestore, Storage e Functions | Cota gratuita do Storage só existe em regiões dos EUA; a região do Firestore **não muda depois** | ~100 ms a mais de latência; dados fora do Brasil (citar na política de privacidade) |
| D5 | **App organizado por funcionalidade** (`lib/features/`) | Cada pessoa trabalha na sua pasta; menos conflito | Exige combinar o que vai em `lib/core/` |
| D6 | **Desenvolvimento no Emulator** (`demo-clippo`) | Sem custo, sem conta, sem risco de mexer em dados reais | Dados de cada um ficam só na máquina de cada um |
| D7 | **O app não grava dados validados**; só Functions gravam | Ninguém pula a validação mexendo no app | Toda escrita nova precisa de uma Function |
| D8 | **Fontes embutidas no app** (Anton e Archivo em `app/assets/fonts/`, sem o pacote `google_fonts`) | Funciona sem internet na quadra; nada é baixado na primeira abertura | ~1 MB a mais no app |
| D9 | **Valores visuais só em `clippo_tokens.dart`** (sem JSON paralelo) | Uma fonte só evita divergência entre docs e código | Quem não usa Flutter lê os valores pelo [design.md](design.md) |

Custos estimados e alternativas descartadas (API de visão computacional, backend próprio): documento da proposta apresentado ao grupo.

## Modelo de dados (Firestore)

Estado atual. Coleções novas entram aqui **antes** de serem implementadas.

| Coleção / documento | Campos | Quem lê | Quem grava |
|---|---|---|---|
| `users/{uid}` — perfil público | `name` string · `username` string · `photoUrl` string\|null · `stats` {`sessions`, `highlights`, `friends`} números · `createdAt` timestamp | Qualquer usuário logado | Só Functions (`completeProfile`) |
| `usernames/{username}` — trava do @ único | `uid` string · `createdAt` timestamp | Qualquer usuário logado | Só Functions (`completeProfile`) |
| `userPrivate/{uid}` — dados privados | `birthDate` string `AAAA-MM-DD` · `createdAt` timestamp | Só o dono | Só Functions (`completeProfile`) |

Regras de modelagem:
- O **e-mail fica só no Firebase Auth**, nunca no Firestore.
- Dado pessoal só com finalidade clara (LGPD, minimização). A data de nascimento existe só para estatísticas agregadas.
- `@usuário` normalizado: minúsculas, 3–20 caracteres, `a–z 0–9 _ .`, sem ponto no começo/fim nem `..`.
- Unicidade garantida pelo **ID do documento** em `usernames/`, criado dentro de transação (sem condição de corrida).

🟡 **Ainda não modelado:** `Session`, `Participant`, `Highlight`, `Friendship`. É o próximo passo do back-end — a tela Início precisa listar "as sessões de que eu participo".

## Quem faz o quê

| Camada | Responsabilidade |
|---|---|
| **App** | Telas, câmera, buffer, detecção, upload. Lê o Firestore direto. Chama Functions para gravar. |
| **Security Rules** | Porteiro: decide cada leitura (e bloqueia escritas do app). Testadas em `backend/tests/`. |
| **Functions chamáveis** | Ações do usuário que precisam de validação no servidor (ex.: `completeProfile`). |
| **Functions de gatilho** | Efeitos colaterais de eventos: contadores, notificações, limpeza. Idempotentes. |

O catálogo de funções planejadas está no [`backend/README.md`](../backend/README.md#catálogo-de-funções-rascunho).

## Ambientes

| | Emulator (`demo-clippo`) | Projeto real (`clippo-dev`) |
|---|---|---|
| Para quê | Todo o desenvolvimento e os testes | Testes em quadra, upload por 4G, demo |
| Custo | Zero | Plano Blaze com alerta de orçamento |
| Status | Em uso | 🟡 ainda não criado |
| Como o app escolhe | Padrão | `--dart-define=USE_EMULATOR=false` (depois de `flutterfire configure`) |

Portas, IP do Emulator no celular e região: [`AGENTS.md` › Ambiente local](../AGENTS.md#ambiente-local).

## Decisões em aberto 🟡

| Tema | Quem decide |
|---|---|
| Gerenciamento de estado no app (Provider, Riverpod, Bloc…) | Front-end |
| Navegação de nível superior: barra (protótipo v1) ou roda (protótipo v2, [link em design.md](design.md#7-referências-no-claude)) | Grupo |
| Modelo de Sessão, Participante, Highlight e Amizade | Back-end + grupo |
| Validar "participantes são amigos do dono" (R10): regras ou Function `createSession` | Back-end |
| Login com Google (precisa do projeto real) | Back-end |
| Recuperação de senha ("Esqueci a senha" já aparece no Entrar) | Back-end |
| Idade mínima para usar o app (LGPD: menores de 12 precisam de consentimento dos pais) | Grupo |
| Política de retenção de vídeos (ex.: apagar após 30 dias, exceto favoritos) | Grupo |

As decisões em aberto de produto estão em [produto.md](produto.md#5-decisões-em-aberto--de-produto).

---

## Como contribuir

### Git (proposta)

A parte de Git é uma **proposta** — ajustem na reunião se quiserem.

- A `main` sempre compila e passa nos testes. **Ninguém commita direto nela.**
- Uma **branch por tarefa**, com prefixo: `feat/tela-inicio`, `fix/erro-login`, `docs/modelo-sessoes`, `chore/atualiza-firebase`.
- Commits curtos no formato `tipo: o que mudou`, em português: `feat: tela Complete seu perfil`.
- Terminou? Abra um **PR** e peça revisão de **uma pessoa de outra área** (todos passam por todas as áreas).
- Mudança em `firestore.rules`, `storage.rules` ou `app/android/` → revisão do back-end obrigatória.
- Faça `git pull` da `main` antes de começar e antes de abrir o PR.

### Checklist do PR

- [ ] `cd app && flutter analyze` sem avisos
- [ ] `cd app && flutter test` passando
- [ ] `cd backend/functions && npm run build && npm test` passando (se mexeu no backend)
- [ ] `cd backend/tests && npm test` passando (se mexeu em regras — com o Emulator desligado)
- [ ] Testei o fluxo no emulador com o Firebase Emulator rodando
- [ ] Tela nova: [checklist de tela nova](design.md#6-checklist-de-tela-nova) conferido e tela adicionada ao catálogo
- [ ] Coleção ou campo novo no Firestore: modelo de dados deste arquivo atualizado
- [ ] Escrevi no PR o que **não** testei

### Criar uma tela nova

Modelo para copiar: `app/lib/features/onboarding/`.

1. Ache a feature certa em `app/lib/features/` (veja o `README.md` de cada uma). Não existe? Crie a pasta com `screens/`, `widgets/`, `state/`, `data/` e um `README.md`.
2. Crie `screens/<nome>_screen.dart` com uma classe `<Nome>Screen`. Nomes em inglês, textos em português.
3. Monte a tela com os componentes de `app/lib/core/widgets/` (lista em [design.md › Componentes](design.md#4-componentes)). Valores visuais **só com tokens**. Referência visual: os canvas linkados no [design.md](design.md#7-referências-no-claude).
4. Precisa de dados? Use (ou crie) um repositório em `app/lib/core/data/`. A tela nunca chama `FirebaseFirestore`/`FirebaseFunctions` direto.
5. Adicione uma linha em `app/lib/dev/screen_catalog.dart` para o time conseguir abrir a tela.
6. Escreva pelo menos um teste em `app/test/` (a tela abre, o texto principal aparece).
7. Rode o checklist do PR.

### Criar uma Cloud Function

Modelo para copiar: `backend/functions/src/users/completeProfile.ts` (chamável) e `validation.ts` (validação testável).

1. **Gatilho ou chamável?**
   - O usuário fez uma ação e a função precisa dos dados que ele enviou → **chamável** (`onCall`).
   - Algo aconteceu no banco/Storage e é preciso reagir (contador, notificação, limpeza) → **gatilho** (`onDocumentCreated`, `onObjectFinalized`, `onSchedule`…).
2. Crie o arquivo no domínio certo (`users/`, `friends/`, `sessions/`, `highlights/`, `maintenance/`) e exporte no `index.ts` **do domínio**. A região vem de `src/config.ts`.
3. Estrutura de uma chamável:
   1. `request.auth?.uid` — sem login, `HttpsError("unauthenticated", ...)`;
   2. valide e normalize os dados **antes** de tocar no banco (regras em arquivo separado, sem Firebase, com testes em `functions/test/`);
   3. grave tudo numa **transação** quando houver mais de um documento;
   4. seja **idempotente** (chamar duas vezes não pode duplicar nada);
   5. erros com `HttpsError` e mensagem em português pronta para a tela (`details: { field }` quando for de um campo).
4. Gatilhos podem disparar mais de uma vez: idempotência é obrigatória (ex.: use o ID do evento ou um documento de controle).
5. Lembre: o Admin SDK **ignora as Security Rules**. A Function é responsável por tudo que grava.
6. Nada do caminho crítico do gesto (salvar o highlight em até 3 s) pode depender de uma função: elas podem levar alguns segundos para "acordar".
7. No app, chame pela camada `core/data` (veja `AuthRepository.completeProfile`).
8. Teste: `npm test` (validação) e o fluxo no Emulator (logs em <http://localhost:4000> → Logs).

### Mudar uma regra (Security Rules)

1. Edite `backend/firestore.rules` (ou `storage.rules`). Comente o porquê de cada `match`.
2. Em `backend/tests/firestore.rules.test.ts`, escreva pelo menos **um teste de "pode" e um de "não pode"**.
3. `cd backend/tests && npm test` (com o `firebase emulators:start` desligado).
4. Se a regra abre escrita para o app, explique no PR por que não pode ser uma Function (D7).

### Trabalhando com IA

O arquivo `AGENTS.md` na raiz (e `CLAUDE.md`, que aponta para ele) é lido automaticamente pelas ferramentas de IA. Se o time combinar uma regra nova, **atualize o `AGENTS.md` no mesmo PR** — assim a IA de todo mundo passa a segui-la.

Peça para a IA explicar o que ela mudou e confira o checklist do PR antes de abrir: a revisão é de vocês, não dela.
