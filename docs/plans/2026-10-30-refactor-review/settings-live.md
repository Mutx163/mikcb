# 设置/时间模板/节假日/实时活动 · 近期重构独立审核（2026-10-30）

- 审核人：独立审核员 `review-settings-live`（对实施者自述文档一律不信，全部回源码复核）
- 审核基线：`git rev-parse HEAD` = `d6c925ba414616163c1c4f007ec6566e2fafa294`
- 审核时刻：2026-10-30 11:10–11:40（Asia/Shanghai）
- 判定口径：**只认 HEAD 已提交快照**。工作区此刻有 139 项改动（`git status --short | wc -l` = 139），其中 `ShellPageIndex.kt` / `ShellWiring.kt` / `SettingsHost.kt` / `SettingsActionDispatcher.kt` 等正被另一会话实时修改；这些在途改动一律标注「在途，非已提交交付」，**不计入本次判定**。
- 取证方式：`git show HEAD:<path>` 取快照后 grep/read；命令与真实输出见各条证据。
- 禁跑项：未跑 Gradle（L1/L2），未跑 `scripts/test-kotlin-module.ps1`，未跑真机；只跑了只读 `scripts/compose-style-lint.ps1 -Domain settings`。

---

## 结论

**一句话：5 条既有声明全部属实（其中第 4 条还超出声明——壳内另有 2 条未点名的分支同样喂空构造 state）；近期重构在「实时活动显示 + 提醒时段」和「时间模板 / 节假日」上确实落地了，但「主题管理 + 课卡重新配色」在 HEAD 上仍是全仓 0 消费者的死动作。**

| 既有声明 | 复核结论 | 证据位置 |
|---|---|---|
| 1. F01 实时活动显示 3 路由 + 提醒时机改了退出即还原 | **通过**（真宿主 + 读盘 + 写补丁 + 离开补写，均有落点） | 见 §A |
| 2. F01 收尾：超限提示上限与生效上限同常量（`3b38a8ff`） | **通过**（`LiveImagePickLogic.MAX_BYTES` 单一出处） | 见 §B |
| 3. 主题管理 4 处 + 课卡「重新配色」点了没反应 | **属实**——HEAD 上确实仍是全仓 0 消费者（`SettingsHost.onIntent` 默认空 `{}`、壳不传） | 见 §C |
| 4. 11 个设置分支喂空 state，`b.live`/`b.liveSelfCheck`/`b.glassDockIcon`/`b.reset` 四条仍是空构造 | **属实**（壳内 `SettingsPageState()` 共 7 处命中、其中 4 处是活代码）；另有 `b.bingGallery`/`b.homeWidget` 两条声明未点名但也空构造 | 见 §D |
| 5. 时间模板两页、节假日两页已接真宿主 | **通过** | 见 §E |

**P0 缺陷 7 条 / P1 3 条 / P2 4 条**（明细见「缺陷清单」）。

> 新增一条跨声明发现：F01 的「选图失败 / 勿扰不可用」两句提示在 HEAD 的 `DisplaySettingsStrings.kt` 里存在，但 **HEAD 的 `app_zh.arb` 没有这两个键**（`liveImagePickFailed`、`liveDoNotDisturbAccessUnavailable`），且 Dart 原件里根本没有这两句 —— 属 Compose 自造的用户可见文案，同时让 `DisplaySettingsStringsParityTest` 在 HEAD 上红。详见 §A 的 D3 与缺陷清单 P1-1。

---

## 逐页 D1..D6 + 证据

### A. 实时活动显示与提醒（`j.live` / `j.displayBefore` / `j.displayDuring` / `j.reminderTiming` / `j.keepAlive`）

**D1 接线真实性：通过。**

命令与输出：

```
$ grep -n "j.live\|j.displayBefore\|j.displayDuring\|j.reminderTiming\|j.keepAlive" \
    /tmp/head/android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
1501:        "j.live" -> LiveDisplayHost(forDuringEnd = false, onBack = onBack)
1502:        "j.displayBefore" -> LiveDisplayHost(forDuringEnd = false, onBack = onBack)
1503:        "j.displayDuring" -> LiveDisplayHost(forDuringEnd = true, onBack = onBack)
1505:        "j.reminderTiming" -> LiveReminderTimingHost(onBack = onBack)
1512:        "j.keepAlive" -> {
```

