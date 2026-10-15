# Design

Como o Clippo parece e soa, e como criar componentes no padrão. O que o app faz está em [produto.md](produto.md); como ele é construído, em [arquitetura.md](arquitetura.md).

Direção visual atual: **C**, aprovada em 14/10/2026. Os valores vivem em **um lugar só**: [`app/lib/core/theme/clippo_tokens.dart`](../app/lib/core/theme/clippo_tokens.dart). As tabelas abaixo explicam esses valores; se as duas divergirem, vale o código, e quem mudou um corrige o outro no mesmo PR.

> Unidades: `dp` para tamanhos e espaços, `sp` para texto (padrão Android). Largura de referência: 412 dp.

---

## 1. Princípios

O visual é esportivo e minimalista: um título condensado e forte por tela, todo o resto quieto, controles redondos e a cor da marca entrando e saindo com suavidade.

1. **Um grito por tela.** Só o título (`displayL`) é alto. Descrições, rótulos e links ficam em Archivo, discretos.
2. **Tudo que se toca é redondo.** Botões, voltar, passos, traços do medidor e o ✓ usam `radiusPill`. Campos usam `radiusField`. Não existe botão de canto reto.
3. **A marca é uma tela, não um enfeite.** O vinho ocupa a boas-vindas inteira e depois vira só um brilho no topo das outras telas (`backgroundGlow`). Nada de tarjas, selos ou faixas vinho espalhadas.
4. **Dois modos, a mesma voz.** O app segue o tema do sistema. Só fundo, superfície, texto e `accent` trocam; `wine`, `peach` e a tipografia ficam iguais.
5. **Funciona a 8 metros e no sol.** Texto principal com contraste alto, alvos de toque de 48 dp ou mais, frases curtas.
6. **O lance é o herói.** As imagens do app são os próprios lances: sem fotos de banco, ilustrações genéricas ou emojis decorativos.

---

## 2. Voz e texto

Todo texto do app (botões, avisos, estados vazios, erros, notificações) segue esta seção.

### Tom de voz

O Clippo fala como **um amigo do time que entende de tecnologia**: direto, animado na hora certa, nunca técnico.

| Somos | Não somos |
|---|---|
| **Curtos.** Quem lê está suado, na quadra, a metros do celular. | Explicativos, com parágrafos. |
| **Diretos.** Verbo na frente: "Gravar", "Salvar sessão". | Passivos: "A sessão foi salva com sucesso pelo sistema". |
| **Energéticos no momento do lance.** "Highlight salvo". | Eufóricos o tempo todo, com exclamações e emojis em tudo. |
| **Informais, em PT-BR.** Tratamos por "você". | Formais ("o usuário deverá…") ou com gírias forçadas. |
| **Claros sobre problemas.** "Sem internet. Seus highlights sobem quando conectar." | Técnicos ("Erro 503", "Falha na sincronização do bucket"). |

### Regras de escrita

