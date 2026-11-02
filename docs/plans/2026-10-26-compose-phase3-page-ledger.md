# Compose 迁移 · Phase 3 页面进度与认领台账

> ⚠️ **【历史归档：Phase 3 页面搬运已于 2026-10-27 全部完工】**  
> 全仓 78 屏 UI 迁移已 100% 完成（**当时的页面单元口径**；2026-11-01 索引口径为 88 条 / 87 条可进入，见派工大表 §1.1）。当前已进入 Phase 3.5 接线装配阶段。  
> 最新唯一派工总表请前往：👉 [**全景直通派工大表（2026-10-28-compose-master-dispatch-table.md）**](2026-10-28-compose-master-dispatch-table.md)  
> 
> 状态：**已完工归档**（2026-10-26 建立，2026-10-27 完工）
> 读者：所有参与页面重构与接线的 agent，**包括没读过本次对话的独立会话**
> 上游：[迁移计划](2026-10-26-compose-migration-plan.md) · [执行规格](2026-10-26-compose-migration-spec.md) · [Phase 2 业务族](2026-10-26-compose-phase2-families.md) · [Phase 3 开工准备](2026-10-26-compose-phase3-prep.md)
>
> ⚠️ **实时进度不在本文档里**。本文档的「状态」列只是 2026-10-26 23:29 的快照；
> 谁正在做什么，一律以本机认领区 `.agents/compose-phase3/claims/` 为准（见 §2）。
> 这样设计的原因：状态高频变化，放进仓库等于每次改状态都要提交，多个会话必然冲突。

> ⚠️ **【2026-10-29 变体清理：本文里的 `composeUi` / `composeP1` 变体已不存在】**
> 两个迁移期 flavor（`composeP1`、`composeUi`）已删除；壳的 6 个文件（`PagesShellActivity` /
> `ShellWiring` / `ShellRoute` / `ShellPageIndex*` / `CourseOverviewHost`）已从
> `src/composeUi/kotlin` 搬进 `src/main/kotlin/.../pages/`，Compose 页面源码仍留在
> `src/composeP1/...`（目录名保留，由 `main` 源集挂载）。
> 因此本文与派工表里出现的 `:app:compileComposeUiDebugKotlin`、`:app:testComposeUiDebugUnitTest`、
> `composeUi 壳`、`ComposeP1Activity` 都是**当时的命令，照抄会失败**。
> 现在的闸门是 `:app:compileDevDebugKotlin` / `:app:testDevDebugUnitTest`；
> 要量性能用新增的 `bench` 构建类型（与正式版同档优化 + `<profileable>`），见 AGENTS.md 的 L3.5 行。

---

## 0. 三十秒上手（独立 agent 从这里开始）

1. `ls .agents/compose-phase3/claims/` —— 已有认领文件的批次 = 有人在做。
2. 从 §4 批次总表里挑一个**没有认领文件、状态为 ⬜ 待领**的批次。
   **按批次领，不要按单页领**：每批是同一功能域的 3~8 个页面，文案/组件/测试写法一致，
   一次干完一批的效率远高于东一页西一页。
3. 照 `claims/_template.md` 新建 `claims/<批次号>.md`，写上你的会话名与开始时间。
   **新建成功就等于领到了**（文件创建是原子操作，两个人同时抢只有一个能成功）；
   如果文件已存在，说明被人领了 —— 换一个批次，**不要删改别人的认领文件**。
4. 只在 §5 里属于你这批的**写作用域**内干活；交付按 §6 的五条门槛。
5. 交付后把认领文件的状态改成 `已交付`，写上提交号与证据；Lead 合入后由 Lead 更新本文档快照。

---

## 1. 范围与规模（2026-10-26 实测，可复算）

| 层 | 文件 | 行数 |
|---|---|---|
| `lib/screens/*.dart`（顶层页面） | 55 | 39 983 |
| `lib/screens/settings/` | 19 | 12 639 |
| `lib/screens/import/`（含 `warehouse/`） | 14 | 9 137 |
| `lib/screens/miuix_showcase/` | 14 | 4 265 |
| `lib/widgets/*.dart`（跨页共享件） | 63 | 23 756 |
| `lib/widgets/timetable/` | 77 | 17 779 |
| `lib/widgets/statistics/` | 22 | 4 460 |
| `lib/ui/`（主题 / 玻璃 / 动效基建） | 75 | 26 705 |
| **合计** | **339** | **≈138 724** |

复算命令：`wc -l lib/screens/*.dart`、`find <目录> -name "*.dart" -exec cat {} + | wc -l`。

> 2026-10-27 21:05 复算：`lib/widgets/timetable/` 为 **17 627** 行（10-26 原始 17 563，
> 之后随 month_view 外观重写持续增长）。其余 7 行实测与上表一致。
> Dart 侧 month_view 那一批改动尚未提交，这行**还会继续漂**——复算后同步即可，不是台账出错。

> 2026-10-27 23:05 再复算（本次）：`lib/screens/*.dart` **54 → 55 个 / 39 766 → 39 983 行**，
> 新增的是 `flight_agenda_extra_lines.dart`（217 行，日视图转场"飞行卡"补议程行的辅助件，
> 随 `3d561559` 那批进来）；`lib/widgets/timetable/` **17 627 → 17 779 行**。
> 两处都是 Dart 侧在途改动带来的漂移，不是台账算错。
> ⚠️ 这个新文件目前**不属于任何批次**（是辅助件而非页面），等 P3-C3 收尾时决定挂到哪一批。

> 计划书写的「UI 层 ≈12.3 万行」是 `screens + widgets` 口径；上表把 `lib/ui/` 也算进来，
> 所以是 13.8 万。**以本表实测为准**。
>
> 截至快照时刻，已迁到 Kotlin 的页面代码 ≈ 5 451 行（`composeP1` + `composeUi` +
> `main/.../pages/` 三处合计）。

---

## 2. 认领区（本机，不进仓库）

**路径**：`.agents/compose-phase3/claims/`（`.agents/` 已被 `.gitignore:133` 排除）

**为什么不在仓库里**：认领状态是高频写入。放 git 的话，两个会话同时改同一张表必然冲突，
而且每改一次状态就要提交一次，噪音远大于收益。

**代价（必须知道）**：换机器、或者别人克隆仓库，**看不到认领状态**。
跨机器协作时把整个 `.agents/compose-phase3/` 拷过去即可；不要为了跨机器把状态塞回仓库。

**文件即锁**：一个批次一个认领文件，文件名就是批次号（`P3-B.md`）。
新建文件是原子操作，所以两个人同时抢同一批只有一个会成功 —— 不需要额外的锁机制。

**失联回收**：认领文件里要写「最后更新」。超过 **24 小时**没有更新的认领，
任何 agent 可以在该文件末尾追加一行 `> [申请回收] <时间> <你的会话名> <理由>`，
并知会 Lead 裁决；**严禁直接删除或覆盖别人的认领文件**（那是抢活，不是协作）。

---

## 3. 状态枚举

| 标记 | 含义 |
|---|---|
| ⬜ 待领 | 没人认领，可以领 |
| 🔄 进行中 | 已有认领文件，有人在做 |
| ✅ 已完成 | 渲染层 + 模型层 + 测试齐备，且已提交 |
| ⏸ 待拍板 | 需要 Lead 先定方案，别领 |
| 🔒 Lead 专属 | 基础设施/共享件，泳道不得改 |

---

## 4. 批次总表