- 3 条显示路由共用 `LiveDisplayHost`，`forDuringEnd` 区分两档键组；提醒路由用 `LiveReminderTimingHost`。**没有 `emptyList()` / `= {}` / 空 state**。
- `LiveDisplayHost.kt:82-85`（HEAD）：
  ```kotlin
  var state by remember(store, forDuringEnd) { mutableStateOf(store.loadDisplay(forDuringEnd)) }
  ```
  不再是 `remember { mutableStateOf(initialState) }`——初值来自真快照。
- `LiveDisplayHost.kt:95-105`：`LaunchedEffect(version)` 做 250ms 防抖 `saveDisplay`；`DisposableEffect` 在 `onDispose` 里 `if (version > 0) store.saveDisplay(...)`——**改过才写，没改一个字节都不写**（对应声明 1 的「退出即还原」已修）。
- `LiveDisplayHost.kt:195-213`：`LiveReminderTimingHost` 同样 `store.loadReminderTiming()` → `store.saveReminderTiming()`，`onPersist` 真落点。
- 守卫 `LiveWiringGuardTest.kt` 读源码文本钉住「四条 j 路由必须调真宿主、宿主必须读+写、三个曾空实现的回调必须真落点、不许 `= {}`」。

**D2 功能复刻：通过（抽查）。** Dart `lib/screens/live_settings_subpages.dart` 的 `_updateDraft` 250ms 防抖 + `dispose` 补写，与宿主口径逐条对齐（`LiveDisplayHost.kt:59-67` 注释逐条给出 Dart 行号）。两档键组 `liveDuringEnd*` / `live*` 不串写由 `LiveDisplayStoreTest` 钉住。

**D3 文案：有缺陷（1 处）。** 选图失败提示走 `DisplaySettingsStrings.imagePickFailed.zh`（`LiveDisplayHost.kt:233-236`，注释自述「2026-10-29 质量审核发现该句绕过了 i18n 层」后已改）；勿扰不可用走 `doNotDisturbAccessUnavailable.zh`；超限提示走 `ImportStrings.importFileTooLarge.filled(...)`。渲染层 CJK 只剩注释（见「审核方法」的扫描）。

但**这两句的 ARB 键在 HEAD 的 `app_zh.arb` 里不存在**：

```
$ git show HEAD:lib/l10n/app_zh.arb | grep -n "liveImage\|liveDoNot"
（无输出，exit 1）

$ git show HEAD:lib/l10n/app_zh.arb | grep -c '": "'
4089

$ grep -c "liveImagePickFailed\|liveDoNotDisturbAccessUnavailable" lib/l10n/app_zh.arb   # 工作区
2
```

- HEAD `DisplaySettingsStrings.kt:181-185` 定义了 `ArbText("liveImagePickFailed", ...)` 与 `ArbText("liveDoNotDisturbAccessUnavailable", ...)`，且两者都在 `allTexts`（`:188-190`）里。
- HEAD `DisplaySettingsStringsParityTest.每一处屏上文案都与 app_zh_arb 逐字一致` 会断言 `arbMap[item.key] != null`（`:20-23`）⇒ **HEAD 上这条测试红**。
- Dart 原件里两句都不存在（`git grep "图片读取失败" HEAD -- lib/` 与 `git grep "这台设备没有" HEAD -- lib/` 均 0 命中）；Dart `_pickAndStoreImage`（`live_settings_subpages.dart:1309-1364`）在非超限失败时**静默 return null，不弹提示**；Dart 的勿扰入口用的是 `guideStatusDoNotDisturbAccess`。⇒ 这是 Compose 自造的用户可见文案（D2 自造行为）。
- 工作区 `app_zh.arb` 已补上这两个键（`git diff --stat` = +13 行），属**在途修复，非已提交交付**。

**D3 棘轮一致性（机械复算）**：用仓库自己的 `scripts/i18n-cjk-baseline.py` 的 `count_line()`（从该脚本 import，保证规则逐字一致）扫 HEAD 的完整 composeP1 树，与 HEAD 基线比对：

