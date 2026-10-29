# Clippo — app Android (Flutter)

## Rodar

```bash
cd app
flutter pub get
flutter run          # com um emulador aberto ou um celular conectado
flutter analyze      # confere o código
flutter test         # roda os testes
```

O laboratório do gesto é instalado como um **segundo app** ("Clippo Lab"), ao lado do Clippo
normal, com o sabor `lab` do Android:

```bash
flutter run --flavor lab -t lib/dev/gesture_lab_main.dart
```

Sem `--flavor`, o `flutter run` usa o sabor `app` (o Clippo normal).

## Estrutura (por funcionalidade)

```
lib/
├── main.dart            só inicia o app
├── app.dart             MaterialApp e temas claro/escuro
├── core/                o que várias features compartilham (tema, dados, componentes)
├── dev/                 PROVISÓRIO: catálogo de telas até a navegação existir
└── features/
    ├── onboarding/      Entrada, login, permissões, explicação do gesto
    ├── home/            Início + Sessão + Player
    ├── capture/         Gravação (Preparar → Gravando → Highlight salvo → Confirme a sessão)
    ├── friends/         Amigos
    └── profile/         Perfil
```

Cada feature tem `screens/`, `widgets/`, `state/` e `data/`, e um `README.md` com o que ela cobre.

## Convenções

- **Código em inglês, interface em português**, com os nomes do glossário em `docs/design.md`.
- **Nada de valores visuais na mão**: cores, fontes e tamanhos vêm de `lib/core/theme/clippo_tokens.dart` (explicados em `docs/design.md`).
- **Componentes prontos** em `lib/core/widgets/`: use os que existem em vez de criar parecidos.
- **Uma feature não importa nada de dentro de outra.** O que é compartilhado vai para `lib/core/`.
- **Telas novas** entram no catálogo (`lib/dev/screen_catalog.dart`) para o time conseguir abrir.
- Antes de abrir um PR: `flutter analyze` sem avisos e `flutter test` passando, e conferir o checklist de tela nova em `docs/design.md`.

## Ainda em aberto

- Gerenciamento de estado (área de front-end).
- Navegação: barra (protótipo v1) ou roda (protótipo v2).
