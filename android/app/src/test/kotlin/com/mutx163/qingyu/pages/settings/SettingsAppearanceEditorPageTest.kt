package com.mutx163.qingyu.pages.settings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 外观编辑页（`lib/screens/settings/settings_appearance_editor.dart`）结构测试。
 *
 * 这一页在 Flutter 侧是**沉浸式整页 + 两个底部面板**，落到设置族模型后拆成四份：
 * - [SettingsAppearanceEditorPage]：页面骨架（预览占位 + 底部两个入口）+ 顶部胶囊；
 * - [SettingsMaterialGeneralPage]：材质面板第一页「通用」（:921-1195）；
 * - [SettingsMaterialCourseCardPage]：材质面板第二页「课程卡片」（:1197-1317）；
 * - [SettingsMaterialSheetPage] / [SettingsWallpaperSheetPage]：两个面板的页签表。
 *
 * 期望值来源：Dart 源的行顺序 / 控件类型 / 上下限 / 条件分支 + ARB 文案。
 */
class SettingsAppearanceEditorPageTest {

    private fun page(material: MaterialPanelState = MaterialPanelState()) =
        SettingsAppearanceEditorPage.spec(SettingsPageState(), material)

    private fun general(material: MaterialPanelState = MaterialPanelState()) =
        SettingsMaterialGeneralPage.spec(SettingsPageState(), material)

    private fun courseCard(
        state: SettingsPageState = SettingsPageState(),
        material: MaterialPanelState = MaterialPanelState(),
    ) = SettingsMaterialCourseCardPage.spec(state, material)

    // ---------------------------------------------------------- 页面骨架

    @Test
    fun `页面标题与 id`() {
        val spec = page()
        assertEquals("settings-appearance-editor", spec.id)
        // 顶栏那行标题被撤掉了（:1895-1898），但 spec 仍需一个标题
        assertEquals("appearanceEditorTitle", spec.titleKey)
        assertEquals("外观编辑", spec.title)
    }

    @Test
    fun `预览卡在最上方且没有标题字`() {
        // :116-193 / :1616-1720：那一整块是「把真首页等比缩进去」，屏上没有任何标题
        val spec = page()
        assertEquals("appearanceEditor.preview", spec.topLevelIds().first())
        val preview = spec.flatten().filterIsInstance<SettingsInline>().single()
        assertEquals(InlineKind.PREVIEW_CARD, preview.kind)
        // Flutter 侧这一块没有标题文案，所以不给 labelKey（空键 = 不来自 ARB）
        assertNull("预览卡不该有 ARB 标题", preview.labelKey)
    }

    @Test
    fun `整页不折行大标题且有预览区权重`() {
        // :1581-1720 是 Positioned 叠层，整页不滚动
        val spec = page()
        assertFalse(spec.collapsibleLargeTitle)
        assertEquals(4, spec.previewFlex)
        assertEquals(6, spec.contentFlex)
    }

    @Test
    fun `底部两个入口：调整壁纸与材质`() {
        // :2011-2049
        val spec = page()
        assertEquals(
            listOf("appearanceEditor.wallpaper", "appearanceEditor.material"),
            spec.group("appearanceEditor.actions").childRowIds(),
        )
        assertEquals("调整壁纸", spec.row("appearanceEditor.wallpaper").title)
        assertEquals("材质", spec.row("appearanceEditor.material").title)
        assertEquals(SettingsAction.SHEET, spec.row("appearanceEditor.wallpaper").action)
        assertEquals(SettingsAction.SHEET, spec.row("appearanceEditor.material").action)
    }

    @Test
    fun `顶部取消与完成两枚胶囊`() {
        // :1899-1918
        val chrome = SettingsAppearanceEditorPage.chromeRows(SettingsPageState())
        assertEquals(listOf("取消", "完成"), chrome.map { it.title })
        assertEquals(
            listOf(
                SettingsAppearanceEditorPage.CANCEL_TARGET,
                SettingsAppearanceEditorPage.DONE_TARGET,
            ),
            chrome.map { it.actionTarget },
        )
        // 顶栏是浮层，不能混进设置列表
        val specIds = page().flattenedIds()
        assertFalse(specIds.contains("appearanceEditor.cancel"))
        assertFalse(specIds.contains("appearanceEditor.done"))
    }

