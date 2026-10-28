# camera — câmera nativa (CameraX + ML Kit)

Código Kotlin que abre a câmera, acha os pontos do corpo com o ML Kit e conversa com o Dart.
A regra do gesto e o disparo **não** ficam aqui: estão em Dart, em `app/lib/core/gesture/`.

| Arquivo | O que faz |
|---|---|
| `ClippoCameraSession.kt` | Abre a câmera traseira, liga os três fluxos (imagem, análise e buffer de 30 s), roda o ML Kit, manda os pontos para o Dart e salva os highlights. |
| `MultiPersonAnalyzer.kt` | Modo várias pessoas (o escolhido; 🟡 falta medir com 3–6 pessoas): o detector do MediaPipe (EfficientDet-Lite0, em `src/main/assets/`) acha cada pessoa (numa thread só dele, com a imagem pela metade; na GPU, ou no processador se ela falhar, como no S24), e cada pessoa tem um ML Kit só dela, em modo stream, lendo o recorte em volta dela. Sem ele, o ML Kit (modo stream) segue só a primeira pessoa que achou e pula para quem passar na frente dela. |
| `CameraPreviewFactory.kt` | Mostra a imagem da câmera dentro de uma tela Flutter (um `PreviewView` do CameraX). |
| `../MainActivity.kt` | Cria a sessão quando o Flutter sobe e repassa a resposta do pedido de permissão. |

## Ponte com o Dart

| Canal | Tipo | O quê |
|---|---|---|
| `clippo/camera` | `MethodChannel` | `hasPermission` → bool · `requestPermission` → bool · `start({accurate, multiPerson})` · `stop` · `saveHighlight({untilMicros})` → `{path, durationMs}` · `copyToGallery({path})` (só nos testes) |
| `clippo/camera/poses` | `EventChannel` | Um mapa por quadro analisado: `t` (µs, relógio do sensor), `width`, `height`, `analysisMs`, `people` (uma entrada por pessoa: `points` = null ou 33 × x, y, z, confiança, com z a profundidade, menor = mais perto; no modo várias pessoas, também `box`), e só no modo várias pessoas `prepMs`, `detectMs`, `poseMs` e `detectorGpu` |
| `clippo/camera-preview` | Platform view | A imagem da câmera, para um `AndroidView` |

## Buffer de 30 s

1. **Uma câmera só.** A `ClippoCameraSession` é o único lugar que abre a câmera. O buffer é o
   **terceiro fluxo** da mesma chamada `bindToLifecycle`: um `Preview` que desenha na superfície
   de entrada de um `MediaCodec` (H.264, 1280×720, 3 Mbps, um quadro-chave por segundo). Abrir
   uma segunda câmera não funciona: o Android entrega a câmera a um cliente por vez.
2. **Fila em memória.** Os quadros saem comprimidos do encoder e vão para uma fila com os últimos
   ~40 s (1200 quadros). O buffer nunca vai para o disco nem sai do aparelho (R6).
3. **Dois relógios.** O `t` de cada quadro analisado (`ImageProxy.imageInfo.timestamp`) e o
   carimbo dos quadros do encoder não usam o mesmo relógio em todo celular (um conta o tempo
   dormindo, o outro não). Cada fluxo guarda a diferença do seu relógio para o `elapsedRealtime`,
   e o `saveHighlight` converte o disparo para o relógio do encoder antes de cortar.
4. **Salvar.** `saveHighlight({untilMicros})` copia da fila os ~30 s que terminam no disparo (R1)
   para um MP4, sem comprimir de novo, e responde `{path, durationMs}`:
   - o MP4 vai para `filesDir/highlights/`, a pasta interna do app (o cache o Android pode apagar
     sozinho, e o highlight precisa ficar até subir para o banco, R13);
   - é montado numa thread só dele: na principal, a tela engasgava a cada highlight;
   - o corte começa no quadro-chave anterior ao início do trecho, então pode ter até 1 s a mais;
   - `durationMs` é menor que 30 000 se a sessão começou há pouco (R5, 🟡);
   - a rotação do MP4 vem da posição do celular na hora do disparo (acelerômetro), porque o
     encoder grava sempre na posição do sensor;
   - erro: `save-failed` com a mensagem; o laboratório mostra o tempo de cada salvamento (R2: até 3 s).
   - Se o encoder morrer, o erro vai para o log (`ClippoBuffer`) e para o fluxo de poses como
     `buffer-failed`, e o laço do encoder para.
5. **Galeria só nos testes.** `copyToGallery({path})` copia o MP4 para o álbum DCIM/Clippo, para o
   time assistir. O produto guarda o highlight só na pasta do app.
6. **Na gravação a tela não mostra a câmera** (R7): sem `PreviewView`, o primeiro fluxo fica sem
   destino. Testado num Galaxy S24: sem `PreviewView`, a análise continua recebendo ~28 quadros
   por segundo. 🟡 Falta confirmar o mesmo com o buffer ligado.

## Testes

O código Kotlin não tem teste automático: câmera e ML Kit só rodam num celular de verdade.
O que dá para testar sem câmera (conversão dos pontos, regra, disparo) está no Dart.
