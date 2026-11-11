# Compose 迁移 · 唯一进度账（2026-11-03）

> **本文件是迁移期唯一的进度来源。** 代码与 git 提交是事实源，本文件只是索引与待办；
> 两者冲突时以代码和提交为准，并回头改这里。
>
> 原五份进度/任务文档（派工大表、Phase 3 页面台账、剩余页任务清单、现状交接、全仓体检）
> 已于 2026-11-03 合并至此，各自顶部只留一句「已合并」。它们以后只作规格或历史记录，
> **状态列不再更新**。
>
> **2026-11-11 校准**（依据代码与提交，未改任何代码）：核销 R02 / R06 / R09 / R13 / R14 五条已失真待办；
> 页面 `.kt` 计数、认领区份数与「进行中」份数按实测改写。逐条证据见文末「变更记录」。

---

## 一、口径（三个数字别混用）

| 指标 | 当前值 | 定义与出处 |
|---|---|---|
| 壳路由目录 | **88 总 / 87 可进入 / 0 暂不可用 / 1 常驻** | `ShellPageCatalogTest` 实测 `openable=87` / `UNAVAILABLE=0` / `ALWAYS_VISIBLE=1`（2026-11-08 复核，HEAD `7f8395776`）；这是用户点得到的入口数 |
| 页面文件 | **63 个 `*Page.kt` / 190 个 `.kt`** | HEAD `358af4aad`（2026-11-11 校准实测），`composeP1/.../pages/`；只说明代码规模。旧记 186/188 是 `29dbc4ae2` 的快照 |
| Phase 3 页面单元 | **78**（历史口径） | 旧目录 82 − 暂不可用 3 − 常驻 1；只描述 2026-10-27 的搬运完成度，**不是现在的入口数** |
| 剩余页任务 | **39 页 / 12 批**（历史任务） | 2026-10-30 复核时 28 已落地、11 未完成；后续批次均已交付，本清单只作历史 |
| 弹层审核 | **138 条：126 已不成立 / 11 仍成立 / 1 部分成立**（2026-11-11 复核：其中「标题动作贴边」「IME 叠加」2 条已修，实际仍成立 **9** 条，见 R10） | `2026-11-02-compose-dialog-full-audit.md`（2026-11-03 第四批收尾口径） |
| 文案三本账 | **清零** | 超宽、死键、复述三份基线文件已由 `02cb22f39`（去 Flutter 化收尾，2026-11-08 12:53）删除，不是只剩注释头；结论不变，当前无自动文案门禁 |
| 样式例外 | **8 条**（timetable 4 + import 2 + showcase 1 + about 1） | `tool/compose_style_exceptions/<域>.txt`；timetable = 3×R5 数据色 + 1×R2 结构性，import = 2×R2 弹层内局部滚动，showcase = 1×R5，about = 1×R4 页尾免责声明 12sp，均注明原因；`-Domain all` 实测待修 0 / 过期 0（2026-11-10 复核） |

> 旧文档里的 82 / 78 / 87 / 88 / 165 都是不同日期、不同口径的快照。引用前先看上表，
> 不要把历史页面单元数当成今天可进入的路由数。

---

## 二、四道门（最后一次可考结果）

