# Compose 迁移 · 唯一进度账（2026-11-03）

> **本文件是迁移期唯一的进度来源。** 代码与 git 提交是事实源，本文件只是索引与待办；
> 两者冲突时以代码和提交为准，并回头改这里。
>
> 原五份进度/任务文档（派工大表、Phase 3 页面台账、剩余页任务清单、现状交接、全仓体检）
> 已于 2026-11-03 合并至此，各自顶部只留一句「已合并」。它们以后只作规格或历史记录，
> **状态列不再更新**。

---

## 一、口径（三个数字别混用）

| 指标 | 当前值 | 定义与出处 |
|---|---|---|
| 壳路由目录 | **88 总 / 87 可进入 / 0 暂不可用 / 1 常驻** | `ShellPageCatalogTest` 实测 `openable=87` / `UNAVAILABLE=0` / `ALWAYS_VISIBLE=1`（2026-11-08 复核，HEAD `7f8395776`）；这是用户点得到的入口数 |
| 页面文件 | **63 个 `*Page.kt` / 183 个 `.kt`** | HEAD `7f8395776`，`composeP1/.../pages/`；只说明代码规模（工作区另有 1 个未跟踪文件，计入为 184） |
| Phase 3 页面单元 | **78**（历史口径） | 旧目录 82 − 暂不可用 3 − 常驻 1；只描述 2026-10-27 的搬运完成度，**不是现在的入口数** |
| 剩余页任务 | **39 页 / 12 批**（历史任务） | 2026-10-30 复核时 28 已落地、11 未完成；后续批次均已交付，本清单只作历史 |
| 弹层审核 | **138 条：126 已不成立 / 11 仍成立 / 1 部分成立** | `2026-11-02-compose-dialog-full-audit.md`（2026-11-03 第四批收尾口径） |
| 文案三本账 | **清零** | 超宽、死键、复述三份基线只剩注释头 |
| 样式例外 | **7 条**（timetable 4 + import 2 + showcase 1） | `tool/compose_style_exceptions/<域>.txt`；timetable = 3×R5 数据色 + 1×R2 结构性，import = 2×R2 弹层内局部滚动，showcase = 1×R5，均注明原因；`-Domain all` 实测待修 0 / 过期 0 |

> 旧文档里的 82 / 78 / 87 / 88 / 165 都是不同日期、不同口径的快照。引用前先看上表，
> 不要把历史页面单元数当成今天可进入的路由数。

---

## 二、四道门（最后一次可考结果）

| 门 | 结果 | 证据 | 是否过期 |
|---|---|---|---|
| **L0 模块单测** | 各域随批交付时绿；`pages/timetable` 的跨域引用已由 `4517d938`（材质契约下沉 `core/`）治理 | 提交 `4517d938`（2026-11-03）；本域 L0 需复跑取证 | 需复跑 |
| **L1 编译** | **通过**：`BUILD SUCCESSFUL in 57s`（4 执行 / 187 复用） | 2026-11-08 11:20，`scripts/safe-gradle.ps1 :app:compileDevDebugKotlin`，HEAD `cb8f14d1f` + 工作区在途改动。首次尝试红是他人未提交的 `ShellWiring.kt` / `DataTransferHost.kt` 半成品，其提交后转绿 | 当次有效；此后有新提交需再跑 |
| **L2 全量单测** | **7584 例 / 1 失败**：`ArbCatalogTest`「六份 ARB 的每一条都在文案表里」报 `en 的 liquidGlassPresetCustom 与 ARB 不一致 expected:<Custom> but was:<null>`。原因是 `ArbCatalog.kt` 未随 ARB 新键重新生成（`python tool/gen_compose_arb_catalog.py --check` 报过期），不是逻辑回归 | 2026-11-08 11:21，`scripts/safe-gradle.ps1 :app:testDevDebugUnitTest`（本地快速变体，非 CI 的 `testProdDebugUnitTest`） | 生成物刷新后需复跑 |
| **L4 真机逐页对照** | **0 页** | 仓库内无任何真机截图/录屏/回填记录 | 仍归用户 |

**声明纪律**：agent 只能声明「编译通过」（L1）或「JVM 单测通过」（L2）；不得声明「能跑 / 能装上 / 已验证」。
CI 权威变体是 `:app:testProdDebugUnitTest`（`.github/workflows/ci.yml:116`）；本地快速 L2 用
`:app:testDevDebugUnitTest`。**交付证据必须写明用的是哪一条**，不要都叫「权威」。

