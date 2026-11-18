package zack20136.com.quill_diary.drive

import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.min

private const val MAX_RESPONSE_BODY_CHARS = 512 * 1024
private const val STREAM_BUFFER_SIZE = 64 * 1024
internal const val DRIVE_FILES_URL = "https://www.googleapis.com/drive/v3/files"
private const val METADATA_FIELDS = "id,name,size,md5Checksum,appProperties"

internal fun driveFileMetadataRequest(fileId: String, accessToken: String): DriveHttpRequest =
    DriveHttpRequest(
        method = "GET",
        url = "$DRIVE_FILES_URL/$fileId?fields=$METADATA_FIELDS",
        headers = mapOf("Authorization" to "Bearer $accessToken"),
    )

internal fun driveFilesByUploadJobRequest(jobId: String, accessToken: String): DriveHttpRequest {
    val query = "appProperties has { key='uploadJobId' and value='$jobId' } and trashed = false"
    val encodedQuery = URLEncoder.encode(query, "UTF-8")
    return DriveHttpRequest(
        method = "GET",
        url = "$DRIVE_FILES_URL?spaces=appDataFolder&q=$encodedQuery&fields=files($METADATA_FIELDS)",
        headers = mapOf("Authorization" to "Bearer $accessToken"),
    )
}

internal fun interface DriveHttpClient {
    fun execute(request: DriveHttpRequest): DriveHttpResponse

    fun disconnectActive() {}
}

internal sealed class DriveHttpBody {
    data class Bytes(val data: ByteArray) : DriveHttpBody()

    data class FileRange(
        val file: File,
        val offset: Long,
        val length: Int,
    ) : DriveHttpBody()
}

internal data class DriveHttpRequest(
    val method: String,
    val url: String,
    val headers: Map<String, String>,
    val body: DriveHttpBody? = null,
)

internal data class DriveHttpResponse(
    val code: Int,
    val headers: Map<String, String>,
    val body: String,
)

internal class UrlConnectionDriveHttpClient : DriveHttpClient {
    private val activeConnection = AtomicReference<HttpURLConnection?>(null)

    override fun execute(request: DriveHttpRequest): DriveHttpResponse {
        val connection = (URL(request.url).openConnection() as HttpURLConnection)
        activeConnection.set(connection)
        try {
            connection.requestMethod = request.method
            connection.connectTimeout = 30_000
            connection.readTimeout = 120_000
            connection.instanceFollowRedirects = false
            connection.doInput = true
            request.headers.forEach { (key, value) ->
                connection.setRequestProperty(key, value)
            }
            when (val body = request.body) {
                is DriveHttpBody.Bytes -> {
                    connection.doOutput = true
                    connection.setFixedLengthStreamingMode(body.data.size)
                    connection.outputStream.use { output ->
                        output.write(body.data)
                        output.flush()
                    }
                }
                is DriveHttpBody.FileRange -> {
                    connection.doOutput = true
                    connection.setFixedLengthStreamingMode(body.length)
                    RandomAccessFile(body.file, "r").use { raf ->
                        raf.seek(body.offset)
                        val buffer = ByteArray(STREAM_BUFFER_SIZE)
                        var remaining = body.length
                        connection.outputStream.use { output ->
                            while (remaining > 0) {
                                val toRead = min(buffer.size, remaining)
                                val n = raf.read(buffer, 0, toRead)
                                if (n < 0) {
                                    throw IOException("無法讀取備份檔區塊。")
                                }
                                output.write(buffer, 0, n)
                                remaining -= n
                            }
                            output.flush()
                        }
                    }
                }
                null -> Unit
            }
            val code = connection.responseCode
            val stream =
                if (code in 200..299 || code == 308) {
                    connection.inputStream
                } else {
                    connection.errorStream ?: connection.inputStream
                }
            val responseBody = readLimitedBody(stream)
            val headers = mutableMapOf<String, String>()
            connection.headerFields?.forEach { (key, values) ->
                if (key != null && !values.isNullOrEmpty()) {
                    headers[key.lowercase()] = values.last()
                }
            }
            return DriveHttpResponse(code = code, headers = headers, body = responseBody)
        } finally {
            connection.disconnect()
            activeConnection.compareAndSet(connection, null)
        }
    }

    override fun disconnectActive() {
        activeConnection.getAndSet(null)?.disconnect()
    }

    private fun readLimitedBody(stream: InputStream?): String {
        if (stream == null) {
            return ""
        }
        return stream.bufferedReader(StandardCharsets.UTF_8).use { reader ->
            val builder = StringBuilder()
            val buffer = CharArray(8 * 1024)
            var total = 0
            while (true) {
                val n = reader.read(buffer)
                if (n < 0) {
                    break
                }
                val room = MAX_RESPONSE_BODY_CHARS - total
                if (room <= 0) {
                    break
                }
                val write = min(n, room)
                builder.append(buffer, 0, write)
                total += write
                if (write < n) {
                    break
                }
            }
            builder.toString()
        }
    }
}
