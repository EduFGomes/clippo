# Produto

> **Levantou os braços, o lance está salvo.**

O que o Clippo faz, por quê, e como cada tela se comporta. Como o app parece e soa está em [design.md](design.md); como ele é construído, em [arquitetura.md](arquitetura.md).

**Convenções**
- Documentação em português (PT-BR); código em inglês, com os nomes do [glossário](design.md#glossário).
- **Decisões em aberto** estão marcadas com 🟡. Não trate uma decisão em aberto como fechada: leve para o grupo e implemente de um jeito fácil de mudar.
- Este arquivo descreve **comportamento**. Cores, fontes e tamanhos ficam só no [design.md](design.md).

---

## 1. Visão

### Em uma frase

O Clippo é um app Android que grava continuamente os últimos 30 segundos de uma partida amadora e, quando um jogador faz o gesto **\ o /** para a câmera, salva esse trecho como um *highlight* visível para todos que jogaram juntos.

### O problema

Em peladas, futebol society e jogos casuais, os melhores lances acontecem e ninguém grava. Quando alguém pega o celular, o momento já passou. Gravar a partida inteira gera horas de vídeo que ninguém assiste nem edita.

### A proposta

1. O jogador apoia o próprio celular em algum ponto da quadra, onde quiser — sem tripé ou posição fixa.
2. Inicia uma **sessão**. O app passa a manter na memória, o tempo todo, só os últimos 30 segundos de vídeo.
3. Aconteceu um lance bom? Qualquer jogador olha para o celular e levanta os dois braços abertos em diagonal: **\ o /**.
4. O app reconhece o gesto e salva os 30 segundos anteriores como um **highlight**. Ninguém precisa tocar no celular.
5. Ao fim do jogo, todos os participantes da sessão encontram os highlights no app.

O valor está em **não precisar fazer nada** durante o jogo além do gesto — e em ter só os melhores momentos, não a partida inteira.

### O gesto

- Os **dois braços levantados**, abertos para fora e para cima, em diagonal — como um "Y" ou uma comemoração.
- Braços **não cruzados**. A opção em "X" foi descartada porque, com os braços se sobrepondo, a detecção de pose confunde os lados esquerdo e direito.
- O jogador faz o gesto **de propósito, olhando para a câmera**, o que ajuda a evitar disparos acidentais em comemorações espontâneas.
- A detecção acontece **no próprio celular**, em tempo real, usando um modelo de pose pronto (pontos do corpo) e uma regra geométrica sobre esses pontos — sem treinar um modelo do zero.

### Público

Jogadores amadores que organizam partidas casuais com amigos, em grupo. Não são atletas profissionais nem editores de vídeo; querem algo que funcione sozinho e renda um vídeo para mandar no grupo.

### Personalidade do produto

Escuro, esportivo e vibrante — na linha de Strava e Nike. Referências de experiência: Strava, GymRats, Instagram, YouTube, X. O app precisa reagir com a mesma energia da jogada que acabou de acontecer. Como isso vira visual e texto: [design.md](design.md).

### Escopo do MVP

| Entra | Fica de fora |
|---|---|
| App Android com as telas descritas em [Telas](#4-telas) | Versão iOS 🟡 *(não descartada para o futuro)* |
| Detecção do gesto no aparelho | Edição de vídeo dentro do app |
| Buffer de 30 s e salvamento automático | Transmissão ao vivo |
| Sessões compartilhadas entre participantes | Publicação aberta na Play Store (só teste interno) |
| Amigos e perfil | Monetização |
| Documentação e demo ao vivo | |

### Critérios de aceite

O projeto está pronto quando:

- O gesto é reconhecido em **≥ 90 % das tentativas a até 8 m** da câmera.
- O highlight é salvo em **até 3 s** depois do gesto.
- O highlight fica **visível para todos os participantes** da sessão.
- A **demo ao vivo** roda do começo ao fim sem falha.

### Premissas e restrições

- Modelo de pose pré-treinado, sem treino de modelo próprio.
- 5 pessoas, cerca de 6 h por semana cada.
- Período: 27/08 a 04/12/2026 (entrega final ainda depende de aprovação do orientador 🟡).
- Só Android no MVP.
- Critério de desempate em qualquer decisão: **o que deixa a demo ao vivo mais convincente** para quem não é técnico.

---

## 2. Conceitos e funcionalidades

Esta seção descreve **o comportamento esperado** do app. Ela não prescreve tecnologia (isso está em [arquitetura.md](arquitetura.md)): quem implementa decide como armazenar, sincronizar e estruturar o código, desde que as regras abaixo sejam respeitadas.

### 2.1 Conceitos

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

```
Usuário ──< Amizade >── Usuário
Usuário ──< Participante >── Sessão ──< Highlight
   (quem gravou também é participante)
```

- Um usuário participa de várias sessões; uma sessão tem vários participantes.
- Uma sessão tem zero ou mais highlights; um highlight pertence a uma única sessão.

### 2.2 Conta e entrada
- Criar conta e entrar (hoje: e-mail e senha; login com Google 🟡, ver [arquitetura.md](arquitetura.md#decisões-em-aberto-)).
- Completar o perfil (nome, @usuário, data de nascimento) depois de criar a conta.
- Na primeira vez: pedir permissão de câmera (e de localização, para sugerir o local da sessão) e explicar o gesto **\ o /** de forma visual.
- Sair da conta a partir do Perfil.

### 2.3 Gravar uma sessão
1. **Preparar** — o usuário vê a câmera em tela cheia para posicionar o celular e, opcionalmente, escolhe com quais amigos está jogando ("gravar sozinho" ou "gravar com [amigo]").
2. **Gravar** — ao tocar em iniciar, a tela fica **preta pura** (economia de bateria em telas OLED), com apenas um ponto pulsando indicando que a detecção está ativa. A câmera continua gravando e mantendo o buffer de 30 s. Um toque na tela mostra por alguns segundos as opções **"Encerrar sessão"** e **"Cancelar gravação"**.
3. **Gesto detectado** — o app salva os últimos 30 s como highlight e mostra o aviso **"Highlight salvo"** por ~2,6 s. Depois volta sozinho ao estado de gravação, sem exigir toque.
4. **Encerrar** — o usuário encerra a sessão e confirma os dados: nome, data e horário de início–fim (preenchidos automaticamente, editáveis), local (sugerido pela localização, editável) e participantes (pode adicionar mais). **"Salvar sessão"** volta à Início com a sessão nova no topo; **"Descartar"** abandona a sessão.

### 2.4 Ver sessões e highlights
- **Início** lista todas as sessões das quais o usuário participa, da mais recente para a mais antiga.
- **"Ver highlights"** abre a sessão, que mostra seus highlights em ordem cronológica, em lista vertical.
- Tocar num highlight reproduz o vídeo.

### 2.5 Amigos
- Lista de amigos com busca.
- Convidar amigos.
- 🟡 Menu de ações por amigo (⋮) — ações a definir.
- A lista de amigos alimenta o seletor "gravar com" da tela de gravação.

### 2.6 Perfil
- Foto (editável), nome, estatísticas rápidas: nº de sessões, nº de highlights, nº de amigos.
- Editar nome, nome de usuário e notificações.
- Sair da conta.

---

## 3. Regras de negócio

Regras marcadas com 🟡 são **propostas ainda não confirmadas pelo grupo** — implemente de forma que seja fácil mudar.

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

### Fluxo principal (caminho feliz da demo)

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

## 4. Telas

Cada tela lista **objetivo, conteúdo, estados e navegação**. A aparência está no [design.md](design.md) e nos canvas do Claude linkados lá. As telas de onboarding já estão desenhadas (direção C); as demais ainda vão ser redesenhadas na C 🟡, e a descrição abaixo vale para o comportamento.

### Mapa de navegação

```
Boas-vindas ─► Como funciona ─► Criar conta ─► Complete seu perfil ─► Início
     └──────────────► Entrar ───────────────────────────────────────► Início

                 ┌──────────── navegação de nível superior ────────────┐
                 │  Início        Gravar          Amigos       Perfil  │
                 └────┬─────────────┬───────────────┬─────────────┬────┘
                      │             │               │             │
              "Ver highlights"   Gravação         (busca,       (editar
                      │          A → B ⇄ C → D    convidar)      campos)
                   Sessão           │
                      │          "Salvar sessão" → volta à Início
                   Player
```

- **Nível superior**: Início, Amigos, Perfil. A forma é a **roda** do protótipo v2 (botão no centro inferior; toque abre, arrastar e soltar escolhe) — decidida em 20/10/2026, 🟡 a confirmar com o grupo.
- **Gravar** é um destino da navegação, mas abre um fluxo **em tela cheia, sem navegação**.
- **Telas de detalhe** (Sessão, Confirme a sessão, Player) **não** mostram a navegação; têm voltar no topo.
- Ordem dos destinos: **Início · Gravar · Amigos · Perfil**.

### 4.1 Onboarding

O app abre aqui quando ninguém está logado. Quem está logado sem perfil cai direto em **Complete seu perfil**.

| Tela | Objetivo | Conteúdo | Navegação |
|---|---|---|---|
| **Boas-vindas** | Primeira impressão; ensinar o gesto antes de tudo | Nome Clippo, **\ o /** grande, "Levantou os braços, / o lance está salvo." | "Começar" → Como funciona · "Já tenho conta" → Entrar |
| **Como funciona** | O gesto em 3 passos | "Três passos. / Zero toques." e os passos: Apoie o celular · Jogue normalmente · Fez um lance bom? \ o / | Voltar → Boas-vindas · "Criar conta" → Criar conta · "Já tenho conta" → Entrar |
| **Criar conta** | Criar conta com e-mail e senha | E-mail, Senha (com medidor de 6 caracteres), Confirme a senha (✓ quando igual, "Não bate" quando diferente) | Voltar → Como funciona · "Criar conta" → Complete seu perfil · "Já tem conta? Entrar" → Entrar |
| **Entrar** | Entrar com e-mail e senha | E-mail, Senha, "Esqueci a senha" 🟡 *(recuperação de senha ainda não existe)* | Voltar → Boas-vindas · "Entrar" → Início · "Ainda não tem conta? Criar conta" → Criar conta |
| **Complete seu perfil** | Dados públicos e data de nascimento | Nome, Nome de usuário (@), Data de nascimento | "Continuar" → Início · "Sair" → Boas-vindas |

**Estados**
- **Validação:** nada é enviado sem passar pelas regras do app e, de novo, do servidor (e-mail no formato `nome@dominio.tld`; senha de 6 a 128 caracteres; nome até 50; @usuário de 3 a 20 com `a–z 0–9 _ .`; data de nascimento entre 1900 e hoje). Os erros aparecem embaixo de cada campo e somem quando a pessoa corrige.
- **Criar conta:** o botão "Criar conta" fica desabilitado até a senha ter 6+ caracteres e a confirmação ser igual. O e-mail é conferido ao tocar no botão.
- **Erros** (e-mail já usado, senha errada, sem internet…) aparecem em português abaixo dos campos, com o texto vindo do `AuthRepository`, e o campo do erro fica marcado. Em "E-mail ou senha incorretos.", os dois campos ficam marcados. No Complete seu perfil, o erro de um campo aparece logo abaixo dele.
- **Carregando:** o botão primário mostra que está trabalhando e não aceita um segundo toque.

🟡 **Permissões** — câmera (obrigatória) e localização (opcional, só para sugerir o local), cada uma com o porquê em uma frase, pedidas quando fizerem sentido. Ainda sem tela.

### 4.2 Início

**Objetivo:** ver as sessões de que participei e entrar numa delas.

**Conteúdo**
- Topo: saudação curta ("Boa noite, Gustavo") e o título **"Suas sessões"**; à direita, o avatar do usuário.
- Lista vertical de **cards de sessão em sanfona**, mais recente primeiro:
  - **Fechado:** nome · data · nº de highlights · botão de abrir.
  - **Aberto:** local, avatares dos participantes (até 5 + "+N"), duração, nº de participantes e o botão **"Ver highlights"**.
  - Só um card aberto por vez; o mais recente começa aberto.
- Navegação com **Início** ativo.

**Estados** 🟡
| Estado | O que mostrar |
|---|---|
| Carregando | Esqueletos no formato do card fechado. |
| Vazio | "Nenhuma sessão ainda", uma frase sobre o gesto e botão "Gravar primeira sessão". |
| Erro | Frase curta + "Tentar de novo". |
| Highlight enviando | No card, "enviando…" na linha de informações (ver R13). |

**Navegação:** tocar no card alterna aberto/fechado; **"Ver highlights" → Sessão**.

### 4.3 Sessão

**Objetivo:** assistir aos highlights de um jogo.

**Conteúdo**
- **Cabeçalho de impacto** com "‹ Sessões" para voltar, nome da sessão, "data · duração", local, avatares e "10 participantes".
- Seção **"Highlights"** com "7 lances salvos" à direita.
- Lista de **highlights** em ordem cronológica: miniatura com play, título do lance e "00:12:40 · 30s".
- **Sem** navegação de nível superior.

**Estados** 🟡
| Estado | O que mostrar |
|---|---|
| Carregando | Cabeçalho já preenchido; linhas em esqueleto. |
| Sem highlights | "Nenhum lance salvo nessa sessão" + lembrete do gesto. |
| Highlight enviando | Linha com miniatura local e "enviando…" no lugar da duração. |

**Navegação:** tocar num highlight → **Player**. 🟡 Menu do dono (editar nome/local, participantes) — a desenhar.

### 4.4 Player

🟡 *Ainda não desenhado.* Diretrizes:
- Vídeo em tela cheia sobre fundo preto.
- Controles mínimos: play/pause, fechar, compartilhar.
- Título do lance e nome da sessão em texto pequeno, sem cobrir o vídeo.
- 🟡 Deslizar para o próximo/anterior highlight da mesma sessão.

### 4.5 Gravação — 4 estados

A gravação ignora o tema claro/escuro.

**Estado A — Preparar**
- Imagem da câmera em **tela cheia**. A barra de status fica escura.
- Topo: voltar e a dica **"Apoie o celular e enquadre o campo"**.
- Embaixo, rótulo **"Gravar com"** e uma fileira rolável de chips: **"Gravar sozinho"** (padrão) e **"Com Rafa"**, **"Com Bruno"**… (amigos). 🟡 Um chip por vez ou vários (a regra R10 prevê vários amigos por sessão).
- **Botão de gravar** grande e a legenda "Iniciar detecção de gesto \ o /".
- Sem permissão de câmera 🟡: explicar por que é necessária + botão para permitir.

**Estado B — Gravando (standby)**
- Tela **preta pura** (nunca cinza escuro: em telas OLED o pixel desliga e economiza bateria), **nenhum** elemento além de um **pequeno ponto pulsando** no centro (ciclo lento de 2,6 s). A barra de status também fica preta.
- **Um toque** na tela mostra, por **3,2 s**, dois botões embaixo: **"Encerrar sessão"** (→ Estado D) e **"Cancelar gravação"** (→ volta ao Estado A 🟡 *confirmar o que acontece com highlights já salvos*).

**Estado C — Highlight salvo**
- Sobre o mesmo preto, sobe o aviso ✓ **"Highlight salvo"** · "últimos 30s · gesto \ o / detectado".
- Some sozinho após **~2,6 s** e volta ao Estado B. Não exige toque.
- 🟡 Vibração curta ao salvar.

**Estado D — Confirme a sessão**
- Cabeçalho: "‹ Voltar à câmera", "Gravação encerrada · 4 highlights" e o título **"Confirme a sessão"**.
- Campos preenchidos automaticamente e editáveis: **Nome da sessão**, **Data** e **Horário** (início – fim), **Local · sugerido por GPS**, **Participantes** (inclui "Você") + "+ adicionar".
- Botão primário **"Salvar sessão"** → volta à **Início**, com a nova sessão no topo.
- Link **"Descartar"** → descarta a sessão e volta à câmera 🟡 *(confirmar o que acontece com os highlights já salvos)*.

### 4.6 Amigos

**Objetivo:** gerenciar com quem eu jogo.

**Conteúdo**
- Título **"Amigos"** com o botão **"Convidar"**.
- Busca: "Buscar amigo ou usuário".
- Lista: avatar, nome e linha secundária ("12 sessões juntos", "nenhuma sessão ainda"), com menu **⋮** 🟡 *(ações a definir: remover, ver sessões juntos…)*.
- Navegação com **Amigos** ativo.

**Estados** 🟡: vazio ("Adicione quem joga com você" + Convidar); busca sem resultado; convites pendentes (se amizade exigir aceite).

### 4.7 Perfil

**Objetivo:** ver meu resumo e ajustar minha conta.

**Conteúdo**
- **Avatar grande** com opção de editar, nome e @usuário.
- **Três estatísticas**: sessões · highlights · amigos.
- Linhas: **Nome ›**, **Usuário ›**, **Notificações** (liga/desliga).
- **"Sair da conta"**, no fim.
- Navegação com **Perfil** ativo.

### Prioridade para a demo

Início → Sessão → Gravação (A–D) são o núcleo da proposta e precisam do maior acabamento. Amigos, Perfil e onboarding vêm depois.

---

## 5. Decisões em aberto 🟡 de produto

| Tema | Pergunta |
|---|---|
| Plataforma | iOS entra depois do MVP? |
| Cooldown | Quantos segundos ignorar gestos após um disparo? |
| Offline | Confirmar que highlights ficam no aparelho até haver internet. |
| Cancelar / Descartar | Highlights já salvos somem junto? Sessão sem highlights pode ser salva? |
| Participantes na gravação | Escolher um amigo por vez no chip, ou vários (como prevê R10)? |
| Permissões de sessão | Participantes podem sair de uma sessão? Dono pode remover alguém? |
| Amizade | Convite com aceite, ou adicionar direto? |
| Título do highlight | Quem escreve: o usuário depois, ou nasce automático ("Lance 3") e é editável? |
| Menu de amigo | Quais ações ficam no ⋮ da lista de amigos? |
| Recuperação de senha | "Esqueci a senha" aparece no Entrar, mas o fluxo ainda não existe. |
| Tela de permissões | Quando e como pedir câmera e localização. |
| Telas internas | Início, Sessão, Player, Gravação, Amigos e Perfil ainda vão ser redesenhadas na direção C. |
| Entrega final | Data de 04/12/2026 depende de aprovação do orientador. |

---

## 6. Equipe

| Área | Líder | Pacote |
|---|---|---|
| Gerência de projeto | Gabriel Capovilla | Planejamento, acompanhamento, entregas |
| Visão computacional | Eduardo Gomes | Detecção do gesto |
| Mobile | Otávio Rosa | Câmera, buffer de 30 s, salvamento |
| Front-end | Laura Suzuki | Identidade visual e telas |
| Back-end | Henrique Della | Pasta compartilhada, sessões, amigos |

Cada área tem um líder, mas todos passam por todas as áreas, com pareamento e revisão cruzada.
