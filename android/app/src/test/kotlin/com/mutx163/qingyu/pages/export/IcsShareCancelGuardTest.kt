package com.mutx163.qingyu.pages.export

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 「取消分享要有收尾提示」这条接线的守卫（2026-11-05，发布版对照 A 类第 4 条）。
 *
 * ## 防的是哪类回退
 *
 * 发布版在系统分享面板被划掉时弹「已取消分享日历」
 * （`v2.1.4.1:lib/screens/ics_export_screen.dart:805-811`）。之前 Compose 侧的分享是
 * `context.startActivity(chooser)`：**拿不到任何结果**，划掉之后一句提示都没有。
 *
 * ## 判据为什么不是 launcher 的 resultCode
 *
 * 发布版用的 `share_plus` 自己也**不看** `resultCode` / `data`：`ShareSuccessManager`
 * 的 `onActivityResult` 注释原文是 "Called regardless of success or dismissal"，
 * 它只认 `Intent.createChooser(intent, title, sender)` 那条广播回执里的
 * `EXTRA_CHOSEN_COMPONENT`。Android 选择器普遍恒回 `RESULT_CANCELED`，拿 resultCode 当判据
 * 会把「分享成功」也说成取消。所以这里守的也是同一套机制。
 *
 * 判据分两层：
 * - 纯逻辑「回执 + 通道 → 语义」（[IcsShareLogic.closeOutcome]）：由 [IcsShareLogicTest] 直接断言；
 * - 「语义 → 界面提示」与回执管道：在 `composeP1` / `platform` 里，L0 编不进来，只能读源码文本。
 *
 * 断言都锚在**代码行**上（`^[ \t]*…$`），注释里出现同样的字不会让探针假绿。
 */
class IcsShareCancelGuardTest {

    private val hostPath =
        "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/IcsExportHost.kt"
    private val adapterPath =
        "android/app/src/main/kotlin/com/mutx163/qingyu/platform/AndroidShareAdapter.kt"
    private val receiverPath =
        "android/app/src/main/kotlin/com/mutx163/qingyu/platform/IcsShareResultReceiver.kt"

    @Test
    fun `分享面板关闭后必须由回执判结局`() {
        val host = readSource(hostPath)
        val block = slice(host, "val shareLauncher = rememberLauncherForActivityResult(", "val runShare:")
        assertTrue("shareLauncher 块的解析范围过短（守卫可能坏了）", block.length > 300)
        assertTrue(
            "分享没有走 launcher 等「面板关闭」（找不到 `ActivityResultContracts.StartActivityForResult()`）：" +
                "`startActivity(chooser)` 那条旧路永远等不到面板关闭，取消提示无从触发。",
            LAUNCHER_CONTRACT.find(block) != null,
        )
        assertTrue(
            "launcher 回调没有读广播回执（找不到 `chosenComponent = IcsShareResultReceiver.take()`）。",
            RELAY_READ.find(block) != null,
        )
        assertTrue(
            "launcher 回调没有把「通道是否可用」一起送进判据（`relayAvailable = shareRelayAvailable`）：" +
                "通道不可用时会把「没回执」误判成取消。",
            RELAY_AVAILABLE.find(block) != null,
        )
        assertTrue(
            "判定没有走纯逻辑 `IcsShareLogic.closeOutcome`（判据被写死在宿主里就没有单测钉得住）。",
            CLOSE_OUTCOME.find(block) != null,
        )
    }

    @Test
    fun `取消必须有自己的提示而不是并进失败`() {
        val host = readSource(hostPath)
        val block = slice(host, "val shareLauncher = rememberLauncherForActivityResult(", "val runShare:")
        assertTrue(
            "launcher 回调里没有 `IcsShareOutcome.Cancelled ->` 分支：取消会落进 Failed，" +
                "用户看到「导出失败」而不是「已取消分享日历」。",
            CANCELLED_BRANCH.find(block) != null,
        )
        assertTrue(
            "取消分支没有用现成文案 `ExportStrings.icsExportCancelled`（ARB 键 `icsExportCancelled`，" +
                "发布版就是这一句）。",
            "ExportStrings.icsExportCancelled.text" in block,
        )
        assertTrue(
            "取消分支后面必须还有成功 / 说不清 / 失败三条分支，否则几态又会被合并。",
            SHARED_BRANCH.find(block) != null &&
                UNCONFIRMED_BRANCH.find(block) != null &&
                FAILED_BRANCH.find(block) != null,
        )
    }

