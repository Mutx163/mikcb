package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.LiquidGlassTuningModel
import com.mutx163.qingyu.app.SettingsActionDispatcher
import com.mutx163.qingyu.app.SettingsActionKind
import com.mutx163.qingyu.app.SettingsDispatch
import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSettingsModelStore
import com.mutx163.qingyu.app.TimetableStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 材质弹层（「通用 / 课程卡片」两个页签）的**点击 → 写回 → 回读**闭环（2026-11-01）。
 *
 * ## 为什么要单独钉这一层
 *
 * 面板的行模型（`SettingsMaterialPanels.kt`）与分派器（`SettingsActionDispatcher`）
 * 在两个包里各写一份 rowId / option id。任何一边改名而另一边没跟上，屏上就是
 * 「点了没反应」或「点了写错字段」——编译能过、面板结构测试也能过（它只断行存在）。
 * 所以这里从**面板真实产出的 spec** 里取 rowId 与 option id，再走真实分派器，
 * 最后从 [AppearanceEditorBridge.toState] 读回面板状态，三段必须一致。
 *
 * ## 覆盖范围
 *
 * | 面板控件 | 断言的闭环 |
 * |---|---|
 * | 默认材质两档（`:974-993`） | option id → `frostedBlurEnabled` → 回读档位 |
 * | 首页顶栏玻璃三档（`:1007-1017`） | option id → `homeBandGlassMaterial` → 回读选中档 |
 * | 课程卡片外观三档（`:1244-1253`） | option id → `courseCardSurfaceStyle` → 回读选中档 |
 * | 档位滑杆 10 格（`:1423-1449` / `:1274-1290`） | 格号 → 档位名 + 推荐参数 → 回读档位 |
 * | 三组八根旋钮（`:1471-1577` 等） | 数值 → 参数 + 档位打 `custom` → 回读数值 |
 * | 三个开关（`:1095-1157`） | 点击 → 字段取反 → 回读开关态 |
 * | 「恢复默认」（`:1053-1085`） | RESET_SCOPE → 只清液态调参 |
 * | 各表面当前材质地图（`:1168-1191`） | 总闸写回 → 三行推导值同口径变化 |
 *
 * 「预览」这一项不在 JVM 里断言：预览是活 Compose 树，只能真机看。当前渲染侧只消费
 * `courseCardSurfaceStyle`（`TimetableStyleMapping.kt`），全局模糊 / 顶栏玻璃材质
 * **还没有渲染消费者**——这是渲染泳道的缺口，写在交付报告里，不在这里造假。
 */
class SettingsMaterialSheetWiringTest {

    private fun model() = TimetableSettingsModel()

    private fun generalSpec(material: MaterialPanelState = MaterialPanelState()) =
        SettingsMaterialGeneralPage.spec(SettingsPageState(), material)

    private fun cardSpec(
        style: CourseCardSurfaceStyle = CourseCardSurfaceStyle.SOLID,
        material: MaterialPanelState = MaterialPanelState(),
    ) = SettingsMaterialCourseCardPage.spec(
        SettingsPageState(courseCardSurfaceStyle = style),
        material,
    )

    private fun write(
        rowId: String,
        target: String?,
        m: TimetableSettingsModel = model(),
    ): SettingsDispatch = SettingsActionDispatcher.dispatch(
        kind = SettingsActionKind.WRITE_SETTING,
        target = target,
        rowId = rowId,
        model = m,
    )

    private fun written(dispatch: SettingsDispatch): TimetableSettingsModel {
        assertTrue("期望 Write，实际是 $dispatch", dispatch is SettingsDispatch.Write)
        return (dispatch as SettingsDispatch.Write).model
    }

    // --------------------------------------------------------------- 多选项行

