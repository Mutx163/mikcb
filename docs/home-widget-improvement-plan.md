# 桌面小组件改进方案：统计组件对齐 + 新增横向长条组件

> 状态：方案评审中（未开工）
> 范围：Android 原生桌面小组件（Kotlin AppWidgetProvider + RemoteViews），Flutter 侧设置页与数据同步
> 关联代码：`android/app/src/main/kotlin/com/mutx163/qingyu/*Widget*.kt`、`android/app/src/main/res/layout/widget_*.xml`、`lib/screens/settings/settings_home_widget.dart`、`lib/services/stats_widget_service.dart`

---

## 一、现状盘点

当前共 **6 个**桌面小组件，全部通过 MethodChannel `com.mutx163.qingyu/home_widget` 与 Flutter 同步数据：

| 组件 | Provider | 目标格数 | 精细程度 |
|---|---|---|---|
| 今日课程主卡 | TodayCompactWidgetProvider | 2×2 | ✅ 完善 |
| 今日课程迷你列表 | TodayMiniListWidgetProvider | 2×2 | ✅ 完善 |
| 今日课程概览 | TodayMediumWidgetProvider | 2×4 | ✅ 完善 |
| 今日课程列表 | TodayLargeWidgetProvider | 4×4 | ✅ 完善 |
| 课程统计 | StatsCompactWidgetProvider | 2×2 | ❌ 简陋 |
| 课程统计概览 | StatsMediumWidgetProvider | 2×4 | ❌ 简陋 |

### 原 4 个 Today 组件的"精细体系"（这是要对齐的基准）

Today 系列共享 `TodayWidgetSupport.kt`（约 1300 行），形成了一套完整的渲染规范：

1. **尺寸画像（SizeProfile）**：每次渲染前从 `AppWidgetManager.getAppWidgetOptions()` 读取实际宽高（dp）→ `TodayWidgetSizeProfile`，派生出 `isNarrow / isShort / isTall / isWide` 四个布尔画像。
2. **自适应内边距**：`applySquareishPadding()` 根据实际宽高比动态增减垂直内边距，让内容在非目标比例下依然居中精致（最多再吃进 18dp）。
3. **自适应字号**：按画像缩放每一段文字（如标题在 isShort 时 16sp、isWide 时 19sp、默认 18sp）。
4. **背景风格系统**：solid / glass / gradient 三种风格 × 圆角 r00~r36 每 2dp 一档 = **57 张预生成 drawable**，由设置页「背景样式」选择 + 「圆角」滑条（8~36dp）控制。
5. **状态徽章（chip）**：`statusBackgroundRes(state, style)` 按"上课中/下一节/已结束/假期/考试"换徽章底色。
6. **文字颜色系统**：gradient 风格自动切换白字/浅蓝字，否则深灰字。
7. **高度微调**：设置页 `widgetHeightAdjustment` 滑条参与 padding 计算。
8. **点击跳转**：`buildLaunchPendingIntent()` 点组件任意位置打开 App。
9. **实时快照**：Kotlin 侧直接读 Flutter SharedPreferences 实时重算课程状态，避免静态快照过期；Flutter 快照仅作兜底。
10. **刷新保障三件套**：AlarmManager 精确刷新（`HomeWidgetStorage.rescheduleRefresh`）+ 15 分钟 WorkManager 兜底（`WidgetRefreshWorker`）+ `onAppWidgetOptionsChanged` 尺寸变化即时重绘。

---

## 二、问题诊断：两个统计组件差在哪

对 `StatsCompactWidgetProvider.kt`（81 行）、`StatsMediumWidgetProvider.kt`（100 行）、`widget_stats_compact.xml`、`widget_stats_medium.xml` 逐一核对后，确认 **7 项差距**：

