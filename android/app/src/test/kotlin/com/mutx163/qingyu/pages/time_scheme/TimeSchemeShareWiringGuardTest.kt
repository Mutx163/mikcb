package com.mutx163.qingyu.pages.time_scheme

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * **时间模板分享接线守卫**（2026-11-10，D22「模板分享」接线）。
 *
 * ## 它防的是哪一类事故
 *
 * 模板页的「分享」菜单项曾被宿主整项剪掉（`menu.filter { it.action != SHARE }`），
 * 弹层本体早就在渲染层写好了、却没有一个入口能打开它；后来接线时又容易退化成
 * 「点了没反应」（把分享分支留成 `-> Unit`）。这类问题**编译通过、单测全绿**，
 * 只有看宿主源码文本才能区分「真接上」与「摆了个假按钮」。
 *
 * ## 它钉住的四件事
 *
 * 1. 菜单不再过滤 SHARE（`TimeSchemeManagementHost` 里不许再出现那条 filter）；
 * 2. 分享弹层**常驻组合**（`TimeSchemeShareSheetDialog(` 出现在宿主里，退场动画才不会丢）；
 * 3. 真打包与真分享：`DataTransferPackageLogic.build(` + `selectedTimeSchemeIds = setOf(schemeId)`
 *    （只带被分享的那一套）+ `AndroidTransferShareAdapter` + `TransferShellBridge.publishOutbound`
 *    （二维码那半复用数据备份页的发送页桥）；
 * 4. 文件头不再是过时的「菜单里不出现该项 / 全仓 FileProvider 仍为 0」。
 *
 * ## 为什么不写行为单测
 *
 * 分享链两端都是 Android 胶水（`FileProvider`、选择器、路由跳转），进不了 JVM 单测
 * classpath；纯逻辑那一半（包内只带点名的模板）已由
 * `pages/transfer/DataTransferPackageTimeSchemeSelectionTest` 断言。同仓先例：
 * `TimeSchemeWiringGuardTest`、`DiagnosticsWiringGuardTest`。
 */
class TimeSchemeShareWiringGuardTest {

    private val hostSource: String by lazy { stripLineComments(readSource(HOST_PATH)) }
    private val dialogsSource: String by lazy { stripLineComments(readSource(DIALOGS_PATH)) }

    @Test
    fun `菜单不再把分享项过滤掉`() {
        assertFalse(
            "TimeSchemeHost.kt 里又出现了 `it.action != TimeSchemeAction.SHARE`：" +
                "分享项被剪掉后，弹层写好了也没有入口能打开",
            hostSource.contains("it.action != TimeSchemeAction.SHARE"),
        )
        assertTrue(
            "分享动作必须真打开分享弹层，不能留成空分支",
            hostSource.contains("TimeSchemeAction.SHARE ->") &&
                hostSource.contains("TimeSchemeDialog.Share("),
        )
    }

    @Test
    fun `分享弹层常驻组合且有系统分享与二维码两条路`() {
        assertTrue(
            "TimeSchemeHost.kt 没有常驻组合 TimeSchemeShareSheetDialog(——" +
                "条件挂载会让官方退场动画一次都播不出来",
            hostSource.contains("TimeSchemeShareSheetDialog("),
        )
        assertTrue(
            "系统分享必须复用 pages/transfer 的拼包器",
            hostSource.contains("DataTransferPackageLogic.build("),
        )
        assertTrue(
            "系统分享必须复用 AndroidTransferShareAdapter（写缓存 → FileProvider → 选择器）",
            hostSource.contains("AndroidTransferShareAdapter("),
        )
        assertTrue(
            "二维码分享必须走现成的发送页桥 TransferShellBridge.publishOutbound",
            hostSource.contains("TransferShellBridge.publishOutbound("),
        )
    }

    @Test
    fun `分享打包只带被点名的这一套模板`() {
        assertTrue(
            "TimeSchemeHost.kt 拼包请求没有传 selectedTimeSchemeIds = setOf(schemeId)：" +
                "那样会把用户所有作息一起发给对方",
            hostSource.contains("selectedTimeSchemeIds = setOf(schemeId)"),
        )
        assertTrue(
            "拼包范围必须是 TIME_TEMPLATE",
            hostSource.contains("scope = TransferScope.TIME_TEMPLATE"),
        )
    }

    @Test
    fun `壳没接二维码路由时不画二维码入口`() {
        assertTrue(
            "宿主必须按 onRequestQrSend 是否有值决定二维码入口是否可用",
            hostSource.contains("qrEnabled = onRequestQrSend != null"),
        )
        assertTrue(
            "分享弹层必须真的按 qrEnabled 分支渲染",
            dialogsSource.contains("if (qrEnabled)"),
        )
    }

    @Test
    fun `文件头不再写分享缺失与 provider 未注册`() {
        assertFalse(
            "TimeSchemeHost.kt 文件头还写着「全仓 FileProvider 仍为 0」——provider 2026-10-29 已注册",
            hostSource.contains("FileProvider` 仍为 0") || hostSource.contains("全仓 `FileProvider` 仍为 0"),
        )
    }

    // ------------------------------------------------------------------ 定位

    /** 去掉行注释：注释里描述「旧实现曾把分享剪掉」不算复发。 */
    private fun stripLineComments(source: String): String =
        source.lineSequence()
            .filterNot { it.trimStart().startsWith("//") }
            .joinToString("\n")

    private fun readSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error(
            "找不到 $relative（工作目录 ${File("").absolutePath}）；" +
                "守卫需要读到源文件才能判接线是否还在",
        )
    }

    private companion object {
        const val HOST_PATH = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/TimeSchemeHost.kt"
        const val DIALOGS_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/time_scheme/TimeSchemeManagementDialogs.kt"
    }
}