---

## 三、仍要做（按阻塞归属）

### A. 等用户

| # | 事项 | 现状 / 卡点 |
|---|---|---|
| **R01** | **L4 真机逐页对照** | 0 页，是当前最大产品缺口。按 `2026-10-27-compose-phase3-l4-checklist.md` 在 `dev` 变体壳里逐页走；必验：相机取景/解码、WebDAV 上传→下载→冲突→恢复两步确认、通知点击落页、键盘不顶按钮、矮屏弹窗不裁切、课卡铃铛与「已设提醒+取消」、宽屏 Rail、弹窗玻璃试点、桌面小组件刷新。**注意**：该清单仍写 `.ui` 包名与已删除的 flavor，按 `dev` 变体走；`dev` 的 applicationId 带 `.debug` 后缀，**不能代替正式包的「覆盖安装后数据一条不丢」**，后者要另用 `prod` 包验 |
| **R02** | **横屏/平板解锁** | `AndroidManifest.xml:166`、`:182` 两个 Activity 仍锁 `screenOrientation="portrait"`；解锁是产品决定，解锁后还要验矮屏弹层、返回手势与 Rail 冲突、配置变更重建 |
| **R03** | **R2：删 Flutter、出正式包** | 前置未满足：L4 未走、Phase 4 未收、回退窗口到 Phase 5 才关，`lib/**` 现在仍是只读对照物。正式包出包归用户跑 |

### B. 等 Lead 拍板

| # | 事项 | 现状 / 卡点 |
|---|---|---|
| **R04** | **超级岛展示层 `P3-L`** | 原生 `LiveUpdateService` 已在发小米超级岛通知；待定的是展示层走 RemoteViews 还是 Compose Glance。W1 的验收句里没有「岛」，需补判据 |
| **R05** | **弹层 4 个决策点** | 审计里的 #1（自动聚焦是否回退）、#5（加课选周结构）、#7（42dp 无标题空档等不等上游）、#8（ICS 导出菜单形态）。拍板后一次落地，不要逐条反复 |
| **R06** | **`src/perf/AndroidManifest.xml` 去留** | 仍只做「把 Flutter `MainActivity` 设为 enabled=false」；启动页已上移，是否删除影响 perfBench 入口 |
| **R07** | **L0 共享目录编译隔离** | `scripts/test-kotlin-module.ps1` 无条件收 app/core/course/sync/transfer/statistics/share/theme 等目录；任何泳道在共享目录留半成品，所有模块 L0 一起红。只有 `-ExcludeShared` 逃生门，需定根治方案 |

### C. agent 可做（按优先级）

