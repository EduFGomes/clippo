# Arquitetura

Como o Clippo é construído e como contribuir. O que o app faz está em [produto.md](produto.md); como ele parece, em [design.md](design.md). As regras curtas que valem para todo código (inclusive o escrito por IA) estão no [`AGENTS.md`](../AGENTS.md); instalação e como rodar, no [README da raiz](../README.md).

Este documento registra **as decisões técnicas já tomadas**, o porquê de cada uma e o **modelo de dados atual**. Antes de mudar qualquer item daqui, leve ao grupo.

## Em uma frase

App Flutter que detecta o gesto **no próprio celular** + Firebase (Auth, Firestore, Storage, Cloud Functions) **sem API própria**. As regras de acesso ficam nas Security Rules; o que precisa de validação ou lógica de servidor fica em Cloud Functions.

```
Celular de quem grava              Firebase (São Paulo; Storage nos EUA)           Outros participantes
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
| D4 | **Firestore e Functions em `southamerica-east1`; só o Storage em `us-east1`** (o gatilho `onVideoUploaded` fica junto do bucket, como o Google exige) | Leituras e chamadas do app ficam rápidas (~20 ms em vez de ~130 ms); a cota gratuita do Storage só existe em regiões dos EUA. A região do Firestore **não muda depois**. Decidido pelo grupo em 09/11/2026 (antes: tudo em `us-east1`) | Envio e download de vídeo continuam indo aos EUA; Functions em SP têm preço "Tier 2" (cota gratuita um pouco menor); vídeos fora do Brasil (citar na política de privacidade) |
| D5 | **App organizado por funcionalidade** (`lib/features/`) | Cada pessoa trabalha na sua pasta; menos conflito | Exige combinar o que vai em `lib/core/` |
| D6 | **Desenvolvimento no Emulator** (`demo-clippo`) | Sem custo, sem conta, sem risco de mexer em dados reais | Dados de cada um ficam só na máquina de cada um |
| D7 | **O app não grava dados validados**; só Functions gravam | Ninguém pula a validação mexendo no app | Toda escrita nova precisa de uma Function |
| D8 | **Fontes embutidas no app** (Anton e Archivo em `app/assets/fonts/`, sem o pacote `google_fonts`) | Funciona sem internet na quadra; nada é baixado na primeira abertura | ~1 MB a mais no app |
| D9 | **Valores visuais só em `clippo_tokens.dart`** (sem JSON paralelo) | Uma fonte só evita divergência entre docs e código | Quem não usa Flutter lê os valores pelo [design.md](design.md) |
| D10 | **Toda entrada validada duas vezes: no app e no servidor**, com as mesmas regras e mensagens (regra 0 do `AGENTS.md`) | O app dá o erro na hora, embaixo do campo, sem gastar chamada; o servidor garante que ninguém pula a validação. O Firebase Auth sozinho aceita e-mails como `nome@g` | Duas cópias das regras (`app/lib/core/validation/input_validation.dart` e `backend/functions/src/{users,sessions}/validation.ts`) que precisam mudar juntas, com testes dos dois lados |
| D11 | **Navegação de nível superior em roda** (protótipo v2), e não em barra | Combina com "o lance é o herói": nada de barra fixa ocupando o rodapé em cima do vídeo; o gesto de segurar-e-arrastar chega em qualquer seção com uma mão só | Menos convencional que uma barra; exige explicar na primeira vez. 🟡 Decidido pelo back-end em 20/10/2026; o grupo aprova em 28/10/2026, mas fica em aberto caso precise mudar |
| D12 | **`flutter_svg`** para desenhar os ícones da marca | Os 19 SVGs de `app/assets/icons/` já existiam sem um jeito de usar; redesenhá-los em código duplicaria o traço | Uma dependência a mais (~200 KB). Os ícones dos controles continuam desenhados em código no `ClippoIcon` |
| D13 | **Câmera e pose em código nativo (Kotlin: CameraX + ML Kit Pose base); regra do gesto em Dart** (`app/android/.../camera/` e `app/lib/core/gesture/`) | O Android entrega a câmera a um cliente por vez: o CameraX abre uma vez e alimenta a imagem na tela, a análise de pose e o buffer de 30 s. O ML Kit (modelo padrão `base`) roda no Kotlin, sem copiar cada quadro para o Dart; o Dart recebe só os 33 pontos do corpo (~25 vezes por segundo). A regra e o disparo em Dart são testáveis sem câmera | Código Kotlin sem teste automático (só no celular); só Android (iOS precisaria do equivalente); o ML Kit Pose só tem versões beta desde 2020 (usamos a 18.0.0-beta5). Decidido pela visão computacional em 23/10/2026, confirmado pelo grupo em 28/10/2026 |
| D14 | **Gesto só vale de frente para a câmera**, conferido pela profundidade (z) do nariz em relação aos ombros | O produto pede o gesto "olhando para a câmera" para não disparar em comemorações. Em vídeo, o Y de costas disparava; a confiança do ML Kit não serve (diz se o ponto está na imagem, não se está visível) e a ordem dos ombros erra. O nariz separou bem: de frente −0,8 a −2,1, de costas +1,2 a +2,1 | Depende de uma profundidade estimada a partir de uma imagem só; ainda não medido a 8 m. Decidido pela visão computacional em 24/10/2026, confirmado pelo grupo em 28/10/2026 |
| D15 | **Sessões e highlights gravados por uma Cloud Function chamável (`saveSession`)**; os vídeos sobem do app direto para o Storage, e um gatilho marca o highlight como enviado (R13) | Valida tudo no servidor (regra 0 do AGENTS.md, e os participantes são amigos do dono, R10) e grava numa transação, como o `completeProfile`; as Security Rules continuam fechadas para escrita. A gravação não depende dela (R8): só o "Salvar sessão" chama, e sem internet o app guarda e tenta de novo depois (WorkManager) | O projeto real precisa do plano Blaze (pago por uso, com cartão; o Storage também exige). O uso de um projeto de faculdade cabe na cota sem custo. Decidido pelo grupo em 28/10/2026 |
| D16 | **Amizade num documento por par** (`friendships/{uidA_uidB}`, ids em ordem), gravado só por Functions | Não existe pedido duplicado nem "meio amigo" (R15 é um documento só); conferir R10 custa uma leitura por participante; a lista de amigos é uma consulta (`uids` contém eu) | Nome e foto copiados no documento (`profiles`) ficam velhos se a pessoa mudar o perfil. 🟡 Proposta do back-end em 09/11/2026, a confirmar com o grupo |
| D17 | **Vídeos protegidos pelas regras do Storage lendo o Firestore** (`firestore.get()` na regra), sem URL pública | Só participantes da sessão baixam (R11) e só quem gravou envia, num highlight `pending`, um MP4 de tamanho limitado; nada de link que funciona sem login. O Player assiste por streaming com o login e o App Check no cabeçalho ([Acesso aos vídeos](#acesso-aos-vídeos-no-storage-d17-)) | Cada download custa uma leitura no Firestore; no projeto real, o primeiro deploy das regras pede para dar ao Storage permissão de ler o Firestore. 🟡 Proposta do back-end em 09/11/2026 |
| D18 | **Juntar sessões** (ex.: tênis com um celular de cada lado): os highlights da sessão de origem são **copiados** para a sessão principal, mas o vídeo **não sai do lugar** no Storage | Um hub só, com todos os ângulos em ordem de horário, sem mover arquivo; a sessão de origem fica escondida (`mergedInto`) e com a mesma lista de participantes, para as regras do Storage continuarem liberando o vídeo | O documento do lance existe em dois lugares (origem e principal); o gatilho do upload e o reenvio da fila atualizam os dois. 🟡 Proposta do back-end em 09/11/2026 |

Custos estimados e alternativas descartadas (API de visão computacional, backend próprio): documento da proposta apresentado ao grupo.

## Modelo de dados (Firestore)

Estado atual. Coleções novas entram aqui **antes** de serem implementadas.

| Coleção / documento | Campos | Quem lê | Quem grava |
|---|---|---|---|
| `users/{uid}` — perfil público | `name` string · `username` string · `photoUrl` string\|null · `stats` {`sessions`, `highlights`, `friends`} números · `createdAt` timestamp · `updatedAt` timestamp (só depois de editar) | Qualquer usuário logado, **um documento por vez** (ninguém lista a coleção) | Só Functions (`completeProfile`; `updateProfile` muda `name`/`username`; `stats` atualizado pelas Functions de sessão e de amizade) |
| `usernames/{username}` — trava do @ único | `uid` string · `createdAt` timestamp | Qualquer usuário logado, **um @ exato por vez** (é a busca da tela Amigos) | Só Functions (`completeProfile`; `updateProfile` libera o antigo e reserva o novo na mesma transação) |
| `friendships/{uidA_uidB}` — amizade ou pedido (D16) | `uids` [uidA, uidB] em ordem · `status` `pending`\|`accepted` · `requestedBy` · `requestedTo` · `profiles` {uid: {`name`, `username`, `photoUrl`}} · `createdAt` · `updatedAt` · `acceptedAt` timestamp\|null | Só as duas pessoas | Só Functions (`sendFriendRequest`, `acceptFriendRequest`, `removeFriend`; `updateProfile` regrava `profiles.{uid}`) |
| `sessionMergeRequests/{intoId__fromId}` — pedido para juntar sessões (D18) | `uids` [quem pediu, dono da outra] · `intoSessionId` · `fromSessionId` · `requestedBy` · `requestedTo` · `intoName` · `fromName` · `createdAt` | Só as duas pessoas | Só Functions (`requestSessionMerge`, `acceptSessionMerge`, `cancelSessionMerge`) |
| `userPrivate/{uid}` — dados privados | `birthDate` string `AAAA-MM-DD` · `createdAt` timestamp | Só o dono | Só Functions (`completeProfile`) |
| `sessions/{sessionId}` — um jogo gravado | `name` string · `ownerId` string · `participantIds` string[] (inclui o dono, R9) · `participantsPreview` [{`uid`, `name`, `photoUrl`}] até 5 · `participantCount` número · `startedAt` timestamp · `endedAt` timestamp · `durationSeconds` número · `location` {`label`, `lat`?, `lng`?}\|null · `highlightCount` número · `mergedInto` string\|null (D18: esta sessão foi juntada àquela) · `mergedFrom` string[] (D18: sessões juntadas a esta) · `createdAt` timestamp · `updatedAt` timestamp | Só os participantes | Só Functions (`saveSession`, `updateSession`, `leaveSession`, `acceptSessionMerge`; `updateProfile` regrava o nome em `participantsPreview`) |
| `sessions/{sessionId}/highlights/{highlightId}` — trecho salvo pelo gesto | `title` string · `offsetSeconds` número · `durationSeconds` número (~30) · `savedAt` timestamp · `createdBy` string · `videoPath` string\|null · `thumbnailPath` string\|null · `status` `pending`\|`uploaded`\|`failed` (R13) · `sourceSessionId` string\|null (D18: de qual sessão o lance veio) · `createdAt` timestamp · `updatedAt` timestamp | Só os participantes da sessão | Só Functions (`saveSession`, `acceptSessionMerge`, `renameHighlight` troca o `title`; `onVideoUploaded` marca `uploaded`, D15) |

Regras de modelagem:
- O **e-mail fica só no Firebase Auth**, nunca no Firestore.
- Dado pessoal só com finalidade clara (LGPD, minimização). A data de nascimento existe só para estatísticas agregadas.
- `@usuário` normalizado: minúsculas, 3–20 caracteres, `a–z 0–9 _ .`, sem ponto no começo/fim nem `..`.
- Unicidade garantida pelo **ID do documento** em `usernames/`, criado dentro de transação (sem condição de corrida).

- **Participante não é coleção.** A lista fica no próprio documento da sessão (`participantIds`), porque é a única forma de responder "as sessões de que eu participo" em **uma** consulta.
- **O Firestore não tem JOIN** (D2): o que a lista precisa mostrar sem abrir a sessão fica copiado nela (`participantsPreview`, `highlightCount`, `durationSeconds`).
- **Cópias do perfil** (`friendships.profiles`, `sessions.participantsPreview`): quando a pessoa muda o nome ou o @ (`updateProfile`), a Function grava `users/` e `usernames/` numa transação e depois regrava as cópias em lotes, fora da transação. Custo: 1 leitura por amizade/pedido + 1 por sessão da pessoa, e só escreve onde a cópia mudou (ex.: 50 amigos e 100 sessões ≈ 154 leituras). Se cair no meio, o perfil já está certo e chamar de novo termina as cópias. A foto ainda não é editável.
- **Contadores são mantidos por gatilho**, nunca pelo app, e de forma idempotente.

### Amigos (D16) 🟡

1. **Pedido:** eu digito o @ exato do meu amigo; o app lê `usernames/{@}` para mostrar quem é, e
   `sendFriendRequest({username})` cria `friendships/{par}` com `status: pending`. Se ele já tinha me
   pedido, a amizade é aceita na hora (os dois querem).
2. **Aceite:** só quem recebeu chama `acceptFriendRequest({uid})` (R15). Os dois ganham +1 em `stats.friends`.
3. **Recusar, cancelar ou desfazer:** `removeFriend({uid})` apaga o documento, em qualquer estado.
   Era amizade? Os dois perdem 1 em `stats.friends`. Sessões antigas não mudam.
4. **Limites contra spam:** até 50 pedidos esperando resposta e até 500 amigos por pessoa.

Telas: **amigos** = `uids` contém eu e `status == accepted`; **pedidos recebidos** = o mesmo com
`requestedTo == eu` e `status == pending`. A busca da tela Amigos é por **@ exato** (ninguém lista
`users/` nem `usernames/`, para um script não baixar a base inteira); filtrar por nome é só dentro da
lista de amigos já carregada.

**"X sessões juntos" (R16)** é contado **no aparelho**, a partir das sessões que a Início já leu
(`participantIds` contém os dois). O Firestore não consegue filtrar duas vezes por `array-contains`, e
um contador por par precisaria de até 435 escritas por sessão de 30 pessoas. Se a lista de sessões de
alguém ficar grande demais, vira contador.

### Participantes e "hub" da sessão 🟡

- No "Salvar sessão", o dono escolhe os participantes **entre os amigos** (R10, conferido no `saveSession`).
  Eles **não precisam aceitar**: a sessão aparece na Início deles (proposta da Gravação › Estado A).
- Todo participante vê, assiste e **baixa** todos os highlights (R11). Download = ler o vídeo pelo Storage.
- Depois de salva, só o dono renomeia um lance: `renameHighlight` (domínio `highlights/`; o
  nome nasce "Lance N" no `saveSession`).
- Depois de salva, só o dono muda nome, local e participantes: `updateSession` (R12). Quem entra
  também precisa ser amigo do dono; quem sai perde o acesso aos vídeos na hora.
- Um participante pode sair sozinho: `leaveSession` (o dono não sai; 🟡 decisão de produto em aberto).
- O dono exclui a sessão para todos: `deleteSession` apaga numa transação os highlights, os
  pedidos de juntar que citam a sessão e a própria sessão, e desconta a sessão e os lances do
  perfil de cada participante; depois apaga a pasta `sessions/{id}/` do Storage (falha ali só vai
  para o log). O app tira a sessão da fila de envio antes de chamar. 🟡 Sessão juntada (D18) ainda
  não é excluída.
- O app **não** cria sessão "aberta" nem entra por código/link: o campo `isClosed` do app não existe no
  servidor. Se o grupo quiser convite por link, entra como pedido que o dono aprova.

### Juntar sessões (D18) 🟡

Caso de uso: tênis, cada um com o celular atrás de si. São duas sessões, cada uma com os seus lances;
no fim, elas viram uma só.

1. Ana (dona da sessão **A**) participa da sessão **B** do Beto (ele a incluiu ao salvar). Na tela da A,
   ela escolhe "Juntar com…" entre as sessões em que ela está, de outro dono, com horário que encosta
   na A (até 30 min de diferença). `requestSessionMerge({intoSessionId: A, fromSessionId: B})`.
2. Beto vê o pedido e aceita: `acceptSessionMerge({requestId})`. Recusar ou desistir:
   `cancelSessionMerge({requestId})`.
3. Numa transação: os lances de B são **copiados** para A (mesmo id, `sourceSessionId: B`,
   `offsetSeconds` recalculado pelo novo início); A passa a ter os participantes das duas, o período
   que cobre as duas e a soma dos lances; B ganha `mergedInto: A` e a mesma lista de participantes.
   Os contadores do perfil são acertados (a pessoa que estava nas duas fica com uma sessão só).
4. A Início **esconde** sessões com `mergedInto` (filtro no aparelho, sem índice novo). Os vídeos de B
   continuam em `sessions/B/...`; como B tem os mesmos participantes que A, as regras do Storage
   liberam o download. `updateSession` e `leaveSession` em A repetem a lista de participantes em B.
5. O vídeo de B que ainda estava subindo, quando chega, marca `uploaded` nas duas cópias
   (`onVideoUploaded`); um reenvio da fila de B grava o lance nas duas sessões (`saveSession`).

Limites: até 5 sessões juntadas numa só, 30 participantes e 200 lances no total.

### Sessões e highlights

As **leituras** abaixo já estão implementadas
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

#### Acesso aos vídeos no Storage (D17) 🟡

Caminho combinado (o `saveSession` devolve ele pronto para o app enviar):
`sessions/{sessionId}/highlights/{highlightId}/video.mp4` e `thumb.jpg`.

As regras do Storage **conseguem** ler o Firestore (`firestore.get()`; a versão anterior deste
documento dizia que não, o que estava desatualizado). Então `storage.rules` diz:

| Ação | Quem | Condições |
|---|---|---|
| Baixar (`read`) | Participante da sessão | `uid in sessions/{id}.participantIds` |
| Enviar o vídeo | Quem gravou o lance (`createdBy`) | highlight `pending` ou `failed`; `video/mp4`; até 100 MB (o mesmo `MAX_VIDEO_BYTES` do gatilho) |
| Enviar a miniatura | Quem gravou o lance | `image/jpeg`; até 1 MB |
| Sobrescrever ou apagar | Ninguém pelo app | Só Functions (Admin SDK) |
| Qualquer outro caminho | Ninguém | — |

Alternativas descartadas: uids nos metadados do arquivo (precisam ser reescritos quando os
participantes mudam), URL com token no documento (funciona sem login para quem tiver o link) e
URL assinada por Function (latência e mais código).

**Como o app lê o vídeo** (`HighlightMediaRepository`), sempre pelas regras acima e sem link público:

| Para quê | Como |
|---|---|
| Assistir no Player | **Streaming**: o player busca o arquivo aos poucos na mesma API que o SDK usa (`/v0/b/{bucket}/o/{caminho}?alt=media`), com os cabeçalhos `Authorization: Firebase <token do login>` e `X-Firebase-AppCheck`. Começa a tocar sem esperar o download inteiro. Sem login ou App Check, o Storage recusa. Se o streaming falhar, o Player baixa o arquivo inteiro e toca |
| Baixar e compartilhar | O SDK baixa o arquivo inteiro para o cache do app (que também serve para tocar de novo na hora) |
| Quem gravou, antes de subir | O MP4 da pasta do app (`Highlight.localPath`, vindo da fila de envio), sem internet |
| Miniatura no card da Sessão | O SDK baixa o `thumb.jpg` para o cache do app (`thumbnailFile`, pelas regras, sem `getDownloadURL()`). Quem gravou, antes de subir: o JPEG da pasta do app (`Highlight.localThumbnailPath`) |

**Como a miniatura nasce:** a fila de envio (`core/upload/upload_queue.dart`), e não o gesto (R2),
pede ao nativo (`extractThumbnail` no canal `clippo/camera`, `MediaMetadataRetriever`) um quadro
do meio do MP4, em JPEG de até 640 px (dezenas de KB), gravado ao lado do vídeo em
`filesDir/highlights/`. Assim que a sessão existe no servidor, a fila envia o JPEG para o
`thumbnailPath` do lance. Isso roda numa fila à parte: falhar ou demorar (teto de 30 s por lance)
nunca atrasa o vídeo nem segura o lance; a próxima passada tenta de novo. O JPEG local sai junto
com o MP4 quando o lance fica `uploaded`. Lances gravados antes disso não têm miniatura.

O `MediaMuxer` grava o índice (`moov`) no fim do MP4; ao salvar o highlight, o app o move para o
começo ("faststart", `Mp4FastStart.kt`), para o streaming tocar com o primeiro pedaço. Lances
gravados antes dessa mudança continuam com o índice no fim e demoram mais para abrir (medido no
S24: 6–9 s).

**No projeto real:** no primeiro
`firebase deploy --only storage`, o CLI pede para dar ao agente de serviço do Storage o papel de
leitura do Firestore; aceite, senão toda regra com `firestore.get()` recusa.

## Quem faz o quê

| Camada | Responsabilidade |
|---|---|
| **App** | Telas, câmera, buffer, detecção, upload. Lê o Firestore direto. Chama Functions para gravar. |
| **Security Rules** | Porteiro: decide cada leitura (e bloqueia escritas do app). Testadas em `backend/tests/`. |
| **Functions chamáveis** | Ações do usuário que precisam de validação no servidor (ex.: `completeProfile`). |
| **Funções de bloqueio do Auth** | Rodam antes de a conta ser criada e podem recusá-la (ex.: `validateNewAccount`, que confere o e-mail). |
| **Política de senha do Auth** | Recusa criar conta (ou trocar a senha) fora da regra: 8 a 128 caracteres, com maiúscula, minúscula e número (`PASSWORD_POLICY` em `functions/src/users/validation.ts`, a mesma regra do `validateNewPassword` do app). É o lado servidor da senha, que nunca passa por uma Function. Aplicada por `node scripts/apply-password-policy.mjs <projeto>` (em `backend/functions`, depois do build). O Emulator guarda a política mas não a aplica no cadastro. |
| **Functions de gatilho** | Efeitos colaterais de eventos: contadores, notificações, limpeza. Idempotentes. |

O catálogo de funções planejadas está no [`backend/README.md`](../backend/README.md#catálogo-de-funções-rascunho).

## Ambientes

| | Emulator (`demo-clippo`) | Projeto real (`clippo-dev`) |
|---|---|---|
| Para quê | Todo o desenvolvimento e os testes | Testes em quadra, upload por 4G, demo |
| Custo | Zero | Plano Blaze com alerta de orçamento |
| Status | Em uso | Criado em 09/11/2026: Firestore em `southamerica-east1`, Storage em `us-east1`, Auth com Identity Platform, regras e Functions publicadas (`validateNewAccount` ligado ao cadastro). Apps Android: `com.clippoapp.clippo` e `com.clippoapp.clippo.lab` |
| Como o app escolhe | Padrão | `flutter run --dart-define=USE_EMULATOR=false` |
| App Check | Não confere | **Obrigatório** em Firestore, Storage, Auth e Functions chamáveis (desde 09/11/2026). Cada celular precisa de um token cadastrado: [primeiro uso](#primeiro-uso-token-do-app-check) |

Portas, IP do Emulator no celular e região: [`AGENTS.md` › Ambiente local](../AGENTS.md#ambiente-local).

### Projeto real (`clippo-dev`)

O que está configurado (09/11/2026):

| Peça | Configuração |
|---|---|
| Plano | Blaze, com alerta de orçamento no Google Cloud (Faturamento › Orçamentos). O alerta só avisa; o que limita o gasto é `MAX_INSTANCES` em `backend/functions/src/config.ts` |
| Firestore | Banco `(default)`, edição Standard, `southamerica-east1` (não muda mais) |
| Storage | `clippo-dev.firebasestorage.app`, `us-east1`, região única (cota gratuita) |
| Authentication | E-mail/senha, com Identity Platform (exigido pela função de bloqueio) |
| Functions | `completeProfile`, `saveSession`, `validateNewAccount` em `southamerica-east1`; `onVideoUploaded` em `us-east1` (junto do bucket). Limpeza das imagens antigas: 1 dia, nas duas regiões |
| Apps Android | `com.clippoapp.clippo` (com SHA-1/SHA-256 da chave de debug) e `com.clippoapp.clippo.lab` (só para o build do sabor `lab` não quebrar) |
| App Check | Play Integrity registrado no app; Aplicação ligada em Firestore, Storage e Authentication; Functions chamáveis com `CALLABLE_OPTIONS` |
| Arquivos no repositório | `app/lib/firebase_options.dart`, `app/android/app/google-services.json`, `app/firebase.json` e o alias `dev` em `backend/.firebaserc`. Não são segredo: identificam o app, e quem protege os dados são as regras e o App Check |

#### Primeiro uso: token do App Check

Com o App Check obrigatório, um celular sem token cadastrado **não consegue nada** no projeto real
(login, leituras e Functions são recusados). Uma vez por celular (e de novo se reinstalar o app):

1. Peça a alguém com acesso ao console para te adicionar em **Configurações do projeto › Usuários e permissões**.
2. Rode o app no projeto real (`flutter run --dart-define=USE_EMULATOR=false`) e procure no terminal a linha
   `Firebase App Check debug token: xxxxxxxx-xxxx-...`. Se o log correr rápido demais, filtre:
   `adb logcat | Select-String "App Check debug token"`.
3. Cadastre o código no app **clippo (android)** (não no Clippo Lab):
   - console: **App Check › Apps › ⋮ › Gerenciar tokens de depuração › Adicionar** e **Salvar**; ou
   - CLI, em `backend/`: `firebase appcheck:debugtokens:create <código> --display-name "Celular do Fulano" --project dev --app 1:17675379807:android:7ec6ed5ab1efae63b167ea`
4. Feche e abra o app. Em **App Check › APIs**, as chamadas devem aparecer como **verificadas**.

O código é **segredo** (libera qualquer aparelho que o use): nunca no repositório, no grupo ou em print.
Para fixar um token (ex.: depois de reinstalar), passe `--dart-define=APP_CHECK_DEBUG_TOKEN=<código>`.
Quem sair do projeto ou trocar de celular: apague o token dele no console.

#### Rodar o app no projeto real

```bash
cd app
flutter run --dart-define=USE_EMULATOR=false
```

Sem `--dart-define`, o app usa o Emulator (o padrão). O sabor `lab` não usa o Firebase.
Se der erro, a ordem para investigar: token do App Check (acima) → **App Check › APIs** (chamadas
"inválidas"?) → **Functions › Registros** no console.

#### Publicar o backend

Sempre de `backend/`, sempre com `--project dev` (sem ele o CLI usa o `demo-clippo`). Antes: `npm run build`
e `npm test` em `functions/`, e `npm test` em `tests/` se mexeu em regras.

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project dev   # regras e índices
firebase deploy --only functions --project dev                                  # todas as funções
firebase deploy --only functions:saveSession --project dev                      # uma só
```

