package com.clippoapp.clippo.camera

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import java.io.Closeable
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.roundToInt

/**
 * Várias pessoas no quadro (o modo escolhido; 🟡 falta medir com 3–6 pessoas, ver docs/arquitetura.md › Decisões em aberto):
 * 1. o detector de objetos do MediaPipe (EfficientDet-Lite0, em assets/) acha as caixas de "person"
 *    numa thread só dele, sem segurar a pose: quando termina, as caixas entram no próximo quadro e
 *    ele começa de novo com o quadro mais recente;
 * 2. cada pessoa vira um "acompanhamento" com um recorte quadrado da imagem e um ML Kit SÓ DELA,
 *    no modo stream;
 * 3. a cada quadro, cada ML Kit lê os 33 pontos do seu recorte, e os pontos voltam para as
 *    coordenadas da imagem inteira.
 *
 * Por que um ML Kit por pessoa: no modo stream o ML Kit procura a pessoa uma vez e depois só segue
 * a região do quadro anterior, o que é rápido e estável, mas ele fica preso a UMA pessoa. Dando a
 * cada pessoa o seu, com o seu recorte, cada um segue a sua. (Um ML Kit só, no modo de imagem
 * única, procurava a pessoa do zero em cada recorte: ~63 ms por pessoa e falhava em metade dos
 * quadros.) O recorte só muda quando a pessoa sai dele, para o ML Kit não perder a região.
 *
 * A imagem nunca é girada inteira: o detector recebe uma cópia em pé e com metade do tamanho (ele
 * reduz para 320×320 de qualquer jeito), e cada recorte é girado sozinho, já pequeno.
 *
 * [analyze] roda na thread da análise e bloqueia até a pose terminar: enquanto isso, o CameraX
 * descarta os quadros que chegarem (KEEP_ONLY_LATEST). O custo cresce com o número de pessoas: uma
 * leitura de pose por pessoa. O detector, na thread dele, não entra nessa conta.
 */
class MultiPersonAnalyzer(private val context: Context, private val accurate: Boolean) : Closeable {

    companion object {
        private const val MODEL = "efficientdet_lite0.tflite"

        /** Mais que isso fica lento demais (cada pessoa é uma leitura do ML Kit). */
        private const val MAX_PEOPLE = 6

        private const val MIN_SCORE = 0.3f

        // Margem do recorte em volta da caixa, em fração do lado maior dela: mãos levantadas podem
        // ficar fora da caixa do detector, e a pessoa pode andar um pouco sem sair do recorte.
        private const val MARGIN = 0.35f

        // Uma caixa que tem mais que isso da sua área dentro de outra mais certa é a mesma pessoa
        // detectada duas vezes (ex.: o corpo inteiro e só o tronco).
        private const val DUPLICATE = 0.6f

        // O detector recebe a imagem reduzida a esta fração: ele a reduz para 320×320 de qualquer
        // jeito, e girar e copiar uma imagem menor custa menos.
        private const val DETECT_SCALE = 0.5f

        // Sobreposição (área em comum ÷ área somada) para uma caixa nova ser a mesma pessoa de um
        // acompanhamento.
        private const val SAME_PERSON = 0.3f

        // O recorte é refeito quando a caixa da pessoa passa a ocupar menos que isso dele (ela
        // andou para a beira ou mudou de tamanho). Refazer à toa faz o ML Kit perder a região.
        private const val KEEP_CROP = 0.8f
    }

    class Person(val box: RectF, val points: DoubleArray?)

    /** [detectMs] é o tempo do detector cujas caixas entraram neste quadro; 0 se nenhuma entrou. */
    class Result(val people: List<Person>, val detectMs: Long, val poseMs: Long)

    /** Uma pessoa acompanhada: a última caixa do detector, o recorte e o ML Kit dela. */
    private class Track(var box: RectF, var crop: Rect, val poses: PoseDetector)

    /**
     * Se o detector roda na placa de vídeo. Começa tentando a GPU; se ela não abrir ou falhar no
     * meio (acontece no S24: GL_INVALID_VALUE depois de alguns quadros), passa para o processador.
     */
    @Volatile var onGpu: Boolean = false
        private set

    // Só a thread do detector mexe no detector (depois de criado aqui).
    private val detectorThread: ExecutorService = Executors.newSingleThreadExecutor()
    @Volatile private var detecting = false
    @Volatile private var closed = false

    /** Caixas prontas do detector (na imagem em pé, tamanho cheio) e quanto ele levou. */
    private val ready = AtomicReference<Pair<List<RectF>, Long>?>(null)

    private var detector: ObjectDetector = try {
        createDetector(Delegate.GPU).also { onGpu = true }
    } catch (e: Exception) {
        createDetector(Delegate.CPU)
    }

    private val tracks = mutableListOf<Track>()

    // ML Kits de quem saiu do quadro, para reaproveitar: abrir um novo carrega o modelo de novo.
    private val idlePoses = ArrayDeque<PoseDetector>()

