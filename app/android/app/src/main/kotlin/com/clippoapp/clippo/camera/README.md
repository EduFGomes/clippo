# camera — câmera nativa (CameraX + ML Kit)

Código Kotlin que abre a câmera, acha os pontos do corpo com o ML Kit e conversa com o Dart.
A regra do gesto e o disparo **não** ficam aqui: estão em Dart, em `app/lib/core/gesture/`.

| Arquivo | O que faz |
|---|---|
| `ClippoCameraSession.kt` | Abre a câmera traseira, liga os fluxos (imagem, análise e buffer de vídeo; ver "Fases" abaixo), roda o ML Kit, manda os pontos para o Dart e salva os highlights. |
| `AudioBuffer.kt` | O som do buffer: microfone em AAC numa fila em memória, ao lado da do vídeo. Opcional. |
| `SaveSignal.kt` | O aviso de highlight salvo: bip, flash curto da lanterna e vibração leve, cada um com liga/desliga. |
| `MultiPersonAnalyzer.kt` | Modo várias pessoas (o escolhido; 🟡 falta medir com 3–6 pessoas): o detector do MediaPipe (EfficientDet-Lite0, em `src/main/assets/`) acha cada pessoa (numa thread só dele, com a imagem pela metade; na GPU, ou no processador se ela falhar, como no S24), e cada pessoa tem um ML Kit só dela, em modo stream, lendo o recorte em volta dela, com as outras pessoas pintadas de cinza (senão o ML Kit seguia a vizinha); pose com os ombros fora da caixa da pessoa é descartada. Com o celular deitado, a cópia do detector é girada pela posição do celular, para ele ver as pessoas em pé. Sem ele, o ML Kit (modo stream) segue só a primeira pessoa que achou e pula para quem passar na frente dela. |
| `CameraPreviewFactory.kt` | Mostra a imagem da câmera dentro de uma tela Flutter (um `PreviewView` do CameraX). |
| `../MainActivity.kt` | Cria a sessão quando o Flutter sobe e repassa a resposta do pedido de permissão. |

## Ponte com o Dart

| Canal | Tipo | O quê |
|---|---|---|
| `clippo/camera` | `MethodChannel` | `hasPermission` → bool · `requestPermission` → bool (pede câmera e microfone; responde pela câmera) · `hasMicrophonePermission` → bool · `requestMicrophonePermission` → bool · `startPreview({recordAudio})` → `{withSound}` (previsão) · `start({multiPerson, fullHd, recordAudio, withPreview})` → `{withSound}` · `stop` · `saveHighlight({untilMicros, seconds})` → `{path, durationMs, withSound}` · `deleteHighlight({path})` · `signalSaved({sound, flash, vibrate})` · `copyToGallery({path})` (só nos testes) |
| `clippo/camera/poses` | `EventChannel` | Um mapa por quadro analisado: `t` (µs, relógio do sensor), `width`, `height`, `analysisMs`, `people` (uma entrada por pessoa: `points` = null ou 33 × x, y, z, confiança, com z a profundidade, menor = mais perto; no modo várias pessoas, também `box`), e só no modo várias pessoas `prepMs`, `detectMs`, `poseMs` e `detectorGpu` |
| `clippo/camera-preview` | Platform view | A imagem da câmera, para um `AndroidView` |

## Fases

Câmeras de nível **LIMITED** (ex.: Galaxy A50) não abrem imagem + análise + buffer juntos: o
CameraX recusa a combinação e o `start` responde `camera-unavailable`. Por isso a tela de gravação
nunca pede os três:

| Fase | Chamada | Fluxos |
|---|---|---|
| Enquadrar | `startPreview` | só a imagem na tela |
| Gravar (tela preta, R7) | `start(withPreview: false)` | análise + buffer |

O laboratório usa `start()` com a imagem (`withPreview` padrão `true`): três fluxos, então só abre
em câmeras FULL ou melhores (ex.: S24). Cada `start`/`startPreview` desliga a fase anterior antes
(o buffer começa no "Gravar"), e um `stop` que chega enquanto o CameraX abre cancela a abertura.

## Buffer

1. **Uma câmera só.** A `ClippoCameraSession` é o único lugar que abre a câmera. O buffer é o
   **terceiro fluxo** da mesma chamada `bindToLifecycle`: um `Preview` que desenha na superfície
   de entrada de um `MediaCodec` (H.264, 1280×720, 3 Mbps, um quadro-chave por segundo). Abrir
   uma segunda câmera não funciona: o Android entrega a câmera a um cliente por vez.
