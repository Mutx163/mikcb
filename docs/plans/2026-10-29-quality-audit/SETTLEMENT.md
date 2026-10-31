# 近期重构页面 · 缺陷结账表（2026-10-30 收口版）

> 结账对象：[页面质量审核总报告](2026-10-29-page-quality-audit.md) 的 **P0 15 / P1 37 / P2 41 = 93 条**（另 16 条「文档与源码不符」）。
> 分族报告（含每条证据）：[课表核心](timetable.md) · [设置/时间模板/节假日](settings-time-scheme.md) · [云同步/备份迁移](sync-transfer.md) · [诊断/关于](diagnostics-about.md) · [任务/考试/统计/日程/live](misc-wiring.md)
>
> 本文只记**结论与证据**。修复期间并行泳道（F01/F03/F04/F05/F07/F09/F10/F12）各自落了一批，
> 逐条标注「谁修的」：既是交代，也免得下一个人重复修同一处。

---

## 一、结论

**93 条里：已修 65 条 / 仍存在 20 条 / 部分修 7 条 / 误判 1 条。**

闸门**全部实跑**（不是引用别人的数字）：

| 闸门 | 结果 |
|---|---|
| **L1** `:app:compileDevDebugKotlin` | ✅ **BUILD SUCCESSFUL**（反复复跑；过程中修掉 3 类真编译错误，见 §二.2） |
| **L2** `:app:testDevDebugUnitTest` | ✅ **BUILD SUCCESSFUL（5307 例，11:02）**。之后并行泳道持续加测试（5360 例起出现他们自己的在途红项），见 §五.4 |
| **我改过的 7 个模块（L0）** | ✅ 全绿：`shell` 61 / `statistics` 264 / `task` 33 / `exam` 105 / `transfer` 234 / `timetable` 221 / `settings` 714 |
| **样式守卫**（18 域） | ✅ 12 处全部命中基线，**0 新增 0 过期** |
| **文案守卫** | ✅ 超宽新增 0 / 死键新增 0（5 个 Kotlin 消费键已登记并注明原因）/ 复述 0 |
| **i18n 中文闸门** | ✅ 17 文件 171 条，**与基线逐一对上**（原先 24 文件 184 条 + 1 个未登记文件） |
| **咬合探针** | ✅ 新守卫做过「改坏→红→还原→绿」验证（§二.3） |

---

## 二、本轮（Lead）亲自修的

### 2.1 缺陷（原审核清单内）

| # | 缺陷 | 处理 |
|---|---|---|
| **P0-2（课表）** | 点星期栏「周五」进日视图**看到的是今天** | `ShellWiring.onOpenDay` 把点的那天写进 `pendingDayViewDayOfWeek`；`c3.day` 读它并**读完立即清空**（一次性意图），不再用 `LocalDate.now()` 顶替 |
| **P0-1（课表）** | 日视图课卡「作业」「备注」两颗胶囊点了没反应 | 壳补齐 `onOpenCourseNotes`（带 courseId 进编辑）/ `onOpenCourseTask`（带课程建任务）；页面本就是「传了才画、不传不画」 |
| **P1-12（课表）** | 日视图**日程卡 / 考试卡 / 待办带**三条通道生产代码 0 构造 | 壳改调模型层唯一实现 `DayViewDataAssembler.build(...)` + `dayViewPageDataOf(...)`：课程筛选/日程/考试/待办带/冲突一次到位 |
| **P1-13（课表）** | 摘要卡大字标题自造中文「第 3 周 · 周1」且与上一行重复 | 随 P1-12 消失（装配器按 Dart 口径出「10月27日 周二」）；壳里那句拼串已删 |
| **P1-14（课表）** | 日视图恒可翻 30 周 × 7 天 | 壳传 `totalWeeks = settings.semesterWeekCount`、`visibleDays = TimetableHostLogic.visibleDayNumbers(hideWeekends)` |
| **P0-4（统计）** | 分享图标可见可点但没反应 | 参数改 `onOpenShare: (() -> Unit)?`：**没有能力就不画入口**（本仓既定口径）；并修掉并行泳道遗留的类型错配（`feedState` → `feedState.home`），让真文本分享能编过 |
| **P1-3（统计）** | 深度分析排行「点课程名」是死热区 | 壳补 `onOpenCourse`：按课名找回课程 → 走 `d1.addCourse` 编辑路径（与周视图点课同一落点）。页面侧本来就是「有落点才画 clickable」 |
| **P2-8（统计）** | 周报开关失败既不改界面也不提示 | `scheduleNext` / `cancel` 包 `runCatching`，失败弹 `StatisticsStrings.saveFailed`；原来用户以为「已开启」其实永远不会推送 |

