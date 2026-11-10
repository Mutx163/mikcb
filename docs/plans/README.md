# 设计文档与实施计划索引

本目录放「还没做完」或「做完了但需要回溯为什么这么做」的计划与规格。
**改代码前先来这里查一遍有没有既定方案**——避免重复设计，也避免破坏前人定下的约束。

---

## 🔴 进行中：Flutter → Jetpack Compose 迁移（2026-10-26 起）

> **接手重构与接线的 agent 从这里进** →
> [**Compose 迁移 · 唯一进度账**](2026-11-03-compose-status.md)
> 当前状态、剩余待办、阻塞归属、接活与避让、文档地图都在这一份里。
> 认领状态仍在本机 `.agents/compose-phase3/claims/`：**有文件的批次 = 有人在做，别碰**；
> 领用 = 新建 `claims/<批次号>.md`（文件即锁，新建成功才算领到）。**但认领文件可能过期，
> 开工前再用 `git status` / `git log` 核实是否真有人在动。**
> 仓库根 `AGENTS.md` 的「Compose 迁移」节也指向这里。

| 文档 | 作用 |
|---|---|
| [**Compose 迁移 · 唯一进度账**](2026-11-03-compose-status.md) | **当前主入口**：唯一进度来源、待办与阻塞归属 |
| [全景直通派工大表](2026-10-28-compose-master-dispatch-table.md) | 派工明细与逐包验收门槛（状态列已冻结） |
| [Phase 3.5 接线装配计划](2026-10-28-compose-phase35-wiring-plan.md) | 真实数据持久化（L1~L5）分层架构与演示数据清零标准 |
| [页面进度与认领台账](2026-10-26-compose-phase3-page-ledger.md) | 存量 78 屏 UI 迁移历史台账（Phase 3 归档） |
| [剩余页任务清单](2026-10-29-remaining-pages-tasklist.md) | F01–F24 历史任务清单与复核记录 |
| [迁移计划](2026-10-26-compose-migration-plan.md) | 总体方案、六条硬约束、五个阶段、回退方案、被否掉的方案 |
| [执行规格（doublecheck spec）](2026-10-26-compose-migration-spec.md) | Goal / Scope / 验收标准 / 红线，开工前必读 |
| [数据契约](2026-10-26-data-contract.md) | 盘上格式冻结：prefs key 的逐字段 schema（Phase 0 产出） |
| [Phase 2 业务族](2026-10-26-compose-phase2-families.md) | 逻辑层移植顺序、泳道纪律、Dart↔Kotlin 对拍机制 |
| [Phase 3 开工准备](2026-10-26-compose-phase3-prep.md) | 主题桥映射（色板/字阶/圆角）、族 7 原生覆盖核对、待定项 |
| [Miuix 组件选型](2026-10-26-compose-miuix-components.md) | 官方 Compose Miuix 组件对照表（哪些直接用 / 哪些要自绘） |

---

## 配套方案与清单（计划类，按需查阅）

- [Phase 3 L4 真机逐页对照清单](2026-10-27-compose-phase3-l4-checklist.md)｜R01 的必验项来源；清单仍写 `.ui` 包名与已删 flavor，按 `dev` 变体走
- [Phase 3.5 批次表](2026-10-28-compose-phase35-batches.md)｜批次划分与认领口径
- [全仓体检与收口计划](2026-10-28-full-software-audit-and-completion-plan.md)｜F 系列任务的来源
- [宽屏适配方案](2026-11-03-compose-widescreen-adaptive-plan.md)｜三档断点与 Rail 接入设计（对应进度账 R17 的剩余面）

---

## 历史计划（按时间倒序）

- [2026-11-07 去 Flutter 化阶段 2 施工单](2026-11-07-deflutter-stage2-workorder.md)（已执行：删 Dart / pubspec / CI 的 Flutter 步骤）
- [2026-11-07 去 Flutter 化 P4 四刀删除顺序](2026-11-07-deflutter-stage2-p4-deletion-order.md)（已执行：P4-A~P4-D，唯一未完成是 P2 真出包）
- [2026-11-07 插件迁移账（18 个 Android 插件）](2026-11-07-deflutter-stage2-plugin-ledger.md)（账本：摘除难度与替代件）
- [2026-11-07 全仓重构复核](2026-11-07-refactor-full-audit.md)（时点复核：基线 `3cf8d910b`）
- [2026-09-09 玻璃 UX 认知成本](2026-09-09-glass-ux-cognitive-cost-plan.md)
- [2026-08-24 UI 设计审计与重做](2026-08-24-ui-design-audit-and-redesign.md)
- [2026-08-23 上游 v2 桥接兼容](2026-08-23-upstream-v2-bridge-compat-plan.md)
- [2026-08-14 DSH Flutter Runner 插件](2026-08-14-dsh-flutter-runner-plugin-plan.md)
- [2026-07-11 导入课程随机配色](2026-07-11-import-random-course-colors.md)
- [2026-06-29 局域网编辑 Web 路线图](2026-06-29-lan-edit-web-roadmap.md)
- [2026-06-27 局域网编辑](2026-06-27-lan-edit-plan.md)
- [2026-04-25 节假日标记](2026-04-25-holiday-marking-plan.md)
- [2026-04-05 轻屿仓库（教务适配）集成](2026-04-05-qingyu-warehouse-integration-plan.md)
- [2026-03-24 桌面小组件实现](2026-03-24-home-widget-implementation-plan.md)
- [2026-03-22 时间方案与冲突角标](2026-03-22-time-scheme-and-conflict-badge-plan.md)
- [2026-03-22 学校适配](2026-03-22-school-adaptation-plan.md)
- [2026-03-22 多课表实现](2026-03-22-multi-timetable-implementation-plan.md)
- [教务仓库快速导入设计](warehouse-quick-import-design.md)

---

## 维护约定

- 新计划按 `yyyy-mm-dd-主题.md` 命名；**做完的不要删**，它是后来者理解既有取舍的唯一线索。
- 计划被新方案取代时：新文档里写清「取代了哪一份、为什么」，并在旧文档顶部加一行指向新文档。
- **审核 / 复核类文档不进本索引**（`*-audit.md`、`*-census.md`、`*-quality-*.md`、`*-tasklist.md`、`*-log.md`
  这类时点快照，如 `2026-11-02-compose-dialog-full-audit.md`）：它们是某一天的证据留存，不维护「当前状态」，
  挂进索引反而让人当成现行口径。要查现状看[唯一进度账](2026-11-03-compose-status.md)，要查某次结论按文件名或
  `git log -- docs/plans/` 找。
- 页面级任务的分工与进度**不放这里**（高频变化，放仓库会天天冲突）：统一放
  [Compose 迁移 · 唯一进度账](2026-11-03-compose-status.md)。
