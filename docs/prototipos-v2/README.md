# Protótipo v2: "o lance é o herói"

Uma proposta alternativa às telas de [`../prototipos`](../prototipos/README.md), para comparar lado a lado. **A v1 não foi alterada.** Nada aqui vale como referência oficial até o grupo escolher.

| Arquivo | O que é |
|---|---|
| `index.html` | O protótipo. Um arquivo só, sem dependências: dois cliques e abre no navegador. Precisa de internet só para as fontes. |
| `flutter/clippo_tokens.dart` | Cores, textos, espaços, raios e movimento prontos para colar no app Flutter. |
| `flutter/radial_nav.dart` | A navegação em roda como widget Flutter, pronta para usar. |
| `telas/` | Capturas de cada tela nos temas claro e escuro, com os mesmos nomes da v1 (mais `00-boas-vindas`, `01b-navegacao-roda` e `02b-player`). |
| `README.md` | Este arquivo: o que mudou, por quê, e como cada tela vira Flutter. |

## Como usar

- **Navegar**: um celular funcional. Toque como no app. O fluxo da demo roda inteiro: Início → Gravar → escolher amigos → Iniciar → **gesto** (botão ao lado do celular ou tecla **G**) → toque na tela preta → Encerrar sessão → Salvar sessão → a sessão nova aparece no topo da Início → abrir → assistir.
- **Todas as telas**: todas lado a lado, na mesma ordem das capturas da v1.
- **Roda / Barra** no topo: alterna entre a navegação em roda (proposta) e a barra em cápsula da v1, para comparar.
- **Escuro / Claro** no topo. O escuro abre por padrão porque a personalidade do produto é "escuro, esportivo e vibrante" (01-produto).

---

## A ideia

