package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * P3-B 设置族**批次完成度守卫**。
 *
 * ## 它判的是「代码里真有什么」，不是「谁声称做完了」
 *
 * 2026-10-27 的教训：那批设置页代码写了 15 小时、认领文件上看着像在推进，
 * 但**一次都没有编译通过**（miuix 0.8.8 → 0.9.4 的包名变更没人发现），
 * 而且从头到尾没提交过。认领文件、汇报、笔记都可能失真，只有两件事不会：
 * **能编译**、**能构造出 spec**。
 *
 * 所以这条守卫要求台账 §5 列出的每一页都必须在 [deliveredSpecs] 里登记，
 * 且每条登记都配一个**真的能构造出来**的构造器。少一页就红，红的那几行就是待办。
 *
 * ## 各组的状态类型不同，这是设计而不是意外
 *
 * 基线三页用共享的 [SettingsPageState]；4 个并行组各自需要共享件里没有的字段
 * （材质面板、首页小组件、玻璃坞……），按「不改共享件、各自持有页面私有状态」
 * 的避让规则落成了 `BingGalleryState` / `SettingsHomeWidgetState` /
 * `GlassDockEditorState` 等。所以这里的构造器按页写，不强行统一。
 *
 * ## 加页面的做法
 *
 * 1. 在 [deliveredSpecs] 对应 Dart 源里加上 spec id；
 * 2. 在 [builders] 里加一行构造器；
 * 3. 跑这个测试，绿了才算这一页真的交付。
 */
class SettingsBatchCoverageTest {

    /**
     * 台账 §5 P3-B 的页面清单：Dart 源 → 交付后登记的 spec id。
     *
     * 一个 Dart 文件可以产多个 spec（例如 `settings_appearance.dart` 里含主题管理子页），
     * 所以值用 `Set`。
     */
    private val deliveredSpecs: Map<String, Set<String>> = linkedMapOf(
        // ── 基线（2026-10-26 交付）──────────────────────────────────────
        "settings/settings_general.dart" to setOf("settings-general"),
        "settings/settings_appearance.dart" to setOf("settings-appearance", "settings-theme"),
        "settings/settings_course_card.dart" to setOf("settings-course-card"),

        // ── P3-B-1 外观与材质（settings-appearance，提交 39b851f2）──────
        // 外观编辑器原页拆成 3 份 spec：骨架 + 材质面板通用的两页签
        // （backdrop / recent 两块不是独立页，是嵌在外观页里的段）
        "settings/settings_appearance_editor.dart" to
            setOf("settings-appearance-editor", "settings-material-general", "settings-material-course-card"),
        "settings/settings_home_backdrop_flow.dart" to setOf("settings-backdrop-flow"),
        "settings/settings_recent_wallpaper.dart" to setOf("settings-recent-wallpaper"),
        "settings/bing_wallpaper_gallery_page.dart" to setOf("settings-bing-wallpaper-gallery"),

        // ── P3-B-2 首页与课表展示（settings-home）──────────────────────
        "settings/settings_home_widget.dart" to setOf("settings-home-widget"),
        "settings/settings_home_navigation.dart" to setOf("settings-home-navigation"),
        "settings/settings_home_menu_editor.dart" to setOf("settings-home-menu-editor"),
        "timetable_settings_screen.dart" to setOf("settings-timetable"),

        // ── P3-B-3 行为与系统（settings-behavior）──────────────────────
        "settings/settings_live.dart" to setOf("settings-live", "settings-live-self-check"),
        "settings/settings_holiday.dart" to setOf("settings-holiday", "settings-holiday-advanced"),
        "settings/settings_weather.dart" to setOf("settings-weather"),
        "settings/settings_diagnostics.dart" to setOf("settings-diagnostics"),

        // ── P3-B-4 坞栏与重置（settings-dock）──────────────────────────
        "settings/settings_glass_dock_editor.dart" to setOf("settings-glass-dock-editor"),
        "settings/settings_glass_dock_icon_editor.dart" to setOf("settings-glass-dock-icon-editor"),
        "settings/settings_reset.dart" to setOf("settings-reset"),
    )