    @Test
    fun `日周分段的两项与默认选中`() {
        // :1998-2005；初始值跟首页持久化的视图走（:203-204 + :376-377）
        assertEquals(
            listOf("日课表", "周课表"),
            SettingsAppearanceEditorPage.dayWeekOptions().map { it.label },
        )
        assertEquals(
            listOf("day", "week"),
            SettingsAppearanceEditorPage.dayWeekOptions().map { it.id },
        )
        assertEquals(
            "week",
            SettingsAppearanceEditorPage.dayWeekSelectedId(MaterialPanelState(previewDayView = false)),
        )
        assertEquals(
            "day",
            SettingsAppearanceEditorPage.dayWeekSelectedId(MaterialPanelState(previewDayView = true)),
        )
    }

    @Test
    fun `进页时的加载罩文案`() {
        // :1868 `commonLoadingLabel`
        assertEquals("commonLoadingLabel", SettingsAppearanceEditorPage.LOADING_LABEL.key)
        assertEquals("加载中", SettingsAppearanceEditorPage.LOADING_LABEL.zh)
    }

    // -------------------------------------------------- 材质面板 · 通用页

    @Test
    fun `通用页 id 与标题`() {
        val spec = general()
        assertEquals("settings-material-general", spec.id)
        // 翻页胶囊本身就是标题，用的是「通用」（:2332）
        assertEquals("generalSettingsTitle", spec.titleKey)
        assertEquals("通用", spec.title)
    }

    @Test
    fun `默认材质两档只有实体与液态`() {
        // :974-983：高斯模糊档 2026-09-30 退场，只剩两档
        val row = general().row("material.general.glassMode.row")
        assertEquals("默认材质", row.title)
        assertEquals(listOf("实体卡片", "液态玻璃"), row.options.map { it.label })
        assertEquals(listOf("solid", "liquidGlass"), row.options.map { it.id })
        assertEquals("liquidGlass", row.selectedOptionId)
        assertEquals(
            "solid",
            general(MaterialPanelState(frostedBlurEnabled = false))
                .row("material.general.glassMode.row")
                .selectedOptionId,
        )
    }

    @Test
    fun `实体档才出现那句全 App 模糊已关闭的说明`() {
        // :985-993
        val liquidKeys = general().flatten().filterIsInstance<SettingsDescription>().map { it.textKey }
        assertFalse(
            "液态档不该有实体档说明",
            liquidKeys.contains("frostedGlassModeSolidNotice"),
        )
        val solidKeys = general(MaterialPanelState(frostedBlurEnabled = false))
            .flatten()
            .filterIsInstance<SettingsDescription>()
            .map { it.textKey }
        assertTrue("实体档必须出现说明", solidKeys.contains("frostedGlassModeSolidNotice"))
    }

    @Test
    fun `首页顶栏玻璃三档`() {
        // :1007-1017
        val row = general().row("material.general.homeBand.row")
        assertEquals("首页顶栏玻璃", row.title)
        assertEquals(listOf("跟随默认材质", "实体", "液态玻璃"), row.options.map { it.label })
        assertEquals(listOf("follow", "solid", "liquid"), row.options.map { it.id })
        assertEquals("liquid", row.selectedOptionId)
        assertEquals(
            "follow",
            general(MaterialPanelState(homeBandGlassMaterial = "follow"))
                .row("material.general.homeBand.row")
                .selectedOptionId,
        )
    }

