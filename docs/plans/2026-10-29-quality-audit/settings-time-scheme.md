# 设置族 / 学期设置 / 时间模板 / 节假日 · 质量审核（2026-10-29，独立复核）

审核基线：HEAD `3f3b7354`（2026-10-29 20:10 提交）；审核时刻：2026-10-29 20:33（Asia/Shanghai）。
未提交文件一律按 `git show HEAD:<path>` 判；工作区差异另列在 §在途改动，不入判。

## 结论（先看这段）

**审核页面清单**

| 页面 | 壳分支 | 文件 | 基线来源 | 是否在途 |
|---|---|---|---|---|
| 设置首页（课表设置摘要卡 + 24 行入口） | `b.settingsHome` | `main: pages/settings/SettingsTimetablePage.kt` + `composeP1: app/SettingsSemesterHost.kt`（`SettingsTimetableHubHost`） | HEAD | 文件在途（仅补图标） |
| 通用设置 | `b.general` | `main: pages/settings/SettingsGeneralPage.kt` + `composeP1: app/SettingsHost.kt` | `1703478d` / `6533d842` | 否 |
| 外观与配色 | `b.appearance` | `SettingsAppearancePage.kt` | `1703478d` 前后 | 否 |
| 主题管理 | `b.theme` | `SettingsAppearancePage.kt`（`SettingsThemeManagePage`） | 同上 | 否 |
| 课程卡片 | `b.courseCard` | `SettingsCourseCardPage.kt` | 同上 | 否 |
| 课表页面设置 | `b.timetablePage` | `SettingsTimetablePageSettingsPage.kt` + `SettingsHost.kt`（`TimetablePageSettingsHost`） | 同上 | 否 |
| 首页与导航 / 两个编辑器 | `b.homeNavigation` `b.homeMenuEditor` `b.glassDock` | `SettingsHomeNavigationPage.kt` + `SettingsHost.kt` | 同上 | 否 |
| 学期设置 | `b.semester` | `SettingsSemesterHost.kt` + `SettingsTimetablePage.semesterSpec` | `62417867` `415184e0` `1813c821` | 否 |
| 节假日标记 | `b.holiday` | `SettingsHolidayHost.kt` + `SettingsHolidayPage.kt` | `2083fa08` | 否 |
| 节假日数据更新 | `b.holidayAdvanced` | `SettingsHolidayAdvancedHost.kt` | `2083fa08` | 否 |
| 时间模板列表 | `d3.timeSchemes` | `TimeSchemeHost.kt` + `pages/time_scheme/*` | `9c2ec06a` `28d703b7` | 否 |
| 时间模板编辑节次 | `d3.timeSchemeEditor` | 同上 | `9c2ec06a` `28d703b7` | 否 |
| 11 个空构造演示页群 | `b.appearanceEditor` 等 | 见 §12 存量 | 存量（`867f83e8`，非本期） | 否 |
| 地点作息匹配 | `d3.locationMatch` | `LocationTimeMatchPage.kt` | 存量 | 否 |

**P0 4 条 / P1 8 条 / P2 6 条 / 与既有文档不一致 4 条。**

最严重 3 条（详细证据见对应小节）：

1. **P0 主题管理页 4 处可点的东西点了完全没反应**（导出主题 / 导入主题 / 保存当前主题 / 已存主题「更多操作」）——
   `SettingsAppearancePage.kt:296-314`、`:349-361` 给出 `CLIPBOARD_EXPORT` / `CLIPBOARD_IMPORT` / `DIALOG` / `SHEET`，
   分派器把它们翻成 `ClipboardExport` / `ShowDialog` / `ShowSheet`（`SettingsActionDispatcher.kt:262-289`），
   宿主丢给默认空实现的 `onIntent`（`SettingsHost.kt:124` `= {}`、`:313-317`），壳 `ShellPageIndex.kt:330-335` 又没传 `onIntent`
   ⇒ 全仓 0 消费者（grep 只命中测试）。Dart 原件 `settings_appearance.dart:516-526` + `:831-863` 是真功能带 toast。
2. **P0 课卡「课表重新配色」点了没反应** —— `SettingsCourseCardPage.kt:189-197` `action = SettingsAction.RECOLOR_SHEET`，
   `SettingsHost.kt:281-317` 的 `when` 无此分支，`ShowRecolorSheet` 生产代码 0 消费者；
   Dart `settings_course_card.dart:300-305` 是 `onTap: () => showCourseRecolorSheet(context)`。
3. **P0 11 个设置分支喂空构造 state（存量）+ 1 个整页死页** —— `ShellPageIndex.kt`（HEAD）`336-344`、`367-374`、`403-404`
   共 11 条 `SettingsScreen(...State())`，而 `SettingsScreen` 本体（`:1340-1355`）`onAction` 只做路由映射 ⇒ 开关/滑杆点了不动；
   `d3.locationMatch`（`:812-819`）整页 5 个空 lambda。守卫 `DiagnosticsWiringGuardTest` 的 `FORBIDDEN` 已有
   `SettingsPageState()` 模式（`:183`）但 `MANAGED` 只登记 5 个诊断页（`:159-170`）⇒ 11 条无人看管。

一句话：**真宿主接得最实的是「学期设置」「节假日两页」「时间模板两页」（读仓储、写合并、失败有提示路径、单测钉行为）；
最虚的是「主题管理页」与「课程卡片页的重新配色」——4+1 处可点的东西点了完全没反应，因为分派器把动作翻成
`ShowSheet` / `ShowDialog` / `ClipboardExport` / `ClipboardImport` / `ShowRecolorSheet` 之后，全仓没有任何消费者，
宿主把它们丢给一个默认空实现的 `onIntent`。**

---

## 逐页结论

### 1. 设置首页（`b.settingsHome`）· `main: pages/settings/SettingsTimetablePage.kt`

- **D1 有缺陷（存量）**：摘要卡与各处行都读真仓储，导航行有落点；但同页的 **1 个开关 + 1 个弹层行没有任何落点**。
  `composeP1: app/SettingsSemesterHost.kt:406-413`（`SettingsTimetableHubHost`，HEAD 同文件未被改）：

  ```kotlin
  SettingsPageScreen(
      spec = SettingsTimetablePage.spec(state),
      onBack = onBack,
      onAction = { action, target, _ ->
          // 本页只有「箭头行」有落点；开关/弹层那几行仍属演示数据（no-op 与改动前一致）。
          if (action == SettingsAction.NAVIGATE) target?.let(onNavigate)
      },
  )
  ```

  而该 spec 里确有非导航行（HEAD 行号）：`SettingsTimetablePage.kt:542-548`（`timetable.debugOverlay`，
  `component = MiuixRowComponent.SWITCH`，`action = SettingsAction.WRITE_SETTING`）与
  `:549-556`（`timetable.debugPanel`，`action = SettingsAction.DIALOG`）。这两行只在开发者工具组可见
  （诊断构建），开关点了不动、面板点了不开。宿主注释**自述**了这一点，属「诚实标注的未接线」，但按判据仍是空落点。
- **D2 通过（抽查）**：摘要卡「当前第 N 周 / 共 M 周」+ 开学日期、四组入口行与 Dart
  `lib/screens/timetable_settings_screen.dart:379-397` 一致；开发者工具组可见性按 Dart `:1052-1070`
  用 `MemoryStatsCollector.isDiagnosticsPackage` + `BuildConfig.DEBUG` 判（`SettingsSemesterHost.kt:394-404`），
  不再恒定 false。
- **D3 通过**：本页文案全部 `ArbText`（见 §D3 脚本：652 条 0 不一致）。
- **D4 通过**：`SemesterSettingsLogic` 被宿主真调（`stateOf` / `weekForNow` / `pickerInitialDate` …）。
- **D5 通过**：`-Domain settings` → 0 违规。
- **D6 有缺陷（盲区）**：没有测试钉「本页非导航行必须有落点」，`SettingsTimetablePageWiringTest` 只验行 id/取值映射。
- 缺陷清单：
  - P1｜`timetable.debugOverlay` / `timetable.debugPanel` 两行无落点（`SettingsTimetablePage.kt:566-580` + `SettingsSemesterHost.kt:409-412`）。

### 2. 通用设置（`b.general`）· `SettingsGeneralPage.kt` + `SettingsHost.kt`

- **D1 通过（4/4 行有写路径 + 自动更新 5 行独立写路径）**：`ShellPageIndex.kt`（HEAD）`317-325` 把
  `store` / `autoRefreshStore` / 两个「当场生效」回调都传了：

  ```kotlin
  "b.general" -> SettingsHost(
      pageId = SettingsGeneralPage.ID, store = wiring.settingsModel, onBack = onBack,
      onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
      autoRefreshStore = wiring.autoRefresh,
      onTransitionSpeedChanged = { wiring.pageTransitionSpeed = it },
      onHapticsChanged = { wiring.enableHaptics = it },
  )
  ```

  消费者实测（grep 全 `android/app/src`，排除 test）：
  - `pageTransitionSpeed` → `PagesShellActivity.kt:192-193` `NavTransitions.MiuixDefault.scaledToUserSpeed(...)`（真生效）；
  - `enableHaptics` → `PagesShellActivity.kt:191` 换 `NoopHapticFeedback`（真生效）；
  - `appLocaleTag` → **只有** `pages/diagnostics/PerformanceSettingsSnapshot.kt:183` 读，**没有任何一处按它切语言**；
  - `homePullQuickImportEnabled` → **0 个读者**（除模型自身的读写）。