| # | 事项 | 现状 / 写作用域 |
|---|---|---|
| **R08** | **全仓 L1/L2 复跑（原 F19）** | 部分完成（2026-11-08）：L1 已通过；L2 跑出 7584 例 / 1 失败，唯一失败是 `ArbCatalog.kt` 生成物过期（ARB 新键 `liquidGlassPresetCustom`），重新生成后再跑一次即可销账。写作用域：无代码，只跑 `scripts/safe-gradle.ps1` |
| **R09** | **通知点击落页** | `NotificationLaunchTarget.kt:31` 自认壳不读 Intent 页面参数；`PagesShellActivity` 无 Intent 解析。生产端已有 `open_route` / `open_lan_edit` 两处 extras 但无人消费。需定义页面参数、冷启动 + `singleTop` 两路解析，并补断言目标路由 id 的契约测试。写作用域：`NotificationLaunchTarget.kt`、四个 scheduler/service、`test/`；壳侧 `PagesShellActivity.kt` **[Lead]** |
| **R10** | **弹层剩余 11 条（`QingyuSheet` 两个底层缺口已修）** | ✅ `QingyuSheet.kt` 两处已修并提交 `bd0c3eb7`：IME>0 时底部只留 16dp 呼吸（原来多垫 24~40dp）、有标题动作时保留 16dp 并用私有 `horizontalBleed` 把内容反向撑出（标题不贴边、内容仍满宽）。仍未做：42dp 无标题空档 ×4、自动聚焦 ×4、选周结构、ICS 菜单等（部分待 R05 拍板）。写作用域：`components/`、`pages/course/`、`pages/timetable/`、`pages/settings/` |
| **R11** | **弹窗玻璃铺开** | 试点只有加课页删除确认 1 处（`e8cafb75` / `4a8011b3`，守卫钉调用点数=1）。先等真机看采样跟手与低端机帧率，确认后再铺其余 46 处 OverlayDialog 与底部弹层。写作用域：`components/glass/`、`pages/**` |
| **R12** | **局域网两个残余** | `LanTransferLogic.kt:54` / `LanEditRepositoryHost.kt:70-72`：① settings 只应用 Kotlin 已移植的时间/周次子集；② 地点分组变化后不重算课程钟点（Dart `replaceLocationTimeGroups(resync:true)` 无对应物）。撤销点、真实 `transferId`、整份恢复已完成，勿重做。写作用域：`main/transfer/lan/`、`main/app/TimetableRepository.kt` |
| **R13** | **F18：两条壁纸路由语义** | `ShellPageIndex.kt:477-489` 两条路由都传 `initialWallpaperPage = PICKER`，疑似一条吃掉另一条；对照 Dart 两个文件确认是不同页签还是同一面板入口。写作用域：`pages/settings/`、`app/AppearanceEditorHost.kt`；`ShellPageIndex.kt` **[Lead]** |
| **R14** | **壁纸取景页「换壁纸」入口** | `WallpaperPositionPickerPage.kt:85-87` 自认没有 `pickAndStoreManagedImage` 那样的公共入口，只显示重置；需把 URI→受管目录→写 path + 补历史抽成共享件。写作用域：`main/pages/settings/`、`main/platform/`、`composeP1/pages/settings/` |
| **R15** | **自检页 4 个测试通知按钮** | `LiveSelfCheckHost.kt:362-366` 四个分支仍只弹「不可用」；要么移植测试夹具管线，要么明确记为已知缺口。台账旧 §9.10「已闭环」是过度声明。写作用域：`app/LiveSelfCheckHost.kt`、`pages/live/`、`main/pages/live/` |
| **R16** | **埋点页面级接线** | core 三件与 `TimetableRepository` 单点已提交（`b9e5cdb6` / `9cd1e337`）；`composeP1` 页面侧引用为 0，无持久化/导出/后端 sink。先定要采哪些页面事件与隐私边界（产品决定）。写作用域：`main/core/`、`composeP1/app/` 与各页面宿主 |
| **R17** | **宽屏收尾** | 前三批已落地：三档判据 `499b28d8`、`QingyuPageScaffold` 限宽与 SmallTopAppBar 分支 `75afb7f0`、Rail 判据 `6a564625`、`ShellNavigationRail` 接入 `e2e33583`。剩余：R02 解锁后的连带面 + 首页课表网格宽屏列数（属课程域另一批）。写作用域：`AndroidManifest.xml` **[Lead]**、`components/`、`pages/shell/`、`pages/timetable/` |

> 标 **[Lead]** 的文件由 Lead 改；agent 只交 patch / snippet。共享件（`components/`、`main: platform/`、
> `main: app/`、`*Strings.kt`）的历史锁规则见 `2026-10-29-remaining-pages-tasklist.md` §1.4：
> 改动前抢 `_SHARED-WRITER.md`，改完立刻删锁；现在还需用 `git status` 核实锁文件里的状态不是「已放锁」。

---

## 四、已销账（已提交，别再当缺口做）

| 大项 | 证据 |
|---|---|
| 正式包入口切 Compose 壳 | `1158ee20`；回退方式在 `main/AndroidManifest.xml:159-160` 注释 |
| WebDAV 恢复写回 + 两步制 + 差异概要 + 撤销 | `c701a6b7` / `27f8ac2e` / `8ee25744` / `c6e374cd` / `bc0a02c6` |
| 局域网撤销端点 + 整份快照恢复 + 预演标记 | `eb32ae25` / `45cfb149` / `6c4a40dd` |
| 通知换通道：Compose 壳权限 + 四处点击走 `NotificationLaunchTarget` | `bd1bbeb0`；**但落页仍未做，见 R09** |
| 单节课提醒 `classReminders` 全链 | `50e8af4c` + `7adf26a2` |
| 教务网页原生 confirm/prompt/单选对话框 + 保存配置 + 替换/合并 + 开学日/周次映射 | `2ed2fbba` / `e7a6da08` / `c033cd97` / `fe20187e` / `67629973` / `926a612f` |
| 截屏后提示面板 | `be6b9a68` + `5f0a4e7e` |
| 宽屏前三批（判据 + 限宽 + Rail） | `499b28d8` / `75afb7f0` / `6a564625` / `e2e33583` |
| `pages/timetable` L0 跨域引用治理 | `4517d938`：材质契约下沉 `core/HomeMaterialRenderSpec.kt`，设置域只留 typealias |
| JVM 21 统一（miuix 0.9.4 class file 65 兼容） | `android/app/build.gradle:313`、`android/build.gradle:122` |
| 壁纸取景 `transformable` 手势例外登记 | `docs/reference/miuix-component-first-standard.md` 第 5 条表第 2 行 |
| 弹层审核 126/11/1 | `2026-11-02-compose-dialog-full-audit.md` 复核结论 |

