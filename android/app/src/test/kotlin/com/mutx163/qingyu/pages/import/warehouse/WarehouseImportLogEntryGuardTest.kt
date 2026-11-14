package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.testutil.SourceSlice
import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import com.mutx163.qingyu.testutil.readSourceNormalized
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **执行日志面板的接线守卫**（读源码，不是 UI 测试）。
 *
 * ## 为什么只能是源码守卫
 *
 * 面板、入口、超时弹窗全在 `composeP1`，**L0 只编 `main/`**，本仓也没有能跑 Compose 的 UI
 * 测试层——「点了真会打开面板」「第三颗按钮真在」这类事实只能靠源码结构判。这里判的是接线，
 * 不是观感：布局、配色、横滚手感仍需真机（见回报的「未验」清单）。
 *
 * ## 钉的五条
 *
 * 1. 入口：`WarehouseWebLoginPage` 里调 `WarehouseImportLogPage(...)`，显隐由宿主的
 *    `showImportLog` 驱动（顶栏「更多」菜单项置真、面板返回置假）；顶栏**不再**有
 *    单独一颗入口按钮（2026-11-14 用户实报：那颗玻璃球风格特殊、且与菜单两套入口并存）；
 * 2. 数据源：面板页持有 `WarehouseImportLogBuffer` 并调 `snapshot()`（不是自己编数据）；
 * 3. 复用：面板的分组/行格式/分享文本**只来自** `WarehouseImportLogView`——UI 文件里不许
 *    再出现 `RUN ` 组头拼接、`snapshot.runs` 遍历、`formatEntryLine(` 或 `LogSection(`；
 * 4. 超时弹窗：三颗按钮都在（重试 / 改用手动导入 / 查看日志），第三颗引 `executeViewLogAction`；
 * 5. 注释事实化：两处旧措辞（「日志面板还没移植」「看返回值的人」）不许再出现——这两处
 *    直接决定评审判「是否真交付」，所以用**带注释的原文**读（剥注释的读法会让这条恒真）。
 *
 * 读法说明：结构判据走 [readKotlinSourceNoStrings]（剥注释 + 中性化字符串，避免被 KDoc /
 * 字面量满足）；「某字面量不许出现」与「注释里旧措辞不许出现」走另两档，逐条写在用例旁。
 */
class WarehouseImportLogEntryGuardTest {

    private val pageSource: String by lazy { readKotlinSourceNoStrings(PAGE_PATH) }
    private val hostSource: String by lazy { readKotlinSourceNoStrings(HOST_PATH) }
    private val panelSource: String by lazy { readKotlinSourceNoStrings(PANEL_PATH) }

    /** 字符串内容**保留**的档位：判「UI 里不许出现 `RUN ` 这个字面量」。 */
    private val panelTextSource: String by lazy { readKotlinSourceNormalized(PANEL_PATH) }

    /** 原文（含注释）：判「旧措辞已不存在」，剥注释会让否定式断言恒真。 */
    private val rawHost: String by lazy { readSourceNormalized(HOST_PATH) }
    private val rawWriter: String by lazy { readSourceNormalized(WRITER_PATH) }
    private val rawLogHooks: String by lazy { readSourceNormalized(LOG_HOOKS_PATH) }

    /** C 的落点文件（纯逻辑，剥注释 + 中性化字符串判结构）。 */
    private val writerSource: String by lazy { readKotlinSourceNoStrings(WRITER_PATH) }

    /** 先自证三份源码都读到了（路径写错时下面几条会一起红，不如这里先红得清楚）。 */
    @Test
    fun `sources are readable and anchors exist`() {
        assertSourceContains(pageSource, "fun WarehouseWebLoginPage(", "WarehouseWebLoginPage")
        assertSourceContains(hostSource, "fun WarehouseWebLoginHost(", "WarehouseWebLoginHost")
        assertSourceContains(panelSource, "fun WarehouseImportLogPage(", "WarehouseImportLogPage")
        assertSourceContains(rawHost, "WarehouseExecutionTimeoutDialog", "WarehouseWebLoginHost (raw)")
        assertSourceContains(rawWriter, "WarehouseImportLogFileWriter", "WarehouseImportLogFileWriter (raw)")
    }