- **D2 有缺陷（两条「改了不生效」）**：
  - P1｜语言下拉：`SettingsGeneralPage.kt:51-58` 给出 4 个语言选项并 `WRITE_SETTING` 落盘，但壳没有
    `setApplicationLocales`（grep `appLocaleTag` 仅命中诊断快照）。用户选「English」→ 屏上仍是中文。
    Dart 原件同一行是 `settings_general.dart:58` 的 `HyperosSelectTile`，选完立即 `setLocale`。
  - P1｜首页下拉快捷导入：开关落盘，但 Compose 首页没有下拉手势，等于「写了没人读」。
    （`docs/plans/2026-10-29-compose-general-page-audit.md:42` 已自述，属壳层缺能力。）
- **D3 通过**：文案全走 `SettingsStrings`；`SettingsArbParityTest` 逐字对拍（4 页 spec），我另跑脚本 652 条 0 不一致。
- **D4 通过**：`SettingsPageBridge.toSettingsPageState` + `SettingsActionDispatcher` 都被宿主真调。
- **D5 通过**：0 违规。
- **D6 有缺陷（P1）**：写盘失败路径**不可达**——
  `platform/PrefsKeyValueStore.kt:90-92`：

  ```kotlin
  override fun putString(key: String, value: String) {
      prefs.edit().putString(FrozenValueCodec.physicalKey(key), value).commit()
  }
  ```

  `commit()` 的 `Boolean` 被丢弃，`KeyValueStore`（`app/KeyValueStore.kt:58-67`）签名也全是 `Unit`；
  于是宿主里 `runCatching { store.save(next) }.onFailure { notify(saveFailed) }`（`SettingsHolidayHost.kt:142-147`）
  与 `if (autoStore.saveSchedule(next))`（`SettingsHost.kt:262-267`，这条有 read-back 校验、是真的）之外的
  「落盘失败」提示分支**永远进不去**。Dart 侧 `settings_general.dart:155-163` 是 `catch → reportSettingsPersistFailure(..., resetDraft)`
  ——失败会把草稿拉回真值并提示；Compose 没有对应物。
- 缺陷清单：
  - P1｜语言下拉选了不生效（`SettingsGeneralPage.kt:51-58` + 全仓无 `appLocaleTag` 读者）。
  - P1｜首页下拉快捷导入开关无读者。
  - P1｜设置模型的落盘失败无法感知（`KeyValueStore.putX` 丢 `commit()` 返回值）；Dart 会回滚草稿 + 提示。

### 3. 外观与配色（`b.appearance`）

- **D1 通过**：`ShellPageIndex.kt:326-329`（HEAD）传真 `store`；`WRITE_SETTING` 6 行、`NAVIGATE` 2 行、
  `RESET_SCOPE` 1 行全部有落点（`SettingsHost.kt:281-317`：写/导航/恢复默认确认框 `applyReset` 真写盘）。
  动作分布实测：`grep -n "action = SettingsAction" SettingsAppearancePage.kt` → `WRITE_SETTING 6 / NAVIGATE 2 / RESET_SCOPE 1 /
  CLIPBOARD_EXPORT 1 / CLIPBOARD_IMPORT 1 / DIALOG 1 / SHEET 1`（后四类属主题管理页，见 §4）。
- **D2 通过（抽查）**：预览卡 / 字体模式 / 字重 / 字号 / 主题预设 / 恢复默认与 Dart `settings_appearance.dart` 同构。
- **D3 通过**；**D4 通过**（`SettingsAppearancePage` + `ForuiTheme` 由桥/宿主消费）；**D5 通过**。
- **D6 通过**：`SettingsAppearancePageTest` / `SettingsArbParityTest` 断言行 id、选中态、取值，不是「页面能打开」。

### 4. 主题管理（`b.theme`）——**P0 集中区**

- **D1 有缺陷（P0）**：4 处可点的东西没有落点。链路三段全在 HEAD：

  1. 页面模型给了动作（`SettingsAppearancePage.kt:296-314`）：

     ```kotlin
     settingsRow(id = "theme.export",  component = MiuixRowComponent.ARROW,
         title = SettingsStrings.themeExport, action = SettingsAction.CLIPBOARD_EXPORT),
     settingsRow(id = "theme.import",  ..., action = SettingsAction.CLIPBOARD_IMPORT),
     settingsRow(id = "theme.save",    ..., action = SettingsAction.DIALOG),
     ```

     以及「我的主题」逐条行（`:349-361`）：`action = SettingsAction.SHEET`，`trailingActionKind = SettingsAction.SHEET`，
     `trailingActionKey = SettingsStrings.themeMoreActions`。

  2. 渲染层把动作原样转出去（`SettingsPageRenderers.kt` HEAD `320-327`：`val click = row.action?.let { … onAction(action, …) }`）；
     行尾那个「更多操作」**只画文字、没有点击**（HEAD `683-690` `TrailingActionHint` = 纯 `Text`，
     HEAD `396-397` 注释自己写着「点击由宿主按 `trailingActionKind` 接」）。

  3. 宿主把非写动作丢给默认空实现（`SettingsHost.kt:124` `onIntent: (SettingsDispatch) -> Unit = {}`，
     `:313-317` `else -> onIntent(SettingsActionDispatcher.dispatch(kind, target, rowId, model))`），
     而壳 `ShellPageIndex.kt:330-335`（HEAD）**一个宿主都没传 `onIntent`**：

     ```kotlin
     "b.theme" -> SettingsHost(
         pageId = SettingsThemeManagePage.ID,
         store = wiring.settingsModel,
         onBack = onBack,
         onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
     )
     ```

  4. 分派器把动作翻成「意图对象」（`SettingsActionDispatcher.kt:262-289`：`SHEET → ShowSheet`、`DIALOG → ShowDialog`、
     `CLIPBOARD_EXPORT → ClipboardExport`、`CLIPBOARD_IMPORT → ClipboardImport`），**全仓没有消费者**：

     ```text
     $ grep -rn "ShowSheet\|ShowDialog\|ClipboardExport\|ClipboardImport" android/app/src --include=*.kt \
         | grep -v app/SettingsActionDispatcher.kt
     android/app/src/test/kotlin/com/mutx163/qingyu/app/SettingsActionDispatcherTest.kt:51,55,72,73,621
     （仅测试；生产代码 0 命中）
     ```

     `trailingActionKind` 同理：`grep -rn "trailingActionKind" android/app/src/composeP1 android/app/src/test`
     → 生产代码只有 `SettingsPageRenderers.kt:419` 的一行注释，其余全是模型字段与两条测试断言。

  Dart 原件这四个动作都是真功能：`settings_appearance.dart:516`（导出 `onTap: _exportTheme`）、
  `:521`（导入 `_importTheme`）、`:525`（保存 `_showSaveThemeDialog`），成功/失败各有 toast（`:831-863`：
  `themeExportSuccess` / `themeImportSuccess` / `themeImportFailed`）。
- **D2 有缺陷**：控制卡「保存当前主题」按钮（`SettingsPageRenderers.kt` HEAD `959-966` → `settingsRow` …
  `controlCardWiring("themeSaveCurrent") = DIALOG to ROW_THEME_CURRENT_SAVE`）也走同一条空通道 ⇒ 同一类死控件。
  另注：「重置为预设」这条**是通的**（`ROW_THEME_CURRENT_RESET` 在分派器 `:479-489` 有真实现）。
- **D3 通过**（652 条 0 不一致）；**D4 通过**；**D5 通过**。
- **D6 有缺陷（盲区）**：`SettingsRouteWiringGuardTest` 只钉「路由串在 `shellPageIdForRoute` 里有落点」，
  而本页的 4 个死控件一个都不走 NAVIGATE ⇒ 守卫天然看不见。
- 缺陷清单：
  - **P0**｜主题管理页「导出主题 / 导入主题 / 保存当前主题 / 已存主题的更多操作」四处点了没反应
    （`SettingsAppearancePage.kt:296-314`、`:349-361` + `SettingsHost.kt:124,313-317` + 壳未传 `onIntent`）。
    建议修法：壳为 `b.theme` 传 `onIntent`，实现剪贴板导出/导入（`ClipboardManager` + 主题 JSON）与保存主题弹窗；
    行尾按钮要么接 `trailingActionKind`，要么在模型里删掉这个字段以免误导。
  - P1｜「保存当前主题」按钮同样无落点（同上，`SettingsPageRenderers.kt` HEAD `959-966`）。

### 5. 课程卡片（`b.courseCard`）