```
$ python <复算脚本>   # 规则 import 自 scripts/i18n-cjk-baseline.py
HEAD scan total: 190 files: 24
HEAD baseline total: 186 files: 23
=== HEAD-scan files NOT in baseline ===
  NEW com/mutx163/qingyu/pages/exam/ExamPickerSheets.kt 4
=== 过期 / 超基线 ===
（无）
```

- 本域（设置/实时活动/天气/引导/展示）的 8 个有 CJK 的文件**全部落在基线内且不超**：`MiuixShowcaseSubpages.kt:73`、`HyperosShowcasePage.kt:12`、`SettingsWeekPreview.kt:8`、`MiuixShowcasePage.kt:7`、`StartupFlowPage.kt:6`、`MoreFeaturesPage.kt:1`、`MoreFeaturesSearchOverlay.kt:1`、`SettingsRowRenderTable.kt:1`。
- 唯一「新增未登记」的是 `pages/exam/ExamPickerSheets.kt:4`——**考试域，不在本次审核范围**；但这意味着 HEAD 上 `CjkLiteralGateTest.渲染层中文字面量不高于棘轮基线` 会红（基线没登记该文件）。作为跨域观察记录，不计入本域缺陷。
- 顺带：工作区的 `cjk-literal-baseline.txt` 正被另一会话改动（`git diff` 显示删掉了 6 行），属在途，不计入。

**D3 键存在性（机械复算，补充）**：对本域 6 个 main 源集目录的 strings 文件，解析 `ArbText("key", ...)` 与 `ArbText(<const>, ...)`，与 HEAD ARB 比对：

```
$ python <arb_check2.py>
key references checked: 1164
missing ARB key: 2
  MISS ('DisplaySettingsStrings.kt', 'liveImagePickFailed')
  MISS ('DisplaySettingsStrings.kt', 'liveDoNotDisturbAccessUnavailable')
```

即除上述两句外，本域其余 1162 处键引用都能在 HEAD ARB 找到，且 0 处值不一致。

**D4 分层：通过。** `LiveDisplayStore` / `LiveImagePickLogic` / `ReminderTimingModel` 均被宿主真调。

**D5 样式：通过。** `pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain settings` → `=== settings ：0 处 === 干净`。

**D6 测试牙齿：通过。** `LiveDisplayStoreTest.kt` 26 例（空盘默认值 / 往返 / 不越界 / 两档不串 / 键名逐字对拍 / 坏值回退）；`LiveImagePickLogicTest.kt` 11 例（超限先于读、恰好等于上限算通过等）。

---

### B. 超限提示上限常量（`3b38a8ff`）

**复核：通过。**

```
$ git show --stat --oneline 3b38a8ff
3b38a8ff F01 审核收尾：超限提示里的上限改成与生效上限同一常量
 .../src/composeP1/kotlin/com/mutx163/qingyu/app/LiveDisplayHost.kt    | 4 +++-
 1 file changed, 3 insertions(+), 1 deletion(-)
```

- `LiveDisplayHost.kt:157-161`：`ImportSharedModel.formatByteBudget(LiveImagePickLogic.MAX_BYTES)`（提示文案用这个常量）
- `LiveDisplayHost.kt:253`：`ExternalImportReader.readCapped(input, LiveImagePickLogic.MAX_BYTES)`（真正限长读也用同一个常量）
- `LiveImagePickLogic.kt:29`：`const val MAX_BYTES: Long = 20L * 1024 * 1024`

三处同一出处，声明成立。

---

### C. 主题管理 4 处 + 课卡「重新配色」（声明 3：声称仍未修）

**复核：声明成立，HEAD 上确实未修，且我未发现任何生产代码消费者。判 D1 有缺陷（P0）。**

命令与输出：

```
$ grep -n "onIntent" /tmp/head/android/app/src/composeP1/kotlin/com/mutx163/qingyu/app/SettingsHost.kt
114: * @param onIntent 其余界面意图（弹层 / 剪贴板 / 恢复默认确认 / RUN_NOW 等），由壳执行。
124:    onIntent: (SettingsDispatch) -> Unit = {},          ← 默认空实现
236:                onIntent(result)
297:                    current == null -> onIntent(
314:            else -> onIntent(

$ grep -n "onIntent" /tmp/head/android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
（无输出）                                              ← 壳一处都没传

$ grep -rn "ShowRecolorSheet" /tmp/head/android/app/src --include=*.kt | grep -v "/test/"
.../app/SettingsActionDispatcher.kt:92:    data class ShowRecolorSheet(val rowId: String) : SettingsDispatch
.../app/SettingsActionDispatcher.kt:322:        SettingsActionKind.RECOLOR_SHEET -> SettingsDispatch.ShowRecolorSheet(rowId)
.../app/AppearanceEditorHost.kt:232:            // ShowSheet / ShowDialog / ShowColorPicker / ShowMaterialPanel / ShowRecolorSheet /
（仅定义 + 注释，0 消费者）
```

