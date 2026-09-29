# 04 — Design system

O Clippo guarda o lance, não o dado. Toda decisão visual serve a um momento: alguém faz o gesto, e o app precisa reagir com a mesma energia da jogada que acabou de acontecer.

**Fonte da verdade visual:** o [protótipo de alta fidelidade](prototipos/README.md). Este documento descreve em palavras e números o que o protótipo mostra; os mesmos valores estão em [`design-tokens.json`](design-tokens.json). **Nunca escreva uma cor, fonte ou tamanho "solto" no código** — use sempre o token.

> Unidades: `dp` para tamanhos e espaços, `sp` para texto (padrão Android). As medidas vêm de um protótipo com 412 dp de largura.

---

## 1. Princípios

1. **O lance é o herói.** Vídeo e números grandes chamam atenção; a interface em volta fica quieta.
2. **Dois ritmos de forma.** Tudo que é uso diário é **pílula** (confortável). Tudo que é **momento de impacto** é **bloco sólido vinho de canto reto**. Esse contraste é a assinatura visual do Clippo.
3. **Cor com intenção.** Vinho é ação e identidade; pêssego é pessoa e destaque. Nenhum dos dois vira fundo de tela.
4. **Plano, sem truques.** Sem gradientes, sem sombras, sem vidro/desfoque, sem ícones preenchidos. Profundidade vem da diferença entre fundo e superfície e de bordas finas.
5. **Funciona a 8 metros e no sol.** Contraste alto, textos curtos, alvos de toque grandes.

---

## 2. Cor

### 2.1 Cores de marca — iguais nos dois temas

| Token | Hex | Uso |
|---|---|---|
| `wine` | `#741A2F` | **Primária.** Botões, cabeçalhos de impacto, blocos de estatística, aviso "Highlight salvo", ponto de gravação, switch ligado. |
| `wineDeep` | `#5C1425` | Estado pressionado de tudo que é vinho. |
| `onWine` | `#FFF1E8` | Texto e ícones sobre vinho (9,8:1). Em textos secundários sobre vinho, use com 80–85 % de opacidade. |
| `peach` | `#FFC6A8` | **Accent.** Avatares com iniciais, chip selecionado, chips de participante, cor de destaque no tema escuro. |
| `onPeach` | `#241014` | Texto sobre pêssego (12:1). |

**Regras**
- Vinho e pêssego **nunca** são cor de fundo da tela inteira.
- **Pêssego = pessoas.** Todo avatar sem foto é um círculo pêssego com iniciais.

### 2.2 Cores de tema

| Token | Tema claro | Tema escuro | Uso |
|---|---|---|---|
| `background` | `#FBF4F0` | `#141013` | Fundo das telas. |
| `surface` | `#F3E4DC` | `#1E1719` | Cards, linhas, campos, busca, barra de navegação. |
| `text` | `#241014` | `#F6ECE7` | Texto principal e ícones. |
| `textMuted` | `text` a 60 % | `text` a 62 % | Texto secundário, metadados, ícones inativos, placeholders. |
| `divider` | `text` a 10 % | `text` a 13 % | Bordas de 1 dp de cards, campos e barra; separadores. |
| `accentSoft` | `wine` a 13 % | `wine` a 42 % | Fundo em pílula do item ativo da barra de navegação. |

O app segue o tema do sistema. Só fundo, superfície e texto mudam; as cores de marca ficam iguais.

> ⚠️ No tema claro, `textMuted` sobre `surface` fica em 4,4:1 — um fio abaixo do recomendado (4,5:1) para texto pequeno. Em textos importantes sobre card, prefira `text`; se for preciso, suba para 64 %.

### 2.3 Cor de destaque em primeiro plano

Vinho funciona muito bem **como preenchimento**, mas **como texto ou ícone sobre o fundo escuro ele quase some** (1,7:1). Por isso o protótipo troca o vinho "desenhado" por pêssego no tema escuro. Esse é o token `accentForeground`:

| Token | Tema claro | Tema escuro |
|---|---|---|
| `accentForeground` | `wine` `#741A2F` (10:1) | `peach` `#FFC6A8` (12,5:1) |

