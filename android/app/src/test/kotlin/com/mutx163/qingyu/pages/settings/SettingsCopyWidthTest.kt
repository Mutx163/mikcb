package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 行控件单行口径（AGENTS.md 文案纪律：标题 ≤11、说明 ≤17，按渲染宽度量）。
 *
 * 口径的**唯一定义处**是 `AGENTS.md`「界面文案风格」段（标题 ≤11、说明 ≤17 + 渲染宽度算法）；
 * 这里用 [CopyWidthMirror] 做同一套度量，把「Kotlin 侧设置行有没有超宽」也钉住
 * ——原 Dart 守卫（`tool/copy_style_rules.dart`，已随 P4-C 删除）只扫 ARB 文案，扫不到「同一段文案被放进更窄的槽位」这类接线错误。
 *
 * 不适用本口径的（本测试不检查，与原 Dart 守卫一致；该守卫已删）：分组小标题
 * （`HyperosSectionLabel`）、整宽段说明（`HyperosSectionDescription`）、
 * 对话框正文、行尾取值（`details`/`value`）。
 */
class SettingsCopyWidthTest {

    private fun allSpecs(): List<SettingsPageSpec> = listOf(
        SettingsGeneralPage.spec(
            SettingsPageState(
                autoRefresh = AutoRefreshState(
                    enabled = true,
                    mode = CourseAutoRefreshMode.DAILY_AT,
                    lastSuccessLabel = "9-21 07:30",
                    nextRunLabel = "9-22 07:30",
                ),
            ),
        ),
        SettingsAppearancePage.spec(SettingsPageState()),
        SettingsThemeManagePage.spec(
            SettingsPageState(
                themeCheckpointName = "小米",
                themeHasModifications = true,
                savedThemes = listOf(SavedThemeRow(id = "t1", name = "冬季配色", selected = true)),
            ),
        ),
        SettingsCourseCardPage.spec(SettingsPageState(timetableUseUnifiedCardColor = true)),
        // 补口页（2026-10-28）：用「支持截屏提示」的状态，把条件行也纳入宽度检查
        SettingsTimetablePageSettingsPage.spec(
            TimetablePageSettingsState(screenshotShareSupported = true),
        ),
    )

    @Test
    fun `度量镜像与 Dart 口径一致`() {
        // 口径依据：AGENTS.md「界面文案风格」段的渲染宽度算法
        assertEquals(4.0, CopyWidthMirror.of("语言选择"), 1e-9)
        assertEquals(3.85, CopyWidthMirror.of("English"), 1e-9)
        assertEquals(4.2, CopyWidthMirror.of("{name} 副本"), 1e-9)
        assertEquals(0.0, CopyWidthMirror.of(""), 1e-9)
        assertEquals(TITLE_MAX_WIDTH, 11.0, 0.0)
        assertEquals(SUBTITLE_MAX_WIDTH, 17.0, 0.0)
    }

    @Test
    fun `所有行标题不超过十一`() {
        val offenders = allSpecs().flatMap { spec ->
            spec.rows().mapNotNull { row ->
                val w = CopyWidthMirror.of(row.title)
                if (w > TITLE_MAX_WIDTH) "${spec.id}/${row.id} 『${row.title}』宽 ${w}" else null
            }
        }
        assertEquals("行控件标题超过 11 会真的折行：$offenders", emptyList<String>(), offenders)
    }

    @Test
    fun `所有行说明不超过十七`() {
        val offenders = allSpecs().flatMap { spec ->
            spec.rows().mapNotNull { row ->
                val subtitle = row.subtitle ?: return@mapNotNull null
                val w = CopyWidthMirror.of(subtitle)
                if (w > SUBTITLE_MAX_WIDTH) "${spec.id}/${row.id} 『$subtitle』宽 $w" else null
            }
        }
        assertEquals("行控件说明超过 17 会真的折行：$offenders", emptyList<String>(), offenders)
    }

    @Test
    fun `行标题与说明都不为空`() {
        allSpecs().forEach { spec ->
            spec.rows().forEach { row ->
                assertTrue("${spec.id}/${row.id} 标题为空", row.title.isNotBlank())
                row.subtitle?.let { assertTrue("${spec.id}/${row.id} 说明为空串", it.isNotBlank()) }
            }
        }
    }

    @Test
    fun `覆盖到的行控件数量不为零`() {
        // 防空转：spec 若变空，上面三条会「零违规=绿」
        val count = allSpecs().sumOf { it.rows().size }
        assertTrue("设置族三页行控件共 $count 行，低于预期", count >= 40)
    }
}
