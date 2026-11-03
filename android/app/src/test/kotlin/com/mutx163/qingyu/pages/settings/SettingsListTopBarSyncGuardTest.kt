package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 设置列表「顶栏折叠联动按顶栏形态分流」的判据与守卫（2026-11-03 用户实报「下面的设置区
 * 滚不动」）。
 *
 * ## 根因（为什么要这条守卫）
 *
 * `QingyuPageScaffold` 每页都建 `MiuixScrollBehavior()`。小顶栏页
 * （`collapsibleLargeTitle = false`：课程卡片 / 课表页面两页）里 `SmallTopAppBar`
 * **不接**这个 behavior，`heightOffsetLimit` 停在 `rememberTopAppBarState` 的默认值
 * `-Float.MAX_VALUE`（miuix `TopAppBar.kt:276`）⇒ 连接器的 `onPreScroll` 对任何向上
 * 滚动都产生有效差值并整个吞掉，「幻影折叠」永不结束，列表一格都滚不动。
 *
 * 读源码文本的判据**先剥注释**；找不到文件判失败而不是跳过。
 */
class SettingsListTopBarSyncGuardTest {

    // ── 判据（settingsListAttachesTopBarSync）───────────────────────────

    @Test
    fun `小顶栏页不挂折叠连接器否则幻影折叠吞掉全部滚动`() {
        // 课程卡片 / 课表页面两页 collapsibleLargeTitle = false：挂了必坏（用户实报）。
        assertFalse(settingsListAttachesTopBarSync(collapsibleLargeTitle = false))
    }

    @Test
    fun `大顶栏页照常挂折叠联动`() {
        assertTrue(settingsListAttachesTopBarSync(collapsibleLargeTitle = true))
    }

    // ── 源码守卫 ────────────────────────────────────────────────────────

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
            "找不到 android/app/src —— 守卫无法验证，按失败处理。当前工作目录：" +
                System.getProperty("user.dir"),
        )
    }

    /** 去掉块注释与行注释再判（KDoc 里摆的说明不能算违规）。 */
    private fun codeOf(source: String): String = source
        .replace(Regex("""/\*[\s\S]*?\*/"""), "")
        .replace(Regex("""//[^\n]*"""), "")

    @Test
    fun `设置列表按顶栏形态挂折叠联动不许裸传scrollBehavior`() {
        val file = File(
            androidSrc(),
            "composeP1/kotlin/com/mutx163/qingyu/pages/settings/SettingsPageRenderers.kt",
        )
        assertTrue("SettingsPageRenderers.kt 不存在：${file.path}", file.isFile)
        val code = codeOf(file.readText())
        assertFalse(
            "SettingsPageScreen 里出现了裸传 scrollBehavior：小顶栏页（collapsibleLargeTitle=false）" +
                "挂上连接器会把向上滚动全部吞进幻影折叠，列表滚不动（2026-11-03 用户实报）。" +
                "必须走 settingsListAttachesTopBarSync 分流",
            "scrollBehavior = scrollBehavior," in code,
        )
        assertEquals(
            "两个分支（预览分栏 / 整页列表）都要走同一条分流判据",
            2,
            Regex("settingsListAttachesTopBarSync\\(spec\\.collapsibleLargeTitle\\)")
                .findAll(code)
                .count(),
        )
    }
}