| # | 差距 | 后果（用户看到的样子） |
|---|---|---|
| 1 | 写死单一浅色背景 `widget_stats_bg.xml`（28dp 圆角固定），不接入 solid/glass/gradient × 圆角档位系统 | 和旁边组件圆角、底色不一致，突兀 |
| 2 | 完全没有 SizeProfile：不读 `getAppWidgetOptions`，padding 固定 14/16dp、字号固定 | 用户拖大拖小后内容呆板溢出或大片留白，视觉上"就是一个矩形块"，而 Today 系列会自适应收放 |
| 3 | 设置页的「高度微调」「圆角」「背景样式」对统计组件全部无效 | 用户调了设置发现统计卡不变 |
| 4 | 两个 Provider 都**没有挂任何 PendingIntent** —— 统计组件点了没反应（字符串 `widget_tap_to_open` 已存在但没用上） | 交互缺失 |
| 5 | 不在刷新链路里：`WidgetRefreshWorker.doWork()` 只调 `TodayWidgetSupport.updateAll()`，Alarm 刷新同理 | 只有打开统计页那一刻同步一次快照，之后桌面数字一直陈旧 |
| 6 | 不在「快速添加到桌面」pin 列表：`MainActivity.resolveWidgetProvider()` 只映射 4 种 widgetType | 只能靠系统选择器手动添加 |
| 7 | medium 版式元素不统一：周数是裸文本而非 chip 徽章、ProgressBar 是系统默认样式、信息行无分隔符规范 | 页面观感"不够丰富"、与其他组件不像一家 |

> 注：两个 stats 的 `*_info.xml` 尺寸声明（targetCellWidth/Height 2×2、2×4，minWidth/minHeight）本身已与 Today 对应版本一致，**声明层不用动，要改的是渲染层**。

---

## 三、方案一（P0）：统计组件全面对齐 Today 规范

原则：**不改尺寸声明、不动用户已放置的组件 ID，只升级渲染管线与设置接入。**

### 3.1 接入背景/圆角/高度设置（差距 #1 #3）

- **复用现有 drawable 全家桶**，删除 `widget_stats_bg.xml`：
  - 卡片背景改由代码设置：`views.setInt(R.id.widget_card, "setBackgroundResource", TodayWidgetSupport.backgroundRes(style, cornerRadius))`；
  - 徽章复用 `widget_status_chip_*` 系列；
  - 文字颜色走 `primaryTextColor(style) / secondaryTextColor(style)`（gradient 自动白字）。
- **读取设置的通道**：新增 `StatsWidgetSupport.readChrome(context)`，仿照 `TodayWidgetSupport.readActiveProfileJson()` 直接从 `FlutterSharedPreferences` 读 active profile settings 里的 `widgetBackgroundStyle` / `widgetCornerRadius` / `widgetHeightAdjustment`。这样 **Dart 侧零改动**（无需扩协议），且与 Today 行为同源。
- 高度微调参与 `applySquareishPadding(heightAdjustmentDp = ...)`。

### 3.2 接入尺寸画像与自适应排版（差距 #2）

- 两个 Provider 的 `updateWidget()` 开头加：
  ```kotlin
  val profile = TodayWidgetSupport.sizeProfile(appWidgetManager, appWidgetId)
  TodayWidgetSupport.applySquareishPadding(views, R.id.widget_root, profile,
      baseHorizontalDp = 14, baseVerticalDp = 14,
      heightAdjustmentDp = chrome.heightAdjustment)
  ```
- 字号按画像分档（对齐 TodayCompact 的做法）：
  - 主数字/主行（本周 N 节）：isShort → 16f，isWide → 20f，默认 20f；
  - 辅助行：isNarrow || isShort → 11f，否则 12f；
  - medium 的进度条区域：`profile.isShort` 时隐藏 nature/streak 行（`setViewVisibility(GONE)`），保证矮高度下不挤压。

### 3.3 补齐点击跳转（差距 #4）

- 两个 Provider 末尾统一加：
  ```kotlin
  views.setOnClickPendingIntent(R.id.widget_root,
      TodayWidgetSupport.buildLaunchPendingIntent(context, 20000 + appWidgetId))
  ```
- requestCode 区间约定：Today 用 10000+，Stats 用 20000+，后续新组件按万位分段，避免冲突。

### 3.4 补齐刷新链路（差距 #5）

- `WidgetRefreshWorker.doWork()` 增加 `StatsWidgetSupport.updateAll(applicationContext)`；
- `HomeWidgetStorage.syncSnapshot/clearSnapshot/rescheduleRefresh` 触发点同样追加（与 Today 并列一行调用）；
- 效果：即使不打开统计页，桌面统计数字也随 15 分钟兜底刷新保持新鲜。

### 3.5 medium 版式美化（差距 #7）

对 `widget_stats_medium.xml` 做一次结构升级（保持现有 view id 不变，便于 Provider 平滑迁移）：

