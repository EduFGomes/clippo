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
| D10 | **Toda entrada validada duas vezes: no app e no servidor**, com as mesmas regras e mensagens (regra 0 do `AGENTS.md`) | O app dá o erro na hora, embaixo do campo, sem gastar chamada; o servidor garante que ninguém pula a validação. O Firebase Auth sozinho aceita e-mails como `nome@g` | Duas cópias das regras (`app/lib/core/validation/input_validation.dart` e `backend/functions/src/users/validation.ts`) que precisam mudar juntas, com testes dos dois lados |
| D11 | **Navegação de nível superior em roda** (protótipo v2), e não em barra | Combina com "o lance é o herói": nada de barra fixa ocupando o rodapé em cima do vídeo; o gesto de segurar-e-arrastar chega em qualquer seção com uma mão só | Menos convencional que uma barra; exige explicar na primeira vez. 🟡 Decidido pelo back-end em 20/10/2026; o grupo aprova em 28/10/2026, mas fica em aberto caso precise mudar |
| D12 | **`flutter_svg`** para desenhar os ícones da marca | Os 19 SVGs de `app/assets/icons/` já existiam sem um jeito de usar; redesenhá-los em código duplicaria o traço | Uma dependência a mais (~200 KB). Os ícones dos controles continuam desenhados em código no `ClippoIcon` |
| D13 | **Câmera e pose em código nativo (Kotlin: CameraX + ML Kit Pose); regra do gesto em Dart** (`app/android/.../camera/` e `app/lib/core/gesture/`) | O Android entrega a câmera a um cliente por vez: o CameraX abre uma vez e alimenta a imagem na tela, a análise de pose e o buffer de 30 s. O ML Kit roda no Kotlin, sem copiar cada quadro para o Dart; o Dart recebe só os 33 pontos do corpo (~25 vezes por segundo). A regra e o disparo em Dart são testáveis sem câmera | Código Kotlin sem teste automático (só no celular); só Android (iOS precisaria do equivalente); o ML Kit Pose só tem versões beta desde 2020 (usamos a 18.0.0-beta5). Decidido pela visão computacional em 23/10/2026, confirmado pelo grupo em 28/10/2026 |
| D14 | **Gesto só vale de frente para a câmera**, conferido pela profundidade (z) do nariz em relação aos ombros | O produto pede o gesto "olhando para a câmera" para não disparar em comemorações. Em vídeo, o Y de costas disparava; a confiança do ML Kit não serve (diz se o ponto está na imagem, não se está visível) e a ordem dos ombros erra. O nariz separou bem: de frente −0,8 a −2,1, de costas +1,2 a +2,1 | Depende de uma profundidade estimada a partir de uma imagem só; ainda não medido a 8 m. Decidido pela visão computacional em 24/10/2026, confirmado pelo grupo em 28/10/2026 |
| D15 | **Sessões e highlights gravados por uma Cloud Function chamável (`saveSession`)**; os vídeos sobem do app direto para o Storage, e um gatilho marca o highlight como enviado (R13) | Valida tudo no servidor (regra 0 do AGENTS.md, e os participantes são amigos do dono, R10) e grava numa transação, como o `completeProfile`; as Security Rules continuam fechadas para escrita. A gravação não depende dela (R8): só o "Salvar sessão" chama, e sem internet o app guarda e tenta de novo depois (WorkManager) | O projeto real precisa do plano Blaze (pago por uso, com cartão; o Storage também exige). O uso de um projeto de faculdade cabe na cota sem custo. Decidido pelo grupo em 28/10/2026 |

Custos estimados e alternativas descartadas (API de visão computacional, backend próprio): documento da proposta apresentado ao grupo.

## Modelo de dados (Firestore)

Estado atual. Coleções novas entram aqui **antes** de serem implementadas.