Use em: **data da sessão** nos cards, **ícone e rótulo ativos** da barra, ícone de local no formulário, **"Sair da conta"**, links.

### 2.4 Cores da gravação

A gravação ignora o tema.

| Token | Valor | Uso |
|---|---|---|
| `capture.background` | `#000000` | Estados B e C. **Preto puro** — em telas OLED o pixel desliga e economiza bateria. Nunca cinza escuro. |
| `capture.indicator` | `wine` | Ponto pulsante do estado B. |
| `capture.overlay` | `#141013` a 60 % | Botão voltar e dica flutuando sobre a câmera. |
| `capture.chip` / `chipBorder` | `onWine` a 12 % / 22 % | Chip não selecionado sobre a câmera. |
| `capture.textMuted` | `onWine` a 70 % | Legendas sobre a câmera. |
| `capture.recordRing` | `onWine` a 35 % | Anel do botão de gravar. |

### 2.5 Complementos (não aparecem no protótipo)

🟡 Necessários para estados que o protótipo não mostra. Use sempre com ícone ou texto, nunca só a cor.

| Token | Tema claro | Tema escuro | Uso |
|---|---|---|---|
| `error` | `#B3261E` | `#F2B8B5` | Mensagens de erro em formulários e falhas de envio. |
| `skeleton` | `#EAD5C9` | `#2A2023` | Blocos de carregamento. |

---

## 3. Tipografia

Duas famílias, nenhuma outra. Ambas gratuitas no Google Fonts.

| Família | Papel | Pesos |
|---|---|---|
| **Bricolage Grotesque** | **Tudo que é nome ou número**: títulos, nomes de sessão, títulos de highlight, nomes de amigos, valores de campo, estatísticas. | 700, 800 |
| **Instrument Sans** | Interface e apoio: botões, metadados, rótulos, placeholders, textos corridos. | 400, 600 |

- Bricolage Grotesque: <https://fonts.google.com/specimen/Bricolage+Grotesque>
- Instrument Sans: <https://fonts.google.com/specimen/Instrument+Sans>

### 3.1 Estilos

| Token | Família · peso | Tamanho | Linha | Espaçamento | Onde |
|---|---|---|---|---|---|
| `screenTitle` | Bricolage 800 | 38 | 1,02 | −3 % | "Suas sessões", "Amigos" |
| `sessionTitle` | Bricolage 800 | 36 | 1,02 | −3 % | Nome da sessão no cabeçalho vinho |
| `statNumber` | Bricolage 800 | 34 | 1,0 | 0 | Números do Perfil |
| `formTitle` | Bricolage 800 | 32 | 1,04 | −3 % | "Confirme a sessão" |
| `profileName` | Bricolage 800 | 30 | 1,1 | −2 % | Nome no Perfil |
| `cardTitleOpen` | Bricolage 800 | 25 | 1,1 | −2 % | Nome da sessão no card **aberto** |
| `sectionTitle` | Bricolage 800 | 22 | 1,1 | −2 % | "Highlights" |
| `cardTitle` | Bricolage 700 | 20 | 1,1 | −2 % | Nome da sessão no card **fechado** |
| `toastTitle` | Bricolage 800 | 20 | 1,2 | −1 % | "Highlight salvo" |
| `fieldValue` | Bricolage 700 | 20 | 1,2 | 0 | Valores dos campos do formulário |
| `itemTitle` | Bricolage 700 | 18 (19 em Amigos) | 1,15 | −1 % | Título do highlight, nome do amigo |
| `button` | Instrument 600 | 15 | — | 0 | Botão primário grande ("Salvar sessão") |
| `buttonSmall` | Instrument 600 | 13–14 | — | 0 | "Ver highlights", "Convidar", "Encerrar sessão" |
| `body` / `bodyStrong` | Instrument 400 / 600 | 14 | 1,4 | 0 | Placeholder da busca / linhas do Perfil |
| `caption` | Instrument 400 (600) | 13 | 1,4 | 0 | Local, @usuário, saudação |
| `meta` | Instrument 600 | 12,5 | 1,3 | 0 | Data, nº de highlights, duração, tempo do lance, chips |
| `overline` | Instrument 600 | 11,5 | 1,3 | +4 %, MAIÚSCULAS | Rótulos dos campos ("NOME DA SESSÃO") |
| `navLabel` | Instrument 600 | 10,5 | 1,2 | 0 | Rótulos da barra de navegação |

