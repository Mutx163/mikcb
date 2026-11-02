package com.mutx163.qingyu.pages.transfer

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 取件码页「交互不许在最后一跳丢掉」守卫（2026-11-02 建立）。
 *
 * ## 它防的是哪一类事故
 *
 * 2026-10-29 的 F03 把 `g3.pickupCodes` 从空回调换成了 `PickupCodesHost`，台账记「已接真宿主」。
 * 但渲染层 `EntryRow` 收了 `onClick` 参数**却从未使用**，行上也没有任何 clickable：
 * 七条入口点了没反应，而模型层 20 例单测全绿——它们测的是数据与回退顺序，
 * 看不到 Compose 里的点击接线。
 *
 * 现有测试设施（JUnit + compose runtime，无 compose-ui-test / Robolectric）跑不了
 * 「点一下」这个动作，所以这里沿用仓库已有的源码文本守卫做法
 * （`ComposePageStyleGuardTest` / `DiagnosticsWiringGuardTest` 同一套路）：
 * 只钉「必须出现的接线」与「不许回退的旧写法」。
 *
 * **代价写清**：文本判据对格式敏感。真把 `ArrowPreference` 换成别的官方可点组件时，
 * 这条会先红——那是**故意的**，提醒改接线的人同时更新判据，而不是静默失效。
 */
class PickupCodesPageGuardTest {

    private val pageSource: String by lazy { readAndroidSource(PAGE_PATH) }
    private val hostSource: String by lazy { readAndroidSource(HOST_PATH) }

    @Test
    fun `入口行必须用官方可点组件并把回调接上`() {
        assertTrue(
            "取件码入口行没走官方 ArrowPreference：手搓 Row 会重新丢掉点击/按压/箭头",
            pageSource.contains("ArrowPreference("),
        )
        assertTrue(
            "ArrowPreference 没有把 onTap 接到 onClick —— 整页会点了没反应",
            Regex("onClick\\s*=\\s*if\\s*\\(\\s*interactive\\s*\\)\\s*activate\\s*else\\s*null")
                .containsMatchIn(pageSource),
        )
        assertFalse(
            "页面又出现了裸 Row 拼行（`EntryRow` 的开头是 Row(）：点击与语义会再次靠自觉",
            Regex("private fun EntryRow[\\s\\S]{0,400}?\\n\\s*Row\\(").containsMatchIn(pageSource),
        )
    }

    @Test
    fun `忙碌状态真的传到渲染层`() {
        assertTrue("页面没有 busyTitleKey 入参", pageSource.contains("busyTitleKey"))
        assertTrue("忙碌态没有进度圈", pageSource.contains("CircularProgressIndicator("))
        assertTrue("其余行没有做淡化", pageSource.contains("animateFloatAsState("))
        assertTrue(
            "宿主没有把正在跳的入口键传给页面 —— 跳转中屏幕仍然毫无变化",
            Regex("busyTitleKey\\s*=\\s*busyTitleKey").containsMatchIn(hostSource),
        )
    }

    @Test
    fun `无障碍标签与提示胶囊必须接线`() {
        assertTrue(
            "模型层拼好的 semanticsLabel 没有被渲染层使用（读屏听不到分组/未安装）",
            pageSource.contains("semanticsLabel("),
        )
        assertTrue(
            "入口行没有合并成按钮语义",
            pageSource.contains("clearAndSetSemantics") && pageSource.contains("Role.Button"),
        )
        assertTrue(
            "宿主没有使用本族共享的 AppToastCapsule",
            hostSource.contains("AppToastCapsule("),
        )
        assertFalse(
            "宿主又用回系统 Toast（样式/位置与全站不一致，还会盖在目标 App 上）",
            hostSource.contains("Toast.makeText"),
        )
    }

    private fun readAndroidSource(relative: String): String {
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir.parentFile
        }
        // 找不到就失败，不静默跳过——跳过等于守卫不存在。
        throw AssertionError("找不到 $relative —— 守卫无法验证，按失败处理")
    }

    private companion object {
        const val PAGE_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/PickupCodesPage.kt"
        const val HOST_PATH =
            "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/PickupCodesHost.kt"
    }
}
