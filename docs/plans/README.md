# 设计文档与实施计划索引

本目录放「还没做完」或「做完了但需要回溯为什么这么做」的计划与规格。
**改代码前先来这里查一遍有没有既定方案**——避免重复设计，也避免破坏前人定下的约束。

---

## 🔴 进行中：Flutter → Jetpack Compose 迁移（2026-10-26 起）

> **接手重构与接线的 agent 从这里进** →
> [**全景直通派工大表**](2026-10-28-compose-master-dispatch-table.md)
> 覆盖 7 大业务域与 10 个端到端工作包，做完本表即彻底达到 Flutter 生产水平。
> 认领状态在本机 `.agents/compose-phase3/claims/`：**有文件的批次 = 有人在做，别碰**；
> 领用 = 新建 `claims/<批次号>.md`（文件即锁，新建成功才算领到）。
> 仓库根 `AGENTS.md` 的「Compose 迁移」节也指向这里。

| 文档 | 作用 |
|---|---|
| [**全景直通派工大表**](2026-10-28-compose-master-dispatch-table.md) | **当前主入口**：直通 Flutter 水平的 10 个端到端工作包与派工看板 |
| [**Phase 3.5 接线装配计划**](2026-10-28-compose-phase35-wiring-plan.md) | 真实数据持久化（L1~L5）分层架构与演示数据清零标准 |
| [页面进度与认领台账](2026-10-26-compose-phase3-page-ledger.md) | 存量 78 屏 UI 迁移记录（Phase 3 归档） |
| [迁移计划](2026-10-26-compose-migration-plan.md) | 总体方案、六条硬约束、五个阶段、回退方案、被否掉的方案 |
| [执行规格（doublecheck spec）](2026-10-26-compose-migration-spec.md) | Goal / Scope / 验收标准 / 红线，开工前必读 |
| [数据契约](2026-10-26-data-contract.md) | 盘上格式冻结：prefs key 的逐字段 schema（Phase 0 产出） |
| [Phase 2 业务族](2026-10-26-compose-phase2-families.md) | 逻辑层移植顺序、泳道纪律、Dart↔Kotlin 对拍机制 |
| [Phase 3 开工准备](2026-10-26-compose-phase3-prep.md) | 主题桥映射（色板/字阶/圆角）、族 7 原生覆盖核对、待定项 |
| [Miuix 组件选型](2026-10-26-compose-miuix-components.md) | 官方 Compose Miuix 组件对照表（哪些直接用 / 哪些要自绘） |

---

## 历史计划（按时间倒序）

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
- 页面级任务的分工与进度**不放这里**（高频变化，放仓库会天天冲突）：见
  [台账](2026-10-26-compose-phase3-page-ledger.md) §2 说明的双文件制。
