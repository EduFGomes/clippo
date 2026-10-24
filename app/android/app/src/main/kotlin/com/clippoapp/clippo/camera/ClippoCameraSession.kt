package com.clippoapp.clippo.camera

import android.Manifest
import android.content.pm.PackageManager
import android.os.SystemClock
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
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * O ÚNICO lugar do app que abre a câmera (contrato com o buffer em README.md, nesta pasta).
 *
 * Abre a câmera traseira com o CameraX e liga dois fluxos:
 * - Preview: a imagem na tela, desenhada por um PreviewView (ver CameraPreviewFactory);
 * - ImageAnalysis: quadros para o ML Kit, que devolve os 33 pontos do corpo.
 * Os pontos vão para o Dart, onde ficam a regra do gesto e o disparo (lib/core/gesture/).
 *
 * Ponte com o Dart:
 * - MethodChannel "clippo/camera": hasPermission, requestPermission, start, stop;
 * - EventChannel "clippo/camera/poses": um mapa por quadro analisado (formato em sendPose).
 */
class ClippoCameraSession(private val activity: FlutterActivity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "clippo/camera"
        const val POSES_CHANNEL = "clippo/camera/poses"
        const val PREVIEW_VIEW_TYPE = "clippo/camera-preview"
        private const val PERMISSION_REQUEST = 4201 // qualquer número, só para reconhecer a resposta
        private const val LANDMARK_COUNT = 33
        // x, y, z (profundidade) e confiança. Mudou? Mude PoseLandmarkIndex.valuesPerPoint no Dart.
        private const val VALUES_PER_LANDMARK = 4
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

    private val analysis = ImageAnalysis.Builder()
        .setResolutionSelector(resolution)
        // Só o quadro mais recente: se o ML Kit atrasar, os quadros velhos são jogados fora em
        // vez de formar fila. Melhor analisar menos quadros do que reagir ao gesto atrasado.
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .build()

    // A análise roda fora da thread principal, para não travar a interface.
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var cameraProvider: ProcessCameraProvider? = null
    private var detector: PoseDetector? = null
    private var poseSink: EventChannel.EventSink? = null
    private var pendingPermission: MethodChannel.Result? = null

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
            "start" -> start(accurate = call.argument<Boolean>("accurate") ?: false, result)
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

    private fun start(accurate: Boolean, result: MethodChannel.Result) {
        if (!hasPermission()) return result.error("no-permission", "Sem permissão de câmera.", null)

        // O modo STREAM aproveita o quadro anterior para achar a pessoa mais rápido: é o modo
        // para vídeo. (O modo SINGLE_IMAGE procura do zero em cada foto.)
        detector?.close()
        detector = PoseDetection.getClient(
            if (accurate) {
                AccuratePoseDetectorOptions.Builder().setDetectorMode(AccuratePoseDetectorOptions.STREAM_MODE).build()
            } else {
                PoseDetectorOptions.Builder().setDetectorMode(PoseDetectorOptions.STREAM_MODE).build()
            }
        )
        analysis.setAnalyzer(analysisExecutor, ::analyze)

        // Pegar o CameraX é assíncrono: a resposta para o Dart só sai quando a câmera abriu.
        val providerFuture = ProcessCameraProvider.getInstance(activity)
        providerFuture.addListener({
            try {
                val provider = providerFuture.get()
                cameraProvider = provider
                provider.unbindAll()
                // Presa ao ciclo de vida da tela: o CameraX desliga a câmera sozinho quando o
                // app vai para segundo plano e liga de novo quando ele volta.
                // 🔜 O buffer do Otávio entra aqui como terceiro fluxo (ver README.md).
                provider.bindToLifecycle(activity, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
                result.success(null)
            } catch (e: Exception) {
                result.error("camera-unavailable", "Não foi possível abrir a câmera: ${e.message}", null)
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    fun stop() {
        cameraProvider?.unbindAll()
        analysis.clearAnalyzer()
        detector?.close()
        detector = null
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
        // Hora em que o quadro foi FILMADO, no relógio do sensor (o mesmo do vídeo do buffer).
        val timestampNanos = proxy.imageInfo.timestamp
        val startedAt = SystemClock.elapsedRealtime()

        detector.process(InputImage.fromMediaImage(mediaImage, rotation))
            .addOnSuccessListener { pose ->
                val points = DoubleArray(LANDMARK_COUNT * VALUES_PER_LANDMARK)
                for (landmark in pose.allPoseLandmarks) {
                    val i = landmark.landmarkType * VALUES_PER_LANDMARK
                    points[i] = landmark.position.x.toDouble()
                    points[i + 1] = landmark.position.y.toDouble()
                    // z: profundidade estimada, com o quadril como zero; menor = mais perto da câmera.
                    // Está aqui para descobrir se a pessoa está de frente ou de costas.
                    points[i + 2] = landmark.position3D.z.toDouble()
                    points[i + 3] = landmark.inFrameLikelihood.toDouble()
                }
                sendPose(
                    timestampNanos, width, height,
                    analysisMs = SystemClock.elapsedRealtime() - startedAt,
                    points = if (pose.allPoseLandmarks.isEmpty()) null else points,
                )
            }
            .addOnFailureListener { e -> poseSink?.error("analysis-failed", e.message, null) }
            // Só libera o quadro depois que o ML Kit terminou: é isso que faz o CameraX esperar
            // e descartar os quadros que chegarem no meio (KEEP_ONLY_LATEST).
            .addOnCompleteListener { proxy.close() }
    }

    /**
     * Um quadro analisado, como chega no Dart:
     * - "t": hora do quadro em microssegundos, no relógio do sensor;
     * - "width", "height": tamanho da imagem já em pé, no mesmo referencial dos pontos;
     * - "analysisMs": quanto o ML Kit levou neste quadro;
     * - "points": null se não achou ninguém; senão 33 × (x, y, z, confiança), na ordem dos tipos
     *   de PoseLandmark (ombros 11 e 12, cotovelos 13 e 14, pulsos 15 e 16).
     */
    private fun sendPose(timestampNanos: Long, width: Int, height: Int, analysisMs: Long, points: DoubleArray?) {
        // Os ouvintes do ML Kit rodam na thread principal, que é onde o EventSink pode ser usado.
        poseSink?.success(
            mapOf(
                "t" to timestampNanos / 1000,
                "width" to width,
                "height" to height,
                "analysisMs" to analysisMs,
                "points" to points,
            )
        )
    }

    fun dispose() {
        stop()
        analysisExecutor.shutdown()
    }
}
