package com.mutx163.qingyu.pages.live

/**
 * 超级岛两个图片入口（左侧标签 Logo / 展开态大图标）的**选图落盘判据**（纯 Kotlin，零 IO）。
 *
 * 移植 Dart `_pickAndStoreImage`（`lib/screens/live_settings_subpages.dart:1310-1364`）里
 * 「怎么判、存成什么名字」这一半；真正读流 / 写文件留在宿主层（那里才摸得到 `Context`）。
 *
 * ## 为什么值得单独一层
 *
 * 这三条判据都有**错一次就说不清**的分支：
 * 1. 超限必须先于「读进内存」判（Dart 原注释：`withData: true` 会让用户选一张相机原图就当场被系统杀掉）；
 * 2. 流读完为 null 只可能是「超限」，不是「读失败」——两者给的提示不一样，
 *    错报成「读取失败」会让用户以为图片坏了，反复重选；
 * 3. 文件名是**固定前缀**（`before_class_label_logo.png`），换图时靠它清掉旧图，
 *    否则历史图片会一直攒在私有目录里。
 *
 * 抽成纯函数后这三条能被 JVM 单测直接钉住（宿主层是 Compose + `ContentResolver`，测不到）。
 */
object LiveImagePickLogic {

    /**
     * 图片体积上限，与 Dart `UnifiedTransferService.maxImportFileBytes` 同一口径
     * （`lib/services/unified_transfer_service.dart:142` = 20 MB）。
     *
     * 这不是「图片该多大」的审美判断，而是「读进内存前先挡住」的兜底：
     * 一份 20 MB 的图解码成位图后可能上百 MB，而 Android 内存不足是直接杀进程、抛不出异常。
     */
    const val MAX_BYTES: Long = 20L * 1024 * 1024

    /** Dart `_labelLogoDir`（`live_settings_subpages.dart:35`）。 */
    const val LABEL_LOGO_DIR: String = "miui_label_logos"

    /** Dart `_expandedIconDir`（同文件 `:34`）。 */
    const val EXPANDED_ICON_DIR: String = "miui_expanded_icons"

    /** 一次选图落盘尝试的三种结局。 */
    enum class Outcome {
        /** 字节读齐了，可以写盘。 */
        OK,

        /** 超出 [MAX_BYTES]：给「文件超出大小上限」的提示，不是「读取失败」。 */
        TOO_LARGE,

        /** 真的没读到东西（空文件 / 读流出错）。 */
        FAILED,
    }

    /**
     * 判定这次选图能不能落盘。
     *
     * @param declaredLength `ContentResolver` 报出来的长度；`-1` = 说不清（某些 provider 不给）。
     * @param bytes 限长读完的结果；`null` = [com.mutx163.qingyu.ExternalImportReader.readCapped] 判超限。
     *
     * 期望值（手推）：
     * - `declaredLength = 21 MB` → TOO_LARGE（**不必**先读内容）
     * - `declaredLength = -1, bytes = null`（读的时候才发现超了）→ TOO_LARGE
     * - `bytes = 空数组` → FAILED（是空文件，不是超限）
     * - `bytes = 非空` → OK
     */
    fun classify(declaredLength: Long, bytes: ByteArray?): Outcome = when {
        declaredLength > MAX_BYTES -> Outcome.TOO_LARGE
        // readCapped 的唯一 null 出口就是「读的过程中发现超过上限」。
        bytes == null -> Outcome.TOO_LARGE
        bytes.isEmpty() -> Outcome.FAILED
        else -> Outcome.OK
    }

    /**
     * MIME 子类型 → 文件扩展名。
     *
     * 认不出的按 `png` 兜底（Dart 同一处也是 `: 'png'`）。扩展名只影响文件名，
     * 图片内容与解码方式由文件头决定——原生超级岛按路径读图，不看后缀。
     */
    fun extensionFor(mimeType: String?): String = when (mimeType?.lowercase()) {
        "image/png" -> "png"
        "image/jpeg", "image/jpg" -> "jpg"
        "image/webp" -> "webp"
        "image/gif" -> "gif"
        "image/bmp" -> "bmp"
        else -> "png"
    }

    /**
     * 落盘文件名：固定前缀 + 扩展名（Dart `'$filePrefix.$ext'`）。
     *
     * 固定（而不是加时间戳）是**故意的**：换图时靠同一个前缀把旧图清掉，
     * 私有目录里始终最多一份，用户反复试图也不会把磁盘塞满。
     */
    fun fileNameFor(filePrefix: String, mimeType: String?): String =
        "$filePrefix.${extensionFor(mimeType)}"

    /**
     * 该删掉的旧文件：同前缀、但不是即将写入的这一份。
     *
     * 只比前缀 + 点，不比整个文件名：换扩展名（png → jpg）时必须把旧的那份删掉，
     * 否则超级岛读哪一份取决于目录遍历顺序，用户会看到「换了图但没生效」。
     */
    fun shouldDelete(existingName: String, filePrefix: String, keepName: String): Boolean =
        existingName != keepName && existingName.startsWith("$filePrefix.")
}