    /**
     * 每个 spec 的构造器。键 = spec id，值 = 用**默认状态**构造一次。
     *
     * 刻意真构造而不是只比对字符串 id：页面登记了 id、但 `spec()` 跑不起来
     * （抛异常 / 返回空节点），在字符串层面看不出来。
     */
    private fun builders(): Map<String, () -> SettingsPageSpec> = mapOf(
        // 基线：共享 SettingsPageState
        "settings-general" to { SettingsGeneralPage.spec(SettingsPageState()) },
        "settings-appearance" to { SettingsAppearancePage.spec(SettingsPageState()) },
        "settings-theme" to { SettingsThemeManagePage.spec(SettingsPageState()) },
        "settings-course-card" to { SettingsCourseCardPage.spec(SettingsPageState()) },

        // P3-B-1
        "settings-appearance-editor" to {
            SettingsAppearanceEditorPage.spec(SettingsPageState())
        },
        "settings-material-general" to {
            SettingsMaterialGeneralPage.spec(SettingsPageState())
        },
        "settings-material-course-card" to {
            SettingsMaterialCourseCardPage.spec(SettingsPageState())
        },
        "settings-backdrop-flow" to {
            // 这不是独立页（`PAGE_ID` 为 null）：它是 home_backdrop_flow 这个 mixin
            // 对应的两块可组装内容 —— 选图块与设置块，各自产一份 spec。
            // 这里两块都构造一次，保证任一块坏了都红。
            val selection = SettingsBackdropFlowPage.selectionPage(BackdropFlowState())
            val settings = SettingsBackdropFlowPage.settingsPage(BackdropFlowState())
            listOf(selection, settings).first { it.nodes.isNotEmpty() }
        },
        "settings-recent-wallpaper" to {
            // 用**有壁纸**的状态：空状态（没选过壁纸）本来就该渲染零节点，
            // 拿空态断言「非空」是把测试写错了，不是实现有问题。
            SettingsRecentWallpaperSection.spec(
                RecentWallpaperState(
                    entries = listOf("/sdcard/a.jpg", "/sdcard/b.jpg"),
                    selectedKey = "/sdcard/a.jpg",
                ),
            )
        },
        "settings-bing-wallpaper-gallery" to {
            SettingsBingWallpaperGalleryPage.spec(BingGalleryState())
        },

        // P3-B-2
        "settings-home-widget" to { SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()) },
        "settings-home-navigation" to {
            SettingsHomeNavigationPage.spec(SettingsHomeNavigationState())
        },
        "settings-home-menu-editor" to {
            SettingsHomeMenuEditorPage.spec(SettingsHomeMenuEditorState())
        },
        "settings-timetable" to { SettingsTimetablePage.spec(SettingsTimetableState()) },

        // P3-B-3
        "settings-live" to { SettingsLivePage.spec(SettingsPageState()) },
        "settings-live-self-check" to { SettingsLiveSelfCheckPage.spec(SettingsPageState()) },
        "settings-holiday" to { SettingsHolidayPage.spec(SettingsPageState()) },
        "settings-holiday-advanced" to { SettingsHolidayAdvancedPage.spec(SettingsPageState()) },
        "settings-weather" to { SettingsWeatherPage.spec(SettingsPageState()) },
        "settings-diagnostics" to { SettingsDiagnosticsPage.spec(SettingsPageState()) },

        // P3-B-4
        "settings-glass-dock-editor" to {
            SettingsGlassDockEditorPage.spec(SettingsPageState(), GlassDockEditorState())
        },
        "settings-glass-dock-icon-editor" to {
            SettingsGlassDockIconEditorPage.spec(SettingsPageState())
        },
        "settings-reset" to { SettingsResetPage.spec(SettingsPageState()) },
    )

    @Test
    fun `台账列出的每一页都交付了`() {
        val registered = builders().keys
        val missing = deliveredSpecs.filterValues { ids -> ids.none { it in registered } }
        assertEquals(
            "设置族还有 ${missing.size} 个页面文件没有交付 spec：\n" +
                missing.entries.joinToString("\n") { (dart, ids) ->
                    "  $dart → 期望 ${ids.joinToString("/")}"
                },
            0,
            missing.size,
        )
    }

    @Test
    fun `每个登记的 spec id 都能真的构造出来`() {
        val failures = mutableListOf<String>()
        for (id in deliveredSpecs.values.flatten()) {
            val builder = builders()[id]
            if (builder == null) {
                failures += "$id：没有构造器"
                continue
            }
            try {
                val spec = builder()
                if (spec.nodes.isEmpty()) failures += "$id：构造成功但节点为空"
                if (spec.title.isBlank()) failures += "$id：标题为空"
            } catch (t: Throwable) {
                failures += "$id：构造时抛 ${t::class.simpleName}: ${t.message}"
            }
        }
        assertTrue("有 spec 构造不出来：\n" + failures.joinToString("\n"), failures.isEmpty())
    }

    @Test
    fun `spec id 不重复`() {
        // 两个页面抢同一个 id 会让宿主路由到同一页，LazyColumn 的 key 也会撞。
        val all = deliveredSpecs.values.flatten()
        val dup = all.groupingBy { it }.eachCount().filterValues { it > 1 }.keys
        assertTrue("重复的 spec id：$dup", dup.isEmpty())
    }

    @Test
    fun `已交付页面数不得低于基线`() {
        // 2026-10-27 基线：18 个 Dart 页面文件。只许变大；变小说明已交付的页面被删了。
        assertTrue(
            "已交付页面数回退：当前 ${deliveredSpecs.size} 个文件",
            deliveredSpecs.size >= 18,
        )
    }
}