    @Test
    fun `液态档才出现高级材质那几块`() {
        // :1019-1160 整块在 `if (displayedChoice == liquidGlass)` 里
        val liquid = general().flattenedIds()
        assertTrue(liquid.contains("material.general.preset"))
        assertTrue(liquid.contains("material.general.tuning.refraction"))
        assertTrue(liquid.contains("material.general.darkBoost"))
        assertTrue(liquid.contains("material.general.scopeDock"))

        val solid = general(MaterialPanelState(frostedBlurEnabled = false)).flattenedIds()
        assertFalse(solid.contains("material.general.preset"))
        assertFalse(solid.contains("material.general.tuning.refraction"))
        assertFalse(solid.contains("material.general.darkBoost"))
        assertFalse(solid.contains("material.general.scopeDock"))
        // 各表面地图**不**在条件里，实体档照样显示
        assertTrue(solid.contains("material.general.surfaces"))
    }

    @Test
    fun `档位滑杆是一到十格的节点滑杆`() {
        // :1423-1448：min 1 / max 10 / divisions 9，读数只给数字
        val row = general().row("material.general.preset")
        assertEquals("液态玻璃预设", row.title)
        val slider = row.slider!!
        assertEquals(1.0, slider.min, 0.0)
        assertEquals(10.0, slider.max, 0.0)
        assertEquals(9, slider.divisions)
        // 出厂档就是第 7 格（标准）
        assertEquals("7", row.value)
        assertEquals(7.0, row.sliderValue!!, 0.0)
    }

    @Test
    fun `拖成自定义档时滑杆停在最近那格`() {
        // :1429-1430 `(preset.step ?? nearest.step)`
        val custom = general(
            MaterialPanelState(
                liquidGlassPreset = SettingsMaterialModel.PRESET_CUSTOM,
                liquidGlassTuning = LiquidGlassTuning(blurSigma = 18.0, tintAlpha = 0.75),
            ),
        ).row("material.general.preset")
        // 模糊 18 / 染色 0.75 是第 8 格的推荐值 → 滑杆落在第 8 格
        // 2026-11-07：格号仍是 8（滑杆停在最近那格），但读数必须带上「自定义」,
        // 只给数字会读成「你还在第 8 格」
        assertEquals("8 · 自定义", custom.value)
        assertEquals(8.0, custom.sliderValue!!, 0.0)
    }

    @Test
    fun `八根旋钮的顺序与上下限`() {
        // :1471-1577
        val spec = general()
        assertEquals(
            listOf(
                "material.general.tuning.refraction",
                "material.general.tuning.refractionBand",
                "material.general.tuning.edgePow",
                "material.general.tuning.dispersion",
                "material.general.tuning.rimStrength",
                "material.general.tuning.rimWidth",
                "material.general.tuning.blurSigma",
                "material.general.tuning.tint",
            ),
            // 2026-11-07：八根拆成两张同宽同轴的卡（光学 4 / 表面 4），拼起来仍是原来那八根
            spec.group("material.general.tuning.optics").childRowIds() +
                spec.group("material.general.tuning.surface").childRowIds(),
        )
        assertEquals("折射强度", spec.row("material.general.tuning.refraction").title)
        assertEquals("作用带宽度", spec.row("material.general.tuning.refractionBand").title)
        assertEquals("边缘陡缓", spec.row("material.general.tuning.edgePow").title)
        assertEquals("色散", spec.row("material.general.tuning.dispersion").title)
        assertEquals("边缘高光", spec.row("material.general.tuning.rimStrength").title)
        assertEquals("高光带宽", spec.row("material.general.tuning.rimWidth").title)
        assertEquals("磨砂强度", spec.row("material.general.tuning.blurSigma").title)
        assertEquals("染色强度", spec.row("material.general.tuning.tint").title)

        // 折射：0~10 / 40 档（2026-11-03 收档，`845dd9a49`）
        val refraction = spec.row("material.general.tuning.refraction").slider!!
        assertEquals(0.0, refraction.min, 0.0)
        assertEquals(10.0, refraction.max, 0.0)
        assertEquals(40, refraction.divisions)
        // 作用带 1~12 / 46 档（同上）
        val band = spec.row("material.general.tuning.refractionBand").slider!!
        assertEquals(1.0, band.min, 0.0)
        assertEquals(12.0, band.max, 0.0)
        assertEquals(46, band.divisions)
        // 陡缓 1~6 / 20 档（:1513-1527）
        val edge = spec.row("material.general.tuning.edgePow").slider!!
        assertEquals(1.0, edge.min, 0.0)
        assertEquals(6.0, edge.max, 0.0)
        assertEquals(20, edge.divisions)
        // 色散 / 边缘高光 / 染色：默认 0~1（:1528-1543 / :1565-1576）
        assertEquals(20, spec.row("material.general.tuning.dispersion").slider!!.divisions)
        assertEquals(20, spec.row("material.general.tuning.rimStrength").slider!!.divisions)
        assertEquals(20, spec.row("material.general.tuning.tint").slider!!.divisions)
        // 高光带 0~3 / 30 档（:1544-1554）
        val rimWidth = spec.row("material.general.tuning.rimWidth").slider!!
        assertEquals(0.0, rimWidth.min, 0.0)
        assertEquals(3.0, rimWidth.max, 0.0)
        assertEquals(30, rimWidth.divisions)
        // 磨砂 0~40，档数跟着上限（40，不是写死）
        val blur = spec.row("material.general.tuning.blurSigma").slider!!
        assertEquals(0.0, blur.min, 0.0)
        assertEquals(40.0, blur.max, 0.0)
        assertEquals(40, blur.divisions)
    }

