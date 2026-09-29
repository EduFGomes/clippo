# 02 — Funcionalidades e regras

Este documento descreve **o comportamento esperado** do app. Ele não prescreve tecnologia: quem implementa decide como armazenar, sincronizar e estruturar o código, desde que as regras abaixo sejam respeitadas.

Regras marcadas com 🟡 são **propostas ainda não confirmadas pelo grupo** — implemente de forma que seja fácil mudar.

---

## 1. Conceitos

O modelo é **por sessão**: cada jogo é uma sessão, e quem participou dela vê os highlights dela. Não existe "time" ou "grupo fixo".

| Conceito | O que é | Nome no código |
|---|---|---|
| **Usuário** | Pessoa com conta no app. Tem nome, nome de usuário (@), foto e preferências. | `User` |
| **Amigo** | Outro usuário com quem existe uma amizade. É de quem se escolhe os participantes de uma sessão. | `Friend` / `Friendship` |
| **Sessão** | Um jogo gravado. Tem nome, data/hora de início, duração, local, quem gravou e a lista de participantes. Funciona como a "pasta compartilhada". | `Session` |
| **Participante** | Usuário incluído numa sessão. Todo participante vê todos os highlights da sessão. | `Participant` |
| **Highlight** | Trecho de ~30 s salvo pelo gesto. Pertence a exatamente uma sessão. Tem vídeo, miniatura, momento em que foi salvo (dentro da sessão) e um título curto. | `Highlight` |
| **Gesto** | O movimento **\ o /** que dispara o salvamento. | `Gesture` / `Trigger` |
| **Buffer** | Os últimos 30 s de vídeo mantidos em memória enquanto a sessão grava. Não é salvo sozinho. | `Buffer` |

### Relações

```
Usuário ──< Amizade >── Usuário
Usuário ──< Participante >── Sessão ──< Highlight
   (quem gravou também é participante)
```

- Um usuário participa de várias sessões; uma sessão tem vários participantes.
- Uma sessão tem zero ou mais highlights; um highlight pertence a uma única sessão.

---

## 2. Funcionalidades

### 2.1 Conta e entrada
- Criar conta e entrar (o método de login fica a critério do back-end).
- Na primeira vez: pedir permissão de câmera (e de localização, para sugerir o local da sessão) e explicar o gesto **\ o /** de forma visual.
- Sair da conta a partir do Perfil.

### 2.2 Gravar uma sessão
1. **Preparar** — o usuário vê a câmera em tela cheia para posicionar o celular e, opcionalmente, escolhe com quais amigos está jogando ("gravar sozinho" ou "gravar com [amigo]").
2. **Gravar** — ao tocar em iniciar, a tela fica **preta pura** (economia de bateria em telas OLED), com apenas um ponto pulsando indicando que a detecção está ativa. A câmera continua gravando e mantendo o buffer de 30 s. Um toque na tela mostra por alguns segundos as opções **"Encerrar sessão"** e **"Cancelar gravação"**.
3. **Gesto detectado** — o app salva os últimos 30 s como highlight e mostra o aviso **"Highlight salvo"** por ~2,6 s. Depois volta sozinho ao estado de gravação, sem exigir toque.
4. **Encerrar** — o usuário encerra a sessão e confirma os dados: nome, data e horário de início–fim (preenchidos automaticamente, editáveis), local (sugerido pela localização, editável) e participantes (pode adicionar mais). **"Salvar sessão"** volta à Início com a sessão nova no topo; **"Descartar"** abandona a sessão.

### 2.3 Ver sessões e highlights
- **Início** lista todas as sessões das quais o usuário participa, da mais recente para a mais antiga, em cards que abrem e fecham (resumo → detalhes).
- **"Ver highlights"** abre a sessão, que mostra seus highlights em ordem cronológica, em lista vertical.
- Tocar num highlight reproduz o vídeo.

### 2.4 Amigos
- Lista de amigos com busca.
- Convidar amigos.
- 🟡 Menu de ações por amigo (⋮) — ações a definir.
- A lista de amigos alimenta o seletor "gravar com" da tela de gravação.

### 2.5 Perfil
- Foto (editável), nome, estatísticas rápidas: nº de sessões, nº de highlights, nº de amigos.
- Editar nome, nome de usuário e notificações.
- Sair da conta.

---

## 3. Regras de negócio

### Gravação e gesto
| # | Regra |
|---|---|
| R1 | O highlight contém os **~30 s anteriores** ao momento do gesto. |
| R2 | O highlight deve estar salvo em **até 3 s** após o gesto (critério de aceite). |
| R3 | O gesto é válido só com **os dois braços** levantados em diagonal para fora, acima dos ombros, sem cruzar. Um braço só não dispara. |
| R4 | 🟡 Depois de um disparo, novos gestos são ignorados por alguns segundos (sugestão: ~5 s) para não salvar o mesmo lance duas vezes. |
| R5 | 🟡 Se a sessão tem menos de 30 s de gravação quando o gesto acontece, salva o que houver. |
| R6 | O buffer em si **nunca** é enviado ou guardado — só o que o gesto salvar. |
| R7 | Durante a gravação, a tela não mostra a imagem da câmera (só o ponto pulsante), e o aparelho não deve apagar a tela nem bloquear sozinho. |
| R8 | A detecção acontece no aparelho; não depende de internet. |

### Sessões e visibilidade
| # | Regra |
|---|---|
| R9 | Quem inicia a gravação é o **dono** da sessão e também é participante. |
| R10 | Os participantes são escolhidos **entre os amigos** do dono. |
| R11 | **Todo participante vê todos os highlights** da sessão. Quem não é participante não vê nada da sessão. |
| R12 | 🟡 Só o dono edita nome/local da sessão e adiciona ou remove participantes depois da gravação. |
| R13 | 🟡 Um highlight salvo **nunca pode se perder** por falta de internet na quadra: ele fica guardado no aparelho e é enviado quando houver conexão. A interface mostra que está "enviando". |
| R14 | A sessão pode ser abandonada de duas formas: **"Cancelar gravação"** (durante) ou **"Descartar"** (na confirmação). 🟡 Decidir se os highlights já salvos também somem nesses casos, e se sessão sem nenhum highlight pode ser salva. |

### Amigos
| # | Regra |
|---|---|
| R15 | 🟡 Amizade é mútua: um convida, o outro aceita. |
| R16 | O contador "X sessões juntos" na lista de amigos conta as sessões em que os dois são participantes. |

---

## 4. Fluxo principal (caminho feliz da demo)

```
Abrir app ─► Início ─► [Gravar] ─► Preparar (posiciona o celular, escolhe amigos)
          ─► Iniciar ─► Tela preta + ponto pulsante
          ─► jogador faz \ o / ─► "Highlight salvo" (2–3 s) ─► volta à tela preta
          ─► … (repete a cada lance)
          ─► toque na tela ─► Encerrar sessão ─► Confirme a sessão ─► Salvar sessão
          ─► Início (sessão nova no topo, aberta) ─► Ver highlights ─► toca um ─► assiste
          ─► outro participante abre o app e vê a mesma sessão no Início dele
```

Esse é o fluxo que precisa funcionar sem falha na apresentação. Qualquer feature nova não pode atrapalhá-lo.

---

## 5. Decisões em aberto 🟡

| Tema | Pergunta |
|---|---|
| Plataforma | iOS entra depois do MVP? |
| Cooldown | Quantos segundos ignorar gestos após um disparo? |
| Offline | Confirmar que highlights ficam no aparelho até haver internet. |
| Cancelar / Descartar | Highlights já salvos somem junto? Sessão sem highlights pode ser salva? |
| Participantes na gravação | O protótipo escolhe um amigo por vez no chip; a regra prevê vários. Permitir seleção múltipla? |
| Permissões | Participantes podem sair de uma sessão? Dono pode remover alguém? |
| Amizade | Convite com aceite, ou adicionar direto? |
| Título do highlight | O protótipo mostra títulos descritivos ("Golaço de fora da área"). Quem escreve: o usuário depois, ou nasce automático ("Lance 3") e é editável? |
| Menu de amigo | Quais ações ficam no ⋮ da lista de amigos? |
| Onboarding | Telas de entrada ainda não foram desenhadas. |
