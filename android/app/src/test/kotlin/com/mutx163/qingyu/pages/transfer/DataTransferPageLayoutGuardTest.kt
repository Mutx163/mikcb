package com.mutx163.qingyu.pages.transfer

import java.io.File
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **「数据备份与迁移」页排布守卫**（2026-11-08 美化轮建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 这一页原来两个动作组都用 `FlowRow`（转抄发布版 Dart 的 `Wrap`）：按钮按文案长度换行，
 * 必然 2+1 穿位；明文警告则裸挤在说明正文里、与动作没有层级。美化把动作组统一成整宽
 * 竖排、警告拆成独立错误横幅、概览行间补分割线。排布只有在源码里看得见——编译不会
 * 变红，所以这里把这套具体形状用文本钉住，谁改回 `FlowRow`/裸警告/去分割线谁就红。
 *
 * ## 钉住的事实
 *
 * 1. 页面里不再出现 `FlowRow(`（导出 / 二维码两组都不许靠换行排布）；
 * 2. 主动作按钮一律 `fillWidth = true` 整宽竖排（导出 3 + 导入 1 + 二维码 3）；
 * 3. 明文警告仍用同一条 ARB 文辞、走独立横幅（警示图标 + error 字色）；
 * 4. 概览行之间有 `HorizontalDivider` 分割线；
 * 5. 行为红线未动：导出/导入的忙碌转圈、禁用判据、二维码收发分支、导入的三个动作
 *    （覆盖/合并/导入为新）、选课弹层与范围弹窗的调用处全部原样在位。
 */
class DataTransferPageLayoutGuardTest {

    /** 页面源码去 `//` 行注释：注释里写「原先是 FlowRow」不算复发。 */
    private val pageSource: String by lazy { stripLineComments(readRepoFile(PAGE_PATH)) }

    @Test
    fun `动作组不再用 FlowRow 换行排布`() {
        assertTrue(
            "DataTransferPage 又用上 FlowRow( 了——动作组一换行就 2+1 穿位，" +
                "应走 Column 整宽竖排 + fillWidth",
            !pageSource.contains("FlowRow("),
        )
    }

    @Test
    fun `主动作按钮一律整宽竖排`() {
        val fullWidth = Regex("""fillWidth = true""").findAll(pageSource).count()
        assertTrue(
            "整宽按钮应有 7 处（导出 3 + 导入 1 + 二维码 3），当前 $fullWidth 处",
            fullWidth >= 7,
        )
        assertTrue(
            "二维码三键必须在同一竖排组里是 QR 段的顺序" +
                "（发送当前课表 / 发送全部数据 / 扫码接收课表数据）",
            pageSource.indexOf("qrTransferSendCurrent") < pageSource.indexOf("qrTransferSendAll") &&
                pageSource.indexOf("qrTransferSendAll") < pageSource.indexOf("qrTransferScanReceive"),
        )
    }

    @Test
    fun `明文警告是独立横幅且措辞原样`() {
        assertTrue(
            "警告横幅必须有警示图标 MiuixIcons.Report（独立提示形态）",
            pageSource.contains("MiuixIcons.Report"),
        )
        assertTrue(
            "警告文字必须仍取 TransferStrings.qrTransferPlaintextWarning（措辞不改）",
            pageSource.contains("TransferStrings.qrTransferPlaintextWarning.text"),
        )
        assertTrue(
            "警告横幅必须挂独立成段的私有组件" +
                "（不能再回到正文里的裸红字 Text）",
            pageSource.contains("private fun QrPlaintextWarningBanner("),
        )
    }

    @Test
    fun `概览行之间有分割线`() {
        assertTrue(
            "概览行应有行间分割线（与日历导航的堆叠行视觉统一）",
            pageSource.contains("HorizontalDivider(") &&
                pageSource.contains("QingyuTheme.dividerLine("),
        )
    }

    @Test
    fun `行为红线未动`() {
        for (anchor in listOf(
            // 导出中的忙碌转圈与禁用判据（红线 1：转圈替换标签）。
            "loading = viewState.isExporting",
            "enabled = !viewState.isExporting",
            "enabled = !viewState.isExporting && viewState.canExportTimeTemplate",
            // 导入中的忙碌转圈与禁用判据。
            "loading = viewState.isImporting",
            "enabled = !viewState.isImporting",
            // 二维码收发分支：扫码只看 isImporting，不看 isExporting。
            "onClick = { qrScopeDialogVisible = true }",
            "onClick = onQrSendAll",
            "onClick = onQrScan",
            // 选课/范围弹层的入口与调用（红线 2）。
            "private fun QrScopeDialog(",
            "private fun CoursePickerSheet(",
            "DataTransferLogic.requiresCourseSelection(scope)",
            "DataTransferLogic.toggleCourseGroup(selectedCourseIds, group)",
            "DataTransferLogic.isCourseGroupSelected(selected, group)",
            "onQrSend(scope, selectedCourseIds)",
            // 导入的三个动作：覆盖 / 合并 / 导入为新（红线 3）。
            "fun TransferPreviewDialog(",
            "DataTransferLogic.previewActions(canMerge, canImportAsNew)",
            "TransferApplyMode.OVERWRITE",
        )) {
            assertTrue("行为红线锚点丢失：$anchor", pageSource.contains(anchor))
        }
    }

    // ------------------------------------------------------------------ 定位

    private fun readRepoFile(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    /** 行注释与块注释（KDoc/骨架说明）都剥掉：注释里写「MiuixIcons.Report」不算实现。 */
    private fun stripLineComments(text: String): String =
        text.replace(Regex("""/\*[\s\S]*?\*/"""), " ")
            .lineSequence().joinToString("\n") { line -> line.substringBefore("//") }

    private companion object {
        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/DataTransferPage.kt"
    }
}
