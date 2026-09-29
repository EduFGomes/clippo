# 03 — Telas

Cada tela abaixo lista **objetivo, conteúdo, estados e navegação**, conforme o [protótipo navegável](prototipos/README.md) — que é a referência visual. Os valores (cores, tamanhos, raios) estão no [04 — Design system](04-design-system.md); os textos seguem o [05 — Conteúdo e voz](05-conteudo-e-voz.md).

## Mapa de navegação

```
                 ┌──────────── barra flutuante (nível superior) ────────────┐
                 │  Início        Gravar          Amigos          Perfil    │
                 └────┬─────────────┬───────────────┬────────────────┬──────┘
                      │             │               │                │
              card aberto →     Gravação         (busca,          (editar
            "Ver highlights"   A → B ⇄ C → D     convidar)         campos)
                      │             │
                   Sessão        "Salvar sessão" → volta à Início
                      │
                   Player
```

- **Nível superior** (com barra de navegação): Início, Amigos, Perfil.
- **Gravar** é um destino da barra, mas abre um fluxo **em tela cheia, sem barra**.
- **Telas de detalhe** (Sessão, Confirme a sessão, Player) **não** mostram a barra; têm voltar no topo.
- Ordem da barra: **Início · Gravar · Amigos · Perfil**.

---

## 1. Início

📱 Protótipo: [claro](prototipos/telas/01-inicio-claro.png) · [escuro](prototipos/telas/01-inicio-escuro.png)

**Objetivo:** ver as sessões de que participei e entrar numa delas.

