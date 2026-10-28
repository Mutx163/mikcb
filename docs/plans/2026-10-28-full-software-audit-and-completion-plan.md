# 轻屿课表 · 全仓体检与完善计划（2026-10-28 晚）

> **定位**：这不是又一份"要做什么"的愿望清单，而是**对当前工作区做一次只读体检后的实测结论 + 可执行收口计划**。
> 上游唯一派工看板仍是 [全景直通派工大表](2026-10-28-compose-master-dispatch-table.md)；本文件只回答两件事：
> ① 现在到底完成到哪了（比文档口径乐观得多）；② 剩下的活按什么顺序、由谁、怎么验收地收掉。
>
> **一句话结论**：软件**没有被做坏**，绝大多数「页面 + 数据层 + 宿主层 + 壳接线」其实**已经在工作区里了、只是没提交**。
> 真正的缺口集中在三类：**未提交的接线要安全落地** / **少数几处真缺的能力** / **一页都没真机验过**。

---

## 一、体检方法与边界

- **只读**：本报告全程未改任何生产代码、未跑编译/测试（体检时检测到 `~/.gradle` 的 `kotlin-build-tools` 守护进程仍在跑，
  说明另有会话正在构建 —— 按 `AGENTS.md`「别一改一跑 / 别并发编译」的纪律，本轮不抢构建）。
- **口径**：所有计数都是**扫描时刻 2026-10-28 20:2x 的工作区**，不是 HEAD、也不是某次提交。
- **诚实边界**：静态扫描只能证明「代码长什么样」，**证明不了「点上去一定有反应」**（见 `_CENSUS-dead-entries.md` §0 的假阳性实例）；
  最终「能用」只能由用户在真机上走一遍。

---

## 二、关键事实（实测，与文档旧口径的差异）

| 事实 | 实测值 | 说明 |
|---|---|---|
| 路由条目 | **84 条**（`ShellPageIndex.kt`） | 与台账一致 |
| 壳里显式空回调 | **91 处**（`= {}` 形态） | 比 17:30 普查的 **135** 降了 44 处 —— 说明这半天确实在接线 |
| 未提交改动规模 | **67 M + 26 ?? + 5 D** | ⚠️ **大量成果还在工作区、未落库**，是当前最大风险 |
| `ShellPageIndex.kt` 工作区 diff | +171 / −101 | 含多位会话的在途改动（家菜单/引导/设置 S2/日程…） |
| 构建守护进程 | 4~5 个 java（最近 20:16 启动） | 另有会话在构建；工作区当前**不是全绿**（`CourseOverviewPage.kt` 有他人未提交的 `boundsInWindow` 未解析）|

**已经接进壳（工作区里核到具体件，不是"我记得"）**：
`StatisticsFeed`（`:679-777`，主页/明细/分析/设置四路由真数据）、`TimetableProfilesController`（档案管理）、
`SettingsHost`（4 个设置页）、`ScheduleHost`（日程）、`CloudSyncController`（云同步 + 备份列表）、
`pendingAnalysisModule` / `pendingTaskCourse` / `saveScheduleItem`（ShellWiring 新字段）。
⇒ **主表 §五 里标"未接"的统计族、日程，工作区其实已接**；主表是 2026-10-28 白天快照，**已经落后于工作区**。

---

## 三、真实缺口清单（四类，按性质分）

### A 类：能力已交付，但**壳接线未落地 / 未提交**（性价比最高，多数只差一步）