2. **Fila em memória.** Os quadros saem comprimidos do encoder e vão para uma fila com os últimos
   ~65 s (`KEEP_US`: o highlight mais longo, 60 s, mais folga para o quadro-chave), ~25 MB. O
   buffer nunca vai para o disco nem sai do aparelho (R6).
3. **Som (opcional).** Com o microfone liberado, o `AudioBuffer` grava em AAC (44,1 kHz, mono,
   96 kbps) numa fila ao lado, com o mesmo tempo. Sem a permissão, ou se o microfone não abrir,
   o vídeo segue sem som; se ele falhar no meio, o erro vai para o log (`ClippoAudio`) e os
   próximos highlights saem sem som. O `requestPermission` pede câmera e microfone juntos.
4. **Dois relógios.** O `t` de cada quadro analisado (`ImageProxy.imageInfo.timestamp`) e o
   carimbo dos quadros do encoder não usam o mesmo relógio em todo celular (um conta o tempo
   dormindo, o outro não). Cada fluxo guarda a diferença do seu relógio para o `elapsedRealtime`,
   e o `saveHighlight` converte o disparo para o relógio do encoder antes de cortar. O som é
   carimbado no `elapsedRealtime` (`AudioTimestamp`, base boottime) e convertido do mesmo jeito.
5. **Salvar.** `saveHighlight({untilMicros, seconds})` copia da fila os `seconds` (15, 30, 45 ou 60;
   padrão 30) que terminam no disparo (R1) para um MP4, sem comprimir de novo, com o som do mesmo
   intervalo se houver, e responde `{path, durationMs, withSound}`:
   - o MP4 vai para `filesDir/highlights/`, a pasta interna do app (o cache o Android pode apagar
     sozinho, e o highlight precisa ficar até subir para o banco, R13);
   - é montado numa thread só dele: na principal, a tela engasgava a cada highlight;
   - o corte começa no quadro-chave anterior ao início do trecho, então pode ter até 1 s a mais;
   - `durationMs` é menor que a duração pedida se a sessão começou há pouco (R5);
   - a rotação do MP4 vem da posição do celular na hora do disparo (acelerômetro), porque o
     encoder grava sempre na posição do sensor;
   - depois do `MediaMuxer`, o `Mp4FastStart.kt` move o índice (`moov`) para o começo do arquivo e
     corrige as posições dos quadros (`stco`/`co64`): o Player toca por streaming com o primeiro
     pedaço. Se não der, o MP4 fica como saiu do muxer (o log `ClippoBuffer` mostra `faststart=` e o tempo);
   - erro: `save-failed` com a mensagem; o laboratório mostra o tempo de cada salvamento (R2: até 3 s).
   - Se o encoder morrer, o erro vai para o log (`ClippoBuffer`) e para o fluxo de poses como
     `buffer-failed`, e o laço do encoder para.
6. **Aviso de salvo.** Depois que o MP4 fica pronto, o Dart chama `signalSaved({sound, flash,
   vibrate})`: bip do sistema no volume de mídia (🟡 até o design definir o som), flash de
   200 ms da lanterna (pela câmera aberta; aparece também no vídeo) e vibração de 40 ms.
7. **Galeria só nos testes.** `copyToGallery({path})` copia o MP4 para o álbum DCIM/Clippo, para o
   time assistir. O produto guarda o highlight só na pasta do app.
8. **Na gravação a tela não mostra a câmera e não apaga sozinha** (R7): enquanto a câmera está ligada, `FLAG_KEEP_SCREEN_ON` impede o Android de apagar a tela e bloquear o celular (no laboratório a imagem e os esqueletos continuam na tela; no app final a tela fica preta `#000000`, desligando os pixels OLED). Sem `PreviewView`, o primeiro fluxo fica sem
   destino. Testado num Galaxy S24: sem `PreviewView`, a análise continua recebendo ~28 quadros
   por segundo. 🟡 Falta confirmar o mesmo com o buffer ligado.

## Testes

O código Kotlin não tem teste automático: câmera e ML Kit só rodam num celular de verdade.
O que dá para testar sem câmera (conversão dos pontos, regra, disparo) está no Dart.