- 主题管理页三行：`SettingsAppearancePage.kt:299-313`（HEAD）给出 `CLIPBOARD_EXPORT` / `CLIPBOARD_IMPORT` / `DIALOG`（导出 / 导入 / 保存当前主题），已存主题「更多操作」走 `SHEET`（`:357`、`:360`）。
- 分派器把它们翻成 `ClipboardExport` / `ClipboardImport` / `ShowDialog` / `ShowSheet`（`SettingsActionDispatcher.kt:312-330`）。
- 宿主 `SettingsHost.kt:284-317`（HEAD）的 `when` 无这些分支，落到 `else -> onIntent(...)`；`onIntent` 默认 `{}`，壳不传 ⇒ **点了完全没反应**。
- 课卡重新配色：`SettingsCourseCardPage.kt:191-195`（HEAD）`action = SettingsAction.RECOLOR_SHEET`；分派器翻成 `ShowRecolorSheet`；全仓 0 消费者 ⇒ 点了没反应。Dart `lib/screens/settings/settings_course_card.dart:300-305` 是 `onTap: () => showCourseRecolorSheet(context)`。

> 备注：工作区在途的 `SettingsHost.kt` 已出现 `handleIntent` / `deliverIntent` / `SettingsThemeDialogHost` / `notice` 等实现（`git diff` 显示 +581/-27 行），但那是**在途改动，非已提交交付**，不计入判定。

---

### D. 壳内空构造 state 分支（声明 4）

**复核：声明属实，且我复核出壳内另有 2 条声明未点名的空构造分支。**

命令与输出：

```
$ grep -n "SettingsPageState()" /tmp/head/android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
355:        // `SettingsScreen(SettingsAppearanceEditorPage.spec(SettingsPageState()))`——传**空构造的   ← 注释
425:            spec = SettingsLivePage.spec(SettingsPageState()),
431:        "b.liveSelfCheck" -> SettingsScreen(SettingsLiveSelfCheckPage.spec(SettingsPageState()), onBack)
432:        // 2026-10-29 节假日两页接真宿主（此前是 `SettingsScreen(SettingsHolidayPage.spec(SettingsPageState()))`：  ← 注释
451:        // 2026-10-29 接真宿主：原先 `SettingsScreen(SettingsDiagnosticsPage.spec(SettingsPageState()), onBack)`  ← 注释
460:        "b.glassDockIcon" -> SettingsScreen(SettingsGlassDockIconEditorPage.spec(SettingsPageState()), onBack)
461:        "b.reset" -> SettingsScreen(SettingsResetPage.spec(SettingsPageState()), onBack)

$ grep -c "SettingsPageState()" /tmp/head/android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
7
```

- **7 处命中 = 4 处活代码 + 3 处注释**。4 条活分支与声明一致：`b.live`(:425)、`b.liveSelfCheck`(:431)、`b.glassDockIcon`(:460)、`b.reset`(:461)。
- **声明未点名的 2 条**（同样是空构造，只是 state 类型不同）：
  - `:398` `"b.bingGallery" -> SettingsScreen(SettingsBingWallpaperGalleryPage.spec(BingGalleryState()), onBack)`
  - `:399` `"b.homeWidget" -> SettingsScreen(SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()), onBack)`

逐条后果：