    private fun createDetector(delegate: Delegate) = ObjectDetector.createFromOptions(
        context,
        ObjectDetector.ObjectDetectorOptions.builder()
            .setBaseOptions(BaseOptions.builder().setModelAssetPath(MODEL).setDelegate(delegate).build())
            .setRunningMode(RunningMode.IMAGE)
            .setMaxResults(MAX_PEOPLE)
            .setScoreThreshold(MIN_SCORE)
            .setCategoryAllowlist(listOf("person"))
            .build()
    )

    private fun takePoses(): PoseDetector = idlePoses.removeFirstOrNull() ?: PoseDetection.getClient(
        if (accurate) {
            AccuratePoseDetectorOptions.Builder().setDetectorMode(AccuratePoseDetectorOptions.STREAM_MODE).build()
        } else {
            PoseDetectorOptions.Builder().setDetectorMode(PoseDetectorOptions.STREAM_MODE).build()
        }
    )

    /**
     * [raw] é o quadro como veio do sensor (deitado); [rotation] é quanto girar para ficar em pé.
     * Pontos e caixas voltam no referencial da imagem em pé.
     */
    fun analyze(raw: Bitmap, rotation: Int): Result {
        val toUpright = uprightMatrix(raw, rotation)
        val width = if (rotation % 180 == 0) raw.width else raw.height
        val height = if (rotation % 180 == 0) raw.height else raw.width

        // Caixas novas do detector, se ele terminou desde o último quadro.
        var detectMs = 0L
        ready.getAndSet(null)?.let { (boxes, ms) ->
            updateTracks(boxes, width, height)
            detectMs = ms
        }
        if (!detecting && !closed) startDetect(raw, rotation)

        val poseStart = SystemClock.elapsedRealtime()
        val toRaw = Matrix().also { toUpright.invert(it) }
        val people = tracks.map { track ->
            val c = track.crop
            val pose = Tasks.await(track.poses.process(InputImage.fromBitmap(cropUpright(raw, rotation, toRaw, c), 0)))
            Person(track.box, pose.toPoints(c.left.toDouble(), c.top.toDouble()))
        }
        return Result(people, detectMs, SystemClock.elapsedRealtime() - poseStart)
    }

    /** Leva um ponto da imagem do sensor para a imagem em pé (girar e trazer para x, y ≥ 0). */
    private fun uprightMatrix(raw: Bitmap, rotation: Int): Matrix {
        val m = Matrix().apply { postRotate(rotation.toFloat()) }
        val bounds = RectF(0f, 0f, raw.width.toFloat(), raw.height.toFloat())
        m.mapRect(bounds)
        m.postTranslate(-bounds.left, -bounds.top)
        return m
    }

    /** O pedaço [crop] (em pé) da imagem: recorta do sensor e gira só o pedaço. */
    private fun cropUpright(raw: Bitmap, rotation: Int, toRaw: Matrix, crop: Rect): Bitmap {
        val r = RectF(crop).also { toRaw.mapRect(it) }
        val left = r.left.roundToInt().coerceIn(0, raw.width - 1)
        val top = r.top.roundToInt().coerceIn(0, raw.height - 1)
        val right = r.right.roundToInt().coerceIn(left + 1, raw.width)
        val bottom = r.bottom.roundToInt().coerceIn(top + 1, raw.height)
        val turn = Matrix().apply { postRotate(rotation.toFloat()) }
        return Bitmap.createBitmap(raw, left, top, right - left, bottom - top, turn, false)
    }

    /** Uma detecção na thread do detector, com uma cópia pequena e em pé do quadro. */
    private fun startDetect(raw: Bitmap, rotation: Int) {
        val small = Bitmap.createBitmap(
            raw, 0, 0, raw.width, raw.height,
            Matrix().apply {
                postRotate(rotation.toFloat())
                postScale(DETECT_SCALE, DETECT_SCALE)
            },
            true,
        )
        detecting = true
        detectorThread.execute {
            try {
                if (closed) return@execute
                val startedAt = SystemClock.elapsedRealtime()
                val boxes = detect(small).map { box ->
                    RectF(box.left / DETECT_SCALE, box.top / DETECT_SCALE, box.right / DETECT_SCALE, box.bottom / DETECT_SCALE)
                }
                ready.set(boxes to SystemClock.elapsedRealtime() - startedAt)
            } catch (e: Exception) {
                Log.e("ClippoMulti", "detector falhou", e)
            } finally {
                detecting = false
            }
        }
    }

    /** Liga as caixas novas aos acompanhamentos: quem continua, quem chegou, quem saiu. */
    private fun updateTracks(boxes: List<RectF>, width: Int, height: Int) {
        val left = tracks.toMutableList()
        val kept = mutableListOf<Track>()
        for (box in boxes) {
            val match = left.maxByOrNull { overlap(it.box, box) }?.takeIf { overlap(it.box, box) >= SAME_PERSON }
            if (match != null) {
                left.remove(match)
                match.box = box
                if (coverage(box, match.crop) < KEEP_CROP) match.crop = cropAround(box, width, height)
                kept += match
            } else {
                kept += Track(box, cropAround(box, width, height), takePoses())
            }
        }
        // Quem saiu devolve o ML Kit. Ele ainda lembra da região da pessoa antiga; no recorte de
        // outra pessoa, não acha nada ali e procura de novo sozinho.
        for (gone in left) idlePoses.addLast(gone.poses)
        tracks.clear()
        tracks += kept
    }

