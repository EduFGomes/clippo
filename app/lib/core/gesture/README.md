# lib/core/gesture — detecção do gesto \ o /

Decide, quadro a quadro, se alguém fez o gesto, e quando disparar o salvamento do highlight.
Tudo roda no celular, sem internet (R8). Por que é assim: `docs/arquitetura.md` › D1, D13 e D14.

| Arquivo | O que faz |
|---|---|
| `body_pose.dart` | Os pontos que a regra usa (ombros, cotovelos, pulsos, nariz e quadril), sem depender do modelo de pose. |
| `gesture_rule.dart` | A regra sobre **um** quadro: `measure()` calcula a geometria, `evaluate()` compara com os limites (`GestureThresholds`) e diz o motivo da recusa (`GestureCheck`). |
| `gesture_trigger.dart` | O **tempo**: o gesto precisa durar, um quadro perdido não zera a contagem, e entre disparos há uma espera (R4). Tempos em `GestureTriggerTimings`. |
| `gesture_pipeline.dart` | Liga os quadros da câmera (`core/camera/`) à regra e ao disparo. Uma `GestureObservation` por quadro; a que tem `triggered` é a hora de salvar. |

Os quadros vêm de `core/camera/` (`ClippoCamera` e `PoseFrame`), que conversa com o código nativo
em `android/app/src/main/kotlin/com/clippoapp/clippo/camera/` (CameraX + ML Kit).

## Como um quadro é decidido

Na ordem; a primeira verificação que falha é o motivo mostrado no laboratório.

1. **Alguém no quadro?** Senão, `noPerson`.
2. **Confiança** dos 6 pontos dos braços. Senão, `lowConfidence`. Atenção: no ML Kit a confiança diz
   se o ponto está **dentro da imagem**, não se está visível.
3. **De frente, não de lado**: distância entre os ombros, em "braços". Senão, `notFacingCamera`.
4. **De frente, não de costas**: o nariz precisa estar à frente dos ombros (profundidade z).
   Senão, `facingAway`. Vem depois de "de lado" porque de lado essa medida fica instável.
5. **Cada braço**: sem cruzar (`armCrossed`), em diagonal (`armNotDiagonal`) e esticado (`armBent`).

Tudo é medido em ângulos ou proporções do próprio corpo, nunca em pixels: o mesmo limite vale com
a pessoa a 2 m ou a 8 m.

"Para cima" também é o do corpo: a linha do meio do quadril ao meio dos ombros. Assim o gesto vale
com o celular deitado ou torto (no teste no corredor de 27/10/2026, com o celular deitado, o
\ o / saía como "braço cruzado"). Se o quadril não está na imagem com confiança, a regra usa a
vertical da imagem. O laboratório mostra qual eixo valeu ("corpo 90°" ou "sem quadril").

## Limites atuais 🟡

Valores ainda não medidos em quadra. Ajustáveis ao vivo no laboratório ("Ajustar limites").

| Limite | Valor | De onde veio |
|---|---|---|
| Confiança mínima | 0,5 | Chute inicial |
| Ombros (de lado) | ≥ 0,5 braço | De frente mede ~1,0–1,9; de lado, 0,1–0,3 (vídeo de 24/10/2026) |
| Nariz (de costas) | ≤ −0,5 | De frente −0,8 a −2,1; de costas +1,2 a +2,1 (vídeos de 24/10/2026) |
| Braço (diagonal) | 10° a 75° da vertical | Braço reto para cima mede −4° a 5°; Ys fechados, 13° a 20°. Era 15° até 24/10/2026 |
| Cotovelo | ≥ 130° | Pose de "muque" fica abaixo de 110° |
| Tempo mínimo do gesto | 400 ms | Chute inicial; funcionou nos testes em casa |
| Buraco tolerado | 250 ms | Um ou dois quadros perdidos a ~25 quadros/s |
| Espera entre disparos (R4) | 5 s | Sugestão da R4, não confirmada pelo grupo |

## Como testar

O **laboratório do gesto** mostra a câmera, o esqueleto, os ângulos, o motivo de cada quadro, os
limites e os disparos, sem login e sem Firebase:

```
cd app
flutter run --flavor lab -t lib/dev/gesture_lab_main.dart
```

Com o cabo conectado, o `flutter run` mostra no log uma linha `LAB` a cada mudança de motivo e a
cada disparo. Sem cabo, grave a tela do celular: o painel tem tudo o que importa.

## Roteiro de medição (critério de aceite: ≥ 90 % a até 8 m)

**Onde:** um lugar amplo, de preferência a quadra de verdade. Anote o lugar, a hora e a luz (sol,
sombra, refletor) — a luz muda muito o resultado.

**Montagem:** celular em pé, apoiado na altura do peito, câmera traseira, enquadrando a pessoa de
corpo inteiro. Marque no chão 2, 4, 6 e 8 m.

**Para cada distância e cada modelo** (o laboratório troca entre `base` e `accurate`):

1. **20 gestos de frente**, um de cada vez: braços abaixados → \ o / por ~1 s → abaixados.
   Espere ~6 s entre um e outro (a espera da R4 é de 5 s). Conte quantos dispararam.
2. **10 "quase gestos"**, que **não** podem disparar: um braço só, braços retos para cima, em X,
   na horizontal, "muque", e o Y **de costas**. Conte os disparos indevidos.
3. **1 minuto de movimento normal** (andar, chutar, comemorar sem o gesto). Conte os disparos indevidos.

**Anote numa tabela:**

| Distância | Modelo | Gestos que dispararam (de 20) | Indevidos nos "quase" (de 10) | Indevidos em 1 min | Quadros/s | ML Kit (ms) | Observações |
|---|---|---|---|---|---|---|---|
| 2 m | base | | | | | | |
| 2 m | accurate | | | | | | |
| … | | | | | | | |

**Como ler o resultado:**
- **Passou** em uma distância: ≥ 18 de 20 (90 %) e nenhum disparo indevido.
- **Gesto perdido:** grave a tela e veja no painel qual motivo apareceu e qual medida ficou fora do
  limite. Se for sempre a mesma (por exemplo, o braço em 8° com o limite em 10°), ajuste o limite no
  laboratório e **repita a distância inteira**.
- **Disparo indevido:** anote o que a pessoa estava fazendo. Um disparo indevido pesa mais que um
  gesto perdido: salva lances que ninguém pediu.
- **Escolha do modelo:** fica o que passar nas 4 distâncias; se os dois passarem, o `base` (mais leve).
  De longe, confira a medida do nariz no `accurate`: de perto ela já ficou mais próxima do limite.

Depois da medição, atualize a tabela "Limites atuais" e a decisão em aberto do modelo em
`docs/arquitetura.md`.