- **D1 有缺陷（P0 ×1）**：「课表重新配色」行是死控件。`SettingsCourseCardPage.kt:189-197`：

  ```kotlin
  settingsRow(id = "courseCard.recolor", component = MiuixRowComponent.ARROW,
      title = SettingsStrings.courseRecolorTileTitle,
      subtitle = SettingsStrings.courseRecolorTileSubtitle,
      action = SettingsAction.RECOLOR_SHEET),
  ```

  `SettingsHost.kt:281-317` 的 `when` 只有 `WRITE_SETTING` / `NAVIGATE` / `MATERIAL_PANEL` / `RESET_SCOPE` /
  `COLOR_PICKER`，`RECOLOR_SHEET` 落进 `else -> onIntent(...)` = 默认 `{}`；
  `ShowRecolorSheet` 生产代码 0 消费者（同上 grep）。
  Dart 原件 `lib/screens/settings/settings_course_card.dart:300-305` 是 `onTap: () => showCourseRecolorSheet(context)`，
  弹层本体在 `lib/widgets/course_recolor_sheet.dart`。
- **D1 通过（其余行）**：`courseCard.colorChips` 色板**已通**（HEAD `SettingsPageRenderers.kt:855-874` 每个色块
  `.clickable { onAction(WRITE_SETTING, hex, ROW_CARD_COLOR_CHIPS) }`），`MATERIAL_PANEL` 走 `onNavigate`；
  预览槽 `SettingsWeekPreviewSlot` 用仓储真数据（`ShellPageIndex.kt:358-364`）。
- **D2 有缺陷**：除「重新配色」外与 Dart 同构（字段开关 7 个、对齐、字号、统一色、冲突徽标/透明度、四路文字色、恢复默认）。
- **D3 通过**；**D4 通过**；**D5 通过**；**D6 通过**（`SettingsCourseCardPageTest:273` 断言该行 action 为 `RECOLOR_SHEET`——
  但这条断言恰恰把「有一个没人消费的动作值」钉成了绿，属「断言与真实可用性脱节」）。
- 缺陷清单：
  - **P0**｜「课表重新配色」点了没反应（`SettingsCourseCardPage.kt:189-197` + `SettingsHost.kt` 无 `RECOLOR_SHEET` 分支）。
    建议修法：壳传 `onIntent` 处理 `ShowRecolorSheet`（调 `repository` 批量重刷课程色），或先把该行 `enabled = false` 并写缺口。

### 6. 课表页面设置（`b.timetablePage`）

- **D1 通过（有保留）**：`TimetablePageSettingsHost`（`SettingsHost.kt:828-871`）读模型、`WRITE_SETTING` 合并落盘、
  `NAVIGATE` 推页；`ROW_CARD_COLOR_CHIPS` 被显式改写成 `ROW_TP_BG_CHIPS`（`:838-842`），避免「背景色板写成课卡统一色」——
  这条拦截是**故意的且正确**，代价是该色板在**本页**点不动（分派器不拥有背景色）。
- **D1 有缺陷**：`else -> Unit`（`:867`）——本页若有 `SHEET`/`DIALOG` 行则静默丢弃；实际扫本页 spec 只有
  `NAVIGATE`（20 行）+ `WRITE_SETTING`（滑杆/开关），因此**当前无可见死控件**。
- **D2 未验（部分）**：模型注释自述「背景 / 材质 / 字色待扩模型」（`ShellPageIndex.kt:360`），
  本批只接了密度与浮钮不透明度。**本页只审到「行结构 + 写路径」；Dart `settings_timetable_page.dart` 的 11 行密度组、
  背景组、玻璃材质档、字色组未逐行对拍 ⇒ 缺口数量是「按模型自述 3 组」，不是逐项数出来的。**
- **D3 通过**；**D4 通过**；**D5 通过**；**D6 有缺陷**：`SettingsTimetablePageSettingsPageTest` 钉行结构，
  没有任何测试钉「哪几行写进哪个字段」（`ROW_TP_BG_CHIPS` 那条拦截无测试）。
- 缺陷清单：
  - P1｜背景色板在本页点了不动（拦截为正确，但用户看到的是「点了没反应」，且旁边有「壁纸/最近/随周滑动」同组行）。
  - P1｜背景组 / 玻璃材质 / 字色三块未复刻（模型注释自述）。

### 7. 首页与导航 + 两个编辑器（`b.homeNavigation` / `b.homeMenuEditor` / `b.glassDock`）

- **D1 通过**：`HomeNavigationHost`（`SettingsHost.kt:772-811`）写 + 导航 + `RESET_SCOPE` 都有落点；
  `GlassDockEditorHost` / `HomeMenuEditorHost`（`:892-961`）把增/删/移/恢复翻成 `dock.*` / `menu.*` 并 `store.save`，
  空表先回退出厂排列（`:900-904`、`:937-941`）——这条与 Dart 种子口径一致，是本域少见的「边界想到了」。
- **D1 小缺陷**：`HomeNavigationHost:807` 与 `TimetablePageSettingsHost:867` 的 `else -> Unit` 静默吞掉未知动作
  （无日志、无提示），与 `SettingsHost.commitWrite:229-235` 的「Ignored 要落 logcat」口径不一致。
- **D2 通过（抽查）**：导航形态 `"classic"`/`"glassDock"` 词汇翻译在 `SettingsPageBridge.navigationFormToken`（`:117-…`），
  与磁盘值 `glass_dock` 的差异被显式处理。
- **D3 通过**；**D4 通过**（`SettingsPageBridge.toHomeNavigationState` 被宿主调用）；**D5 通过**；**D6 通过**
  （`SettingsHomeNavigationPageTest` / `SettingsGlassDockEditorPageTest` 断言取值与增删语义）。
- 缺陷清单：
  - P2｜两处 `else -> Unit` 静默（`SettingsHost.kt:807`、`:867`），与 Ignored 留痕口径不一致。

### 8. 学期设置（`b.semester`）——本域最扎实的一页

- **D1 通过**：`SettingsSemesterHost.kt:88-92` 订阅仓储；三行 `SHEET/SHEET/RUN_NOW` 分别落到日期滚轮、周数滚轮、
  同步当前周（`:169-186`）；写盘走 `repository.updateSettings` / `setCurrentWeek`，失败 `Toast(saveFailed)`（`:119-123`、`:133-136`、`:145-147`）。
- **D2 通过（逐行对拍 Dart）**：`lib/screens/timetable_settings_screen.dart:696-748` 三行（开学日期三态标题 + 日期行尾；
  周数「{count} 周」；同步当前周「请先设置开学日期」+ `onClick: null` 禁用）与
  `SettingsTimetablePage.kt:336-372` 逐项一致；「改日期后立刻按新日期对齐周次」（Dart `:772-803`）由
  `applyStartDate → syncCurrentWeek(showTip = true)` 复刻，且注释写明「顺序不能反」——`repository.snapshot` 取现值这一处与
  `1813c821` 的修复对得上。
- **D2 一处差异（P2）**：Dart 在 `updateTimetableSettings` 内做 `TimetableSettingsWriter.normalize(...)` 与
  `clampCurrentWeekToSettings`（`lib/providers/timetable_provider.dart:3063-3074`），而
  `app/TimetableRepository.kt:174-178` 的 `updateSettings` 是裸写：

  ```kotlin
  fun updateSettings(settings: TimetableSettings) {
      loadedSettings = settings
      store.saveSettings(settings)
      notifyStateChanged()
  }
  ```

  本页三行改的都是 `semesterStartDate` / `semesterWeekCount`，`sectionConfigChanged` 为 false ⇒ **不会触发**
  Dart 的 `section_count_below_usage` 拦截（我核过 `:3043-3053`），所以本页用户可见行为一致；
  但「写设置不做 normalize」是全局口径差，记 P2 留档。
- **D3 通过**；**D4 通过**；**D5 通过**。
- **D6 通过**：`SemesterSettingsLogicTest` 13 例全是行为断言，例如
  「开学前一律算第 1 周而不是 0 或负数」「超过学期周数钳到末周且不扩学期」「周数改小且当前周超出时才回拨」
  「三行的行 id 与渲染层分派约定逐字一致」。
- 缺陷清单：
  - P2｜`TimetableRepository.updateSettings` 无 Dart 的 normalize/clamp 口径（本页不触发，全局留档）。

### 9. 节假日标记（`b.holiday`）+ 节假日数据更新（`b.holidayAdvanced`）

- **D1 通过**：`SettingsHolidayHost.kt:227-253` 四个动作各有落点（`NAVIGATE` 推页 / 开关 `toggleEnable` /
  「添加假期」按 rowId 认 / 长按 = 删除确认 / 点按 = 编辑）；写盘失败 `notify(saveFailed)` 且**不改进界面**（`:140-148`）。
  数据源 `wiring.holiday` 与月视图/小组件共用（`ShellPageIndex.kt:378-391` HEAD）。
  开关的消费者实测：`calendar/HolidayResolver.kt:25`、`LiveUpdateScheduler.kt:131`、`IcsExportHost.kt:148`
  —— 不是「写完没人读」。
- **D2 通过（抽查）**：自定义假期三态优先级（损坏 > 空 > 列表）在 `SettingsHolidayPage.kt:189-231`，
  与 Dart `:528-571` 同序；「添加假期」前必须预填今天（`:150-157`）避免「保存静默无效」。