| 门 | 结果 | 证据 | 是否过期 |
|---|---|---|---|
| **L0 模块单测** | 各域随批交付时绿；`pages/timetable` 的跨域引用已由 `4517d938`（材质契约下沉 `core/`）治理 | 提交 `4517d938`（2026-11-03）；本域 L0 需复跑取证 | 需复跑 |
| **L1 编译** | **通过**（UP-TO-DATE 复用）：`scripts/safe-gradle.ps1 :app:compileDevDebugKotlin` | 2026-11-09 23:17，HEAD `4a21d0ae4`（`build/app/tmp/kotlin-classes/devDebug` 类文件 mtime 23:17:10–23:18:43）；复核员用 `javap` 在 `SettingsHomeMenuEditorPage.class` 里读到该提交新增的 `editorSeed`，证实产物就是这份源码编出来的 | 当次有效；`4a21d0ae4` 之后的新提交此后只在 L2 轮里编过，未单独留 L1 记录 |
| **L2 全量单测** | **7667 例 / 0 失败 / 0 错误 / 0 跳过**（来源：编译员 00:40 全量轮；产物已被 00:43 单类重跑覆盖、无法独立复现，仅 `+10 个 @Test` 旁证 7657+10=7667；待修复波次后全量 L2 回填） | 2026-11-10 00:40，`scripts/safe-gradle.ps1 :app:testDevDebugUnitTest`（本地快速变体，非 CI 的 `testProdDebugUnitTest`）。跑测时记作 HEAD `33c20a37a`，但该提交时间 00:46:46 晚于跑测，只能算同一棵工作树推定（2026-11-10 复核员核对） | 该轮数字无法从产物复现；等修复波次后全量 L2 定案 |
| **L4 真机逐页对照** | **0 页** | 仓库内无任何真机截图/录屏/回填记录 | 仍归用户 |

**声明纪律**：agent 只能声明「编译通过」（L1）或「JVM 单测通过」（L2）；不得声明「能跑 / 能装上 / 已验证」。
CI 权威变体是 `:app:testProdDebugUnitTest`（`.github/workflows/ci.yml` 的「Android JVM Tests」任务）；本地快速 L2 用
`:app:testDevDebugUnitTest`。**交付证据必须写明用的是哪一条**，不要都叫「权威」。

---

## 三、仍要做（按阻塞归属）

### A. 等用户

| # | 事项 | 现状 / 卡点 |
|---|---|---|
| **R01** | **L4 真机逐页对照** | 0 页，是当前最大产品缺口。按 `2026-11-11-l4-device-checklist-dev.md`（`dev` 变体口径，2026-11-11 起取代 `2026-10-27-compose-phase3-l4-checklist.md`；旧册仍写 `.ui` 包名与已删除的 flavor，只作历史）在 `dev` 变体壳里逐页走；必验：相机取景/解码、WebDAV 上传→下载→冲突→恢复两步确认、通知点击落页、键盘不顶按钮、矮屏弹窗不裁切、课卡铃铛与「已设提醒+取消」、宽屏 Rail、弹窗玻璃试点、桌面小组件刷新。**注意**：`dev` 的 applicationId 带 `.debug` 后缀，**不能代替正式包的「覆盖安装后数据一条不丢」**，后者要另用 `prod` 包验。**2026-11-11 补（R09 核销后的真机项）**：通知落页要单独验两条——① 壳在前台/后台时点通知能进 `d3.examList` / `g3.lanEdit`；② **杀进程后点一条新通知**（R09 已知边缘：`PagesShellActivity.kt:217-220` 的 `savedInstanceState == null` 守卫可能吞掉落点），命中即转为代码修复。**另（R18）**：A6「取消提醒」需要一条已存在的单节课提醒作前置，干净包里造不出来——见 R18 |
| **R02** | ~~横屏/平板解锁~~ | ✅ **已解决**（2026-11-11 校准）：`1e8b953b7`（2026-11-08，去 Flutter 化 P4-B）删掉两个壳 Activity 的 `android:screenOrientation="portrait"`；现主清单里该串只剩解释性注释（`android/app/src/main/AndroidManifest.xml:169-172`，写明「两 Activity 不再锁 portrait」与回退方式），四个源集 manifest 无一处属性级方向锁。**残留**：解锁后的连带面（矮屏弹层、返回手势与 Rail 冲突、配置变更重建）属真机项，归 R01 / R17，不再是产品决策 |
| **R03** | **R2：删 Flutter、出正式包** | `lib/**` 已由 `303220db1`（P4-C）整层删除，回退只能走 git 历史；唯一未完成项是 **P2 真出包未由用户执行**（见 `2026-11-07-deflutter-stage2-p4-deletion-order.md:8`）。L4 真机对照与原正式包仍归用户跑 |