### 2.2 闸门红项（不在 93 条内，但不修无法交付）

| 问题 | 性质 | 处理 |
|---|---|---|
| `DataTransferModel.kt` 与其测试：字符串里嵌了**真实换行**（本该 `\n`） | **`pages/transfer` 完全编不过** | 改回 `\n`；随后 234 例全绿 |
| `SettingsHost.kt`：`deliverIntent` 调用**后定义**的局部函数 `handleIntent` | **全量编译失败**（Kotlin 局部函数不许前向引用） | 调整定义顺序 + 写明「顺序有讲究」的 KDoc |
| `DayViewStrings.courseTaskAction` **重复声明**；`CourseGridCard` 缺 `isSystemInDarkTheme` import、引用不存在的键 | **全量编译失败** | 删重复声明；补 import；把 `courseTaskAction` 补进 `TimetableStrings`（同一 ARB 键） |
| 6 条 CJK 基线行**过期**（代码已清、基线没降） | 棘轮「过期必红」 | 删除（24 → 17 行） |
| `AboutUpdateHost` 6 条**内部日志**写成渲染层中文字面量 | i18n 债 | 搬进 `main` 的 `DiagnosticLogMessages`（与 `MainActivity` 同惯例） |
| `LiveDisplayHost` 2 条**用户可见** toast 硬编码中文 | i18n 债 | 补 ARB `liveImagePickFailed` / `liveDoNotDisturbAccessUnavailable`（**六份 ARB 同步**），接 `DisplaySettingsStrings` 进 parity |
| `ExamPickerSheets` 4 处中文（F10 交付时留下的） | i18n 债；英文下 `removePrefix("周")` 会截错 | 补 ARB `datePickerYear/Month/Day`（六份同步）；星期短名改读 ARB `weekdayShortMonday..Sunday` |
| 5 个新 ARB 键在 Dart 侧被判「死键」 | 判据只扫 Dart | 在设计上登记进死键基线并注明「由 Kotlin 渲染层消费」，同时写明彻底消掉要扩判据 corpus（另开一批） |

### 2.3 守卫加固（防同类事故复发）

1. **诊断接线守卫**：宿主符号改「**去注释后**的代码里必须出现」（原先注释里写一遍就绿）；`= null` 判据开 `MULTILINE`（原先只有落在分支末尾才被抓）；`MANAGED` 值由单字符串改列表（可同时钉「宿主 + 关键回调」）。
2. **`PageScaffoldGuardTest` 误报**：把 `innerPadding` 转发给 `QingyuPageList` 的页面被误判「没算手势条」——而 `QingyuPageList:85` 内部已经算过。加豁免并写明原因（否则会把正确写法逼成重复相加）。
3. **新增 `DayViewWiringGuardTest`（5 例）**：钉住「日视图必须接收点击意图」「必须走模型层装配器」「必须传周数/可见星期」「星期栏必须写意图」。
   **咬合探针**：把 `initialDayOfWeek = dayIntent` 改回 `LocalDate.now()` → 立即红（1 例失败）；还原 → 61 例全绿。

---

## 三、并行泳道修掉的（本轮不重复修）