    @Test
    fun `八根旋钮的读数格式`() {
        // :1387-1388：数值按指定位数、百分比四舍五入到整数
        val spec = general()
        // 2026-11-03 收档（`845dd9a49`）：折射 8→6、作用带 11→8。
        assertEquals("6.0", spec.row("material.general.tuning.refraction").value)
        assertEquals("8.0", spec.row("material.general.tuning.refractionBand").value)
        assertEquals("2.50", spec.row("material.general.tuning.edgePow").value)
        assertEquals("35%", spec.row("material.general.tuning.dispersion").value)
        assertEquals("20%", spec.row("material.general.tuning.rimStrength").value)
        assertEquals("1.5", spec.row("material.general.tuning.rimWidth").value)
        assertEquals("15", spec.row("material.general.tuning.blurSigma").value)
        assertEquals("70%", spec.row("material.general.tuning.tint").value)
    }

    @Test
    fun `恢复默认按钮与范围说明`() {
        // :1053-1085
        val spec = general()
        val reset = spec.row("material.general.reset")
        assertEquals("恢复默认", reset.title)
        assertEquals(SettingsAction.RESET_SCOPE, reset.action)
        val notice = spec.flatten().filterIsInstance<SettingsDescription>()
            .single { it.textKey == "liquidGlassResetScopeNotice" }
        assertEquals("只恢复液态玻璃的调参，不动整体材质与其他设置", notice.text)
    }

    @Test
    fun `两个开关：深色更暗与独立设置深色档`() {
        // :1093-1125
        val spec = general()
        val boost = spec.row("material.general.darkBoost")
        assertEquals("深色模式玻璃更暗", boost.title)
        assertEquals("中性灰底、更模糊、边缘高光更弱", boost.subtitle)
        assertEquals(true, boost.switchValue)

        // 开关语义是「独立」，字段存的是「是否跟随」→ 取反（:1106-1109）
        val independent = spec.row("material.general.darkIndependent")
        assertEquals("独立设置深色档", independent.title)
        assertEquals("默认沿用浅色档；打开后可单独调一套", independent.subtitle)
        assertEquals(false, independent.switchValue)
        assertEquals(
            true,
            general(MaterialPanelState(linkLiquidGlassTuning = false))
                .row("material.general.darkIndependent")
                .switchValue,
        )
    }

    @Test
    fun `深色档旋钮只在打开独立设置后出现`() {
        // :1130-1139 `if (!linkLiquidGlassTuning)`
        val linked = general().flattenedIds()
        assertFalse(linked.contains("material.general.darkTuning.refraction"))
        val independent = general(MaterialPanelState(linkLiquidGlassTuning = false)).flattenedIds()
        assertTrue(independent.contains("material.general.darkTuning.refraction"))
        assertTrue(independent.contains("material.general.darkTuning.tint"))
    }