### B. 等 Lead 拍板

| # | 事项 | 现状 / 卡点 |
|---|---|---|
| **R04** | **超级岛展示层 `P3-L`** | 原生 `LiveUpdateService` 已在发小米超级岛通知；待定的是展示层走 RemoteViews 还是 Compose Glance。W1 的验收句里没有「岛」，需补判据 |
| **R05** | **弹层 4 个决策点** | 审计里的 #1（自动聚焦是否回退）、#5（加课选周结构）、#7（42dp 无标题空档等不等上游）、#8（ICS 导出菜单形态）。拍板后一次落地，不要逐条反复 |
| **R06** | ~~`src/perf/AndroidManifest.xml` 去留~~ | ✅ **已取消**（2026-11-11 校准）：该文件已不存在——`android/app/src/perf/` 目录还在但**为空**（`git ls-files android/app/src/perf` 返回 0 个跟踪文件，`Test-Path .../AndroidManifest.xml` = false）。`build.gradle:108` 的 `perf {}` 是 `env` 维度的 flavor，不是源集；`assemblePerfBench` 由 flavor 与变体决定，与该 manifest 无关。无需再拍板 |
| **R07** | **L0 共享目录编译隔离** | `scripts/test-kotlin-module.ps1` 无条件收 app/core/course/sync/transfer/statistics/share/theme 等目录；任何泳道在共享目录留半成品，所有模块 L0 一起红。只有 `-ExcludeShared` 逃生门，需定根治方案 |
| **R18** | **单节课提醒：App 内无法新建（产品缺口，2026-11-11 新发现）** | **现状**：`ClassReminderLogic.upsert`（`main: core/ClassReminder.kt:113`）**生产调用点 0 处**，只有单测在调（`test: pages/timetable/ClassReminderSettingsTest.kt:153`/`:161`）；`ClassAlarmSheet`（`composeP1: pages/course/ClassAlarmSheet.kt`，KDoc `:43-48`）三个动作全部抛 `ClassAlarmEvent` → 宿主 `SystemAlarmHelper.fireSetAlarm`（`SystemAlarm.kt:21`/`:29`，`AlarmClock.ACTION_SET_ALARM`）走**系统时钟**，本层不写 `timetable_settings.classReminders`；目前整条链只有**读**（课卡铃铛 `TimetableWeekPage.kt:773-775`）与**删**（`ShellWiring.kt:1284` 调 `ClassReminderLogic.remove`）有生产调用方。**影响**：单节课提醒在 App 内只能读 / 删，**不能在 App 内新建**；且 L4 的 A6「取消提醒」在干净的 `dev` 包里造不出前置数据（得先有一条旧版一次性提醒条目），真机验收会卡在这一步。**需要谁拍板**：**Lead**——要不要在 Compose 侧补「App 内新建」属产品取向（写侧本身不复杂：`upsert` → `saveSettingsPatch` 落盘 → toast；真正要定的是继续只往系统时钟引导、还是复刻旧版一次性提醒语义）。**未排期，不要写成已开工** |

### C. agent 可做（按优先级）

