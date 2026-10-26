# Compose Phase 3 开工准备（Miuix 版本 / 主题桥 / 族7核对）

> 结论一句话：P1 验证壳维持 Miuix 0.8.8 不动，0.9.4 升级单独立项并先解 Kotlin 2.4 与 minSdk 口径；主题桥按本文对照表逐项搬色板与字阶；族7数据面原生侧已就绪、Phase 3 只需接 Miuix 展示层，无已知缺口（方法级细对留待开工）。
>
> 状态：准备文档（s2-prep 泳道）。只写本文件，不动任何代码与构建配置。不碰真机，不提交，由 Lead 评审合入。
> 依据注法：`路径:行号` 均为本次实读行；拿不准的一律标「未验 / 待定」，不猜。
> 上游规格：`docs/plans/2026-10-26-compose-migration-spec.md`（执行方式/验收/红线）、
> `docs/plans/2026-10-26-compose-miuix-components.md`（选型 0.9.4）、
> `docs/plans/2026-10-26-compose-phase2-families.md` 第 2 节（状态架构）与第 3 节族 7 行。

## 0. 前置口径（防踩线）

- 数据与构建红线只归 Lead：泳道不碰 `storage/`、契约、applicationId/签名/versionCode/组件类名
 （`2026-10-26-compose-migration-spec.md:21-23,47-53`；族泳道纪律 `2026-10-26-compose-phase2-families.md:68-69`）。
- Phase 3 范围是 UI 层约 12.3 万行、按页面分批、每批真机截图对照
 （`2026-10-26-compose-migration-spec.md:28-29,43-44`）；官方 Miuix 有的直接用、自绘须说明官方无对应物
 （同文件 `:45,:61-62`）。
- 本文档读的 `android/app/build.gradle` 仅只读核对版本，不做任何修改。

---

## ① Miuix 版本统一：0.8.8（壳锁定） vs 0.9.4（选型）

### 1.1 两边各是什么（实读）

| 项 | 0.8.8（验证壳锁定） | 0.9.4（选型文档） |
|---|---|---|
| 坐标 | `top.yukonga.miuix.kmp:miuix-android:0.8.8`，见 `android/app/build.gradle:256-257`（`composeP1Implementation`，注释在 `:253-255`） | `miuix-ui 0.9.4（2026-09-20）`，见 `docs/plans/2026-10-26-compose-miuix-components.md:4`；Maven 多模块形态见同文件 `:11-13`（miuix-ui / -preference / -icons / -blur / -squircle / -nav / -window / -shader） |
| 锁定理由 | 注释原文：`0.9.x 由 Kotlin 2.4.x 元数据编译，主工程 Kotlin 2.2.20 读不了`（`android/app/build.gradle:254-255`）；主工程 Kotlin 版本见 `android/settings.gradle:33`（`org.jetbrains.kotlin.android version 2.2.20`，compose 插件同版本 `:35-36`） | 结论有效性与上游版本绑定，0.x 实验库 API 可能无通知变更，Phase 3 开工前重验（同文件 `:4-5,:51`：`锁定 0.9.4 起步，升级单独评估`） |
| minSdk 口径 | 壳：`composeP1` flavor `minSdk 33`（`android/app/build.gradle:144-146`，注释点名 miuix-blur 硬性要求）；默认 `minSdk = 26`（同文件 `:49`）保持不动 | 选型文档写「本仓已拍板 minSdk 33 → miuix-blur 可直接用」（`docs/plans/2026-10-26-compose-miuix-components.md:14`）——与当前 build.gradle「仅 P1 为 33、prod 仍 26」不一致，见下 1.3 |

### 1.2 差异核对（能定的定，定不了的标未验）

