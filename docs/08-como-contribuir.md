# 08 — Como contribuir

Combinados do time e passo a passo das tarefas mais comuns. A parte de Git é uma **proposta** — ajustem na reunião se quiserem.

## Git (proposta)

- A `main` sempre compila e passa nos testes. **Ninguém commita direto nela.**
- Uma **branch por tarefa**, com prefixo: `feat/tela-inicio`, `fix/erro-login`, `docs/modelo-sessoes`, `chore/atualiza-firebase`.
- Commits curtos no formato `tipo: o que mudou`, em português: `feat: tela Complete seu perfil`.
- Terminou? Abra um **PR** e peça revisão de **uma pessoa de outra área** (todos passam por todas as áreas).
- Mudança em `firestore.rules`, `storage.rules` ou `app/android/` → revisão do back-end obrigatória.
- Faça `git pull` da `main` antes de começar e antes de abrir o PR.

### Checklist do PR

- [ ] `cd app && flutter analyze` sem avisos
- [ ] `cd app && flutter test` passando
- [ ] `cd backend/functions && npm run build && npm test` passando (se mexeu no backend)
- [ ] `cd backend/tests && npm test` passando (se mexeu em regras — com o Emulator desligado)
- [ ] Testei o fluxo no emulador com o Firebase Emulator rodando
- [ ] Tela nova: `docs/06-checklist-nova-tela.md` conferido e tela adicionada ao catálogo
- [ ] Coleção ou campo novo no Firestore: `docs/07-arquitetura.md` atualizado
- [ ] Escrevi no PR o que **não** testei

## Criar uma tela nova

Modelo para copiar: `app/lib/features/onboarding/`.

1. Ache a feature certa em `app/lib/features/` (veja o `README.md` de cada uma). Não existe? Crie a pasta com `screens/`, `widgets/`, `state/`, `data/` e um `README.md`.
2. Crie `screens/<nome>_screen.dart` com uma classe `<Nome>Screen`. Nomes em inglês, textos em português.
3. Visual **só com tokens**: `Theme.of(context).extension<ClippoColors>()!`, `ClippoText`, `ClippoSpace`. Referência visual: o protótipo em `docs/prototipos*/` e `docs/04-design-system.md`.
4. Precisa de dados? Use (ou crie) um repositório em `app/lib/core/data/`. A tela nunca chama `FirebaseFirestore`/`FirebaseFunctions` direto.
5. Adicione uma linha em `app/lib/dev/screen_catalog.dart` para o time conseguir abrir a tela.
6. Escreva pelo menos um teste em `app/test/` (a tela abre, o texto principal aparece).
7. Rode o checklist do PR.

## Criar uma Cloud Function

Modelo para copiar: `backend/functions/src/users/completeProfile.ts` (chamável) e `validation.ts` (validação testável).

1. **Gatilho ou chamável?**
   - O usuário fez uma ação e a função precisa dos dados que ele enviou → **chamável** (`onCall`).
   - Algo aconteceu no banco/Storage e é preciso reagir (contador, notificação, limpeza) → **gatilho** (`onDocumentCreated`, `onObjectFinalized`, `onSchedule`…).
2. Crie o arquivo no domínio certo (`users/`, `friends/`, `sessions/`, `highlights/`, `maintenance/`) e exporte no `index.ts` **do domínio**.
3. Estrutura de uma chamável:
   1. `request.auth?.uid` — sem login, `HttpsError("unauthenticated", ...)`;
   2. valide e normalize os dados **antes** de tocar no banco (regras em arquivo separado, sem Firebase, com testes em `functions/test/`);
   3. grave tudo numa **transação** quando houver mais de um documento;
   4. seja **idempotente** (chamar duas vezes não pode duplicar nada);
   5. erros com `HttpsError` e mensagem em português pronta para a tela (`details: { field }` quando for de um campo).
4. Gatilhos podem disparar mais de uma vez: idempotência é obrigatória (ex.: use o ID do evento ou um documento de controle).
5. Lembre: o Admin SDK **ignora as Security Rules**. A Function é responsável por tudo que grava.
6. No app, chame pela camada `core/data` (veja `AuthRepository.completeProfile`).
7. Teste: `npm test` (validação) e o fluxo no Emulator (logs em <http://localhost:4000> → Logs).

## Mudar uma regra (Security Rules)

1. Edite `backend/firestore.rules` (ou `storage.rules`). Comente o porquê de cada `match`.
2. Em `backend/tests/firestore.rules.test.ts`, escreva pelo menos **um teste de "pode" e um de "não pode"**.
3. `cd backend/tests && npm test` (com o `firebase emulators:start` desligado).
4. Se a regra abre escrita para o app, explique no PR por que não pode ser uma Function (D7 em `07-arquitetura.md`).

## Trabalhando com IA

O arquivo `AGENTS.md` na raiz (e `CLAUDE.md`, que aponta para ele) é lido automaticamente pelas ferramentas de IA. Se o time combinar uma regra nova, **atualize o `AGENTS.md` no mesmo PR** — assim a IA de todo mundo passa a segui-la.

Peça para a IA explicar o que ela mudou e confira o checklist do PR antes de abrir: a revisão é de vocês, não dela.