| # | 事项 | 现状 / 写作用域 |
|---|---|---|
| **R08** | **全仓 L1/L2 复跑（原 F19）** | 部分完成（2026-11-08）：L1 已通过；L2 跑出 7584 例 / 1 失败，唯一失败是 `ArbCatalog.kt` 生成物过期（ARB 新键 `liquidGlassPresetCustom`），重新生成后再跑一次即可销账。写作用域：无代码，只跑 `scripts/safe-gradle.ps1` |
| **R09** | ~~通知点击落页~~ | ✅ **已落地**（2026-11-11 核销，依据代码与提交）：① **生产端 + 参数契约** `38df5178d`（2026-11-03）——`NotificationLaunchTarget.kt` 定 `open_route` / `open_lan_edit` 两个 extra，`pageIdFor`(:99) / `pageIdForIntent`(:119) / `postLaunchPage`(:132，解析后移除 extra 防重建重复推页)，生产端两处：`ExamReminderScheduler.kt:360` 写 `open_route=/exams`、`LanEditForegroundService.kt:29` 写 `open_lan_edit=true`；② **壳侧接线** `9427c4fd3`（2026-11-04）——冷启动 `pages/PagesShellActivity.kt:221-223`（`NotificationLaunchTarget.postLaunchPage(intent)`）、`singleTop` 复用 `:428-432`（`onNewIntent` → `setIntent` → `postLaunchPage`）；③ 三份 JVM 单测：`NotificationLaunchPageContractTest` / `NotificationLaunchShellWiringGuardTest` / `NotificationLaunchTargetGuardTest`。**已知边缘（未修，待真机判）**：`PagesShellActivity.kt:221` 的守卫是 `savedInstanceState == null`，进程被回收后点**新**通知若系统同时带回非空 `savedInstanceState`，该落点会被一起吞掉（作者在 `:217-220` 自记此事）；收紧方案是改判「该 Intent 是否真带页面 extra」，本行不预先实施。**真机项归 R01**，不算代码待办 |
| **R10** | **弹层剩余 11 条（`QingyuSheet` 两个底层缺口已修；42dp 一族 4 处已修 1）** | **两个底层缺口 → 已销**（2026-11-11 复核，均为活码、非注释）：① 标题动作贴边 —— `bd0c3eb7` 的私有 `horizontalBleed`（`QingyuSheet.kt:186` 调用、`:236` 定义）：有标题动作时保留 16dp、内容反向外扩，标题不贴边且内容仍满宽；② IME 叠加 —— 同提交引入 `androidx.compose.foundation.layout.ime` 与条件（现 `:176-177`：`imeBottomPx > 0` 时只留 16dp 呼吸，不再多垫 24~40dp）。**审计「11 条仍成立」里这两条已过期，别再按 `2026-11-02-compose-dialog-full-audit.md` 报**。另：`143638290`（11-10）是标题区 / 内边距 / 按钮区统一刻度 + 缩放守卫，IME 判据未变（只随重构移行）——「IME 由 `143638290` 修」与代码不符，见文末变更记录。**42dp 无标题空档（原计 4 处）→ 已修 1 / 未修 3 / 非缺陷 1**：已修 `pages/timetable/WeekSelectorSheet.kt`（`f7723ddd`：标题收回套件标题行 `:108`，删掉自绘 `headline1` + 8dp `Spacer`）；未修 `pages/course/CourseActionSheet.kt:163`、`pages/course/CourseNoteSheet.kt:143`（其注释 `:145-148` 已自记这 42dp）、`app/AppearanceEditorHost.kt`（材质 `:853` / 壁纸 `:886` 两面板不传 `title`，正文自带头）；**非缺陷** `pages/timetable/TimetableTopBar.kt:695`（八宫格「更多」，用户口径就是「不显示标题」，注释 `:697-699`，**别被后人当缺陷翻修**）。**算式（以后一次收口用）**：**42 = 24dp 把手 + 6+12dp 标题行**，两段都**无条件**画在 `third_party/miuix-ui/src/main/kotlin/top/yukonga/miuix/kmp/layout/BottomSheetContentLayout.kt:643-657`（`DragHandleArea` + `TitleAndActionsRow`，无 `title != null` 守卫），标题行 `padding(top = 6.dp, bottom = 12.dp)` 在 `:806`、把手 `.height(24.dp)` 在 `:735` ⇒ `title = null` 只跳过文字、不跳 padding。**收口要走「改库批次」**（动 miuix 共享件，影响所有无标题弹层）⇒ 需一次 L1 验编译，**待排批、不排期**。仍未做：自动聚焦 ×4、选周结构、ICS 菜单等（部分待 R05 拍板）。写作用域：`components/`、`pages/course/`、`pages/timetable/`、`pages/settings/`、`third_party/miuix-ui/` |
| **R11** | **弹窗玻璃铺开** | 试点只有加课页删除确认 1 处（`e8cafb75` / `4a8011b3`，守卫钉调用点数=1）。先等真机看采样跟手与低端机帧率，确认后再铺其余 46 处 OverlayDialog 与底部弹层。写作用域：`components/glass/`、`pages/**` |
| **R12** | **局域网两个残余** | `LanTransferLogic.kt:54` / `LanEditRepositoryHost.kt:70-72`：① settings 只应用 Kotlin 已移植的时间/周次子集；② 地点分组变化后不重算课程钟点（Dart `replaceLocationTimeGroups(resync:true)` 无对应物）。撤销点、真实 `transferId`、整份恢复已完成，勿重做。写作用域：`main/transfer/lan/`、`main/app/TimetableRepository.kt` |
| **R13** | ~~F18：两条壁纸路由语义~~ | ✅ **已解决**（2026-11-11 校准）：`ShellPageIndex.kt:553-557` 注释原文记「原先 `b.recentWallpaper` 与 `b.backdropFlow` 都落 PICKER、语义重复（R13），已合并为这一条」，判据是 Dart `settings_home_backdrop_flow.dart:439-472`（该页同时含选图行与「最近使用」缩略图条，无独立页）；课表页「最近使用」行改由 `SettingsHost.timetablePageSheetRoute` 映射到同一个 `b.backdropFlow`。**注意**：保留哪一条是实现决定，若产品要恢复两个独立入口需另开需求 |
| **R14** | ~~壁纸取景页「换壁纸」入口~~ | ✅ **已交付**（2026-11-11 校准）：提交 `5ade79faf`（2026-11-03）「取景页补『换壁纸』，选图落盘与补历史抽成共享件」——新增 `ManagedWallpaperStore.kt` / `ManagedWallpaperNaming.kt`，`WallpaperPositionPickerPage.kt` +180 行、`ManagedWallpaperPickChainTest.kt` 149 例；`WallpaperPositionPickerPage.kt:148` 注释自证「『换壁纸』（2026-11-03 R14 补上）」 |
| **R15** | **自检页 4 个测试通知按钮** | `LiveSelfCheckHost.kt:362-366` 四个分支仍只弹「不可用」；要么移植测试夹具管线，要么明确记为已知缺口。台账旧 §9.10「已闭环」是过度声明。写作用域：`app/LiveSelfCheckHost.kt`、`pages/live/`、`main/pages/live/` |
| **R16** | **埋点页面级接线** | core 三件与 `TimetableRepository` 单点已提交（`b9e5cdb6` / `9cd1e337`）；`composeP1` 页面侧引用为 0，无持久化/导出/后端 sink。先定要采哪些页面事件与隐私边界（产品决定）。写作用域：`main/core/`、`composeP1/app/` 与各页面宿主 |
| **R17** | **宽屏收尾** | 前三批已落地：三档判据 `499b28d8`、`QingyuPageScaffold` 限宽与 SmallTopAppBar 分支 `75afb7f0`、Rail 判据 `6a564625`、`ShellNavigationRail` 接入 `e2e33583`。剩余：首页课表网格宽屏列数（属课程域另一批）+ 宽屏连带面的真机验（`R02` 的方向锁已由 `1e8b953b7` 解除，剩下的矮屏弹层 / 返回手势 / Rail 冲突归 R01）。写作用域：`components/`、`pages/shell/`、`pages/timetable/`（`AndroidManifest.xml` 已无需再动） |

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
| R02 横屏/平板解锁（原「两个 Activity 锁 portrait」） | `1e8b953b7`（2026-11-08）删除两处方向锁；现仅注释 `main/AndroidManifest.xml:169-172` |
| R06 `src/perf/AndroidManifest.xml` 去留 | 文件已不存在，`android/app/src/perf/` 空目录、0 个跟踪文件（2026-11-11 校准） |
| R13 两条壁纸路由语义 | `ShellPageIndex.kt:553-557` 注释：已合并为单条 `b.backdropFlow`，Dart 判据 `settings_home_backdrop_flow.dart:439-472` |
| R14 壁纸取景页「换壁纸」 | `5ade79faf`（2026-11-03）+ `WallpaperPositionPickerPage.kt:148` 注释；共享件 `ManagedWallpaperStore.kt` / `ManagedWallpaperNaming.kt` |

