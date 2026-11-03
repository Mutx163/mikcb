package com.mutx163.qingyu.transfer

import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets

/**
 * 传输包文本读取的**严格 UTF-8 解码**（与 Dart `utf8.decode(bytes)` 同口径）。
 *
 * Dart 文件通道用 `utf8.decode`（默认 `allowMalformed: false`），畸形字节直接抛
 * `FormatException`；旧实现用 `String(bytes, UTF_8)`（替换字符兜底），会把损坏包
 * 解成带乱码的「看似合法」JSON 再导进去。这里把判据抽成纯逻辑，供 Android 胶水层调用，
 * 也让 JVM 单测能覆盖 `\xC3` / `\xFF` 这类字节。
 *
 * 注意：BOM（`EF BB BF`）是**合法** UTF-8，不在这里拒绝——它解出 `U+FEFF`，
 * 由后续 JSON 门按 Dart 口径判 `transfer_package_json_invalid`。
 */
object TransferTextDecoding {

    /** 严格解码；畸形/截断字节返回 null（调用方映射为「编码无效」）。 */
    fun decodeStrictUtf8(bytes: ByteArray): String? = try {
        StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    } catch (_: CharacterCodingException) {
        null
    }
}