- **D3 通过**：`HolidayStringsParityTest` 存在；我的脚本把 `HolidayEditorLogic.kt` 的 `ArbText` 也纳入对拍，0 不一致。
- **D4 通过**：`HolidayEditorLogic.ROW_ENABLE` / `groupIdOfRow` / `initialEditorState` 全被宿主调用。
- **D5 通过**；**D6 通过**（`HolidayEditorLogicTest` 662 行、`SettingsHolidayPageDataTest` 351 行断言归并/代表项/isPast）。
- 缺陷清单：
  - P2｜`deleteCustomHoliday` 对 `groupId == null` 的老条目是空操作（`SettingsHolidayHost.kt:195-211` 注释自述「与 Dart 同病」）
    ——两边同错，按「不自造差异」原则不动是对的，但应进台账。

### 10. 时间模板列表（`d3.timeSchemes`）

- **D1 通过**：`TimeSchemeHost.kt:100-223` 读仓储快照、订阅变更、`TimeSchemeUsageIndexFactory` 构占用索引；
  菜单 7 项各有落点（`dispatch:152-206`）：使用情况 / 编辑节次 / 改名 / 复制 / 应用 / 删除 / 删除被拦，
  成功与失败都有本地化 toast；新建成功后直接进编辑器（`:245-252`，对齐 Dart `_createScheme` 末尾 `_openEditor`）。
- **D1 一处诚实缺口**：分享**没接**——`openMenu` 直接把 `SHARE` 过滤掉（`:146` `filter { it.action != TimeSchemeAction.SHARE }`），
  等于「不给你一个点了没反应的按钮」。这是本域处理死控件最诚实的做法，可作 §4/§5 的修法参考。
- **D2 有缺陷（P1）**：Dart 菜单有分享（`time_scheme_management_screen.dart` 菜单 `:306-345`，share 项），
  Compose 菜单少一项 ⇒ 与 Dart 可见不一致（文档已声明归 I3/C2）。
  抽查其余「已消」项**复核通过**：菜单顺序与 `isUnused` 守卫（`TimeSchemeManagementModel.kt:144-156` 与 Dart 同序）、
  复制默认名「X 副本」（`:213-220` → `copiedSchemeNameTemplate`）、卡片间距 12dp（`TimeSchemeManagementPage.kt:314`）。
- **D3 通过**：`TimeSchemeManagementStrings.kt` / `TimeSchemeServiceMessages.kt` 全 `ArbText`，脚本 0 不一致；
  `TimeSchemeServiceMessagesParityTest` 存在。
- **D4 通过**；**D5 通过**（`-Domain time_scheme` 0 违规）。
- **D6 通过**：`TimeSchemeEditorModelTest` 26 例断言边界（「末节结束时间必须留出五十五分钟余量」「与上一节重叠时整表拒绝并弹服务消息」
  「原本是二十四点且选回零点时保留二十四点」），认领文件还记了两条咬合探针（改回历史 bug ⇒ 红 2 例）。
- 缺陷清单：
  - P1｜分享缺失（`TimeSchemeHost.kt:146` 主动过滤；文档已声明责任批 I3/C2）。

### 11. 时间模板编辑节次（`d3.timeSchemeEditor`）

- **D1 通过**：`TimeSchemeHost.kt:365-466`；`schemeId` 不存在时 `onBack()` 而不是渲染空壳（`:404-409`）；
  保存先 `validateForSave()` 再落盘，失败 `localize(code)` 或 `saveFailed`（`:422-441`）。
- **D2 通过（抽查）**：开始→结束两跳 + `24:00` 哨兵回收（`:481-494`，Dart `resolveSectionEndTimeEdit`）、
  快捷生成失败按服务消息本地化（`:457-465`）。
- **D3 通过**；**D4 通过**；**D5 通过**；**D6 通过**（见 §10）。
- 缺陷清单：无（本页）。

### 12. 存量演示页群：11 个「空构造 state」设置分支（**P0，但非本期交付**）

`ShellPageIndex.kt`（HEAD）逐条列：

```text
336: "b.appearanceEditor"   -> SettingsScreen(SettingsAppearanceEditorPage.spec(SettingsPageState()), onBack)
337: "b.materialGeneral"    -> SettingsScreen(SettingsMaterialGeneralPage.spec(SettingsPageState()), onBack)
338: "b.materialCourseCard" -> SettingsScreen(SettingsMaterialCourseCardPage.spec(SettingsPageState()), onBack)
339: "b.backdropFlow"       -> SettingsScreen(SettingsBackdropFlowPage.settingsPage(BackdropFlowState()), onBack)
340: "b.recentWallpaper"    -> SettingsScreen(SettingsRecentWallpaperSection.spec(RecentWallpaperState()), onBack)
341: "b.bingGallery"        -> SettingsScreen(SettingsBingWallpaperGalleryPage.spec(BingGalleryState()), onBack)
342: "b.homeWidget"         -> SettingsScreen(SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()), onBack)
367-373: "b.live"           -> SettingsPageScreen(spec = SettingsLivePage.spec(SettingsPageState()), …)（仅 NAVIGATE 有落点）
374: "b.liveSelfCheck"      -> SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)
403: "b.glassDockIcon"      -> SettingsScreen(SettingsGlassDockIconEditorPage.spec(SettingsPageState()), onBack)
404: "b.reset"              -> SettingsScreen(SettingsResetPage.spec(SettingsPageState()), onBack)
```

`SettingsScreen` 本体（`ShellPageIndex.kt:1340-1355`）自己的注释就写明「这些页还没接真模型：开关/滑杆等写回仍是 no-op」：

```kotlin
onAction = { _, target, _ -> shellPageIdForRoute(target)?.let(openPage) },
```

- 判据归属：`867f83e8`（「壳里加页面索引入口，75 页在真机点得进去」）引入，**早于**本轮审计窗口，
  壳注释与认领文件均自述「其余设置页仍是演示数据」。按 rubric §0 它不属「2026-10-28~29 动过功能」，
  但按 rubric §4 它是**用户点进去就能发现的死页**，且是设置族里占比最大的一块（11/24）。
- **D6 盲区（关键）**：仓库里已有通用守卫 `DiagnosticsWiringGuardTest`，其 `FORBIDDEN` 已经包含
  `SettingsPageState(\s*)` 这条模式（`android/app/src/test/kotlin/com/mutx163/qingyu/pages/shell/DiagnosticsWiringGuardTest.kt:183`），
  但 `MANAGED` 只登记了 5 个诊断页（`:159-170`），**一个设置页都没有** ⇒ 这 11 条空构造分支不被任何守卫覆盖。
  把其中任意一条加进 `MANAGED`（如 `"b.reset" to "SettingsResetPage"`）就会立刻红——这既是缺陷证据，也是现成的修法。
- 缺陷清单：
  - **P0**｜11 个死页（上表；存量，非本期引入）。
  - P2｜守卫覆盖面缺口：`MANAGED` 未登记设置族（`DiagnosticsWiringGuardTest.kt:159-170`）。

### 13. 地点作息匹配（`d3.locationMatch`，时间模板族的入口）

- **D1 有缺陷（P0）**：`ShellPageIndex.kt`（HEAD）`812-819`：

  ```kotlin
  "d3.locationMatch" -> LocationTimeMatchPage(
      model = LocationTimeMatchModel(),
      onBack = onBack,
      onCreateGroup = {},
      onEditGroup = {},
      onDeleteGroup = {},
      onToggleGroup = { _, _ -> },
      onApplyActive = {},
  )
  ```

  5 个空 lambda + 空构造模型 = 整页死页，而时间模板列表的「地点作息匹配」入口是**能点进去**的
  （`TimeSchemeHost.kt:221` `onOpenLocationEntry`）。审计文档 §五 写明「本轮只保证入口点得动、跳得过去」——
  入口确实通了，进去以后全是死控件。
- 缺陷清单：
  - **P0**｜整页死（`ShellPageIndex.kt:812-819`）；文档已声明责任批 `P35-B2`，但用户侧症状是「点进去什么都不动」。

---

## D1..D6 汇总

| 维度 | 结论 | 证据 |
|---|---|---|
| **D1 接线真实性** | **有缺陷**：真宿主 6 页（general / appearance / semester / holiday×2 / timeScheme×2 / homeNav / courseCard 骨架）确实读仓储并写盘；但主题管理 4 处、课卡重新配色 1 处、`d3.locationMatch` 整页、11 个存量演示页是「点了没反应」 | 见 §4/§5/§12/§13 的 `文件:行号` + 三处 grep（`ShowSheet|ShowDialog|ClipboardExport|ClipboardImport`、`ShowRecolorSheet`、`trailingActionKind` 均只有测试命中） |
| **D2 复刻完整度** | **有缺陷**：学期设置与 Dart 逐行对拍一致；通用页语言/下拉导入「改了不生效」；课卡缺重新配色；课表页面设置缺背景/材质/字色三块；时间模板缺分享 | §2/§5/§6/§10 |
| **D3 文案** | **通过（1 处例外）**：12 个文案文件的 652 条 `ArbText` 与 HEAD `lib/l10n/app_zh.arb` **0 不一致**；例外是 `SettingsWeekPreview.kt` 的 8 条硬编码中文 | 脚本见 §审核方法第 3 条；`SettingsWeekPreview.kt:63`（`listOf("一","二",…,"日")`）、`:144`（`text = "本周没有排课"`）——ARB 里已有 `weekdayShortMonday…Sunday`（`app_zh.arb:1769-1775`），"本周没有排课" 在 ARB 里**不存在**，属自造文案。附 P2：`SettingsStringsExt1/Ext2`（学期设置、桌面小组件等文案）**没有** `*ParityTest`（Ext3/Ext4/Ext5 都有），跑的是我这份临时脚本，不是常驻守卫 |
| **D4 分层** | **通过**：`main: pages/settings` 的 40 个文件逐个扫外部引用，spec 工厂/状态/逻辑件都被渲染层或宿主真调；渲染层零引用的只是页内私有数据类型（`HolidayGroupRow`、`LiveSummary`、`BingGalleryItem` 等，属正常内聚） | 扫描脚本见 §审核方法第 5 条 |
| **D5 样式** | **通过**：`-Domain settings` 0 违规；`-Domain time_scheme` 0 违规 | 两域输出均为「合计：0 条 / 可清」 |
| **D6 测试牙齿** | **部分通过**：有行为断言的页（semester / timeScheme editor / holiday / general / appearance）断言的是取值与边界；缺的是「接线」这一层——`ShellPageDispatchCoverageTest` 只验分支存在、`DiagnosticsWiringGuardTest` 只登记 5 个诊断页、`SettingsRouteWiringGuardTest` 只验 NAVIGATE 路由 | `ShellPageDispatchCoverageTest.kt:74-126`（5 个用例全是「有分支/不重复/有兜底」）；`DiagnosticsWiringGuardTest.kt:159-170`；`SettingsRouteWiringGuardTest.kt:82-93` |