| Coleção / documento | Campos | Quem lê | Quem grava |
|---|---|---|---|
| `users/{uid}` — perfil público | `name` string · `username` string · `photoUrl` string\|null · `stats` {`sessions`, `highlights`, `friends`} números · `createdAt` timestamp | Qualquer usuário logado | Só Functions (`completeProfile`) |
| `usernames/{username}` — trava do @ único | `uid` string · `createdAt` timestamp | Qualquer usuário logado | Só Functions (`completeProfile`) |
| `userPrivate/{uid}` — dados privados | `birthDate` string `AAAA-MM-DD` · `createdAt` timestamp | Só o dono | Só Functions (`completeProfile`) |
| `sessions/{sessionId}` — um jogo gravado 🟡 | `name` string · `ownerId` string · `participantIds` string[] (inclui o dono, R9) · `participantsPreview` [{`uid`, `name`, `photoUrl`}] até 5 · `participantCount` número · `startedAt` timestamp · `endedAt` timestamp · `durationSeconds` número · `location` {`label`, `lat`?, `lng`?}\|null · `highlightCount` número · `createdAt` timestamp · `updatedAt` timestamp | Só os participantes | Só Functions (`saveSession`, D15) |
| `sessions/{sessionId}/highlights/{highlightId}` — trecho salvo pelo gesto 🟡 | `title` string · `offsetSeconds` número · `durationSeconds` número (~30) · `savedAt` timestamp · `createdBy` string · `videoPath` string\|null · `thumbnailPath` string\|null · `status` `pending`\|`uploaded`\|`failed` (R13) · `createdAt` timestamp · `updatedAt` timestamp | Só os participantes da sessão | Só Functions (`saveSession`; um gatilho marca `uploaded`, D15) |

Regras de modelagem:
- O **e-mail fica só no Firebase Auth**, nunca no Firestore.
- Dado pessoal só com finalidade clara (LGPD, minimização). A data de nascimento existe só para estatísticas agregadas.
- `@usuário` normalizado: minúsculas, 3–20 caracteres, `a–z 0–9 _ .`, sem ponto no começo/fim nem `..`.
- Unicidade garantida pelo **ID do documento** em `usernames/`, criado dentro de transação (sem condição de corrida).

- **Participante não é coleção.** A lista fica no próprio documento da sessão (`participantIds`), porque é a única forma de responder "as sessões de que eu participo" em **uma** consulta.
- **O Firestore não tem JOIN** (D2): o que a lista precisa mostrar sem abrir a sessão fica copiado nela (`participantsPreview`, `highlightCount`, `durationSeconds`).
- **Contadores são mantidos por gatilho**, nunca pelo app, e de forma idempotente.

🟡 **Ainda não modelado:** `Friendship`. A tela Amigos e a validação de R10 ("participantes são amigos do dono") dependem dele.

### Proposta 🟡 — sessões e highlights

Rascunho do back-end para o grupo aprovar. As **leituras** abaixo já estão implementadas
nas regras e testadas; as **escritas** continuam fechadas para o app: só Functions gravam
(D15, próxima seção).

**A consulta que define o modelo.** A Início precisa de "as sessões de que eu participo,
mais recente primeiro":

```dart
FirebaseFirestore.instance
    .collection('sessions')
    .where('participantIds', arrayContains: uid)
    .orderBy('startedAt', descending: true)
```

Isso exige o índice composto que está em `firestore.indexes.json`
(`participantIds` CONTAINS + `startedAt` DESC). E o filtro **não é opcional**: as regras
avaliam cada documento devolvido, então uma consulta sem `arrayContains: uid` falha
inteira ao encontrar a primeira sessão de outra pessoa. Quem escrever o repositório da
Início precisa saber disso.

**Por que os highlights são subcoleção** (`sessions/{id}/highlights/{id}`) e não uma
coleção de primeiro nível: um highlight pertence a exatamente uma sessão, e a permissão
sai da sessão. Em coleção separada, seria preciso copiar `participantIds` em cada
highlight e sair atualizando todos quando o dono mudasse os participantes (R12). O preço
é uma leitura a mais por consulta (a regra lê o documento da sessão para conferir
`participantIds`); em troca, a permissão nunca fica desatualizada.