> 以上只证明「代码已提交、门禁当时绿」，**不等于真机验过**。所有真机验收统一归 R01；
> 不要因为某条出现在本表就对外说「已完成」。

---

## 五、接活与避让

1. **认领协议仍有效**（用户 2026-11-03 决定保留）：`.agents/compose-phase3/claims/` 里「有文件的批次 = 有人在做」。
   **但认领文件大面积过期**（2026-11-11 校准实测）：清理前 **199 个文件（120 份 `.md`）**，只有 31 个在 2026-11-01 之后动过；
   头部状态写「进行中」的 **7 份**而工作早已交付，本次已按交付提交清掉这 7 份（B1 / F29 / F28 / F32 / P3-C2 / P3-F / P3-K，
   依据提交见文末变更记录），**清理后 192 个文件（113 份 `.md`）、25 个在 2026-11-01 之后动过、无「进行中」**；
   最新文件回到 `F03-pickup-lan.md`（2026-11-02）。F18 仍无认领文件。
   **核实方法要改**：`.agents/` 被 `.gitignore:140` 忽略（`git ls-files .agents` 返回 0），所以认领区**无法**用
   `git status` / `git log` 核实。要落到产物上：`git cat-file -e HEAD:<目标路径>` 判产物在不在，
   `git merge-base --is-ancestor <提交> HEAD` 判交付提交是否已在 HEAD。
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
| 3 | ~~`src/perf/AndroidManifest.xml` 去留（R06）~~ **已取消**：文件不存在（2026-11-11 校准） | — |
| 4 | L0 共享目录隔离方案：挪文件 / 扩源集 / 换宿主域（R07） | Lead |
| 5 | ~~横屏/平板是否解锁（R02）~~ **已解决**：`1e8b953b7` 已删方向锁（2026-11-11 校准） | — |
| 6 | R2 删 Flutter 的时机（R03） | 用户 |
| 7 | 弹层 #5 / #7 / #8 的取舍（R05） | Lead |
| 8 | 单节课提醒要不要补「App 内新建」（R18，2026-11-11 新发现） | Lead |

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
| `2026-11-11-l4-device-checklist-dev.md` | **现行 L4 真机手册（`dev` 变体口径）**，2026-11-11 起取代下面那份；正文提交 `8b84bc13a`（已核实存在于 HEAD） |
| `2026-10-27-compose-phase3-l4-checklist.md` | ~~用户真机逐页清单~~ **已被上一条取代**（历史）：仍写 `.ui` 包名与已删 flavor，只作历史依据 |
| `2026-11-02-compose-dialog-full-audit.md` | 弹层审核明细与 8 个决策点 |
| `2026-11-03-compose-widescreen-adaptive-plan.md` | 宽屏方案；前三批已落地，剩 R17（R02 已解决） |
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