> 以上只证明「代码已提交、门禁当时绿」，**不等于真机验过**。所有真机验收统一归 R01；
> 不要因为某条出现在本表就对外说「已完成」。

---

## 五、接活与避让

1. **认领协议仍有效**（用户 2026-11-03 决定保留）：`.agents/compose-phase3/claims/` 里「有文件的批次 = 有人在做」。
   **但认领文件大面积过期**：121 份里只有 24 份在 2026-11-01 之后动过（最新是 `F03-pickup-lan.md`，2026-11-02），
   其余 97 份更早；其中 23 份仍写「进行中」而工作早已交付，F18/F19 反而没有文件。
   所以它只能当意图登记，不能当占满判据：开工前必须再用
   `git status -- <目标路径>` 与 `git log -1 --format='%h %ad %s' -- <目标文件>` 核实是否真有人在动。
2. **写作用域**：按目录认领；`android/app/build.gradle`、`theme/`、两个壳的 Activity、`lib/ui/`、
   路由表、`AndroidManifest.xml` 都是 **Lead 专属**，泳道不得改。同域必须串行。
3. **当前在途（2026-11-03 15:20 实测，避让）**：
   - 样式守卫重构：`test/.../ComposePageStyleGuardTest.kt`、`scripts/compose-style-lint.ps1`、
     `tool/compose_style_exceptions/**`；
   - 壳/日视图：`PagesShellActivity.kt`、`pages/timetable/day/DayViewPage.kt`、
     `test/.../DockPagerWiringGuardTest.kt`；
   - 传输：`pages/transfer/LanEditHost.kt`（2026-11-02 23:05 起）。
   - 高改动域（先协调）：`pages/import/warehouse`、`pages/timetable`、`pages/about`、`pages/course`、
     `pages/settings`、`pages/sync`、`lib/l10n`（**不要并发跑 `gen-l10n`**）。
4. **索引警告（2026-11-03 实测）**：`git status` 当前有大量幻影条目，57 个 HEAD 里的活文件不在索引里。
   **任何不带路径的提交都会删掉它们**。提交一律 `git commit -- <自己的路径>`，禁止 `git add -A` / `git add .`。
5. **别在别人收口前跑全仓 L1/L2**：结论会冤枉人；先用本模块 L0 修干净，攒够再跑。

---

## 六、交付门槛（一条都不能省）

1. 模型层 + 渲染层都有；
2. JVM 单测绿（写清 L0 模块名 / L2 变体）；
3. 文案与 ARB 逐字对拍；
4. 改断言/守卫/棘轮基线必须做咬合探针（改坏 → 红 → 还原）；
5. `dev` 变体页面壳（`PagesShellActivity`）真机逐页对照——最后一条需要用户配合。

L0 / L1 / L2 的机器与命令见 `AGENTS.md` 与 `.agents/reference/local-toolchain.md`。
L3 出包、L3.5 性能包、L4 真机一律用户跑；**性能只认 Bench 或 release 包**。

**数据契约（冻结，优先级高于本文件的任何排期）**：`2026-10-26-data-contract.md` 里的 prefs key
逐字段 schema 与盘上格式不变；升级必须 A→B / B→A 双向兼容，并按迁移计划 Task 1 的 golden 对拍。
注意：`.agents/golden` 目前只有 UI 截图，没有 `shared_prefs` 原文，**双向数据验收仍缺实物基线**；
动落盘/网络/配置格式前先补这一课，再谈功能。

---