    @Test
    fun `默认材质每个选项都能写回并回读`() {
        val row = generalSpec().row("material.general.glassMode.row")
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
        assertEquals(2, row.options.size)

        for (option in row.options) {
            val next = written(write(row.id, option.id))
            val state = AppearanceEditorBridge.toState(next)
            // 回读：同一行会亮在这一档（`glassModeChoice` 只看模糊总开关）。
            assertEquals(
                "${option.id} 写回后回读不到",
                option.id,
                generalSpec(state.material).row(row.id).selectedOptionId,
            )
            if (option.id == GlassModeChoice.SOLID.value) {
                assertEquals(false, next.frostedBlurEnabled)
            }
            if (option.id == GlassModeChoice.LIQUID_GLASS.value) {
                assertEquals(true, next.frostedBlurEnabled)
                // 液态档顺手打开玻璃坞那把唯一的例外开关（glass_mode_choice.dart:22-40）
                assertEquals(true, next.liquidGlassDockEnabled)
            }
        }
    }

    @Test
    fun `首页顶栏玻璃每个选项都能写回并回读`() {
        val row = generalSpec().row("material.general.homeBand.row")
        assertEquals(3, row.options.size)
        for (option in row.options) {
            val next = written(write(row.id, option.id))
            assertEquals(option.id, next.homeBandGlassMaterial)
            val state = AppearanceEditorBridge.toState(next)
            assertEquals(
                "${option.id} 写回后回读不到",
                option.id,
                generalSpec(state.material).row(row.id).selectedOptionId,
            )
        }
    }

    @Test
    fun `课程卡片外观每个选项都能写回并回读`() {
        val row = cardSpec().row("material.courseCard.surfaceStyle.row")
        assertEquals(3, row.options.size)
        for (option in row.options) {
            val next = written(write(row.id, option.id))
            assertEquals(option.id, next.courseCardSurfaceStyle.value)
            val state = AppearanceEditorBridge.toState(next)
            assertEquals(option.id, state.material.courseCardSurfaceStyle.value)
            assertEquals(
                "${option.id} 写回后回读不到",
                option.id,
                cardSpec(style = state.material.courseCardSurfaceStyle, material = state.material)
                    .row(row.id)
                    .selectedOptionId,
            )
        }
    }

    // --------------------------------------------------------------- 档位滑杆

    @Test
    fun `通用页档位滑杆写档位名与推荐参数`() {
        val row = generalSpec().row("material.general.preset")
        assertEquals(SettingsAction.WRITE_SETTING, row.action)
        // 10 格：min 1 / max 10（Dart :1423-1449）
        assertEquals(1.0, row.slider!!.min, 0.0)
        assertEquals(10.0, row.slider!!.max, 0.0)

        val first = written(write(row.id, "1"))
        assertEquals("clear", first.liquidGlassPreset)
        // 第 1 格染色与模糊都归零（liquid_glass_tuning.dart:254-266）
        assertEquals(0.0, first.liquidGlassTuning!!.blurSigma, 0.0)
        assertEquals(0.0, first.liquidGlassTuning!!.tintAlpha, 0.0)

        val seventh = written(write(row.id, "7"))
        assertEquals("standard", seventh.liquidGlassPreset)
        assertEquals(
            LiquidGlassTuningModel.DEFAULTS.blurSigma,
            seventh.liquidGlassTuning!!.blurSigma,
            0.0,
        )
        // 回读：面板读数停在同一格
        val state = AppearanceEditorBridge.toState(seventh)
        assertEquals("standard", state.material.liquidGlassPreset)
        assertEquals(
            "7",
            generalSpec(state.material).row(row.id).value,
        )
    }

    @Test
    fun `卡片页档位滑杆与通用页同一套格`() {
        val style = CourseCardSurfaceStyle.LIQUID_GLASS
        val row = cardSpec(style = style).row("material.courseCard.preset")
        assertEquals(1.0, row.slider!!.min, 0.0)
        assertEquals(10.0, row.slider!!.max, 0.0)

        val dense = written(write(row.id, "10"))
        assertEquals("dense", dense.courseCardGlassPreset)
        val state = AppearanceEditorBridge.toState(dense)
        assertEquals("dense", state.material.courseCardGlassPreset)
    }

    // --------------------------------------------------------------- 八根旋钮

