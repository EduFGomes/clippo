# Clippo

> **Levantou os braços, o lance está salvo.**

App Android que guarda sempre os últimos 30 segundos de uma partida amadora. Quando um jogador faz o gesto **\ o /** para a câmera, o trecho vira um *highlight* que todos os participantes da sessão veem.

## Para a banca (entrega de 25/11/2026)

**O que funciona hoje**

- **Conta:** criar conta, entrar, "Esqueci a senha", completar o perfil (nome, @, foto) e excluir a conta.
- **Gravação:** o celular guarda os últimos segundos da partida (15 a 60 s). O gesto **\ o /** é detectado no próprio aparelho, sem internet, e o highlight é salvo com bip, flash e vibração.
- **Sessões:** a sessão gravada aparece no Início de todos os participantes. O dono renomeia ou apaga lances, adiciona amigos e junta duas sessões do mesmo jogo.
- **Envio:** os vídeos sobem numa fila que aguenta queda de internet e tenta de novo sozinha.
- **Player:** assistir aos highlights, com curtir (favoritos) e comentários.
- **Amigos e Perfil:** busca, convites com aceite e perfil com estatísticas.

**Roteiro da demo:** o [fluxo principal em `docs/produto.md`](docs/produto.md#fluxo-principal-caminho-feliz-da-demo). Os critérios de aceite estão em [Critérios de aceite](docs/produto.md#critérios-de-aceite), e o roteiro para medir o gesto está em [`app/lib/core/gesture/README.md`](app/lib/core/gesture/README.md).

**Qualidade:** em 24/11/2026 passavam **522 testes do app**, **126 das Cloud Functions** e **58 das Security Rules**, e o `flutter analyze` não dava nenhum aviso. Todo dado digitado é validado duas vezes, no app e no servidor (regra 0 do [`AGENTS.md`](AGENTS.md)).

**Próximos passos** (decisões em aberto 🟡, detalhadas em [`docs/arquitetura.md`](docs/arquitetura.md#decisões-em-aberto-) e [`docs/produto.md`](docs/produto.md#5-decisões-em-aberto--de-produto)):

- Medir a detecção com 3 a 6 pessoas no quadro.
- Fazer a fila de envio rodar com o app fechado (WorkManager).
- Fazer a limpeza automática dos vídeos depois de 60 dias, sem apagar os favoritos.
- Fazer o "Continuar com Google".
- Escrever a política de privacidade completa.
- Redesenhar as telas internas na direção C e definir o logotipo e o ícone definitivo.
- Publicar o app na faixa de teste interno da Play Store.

## O que tem aqui

| Pasta | O que é | Comece por |
|---|---|---|
| [`app/`](app/README.md) | App Flutter (Android) | [`app/README.md`](app/README.md) |
| [`backend/`](backend/README.md) | Firebase: Security Rules, Cloud Functions (TypeScript) e testes | [`backend/README.md`](backend/README.md) |
| [`AGENTS.md`](AGENTS.md) | Regras do projeto para assistentes de IA (e um bom resumo para humanos) | — |

## Documentação

| Arquivo | O que tem |
|---|---|
| [`docs/produto.md`](docs/produto.md) | O que o app faz e por quê: visão, regras de negócio R1–R17, telas, decisões de produto em aberto, equipe |
| [`docs/design.md`](docs/design.md) | Como o Clippo parece e soa: voz, glossário, cores, fontes, componentes e como criar um no padrão |
| [`docs/arquitetura.md`](docs/arquitetura.md) | Como o sistema é construído e como contribuir: decisões, modelo de dados, Git, Functions, Security Rules |

Leitura obrigatória antes do primeiro PR: [`docs/arquitetura.md`](docs/arquitetura.md).

## Instalação do zero (Windows)

Faça uma vez por máquina, nesta ordem. Os avisos ⚠️ são problemas que o time já encontrou.

1. **Git** e **Node.js 22** — <https://nodejs.org>
2. **Android Studio** — <https://developer.android.com/studio>. Depois, em **More Actions → SDK Manager → SDK Tools**:
   - marque **Android SDK Command-line Tools (latest)**;
   - marque **Show Package Details**, abra **NDK (Side by side)** e instale a versão que o build pedir (hoje, `28.2.13676358`). ⚠️ O Flutter não consegue instalar o NDK sozinho com a ferramenta nova do Android.
3. **Flutter SDK** — <https://docs.flutter.dev/get-started/install/windows>. Rode `flutter doctor`.
   - "Visual Studio" com ❌ pode ser ignorado (só serve para apps de desktop).
   - "Android license status unknown" pode ser ignorado se o app compilar.
4. **Java 21 ou mais novo** (o Emulator do Firebase exige). O Android Studio já traz um: adicione `C:\Program Files\Android\Android Studio\jbr\bin` ao *Path* do usuário (Iniciar → "Editar as variáveis de ambiente do sistema"). Confira com `java -version`.
5. **Firebase CLI**: `npm install -g firebase-tools`, depois `firebase --version`.
   - ⚠️ Se o PowerShell disser que "a execução de scripts foi desabilitada": `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`.

## Rodar tudo (3 terminais)

```powershell
# Terminal 1 — backend local (Emulator, sem custo)
cd backend\functions
npm install
npm run build
cd ..
firebase emulators:start          # interface em http://localhost:4000

# Terminal 2 — emulador de celular
flutter emulators --launch Medium_Phone

# Terminal 3 — app
cd app
flutter pub get
flutter run
```

Para rodar contra o **projeto real** (`clippo-dev`) em vez do Emulator: `flutter run --dart-define=USE_EMULATOR=false`,
depois de cadastrar o token do App Check do seu celular — passo a passo em
[`docs/arquitetura.md` › Projeto real](docs/arquitetura.md#projeto-real-clippo-dev).

Fluxo para conferir que está tudo certo: **Começar → Criar conta → Complete seu perfil → Salvar**. Em <http://localhost:4000> devem aparecer a conta (Authentication) e os documentos `users/`, `usernames/` e `userPrivate/` (Firestore).

## Problemas conhecidos

| Sintoma | Causa | Solução |
|---|---|---|
| `'firebase' não é reconhecido` | Firebase CLI não instalada | Passo 5 acima |
| `firebase-tools no longer supports Java version before 21` | Java antigo | Passo 4 acima |
| `Could not start Firestore Emulator, port taken` | Outro programa na porta | O projeto já usa **8180** para o Firestore. Se outra porta der conflito, veja `backend/README.md` |
| `Android sdkmanager did not install NDK ...` | Ferramenta nova do Android | Instale o NDK pelo SDK Manager (passo 2) |
| `this and base files have different roots` (Kotlin) | Projeto em um disco (D:) e cache do Flutter em outro (C:) | Já resolvido com `kotlin.incremental=false` em `app/android/gradle.properties`. Rode `flutter clean` |
| `npm test` em `backend/tests` não sobe | `firebase emulators:start` já está rodando | Os dois usam as mesmas portas: rode um de cada vez |
| App não conecta no Emulator num **celular de verdade** | `10.0.2.2` só vale no emulador do Android Studio | `flutter run --dart-define=EMULATOR_HOST=<IP do computador>` e o computador na mesma rede |

## Equipe

Áreas, líderes e pacotes: [`docs/produto.md` › Equipe](docs/produto.md#6-equipe).
