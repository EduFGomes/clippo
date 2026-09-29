# 06 — Checklist de nova tela ou feature

Confira antes de abrir o PR. Se algum item não se aplica, tudo bem — se algum não fecha, converse com o grupo antes de inventar.

## Antes de começar

- [ ] A funcionalidade está descrita em [02 — Funcionalidades](02-funcionalidades.md)? Se não, adicione lá primeiro (o quê, regras, decisões em aberto).
- [ ] A tela está em [03 — Telas](03-telas.md) e no [protótipo](prototipos/README.md)? Se não, adicione ao 03 (objetivo, conteúdo, estados, navegação) e, se possível, desenhe no Claude Design.
- [ ] Ela atrapalha de alguma forma o fluxo da demo (Início → Gravar → gesto → Sessão)? Se sim, repense.
- [ ] Depende de alguma decisão 🟡? Leve ao grupo ou implemente de forma fácil de mudar.

## Visual

- [ ] Todas as cores, fontes, espaços e raios vêm de [`design-tokens.json`](design-tokens.json) — nenhum valor solto.
- [ ] Funciona e foi olhada nos **dois temas** (claro e escuro).
- [ ] Vinho usado como texto/ícone vem de `accentForeground` (vira pêssego no escuro), nunca vinho direto.
- [ ] Nomes e números em Bricolage; interface em Instrument.
- [ ] Pílula em botões, chips, busca e linhas; cantos retos só em blocos de impacto e miniaturas.
- [ ] No máximo **um** botão primário vinho por área visível.
- [ ] Comparou lado a lado com a captura do protótipo.
- [ ] Sem sombras, gradientes, vidro, ícones preenchidos ou terceira fonte.
- [ ] Margem lateral de 20 dp; se tem barra de navegação, a lista termina com 130 dp de folga.
- [ ] Ícones novos adicionados em `assets/icons/` no mesmo estilo (outline 1,6).

## Estados

- [ ] Carregando (esqueleto).
- [ ] Vazio (título + frase + ação).
- [ ] Erro (frase curta + "Tentar de novo").
- [ ] Sem internet, se a tela depende de dados remotos.
- [ ] Sem permissão, se usa câmera ou localização.

## Texto

- [ ] Segue o [tom de voz](05-conteudo-e-voz.md): curto, direto, verbo nos botões, sem emoji.
- [ ] Usa "highlight"/"lance"/"sessão" como no [guia](05-conteudo-e-voz.md#highlight-lance-e-sessão) e os textos da tabela de microcopy.
- [ ] Nomes no código em inglês, conforme o glossário.

## Acessibilidade

- [ ] Alvos de toque ≥ 48 dp.
- [ ] Ícones sem texto têm rótulo de acessibilidade.
- [ ] Layout aguenta fonte do sistema 130 % maior.
- [ ] Informação não depende só de cor.

## Entrega

- [ ] Prints da tela nos dois temas no PR.
- [ ] Se criou componente, token ou regra nova, atualizou esta pasta `/docs` no mesmo PR.