- 顶部改 chip 徽章形态：「第 N 周」放进 `widget_status_chip_strong` 底的胶囊，右侧保留「已上 x / 共 y 节」；
- ProgressBar 加圆角与主题色：progressTint 跟随背景风格（solid/glass → 蓝 #2563EB；gradient → 白），backgroundTint 用半透明；
- 底部信息行加分隔符「·」规范并允许 GONE 折叠；
- 无数据态（snapshot == null）沿用 Today 的文案层级：「暂无课程数据 / 点击打开首页」。

### 3.6 接入「快速添加到桌面」（差距 #6）

- `MainActivity.resolveWidgetProvider()` 增加 `"stats_compact" -> StatsCompactWidgetProvider`、`"stats_medium" -> StatsMediumWidgetProvider`；
- Dart 侧 `HomeWidgetPinTarget` 枚举加 `stats22('stats_compact')`、`stats24('stats_medium')`；
- `settings_home_widget.dart` 快速添加区改为 3 行 6 按钮（新增一行放两个统计按钮）；
- l10n 六语言补 `homeWidgetTargetStats22`（如「统计 2×2」）/ `homeWidgetTargetStats24`（「统计 2×4」）。

### 3.7 验收标准

- [ ] 同一桌面上，统计组件与今日组件：圆角一致、底色风格一致、gradient 下同为白字；
- [ ] 拖拽改变大小（拉宽/压扁/增高）后无溢出、无大面积留白；
- [ ] 设置页调整圆角/背景/高度，两个统计组件立即跟随；
- [ ] 点击任一统计组件打开 App；
- [ ] 杀掉 App 后等 ≥15 分钟，统计数字仍会刷新；
- [ ] `flutter analyze` 通过、`./gradlew testDevDebugUnitTest` 通过。

---

## 四、方案二（P1）：新增横向长方形组件（横条）

### 4.1 可行性结论

用户反馈属实：现有 6 个组件的目标格数是 2×2 / 2×2 / 2×4 / 4×4，**全是正方形或竖向长方形，没有一个横向长条**。Android AppWidget 原生支持任意 targetCellWidth/targetCellHeight 组合，RemoteViews 的水平 LinearLayout + TextView + ProgressBar 足够支撑横条版式，且 `TodayWidgetSizeProfile.isWide`（width > height+36）画像分支已经存在，技术上是低风险增量。

HyperOS/MIUI 桌面常见 4 列或 5 列网格，横条建议以 **4×1**（全宽单行，高约 50~60dp）为主打规格，另配 **4×2** 双栏变体。

### 4.2 新组件清单（一期 2 个 + 二期可选 1 个）

#### A. 今日横条 TodayStrip 4×1（推荐首选）

一整行横向铺满：`[chip 状态] [课名(加粗,伸缩)] [时间·倒计时] [第 N 周]`

- 数据全部现成：`TodayWidgetSupport.readSnapshot()` 实时计算（含假期/考试/明日课程兜底逻辑，直接复用）；
- 信息优先级（宽度不够时依次截断）：课名 > 时间 > 倒计时 > 周数，全部 maxLines=1 + ellipsize=end；
- 复用全部规范：背景全家桶、chip、字号分档（isWide 分支）、PendingIntent、刷新三件套。

#### B. 统计横条 StatsStrip 4×1

一整行：`[chip 第 N 周] [本周 X 节] [较上周 ±Y] [迷你学期进度条(固定宽 ~80dp)]`

- 数据源：现有 `StatsWidgetSnapshot` 十个字段足够，Dart 协议不用扩；
- 进度条在 4×1 上必须限宽固定值，防止被 flex 拉伸变形；高度太矮（<45dp）时整体隐藏进度条只留文字。

#### C.（二期可选）双栏横条 4×2

左半：今日接下来两节课列表；右半：学期进度 + 本周节数。适合想要更多信息密度的用户，实现上就是把 A+B 的素材拼进一个两栏 LinearLayout，无新技术点。

### 4.3 每个新组件的标准交付物（以 A 为例，B 同构）