- **2026-11-11 R10 复核（只改账）**：
  - **审计 11 条里 2 条已过期**：「标题动作贴边」与「IME 叠加」均已由 `bd0c3eb7`（2026-11-03）修掉，
    代码为活码 —— `QingyuSheet.kt:186` 调 `horizontalBleed`（定义 `:236`）、`:176-177` 的 `imeBottomPx > 0`
    只留 16dp 呼吸。`2026-11-02-compose-dialog-full-audit.md` 的「11 仍成立」按 **9** 条引用。
  - **归属更正（未采信口述的 sha）**：另有说法称 IME 那条由 `143638290` 修。实测 `143638290`（11-10，
    标题区/内边距/按钮区统一刻度 + 缩放守卫）的 diff 里 IME 段落全是**上下文行**（`*` / 空），
    未改判据；`bd0c3eb7` 的 diff 里才有 `+import ...layout.ime` 与 `+val imeBottomPx`。
    故 IME 那条记在 `bd0c3eb7` 名下，`143638290` 只记「统一刻度 + 缩放守卫」。
  - **42dp 一族进展**：已修 1 处 `WeekSelectorSheet`（`f7723ddd`，标题收回套件标题行 `:108`，删自绘
    `headline1` + 8dp `Spacer`）；未修 3 处 `CourseActionSheet.kt:163`、`CourseNoteSheet.kt:143`、
    `AppearanceEditorHost.kt`（材质 `:853` / 壁纸 `:886`）；`TimetableTopBar.kt:695` 为**用户口径的故意无标题**（注释 `:697-699`），计为非缺陷。
  - **算式与出处**：42 = 24dp 把手 + 6+12dp 标题行，两段无条件画在
    `third_party/miuix-ui/.../layout/BottomSheetContentLayout.kt:643-657`，标题行 padding 在 `:806`、
    把手高度在 `:735` ⇒ `title = null` 照占。改库批次影响所有无标题弹层、需一次 L1，标**待排批、不排期**。

