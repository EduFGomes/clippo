package com.clippoapp.clippo.camera

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import androidx.camera.core.Camera

/**
 * O aviso de "highlight salvo" para quem está jogando longe do celular: um bip, um flash curto
 * da lanterna e uma vibração leve. Cada um pode ser desligado (decidido pelo grupo em 28/10/2026).
 *
 * Nada aqui atrasa o salvamento: o Dart só chama depois que o MP4 está pronto (R2).
 */
class SaveSignal(private val context: Context) {

    companion object {
        private const val TAG = "ClippoSignal"
        // 🟡 Bip do sistema até o design definir o som do Clippo.
        private const val TONE = ToneGenerator.TONE_PROP_ACK
        private const val TONE_MS = 150
        private const val FLASH_MS = 200L
        private const val VIBRATION_MS = 40L
    }

    private val main = Handler(Looper.getMainLooper())

    // No volume de mídia (o dos vídeos), e não no de notificação: muita gente deixa esse zerado,
    // e na quadra o bip precisa ser ouvido (decidido pelo grupo em 29/10/2026).
    private val tone: ToneGenerator? = try {
        ToneGenerator(AudioManager.STREAM_MUSIC, 100)
    } catch (e: RuntimeException) {
        Log.w(TAG, "bip indisponível neste celular", e)
        null
    }

    /** [camera] é a câmera aberta: a lanterna só acende por ela enquanto a câmera está em uso. */
    fun play(sound: Boolean, flash: Boolean, vibrate: Boolean, camera: Camera?) {
        if (sound) tone?.startTone(TONE, TONE_MS)
        if (flash) flash(camera)
        if (vibrate) vibrate()
    }

    // O flash também aparece no vídeo dos próximos highlights: é a mesma câmera que grava.
    private fun flash(camera: Camera?) {
        if (camera == null || !camera.cameraInfo.hasFlashUnit()) return
        camera.cameraControl.enableTorch(true)
        main.postDelayed({ camera.cameraControl.enableTorch(false) }, FLASH_MS)
    }

    @Suppress("DEPRECATION") // vibrate(ms) é o único jeito antes do Android 8
    private fun vibrate() {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(VIBRATION_MS, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            vibrator.vibrate(VIBRATION_MS)
        }
    }

    fun release() {
        main.removeCallbacksAndMessages(null)
        tone?.release()
    }
}