## 七、待拍板清单

| # | 事项 | 决策人 |
|---|---|---|
| 1 | 超级岛展示层 RemoteViews vs Compose Glance（R04） | Lead / 用户 |
| 2 | 课表管理新建/重命名已加的自动聚焦是否回退（R05 #1） | Lead |
| 3 | `src/perf/AndroidManifest.xml` 去留（R06） | Lead |
| 4 | L0 共享目录隔离方案：挪文件 / 扩源集 / 换宿主域（R07） | Lead |
| 5 | 横屏/平板是否解锁（R02） | 用户 |
| 6 | R2 删 Flutter 的时机（R03） | 用户 |
| 7 | 弹层 #5 / #7 / #8 的取舍（R05） | Lead |

---

## 八、文档地图（谁还是规格，谁只是历史）

| 文档 | 角色 |
|---|---|
| **本文件** | **唯一进度来源**；状态、待办、阻塞归属只改这里 |
| `2026-10-28-compose-master-dispatch-table.md` | 派工明细与逐包验收门槛；状态列已冻结 |
| `2026-10-26-compose-phase3-page-ledger.md` | Phase 3 页面搬运历史台账（82/78 旧口径） |
| `2026-10-29-remaining-pages-tasklist.md` | F01–F24 历史任务清单与复核记录 |
| `2026-11-03-status-handover.md` | 2026-11-03 当日交接快照（已被本文件取代） |
| `2026-10-28-full-software-audit-and-completion-plan.md` | 全仓体检快照与技术债背景 |
| `2026-10-28-compose-phase35-wiring-plan.md` | 分层接线规格（仍然有效） |
| `2026-10-28-compose-phase35-batches.md` | Phase 3.5 历史批次 |
| `2026-10-27-compose-phase3-l4-checklist.md` | 用户真机逐页清单（数字待更新为 88/87；`.ui` 包名与 flavor 已失效，按 `dev` 变体走） |
| `2026-11-02-compose-dialog-full-audit.md` | 弹层审核明细与 8 个决策点 |
| `2026-11-03-compose-widescreen-adaptive-plan.md` | 宽屏方案；前三批已落地，剩 R02/R17 |
| `2026-10-26-compose-migration-plan.md` | 总体方案、硬约束、阶段与回退方案 |
| `2026-10-26-data-contract.md` | 盘上格式冻结 schema |

---

## 九、维护规则

- **只有本文件更新状态。** 其他文档顶部有「已合并」标记，改它们只为修规格，不要回填进度。
- 每次 L1/L2 复跑、真机对照、拍板落地，都在本文件对应行补「结果 + 日期 + 提交号」。
- 新增待办必须写清「写作用域 + 阻塞在谁 + 证据」；不能落到某个人的事不要放进来。
- 文档里的行号会漂，优先引用**路由 id、文件名、提交号、测试名**，行号只作辅助。

---

## 变更记录

- **2026-11-08 L1/L2 复跑**：L1 通过（`BUILD SUCCESSFUL in 57s`，HEAD `cb8f14d1f`）；L2 `:app:testDevDebugUnitTest` **7584 例 / 1 失败**，唯一失败是 `ArbCatalogTest`——`ArbCatalog.kt` 未随 ARB 新键 `liquidGlassPresetCustom` 重新生成（生成器 `--check` 报过期）。刷新生成物后需再跑一次 L2 才能销 R08。
- **2026-11-08 数字校正**：路由 89/88 → **88/87**（`ShellPageCatalogTest` 实测，HEAD `7f8395776`）；`pages/**/*.kt` 176 → **183**（同 HEAD，工作区含未跟踪文件为 184）；样式例外 10 → **7**（timetable 4 + import 2 + showcase 1，`-Domain all` 待修 0 / 过期 0）。
  注意：`2026-11-07-refactor-full-audit.md` 里的 181 是 `3cf8d910b` 基线，不是当前值；例外 5 条同理。
- **2026-11-03 建立**：合并派工大表、Phase 3 页面台账、剩余页任务清单、现状交接、全仓体检五份进度文档；
  统一口径为 89/88/0/1；把 78/82/87/165 标为历史；销账 I2 收尾、截屏面板、教务对话框、WebDAV 恢复、
  通知权限、JVM21、宽屏前三批、timetable L0 跨域；新增 R01–R17 待办与阻塞归属。