**Regras**
- Nomes e números em Bricolage; todo o resto em Instrument.
- Ênfase com **peso ou cor**, não com um tamanho fora da tabela.
- Números que mudam (contadores, tempo) com algarismos de largura fixa.
- Frase normal ("Suas sessões"), não Título Com Cada Palavra Maiúscula. Maiúsculas só no `overline`.
- 🟡 O protótipo usa 10,5 sp nos rótulos da barra; é o menor texto do app e não deve ser usado em nenhum outro lugar.

---

## 4. Espaço

| Token | Valor | Uso |
|---|---|---|
| `screenGutter` | 20 | Margem lateral das telas. |
| `screenTop` | 14 | Respiro entre a barra de status e o conteúdo. |
| `cardGap` | 12 | Entre cards de sessão. |
| `rowGap` | 11 | Entre linhas de highlight, linhas do Perfil e chips. |
| `sectionGap` | 22 | Entre cabeçalho de tela e conteúdo, entre blocos. |
| `listBottomInsetWithNav` | 130 | Folga no fim de toda lista em tela com barra de navegação. |
| `impactHeaderPadding` | 16 · 22 · 26 | Topo · laterais · base do cabeçalho vinho. |
| `minTouchTarget` | 48 | Alvo de toque mínimo, mesmo que o elemento visível seja menor. |

---

## 5. Forma

| Token | Valor | Onde |
|---|---|---|
| `radiusNone` | 0 | **Momentos de impacto**: cabeçalho da Sessão e do "Confirme a sessão", blocos de estatística, aviso "Highlight salvo". Também **miniaturas de vídeo**. |
| `radiusMedium` | 22 | Linha de highlight, cards de campo do formulário. |
| `radiusLarge` | 30 | Card de sessão **aberto**. |
| `radiusFull` | 999 | **Pílula**: botões, chips, busca, linhas do Perfil, card de sessão **fechado**, barra de navegação. Círculo: avatares, botão de gravar, botão do chevron. |

**Bordas:** 1 dp em `divider` em cards, linhas, campos, busca, barra e botões contornados.

**Sombras: nenhuma** dentro do app.

---

## 6. Ícones

- **Outline fino**, traço de **1,6** (na grade de 24), pontas e junções arredondadas.
- **Sem preenchimento em nenhum estado.** O estado ativo muda **só a cor**.
- Tamanhos: **23** (barra), **19** (voltar), **17–18** (dentro de botões e campos), **15** (metadados), **34** (botão de gravar).
- Cor padrão: `text`; inativo/secundário: `textMuted`; ativo: `accentForeground`; sobre vinho ou câmera: `onWine`.

Ícones em [`assets/icons/`](assets/icons/) (SVG, grade 24, `stroke="currentColor"`), com os mesmos traços do protótipo:

| Arquivo | Uso |
|---|---|
| `home.svg` | Início (barra) |
| `capture.svg` | Gravar (barra e botão de gravar) — câmera de vídeo |
| `friends.svg` | Amigos (barra) e nº de participantes |
| `profile.svg` | Perfil (barra) |
| `play.svg` | Reproduzir highlight |
| `clock.svg` | Duração e tempo do lance |
| `map-pin.svg` | Local |
| `search.svg` | Busca |
| `plus.svg` | Convidar |
| `check.svg` | "Highlight salvo" |
| `chevron-left.svg` | Voltar |
| `chevron-right.svg` | "Ver highlights", linhas do Perfil |
| `chevron-down.svg` | Abrir/fechar card de sessão (gira 180° quando aberto) |
| `more-vertical.svg` | Menu de ações na linha de amigo |
| `edit.svg` | Editar foto do perfil |
| `logout.svg` | Sair da conta |
| `tripod.svg` | Dica "Apoie o celular e enquadre o campo" |
| `close.svg` | Fechar (Player e diálogos — não aparece no protótipo) |
| `highlights.svg` | Extra, para nº de highlights se precisar de ícone |