| 维度 | 已验结论 | 依据 |
|---|---|---|
| 编译器 | 0.8.8 可在 Kotlin 2.2.20 下编译（P1 壳现状）；0.9.x 需要 Kotlin 2.4.x 元数据，2.2.20 读不了，升级 = 先升 Kotlin | `android/app/build.gradle:253-257` + `android/settings.gradle:33,35-36` |
| 运行隔离 | Compose runtime 只进 `composeP1` classpath，其余变体用 `compileOnly` 垫片避 `IncompatibleComposeRuntimeVersionException`，非 P1 行为零变化、APK 零体积影响 | `android/app/build.gradle:186-202`（注释含 2026-10-26 实测连挂记录） |
| 组件选型 | 选型结论（直接用 / 包一层 / 必须自绘 5 项）是按 0.9.4 写的，0.8.8 是否缺其中某组件未知 | 选型见 `docs/plans/2026-10-26-compose-miuix-components.md:27-39`；0.8.8→0.9.4 changelog **未验 / 待定**（离线无从核对官方 release notes，需 Phase 3 开工联网重验） |
| miuix-blur | 选型要求 minSdk 33；P1 已满足，prod 未满足 | 同上 + `android/app/build.gradle:49,144-146` |
| 0.x 稳定性 | 官方 0.x API 不稳（minSdk 曾 23→24），升级必须单独评估 | `docs/plans/2026-10-26-compose-miuix-components.md:51` |

### 1.3 建议（维持 / 升级二选一，已定）

- **维持**：P1 验证壳继续锁定 `0.8.8`，不升 Kotlin、不动 prod `minSdk 26`。理由：P1 目标只是「同包名覆盖安装读同一份 FlutterSharedPreferences」（`android/app/build.gradle:131-140` 注释），0.8.8 已够；升级 Kotlin 到 2.4 是全仓行为，与验证壳无关。
- **升级（单独立项，不在 P1 顺手做）**：Phase 3 真开工时再议，需同时拍板三件事：
  1. Kotlin 2.2.20 → 2.4.x（全仓回归面）；
  2. 0.8.8 → 0.9.4（按官方 changelog 逐项回归，**未验 / 待定**，开工联网核对）；
  3. prod `minSdk 26` 是否抬到 33（选型文档 `:14` 写已拍板，但 build.gradle `:49` 仍为 26——以用户最新拍板为准，本文档不代判，标**待定**）。
- 影响面（若升级）：`composeP1` 源集 + 全仓 Kotlin 插件版本 + 所有 `top.yukonga.miuix.kmp` 坐标 + blur 相关降级路径删除与否 + 自绘白名单复核（选型 `:35-39` 的 5 项在 0.9.4 是否仍无官方对应物，开工重验）。

---

## ② 主题桥映射：Flutter 现色板 → Miuix `colorScheme` / `defaultTextStyles`

> 口径：Flutter 侧手抄 Miuix 色板（`lib/ui/hyperos/hyperos_miuix_spec.dart:7-15` 注明转录自 `Colors.kt` 的 `lightColorScheme()/darkColorScheme()` 与 `TextStyles.kt` 的 `defaultTextStyles()`，对应上游 main 分支 v0.9+），
> UI 一律经 `HyperosColors` 取色、不直涂 token（`lib/ui/hyperos/hyperos_tokens.dart:5-9`）。

### 2.1 颜色：Flutter 现值 → Compose Miuix 目标

下表「Flutter 现值」即 `HyperosMiuixLightColors`（`hyperos_miuix_spec.dart:99-154`）/
`HyperosMiuixDarkColors`（同文件 `:160-214`）实读 hex；「Miuix 目标」列按选型文档口径
（`docs/plans/2026-10-26-compose-miuix-components.md:23`：颜色/字体全局覆写 `lightColorScheme/darkColorScheme`）
给出映射槽位，**Kotlin 侧形参名以 Phase 3 开工对照 0.9.4 实物为准（待定）**，此处只定槽位语义。

