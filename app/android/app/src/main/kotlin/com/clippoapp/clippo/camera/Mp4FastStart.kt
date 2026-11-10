package com.clippoapp.clippo.camera

import java.io.File
import java.io.OutputStream
import java.io.RandomAccessFile
import java.nio.ByteBuffer

/**
 * "Faststart": põe o índice do MP4 (o átomo `moov`) no começo do arquivo.
 *
 * O MediaMuxer grava o índice no fim, depois dos quadros (`mdat`). Para tocar por streaming
 * (Player, D17), o player precisa do índice antes de qualquer quadro: com ele no fim, faz
 * pedidos a mais ao Storage (começo, fim, começo de novo), e cada pedido passa pelas regras.
 * Com o índice na frente, toca com o primeiro pedaço.
 *
 * Mover o `moov` para antes do `mdat` empurra os quadros para a frente exatamente o tamanho do
 * `moov`; por isso cada posição de quadro guardada no índice (`stco`, ou `co64` em arquivos
 * grandes) ganha esse tamanho. Nada mais muda: os quadros são copiados byte a byte.
 */
object Mp4FastStart {

    private class Atom(val type: String, val start: Long, val size: Long, val headerSize: Int)

    /** Os átomos que contêm outros até chegar ao `stco`: moov › trak › mdia › minf › stbl. */
    private val containers = setOf("moov", "trak", "mdia", "minf", "stbl")

    /**
     * Reescreve [file] com o índice no começo. Devolve false (e deixa o arquivo como estava)
     * se o índice já está no começo ou se o arquivo não tem o formato esperado.
     */
    fun apply(file: File): Boolean {
        val atoms = RandomAccessFile(file, "r").use { readTopLevel(it) } ?: return false
        val moovIndex = atoms.indexOfFirst { it.type == "moov" }
        val mdatIndex = atoms.indexOfFirst { it.type == "mdat" }
        if (moovIndex < 0 || mdatIndex < 0 || moovIndex < mdatIndex) return false
        val moovAtom = atoms[moovIndex]
        if (moovAtom.size > Int.MAX_VALUE) return false

        val moov = ByteArray(moovAtom.size.toInt())
        RandomAccessFile(file, "r").use {
            it.seek(moovAtom.start)
            it.readFully(moov)
        }
        if (!shiftChunkOffsets(ByteBuffer.wrap(moov), moovAtom.headerSize, moov.size, moovAtom.size)) return false

        // Mesma ordem, só o moov sobe para logo antes do mdat.
        val ordered = atoms.subList(0, mdatIndex).filter { it !== moovAtom } +
            moovAtom +
            atoms.subList(mdatIndex, atoms.size).filter { it !== moovAtom }

        val temp = File(file.parentFile, "${file.name}.faststart")
        try {
            RandomAccessFile(file, "r").use { input ->
                temp.outputStream().buffered(COPY_BUFFER).use { out ->
                    for (atom in ordered) {
                        if (atom === moovAtom) out.write(moov) else copy(input, atom.start, atom.size, out)
                    }
                }
            }
            // Escreve ao lado e só então troca: se algo falhar no meio, o original continua inteiro.
            if (temp.length() != file.length() || !temp.renameTo(file)) {
                temp.delete()
                return false
            }
            return true
        } catch (e: Exception) {
            temp.delete()
            throw e
        }
    }

    /** Os átomos do nível de cima, ou nulo se algum tamanho não fecha com o arquivo. */
    private fun readTopLevel(input: RandomAccessFile): List<Atom>? {
        val length = input.length()
        val atoms = mutableListOf<Atom>()
        var pos = 0L
        val header = ByteArray(8)
        while (pos + 8 <= length) {
            input.seek(pos)
            input.readFully(header)
            val buf = ByteBuffer.wrap(header)
            var size = buf.getInt(0).toLong() and 0xFFFFFFFFL
            val type = String(header, 4, 4, Charsets.US_ASCII)
            var headerSize = 8
            when (size) {
                1L -> { // tamanho de 64 bits logo depois do tipo
                    size = input.readLong()
                    headerSize = 16
                }
                0L -> size = length - pos // vai até o fim do arquivo
            }
            if (size < headerSize || pos + size > length) return null
            atoms += Atom(type, pos, size, headerSize)
            pos += size
        }
        return if (pos == length) atoms else null
    }

    /** Soma [shift] a cada posição de quadro (`stco`/`co64`) dentro de [buf] de [from] a [to]. */
    private fun shiftChunkOffsets(buf: ByteBuffer, from: Int, to: Int, shift: Long): Boolean {
        var p = from
        while (p + 8 <= to) {
            var size = buf.getInt(p).toLong() and 0xFFFFFFFFL
            val type = String(byteArrayOf(buf.get(p + 4), buf.get(p + 5), buf.get(p + 6), buf.get(p + 7)), Charsets.US_ASCII)
            var header = 8
            when (size) {
                1L -> {
                    size = buf.getLong(p + 8)
                    header = 16
                }
                0L -> size = (to - p).toLong()
            }
            if (size < header || p + size > to) return false
            val end = (p + size).toInt()
            when (type) {
                in containers -> if (!shiftChunkOffsets(buf, p + header, end, shift)) return false
                "stco" -> {
                    // versão e flags (4 bytes), quantidade (4), e uma posição de 32 bits por bloco
                    val count = buf.getInt(p + header + 4).toLong() and 0xFFFFFFFFL
                    val first = p + header + 8
                    if (first + count * 4 > end) return false
                    for (i in 0 until count.toInt()) {
                        val at = first + i * 4
                        val moved = (buf.getInt(at).toLong() and 0xFFFFFFFFL) + shift
                        if (moved > 0xFFFFFFFFL) return false // não cabe em 32 bits: deixa como está
                        buf.putInt(at, moved.toInt())
                    }
                }
                "co64" -> {
                    val count = buf.getInt(p + header + 4).toLong() and 0xFFFFFFFFL
                    val first = p + header + 8
                    if (first + count * 8 > end) return false
                    for (i in 0 until count.toInt()) {
                        val at = first + i * 8
                        buf.putLong(at, buf.getLong(at) + shift)
                    }
                }
            }
            p = end
        }
        return true
    }

    private fun copy(input: RandomAccessFile, start: Long, size: Long, out: OutputStream) {
        input.seek(start)
        val chunk = ByteArray(COPY_BUFFER)
        var left = size
        while (left > 0) {
            val read = input.read(chunk, 0, minOf(chunk.size.toLong(), left).toInt())
            if (read < 0) throw java.io.EOFException("MP4 terminou antes do esperado")
            out.write(chunk, 0, read)
            left -= read
        }
    }

    private const val COPY_BUFFER = 1 shl 16
}
