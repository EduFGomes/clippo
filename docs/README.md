# Clippo — Documentação

> **Levantou os braços, o lance está salvo.**

Esta pasta reúne tudo o que um integrante precisa para criar telas e funcionalidades novas no Clippo sem ter participado das conversas de brainstorm e design. Ela descreve **o quê** o app faz, **como ele deve parecer e soar** e, desde a versão de outubro, **as decisões técnicas já tomadas** ([07 — Arquitetura](07-arquitetura.md)) e **como contribuir** ([08 — Como contribuir](08-como-contribuir.md)). Escolhas técnicas ainda em aberto estão listadas no 07.

## Por onde começar

| Se você vai… | Leia primeiro |
|---|---|
| Entender o projeto do zero | [01 — Produto](01-produto.md) |
| Implementar uma regra de negócio ou o backend | [02 — Funcionalidades e regras](02-funcionalidades.md) |
| Criar ou alterar uma tela | [03 — Telas](03-telas.md) → [Protótipo](prototipos/README.md) → [04 — Design system](04-design-system.md) |
| Escrever qualquer texto que aparece no app | [05 — Conteúdo e voz](05-conteudo-e-voz.md) |
| Abrir um PR com tela nova | [06 — Checklist de nova tela](06-checklist-nova-tela.md) |
| Entender a arquitetura, o modelo de dados e o que está decidido | [07 — Arquitetura](07-arquitetura.md) |
| Criar uma tela, uma Cloud Function ou mudar uma regra; combinados de Git | [08 — Como contribuir](08-como-contribuir.md) |
| Configurar cores/fontes no código | [`design-tokens.json`](design-tokens.json) |
| Usar os ícones da marca | [`assets/icons/`](assets/icons/) |

## Estrutura

```
docs/
├── README.md                  ← você está aqui
├── 01-produto.md              ← visão, problema, público, escopo, critérios de aceite
├── 02-funcionalidades.md      ← funcionalidades, conceitos, regras, fluxos
├── 03-telas.md                ← cada tela: objetivo, conteúdo, estados, navegação
├── 04-design-system.md        ← cores, tipografia, espaço, forma, ícones, componentes, movimento
├── 05-conteudo-e-voz.md       ← tom de voz, microcopy, glossário PT ↔ nomes no código
├── 06-checklist-nova-tela.md  ← o que conferir antes de entregar uma tela
├── 07-arquitetura.md          ← decisões técnicas, modelo de dados, ambientes, pendências
├── 08-como-contribuir.md      ← Git, PR, passo a passo de tela, Function e regra
├── design-tokens.json         ← todos os valores visuais em formato neutro (qualquer stack lê)
├── assets/icons/              ← ícones outline oficiais em SVG
└── prototipos/                ← protótipo navegável do Claude Design + capturas de cada tela
```

## Convenções do projeto

- **Documentação em português (PT-BR); código em inglês.** Nomes de classes, variáveis, campos e coleções usam os termos em inglês do [glossário](05-conteudo-e-voz.md#glossário).
- **O protótipo é a referência visual, e o design system o traduz em números.** Os dois estão alinhados. Se uma tela precisar de algo que não existe aqui (uma cor, um tamanho, um componente), proponha a adição no design system antes de inventar no código.
- **Decisões em aberto** estão marcadas com 🟡 nos arquivos. Não trate uma decisão em aberto como fechada: leve para o grupo.

## Equipe

| Área | Líder | Pacote |
|---|---|---|
| Gerência de projeto | Gabriel Capovilla | Planejamento, acompanhamento, entregas |
| Visão computacional | Eduardo Gomes | Detecção do gesto |
| Mobile | Otávio Rosa | Câmera, buffer de 30 s, salvamento |
| Front-end | Laura Suzuki | Identidade visual e telas |
| Back-end | Henrique Della | Pasta compartilhada, sessões, amigos |

Cada área tem um líder, mas todos passam por todas as áreas, com pareamento e revisão cruzada.

## Referências visuais publicadas

- Manual de marca (versão navegável): <https://claude.ai/artifact/EjgsyTa3QHeP5XYYSgmhy4>
- Prompt de telas usado no Claude Design: <https://claude.ai/artifact/88Vp7qT43DokfXh7xS1qED>
- Protótipo no Claude Design (cópia local em [`prototipos/`](prototipos/README.md)): <https://claude.ai/design/p/bdc6b3ae-9e35-41cb-a4f8-39dccd78d8d5?file=Clippo.dc.html>

O manual de marca e o prompt são anteriores ao protótipo. Se algo neles divergir desta pasta, **vale o que está aqui**.