---

## 在途改动（他人，不入判）

基线时刻（HEAD `3f3b7354`）与本域相关的未提交差异，按 `git diff HEAD -- <path>` 逐条：

| 文件 | 差异要点 | 判定影响 |
|---|---|---|
| `composeP1: pages/settings/SettingsPageRenderers.kt` | +106：图标映射扩容（`layers`/`timer`/`favorites`… 共 24 个新名）、行首徽章 28→26dp、`SettingsNodeView` 放宽为 `internal`、新增 `SettingsNodeList`（不带骨架的节点列表，给外观编辑页底部面板用）、`TrailingText` 单行化 | 不入判。**注意**：图标映射与徽章尺寸变更未被任何守卫覆盖（`SettingsIconCoverageGuardTest.kt` 仍是未跟踪新文件） |
| `main: pages/settings/SettingsTimetablePage.kt` | +26：全部是给设置首页行补 `icon = SettingsRowIcon(...)`（`layers`/`timer`/`favorites`/`gridView`/`months`/`cloudFill`/`alarm`/`home`/`theme`/`sidebar`/`tune`/`convertFile`/`backup`/`link`/`favoritesFill`/`info`/`notes`/`report`/`background`/`stopwatch`/`listView`/`show`），零行为改动 | 不入判 |
| `main: pages/ShellPageIndex.kt` | 任务族重构（`d2.taskList` 抽成 `TaskListHost`、新增 `pendingEditWeek`、删 `shellSampleTaskViewState`）；**设置分支无改动** | 不入判（本报告一律引 HEAD 行号） |
| 未跟踪新文件（本域相关） | `main: pages/settings/AppearanceEditorState.kt`、`test: pages/settings/SettingsIconCoverageGuardTest.kt` | 不入判 |

**另需提醒 Lead 的一条仓库卫生问题**：索引里存着一份「把节假日支持整体删掉」的暂存内容，
与工作区/HEAD 都不一致：

```text
$ git diff --cached --stat
 .../app/IcsExportHost.kt                        | 485 --------------------
 .../pages/settings/SettingsPageRenderers.kt     | 239 +---------
 .../app/SettingsActionDispatcher.kt             |  12 -
 .../pages/ShellPageIndex.kt                     |  28 +-
 .../pages/export/IcsEventCollection.kt          | 417 ------------------
 .../pages/settings/SettingsPageModel.kt         |  68 ---
 .../test/.../SettingsActionDispatcherTest.kt    |  19 -
 .../test/.../IcsEventCollectionTest.kt          | 490 ---------------------
 .../test/.../SettingsSpecTestSupport.kt         |   8 +-
 9 files changed, 45 insertions(+), 1721 deletions(-)

$ git show :android/app/src/main/kotlin/com/mutx163/qingyu/app/SettingsActionDispatcher.kt | grep -c ROW_HOLIDAY_ENABLE
0        # 索引里没有
$ git show HEAD:…/SettingsActionDispatcher.kt | grep -c ROW_HOLIDAY_ENABLE
2        # HEAD 有；工作区同 HEAD
```

任何人此刻直接 `git commit`（不带路径）会把这份回退提交上去。我没有动索引（只读审核）。

---

## 缺陷清单总表（可数，P0 4 / P1 8 / P2 6）

| 级 | # | 缺陷 | 位置 | 证据强度 |
|---|---|---|---|---|
| P0 | 1 | 主题管理页 导出/导入/保存当前主题/已存主题更多操作 4 处点了没反应 | `SettingsAppearancePage.kt:296-314`、`:349-361` + `SettingsHost.kt:124,313-317` + `ShellPageIndex.kt:330-335` | 强（三段链路 + 0 消费者 grep + Dart 对照） |
| P0 | 2 | 课卡「课表重新配色」点了没反应 | `SettingsCourseCardPage.kt:189-197` + `SettingsHost.kt:281-317` | 强（同上） |
| P0 | 3 | 11 个设置分支空构造 state（存量）+ `SettingsScreen` 只做路由 | `ShellPageIndex.kt:336-344,367-374,403-404` + `:1340-1355` | 强（源码逐行） |
| P0 | 4 | `d3.locationMatch` 整页演示数据（5 空 lambda） | `ShellPageIndex.kt:812-819` | 强（源码逐行） |
| P1 | 1 | 设置首页 `timetable.debugOverlay` / `timetable.debugPanel` 无落点 | `SettingsSemesterHost.kt:406-413` + `SettingsTimetablePage.kt:542-556` | 强 |
| P1 | 2 | 语言下拉选了不生效（`appLocaleTag` 无读者） | `SettingsGeneralPage.kt:51-58` | 强（grep 全仓） |
| P1 | 3 | 首页下拉快捷导入开关无读者 | `SettingsGeneralPage.kt:84-91` | 强（grep 0 命中） |
| P1 | 4 | 设置模型落盘失败不可感知（提示分支死） | `KeyValueStore.kt:58-67` + `PrefsKeyValueStore.kt:90-92` + `SettingsHost.kt:207-247` | 强（签名 + Dart 对照） |
| P1 | 5 | 主题管理页控制卡「保存当前主题」按钮无落点 | `SettingsPageRenderers.kt` HEAD `959-966` → `SettingsHost.kt:313-317` | 强 |
| P1 | 6 | 课表页面设置背景色板点了不动（拦截正确但症状同死控件） | `SettingsHost.kt:837-857` | 中（拦截意图有注释；未真机验） |
| P1 | 7 | 课表页面设置缺背景/材质/字色三组 | `ShellPageIndex.kt:360` 注释 + 模型 | 中（**证据待补**：未逐行对拍 Dart） |
| P1 | 8 | 时间模板分享缺失（菜单主动过滤，Dart 有） | `TimeSchemeHost.kt:146` | 强（源码 + Dart `:306-345`） |
| P2 | 1 | 两处 `else -> Unit` 静默吞未知动作，与 Ignored 要落 logcat 的口径不一致 | `SettingsHost.kt:807`、`:867` | 强 |
| P2 | 2 | `TimetableRepository.updateSettings` 无 Dart 的 normalize/clamp 口径 | `TimetableRepository.kt:174-178` vs `timetable_provider.dart:3063-3074` | 强 |
| P2 | 3 | `deleteCustomHoliday` 对 `groupId==null` 老条目空操作（与 Dart 同病） | `SettingsHolidayHost.kt:195-211` | 强（注释自述） |
| P2 | 4 | 守卫覆盖面缺口：`MANAGED` 未登记设置族（`FORBIDDEN` 已有对应模式） | `DiagnosticsWiringGuardTest.kt:159-170`、`:183` | 强 |
| P2 | 5 | `SettingsRowRenderTable` 是死契约表：引用的 `SettingsRenderContractTest` 不存在、符号是已删的 `extra.Super*` | `SettingsRowRenderTable.kt:8-13`、`:59-90` | 强（grep） |
| P2 | 6 | `SettingsStringsExt1/Ext2` 无 `*ParityTest`（Ext3/4/5 都有） | `test: pages/settings/` 目录清单 | 强（ls） |

---

## 我没能验的

1. **真机逐页对照**：本会话没有设备，也不允许控制设备。所有「点得动 / 点不动」的结论都是从「壳 → 宿主 → 分派器 → 消费者」
   代码链推出来的，**没有一次真机点击**。要确认 §12 的 11 个死页与 §4/§5 的死控件，需用户按
   `docs/plans/2026-10-27-compose-phase3-l4-checklist.md` 在 `dev` 壳里点一遍。
2. **L0/L1/L2 是否绿**：受硬约束，没跑 Gradle、没跑 `test-kotlin-module.ps1`。认领文件声称
   「L0 129 例 / L2 4983 例 / L1 SUCCESSFUL」，我**只在源码层复核了对应测试是否存在、断言是否钉行为**，没有独立复跑。