| 语义 | Flutter 取色入口 | Light 现值 | Dark 现值 | Miuix `colorScheme` 槽位（语义） | 备注 |
|---|---|---|---|---|---|
| 主强调 | `HyperosColors.primary`（`lib/ui/hyperos/hyperos_theme.dart:72-88`：无 scope 回落 Miuix 蓝，有 seed 所见即所得，仅深色近黑回落墨色） | `#FF3482FF`（`hyperos_miuix_spec.dart:100`） | `#FF277AF7`（同文件 `:161`） | primary | seed 逻辑见 `lib/utils/theme_seed_accent.dart:25-35`；墨水 `onAccentInk` 见同文件 `:40-42`（luminance>0.5 黑墨否则白墨） |
| 主强调面 | `HyperosColors.primarySurface`（`hyperos_theme.dart:96-109`：深色近黑向白提亮） | 同上 | 同上 | primary（承载面复用同一 seed，提亮规则不同） | 提亮规则 `resolveThemeSeedSurface`（`theme_seed_accent.dart:51-61`） |
| 页底 | `HyperosColors.scaffoldBackground`（`hyperos_theme.dart:15-19`） | `#FFF2F2F2` settingsBackground（`hyperos_miuix_spec.dart:65`） | Miuix `background #FF242424`（同文件 `:192`） | background | Light 用 mikcb 实测覆写值而非 Miuix `background #FFFFFFFF`（`:131`），差异见 `hyperos_theme.dart:15-19` |
| 卡面 | `HyperosColors.card`（`hyperos_theme.dart:21-29`：注释说明深色不用 `surfaceContainer` 而用 `surfaceContainerHighest`，否则卡片隐形） | `#FFFFFFFF` surfaceContainer（`:141`） | `#FF2D2D2D` surfaceContainerHighest（`:207`） | surfaceContainer / surfaceContainerHighest | 槽位选择本身就是映射结论，直搬时保留这条分支 |
| 主文字 | `HyperosColors.primaryText`（`:31-35`） | `#FF333333` settingsPrimaryText（`:66`） | `onBackground #E6FFFFFF`（`:193`） | onBackground | Light 实测覆写值，非 Miuix `onBackground #FF000000`（`:132`） |
| 次文字 | `HyperosColors.secondaryText`（`:37-41`） | `#FF999999` settingsSecondaryText（`:67`） | `onSurfaceVariantSummary #80FFFFFF`（`:199`） | onSurfaceVariantSummary | Light `#FF999999` vs Miuix `onSurfaceVariantSummary #99000000`（`:138`）：实测覆写，桥接保留 |
| 第三操作墨（chevron/尾行） | `HyperosColors.actionIcon`（`:43-48`） | `onSurfaceVariantActions #66000000`（`:139`） | `#66FFFFFF`（`:200`） | onSurfaceVariantActions | settings 分组标题亦用此色（`hyperos_theme.dart:58-61`，light `#66000000` 见 `:74`） |
| 按压缩痕 | `HyperosColors.rowHighlight`（`:50-54`） | `#FFE0E0E0` settingsPressed（`:68`） | `secondary #FF505050`（`:177`） | secondary（深色）/ 自定义 pressed（浅色） | Miuix 无 rowHighlight token，Compose 侧按 pressed 语义实现 |
| 容器（弹层/toolbar） | `HyperosColors.surfaceContainer`（`:119-123`） | `#FFFFFFFF`（`:141`） | `#FF242424`（`:202`） | surfaceContainer | — |
| 容器最高（高亮卡） | `HyperosColors.surfaceContainerHighest`（`:126-130`） | `#FFE8E8E8`（`:146`） | `#FF2D2D2D`（`:207`） | surfaceContainerHighest | — |
| 错误 | `HyperosColors.error`（`:137-141`） | `#FFE94634`（`:105`） | `#FFF12522`（`:165`） | error | destructive 另立 token：`#FFE05D44` 亮暗同值（`hyperos_theme.dart:132-134`），**不与 Miuix error 合并** |
| 错误上墨 | `HyperosColors.onError`（`:144-148`） | `#FFFFFFFF`（`:106`） | `#FFFFFFFF`（`:166`） | onError | — |
| 成功 | Miuix token 直用（Flutter 侧 `HyperosColors.success`，本次只读到入口未展全，行号未验） | `#FF0E8043`（`:107`） | `#FF3FD684`（`:167`） | success（Miuix 非 Material 标准槽，桥接保留自定义槽） | Flutter 侧 success/errorContainer 等入口行号**未验 / 待定**（本次只读 `hyperos_theme.dart:1-150`），开工补齐 |
| 分隔线 | `HyperosTokens.divider`（`hyperos_tokens.dart:31`） | `#FFE0E0E0` dividerLine（`:149`） | `#FF393939`（`:210`） | dividerLine（Miuix 自定义槽，非 Material `outline`） | 顶栏/卡片描边用 `outline`（light `#FFD9D9D9 :148` / dark `#FF404040 :209`），勿与 divider 混用 |
| 遮罩 | 直用 token | `windowDimming #4D000000`（`:150`） | `#99000000`（`:211`） | windowDimming | — |
| 禁用底 / 禁用墨 | seed 派生（`theme_seed_accent.dart:63-96`：浅向白混 0.7、深向 `#242424` 混 0.7；墨水浅 `#FFFCFCFC`、深混 0.35） | Miuix 默认 `#FFC2D9FF/#FFF3F8FF`（`:109-110`）等 | `#FF253E64/#FF677993`（`:170-171`）等 | disabledPrimary 系列（全套 `:109-113,:170-174` 按 seed 派生覆写） | 派生比例与默认蓝自洽（注释 `:66-70`）；可读墨水 `disabledInkOn` 保 4.5:1（`:98-133`） |
| 图标彩豆 | `HyperosIconColors`（`hyperos_tokens.dart:124-135`：蓝 `#3482FF`/绿 `#10C550`/橙 `#FF6B00`/紫 `#8B5CF6`/青 `#14B8A6`/红 `#FA382E`/黄 `#F5A623`/靛 `#6366F1`/青 `#06B6D4`） | — | — | **无对应槽**：Miuix `colorScheme` 无图标彩豆，Compose 侧保留为应用层 token | 不进主题桥，按原样搬运 |