| # | 项 | 现状证据 | 动作 |
|---|---|---|---|
| A1 | **T1 课程操作弹层** | 分派器 + `CourseActionSheet.kt` 已交付（`8866b3b5`），但壳里 `CourseActionSheet(` 命中 **0** | 按 `T1-course-action-sheet.md` 的 diff 把弹层挂到 `c1.week` |
| A2 | **S2 设置族其余 20 路由** | `SettingsPageBridge.SUPPORTED_PAGE_IDS` 只有 4 个；其余 20 条走裸 `SettingsScreen` | 扩 `SUPPORTED_PAGE_IDS` + 路由换 `SettingsHost`（S2 在跑，需先确认其进度） |
| A3 | **I3 ICS 导出** | 模型/序列化已交付；`AndroidManifest` 里 `FileProvider` **0 处** | Lead 补 manifest + 壳分享 Intent 注册 |
| A4 | **壳接线整体落库** | `ShellPageIndex/ShellWiring/PagesShellActivity` 三文件含他人未提交改动 | **等工作区收敛后**，按路径限定分批提交（不能混别人的） |
| A5 | 演示/示例数据 | 壳内 `演示/示例/demoData` 标记约 **34 处**；`emptyList()` 写死 `:657/658`（考试）、`:901`（学校适配器）等 | 随各域接线逐个换真数据源 |

### B 类：**真缺的能力**（底层就没有，接线填不上）

| # | 项 | 证据 | 归属 |
|---|---|---|---|
| B1 | **考试族写服务** ✅ *服务已交付* | `TimetableCourseService` 无 `addExam/updateExam/deleteExam`；壳喂 `exams = emptyList()` → **已补 `TimetableExamService` + 11 例测试（`f70604b0`）**；壳 `d3.*` 接线待收敛 | 主表外 / 需新开包 |
| B2 | **任务清单控制器** ✅ *控制器已交付* | `pages/task/` 无 TaskList 控制器/宿主（`addTask/deleteTask` 有，缺装配层）→ **已补 `TaskListController` + 7 例测试（`4efc79f4`）**；壳 `d2.taskList` 接线待收敛后落地 | A4 普查"A4 任务清单" |
| B3 | **统计分享（导出+光栅化+系统分享）** | Kotlin 侧无 `StatisticsShareService` 对应物（`ST1-statistics-wiring.md` §2） | 并入 I3 能力面 |
| B4 | **局域网 `import/apply`** | `LanEditApiRouter` 仍 9 处 `501`（唯一"真缺的能力"） | `GAP-lan` |
| B5 | **备份 tasks/exams 写回、多档案恢复** | 台账 §9.4 ③（task-14） | 仓储原子入口 |
| B6 | 全局：前台服务/保活、通知换通道、超级岛 | 原生件在、接线未列行 / 判据未拍板 | Phase 4 |

### C 类：**只能由用户真机验证**（agent 无论如何声明不了"能用"）

- 一页都没真机对照过（台账 §9.4 ①）；相机取景、权限弹窗、系统分享面板、WebDAV 真收发、SAF 选文件、
  杀进程重开后设置/课表是否还在……**全部需要用户在 composeUi 壳里走一遍**。

### D 类：技术债 / 环境问题（不阻塞功能，但要单独定方案）

- `:app:testComposeUiDebugUnitTest` 变体下 `QingyuTextStylesTest` 报 `UnsupportedClassVersionError`（miuix 0.9.4 是 Java 21，工程 jvmTarget=17）。
- 共享模型目录（`app/ share/ sync/ transfer/`）被每次 L0 无条件收录 ⇒ 一条泳道半成品污染全队编译（今天已多次发生）。
- 毛玻璃页面层 / `fontWeight` / 余量裸 `Card(` 未动（样式债，非功能）。

---

## 四、完善计划（按波次，含门槛）

> 原则：**先安全落地已完成的，再补真缺的，最后才谈真机与删 Flutter**。每波都以「工作区收敛 → 只认自己文件上的 `e:`」为前提。

### Wave 0 · 体检基线（只读，本文件即产出）
- 产出：本报告 + 缺口清单 + 更新后的大表状态列（让看板与工作区对齐）。
- 门槛：不需要编译。

### Wave 1 · 收口已完成的接线（Lead 主导，最高价值）
1. 等其它会话把 `composeP1/pages` 的未提交改动收敛（未提交数连续两次 ≥10 分钟不变）。
2. 跑一次权威闸门 `:app:testProdDebugUnitTest`（走 `scripts/safe-gradle.ps1`，全机互斥）×1，拿到基线。
3. 按**路径限定**分批提交：壳接线（A4）、T1 弹层（A1）、S2 剩余路由（A2）、I3 manifest（A3）。
4. 门槛：L2 全绿 + 每批 `git diff --cached --name-status` 只含本批文件。

