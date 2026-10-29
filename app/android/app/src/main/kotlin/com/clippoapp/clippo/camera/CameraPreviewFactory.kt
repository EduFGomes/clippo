package com.clippoapp.clippo.camera

import android.content.Context
import android.view.View
import androidx.camera.view.PreviewView
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Coloca a imagem da câmera dentro da tela Flutter (no Dart, um AndroidView com o tipo
 * ClippoCameraSession.PREVIEW_VIEW_TYPE).
 *
 * Usa o PreviewView do próprio CameraX, que já resolve rotação e proporção. A alternativa
 * (desenhar numa Texture do Flutter) exigiria girar e escalar a imagem à mão no Dart.
 */
class CameraPreviewFactory(private val session: ClippoCameraSession) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val view = PreviewView(context).apply {
            // COMPATIBLE desenha num TextureView, que o Flutter consegue misturar com os widgets
            // por cima (o esqueleto do laboratório). O modo padrão (SurfaceView) pode ficar por
            // cima de tudo ou não aparecer.
            implementationMode = PreviewView.ImplementationMode.COMPATIBLE
            // Mostra a imagem inteira, sem cortar: é o mesmo enquadramento que o ML Kit analisa.
            scaleType = PreviewView.ScaleType.FIT_CENTER
        }
        session.attachPreview(view)
        return object : PlatformView {
            override fun getView(): View = view
            override fun dispose() = session.detachPreview()
        }
    }
}