    @Test
    fun `适配器把 CANCELLED 映射成 Cancelled，不许映射成 Failed`() {
        val adapter = readSource(adapterPath)
        assertTrue(
            "`IcsShareOutcome` 没有 `Cancelled` 结局：取消无从表达。",
            CANCELLED_OUTCOME.find(adapter) != null,
        )
        assertTrue(
            "`outcomeForClose` 没有把 CANCELLED 映射成 `IcsShareOutcome.Cancelled`。",
            CANCELLED_MAPPING.find(adapter) != null,
        )
        assertTrue(
            "CANCELLED 被映射成了 Failed：等于把「用户主动取消」报成「导出失败」。",
            CANCELLED_AS_FAILED.find(adapter) == null,
        )
        assertTrue(
            "INDETERMINATE（通道不可用）必须映射成 `Unconfirmed` 而不是 Failed：宿主对它保持沉默，不谎报。",
            UNCONFIRMED_MAPPING.find(adapter) != null,
        )
    }

    @Test
    fun `回执管道必须是广播 sender 加可用性检查`() {
        val adapter = readSource(adapterPath)
        assertTrue(
            "回执 sender 不是发给 `IcsShareResultReceiver` 的广播（找不到 `Intent(context, IcsShareResultReceiver::class.java)`）：" +
                "没有它，系统不会把用户选定的目标投回来。",
            SENDER_TARGET.find(adapter) != null,
        )
        assertTrue(
            "PendingIntent 没带 `FLAG_MUTABLE`：API 31+ 上框架无法把 `EXTRA_CHOSEN_COMPONENT` 填进去。",
            SENDER_MUTABLE.find(adapter) != null,
        )
        assertTrue(
            "准备阶段没有把「通道是否可用」传给宿主（`resultRelayAvailable = IcsShareResultReceiver.isDeclared(context)`）：" +
                "manifest 少声明时宿主会误报取消。",
            RELAY_DECLARED.find(adapter) != null,
        )
        val receiver = readSource(receiverPath)
        assertTrue(
            "回执接收器没有读 `EXTRA_CHOSEN_COMPONENT`：拿到回执也判不出选了谁。",
            "Intent.EXTRA_CHOSEN_COMPONENT" in receiver,
        )
        assertTrue(
            "回执接收器没有 `isDeclared(context)` 这条可用性判据：宿主就没法安全降级。",
            DECLARED_CHECK.find(receiver) != null,
        )
    }

    @Test
    fun `旧的同步 share 入口不许回来`() {
        // `adapter.share(...)` 是「送了 Intent 就算完」的旧写法：它没法知道用户选没选目标，
        // 一旦被谁接回宿主，取消提示就整条失效。
        val host = readSource(hostPath)
        assertTrue(
            "宿主又用回了同步的 `shareAdapter.share(...)`：这条路径拿不到面板结果，取消会重新变静默。",
            "shareAdapter.share(" !in host,
        )
    }

    @Test
    fun `manifest 必须声明回执接收器且不外暴`() {
        val manifest = readSource("android/app/src/main/AndroidManifest.xml")
        val nameIndex = manifest.indexOf(RECEIVER_NAME_ATTR)
        assertTrue(
            "AndroidManifest.xml 没有声明 `$RECEIVER_TARGET`：系统无处投递 EXTRA_CHOSEN_COMPONENT，" +
                "「已取消分享日历」永远是哑的（适配器判「通道不可用」→ 宿主静默降级，" +
                "用户划掉面板不会得到任何反馈）。",
            nameIndex >= 0,
        )
        val tagStart = manifest.lastIndexOf(RECEIVER_TAG, nameIndex)
        val tagEnd = manifest.indexOf("/>", nameIndex)
            .takeIf { it >= 0 }
            ?: manifest.indexOf("</receiver>", nameIndex)
        assertTrue(
            "接收器声明解析失败（守卫可能坏了：找不到 `<receiver` 起点或标签结尾）",
            tagStart >= 0 && tagEnd > nameIndex,
        )
        val declaration = manifest.substring(tagStart, tagEnd + 2)
        assertTrue(
            "声明里必须写 `android:exported=\"false\"`：这是只给自己应用送结果的回执通道，" +
                "没有理由把广播接收器对外暴露。实际声明：" +
                declaration.replace("\n", " ").replace(Regex("\\s+"), " ").trim(),
            "android:exported=\"false\"" in declaration,
        )
    }