| 分支 | 可达性 | 喂入 | 后果 | 级别 |
|---|---|---|---|---|
| `b.live` :425 | 可达（`liveSettings` → `b.live`；`/settings/live`） | `SettingsPageState()` + spec 内 `LivePageData()` 默认值 | 两行摘要恒为默认「…等 3 项」，不是真设置 | P0 回显不对 |
| `b.liveSelfCheck` :431 | 可达（`/settings/live/self-check`） | `SettingsPageState()` + `LiveSelfCheckData()` 默认值 | 自检页恒为静态假诊断（服务未运行 / 无日志） | P0 假数据 |
| `b.glassDockIcon` :460 | 可达（`ROUTE_GLASS_DOCK_ICON` → `b.glassDockIcon`） | `SettingsPageState()` + `IconPickerState()`（`names = emptyList()`） | 图标清单恒空，选择无落点 | P0 空页 |
| `b.reset` :461 | 仅开发目录 / 深链 | `SettingsPageState()` | 迁移期对照页，非 Dart 原件界面 | P2 |
| `b.bingGallery` :398 | 入口目标未映射 | `BingGalleryState()`（`loading = true`） | 恒「加载中」；且导航目标 `bingWallpaperGallery` 壳里无映射 | P0 |
| `b.homeWidget` :399 | 可达（`homeWidgetSettings`、`/settings/home-widget`） | `SettingsHomeWidgetState()` | 6 个开关恒默认值、写了不落盘 | P0 |

**D1 有缺陷（6 条空构造分支，其中 5 条用户可达）。**

补充证据：

```
$ grep -rn "bingWallpaperGallery" /tmp/head/android/app/src --include=*.kt | grep -v "/test/"
.../settings/SettingsBackdropFlowPage.kt:182:    const val BING_GALLERY_TARGET = "bingWallpaperGallery"
（壳的 shellPageIdForRoute / shellTimetableMenuPageId 两张表里都没有这一串）
```

```
$ grep -rn "IconPickerState" /tmp/head/android/app/src --include=*.kt | grep -v "/test/"
（只出现在 SettingsGlassDockIconEditorPage.kt 自身；composeP1 渲染层 0 引用）
```

---

### E. 时间模板两页 + 节假日两页（声明 5）

**复核：通过。**

- 时间模板：
  ```
  $ grep -n "d3.timeSchemes\|d3.timeSchemeEditor\|d3.locationMatch" \
      /tmp/head/android/app/src/main/kotlin/com/mutx163/qingyu/pages/ShellPageIndex.kt
  820:        "d3.timeSchemes" -> TimeSchemeManagementHost(repository = wiring.timetable, ...)
  833:        "d3.timeSchemeEditor" -> { ... TimeSchemeEditorHost(repository = wiring.timetable, schemeId = editingId, ...) }
  855:        "d3.locationMatch" -> { ... LocationTimeMatchHost(groups = snapshot.locationTimeGroups, ...) }
  ```
  `TimeSchemeManagementHost` 订阅仓储快照、写入口落 `TimetableRepository`；`TimeSchemeEditorHost` 同样。`TimeSchemeManagementModelTest.kt` 45 例、`TimeSchemeEditorModelTest.kt` 钉行为。
- 节假日：
  ```
  435:        "b.holiday" -> SettingsHolidayHost(provider = wiring.holiday, store = wiring.settingsModel, ...)
  441:        "b.holidayAdvanced" -> SettingsHolidayAdvancedHost(provider = wiring.holiday, onBack = onBack)
  ```
  `SettingsHolidayHost` 订阅 `HolidayProvider` + `store`，开关/增删改都落盘并给失败提示；`SettingsHolidayAdvancedHost` 的「检查更新」真调 `provider.refresh()`。`HolidayEditorLogicTest.kt` 55 例。

**D2 抽查**：节假日的「添加假期」起止日期预填今天（`SettingsHolidayHost.kt:150-154`），与 Dart `:586-589` 一致；删除走 `removeCustomHoliday(groupId)`（`:184-195`）。日期滚轮用三列 `NumberPicker`（官方无 DatePicker），宿主注释已声明为已知差异。

**D3 抽查**：`holidayCheckUpdate` / `customHolidayEdit` / `customHolidayAdd` / `pleaseSetSemesterStartDate` / `saveFailed` / `aboutUnavailable` / `datePickerYear|Month|Day` / `cancelAction` / `confirmAction` / `deleteAction` 在 `lib/l10n/app_zh.arb` 全部存在且逐字一致（见「审核方法」的键存在性检查输出）。

