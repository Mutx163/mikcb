# Compose 弹层 / 对话框 · 全量审核（2026-10-30）

> 触发：用户「所有弹窗都审核一下」（承接 2026-10-29「周视图课程弹窗…把他完善好」）。
> 判据来源：Dart 侧 `lib/ui/hyperos/miuix_bottom_sheet.dart`、`lib/ui/hyperos/hyperos_dialog.dart`、
> `lib/ui/hyperos/hyperos_controls.dart`，以及 `docs/reference/changelog-2026-07-30-sheet-fixes.md`。
> **本仓文档（含旧 L4 清单）只作线索**；数值一律回到 Dart 源码。

---

## 零、结论（先看这段）

**上一轮在「课程操作弹层」里查到的问题，不是个案，是全仓系统性的。** 普查 70 个弹层/对话框调用点后：

| # | 规则 | 违反面 | 用户看到的症状 |
|---|---|---|---|
| **S1** | miuix `OverlayBottomSheet` / `OverlayDialog` 默认侧边距 **24dp**，本仓口径 **16dp** | **27 个调用点**自己又叠了一层内容内边距 ⇒ 单边 **32~40dp** | 内容被挤成中间窄条、两边各空一大块（用户原话「感觉留白过大，只有中间一块有内容」） |
| **S2** | miuix 底栏弹层只 `imePadding()`（**只让键盘、不管导航栏/手势条**） | **32 个底部弹层**全都缺底部让位 | 最后一排按钮贴到屏幕最下沿、被小白条压住（Dart 侧当年原话：「调课停课什么的都到底部屏幕外面去了」） |
| **S3** | 危险色要染**字**（`textButtonColors(textColor=…)`），不是染底 | 8 处写成 `color = 危险色` | 「删除」变成红底 + 默认灰字：既不像原版，对比度也不够 |
| **S4** | 实心危险按钮（`buttonColors(color=红)`）必须同时给 `contentColor` | 2 处（sheet-app 泳道查出的形状） | 同上，只是发生在实心按钮上 |

**修法不是逐个补 padding**，而是把口径收进共享套件 **`components/QingyuSheet.kt`**（与
`QingyuPageScaffold` / `QingyuCard` 同一套思路），再配一条棘轮守卫
`ComposeSheetGuardTest` 拦住「绕开套件」。本轮已迁移 **26 个调用点 / 18 个文件**。

---

## 一、普查口径

脚本扫 `composeP1/kotlin/**`，按括号配平提取实参（不用正则硬抠——`color = Color(QingyuTheme.error(dark))`
这种嵌套括号会把 `[^)]*` 截断，第一版守卫就在这里漏判了 3 处）：

| 类型 | 调用点 |
|---|---|
| `OverlayBottomSheet` | 35 |
| `OverlayDialog` | 34 |
| 合计 | **70**（含本轮新增的套件自身 1 处） |

**对话框（`OverlayDialog`）不套 S2**：它是居中呈现，不存在贴屏幕底；本轮只处理 S1（消叠加）
与 S3/S4（配色）。

---

## 二、本轮改了什么

### 2.1 新增共享套件 `components/QingyuSheet.kt`

```kotlin
QingyuSheet(
    show, onDismissRequest,
    title = null, startAction = null, endAction = null,
    contentPadsHorizontally = false,  // 内容自带左右内边距（≥12dp 的主边距）时 true
    contentScrolls = false,           // 内容里有 LazyColumn / verticalScroll 时 true
    scrollState = null,               // 调用方需要「滚回顶部」等操作时传
    maxHeightFraction = null,         // 原来是「屏高 × 0.9」就传 0.9f
    content = { /* this: QingyuSheetContentScope，可读 bottomInset */ },
)
```

它统一给三件事：**16dp 侧边距**、**底部「系统手势区 + 16dp」**（`bottomInset`）、**限高 + 滚动**。
底部让位**垫在滚动内容里面**（垫在视口外面会留下一截永远空的板——Dart 侧同一处踩过）。

### 2.2 迁移清单（26 个调用点 / 18 个文件）