### Wave 2 · 补齐真缺口（可并行，按可见度排序）
1. **任务清单控制器**（B2，可见度高、`addTask/deleteTask` 已有下半截）。
2. **考试族写服务 + 接线**（B1，空回调最多但成本也最高，先做服务）。
3. **统计分享**（B3）+ **ICS 导出分享面板**（A3，合并到 I3 能力面）。
4. **LAN `apply`**（B4，唯一真缺能力，`GAP-lan` 继续）。
5. **备份 tasks/exams 写回**（B5）。
- 门槛：每项 L0 单测 + 咬合探针 + L1 `e:` 只认自己文件；共享目录改动必带跨域 L0。

### Wave 3 · 真机逐页验收（用户）
- 按 `2026-10-27-compose-phase3-l4-checklist.md` + 各认领文件的"真机对照清单"逐页走。
- agent 只交"编译过 / 单测过"，**不声明"能用"**。

### Wave 4 · 收尾（R1/R2）
- 主 `MainActivity` 切 Compose 入口（保留回退）→ 覆盖安装验数据不丢 → 关回退窗口 → 删 Flutter 出正式包（用户跑构建）。

### Wave 5 · 技术债（可随时插空）
- `QingyuTextStylesTest` 变体 JVM 问题（D1，需用户拍板改构建环境）。
- 共享目录编译隔离（D2，根治"半成品污染"）。

---

## 五、风险与协调（必须先讲清，否则会互相踩）

1. **共享工作区**：当前 67 改 / 26 新增 / 5 删**混着多位会话的在途改动**。任何人 `git add .` 都会把别人的半成品卷进提交。
   ⇒ 一律**路径限定提交**，先 `git diff --cached --name-status` 核对。
2. **并发编译**：现在有构建守护进程在跑；**别一改一跑**、别与用户 AS 构建并发。L1/L2 一律走 `scripts/safe-gradle.ps1`。
3. **工作区当前不是全绿**：`CourseOverviewPage.kt` 有他人未提交的 `boundsInWindow` 未解析 ⇒ 任何"全绿"结论要等它收敛。
4. **设备铁律**：真机操作（安装/输入/设置）**只有用户能做**，agent 不得碰。

---

## 六、我建议的下一步（等用户拍板）

- **若同意全自动推进**：我先做 Wave 0 收尾（本报告 + 大表状态对齐），再等一个安全窗口做 Wave 1 的提交与 L2 基线；
  Wave 2 按 B2→B1→B3/A3→B4→B5 顺序开子任务推进。
- **若只想先看计划**：本文件即为计划，我不落任何改动。
- **若想缩小范围**：指定域（如"先只把设置族和课表族收口"），我据此裁剪波次。

---

## 六·附一、路由机器体检表（2026-10-28 20:55 刷新）

> 机器生成（只读，启发式候选清单，**非判决书**）。原始表在本机 `.agents/compose-phase3/_ROUTE-SCORECARD.md`（不入库）。
> 口径：按 `"id" ->` 切块，`emptyList()`=写死空数据、`= {}`=显式空回调、`Host(`/`Controller(`/`StatisticsFeed.feed`/`SettingsHost`=有宿主。

壳 `ShellPageIndex.kt` 现有 **86** 个路由块（白天以来又长了一截，行号已到 1255+）：

