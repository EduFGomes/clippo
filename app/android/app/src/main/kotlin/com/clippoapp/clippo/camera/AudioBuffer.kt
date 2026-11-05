package com.clippoapp.clippo.camera

import android.annotation.SuppressLint
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaRecorder
import android.os.SystemClock
import android.util.Log
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentLinkedDeque
import java.util.concurrent.atomic.AtomicBoolean

/**
 * O som do buffer: grava o microfone em AAC numa fila em memória, como a do vídeo, com os
 * últimos [keepUs] microssegundos. Nunca vai para o disco nem sai do aparelho (R6); só entra
 * no MP4 que o gesto salvar.
 *
 * O carimbo de cada quadro de som está no relógio do elapsedRealtime (o "boottime" do
 * AudioTimestamp). Quem monta o MP4 converte para o relógio do encoder de vídeo.
 *
 * Opcional: sem a permissão do microfone, ou se ele não abrir, o highlight sai só com imagem.
 */
class AudioBuffer(private val keepUs: Long) {

    companion object {
        private const val TAG = "ClippoAudio"
        private const val SAMPLE_RATE = 44_100
        private const val BIT_RATE = 96_000
        private const val BYTES_PER_FRAME = 2 // mono, 16 bits
        // Um quadro AAC tem 1024 amostras: ler o mesmo tanto por vez (~23 ms).
        private const val CHUNK_FRAMES = 1024
    }

    class Sample(val buffer: ByteBuffer, val info: MediaCodec.BufferInfo)

    private val queue = ConcurrentLinkedDeque<Sample>()
    private val running = AtomicBoolean(false)
    private var record: AudioRecord? = null
    private var codec: MediaCodec? = null
    private var thread: Thread? = null

    /** O formato do AAC (com a configuração do decodificador), conhecido depois dos primeiros quadros. */
    @Volatile var format: MediaFormat? = null
        private set

    /** Se o som está sendo gravado agora. Cai para false se o microfone falhar no meio. */
    val active: Boolean get() = running.get()

    /** Liga o microfone. Devolve false (e o vídeo segue sem som) se ele não abrir. */
    @SuppressLint("MissingPermission") // quem chama confere a permissão do microfone antes
    fun start(): Boolean {
        try {
            val minBytes = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            val chunkBytes = CHUNK_FRAMES * BYTES_PER_FRAME
            // CAMCORDER: o microfone e o ajuste que o celular usa para filmar.
            val rec = AudioRecord(
                MediaRecorder.AudioSource.CAMCORDER, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(minBytes, chunkBytes) * 4,
            )
            if (rec.state != AudioRecord.STATE_INITIALIZED) {
                rec.release()
                Log.w(TAG, "microfone não abriu")
                return false
            }
            val enc = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC).apply {
                val aac = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1).apply {
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
                    setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, chunkBytes)
                }
                configure(aac, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                start()
            }
            rec.startRecording()
            queue.clear()
            format = null
            record = rec
            codec = enc
            running.set(true)
            thread = Thread { loop(rec, enc, chunkBytes) }.apply {
                name = "ClippoAudio"
                start()
            }
            return true
        } catch (e: Exception) {
            Log.e(TAG, "som do buffer não ligou", e)
            stop()
            return false
        }
    }

    /** Lê o microfone, comprime e guarda na fila, até o stop() ou um erro. */
    private fun loop(rec: AudioRecord, enc: MediaCodec, chunkBytes: Int) {
        val pcm = ByteArray(chunkBytes)
        val info = MediaCodec.BufferInfo()
        val timestamp = AudioTimestamp()
        val startedNs = SystemClock.elapsedRealtimeNanos()
        var framesRead = 0L
        var lastPtsUs = -1L
        while (running.get()) {
            try {
                // Bloqueia até ter um pedaço de som (~23 ms).
                val read = rec.read(pcm, 0, pcm.size)
                if (read < 0) throw IllegalStateException("AudioRecord.read devolveu $read")
                if (read > 0) {
                    // Hora do primeiro quadro deste pedaço. O AudioTimestamp diz quando um quadro
                    // conhecido foi gravado; sem ele, conta a partir do início.
                    val ns = if (rec.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_BOOTTIME) == AudioRecord.SUCCESS) {
                        timestamp.nanoTime + (framesRead - timestamp.framePosition) * 1_000_000_000L / SAMPLE_RATE
                    } else {
                        startedNs + framesRead * 1_000_000_000L / SAMPLE_RATE
                    }
                    // O muxer exige carimbos crescentes.
                    val ptsUs = maxOf(ns / 1000, lastPtsUs + 1)
                    lastPtsUs = ptsUs
                    framesRead += read / BYTES_PER_FRAME
                    val index = enc.dequeueInputBuffer(10_000)
                    if (index >= 0) {
                        enc.getInputBuffer(index)?.apply {
                            clear()
                            put(pcm, 0, read)
                        }
                        enc.queueInputBuffer(index, 0, read, ptsUs, 0)
                    } else {
                        Log.w(TAG, "encoder de som ocupado: um pedaço de ~23 ms ficou de fora")
                    }
                }
                drain(enc, info)
            } catch (e: Exception) {
                if (!running.get()) break // o stop() fechou no meio de uma leitura
                Log.e(TAG, "som do buffer parou; o vídeo segue sem som", e)
                running.set(false)
            }
        }
    }

    /** Tira do encoder tudo o que já saiu comprimido. */
    private fun drain(enc: MediaCodec, info: MediaCodec.BufferInfo) {
        while (true) {
            val index = enc.dequeueOutputBuffer(info, 0)
            when {
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> format = enc.outputFormat
                index >= 0 -> {
                    val out = enc.getOutputBuffer(index)
                    // A configuração do decodificador já vem no format; não é um quadro de som.
                    val isConfig = (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                    if (out != null && info.size > 0 && !isConfig) {
                        val copy = ByteBuffer.allocateDirect(info.size)
                        out.position(info.offset)
                        out.limit(info.offset + info.size)
                        copy.put(out)
                        copy.flip()
                        queue.add(Sample(copy, MediaCodec.BufferInfo().apply { set(0, info.size, info.presentationTimeUs, info.flags) }))
                        while (info.presentationTimeUs - (queue.peekFirst()?.info?.presentationTimeUs ?: break) > keepUs) {
                            queue.pollFirst()
                        }
                    }
                    enc.releaseOutputBuffer(index, false)
                }
                else -> return // nada pronto agora
            }
        }
    }

    /** Uma cópia da fila agora (os quadros não mudam depois de entrar). */
    fun snapshot(): List<Sample> = queue.toList()

    fun stop() {
        running.set(false)
        // O read() bloqueia: parar a gravação o solta.
        try {
            record?.stop()
        } catch (e: Exception) {
            Log.w(TAG, "microfone não parou limpo", e)
        }
        thread?.join(500)
        thread = null
        record?.release()
        record = null
        try {
            codec?.stop()
            codec?.release()
        } catch (e: Exception) {
            Log.w(TAG, "encoder de som não fechou limpo", e)
        }
        codec = null
        queue.clear()
        format = null
    }
}