Material 侧补充（`lib/main.dart:90-133`）：`_appThemeData` 仅当 seed 可解析时用
`ColorScheme.fromSeed(seedColor, brightness).copyWith(primary: seedAccent, onPrimary: onAccentInk)`（`:106-116`），
否则 `colorScheme: null` 保持 M3 默认（`:106-107`），secondary 刻意保留 fromSeed 派生（`:113-114` 注释）。
结论：Material `colorScheme` 只有 primary/onPrimary 被主题色触碰，其余一切以 Hyperos/Miuix 色板为准——
Compose 桥接同样只覆写 primary 系，不重播 `fromSeed` 全量。

### 2.2 字阶：Flutter 现值 → Miuix `defaultTextStyles`

Flutter 现值（`hyperos_miuix_spec.dart:221-237`）：main 17 / paragraph 17（行高比 1.2）/
body1 16 / body2 14 / button 17 / footnote1 13 / footnote2 11 / headline1 17 / headline2 16 /
subtitle 14 / title1 32 / title2 24 / title3 20 / title4 18。

| Flutter 用法 | 字号 | Miuix `defaultTextStyles` 槽位（语义） | 备注 |
|---|---|---|---|
| 设置行标题 `preferenceTitleSize`（`hyperos_miuix_spec.dart:80`）/ 列表标题 `HyperosTokens.titleSize`（`hyperos_tokens.dart:71-74`） | 17 | body/main（title 语义，待定形参名） | 与 `main/headline1/button` 同 17，需开工对照 0.9.4 `TextStyles.kt` 定唯一槽 |
| 行内说明 `listDetailSize` = body2（`hyperos_tokens.dart:77`） | 14 | body2/subtitle | — |
| 分组小标题 `settingsSectionLabelSize` = footnote1（`:72`） | 13 | footnote1 | 色用 `onSurfaceVariantActions`（`:73-74`），缩进 16、间距 12（`:77-78`） |
| 整宽段说明 `sectionDescriptionSize` = footnote1（`hyperos_tokens.dart:87`） | 13 | footnote1 | 不受单行口径约束（文案纪律，不在本表改） |
| 大标题 title1/title2/title3 | 32 / 24 / 20 | title1/title2/title3 | 折叠大标题走 `TopAppBar(largeTitle)`（选型 `:23`），字阶对齐即可 |
| 字体族/字重 | `AppFontSpec`（`lib/ui/app_fonts.dart:20-24`）+ `AppFontScope`（同文件 `:55-70`：用户字重 100–900、系统粗体增量）+ `main.dart:118-133`（textTheme.apply 字族/字重） | Miuix `defaultTextStyles` 全局覆写（选型 `:23`）+ Compose 侧 fontFamily/字重 scope | 硬编码 HyperOS 文本不继承 textTheme（`app_fonts.dart:51-54` 注释），桥接必须显式解析 scope，不止套 textTheme |

