# 07 — Arquitetura

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

## Ambientes

| | Emulator (`demo-clippo`) | Projeto real (`clippo-dev`) |
|---|---|---|
| Para quê | Todo o desenvolvimento e os testes | Testes em quadra, upload por 4G, demo |
| Custo | Zero | Plano Blaze com alerta de orçamento |
| Status | Em uso | 🟡 ainda não criado |
| Como o app escolhe | Padrão | `--dart-define=USE_EMULATOR=false` (depois de `flutterfire configure`) |

## Decisões em aberto 🟡

| Tema | Quem decide |
|---|---|
| Gerenciamento de estado no app (Provider, Riverpod, Bloc…) | Front-end |
| Navegação: barra (protótipo v1) ou roda (v2) | Grupo |
| Modelo de Sessão, Participante, Highlight e Amizade | Back-end + grupo |
| Validar "participantes são amigos do dono" (R10): regras ou Function `createSession` | Back-end |
| Login com Google (precisa do projeto real) | Back-end |
| Idade mínima para usar o app (LGPD: menores de 12 precisam de consentimento dos pais) | Grupo |
| Fontes embutidas no app ou baixadas | Front-end |
| Política de retenção de vídeos (ex.: apagar após 30 dias, exceto favoritos) | Grupo |