3. **写盘/回显的真机验证**：`SharedPreferences.commit()` 失败（磁盘满、只读）这类场景无法构造，
   「落盘失败提示是死分支」是从签名与 `commit()` 返回值被丢弃推出的，没有制造过真实失败。
4. **时间模板「应用到当前课表」的最终效果**：`repository.applyTimeScheme` 的仓储实现与课表镜像同步我没逐行读
   （超本域范围，属 `TimetableRepository` 与课表族）。
5. **`b.timetablePage` 背景/材质/字色三块的 Dart 逐项差异**：只核到「模型注释自述待扩模型」，没逐行对拍
   `settings_timetable_page.dart` 的 11 行密度组与材质档。
6. **样式审计的像素级口径**：D5 只跑机械 lint（0 违规），没做与 `hyperos_tokens.dart` 的逐值对拍。

---

## 审核方法（跑了哪些命令、扫了哪些文件、多少行）

1. **读判据 + 认领**：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`（70 行）、`team_task_get("task-2")` → `claim`。
2. **基线钉死**：`git status --porcelain`、`git diff HEAD --stat`、`git diff --cached --stat`；
   本域所有未提交文件一律 `git show HEAD:<path>` 取内容（`SettingsPageRenderers.kt` 976 行、
   `ShellPageIndex.kt` 1513 行、`SettingsTimetablePage.kt`）。
3. **文案逐字对拍（652 条）**：Python 扫 12 个文案文件（`SettingsStrings.kt`、`Ext1..Ext5`、
   `TimeSchemeManagementStrings.kt`、`TimeSchemeServiceMessages.kt`、`TimeSchemeEditorModel.kt`、
   `TimeSchemeManagementModel.kt`、`SemesterSettingsLogic.kt`、`HolidayEditorLogic.kt`）里所有
   `ArbText("key", "value")`，与 `git show HEAD:lib/l10n/app_zh.arb` 的 JSON 逐值比对：

   ```text
   文件数 12 比对条目 652 不一致 0
   ```

4. **中文字面量**：读 `test/.../i18n/cjk-literal-baseline.txt`（26 行）与 `CjkLiteralGateTest`；
   本域内只有 `settings/SettingsWeekPreview.kt:8`、`settings/SettingsRowRenderTable.kt:1` 两条在基线里，
   逐条回源码确认（前者 8 条上屏、后者 1 条是 `error()` 文案不上屏）。
5. **分层（D4）**：Python 扫 `main: pages/settings` 40 个文件的所有顶层声明，
   在 `android/app/src/**/*.kt`（排除 test）里统计**声明文件之外**的引用，输出「外部零引用」清单（见 §D4）。
6. **接线（D1）**：通读 `composeP1: app/SettingsHost.kt`（961 行）、`SettingsSemesterHost.kt`（414 行）、
   `SettingsHolidayHost.kt`（674 行）、`SettingsHolidayAdvancedHost.kt`（115 行）、`TimeSchemeHost.kt`（628 行）、
   `SettingsPageRenderers.kt`（HEAD 976 行）、`SettingsRowRenderTable.kt`（137 行）、
   `ShellPageIndex.kt` 设置段（HEAD 293-406、780-820、1340-1355）；三处 grep 确认动作消费者：
   `ShowSheet|ShowDialog|ClipboardExport|ClipboardImport`、`ShowRecolorSheet|recolor`、`trailingActionKind`。
7. **Dart 对照**：`lib/screens/settings/settings_general.dart`（读盘/失败提示 `:95-163`）、
   `settings_appearance.dart`（主题管理 `:431-560`、导出导入 toast `:831-863`）、
   `settings_course_card.dart:296-305`、`lib/screens/timetable_settings_screen.dart:679-865`（学期设置三行 + 两个 pick 处理）、
   `lib/providers/timetable_provider.dart:3036-3074`（`updateTimetableSettings` 的拦截与 normalize）、
   `lib/widgets/timetable_week_preview.dart`（无「本周没有排课」这句）。
8. **样式（D5）**：`pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain settings` → `合计：0 条`；
   同命令 `-Domain time_scheme` → `合计：0 条`。
9. **测试（D6）**：读 `SettingsArbParityTest`（95 行）、`SettingsRouteWiringGuardTest`（94 行）、
   `DiagnosticsWiringGuardTest`（`MANAGED`/`FORBIDDEN`/`BRANCH`）、`ShellPageDispatchCoverageTest`（用例名 5 条）、
   `SemesterSettingsLogicTest`（13 例名）、`TimeSchemeEditorModelTest`（26 例名）、
   `SettingsCourseCardPageTest:273`、`CjkLiteralGateTest`。
10. **既有文档复核**：`docs/plans/2026-10-29-compose-general-page-audit.md`（57 行）、
    `docs/plans/2026-10-29-compose-time-scheme-audit.md`（184 行）、
    `.agents/compose-phase3/claims/P35-settings-host.md`（176 行）、`P35-settings-dead-controls.md`（137 行）、
    `P35-TS-parity.md`（70 行）——凡引用处均回源码复核，结果见下。

### 与既有审核文档不一致的地方（4 条）

1. **`docs/plans/2026-10-29-compose-general-page-audit.md:18`** 把「写盘失败**完全静默**（Dart 会提示并把草稿拉回真值）」
   记为**改之前**的缺陷，但 §二/§三既没说修了、也没说没修。源码复核：**仍在**——设置模型这条写路径
   `SettingsHost.kt:207-239` 的 `store.save(result.model)` 返回 `Unit`，`KeyValueStore.putX`
   （`app/KeyValueStore.kt:58-67` + `platform/PrefsKeyValueStore.kt:90-92`）丢弃 `commit()` 返回值 ⇒ 提示分支不可达。
   （该文档 §二.5 说的「自动更新落盘失败会保留旧值并记日志」是真的：`CourseAutoRefreshStore.saveSchedule:60-64` 有 read-back 校验。）
2. **`.agents/compose-phase3/claims/P35-settings-host.md`（诚实清单第 2 条）** 写「`themeHasModifications` 恒 `false`
   ⇒ 主题管理页『基于 X 已修改』徽标不出现」。源码复核：**已修**——
   `SettingsPageBridge.kt:202` `val themeHasModifications = SettingsActionDispatcher.hasThemeModifications(model)`，
   `:233` 喂进 state，`:400` 用于 `selected` 判定。认领文件过期。
3. **`.agents/compose-phase3/claims/P35-settings-dead-controls.md`** 把「保存当前主题」记为
   「`themeSaveCurrent` → `DIALOG` + `ROW_THEME_CURRENT_SAVE`（对话框本体属宿主/页面层）」，读起来像已接。
   源码复核：**宿主与壳都没有这个对话框**，`ShowDialog` 生产代码 0 消费者 ⇒ 按钮仍是死控件（§4 P0）。
4. **`composeP1: pages/settings/SettingsRowRenderTable.kt:8-13`** 写「由 `SettingsRenderContractTest` 逐项断言，两个方向都钉住」。
   `grep -rn "SettingsRenderContractTest" --include=*.kt .` → **只命中这句注释本身**（外加一份 2026-10-27 的旧审计文档），
   该类不存在；`all` / `rendering()` / `miuixSymbols` 在 `android/app/src` 里 0 调用点，
   且表里写的还是 0.9.4 已删除的 `extra.SuperArrow` 等符号（`:24`、`:59-90`），而渲染层实际 import 的是
   `top.yukonga.miuix.kmp.preference.ArrowPreference`（`SettingsPageRenderers.kt` HEAD `63-68`）。

---

# 二轮验真（HEAD `bf0e5a57`）

> 方法：一轮报告的每条缺陷在当前 HEAD + 工作树上**回源码重新定位**。
> 他人未提交文件（`SettingsPageRenderers.kt` / `SettingsTimetablePage.kt`）只读不判；
> 6116529c（外观编辑页重做）已顺手改掉的条目单独标注。

## 一、逐条状态表

| # | 一轮的缺陷 | 状态 | 证据 / 反证 |
|---|---|---|---|
| **P0-1** | 主题管理页 导出 / 导入 / 保存当前主题 / 已存主题「更多操作」四处点了没反应 | **已修（本轮，未提交）** | 根因三段仍在：`SettingsAppearancePage.kt:296-324`（动作值）、`SettingsActionDispatcher.kt:312-330`（翻成意图）、`SettingsHost.kt` 旧 `onIntent = {}`。修法见 §修复 1 |
| **P0-2** | 课卡「课表重新配色」点了没反应 | **部分修（本轮）** | 意图已被消费（有反馈、不再静默），但**没有真正配色**：完整复刻要 Dart 479 行弹层 + `course_recolor_history_service.dart` + 调色板，且需要 `TimetableRepository.courses` 写入口（本批写作用域外）⇒ 仍存在，见 §壳接线请求 R2 |
| **P0-3** | 11 个设置分支喂 `SettingsPageState()` 空构造 | **5 条已修（6116529c，他人）**；**5 条他人泳道在修（F06）**；**1 条无人认领** | 6116529c 把 `b.appearanceEditor` / `b.materialGeneral` / `b.materialCourseCard` / `b.backdropFlow` / `b.recentWallpaper` 改成 `AppearanceEditorHost`（HEAD `ShellPageIndex.kt:353-391`）。剩余空构造：`b.bingGallery:392`、`b.homeWidget:393`、`b.live:419`、`b.liveSelfCheck:425`、`b.glassDockIcon:454`、`b.reset:455`。其中 **`b.bingGallery` 不在 Lead 给的 F06 名单里** ⇒ 漏项，见 §壳接线请求 R3 |
| **P0-4** | `d3.locationMatch` 整页演示数据（5 空 lambda） | **仍存在** | `ShellPageIndex.kt:900-908`（HEAD）：`LocationTimeMatchPage(model = LocationTimeMatchModel(), … onCreateGroup = {}, …)`。`LocationTimeMatch*` 与壳分支都**不在本批写作用域** ⇒ 见 R4 |
| **P1-1** | 设置首页 `timetable.debugOverlay` / `timetable.debugPanel` 无落点 | **仍存在** | `SettingsTimetableHubHost`（`composeP1: app/SettingsSemesterHost.kt:406-413`）只认 `NAVIGATE`；该文件不在本批写作用域 ⇒ 见 R5 |
| **P1-2** | 语言下拉选了不生效（`appLocaleTag` 0 读者） | **仍存在** | `grep -rn appLocaleTag android/app/src --include=*.kt \| grep -v /test/`：生产侧仍只有 `PerformanceSettingsSnapshot.kt:183` 读它 ⇒ 壳缺 `setApplicationLocales`，见 R1 |
| **P1-3** | 首页下拉快捷导入开关无读者 | **仍存在** | `grep -rn homePullQuickImportEnabled` 仍只有模型/分派器自身 ⇒ 壳没有下拉手势，见 R1 |
| **P1-4** | 设置模型落盘失败不可感知（提示分支是死代码） | **已修（本轮，未提交）** | `SettingsActionDispatcher.persistLanded(before, after, disk)` + 宿主 `saveVerified` 读回校验 + 滑杆防抖失败回调；根因（`PrefsKeyValueStore.kt:90-92` 丢 `commit()` 返回值）仍在，但**宿主已能感知**。测试 `SettingsThemeConfigTest` 3 例 |
| **P1-5** | 控制卡「保存当前主题」按钮无落点 | **已修（本轮）** | `handleIntent` 现在认 `ROW_THEME_CURRENT_SAVE` **与** `SettingsThemeManagePage.ROW_SAVE_CURRENT`（新常量）两个 rowId |
| **P1-6** | 课表页面设置背景色板点了不动 | **仍存在** | 卡在数据层：`TimetableSettingsModel` 里**没有** `timetablePageBackgroundColor` 这个键（`grep -n BackgroundColor TimetableSettingsModel.kt` → 0 命中），所以 `ROW_TP_BG_CHIPS` 只能 Ignored ⇒ 见 R6 |
| **P1-7** | 课表页面设置缺背景 / 材质 / 字色三组 | **仍存在（未逐项数）** | 模型注释仍自述「背景/材质/字色待扩模型」；6116529c 扩的是**外观编辑页**的材质/壁纸 18 键，不是本页的这三组。**本页只验到「行结构 + 写路径」，三组的逐项差异未对拍** |
| **P1-8** | 时间模板分享缺失（菜单主动过滤） | **仍存在** | `TimeSchemeHost.kt:146` `filter { it.action != TimeSchemeAction.SHARE }`；`app/TimeSchemeHost.kt` 不在本批写作用域 ⇒ 见 R7 |
| **P1-新** | 已存主题行的四个色点**永远是空的** | **已修（本轮）** | 新发现：`SettingsPageBridge.kt:405-416` 拿**长键**（`seedColor`/`courseCardTitleColorLight`…）去读 `themeData`，而那是 `ThemeConfig.toJson` 的**短键**（`seed`/`ccl`/`cdl`/`wbl`/`wal`）⇒ 恒空。改成短键 |
| **P2-1** | 两处 `else -> Unit` 静默 | **已修（本轮）** | `HomeNavigationHost` / `TimetablePageSettingsHost` 的兜底分支改成 `Log.w`，并把 `when` 改成 `when (val kind = …)`（原来那两处 `kind` 没绑定） |
| **P2-2** | `TimetableRepository.updateSettings` 无 Dart 的 normalize/clamp | **仍存在** | `app/TimetableRepository.kt:174-178` 未变；该文件不在本批写作用域 ⇒ R8 |
| **P2-3** | `deleteCustomHoliday` 对 `groupId==null` 老条目空操作 | **仍存在** | `app/SettingsHolidayHost.kt:195-211` 未变（与 Dart 同病，注释已自述）；该文件不在本批写作用域 ⇒ R9 |
| **P2-4** | 守卫没覆盖设置分支（`MANAGED` 只 5 个诊断页） | **部分修（本轮）** | 新增 `SettingsHostIntentWiringGuardTest`（钉「动作通道」：默认值不许回空实现、五类意图必须有分支、分派器必须有那 10 个入口）。**空构造分支**的守卫仍未加（`test/pages/shell/**` 超范围，且 F06 正在改那 6 条）⇒ R10 |
| **P2-5** | `SettingsRowRenderTable` 死契约表（引用的测试不存在） | **已修（本轮）** | 删掉 `Requirement` / `Rendering` / `all` / `rendering()` / `miuixSymbols` 与那张 `extra.Super*` 表，KDoc 改成「哪些是真在用的」；`SettingsSharedParityTest` 断言的四条子串全部保留（已逐条核对） |
| **P2-6** | `SettingsStringsExt1/Ext2` 无 parity 测试 | **Ext2 = 误判；Ext1 = 已修（本轮）** | **反证**：`SettingsStringsExt2.all()`（`:235`）+ `SettingsHomeWidgetPageStringsParityTest.的文案表逐条等于 ARB` 早已存在 ⇒ 一轮那条对 Ext2 判错。Ext1 确实没有（60 条），本轮补 `SettingsStringsExt1ParityTest`（反射读全部 `ArbText` getter，含条数下限防空跑） |
| **D3-1** | `SettingsWeekPreview.kt:63/144` 硬编码中文 | **已修（本轮）** | 星期短名改走 `SettingsStrings.weekdayShort*`（ARB 早有这七个键）；空态改走 `dayViewEmptyTitle`（"暂无课程"，**不新增 ARB 键**）。修完该文件中文字面量 **8 → 0** |

计数：**已修（本轮）7 条 + 已修（他人 6116529c）5 条 + 部分修 2 条 + 仍存在 9 条 + 误判 1 条（Ext2）+ 他人泳道在修 5 条。**

## 二、修复（本轮改了什么，全是未提交状态）

| 文件 | 改动 | 为什么 |
|---|---|---|
| `composeP1: app/SettingsHost.kt` | **+599 行**：`onIntent` 默认值 `{}` → `null`；新增 `deliverIntent` / `handleIntent` / `exportTheme` / `importTheme` / `runSavedThemeAction` / `commitModel`（读回校验）；新增 `SettingsThemeDialogHost`（保存/重命名/删除/动作表四形态）、`SettingsNoticeDialog`（含撤销）；四处写路径改走 `saveVerified` | P0-1 只有这个宿主能修（壳不许改）；P1-4 写失败要能感知 |
| `main: app/SettingsActionDispatcher.kt` | **+177 行**：`THEME_CONFIG_VERSION`、`ROW_SAVED_THEME_PREFIX`、`SAVED_THEME_KEY_*`、`themeConfigOf`、`applyThemeConfig`、`themeConfigIsUsable`、`saveTheme`、`applySavedTheme`、`renameSavedTheme`、`duplicateSavedTheme`、`deleteSavedTheme`、`savedThemeIdOf`、`persistLanded` | 主题配置与已存主题 CRUD 全是**纯逻辑**，放分派器才能在 L0 上被钉住（与既有风格一致） |
| `main: pages/settings/SettingsStrings.kt` | +37 行、13 个句柄（`themeExportSuccess` / `themeImportSuccess` / `themeImportFailed` / `themeApply` / `themeDelete` / `themeRename` / `themeDuplicate` / `themeDuplicateCopyName` / `themeDeleteConfirmMessage` / `themeNameHint` / `themeChanged` / `themeUndo` / `weekdayShortMon..Sun` / `weekPreviewEmpty`） | **全部照抄既有 ARB 值**（脚本复核 680 条 0 不一致），**未动 ARB** |
| `main: pages/settings/SettingsAppearancePage.kt` | +常量 `ROW_EXPORT` / `ROW_IMPORT` / `ROW_SAVE_CURRENT`，spec 改用常量 | 宿主按 rowId 认「保存当前主题」这一行，id 必须有唯一出处 |
| `main: pages/settings/SettingsPageBridge.kt` | `previewColorsOf` 改短键 | P1-新（色点恒空） |
| `composeP1: pages/settings/SettingsWeekPreview.kt` | 星期名/空态改走 ARB | D3-1 |
| `composeP1: pages/settings/SettingsRowRenderTable.kt` | 删死契约表，只留 4 个真在用的函数 | P2-5 |
| `test: pages/settings/SettingsThemeConfigTest.kt`（新，18 例） | 导出键表/版本号、v2 必填校验、导入写回、导出→导入往返、保存/应用/重命名/复制/删除、id 前缀解析、`persistLanded` 三种情形 | P0-1 + P1-4 的行为断言 |
| `test: pages/settings/SettingsHostIntentWiringGuardTest.kt`（新，4 例） | 默认值不许回 `= {}`、五类意图必须有分支、不许再有 `else -> onIntent(`、分派器必须有那 10 个入口 | P2-4 |
| `test: pages/settings/SettingsStringsExt1ParityTest.kt`（新，3 例） | Ext1 逐条等于 ARB（反射，含 ≥40 条下限） | P2-6 |

**还要麻烦你（我改不了的三件事，按优先级）**

1. 🔴 **必做，否则 L2 会红**：删掉 `android/app/src/test/kotlin/com/mutx163/qingyu/i18n/cjk-literal-baseline.txt` 里这两行
   （棘轮「过期必红」）：
   ```
   com/mutx163/qingyu/pages/settings/SettingsWeekPreview.kt:8
   com/mutx163/qingyu/pages/settings/SettingsRowRenderTable.kt:1
   ```
   实测现在这两个文件的中文字面量都是 **0**（`SettingsHost.kt` 也是 0）。
2. `SettingsRowRenderTable.kt` 我删了死代码，`SettingsSharedParityTest` 依赖的 4 条子串（`0xFF2563EB` / `fun colorFromHex(` / `trim()` / `startsWith("#")` / `length != 6` / `fun trailingText(` / `row.details ?: row.value`）**我逐条核过仍在**，不用动测试。
3. L0 我按纪律没跑。请跑 `-Module "pages/settings"` 并带上 `app/SettingsPageBridge.kt`、`app/SettingsActionDispatcherTest.kt` 那两个 ExtraSources（与既有跑法一致）。

## 三、壳接线请求（我写不了壳，按价值排序）

> **对 P0-1 来说：0 条。** 主题管理页四处动作现在全在宿主内消费，`b.theme` 分支**一个字都不用改**——
> 这正是 Lead 要的「理想是 0 条」。

**R1（P1-2 / P1-3，同一件事，属壳层能力）**
语言下拉与首页下拉导入都是「写了没人读」。最小闭环各一处：
```kotlin
// 1) 语言：PagesShellActivity / Application 里，设置变化后应用 locale
//    Dart 对应 `setLocale`；Kotlin 侧建议 androidx.appcompat 的 per-app language：
val tag = wiring.settingsModel.load().appLocaleTag      // "" = 跟随系统
AppCompatDelegate.setApplicationLocales(
    if (tag.isBlank()) LocaleListCompat.getEmptyLocaleList() else LocaleListCompat.forLanguageTags(tag)
)
// 2) 首页下拉快捷导入：TimetableWeekPage 加 pull-to-refresh，
//    读 wiring.settingsModel.load().homePullQuickImportEnabled 决定是否触发导入。
```

**R2（P0-2 课卡「重新配色」，要真跑得先扩数据入口）**

现状：点了会弹「课表重新配色 / 不可用」，**不再静默**；真配色没做。要真跑，宿主要一个课程写入口：

```kotlin
// 1) SettingsHost 增一个可选入参（消费端我已写好，只差数据）：
recolorCourses: ((List<String>) -> Unit)? = null,

// 2) 壳（ShellPageIndex.kt 的 b.courseCard 分支）多传一行：
"b.courseCard" -> SettingsHost(
    pageId = SettingsCourseCardPage.ID, store = wiring.settingsModel, onBack = onBack,
    onNavigate = { route -> shellPageIdForRoute(route)?.let(onOpenPage) },
    preview = { SettingsWeekPreviewSlot(wiring) },
    recolorCourses = { colors -> /* wiring.timetable.recolorAllCourses(colors) —— 需新入口 */ },
)