Precisa de outro ícone? **Lucide** ou **Phosphor (Light)** combinam — ajuste o traço para 1,6 e adicione o SVG à pasta.

---

## 7. Componentes

### 7.1 Barra de navegação flutuante
Inspirada no padrão atual da Apple, **com fundo sólido** — nada de vidro.

- Cápsula (`radiusFull`), fundo `surface`, borda 1 dp `divider`, sem sombra.
- Altura **66**, recuada **24** das laterais e **22** do fundo (mais a área segura).
- 4 itens de **82** de largura, distribuídos: **Início · Gravar · Amigos · Perfil**.
- Cada item: ícone 23 em cima + rótulo `navLabel` embaixo (4–5 dp de espaço).
- **Ativo:** ícone e rótulo em `accentForeground`, sobre uma **pílula `accentSoft`** que ocupa o item (9 dp de respiro vertical).
- **Inativo:** ícone e rótulo em `textMuted`.
- O conteúdo rola por trás; toda lista termina com 130 dp de folga.

### 7.2 Botões

| Variante | Visual | Exemplo |
|---|---|---|
| **Primário** | Fundo `wine`, texto `onWine` `button`, pílula, 18 dp de respiro vertical, largura total | "Salvar sessão" |
| **Primário no card** | Igual, com 14 dp vertical, texto 14 e chevron à direita | "Ver highlights" |
| **Primário compacto** | Pílula `wine`, 11 × 17 dp, ícone 17 + texto 13 | "Convidar" |
| **Contornado** | Transparente, borda `divider`, texto e ícone em `accentForeground` | "Sair da conta" |
| **Texto** | Só texto `textMuted` 13/600, sem fundo | "Descartar" |
| **Claro sobre preto** | Fundo `onWine`, texto `onPeach` 13,5/600 | "Encerrar sessão" (gravação) |
| **Contornado sobre preto** | Borda `onWine` 32 %, texto `onWine` 82 % | "Cancelar gravação" |

- **Um primário vinho por área visível.**
- Pressionado: `wine` → `wineDeep`. Desabilitado: 40 % de opacidade.

### 7.3 Card de sessão (sanfona)
O card da Início **abre e fecha**. Só um fica aberto por vez; o primeiro começa aberto.

**Fechado** — pílula (`radiusFull`), fundo `surface`, borda `divider`, respiro 15 · 18 · 15 · 20:
- Nome da sessão em `cardTitle` (uma linha, com reticências).
- Linha `meta`: **data em `accentForeground`** · ponto de 3 dp · "7 highlights" em `textMuted`.
- À direita, botão-círculo de 32 com `chevron-down`, borda `divider`, ícone `textMuted`.