    @Test
    fun `玻璃坞作用范围开关`() {
        // :1148-1157
        val row = general().row("material.general.scopeDock")
        assertEquals("玻璃坞导航", row.title)
        assertEquals("底部悬浮药丸与加课圆钮", row.subtitle)
        assertEquals(true, row.switchValue)
        assertEquals(
            false,
            general(MaterialPanelState(liquidGlassDockEnabled = false))
                .row("material.general.scopeDock")
                .switchValue,
        )
    }

    @Test
    fun `各表面当前材质地图三行且是只读`() {
        // :1173-1191：只列可调表面（弹窗家族、子页顶栏锁死，不显示）
        val spec = general()
        assertEquals(
            listOf(
                "material.general.surface.homeBand",
                "material.general.surface.dock",
                "material.general.surface.courseCard",
            ),
            spec.group("material.general.surfaces").childRowIds(),
        )
        assertEquals("首页玻璃带", spec.row("material.general.surface.homeBand").title)
        assertEquals("玻璃坞导航", spec.row("material.general.surface.dock").title)
        assertEquals("课程卡片", spec.row("material.general.surface.courseCard").title)
        spec.group("material.general.surfaces").children.forEach { node ->
            val row = node as SettingsRow
            assertNull("只读行不能有动作", row.action)
            assertNull("只读行不能有跳转目标", row.actionTarget)
        }
    }

    @Test
    fun `表面地图的值随设置变`() {
        // 实体档下：首页带、坞、课卡都是实体
        val solid = general(
            MaterialPanelState(
                frostedBlurEnabled = false,
                courseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
            ),
        )
        assertEquals("实体", solid.row("material.general.surface.homeBand").details)
        assertEquals("实体", solid.row("material.general.surface.dock").details)
        assertEquals("实体", solid.row("material.general.surface.courseCard").details)
        // 液态档 + 坞关 → 坞报磨砂；课卡选了液态但没有壁纸 → 仍是实体
        val dockOff = general(
            MaterialPanelState(
                liquidGlassDockEnabled = false,
                courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS,
                hasHomePageBackdrop = false,
            ),
        )
        assertEquals("液态玻璃", dockOff.row("material.general.surface.homeBand").details)
        assertEquals("高斯模糊", dockOff.row("material.general.surface.dock").details)
        assertEquals("实体", dockOff.row("material.general.surface.courseCard").details)
    }

    @Test
    fun `首页玻璃带开关关掉时地图报已关闭`() {
        assertEquals(
            "已关闭",
            general(MaterialPanelState(homePageHeaderBlurEnabled = false))
                .row("material.general.surface.homeBand")
                .details,
        )
    }

    // ---------------------------------------------- 材质面板 · 课程卡片页

    @Test
    fun `课程卡片页 id 与标题`() {
        val spec = courseCard()
        assertEquals("settings-material-course-card", spec.id)
        assertEquals("surfaceCourseCard", spec.titleKey)
        assertEquals("课程卡片", spec.title)
    }