- Função nova chamável: use `onCall(CALLABLE_OPTIONS, ...)`; sem isso ela fica sem App Check.
- Mudou a região de uma função: o deploy cria a nova e pergunta se apaga a antiga.
- Primeiro deploy de uma função de gatilho novo pode falhar com "Permission denied while using the Eventarc
  Service Agent": espere ~5 minutos e rode de novo.
- `validateNewAccount` é ligado ao cadastro pelo próprio deploy (confira em **Authentication › Configurações ›
  Funções de bloqueio**).

#### Refazer a configuração do app

Só se mudar o pacote, entrar uma plataforma nova ou o `google-services.json` se perder:

```bash
dart pub global run flutterfire_cli:flutterfire configure --project=clippo-dev --platforms=android --android-package-name=com.clippoapp.clippo
```

Depois, baixe o `google-services.json` com os **dois** apps (o `flutterfire` grava só um, e o build do `lab`
quebra): `firebase apps:sdkconfig ANDROID 1:17675379807:android:7ec6ed5ab1efae63b167ea --project dev --out app/android/app/google-services.json`.

#### Rumo à Play Store

Hoje o App Check em builds de **release** usa o **Play Integrity**, que só aprova apps que o Google Play
conhece. Um APK de release instalado direto no celular é **recusado** (e com a Aplicação ligada, o app não
funciona). Até publicar, use builds de debug com token, inclusive na demo.