| 域 | 文件 | 弹层数 |
|---|---|---|
| app | `AppearanceEditorHost.kt` / `SettingsHolidayHost.kt` / `SettingsSemesterHost.kt` / `TimeSchemeHost.kt` | 7 |
| course | `CourseActionSheet.kt` / `CourseFollowupSheets.kt` / `CourseNoteSheet.kt` | 6 |
| about | `AboutStaticPage.kt` / `SupportCreatorPage.kt` | 3 |
| diagnostics | `LiveDiagnosticsLogPage.kt` / `MemoryStatsPage.kt` | 2 |
| task | `TaskPickerSheets.kt` | 2 |
| timetable | `TimetableTopBar.kt` | 1 |
| statistics | `AchievementDetailSheet.kt` | 1 |
| sync | `CloudBackupDetailSheet.kt` / `CoupleWebdavConnectSheet.kt` | 2 |
| time_scheme | `TimeSchemeManagementDialogs.kt` / `TimeSchemeQuickGenerateSheet.kt` | 2 |

### 2.3 配色（S3 / S4）

| 位置 | 错的写法 | 改成 |
|---|---|---|
| `task/AddTaskPage.kt`、`task/TaskListPage.kt`、`time_scheme/LocationTimeMatchHost.kt` | `textButtonColors(color = 错误色)` | `textButtonColors(textColor = 错误色)` |
| `time_scheme/TimeSchemeManagementDialogs.kt`（菜单删除项 / 删除确认 DialogActionRow） | 同上 | 同上 |
| `app/SettingsHolidayHost.kt`、`app/SettingsSemesterHost.kt` | 实心 `Button(colors = buttonColors(color = 红))` **没给字色** | 补 `contentColor = onError` |
| 主操作按钮（`about` ×2、`diagnostics`、`task`、`statistics`、`app` ×3） | 用默认灰 `buttonColors()` | `buttonColorsPrimary()` |

### 2.4 对话框侧边距

`diagnostics/LiveDiagnosticsLogPage.kt` 的清空确认：内容自带 8dp + miuix 默认 24 ⇒ 单边 32dp。
改成 `insideMargin = DpSize(8.dp, 24.dp)` ⇒ 单边 **16dp**，正好是 Dart 对话框口径
（`EdgeInsets.fromLTRB(16,16,16,16)`）。

---

## 三、证据

| 检查 | 结果 |
|---|---|
| L1 编译 `:app:compileDevDebugKotlin` | `BUILD SUCCESSFUL`，整包 `e:` 0 条 |
| L1 测试源码编译 `:app:compileDevDebugUnitTestKotlin` | `BUILD SUCCESSFUL` |
| 弹层守卫 `ComposeSheetGuardTest` | `BUILD SUCCESSFUL`（2 例全绿） |
| 样式守卫 `compose-style-lint` | about / diagnostics / task / statistics / sync / time_scheme / course 均 0 处新增 |
| 渲染层中文硬编码 | 新增 0 条（`CjkLiteralGateTest` 判据自查） |

### 3.1 咬合探针（守卫必须会红）

1. **新增违规必红**：临时在 `pages/course/CourseActionSheet.kt` 里加一个
   `private fun ProbeOnlyRawSheet() { top.yukonga.miuix.kmp.overlay.OverlayBottomSheet(...) }`
   ⇒ `ComposeSheetGuardTest` 失败，消息指到
   `pages/course/CourseActionSheet.kt|S1`；删掉探针后恢复绿。
2. **过期基线必红**：在 `tool/compose_sheet_baseline/app.txt` 里塞一行假基线
   `zzz/Fake.kt|S1|探针用的假基线行` ⇒ 同一用例报「基线里有这些行，但代码已经不违规了」。
   （这条分支在修守卫路径 bug 时也**真实触发过**一次：当时扫到 0 个文件，基线 13 行被判「过期」。）
3. 探针全部还原，`git diff` 里没有 `ProbeOnlyRawSheet` / `zzz/Fake.kt`。

---

## 四、判断经验（这三条是踩出来的，下一个人别再踩）

