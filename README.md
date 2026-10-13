# Clippo

> **Levantou os braços, o lance está salvo.**

App Android que guarda sempre os últimos 30 segundos de uma partida amadora. Quando um jogador faz o gesto **\ o /** para a câmera, o trecho vira um *highlight* que todos os participantes da sessão veem.

## O que tem aqui

| Pasta | O que é | Comece por |
|---|---|---|
| [`docs/`](docs/README.md) | O quê o app faz, como parece e soa, **arquitetura** e **como contribuir** | [`docs/README.md`](docs/README.md) |
| [`app/`](app/README.md) | App Flutter (Android) | [`app/README.md`](app/README.md) |
| [`backend/`](backend/README.md) | Firebase: Security Rules, Cloud Functions (TypeScript) e testes | [`backend/README.md`](backend/README.md) |
| [`AGENTS.md`](AGENTS.md) | Regras do projeto para assistentes de IA (e um bom resumo para humanos) | — |

Leitura obrigatória antes do primeiro PR: [`docs/07-arquitetura.md`](docs/07-arquitetura.md) e [`docs/08-como-contribuir.md`](docs/08-como-contribuir.md).

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

| Área | Líder |
|---|---|
| Gerência de projeto | Gabriel Capovilla |
| Visão computacional | Eduardo Gomes |
| Mobile | Otávio Rosa |
| Front-end | Laura Suzuki |
| Back-end | Henrique Della |