### 2.3 圆角（无全局 token，逐组件搬）

选型已定：圆角无全局 token、逐组件 `cornerRadius`（`docs/plans/2026-10-26-compose-miuix-components.md:23`）。
Flutter 现值：设置组 24（`hyperos_miuix_spec.dart:69`）、控件 10（`hyperos_tokens.dart:52` 经 `MiuixButton.cornerRadius`，配 `controlMinHeight`）、行内边距 16/13/56（`:79-82`）。
Compose 侧按组件逐项设 `cornerRadius`（Scaffold/TopAppBar reng啥的不设全局），本表只定数值来源，不发明新值。

---

## ③ 族7核对：Dart 数据面 vs 原生 Kotlin 现状

> 族定义：`2026-10-26-compose-phase2-families.md:47`——`home_widget_*`、`timetable_live_activity(1447)`、`live_testing`，依赖注明「原生已就绪」。
> 通道名是核对锚点：Dart 与 Kotlin 必须同名字符串，否则 Phase 3 先对通道再对 UI。

### 3.1 通道锚点（已验一致）

| 通道 | Dart 侧 | Kotlin 侧 | 状态 |
|---|---|---|---|
| `com.mutx163.qingyu/home_widget` | `lib/services/home_widget_service.dart:153`、`lib/services/home_widget_binding_service.dart:77`、`lib/services/stats_widget_service.dart:99`（注释 `:94`：复用 home_widget 通道、方法级隔离） | `MainActivity.kt:61`（`HOME_WIDGET_CHANNEL`）+ 处理器 `:1025-1069`（`syncSnapshot/clearSnapshot/syncStatsSnapshot/clearStatsSnapshot` 等） | ✅ 已覆盖 |
| `com.mutx163.qingyu/miui_live` | `lib/services/miui_live_activities_service.dart:35` | `MainActivity.kt:58`（`METHOD_CHANNEL`） | ✅ 已覆盖（超级岛/实时活动入口） |

### 3.2 Dart 数据面清单 → Kotlin 对应物

