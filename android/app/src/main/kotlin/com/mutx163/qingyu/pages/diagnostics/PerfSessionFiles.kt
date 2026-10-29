package com.mutx163.qingyu.pages.diagnostics

import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * 探针落盘文件的命名与清理判据（源：`lib/utils/perf_probe.dart:292-444`）。
 *
 * 为什么单独一个文件：这一段是**纯字符串/时间逻辑**，却决定了「探针会不会删掉用户
 * 自己放进来的文件」。把它留在 Android 层就没人能钉住它了，而这类误删比少一份报表
 * 严重得多（Dart 侧三条不变量各有用例）。
 *
 * 三条不变量（Dart `sessionsToPrune` 注释）：
 * 1. 返回值里**永远不含** live 文件；
 * 2. 永远不含不认得的文件名（探针删掉用户自己放进来的东西，比不清理严重得多）；
 * 3. 超量时从**最旧**的开始删（文件名是零填充的 ISO 形状，字典序即时间序）。
 */
object PerfSessionFiles {
    /** 当前会话的落盘名（固定名字的好处是取数据只要记一条路径）。 */
    const val LIVE_JSON_NAME: String = "perf-live.json"
    const val LIVE_TXT_NAME: String = "perf-live.txt"

    /** 目录名（`filesDir/perf_reports`），与 Dart 的 `applicationSupportDirectory/perf_reports` 同层语义。 */
    const val REPORT_DIR_NAME: String = "perf_reports"

    /** 历史会话文件名形状：只认这一种。 */
    private val SESSION_PATTERN = Regex("^perf-session-\\d{8}T\\d{6}\\.json$")

    /** 导出文件名形状（json/txt 成对，共用同一时间戳前缀）。 */
    private val EXPORT_PATTERN = Regex("^perf-export-(\\d+)\\.")

    private val SESSION_STAMP = DateTimeFormatter.ofPattern("yyyyMMdd'T'HHmmss")

    /**
     * 历史会话文件名（带那次启动的落盘时刻，UTC）。
     *
     * 为什么要有历史会话：账本在内存里，冷启动会清零，而自动落盘原本是覆盖同一个
     * 文件名 —— 真机巡检因此只剩最后一次启动的几页，前面十几处页面的数据全被盖掉。
     */
    fun sessionFileName(stamp: Instant): String {
        val utc = stamp.atZone(ZoneOffset.UTC)
        return "perf-session-${utc.format(SESSION_STAMP)}.json"
    }

    /** 该删哪些历史会话文件（Dart `sessionsToPrune`）。 */
    fun sessionsToPrune(existingNames: List<String>, keep: Int = PerfProbeCore.MAX_KEPT_SESSIONS): List<String> {
        val sessions = existingNames.filter { SESSION_PATTERN.matches(it) }.sorted()
        if (sessions.size <= keep) return emptyList()
        return sessions.subList(0, sessions.size - keep).toList()
    }

    /** 一次导出的文件名（不含扩展名）：`perf-export-<epochMillis>`。 */
    fun exportBaseName(stampMillis: Long): String = "perf-export-$stampMillis"

    /**
     * 该删哪些导出文件（Dart `_pruneOldExports`）。
     *
     * 判据用**文件名里的时间戳**而不是文件 mtime：mtime 会被拷贝/解压改掉，
     * 而这两个数字是导出那一刻写进去的。
     *
     * @param keepPairs 保留几「轮」（一轮 = json + txt 两个文件），Dart 用 `12 * 2`。
     */
    fun exportsToPrune(
        existingNames: List<String>,
        keepPairs: Int = PerfProbeCore.MAX_KEPT_EXPORTS,
    ): List<String> {
        val stamps = existingNames.mapNotNull { name ->
            val match = EXPORT_PATTERN.find(name) ?: return@mapNotNull null
            val stamp = match.groupValues[1].toLongOrNull() ?: return@mapNotNull null
            name to stamp
        }
        val maxFiles = keepPairs * 2
        if (stamps.size <= maxFiles) return emptyList()
        // 从最旧的开始删；返回顺序也是「旧 → 新」，调用方按顺序删即可。
        return stamps.sortedByDescending { it.second }.drop(maxFiles).sortedBy { it.second }.map { it.first }
    }
}