- **2026-11-11 补记（新发现，未排期）**：
  - **新增 R18「单节课提醒 App 内无法新建」**（放「等 Lead 拍板」，不排期）：`ClassReminderLogic.upsert`
    （`core/ClassReminder.kt:113`）生产调用点 0，只有 `ClassReminderSettingsTest.kt:153`/`:161` 在调；
    `ClassAlarmSheet` 三动作全走 `SystemAlarmHelper.fireSetAlarm`（`SystemAlarm.kt:21`/`:29`，
    `AlarmClock.ACTION_SET_ALARM`），不写 `classReminders`；整链只有读（`TimetableWeekPage.kt:773-775`）
    与删（`ShellWiring.kt:1284` → `ClassReminderLogic.remove`）。影响：A6「取消提醒」在干净 `dev` 包里
    造不出前置数据。
  - **L4 手册更替**：`2026-10-27-compose-phase3-l4-checklist.md` 已被 `2026-11-11-l4-device-checklist-dev.md`
    （`dev` 变体口径）取代，R01 与 §八 文档地图两处引用同步改指新册；新册正文由 L4 手册那条线提交于
    `8b84bc13a`（2026-11-11，已核实存在于 HEAD；本行只登记更替关系，不复制手册内容）。

- **2026-11-11 校准（只改账，未改代码；依据代码与提交）**：核销五条已失真待办，修正三处计数。
  - **R02 横屏/平板解锁 → 已解决**：提交 `1e8b953b7`（2026-11-08，去 Flutter 化 P4-B）删除两处
    `android:screenOrientation="portrait"`；`git show 1c198b4f3:.../main/AndroidManifest.xml` 当时仍有两条属性行（`:174`/`:190`），
    到 `1e8b953b7` 只剩解释性注释（现行 `main/AndroidManifest.xml:169-172`）。残留真机连带面归 R01/R17。
  - **R06 `src/perf/AndroidManifest.xml` 去留 → 已取消**：`Test-Path` = false，`git ls-files android/app/src/perf` = 0，
    目录存在但为空；`build.gradle:108` 的 `perf {}` 是 `env` flavor 而非源集。
  - **R09 通知点击落页 → 已落地**：`38df5178d`（2026-11-03）定义 `open_route` / `open_lan_edit` 契约与
    `pageIdFor`(:99) / `pageIdForIntent`(:119) / `postLaunchPage`(:132)，生产端 `ExamReminderScheduler.kt:360`、
    `LanEditForegroundService.kt:29`；`9427c4fd3`（2026-11-04）壳侧接冷启动 `PagesShellActivity.kt:221-223`
    与 `onNewIntent` `:428-432`；三份 JVM 单测 `NotificationLaunchPageContractTest` /
    `NotificationLaunchShellWiringGuardTest` / `NotificationLaunchTargetGuardTest`。**已知边缘未修**：
    `PagesShellActivity.kt:221` 用 `savedInstanceState == null` 作守卫，杀进程后点新通知可能被吞（作者自记于 `:217-220`）；
    改为判「Intent 是否真带页面 extra」属后续可选收紧。真机项归 R01（已在其行内补两条必验）。
  - **R13 两条壁纸路由 → 已解决**：`ShellPageIndex.kt:553-557` 注释记已合并为 `b.backdropFlow`（判据 Dart `settings_home_backdrop_flow.dart:439-472`）。
  - **R14 取景页「换壁纸」→ 已交付**：`5ade79faf`（2026-11-03）+ `WallpaperPositionPickerPage.kt:148` 注释；
    同批新增共享件 `ManagedWallpaperStore.kt` / `ManagedWallpaperNaming.kt` 与 `ManagedWallpaperPickChainTest.kt`（149 例）。
  - **计数**：`composeP1/.../pages/` 实测 **63 个 `*Page.kt` / 190 个 `.kt`**（HEAD `358af4aad`，工作区干净），旧记 186/188 作废；
    认领区清理前 **199 个文件（120 份 `.md`）**、31 个在 2026-11-01 之后动过、头部写「进行中」**7 份**（旧记分别是 121 份 / 24 份 / 23 份）；
    清理后 **192 个文件（113 份 `.md`）**、25 个在 2026-11-01 之后动过、无「进行中」。
  - **清过期认领 7 份**（`.agents/compose-phase3/claims/`，该目录被 `.gitignore:140` 忽略，不进 git）：
    `B1-first-run-privacy.md`（`8d2d22f36`/`3f49f0257`）、`F29-wallpaper-whitelist-profiles.md`（`d0671f983`）、
    `F28-i2-school-list.md`（`0abf794ed`）、`F32-i2-import-writeback.md`（`83e8426ac`/`2ed2fbba6`）、
    `P3-C2.md`（`810f801a7`）、`P3-F.md`（`dfdac7f2c`）、`P3-K.md`（`aef4c5c85`）；
    九条提交均以 `git merge-base --is-ancestor <sha> HEAD` 核实为 HEAD 祖先。
  - **F18 归位**：`2026-10-29-remaining-pages-tasklist.md` §七 状态由「🔒 等前置」改为「可开工，待认领」——
    前置 F06 认领文件状态为「已交付（由后续批次落地，2026-11-01 复核）」，且 `claims/` 下无 `F18-*` 文件；未标完成。

