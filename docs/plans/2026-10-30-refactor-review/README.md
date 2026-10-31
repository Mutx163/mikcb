# 近期重构 · 独立审核总报告（2026-10-30）

> 审核员：Lead + 4 名独立审核员（`review-timetable` / `review-settings-live` / `review-sync-statistics` / `review-diagnostics-task`）
> 分报告：[课表](timetable.md) · [设置/时间模板/节假日/实时活动](settings-live.md) · [同步备份/情侣/数据迁移/统计](sync-statistics.md) · [诊断/关于/任务/考试/反馈](diagnostics-task.md)
> 判据：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`（D1..D6 / P0-P2）

---

## 零、结论（先看这段）

**这次审核最重要的不是「又找到多少条」，而是「已修 63 条」这个说法站不站得住。**

1. **基线在审核期间被推进了 3 次**。审核开始时 HEAD 是 `d6c925ba`（11:04），到 12:07 已变成 `35154ce5`。
   4 名审核员全部按硬规矩用 `git show HEAD:` 快照判定，因此他们的结论锚定在 **`d6c925ba`**；
   Lead 另对**当前 HEAD `35154ce5`** 做了逐条复核，本文两列都给。

2. **「已修 63 条」（SETTLEMENT.md §一）在写下时 mostly 是未提交的工作树状态。**
   `git log --all -S` 证明 `pendingDayViewDayOfWeek` / `DayViewDataAssembler` 在 `d6c925ba` 时**不在任何提交里**。
   它们随后被 `90698ac6`（标题「教务适配仓数据层移植」）一并提交——**提交标题与内容不符**。
   ⇒ 「已修」= 代码改了，但**不等于已交付、不等于可回滚、不等于别人能复现**。

3. **当前 HEAD（`35154ce5`）仍然有 9 条 P0**（用户点得到、但没反应 / 没生效 / 丢数据 / 回显不对）。
   其中最重的是**数据迁移导入丢作业与考试**，以及**地点作息分组双向全丢**。

4. **机械闸门全绿**（样式 12 处全在基线、文案超宽新增 0、CJK 171 条与基线逐字一致），
   所以「质量红线」没有新增违规；问题全部在**接线层**，而接线层恰恰是机械闸门扫不到的地方。

---

## 一、审核口径

| 项 | 取值 |
|---|---|
| 审核对象 | 2026-10-28 至今动过功能的 Compose 页面（`composeP1/` + `main/kotlin/.../pages/`） |
| 判据来源优先级 | Dart 原版（`lib/`）+ ARB > 真机基线 > 本仓文档（只作线索） |
| 已提交基线 | `d6c925ba`（审核员）/ `35154ce5`（Lead 复核） |
| 在途改动 | 标注「在途，非已提交交付」，**不计缺陷也不计通过** |
| 硬规矩 | 只读产品代码；不跑 Gradle/L1/L2；每条结论带 `文件:行号` + 原文 + 命令 + 输出 |

### 1.1 基线移动（元问题）

```
d6c925ba  2026-10-30 11:04  迁移(半接收尾 F12)
90698ac6  2026-10-30 11:49  feat(warehouse/F08-8a) ← 标题与内容不符（内含日视图修复）
76ea9cf5  2026-10-30 11:53  迁移(接线守卫 F14)
35154ce5  2026-10-30 12:07  F15：统计分享补图片导出
```

`90698ac6` 的 diffstat 里有 `ShellPageIndex.kt | 267 ++++---`——它把日视图 P0 修复（`dayIntent` /
`DayViewDataAssembler` / `onOpenCourseNotes` / `onOpenCourseTask` / `totalWeeks` / `visibleDays`）
连同仓库适配一起提交了。**提交信息没有提到这些**，下一个读 `git log` 的人会以为日视图没修过。

---

## 二、Lead 独立复核了什么（不依赖审核员）

| 复核项 | 结论 | 证据 |
|---|---|---|
| 机械闸门 | **全绿** | `compose-style-lint.ps1 -Domain all` → 12 处全在基线；`copy_style_lint.dart` → 超宽新增 0 / 死键新增 0 / 复述 0；`i18n-cjk-baseline.py` → 17 文件 171 条与基线逐字一致 |
| `c3.day` 日视图修复是否落地 | **当前 HEAD 已落地**（`d6c925ba` 时未落地） | HEAD `ShellPageIndex.kt` 的 `c3.day` 分支有 `dayIntent` / `DayViewDataAssembler.build(` / `onOpenCourseNotes` / `onOpenCourseTask` / `totalWeeks` / `visibleDays` |
| 统计分享是否编译 | **当前 HEAD 已修**（`d6c925ba` 时类型错配编译不过） | HEAD `onOpenShare` 用 `StatisticsShareText.build(feedState.home)` |
| `b.reset` 是否死页 | **当前 HEAD 已接真宿主** | HEAD `b.reset -> SettingsHost(...)`，`SettingsHost.kt:291/801` 处理 `RESET_SCOPE` |
| `b.bingGallery` 宿主 | **当前 HEAD 已接真宿主** | HEAD `b.bingGallery -> BingGalleryHost(store = wiring.settingsModel, ...)` |
| `e.analysis` 排行点课 | **当前 HEAD 已接线** | HEAD `onOpenCourse = { courseName -> ... onOpenPage("d1.addCourse") }` |
| `bingWallpaperGallery` 路由映射 | **当前 HEAD 仍未映射** | `git show HEAD:ShellWiring.kt \| grep -c bingWallpaperGallery` → **0** |
| 备份导入是否丢数据 | **当前 HEAD 仍丢** | HEAD `DataTransferHost.kt:423-424,440-441` `tasks = repository.tasks, exams = repository.exams`（用本机旧值顶掉包里的） |
| 地点作息分组 | **当前 HEAD 仍全丢** | HEAD `DataTransferPackageLogic.kt:274` `locationTimeGroupsJson = emptyList()` |
| 主题管理 4 处动作 | **当前 HEAD 仍死** | HEAD `SettingsHost.kt:124` `onIntent = {}`；只消费 `Ignored`/`Write`，`ShowSheet`/`ShowDialog`/`ShowRecolorSheet`/`ClipboardExport` 全仓 0 消费者 |
| 关于族日志入口 | **当前 HEAD 仍死** | HEAD `AboutUpdateHost.kt:185` `onOpenDiagnostics = { /* 日志页路由未在本批次接入 */ }` |
| 考试滚轮中文 | **当前 HEAD 仍 4 处** | HEAD `ExamPickerSheets.kt:297,311,320,602` |
| 镜像编辑动作 | **当前 HEAD 反馈错误** | HEAD `AboutUpdateHost.kt:184` `onEditMirrorUrl` 弹 `mirrorPrefixLabel`（「镜像前缀」）toast，全仓无镜像编辑页 |

---

## 三、当前 HEAD（`35154ce5`）仍成立的缺陷

### P0（9 条）

| # | 缺陷 | 证据 | 修法 |
|---|---|---|---|
| 1 | **主题管理 4 处死动作**：导出主题 / 导入主题 / 保存当前主题 / 已存主题「更多操作」点了没反应 | `SettingsHost.kt:124` `onIntent = {}`；`SettingsActionDispatcher` 把它们翻成 `ClipboardExport`/`ShowDialog`/`ShowSheet` 后全仓 0 消费者 | 壳传 `onIntent`，接 `ShowSheet`/`ShowDialog`/`ClipboardExport` |
| 2 | **课卡「重新配色」点了没反应** | 同上（`ShowRecolorSheet` 0 消费者） | 接 `ShowRecolorSheet` 或删入口 |
| 3 | **`b.live` 摘要行恒显示默认值**（`spec(state, data)` 的 `state` 未被使用，`data` 用默认构造） | `SettingsLivePage.kt:51`；壳传 `SettingsPageState()` | 壳传真 `LivePageData` |
| 4 | **`b.liveSelfCheck` 假诊断**（空构造 state） | 壳 `b.liveSelfCheck -> SettingsScreen(...SettingsPageState())` | 接真诊断数据源 |
| 5 | **`b.glassDockIcon` 图标清单恒空**（空构造 state） | 壳同上 | 接真图标清单 |
| 6 | **`b.homeWidget` 6 开关恒默认不落盘** | 壳 `b.homeWidget -> ...SettingsHomeWidgetState()` | 接 `TimetableSettingsModel` |
| 7 | **「更多壁纸」入口点了没反应**：`bingWallpaperGallery` 不在壳两张路由表里 | `SettingsBackdropFlowPage.kt:182` `BING_GALLERY_TARGET = "bingWallpaperGallery"`；`git show HEAD:ShellWiring.kt \| grep -c` → 0 | 在 `shellPageIdForRoute` 登记，或把守卫改成扫 const |
| 8 | **备份导入丢作业与考试**：`applyImport` 用本机旧值顶掉包里的 | `DataTransferHost.kt:423-424,440-441` `tasks = repository.tasks, exams = repository.exams`；`:403` 注释自认「已知缺口」 | 写回 `plan.tasks` / `plan.exams`（Dart 全写回） |
| 9 | **地点作息分组双向全丢**：导出恒写空列表 | `DataTransferPackageLogic.kt:274` `locationTimeGroupsJson = emptyList()`；`:57-58` 注释谎称 snapshot 无此字段（实际 `TimetableRepository.kt:45` 已有） | 用 `snapshot.locationTimeGroups` 写回 |

> 另有一条同类：`AboutUpdateHost.kt:185`「查看手机日志」空回调（诊断域 P0），也计入 9 条之一。
> 即：上表 #1–#9 中，#1/#2 同源（1 条根因 5 个控件）、#8/#9 是数据层两条独立缺陷。

### P1（9 条，节选）

- 考试列表日期缺「第 N 周 · 」前缀：`ShellPageIndex.kt` `d3.examList` 传 `semesterStart = null`（Dart 用 `provider.semesterStartDate`）。
- `ExamPickerSheets.kt:297,311,320,602` 4 处渲染层中文字面量，**不在 CJK 基线** ⇒ `CjkLiteralGateTest` 会红。
- 壳层硬编码中文：「Compose 壳」（`ShellPageIndex.kt:1300,1352`）、"连接测试失败"（`:1329`）——CJK 门禁只扫 `composeP1`，扫不到 `main` 壳。
- `AboutUpdateHost.kt:184` `onEditMirrorUrl` 弹「镜像前缀」toast（错误反馈），全仓无镜像编辑页。
- `DisplaySettingsStrings.kt:181,183` 的 `liveImagePickFailed` / `liveDoNotDisturbAccessUnavailable` 在 HEAD 的 `app_zh.arb` 里**没有键**（Dart 原件也没有这两句 ⇒ Compose 自造文案），`DisplaySettingsStringsParityTest` 会红。
- 云备份「恢复」无差异预览 / 无合并选择 / 无「设为当前版本」确认 / 强制远端为准，且成功提示丢 Dart 的「撤销」动作。
- 跨设备导入时 `scheduleDateRules.timeSchemeId` 未按新模板 id 改写 ⇒ 悬空引用。
- `QrTransferSendHost(title:)` 加了参数但壳没传 `outboundTitle`（死参数）。
- 全量备份隐藏「合并更改」按钮（Dart 支持全量合并）。

### P2（节选）

- 模型层摆设：`TimetableGridMetrics` / `TimetableGridConfig` / `SectionTimeSlot` / `TimetableProfilesLogic` / `DayExamSummary`（生产 0 引用）。
- `DayViewWeather` 全仓 0 引用 ⇒ 日课卡天气行永不出现。
- `e.analysis` 未进 `DiagnosticsWiringGuardTest.MANAGED`（F14 已扩到 65 条，但该条是否在内需复核）。
- `ExamListModelTest` 全部用例传 `semesterStart = null`，恰好放过 P1 的日期前缀缺陷。
- `TaskStrings.datePicker*` 在 HEAD 既无 ARB 键也无 parity 测试。
- 关于族 / 考试族无接线守卫（F09 / F10 的修复被回退时编译与单测都不会响）。
- `i.moreSearch` 顺序仍是「先推页再退栈」（声明与交付不一致）。

---

## 四、已修 vs 未提交（交付状态）

| 项 | 状态 |
|---|---|
| 日视图 5 条修复（P0-1/P0-2/P1-12/13/14） | **已进 HEAD**，但藏在 `90698ac6`（标题不符） |
| 统计分享编译错误 | **已进 HEAD**（`feedState.home`） |
| `b.reset` 接真宿主 | **已进 HEAD** |
| `b.bingGallery` 接真宿主 | **已进 HEAD** |
| `e.analysis` onOpenCourse | **已进 HEAD** |
| 主题管理 4 处 + 重新配色 | **仍未修**（HEAD） |
| 备份导入丢数据 / 地点作息分组 | **仍未修**（HEAD） |
| 5 个新 ARB 键（live* / datePicker*） | **仍在工作树**（`tool/copy_style_dead_keys_baseline.txt` 已登记原因，未提交） |
| 5 个新守卫/测试文件 | **全部 untracked**：`SettingsHostIntentWiringGuardTest` / `SettingsIconCoverageGuardTest` / `SettingsStringsExt1ParityTest` / `TaskStringsParityTest` / `DataTransferRoundTripTest` / `DayViewWiringGuardTest` |
| `DataTransferRoundTripTest`（声称的「7 例往返测试」） | **untracked**，HEAD 上一条都没有 |
| `SettingsHost.kt` 的 `handleIntent` 内置消费端 | **只在工作树**（HEAD 仍是 `onIntent = {}` + 0 消费者） |

---

## 五、系统性问题

### 5.1 动作通道断头（同一病灶，6 个域）

渲染层发动作 → 分派器翻成意图 → 宿主/壳入口默认 `{}` → 生产 0 消费者。
屏上控件照常渲染、能点、无反应，**单测全绿**（测的是模型层与渲染层）。

当前 HEAD 仍在断头的位置：主题管理 4 处 + 重新配色、`b.live` 摘要、`b.liveSelfCheck`、
`b.glassDockIcon`、`b.homeWidget`、`bingWallpaperGallery` 入口、`onOpenDiagnostics`。

### 5.2 守卫覆盖面与判据盲区

- `DiagnosticsWiringGuardTest.MANAGED` 只覆盖它登记的路由；**未登记的页面必须人肉验**。
- `SettingsRouteWiringGuardTest` 只扫 `actionTarget = "/..."` 字面量 ⇒ **漏掉 `bingWallpaperGallery` 这个 const**（P0-7 的直接原因）。
- CJK 门禁只扫 `composeP1/kotlin` ⇒ **扫不到 `main/kotlin` 壳里的硬编码中文**（P1 壳层 2 处漏网）。
- 守卫文件本身**未提交**（`SettingsHostIntentWiringGuardTest` 等）⇒ 别人拉不到 HEAD 时守卫不存在。

### 5.3 文档与源码不符

- `SETTLEMENT.md` §一「已修 63 条」——写下时 mostly 未提交。
- `DataTransferPackageLogic.kt:57-58` 注释谎称 snapshot 无 `locationTimeGroups`（实际有）。
- `90698ac6` 提交标题与内容不符（内含日视图修复）。
- `i.moreSearch` 提交声明已修，HEAD 上仍是旧顺序。

---

## 六、交付卫生

| 项 | 现状 |
|---|---|
| 暂存区 | 已清空（11:00 记录的 −1720 行删除已被 `38888d8e`/`d6c925ba` 消化） |
| 工作树 | **165+ 项未提交**，且**审核期间持续被另一会话改动**（`ShellPageIndex.kt` mtime 11:27） |
| 编译 | 无法归因：工作树在动 + 已有 5 个 java 进程（含 kotlinc）⇒ 未跑 L1/L2 |
| 提交路径 | 必须按路径限定；`90698ac6` 的标题说明「不带路径提交」的风险仍在 |

---

## 七、建议（按「用户损失 × 修复成本」排）

1. **备份导入丢数据**（P0-8/9）：写回 `plan.tasks` / `plan.exams` / `locationTimeGroups`；补「导出→导入→数据仍在」往返测试并提交。
2. **主题管理 4 处 + 重新配色**（P0-1/2）：壳传 `onIntent`，接 `ShowSheet`/`ShowDialog`/`ClipboardExport`/`ShowRecolorSheet`。
3. **`bingWallpaperGallery` 路由**（P0-7）：在 `shellPageIdForRoute` 登记；并把 `SettingsRouteWiringGuardTest` 改成扫 const 而非只扫字面量。
4. **设置族空 state 三页**（P0-3/4/5/6）：`b.live` 传真 `LivePageData`；`b.liveSelfCheck` / `b.glassDockIcon` / `b.homeWidget` 接真数据源。
5. **关于族日志入口**（P0）：`onOpenDiagnostics` 接真路由。
6. **把未提交的守卫/测试提交**：否则「已修」不可复现、不可回滚。
7. **给 `90698ac6` 补一条说明**（或在台账里记一笔）：日视图修复藏在仓库适配提交里。
8. **CJK 门禁扩到 `main/kotlin`**：否则壳层硬编码中文永远漏网。

---

## 八、诚实边界（没能验的）

- **没有真机验证**：所有「点了有没有反应」都是源码链 + 静态接线推断，真机逐页对照归用户。
- **没有跑 L1/L2**：工作树在动 + 资源争用 ⇒ 编译/单测是否真绿**未独立验证**。
- **咬合探针未跑**：守卫「有没有牙齿」只有代码阅读结论（审核员读过守卫源码与反向验证记录）。
- **基线在动**：审核员锚定 `d6c925ba`，Lead 复核锚定 `35154ce5`；两次结论的差异已逐条标注。
