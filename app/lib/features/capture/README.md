# features/capture — Gravação

Um fluxo de 4 estados que compartilham câmera, buffer de 30 s, detector do gesto e a sessão em andamento:
Preparar (`preparing`) → Gravando (`recording`) → Highlight salvo (`saved`) → Confirme a sessão (`finishing`).
Referência: `docs/produto.md` › 4.5 Gravação; regras R1–R8 e R14 em `docs/produto.md` › 3. Regras de negócio.

- `screens/` telas · `widgets/` peças só desta feature · `state/` a sessão em andamento · `data/` salvar sessão e highlights
- A lista de amigos do seletor "Gravar com" vem de `friendsRepository.watchFriendships()` (só as aceitas, `acceptedFriends`), nunca de `features/friends/`.
- "Salvar sessão" entrega tudo à fila de `lib/core/upload/` (R13): ela guarda no aparelho, chama o `saveSession` e sobe os vídeos. Erro de campo do servidor volta para a tela (`SessionsFailure.code`); sem internet, a sessão fica na fila e a tela segue.
- Lembrete: o highlight precisa estar salvo em até 3 s após o gesto, sem depender de internet nem de Cloud Functions.