    /** ① 入口：页面里有面板调用，显隐由宿主状态驱动；面板叠在登录页之后（WebView 不被销毁）。 */
    @Test
    fun `panel is opened from the login page and driven by host state`() {
        assertSourceContains(
            pageSource,
            "if (showImportLog) {",
            "WarehouseWebLoginPage (panel visibility)",
        )
        assertSourceContains(
            pageSource,
            "WarehouseImportLogPage(onBack = onCloseImportLog)",
            "WarehouseWebLoginPage (panel call)",
        )
        // 叠层顺序：面板必须组合在骨架之后（同父容器里后组合的一层盖在前面）。
        val scaffoldAt = pageSource.indexOf("QingyuPageScaffold(")
        val panelAt = pageSource.indexOf("WarehouseImportLogPage(")
        assertTrue(
            "panel must be composed after the page scaffold (scaffoldAt=$scaffoldAt panelAt=$panelAt)",
            scaffoldAt >= 0 && panelAt > scaffoldAt,
        )
        // 入口只有一处：顶栏「更多」菜单里的一行 miuix `TextButton`
        // （2026-11-14 用户实报：顶栏那颗独立玻璃球与同页其它动作键不同款，且与
        // 「更多」菜单并存两套入口，用户要猜哪个才是完整的）。
        val moreMenu = SourceSlice.between(
            hostSource,
            "WarehouseStrings.moreActionsTooltip.text",
            "WarehouseStrings.cancelAction.text",
        )
        assertSourceContains(
            moreMenu,
            "WarehouseStrings.warehouseImportExecutionLogMenuLabel.text",
            "更多菜单（执行日志项）",
        )
        assertSourceContains(moreMenu, "showImportLog = true", "更多菜单（执行日志项打开面板）")
        // 反向：顶栏不许再画那颗独立入口——参数与按钮本体都必须消失。
        assertSourceLacks(pageSource, "onOpenImportLog", "WarehouseWebLoginPage (no standalone entry param)")
        assertSourceLacks(pageSource, "QingyuGlassIconButton(", "WarehouseWebLoginPage (no special-style ball)")
        // 顶栏动作区只剩 miuix 标准 `IconButton`（含「更多」那颗）。
        assertSourceContains(
            pageSource,
            "IconButton(onClick = onMoreOptions)",
            "WarehouseWebLoginPage (standard more icon)",
        )

        // 宿主侧：状态位 + 面板返回置假。
        assertSourceContains(hostSource, "var showImportLog by remember", "WarehouseWebLoginHost (state)")
        assertSourceContains(hostSource, "showImportLog = showImportLog", "WarehouseWebLoginHost (pass state)")
        assertSourceContains(hostSource, "onCloseImportLog = { showImportLog = false }", "WarehouseWebLoginHost")
    }

    /** ② 数据源：面板读的是 buffer 快照，不是任何自造数据。 */
    @Test
    fun `panel page reads a WarehouseImportLogBuffer snapshot`() {
        assertSourceContains(panelSource, "fun WarehouseImportLogPage(", "WarehouseImportLogPage")
        assertSourceContains(panelSource, "buffer: WarehouseImportLogBuffer", "WarehouseImportLogPage")
        assertSourceContains(panelSource, "buffer.snapshot()", "WarehouseImportLogPage")
        assertSourceContains(panelSource, "WarehouseImportLogView.buildLogSections(", "WarehouseImportLogPage")
        assertSourceContains(panelSource, "WarehouseImportLogView.buildShareText(", "WarehouseImportLogPage")
    }

    /**
     * ③ UI 不许重复实现分组与行格式。
     *
     * 判据全是「这几种写法不许出现在 UI 文件里」：组头字面量 `RUN `、快照 run 遍历、
     * 行格式化函数、分组结果构造。**负例探针**：在面板页的 UI 文件里临时加
     * `text = "RUN " + index`，本用例必须红（回报里贴了失败原文与还原后的 OK 行）。
     */
    @Test
    fun `UI must not reimplement grouping or row formatting`() {
        assertSourceContains(panelSource, "WarehouseImportLogView.buildLogSections(", "panel (uses pure model)")
        assertSourceContains(panelSource, "line.emphasis", "panel (maps emphasis to color)")
        assertSourceContains(panelSource, "MiuixTheme.colorScheme.error", "panel (R5 theme color)")
        assertSourceContains(panelSource, "MiuixTheme.colorScheme.primary", "panel (R5 theme color, WARN)")

        // 字符串保留档位：`"RUN "` 这种字面量拼接必须红。
        assertSourceLacks(panelTextSource, "\"RUN \"", "panel (no RUN header literal)")
        // 代码档位：不许自己遍历 runs、自己格式化行、自己造分组。
        assertSourceLacks(panelSource, "snapshot.runs", "panel (no run grouping)")
        assertSourceLacks(panelSource, ".runs", "panel (no run grouping)")
        assertSourceLacks(panelSource, "formatEntryLine(", "panel (no row formatting)")
        assertSourceLacks(panelSource, "LogSection(", "panel (no section building)")
        assertSourceLacks(panelSource, "LogLine(", "panel (no line building)")
    }