    /** Quadrado em volta da caixa, com margem: é o formato que o ML Kit espera. Cortado na beira. */
    private fun cropAround(box: RectF, width: Int, height: Int): Rect {
        val side = maxOf(box.width(), box.height()) * (1 + 2 * MARGIN)
        val left = (box.centerX() - side / 2).toInt().coerceIn(0, width - 1)
        val top = (box.centerY() - side / 2).toInt().coerceIn(0, height - 1)
        val right = (box.centerX() + side / 2).toInt().coerceIn(left + 1, width)
        val bottom = (box.centerY() + side / 2).toInt().coerceIn(top + 1, height)
        return Rect(left, top, right, bottom)
    }

    /** Roda na thread do detector. */
    private fun detect(image: Bitmap): List<RectF> {
        val detections = try {
            detector.detect(BitmapImageBuilder(image).build()).detections()
        } catch (e: Exception) {
            if (!onGpu) throw e
            Log.w("ClippoMulti", "detector falhou na GPU, passando para o processador", e)
            closeQuietly(detector)
            detector = createDetector(Delegate.CPU)
            onGpu = false
            detector.detect(BitmapImageBuilder(image).build()).detections()
        }
        // Da mais certa para a menos: entre duas caixas da mesma pessoa, fica a mais certa.
        val found = detections
            .sortedByDescending { it.categories().firstOrNull()?.score() ?: 0f }
            .map { it.boundingBox() }
        val boxes = mutableListOf<RectF>()
        for (candidate in found) {
            if (boxes.none { isDuplicate(candidate, it) }) boxes += candidate
            if (boxes.size == MAX_PEOPLE) break
        }
        return boxes
    }

    private fun area(r: RectF) = r.width() * r.height()

    private fun intersection(a: RectF, b: RectF): Float {
        val common = RectF()
        return if (common.setIntersect(a, b)) area(common) else 0f
    }

    /** Área em comum ÷ área somada. */
    private fun overlap(a: RectF, b: RectF): Float {
        val shared = intersection(a, b)
        val union = area(a) + area(b) - shared
        return if (union > 0) shared / union else 0f
    }

    /** Quanto de [box] cabe dentro de [crop]. */
    private fun coverage(box: RectF, crop: Rect): Float =
        if (area(box) > 0) intersection(box, RectF(crop)) / area(box) else 0f

    /** Se [box] está quase toda dentro de [kept] (ou o contrário): a mesma pessoa duas vezes. */
    private fun isDuplicate(box: RectF, kept: RectF): Boolean {
        val smaller = minOf(area(box), area(kept))
        return smaller > 0 && intersection(box, kept) / smaller > DUPLICATE
    }

    // Um detector que falhou na GPU também pode falhar ao fechar: isso não pode derrubar o app.
    private fun closeQuietly(target: AutoCloseable) {
        try {
            target.close()
        } catch (e: Exception) {
            Log.w("ClippoMulti", "erro ao fechar", e)
        }
    }

    /** Chame na thread da análise. O detector fecha na thread dele, depois da detecção em curso. */
    override fun close() {
        closed = true
        detectorThread.execute { closeQuietly(detector) }
        detectorThread.shutdown()
        for (track in tracks) closeQuietly(track.poses)
        for (poses in idlePoses) closeQuietly(poses)
        tracks.clear()
        idlePoses.clear()
    }
}

/**
 * Os 33 pontos como o Dart espera: 33 × (x, y, z, confiança), na ordem dos tipos de PoseLandmark.
 * [offsetX] e [offsetY] levam um ponto do recorte para a imagem inteira. null se não achou ninguém.
 */
fun Pose.toPoints(offsetX: Double = 0.0, offsetY: Double = 0.0): DoubleArray? {
    if (allPoseLandmarks.isEmpty()) return null
    val points = DoubleArray(ClippoCameraSession.LANDMARK_COUNT * ClippoCameraSession.VALUES_PER_LANDMARK)
    for (landmark in allPoseLandmarks) {
        val i = landmark.landmarkType * ClippoCameraSession.VALUES_PER_LANDMARK
        points[i] = landmark.position.x + offsetX
        points[i + 1] = landmark.position.y + offsetY
        // z: profundidade estimada, com o quadril como zero; menor = mais perto da câmera.
        // Está aqui para descobrir se a pessoa está de frente ou de costas. O recorte não muda a
        // escala, então o z continua na mesma unidade de x e y.
        points[i + 2] = landmark.position3D.z.toDouble()
        points[i + 3] = landmark.inFrameLikelihood.toDouble()
    }
    return points
}