- **Títulos de tela em MAIÚSCULAS, em duas linhas, com ponto final**: "TRÊS PASSOS. / ZERO TOQUES.", "CRIAR / CONTA.". É o único lugar com maiúsculas. No código, escreva o texto normal e aplique `.toUpperCase()` (o `ClippoScreenTitle` já faz isso).
- Fora do título, **frase normal**, não Título Com Cada Palavra Maiúscula.
- **Botões com verbo**, 1 a 3 palavras: "Começar", "Criar conta", "Gravar", "Salvar sessão", "Tentar de novo".
- **Sem ponto final** em botões, chips e avisos curtos. Com ponto final em frases completas e nos títulos de tela.
- **Erros dizem o que fazer**: "E-mail ou senha incorretos.", "Não bate".
- O gesto se escreve **\ o /** no texto corrido e **\O/** quando é marca gigante em Anton.
- **Números em algarismos**: "3 sessões juntos", "7 highlights". Durações: "1h 42min", "58min".
- **Datas**: "11 set 2026"; horários "19:30 – 21:12". 🟡 Para sessões recentes, "Hoje" e "Ontem" podem substituir a data.
- **Momento dentro da sessão**: "00:12:40" (horas:minutos:segundos desde o início da gravação), seguido da duração do trecho: "00:12:40 · 30s".
- Evite exclamação; no máximo uma, e só em comemoração. Sem emojis na interface.
- Separador de informações na mesma linha: ponto médio com espaços ( · ).

### Highlight, lance e sessão

- **Highlight** é o nome do trecho salvo — em botões, avisos e contadores ("Ver highlights", "Highlight salvo", "7 highlights"). Não use "clipe".
- **Lance** é a palavra do jogo, usada só em frases ("7 lances salvos", "Nenhum lance salvo nessa sessão").
- **Sessão** é o jogo gravado. Não use "partida", "jogo" ou "pasta" na interface.

### Microcopy de referência

Use exatamente assim.

**Onboarding (direção C)**

| Onde | Texto |
|---|---|
| Boas-vindas — marca | CLIPPO · \O/ |
| Boas-vindas — frase | LEVANTOU OS BRAÇOS, / O LANCE ESTÁ SALVO. |
| Boas-vindas — ações | Começar · Já tenho conta |
| Como funciona — título | TRÊS PASSOS. / ZERO TOQUES. |
| Como funciona — passos | Apoie o celular · Em qualquer canto da quadra, de frente para o jogo. / Jogue normalmente · O Clippo guarda sempre os últimos 30 segundos. / Fez um lance bom? \ o / · Levante os dois braços para a câmera e o lance fica salvo. |
| Como funciona — ações | Criar conta · Já tenho conta |
| Criar conta — título | CRIAR / CONTA. · Seus lances ficam guardados na sua conta. |
| Criar conta — campos | E-mail (voce@email.com) · Senha (mínimo de 6 caracteres) · Confirme a senha (repita a senha) |
| Medidor de senha | 6+ caracteres → Pronto |
| Confirmação diferente | Não bate |
| Criar conta — rodapé | Criar conta · Já tem conta? Entrar |
| Entrar — título | DE VOLTA / AO JOGO. · Seus highlights estão te esperando. |
| Entrar — campos | E-mail (voce@email.com) · Senha (sua senha) |
| Entrar — erro | E-mail ou senha incorretos. |
| Entrar — link | Esqueci a senha |
| Entrar — rodapé | Entrar · Ainda não tem conta? Criar conta |
| Completar perfil — título | QUASE / LÁ. · Escolha como seus amigos vão te achar. |
| Completar perfil — campos | Nome · Nome de usuário (@, letras, números, "_" e ".") · Data de nascimento (dd/mm/aaaa) |
| Completar perfil — nota da data | Não aparece no seu perfil. Usamos só para estatísticas gerais. |
| Completar perfil — ações | Continuar · Sair |
| Olho da senha (acessibilidade) | Mostrar senha · Ocultar senha |
| Voltar (acessibilidade) | Voltar |

**Erros de validação** (iguais no app e no servidor; aparecem embaixo do campo, em `label` / `error`)

| Campo | Texto |
|---|---|
| E-mail | Informe seu e-mail. · Esse e-mail não parece válido. |
| Senha | Informe a senha. · Use uma senha com pelo menos 6 caracteres. · A senha pode ter até 128 caracteres. |
| Confirmação | Repita a senha. · As senhas não são iguais. |
| Nome | Informe seu nome. · O nome pode ter até 50 caracteres. |
| Nome de usuário | Escolha um nome de usuário. · O nome de usuário precisa ter de 3 a 20 caracteres. · Use só letras sem acento, números, "_" e ".". · O ponto não pode ficar no começo, no fim ou repetido. |
| Data de nascimento | Informe a data de nascimento. · Data de nascimento inválida. |

**Telas internas** (vindas do protótipo v1; revisar quando forem redesenhadas na C)

| Onde | Texto |
|---|---|
| Início — saudação | Boa noite, Gustavo *(Bom dia / Boa tarde / Boa noite + primeiro nome)* |
| Início — título | Suas sessões |
| Card de sessão | 11 set 2026 · 7 highlights |
| Card aberto — botão | Ver highlights |
| Participantes | 10 participantes |
| Sessão — voltar | Sessões |
| Sessão — seção | Highlights · 7 lances salvos |
| Linha de highlight | 00:12:40 · 30s |
| Gravação — dica | Apoie o celular e enquadre o campo |
| Gravação — rótulo dos chips | Gravar com |
| Chip padrão | Gravar sozinho |
| Chip de amigo | Com Rafa *(primeiro nome)* |
| Legenda do botão de gravar | Iniciar detecção de gesto \ o / |
| Aviso ao salvar | **Highlight salvo** · últimos 30s · gesto \ o / detectado |
| Controles do standby | Encerrar sessão · Cancelar gravação |
| Fim — voltar | Voltar à câmera |
| Fim — resumo | Gravação encerrada · 4 highlights |
| Fim — título | Confirme a sessão |
| Fim — rótulos | Nome da sessão · Data · Horário · Local · sugerido por GPS · Participantes |
| Fim — participante você | Você |
| Fim — adicionar | + adicionar |
| Fim — ações | Salvar sessão · Descartar |
| Amigos — botão | Convidar |
| Amigos — busca | Buscar amigo ou usuário |
| Amigos — linha secundária | 12 sessões juntos · nenhuma sessão ainda |
| Perfil — estatísticas | sessões · highlights · amigos |
| Perfil — linhas | Nome · Usuário · Notificações |
| Sair | Sair da conta |

**Estados** 🟡

| Onde | Texto |
|---|---|
| Início vazio — título | Nenhuma sessão ainda |
| Início vazio — texto | Posicione o celular, comece a gravar e faça \ o / quando rolar um lance bom. |
| Início vazio — botão | Gravar primeira sessão |
| Sessão sem highlights | Nenhum lance salvo nessa sessão |
| Highlight ainda subindo | enviando… |
| Sem internet | Sem internet. Seus highlights sobem quando conectar. |
| Erro genérico | Algo deu errado. |
| Botão de erro | Tentar de novo |
| Amigos vazio | Adicione quem joga com você |
| Permissão de câmera | O Clippo precisa da câmera para gravar os lances. |
| Permissão de localização | Usamos sua localização só para sugerir o local da sessão. |
| Frase-assinatura | Levantou os braços, o lance está salvo. |

### Glossário

Termo na interface (PT-BR) → nome no código (EN). Use sempre o nome em inglês em classes, variáveis, campos, rotas e coleções.

| Interface | Código | Observação |
|---|---|---|
| Usuário / você | `User` | |
| Perfil | `Profile` | Tela e dados públicos do usuário. |
| Nome de usuário (@) | `username` | |
| Amigo | `Friend` | |
| Amizade / convite | `Friendship` / `FriendInvite` | |
| Sessão | `Session` | Um jogo gravado; é a "pasta compartilhada". |
| Dono da sessão | `owner` | Quem iniciou a gravação. |
| Participante | `Participant` | |
| Highlight | `Highlight` | Trecho salvo pelo gesto. |
| Miniatura | `thumbnail` | |
| "00:12:40" | `offset` | Momento do highlight dentro da sessão. |
| Local | `location` | |
| Duração | `duration` | |
| Gesto \ o / | `Gesture` | |
| Disparo do gesto | `trigger` | |
| Buffer de 30 s | `Buffer` / `ringBuffer` | |
| Gravação (tela/fluxo) | `Capture` | Estados: `preparing`, `recording`, `saved`, `finishing`. |
| Início (tela) | `Home` | |
| Amigos (tela) | `Friends` | |
| Entrada (telas) | `onboarding` | Boas-vindas `Welcome`, Como funciona `HowItWorks`, Criar conta `SignUp`, Entrar `SignIn`, Complete seu perfil `CompleteProfile`. |

---

## 3. Cor, tipografia, espaço, forma e movimento

Todos os valores estão em [`clippo_tokens.dart`](../app/lib/core/theme/clippo_tokens.dart). Cores de tema se leem com `ClippoColors.of(context)` (atalho para `Theme.of(context).extension<ClippoColors>()!`).

### 3.1 Cores de marca (`ClippoBrand`, iguais nos dois temas)

| Token | Valor | Uso |
|---|---|---|
| `wine` | `#741A2F` | Fundo da boas-vindas; botão primário e destaque no modo claro |
| `wineDeep` | `#5C1425` | Pressionado de tudo que é vinho |
| `peach` | `#FFC6A8` | Accent: `\O/` e 2ª linha da boas-vindas; botão primário e destaque no modo escuro |
| `onWine` | `#FFF1E8` | Texto sobre vinho |
| `onPeach` | `#241014` | Texto sobre pêssego |
| `peachPressed` | `#FFC6A8` a 85 % | Pressionado de tudo que é pêssego |

**Gravação** (ignora o tema; continuam do design anterior até a gravação ser redesenhada na C)

| Token | Valor | Uso |
|---|---|---|
| `captureBackground` | `#000000` | Estados B e C. **Preto puro** — em telas OLED o pixel desliga. Nunca cinza escuro. |
| `captureOverlay` | `#141013` a 60 % | Voltar e dica flutuando sobre a câmera |
| `captureChip` / `captureChipBorder` | `onWine` a 12 % / 22 % | Chip não selecionado sobre a câmera |
| `captureTextMuted` | `onWine` a 70 % | Legendas sobre a câmera |
| `captureRecordRing` | `onWine` a 35 % | Anel do botão de gravar |
| `captureGhostBorder` | `onWine` a 32 % | Botão contornado sobre o preto ("Cancelar gravação") |

### 3.2 Cores de tema (`ClippoColors.dark` / `ClippoColors.light`)

| Token | Escuro | Claro | Uso |
|---|---|---|---|
| `background` | `#160A0D` | `#FBF4F0` | Fundo de tela (abaixo do brilho) |
| `backgroundGlow` | `#4A1220` | `#EED8D5` | Topo do degradê de fundo |
| `surface` | `#1E1719` | `#FFFFFF` | Campos de texto |
| `text` | `#FFF1E8` | `#241014` | Texto principal e ícones |
| `textMuted` | `#FFF1E8` a 62 % | `#241014` a 64 % | Subtítulos e descrições |
| `textLabel` | `#FFF1E8` a 55 % | `#241014` a 58 % | Rótulo dentro do campo, ícone do olho |
| `placeholder` | `#FFF1E8` a 32 % | `#241014` a 36 % | Texto de exemplo no campo |
| `accent` | `#FFC6A8` | `#741A2F` | 2ª linha do título, links, borda de foco, medidor, passo em destaque, ✓ |
| `primary` | `#FFC6A8` | `#741A2F` | Fundo do botão primário |
| `primaryPressed` | `peachPressed` | `wineDeep` | Botão primário pressionado |
| `onPrimary` | `#241014` | `#FFF1E8` | Texto sobre `primary` / `accent` preenchido |
| `controlSoft` | `#FFF1E8` a 10 % | `#241014` a 7 % | Fundo do círculo de voltar |
| `line` | `#FFF1E8` a 14 % | `#241014` a 12 % | Linha entre passos, traço vazio do medidor |
| `outline` | `#FFF1E8` a 30 % | `#241014` a 25 % | Contorno do círculo de passo |
| `error` | `#F2B8B5` | `#B3261E` | Erros de formulário (sempre com texto) |

O app segue o tema do sistema. O fundo da boas-vindas é sempre `wine`.

### 3.3 Tipografia (`ClippoText`)

Famílias: **Anton** (display) e **Archivo** (resto), embutidas em `app/assets/fonts/` (licença OFL). Nenhuma outra.

| Token | Família · peso | Tamanho | Altura de linha | Espaçamento | Uso |
|---|---|---|---|---|---|
| `heroMark` | Anton 400 | 184 | 0,82 | +1 % | `\O/` da boas-vindas |
| `displayL` | Anton 400 | 48 | 1,3 | +1 % | Título de tela (MAIÚSCULAS, 2 linhas) |
| `displayM` | Anton 400 | 40 | 1,3 | +1 % | Frase da boas-vindas |
| `wordmark` | Anton 400 | 20 | 1,0 | +14 % | "CLIPPO" no topo da boas-vindas |
| `titleS` | Archivo 700 | 19 | 1,2 | 0 | Título de passo/item |
| `input` | Archivo 500 | 18 | 1,25 | 0 | Valor digitado |
| `button` | Archivo 700 | 17 | 1,2 | 0 | Botão primário |
| `bodyL` | Archivo 400 | 16 | 1,4 | 0 | Subtítulo do título |
| `link` | Archivo 600 | 16 | 1,2 | 0 | Botão de texto e link |
| `body` | Archivo 400 | 15 | 1,45 | 0 | Descrições |
| `label` | Archivo 600 | 13 | 1,3 | 0 | Rótulo do campo, legenda, erro |
| `linkStrong` | Archivo 700 | 16 | 1,2 | 0 | Ação da `ClippoLinkLine` ("Entrar", "Criar conta") |
| `linkS` | Archivo 600 | 15 | 1,2 | 0 | Link ao lado de um erro ("Esqueci a senha") |
| `stepNumber` | Archivo 600 | 15 | 1,0 | 0 | Número no círculo de passo |
| `errorInline` | Archivo 600 | 14 | 1,3 | 0 | Erro na linha do "Esqueci a senha" |

Números que mudam (contadores, tempo) usam algarismos de largura fixa (`ClippoText.tabular`).

Títulos em Anton com mais de uma linha usam altura de linha **1,3** (era 1,0 no design C). Os acentos das maiúsculas sobem até 1,10 da altura da fonte e a cedilha desce 0,31; com menos que isso, "QUASE / LÁ." e "BRAÇOS, / O LANCE" se encostam. Só uma cedilha exatamente em cima de uma letra acentuada ainda pode tocar; evite essa combinação em títulos novos. Ajustado em 14/10/2026 depois do teste no emulador.

### 3.4 Espaço, forma e tamanhos (`ClippoSpace`, `ClippoRadius`, `ClippoSize`)

| Token | Valor | Uso |
|---|---|---|
| `spaceXs` | 4 | Entre traços do medidor |
| `spaceS` | 6 | Entre botão primário e botão de texto |
| `spaceM` | 10 | Entre campos |
| `spaceL` | 18 | Círculo do passo → texto; respiro lateral do campo |
| `gutter` | 28 | Margem lateral das telas |
| `section` | 32 | Voltar → título; subtítulo → 1º campo |
| `sectionL` | 48 | Topo → voltar; título → lista de passos |
| `screenBottom` | 34 | Último botão → base (+ área segura) |
| `titleToSubtitle` | 12 | Título → subtítulo |
| `labelToValue` | 3 | Rótulo do campo → valor |
| `fieldPaddingV` | 12 | Respiro vertical do campo |
| `fieldPaddingEndWithAction` | 8 | Respiro à direita do campo com botão (olho, ✓) |
| `stepGap` | 36 | Entre passos da `ClippoStepList` |
| `welcomeTop` · `welcomeHeroToPhrase` · `welcomePhraseToActions` | 60 · 26 · 56 | Boas-vindas: topo → "CLIPPO"; \O/ → frase; frase → botões |
| `radiusField` | 18 | Campos |
| `radiusPill` | 999 | Botões, círculos, traços do medidor |
| `buttonHeight` | 58 | Botão primário |
| `textButtonHeight` | 48 | Botão de texto |
| `control` | 44 | Desenho do círculo de voltar e do botão do olho |
| `minTouchTarget` | 48 | Área de toque mínima de qualquer controle, mesmo quando o desenho é menor |
| `step` | 36 | Círculo de passo |
| `check` | 26 | Círculo do ✓ |
| `meter` | 4 | Espessura do traço do medidor |
| `glowHeight` | 460 | Altura do degradê do topo |
| `backIcon` · `fieldIcon` · `checkIcon` | 22 · 20 · 16 | Chevron do voltar · olho no campo · ✓ no círculo |
| `spinner` | 20 | Indicador de carregando dentro do botão |
| `iconStroke` · `checkStroke` | 1,8 · 3 | Traço dos ícones de controle · traço do ✓ |
| `border` | 1,5 | Borda de foco/erro do campo, contorno e linha dos passos |

Espaços ficam em `ClippoSpace` (`spaceXs`…`screenBottom` e os demais respiros), raios em `ClippoRadius` (`radiusField`, `radiusPill`) e tamanhos em `ClippoSize`.

**Opacidades** (`ClippoOpacity`): `disabled` 45 % (controle desabilitado) · `textButton` 85 % (botão de texto).

Sem sombras, vidro ou desfoque. Profundidade vem de `surface` sobre `background` e do degradê do topo.

### 3.5 Movimento (`ClippoMotion`)

| Token | Valor | Uso |
|---|---|---|
| `standard` | `Cubic(0.2, 0.8, 0.2, 1)` | Curva padrão: sai rápido e assenta devagar |
| `enterFromWelcome` | 700 ms | Camada vinho some ao entrar vindo da boas-vindas |
| `focus` | 160 ms | Borda de foco do campo, traço do medidor |
| `enable` | 200 ms | Botão desabilitado → habilitado |
| `standbyPulse` · `savedBanner` · `stopControls` | 2,6 s · 2,6 s · 3,2 s | Gravação: ciclo do ponto pulsante · aviso "Highlight salvo" · controles após um toque |

A camada vinho só aparece na saída da boas-vindas ("Começar" e "Já tenho conta"); voltar entre as outras telas usa a transição normal. Com "reduzir movimento" (`MediaQuery.disableAnimations`), sem a camada vinho e sem transições.

### 3.6 Ícones

- **Outline**, traço de 1,6–1,8 na grade de 24, pontas e junções arredondadas, **sem preenchimento** em nenhum estado.
- Cor: `text` por padrão, `textLabel` dentro de campos, `onPrimary` sobre `primary`.
- Usados no onboarding: voltar (chevron, traço 1,8, 22 dp), olho / olho cortado (20 dp), ✓ (traço 3, dentro do círculo `check`). Hoje são desenhados em código, nos próprios componentes.
- SVGs da marca para as próximas telas: [`app/assets/icons/`](../app/assets/icons/) (grade 24, `stroke="currentColor"`, traço 1,6): `home`, `capture`, `friends`, `profile`, `play`, `clock`, `map-pin`, `search`, `plus`, `check`, `chevron-left`, `chevron-right`, `chevron-down`, `more-vertical`, `edit`, `logout`, `tripod`, `close`, `highlights`. Ainda não estão registrados no `pubspec.yaml`: o app precisa de um jeito de desenhar SVG antes.
- Precisa de outro ícone? **Lucide** ou **Phosphor (Light)** combinam; ajuste o traço e adicione o SVG à pasta.

### 3.7 Marca

- Ainda **não há logotipo** 🟡. O nome aparece como texto: **CLIPPO** em `wordmark`.
- Ícone do app: 🟡 a definir. Sugestão coerente: fundo `wine` sólido com **\O/** em `peach`.
- Frase-assinatura: **"Levantou os braços, o lance está salvo."**

---

## 4. Componentes

Ficam em [`app/lib/core/widgets/`](../app/lib/core/widgets/), um arquivo por componente. **Os componentes são feitos pelo Gabriel (com o Claude) e entregues prontos**: o resto do time usa os que existem. Se nenhum servir, peça um novo ao Gabriel em vez de criar um parecido dentro da feature. A seção 5 é o padrão que quem cria componentes segue.

- **`ClippoScreenGround`** — fundo de toda tela depois da boas-vindas: degradê vertical de `backgroundGlow` para `background` nos primeiros `glowHeight`, depois `background` liso. Padding `gutter` nas laterais, `sectionL` no topo (abaixo da área segura) e `screenBottom` + área segura embaixo. Com `enterFromWelcome: true`, uma camada `wine` cobre a tela e some em 700 ms (`standard`), sem bloquear toques. Recebe o conteúdo em `child` e a pilha de ações em `footer`, que fica presa no rodapé e rola junto quando não cabe (fonte grande, teclado aberto). Já inclui o `Scaffold` e a cor dos ícones da barra de status.
- **`ClippoBackButton`** — círculo `control` com fundo `controlSoft` e chevron para a esquerda (traço 1,8, 22 dp, `text`). Área de toque `minTouchTarget`. Semântica "Voltar".
- **`ClippoScreenTitle(line1, line2, subtitle?)`** — `displayL` em MAIÚSCULAS, linha 1 em `text`, linha 2 em `accent`; subtítulo em `bodyL` / `textMuted` 12 dp abaixo. Fica `section` abaixo do voltar.
- **`ClippoPrimaryButton(label, onPressed, enabled, loading)`** — largura total, altura `buttonHeight`, `radiusPill`, fundo `primary` (pressionado `primaryPressed`), texto `button` em `onPrimary`. Desabilitado = 45 % de opacidade, animando em `enable`. `loading` mostra um indicador e ignora toques. Variante `ClippoPrimaryButton.onWine` para a boas-vindas: fundo `peach` (pressionado `peachPressed`), texto `onPeach`.
- **`ClippoTextButton(label)`** — sem fundo, altura `textButtonHeight`, `link` em `text` a 85 % (na boas-vindas, `ClippoTextButton.onWine`: `onWine` a 85 %).
- **`ClippoLinkLine(prefix, action, onPressed)`** — centralizado, altura `textButtonHeight`: `prefix` em `bodyL` / `textMuted` + `action` em `linkStrong` / `accent`. A linha inteira é tocável. Ex.: "Já tem conta?" + "Entrar".
- **`ClippoTextField(label, hint, …)`** — bloco `surface`, `radiusField`, padding 12 · 18 (direita 8 quando há botão), sem borda em repouso, borda 1,5 em `accent` com foco (`focus`), em `error` com erro. Rótulo `label` / `textLabel` em cima; valor `input` / `text` 3 dp abaixo; hint em `placeholder`; cursor `accent`. Também aceita `prefixText` (o "@" do usuário), `readOnly` + `onTap` (campo que abre o seletor de data), `hasError` (só a borda) e `errorText` (borda + mensagem em `label` / `error` logo abaixo).
  - **Senha** (`ClippoTextField.password`): botão do olho à direita (`control`, transparente, ícone 20 em `textLabel`) alterna mostrar/ocultar, com a semântica "Mostrar senha" / "Ocultar senha".
  - **Confirmação** (`ClippoTextField.confirmation`, recebe o controller da senha): à direita, círculo `check` em `accent` com ✓ (traço 3) em `onPrimary` quando igual à senha; "Não bate" em `label` / `error` quando o tamanho já alcançou o da senha e é diferente.
  - **Mensagem de erro geral:** `label` / `error`, abaixo dos campos.
- **`ClippoPasswordMeter(length)`** — 6 traços de espessura `meter`, largura flexível, `radiusPill`, `spaceXs` entre eles; acesos (`min(length, 6)`) em `accent`, os outros em `line`; legenda à direita em `label`: "6+ caracteres" (`textMuted`) ou "Pronto" (`accent`). Fica 10 dp abaixo do campo de senha, com recuo lateral de 6. Fora da semântica (o requisito já está no hint).
- **`ClippoStepList(steps, highlightIndex)`** — uma linha por passo: círculo `step` com número em Archivo 600 15 e contorno 1,5 em `outline`; o destacado é preenchido em `accent`, número em `onPrimary`; linha vertical 1,5 em `line` ligando os círculos; texto a `spaceL`: título `titleS`, descrição `body` / `textMuted` 6 dp abaixo; 36 dp entre passos. Cada passo é um `ClippoStep(title, description, titleAccent)`; `titleAccent` é o trecho final do título em `accent` (o "\ o /").
- **`ClippoIcon(shape, size, color)`** — apoio dos componentes: chevron, olho, olho cortado e ✓ desenhados em código na grade de 24, com os traços dos SVGs da marca. Telas não usam direto.

Para ver todos os componentes nos dois temas: catálogo do app › **Componentes** (`app/lib/dev/component_gallery.dart`), com botão para trocar o tema.

🟡 **Componentes das telas internas** (navegação, card de sessão, cabeçalho, linha de highlight, chips, switch, estatísticas, avatares, gravação): ainda vão ser desenhados na C pelo Gabriel (com o Claude) e entregues prontos nesta pasta. A especificação antiga (direção v1) está no histórico do Git, no `docs/04-design-system.md` do commit `51247d6`, só para consulta.

---

## 5. Como criar um componente no padrão Clippo

1. **Procure antes de criar.** Veja se um componente de `app/lib/core/widgets/` já resolve, talvez com um parâmetro a mais. Componente novo só quando nenhum serve.
2. **Só tokens.** Cores de `ClippoColors` (via `Theme.of(context).extension<ClippoColors>()`), textos de `ClippoText`, espaços de `ClippoSpace`, raios de `ClippoRadius`, tamanhos de `ClippoSize`, animações de `ClippoMotion`. Precisa de um valor que não existe? Adicione o token em `clippo_tokens.dart` e na tabela deste arquivo no mesmo PR.
3. **Siga as formas.** Tudo que se toca é redondo (`radiusPill`); blocos de conteúdo e campos usam `radiusField`. Sem sombra, vidro ou desfoque. Área de toque de pelo menos 48 dp (`minTouchTarget`).
4. **Siga a tipografia.** Anton só para o título da tela e para a marca. Todo o resto em Archivo, com os estilos da tabela.
5. **Use `accent` para o destaque desenhado** (pêssego no escuro, vinho no claro). Nunca pêssego como texto no claro nem vinho como texto no escuro.
6. **Dois temas, sempre.** Abra o componente nos dois modos antes do PR.
7. **Estados.** Desenhe repouso, pressionado, desabilitado (45 % de opacidade), foco e erro quando fizerem sentido.
8. **Acessibilidade.** Rótulo de semântica em todo botão só com ícone; erro nunca só pela cor; nada corta com a fonte do sistema a 130 %.
9. **Um arquivo por componente**, nome `Clippo<Nome>`, em `app/lib/core/widgets/`, com um comentário de uma linha dizendo quando usar.
10. **Registre.** Adicione o componente à lista "Componentes" deste arquivo e à galeria `app/lib/dev/component_gallery.dart` (aberta pelo catálogo `screen_catalog.dart`), e escreva um teste em `app/test/core_widgets_test.dart`.

### Regras

- Um título em Anton por tela; Anton nunca em botão, rótulo ou texto corrido.
- Todo controle é redondo (`radiusPill`); campos usam `radiusField`. Sem canto reto em botão.
- Sem sombras, vidro ou desfoque. O único degradê é o do `ClippoScreenGround`.
- `peach` nunca como texto sobre fundo claro; vinho nunca como texto no escuro (use `accent`).
- Sem indicadores decorativos (REC, relógio, contadores) fora da gravação.
- Preto puro (`captureBackground`) na gravação, nunca cinza escuro.
- Lista vertical para sessões e highlights, sem grade estilo Instagram.
- Textos da interface em PT-BR, na voz da seção 2.

### Acessibilidade

- Texto normal com contraste ≥ **4,5:1**; texto grande (24 dp ou mais), ícones, bordas de controle e anel de foco ≥ **3:1**, nos dois temas.
- Alvos de toque ≥ **48 dp**, mesmo quando o desenho é menor (o círculo de voltar tem 44 dp desenhados dentro de 48 de toque).
- Ícone sem texto tem rótulo de acessibilidade.
- Cor nunca é o único sinal (erro sempre com texto).
- Layouts aguentam fonte do sistema **130 %** maior sem cortar.

---

## 6. Checklist de tela nova

Confira antes de abrir o PR. Se algum item não fecha, converse com o grupo antes de inventar.

**Antes de começar**
- [ ] A tela está descrita em [produto.md › Telas](produto.md#4-telas) (objetivo, conteúdo, estados, navegação)? Se não, adicione lá primeiro.
- [ ] Ela atrapalha o fluxo da demo (Início → Gravar → gesto → Sessão)? Se sim, repense.
- [ ] Depende de alguma decisão 🟡? Leve ao grupo ou implemente de forma fácil de mudar.

**Visual**
- [ ] Montada com os componentes de `core/widgets/` sobre `ClippoScreenGround`; nenhum valor visual fora de `clippo_tokens.dart`.
- [ ] Um título `ClippoScreenTitle` e no máximo um botão primário; ações empilhadas no rodapé.
- [ ] Olhada nos **dois temas** (Configurações do Android › Tela › Tema escuro).

**Estados**
- [ ] Carregando, vazio (título + frase + ação), erro (frase curta + "Tentar de novo").
- [ ] Sem internet, se depende de dados remotos; sem permissão, se usa câmera ou localização.

**Texto**
- [ ] Segue a [voz](#2-voz-e-texto) e o microcopy; nomes no código em inglês, conforme o [glossário](#glossário).

**Acessibilidade**
- [ ] Alvos ≥ 48 dp, rótulos em botões só com ícone, nada corta com fonte a 130 %, erro não depende só da cor.

**Entrega**
- [ ] Tela adicionada ao catálogo `app/lib/dev/screen_catalog.dart`.
- [ ] Prints nos dois temas no PR.
- [ ] Criou token, componente ou regra nova? Atualizou este arquivo no mesmo PR.

---

## 7. Referências no Claude

- **Canvas das telas de onboarding (direção C)**, modo escuro e claro, clicáveis: <https://claude.ai/artifact/2VkZueZGbU3aH1TjV4M4xR>
- **Design system Clippo (direção C)**: <https://claude.ai/artifact/KigMEoe5UvsGj6z1giwUqa>

Se o canvas ou o design system mudarem, atualize este arquivo e `clippo_tokens.dart` no mesmo PR.

**Histórico** (direções anteriores, só para consulta):
- Manual de marca: <https://claude.ai/artifact/EjgsyTa3QHeP5XYYSgmhy4>
- Prompt de telas usado no Claude Design: <https://claude.ai/artifact/88Vp7qT43DokfXh7xS1qED>
- Protótipo v1 no Claude Design: <https://claude.ai/design/p/bdc6b3ae-9e35-41cb-a4f8-39dccd78d8d5?file=Clippo.dc.html>
- Protótipo v2 ("o lance é o herói", com a navegação em roda): <https://claude.ai/artifact/YKoWepb8PufB6XN6rwfBkq>
- Os arquivos dos protótipos v1 e v2 (HTML, capturas, `radial_nav.dart`) estão no Git, na pasta `docs/` do commit `51247d6`.
