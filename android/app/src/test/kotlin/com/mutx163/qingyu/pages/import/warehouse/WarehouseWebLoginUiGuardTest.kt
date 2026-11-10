package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * **网页登录页 / 回放覆盖层的 UI 契约守卫**（W2，2026-11-10）。
 *
 * 这两个文件在 `composeP1` 源集，L0 编译不到（只编 `main/`），而审核抓到的问题都是
 * **源码结构可判**的 UI 契约：
 * - 网页加载失败 / 脚本 error / 超时的文案（`session.errorMessage`）必须上屏，
 *   ERROR 态不许整条静默（审核 8b）；
 * - 执行期按钮必须换「导入中……」+ loading，写盘期必须禁用（发布版
 *   `_isExecutingImport` 同一旗标）；
 * - 回放期间顶栏的「录制 / 桌面切换」必须不渲染（发布版 `macroRecord != null` 同款）；
 * - 回放遮罩必须自己拦触摸，而暂停态必须放行；执行态必须有取消按钮（审核 8d + P0-2）。
 *
 * 判据只读源码、不碰 Compose；改坏必须红（每条都做过咬合探针，见回报）。
 */
class WarehouseWebLoginUiGuardTest {

    private val pageSource: String by lazy {
        readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebLoginPage.kt")
    }
    private val overlaySource: String by lazy {
        readSource("android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseMacroPlaybackUi.kt")
    }

    @Test
    fun `网页错误文案必须上屏_ERROR 态不许整条静默`() {
        val marker = "val issue = sessionState.errorMessage"
        assertTrue("错误文案必须从 sessionState.errorMessage 取：$marker", pageSource.contains(marker))

        // 状态行必须真的渲染它（不是只取不用），且用错误色。
        // 注意：marker 行本身带 `takeIf { … }` 的 `{`，不能直接从 marker 起配平；
        // 先跳到它后面的 `when {` 再取整块。
        val statusBlock = blockAfter(pageSource.substringAfter(marker), "when {")
        assertTrue("取到 errorMessage 后必须在状态行里显示", statusBlock.contains("issue != null ->"))
        assertTrue(
            "错误状态行必须用主题错误色（R5：不许写死颜色）",
            statusBlock.contains("MiuixTheme.colorScheme.error"),
        )

        // 旧写法在 ERROR 时把整条提示藏掉（只剩一颗灰按钮）——不许回来。
        assertFalse(
            "ERROR 态不许再把状态行整条藏掉（`stage != WarehouseWebLoginStage.ERROR`）",
            pageSource.contains("stage != WarehouseWebLoginStage.ERROR"),
        )
        // 加载完成与否的提示只允许落在「非执行期」，执行期由按钮自己说「导入中……」。
        assertTrue(
            "「等待页面加载」只许在非执行期出现（执行期错文案是审核 8b 的另一半）",
            pageSource.contains("!scriptReady && !executing"),
        )
    }

    @Test
    fun `执行态必须换导入中并 loading_写盘期禁用主按钮`() {
        assertTrue(
            "页面必须暴露写盘期契约（宿主传 true 时按钮显示导入中并禁用）",
            pageSource.contains("importWriting: Boolean = false"),
        )
        assertTrue(
            "执行期（注入 / 执行脚本）与写盘期的按钮文案必须换成 importingAction",
            pageSource.contains("label = if (executing || importWriting)"),
        )
        assertTrue(
            "按钮 loading 必须由 executing / importWriting 驱动",
            pageSource.contains("loading = executing || importWriting"),
        )
        assertTrue(
            "写盘期必须禁用按钮（防重复导入）",
            pageSource.contains("enabled = scriptReady && !importWriting"),
        )
        assertTrue(
            "「导入中……」文案键必须是 ARB 已有的 importingAction",
            pageSource.contains("WarehouseStrings.importingAction.text"),
        )
    }

    @Test
    fun `回放期间必须隐藏录制与桌面切换`() {
        val actions = blockAfter(pageSource, "actions = {")
        assertTrue("取不到顶栏 actions 块（守卫自身失效）", actions.isNotEmpty())
        val guarded = blockAfter(actions, "if (!foregroundReplayActive) {")
        assertTrue("顶栏动作必须按 foregroundReplayActive 收口", guarded.isNotEmpty())
        assertTrue(
            "回放期间「录制」入口必须被隐藏（否则会把回放录进新宏覆盖旧宏）",
            guarded.contains("onToggleMacroRecording"),
        )
        assertTrue(
            "回放期间「桌面/移动切换」必须被隐藏（否则 reload 直接打断回放）",
            guarded.contains("webViewController.toggleDesktopMode()"),
        )
    }

    @Test
    fun `回放遮罩必须拦触摸_暂停态放行_执行态有取消`() {
        val scrim = blockAfter(overlaySource, "private fun PlaybackScrim(")
        assertTrue("取不到 PlaybackScrim（守卫自身失效）", scrim.isNotEmpty())
        assertTrue(
            "遮罩必须装 pointerInput 参与命中（审核 8d：不拦就穿透到 WebView / 顶栏）",
            scrim.contains(".pointerInput(Unit)"),
        )
        assertTrue(
            "遮罩必须真的收事件（只写注释不算数）",
            scrim.contains("awaitPointerEvent()"),
        )

        // 暂停态走 PausedBottomCard、不用 PlaybackScrim：用户要在网页里填验证码。
        val pausedLine = overlaySource.lineSequence()
            .firstOrNull { it.contains("PAUSED_FOR_INPUT ->") }
        assertTrue("取不到暂停态分支（守卫自身失效）", pausedLine != null)
        assertTrue("暂停态必须是放行的底部卡片", pausedLine!!.contains("PausedBottomCard("))
        assertFalse(
            "暂停态不许套拦触摸的 PlaybackScrim（否则验证码/密码点不到）",
            pausedLine.contains("PlaybackScrim"),
        )

        val executingBranch = blockAfter(overlaySource, "EXECUTING_IMPORT -> PlaybackScrim")
        assertTrue("取不到执行态分支（守卫自身失效）", executingBranch.isNotEmpty())
        assertTrue(
            "执行态必须把取消回调传给内容（发布版这一态没有出口，审核后补）",
            executingBranch.contains("ExecutingContent(schoolName, adapterName, onCancel)"),
        )
        val executing = blockAfter(overlaySource, "private fun ExecutingContent(")
        assertTrue("取不到 ExecutingContent（守卫自身失效）", executing.isNotEmpty())
        assertTrue(
            "执行态卡片必须有「取消导入」按钮",
            executing.contains("Button(onClick = onCancel") &&
                executing.contains("quickImportCancelImportAction"),
        )
    }

    // -----------------------------------------------------------------------
    // 工具
    // -----------------------------------------------------------------------

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(10) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }

    /** 取 `marker` 之后**第一对配平的 `{}`**（含两端）；marker 自身带 `{` 时从它开始配平。 */
    private fun blockAfter(source: String, marker: String): String {
        val markerAt = source.indexOf(marker)
        if (markerAt < 0) return ""
        val begin = source.indexOf('{', markerAt)
        if (begin < 0) return ""
        var depth = 0
        var i = begin
        while (i < source.length) {
            when (source[i]) {
                '{' -> depth++
                '}' -> {
                    depth--
                    if (depth == 0) return source.substring(begin, i + 1)
                }
            }
            i++
        }
        return source.substring(begin)
    }
}
