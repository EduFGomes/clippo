# AGENTS.md — regras do projeto Clippo para assistentes de IA

Leia isto antes de escrever qualquer código. Em caso de dúvida, os detalhes estão em
`docs/arquitetura.md` (decisões, modelo de dados e passo a passo de contribuição) e `docs/design.md` (visual, voz e componentes).

## O projeto em uma frase
App Android (Flutter) que guarda os últimos 30 s de uma partida; o gesto \ o / salva o trecho como highlight
visível aos participantes da sessão. Backend 100% Firebase, sem API própria.

## Estrutura
- `app/` — Flutter. Organização **por funcionalidade**: `lib/features/<feature>/{screens,widgets,state,data}` e `lib/core/` para o que é compartilhado.
- `backend/` — `firestore.rules`, `storage.rules`, `functions/` (TypeScript, Cloud Functions 2ª geração) e `tests/` (testes das regras no Emulator).
- `docs/` — três arquivos: `produto.md` (visão, regras de negócio R1–R16, telas, equipe), `design.md` (voz, glossário, tokens, componentes) e `arquitetura.md` (decisões, modelo de dados, como contribuir).

## Regras que não podem ser quebradas
1. **Código em inglês, interface em português (PT-BR)**, com os nomes do glossário de `docs/design.md` (`Session`, `Highlight`, `Capture`, `Home`…). Textos da interface seguem a voz de `docs/design.md`.
2. **Nada de valores visuais escritos à mão.** Cores, fontes, espaços, raios e animações vêm de `app/lib/core/theme/clippo_tokens.dart` (`ClippoColors`, `ClippoText`, `ClippoSpace`…). Precisa de um valor que não existe? Proponha no design system antes.
3. **Uma feature não importa nada de dentro de outra feature.** O que duas features usam vai para `app/lib/core/`.
4. **Telas não falam direto com o Firebase.** Usam repositórios em `app/lib/core/data/` (ex.: `AuthRepository`).
5. **O app não grava dados que precisam de validação.** Hoje o app não grava nenhuma coleção diretamente: tudo passa por Cloud Functions chamáveis. Não abra escrita nas Security Rules sem discutir com o back-end.
6. **Toda mudança em `firestore.rules` ou `storage.rules` vem com testes** em `backend/tests/` (pelo menos um "pode" e um "não pode").
7. **Nunca coloque segredos no repositório** (chaves de conta de serviço, `.env`). O Admin SDK só existe nas Functions.
8. **Nada do caminho crítico do gesto depende de internet ou de Cloud Functions** (R8, e o highlight salvo em até 3 s). A detecção roda no celular.
9. **Decisões marcadas com 🟡 nos docs estão em aberto.** Não as trate como fechadas; implemente de um jeito fácil de mudar e avise.
10. Mudanças em `app/android/` só quando necessário (permissões, minSdk, Firebase) e explicadas no PR.

## Padrões a copiar
- **Cloud Function chamável:** `backend/functions/src/users/completeProfile.ts` — (1) quem chamou? (2) valida antes de tocar no banco (validação em arquivo separado e testável), (3) grava tudo numa transação, (4) idempotente, (5) erros com `HttpsError` e mensagem em português pronta para a tela.
- **Gatilhos** (ex.: highlight criado) podem rodar mais de uma vez: escreva de forma idempotente.
- **Nova Function:** arquivo no domínio certo (`users/`, `friends/`, `sessions/`, `highlights/`, `maintenance/`) e exportada no `index.ts` **do domínio**. Região vem de `src/config.ts`.
- **Componentes visuais:** use os prontos de `app/lib/core/widgets/` (lista em `docs/design.md` › Componentes). Componentes novos são feitos pelo Gabriel; se nenhum serve, avise em vez de criar um parecido dentro da feature.
- **Tela:** veja `app/lib/features/onboarding/` (scaffold compartilhado em `widgets/`, uma tela por arquivo em `screens/`, erros traduzidos pelo repositório). Toda tela nova entra no catálogo `app/lib/dev/screen_catalog.dart` até a navegação definitiva existir.
- **Gerenciamento de estado:** ainda não escolhido 🟡 (área de front-end). Use `StatefulWidget`/`StreamBuilder` simples até a decisão; não adicione Provider/Riverpod/Bloc por conta própria.

## Ambiente local
- Tudo roda contra o **Firebase Emulator** com o projeto `demo-clippo` (sem custo, sem conta).
- Portas: Auth 9099 · Firestore **8180** · Storage 9199 · Functions 5001 · interface 4000. Se mudar uma, mude em `backend/firebase.json`, `backend/tests/firestore.rules.test.ts` e `app/lib/core/firebase/firebase_setup.dart`.
- App → Emulator: `10.0.2.2` no emulador do Android; IP do computador num celular real (`--dart-define=EMULATOR_HOST=...`).
- Região de tudo: `us-east1`.

## Antes de dizer que terminou
- `app/`: `flutter analyze` sem avisos e `flutter test` passando.
- `backend/functions/`: `npm run build` e `npm test` passando.
- Mexeu em regras: `cd backend/tests && npm test` (com o Emulator desligado).
- Tela nova: confira o checklist de tela nova em `docs/design.md`.
- Diga explicitamente o que **não** foi testado.
