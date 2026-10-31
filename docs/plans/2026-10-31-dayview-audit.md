# 日视图（c3.day）重构质量审核与收口（2026-10-31）

审核人：Lead（DSH 会话「日视图页面审核」）+ 3 名只读审核员
（`dayview-render-audit` / `dayview-data-audit` / `dayview-style-audit`，报告在 `.agents/dayview-audit/`）
判据：Flutter 原版源码 `lib/screens/timetable_day_view_part.dart` + `lib/widgets/timetable/day_view/**` + ARB。
基线：工作树（2026-10-31 17:55 起；期间另一会话也在改同一页，逐项结论以最终工作树为准）。

---

## 一、先说三件必须知道的事

1. **5 条修复曾被整文件覆盖退回**。`90698ac6`（10-30 11:49，标题是「教务适配仓」）里已含日视图修复，
   但 `ade88452`（10-30 12:47，标题是「Bing 壁纸」）把 `c3.day` 整段退回旧写法，**同一提交还退回**
   `b.reset`、warehouse 三页宿主、统计分享 `feedState`、周报 `runCatching` 等与壁纸无关的泳道。
   `git log -S "DayViewDataAssembler"` 只有引入 / 删除两条，是整文件覆盖的特征。
   教训：**改共享文件前重读，写完立刻验证；别整文件覆盖。**

2. **`90698ac6` 本身是一个不可编译提交**：它让跟踪中的 `ShellPageIndex.kt` 调用未跟踪的
   `DayViewDataAssembler.kt`，而路径限定提交只带走了壳文件。本次已把装配器、天气、日期逻辑、
   守卫测试与实现同批入库。

3. **本轮审核期间（18:10–18:40）另一会话也在改日视图**，三份审核报告都按快照标注了
   「已修，别重复修」。最终交付以本文件与工作树为准。

---

## 二、审核计数

| 审核线 | P0 | P1 | P2 | 备注 |
|---|---|---|---|---|
| 渲染层对拍（Dart 12 件 vs Compose 9 件） | 1 | 9 | 15 | P0：逾期折叠行画了箭头点不动 |
| 数据 / 接线 / 翻页 | 3 | 11 | 8 | P0 含「装配器未入库」的结构性风险 |
| 文案 / 样式 / 守卫 | 1 | 7 | 8 | P0：新增文案没进 `allTexts`，逐字对拍漏检 |

修完之后仍缺的项见 §四（都不在本轮范围）。

---

## 三、已收口（逐条）

**页面结构**
- 顶部星期日期条：周次（可点开选择器）/ 周一..周日 / 日期 / 今天下划线 / 考试红点 / 日程点 /
  点某天换日（`TimetableWeekdayHeader` + `WeekSelectorSheet`）。
- 「回今日」浮钮：38dp 胶囊，非今天时出现，点回今天那一页。
- 空态：只留「第 N 周」，并在可视区居中（Dart `SliverFillRemaining`）。
- 摘要卡：大字日期「10月27日 周二」、课程/日程/作业计数分支、议程区间、
  进行中/冲突/非本周/考试四类胶囊。

**数据**
- 装配收敛到 `DayViewDataAssembler`（模型层唯一实现）+ `dayViewPageDataOf`；壳不再手拼。
- 课程：`coursesForDay` + `visibleDayCourses` 剪枝（与周视图同一口径）。
- 日程：重复/例外日期、跨天 00:00/23:59 剪裁、occurrence id；**不按 `enabled` 过滤**（Dart 同口径）。
- 考试：同日、未过期（23:59 兜底）、按钟点排序、关联课程。
- 待办带：逾期/今日/已完成三档、逾期折叠到 3 条、可操作计数。
- 作业红点：`tasksForCourse(courseId, sourceWeek: week)` 口径（不过滤已完成）。
- 天气行：`DayViewWeather.lineProvider` → 装配器 `weatherOf` → 页面 `weatherLines` → 课卡。
- 无开学日兜底：按 Dart `_resolveDisplayDateForWeekDay` 推日期，日程/考试/待办不再整块消失。

**交互**
- 课程卡：备注 → `CourseNoteSheet`（带查看周，不是课程表单）；作业 → `d2.addTask`（带来源周）；
  点卡 → `d1.addCourse`（带同名课次组成的 `CourseGroup`）。
- 日程卡 → `d2.addSchedule`（带 `occurrenceDate`，可「只改这一次」）。
- 考试卡 → `d3.addExam`（带 `pendingEditExam`，不是考试列表）。
- 待办：勾选落盘（失败 toast）、行点击编辑、「还有 N 项逾期」→ 任务清单。
- 翻页落定回写仓储当前周（退出日视图后周视图停在同周）。

**守卫**
- `DayViewWiringGuardTest` 5 → 10 条：能力回调、星期条数据、考试深链、日程 occurrenceDate。
- `DayViewStringsParityTest`：新增「每条 `ArbText` 声明都必须在 `allTexts` 里」；
  门槛从 `>= 40` 提到 49。原缺口是新增两条文案没登记，逐字对拍完全看不见。
- 样式 lint `-Domain timetable` 9 条全在基线，无新增。

---

## 四、明确没做（诚实清单）

1. **外语界面仍是中文**：`ArbText` 只存 zh，页面取 `.zh`。全站口径，非本页独有。
2. **玻璃 / 壁纸墨色**：Dart 的 `DayViewAgendaSurface` / `dayAgendaAutoInk` 依赖壁纸亮度与
   miuix-blur；Compose 全站未接（见 `docs/reference/miuix-component-first-standard.md`）。
3. **情侣叠加 / 共同空闲摘要**：情侣数据不在 `TimetableSnapshot`，属情侣域。
4. **星期条跟手平移**：`TimetableWeekdayHeader` 无跨周位移入参，翻页时是"跳"不是"跟手推"。
5. **冲突透明度** `timetableConflictCourseOpacity` 在日课卡未生效（周视图已接）。
6. **下拉快捷导入 / 飞行动效 / 滚动位置恢复**：首页级交互，Compose 日视图是独立路由。
7. **真机观感未验**：圆角、按压反馈、星期条高度、浮钮位置、深色对比度需在 `dev` 变体
   `PagesShellActivity` 逐页对照；编译通过 ≠ 能装上。

---

## 五、证据

| 级别 | 命令 | 结果 |
|---|---|---|
| L0 模型 | `scripts/test-kotlin-module.ps1 -Module pages/timetable -ExtraSources android/app/src/main/kotlin/com/mutx163/qingyu/pages/weather` | 230 例全绿 |
| L0 壳 | `scripts/test-kotlin-module.ps1 -Module pages/shell` | 119 例全绿 |
| 咬合探针 | 临时删 `onViewAllOverdue =` → `DayViewWiringGuardTest` 红；还原 → 全绿 | 通过 |
| L1 | `scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` | BUILD SUCCESSFUL |
| 样式 | `scripts/compose-style-lint.ps1 -Domain timetable` | 9 条全在基线 |