Para publicar:

1. **Conta de desenvolvedor** no [Google Play Console](https://play.google.com/console) (taxa única de US$ 25).
2. **Chave de upload própria** (hoje o release é assinado com a chave de debug, ver `TODO` em
   `app/android/app/build.gradle.kts`):
   - gerar: `keytool -genkey -v -keystore clippo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`;
   - guardar o `.jks` e as senhas **fora do repositório** (num cofre do grupo) e ler por um `key.properties`
     ignorado pelo Git ([guia do Flutter](https://docs.flutter.dev/deployment/android#sign-the-app));
   - perder essa chave = não conseguir mais atualizar o app (dá para pedir troca ao Google, mas demora).
3. **Gerar o pacote**: `flutter build appbundle --release` (a Play Store pede `.aab`, não `.apk`).
4. **Subir numa faixa de teste interno** primeiro (até 100 testadores por e-mail, sem revisão pública). A
   Play Store exige também política de privacidade (cite que os vídeos ficam nos EUA, decisão D4), ficha da
   loja e a declaração de segurança de dados.
5. **Ativar o Play App Signing** (padrão): o Google re-assina o app com a chave dele. Copie o **SHA-256 da
   chave de assinatura do app** (Play Console › Configuração › Integridade do app) e cadastre no Firebase:
   `firebase apps:android:sha:create 1:17675379807:android:7ec6ed5ab1efae63b167ea <SHA-256> --project dev`.
   Cadastre também o SHA-256 da chave de upload, para testar builds locais de release.
6. **Ligar o Play Integrity ao projeto**: Play Console › Configuração › **Integridade do app** › Play Integrity
   API › vincular ao projeto do Google Cloud `clippo-dev`.
7. Instalar pela faixa de teste e conferir em **App Check › APIs** que as chamadas do release chegam
   verificadas. Os tokens de depuração podem ser apagados quando ninguém mais usar builds de debug no
   projeto real.

Antes de abrir para o público, avaliar também: o sabor `lab` não vai para a loja; `MAX_INSTANCES` e o
alerta de orçamento; e o que está 🟡 abaixo (retenção de vídeos, idade mínima, acesso aos vídeos).

## Decisões em aberto 🟡

| Tema | Quem decide |
|---|---|
| Gerenciamento de estado no app (Provider, Riverpod, Bloc…) | Front-end |
| Confirmar D16 (amizade por par), D17 (vídeos pelas regras do Storage) e D18 (juntar sessões) | Back-end + grupo |
| Participante pode sair sozinho da sessão (`leaveSession` já existe)? Participante precisa aceitar entrar? | Grupo |
| Sessão aberta/fechada e entrada por código ou link (o app tem `isClosed`; o servidor não) | Grupo |
| Login com Google (precisa do projeto real) | Back-end |
| Recuperação de senha ("Esqueci a senha" manda o e-mail padrão do Firebase desde 10/11/2026, por `AuthRepository.sendPasswordReset`; falta o texto do e-mail e a nova senha dentro do app) | Back-end |
| Idade mínima para usar o app (LGPD: menores de 12 precisam de consentimento dos pais) | Grupo |
| Política de retenção de vídeos (ex.: apagar após 30 dias, exceto favoritos) | Grupo |
| Várias pessoas no quadro: escolhido o **detector de pessoas (MediaPipe, EfficientDet-Lite0, numa thread à parte) + um ML Kit em modo stream para cada pessoa**, sempre ligado no laboratório desde 28/10/2026. Escolhido por licença (Apache 2.0 e ML Kit podem ir para a Play Store; o YOLO-pose é AGPL) e por manter a regra e o z do nariz. A medir: tempo com 3–6 pessoas e acerto de longe. Alternativa a comparar: MediaPipe Pose Landmarker no lugar do ML Kit (mesmos 33 pontos, sem beta, pode usar a GPU) | Visão computacional |
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
- [ ] `cd backend/tests && npm run test:e2e` passando (se mexeu numa Function chamável)
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
8. Teste: `npm test` em `functions/` (validação, sem Emulator) e
   `npm run test:e2e` em `tests/` (a função de verdade no Emulator; veja o `saveSession`
   como modelo). Logs em <http://localhost:4000> → Logs.

### Mudar uma regra (Security Rules)

1. Edite `backend/firestore.rules` (ou `storage.rules`). Comente o porquê de cada `match`.
2. Em `backend/tests/firestore.rules.test.ts`, escreva pelo menos **um teste de "pode" e um de "não pode"**.
3. `cd backend/tests && npm test` (com o `firebase emulators:start` desligado).
4. Se a regra abre escrita para o app, explique no PR por que não pode ser uma Function (D7).

### Trabalhando com IA

O arquivo `AGENTS.md` na raiz (e `CLAUDE.md`, que aponta para ele) é lido automaticamente pelas ferramentas de IA. Se o time combinar uma regra nova, **atualize o `AGENTS.md` no mesmo PR** — assim a IA de todo mundo passa a segui-la.

Peça para a IA explicar o que ela mudou e confira o checklist do PR antes de abrir: a revisão é de vocês, não dela.