| 层 | 文件 | 要点 |
|---|---|---|
| 尺寸声明 | `res/xml/widget_today_strip_info.xml` | `minWidth=250dp` `minHeight=40dp` `targetCellWidth=4` `targetCellHeight=1` `resizeMode=horizontal|vertical` `previewLayout=@layout/widget_today_strip` |
| 布局 | `res/layout/widget_today_strip.xml` | 根 FrameLayout(widget_root) + 单行水平 LinearLayout(widget_card)，四段文字 + 可选 chip；所有文本 maxLines=1 |
| Provider | `TodayStripWidgetProvider.kt` | 结构照抄 TodayCompact：onUpdate/onReceive/onAppWidgetOptionsChanged/updateAll/updateWidget；渲染复用 Support 函数；requestCode 用 30000+id 段 |
| Manifest | `<receiver>` 一段 | label 引用新字符串 |
| 字符串 | `values/widget_strings.xml` + en/ja/ko/zh-rHK/zh-rTW 五个翻译目录 | 名称（如「今日横条 4×1」）+ 文案 key |
| Pin 入口 | MainActivity 映射 + `HomeWidgetPinTarget.strip41('today_strip')` + 设置页按钮 + l10n | 与 3.6 同一套路 |
| 刷新 | TodayWidgetSupport.updateAll() 追加一行 | 自动继承 Alarm + Worker 兜底链路 |

### 4.4 横条特有的适配规则

1. **矮高度防御**：launcher 实际给 4×1 的高度可能低至 ~40dp。渲染时若 `profile.heightDp < 45`：chip 改为纯文字（去胶囊背景）、隐藏次级信息、字号降到 11sp。
2. **超宽利用**：`profile.widthDp > 320`（5~6 列桌面）时，中段课名允许 maxLines=2 并放开 ellipsize。
3. **竖向误拖**：用户把横条拖成 1×4 时，`isWide == false`，退化为"紧凑竖排"（课名+时间上下堆叠），不崩版——这与 Today 系列的响应式哲学一致。
4. **预览图**：API 31+ 用 previewLayout 实布局预览；如需兼容更低版本选择器，可后续补 previewImage（非必需）。

---

## 五、实施顺序与工作量预估

| 阶段 | 内容 | 主要改动文件 | 预估 |
|---|---|---|---|
| Phase 1a | Stats 渲染管线升级（3.1–3.4） | Stats 两 Provider、StatsWidgetSupport、删 widget_stats_bg | 小（纯 Kotlin） |
| Phase 1b | Stats medium 版式美化（3.5） | widget_stats_medium.xml | 小 |
| Phase 1c | Pin 入口接入（3.6） | MainActivity、home_widget_service.dart、settings_home_widget.dart、l10n×6 | 中 |
| Phase 2a | 今日横条 4×1（4.2.A） | 新增 info/layout/Provider + Manifest + strings×6 + pin/l10n | 中 |
| Phase 2b | 统计横条 4×1（4.2.B) | 同上（Stats 侧） | 小～中 |
| Phase 2c | 双栏横条 4×2（二期备选） | 同构复刻 | 视反馈再定 |

每个 Phase 独立可发布、独立提交（小步提交，中文提交信息）。Phase 1 全部完成后即可先发版收集反馈，Phase 2 的横条样式可据此微调。

## 六、验证方式

1. `flutter analyze` + `./gradlew testDevDebugUnitTest`；
2. 模拟器实测（本项目已接 adb 工具链）：添加每个组件 → 截图对比 Today/Stats 风格一致性；拖拽改形验证自适应；修改设置项验证联动；杀进程等待 15 分钟验证兜底刷新；
3. 多语言抽查：zh / zh-rHK / zh-rTW / en / ja / ko 六语言下组件名与文案完整。

## 七、风险与备注

- **RemoteViews 能力边界**：横条只用 TextView/LinearLayout/ProgressBar，均在支持列表内，无自定义 View 风险；
- **launcher 差异**：不同厂商网格像素不同，已用 dp 下限 + isWide/isShort 画像 + 截断优先级兜底；
- **共享工作区协作**：本方案涉及文件与其他进行中的任务无交集（当前未提交改动集中在 lib/ui/hyperos/*）；实施时按文件精确提交，不做全局格式化；
- **数据新鲜度**：Phase 1 后统计组件依赖 Flutter 侧写入的静态快照 + 周期刷新；若后续要求完全实时（像 Today 那样 Kotlin 直算），可在二期把周课时计算下沉到 `StatsWidgetSupport`，接口已预留（readSnapshot 返回可空对象，扩展字段向后兼容）。
