package com.mutx163.qingyu.architecture

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「静默失败」源码守卫（2026-11-03）。
 *
 * ## 为什么需要它
 *
 * 空 `catch` 把失败吞掉后，界面仍停在「像成功」的状态——用户点了、以为成了，实际什么都没发生。
 * 这比崩溃更难发现：崩溃至少看得见。典型场景是写盘 / 网络 / 权限失败后既不提示、也不回滚。
 *
 * ## 判据
 *
 * 扫描 `main` 与 `composeP1` 两个源集里的 `.kt`，命中「catch 体为空」即违规：
 * `catch (e: Exception) { }`、`catch (e: Exception) { /* 注释 */ }` 都算。
 * 注释与字符串会先被 [KotlinCatchScanner] 跳过，不会被字样误判；
 * 只写日志的 catch **不算空**：日志提供了「明确记录」，符合本次审计的另一条出口。
 *
 * ## 白名单（棘轮，只许收不许放）
 *
 * 存量登记在 `tool/silent_failure_exceptions.txt`，每行 `<仓库相对路径>|<允许条数>|<原因>`。
 * - 新增或条数上调 → 失败（必须改代码，不能往白名单里加）；
 * - 已修复但白名单没删行 / 条数没下调 → 同样失败（防止「顺手加回去」）。
 *
 * 另外，关键写路径（设置保存 / 课程导入 / 云同步 / 宏录制 / 提醒调度）**不允许进白名单**：
 * 这些文件的空 catch 只能靠改代码清掉，不能靠登记放过。
 */
class SilentFailureCatchGuardTest {

    private data class Allowance(val count: Int, val reason: String)

    private val sourceRoots = listOf(
        "android/app/src/main/kotlin",
        "android/app/src/composeP1/kotlin",
    )

    /**
     * 关键写路径：出现**新增**空 catch 一律失败，白名单也不兜底。
     *
     * 注意只收「写 / 调度」发生点；同类文件里读侧的逐条宽松解析（坏条目丢弃、外层另有
     * corrupt 判据）不属于写失败，按普通文件登记即可。
     */
    private val keyWritePathFragments = listOf(
        "app/TimetableRepository.kt",
        "app/TimetableSettingsModel.kt",
        "pages/ShellWiring.kt",
        "pages/import/warehouse/WarehouseWebLoginHost.kt",
        "pages/import/warehouse/WarehouseCoursesImportApply.kt",
        "pages/import/warehouse/WarehouseMacroStore.kt",
        "pages/sync/CloudSyncController.kt",
        "pages/sync/CloudSyncCoordinator.kt",
        "ScheduleReminderScheduler.kt",
        "ExamReminderScheduler.kt",
        "LiveUpdateScheduler.kt",
        "LiveUpdateService.kt",
        "LiveUpdateRefreshWorker.kt",
        "WeeklyReportScheduler.kt",
    )

    @Test
    fun `扫描器必须真的扫到两个源集且白名单存在`() {
        val repoRoot = repoRoot()
        val files = scanKotlinFiles(repoRoot)
        assertTrue(
            "只扫到 ${files.size} 个 .kt 文件，扫描根疑似失效（守卫空跑会假绿）",
            files.size >= 400,
        )
        assertTrue("找不到白名单 tool/silent_failure_exceptions.txt", exceptionsFile(repoRoot).isFile)
    }

    @Test
    fun `catch 体不得为空（含只有注释的空 catch 也算）`() {
        val repoRoot = repoRoot()
        val actual = collectEmptyCatches(repoRoot)
        val allowed = loadExceptions(repoRoot)
        val problems = mutableListOf<String>()

        // 1) 新增：路径未登记，或条数比登记的多。
        actual.forEach { (path, lines) ->
            if (isKeyWritePath(path)) {
                problems += "关键写路径出现空 catch（不允许登记放过）：$path"
                lines.forEach { problems += "    L$it" }
                return@forEach
            }
            val allowance = allowed[path]
            when {
                allowance == null -> {
                    problems += "新增空 catch（$path，${lines.size} 处）："
                    lines.forEach { problems += "    L$it" }
                }
                lines.size > allowance.count -> {
                    problems += "$path 的空 catch 由 ${allowance.count} 增至 ${lines.size}："
                    lines.drop(allowance.count).forEach { problems += "    L$it" }
                }
            }
        }

        // 2) 过期：已修复却没把白名单条数下调。
        allowed.forEach { (path, allowance) ->
            val now = actual[path]?.size ?: 0
            if (now < allowance.count) {
                problems += "$path 已修复但白名单未下调：登记 ${allowance.count}，实际 $now；请删掉多余行"
            }
        }

        assertTrue(
            buildString {
                appendLine("静默失败守卫失败（${problems.size} 处）：")
                problems.forEach { appendLine("  - $it") }
                appendLine()
                appendLine("修法：catch 里至少留下日志，并把失败语义往上抛 / 回滚 / 给用户提示；")
                appendLine("确需静默的存量登记到 tool/silent_failure_exceptions.txt 并写明原因。")
            },
            problems.isEmpty(),
        )
    }

    // ── 扫描 ────────────────────────────────────────────────────────────

    private fun scanKotlinFiles(repoRoot: File): List<File> = sourceRoots
        .map { File(repoRoot, it) }
        .flatMap { root ->
            check(root.isDirectory) { "找不到源码根：${root.absolutePath}" }
            root.walkTopDown().filter { it.isFile && it.name.endsWith(".kt") }.toList()
        }

    private fun collectEmptyCatches(repoRoot: File): Map<String, List<Int>> {
        val result = LinkedHashMap<String, MutableList<Int>>()
        scanKotlinFiles(repoRoot).forEach { file ->
            val lines = KotlinCatchScanner.findEmptyCatchLines(file.readText())
            if (lines.isEmpty()) return@forEach
            val relativePath = repoRelativePath(repoRoot, file)
            result.getOrPut(relativePath) { mutableListOf() }.addAll(lines)
        }
        return result
    }

    private fun repoRelativePath(repoRoot: File, file: File): String =
        repoRoot.toPath().relativize(file.toPath()).toString().replace('\\', '/')

    private fun isKeyWritePath(relativePath: String): Boolean =
        keyWritePathFragments.any { relativePath.contains(it) }

    // ── 白名单 ──────────────────────────────────────────────────────────

    private fun exceptionsFile(repoRoot: File): File =
        File(repoRoot, "tool/silent_failure_exceptions.txt")

    private fun loadExceptions(repoRoot: File): Map<String, Allowance> {
        val file = exceptionsFile(repoRoot)
        if (!file.isFile) return emptyMap()
        val result = LinkedHashMap<String, Allowance>()
        file.readLines().forEach { raw ->
            val line = raw.trim()
            if (line.isEmpty() || line.startsWith("#")) return@forEach
            val parts = line.split('|')
            require(parts.size >= 2) { "白名单行格式非法：$raw" }
            val path = parts[0].trim()
            val count = parts[1].trim().toIntOrNull() ?: error("白名单条数不是整数：$raw")
            val reason = parts.drop(2).joinToString("|").trim()
            require(reason.isNotEmpty()) { "白名单行必须写明原因：$raw" }
            result[path] = Allowance(count, reason)
        }
        return result
    }

    private fun repoRoot(): File {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            if (File(dir, "lib/l10n/app_zh.arb").isFile) return dir!!
            dir = dir?.parentFile
        }
        error("找不到仓库根（未定位到 lib/l10n/app_zh.arb）")
    }
}
