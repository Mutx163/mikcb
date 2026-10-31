package com.mutx163.qingyu.pages.about

import java.io.File
import java.io.InputStream
import java.security.MessageDigest

/**
 * 安装包摘要校验（纯 JVM，可 L0 单测）。
 *
 * 源：`lib/services/app_update_service.dart` 的 sha256 判据与两个错误码
 * （`update_download_hash_mismatch` / `update_sha256_unverified_install_refused`），
 * 参考 `lib/screens/about_screen.dart:1462-1505`（`_downloadAndInstall` 把
 * `expectedApkSha256` 一路传到 `downloadAndInstallUpdate`）。
 *
 * ## 为什么这段必须独立出来
 *
 * 「下载完就弹安装」是所有更新器的经典漏洞：中间人换掉 APK、镜像返回错误文件、
 * CDN 截断，都能让用户装上**不是我们发的**包。Dart 侧的口径是：
 *
 * 1. 发布元数据里带 `sha256` 时**必须**校验；
 * 2. 校验不一致 ⇒ 拒绝安装（`hash_mismatch`）；
 * 3. 声明了摘要但本地算不出来（读不到文件/流断了）⇒ 同样拒绝安装
 *    （`sha256_unverified_install_refused`），**不降级成「没有摘要就当没要求」**。
 *
 * 这三条都在 [apkDigestVerdict] 里表达，宿主只负责按结论弹提示/装包，
 * 判据本身不碰 Android API（因此能进 `pages/about` 的 L0 通道）。
 */

/** 期望摘要的归一化结果：只有「64 位十六进制」才算有效声明。 */
const val APK_SHA256_HEX_LENGTH: Int = 64

/** 摘要比对结论（[apkDigestVerdict] 的返回值）。 */
enum class ApkDigestVerdict {
    /** 元数据没声明摘要：无可校验项，按 Dart 口径放行（不是「校验通过」）。 */
    NOT_DECLARED,

    /** 声明了摘要且本地算出来一致。 */
    MATCH,

    /** 声明了摘要，本地算出来不一致 ⇒ 拒绝安装。 */
    MISMATCH,

    /** 声明了摘要，但本地算不出（读不到文件 / 长度不对）⇒ 拒绝安装。 */
    UNVERIFIABLE,
}

/**
 * 把元数据里的 `sha256` 归一化成小写十六进制；不是 64 位十六进制就当没声明（返回 null）。
 *
 * 接受 `sha256:xxxx` / `SHA256=xxxx` 这类前缀写法（GitHub Release API 的 `digest`
 * 字段就是 `sha256:<hex>`），也接受全大写。
 */
fun normalizeExpectedSha256(raw: String?): String? {
    val text = raw?.trim().orEmpty()
    if (text.isEmpty()) return null
    val withoutPrefix = text
        .removePrefix("sha256:")
        .removePrefix("sha256=")
        .removePrefix("SHA256:")
        .removePrefix("SHA256=")
        .trim()
        .lowercase()
    if (withoutPrefix.length != APK_SHA256_HEX_LENGTH) return null
    if (!withoutPrefix.all { it in '0'..'9' || it in 'a'..'f' }) return null
    return withoutPrefix
}

/**
 * 判据：期望值（元数据声明）与实测值（本地算）→ 该不该装。
 *
 * [actual] 为 null 表示「算不出来」，只有在**没有声明**摘要时才放行。
 */
fun apkDigestVerdict(expected: String?, actual: String?): ApkDigestVerdict {
    val normalizeExpected = normalizeExpectedSha256(expected) ?: return ApkDigestVerdict.NOT_DECLARED
    val normalizeActual = actual?.trim()?.lowercase()?.takeIf { it.isNotEmpty() }
        ?: return ApkDigestVerdict.UNVERIFIABLE
    return if (normalizeActual == normalizeExpected) {
        ApkDigestVerdict.MATCH
    } else {
        ApkDigestVerdict.MISMATCH
    }
}

/** 摘要字节 → 小写十六进制（不用 `%02x`：Byte 的符号/本地化口径不值得赌）。 */
private fun ByteArray.toHexLower(): String {
    val out = StringBuilder(size * 2)
    for (byte in this) {
        val value = byte.toInt() and 0xFF
        out.append(HEX_DIGITS[value ushr 4]).append(HEX_DIGITS[value and 0x0F])
    }
    return out.toString()
}

private const val HEX_DIGITS = "0123456789abcdef"

/** 字节数组的 SHA-256 小写十六进制。 */
fun sha256Hex(bytes: ByteArray): String =
    MessageDigest.getInstance("SHA-256").digest(bytes).toHexLower()

/**
 * 流的 SHA-256（不一次性读进内存：APK 可以上百 MB）。
 *
 * 不关闭传入的流——调用方负责 `use { }`，这里只消费。
 */
fun sha256Hex(stream: InputStream, bufferSize: Int = 64 * 1024): String {
    val digest = MessageDigest.getInstance("SHA-256")
    val buffer = ByteArray(bufferSize)
    while (true) {
        val read = stream.read(buffer)
        if (read <= 0) break
        digest.update(buffer, 0, read)
    }
    return digest.digest().toHexLower()
}

/** 文件摘要；读不到时返回 null（对应 [ApkDigestVerdict.UNVERIFIABLE]）。 */
fun sha256HexOfFile(file: File): String? = runCatching {
    file.inputStream().use { sha256Hex(it) }
}.getOrNull()