**D4 抽查**：`HolidayEditorLogic` 被宿主真调（`initialEditorState` / `expandEntries` / `validateName` / `pickerRange` …）。

---

### F. 天气 / 引导 / 展示

- **天气**：`b.weather -> WeatherSettingsHost(provider = weatherProvider, store = wiring.settingsModel, ...)`；`j.weatherCity -> WeatherCityPickerHost(provider = weatherProvider, ...)`。真宿主，读 provider + 设置模型。**D1/D4 通过。**
- **引导**：`i.userGuide` 分支（`ShellPageIndex.kt:1433-1475`）读 `GuidePermissionProbe` 平台真值 + `GuideSettingsMapping.snapshotFrom(wiring.settingsModel.load())`，写回 `wiring.settingsModel.save(next)`，并监听 `ON_RESUME` 重探。`i.startup -> StartupFlowHost(repository = wiring.timetable, ...)`。**D1 通过。**
- **展示**：`i.hyperosShowcase -> HyperosShowcasePage(onBack)`、`i2.showcase -> MiuixShowcasePage(onBack)`。属静态展示册，无数据依赖。
- **全部功能**：`i.more -> MoreFeaturesWithSearch(...)`、`i.moreSearch -> MoreFeaturesSearchOverlay(...)`，39 行经 `shellTimetableMenuPageId` 跳页；`MoreFeaturesNavigationGuardTest` 钉住表与目录一致。

---

### G. 设置族其余页（对照，非本次声明对象）

- `b.general` / `b.appearance` / `b.theme` / `b.courseCard` → `SettingsHost`（store 真接，但 `onIntent` 空默认 ⇒ 见 §C）。
- `b.semester` / `b.settingsHome` → `SettingsSemesterHost` / `SettingsTimetableHubHost`（真仓储）。
- `b.appearanceEditor` / `b.material*` / `b.backdropFlow` / `b.recentWallpaper` → `AppearanceEditorHost`（真 store + repository）。
- `b.homeNavigation` / `b.homeMenuEditor` / `b.glassDock` / `b.diagnostics` → 各自真宿主。
- **D5**：`-Domain settings` → 0 违规。

---

## 缺陷清单

### P0（用户点进去就发现坏了/骗人）

1. **主题管理页 4 处可点的东西点了完全没反应**——导出主题 / 导入主题 / 保存当前主题 / 已存主题「更多操作」。
   证据：`SettingsHost.kt:124` `onIntent: (SettingsDispatch) -> Unit = {}`；`ShellPageIndex.kt` 无 `onIntent` 传参；`SettingsAppearancePage.kt:299-313,357,360` 给出 `CLIPBOARD_EXPORT`/`CLIPBOARD_IMPORT`/`DIALOG`/`SHEET`；`SettingsActionDispatcher.kt:312-330` 翻成 `ClipboardExport`/`ClipboardImport`/`ShowDialog`/`ShowSheet`；全仓 0 消费者。

2. **课卡「课表重新配色」点了没反应**。
   证据：`SettingsCourseCardPage.kt:191-195` `action = SettingsAction.RECOLOR_SHEET`；`SettingsActionDispatcher.kt:322` → `ShowRecolorSheet`；`grep ShowRecolorSheet` 仅定义 + 注释，0 消费者。Dart `settings_course_card.dart:300-305` 是真 `showCourseRecolorSheet`。

3. **`b.live` 入口页两行摘要回显错误**（恒默认值，不是真设置）。
   证据：`ShellPageIndex.kt:425` `spec = SettingsLivePage.spec(SettingsPageState())`；`SettingsLivePage.kt:51` `data: LivePageData = LivePageData()` 默认；Dart `settings_live.dart:59-68` 从 `context.read<TimetableProvider>().settings` 读真值。

4. **`b.liveSelfCheck` 自检页恒为静态假诊断**（无真宿主，`LiveSelfCheckData()` 全默认）。
   证据：`ShellPageIndex.kt:431`。

5. **`b.glassDockIcon` 图标挑选页无真宿主**——`IconPickerState()` 的 `names = emptyList()`，且 composeP1 渲染层 0 引用 `IconPickerState`，选择无落点。
   证据：`ShellPageIndex.kt:460`；`SettingsGlassDockIconEditorPage.kt:230-234`。

