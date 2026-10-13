# lib/core — o que várias features compartilham

| Pasta | O que vai aqui |
|---|---|
| `theme/` | Tokens de design (`clippo_tokens.dart`) e o `ThemeData` claro/escuro. Telas **nunca** escrevem cores, tamanhos ou fontes na mão: usam `ClippoBrand`, `ClippoColors`, `ClippoText`, `ClippoSpace`, `ClippoRadius`, `ClippoSize` e `ClippoMotion`. |
| `data/` | Acesso a dados usado por mais de uma feature: sessões, highlights, amigos, usuário logado. Vazia até o modelo de dados do Firestore ser definido. |
| `widgets/` | Componentes do design system usados por mais de uma feature (botões pílula, chips, avatar…). |

Regra: uma feature pode usar `core/`, mas nunca importa nada de dentro de outra feature. Se duas features precisam da mesma coisa, ela sobe para cá.