    /** ④ 超时弹窗第三颗按钮：三颗都在，第三颗引「查看日志」并打开同一个面板。 */
    @Test
    fun `timeout dialog has three buttons including view log`() {
        val dialog = SourceSlice.functionBody(hostSource, "private fun WarehouseExecutionTimeoutDialog(")
        assertSourceContains(dialog, "onRetry", "timeout dialog (button 1)")
        assertSourceContains(dialog, "onSwitchToManual", "timeout dialog (button 2)")
        assertSourceContains(dialog, "onViewLog", "timeout dialog (button 3)")
        assertSourceContains(dialog, "WarehouseStrings.quickImportRetryAction", "timeout dialog (retry label)")
        assertSourceContains(dialog, "WarehouseStrings.executeSwitchToManualAction", "timeout dialog (manual label)")
        assertSourceContains(dialog, "WarehouseStrings.executeViewLogAction", "timeout dialog (view log label)")

        // 调用点：第三颗把面板打开；面板展开期间弹窗先收起（关面板后自动恢复）。
        assertSourceContains(hostSource, "onViewLog = { showImportLog = true }", "WarehouseWebLoginHost")
        assertSourceContains(
            hostSource,
            "show = showExecutionTimeoutDialog && !showImportLog",
            "WarehouseWebLoginHost (dialog hidden while the panel is open)",
        )
    }

    /** ⑤ 两处旧措辞必须消失（读带注释的原文；否定式断言在空读上会先红）。 */
    @Test
    fun `stale wording about the missing panel is gone`() {
        listOf(
            "日志面板还没移植",
            "面板没做",
            "还没移植",
            "生产端还没移植",
            "第 2 步",
        ).forEach { phrase ->
            assertSourceLacks(rawHost, phrase, "WarehouseWebLoginHost (raw)")
        }
        listOf(
            "看返回值的人",
            "第 2 步",
        ).forEach { phrase ->
            assertSourceLacks(rawWriter, phrase, "WarehouseImportLogFileWriter (raw)")
        }

        // 正向一侧：两处都指向了真实符号（只删不指 = 读者照样不知道去哪看）。
        assertSourceContains(rawHost, "WarehouseImportLogPage", "WarehouseWebLoginHost")
        assertSourceContains(rawWriter, "WarehouseImportLogPage", "WarehouseImportLogFileWriter")
    }

    /**
     * C：应用日志的 append 调用点必须在脱敏之后（相对位置判据）。
     *
     * 顺序反了（先 append 再脱敏）= 应用日志拿到的是原文；这不是审美问题，是「面板干净、
     * 应用日志脏」的那条新增风险。判据按 `indexOf` 的相对位置，不依赖行号。
     */
    @Test
    fun `app log append site sits after the redaction step`() {
        assertSourceContains(hostSource, "writeWarehouseImportLogFile(", "WarehouseWebLoginHost")
        assertSourceContains(hostSource, "appendWarehouseImportLogToAppLog(", "WarehouseWebLoginHost")

        val redactAt = hostSource.indexOf("WarehouseLogRedaction.redactText(")
        val appendAt = hostSource.indexOf("appendWarehouseImportLogToAppLog(")
        assertTrue(
            "host: appendWarehouseImportLogToAppLog( must sit after WarehouseLogRedaction.redactText(; " +
                "redactAt=$redactAt appendAt=$appendAt",
            redactAt >= 0 && appendAt > redactAt,
        )
    }

    /** C：8 KiB 上限、未初始化跳过、写失败记 INTERNAL、第二道脱敏——四条都在落点文件里。 */
    @Test
    fun `app log helper keeps the cap the gate and the internal fallback`() {
        assertSourceContains(
            writerSource,
            "WAREHOUSE_IMPORT_APP_LOG_MAX_BYTES: Int = 8 * 1024",
            "WarehouseImportLogFileWriter (cap)",
        )
        assertSourceContains(
            writerSource,
            "WAREHOUSE_IMPORT_APP_LOG_TRUNCATED_NOTE",
            "WarehouseImportLogFileWriter (truncation marker)",
        )
        assertSourceContains(writerSource, "AppLogStore.isInitialized()", "WarehouseImportLogFileWriter")
        assertSourceContains(writerSource, "AppLogStore.append(", "WarehouseImportLogFileWriter")
        assertSourceContains(writerSource, "WarehouseLogRedaction.redactText(", "WarehouseImportLogFileWriter")
        assertSourceContains(writerSource, "WarehouseLogCategory.INTERNAL", "WarehouseImportLogFileWriter")
    }

    /** B2：采集钩子的文件头不许再留「第 2 步 / B 半」这类阶段说法（读原文，注释也算）。 */
    @Test
    fun `log hooks file no longer mentions the second step`() {
        listOf("第 2 步", "B 半").forEach { phrase ->
            assertSourceLacks(rawLogHooks, phrase, "WarehouseLogHooks (raw)")
        }
    }

    private companion object {
        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt"
        const val HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginHost.kt"
        const val PANEL_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseImportLogPage.kt"
        const val WRITER_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseImportLogFileWriter.kt"
        const val LOG_HOOKS_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseLogHooks.kt"
    }
}