A v1 segue o design system à risca, mas em quase todas as telas **o dado aparece antes do lance**: a Início é uma lista de nomes e datas, os vídeos da Sessão são miniaturas pequenas, e o gesto **\ o /**, que é o produto, aparece só como legenda. A v2 mantém os mesmos tokens, fontes, ícones e regras e muda a hierarquia, seguindo três frases da própria documentação:

1. **"O lance é o herói."** Vídeo e números grandes na frente, interface quieta em volta.
2. **"Levantou os braços, o lance está salvo."** O gesto vira a assinatura visual. **\ o /** em Bricolage 800 aparece grande nos momentos de impacto: boas-vindas, "Highlight salvo" e a dica da gravação.
3. **"Reagir com a mesma energia da jogada."** O "Highlight salvo" deixa de ser um aviso discreto e passa a ser o único momento que grita.

Continua valendo tudo do 04-design-system: pílula no uso diário, bloco vinho de canto reto no impacto, sem sombra, sem gradiente, sem vidro, ícones outline 1,6, vinho desenhado vira pêssego no escuro e preto puro na gravação.

## Navegação em roda (proposta)

A barra em cápsula vira **um único círculo vinho** no centro inferior, com o ícone da seção atual. Ele abre uma roda com as quatro seções num arco de 180° acima do botão, tudo ao alcance do polegar.

- **Tocar e escolher**: um toque abre a roda, outro toque escolhe a seção. Tocar fora ou no X fecha.
- **Segurar, arrastar e soltar** (como no Pinterest): a roda abre assim que o dedo encosta. A seção na direção do dedo acende com uma fatia inteira, como na roda de armas do GTA, e soltar confirma. Não precisa acertar o ícone, só a direção. Soltar perto do botão ou arrastar para baixo cancela.
- **Ordem, da esquerda para a direita**: Perfil · Início · Amigos · Gravar. É a ordem do design system publicado no Claude (artefato "CLIPPO"), que já previa essa roda. Gravar, a ação principal, fica sob o polegar direito.
- **Feedback**: vibração leve ao abrir, um "tique" a cada seção que acende e uma vibração mais forte ao confirmar. O nome da seção aparece grande acima do arco.
- **Acessibilidade**: continua sendo um menu com 4 botões para leitores de tela. No teclado, Enter abre, as setas escolhem e Esc fecha. No Android, "voltar" fecha a roda.

**Adaptada às regras do repositório** (o design system publicado usava desfoque e sombra, que o 04 §1 proíbe):

- o fundo atrás da roda é a própria cor da tela a 95 %, sem desfoque;
- o botão se separa do conteúdo por um anel de 4 dp na cor do fundo, não por sombra.

**Trade-off honesto**: a barra mostra as 4 seções o tempo todo, e a roda esconde três delas atrás de um toque. Em troca, a tela fica mais limpa ("o lance é o herói") e a navegação ganha um gesto próprio, que conversa com o \ o /. Vale testar com 2 ou 3 pessoas de fora do grupo, pedindo "vá para Amigos", para ver se descobrem o gesto sem explicação.

## O que mudou, tela a tela

| Tela | v1 | v2 | Por quê |
|---|---|---|---|
| **Boas-vindas** *(nova)* | Não existia (🟡 em 03-telas §7) | Bloco vinho com **\ o /** gigante em pêssego e a frase-assinatura, depois 3 passos e "Começar" | É a primeira impressão. A pessoa aprende o gesto antes de tudo. |
| **1 · Início** | Cards em sanfona só com texto | A sessão mais recente vira destaque: capa 16:9 com o último lance, tira com mais 3 lances e "+N", depois os detalhes e "Ver highlights". As anteriores viram linhas compactas com miniatura. | Abrir o app já mostra um lance. Some a sanfona (menos estado e menos animação no Flutter). |
| **2 · Sessão** | Cabeçalho vinho + linhas com miniatura 108×68 | Mesmo cabeçalho, agora com o **nº de lances** em destaque. Os highlights viram um feed vertical com miniatura **16:9 na largura toda**, numerados 01, 02… | Os vídeos são o conteúdo da tela. Continua lista vertical, sem grade (regra do 04 §12). |
| **Player** *(nova)* | Não existia (🟡 em 03-telas §3) | Preto, vídeo no centro, só o play sobre a imagem; título, barra de progresso, anterior/próximo, fechar e compartilhar | O fluxo da demo termina em "toca um → assiste". Sem essa tela, ele quebra. |
| **3A · Preparar** | Câmera + chips + botão | **Dica do gesto** com o boneco \ o / em pêssego ("Lance bom? Faça \ o /"), cantos de enquadramento, e **vários amigos** no "Gravar com" | O gesto é ensinado na hora em que importa. A seleção múltipla segue a regra R10 (🟡 em 03-telas). |
| **3B · Gravando** | Preto + ponto; toque mostra 2 botões | Igual, e o toque também mostra **tempo de gravação e nº de highlights** | Quem volta ao celular no meio do jogo quer saber se está gravando e quantos lances já foram. |
| **3C · Highlight salvo** | Faixa vinho baixa com ✓ | Bloco vinho maior: **\ o /** em 64 px que entra com impulso, "Highlight salvo", o nº do lance (#4) e uma barra pêssego que marca os 2,6 s até sumir | É o momento de impacto do produto, e precisa ser visto de longe (critério "funciona a 8 metros"). |
| **3D · Confirme** | Cabeçalho + formulário | O cabeçalho comemora o placar da noite (**4** em 64 px) e mostra os **lances gravados** logo abaixo. "Salvar sessão" fica fixo embaixo. | Antes de preencher dados, a pessoa vê o que ganhou. |
| **4 · Amigos** | Lista com ⋮ | Mesma estrutura. Rótulo "Jogaram com você" e busca funcionando | A lista não é ranking (tom de voz: celebrar o lance, não ranquear pessoas). |
| **5 · Perfil** | Avatar, estatísticas, ajustes | Igual, mais **"Seus últimos lances"** | Até no perfil, o lance vem antes do dado. |

## Propostas de adição ao design system

Nada disso está no `design-tokens.json`. Se o grupo aprovar a v2, entram no mesmo PR:

| Tipo | Nome | Valor | Onde |
|---|---|---|---|
| Texto | `impactNumber` | Bricolage 800 · 64 · 0,9 · −3 % | **\ o /** do "Highlight salvo", nº de highlights no "Confirme" |
| Tamanho | `thumbnail.feed` | 16:9, largura total | Feed da Sessão, capa da Início, Player |
| Tamanho | `thumbnail.strip` | 136 × 77 (16:9) | Tira de lances no Confirme |
| Cor | `textMuted` (claro) | `text` a **64 %** (era 60 %) | Resolve o ⚠️ de 4,4:1 sobre `surface` (04 §2.2) |
| Ícone | `gesture.svg` | Boneco \ o /, outline 1,6 | Dica da gravação |
| Ícone | `share.svg`, `pause.svg` | Outline 1,6 | Player |
| Componente | Navegação em roda | Botão 56 + anel 4 · raio do arco 118 · itens 56 · fatia de 52° | Substitui 7.1 (barra flutuante) se aprovada |
| Movimento | `pop` | `cubic-bezier(.34, 1.56, .64, 1)` | Entrada do **\ o /** no "Highlight salvo" |

Os SVGs dos três ícones novos estão no objeto `P` dentro de `index.html`, com o mesmo traço dos de `assets/icons/`.

---

## Como vira Flutter

O protótipo foi feito com o que o Flutter faz de forma nativa: só colunas, linhas, pilhas, bordas, cantos e opacidade. Não tem desfoque, sombra nem efeito que só funcione na web. `flutter/clippo_tokens.dart` traz os valores; use `Theme.of(context).extension<ClippoColors>()!` para as cores do tema.

### Componentes

| No protótipo | Em Flutter |
|---|---|
| Navegação em roda | Pronta em `flutter/radial_nav.dart`: `Listener` no botão (o arraste segue o mesmo dedo mesmo fora dele), `atan2` para achar a seção pela direção, `AnimationController` com `Interval` por item (cascata) e curva `ClippoMotion.pop`, `CustomPainter` para o arco e a fatia, `HapticFeedback`, `PopScope` para o voltar |
| Barra flutuante em cápsula (v1) | `Stack` + `Positioned(left: 24, right: 24, bottom: 22)` com `Container(height: 66, decoration: BoxDecoration(color: surface, border: Border.all(color: divider), borderRadius: BorderRadius.circular(999)))`; item ativo com `AnimatedContainer` no fundo `accentSoft` |
| Miniatura de vídeo (canto reto) | `AspectRatio(16/9)` + `Image.memory` / `Image.file` do thumbnail com `fit: BoxFit.cover`; `Container(color: thumbnailPlaceholder[i % 4])` enquanto carrega |
| Botão de play sobre o vídeo | `Container(shape: BoxShape.circle, color: thumbnailPlayScrim)` centralizado no `Stack` |
| Cabeçalho de impacto | `Container(color: wine, padding: impactHeaderPadding)` + `AnnotatedRegion<SystemUiOverlayStyle>` para a barra de status vinho |
| Card de sessão em destaque | `Container` com `BorderRadius.circular(30)`, borda `divider`, padding 10 |
| Tira de lances | `Row` com `Expanded` (Início) ou `ListView(scrollDirection: Axis.horizontal)` (Confirme) |
| Chips "Gravar com" | `ListView` horizontal de `FilterChip`, ou `AnimatedContainer` próprio em pílula (fica mais fiel) |
| Campos do "Confirme" | `TextField` com `InputDecoration.collapsed` dentro do card `radius 22` |
| Botão fixo embaixo | `Scaffold(bottomNavigationBar: SafeArea(child: …))` |
| Switch | `Switch` com `activeTrackColor: wine`, `activeThumbColor: onWine`, ou um `AnimatedAlign` de 50 × 29 |

### Telas

| Tela | Estrutura |
|---|---|
| Boas-vindas | `Scaffold` → `Column`: `Container(color: wine)` com `Text('\\ o /', style: impactNumber.copyWith(fontSize: 118))` + `screenTitle`; lista de 3 passos; `FilledButton` |
| Início | `CustomScrollView` com `SliverList`; lista termina com `SizedBox(height: 130)`; barra flutuante no `Stack` por cima |
| Sessão | `CustomScrollView`: `SliverToBoxAdapter` (cabeçalho) + `SliverList` de `AspectRatio(16/9)` + título |
| Player | `Scaffold(backgroundColor: Colors.black)` + `video_player` (`VideoPlayer` dentro de `AspectRatio`), `VideoProgressIndicator` com `colors: VideoProgressColors(playedColor: peach)`; `PageView` vertical para anterior/próximo |
| 3A Preparar | `Stack`: `CameraPreview` (pacote `camera`) em tela cheia + `CustomPainter` para os 4 cantos + dica, chips e botão de gravar por cima |
| 3B Gravando | `Scaffold(backgroundColor: Colors.black)`, `GestureDetector(onTap:)` na tela toda; ponto com `AnimationController(duration: 2600ms)..repeat(reverse: true)` em `ScaleTransition` (1 → 1,9) + `FadeTransition` (.45 → 1); `wakelock_plus` para a tela não apagar (R7). A câmera segue gravando, só o preview some. |
| 3C Highlight salvo | `AnimationController(2600ms)`: `SlideTransition` + `FadeTransition` com `Interval(0, .12)` na entrada e `Interval(.82, 1)` na saída; `ScaleTransition(curve: ClippoMotion.pop)` no **\ o /**; `LinearProgressIndicator(value: 1 - t)` como barra; `HapticFeedback.heavyImpact()` |
| 3D Confirme | `Scaffold` com `bottomNavigationBar` (Salvar + Descartar) e `ListView`: cabeçalho vinho, tira horizontal, cards de campo |
| Amigos | `TextField` de busca filtrando uma `ListView` de `ListTile` com avatar pêssego e `IconButton(more)` |
| Perfil | `Column` centralizada + `Row` de 3 blocos vinho com `SizedBox(width: 2)` entre eles, tira de lances, linhas em pílula |

### Movimento e acessibilidade

- Curva padrão: `ClippoMotion.standard`. Transição entre telas: `PageRouteBuilder` com fade + 10 dp de deslize, em 280 ms.
- Com `MediaQuery.of(context).disableAnimations`: só opacidade, sem deslize nem escala (como o `prefers-reduced-motion` do protótipo).
- Todo ícone sem texto tem `Semantics(label:)` / `tooltip`. Alvos de toque ≥ 48 com `SizedBox` ou `padding` em volta do desenho.

---

## Decisões em aberto que a v2 toca

- **Seleção múltipla no "Gravar com"**: a v2 permite. É o que a regra R10 prevê.
- **Título do highlight**: sessões novas nascem com "Lance 1, Lance 2…". É a opção "automático e editável" de 02 §5.
- **"Hoje" no lugar da data**: aparece na sessão recém-salva (🟡 em 05-conteudo-e-voz).
- **Sessão sem highlights**: o "Confirme" mostra "Nenhum lance salvo nessa sessão" e ainda deixa salvar. A decisão continua com o grupo.

> Os dados (nomes, locais, lances) são fictícios e iguais aos da v1, para facilitar a comparação. As miniaturas são desenhos que ocupam o lugar do frame real do vídeo.
