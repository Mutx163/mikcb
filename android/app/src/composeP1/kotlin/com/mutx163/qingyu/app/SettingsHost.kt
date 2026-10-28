package com.mutx163.qingyu.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.SettingsPageScreen

/**
 * 设置族宿主（Phase 3.5 · 设置族竖切第一刀）。
 *
 * 一份渲染层（`SettingsPageScreen(spec, …)`）服务 20 页，所以宿主也只有这一份：
 *
 * ```
 * TimetableSettingsModelStore ──load──▶ TimetableSettingsModel
 *          ▲                                  │ SettingsPageBridge.toSettingsPageState
 *          │ save                             ▼
 *          └──────── Write ◀── SettingsActionDispatcher ◀── onAction(action, target, rowId)
 *                                            │
 *                                            └── 其余意图（导航/弹层/剪贴板/恢复默认）→ 壳
 * ```
 *
 * ## 本刀只认 4 页
 *
 * 通用 / 外观 / 主题管理 / 课程卡片（[SettingsPageBridge.SUPPORTED_PAGE_IDS]）。
 * 传别的页 id ⇒ `specFor` 返回 null ⇒ **本宿主什么都不渲染**（由壳决定要不要回退到
 * 演示数据），不会崩。
 *
 * ## 写回与重组
 *
 * `WRITE_SETTING` 由分派器算出新模型 → `store.save(...)`（**合并写**，只覆盖本模型
 * 拥有的 35 个键）→ 更新本地状态 → 重组。界面立刻跟着变，盘上也同步变了。
 *
 * ## 与仓储（`TimetableRepository`）共用同一个键，为什么不冲突
 *
 * 仓储只写 `timetable_settings` 里的 **core 4 键**（sections / activeTimeSchemeId /
 * semesterWeekCount / semesterStartDate），本模型写另外 35 个显示键；两者都走
 * `TimetableStore.saveSettingsPatch` 的**读-合并-写**，所以谁都不会覆盖谁。
 * ⚠️ 反过来：仓储在内存里那份设置与本宿主不同步，宿主**不做**外部变更订阅——
 * 本刀里设置只从本宿主改（Dart 侧 `_updateDraft` → `_enqueuePersist` 也是这个形态）。
 *
 * ## 预览区
 *
 * 课程卡片页的 `previewFlex = 4` 需要一张课卡预览，本刀**不提供**（`preview = null`）：
 * 渲染层在 preview 为 null 时忽略 flex、内容占满（`SettingsPageRenderers.kt:112-121`），
 * 所以不会出现空白条。真预览要接课程数据与壁纸采样，留给下一刀。
 *
 * @param pageId 四个受支持页 id 之一。
 * @param store 设置模型的读写入口（壳里由 `PrefsKeyValueStore` 构造）。
 * @param onBack 返回；null = 无返回键（与 `SettingsPageScreen` 的语义一致）。
 * @param onNavigate 推页（`NAVIGATE` 意图的路由）。
 * @param onIntent 其余界面意图（弹层 / 剪贴板 / 恢复默认确认 / RUN_NOW 等），由壳执行。
 * @param onRequestColor 选色：壳弹官方 `ColorPicker`，选完调 `commit(hex)`。
 *   不传 = 该行的选色不弹（no-op），不会崩。
 */
@Composable
fun SettingsHost(
    pageId: String,
    store: TimetableSettingsModelStore,
    onBack: (() -> Unit)? = null,
    onNavigate: (route: String) -> Unit = {},
    onIntent: (SettingsDispatch) -> Unit = {},
    onRequestColor: (rowId: String, currentHex: String, commit: (String) -> Unit) -> Unit =
        { _, _, _ -> },
) {
    var model by remember(store) { mutableStateOf(store.load()) }

    // 写路径只有这一条：算新模型 → 落盘 → 更新状态（界面跟着重组）。
    fun commitWrite(target: String?, rowId: String) {
        when (
            val result = SettingsActionDispatcher.dispatch(
                kind = SettingsActionKind.WRITE_SETTING,
                target = target,
                rowId = rowId,
                model = model,
            )
        ) {
            is SettingsDispatch.Write -> {
                store.save(result.model)
                model = result.model
            }
            // 值不认识 / rowId 不认识：不写、不崩，交给壳记录。
            else -> onIntent(result)
        }
    }

    val state = SettingsPageBridge.toSettingsPageState(model)
    val spec = SettingsPageBridge.specFor(pageId, state) ?: return

    SettingsPageScreen(
        spec = spec,
        preview = null,
        onBack = onBack,
        onAction = { action, target, rowId ->
            val kind = SettingsPageBridge.toKind(action)
            when (kind) {
                SettingsActionKind.WRITE_SETTING -> commitWrite(target, rowId)

                // 选色行：先把当前色给壳，壳弹完把新色回投成一条 WRITE_SETTING，
                // 于是「联动时详情色跟随标题色」那套判据仍然只在一处（分派器里）。
                SettingsActionKind.COLOR_PICKER -> {
                    val current = SettingsPageBridge.currentColorHex(model, rowId)
                    if (current == null) {
                        onIntent(
                            SettingsDispatch.Ignored(
                                kind = kind,
                                target = target,
                                rowId = rowId,
                                // 渲染层不许写中文字面量（CjkLiteralGateTest）：这里是
                                // 开发者向的诊断码，不是屏上文案，所以给稳定错误码。
                                reason = "row_not_a_color_row",
                            ),
                        )
                    } else {
                        onRequestColor(rowId, current) { hex -> commitWrite(hex, rowId) }
                    }
                }

                else -> onIntent(
                    SettingsActionDispatcher.dispatch(kind, target, rowId, model),
                )
            }
        },
    )
}
