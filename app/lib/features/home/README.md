# features/home — Início, Sessão e Player

Ficam juntas porque mostram as mesmas sessões e highlights: a lista (Início), o detalhe (Sessão) e a reprodução (Player, que pode deslizar para o próximo highlight da mesma sessão).
Referência: `docs/03-telas.md` · 1. Início, 2. Sessão, 3. Player.

- `screens/` telas · `widgets/` peças só desta feature · `state/` estado compartilhado entre as telas · `data/` acesso a dados só desta feature
- Dados de sessões e highlights usados também por outras features ficam em `lib/core/data/`.