**Por que `participantsPreview`:** a Início mostra até 5 avatares por sessão. Sem a
cópia, 10 sessões × 10 participantes = 100 leituras de `users/` só para desenhar a
lista. A cópia guarda `uid`, `name` e `photoUrl` dos 5 primeiros. 🟡 Efeito colateral
aceito: quem troca o nome ou a foto continua aparecendo com o antigo nos avatares até a
sessão ser atualizada — a tela Sessão lê os perfis de verdade.

#### Quem grava sessões e highlights

**Decidido pelo grupo em 28/10/2026: opção B, por uma Function** (D15). O back-end
recomendava a A; a comparação fica aqui para registro.

O conflito era entre duas regras do projeto:

- **D7 / regra 5 do `AGENTS.md`:** o app não grava dados validados; só Functions gravam.
- **R13 + R8:** um highlight salvo nunca pode se perder por falta de internet na quadra,
  e nada do caminho crítico do gesto pode depender de Cloud Functions.

| | Como funciona | A favor | Contra |
|---|---|---|---|
| **A — app grava, regras validam** | O app cria a sessão e os highlights direto no Firestore; as regras conferem formato, tipos e participação. A fila offline do Firestore sincroniza sozinha quando a internet volta. | R13 sai de graça; nada no caminho do gesto depende de servidor | Abre escrita para o app, contra D7; as regras passam a carregar a validação |
| **B — fila local + Function** ✅ | O app guarda a sessão e os highlights no aparelho e chama `saveSession` quando houver conexão. | Mantém D7 e a validação em um lugar só (inclusive R10) | O app implementa fila, repetição e o estado "enviando…" |

**Como a B atende R8 e R13:** o gesto só grava o MP4 na pasta interna do app, sem
servidor. A Function é chamada no "Salvar sessão"; sem internet, o app guarda a sessão e
tenta de novo sozinho quando a conexão voltar (WorkManager), mesmo com o app fechado. O
vídeo sobe do app direto para o Storage, e um gatilho marca o highlight como `uploaded`;
só depois disso o app apaga a cópia local (R13).

#### Acesso aos vídeos no Storage 🟡

Problema encontrado ao modelar, que vale levar ao grupo: **as regras do Storage não
conseguem ler o Firestore.** Então não dá para escrever "só participantes desta sessão
baixam este vídeo" como se faz no Firestore. Os caminhos possíveis:

1. Gravar os uids participantes nos **metadados do objeto** e conferir na regra do Storage
   (funciona, mas os metadados precisam ser atualizados quando os participantes mudam);
2. Guardar a **URL de download com token** no documento do highlight (quem tem a regra do
   Firestore tem a URL; quem tem a URL vê o vídeo, mesmo sem login);
3. Uma **Function que gera URL assinada** a cada pedido (mais controle, mais latência).

Caminho sugerido: `sessions/{sessionId}/highlights/{highlightId}/video.mp4` e
`thumb.jpg`. `storage.rules` segue bloqueando tudo até a decisão.

## Quem faz o quê