**Conteúdo**
- Topo: saudação curta ("Boa noite, Gustavo") e o título **"Suas sessões"**; à direita, o avatar do usuário.
- Lista vertical de **cards de sessão em sanfona**, mais recente primeiro ([componente 7.3](04-design-system.md#73-card-de-sessão-sanfona)):
  - **Fechado:** nome · data (em destaque) · nº de highlights · botão de abrir.
  - **Aberto:** local, avatares dos participantes (até 5 + "+N"), duração, nº de participantes e o botão **"Ver highlights"**.
  - Só um card aberto por vez; o mais recente começa aberto.
- Barra de navegação com **Início** ativo.

**Estados** 🟡 *(não estão no protótipo)*
| Estado | O que mostrar |
|---|---|
| Carregando | Pílulas "esqueleto" no formato do card fechado. |
| Vazio | "Nenhuma sessão ainda", uma frase sobre o gesto e botão "Gravar primeira sessão". |
| Erro | Frase curta + "Tentar de novo". |
| Highlight enviando | No card, "enviando…" na linha de metadados (ver R13). |

**Navegação:** tocar no card alterna aberto/fechado; **"Ver highlights" → Sessão**.

---

## 2. Sessão

📱 Protótipo: [claro](prototipos/telas/02-sessao-claro.png) · [escuro](prototipos/telas/02-sessao-escuro.png)

**Objetivo:** assistir aos highlights de um jogo.

**Conteúdo**
- **Cabeçalho de impacto** vinho, cantos retos, colado na barra de status (também vinho):
  - "‹ Sessões" para voltar.
  - Nome da sessão, "data · duração" e local.
  - Avatares sobrepostos + "10 participantes".
- Seção **"Highlights"** com "7 lances salvos" à direita.
- Lista de **linhas de highlight** em ordem cronológica: miniatura com play, título do lance e "00:12:40 · 30s".
- **Sem** barra de navegação.

**Estados** 🟡
| Estado | O que mostrar |
|---|---|
| Carregando | Cabeçalho já preenchido; linhas em esqueleto. |
| Sem highlights | "Nenhum lance salvo nessa sessão" + lembrete do gesto. |
| Highlight enviando | Linha com miniatura local e "enviando…" no lugar da duração. |

**Navegação:** tocar num highlight → **Player**. 🟡 Menu do dono (editar nome/local, participantes) — a desenhar.

---

## 3. Player

🟡 *Não está no protótipo.* Diretrizes:
- Vídeo em tela cheia sobre fundo preto.
- Controles mínimos com ícones outline: play/pause, fechar, compartilhar.
- Título do lance e nome da sessão em texto pequeno, sem cobrir o vídeo.
- 🟡 Deslizar para o próximo/anterior highlight da mesma sessão.

---

## 4. Gravação — 4 estados

A gravação ignora o tema claro/escuro.

### Estado A — Preparar

📱 Protótipo: [claro](prototipos/telas/03a-gravacao-preparar-claro.png) · [escuro](prototipos/telas/03a-gravacao-preparar-escuro.png)

- Imagem da câmera em **tela cheia** (no protótipo, um campo desenhado faz o papel da câmera). A barra de status fica escura.
- Topo: botão-círculo de voltar e a dica **"Apoie o celular e enquadre o campo"**.
- Embaixo, rótulo **"Gravar com"** e uma fileira rolável de chips: **"Gravar sozinho"** (padrão) e **"Com Rafa"**, **"Com Bruno"**… (amigos). 🟡 O protótipo permite escolher um chip por vez; a regra de participantes (R10) prevê vários amigos por sessão.
- **Botão circular grande** de gravar e a legenda "Iniciar detecção de gesto \ o /".
- Sem permissão de câmera 🟡: explicar por que é necessária + botão para permitir.

### Estado B — Gravando (standby)

📱 Protótipo: [claro](prototipos/telas/03b-gravacao-standby-claro.png) · [escuro](prototipos/telas/03b-gravacao-standby-escuro.png)

- Tela **preta pura**, **nenhum** elemento além de um **pequeno ponto vinho pulsando** no centro. A barra de status também fica preta.
- **Um toque** na tela mostra, por 3,2 s, dois botões embaixo: **"Encerrar sessão"** (→ Estado D) e **"Cancelar gravação"** (→ volta ao Estado A 🟡 *confirmar o que acontece com highlights já salvos*).

### Estado C — Highlight salvo

📱 Protótipo: [claro](prototipos/telas/03c-gravacao-salvo-claro.png) · [escuro](prototipos/telas/03c-gravacao-salvo-escuro.png)

- Sobre o mesmo preto, um **aviso vinho de canto reto** sobe na parte de baixo da tela: ✓ **"Highlight salvo"** e "últimos 30s · gesto \ o / detectado".
- Some sozinho após ~2,6 s e volta ao Estado B. Não exige toque.
- 🟡 Vibração curta ao salvar.

### Estado D — Confirme a sessão

📱 Protótipo: [claro](prototipos/telas/03d-gravacao-fim-claro.png) · [escuro](prototipos/telas/03d-gravacao-fim-escuro.png)

- **Cabeçalho de impacto** vinho: "‹ Voltar à câmera", "Gravação encerrada · 4 highlights" e o título **"Confirme a sessão"**.
- **Cards de campo**, preenchidos automaticamente e editáveis:
  - **Nome da sessão**.
  - **Data** e **Horário** (início – fim), lado a lado.
  - **Local · sugerido por GPS**, com ícone de local.
  - **Participantes**: chips pêssego com os nomes (inclui "Você") + chip "+ adicionar".
- Botão primário **"Salvar sessão"** → volta à **Início**, com a nova sessão no topo.
- Link **"Descartar"** → descarta a sessão e volta à câmera 🟡 *(confirmar o que acontece com os highlights já salvos)*.

---

## 5. Amigos

📱 Protótipo: [claro](prototipos/telas/04-amigos-claro.png) · [escuro](prototipos/telas/04-amigos-escuro.png)

**Objetivo:** gerenciar com quem eu jogo.

**Conteúdo**
- Título **"Amigos"** com o botão **"+ Convidar"** à direita.
- Busca em pílula: "Buscar amigo ou usuário".
- Lista: avatar, nome e linha secundária ("12 sessões juntos", "nenhuma sessão ainda"), com menu **⋮** à direita 🟡 *(ações a definir: remover, ver sessões juntos…)*.
- Barra de navegação com **Amigos** ativo.

**Estados** 🟡: vazio ("Adicione quem joga com você" + Convidar); busca sem resultado; convites pendentes (se amizade exigir aceite).

---

## 6. Perfil

📱 Protótipo: [claro](prototipos/telas/05-perfil-claro.png) · [escuro](prototipos/telas/05-perfil-escuro.png)

**Objetivo:** ver meu resumo e ajustar minha conta.

**Conteúdo**
- **Avatar grande** com selo de edição, nome e @usuário, centralizados.
- **Três blocos de estatística** vinho, de canto reto: sessões · highlights · amigos.
- Linhas em pílula: **Nome ›**, **Usuário ›**, **Notificações** (switch).
- **"Sair da conta"** — botão contornado, no fim.
- Barra de navegação com **Perfil** ativo.

---

## 7. Entrada / onboarding

🟡 *Não está no protótipo.* O que precisa existir:
1. **Boas-vindas** — nome Clippo + "Levantou os braços, o lance está salvo."
2. **Como funciona** — o gesto **\ o /** mostrado visualmente (traço outline ou vídeo curto), em no máximo 3 passos.
3. **Entrar / criar conta.**
4. **Permissões** — câmera (obrigatória) e localização (opcional, só para sugerir o local), cada uma com o porquê em uma frase, pedidas quando fizerem sentido.

Mesmo vocabulário visual: fundo do tema, título `screenTitle`, um botão primário por tela.

---

## Prioridade para a demo

Início → Sessão → Gravação (A–D) são o núcleo da proposta e precisam do maior acabamento. Amigos, Perfil e onboarding vêm depois.