6. **`b.homeWidget` 桌面小组件设置页喂空 state**——6 个开关恒默认值、写了不落盘。
   证据：`ShellPageIndex.kt:399`；`SettingsHomeWidgetPage.kt:105` `fun spec(state: SettingsHomeWidgetState)`。

7. **`b.bingGallery` Bing 壁纸画廊恒「加载中」+ 导航目标无映射**。
   证据：`ShellPageIndex.kt:398` `BingGalleryState()`（`loading = true`）；`SettingsBackdropFlowPage.kt:182` `BING_GALLERY_TARGET = "bingWallpaperGallery"`；壳两张路由表均无此串。

### P1（与 Dart 原版可见不一致）

8. **`DisplaySettingsStrings` 的两句用户可见提示在 HEAD 的 ARB 里没有键，且 Dart 原件根本没有这两句**（Compose 自造文案）。
   - `liveImagePickFailed`（"图片读取失败，请换一张再试"，选图失败 Toast）与 `liveDoNotDisturbAccessUnavailable`（"这台设备没有勿扰权限设置页，请到系统设置里手动授权"，系统页打不开时的 Toast）。
   - 证据：`DisplaySettingsStrings.kt:181-185`（HEAD）定义，`:188-190` 都在 `allTexts`；`git show HEAD:lib/l10n/app_zh.arb | grep "liveImage\|liveDoNot"` **0 命中**（HEAD ARB 共 4089 键）；`DisplaySettingsStringsParityTest.kt:20-23` 断言 `arbMap[item.key] != null` ⇒ **HEAD 上该测试红**。
   - Dart 侧：`git grep "图片读取失败" HEAD -- lib/` 与 `git grep "这台设备没有" HEAD -- lib/` 均 0 命中；Dart `_pickAndStoreImage`（`live_settings_subpages.dart:1309-1364`）在非超限失败时静默 `return null`；Dart 勿扰入口用 `guideStatusDoNotDisturbAccess`。
   - 工作区 `app_zh.arb` 已补键（+13 行）⇒ 在途修复，非已提交交付。

9. **`b.reset` 独立分派分支是迁移期对照页，非 Dart 原件界面**——Dart `settings_reset.dart` 产的是五张设置页页尾的「恢复默认」白卡，不是独立页。该分支用户正常流程不可达（仅开发目录 / 深链），但出现在壳分派里且喂空 state。
   证据：`ShellPageIndex.kt:461`；`SettingsResetPage.kt:5-13`（文件头自述「Dart 文件不产一页独立界面」）；`ShellPageCatalog.kt:166` 标 `DEMO`。

10. **`b.bingGallery` 的入口「更多壁纸」点了没反应**（导航目标 `bingWallpaperGallery` 未在 `shellPageIdForRoute` / `shellTimetableMenuPageId` 登记）。与 P0-7 同源，单列以便追踪。
    证据：见 P0-7。

### P2（内部债）

11. **壳内 4 条空构造分支（`b.live` / `b.liveSelfCheck` / `b.glassDockIcon` / `b.reset`）没有任何守卫看管**。
    证据：`DiagnosticsWiringGuardTest.kt` 的 `FORBIDDEN` 已含 `SettingsPageState()` 模式（`:211`），但 `MANAGED`（`:176-205`）只登记诊断族等 9 页，未含这 4 条 ⇒ 守卫不会红。`SettingsBatchCoverageTest.kt` 只验 spec 能构造，不验接线。

12. **主题管理 / 课卡重新配色的动作没有测试钉「必须有消费者」**。
    证据：`SettingsActionDispatcherTest.kt` 只测分派器本身；没有测试断言 `ClipboardExport` / `ShowDialog` / `ShowSheet` / `ShowRecolorSheet` 在壳或宿主有落点。

13. **5 个模型层 public 件在渲染层（composeP1）0 直接引用**（均由 main 壳/模型胶水消费，非死代码，但按判据记录）：
    `GuideSettingsMapping`、`StartupFlowPreferences`、`SettingsCourseCardPage`、`SettingsHomeWidgetPage`、`SettingsStringsExt5`。
    证据：见「审核方法」的引用扫描输出。