**Aberto** — cantos passam a `radiusLarge` (30) e a borda a vinho 28 %:
- Nome cresce para `cardTitleOpen`.
- O chevron vira círculo **preenchido de vinho**, ícone `onWine`, girado 180°.
- Aparece o conteúdo: local (ícone + `caption`), fila de avatares de 30 (sem sobrepor, 7 dp de espaço) + pílula contornada "+N", fio `divider`, duração e nº de participantes (`meta` com ícones), botão **"Ver highlights"**.
- Transição suave (ver [Movimento](#9-movimento)).

### 7.4 Cabeçalho de impacto
Usado na **Sessão** e no **Confirme a sessão**.
- Bloco `wine`, **cantos retos**, largura total. Na Sessão, a barra de status também fica vinho e o bloco começa colado nela; no "Confirme a sessão", a barra de status segue o fundo do tema.
- Respiro 16 · 22 · 26. Texto `onWine`.
- Linha de voltar: `chevron-left` 19 + rótulo 13/600 a 85 % ("Sessões", "Voltar à câmera"), 18 dp acima do título.
- Título em `sessionTitle` ou `formTitle`; linhas de apoio em 13,5 a 82 %.
- Sessão: avatares de 34 **sobrepostos** (−9 dp), contorno de 2 dp em `wine`, seguidos de "10 participantes".

### 7.5 Linha de highlight
- Card `surface`, borda `divider`, `radiusMedium` (22), respiro 10 · 16 · 10 · 10, 11 dp entre linhas.
- À esquerda, **miniatura 108 × 68 de canto reto**; no centro, botão de play circular de 30 com fundo `#141013` a 55 % e `play.svg` 15 em `onWine`.
- À direita: título em `itemTitle` (até 2 linhas) e, 6 dp abaixo, `clock` 14 + "00:12:40 · 30s" em `meta`/`textMuted`.

### 7.6 Card de campo (formulário)
- `surface`, borda `divider`, `radiusMedium` (22), respiro 14 × 20, 14 dp entre cards.
- Rótulo em `overline`/`textMuted` ("NOME DA SESSÃO", "LOCAL · SUGERIDO POR GPS").
- Valor em `fieldValue`, 5 dp abaixo. Ícone opcional à esquerda em `accentForeground`.
- Campos curtos lado a lado (Data | Horário) com 11 dp de espaço.

### 7.7 Chips
| Variante | Visual |
|---|---|
| **Seleção sobre a câmera** | Pílula 10 × 16, texto 13/600. Selecionado: `peach` + `onPeach`. Não selecionado: `onWine` 12 % com borda `onWine` 22 % e texto `onWine`. Rolagem horizontal. |
| **Participante** | Pílula 7 × 13, `peach` + `onPeach`, 12,5/600. |
| **Adicionar** | Mesma medida, contornado `divider`, texto `textMuted` ("+ adicionar"). |

### 7.8 Busca
Pílula `surface`, borda `divider`, respiro 13 × 20, `search.svg` 18 + placeholder `body` em `textMuted`.

### 7.9 Linha de amigo
- Sem card nem divisor; respiro vertical 11.
- Avatar 46 + 14 dp + nome em `itemTitle` (19) e linha secundária `meta` 12,5/400 em `textMuted`.
- À direita, `more-vertical.svg` 20 em `textMuted` (menu de ações 🟡).

### 7.10 Linha de configuração (Perfil)
- Pílula `surface`, borda `divider`, respiro 15 × 22, 11 dp entre linhas.
- Rótulo à esquerda em `bodyStrong`/`textMuted`; valor à direita em `bodyStrong`/`text` + `chevron-right` 17 em `textMuted`.
- Variante com **switch** no lugar do valor.

### 7.11 Switch
Trilho 50 × 29 em pílula, botão 23 com 3 dp de folga. Ligado: trilho `wine`, botão `onWine`, à direita. Desligado: trilho `divider`, botão `textMuted`, à esquerda.

### 7.12 Blocos de estatística
- Três blocos `wine` de **canto reto** lado a lado, separados por 2 dp.
- Respiro 16 × 14; número em `statNumber`/`onWine`; rótulo 11,5/600 a 82 % ("sessões", "highlights", "amigos").

### 7.13 Avatares
| Tamanho | Onde |
|---|---|
| 30 | Card de sessão aberto |
| 34 | Cabeçalho da Sessão (sobrepostos, contorno 2 dp `wine`) |
| 44 | Topo da Início |
| 46 | Lista de Amigos |
| 104 | Perfil, com selo de edição: círculo `wine` 34 com `edit.svg` 16 e contorno 3 dp na cor do fundo |

Sem foto: círculo `peach`, iniciais em Instrument 600 (Bricolage 800 no avatar de 104) em `onPeach`.

### 7.14 Gravação
- **Botão de gravar:** círculo 88 `wine`, anel de 3 dp em `onWine` 35 %, `capture.svg` 34 em `onWine`. Legenda abaixo em `meta` `onWine` 70 %: "Iniciar detecção de gesto **\ o /**" (o gesto em Bricolage 700).
- **Botões flutuantes sobre a câmera:** círculo 42 em `capture.overlay` (voltar); dica em pílula `capture.overlay` com `tripod.svg` 15 + texto 12,5/600.
- **Ponto de standby:** 11 dp, `wine`, pulsando (ver Movimento).
- **Aviso "Highlight salvo":** bloco `wine` de **canto reto**, 26 dp das laterais e 120 dp do fundo, respiro 16 × 20; `check.svg` 24 + "Highlight salvo" em `toastTitle` e, embaixo, "últimos 30s · gesto \ o / detectado" 12,5 a 82 %.

### 7.15 Estados vazios, carregando e erro
🟡 Não estão no protótipo. Siga o mesmo vocabulário:
- **Vazio:** `sectionTitle` + uma frase em `caption`/`textMuted` + botão primário.
- **Carregando:** formas reais dos componentes em `skeleton`, com leve pulsação de opacidade.
- **Erro:** frase curta + botão contornado "Tentar de novo".

---

## 8. Imagens e vídeo

- As imagens do app são **os próprios lances**. Sem fotos de banco, ilustrações genéricas ou emojis decorativos.
- Miniaturas recortadas para preencher, **canto reto**. Enquanto não carregam, use um dos tons de `thumbnailPlaceholder`.
- Sobre o vídeo, só o botão de play.

---

## 9. Movimento

Curva padrão: **`cubic-bezier(0.2, 0.8, 0.2, 1)`** — sai rápido e assenta devagar.

| Onde | Comportamento |
|---|---|
| Card de sessão abrindo | Cantos 999 → 30 e chevron girando em **300 ms**; área de conteúdo expande em **380 ms**; o conteúdo aparece (opacidade + desliza 6 dp) em 300 ms com 80 ms de atraso. Ao fechar, o conteúdo some rápido (160–200 ms). |
| Ponto de standby | Ciclo de **2,6 s**, ida e volta: escala 1 → 1,9 e opacidade 45 % → 100 %. Lento e calmo. |
| "Highlight salvo" | Duração total **2,6 s**: entra subindo 14 dp e aparecendo (primeiros ~12 %), fica parado, e sai subindo 6 dp e sumindo (a partir de ~82 %). Depois volta sozinho ao standby. |
| Controles do standby | Um toque na tela preta mostra "Encerrar sessão" e "Cancelar gravação" por **3,2 s**. |

Com "reduzir movimento" ativo no sistema: sem deslizes nem escala, só opacidade.

---

## 10. Marca

- Ainda **não há logotipo** 🟡. O nome aparece como texto: **Clippo** em Bricolage Grotesque 800, −2 %, em `wine` (ou `onWine` sobre vinho).
- Ícone do app: 🟡 a definir. Sugestão coerente: fundo `wine` sólido com símbolo simples em `peach`.
- Frase-assinatura: **"Levantou os braços, o lance está salvo."**

---

## 11. Acessibilidade

- Texto normal ≥ **4,5:1**; texto grande e ícones ≥ **3:1**. Pontos de atenção: `textMuted` sobre `surface` no claro (4,4:1) e o ponto de standby (discreto de propósito).
- Alvos de toque ≥ 48 dp — o botão-chevron de 32 e o menu de amigo precisam de área de toque maior que o desenho.
- Ícone sem texto tem rótulo de acessibilidade.
- Cor nunca é o único sinal.
- Layouts aguentam fonte do sistema 130 % maior sem cortar.

---

## 12. Faça / não faça

| ✅ Faça | ❌ Não faça |
|---|---|
| Pílula em botões, chips, busca, linhas e barra. | Cantos retos em botões ou pílula em blocos de impacto. |
| Blocos vinho de canto reto para cabeçalhos, estatísticas e o aviso de highlight. | Vinho ou pêssego como fundo de tela inteira. |
| Separar camadas com `surface` e bordas `divider`. | Sombras, gradientes, vidro/desfoque. |
| Ícones outline de 1,6, ativos mudando só a cor. | Ícones preenchidos, inclusive no estado ativo. |
| `accentForeground` para vinho "desenhado" (vira pêssego no escuro). | Texto ou ícone vinho sobre o fundo escuro. |
| Nomes e números em Bricolage; resto em Instrument. | Qualquer terceira fonte. |
| Lista vertical para sessões e highlights. | Grade estilo Instagram. |
| Preto puro na gravação. | Cinza escuro "parecido com preto" na gravação. |