1. **`contentPadsHorizontally` 不能机械判「有没有 padding(horizontal」**。
   本仓弹层内容常见 `Column { 每行自己 padding(horizontal = 4.dp) }` —— 4dp 是面板内微调，
   归零会让内容贴到面板边（单边 4dp），比 16dp 口径更糟。经验线：**自带 ≥ 12dp 才算主边距**。
   两个泳道都在这一条上反过车。
2. **`contentScrolls` 判错不是「滚得怪」，是「打开就崩」**。外观编辑器的 `HorizontalPager(Modifier.weight(1f))`
   若被套进套件的无限高 `verticalScroll`，Column 直接抛异常。凡内容里有
   `LazyColumn` / `verticalScroll` / `weight` 撑满的子件，必须 `contentScrolls = true`。
3. **`bottomInset` 的落点取决于布局**：滚动区直通屏幕底 ⇒ 塞列表 `contentPadding`；
   滚动区下面还有固定按钮 ⇒ 垫在固定件**之后**（塞进列表会在按钮上方造一截空白）。

---

## 五、诚实清单（本轮没做 / 留着债）

0. **债已清零**（2026-10-30 13:16 复核）：`tool/compose_sheet_baseline/` 只剩 `app.txt` 一个
   **空表**（只有注释头），`exam.txt` / `transfer.txt` 已删；除 `pages/showcase/`（豁免）外，
   全仓**再没有一处**裸调 `OverlayBottomSheet`。守卫 `ComposeSheetGuardTest` 绿。
1. **`pages/showcase/` 豁免 S1**：展厅页是**故意**逐个展示官方裸组件的地方，与样式守卫的豁免同口径。
2. **顶部那 42dp 空档消不掉**：Dart 用 `dragHandleOverlaysContent` 让把手条悬浮在内容之上，
   miuix Compose 0.9.4 没这个开关 ⇒ 把手条恒占 24dp，**且无标题时还会多一条 18dp 的空标题行**。
   这是组件能力缺口，已在本报告登记；能做的只有「内容别再自己加一遍顶部间距」。
3. **`ExamPickerSheets` 日期周次弹层在小屏上可能裁掉底部按钮行**：那支弹层内容里有 LazyColumn
   （⇒ `contentScrolls = true`，套件不再给外层滚动），固定件四段加起来在小屏上会超屏。
   **改动前直接调 `OverlayBottomSheet` 也是同一行为**（同样没有外层滚动），不算回归；
   要更稳得把列表限高从 0.64 降到 ~0.55，属观感取舍，本轮未动。
4. **滚轮与外层滚动的抢手势问题只有真机能看出来**：`NumberPicker` 是固定高、内部可滚的控件，
   套件在外层再套 `verticalScroll` 不会崩；「手指按在滚轮上拖会不会被外层抢走」与已迁移的
   `TaskPickerSheets` 同形状、同一先例，本轮未验。
5. **真机一次都没验**：本轮只能声明「编译通过 + 单测/守卫通过」。要用户在 `dev` 变体上看的路径：
   每个弹层的**最后一排按钮是否离手势条有余量**、**左右是否不再有双倍内边距**、
   「删除」是否红字而非红底、主操作按钮是否是强调色、对话框四周是否已从 24 收到 16。

---

## 六、提交记录（本轮）

| 提交 | 内容 |
|---|---|
| `35154ce5` | 套件 `components/QingyuSheet.kt` + 守卫 `ComposeSheetGuardTest` + 本报告 + 基线（⚠️ 被别的会话的「F15 统计分享」提交连带，见下） |
| `f5cc28a9` | 20 个迁移调用点（含配色修正） |
| `681cdaa7` | 26 个对话框 `insideMargin` 对齐 Dart 16dp + 备份迁移页弹层迁移 + `transfer.txt` 清零 |
| `150865a6` | 考试族 5 个弹层迁移 + `exam.txt` 清零 |
| `f8a823f6` | 设置主页弹层（只提弹层这一半，见下）+ `app.txt` 清零 |

### 两次共享工作区事故（都发生在「改完没立刻提交」的窗口里）

1. **我的暂存被别人的提交卷走**：`35154ce5` 的提交信息写的是「F15 统计分享」，内容里却包含
   我 `git add` 后去跑编译的 4 个文件。教训：**`git add` 之后不得插入任何耗时操作**，
   或者干脆全程走路径限定提交（`git commit -- <paths>`，不经暂存区）。
2. **`SettingsHost.kt` 里有别的会话 600 行在途改动**，我的弹层迁移与它同文件。按纪律不能替别人
   提交整文件，最后用 `git update-index --cacheinfo` 只把「HEAD 版 + 弹层迁移」那个 blob 提上来
   （`f8a823f6`），工作区里对方的在途改动原样保留。
   **注意**：`update-index` 之后提交**必须不带路径**，否则 git 会从工作区重新读文件、
   把对方的在途改动一起带进来。