| 条目 | 谁 | 证据 |
|---|---|---|
| P0-2 / P0-3（同步）`g3.lanEdit` / `g3.pickupCodes` 死页 | F03 | `7184712f`、`a481d615`；壳已是 `LanEditHost` / `PickupCodesHost` |
| P0-1 / P1-1 / P1-2（考试）`d3.addExam` 死表单、`semesterStart`、删除无 runCatching | F10 | `a8a55bc3`；壳已是真状态机 + `TimetableExamService` |
| P0-4（设置）`d3.locationMatch` 演示数据 | F10 | 同上；壳已 `LocationTimeMatchHost` |
| P1-5（诊断）`a.support` 死按钮 / `a.contributors` 恒空 | F09 | `01d8a079`；壳已是 `SupportCreatorHostPage` / `ContributorsHostPage` |
| P0-2 / P0-3（任务族）live 显示设置 / 提醒时机不落盘 | F01 | `96fee704` + `60f85d69`；壳已 `LiveDisplayHost` / `LiveReminderTimingHost` |
| P0-4（统计）分享真落点 | F12 | 壳内 `shareStatisticsText(...)`；本轮补的是类型错配与「无能力不画入口」 |
| P0-3（设置）5 个空构造分支 | F05 | `6116529c`（外观编辑页整页重建）；`b.bingGallery` / `b.homeWidget` 也已换真 state |
| P0-1（同步）导入丢数据 + P1/P2 全清 | sync 修复批次 | 见 [sync-transfer.md](sync-transfer.md) §八（新增 7 例「导出→导入→数据仍在」往返测试） |
| P1-3/P1-4/P1-5（任务族）统计明细假读数、日程失败无提示、排行死热区 | 任务/统计修复批次 | 见 [misc-wiring.md](misc-wiring.md)：新增 `ScheduleEditHost`、`reminderKeys` 改可空、有落点才 clickable |

---

## 四、仍未修（22 条 + 7 条部分修），按原因分三类

**A. 并行泳道未落地（6 条）**
- `b.liveSelfCheck` / `b.live` / `b.glassDockIcon` / `b.reset` 四条分支**仍是空构造 `SettingsPageState()`**。
  已登记成 `.agents/compose-phase3/claims/F06-settings-components.md`（含逐页方案与三条实测原因：
  `specFor` 只认 4 页、dispatcher 对这页 rowId 覆盖为 0、`ConfirmReset` 是空实现 ⇒ 硬接会变成
  「一键清数据且不确认」）。
- 时间模板分享（`TimeSchemeHost` 主动从菜单过滤，属 F 批次）。

**B. 需要新增能力层（8 条）**
- 课卡「重新配色」真功能（Dart 479 行弹层 + 配色历史服务 + 仓储写入口）。
- 统计**图片**导出（光栅化 + FileProvider 白名单）；当前只有文本分享。
- 应用内下载控制器（进度条 + 换源重试）。
- 跨域铺应用日志（现 5 个落盘点）。
- 日视图课程卡天气行（需宿主按节次喂天气）。

**C. 数据层缺键 / 系统性 i18n（6 条）**
- `timetablePageBackgroundColor` 等键未进 `TimetableSettingsModel`。
- 整族文案只有中文（`ArbText` 只有 zh）。
- 内存页固定语义量纲。

**D. 部分修（7 条）**：主链路通了但缺一段，逐条原因见各分族报告。

---

## 五、口径与限制（不许含糊）

1. **没有真机验证**。所有「点了有反应 / 不再落到今天」都是源码链 + JVM 单测结论；真机逐页对照仍归用户。
2. **本轮所有修复未提交**：工作树与并行泳道（100+ 文件）混在一起，提交必须按路径限定，否则会带走别人的半成品。
3. **`pages/guide` / `pages/timetable` 的 L0 红是脚本模块隔离限制**（跨模块 import 的守卫测试与渲染件）；`-ExtraSources` 补齐后 `pages/timetable` **221 例全绿**，L1 全量编译通过。
4. **L2 的绿/红被并行泳道的在途代码来回搅动**（这是共享工作区的正常状态，不是本次修复的问题）：
   - 11:02 全量 L2 绿（5307 例）；
   - 之后并行泳道持续加新测试（例数涨到 5360），出现他们自己的红项
     （`BingGalleryApplyTest` ×2 —— `b.bingGallery` 正在被另一泳道改造；
     `StatisticsShareTextTest` / `CloudBackupDetailWiringTest` 曾在 10:53 红过，是其未跟踪测试）。
   - `LanEditHttpServerTest`（F03 已提交的时序测试）在**整机负载高时抖**：全量跑红一次，
     `--tests` 单独复跑**通过** ⇒ 判定为 flaky（空闲看门狗超时断言对机器负载敏感），不是回归。
   - 因此本文的「我的工作是否绿」以**我改过的 7 个模块的 L0** 为准（见 §一表），
     那 7 项与并行泳道的 churn 无关，反复复跑都绿。
5. 「已修」= 代码改了 + 该模块 L0 绿 + 无新增样式/文案/CJK 违规。**不等于**「用户看到的就是对的」。