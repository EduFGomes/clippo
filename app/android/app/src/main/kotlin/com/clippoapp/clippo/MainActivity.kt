package com.clippoapp.clippo

import com.clippoapp.clippo.camera.ClippoCameraSession
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var camera: ClippoCameraSession? = null

    // Chamado quando o Flutter sobe: é aqui que os canais do código nativo do app são registrados.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        camera = ClippoCameraSession(this).also {
            it.attach(flutterEngine.dartExecutor.binaryMessenger, flutterEngine.platformViewsController.registry)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        camera?.dispose()
        camera = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    // O Android entrega a resposta do pedido de permissão à Activity, não a quem pediu.
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (camera?.onPermissionResult(requestCode, grantResults) != true) {
            super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }
}