    @Test
    fun `通用页八根旋钮写参数并把档位打成自定义`() {
        val spec = generalSpec()
        val ids = listOf(
            "material.general.tuning.refraction",
            "material.general.tuning.refractionBand",
            "material.general.tuning.edgePow",
            "material.general.tuning.dispersion",
            "material.general.tuning.rimStrength",
            "material.general.tuning.rimWidth",
            "material.general.tuning.blurSigma",
            "material.general.tuning.tint",
        )
        for (id in ids) {
            val row = spec.row(id)
            val mid = ((row.slider!!.min + row.slider!!.max) / 2.0).toString()
            val next = written(write(row.id, mid))
            // 动任何一根 = 档位打成 custom（settings_appearance_editor.dart:1355-1370）
            assertEquals("$id 拖完没打成自定义档", "custom", next.liquidGlassPreset)
        }

        // 精确值抽查：拖到 20 就是 20（分派器按区间收口，40 以内不夹）
        val blur = written(write("material.general.tuning.blurSigma", "20"))
        assertEquals(20.0, blur.liquidGlassTuning!!.blurSigma, 0.0)
        val state = AppearanceEditorBridge.toState(blur)
        assertEquals(20.0, state.material.liquidGlassTuning.blurSigma, 0.0)
        assertEquals(
            "20",
            generalSpec(state.material).row("material.general.tuning.blurSigma").value,
        )
    }

    @Test
    fun `深色档旋钮只写参数不动档位`() {
        // 先打开「独立设置深色档」，深色旋钮才存在（:1130-1139）
        val independent = written(write("material.general.darkIndependent", null))
        val spec = generalSpec(AppearanceEditorBridge.toState(independent).material)
        val row = spec.row("material.general.darkTuning.blurSigma")
        val next = written(write(row.id, "5", independent))
        assertEquals(5.0, next.liquidGlassTuningDark!!.blurSigma, 0.0)
        // 深色那套没有独立档名，不能把浅色档位改掉（:1373-1384）
        assertEquals(independent.liquidGlassPreset, next.liquidGlassPreset)
    }

    @Test
    fun `卡片档旋钮写参数并把卡片档位打成自定义`() {
        val style = CourseCardSurfaceStyle.LIQUID_GLASS
        val spec = cardSpec(style = style)
        val row = spec.row("material.courseCard.tuning.blurSigma")
        val next = written(write(row.id, "20"))
        assertEquals(20.0, next.courseCardGlassTuning!!.blurSigma, 0.0)
        assertEquals("custom", next.courseCardGlassPreset)

        val state = AppearanceEditorBridge.toState(next)
        assertEquals(20.0, state.material.courseCardGlassTuning.blurSigma, 0.0)
        assertEquals("custom", state.material.courseCardGlassPreset)
        // 卡片那根的上限是 24（kPreblurMaxSigma），面板读数不能停在 40 那档
        assertEquals(
            "20",
            cardSpec(style = style, material = state.material)
                .row("material.courseCard.tuning.blurSigma")
                .value,
        )
    }

    // ------------------------------------------------------------------ 开关

    @Test
    fun `材质面板三个开关点击后都真的取反`() {
        val ids = listOf(
            "material.general.darkBoost",
            "material.general.darkIndependent",
            "material.general.scopeDock",
        )
        for (id in ids) {
            val before = generalSpec().row(id).switchValue
            val next = written(write(id, null))
            val after = generalSpec(AppearanceEditorBridge.toState(next).material).row(id).switchValue
            assertEquals("$id 点了没变", !before!!, after)
        }
    }

    @Test
    fun `恢复默认只清液态调参不动整体材质`() {
        val changed = written(write("material.general.tuning.blurSigma", "20"))
        assertNotEquals(
            LiquidGlassTuningModel.DEFAULTS,
            changed.liquidGlassTuning,
        )

        val resetRow = generalSpec().row("material.general.reset")
        assertEquals(SettingsAction.RESET_SCOPE, resetRow.action)
        assertEquals(
            SettingsMaterialGeneralPage.RESET_SCOPE_LIQUID_GLASS,
            resetRow.actionTarget,
        )

        val reset = SettingsActionDispatcher.applyResetScope(
            changed,
            resetRow.actionTarget!!,
        )
        assertTrue("液态玻璃恢复作用域必须已实现", reset != null)
        reset!!
        assertEquals("standard", reset.liquidGlassPreset)
        assertEquals(LiquidGlassTuningModel.DEFAULTS, reset.liquidGlassTuning)
        // 整体材质档不在这颗按钮的范围里（settings_appearance_editor.dart:1072-1082）
        assertEquals(changed.frostedBlurEnabled, reset.frostedBlurEnabled)
        assertEquals(changed.courseCardSurfaceStyle, reset.courseCardSurfaceStyle)
    }