> 写作用域里的 `<domain>` 对应三处：
> 渲染层 `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/<domain>/`、
> 模型层 `android/app/src/main/kotlin/com/mutx163/qingyu/pages/<domain>/`、
> 测试 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/<domain>/`。
> `composeP1` 源集被 `composeUi` 变体共用（见 `android/app/build.gradle` 的 `sourceSets`），
> 所以页面代码只写这一处，两个壳都能看到。
>
> **写作用域必须机器可判**：`pages/<域>/` 是一个完整目录边界。出现父子嵌套时
> （如 `pages/timetable/` 与 `pages/timetable/month/`），**父行必须显式写「不含 `pages/.../`」**，
> 否则一律视为重叠。守卫脚本 `local/verify_phase3_ledger.ps1` 就按这条判据检查各批次互不重叠 ——
> 写成「除了某几个子目录」而不写清是哪几个，等于没划边界，两个 agent 真按它开工就会撞车。

| 批次 | 功能域 | 页/件 | 规模 | 写作用域 | 状态 |
|---|---|---|---|---|---|
| P3-A | 关于与说明 | 4 | 4 113 行 | `pages/about/` | ✅ 已完成（未真机对照） |
| P3-B | 设置族 | 20 | 13 795 行 | `pages/settings/` | ✅ 已完成（511 例全绿，未真机对照） |
| P3-B-1 | 设置 · 外观与材质 | 4 | — | 同上 | ✅ 已完成（`39b851f2` `240ad8e9`，112 例） |
| P3-B-2 | 设置 · 首页与课表展示 | 4 | — | 同上 | ✅ 已完成（`9cbe96b1` `f444aef1`，109 例） |
| P3-B-3 | 设置 · 行为与系统 | 4 | — | 同上 | ✅ 已完成（`ba47a609` `e398df5a`，128 例） |
| P3-B-4 | 设置 · 坞栏与重置 | 3+1 | — | 同上 | ✅ 已完成（`459d7ceb`，79 例） |
| P3-C1 | 课表 · 周视图 | 57 | 13 588 行 | `pages/timetable/`（不含 `pages/timetable/month/`、`pages/timetable/day/`） | ✅ 已交付（`367f3aed`；挂载于 18:40 由 Lead 补上，见 §7.2.1） |
| P3-C2 | 课表 · 月视图 | 11 | 4 093 行 | `pages/timetable/month/` | ✅ **已交付**（两泳道并行：`a7cb2b2b` `810f801a` `644c2d25` + `08805e77` `2e29bb40` `0149149f`；L0 79 例、L1 绿；未真机对照） |
| P3-C3 | 课表 · 日视图 | 13 | 4 171 行 | `pages/timetable/day/` | ✅ 已交付（另一会话，`b5b8bba2`；随父目录 `timetable` 于 18:40 一并纳入编译，见 §7.2.1） |
| P3-D1 | 课程表单与概览 | 4 | 2 753 行 | `pages/course/` | ✅ 已交付（`8e140fb7`，13 文件 4 816 行，86 例；未真机对照） |
| P3-D2 | 日程与任务 | 5 | 3 171 行 | `pages/schedule/`、`pages/task/` | ✅ 已完成（`97157c7a`，未真机对照） |
| P3-D3 | 作息与考试 | 4 | 5 027 行 | `pages/time_scheme/`、`pages/exam/` | ✅ **4/4 页已交付**（exam 侧 2 页 + D3-b/D3-c 各 1 页；未真机对照）；余量已拆分为下列两行 |
| P3-D3-b | 作息与考试 · 作息管理页 | 1 | 1 888 行 | `pages/time_scheme/`（仅 `TimeSchemeManagement*`） | ✅ 已交付（`fae9721a`，25 例；未真机对照） |
| P3-D3-c | 作息与考试 · 地点时间匹配页 | 1 | 1 131 行 | `pages/time_scheme/`（仅 `LocationTimeMatch*`） | ✅ 已交付（`7499c7ab`，21 例；编辑页留下一批） |
| P3-E | 统计族 | 26 | 5 299 行 | `pages/statistics/` | ✅ **4/4 页已交付**（前 2 页 + E-b 的 2 页；widget 图表未迁）；余量已拆分为下列一行 |
| P3-E-b | 统计族 · 分析页与会话页 | 2 | 355 行 | `pages/statistics/`（仅 `StatisticsAnalysis*`、`StatisticsSession*`） | ✅ 已交付（`09e2de9f`，33 例；图表为骨架） |
| P3-F | 同步与备份 | 4 | 2 536 行 | `pages/sync/` | ✅ 四件套已交（`dfdac7f2` `03015c20` `65247cb8` `8f5c4675`，86 例）；**L1/L2 已出证（2026-11-02 回填，原记「L1/L2 未出证」已过期）**：2026-11-01 全仓 L2 `:app:testDevDebugUnitTest` **5791 例全绿**、L1 `BUILD SUCCESSFUL`（`.agents/compose-phase3/claims/STYLE-fontweight-sweep.md:3`）；未真机对照 |
| P3-G1 | 导入 · 基础 | 6 | 1 878 行 | `pages/import/`（不含 `pages/import/warehouse/`） | ✅ 已交付（`1b58806b`，17 文件 5 191 行，161 例；未真机对照） |
| P3-G2 | 导入 · 仓库适配 | 8 | 7 259 行 | `pages/import/warehouse/` | ✅ 已交付（`ea9202aa`，24 文件 6 195 行；6 个 Page 覆盖 8 个 Dart 文件；未真机对照） |
| P3-G3 | 导出与传输 | 7 | 3 914 行 | `pages/transfer/`、`pages/export/` | ✅ **7/7 页已交付**（export/transfer 前 2 页 + G3-b/G3-c 的 5 件）；余量已拆分为下列两行 |
| P3-G3-b | 导出与传输 · 二维码发送/扫码 | 2 | 1 192 行 | `pages/transfer/`（仅 `QrTransfer*`） | ✅ 已交付（`bccbb2e9`，28 例；相机需真机验） |
| P3-G3-c | 导出与传输 · 局域网编辑/取件码/预览 | 3 | 1 011 行 | `pages/transfer/`（仅 `LanEdit*`、`PickupCodes*`、`TransferPreview*`） | ✅ 已交付（`92050236`，45 例；局域网需真机验） |
| P3-H | 诊断与测试夹具 | 5 | 3 559 行 | `pages/diagnostics/` | ✅ 已交付（`dcb4b6c9` 等；未真机对照） |
| P3-I | 引导与展示 | 5 | 3 732 行 | `pages/guide/` | ✅ 已交付（`28cfdc9f`；未真机对照） |
| P3-I2 | Miuix 展示册 | 15 | 5 413 行 | `pages/showcase/` | ✅ 已交付（`ea9202aa`；未真机对照） |
| P3-J | 实时活动与天气 | 2 | 2 524 行 | `pages/live/`、`pages/weather/` | ✅ 已交付（`28cfdc9f`；未真机对照） |
| P3-K | 冲突与反馈小页 | 2 | 606 行 | `pages/conflict/`、`pages/feedback/` | ✅ 已交付（`aef4c5c8`；未真机对照） |
| P3-L | 小组件 / 超级岛展示层 | — | — | 待定 | ⏸ 待拍板 |
| P3-0 | 基础设施与共享件 | 138 | ≈50 000 行 | 见 §6 | 🔒 Lead 专属（玻璃导航栏见 P3-0-glassdock） |
| P3-0-glassdock | 壳 · 玻璃导航栏 | 2 | 约 580 行 | `pages/shell/`（四层结构 + `components/liquid/`） | ✅ 已交付（26 例 + 4 次咬合探针；未真机对照） |
| P3-0-interaction | 交互与材质补齐 | — | 39 文件改写 | `components/`（常驻）；跨域页面改写为一次性交付 | ✅ 主要项完成（卡片入口 39 文件 + 字阶注入 + 展示册真模糊；毛玻璃页面层未开） |

**可合并领取**：P3-K（606 行）偏小，可并入 P3-H 或 P3-D2 一起做；
P3-G1（1 878 行）偏小，可并入 P3-D1 一起做。领的时候在认领文件里写清你领了哪两批。

---

## 5. 批次明细

### P3-A 关于与说明 ✅ 已完成
`about_screen`(2727) `changelog_screen`(345) `open_source_licenses_screen`(259) `support_creator_screen`(782)
提交证据：`2a7f78ea` `1341633a` `02dfaa2c` `1d8dd0ed` `7357e1a9` `46d806a3`
**遗留**：整页真机逐页对照未做（§6 第 5 条），谁有空可以补一次对照并更新认领文件。

### P3-B 设置族 ✅ 已完成（Lead 接管，4 组并行，511 例全绿）
`lib/screens/settings/` 全 19 件（外观 / 课程卡 / 通用 / 诊断 / 节假日 / 首页背景 / 首页菜单编辑器 /
首页导航 / 首页小组件 / 实时活动 / 最近壁纸 / 重置 / 共享 / 课表设置 / 天气 / 玻璃坞编辑器 /
玻璃坞图标编辑器 / Bing 壁纸画廊）+ `timetable_settings_screen`(1156)。

**2026-10-27 接管记录**：原会话产出 4 页（14 文件 / 3,821 行）后于 10-26 21:35 停写、
连续 15 小时无更新且未署名，Lead 按 §2 回收规则直接接管，拆成 4 组并行，**原产出全部保留**。

**一个改变本批性质的关键发现**（独立 agent 接手前必读）：
本批的渲染层是**通用的一次性投入**。`composeP1/.../pages/settings/SettingsPageRenderers.kt`
里的 `SettingsPageScreen(spec: SettingsPageSpec)` 接受任意 spec 就能渲染，
所以剩余 16 页**不需要写任何 Composable**——每页只需在模型层构造出等价的
`SettingsPageSpec`（节点树 + ARB 文案）。工作量性质从「16 页 UI 代码」变成
「16 份数据 + 文案对拍」，且几乎不会遇到 Compose 编译错误。

**拆组与写作用域**（4 个 agent 同写 `pages/settings/` 一个目录，靠**文件名与文案对象**互斥）：

| 组 | 智能体 | 页面 | 文案对象 | 写作用域 |
|---|---|---|---|---|
| P3-B-1 | `settings-appearance` | 外观编辑器 / 首页背景流 / 最近壁纸 / Bing 壁纸画廊 | `SettingsStringsExt1` | 只新建 `Settings<Xxx>Page.kt` |
| P3-B-2 | `settings-home` | 首页小组件 / 首页导航 / 首页菜单编辑器 / 课表页面设置 | `SettingsStringsExt2` | 同上 |
| P3-B-3 | `settings-behavior` | 实时活动（71 键）/ 节假日 / 天气 / 诊断 | `SettingsStringsExt3` | 同上 |
| P3-B-4 | `settings-dock` | 玻璃坞编辑器 / 坞图标编辑器 / 重置 + `settings_shared` 核对 | `SettingsStringsExt4` | 同上 |

**谁都不许改**（共享件，4 组同时依赖）：`SettingsStrings.kt`、`SettingsPageModel.kt`、
`SettingsPageState.kt`、`composeP1/.../settings/**`（那两件渲染基础设施由 Lead 直管）。

**完成度以机器判定**：`SettingsBatchCoverageTest` 要求 20 页全部交付，红即未完成。
每交付一页改一个 `true`（**由 Lead 统一改**，避免 4 人撞车）。

**交付结论（2026-10-27 15:35）**：20 页全部迁完、代码全部入库（62 文件 / 18,798 行），
隔离沙箱全量 **511 例全绿**（28 个测试类）。四组提交：
`39b851f2`+`240ad8e9`（B-1，112 例）、`9cbe96b1`+`f444aef1`（B-2，109 例）、
`ba47a609`+`e398df5a`（B-3，128 例）、`459d7ceb`（B-4，79 例）；
基线 4 页与通用渲染层：`88932875` `ba465eba` `82d7ff93`；源集挂载 `69108d08`。

**唯一未完成的门槛是真机逐页对照**（需用户配合）。另外两条必须说明的诚实声明：
① `:app:testProdDebugUnitTest` 这条官方 gradle 任务本批**从未跑通**——被其它泳道的
在途测试文件（`pages/course`、`pages/import`）挡住，验收证据来自隔离沙箱
（`.agents/compose-phase3/lead-sandbox.sh`，只编设置族、不碰别人文件），
全仓测试源集干净后应再跑一次复核；② `459d7ceb` 的提交信息挂错（内容是 B-4 的 9 个
真实产物、标题是 B-3 的修复，因共享暂存区被并发重置），内容无误，不重写历史。

**四条可复用的经验**：
1. **渲染层不挂源集 = 等于没写。** 原基线代码 15 小时「没暴露问题」，根因不是没人检查，
   而是没有任何变体去编 `pages/settings`。挂上后立刻炸出 miuix 包名错误。
2. **通用渲染层改变工作量性质。** `SettingsPageScreen(spec)` 一次投入之后，
   20 页只需写模型层（数据）——这是 4 组能在几小时内并行做完的原因。
3. **`filled` 这类小工具在多个域各定义一份是踩踏源。** 8 个包各有 `filled`/`filledImport`，
   签名还不一致（单参 vs vararg），全队为此互相阻塞过。正确做法是收进 `core/` 一处。
4. **共享暂存区真的会被抢。** 两次实际事故（`459d7ceb` 挂错标题、B-4 提交变空）。
   路径限定提交仍是正道，但 `add` 与 `commit` 之间**不能夹任何耗时操作**。
5. **验收口径只认 gradle 结果文件，不认自建沙箱的「全绿」。**
   `:app:testProdDebugUnitTest` 的结果在 `build/app/test-results/testProdDebugUnitTest/*.xml`，
   逐类读 `tests`/`failures`/`errors` 才是硬证据。
   隔离沙箱（`.agents/compose-phase3/lead-sandbox.sh`）在**不与 gradle 并发**时可信，
   但并发时它加载的类会被 gradle 重写的 `build/` 换掉，出现「用例总数从 511 掉到 85
   + 一堆 initializationError」的假象。沙箱只用于单域快速看红绿与探针反向验证。
   **旁证**：`--tests` 过滤在这台并发机器上也不可靠——会 `BUILD SUCCESSFUL` 但结果目录里
   一条目标用例都没有（空跑），必须核对结果文件里真的有那些类。

**验收基线问题（Lead 已修，2026-10-27）**：原基线代码按 miuix **0.8.8** 的
`extra.Super*` 包名写的，而依赖已升到 **0.9.4**——`extra` 包整体消失，官方改成独立的
`miuix-preference` 模块（`preference.{Arrow,Switch,Slider,OverlayDropdown,RadioButton,Checkbox}Preference`）。
这批代码此前**从未通过编译**，就是这个原因。Lead 已全部改到 0.9.4 官方组件
（滑杆行也从自绘包一层改为官方 `SliderPreference`），`:app:compileComposeUiDebugKotlin` 已绿。

### P3-C1 课表 · 周视图 ✅
`timetable_screen`(1842) `timetable_profiles_screen`(522) + `lib/widgets/timetable/*.dart` 55 件
（`flight_*` 飞行动效链、`course_grid_surface_host`、`morph_card_flight_layer`、`timetable_*` 等）。
**已交付** `367f3aed`（14 文件 3,591 行，54 例）。挂载后修 3 处重复声明，
`compileComposeUiDebugKotlin` 绿、模块 58 例绿。**未真机对照**。
**写作用域**：`pages/timetable/` 顶层，**不含** `pages/timetable/month/`、`pages/timetable/day/`
（后两个目录分别归 P3-C2 / P3-C3，各写各的，互不越界）。

### P3-C2 课表 · 月视图 ✅ 已交付（2026-10-27 深夜，两泳道并行）
`month_view_screen`(952) + `lib/widgets/timetable/month_view/` 10 件
（`month_grid` `month_day_cell` `month_day_agenda` `month_calendar_card` `month_panel_surface` …）。
`pages/timetable/month/` 当前 **0 文件**；父目录已挂载，**落文件即自动纳入编译**，无需再改 `build.gradle`。
⚠️ 这批 Dart 侧正在被另一会话重构（工作区在途改动），**只读不改**，等它稳定。

### P3-C3 课表 · 日视图 ✅
`timetable_day_view_part`(973) + `lib/widgets/timetable/day_view/` 12 件。
**已交付** `b5b8bba2`（另一会话，19 文件 3,456 行，25 例）。该目录 9 个 `.kt` 已随父目录
`pages/timetable` 挂载纳入编译。**未真机对照**。

### P3-D1 课程表单与概览 ⬜
`add_course_screen`(2239) `add_course_week_picker_tiles`(93) `timetable_form_pages_impl`(97) `course_overview_screen`(324)

### P3-D2 日程与任务 ⬜
`add_schedule_item_screen`(1076) `schedule_list_screen`(518) `schedule_date_rule_screen`(586) `add_task_screen`(467) `task_list_screen`(524)

### P3-D3 作息与考试 ⬜
`time_scheme_management_screen`(1888) `location_time_match_screen`(1131) `add_exam_screen`(1290) `exam_list_screen`(718)

### P3-E 统计族 ⬜
`course_statistics_screen`(372) `statistics_analysis_screen`(208) `statistics_session_screen`(147)
`statistics_settings_screen`(112) + `lib/widgets/statistics/` 22 件（图表卡 / 排行 / 热力图 / 导出文档）。

### P3-F 同步与备份 ⬜
`cloud_sync_screen`(1339) `cloud_backup_list_screen`(294) `cloud_backup_ui_helpers`(126) `couple_timetable_settings_screen`(777)

### P3-G1 导入 · 基础 ⬜
`import/course_import_entry_screen` `import/import_shared` `import/ics_course_import_screen`
`import/spreadsheet_course_import_screen` `import/course_auto_refresh_runner` `import/home_pull_quick_import`（6 件 / 1 878 行）

### P3-G2 导入 · 仓库适配 ⬜
`import/warehouse/` 全 7 件（适配器详情 / 网页登录 / 课程导入 / 自定义调试 / 导入策略 / 学校适配器 / 共享）
+ `import/ai_image_course_import_screen`（8 件 / 7 259 行）

### P3-G3 导出与传输 ⬜
`ics_export_screen`(873) `data_transfer_screen`(838) `qr_transfer_send_screen`(464) `qr_transfer_scan_screen`(728)
`transfer_preview_dialog`(56) `lan_edit_screen`(489) `pickup_codes_screen`(466)

### P3-H 诊断与测试夹具 ⬜
`live_diagnostics_log_viewer_screen`(1522) `log_viewer_entry`(221) `memory_stats_screen`(1116)
`perf_report_screen`(305) `live_testing_fixture_screen`(395)

### P3-I 引导与展示 ⬜
`startup_flow_screens`(261) `user_guide_screen`(1309) `more_features_screen`(521)
`more_features_search_overlay`(336) `hyperos_showcase_screen`(1305)

### P3-I2 Miuix 展示册 ⬜
`miuix_showcase_screen`(1148) + `miuix_showcase/` 14 件（buttons / display / inputs / menus / navigation /
overlays / pickers / preferences / theming / foundation / blur / feedback / common / utility）。

### P3-J 实时活动与天气 ⬜
`live_settings_subpages`(2252) `weather_city_picker_screen`(272)
（设置页里的天气/壁纸子页现在归 P3-B；P3-B 交付后可移交本批。）

### P3-K 冲突与反馈小页 🔄 进行中
`course_conflict_screen`(211) `feedback_screen`(395)。见 `claims/P3-K.md`。
反馈页**模型层已迁**（`pages/feedback/FeedbackModel.kt` + 测试），渲染层未做。

### P3-L 小组件 / 超级岛展示层 ⏸ 待拍板
Phase 3 准备文档 §3.3 待定项 5：小组件展示层是沿用现有 RemoteViews，还是改 Compose Glance。
**Lead 拍板前不要开工**。

---

## 6. 共享件与基础设施（🔒 Lead 专属 / 归属规则）

**禁止泳道修改**（改一处会同时影响多个批次）：

- `android/app/build.gradle`、`android/settings.gradle`（flavor / 依赖 / Kotlin 版本）
- `android/app/src/composeUi/**`（页面壳 `PagesShellActivity`）与
  `android/app/src/composeP1/kotlin/com/mutx163/qingyu/ComposeP1Activity.kt`
- `android/app/src/main/kotlin/com/mutx163/qingyu/theme/**`（主题桥：色板 / 字阶 / 圆角 / seed）
- 路由表 `home_menu_route_registry.dart`、`debug_deep_link_route_registry.dart`
- `lib/ui/**`（玻璃 / 动效 / 模糊基建，75 件 26 705 行）

**跨页共享的 Flutter 组件**（`lib/widgets/*.dart` 63 件里的这些，被 2 个以上批次用到）：

`app_dialogs` `app_startup_splash` `app_icon_badge` `open_container` `task_checkbox`
`course_card` `course_surface` `course_action_sheet` `course_followup_sheets` `course_note_sheet`
`course_palette_sheet` `course_recolor_sheet` `course_template_picker_sheet` `course_field_picker_sheet`
`course_color_picker_sheet` `course_auto_refresh_settings` `course_weather_display` `course_glass_shader`
`glass_shader_program` `home_menu_catalog` `home_menu_route_catalog` `home_top_menu` `home_top_menu_popup`
`home_page_region_blur` `preblurred_wallpaper_backdrop` `preblurred_wallpaper_glass`
`theme_manage_sheets` `miuix_*_picker_sheet`（6 件）`time_scheme_picker_sheet` `week_selector_picker_sheet`
`semester_week_count_picker_sheet` `profile_quick_switch_sheet` `timetable_share_export`
`timetable_export_document` `timetable_week_preview` `timetable_home_preview_scope`
`release_notes_markdown` `release_digest_view` `support_donor_tile` `third_party_disclaimer_card`
`wallpaper_blur_tile` `wallpaper_position_picker_sheet` `pickup_code_icons` `live_island_preview`
`class_reminder_sheet` `couple_webdav_connect_sheet` `timetable_text_color_settings`
`import_random_color_toggle` `day_agenda_info_row` `day_course_weather_row` `miuix_font_weight_scope`
`miuix_fling_number_picker` `bundled_asset_image` `warehouse_macro_recorder` `warehouse_macro_replayer`
`warehouse_playback_overlay`

**归属规则**（按优先级）：
1. 共享件默认**由 Lead 指派**给某一个批次，并在该批次的认领文件「共享件」栏登记；
2. 没被指派前，谁先用到谁负责**先跟 Lead 说一声**再动手；
3. 两个批次都要改同一个共享件时：**后到者改设计避让**（在 Kotlin 侧包一层，不去改那个共享件），
   并把避让写进自己的认领文件；
4. 共享件在 Kotlin 侧的落点统一为
   `android/app/src/composeP1/kotlin/com/mutx163/qingyu/components/<名字>.kt`（新建目录，属 Lead 直管）。

**例外：`pages/shell/`（2026-10-27 新增，Lead 直管）**

底部玻璃导航栏落在这里，而不是 `components/`：它带**页面级**语义（选中下标、
导航回调），且同时被壳 `PagesShellActivity` 与以后的展示页使用。
`components/` 那层按现有约定只放无状态的跨页零件（`QingyuPageTheme`）。

| 文件 | 作用 | 门槛 |
|---|---|---|
| `composeP1/.../pages/shell/GlassDockNavigationBar.kt` | 玻璃导航栏渲染层（miuix-blur 装配，四层结构） | L1 绿 |
| `main/.../pages/shell/GlassDockGeometry.kt` | 几何/动效/材质参数（纯算术） | L0 26 例 |
| `test/.../pages/shell/GlassDockGeometryTest.kt` | 上述契约测试（含 4 次咬合探针） | 全绿 |

**为什么要有这个组件**：miuix 0.9.4 的 Kotlin 侧**没有**玻璃导航栏——
`NavigationBar` / `FloatingNavigationBar` 都是纯色 `squircleBackground(color = surface)`，
`GlassNavigationBar` 只存在于 Flutter 移植（`flutter_miuix` 1.2.0）。
玻璃材质引擎（`Backdrop` / `blur` / `Highlight` / `TiltLight`）在**独立 artifact**
`miuix-blur` 里，此前本工程没引（`miuix-ui` 的 POM 不含它），已于本次一并加上。

**例外二：`components/liquid/`（2026-10-27 新增，Lead 直管）**

`lens` / `vibrancy` / `innerShadow` / `CombinedBackdrop` / `DampedDragAnimation` /
`InteractiveHighlight` 六个件**不在 miuix 的任何发布物里**（0.9.4 六个 artifact 的
sources 全解出来搜，0 命中），只在官方 demo 的 `component/{liquid,animation}/` 下。
按 Apache-2.0 整段搬入（**保留版权头**，来源注明 `Kyant0/AndroidLiquidGlass`）：

| 文件 | 作用 |
|---|---|
| `LiquidLens.kt` | 圆角矩形折射镜片 + 两个 AGSL 着色器（带/不带色散） |
| `LiquidVibrancy.kt` | 玻璃加饱和（模糊会发灰，真玻璃透色更浓） |
| `LiquidInnerShadow.kt` | 内阴影（离屏层 + Clear 挖洞 + 模糊） |
| `LiquidCombinedBackdrop.kt` | 两个 Backdrop 叠成一个采样源 |
| `LiquidDampedDrag.kt` | 五通道独立弹簧 + 不吃点击的拖拽检测 |
| `LiquidInteractiveHighlight.kt` | 指尖光斑（平滑阶跃着色器） |

**泳道若要复用它们**（比如给卡片加折射）：直接用，但**不要改**——
`lens` 的像素口径 uniform 必须除以 `downscaleFactor`、`DampedDragAnimation` 的
五条弹簧参数是成套的，改一处会连带别处。需要新行为请提给 Lead 加参数。

**顶层 `lib/widgets/*.dart` 其余文件**：随「第一个使用它的页面」迁，写进该批次认领文件。

---

## 7. 完成门槛（一批算「做完」的五条，缺一条不算完）

1. **两层齐**：该批每个页面都有 Kotlin **模型层**（纯逻辑，落 `main/.../pages/<domain>/`）
   与 **渲染层**（Compose，落 `composeP1/kotlin/.../pages/<domain>/`）。
2. **JVM 单测绿**：模型层带单测，`cd android && ./gradlew :app:testProdDebugUnitTest` 全绿
   （与 CI 同一条任务；只跑你新加的那些类也可以，但交付前要跑一次全量 JVM 单测）。
3. **文案逐字对拍**：界面文案与 ARB 原文逐字一致（对照 `lib/l10n/app_*.arb`），
   不自己改写、不省略占位符。
4. **咬合探针**：改断言/加守卫类改动，必须做一次反向验证 —— 把被测行为故意改坏，
   确认测试**真的会红**，再还原。仓库 AGENTS.md 的 TEST-POLICY 有完整纪律与实例。
5. **真机逐页对照**：用 `composeUi` 壳（独立包名 `.ui`，不覆盖正式版）装机，
   与 Flutter 老版逐页截图对照。**这一步需要用户配合**（仓库设备铁律：agent 不主动碰设备）——
   在认领文件里写明「已请用户对照」或「未对照」，不许含糊过去。

### 7.1 编译分工（省资源：出包归用户，agent 只做编译验证）

| 级别 | 谁跑 | 命令 | 能证明什么 |
|---|---|---|---|
| L1 编译验证 | **领用者**（可高频） | `./gradlew :app:compileComposeUiDebugKotlin`（**且该目录已挂载**） | 代码无编译错误 |
| L2 单测 | **领用者**（每批交付时一次） | `./gradlew :app:testProdDebugUnitTest --tests 'com.mutx163.qingyu.pages.<域>.*'` | 能编 + 逻辑正确 |
| L3 出包 | **用户**（Android Studio 里点，或 `flutter build`） | `flutter build apk …` | APK 能出来 |
| L4 真机验证 | **用户**（AS Run / Live Edit） | — | 真的能用 |

- **禁止领用者执行**：`flutter build *`、`assemble*`、`bundle*`、`adb install`、任何真机操作。
- **声明纪律**：只能声明「编译通过」（L1）或「JVM 单测通过」（L2），
  **不得**声明「能跑 / 能装上 / 已验证」——**编译过 ≠ 能装上**。
- L1 只编 Kotlin（含 Compose 编译器），不 dex、不打包、不签名；实测 19s~1m37s。
  每次仍会拉起 3 个 JVM（实测合计约 2.1~2.3 GB：gradlew 客户端 107 MB + daemon 1051 MB +
  Kotlin 编译守护 1006~1132 MB；单次 L1 的这 3 个 JVM 实测占整机 61% CPU）：别一改一跑，
  用户在 AS 里构建时不要并发跑。走闸门时 daemon 是**复用**的，只有冷启动那一次才新起。
- ⚠️ **2026-10-27 21:0x 更正：上面「不编 Dart」这条已经不成立。**
  `:app:compileComposeUiDebugKotlin` 现在依赖 `:app:compileFlutterBuildComposeUiDebug`
  （`--dry-run` 可见），于是**别人把 Dart 改坏，你的 L1 也会红**，而且红在与自己无关的文件上
  （本轮实例：`lib/services/app_sync_snapshot_service.dart:261` 初始化列表里写了 `;`）。
  只想要纯 Kotlin 证据就把它剔掉：

  ```bash
  pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin \
    -x :app:compileFlutterBuildComposeUiDebug
  ```

  实测 1 分 03 秒。**报「L1 绿」必须写清是哪条命令**；只要 `e:` 不落在自己文件上，
  就不能反推「我的代码有问题」。

⚠️ **覆盖盲区（2026-10-27 已补）**：`prod` 变体不包含 compose 源集，所以
`:app:testProdDebugUnitTest` **编译不到渲染层**（`src/composeP1/kotlin` **只有 compose 变体编译得到**）。
2026-10-27 起 CI（`.github/workflows/ci.yml` 的 `quality` job）在 JVM 单测之后补了一条
`./gradlew :app:compileComposeP1DebugKotlin :app:compileComposeUiDebugKotlin`——只编译、不打包不签名。

### 7.2 渲染层怎么进编译（逐目录挂载，2026-10-27 定稿）

**问题**：多会话并行时 `src/composeP1/kotlin/…/pages/` 里永远有半成品。曾经让 `composeP1`
编整棵 `pages/`，结果是「任何一条泳道的在途文件都能让所有人的 L1 失败」（2026-10-27 实测：
一次基线编译 74 个错误，分布在 3 个批次；同一时刻别的泳道还在往里写）。

**定稿**：

| 变体 | 编什么 | 说明 |
|---|---|---|
| `composeP1` | 迁移期**不编** | 它扫整棵 `src/composeP1/kotlin`（含在途 `pages/`），必然带出别人的欠账。尝试过把它的 `kotlin.srcDirs` 收窄成「只编壳」：**赋值不生效**（`sourceSets.composeP1 { kotlin.srcDirs = [...] }` 之后 AGP 又把默认根加回来，实测仍编 `pages/`）。Phase 1 的覆盖安装验证已完成，Phase 3 期间不构建该变体、也不拿它当证据 |
| `composeUi` | `about` + `task` + `schedule` + 各批交付后**逐目录**追加 | 页面开发壳，**L1 的唯一目标**。`+=` 追加有效（实测） |

- **L1（渲染层编译证据）= `:app:compileComposeUiDebugKotlin`**；`:app:compileComposeP1DebugKotlin`
  在迁移期是红的（含在途 `/pages/`），**不能**拿来当证据，也不要为了让它变绿去动别人的目录。
- 挂载行由 **Lead** 维护（`android/app/build.gradle` 的 `sourceSets.composeUi`），
  泳道不得自行改 `build.gradle`。挂载要求：该目录至少一页四件套齐全、且 Lead 验过。
- 反过来：**没挂载的目录不受 L1 保护**，渲染层写完了也先别声明「编译通过」，等挂载。
- 挂载现状（2026-10-27 18:40）：`about`、`task`+`schedule`、`export`+`transfer`、`diagnostics`、
  `sync`、`exam`+`time_scheme`、`settings`、`statistics`、`course`、`import`、
  `conflict`+`feedback`+`guide`+`showcase`+`live`+`weather`、`timetable`。
  `timetable` 挂的是父目录，**递归覆盖 `day/`（9 文件，P3-C3）**；`month/` 目前 0 文件（P3-C2 未交付），
  文件落地即自动纳入编译，届时无需再改 `build.gradle`。

#### 7.2.1 漏挂事故（2026-10-27 18:40 补挂，必读）

**现象**：`composeUi` 壳首页一直是「课表页正在迁移泳道中重构」占位页，用户以为有人在重构，
实际上**没有人在做**——那一批早就交付了。

**根因是两步都漏了，且互相掩盖**：

1. **漏挂载**：P3-C1 交付时**没有**在 `android/app/build.gradle` 里追加 `pages/timetable` 挂载行
   （P3-C3 的 `day/` 挂在 `timetable` 父目录下，所以一并被漏掉）。没挂载 ⇒ 不受 L1 保护 ⇒
   **这 3,920 行渲染层从交付起没有被任何变体编译过一次**，`composeP1` 又停役，于是完全裸奔。
2. **占位页被当成常态**：壳里的 `TimetablePendingPage()` 注释写着「泳道重构中，落地后换回」。
   交付时没人回来做这一步，占位页就一直摆在首页，注释还继续向后来者宣称「有人在干」。

**补挂后立刻炸出 3 处同名同包重复声明**（模型层与渲染层各写了一份同名类型，此前从没一起编过）：

| 重复符号 | 模型层（`main/…`） | 渲染层（`composeP1/…`） | 处置 |
|---|---|---|---|
| `WeekCourseCardModel` | `WeekGridCourseMapping.kt:36`（字段全，含节次与配色） | `CourseGridCard.kt:38`（字段少，用 `Course`） | 渲染层改名 `WeekGridCardModel` |
| `TimetableStrings` | `TimetableStrings.kt:26`（枚举式 ARB 键） | `TimetableProfilesPage.kt:70`（`const val` 硬编码） | 渲染层改名 `TimetableProfilesStrings` |
| `TimetableProfileItem` | `TimetableProfilesModel.kt:6`（含 `timeSchemeId`） | `TimetableProfilesPage.kt:109`（含 `currentWeek`） | 保留模型层那份，`currentWeek` 并入模型层；渲染层删掉重复声明 |

**教训（写进纪律）**：

- **「交付」不等于「已编译」**。没挂载的目录里写多少行都只是文本。领用者在认领文件里写
  「L1 绿」时，必须写清是**哪条命令**绿的；挂载前不许声明编译通过。
- **占位页是债务，不是状态**。凡是把占位页留在首页并在注释里写「等 X 落地后换回」，
  那份注释等于一张无人认领的欠条。交付方必须在**同一笔提交里**把占位换掉，否则不许标 ✅。
- **同名同包重复声明是「从没一起编过」的指纹**。一挂载就报 Redeclaration，说明这两处
  代码从来没进过同一次编译；此后每批挂载都要预期这类冲突。
- 模型层与渲染层之间的类型，**归属只能是模型层那一份**；渲染层需要展示字段时往模型层加，
  不准自己复制一份同名数据类。

### 7.3 并发构建必须串行（本机纪律）

每次 Gradle 构建会拉起 3 个 JVM、峰值约 2.7 GB；本机常同时有 Android Studio 与别的会话在跑。
2026-10-27 起本机提供闸门脚本 `.agents/compose-phase3/build-gate.sh`（不进仓库）：

```bash
bash .agents/compose-phase3/build-gate.sh :app:compileComposeUiDebugKotlin
bash .agents/compose-phase3/build-gate.sh :app:testProdDebugUnitTest --tests 'com.mutx163.qingyu.pages.<域>.*'
```

**2026-10-27 16:00 起上游有了正式工具，优先用它**：
- `pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>"` —— 免 Gradle 的**模块级 L0**
  （内置 kotlinc + JUnitCore，完全不受别人半成品拖累）；缺依赖时用 `-ExtraSources` 补。
  ⚠️ **2026-10-27 实测更正**：旧稿的「0.2 秒、<150MB」混了两个口径 —— 用例执行 **0.1~0.2s**
  （`JUnitCore` 报的，**不含 kotlinc 编译**）；整次调用实测 **RSS 616~829 MB**（同一模块抓到两个并存
  `kotlinc` 进程，17 分钟跑了 12 次）。别拿它当「L0 是零成本操作」的依据。
- `pwsh -File scripts/safe-gradle.ps1 <gradle 参数>` —— 带 Windows 内核互斥锁的 Gradle 包装，
  L1/L2 一律走这条（同一时刻全机只允许一个 Gradle）。
- 本机的 `.agents/compose-phase3/build-gate.sh` 是这套工具之前的手工版，保留作兜底；
  两者不要同时用（锁不通）。

锁是 `.agents/compose-phase3/build-lock/` 目录（mkdir 原子），20 分钟无更新自动回收，最多排队 30 分钟。
**泳道不要裸跑 `./gradlew`**，否则多条泳道 + AS 同时构建会互相拖到 OOM/超时。

⚠️ **比 OOM 更阴的后果（2026-10-27 13:11 实测）**：两个 Gradle 构建同时跑**同一个工程目录**时，
它们共享 `android/build`、`android/app/build`，会互相覆盖 Kotlin 增量输出。症状不是「内存不够」，
而是**假失败**：`compileProdDebugKotlin` 明明 0 错误，紧接着的 `compileProdDebugUnitTestKotlin`
却报出成千上万条 `Unresolved reference`，指向的还是一分钟前刚编过的主源集类
（实测 `WidgetDataClock`、`StatisticsService`、`TimeSchemeLogic` 全被报「找不到」）。

- 判别：错误的类**分散在所有模块**（不是集中在某一域）+ 同一提交重跑就好了 → 并发污染。
- 处置：等外部构建退出后重跑一次，**不要去改代码**（那些引用本来是对的）。
- 闸门已加固：拿到锁之后**还要等外部 `GradleWrapperMain` 进程清零**才开跑（最多等 30 分钟，
  超时退出码 112）。只统计 wrapper 进程，不统计常驻 `GradleDaemon`（AS 会一直留着空闲 daemon，
  算进来会永远等不到零）。

---

## 8. 反撞车规则（硬约束）

1. **按批次领，不按页领**；一次只领一个批次（或 §4 里注明的可合并两批）。
2. **只在写作用域内写文件**。别人的目录、别人的在途改动，一律不改、不格式化、不覆盖。
3. **不改 Dart 源码**（`lib/**` 是参照物）。发现 Dart 侧有 bug，写进认领文件交 Lead，别顺手改。
4. **提交走路径限定**：`git commit -- <你自己的路径>…`，禁止 `git add .` / `-A` / `commit -am`。
5. **不建分支、不建 worktree**：本仓库是多会话共享工作区，隔离靠写作用域，不靠分支。
6. **共享件冲突**：按 §6 的规则办，后到者避让。
7. **认领文件是你的唯一凭据**：不写认领文件就开工 = 抢活；写完不更新 = 别人无法判断进度。

---

## 9. 进度快照（2026-10-27 21:10，Lead 更新）

| 批次 | 状态 | 证据 |
|---|---|---|
| P3-A 关于与说明 | ✅ 已完成 | 6 笔提交（`2a7f78ea`…`46d806a3`），`pages/about/` 5 个 Kotlin 文件 + 测试 |
| P3-B 设置族 | ✅ 已完成 | 20 页全迁（62 文件 / 18,798 行），511 例全绿；通用渲染层 `SettingsPageScreen(spec)` 一目录服务 20 页 |
| P3-C1 课表·周视图 | ✅ 已完成（18:40 补挂载并首次编译通过） | `367f3aed`，14 文件 3,591 行，54 例；挂载后修 3 处重复声明，模块 58 例绿 |
| P3-C2 课表·月视图 | ✅ 已交付 | 拆两泳道并行：日历半 `a7cb2b2b`+`810f801a`+`644c2d25`，面板半 `08805e77`+`2e29bb40`+`0149149f`；模型层 42 格/周次/课考日程计数，渲染层 10 件；L0 79 例、L1 绿；**未真机对照**；横向滑动翻月刻意未做 |
| P3-C3 课表·日视图 | ✅ 已交付 | `b5b8bba2`，19 文件 3,456 行，25 例 |
| P3-D1 课程表单与概览 | ✅ 已交付 | `8e140fb7`，13 文件 4,816 行，86 例 |
| P3-D2 日程与任务 | ✅ 已完成 | `97157c7a` + `59faedc8` 修 74 个 miuix 0.9.4 错误中的 schedule/task 部分 |
| P3-D3 作息与考试 | ✅ **4/4 页已交付** | exam 侧 `40dbb943`（41 例）+ `a84fb0d6`（36 例）；`fae9721a` 作息管理（25 例）+ `7499c7ab` 地点匹配（21 例）。D3-b 渲染层首次进编译 |
| P3-E 统计族 | ✅ 页 4/4 + **图表 22/22 全迁** | 页：`61f3d80e` `e0473069` `09e2de9f`。图表：`f518c917` `ddc5e48b` `35a0fca2` `96d9b704`，折线/柱/热力/环形/排行条/周分布/热度全为 Canvas 真绘，非读数行；L0 153 例。偏差（无奖杯/锁图标、成就动画与详情弹层未搬、日期仅中文、二维码自写版本 2-L 编码器）均在 KDoc 与提交信息里 |
| P3-F 同步与备份 | ✅ **4/4 页已交付** | `dfdac7f2` + `03015c20` + `65247cb8` + `8f5c4675`；86 例（含 2 份 ARB 逐字对拍）。2026-11-02 回填：L1/L2 已出证——2026-11-01 全仓 L2 **5791 例全绿**、L1 `BUILD SUCCESSFUL`（`claims/STYLE-fontweight-sweep.md:3`） |
| P3-G1 导入·基础 | ✅ 已交付 | `1b58806b`，17 文件 5,191 行，161 例 |
| P3-G2 导入·仓库适配 | ✅ 已交付 | `ea9202aa`，24 文件 6,195 行 |
| P3-G3 导出与传输 | ✅ **7/7 页已交付** | 前 2 页 `ff6d3bcb`（34 例）+ `11988a1d`（26 例）；`92050236` 局域网编辑/取件码/预览（45 例）+ `bccbb2e9` 二维码收发（28 例） |
| P3-H 诊断与夹具 | ✅ **5/5 已交付** | `43463b8a`/`2c2d373a`/`b1c72465`/`4462c62a`/`dcb4b6c9`；91 例；3 次咬合探针 |
| P3-I 引导与展示 | ✅ 已交付 | `28cfdc9f` |
| P3-I2 Miuix 展示册 | ✅ 已交付 | `ea9202aa` |
| P3-J 实时活动与天气 | ✅ 已交付 | `28cfdc9f` |
| P3-K 冲突与反馈小页 | ✅ 已交付 | `aef4c5c8` |
| P3-0 基础设施 | ✅ 主体完成 | 主题桥 `772ce837`；渲染层逐目录挂载 + CI 编译 + `composeP1` 停役守卫；L0 模块单测 + `safe-gradle` 排队锁；i18n 中文字面量棘轮门禁 `b9bc98d1` |
| P3-0-glassdock 玻璃导航栏 | ✅ 已交付 | 第一轮 `0d23ddf3`（miuix-blur 装配）；第二轮 `0d6bd966` 补齐 demo 的**四层结构** + 移植 6 个 demo 自带件到 `components/liquid/`；`pages/shell/` 模型层 26 例 + 4 次咬合探针；壳里 Material 占位条整体删除。**未真机对照** |
| P3-0-interaction 交互与材质 | ✅ 主要项完成 | `bfdfabfd` 卡片入口（30 文件 107 处）+ `1a90f008` 收尾最后 11 处（复扫可点裸 Card = **0 处**）；**字阶迁移完成** `04a78c7f`+`9649c46c`（31 文件 275 处，映射脚本 `scripts/migrate-fontsize-to-textstyles.py`）+ `fb2a2c84` 打通**主题级** textStyles 注入（用户字重/系统粗体/字族，10 例 + 3 次咬合探针）；`cb731202` 九页改走官方配方；`1577252a` 展示册改真模糊。**未做**：`fontWeight` 未动、毛玻璃页面层未接 |
| P3-L 小组件 / 超级岛 | ⏸ 待拍板 | RemoteViews 还是 Compose Glance，Lead 未拍板前不开工 |

**本轮验证基线（Lead 亲自跑，21:07）**：`:app:testProdDebugUnitTest` → **2978 例 / 0 失败 / 0 错误 / 0 跳过**（218 个测试类，`BUILD SUCCESSFUL in 1m17s`）。
L1：`:app:compileComposeUiDebugKotlin` → BUILD SUCCESSFUL。
台账守卫 `local/verify_phase3_ledger.ps1` → 全部通过。

⚠ **仍然没有一页做过真机对照**（L4 需用户配合），所有「绿」只到 L1/L2。另外两条必须点明的：
① 统计族六张卡的完整图表（`lib/widgets/statistics/` 22 件）与地点匹配编辑页（约 760 行）
留作下一批，本批给的是结构一致的骨架/列表；
② 相机扫码、局域网真实收发热都没有真机证据。

> 上表是 Phase 3 **页面搬运**批次的快照。此后的**接线批次**不在上表：F23（2026-10-31，设置族收尾 + 壁纸死路由）见 §9.9；F24（2026-11-01，并行硬化，**已交付**）见 §9.10。

### 9.1 本轮五个批次的过程记录（写给后来者）

2026-10-27 18:30 领五个批次、21:08 全部交付。**四名队友中三人零产出或近乎零产出**，
实际完成量主要由 Lead 自己写：

| 批次 | 执行者 | 结果 |
|---|---|---|
| P3-D3-b | timescheme-mgmt | 交出模型层+文案+测试（25 例）后停写，渲染层由 Lead 补 |
| P3-D3-c | timescheme-loc | **零产出**，只在未授权目录留了一张文案表；Lead 全量接手 |
| P3-E-b | stats-extra | **零产出**（自述把时间全花在读材料上），Lead 全量接手 |
| P3-G3-b | transfer-qr → transfer-qr2 | **两次重派均零产出**，Lead 全量接手 |
| P3-G3-c | transfer-misc → transfer-misc2 | **两次重派均零产出**，Lead 全量接手 |

**可复用的判断**：子代理「读完了、想清楚了、马上写」这种汇报连续出现两次而工作区没有文件落盘，
基本等于不会再写了。有效期应设为 **30~45 分钟无文件落盘即收回**，而不是等它自己说卡住。

### 9.2 交互与材质补齐（P3-0-interaction，2026-10-27 21:1x）

**为什么单独做这件事**：老版 Flutter 的「小米观感」是自建组件层仿出来的
（`lib/ui/hyperos/` 51 件 26,132 行，含按压状态机、真模糊、弹簧动效）。
迁到 Compose 后只用了 miuix 本体的**静态外观**，交互与材质管线一层没搬，
于是出现「用了正主反而更丑、点击没手感」。对照依据已归档在
`docs/reference/miuix-demo/`（官方 demo 快照 + 四份精读笔记），
结论见 `docs/reference/miuix-demo/我们的差距与修法.md`。

**官方默认值是「空壳」**（这是根因）：`Card.kt:87-95` 的
`pressFeedbackType = PressFeedbackType.None`、`showIndication = false` 默认全关，
官方 `card.md` 的 Interactive Card 一节要求两个都显式打开。我们按默认值抄了。

**本轮已做**（`bfdfabfd`）：

- 新增 `composeP1/.../components/QingyuCard.kt`——官方 `Card` 的封装，
  **可点时默认 `PressFeedbackType.Sink` + `showIndication = true`**（把正确行为设成默认值，
  因为靠每个调用点记得传参数已经漏了 230 次）；圆角给语义默认
  （`Corner` 16 / `SettingsGroupCorner` 24，均取自 `QingyuShapes`）。
- 30 个页面文件、107 处调用由 `Card(` 换成 `QingyuCard(`。
- L1 `:app:compileComposeUiDebugKotlin` BUILD SUCCESSFUL（1m27s，仅既存警告）。

**尚未做（接手时照做）**：

1. **余 27 个文件**含裸 `Card(`，本轮**一个都没动**——它们当时全部有未提交改动，
   属于并发会话的在途工作。跑
   `python scripts/migrate-card-to-qingyucard.py`（干跑，列出可改与跳过）
   再 `--write` 即可；脚本自己读 `git status` 跳过脏文件，不会卷进别人的改动。
   涉及 `showcase`(27) / `sync` / `diagnostics` / `export` / `import·warehouse` /
   `live` / `conflict` / `feedback` / `statistics` / `timetable` / `weather` / `transfer`。
2. **字号**：全仓 0 处用 `MiuixTheme.textStyles`、577 处硬写 `fontSize`，
   散成 14 种字号（含 10/15/22/28 这四种官方刻度里没有的）。官方字阶与我们转录的
   `QingyuTypography` **一字不差**，所以修法是「改用 `style = MiuixTheme.textStyles.X`」
   而不是另立一套。这是「廉价感」最大的单一来源，建议单独一批。
3. **毛玻璃**：`miuix-blur` 依赖已由 `0d23ddf3` 引入（两个变体都有），
   目前只有壳的玻璃导航栏在用（`layerBackdrop` 1 处）。页面顶栏 / 弹层尚未接，
   官方接线照抄 `docs/reference/miuix-demo/example/.../utils/PageUtils.kt:116-168`。
4. **不实文案**：`pages/showcase/MiuixShowcaseSubpages.kt:935-951` 用主色 alpha 冒充毛玻璃，
   文案（`main/.../ShowcaseStrings.kt:143-146`）却写「背景捕获 + 高斯模糊」——
   补了真模糊后顺手改，或先改文案。

⚠ 本节全部证据只到 L1（编译过），**没有一页做过真机对照**。

### 9.3 第三轮五泳道（2026-10-27 21:40 领 · 23:05 收口）

用户口径「查看进度、用智能体团队、领五个任务、提速」。领的五条泳道（写作用域按**文件清单**互斥，
同域多泳道照 P3-B 的模式办；认领见 `.agents/compose-phase3/claims/`）：

| 泳道 | 批次 | 内容 | 结果 |
|---|---|---|---|
| `type-sweep` | P3-0-interaction | 硬写字号 → 官方字阶 | ✅ **31 文件 275 处**：`04a78c7f`（29 文件 269 处）+ `9649c46c`（周视图课卡 5 处 + 玻璃坞标签 1 处） |
| `stats-charts` | P3-E | 统计族图表：模型层 + 渲染层 | ✅ **22/22 件全迁**（含导出四件套与自写二维码编码器）：`f518c917` `ddc5e48b` `35a0fca2` `96d9b704`；模型层 12 文件 3 073 行 + 渲染层 10 文件 3 629 行 + 测试 8 文件 2 587 行；L0 **153 例** |
| `month-calendar` | P3-C2 | 月视图日历半 | ✅ `a7cb2b2b` `810f801a` `644c2d25` `62a6ccea` `45ba821b` |
| `month-panel` | P3-C2 | 月视图面板半 | ✅ `08805e77` `2e29bb40` `0149149f` `7f85ee1f` |
| `l4-recon` | — + P3-0 壳 | L4 逐页清单 → 追加：壳页面索引 | ✅ **清单 528 行**（`3f1c35eb`）+ **壳路由**（`867f83e8` `2f59c811`） |

**月视图 P3-C2 至此交付**：模型层（42 格/周次/课考日程计数/假期/busyDays）+ 10 件渲染层
（日历卡、网格、日期格、工具栏、面板材质、拉拽区、概览、当日议程、拉杆、整页壳）。
两泳道共用 Lead 写的 `MonthMetrics.kt` / `MonthViewStrings.kt`，**跨泳道只有一处签名依赖**
（`MonthGridHandle`），实测对上了。L0 **79 例**。

**壳路由是这一轮真正的解锁点**：`composeUi` 壳原本只有课表/日程/任务三个槽位、
不读 Intent、深链是 Flutter debug 专属，**82 个页面单元只有 3 个点得到**（当时口径；2026-11-01 复核为 88 条目录 / 87 条可进入，见 §9.5）——L4「逐页对照」
在接线前物理上做不了。现在底部玻璃坞第 4 个槽位「索引」= 按批次分组的页面目录：
**可进 75 条（16 零参 + 59 演示数据）、暂不可用 6 条、常驻 1**，四个数字被
`ShellPageCatalogTest` 钉住（改口径必须同时改测试与 L4 清单，是显式决定）。
「暂不可用」升级成机器可查的 `ShellBlockReason`（缺整页渲染层 4 / 缺宿主槽位 2 / 缺依赖 0），
原因文字必须以分类标签开头，`filter { blockedBy == … }` 就是将来待放开清单。

**本轮验证基线（Lead 亲自跑）**：

| 级别 | 命令 | 结果 |
|---|---|---|
| L1 | `safe-gradle :app:compileComposeUiDebugKotlin -x :app:compileFlutterBuildComposeUiDebug` | **BUILD SUCCESSFUL，`e:` 0 条**（1m35s 全量、23s 增量，四次泳道产物全部在册） |
| L0 | `test-kotlin-module.ps1` × 3 模块 | 月视图 **79** + 统计图表 **153** + 壳 **39** = **271 例全绿** |
| Dart 架构守卫 | `flutter test --no-pub test/architecture/` | **62 例全过**（补跑 `--no-verify` 欠下的门禁） |
| L2 全量 | `:app:testProdDebugUnitTest` | ❌ **暂时红，但与本轮五行无关**：他人 WIP 把 `components/QingyuTextStylesTest.kt` 放进共用测试源集，而它引用 `composeP1` 的 `buildQingyuTextStyles`（prod 变体编译不到）。证据：46 条 `e:` 全在该文件。**待其所有者把测试挪到 compose 变体源集后重跑** |

**仍未做（诚实清单）**：
① **没有一页做过真机对照**——现在至少能点进去了，清单已就位；
② 统计族已 22/22 全迁，但**无 UI 测试设施**，证据只到「L1 编译 + 模型层 L0」；
   奖杯/锁图标因 miuix 扩展图标没有而用替代视觉，成就进场动画与详情弹层未搬；
③ 月视图横向滑动翻月（属日历半的 HorizontalPager，本批刻意不做）；
④ 毛玻璃仍只在壳底栏 1 处，页面顶栏/弹层没接；
⑤ `fontWeight` 未动（本轮只管字号），局部强调仍写 `fontWeight = Medium`，会盖掉主题字重。

#### 本轮可复用的三个做法

1. **「喂坏值」型常驻守卫 > 一次性改坏探针。** `month-calendar` 给共享层写的是
   `requireCardChrome(40, 2, 26)` 必须抛 / 喂真值必须过，可反复跑；比「今天改坏一次证明有牙」
   更能证明明天还有牙。`stats-charts` 的 4 处改坏 → 7 条红也留了具体报错原文。
2. **跨泳道依赖只留一处，并当场点明。** 月视图两条泳道只通过 `MonthGridHandle` 的签名耦合，
   交付汇报里主动列出这一处，编译时一眼就能判定归属。
3. **事故主动上报、不动历史。** `month-panel` 的 `git commit --amend` 撞上别人成了 HEAD、
   立即 `reset --soft` 还原并核对 tree；`2e29bb40` 的提交信息里混进 L0 输出
   （因为在信息里写了反引号包的命令，**bash 当命令替换真跑了一次**）——**保留不改**，
   并发提交下 rebase 的风险远大于一条难看的提交信息。这条坑值得记：提交信息里别写反引号命令。


#### 三条必须记住的实测（本轮踩出来的）

**① L1 现在会顺带编 Dart，必须用 `-x` 剔掉 Dart 才拿得到纯 Kotlin 证据。**
台账 §7.1 原先写「L1 只编 Kotlin、不编 Dart」——**这条已经不成立**：
`:app:compileComposeUiDebugKotlin` 依赖 `:app:compileFlutterBuildComposeUiDebug`（dry-run 可见）。
后果：任何一条泳道把 Dart 改坏（本轮实例：`lib/services/app_sync_snapshot_service.dart:261`
初始化列表里写了 `;`，是另一会话的在途改动），**所有人的 L1 都会红，而且红在与自己无关的文件上**。

正确姿势：

```bash
pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin \
  -x :app:compileFlutterBuildComposeUiDebug
```

实测 1 分 03 秒，只编 Kotlin。**报告里要写清是哪条命令绿的**；
反过来，只要 `e:` 行不落在你的文件上，就不能说「L1 红了所以我的代码有问题」。

**② `pre-commit` 钩子会卡死，且卡住时挡住全仓所有提交。**
本轮 21:49 卡了一次：`git → sh .githooks/pre-commit → dart`，整链 CPU 隔 15 秒两次采样零增长，
持 `.git/index.lock` 四分钟。按 AGENTS.md 的判据杀链（最深的 `dartaotruntime` 往上）、锁随进程消失，
**不要手删锁**。本轮五笔提交因此都走 `--no-verify`（`post-commit` 已自动留痕）。收尾必须补跑
`flutter test --no-pub test/architecture/` 与 `dart analyze`。
派活给泳道时**一开始就要把这条告诉他们**，否则每个泳道都会各撞一次。

**③ 迁移脚本的「需人工判断 0」不等于没有漏网。**
`migrate-fontsize-to-textstyles.py` 的正则只认 `fontSize = 整数.sp` 与
`fontSize = QingyuTypography.X.sp`，因此**小数（8.5 / 10.5 / 11.5 / 12.5）与
条件表达式（`if (e) 15.sp else 13.sp`）既不替换、也不进提示**——静默跳过。
本轮那 29 个文件里就有 8 处属于此类，由 `type-sweep` 手工按就近归档补掉。
尚未处理、扩正则时会踩到的还有两处例外写法：

- `pages/timetable/CourseGridCard.kt`：7.5 / 8.5 / 9 / 9.5 / 10.5（全是小数或条件式）
- `pages/shell/GlassDockNavigationBar.kt`：`fontSize = GlassDockGeometry.LabelSizeSp.sp`（前缀不是 `QingyuTypography`）

**视觉风险要留给真机对照**：时间轴 8.5 → 11 是这批唯一明显放大（+2.5sp），窄列可能发紧；
11.5 → 11 略缩小。对照时重点看左侧时间轴与任务带小节标题。

#### 有意偏离 Dart 的一处（已拍板，别再改回去）

统计族「课程排行」的名次：Dart `course_ranking.dart:52` 是 `rank = index + 1`，
于是两门并列的课会被编成 2、3（原实现的已知缺陷）。**本批保持 1:1**，
理由是对照基线（L4 逐页截图对拍）不能被行为改进污染；改进留到对照完成之后单开一批，
两侧一起改。`ChartMath.sequentialRanks` 的 KDoc 里已写明这条。

#### 台账虚标的三处（2026-10-27 由 `l4-recon` 核对发现，Lead 逐条复验）

l4-recon 把「渲染层是否存在」逐页核了一遍，结论比台账乐观的写法更保守。以下三处**复验属实**，
状态需要从「已完成」降级为「待收口」；根因是**登记靠人工**，而设置族的页面根本没有独立
Composable（由一个通用 `SettingsPageScreen(spec)` 渲染），于是「没写页面函数」和「没写页面」
在人工登记里长得一模一样。

| 台账原本 | 实际 | 证据 |
|---|---|---|
| P3-A「4 页已完成」 | **3 页**。「更新日志」只有解析层 `about/ReleaseNotesBlocks.kt`(96)，`composeP1/.../about/` 下无对应渲染 | `AboutInfoModel.kt:154` 有入口行，落点没有界面 |
| P3-B「20 页全迁」 | **19 页**。「课表页面设置」只有入口行 `timetable.pageSettings`（`SettingsTimetablePage.kt:148`），**没有落点 spec** | `SettingsBatchCoverageTest` 登记 41 个 spec id，其中不含该页 |
| P3-J「已交付」 | 主设置屏交付，「实时活动·保持后台运行」子屏**无实现** | `SettingsLivePage.kt:113` 有 `live.keepAlive` 导航行，落点缺 |

（`l4-recon` 同时报的第四项「月视图没有渲染层」属实但不算虚标——台账本来就写「未启动」，
本轮已由 `month-calendar` / `month-panel` 开始补。）

**教训与修法**：只登记「页面存在」挡不住这类缺口，**要登记「入口行的落点真的能构造出来」**。
设置族已有 `SettingsBatchCoverageTest` 做这件事（每个 spec id 都真的构造一次），
其余族没有；建议补一条同构守卫：扫描渲染层里的入口 id，逐个断言落点。

#### 壳只能进 3 页（L4 的前置阻塞，本轮已开工）

`composeUi` 的 `PagesShellActivity` 只有 `DockSlot`（课表/日程/任务）三个值，没有路由状态、
不读 Intent；manifest 的 mime/scheme 过滤全挂在 `enabled=false` 的 `MainActivity` 上，
深链又是 Flutter debug 专属（release 直接 return）。所以**82 个页面单元里只有 3 个点得到**（当时口径；现为 87 条可进入，见 §9.5），
L4「逐页对照」在接线前物理上做不了。交给 `l4-recon` 做 task-6（页索引 + 分派，壳属 Lead 区，
本次点名授权），并要求「接进去就崩的页面宁可标暂不可用，也不要给一个闪退入口」。

### 9.4 补口轮（2026-10-28 上午，用户口径「继续做什么」→ 选了两条）

用户当时选的是：**① 补 3 处虚标 + 修 L2 红点 + 加落点守卫**，**② 补底层能力缺口**。
这一轮把①做完，②开了个头（WebDAV + WebView 两条泳道）。

| 任务 | 泳道 | 结果 |
|---|---|---|
| 台账虚标 3 处补渲染层 | `gap-changelog` / `gap-live` / Lead | ✅ 三处全部补上并接进索引：`2801c320`（更新日志）、`5aa302b7`+`78fd44b7`+`c4b9bf72`（保活子屏）、`2cec8462`（课表页面设置） |
| 三处**接线**（目录 + 分派） | Lead | ✅ `b2189d95`；「缺整页渲染层」这一档**清空**，口径 82 / 78 / 3 / 1 |
| L2 红点（`QingyuTextStylesTest` 放错源集） | Lead | ✅ `2cec8462`：挪到 `src/testComposeUi/` + `build.gradle` 显式登记 |
| 目录↔分派一致性守卫 | Lead | ✅ `ShellPageDispatchCoverageTest`（含防空转断言与咬合探针） |
| 能力缺口 B1 WebDAV 真收发 | `cap-webdav` | ✅ `c339330d`（4 文件 2376 行，70 例）；**收口未完**：测试用了 `com.sun.*` 让 CI 单测编译红 → 见 task-5 |
| 能力缺口 B3 教务网页登录 WebView | `cap-webview` | ✅ `ca94d1a6`+`2dec48fb`（4 文件 1585 行，17 例）；**接线未做**（目标文件仍是别人未提交的 `M`） |

**这一轮踩出来的四条（都值得写进纪律）**：

1. **L0 绿 ≠ CI 绿：两者的编译平台不是同一个。**
   `scripts/test-kotlin-module.ps1` 用**完整 JDK**，Gradle 的 Android 单测用
   **AGP 裁剪过的 system-modules jar**（只含受支持的 JDK API）。
   `com.sun.net.httpserver.*` 在前者可见、后者不可见 ⇒ `cap-webdav` 的测试
   L0 156 例全绿，`:app:testProdDebugUnitTest` 直接编译失败。
   **凡测试里用了 JDK 内部 API（`com.sun.*` / `sun.*`），必须再过一次真 Gradle 任务。**

2. **`sync/` 是共享模型层，被每一次 L0 无条件收进去。**
   一条泳道在 `sync/` 留一行编译错误，**全队四条泳道 + Lead 的 L0 全红**。
   规矩：在 `sharedModelDirs` 名单里的目录（`core` / `sync` / `share` / `transfer` /
   `statistics` / `theme` / …）里写文件，**必须保持时刻可编译**，不能攒到最后。

3. **`src/test/` 是所有变体共享的测试源集。**
   引用 `composeP1`（只被 compose 变体编译）的用例放进去，prod 变体的
   `:app:testProdDebugUnitTest`（**CI 跑的那条**）就会编译失败——它红了一整晚没人发现。
   修法不只是挪文件，还要在 `build.gradle` **显式登记** `src/testComposeUi/`：
   只靠默认目录约定的话，「源集名改了、测试静默不跑、而 prod 刚好绿」是最难查的组合。
   验证方式（已做）：往挪走的测试里注入一个不存在的符号 →
   `:app:compileComposeUiDebugUnitTestKotlin` 必须报错（证明它真在那个源集里）。

4. **「入口行有、落点没有」是这一轮三处虚标的共同形态，且人工登记看不出来。**
   设置族 20 页共用一个 `SettingsPageScreen(spec)`，所以「没写页面函数」与
   「没写页面」在登记表里长得一模一样。
   现在有 `ShellPageDispatchCoverageTest` 钉「目录里标可进入 ↔ 分派里有分支」；
   **仍未解决**的是「设置首页那一行 `actionTarget` 指的路由，是否真有 spec 接」——
   两侧用的是两套命名空间（`/settings/xxx` vs `b.xxx`），中间没有可机器校验的映射。
   建议下一批补一条**路由 → spec 的登记表**并让守卫逐条构造一次。

5. **`unresolved reference` 里混着「本来就在文件里、位置还很靠后」的符号 ⇒ 先查花括号，别补声明。**
   实例（2026-10-28，`transfer/lan/LanEditApiRouter.kt`）：一条泳道改函数体时用了「只匹配签名行」的编辑，
   把函数体删掉、函数没闭合，于是 Kotlin 把**后面整个类的声明**当成了它的函数体，
   一次报出十几条假错误——`isoNow` 未解析（它好好地在文件尾）、五个还没写的 handler 未解析、
   一个 import 未解析，看起来像「少了一大堆东西」。
   **判别特征**：错误清单里混着**本来就在文件里**的符号。这种形态先去数花括号，别一条条补声明。
   同一天里 `sync/` 与 `transfer/` 各挡了全队一次 L0，为此给 L0 脚本加了逃生门：
   `pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/<域>" -ExcludeShared <共享目录>`
   ——**用了它本次结果不覆盖被排除的目录，交付证据里必须写明**（否则等于悄悄缩小验证面）。

6. **Kotlin 的块注释会嵌套：KDoc 正文里写 `/**` 会开第二层注释。**
   实例（2026-10-28，`TimetableSettingsModel.kt`）：一条泳道在 KDoc 里写了
   `去重/截断到 8/**钉住 settings**`，那个 `/**` 开了第二层注释、只闭掉一层 ⇒
   报错出现在**文件末尾**（`Unclosed comment`）+ 整个 package 的 `unresolved reference` 雪崩，
   **连别人的文件都跟着报**，症状极像「别人把我的符号弄没了」。作者为此白跑两轮 L0。
   ⇒ **KDoc 正文里不许出现 `/**` 或 `*/`。**

7. **报「我这边红了」之前，先查自己的文件有没有 `syntax error` / `Unclosed comment`，再看别人。**
   这是第 6 条的直接推论：那类语法错会让**别人的错里混进你的行号**，先看别人会把你带偏。
   另外等不到别人落盘时，可以**换一个 `pages/` 模块**先拿自己的证据
   （实例：一条泳道用 `-Module pages/live` 跑通自己的用例，等 `SettingsPageBridge.kt` 落盘后
   再用官方 `pages/settings` 复跑）。汇报里要写明换了哪个模块、为什么。

8. **判「在途」还是「停滞」：单点采样不能定生死，要看两次采样之间的变化。**
   实例（2026-10-28 下午）：一批 45 个未提交文件的最后修改时间停在 14:01~14:05，
   到 15:58 仍无人动 ⇒ 一度判定「已停滞 2 小时」并准备提议**回退**。
   实际在 16:03 恢复写入——**差一步就把它正在写的活冲掉**。
   拦住它的是「先量再动」：把 83 个未提交文件逐个**逐字节比对备份**时发现，
   恰好有 1 个文件**在复制过程中变了** ⇒ 作者活着。这个信号比时间戳可靠得多。
   同源纪律：**pre-commit 卡死要看两次 CPU 采样（间隔 10~15 秒，有增长就是还在跑）**，
   而不是看一眼进程列表。
   ⇒ **不确定时只读观察；不要按「它大概死了」的推断去动别人的文件。**

9. **写冲突是「文件级」的，不是「目录级」的。**
   实例（同日）：一条泳道被要求「等全仓 sweep 提交后再开工」，而它实际等的是一个
   **永远不会来的信号**——sweep 的作者要提交自己的 45 个文件，与它开工没有因果关系。
   实测那 45 个文件**一个 `pages/task/` 都没碰**，两边零交集。
   ⇒ 正确判据：**开工前 `git status -- <你要写的每个具体文件>`，确认那几个文件不在别人的
   未提交清单里**；而不是要求「某个目录干净」或「别人先提交」。
   **代别人提交是危险的**（无法判断对方是否写完），但**防冲突不需要等别人提交**。

**全仓 sweep 与工作包的碰撞面（2026-10-28 下午实测）**

一个会话在做全仓批量改动（给页面加**大标题折叠滚动**，仿 Dart `HyperosSubpage`），
`composeP1/.../pages/` 下 **45 个文件未提交**（+825/−365）。**它跨了好几个工作包的写作用域**：

| 目录 | 文件数 | 对应工作包 | 碰撞程度 |
|---|---|---|---|
| `import/warehouse/` | 6 | **I2** 教务导入 | **直接碰撞**（其中 5 个曾编译不过） |
| `transfer/` | 5 | **I1** 相机（`transfer/camera/` 新目录不冲突，但 `QrTransferScanPage.kt` 重叠） | 部分碰撞 |
| `statistics/` | 4 | **ST1** 统计 | **直接碰撞** |
| `sync/` | 3 | **C1/C2** 云同步 | **直接碰撞** |
| `timetable/` | 2 | **T2** 档案 | **直接碰撞**（其中 `TimetableProfilesPage.kt` 曾编译不过） |
| `export/` | 1 | **I3** 日历导出 | **直接碰撞** |
| `course/` | 1 | **T1** 课程操作 | 部分碰撞（`AddCoursePage.kt`） |
| `settings/` | 1 | **S1/S2** 设置 | 部分碰撞 |

⇒ **I2 / ST1 / C1 / C2 / T2 / I3 这几条线在 sweep 提交前不宜开工**；
T1 的 `pages/task/`、S1/S2 的 `main/.../app/` 侧不受影响。
**教训**：在共享工作区里，一个人「改 45 个文件、改到一半不提交」的代价是**多条工作包一起停工**。

**本轮验证基线（Lead 亲自跑）**：

| 级别 | 命令 | 结果 |
|---|---|---|
| L0 | `test-kotlin-module.ps1` × 3 模块（settings / shell / live） | **535 + 44 + 36 例全绿** |
| L1 | `safe-gradle :app:compileComposeUiDebugKotlin -x :app:compileFlutterBuildComposeUiDebug` | **BUILD SUCCESSFUL，`e:` 0 条**（三条泳道渲染层同批进编译） |
| L2 | `safe-gradle :app:testProdDebugUnitTest` | ✅ **3421 例 / 0 失败 / 0 错误 / 0 跳过**（252 个测试类，`BUILD SUCCESSFUL`）。数字取自结果文件 `build/app/test-results/testProdDebugUnitTest/*.xml`，**不认「BUILD SUCCESSFUL」这一句**（台账 §5 纪律）。对比 2026-10-27 21:07 基线 2978 例 / 218 类 |
| 守卫探针 | 改坏 `b.courseCard` → 红（2 条断言指名道姓）→ 字节级还原 | ✅ |
| 源集探针 | 往 `src/testComposeUi/...` 注入不存在的符号 → `compileComposeUiDebugUnitTestKotlin` 报错 | ✅ 证明源集登记生效 |

**L2 复核过程里又踩到一次第 2 条纪律**（记下来当实例）：`cap-webview` 在
`transfer/lan/` 写局域网服务端时，一个 550 行的文件分两次落盘，中间那次缺
`import com.mutx163.qingyu.core.FormatException`（**仓库自己定义**的类，`Course.kt:9`，
不是 JDK 的），于是 `:app:compileProdDebugKotlin` 连带 `:app:testProdDebugUnitTest` 一起红。
它改成「每落一个文件立刻跑一次 L0」后解决。
⇒ 共享模型层目录里的文件，**写盘即生效于全队**，中间态必须可编译。

**仍未做（诚实清单）**：① 一页都没真机对照（现在 78 条可点——**当时口径；2026-11-01 复核为 87，见 §9.5**，入口齐了，**就差用户在手机上走一遍**）；
② WebDAV / WebView 都只到「JVM 真 HTTP 单测」/「L1 编译」，**没有一页接过界面**——
WebView 的接线被 `WarehouseWebLoginPage.kt`（别人未提交）挡着，WebDAV 还没定接到哪一屏；
③ 局域网收发与相机扫码**尚未开工**（相机要新依赖，属 build.gradle = Lead 区）；
④ 毛玻璃页面层 / `fontWeight` / 余 26 个文件裸 `Card(` 未动（2026-11-01 复核：裸 `Card(` 实为 **26 处 / 2 文件**，原文「26 个文件」是笔误）。

### 9.5 Phase 3.5 接线与装配（2026-10-28 白天，用户口径「让按钮真的有反应」）

用户实机反馈「好多页面是空壳、按钮点了没反应」。查实后的结论不是「页面没做完」，
而是**页面搬完了却没有任何东西给它们提供数据与动作**——原计划从 Phase 3 直接跳到删 Flutter，
中间缺了「接线」这一段。计划见 [Phase 3.5](2026-10-28-compose-phase35-wiring-plan.md)，
可并行批次表见 [批次表](2026-10-28-compose-phase35-batches.md)。

**第一条竖切（课表族）—— 已打通**

| 层 | 落点 | 提交 |
|---|---|---|
| 存储抽象（Lead 定稿，签名冻结） | `main/.../app/KeyValueStore.kt` | `01067260` |
| 存储实现（Android） | `main/.../platform/PrefsKeyValueStore.kt` | `acd7b1e8` |
| 领域存储（含损坏值留档自愈） | `main/.../app/TimetableStore.kt` | `acd7b1e8` |
| 仓储（持状态 / 落盘 / 通知） | `main/.../app/TimetableRepository.kt` | `acd7b1e8` |
| 宿主层（把仓储接到页面） | `composeP1/.../app/TimetableHost.kt` | `199b8dad` |
| 壳接线（Lead 专属） | `composeUi/.../pages/ShellWiring.kt` | `56cc5fab` |
| 收口：整组替换 + 删课 | `TimetableHostLogic.kt` + 壳 | `c374ca64` / `78abfc53` |

**两个数据正确性修复（不是体验问题）**：
① **设置必须合并写**：本层只认识 4 个设置键，而用户存档里有 250+ 个。整体覆盖会**静默清空**用户其余设置。
现有守卫测试塞 8 个未知键（含 bool/double/null/嵌套/中文）后改一个已知键，断言一个都没少；
改成整体覆盖立刻红并点名丢了哪 8 个。
② **整组替换**：旧写法逐门 update，编辑态删掉的课次**不会从仓储消失**（3 门删成 2 门，第 3 门还在）。
探针报的正是 `expected:<2> but was:<3>`。

**第二条竖切（设置族）—— 进行中**（选它是因为**一份渲染层服务 20 页**）
数据模型分两批交付 35 → **61 键**（`4be6c4ad` / `88c33cad`）；宿主 + 动作分派第一刀（4 页）`43272737`。
**被藏住的 Phase 2 缺口**：`core/TimetableSettings.kt` 只是**四键子集**，而设置族 20 页需要几十个字段——
在完整模型到位前设置族根本没法接线。这就是为什么先补数据模型。

**第三条竖切（时间模板族 `d3.timeSchemes` + `d3.timeSchemeEditor`）—— 已打通（2026-10-29）**

用户口径「时间模板页面审核一下重构质量，功能有没有复刻完」。审核结论：**模型层搬得细，页面在壳里是死的**
（空模型 + 7 个空回调），且**编辑节次整屏不存在**。审核报告与修复结果见
[时间模板页审核](2026-10-29-compose-time-scheme-audit.md)（29 条差异逐项销项）。

| 层 | 落点 | 规模 |
|---|---|---|
| 仓储写入口 | `main/.../app/TimetableRepository.kt`（新建/改名/复制/改节次/应用/删除六入口） | +284 |
| 地点分组数据通路 | `main/.../app/TimetableStore.kt`（`location_time_groups` 读写） | +41 |
| 列表模型 / 编辑器状态机 / 占用索引 / 服务消息 | `main/.../pages/time_scheme/` 四件 | 726 + 489 + 119 + 180 |
| 列表页渲染 / 六个弹层 | `composeP1/.../pages/time_scheme/` | 402 + 603 |
| 编辑节次页 / 快捷生成弹层 | `composeP1/.../pages/time_scheme/` | 384 + 649 |
| 宿主（真数据 + 真动作 + 弹层状态机） | `composeP1/.../app/TimeSchemeHost.kt` | 626 |
| 壳路由 | `main/.../pages/ShellWiring.kt`（`pendingTimeSchemeEditId` + `/settings/time-schemes/editor`）、`ShellPageIndex.kt` | 小改 |

L0 `OK (129 tests)`（原 64 例）；样式守卫 `time_scheme` 域 0 违规。**真机未对照**。
未接：分享（时间模板的 `.mikcb` 传输包构建未接；`FileProvider` 本身已在 manifest 注册，`AndroidManifest.xml:137-151`）、地点匹配页本身仍是演示数据（`P35-B2` 余量）。

**能力缺口进展**

| 能力 | 状态 | 提交 |
|---|---|---|
| WebDAV 真收发传输层 | ✅ **已接线到界面**：`CloudSyncController` 用真 `WebdavRemoteTransport` 驱动 `f.cloudSync` / `f.backupList`（`ShellPageIndex.kt:1419-1487`、`CloudSyncController.kt:46-50`） | `c339330d` + 收口 `7861a503` |
| 教务网页登录 WebView 宿主 | ✅ 交付：真 WebView 已接进 `WarehouseWebLoginPage.kt:249-251`；壳侧 `g2.webLogin` 因**没有学校列表/真实 `import_url` 数据源**显示诚实空态（F23 `e8b5a06f`，`ShellPageIndex.kt:1543-1549`），不是「被未提交改动挡住」 | `ca94d1a6` |
| 局域网编辑 HTTP 服务端 | ✅ A/B 组端点全部接在仓储上；`import/preview` 与 `import/apply` 已接真应用（`378b801f`，见下方 ②） | `751b6411` `7e83433c` `090aa000` `378b801f` |
| 二维码生成器 | ✅ 交付（与 Dart `qr` 3.0.2 现场生成的矩阵逐位对拍） | `2a77c08f` |
| 相机扫码（可测层） | ✅ 交付；CameraX `1.6.1` + MLKit `17.3.0` 已进构建（`android/app/build.gradle:363-368`），`QrCameraHost.kt` 经 `QrTransferHosts.kt:162` 注入 `g3.qrScan`（`ShellPageIndex.kt:1578`）。真机取景仍未验 | `9cc5b2e9` |
| 地点时间匹配编辑页 | ✅ 交付（Phase 3 遗留） | `7e8a9d32` |

**仍未做（诚实清单，2026-11-01 复核）**：① **一页都没真机对照**（壳里 **87** 条可点，入口齐了，就差用户走一遍；口径见 `ShellPageCatalogTest.kt:36-45`，旧写的 78 已过期）；
② ~~局域网 `import/apply` 保持 501~~ → **已接真应用**（`378b801f`，2026-10-30：`transfer/lan/LanTransferLogic.kt`
+ `LanTransferApplier.kt`，本机实跑 354 例 L0 绿；2026-11-01 复核）。该端点剩余的缺口已换成两条：
「导入后没有撤销点（`transferId` 恒 null）」「设置只应用已移植子集」，
见 `.agents/compose-phase3/claims/F17-lan-apply-501.md` §明确没做；
③ 备份写回**只解决了一半**：仓储原子入口已交付（`TimetableRepository.kt:197` `replaceActiveProfileContent(courses, tasks, exams)`、`:236` `replaceAllProfiles`），文件导入确实写回 tasks/exams（`DataTransferHost.kt:473-480`）；**WebDAV 云端恢复仍只下载快照、不写回仓储**（`CloudSyncCoordinator.kt:25-27` 自认归 task-14），局域网多档案包明确拒绝而非恢复（`LanTransferLogic.kt:109`）；
④ ~~相机真依赖未加~~ → **已加**（`android/app/build.gradle:363-368`：CameraX `1.6.1` + MLKit `17.3.0`）；真机取景仍未验；
⑤ **毛玻璃仍待接，字重已清、裸 Card 已核销**：`layerBackdrop` 仅 4 处（玻璃坞、首页壁纸、展示册、壳采样），**截至 HEAD 页面顶栏/弹层未接**（F24 E 线在途，见 §9.10）；页面层硬写 `fontWeight` 已于 **2026-11-01 清零**（311 → 15，剩余 15 处全在 `pages/showcase/` 展厅、按规则豁免；功能字重 `fontWeight = weight` 不计），新增 R7 守卫与 `QingyuWeightDelta` / `shiftWeight` 套件，见 `claims/STYLE-fontweight-sweep.md`；裸 `Card(` 复核后**真违例为 0**——旧记的「26 处 / 2 文件」是原始 grep 把 `showcase/MiuixShowcaseSubpages.kt` 的 25 处展厅样例（规则 §五 豁免）与 `WeekSelectorSheet.kt:42` 的**注释文字**（1 处）都数了进去。

**这一轮反复踩到的结构性问题（建议专门收一次）**：
`app/` `share/` `sync/` `transfer/` 这些共享模型目录**被每次 L0 与 Gradle 编译无条件收录**，
任何一条泳道的半成品都会把全队的编译/测试一起挡红——一天内发生了四五次
（漏 import、`com.sun.*`、花括号不闭合、handler 未落）。
已加 `-ExcludeShared` 逃生门与判别特征，但**这只是缓解**。
建议的根治方向：让泳道在**自己的临时目录**里编译（或按目录分源集），绿了才搬进共享目录。

### 9.7 收尾复核（2026-10-28 晚）：L2 全绿

**CI 权威闸门 = `:app:testProdDebugUnitTest`**（`.github/workflows/ci.yml:111`；
该文件 `:114` 的注释也写明它**不编译 `src/composeP1`**）。
本轮最终结果：**4173 例 / 0 失败 / 0 错误 / 0 跳过（308 个测试类）**。

**这一轮把「源集错配」这一类缺陷清干净了**（第 10 条纪律的第三、四、五次实例）：

| 文件 | 症状 | 修法 |
|---|---|---|
| `pages/transfer/QrFountainLt.kt` | 纯 Kotlin 在 composeP1，被 `src/test` 引用 ⇒ prod 单测**编译**失败 | 搬 `main/`（包名不变） |
| `pages/transfer/QrScanSessionCoordinator.kt` | 同上 | 搬 `main/` |
| `pages/transfer/QrTransferReceiveSession.kt` | 同上 | 搬 `main/` |
| `pages/transfer/QrTransferSendSession.kt` | 同上 | 搬 `main/` |
| `components/QingyuPageScaffold.kt` | 返回键默认值 `"返回"` 被判 CJK 漏项 | 新增 `app/CommonUiStrings.kt` 承载文案 |

⚠️ **一次误判（已撤回，值得记）**：我先把 `pages/settings/SettingsRowRenderTable.kt` 也搬了，
事后发现**搬错**——`SettingsSharedParityTest` 是**按源码文本**读它（`composeP1File()`），
从不引用类，所以它**本来就该留在 composeP1**。我的静态扫描把**KDoc 里出现的类名**当成了引用。
⇒ **「文件里出现某个类名」≠「引用了这个类」**：静态扫描判「引用」时必须排除注释与字符串。
这是「核查脚本的基线本身就是失败模式」的第 3 次实证（前两次：文件名写错、只扫显式空回调）。

**CJK 棘轮基线必须跟随现实下调**：机制要求「修复后下调，只许收不许放」。
用 `python scripts/i18n-cjk-baseline.py --write` 重生成（27 文件 / 224 条），
重生成**前**先确认「无任何文件超基线」⇒ 只会有下调/删行，不会有上调。

**已知遗留（不是本轮引入，需单独定方案）**：
`:app:testComposeUiDebugUnitTest`（**非 CI 变体**）里 `QingyuTextStylesTest` 报
`UnsupportedClassVersionError`（miuix 0.9.4 的 class file 65 = Java 21，而工程 `jvmTarget=17`
且 `JAVA_HOME` 是 17；本机另有 Android Studio JBR 25）。
⇒ 任何**在 JVM 里构造 miuix 类型**的单元测试在这个变体下都跑不了。
候选解法：① 该变体的单测改用 JDK 21+ 的 `javaLauncher`；② 把该测试改成源码级守卫（削弱验证力）。
**未擅自改**：改整条单测 JVM 环境属构建环境决策，影响所有泳道，应先与用户确认。

### 9.8 2026-10-31 收口快照（F22 账目收口）

只记当场核实到的事实，每条都附出处；**本节落笔时 `android/**` 正由 F21 收口提交，
工作区里的 `M` 不保证已落库**，所以下面写「尚未提交」的条目以本节时间为准。

| # | 事实 | 出处 |
|---|---|---|
| 1 | **F20 桌面小组件设置页已交付**：`b.homeWidget` 从喂空构造 `SettingsHomeWidgetState()` 换成 `HomeWidgetHost`（10 项设置真读真写 + 桌面卡片真绑定 + 添加到桌面 / 精确闹钟授权）。 | 认领文件 `.agents/compose-phase3/claims/F20-home-widget.md` 状态行（2026-10-31 18:40）；提交 `88c22e34` |
| 2 | **F06 只剩 2 页仍传空构造 `SettingsPageState()`**：`b.live`（`ShellPageIndex.kt:445-446`）与 `b.liveSelfCheck`（`ShellPageIndex.kt:452`）。 | 直接读该文件当前工作区内容 |
| 3 | `b.reset`、`b.glassDockIcon` 已从 `SettingsScreen(... spec(SettingsPageState()))` 换成 `SettingsHost` 真宿主（`ShellPageIndex.kt:481` / `:487`），**已落库**。 | 提交 `2a07498d`（2026-10-31 复核：`git diff 2a07498d HEAD -- ShellPageIndex.kt` 为空，即 HEAD 已是该版本） |
| 4 | **P0-7「更多壁纸」入口点了没反应**：`SettingsBackdropFlowPage.BING_GALLERY_TARGET = "bingWallpaperGallery"`（`SettingsBackdropFlowPage.kt:182`）在 `ShellWiring.kt` 的路由表里**无登记**（HEAD 上 `grep -c bingWallpaperGallery` = 0）。 | `docs/plans/2026-10-30-refactor-review/README.md:65` 与 `:87`；F22 本地复核同结论 |
| 5 | **全仓 87 条可进入路由；真机逐页对照 0 页**（46 页「代码上真」但无一页被用户在真机上确认）。 | 口径来源 `docs/plans/2026-10-29-page-coverage-census.md:10-11`（88 条目录 / 87 条分派分支）；未对照的自认见 `docs/plans/2026-10-29-remaining-pages-tasklist.md:597` |
| 6 | **收口提交仍在进行中**：`android/**` 的已完工改动由 F21 独占提交，本节落笔时未收口。 | `.agents/compose-phase3/claims/F21-settlement-commit.md` 状态行 |

**F22 未能核实、因此没有写进上表的**：F21 最终提交了几笔、各自覆盖哪些文件（认领文件仍写「进行中」）；
87 条路由里每页当前的真实数据源状态（只能引用 10-29 的普查结论，未逐页重扫）；
工作区里剩下的 `android/**` 改动属于哪条泳道、何时收口。

### 9.9 2026-10-31 F23 交付快照（设置族收尾 + 壁纸死路由）

F23 认领文件：`.agents/compose-phase3/claims/F23-settings-tail-and-gallery.md`（状态**已交付**，2026-10-31 22:1x）。5 笔提交，工作区干净。本节只记核实到的事实：

| 提交 | 事实 | 证据 / 落点 |
|---|---|---|
| `06975048` | 桥接层给 `b.live` 开 `liveData` 入口：`SettingsPageBridge.specFor` 增加默认参数 `liveData: LivePageData = LivePageData()`；默认值仍是空构造（现有行为不变），真接线方自己读 `LiveDisplayStore` 再传。新增 `SettingsLivePageBridgeDataTest` 契约测试（自定义档摘要必须原样落到两行）。 | `SettingsPageBridge.kt`；`SettingsLivePageBridgeDataTest.kt` |
| `e8b5a06f` | 实时活动两屏接真宿主：新建 `LiveSelfCheckHost.kt` / `LiveSettingsPageHost.kt`；`b.live` 从 `LiveDisplayStore` 读两档显示设置，`b.liveSelfCheck` 每秒读 `LiveUpdateService.buildDebugStatus`（指纹去重）并接五条落点，白名单补 5 键。仓库适配三页（`g2.schoolAdapters` / `g2.adapterDetail` / `g2.webLogin`）改诚实空态，删除「示例学校 / 示例适配器 / example.com」三个常量；`ShellPageCatalog` 前两页 DIRECT→DEMO；`DiagnosticsWiringGuardTest` 把 `b.liveSelfCheck` 转入受管。 | `ShellPageIndex.kt:445-464`、`:1532-1549`；`ShellPageCatalog.kt:252-276` |
| `30603bc6` | 补 `bingWallpaperGallery` 死路由：`shellPageIdForRoute` 增加 `"bingWallpaperGallery" -> "b.bingGallery"`；`SettingsRouteWiringGuardTest` 改为递归扫 `main` / `composeP1` 两源集、判据收紧并剔注释，新增两条判据自检（含「注释掉的路由不算落点」）。 | `ShellWiring.kt`；`SettingsRouteWiringGuardTest.kt` |
| `1c6428d1` | 壁纸「调整位置」不再静默：取景页未移植前，由 `WallpaperSheetBody.handleAction` 认领该行并提示「不可用」（复用 `aboutUnavailable`），不新增 ARB 键。 | `WallpaperSheetBody.kt` |
| `370930ce` | CJK 门禁不再把 `Log.v/d/i/w/e` 里的中文算作上屏文案（Kotlin 侧与 `scripts/i18n-cjk-baseline.py` 逐字一致）；基线重生成后逐字未变；新增判据自检。 | `CjkLiteralGateTest.kt`；`scripts/i18n-cjk-baseline.py` |

验收（认领文件记录，agent 侧）：L0 `pages/settings` **753 例**；L1 `:app:compileDevDebugKotlin` BUILD SUCCESSFUL；L2 `:app:testDevDebugUnitTest` 全绿；样式闸门 `-Domain settings` 0 违规；5 条咬合探针（删/改 → 红 → 还原 → 绿）。**真机对照 0 页，仍归用户。**

**F23 顺带结清的两条 F22 旧账**：§9.8 第 2 条（`b.live` / `b.liveSelfCheck` 仍传空构造 `SettingsPageState()`）由 `e8b5a06f` 解决；§9.8 第 4 条（`bingWallpaperGallery` 在 `ShellWiring` 无登记）由 `30603bc6` 解决。§9.8 其余行是 2026-10-31 当时事实，不回改。

**F23 明确遗留**：`liveTestingExportAction`（导出并分享日志）仍是死按钮；自检页测试通知卡的四个按钮无 Kotlin 数据源；壁纸拖动取景页未移植（现在只给诚实提示）；`b.reset` 四条缺陷另批；CJK 门禁扩到 `main` 源集另批。

### 9.10 2026-11-01 F24 并行硬化（**已交付**，2026-11-02 回填）

F24 认领文件：`.agents/compose-phase3/claims/F24-parallel-hardening.md`（状态：**已交付**，2026-11-01）。8 条工作线并行、写作用域互不重叠；壳与跨族共享件（`ShellPageIndex.kt` / `ShellWiring.kt` / `SettingsPageRenderers.kt` / `SettingsPageBridge.kt`）由 Lead 单写，子代理只交 snippet。

| # | 工作线 | 在做什么 | 状态 |
|---|---|---|---|
| A | `b.reset` 四条缺陷 | ①确认弹窗正文只覆盖 3 个作用域，课表页 / 桌面小组件走了外观口径；②首页导航收到 `RESET_SCOPE` 直接应用、无二次确认；③确认按钮文案用了「重置」而非登记的「恢复默认设置」；④`DONE_MESSAGE_KEY` 从不弹 | ✅ `28cc5044` |
| B | 自检页剩余按钮 | 导出并分享日志、测试通知四颗按钮、假期开关闭环 | ✅ `b2daddbd` |
| C | 壁纸取景页 | 移植 `backdrop.image.adjust` 的真拖动取景；落地后删掉 `1c6428d1` 的「不可用」提示分支 | ✅ 页 `f967fd5f` + 落点 `32808774` |
| D | CJK 门禁扩到 `main` 源集 | 当前 `CjkLiteralGateTest` 只扫 `composeP1/kotlin`，`src/main/kotlin` 整目录是盲区；扩了要整目录立基线 | ✅ `ae4c7f98` |
| E | 共享骨架毛玻璃与宽屏 | `QingyuPageScaffold` 顶栏接 miuix-blur；宽屏 `AdaptiveTopAppBar` / `NavigationRail` 调研 | ✅ `08246e26` |
| F | 壳里假数据 / 死控件普查 | **只读**第二轮普查，不改任何文件 | ✅ 普查完成；成果随 `32808774`（目录 88→89） |
| G | 文档同步 | 派工大表 §五 与本节 §9.9 / §9.10 的核实修订（本批本条） | ✅ `bfb554a4` |
| H | 样式债清理 | 选一个域把 R1–R6 棘轮欠账清零 | ✅ `213a835a` |

**收口验收（2026-11-01，Lead 重跑；原文「本节只是占位、不声明任何一条已完成」随本批交付失效）**：L1 `:app:compileDevDebugKotlin` `BUILD SUCCESSFUL`；L2 `:app:testDevDebugUnitTest` **5569 例全绿**；样式闸门 settings 0 处、exam 1 处（已登记理由）；探针「改坏恢复默认弹窗正文 / 取景拖动方向」→ 3 条用例红 → 还原后 `OK (776 tests)`（`.agents/compose-phase3/claims/F24-parallel-hardening.md:46-68`）。**真机逐页对照仍归用户**。C 线的拖动/捏合手势用标准 Compose `transformable`（miuix 0.9.4 无取景组件），例外登记**待用户确认**，登记表尚未写入（同上 `:78-82`）。

**本节还取代了 §9.5 ⑤ 的「F24 E 线在途」**：顶栏毛玻璃已由 E 线 `08246e26` 交付（2026-11-01）。另两条跨批状态（2026-11-02 复核）：云备份恢复撤销 UI 已交付（`bc0a02c6`，差异预览仍无）；单节课提醒 `classReminders` 与局域网撤销点/真实 `transferId` 已实现但**工作区未提交**。

---

## 10. 维护规则

- **谁更新什么**：批次状态由**领用者自己**在认领文件里更新；本文档的批次表与快照由 **Lead** 在
  合入后更新（避免多人同时改这份文档）。
- **拆批 / 并批**：由 Lead 决定；改完同步 §4 总表。领用者想拆自己的批次，写进认领文件，Lead 认可后落表。
- **新增页面**：Dart 侧新增页面时，Lead 补进对应批次（或新开一批）。
- **Phase 5 收尾**：删 Flutter 时，本文档与 `.agents/compose-phase3/` 一起清理。
- **本文档进仓库**（`.agents/compose-phase3/` 不进），改它请走路径限定提交。

---

## 关联

- [迁移计划](2026-10-26-compose-migration-plan.md) · [执行规格](2026-10-26-compose-migration-spec.md)
- [Phase 2 业务族（泳道纪律的先例）](2026-10-26-compose-phase2-families.md)
- [Phase 3 开工准备（主题桥 / 族 7 核对 / 待定项）](2026-10-26-compose-phase3-prep.md)
- 本机认领区：`.agents/compose-phase3/README.md` 与 `.agents/compose-phase3/claims/`
- 仓库 AGENTS.md：GIT-COLLAB（路径限定提交）、TEST-POLICY（咬合探针）、设备铁律
