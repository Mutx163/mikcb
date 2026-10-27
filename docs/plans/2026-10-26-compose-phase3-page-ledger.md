# Compose 迁移 · Phase 3 页面进度与认领台账

> 状态：**生效中**（2026-10-26 23:29 建立）
> 读者：所有参与 Phase 3 页面迁移的 agent，**包括没读过本次对话的独立会话**
> 上游：[迁移计划](2026-10-26-compose-migration-plan.md) · [执行规格](2026-10-26-compose-migration-spec.md) · [Phase 2 业务族](2026-10-26-compose-phase2-families.md) · [Phase 3 开工准备](2026-10-26-compose-phase3-prep.md)
>
> ⚠️ **实时进度不在本文档里**。本文档的「状态」列只是 2026-10-26 23:29 的快照；
> 谁正在做什么，一律以本机认领区 `.agents/compose-phase3/claims/` 为准（见 §2）。
> 这样设计的原因：状态高频变化，放进仓库等于每次改状态都要提交，多个会话必然冲突。

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
| `lib/screens/*.dart`（顶层页面） | 54 | 39 766 |
| `lib/screens/settings/` | 19 | 12 639 |
| `lib/screens/import/`（含 `warehouse/`） | 14 | 9 137 |
| `lib/screens/miuix_showcase/` | 14 | 4 265 |
| `lib/widgets/*.dart`（跨页共享件） | 63 | 23 756 |
| `lib/widgets/timetable/` | 77 | 17 563 |
| `lib/widgets/statistics/` | 22 | 4 460 |
| `lib/ui/`（主题 / 玻璃 / 动效基建） | 75 | 26 705 |
| **合计** | **338** | **≈138 291** |

复算命令：`wc -l lib/screens/*.dart`、`find <目录> -name "*.dart" -exec cat {} + | wc -l`。

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
| P3-C2 | 课表 · 月视图 | 11 | 4 093 行 | `pages/timetable/month/` | ⬜ 待领（Dart 侧在途，等稳定） |
| P3-C3 | 课表 · 日视图 | 13 | 4 171 行 | `pages/timetable/day/` | ✅ 已交付（另一会话，`b5b8bba2`；随父目录 `timetable` 于 18:40 一并纳入编译，见 §7.2.1） |
| P3-D1 | 课程表单与概览 | 4 | 2 753 行 | `pages/course/` | ✅ 已交付（`8e140fb7`，13 文件 4 816 行，86 例；未真机对照） |
| P3-D2 | 日程与任务 | 5 | 3 171 行 | `pages/schedule/`、`pages/task/` | ✅ 已完成（`97157c7a`，未真机对照） |
| P3-D3 | 作息与考试 | 4 | 5 027 行 | `pages/time_scheme/`、`pages/exam/` | 🔄 进行中（`timescheme-exam` 交 2 页；**余量已拆分**给 P3-D3-b / P3-D3-c） |
| P3-D3-b | 作息与考试 · 作息管理页 | 1 | 1 888 行 | `pages/time_scheme/`（仅 `TimeSchemeManagement*`） | 🔄 进行中（`timescheme-mgmt`，2026-10-27 18:30 领） |
| P3-D3-c | 作息与考试 · 地点时间匹配页 | 1 | 1 131 行 | `pages/time_scheme/`（仅 `LocationTimeMatch*`） | 🔄 进行中（`timescheme-loc`，2026-10-27 18:30 领） |
| P3-E | 统计族 | 26 | 5 299 行 | `pages/statistics/` | 🔄 进行中（`stats-renderer` 交 2 页；**余量已拆分**给 P3-E-b） |
| P3-E-b | 统计族 · 分析页与会话页 | 2 | 355 行 | `pages/statistics/`（仅 `StatisticsAnalysis*`、`StatisticsSession*`） | 🔄 进行中（`stats-extra`，2026-10-27 18:30 领） |
| P3-F | 同步与备份 | 4 | 2 536 行 | `pages/sync/` | 🔶 四件套已交（`dfdac7f2` `03015c20` `65247cb8` `8f5c4675`，86 例）· **L1/L2 未出证**、未真机对照 |
| P3-G1 | 导入 · 基础 | 6 | 1 878 行 | `pages/import/`（不含 `pages/import/warehouse/`） | ✅ 已交付（`1b58806b`，17 文件 5 191 行，161 例；未真机对照） |
| P3-G2 | 导入 · 仓库适配 | 8 | 7 259 行 | `pages/import/warehouse/` | ✅ 已交付（`ea9202aa`，24 文件 6 195 行；6 个 Page 覆盖 8 个 Dart 文件；未真机对照） |
| P3-G3 | 导出与传输 | 7 | 3 914 行 | `pages/transfer/`、`pages/export/` | 🔄 进行中（`export-transfer` 交 2 页；**余量已拆分**给 P3-G3-b / P3-G3-c） |
| P3-G3-b | 导出与传输 · 二维码发送/扫码 | 2 | 1 192 行 | `pages/transfer/`（仅 `QrTransfer*`） | 🔄 进行中（`transfer-qr`，2026-10-27 18:30 领） |
| P3-G3-c | 导出与传输 · 局域网编辑/取件码/预览 | 3 | 1 011 行 | `pages/transfer/`（仅 `LanEdit*`、`PickupCodes*`、`TransferPreview*`） | 🔄 进行中（`transfer-misc`，2026-10-27 18:30 领） |
| P3-H | 诊断与测试夹具 | 5 | 3 559 行 | `pages/diagnostics/` | ✅ 已交付（`dcb4b6c9` 等；未真机对照） |
| P3-I | 引导与展示 | 5 | 3 732 行 | `pages/guide/` | ✅ 已交付（`28cfdc9f`；未真机对照） |
| P3-I2 | Miuix 展示册 | 15 | 5 413 行 | `pages/showcase/` | ✅ 已交付（`ea9202aa`；未真机对照） |
| P3-J | 实时活动与天气 | 2 | 2 524 行 | `pages/live/`、`pages/weather/` | ✅ 已交付（`28cfdc9f`；未真机对照） |
| P3-K | 冲突与反馈小页 | 2 | 606 行 | `pages/conflict/`、`pages/feedback/` | ✅ 已交付（`aef4c5c8`；未真机对照） |
| P3-L | 小组件 / 超级岛展示层 | — | — | 待定 | ⏸ 待拍板 |
| P3-0 | 基础设施与共享件 | 138 | ≈50 000 行 | 见 §6 | 🔒 Lead 专属 |

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