    // ------------------------------------------------------------ 表面材质地图

    /**
     * 版式顺序（2026-11-07）：只读地图排在「高级材质」之前。
     *
     * 这条**不是**在断实现细节，而是在钉住那个决定：这块是「上面两处选择算出来的结果」，
     * 用户打开面板就该看到；一旦有人出于「信息靠后不碍事」把它挪回整页末尾，这里会红。
     * 同时断一次行 id 没被顺手改掉（改名会让分派器静默丢掉写入）。
     */
    @Test
    fun `只读表面地图排在高级材质之前且行 id 不变`() {
        val nodes = generalSpec().nodes
        val surfacesLabel = nodes.indexOfFirst { it.id == "material.general.surfaces.label" }
        val advancedLabel = nodes.indexOfFirst { it.id == "material.general.advanced.label" }
        assertTrue("表面地图标题不在 spec 里", surfacesLabel >= 0)
        assertTrue("高级材质标题不在 spec 里", advancedLabel >= 0)
        assertTrue(
            "只读地图应在高级材质之前（当前 $surfacesLabel vs $advancedLabel）",
            surfacesLabel < advancedLabel,
        )
        // 上移不能改行 id：三行只读行仍是原 id、仍不带动作（不可点）。
        val spec = generalSpec()
        for (id in listOf(
            "material.general.surface.homeBand",
            "material.general.surface.dock",
            "material.general.surface.courseCard",
        )) {
            assertEquals("$id 上移后行 id 变了", null, spec.row(id).action)
        }
    }

    @Test
    fun `表面地图与写回同口径变化`() {        // 默认（模糊开）：玻璃带 / 玻璃坞液态；课卡默认实体档。
        val liquid = written(write("material.general.glassMode.row", "liquidGlass"))
        val liquidSpec = generalSpec(AppearanceEditorBridge.toState(liquid).material)
        assertEquals(
            SettingsStringsExt1.frostedGlassModeLiquid.zh,
            liquidSpec.row("material.general.surface.homeBand").details,
        )
        assertEquals(
            SettingsStringsExt1.frostedGlassModeLiquid.zh,
            liquidSpec.row("material.general.surface.dock").details,
        )
        assertEquals(
            SettingsStringsExt1.materialStateSolid.zh,
            liquidSpec.row("material.general.surface.courseCard").details,
        )

        // 关掉总闸：三行一起回落实体（surface_material.dart:41-59 / 96-107）。
        val solid = written(write("material.general.glassMode.row", "solid"))
        val solidSpec = generalSpec(AppearanceEditorBridge.toState(solid).material)
        assertEquals(
            SettingsStringsExt1.materialStateSolid.zh,
            solidSpec.row("material.general.surface.homeBand").details,
        )
        assertEquals(
            SettingsStringsExt1.materialStateSolid.zh,
            solidSpec.row("material.general.surface.dock").details,
        )
        assertEquals(
            SettingsStringsExt1.materialStateSolid.zh,
            solidSpec.row("material.general.surface.courseCard").details,
        )
    }

    // ------------------------------------------------------------- 落盘 / 回读

    @Test
    fun `写回后合并落盘再加载仍是新值`() {
        val raw = InMemoryKeyValueStore(mapOf("timetable_settings" to "{}"))
        val store = TimetableSettingsModelStore(TimetableStore(raw))
        val seeded = store.load()

        val next = written(
            write("material.general.homeBand.row", "solid", seeded),
        )
        store.save(next)
        val reloaded = store.load()

        assertEquals("solid", reloaded.homeBandGlassMaterial)
        val reRead = generalSpec(AppearanceEditorBridge.toState(reloaded).material)
            .row("material.general.homeBand.row")
        assertEquals("solid", reRead.selectedOptionId)
    }
}