// 3) 数据层：TimetableRepository 加 recolorAllCourses(colors)，写 courses 的 color 字段。
```

> 真正的弹层（颜色组 / 换一批 / 上一套·下一套配色历史 + 首次换色前的原色快照）在 Dart 是
> `lib/widgets/course_recolor_sheet.dart`(479 行) + `lib/services/course_recolor_history_service.dart`，
> 建议单开一批，不要塞进设置族收口。

**R3（P0-3 漏项：`b.bingGallery`，F06 名单里没有它）**

```kotlin
// ShellPageIndex.kt HEAD:392 现在还是空构造：
"b.bingGallery" -> SettingsScreen(SettingsBingWallpaperGalleryPage.spec(BingGalleryState()), onBack)
// 需真宿主：读壁纸服务图集 + 4 个动作（挑图 / 应用 / 收藏 / 预览），
// 数据与动作清单见 pages/settings/SettingsBingWallpaperGalleryPage.kt 的 BingGalleryState。
```

**R4（P0-4 `d3.locationMatch` 死页）**

```kotlin
// ShellPageIndex.kt HEAD:900-908 五个空 lambda；需新建
// composeP1: app/LocationTimeMatchHost.kt（读 repository.locationTimeGroups，
// 动作落 saveLocationTimeGroups）+ LocationTimeMatchModel 接真数据。
```

**R5（P1-1 设置首页开发者工具两行）**

```kotlin
// composeP1: app/SettingsSemesterHost.kt 里 SettingsTimetableHubHost 的 onAction（HEAD:406-413）
onAction = { action, target, rowId ->
    when (action) {
        SettingsAction.NAVIGATE -> target?.let(onNavigate)
        SettingsAction.WRITE_SETTING ->
            if (rowId == "timetable.debugOverlay") { /* 写 wiring.debugOverlayVisible */ } else Unit
        SettingsAction.DIALOG ->
            if (rowId == "timetable.debugPanel") { /* 打开调试叠层面板 */ } else Unit
        else -> Unit
    }
}
```

**R6（P1-6 课表页面设置背景色板）**

```kotlin
// main: app/TimetableSettingsModel.kt 加一个键（Dart ThemeConfig 短键 `bg`）：
val timetablePageBackgroundColor: String = DEFAULT_TIMETABLE_BACKGROUND_COLOR,
// 之后 SettingsActionDispatcher 的 ROW_TP_BG_CHIPS 分支就能真写（常量与注释已在 dispatcher 里备好）。
```

**R7 / R8 / R9（都不在本批写作用域）**

- **R7（P1-8）** 时间模板分享：`TimeSchemeHost.kt:146` 主动过滤 `SHARE`；真做要传输包 + `FileProvider`（I3/C2）。
- **R8（P2-2）** `TimetableRepository.updateSettings` 补 Dart 的 `TimetableSettingsWriter.normalize` + `clampCurrentWeekToSettings`。
- **R9（P2-3）** 节假日 `deleteCustomHoliday` 的 `groupId == null` 桶（与 Dart 同病，建议进台账，不单边修）。

**R10（P2-4 守卫补口，`test/pages/shell/**` 不在我写作用域）**

```kotlin
// DiagnosticsWiringGuardTest 的 MANAGED 追加（F06 落地后就不会红）：
"b.theme" to "SettingsHost",
"b.general" to "SettingsHost",
"b.appearance" to "SettingsHost",
"b.courseCard" to "SettingsHost",
"b.semester" to "SettingsSemesterHost",
"b.holiday" to "SettingsHolidayHost",
"b.holidayAdvanced" to "SettingsHolidayAdvancedHost",
```

## 四、ARB 新增请求

**0 条必需。** 本轮用到的键全部已存在于 `app_zh.arb`，Kotlin 侧只是补句柄（值逐字照抄，
脚本复核 `SettingsStrings*.kt` 680 条 0 不一致）。

可选（只影响一句提示的措辞，不加也能跑）：

| 键 | 建议值 | 用在哪 |
|---|---|---|
| `courseRecolorUnavailable` | 「换配色还没随壳迁移，暂时改不了颜色」 | 课卡「重新配色」的说明框正文现在用 `aboutUnavailable`（"不可用"），偏短 |

## 五、本轮自检清单（交给你的复核点）

1. 🔴 `cjk-literal-baseline.txt` 删两行（§二 第 1 条），否则 `CjkLiteralGateTest` 因「过期必红」失败。
2. `SettingsHost` 的 `onIntent` 形参类型从 `(SettingsDispatch) -> Unit` 变成 `((SettingsDispatch) -> Unit)?`
   —— **壳没有一处传它**，所以零调用点需要改；`SettingsHostIntentWiringGuardTest` 钉住了这一点。
3. 我在 `SettingsHost.kt` 里新增了 `internal` 的 `ThemeDialogMode` / `ThemeRowAction` / `ThemeDialogState` /
   `SettingsNotice` / `SettingsThemeDialogHost` / `themeEntryId`，都在同一个文件里，没有新文件、没有新依赖。
4. 行为断言集中在 `SettingsThemeConfigTest`（18 例）与 `SettingsStringsExt1ParityTest`（3 例）；
   接线断言在 `SettingsHostIntentWiringGuardTest`（4 例）。按纪律我**没有跑** L0，请你统一跑。
5. 本轮**没碰**：`ShellPageIndex.kt` / `ShellWiring.kt` / `ShellPageCatalog.kt` / `build.gradle` /
   `AndroidManifest.xml` / `theme/` / 壳 Activity / `SettingsPageRenderers.kt` / `SettingsTimetablePage.kt` /
   `course/**` / `guide/**` / `shell/ShellPageDispatchCoverageTest.kt`。
