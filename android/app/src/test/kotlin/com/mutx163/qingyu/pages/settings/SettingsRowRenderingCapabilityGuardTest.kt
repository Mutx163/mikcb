package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 渲染层**四项新能力的接线守卫**（2026-10-29 · 节假日页补齐）。
 *
 * ## 为什么需要它
 *
 * 节假日两页要跟 Flutter 原版长得一模一样，靠的是渲染层的四个新能力：
 *
 * | 能力 | 模型字段 | 原版出处 |
 * |---|---|---|
 * | 整行降到 55% 透明（已过去的节假日） | [SettingsRow.dimmed] | `settings_holiday.dart:613-614` |
 * | 行级长按（长按自定义假期 = 删除确认） | [SettingsRow.longPressAction] | `:568-570` |
 * | 日志条目上下两行 | [SettingsRow.stacked] | `:750-781` |
 * | 固定底栏 + 顶栏动作 | [SettingsPageSpec.footerNode] / [SettingsPageSpec.topBarAction] | `:792-812` / `:466-478` |
 *
 * 模型件是**纯数据**，写了字段不等于渲染层真的用了它——官方 `ArrowPreference` 没有长按、
 * `SettingsPageScreen` 原来也没有底栏槽。如果哪天有人重构渲染层把这几处接线丢了，
 * 编译照样过、L0 照样绿，只有真机上才发现「长按没反应 / 已过去的假期不变淡 / 按钮跟着列表滚走」。
 *
 * ## 两条纪律（与 `SettingsRouteWiringGuardTest` 同口径）
 *
 * 1. 路径从工作目录向上找 `android/app/src`，不写死盘符（CI 也能跑）；
 * 2. 找不到文件**失败而不是跳过**——跳过等于这条守卫不存在。
 *
 * 它读的是 `composeP1` 源集里的渲染层（那一层不能在 JVM 里跑 Compose），所以只能做
 * **源码接线断言**；能做成行为断言的（模型字段是否真的落到 `SettingsRow` 上）在
 * [modelFieldsReachTheRow] 里用构造 + 取值断言，不靠字符串匹配。
 */
class SettingsRowRenderingCapabilityGuardTest {

    private fun androidSrc(): File {
        var dir: File? = File(System.getProperty("user.dir")).absoluteFile
        while (dir != null) {
            val candidate = File(dir, "android/app/src")
            if (candidate.isDirectory) return candidate
            val direct = File(dir, "app/src")
            if (direct.isDirectory && File(dir, "app/build.gradle").isFile) return direct
            dir = dir.parentFile
        }
        throw AssertionError(
            "找不到 android/app/src —— 守卫无法验证，按失败处理（不许静默跳过）。" +
                "当前工作目录：${System.getProperty("user.dir")}",
        )
    }