| # | Dart 侧（数据面） | 行数/锚点 | Kotlin 对应物 | 状态 |
|---|---|---|---|---|
| 7-1 | `lib/services/home_widget_snapshot_service.dart`：`HomeWidgetSnapshot/HomeWidgetCourseSummary`（`:20-70`）、`HomeWidgetSnapshotState` 五态（`:8-18`） | 全文件 435 行（本次展读 `:1-80`） | `HomeWidgetStorage.kt:20` `syncSnapshot` / `:62` `syncWidgetSnapshot` + `TodayWidgetSupport.kt:18,29` `TodayWidgetCourseInfo/TodayWidgetSnapshotInfo` | ✅ 已覆盖（快照落盘 + 今日系渲染模型） |
| 7-2 | `lib/services/home_widget_service.dart`：pin/预览/精闹/排程全入口 | 通道 `:153`；方法级错误码 `:176,249,282,309,317,351,360,386,394,415,436,458`（`home_widget_*_failed` 全套） | `WidgetProviderCatalog.kt:21-39`（10 卡映射：今日系 6 + 统计考试 4）+ `*WidgetProvider.kt ×10`（TodayCompact/Medium/Large/MiniList/Strip/Wide、StatsCompact/Medium/Strip、ExamCountdown）+ `BaseQingyuWidgetProvider.kt` + `HomeWidgetRefreshReceiver.kt` + `WidgetRefreshWorker.kt` + `WidgetPreviewRenderer.kt`/`WidgetPreviewSession.kt` + `WidgetThemeWatcher.kt` | ✅ 已覆盖（10 卡全有 Provider；pin/预览/主题监听/刷新链齐） |
| 7-3 | `lib/services/home_widget_binding_service.dart`：逐卡绑定课表 | `:70-71` 注释（绑定表存原生 `home_widget_prefs`、Kotlin `WidgetBindingStore` 独家管理）+ 通道 `:77` | `WidgetBindingStore.kt:19`（`object WidgetBindingStore`）+ `WidgetCoupleMergeLogic.kt:11`（情侣课表合并）+ `widget_launch_router.dart:5`（Dart 侧路由读绑定） | ✅ 已覆盖 |
| 7-4 | `lib/services/stats_widget_service.dart`：统计快照经 home_widget 通道方法隔离同步 | `:94`（注释）+ `:99`（通道） | `StatsWidgetSupport.kt:7,46,57`（`StatsWidgetSnapshot/Chrome/syncSnapshot`）+ `WidgetStatsLogic.kt:15` + `StatsCompact/Medium/StripWidgetProvider.kt` | ✅ 已覆盖 |
| 7-5 | `lib/services/timetable_live_activity_service.dart`：超级岛宿主编排（1447 行）+ `TimetableLiveActivityPort`（`:29-60` 起） | 全文件 1447 行；import 面 `:6-22`（live_activity_logic + home_widget_binding/service/snapshot + miui_live + stats_widget） | `LiveUpdateService.kt`（常驻服务）+ `LiveUpdateScheduler.kt:918` `syncSnapshot` + `LiveUpdateRefreshWorker.kt` + `LiveClock.kt` + `SystemAlarm.kt`（响点） | ✅ 已覆盖（编排→调度→服务→时钟链齐；方法级参数细对留 Phase 3，标待定） |
| 7-6 | `lib/domain/live_activity_logic.dart`：纯逻辑（阶段/里程碑/时钟解析） | `:12,:15` 里程碑 key（`milestone_recent_end/next_start`，注释：须与 `R.string.milestone_*` 对齐）+ `:29-34` `LiveActivityStage` 四态 + `:36-48` `parseClockMinutes/buildCourseDateTime` | `LiveMilestoneLabelLogic.kt` + `CountdownFormat.kt`（倒计时文案） + Phase 2 已迁 `core/`（`WeekCalculator/TimeSchemeLogic` 等，见 families `:29-32` 状态架构） | ✅ 已覆盖（key 对齐要求已在注释中显式声明，Phase 3 接线时复验 `R.string`，标待复验） |
| 7-7 | `lib/services/miui_live_activities_service.dart`：MIUI 超级岛能力探针与设置跳转 | 通道 `:35`；错误码 `:52,111,126,141,156,171,187,240` | `MainActivity.kt:58` 通道 + `LiveUpdateService.kt:199` `updateDebugSnapshot` + `MemoryStatsCollector.kt:381` 快照史（排障面） | ✅ 已覆盖（能力探针与跳转由原生承接；`redactedLiveDebugSnapshot` 见 `infra/LogRedaction.kt:188`） |
| 7-8 | `lib/services/live_testing_fixture_service.dart` + `live_testing_trigger.dart` + `domain` 侧 `live_activity` 触发器 | `live_testing_trigger.dart:7,10,12`（import live_activity_logic + miui_live + fixture）；`debug_deep_link_*` 引用 fixture（`debug_deep_link_navigator.dart:12-13`） | 无独立 Kotlin 对应物（测试夹具，生产链不依赖） | ✅ 已覆盖（按设计无原生对应物；Phase 3 Compose 预览复用同一夹具，待定） |
| 7-9 | 考试倒计时卡数据 | Dart 侧 `Exam` 模型 + `getNextExam()`（`timetable_live_activity_service.dart:53` port 面） | `ExamCountdownWidgetProvider.kt:12` + `TodayWidgetSupport.kt:1268,1314`（`ExamWidgetPhase/examDisplayName`）+ `ExamReminderScheduler.kt:575`（`ExamReminderReceiver`） | ✅ 已覆盖 |
| 7-10 | 小组件课程配色/墨水/节假日/周末氛围 | `lib/utils/widget_course_accent.dart`（snapshot service `:6` import）、`lib/domain/weekend_mood_logic.dart`（`:1` import） | `CourseWidgetAccent.kt:13`（`WidgetCourseAccentMode`）+ `WidgetInk.kt:18` + `WidgetHolidayLogic.kt:12,94,163` + `FairMemoryAdapter.kt`（内存兜底，通道见 `:123`） | ✅ 已覆盖 |

