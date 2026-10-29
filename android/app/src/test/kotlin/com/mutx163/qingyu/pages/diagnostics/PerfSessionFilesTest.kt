package com.mutx163.qingyu.pages.diagnostics

import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 落盘文件命名与清理判据单测（源：`lib/utils/perf_probe.dart:292-444`）。
 *
 * 这一组用例存在的理由只有一个：**探针删错文件比不清理严重得多**。
 * 三条不变量逐条钉住——不碰 live、不碰不认得的名字、只从最旧的开始删。
 */
class PerfSessionFilesTest {

    @Test
    fun `会话文件名是 UTC 零填充的 ISO 形状`() {
        assertEquals(
            "perf-session-20261029T132653.json",
            PerfSessionFiles.sessionFileName(Instant.parse("2026-10-29T13:26:53Z")),
        )
        // 个位数月/日/时/分/秒必须补零，否则字典序不再等于时间序
        assertEquals(
            "perf-session-20260102T030405.json",
            PerfSessionFiles.sessionFileName(Instant.parse("2026-01-02T03:04:05Z")),
        )
    }

    @Test
    fun `清理会话文件时永远不碰 live 与不认识的文件`() {
        val names = buildList {
            add(PerfSessionFiles.LIVE_JSON_NAME)
            add(PerfSessionFiles.LIVE_TXT_NAME)
            add("notes.txt")
            add("user-backup.json")
            repeat(12) { index ->
                add("perf-session-2026100${(index % 9) + 1}T00000${index % 10}.json")
            }
        }
        val pruned = PerfSessionFiles.sessionsToPrune(names, keep = 10)

        assertEquals(2, pruned.size)
        assertTrue(pruned.none { it == PerfSessionFiles.LIVE_JSON_NAME })
        assertTrue(pruned.none { it == "notes.txt" })
        assertTrue(pruned.none { it == "user-backup.json" })
        // 从最旧的开始删：pruned 里每一条都必须排在保留集合之前
        val sessions = names.filter { it.startsWith("perf-session-") }.sorted()
        assertEquals(sessions.take(2), pruned)
    }

    @Test
    fun `会话文件不超过保留份数时一个都不删`() {
        val names = (0 until 10).map { "perf-session-202610${10 + it}T000000.json" }
        assertTrue(PerfSessionFiles.sessionsToPrune(names, keep = 10).isEmpty())
    }

    @Test
    fun `导出文件名带毫秒时间戳`() {
        assertEquals("perf-export-1793000000123", PerfSessionFiles.exportBaseName(1_793_000_000_123L))
    }

    @Test
    fun `导出超过 12 轮时从最旧的开始删 json 与 txt 成对`() {
        // 13 轮 = 26 个文件，上限 12 轮 = 24 个 ⇒ 删最旧的那一轮（2 个文件）
        val names = (1..13).flatMap { round ->
            val stamp = 1_000L + round
            listOf("perf-export-$stamp.json", "perf-export-$stamp.txt")
        } + listOf("notes.txt", PerfSessionFiles.LIVE_JSON_NAME)

        val pruned = PerfSessionFiles.exportsToPrune(names, keepPairs = 12)
        assertEquals(listOf("perf-export-1001.json", "perf-export-1001.txt"), pruned)
    }

    @Test
    fun `导出目录里的无关文件不参与清理`() {
        val names = (1..30).map { "perf-export-${1_000 + it}.txt" } +
            listOf("download.apk", "perf-export-abc.txt")
        val pruned = PerfSessionFiles.exportsToPrune(names, keepPairs = 12)
        assertEquals(6, pruned.size)
        assertTrue(pruned.none { it == "download.apk" })
        assertTrue(pruned.none { it == "perf-export-abc.txt" })
        // 删的必须是最旧的 6 个
        assertEquals((1..6).map { "perf-export-${1_000 + it}.txt" }, pruned)
    }
}