| Camada | Responsabilidade |
|---|---|
| **App** | Telas, câmera, buffer, detecção, upload. Lê o Firestore direto. Chama Functions para gravar. |
| **Security Rules** | Porteiro: decide cada leitura (e bloqueia escritas do app). Testadas em `backend/tests/`. |
| **Functions chamáveis** | Ações do usuário que precisam de validação no servidor (ex.: `completeProfile`). |
| **Funções de bloqueio do Auth** | Rodam antes de a conta ser criada e podem recusá-la (ex.: `validateNewAccount`, que confere o e-mail). |
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
| Modelo de Amizade (`Friendship`) | Back-end + grupo |
| Como autorizar o download dos vídeos, já que as regras do Storage não leem o Firestore — [opções acima](#acesso-aos-vídeos-no-storage-) | Back-end + grupo |
| Login com Google (precisa do projeto real) | Back-end |
| Função de bloqueio `validateNewAccount` no projeto real: exige o Firebase Authentication com Identity Platform (no Emulator funciona sem nada a mais). Sem ela, a validação do e-mail no servidor fica só no app | Back-end |
| Recuperação de senha ("Esqueci a senha" já aparece no Entrar) | Back-end |
| Idade mínima para usar o app (LGPD: menores de 12 precisam de consentimento dos pais) | Grupo |
| Política de retenção de vídeos (ex.: apagar após 30 dias, exceto favoritos) | Grupo |
| Várias pessoas no quadro: escolhido o **detector de pessoas (MediaPipe, EfficientDet-Lite0, numa thread à parte) + um ML Kit em modo stream para cada pessoa**, sempre ligado no laboratório desde 28/10/2026. Escolhido por licença (Apache 2.0 e ML Kit podem ir para a Play Store; o YOLO-pose é AGPL) e por manter a regra e o z do nariz. A medir: tempo com 3–6 pessoas e acerto de longe. Alternativa a comparar: MediaPipe Pose Landmarker no lugar do ML Kit (mesmos 33 pontos, sem beta, pode usar a GPU) | Visão computacional |
| Modelo do ML Kit: `base` ou `accurate`. Os dois estão no app (~14 MB juntos) até a medição a 8 m; o que perder sai | Visão computacional |
| Limites da regra do gesto (ângulos, nariz, tempo mínimo, espera da R4): valores atuais e como medir em [`app/lib/core/gesture/README.md`](../app/lib/core/gesture/README.md) | Visão computacional + grupo |

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
- [ ] Campo novo que o usuário preenche: validado no app e no servidor, com testes nos dois lados (regra 0 do `AGENTS.md`)
- [ ] Escrevi no PR o que **não** testei

### Criar uma tela nova

Modelo para copiar: `app/lib/features/onboarding/`.

1. Ache a feature certa em `app/lib/features/` (veja o `README.md` de cada uma). Não existe? Crie a pasta com `screens/`, `widgets/`, `state/`, `data/` e um `README.md`.
2. Crie `screens/<nome>_screen.dart` com uma classe `<Nome>Screen`. Nomes em inglês, textos em português.
3. Monte a tela com os componentes de `app/lib/core/widgets/` (lista em [design.md › Componentes](design.md#4-componentes)). Valores visuais **só com tokens**. Referência visual: os canvas linkados no [design.md](design.md#7-referências-no-claude).
4. Precisa de dados? Use (ou crie) um repositório em `app/lib/core/data/`. A tela nunca chama `FirebaseFirestore`/`FirebaseFunctions` direto.
5. Tem campo para o usuário preencher? Valide com as regras de `app/lib/core/validation/input_validation.dart` no envio (erro embaixo do campo, nada é enviado se houver erro) e de novo dentro do repositório. Regra que não existe ainda: crie nos dois lados, app e servidor, com testes.
6. Adicione uma linha em `app/lib/dev/screen_catalog.dart` para o time conseguir abrir a tela.
7. Escreva pelo menos um teste em `app/test/` (a tela abre, o texto principal aparece, um dado inválido mostra o erro sem enviar nada).
8. Rode o checklist do PR.

### Criar uma Cloud Function

Modelo para copiar: `backend/functions/src/users/completeProfile.ts` (chamável) e `validation.ts` (validação testável).

1. **Gatilho ou chamável?**
   - O usuário fez uma ação e a função precisa dos dados que ele enviou → **chamável** (`onCall`).
   - Algo aconteceu no banco/Storage e é preciso reagir (contador, notificação, limpeza) → **gatilho** (`onDocumentCreated`, `onObjectFinalized`, `onSchedule`…).
2. Crie o arquivo no domínio certo (`users/`, `friends/`, `sessions/`, `highlights/`, `maintenance/`) e exporte no `index.ts` **do domínio**. A região vem de `src/config.ts`.
3. Estrutura de uma chamável:
   1. `request.auth?.uid` — sem login, `HttpsError("unauthenticated", ...)`;
   2. valide e normalize os dados **antes** de tocar no banco (regras em arquivo separado, sem Firebase, com testes em `functions/test/`; a mesma regra precisa existir no app, em `app/lib/core/validation/`);
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
