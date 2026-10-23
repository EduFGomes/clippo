# lib/core — o que várias features compartilham

| Pasta | O que vai aqui |
|---|---|
| `theme/` | Tokens de design (`clippo_tokens.dart`) e o `ThemeData` claro/escuro. Telas **nunca** escrevem cores, tamanhos ou fontes na mão: usam `ClippoBrand`, `ClippoColors`, `ClippoText`, `ClippoSpace`, `ClippoRadius`, `ClippoSize`, `ClippoOpacity` e `ClippoMotion` (valores explicados em `docs/design.md`). |
| `data/` | Acesso a dados usado por mais de uma feature. Hoje: `AuthRepository` (conta e perfil) e `SessionsRepository` + `Session` (as sessões de que eu participo). Telas nunca chamam `FirebaseFirestore`/`FirebaseFunctions` direto. Highlights e amigos entram aqui quando forem modelados. |
| `camera/` | A câmera do lado Dart: `ClippoCamera` (permissão, ligar, desligar e o fluxo de poses, pelos canais do código nativo em `android/.../camera/`) e `PoseFrame` (um quadro analisado pelo ML Kit, convertido em `BodyPose`). Quem abre a câmera é o Kotlin; aqui não tem câmera, só a conversa com ela. |
| `gesture/` | Detecção do gesto \ o / (produto.md › O gesto, R3). Hoje: `BodyPose` (os pontos do corpo que importam, independentes do modelo de pose) e `GestureRule` (a regra geométrica sobre um quadro, com os limites em `GestureThresholds`) e `GestureTrigger` (o disparo: gesto sustentado por um tempo mínimo e espera entre disparos, com os tempos em `GestureTriggerTimings`). `GesturePipeline` liga as duas aos quadros da câmera e entrega uma `GestureObservation` por quadro; a que tem `triggered` é a hora de salvar o highlight. Fica aqui, e não em `features/capture/`, para a Gravação e o onboarding poderem usar. |
| `format/` | Como a interface escreve data, hora, duração e contagens (`clippo_format.dart`): "11 set 2026", "19:30 – 21:12", "1h 42min", "7 highlights". As regras estão em `docs/design.md` › 2. Voz e texto. Telas e componentes não formatam na mão. |
| `widgets/` | Componentes prontos do design system (`ClippoScreenGround`, `ClippoPrimaryButton`, `ClippoTextField`…), um por arquivo. Lista e regras em `docs/design.md` › Componentes; todos aparecem na galeria do catálogo. |

Regra: uma feature pode usar `core/`, mas nunca importa nada de dentro de outra feature. Se duas features precisam da mesma coisa, ela sobe para cá.
