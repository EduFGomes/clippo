package com.clippoapp.clippo.camera

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.provider.MediaStore
import android.util.Log
import android.view.OrientationEventListener
import android.util.Size
import androidx.annotation.OptIn
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.AspectRatioStrategy
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.accurate.AccuratePoseDetectorOptions
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformViewRegistry
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentLinkedDeque
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * O ÚNICO lugar do app que abre a câmera (contrato com o buffer em README.md, nesta pasta).
 *
 * Abre a câmera traseira com o CameraX e liga os fluxos:
 * - Preview: a imagem na tela, desenhada por um PreviewView (ver CameraPreviewFactory);
 * - ImageAnalysis: quadros para o ML Kit, que devolve os 33 pontos do corpo;
 * - Buffer (MediaCodec): terceiro fluxo para gravação em segundo plano dos últimos 30s.
 * Os pontos vão para o Dart, onde ficam a regra do gesto e o disparo (lib/core/gesture/).
 *
 * Ponte com o Dart:
 * - MethodChannel "clippo/camera": hasPermission, requestPermission, start, stop, saveHighlight;
 * - EventChannel "clippo/camera/poses": um mapa por quadro analisado (formato em sendPose).
 */
class ClippoCameraSession(private val activity: FlutterActivity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "clippo/camera"
        const val POSES_CHANNEL = "clippo/camera/poses"
        const val PREVIEW_VIEW_TYPE = "clippo/camera-preview"
        private const val PERMISSION_REQUEST = 4201 // qualquer número, só para reconhecer a resposta
        const val LANDMARK_COUNT = 33
        // x, y, z (profundidade) e confiança. Mudou? Mude PoseLandmarkIndex.valuesPerPoint no Dart.
        const val VALUES_PER_LANDMARK = 4
    }

    // 16:9 nos dois fluxos: assim a imagem na tela e a imagem analisada mostram o mesmo
    // enquadramento, e o esqueleto desenhado por cima cai no lugar certo.
    // 1280×720 na análise (o padrão do CameraX é 640×480): a 8 m a pessoa é pequena no quadro.
    private val resolution = ResolutionSelector.Builder()
        .setAspectRatioStrategy(AspectRatioStrategy.RATIO_16_9_FALLBACK_AUTO_STRATEGY)
        .setResolutionStrategy(
            ResolutionStrategy(Size(1280, 720), ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER)
        )
        .build()

    private val preview = Preview.Builder().setResolutionSelector(resolution).build()

    // Terceiro fluxo: o CameraX desenha cada quadro na superfície de entrada do encoder do buffer
    // (ver setupEncoder). Mesma resolução dos outros dois, para os três caberem juntos na câmera.
    private val bufferPreview = Preview.Builder().setResolutionSelector(resolution).build()

    private val analysis = ImageAnalysis.Builder()
        .setResolutionSelector(resolution)
        // Só o quadro mais recente: se o ML Kit atrasar, os quadros velhos são jogados fora em
        // vez de formar fila. Melhor analisar menos quadros do que reagir ao gesto atrasado.
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .build()

    // A análise roda fora da thread principal, para não travar a interface.
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    // Montar o MP4 (~11 MB) em outra thread: na principal, a tela engasgava a cada highlight.
    private val saveExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    // Cópia para a galeria (fase de testes) em outra thread: não atrasa a análise dos quadros.
    private val galleryExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var cameraProvider: ProcessCameraProvider? = null
    private var detector: PoseDetector? = null
    // Só no modo várias pessoas (o escolhido): acha as pessoas antes do ML Kit. Criado, usado e
    // fechado na thread da análise.
    @Volatile private var multiPerson: MultiPersonAnalyzer? = null
    // Muda a cada start: um detector que terminar de abrir depois de um stop (ou de outro start)
    // é de uma câmera que já não existe, e é fechado em vez de usado.
    @Volatile private var generation = 0
    private var poseSink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null

    // Buffer de 30 s: o encoder H.264 comprime os quadros e a fila guarda os últimos ~40 s já
    // comprimidos, em memória (R6: nunca vai para o disco nem sai do aparelho). Salvar um
    // highlight é só copiar um pedaço da fila para um MP4, sem comprimir de novo (R2).
    private var mediaCodec: MediaCodec? = null
    private var inputSurface: android.view.Surface? = null
    private var encoderThread: Thread? = null
    private val isEncoding = AtomicBoolean(false)
    private val sampleQueue = ConcurrentLinkedDeque<EncodedSample>()
    private var outputFormat: MediaFormat? = null

    // O quadro analisado e o quadro do encoder NÃO usam o mesmo relógio (em alguns celulares um
    // conta o tempo dormindo e o outro não). Cada fluxo guarda "seu relógio − elapsedRealtime"
    // do último quadro; a diferença converte o disparo para o relógio do encoder.
    @Volatile private var analysisClockLeadUs: Long? = null
    @Volatile private var encoderClockLeadUs: Long? = null

    // O encoder grava na posição do sensor (deitado), qualquer que seja a do celular: o MP4 leva a
    // rotação para o player desvirar. A tela do app fica sempre em pé, então a posição do celular
    // vem do acelerômetro, não da tela.
    @Volatile private var sensorRotation = 90 // trocado pelo valor real quando a câmera abre
    @Volatile private var deviceRotation = 0 // 0, 90, 180 ou 270, no sentido horário
    private val orientationListener = object : OrientationEventListener(activity) {
        override fun onOrientationChanged(orientation: Int) {
            // Celular deitado de costas no chão: sem posição. Fica a última conhecida.
            if (orientation == ORIENTATION_UNKNOWN) return
            deviceRotation = ((orientation + 45) / 90 * 90) % 360
        }
    }

    data class EncodedSample(
        val buffer: ByteBuffer,
        val info: MediaCodec.BufferInfo
    )

    fun attach(messenger: BinaryMessenger, platformViews: PlatformViewRegistry) {
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(this)
        EventChannel(messenger, POSES_CHANNEL).setStreamHandler(this)
        platformViews.registerViewFactory(PREVIEW_VIEW_TYPE, CameraPreviewFactory(this))
    }

    // ---- Comandos vindos do Dart ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(hasPermission())
            "requestPermission" -> requestPermission(result)
            "start" -> start(
                accurate = call.argument<Boolean>("accurate") ?: false,
                manyPeople = call.argument<Boolean>("multiPerson") ?: false,
                result,
            )
            "saveHighlight" -> {
                // Number, e não Long: o Flutter manda um int pequeno como Int e um grande como Long.
                val untilMicros = call.argument<Number>("untilMicros")?.toLong()
                    ?: return result.error("bad-arguments", "Faltou untilMicros.", null)
                saveHighlight(untilMicros, result)
            }
            "copyToGallery" -> {
                val path = call.argument<String>("path")
                    ?: return result.error("bad-arguments", "Faltou path.", null)
                copyToGallery(path, result)
            }
            "stop" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun hasPermission() =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    private fun requestPermission(result: MethodChannel.Result) {
        if (hasPermission()) return result.success(true)
        if (pendingPermission != null) {
            return result.error("permission-pending", "Já existe um pedido de permissão aberto.", null)
        }
        // A resposta chega depois, na MainActivity, que repassa para onPermissionResult.
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.CAMERA), PERMISSION_REQUEST)
    }

    /** Chamado pela MainActivity. Devolve true se a resposta era deste pedido. */
    fun onPermissionResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        pendingPermission?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
        pendingPermission = null
        return true
    }

    private fun start(accurate: Boolean, manyPeople: Boolean, result: MethodChannel.Result) {
        if (!hasPermission()) return result.error("no-permission", "Sem permissão de câmera.", null)

        // Ligar de novo sem desligar (ex.: dois toques seguidos em um botão do laboratório): desliga
        // antes, senão ficam dois encoders e duas threads disputando o mesmo buffer.
        stop()
        val myGeneration = ++generation

        // O modo STREAM aproveita o quadro anterior para achar a pessoa mais rápido: é o modo para
        // vídeo. Por isso fica preso na primeira pessoa que achou; o modo várias pessoas dá um
        // ML Kit a cada pessoa (ver MultiPersonAnalyzer), e este aqui só analisa até o detector
        // de várias pessoas terminar de abrir.
        detector?.close()
        detector = PoseDetection.getClient(
            if (accurate) {
                AccuratePoseDetectorOptions.Builder().setDetectorMode(AccuratePoseDetectorOptions.STREAM_MODE).build()
            } else {
                PoseDetectorOptions.Builder().setDetectorMode(PoseDetectorOptions.STREAM_MODE).build()
            }
        )
        if (manyPeople) {
            // Abrir o detector (na GPU, compilar os shaders) leva segundos: fora da thread da tela,
            // senão o app congela. Na thread da análise, que é a que vai usá-lo: os quadros que
            // chegarem antes dele são analisados no modo de uma pessoa.
            analysisExecutor.execute {
                val startedAt = SystemClock.elapsedRealtime()
                try {
                    val created = MultiPersonAnalyzer(activity, accurate)
                    Log.d("ClippoMulti", "detector aberto em ${SystemClock.elapsedRealtime() - startedAt} ms, GPU=${created.onGpu}")
                    if (generation == myGeneration) {
                        multiPerson = created
                    } else {
                        Log.d("ClippoMulti", "detector descartado: a câmera foi desligada ou religada enquanto ele abria")
                        created.close()
                    }
                } catch (e: Exception) {
                    Log.e("ClippoMulti", "detector não abriu", e)
                    activity.runOnUiThread { poseSink?.error("detector-failed", e.message, null) }
                }
            }
        }
        analysis.setAnalyzer(analysisExecutor, ::analyze)

        // O encoder liga antes da câmera: o terceiro fluxo precisa da superfície dele.
        try {
            setupEncoder()
        } catch (e: Exception) {
            return result.error("encoder-init-failed", "Falha ao iniciar o encoder do buffer: ${e.message}", null)
        }

        // Pegar o CameraX é assíncrono: a resposta para o Dart só sai quando a câmera abriu.
        val providerFuture = ProcessCameraProvider.getInstance(activity)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider
                provider.unbindAll()
                // Presa ao ciclo de vida da tela: o CameraX desliga a câmera sozinho quando o
                // app vai para segundo plano e liga de novo quando ele volta.
                val camera = provider.bindToLifecycle(activity, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis, bufferPreview)
                sensorRotation = camera.cameraInfo.sensorRotationDegrees
                if (orientationListener.canDetectOrientation()) orientationListener.enable()
                result.success(null)
            } catch (e: Exception) {
                stopEncoder()
                result.error("camera-unavailable", "Não foi possível abrir a câmera: ${e.message}", null)
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun setupEncoder() {
        sampleQueue.clear()
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 1280, 720).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 3_000_000) // 3 Mbps
            setInteger(MediaFormat.KEY_FRAME_RATE, 30)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1) // Keyframe a cada 1 segundo para corte rápido
        }

        mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC).apply {
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            inputSurface = createInputSurface()
            start()
        }

        bufferPreview.setSurfaceProvider { request ->
            val surface = inputSurface
            if (surface != null) {
                request.provideSurface(surface, analysisExecutor) { _ ->
                    // Superfície liberada
                }
            }
        }

        isEncoding.set(true)
        // A thread fica com o SEU encoder: se um encoder novo for criado antes de ela sair, ela
        // para em vez de disputar o novo (o MediaCodec só aceita um dequeue por vez).
        val codec = mediaCodec
        encoderThread = Thread {
            val bufferInfo = MediaCodec.BufferInfo()
            while (isEncoding.get() && mediaCodec === codec) {
                try {
                    val index = mediaCodec?.dequeueOutputBuffer(bufferInfo, 10000) ?: -1
                    when {
                        index >= 0 -> {
                            val encodedBuffer = mediaCodec?.getOutputBuffer(index)
                            if (encodedBuffer != null && bufferInfo.size > 0) {
                                val copiedData = ByteBuffer.allocateDirect(bufferInfo.size)
                                encodedBuffer.position(bufferInfo.offset)
                                encodedBuffer.limit(bufferInfo.offset + bufferInfo.size)
                                copiedData.put(encodedBuffer)
                                copiedData.flip()

                                val infoCopy = MediaCodec.BufferInfo().apply {
                                    set(bufferInfo.offset, bufferInfo.size, bufferInfo.presentationTimeUs, bufferInfo.flags)
                                }

                                sampleQueue.add(EncodedSample(copiedData, infoCopy))
                                encoderClockLeadUs =
                                    bufferInfo.presentationTimeUs - SystemClock.elapsedRealtimeNanos() / 1000

                                // 1200 quadros ≈ 40 s a 30 quadros/s: folga sobre os 30 s, para o corte
                                // poder voltar até o quadro-chave anterior ao início do trecho.
                                while (sampleQueue.size > 1200) {
                                    sampleQueue.poll()
                                }
                            }
                            mediaCodec?.releaseOutputBuffer(index, false)
                        }
                        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            outputFormat = mediaCodec?.outputFormat
                        }
                    }
                } catch (e: MediaCodec.CodecException) {
                    // Passageiro (o encoder está ocupado): tenta de novo no próximo giro.
                    if (e.isTransient) continue
                    failEncoder(e)
                    break
                } catch (e: IllegalStateException) {
                    // O stop() desligou o encoder no meio de um dequeue: saída normal.
                    if (!isEncoding.get() || mediaCodec !== codec) break
                    failEncoder(e)
                    break
                }
            }
        }.apply {
            name = "ClippoBufferEncoder"
            start()
        }
    }

    /**
     * O encoder morreu: sem ele não há buffer, e girar o laço de novo só gastaria processador.
     * Registra no log e avisa o Dart pelo fluxo de poses (a tela mostra o erro).
     */
    private fun failEncoder(e: Exception) {
        Log.e("ClippoBuffer", "encoder do buffer parou", e)
        activity.runOnUiThread {
            poseSink?.error("buffer-failed", "O buffer de vídeo parou: ${e.message}", null)
        }
    }

    private fun stopEncoder() {
        isEncoding.set(false)
        encoderThread?.join(500)
        encoderThread = null

        try {
            mediaCodec?.stop()
            mediaCodec?.release()
        } catch (e: Exception) {
            Log.w("ClippoBuffer", "encoder não fechou limpo", e)
        }
        mediaCodec = null

        inputSurface?.release()
        inputSurface = null
        sampleQueue.clear()
        encoderClockLeadUs = null
    }

    /**
     * Salva os ~30 s que terminam no disparo num MP4 (R1) e responde {path, durationMs}.
     * O trecho começa num quadro-chave (o MP4 não abre no meio de um grupo de quadros), então
     * pode ter até 1 s a mais; se a sessão começou há menos de 30 s, sai o que houver (R5 🟡).
     */
    private fun saveHighlight(triggerMicros: Long, result: MethodChannel.Result) {
        // Tudo o que descreve o momento do disparo é lido agora; o MP4 é montado na outra thread.
        val samples = sampleQueue.toList()
        val format = outputFormat
        val analysisLead = analysisClockLeadUs
        val encoderLead = encoderClockLeadUs
        // Câmera traseira: a fórmula do Android para a orientação de foto/vídeo. Vale a posição
        // do celular na hora do disparo (ele fica apoiado durante a partida).
        val rotation = (sensorRotation + deviceRotation) % 360
        Log.d("ClippoBuffer", "rotação do vídeo=$rotation (sensor=$sensorRotation celular=$deviceRotation)")
        if (samples.isEmpty() || format == null || analysisLead == null || encoderLead == null) {
            return result.error("save-failed", "Buffer de vídeo ainda não possui quadros suficientes.", null)
        }
        saveExecutor.execute {
            try {
                val saved = writeHighlight(samples, format, triggerMicros - analysisLead + encoderLead, rotation)
                activity.runOnUiThread { result.success(saved) }
            } catch (e: Exception) {
                Log.e("ClippoBuffer", "highlight não salvou", e)
                activity.runOnUiThread {
                    result.error("save-failed", "Erro ao processar o highlight: ${e.message}", null)
                }
            }
        }
    }

    /** Monta o MP4 com os quadros até [untilMicros] (já no relógio do encoder). Roda no saveExecutor. */
    private fun writeHighlight(
        samples: List<EncodedSample>,
        format: MediaFormat,
        untilMicros: Long,
        rotation: Int,
    ): Map<String, Any> {
        Log.d(
            "ClippoBuffer",
            "até(encoder)=$untilMicros buffer=${samples.first().info.presentationTimeUs}..${samples.last().info.presentationTimeUs}"
        )

        // Filtra quadros até o exato momento do disparo (untilMicros)
        val relevantSamples = samples.filter { it.info.presentationTimeUs <= untilMicros }
        if (relevantSamples.isEmpty()) {
            throw IllegalStateException("Nenhum quadro disponível até o momento especificado.")
        }

        // Janela desejada: 30 segundos antes de untilMicros (30.000.000 microssegundos)
        val targetStartUs = untilMicros - 30_000_000L

        // Encontra o índice inicial garantindo que o corte comece a partir de um Key Frame (I-frame)
        var startIndex = 0
        for (i in relevantSamples.indices) {
            if (relevantSamples[i].info.presentationTimeUs >= targetStartUs) {
                var k = i
                while (k >= 0) {
                    if ((relevantSamples[k].info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0) {
                        startIndex = k
                        break
                    }
                    k--
                }
                if (k < 0) {
                    for (j in 0..i) {
                        if ((relevantSamples[j].info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME) != 0) {
                            startIndex = j
                            break
                        }
                    }
                }
                break
            }
        }

        val slice = relevantSamples.subList(startIndex, relevantSamples.size)
        if (slice.isEmpty()) {
            throw IllegalStateException("Fatia de vídeo vazia.")
        }

        val firstTimestamp = slice.first().info.presentationTimeUs
        val lastTimestamp = slice.last().info.presentationTimeUs
        val durationMs = ((lastTimestamp - firstTimestamp) / 1000).coerceAtLeast(0)

        // Pasta interna do app (filesDir), e não o cache: o Android apaga o cache sozinho quando
        // falta espaço, e o highlight precisa ficar até subir para o banco (R13).
        val folder = File(activity.filesDir, "highlights").apply { mkdirs() }
        val outputFile = File(folder, "highlight_${System.currentTimeMillis()}.mp4")
        val muxer = MediaMuxer(outputFile.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        try {
            val trackIndex = muxer.addTrack(format)
            muxer.setOrientationHint(rotation)
            muxer.start()

            for (sample in slice) {
                val relTime = sample.info.presentationTimeUs - firstTimestamp
                val adjustedInfo = MediaCodec.BufferInfo().apply {
                    set(0, sample.info.size, relTime.coerceAtLeast(0L), sample.info.flags)
                }
                muxer.writeSampleData(trackIndex, sample.buffer, adjustedInfo)
            }

            muxer.stop()
        } catch (e: Exception) {
            outputFile.delete() // um MP4 pela metade não abre: melhor não deixar lixo na pasta
            throw e
        } finally {
            muxer.release()
        }

        return mapOf("path" to outputFile.absolutePath, "durationMs" to durationMs)
    }

    /**
     * SÓ PARA A FASE DE TESTES: copia um highlight salvo para a galeria (álbum DCIM/Clippo), para
     * o time assistir no celular. O produto guarda o highlight só na pasta do app.
     * Usa o MediaStore, que no Android 10+ não pede permissão; antes disso, responde com erro.
     */
    private fun copyToGallery(path: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return result.error("gallery-unavailable", "Galeria só no Android 10 ou mais novo.", null)
        }
        galleryExecutor.execute {
            try {
                val source = File(path)
                val resolver = activity.contentResolver
                val details = ContentValues().apply {
                    put(MediaStore.Video.Media.DISPLAY_NAME, source.name)
                    put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                    put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_DCIM}/Clippo")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
                val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, details)
                    ?: throw IllegalStateException("MediaStore não criou o arquivo.")
                resolver.openOutputStream(uri).use { output ->
                    source.inputStream().use { input -> input.copyTo(output!!) }
                }
                resolver.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
                activity.runOnUiThread { result.success(uri.toString()) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("gallery-failed", "Erro ao copiar para a galeria: ${e.message}", null) }
            }
        }
    }

    fun stop() {
        orientationListener.disable()
        cameraProvider?.unbindAll()
        analysis.clearAnalyzer()
        detector?.close()
        detector = null
        // Fecha na thread da análise: se um quadro estiver no meio, ele termina antes.
        generation++
        multiPerson?.let { analyzer -> analysisExecutor.execute { analyzer.close() } }
        multiPerson = null
        stopEncoder()
    }

    // ---- Imagem na tela ----

    fun attachPreview(view: PreviewView) = preview.setSurfaceProvider(view.surfaceProvider)

    fun detachPreview() = preview.setSurfaceProvider(null)

    // ---- Fluxo de poses para o Dart ----

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        poseSink = events
    }

    override fun onCancel(arguments: Any?) {
        poseSink = null
    }

    // `image` do ImageProxy é marcado como experimental pelo CameraX, mas é o jeito indicado
    // pelo próprio ML Kit de passar o quadro sem copiar.
    @OptIn(ExperimentalGetImage::class)
    private fun analyze(proxy: ImageProxy) {
        val detector = detector
        val mediaImage = proxy.image
        if (detector == null || mediaImage == null) {
            proxy.close()
            return
        }

        // O sensor da câmera fica deitado dentro do celular: rotationDegrees diz quanto girar
        // para a imagem ficar em pé. O ML Kit gira sozinho e devolve os pontos já em pé, então
        // a largura e a altura que valem para o Dart são as da imagem girada.
        val rotation = proxy.imageInfo.rotationDegrees
        val width = if (rotation % 180 == 0) proxy.width else proxy.height
        val height = if (rotation % 180 == 0) proxy.height else proxy.width
        // Hora em que o quadro foi FILMADO, no relógio do sensor (não é o mesmo do vídeo do buffer:
        // ver analysisClockLeadUs).
        val timestampNanos = proxy.imageInfo.timestamp
        val startedAt = SystemClock.elapsedRealtime()
        analysisClockLeadUs = (timestampNanos - SystemClock.elapsedRealtimeNanos()) / 1000

        val many = multiPerson
        if (many != null) {
            analyzeMany(proxy, many, rotation, Frame(timestampNanos, width, height, startedAt))
            return
        }

        detector.process(InputImage.fromMediaImage(mediaImage, rotation))
            .addOnSuccessListener { pose ->
                val points = pose.toPoints()
                sendFrame(
                    Frame(timestampNanos, width, height, startedAt),
                    people = if (points == null) emptyList() else listOf(mapOf("points" to points)),
                )
            }
            .addOnFailureListener { e -> poseSink?.error("analysis-failed", e.message, null) }
            // Só libera o quadro depois que o ML Kit terminou: é isso que faz o CameraX esperar
            // e descartar os quadros que chegarem no meio (KEEP_ONLY_LATEST).
            .addOnCompleteListener { proxy.close() }
    }

    private class Frame(val timestampNanos: Long, val width: Int, val height: Int, val startedAt: Long)

    /** Várias pessoas: a pose nesta thread; o detector, na dele (ver MultiPersonAnalyzer). */
    private fun analyzeMany(proxy: ImageProxy, many: MultiPersonAnalyzer, rotation: Int, frame: Frame) {
        try {
            // Em pixels, ainda deitada: o analisador gira só o que precisa (a cópia pequena do
            // detector e cada recorte), não a imagem inteira.
            val raw = proxy.toBitmap()
            val prepMs = SystemClock.elapsedRealtime() - frame.startedAt
            val result = many.analyze(raw, rotation)
            val analysisMs = SystemClock.elapsedRealtime() - frame.startedAt
            val people = result.people.map { person ->
                mapOf(
                    "box" to doubleArrayOf(
                        person.box.left.toDouble(), person.box.top.toDouble(),
                        person.box.right.toDouble(), person.box.bottom.toDouble(),
                    ),
                    "points" to person.points,
                )
            }
            activity.runOnUiThread {
                sendFrame(
                    frame, people,
                    analysisMs = analysisMs,
                    stages = mapOf(
                        "prepMs" to prepMs,
                        "detectMs" to result.detectMs,
                        "poseMs" to result.poseMs,
                        "detectorGpu" to many.onGpu,
                    ),
                )
            }
        } catch (e: Exception) {
            Log.e("ClippoMulti", "análise falhou", e)
            activity.runOnUiThread { poseSink?.error("analysis-failed", e.message, null) }
        } finally {
            proxy.close()
        }
    }

    /**
     * Um quadro analisado, como chega no Dart (lido em lib/core/camera/pose_frame.dart):
     * - "t": hora do quadro em microssegundos, no relógio do sensor;
     * - "width", "height": tamanho da imagem já em pé, no mesmo referencial dos pontos;
     * - "analysisMs": quanto a análise inteira levou neste quadro;
     * - só no modo várias pessoas, cada etapa: "prepMs" (converter a imagem), "detectMs" (o
     *   detector de pessoas cujas caixas entraram neste quadro; 0 se nenhuma), "poseMs" (todas as
     *   leituras de pose somadas) e "detectorGpu" (se o detector rodou na placa de vídeo);
     * - "people": uma entrada por pessoa (vazia se não achou ninguém), com
     *   - "points": 33 × (x, y, z, confiança), na ordem dos tipos de PoseLandmark (ombros 11 e
     *     12, cotovelos 13 e 14, pulsos 15 e 16); null se o detector achou a pessoa e o ML Kit não;
     *   - "box" (left, top, right, bottom): só no modo várias pessoas.
     */
    private fun sendFrame(
        frame: Frame,
        people: List<Map<String, Any?>>,
        analysisMs: Long = SystemClock.elapsedRealtime() - frame.startedAt,
        stages: Map<String, Any?> = emptyMap(),
    ) {
        // O EventSink só pode ser usado na thread principal.
        poseSink?.success(
            mapOf(
                "t" to frame.timestampNanos / 1000,
                "width" to frame.width,
                "height" to frame.height,
                "analysisMs" to analysisMs,
                "people" to people,
            ) + stages
        )
    }

    fun dispose() {
        stop()
        analysisExecutor.shutdown()
        saveExecutor.shutdown()
        galleryExecutor.shutdown()
    }
}