    // ---------------------------------------------------------------- 解析

    private fun slice(source: String, from: String, to: String): String {
        val start = source.indexOf(from)
        assertTrue("源码里找不到起点 `$from`", start >= 0)
        val end = source.indexOf(to, start)
        assertTrue("源码里找不到终点 `$to`（在 `$from` 之后）", end > start)
        return source.substring(start, end)
    }

    /**
     * 从工作目录向上找仓库根再定位文件：L0 脚本与 Gradle 的工作目录不同，
     * 按「向上找标志文件」而不是写死相对路径；**找不到仍判失败**。
     */
    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private companion object {
        /**
         * manifest 里的接收器声明。用 `android:name="…"` 这一整段（而不是裸类名）定位，
         * 免得注释里提到类名就让守卫假绿。
         */
        const val RECEIVER_TARGET = ".platform.IcsShareResultReceiver"
        const val RECEIVER_NAME_ATTR = "android:name=\".platform.IcsShareResultReceiver\""
        const val RECEIVER_TAG = "<receiver"

        val LAUNCHER_CONTRACT = Regex(
            """^[ \t]*ActivityResultContracts\.StartActivityForResult\(\),[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val RELAY_READ = Regex(
            """^[ \t]*chosenComponent = IcsShareResultReceiver\.take\(\),[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val RELAY_AVAILABLE = Regex(
            """^[ \t]*relayAvailable = shareRelayAvailable,[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val CLOSE_OUTCOME = Regex(
            """^[ \t]*val outcome = shareAdapter\.outcomeForClose\([ \t]*$""",
            RegexOption.MULTILINE,
        )
        val CANCELLED_BRANCH = Regex(
            """^[ \t]*IcsShareOutcome\.Cancelled ->""",
            RegexOption.MULTILINE,
        )
        val SHARED_BRANCH = Regex(
            """^[ \t]*IcsShareOutcome\.Shared ->""",
            RegexOption.MULTILINE,
        )
        val UNCONFIRMED_BRANCH = Regex(
            """^[ \t]*IcsShareOutcome\.Unconfirmed ->""",
            RegexOption.MULTILINE,
        )
        val FAILED_BRANCH = Regex(
            """^[ \t]*is IcsShareOutcome\.Failed ->""",
            RegexOption.MULTILINE,
        )
        val CANCELLED_OUTCOME = Regex(
            """^[ \t]*data object Cancelled : IcsShareOutcome[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val CANCELLED_MAPPING = Regex(
            """^[ \t]*IcsShareLaunchSignal\.CANCELLED -> IcsShareOutcome\.Cancelled[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val CANCELLED_AS_FAILED = Regex(
            """^[ \t]*IcsShareLaunchSignal\.CANCELLED -> IcsShareOutcome\.Failed""",
            RegexOption.MULTILINE,
        )
        val UNCONFIRMED_MAPPING = Regex(
            """^[ \t]*IcsShareLaunchSignal\.INDETERMINATE -> IcsShareOutcome\.Unconfirmed[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val SENDER_TARGET = Regex(
            """^[ \t]*Intent\(context, IcsShareResultReceiver::class\.java\),[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val SENDER_MUTABLE = Regex(
            """^[ \t]*PendingIntent\.FLAG_UPDATE_CURRENT or PendingIntent\.FLAG_MUTABLE,[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val RELAY_DECLARED = Regex(
            """^[ \t]*resultRelayAvailable = IcsShareResultReceiver\.isDeclared\(context\),[ \t]*$""",
            RegexOption.MULTILINE,
        )
        val DECLARED_CHECK = Regex(
            """^[ \t]*fun isDeclared\(context: Context\): Boolean""",
            RegexOption.MULTILINE,
        )
    }
}