14. **（跨域观察，不计入本域缺陷）HEAD 的 `CjkLiteralGateTest` 会因 `pages/exam/ExamPickerSheets.kt:4` 未登记而红**——该文件是考试域，不在本域范围；但 HEAD 基线未登记它，说明「新增渲染层文件必须同步基线」这条没被守住。

---

## 我没能验的

1. **编译与单测未验**：按硬规矩未跑 Gradle（L1/L2）、未跑 `scripts/test-kotlin-module.ps1`。因此「HEAD 能否编译通过」「上述守卫在真实 L2 下是否全绿」均**未验**。D5 只跑了只读 lint。
2. **真机未验（L4）**：所有「点了有没有反应」的结论来自源码接线推断 + 守卫/单测源码，**没有真机点击证据**。这是本次审核最大的证据缺口。
3. **工作区在途改动未纳入**：`ShellPageIndex.kt` / `ShellWiring.kt` / `SettingsHost.kt` / `SettingsActionDispatcher.kt` 等正被另一会话修改。§C（主题/重新配色）在途已出现 `handleIntent` 实现，但那是未提交交付，不计入。
4. **Dart 逐行 1:1 未做**：D2 只抽查了实时活动、节假日、天气、引导的关键路径；未对设置族 24 屏逐行比对。
5. **文案对拍做了机械复算，但没跑测试本体**：未跑 `SettingsArbParityTest` / `DisplaySettingsStringsParityTest`（禁跑 L2）。我改为直接解析 HEAD 的 strings 文件与 `app_zh.arb` 做键存在性 + 逐字比对（1164 处键引用，见 §A 的 D3）。`SettingsArbParityTest` 覆盖的「占位符片段比对」逻辑我未复算。
6. **`SettingsHomeWidgetState` 默认值已读到**：定义在 `SettingsP3B2States.kt:28-58`（`backgroundStyle = "solid"`、`courseAccentMode = "bar_and_text"`、`showLocation = true`、`showCountdown = true`、`hideCompletedCourses = false`、`showTomorrowCourses = true` …）。故 P0-6「6 个开关恒默认值」有逐字段依据；但「写了不落盘」仍是从「壳没接 store」推断，未真机验证。

---

## 审核方法

1. `git rev-parse HEAD`、`git status --short | wc -l`（139）、`git log --oneline -25` 建立基线。
2. `git archive HEAD android/app/src | tar -x -C <临时目录>` 取 **HEAD 完整 `android/app/src` 快照树**（995 个 `.kt`），另用 `git show HEAD:<path>` 取 `lib/l10n/app_zh.arb`、`cjk-literal-baseline.txt` 等。**所有判定基于该快照，不碰工作区。**（临时目录在 `%TEMP%\head`，不在仓库内。）
3. 对每条声明做定向 grep + 原文片段（≤15 行）取证，命令与输出原样贴在证据块里。
4. D5：`pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain settings` → `0 处 / 干净`。
5. D3 两条独立机械复算：
   - **渲染层 CJK 棘轮**：import 仓库自己的 `scripts/i18n-cjk-baseline.py` 的 `count_line()`（保证规则逐字一致），扫 HEAD 完整 composeP1 树，与 HEAD `cjk-literal-baseline.txt` 比对 → 本域 8 个文件全部在基线内；唯一新增未登记的是跨域的 `pages/exam/ExamPickerSheets.kt:4`。
   - **ARB 键存在性 + 逐字**：解析本域 6 个 main 源集目录的 strings 文件里所有 `ArbText("key", ...)` / `ArbText(<const>, ...)`，与 HEAD `app_zh.arb` 比对 → 1164 处引用、2 处缺键（`liveImagePickFailed`、`liveDoNotDisturbAccessUnavailable`）、0 处值不一致。脚本放在 `%TEMP%`，不写仓库。
6. D4：把 composeP1 全部 `.kt` 拼成一个文本，对每个模型层文件的顶层声明名做包含匹配，筛出 0 引用件。
7. D6：列各域测试文件与 `fun \`...\`` 方法名，判断断言是否钉行为（而非只验构造）。
8. 既有声明逐条对照源码；复核不上的写「未验」并说明原因，不写「看起来没问题」。

> 局限：本次未运行任何编译/测试，所有「能点」「落点」结论均为静态接线推断。要把它变成硬证据，需要 L1/L2 或真机点击（用户侧）。