### P3-C2 课表 · 月视图 ⬜ 唯一剩余未启动
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
- L1 只编 Kotlin（含 Compose 编译器），不编 Dart、不 dex、不打包、不签名；实测 19s~1m37s。
  每次仍拉起 3 个 JVM、峰值约 2.7 GB：别一改一跑，用户在 AS 里构建时不要并发跑。

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
  （内置 kotlinc + JUnitCore，0.2 秒、<150MB，完全不受别人半成品拖累）；缺依赖时用 `-ExtraSources` 补。
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

## 9. 进度快照（2026-10-27 16:05，Lead 更新）

| 批次 | 状态 | 证据 |
|---|---|---|
| P3-A 关于与说明 | ✅ 已完成 | 6 笔提交（`2a7f78ea`…`46d806a3`），`pages/about/` 5 个 Kotlin 文件 + 测试 |
| P3-B 设置族 | 🔄 进行中（另一会话接管，`39b851f2`/`9cbe96b1`/`240ad8e9`/`f444aef1`/`ba47a609`） | 通用渲染层 `SettingsPageScreen(spec)` 一目录服务 20 页；B-1/B-2/B-3 已落三批模型+测试 |
| P3-C1 课表·周视图 | ✅ 已完成（未真机对照；18:40 补挂载并首次编译通过） | `367f3aed`，14 文件 3,591 行，54 例测试；挂载后修 3 处重复声明，`compileComposeUiDebugKotlin` 绿、模块 58 例绿 |
| P3-C3 课表·日视图 | ✅ 已交付（另一会话；随父目录挂载后首次编译通过） | `b5b8bba2`，19 文件 3,456 行，25 例测试 |
| P3-D2 日程与任务 | ✅ 已完成（编译修复后，未真机对照） | `97157c7a` + `59faedc8` 修 74 个 miuix 0.9.4 错误中的 schedule/task 部分 |
| P3-D3 作息与考试 | 🔄 **2/4 页已交付** | `40dbb943` 考试安排（41 例）+ `a84fb0d6` 添加/编辑考试（36 例）+ `3c82fcf5` 期望值修正；L1 13:43 绿、L2 81 例 15:24 绿。`time_scheme_management`/`location_time_match` 未启动 |
| P3-E 统计族 | 🔄 **2/4 页已交付** | `61f3d80e` 统计设置（13 例）+ `e0473069` 课程统计主页（26 例）+ `629daea8` 期望值修正；L2 43 例 16:00 提交后新鲜绿。⚠ `CourseStatisticsPage.kt` 整包 L1 未取得（阻塞在 `pages/import/warehouse`、`pages/showcase` 他域在途，本域 0 条报错） |
| P3-F 同步与备份 | ✅ **4/4 页已交付**（未真机对照） | `dfdac7f2` + `03015c20` + `65247cb8` + `8f5c4675`；86 例（含 2 份 ARB 逐字对拍）；闸门内 L2 15:22 全量绿含本域 86 例 |
| P3-G3 导出与传输 | 🔄 **2/7 页已交付** | `ff6d3bcb` 日历导出（34 例）+ `11988a1d` 数据备份迁移（26 例）；L1 13:50 绿、L2 15:28 绿（60 例）。余 4 页见任务板「P3-G3 余量」 |
| P3-H 诊断与夹具 | ✅ **5/5（4 渲染页 + 1 并入）已交付**（未真机对照） | `43463b8a`/`2c2d373a`/`b1c72465`/`4462c62a`/`dcb4b6c9`；L1 13:46 绿、L2 91 例 15:03 绿；3 次咬合探针 |
| P3-0 基础设施 | 部分完成 | 主题桥 `772ce837`；渲染层逐目录挂载 + CI 编译 + `composeP1` 停役守卫（`59faedc8`/`41103aa0`/`4a9cac9a`）；并发构建：本机 `build-gate.sh` 已让位给上游 `scripts/safe-gradle.ps1` 与 `scripts/test-kotlin-module.ps1`（L0 模块级单测） |
| 其余批次 | ⬜ 待领 | P3-D1 课程表单 / P3-G1 导入基础由另一会话在推（`pages/course`、`pages/import` 已挂载） |

**本轮验证基线（Lead 亲自跑）**：`:app:testProdDebugUnitTest` 覆盖 8 个域 → **401 例 / 0 失败 / 0 错误 / 0 跳过**（15:22:31，`BUILD SUCCESSFUL in 1m6s`），XML 快照留在 `.agents/compose-phase3/evidence/2026-10-27-final/`。
⚠ **没有一页做过真机对照**（L4 需用户配合），所有「绿」只到 L1/L2。

> 这份快照只记录**建立台账这一刻**的事实。之后谁做了什么，看认领区，不看这里。

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