    @Test
    fun `卡片外观三档`() {
        // :1244-1253 courseCardSurfaceStyleLabel 的三档名
        val row = courseCard().row("material.courseCard.surfaceStyle.row")
        assertEquals("卡片外观", row.title)
        assertEquals(listOf("实体卡片", "高斯模糊", "液态玻璃"), row.options.map { it.label })
        // 液态的存档值是 refraction，与枚举名不同（SettingsPageState 里记了原因）
        assertEquals(listOf("solid", "gaussian", "refraction"), row.options.map { it.id })
        assertEquals("solid", row.selectedOptionId)
        assertEquals(
            "refraction",
            courseCard(SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS))
                .row("material.courseCard.surfaceStyle.row")
                .selectedOptionId,
        )
    }

    @Test
    fun `总闸关掉且卡片不是实体时才提示暂不生效`() {
        // :1223-1225 maskedByMaster = !frostedBlurEnabled && style != solid
        fun hasHint(state: SettingsPageState, material: MaterialPanelState) = courseCard(state, material)
            .flatten()
            .filterIsInstance<SettingsDescription>()
            .any { it.textKey == "courseCardMaterialMasterOffHint" }

        assertFalse("总闸开着不该提示", hasHint(SettingsPageState(), MaterialPanelState()))
        assertFalse(
            "卡片本来就是实体，无所谓不生效",
            hasHint(
                SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID),
                MaterialPanelState(frostedBlurEnabled = false),
            ),
        )
        assertTrue(
            "总闸关 + 卡片选了液态 → 必须提示",
            hasHint(
                SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS),
                MaterialPanelState(frostedBlurEnabled = false),
            ),
        )
    }

    @Test
    fun `卡片液态档才出现旋钮`() {
        // :1267-1313
        val solid = courseCard().flattenedIds()
        assertFalse(solid.contains("material.courseCard.preset"))
        val liquid = courseCard(
            SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS),
            MaterialPanelState(hasHomePageBackdrop = true),
        ).flattenedIds()
        assertTrue(liquid.contains("material.courseCard.preset"))
        assertTrue(liquid.contains("material.courseCard.tuning.refraction"))
        assertTrue(liquid.contains("material.courseCard.tuning.blurSigma"))
    }

    @Test
    fun `卡片磨砂滑杆上限是预糊上限二十四`() {
        // :1299-1302 blurSigmaMax: kPreblurMaxSigma
        val spec = courseCard(
            SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS),
            MaterialPanelState(
                hasHomePageBackdrop = true,
                courseCardGlassTuning = LiquidGlassTuning(blurSigma = 40.0),
            ),
        )
        val blur = spec.row("material.courseCard.tuning.blurSigma")
        assertEquals(24.0, blur.slider!!.max, 0.0)
        // 档数跟着上限走（24），别写死 40（:1560-1561）
        assertEquals(24, blur.slider!!.divisions)
        // 存量值高于上限时读数也夹到 24（:1479-1483）
        assertEquals("24", blur.value)
        assertEquals(24.0, blur.sliderValue!!, 0.0)
    }

    @Test
    fun `两页的档位滑杆分格完全一致`() {
        // :1263-1266 两页共用一套档位预设 ⇒ 共用一套分格
        val generalPreset = general().row("material.general.preset").slider!!
        val cardPreset = courseCard(
            SettingsPageState(courseCardSurfaceStyle = CourseCardSurfaceStyle.LIQUID_GLASS),
            MaterialPanelState(hasHomePageBackdrop = true),
        ).row("material.courseCard.preset").slider!!
        assertEquals(generalPreset.min, cardPreset.min, 0.0)
        assertEquals(generalPreset.max, cardPreset.max, 0.0)
        assertEquals(generalPreset.divisions, cardPreset.divisions)
    }

    // ---------------------------------------------------------- 面板页签

    @Test
    fun `壁纸面板两个页签的名字`() {
        // :2167-2175：用新加的短标签，不复用 homePageWallpaperTitle / settingsTitle
        assertEquals(
            listOf("壁纸", "设置"),
            SettingsWallpaperSheetPage.TAB_LABELS.map { it.zh },
        )
        assertEquals(
            listOf("wallpaperSheetTabPicker", "wallpaperSheetTabSettings"),
            SettingsWallpaperSheetPage.TAB_LABELS.map { it.key },
        )
    }

    @Test
    fun `材质面板两个页签的名字`() {
        // :2332
        assertEquals(
            listOf("通用", "课程卡片"),
            SettingsMaterialSheetPage.TAB_LABELS.map { it.zh },
        )
        // 课程卡片设置页的「卡片外观」跳转牌停在这一页（:85-88）
        assertEquals(1, SettingsMaterialSheetPage.COURSE_CARD_PAGE_INDEX)
    }
}