- **2026-11-08 L1/L2 复跑**：L1 通过（`BUILD SUCCESSFUL in 57s`，HEAD `cb8f14d1f`）；L2 `:app:testDevDebugUnitTest` **7584 例 / 1 失败**，唯一失败是 `ArbCatalogTest`——`ArbCatalog.kt` 未随 ARB 新键 `liquidGlassPresetCustom` 重新生成（生成器 `--check` 报过期）。刷新生成物后需再跑一次 L2 才能销 R08。
- **2026-11-08 数字校正**：路由 89/88 → **88/87**（`ShellPageCatalogTest` 实测，HEAD `7f8395776`）；`pages/**/*.kt` 176 → **183**（同 HEAD，工作区含未跟踪文件为 184）；样式例外 10 → **7**（timetable 4 + import 2 + showcase 1，`-Domain all` 待修 0 / 过期 0）。
  注意：`2026-11-07-refactor-full-audit.md` 里的 181 是 `3cf8d910b` 基线，不是当前值；例外 5 条同理。
- **2026-11-03 建立**：合并派工大表、Phase 3 页面台账、剩余页任务清单、现状交接、全仓体检五份进度文档；
  统一口径为 89/88/0/1；把 78/82/87/165 标为历史；销账 I2 收尾、截屏面板、教务对话框、WebDAV 恢复、
  通知权限、JVM21、宽屏前三批、timetable L0 跨域；新增 R01–R17 待办与阻塞归属。
