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

    /** 文件通道读取的结局（不抛异常；映射到用户文案由壳接线层做）。 */
    sealed interface DecodedImportText {
        /** 合法 UTF-8 且内容非空白。 */
        data class Success(val text: String) : DecodedImportText

        /**
         * 畸形/截断字节。壳侧映射到 ARB `importFailedInvalidFile`
         * （「导入失败，请确认文件有效」）。
         *
         * Dart 的 `TransferPackage.decodeBytes` 虽定义了 `transfer_package_utf8_invalid`，
         * 但文件通道没走它；Lead 裁决：不为这条未完成分支新增六语文案键，直接复用
         * `importFailedInvalidFile`。
         */
        data object InvalidEncoding : DecodedImportText

        /**
         * 解码成功但内容为空 / 仅空白。壳侧映射到 ARB `importFileReadFailed`
         * （「无法读取所选文件」），与 Dart `data_transfer_screen.dart:419-421` 同键。
         *
         * Dart 只判 `content.isEmpty`；本仓按 Lead 裁决把「仅空白」也判失败——
         * 空白文本对 JSON 门同样不可用，提前给出「读不到内容」比报包体无效更准确。
         */
        data object EmptyContent : DecodedImportText
    }

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

    /** 导入通道的解码入口：严格 UTF-8 → 空/空白判定。 */
    fun decodeImportText(bytes: ByteArray): DecodedImportText =
        when (val text = decodeStrictUtf8(bytes)) {
            null -> DecodedImportText.InvalidEncoding
            else -> if (text.isBlank()) DecodedImportText.EmptyContent
            else DecodedImportText.Success(text)
        }
}