    private fun renderersSource(): String {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )
        assertTrue("渲染层源码不存在：${file.path}", file.isFile)
        return file.readText()
    }

    // ------------------------------------------------------------ 行为断言（模型）

    @Test
    fun modelFieldsReachTheRow() {
        val row = settingsRow(
            id = "holiday.custom.custom-1",
            component = MiuixRowComponent.ARROW,
            title = ArbText("customHolidayTitle", "自定义假期"),
            action = SettingsAction.SHEET,
            longPressAction = SettingsAction.DIALOG,
            stacked = true,
            dimmed = true,
        )
        assertEquals("点按弹编辑层", SettingsAction.SHEET, row.action)
        assertEquals("长按弹删除确认（DIALOG 是界面意图，不是 OverlayDialog 的字面语义）",
            SettingsAction.DIALOG, row.longPressAction)
        assertTrue("日志类条目走上下两行", row.stacked)
        assertTrue("已过去的节假日整行变淡", row.dimmed)
        // 默认值必须是「不变」：这两件是新能力，老页面一个都不能被顺手改了行为。
        val plain = settingsRow(
            id = "general.haptics",
            component = MiuixRowComponent.SWITCH,
            title = ArbText("generalHapticsTitle", "触感反馈"),
        )
        assertEquals(false, plain.dimmed)
        assertEquals(null, plain.longPressAction)
        assertEquals(false, plain.stacked)
    }

    @Test
    fun specCarriesFooterAndTopAction() {
        val spec = SettingsPageSpec(
            id = "settings-holiday",
            titleKey = "holidaySettingsTitle",
            title = "节假日标记",
            nodes = emptyList(),
            footerNode = SettingsInline(
                id = "holidayAdvanced.card.refresh",
                kind = InlineKind.CONTROL_CARD,
                note = "固定底栏",
            ),
            topBarAction = SettingsTopAction(
                route = "/settings/holiday/advanced",
                semanticsLabel = "节假日数据更新",
            ),
        )
        assertNotNull("固定底栏节点必须挂在 spec 上，不许塞回 nodes", spec.footerNode)
        assertEquals(
            "顶栏动作的路由要能被壳的 shellPageIdForRoute 认出来",
            "/settings/holiday/advanced",
            spec.topBarAction?.route,
        )
        assertTrue("底栏节点不能又在 nodes 里（否则会被渲染两次）", spec.nodes.isEmpty())
    }

    // ------------------------------------------------------------ 源码接线断言

    @Test
    fun renderersDimRowsWithAlpha() {
        val src = renderersSource()
        assertTrue(
            "渲染层缺少 dim 能力：没有 ROW_DIMMED_ALPHA 常量",
            src.contains("ROW_DIMMED_ALPHA"),
        )
        assertTrue(
            "渲染层缺少 dim 接线：node.dimmed → Modifier.alpha(ROW_DIMMED_ALPHA)",
            src.contains("Modifier.alpha(ROW_DIMMED_ALPHA)"),
        )
        assertTrue(
            "55% 是原版写死的值（settings_holiday.dart:613-614），不许改",
            src.contains("ROW_DIMMED_ALPHA = 0.55f"),
        )
    }

    @Test
    fun renderersWireLongPress() {
        val src = renderersSource()
        assertTrue(
            "渲染层缺少长按接线：row.longPressAction 没有被读",
            src.contains("row.longPressAction"),
        )
        assertTrue(
            "长按必须用 combinedClickable（官方 ArrowPreference 没有长按回调）",
            src.contains("combinedClickable"),
        )
        assertTrue(
            "长按要转成 onAction，不能直接在渲染层删数据",
            src.contains("onLongClick = { onAction(longPress, row.longPressTarget, row.id) }"),
        )
    }

    @Test
    fun renderersRenderStackedRows() {
        val src = renderersSource()
        assertTrue(
            "渲染层缺少 stacked 行：日志条目会退化成「左标题 + 右结尾」一行横排",
            src.contains("row.stacked -> StackedRow(row = row)"),
        )
    }

    @Test
    fun renderersRespectInlineBusy() {
        val src = renderersSource()
        assertTrue(
            "控制卡按钮没有读 SettingsInline.busy —— 刷新期间按钮仍可连点（Dart :807 是 `onPressed: _refreshing ? null : …`）",
            src.contains("!node.busy"),
        )
    }

    @Test
    fun renderersPinFooterAndTopAction() {
        val src = renderersSource()
        assertTrue(
            "固定底栏没有接到 QingyuPageScaffold 的 bottomBar 槽",
            src.contains("bottomBar = footerSlot"),
        )
        assertTrue(
            "顶栏动作没有接到 QingyuPageScaffold 的 actions 槽",
            src.contains("topBarAction"),
        )
        assertTrue(
            "顶栏动作要转成一次 NAVIGATE（宿主按 rowId=TOP_ACTION_ROW_ID 分流）",
            src.contains("onAction(SettingsAction.NAVIGATE, topAction.route, TOP_ACTION_ROW_ID)"),
        )
    }
}