| 类别 | 数 | 说明 |
|---|---|---|
| 有宿主（疑似已接线） | **23** | 设置 4 页 + 家导航/家菜单/课表页/天气/玻璃坞 + 档案 + 月视图 + 课程总览 + 日程列表/日期规则 + 统计 3 路由 + 云同步/备份 + 二维码收发 + 天气城市 |
| 写死空数据 | 5 | `a.contributors`、`d1.addCourse`、`d3.examList`、`g2.schoolAdapters`、`h.fixture` |
| 多空回调(≥3) | 12 | `d2.taskList`(6)、`d3.addExam`(14)、`d3.timeSchemes`(5)、`d3.locationMatch`(5)、`g3.dataTransfer`(5)、`g3.icsExport`(11)、`f.couple`(3)、`g1.importEntry`(3)、`g3.lanEdit`(3)、`h.log`/`h.memory`/`h.perfReport` |
| 少量空回调 | 7 | `a.support`、`d2.addTask`、`g1.icsImport`、`g1.spreadsheetImport`、`g3.pickupCodes`、`i.moreSearch`、`k.feedback` |
| 无回调/只读 | 39 | 多为设置族子页（渲染但 action 丢弃，见 B 类 S2）+ 展示/诊断页 |

**结论**：白天普查的「135 处空回调」已明显收敛（有宿主增长到 23 条）。剩下"点不动"的热点集中在
**考试族（`d3.addExam`/`d3.examList`/`d3.timeSchemes`/`d3.locationMatch`）、任务清单（`d2.taskList`，控制器已备）、
传输（`g3.dataTransfer`/`icsExport`/`lanEdit`）、情侣课表（`f.couple`）、导入入口（`g1.*`）、诊断族（`h.*`）**。
其中 `d2.taskList` 与 `d3.addExam`/`examList` 正好对应本轮已交付的两个服务，**只差壳接线**。

---

## 六·附二、闸门实测（2026-10-28 22:40 夜）

> 工作区 21:12 起稳定（连续 10 分钟 0 改动），已不是"半成品在途"，遂跑全量闸门取证。

| 闸门 | 命令 | 结果 |
|---|---|---|
| L1 壳编译 | `safe-gradle :app:compileComposeUiDebugKotlin` | **BUILD SUCCESSFUL**（26s）—— 整套壳 + 页面能编过 |
| L2 单测（权威） | `safe-gradle :app:testProdDebugUnitTest` | **4318 例 / 4 失败** |

**4 条失败全部落在「其它会话的在途文件」上，本会话交付的 `TaskListController` / `TimetableExamService` 在 Gradle 真实单测里 0 失败：**

| # | 守卫用例 | 牵涉文件 | 症状 |
|---|---|---|---|
| 1 | `CjkLiteralGateTest` | `pages/settings/SettingsWeekPreview.kt` | 8 处中文硬编码未登记（须走 `ArbText` 或登记基线与原因）|
| 2 | `ComposePageStyleGuardTest` | `settings/SettingsPageRenderers.kt:443` | R5 写死颜色 1 处 |
| 3 | `PageScaffoldGuardTest` | `about/AboutStaticPage.kt`、`about/SupportCreatorPage.kt` | 取了 `innerPadding` 却没把底部内边距差消费掉 |
| 4 | `SettingsActionDispatcherTest` | `app/SettingsActionDispatcher.kt` | 分派器已支持 `timetablePage.sectionHeight`，用例仍断言 `Ignored`（用例没跟上实现）|

⇒ **结论**：编译层已通；单测只差这 4 条守卫（全在别人文件上）。

> **2026-10-28 22:52 更新（Lead 接手收口）**：经用户授权，Lead 已修掉这 4 条守卫（About 两页补手势条底距 /
> 动态取色避开写死色检测 / 过期用例改真未知 id / cjk 基线按棘轮下调），**L2 转全绿（4318 例 / 0 失败）**；
> 并把积累的多域接线（87 文件，仅 `android/app/src`）统一收口提交 **`9f19cd26`**。
> 提交后 HEAD 与已验证工作区一致。Dart `lib/**` 另一摊未纳入。

---

## 附：与既有文档的关系

- 本文件**不取代** [全景派工大表]：大表是"谁领哪个包"的看板，本文件是"当前工作区实测 + 收口顺序"的体检单。
- 大表 §五 的"日程/统计未接"一条**已被工作区推翻**（实际已接、未提交）；合表时请把这两行状态更新。
