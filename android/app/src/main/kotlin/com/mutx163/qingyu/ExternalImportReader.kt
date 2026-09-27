package com.mutx163.qingyu

import java.io.ByteArrayOutputStream
import java.io.InputStream

/**
 * 外部「用其他应用打开 / 分享」导入的字节读取，带体积上限。
 *
 * 拆成独立对象而不是留在 MainActivity 里：上限本身是纯流逻辑，用普通 JVM 单测
 * 就能验（android/app/src/test 下都是这类逻辑测试），不必起设备。
 *
 * ## 为什么上限必须在原生侧
 *
 * 分享进来的 `content://` URI 由**别的应用**提供，用户没有任何自觉约束——目标
 * 文件多大全看对方。原来的 `stream.readBytes()` 会把整份文件一次性塞进堆，
 * 而 Android 的 OOM 是 `Error` 不是 `Exception`，外层的 `catch (e: Exception)`
 * 抓不到，直接杀进程。Dart 侧 `readImportFileBytes` 的上限只管得住「用户自己
 * 用文件选择器选的文件」，对分享这条路完全力不能及（字节早就读完了）。
 *
 * ics / backup 两种分享更彻底：原生把整份读成 `String` 交给 Dart，连文件都没
 * 留下，Dart 侧没有任何可量的东西。
 */
object ExternalImportReader {
    /**
     * 与 Dart 侧同口径：`SpreadsheetImportService.maxFileBytes` 与
     * `UnifiedTransferService.maxImportFileBytes` 都是 20 MB。
     *
     * 注意 xlsx 是 zip 容器，展开后的内存远大于磁盘体积，所以这个数字是
     * 「磁盘体积」上限，不是「解析峰值」上限。
     */
    const val MAX_IMPORT_BYTES: Long = 20L * 1024 * 1024

    private const val CHUNK_BYTES = 64 * 1024

    /**
     * 读 [input]，超过 [maxBytes] 立刻返回 null（已读的那部分随即被丢弃）。
     *
     * 必须在**读进内存的过程中**判，不能先 readBytes() 再看 length：那时候
     * 内存已经花掉了。返回 null 表示「太大，不导入」，调用方按「不是可导入内容」
     * 处理——上层已有 `?: return null` 的路径。
     *
     * [maxBytes] 恰好等于上限时通过（`>` 而非 `>=`），和 Dart 侧一致。
     */
    fun readCapped(input: InputStream, maxBytes: Long = MAX_IMPORT_BYTES): ByteArray? {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(CHUNK_BYTES)
        var total = 0L
        while (true) {
            val read = input.read(buffer)
            if (read < 0) {
                break
            }
            total += read
            if (total > maxBytes) {
                return null
            }
            out.write(buffer, 0, read)
        }
        return out.toByteArray()
    }
}
