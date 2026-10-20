# lib/core — o que várias features compartilham

| Pasta | O que vai aqui |
|---|---|
| `theme/` | Tokens de design (`clippo_tokens.dart`) e o `ThemeData` claro/escuro. Telas **nunca** escrevem cores, tamanhos ou fontes na mão: usam `ClippoBrand`, `ClippoColors`, `ClippoText`, `ClippoSpace`, `ClippoRadius`, `ClippoSize`, `ClippoOpacity` e `ClippoMotion` (valores explicados em `docs/design.md`). |
| `data/` | Acesso a dados usado por mais de uma feature. Hoje: `AuthRepository` (conta e perfil) e `SessionsRepository` + `Session` (as sessões de que eu participo). Telas nunca chamam `FirebaseFirestore`/`FirebaseFunctions` direto. Highlights e amigos entram aqui quando forem modelados. |
| `format/` | Como a interface escreve data, hora, duração e contagens (`clippo_format.dart`): "11 set 2026", "19:30 – 21:12", "1h 42min", "7 highlights". As regras estão em `docs/design.md` › 2. Voz e texto. Telas e componentes não formatam na mão. |
| `widgets/` | Componentes prontos do design system (`ClippoScreenGround`, `ClippoPrimaryButton`, `ClippoTextField`…), um por arquivo. Lista e regras em `docs/design.md` › Componentes; todos aparecem na galeria do catálogo. |

Regra: uma feature pode usar `core/`, mas nunca importa nada de dentro de outra feature. Se duas features precisam da mesma coisa, ela sobe para cá.
