# camera — câmera nativa (CameraX + ML Kit)

Código Kotlin que abre a câmera, acha os pontos do corpo com o ML Kit e conversa com o Dart.
A regra do gesto e o disparo **não** ficam aqui: estão em Dart, em `app/lib/core/gesture/`.

| Arquivo | O que faz |
|---|---|
| `ClippoCameraSession.kt` | Abre a câmera traseira, liga os fluxos de imagem e de análise, roda o ML Kit e manda os pontos para o Dart. |
| `CameraPreviewFactory.kt` | Mostra a imagem da câmera dentro de uma tela Flutter (um `PreviewView` do CameraX). |
| `../MainActivity.kt` | Cria a sessão quando o Flutter sobe e repassa a resposta do pedido de permissão. |

## Ponte com o Dart

| Canal | Tipo | O quê |
|---|---|---|
| `clippo/camera` | `MethodChannel` | `hasPermission` → bool · `requestPermission` → bool · `start({accurate})` · `stop` · `saveHighlight({untilMicros})` → `{path, durationMs}` |
| `clippo/camera/poses` | `EventChannel` | Um mapa por quadro analisado: `t` (µs, relógio do sensor), `width`, `height`, `analysisMs`, `points` (null ou 33 × x, y, z, confiança; z é a profundidade, menor = mais perto) |
| `clippo/camera-preview` | Platform view | A imagem da câmera, para um `AndroidView` |

## Contrato com o buffer de 30 s (Mobile)

1. **Uma câmera só.** A `ClippoCameraSession` é o único lugar que abre a câmera. O buffer entra
   como um **terceiro fluxo** na mesma chamada `bindToLifecycle` (marcada com 🔜), por exemplo um
   `VideoCapture` ou a superfície de entrada de um `MediaCodec`. Abrir uma segunda câmera não
   funciona: o Android entrega a câmera a um cliente por vez.
2. **O mesmo relógio.** O `t` de cada quadro analisado vem de `ImageProxy.imageInfo.timestamp`,
   o relógio do sensor — o mesmo que carimba os quadros de vídeo. Quando o Dart disser "gesto
   às `t`", o buffer salva os ~30 s que terminam em `t` (R1), sem converter nada.
3. **O comando de salvar já existe; falta o buffer por trás.** `saveHighlight({untilMicros})` no
   `MethodChannel` `clippo/camera` chega em `ClippoCameraSession.saveHighlight` (marcado com 🔜),
   que hoje responde o erro `not-implemented`. O Dart já chama esse comando a cada disparo (veja
   no laboratório do gesto: "Último salvamento"). Para implementar, troque só o corpo dessa função:
   - entrada: `untilMicros`, a hora do disparo no relógio do sensor;
   - resposta: `result.success(mapOf("path" to caminhoDoMp4, "durationMs" to duracaoEmMs))`;
     `durationMs` pode ser menor que 30 000 se a sessão começou há pouco (R5, 🟡);
   - erro: `result.error("save-failed", mensagem, null)`;
   - em até 3 s (R2, o laboratório mostra o tempo medido) e sem internet (R8).
   🟡 Se o buffer precisar devolver mais coisas (ex.: a hora de início do trecho), acrescente
   no mapa e em `SavedClip` (`app/lib/core/camera/clippo_camera.dart`).
4. **O buffer não sai do aparelho** (R6): só o MP4 que o gesto salvar.
5. **Na gravação a tela não mostra a câmera** (R7): sem `PreviewView`, o fluxo de imagem fica sem
   destino. Testado num Galaxy S24: sem `PreviewView`, a análise continua recebendo ~28 quadros
   por segundo. 🟡 Falta confirmar o mesmo com o buffer ligado como terceiro fluxo.

## Testes

O código Kotlin não tem teste automático: câmera e ML Kit só rodam num celular de verdade.
O que dá para testar sem câmera (conversão dos pontos, regra, disparo) está no Dart.