### 3.3 缺口与待定（不猜，開工再验）

- 缺口：**无已知缺口**。10 卡 Provider、绑定表、快照双通道（今日/统计）、超级岛调度服务、考试提醒、主题/节假日/配色支撑在 Kotlin 侧均有具名对应物（上表）。
- 待定（Phase 3 开工细对，不阻塞准备结论）：
  1. `syncSnapshot` JSON 字段与 `TodayWidgetSnapshotInfo/StatsWidgetSnapshot` 字段逐字对齐（Dart `toJson :57-70` vs Kotlin `data class` 全字段，开工跑一次快照抓包对照）。
  2. `HomeWidgetSnapshotState` 五态（`no_course/upcoming/ongoing/completed/holiday`）与各 Provider 空态/假日态分支是否一一对应（开工逐卡截图对照，呼应 migration-spec `:43-44`）。
  3. 精闹（exact alarm）`canSchedule/requestScheduleExactAlarm`（`MainActivity.kt:1031-1036`）与 Dart `:317-360` 的调用时序（开工真机验，不在本准备文档内真机操作）。
  4. `milestone_*` 文案 key 与 `R.string` 实物（`live_activity_logic.dart:5-12` 注释要求，开工对照 `res/values`）。
  5. Miuix 小组件展示层是否沿用 RemoteViews（原生已就绪）还是 Phase 3 重写为 Compose Glance——选型文档未覆盖小组件 UI（`components.md:27-39` 只列 App 内组件），**未验 / 待定**，由 Lead 在 Phase 3 开工会拍板，本准备不预设。

---

## 附：本次实读文件清单（备查行号）

- `docs/plans/2026-10-26-compose-migration-spec.md`（全 68 行）
- `docs/plans/2026-10-26-compose-miuix-components.md`（全 51 行）
- `docs/plans/2026-10-26-compose-phase2-families.md`（全 71 行，族 7 在 `:47`）
- `android/app/build.gradle`（`:49` minSdk26、`:144-146` P1 minSdk33、`:186-202` runtime 垫片、`:253-257` miuix 0.8.8 锁定）
- `android/settings.gradle`（`:33` Kotlin 2.2.20、`:35-36` compose 插件同版本）
- `lib/ui/hyperos/hyperos_miuix_spec.dart`（`:99-154` light、`160-214` dark、`:221-237` 字阶）
- `lib/ui/hyperos/hyperos_tokens.dart`（全 135 行）
- `lib/ui/hyperos/hyperos_theme.dart`（`:1-150` 实读，success 后段未展读故标未验）
- `lib/utils/theme_seed_accent.dart`（全 166 行）
- `lib/main.dart`（`:90-133` `_appThemeData`）
- `lib/ui/app_fonts.dart`（`:1-80` 实读）
- Dart 族7：`home_widget_service.dart:153`、`home_widget_binding_service.dart:70-77`、`home_widget_snapshot_service.dart:1-80/全435行`、`stats_widget_service.dart:94,99`、`timetable_live_activity_service.dart:1-60/全1447行`、`live_activity_logic.dart:1-60/全281行`、`miui_live_activities_service.dart:35`、glob 确认 `live_testing_*` 与 `Today*`/`Stats*`/`LiveUpdate*` 文件存在
- Kotlin 族7：`MainActivity.kt:58,61,1025-1069`、`WidgetProviderCatalog.kt:18-39`、`HomeWidgetStorage.kt:20,62`、`StatsWidgetSupport.kt:7,46,57`、`TodayWidgetSupport.kt:18,29` 及其余 Provider/Worker/Scheduler 文件名（glob 实见，不逐一展读内容，方法级细对留 Phase 3）
