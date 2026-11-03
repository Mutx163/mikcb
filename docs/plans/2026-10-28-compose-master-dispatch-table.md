# 轻屿课表 Compose 迁移 · 全景直通派工大表

> **进度已合并（2026-11-03）**：本文件的进度/状态列不再更新，统一见
> [Compose 迁移 · 唯一进度账](2026-11-03-compose-status.md)。本文保留为**派工明细与逐包验收门槛**。

> **定位**：Phase 3（页面搬运）已完工，当前瓶颈是「页面还没被接上真实仓储与系统服务」。
> 本表是**接线期的派工看板**：**7 个业务域 / 13 个工作包**，每个包给「真实写作用域 + agent 可自证门槛 + 用户真机验收」。
>
> **口径（2026-10-28 复核后修订）**：**本表勾完 ≠ 全仓完工**。表外仍有能力没被任何一行覆盖（见 §五）；「演示数据清零 / 1:1 对齐 Flutter」这类话要等 §五 也清空、且用户走完真机逐页对照之后再说。
> 进度与待办状态以 [唯一进度账](2026-11-03-compose-status.md) 为准；本表只是派工看板，**不替代进度账**。

---

## 零、开工前 30 秒（照做，别跳）

1. **先看认领区** `.agents/compose-phase3/claims/`：**有文件的批次 = 有人在做，别碰**。
   本表「当前状态」列已于 2026-11-01 按代码复核刷新，并于 2026-11-02 按 HEAD `b596989c` 回填漂移状态（原为 2026-10-28 快照），但认领前仍一律以认领区为准。
2. **只在 §二 给的写作用域里写文件**（写作 `源集: 相对路径`，源集根见 §二 表头）。
   标 **[Lead]** 的路径属 Lead 专属，泳道不得改。
3. **交付证据按 §三 的门槛走**：L0 模块单测 → L1 编译 → 需要时 L2 单测；
   **L3 出包 / L4 真机归用户**。agent 只能声明「编译通过 / JVM 单测通过」，
   **不得**声明「能装上 / 已验证」。L1/L2 一律走 `scripts/safe-gradle.ps1`，裸跑 `./gradlew` 违规。
4. **动 `composeP1/.../pages/` 下任何页面的布局/滚动/卡片/标题/字号/颜色之前，先读
   `docs/reference/compose-page-style-rules.md`**：七条规则（R1..R7，R7 为 2026-11-01 新增的字重平移规则）有守卫
   `ComposePageStyleGuardTest` 机械执行，存量债冻结在 `tool/compose_style_baseline/<域>.txt`
   （棘轮：新增必红、过期必红）。自查用 `pwsh -File scripts/compose-style-lint.ps1 -Domain <域>`。
   —— 这一节是 2026-10-28 加的：此前页面各写各的（42 页裸 `LazyColumn`、27 页裸 `Card`、
   34 页写死字号、23 页写死颜色），真机上才看得出差异，靠文档自觉一整轮都没治住。

---

## 一、派工总览看板

### 1.1 可复核的底座数字（口径写清，免得被误读）

| 说法 | 真实口径 | 出处 |
|---|---|---|
| 「87 条可进入」 | **索引里可进入的条目数 = 88**（暂不可用 **0**、常驻 1，合计 **89**，四个数字被 JVM 测试钉住）；**不是**页面文件数。旧口径「82 / 78 / 3」与「87 / 0 / 1 / 88」均已过期（原口径是 F24 之前的快照；F24 `32808774` 新增「壁纸取景」一条后为 89/88）。2026-11-01 二次复核 | `ShellPageCatalogTest.kt:38`、`:46-48`（2026-11-01 复核） |
| 页面文件 | `composeP1/.../pages/` 下 `*Page.kt` **63** 个、`.kt` 共 **165** 个（口径 = 已提交的 HEAD `b596989c`；未提交的在途文件不计。原记 63/160 是 HEAD `177cba57` 时的数字，2026-11-02 重数） | `git ls-tree -r --name-only HEAD` 实测（2026-11-02） |
| 小组件 | **10 个** `appwidget-provider`：10 份 `widget_*_info.xml` ↔ manifest 里 10 个 receiver（第 11 处 `APPWIDGET_UPDATE` 是刷新广播，不是 Provider） | `AndroidManifest.xml` |
| 原「还进不去」的 3 条 | **现均已可进入**：二维码发送（`ShellPageIndex.kt:1564`）、二维码扫码（`:1578`）、月视图（`:545`）都已接分派；目录 `UNAVAILABLE = 0` | `ShellPageCatalogTest.kt:41` |
| 相机依赖 | CameraX `1.6.1` + MLKit `barcode-scanning:17.3.0` **已进**两个 compose 变体（`0b97f20c`）——台账 §9.4「相机真依赖未加」**已过期** | `android/app/build.gradle` |
| 正式包入口 | 启动页已切到 Compose 壳 `PagesShellActivity`（`1158ee20`，2026-11-02）；回退方式写在 `main/AndroidManifest.xml:159-160`、`:191-193` 注释里（把 MAIN/LAUNCHER 挪回 `.MainActivity`）。**存疑**：`src/perf/AndroidManifest.xml`（2026-11-02，工作区未提交）在启动页上移到 `main` 后只承担「关掉 `MainActivity`」，可能多余；未删，待定 | `main/AndroidManifest.xml:154-193`、`src/perf/AndroidManifest.xml:14-17` |

### 1.2 七个业务域、十三个工作包

```
[课表核心]  T1 课程操作弹层 · T2 档案管理
     │
[设置偏好]  S1 显示偏好 · S2 设置族其余页面
     │
[导入导出/相机]  I1 扫码 · I2 教务 WebView · I3 ICS 导出/分享
     │
[云同步]    C1 WebDAV 收发 · C2 本地备份导入导出
     │
[统计]      ST1 单节课明细与深度分析接线
     │
[小组件联动]  W1 桌面小组件 / 实时活动刷新
     │
[主入口切壳]  R1 切壳 · R2 撤 Flutter（用户参与）
```

> 图与 §二 表逐一对得上。**ST1 也必须出现在图里**（旧版图漏了它，这是「10 个包」这个错误数字的来源之一）。

---

## 二、全景派工总表（按此表派 Agent）

**写作用域写法**：`源集: 相对路径`；**源集根 = `android/app/src/<源集>/kotlin/com/mutx163/qingyu/`**
（`main` = 全变体可见；`composeP1` = 仅 compose 变体；`test` = 只能引用 `main`；`composeUi` = 壳）。
仓库根下的 `android/app/build.gradle`、`android/app/src/main/AndroidManifest.xml` 均属 **[Lead]**。

| 包 | 覆盖功能与页面 | 写作用域（真实路径，可直接核对） | 当前状态（2026-11-01 复核；原为 2026-10-28 快照） |
|---|---|---|---|
| **T1** | 课程操作弹层：首页点课呼出 6 个动作（编辑/删除/…）。壳 KDoc 诚实清单第 ① 条自己写明「建议单列一批」 | `composeP1: pages/course/`、`composeP1: pages/timetable/`（仅新增回调）＋ **[Lead]** 壳挂接 | **已接线（真机未验）**：弹层按 Dart 原版复刻并接真仓储与课程动作（`962a534b`；壳侧 `ShellPageIndex.kt:507` `TimetableWithCourseActions`，渲染层 `pages/course/CourseActionSheet.kt`）。原文「可立即认领、只剩渲染层」已过期 |
| **T2** | `TimetableProfilesPage`：切换活动课表、新建、重命名、删除 | `composeP1: pages/timetable/`、`main: pages/timetable/TimetableProfilesModel.kt`＋ **[Lead]** 壳路由。仓储已带 `profiles`/`activeProfileId`，**不必动 `main: app/`** | **已接线（真机未验）**：`TimetableProfilesController` 驱动新建/切换/重命名/复制/删除（`ShellPageIndex.kt:512-538`；`TimetableProfilesController.kt:53`）。原文「可立即认领·仅页内动作」已过期 |
| **S1** | 课表显示偏好：隐藏周末、节次行高、时间列宽、长按空档加课 | `main: app/TimetableSettingsModel.kt`（**仅追加**显示偏好键）、`composeP1: app/TimetableHost.kt`、`main: pages/settings/`、`composeP1: pages/settings/` | **已接线（真机未验）**：4 键均已在设置模型（`TimetableSettingsModel.kt:112-143`：`sectionHeight` / `timetableTimeColumnWidthMode` / `timetableHideWeekends` / `longPressEmptySlotToAddCourseEnabled`）；隐藏周末已进周视图片段（`ShellPageIndex.kt:588-589`），行高与时间列宽由 `TimetableHostLogic.kt:101-108`、`SettingsTimetablePageSettingsPage.kt:226-279` 承接。原文「壳用默认值、缺另 3 键」已过期 |
| **S2** | 设置族其余页面：`ShellPageIndex` 的 `b.*` 页面 id 共 **25** 个（`b.weather`/`b.diagnostics`/`b.live` 等严格说不是设置页，归 §五 的未覆盖清单） | `main: app/SettingsActionDispatcher.kt`、`composeP1: app/SettingsHost.kt`、`main: pages/settings/`、`composeP1: pages/settings/` | **已接线（真机未验）**：`b.*` 25 条全部分派到宿主（`ShellPageIndex.kt:325-500`）；`SettingsPageBridge.specFor` 支持 8 个页 id（`SettingsPageBridge.kt:90-105`，`SUPPORTED_PAGE_IDS` 常量仍只列 4 个），其余由 `HomeWidgetHost` / `LiveSelfCheckHost` / `WeatherSettingsHost` 等专用宿主接管（`88c22e34`、`e8b5a06f`）。原文「已接 4 个、其余演示数据」已过期 |
| **I1**<br>*(原 B6)* | 扫码取景：相机预览槽位 + 解码。二维码**生成**已交付（`2a77c08f`）；`QrTransferScanPage` 本身是槽位参数页面（`cameraSlot: @Composable () -> Unit`） | `composeP1: pages/transfer/`、`test: pages/transfer/` ＋ **[Lead]** 壳注入 `cameraSlot`。**注意：没有 `transfer/camera/` 这个目录** | **已接线·真机未验**：可测层与相机宿主已落地（`QrCameraHost.kt` / `QrScanSessionCoordinator.kt`），`cameraSlot` 已由 `QrTransferHosts.kt:162` 注入；CameraX `1.6.1` + MLKit `17.3.0` 已进构建（`android/app/build.gradle:363-368`）。真机取景/解码仍是唯一未验项 |
| **I2** | 教务导入 WebView 桥接：网页登录、Cookie 保持、触发已有抓取适配器 | `composeP1: pages/import/warehouse/`、`main: pages/import/warehouse/`、`main: platform/` ＋ **[Lead]** 壳 | **WebView 层已交付，壳侧也已接真宿主（真机未验）**：真 WebView 宿主 `WarehouseWebViewHost.kt` 已接进 `WarehouseWebLoginPage.kt:249-251`；壳侧 `g2.webLogin` 已由 F28 换成 `WarehouseWebLoginHost`（`ShellPageIndex.kt:1735-1740`，`416972d8`，该提交说明未提这一行；地址链「自定义覆盖 > `import_url`」在宿主内，无地址时宿主自己显示诚实空态）。原「因没有学校列表/真实 `import_url` 数据源而显示诚实空态（`:1543-1549`）」已过期。**2026-11-02 回填：抓课写回已交付**——`83e8426a`（2026-11-01）让脚本回传的 `courses` 经 `WarehouseCourseImportLogic` → `WarehouseCourseWriteBack` → `TimetableRepository.replaceActiveProfileContent` 写回当前档案，壳传 `repository = wiring.timetable`（`composeP1/.../warehouse/WIRING-NOTE.md` §10）。原文「只记日志、不写课表」已由 `83e8426a` 取代。**仍未做**：`saveCourseConfig`/`savePresetTimeSlots` 落盘、「替换/合并」与开学日/周次映射弹窗（同上 §10 诚实清单）；**原生 confirm/prompt/单选对话框进行中**（`WarehouseBridgeDialogHost.kt` / `WarehouseBridgeDialogModels.kt`，2026-11-03 工作区在途，未提交） |
| **I3** | `IcsExportPage`：生成 `.ics` 并通过系统分享导出 | `composeP1: pages/export/`、`main: platform/`（需**新建**分享/文件适配器，如 `AndroidShareAdapter.kt`）＋ **[Lead]** 壳 Activity 注册 `FileProvider` 与分享 Intent | **已交付（真机未验）**：`FileProvider` 已在 manifest 注册（`AndroidManifest.xml:137-151`），分享/SAF 走 `AndroidShareAdapter.kt:123`、`IcsExportHost.kt:278`；`createChooser` 已在 `AndroidShareAdapter` / `AndroidTransferShareAdapter` / 诊断导出等多处。原文「FileProvider 0 处、createChooser 0 处」已过期 |
| **C1** | `CloudSyncPage`、`CoupleTimetableSettingsPage`：WebDAV 备份/恢复真收发 | `main: sync/`（**已交付** `c339330d`）、`composeP1: pages/sync/`、`main: pages/sync/` ＋ **[Lead]** 壳接线 | **已接线（真机未验）**：`CloudSyncController` 用真 `WebdavRemoteTransport` 驱动 `f.cloudSync` / `f.backupList`（`ShellPageIndex.kt:1592-1652`；`CloudSyncController.kt:46-50`），上传/下载/删除/恢复均有落点。**2026-11-01 复核：恢复已写回仓储**（`c701a6b7`）——`CloudSyncController.kt:96-100` 的 `effectiveSnapshotApplier` 调 `TimetableSnapshotBridge.applySnapshot(repo, bytes)`（`TimetableSnapshotBridge.kt:79`），壳在两处控制器构造里都传了 `repository = wiring.timetable`（`ShellPageIndex.kt:1596`、`:1650`）。原「恢复只下载快照、不写回仓储」已过期 |
| **C2** | 备份还原页：SAF 选文件、导入/导出全量 JSON | `main: platform/`（SAF 适配器）、`composeP1: pages/sync/` ＋ **[Lead]** 壳 Activity 注册 `registerForActivityResult` | **已交付（真机未验）**：SAF 导入/导出适配器在（`AndroidSafBackupAdapter.kt`、`AndroidTransferDocumentAdapter.kt`），传输页走 `DataTransferHost.kt:207` `OpenDocument`；全仓 `ActivityResultContracts` 现为 **25** 处。原文「仅 1 处、SAF 入口尚不存在」已过期 |
| **ST1** | `StatisticsSessionPage`（+ 统计族 5 页 / 10 个图表件）：换掉假数据，读真实课表 | `composeP1: pages/statistics/`、`main: pages/statistics/`（模型层**已存在**）＋ **[Lead]** 壳喂数与二级页路由 | **已接线（真机未验）**：统计主页/设置/分析/单节均读真实仓储快照（`ShellPageIndex.kt:1373-1504`，`StatisticsFeed.Input.fromSnapshot`）；分享走真成果图（F15）。原文「壳仍喂 `courses = emptyList()`、打开统计看到空页」已过期。<br>**2026-11-02 回填：`e.analysis` 点课程已交付**——`58057a9c`（2026-11-01）把 `onOpenCourse` 接上 `StatisticsRankingLinkModel.resolve` 并跳 `d1.addCourse`（HEAD `ShellPageIndex.kt:1637-1653`）。原文「仍无落点」已由 `58057a9c` 取代。<br>单节课提醒 `classReminders`：**已提交全链**——字段 `50e8af4c`（`core/TimetableSettings.kt:34`、`StatisticsFeed.kt:121`），课卡铃铛与课程弹层「已设提醒 + 取消」读侧与壳侧回调接线 `7adf26a2`（2026-11-03 复核） |
| **W1** | 课表变更后广播唤醒桌面小组件与实时活动刷新 | `main: *.kt`（**根包**：`TodayWidgetSupport.kt`、`WidgetRefreshWorker.kt`、`HomeWidgetRefreshReceiver.kt`、`WidgetBindingStore.kt`、`WidgetProviderCatalog.kt`）、`main: app/`（事件源） | **已接线（真机未验）**：生产调用点已补上——`WidgetRefreshHost.kt:95` 构造 `WidgetRefreshBridge(`，由 `UmengApplication.kt:19` 启动时 `initialize`；订阅 `FlutterSharedPreferences` 变更、去抖 250ms 后刷新桌面卡片（提交 `480bf611`，2026-11-01）。原「全仓生产代码里没有 `WidgetRefreshBridge(` 的构造点」已过期。注：本行只覆盖桌面小组件与刷新广播；**超级岛判据未定**（`P3-L` 仍 ⏸ 待拍板） |
| **R1** | 主 `MainActivity` 从 `FlutterActivity` 切到 Compose 入口，保留回退 | **[Lead]** `main: MainActivity.kt`、`composeUi: pages/`、`android/app/build.gradle` | **已交付（2026-11-02，`1158ee20`）**：正式包启动页已由 `.MainActivity` 切到 `.pages.PagesShellActivity`（`main/AndroidManifest.xml:154-175`），回退方式写在同文件 `:159-160` 与 `:191-193` 注释（把 MAIN/LAUNCHER 挪回 `.MainActivity` 即可）。原文「等 I/C/W 收口」已过期。**存疑**：工作区未提交的 `src/perf/AndroidManifest.xml` 只承担「关掉 `MainActivity`」，启动页上移后可能多余（未删，待定） |
| **R2** | 摘 Flutter 依赖、出正式包 | **[Lead]** 根构建配置 ＋ 用户（`flutter build` / `assemble*` 归用户跑） | **【Lead 专属·最后一步】**：**前置条件未满足**——接线计划的回退窗口到 Phase 5 才关，`lib/**` 在此之前是只读对照物，**不删**；「删 lib/、Flutter 插件与构建脚本」不能排在切壳同一天 |

---

## 三、验收门槛（逐包，agent 侧 vs 用户侧分开）

> agent 的活只能自证到 **agent 可自证** 这一列；右列必须由用户在真机上确认（L4）。

| 包 | agent 可自证（交付时必须给证据） | 需用户真机（L4） |
|---|---|---|
| T1 | L0 `-Module "pages/course"`；弹层动作→宿主调用的**契约测试**（直接断言目标实例字段）；咬合探针 | 点课出弹层、6 个动作真的生效 |
| T2 | L0 档案模型 CRUD 单测；切换档案后首页数据的契约测试 | 切档案后首页立刻跟着变 |
| S1 | L0 显示偏好键往返单测；**合并写守卫**（改一个已知键不能清掉存档里其它键） | 关掉周末列/改行高，杀进程重开仍然生效 |
| S2 | L0 各页模型单测 + 文案与 ARB **逐字对拍** | 逐页走一遍，开关都能存住 |
| I1 | L0 解码协调层（`QrScanSessionCoordinator`）单测；文案对拍 | 相机真出取景画面、扫得出码 |
| I2 | L0 Cookie 提取 / 课表解析单测 | 真登录页能过、能拉到课 |
| I3 | L0 `IcsSerializer`/`IcsText` 单测；文案对拍；咬合探针 | 系统分享面板真的出现、文件能存到目标应用 |
| C1 | L0 `WebdavHttpTransport` 已有测试 + 冲突/断线/中途退出用例 | 真 WebDAV 走一轮上传→下载→冲突 |
| C2 | L0 备份 JSON 往返、损坏值留档单测 | 选文件、恢复后数据真回来 |
| ST1 | L0 统计模型单测 + 文案对拍 | 统计数字与真实课表一致 |
| W1 | L0 小组件逻辑单测（`WidgetStatsLogic` 等） | 桌面上已添加的小组件真的刷新 |
| R1 | L1 编译 + 壳可进入 | 覆盖安装后数据一条不丢、能正常用 |
| R2 | —（构建归用户） | 出正式包 + 装机验证 |

---

## 四、进度路线图（13/13 全部排入，无遗漏）

| 波次 | 包 | 说明 |
|---|---|---|
| **Wave 1** | I1（真机未验）、T1 ✅、C1 ✅、I3 ✅ | I1 与 I3 都要动壳 Activity 注册 → **两件壳侧改动一次报 Lead 一起做**，别各自改壳。2026-11-01 复核：T1/C1/I3 已接线，I1 只剩真机取景 |
| **Wave 2** | T2 ✅、S1 ✅、I2（WebView + 壳接线 + 抓课写回已交付）、S2 ✅、C2 ✅、ST1 ✅ | S1 必须等设置模型批次收口；S1 与 S2 同泳道，别并行。2026-11-02 回填：I2 抓课写回已由 `83e8426a` 交付，剩余是原生 confirm/prompt/单选/保存配置与逐页真机对照 |
| **Wave 3** | W1 | 依赖 Wave 1/2 的仓储事件源 |
| **Wave 4** | R1 ✅（`1158ee20`）、R2（未做） | Lead + 用户；2026-11-02 回填：正式包入口已切到 Compose 壳，回退方式写在 `main/AndroidManifest.xml:159-160` / `:191-193` 注释；R2 的删除动作仍等 Phase 5 回退窗口关闭 |

> 旧版路线图只列了 9 个包，**S2、C2 从未出现在任何波次里**——已补齐。

---

## 五、本表覆盖不到的（**别以为勾完本表就完工**）

| 缺口 | 现状（2026-11-01 逐条核实；2026-11-02 / 11-03 回填漂移项） |
|---|---|
| 局域网编辑收发 | **已解决（`378b801f`，2026-10-30）**：`LanEditRepositoryHost.previewTransferJson` / `applyTransferJson` 交给 `LanTransferApplier`（`LanEditRepositoryHost.kt:288-303`），真实写仓储；`LanEditApiRouter` 里的 501 只剩「host 不支持」兜底（`LanEditApiRouter.kt:108-109`、`:799-800`），真实宿主已实现。**2026-11-03 回填：撤销点与整份恢复均已提交**——导入撤销端点 `eb32ae25`（`transfer/lan/LanTransferUndo.kt`、`transferId` = 撤销点 id、`POST /api/v1/import/undo`），整份快照恢复放行 `45cfb149`（分层拒绝矩阵 `LanTransferLogic.kt:118`：full+非空 profiles → 整份恢复；full+空 profiles / 非 full 伪 all_data → 拒），预演标记与四语错误文案 `6c4a40dd`。原「没有撤销点 / `transferId` 恒 null / 多档案包一刀切拒绝」全部过期。剩余一条：「设置只应用已移植子集」，见 `.agents/compose-phase3/claims/F17-lan-apply-501.md` §明确没做 |
| 备份里 `tasks`/`exams` 写回、多档案恢复等**仓储原子入口** | **2026-11-01 复核后：WebDAV 云端恢复这条已解决**——`c701a6b7` 让恢复真正写回仓储：`CloudSyncController.kt:96-100` 的 `effectiveSnapshotApplier` → `TimetableSnapshotBridge.applySnapshot(repo, bytes)`（`TimetableSnapshotBridge.kt:79`），壳两处控制器都注入 `repository = wiring.timetable`（`ShellPageIndex.kt:1596`、`:1650`）；恢复前快照还留了撤销用回滚点（`CloudSyncController.kt:102-103`）。仓储原子入口仍在（`replaceActiveProfileContent` `TimetableRepository.kt:197`、`replaceAllProfiles` `:236`），文件导入写回 tasks/exams 在 `composeP1: pages/transfer/DataTransferHost.kt:477-486`（旧记 `:473-480` 已漂移）。**2026-11-03 回填：本行三条「仍未」全部清掉**——① 云备份恢复撤销 UI 已交付（`bc0a02c6`：`CloudSyncController.undoLastRestore` 与两份 viewState 的 `canUndoRestore`，`CloudSyncController.kt:335`、`:386`）；② **恢复前差异预览已交付**（`27f8ac2e` 差异概要纯函数 → `8ee25744` 恢复拆 prepare/confirm 两步、先算差异概要再等确认、确认时写回 prepare 已下载的同一份快照字节 → `c6e374cd` 确认框内嵌差异概要，`CloudSyncController.kt:463-485`；ARB 文案 `f11b5be6`）；③ 局域网多档案包已放行为整份快照恢复（`45cfb149`，见本表「局域网编辑收发」行）。原「多档案包被明确拒绝（`LanTransferLogic.kt:106-109`）」「差异预览仍无」均已过期 |
| 网络图片加载层 | **已交付并已接线**：`platform/AndroidImageLoader.kt` 在 Bing 画廊缩略图（`BingGalleryHost.kt:419`）、最近壁纸（`RecentWallpaperStrip.kt:392-395`）、内存统计（`MemoryStatsCollector.kt:232-237`）都有真实调用。「层在、零接线」的说法已不成立；其余页面按需接入 |
| 诊断族、考试、日程、任务、冲突、天气、引导、关于·更新日志 | **已由多批接线（2026-10-29 ~ 10-31）**：诊断 `ShellPageIndex.kt:484`/`:1608-1615`；考试 `:1095-1120`/`:1245-1280`（真仓储 + `TimetableExamService`）；日程 `:851-897`；任务 `:898-925`；冲突 `:1748-1760`；天气 `:283-287`/`:475-478`/`:1739`；引导 `:1622-1668`/`:1672`/`:1877-1905`；关于·更新日志 `:305-320`（`ChangelogPage` 读 APK 内 assets）。剩余：~~`e.analysis` 点课程进该课明细仍无落点~~ → **已由 `58057a9c` 取代**（2026-11-02 复核：HEAD `ShellPageIndex.kt:1637` 已接 `onOpenCourse` → `d1.addCourse`）；§五 其它行号会随提交漂移，以路由名为准 |
| 前台服务与保活 | **已接线，但本表仍无任何一行覆盖**：局域网前台服务由 `LanEditHost.kt:309-321` 启停；保活页 `j.keepAlive` 已接真状态/开关（`ShellPageIndex.kt:1706-1726`）。「接线未列行」这半句仍成立，指的是派工表覆盖面，不是代码状态 |
| 通知换通道 | **部分成立（2026-11-01 按 HEAD `177cba57` 核实）**：渠道创建已在 Kotlin 侧真做——考试提醒 `ExamReminderScheduler.kt:79-90`、周报 `WeeklyReportScheduler.kt:85-100`、实时活动 `LiveUpdateService.kt:826`、局域网前台服务 `LanEditForegroundService.kt:66-79`；`POST_NOTIFICATIONS` 已在 manifest 声明（`AndroidManifest.xml:92`）。**仍缺两半**：① 运行时申请只在 Flutter 壳 `MainActivity.kt:1877-1893`，**Compose 壳 `PagesShellActivity.kt` 未申请**；② 通知点击 Intent 只指向 `MainActivity`（`ExamReminderScheduler.kt:354-357`、`WeeklyReportScheduler.kt:321-324`、`LiveUpdateService.kt:2401-2406`），Compose 壳收不到。原「仍成立」只对「Compose 壳未接」成立，渠道本身已不是缺口（考试页注释「本批不假装会响」仍在 HEAD:1224，指的是同一件事）。2026-11-01 三次复核（HEAD `25f972ef`）：`PagesShellActivity.kt` 仍无 `POST_NOTIFICATIONS`，四个 scheduler/service 的点击 Intent 仍指向 `MainActivity`（`ExamReminderScheduler.kt:357`、`WeeklyReportScheduler.kt:324`、`LiveUpdateService.kt:2401`、`LanEditForegroundService.kt:26`），本条**仍成立**。**2026-11-02 回填：上述①②已由 `bd1bbeb0`（2026-11-01）取代**——Compose 壳在 `PagesShellActivity.kt:290-301` 申请 `POST_NOTIFICATIONS`；四处通知改用 `NotificationLaunchTarget.intent`，按变体解析启动页（`NotificationLaunchTarget.kt:35-49`），不再硬编码 `MainActivity`。剩余：壳当前不读 Intent 页面参数，点通知落在默认主屏（`NotificationLaunchTarget.kt:29-33` 自认）；渠道创建仍然已做 |
| 超级岛（实时活动） | **仍成立**：`P3-L` ⏸ 待拍板（RemoteViews vs Compose Glance；台账 §5 `:300-302`、`:565`），**本表无验收判据**（W1 的验收句里没有岛）。原生 `LiveUpdateService` 在，但展示层方案未定 |
| 真机逐页对照 / 毛玻璃 / `fontWeight` / 裸 `Card(` | **四项分开看**：① 真机对照 **0 页仍成立**（台账 §9.8 第 5 条；F23 认领文件也写「真机对照归用户」）。② 毛玻璃：**页面顶栏已接**（按 HEAD `177cba57`）——`QingyuPageScaffold.kt` 已引入 `rememberQingyuBlurBackdrop` / `layerBackdrop` / `textureBlur`，`QingyuBlurredTopBar` 以 `blurRadius = 25f` 通栏出玻璃（提交 `08246e26`，2026-11-01）；`layerBackdrop` 已扩到至少 6 个文件族（`QingyuPageScaffold.kt:160`、`GlassDockNavigationBar.kt:604`、`HomeWallpaperBackdrop.kt:209`、`TimetableWeekPage.kt:375/394`、`DayViewPage.kt`、`AppearanceEditorHost.kt:817`）。原「HEAD 的 `QingyuPageScaffold.kt` 无任何 blur 引用 / F24 E 线进行中未提交」已过期；弹层毛玻璃未逐项核，仍可能缺。③ `fontWeight`：**2026-11-01 已清零**（页面层 311 → 15，剩余全在 `pages/showcase/` 展厅、按规则豁免；功能字重 `fontWeight = weight` 不计）。做法见 `claims/STYLE-fontweight-sweep.md`：共享 `QingyuWeightDelta` + `TextStyle/SpanStyle.shiftWeight`，默认设置下与旧的绝对字重逐值一致；新增 R7 守卫防回潮。④ 裸 `Card(`：**真违例 0 处**——旧记「26 处 / 2 文件」是原始 grep 把展厅 25 处（规则 §五 豁免）与 `WeekSelectorSheet.kt:42` 的注释文字（1 处）都数了进去 |
| 壳里现存的演示数据 | **所列四类已清**：示例学校 / 示例适配器 / `example.com` 三个常量由 F23 删除（`e8b5a06f`，`ShellPageIndex.kt:1532-1549`）；示例日程与示例任务更早已删（`:848`、`:2098-2101`）。目录里约 60 条仍标 `DEMO`，但按枚举定义那是「页面需要一份视图状态」，不等于壳在编假数据（`ShellPageCatalog.kt:21-23`）；`b.*` 25 条均已分派到真宿主（`:325-500`） |

---

## 六、认领、回收与避让（与台账 §2 一致）

- **按批次领，不按页领**（同域 3~8 页）；领用 = 新建 `claims/<批次号>.md`（会话名 / 开始时间 / 写作用域），**文件创建是原子操作，新建成功才算领到**。
- **24h 无更新**：只能在那个认领文件里追加一行 `> [申请回收]`，**不许删别人的认领文件**。
  当前已超期：`P3-F`（最后更新 2026-10-27 13:37）。
- **Lead 专属**：`android/app/build.gradle`、`theme/`、两个壳的 Activity、`lib/ui/`、路由表、`AndroidManifest.xml`。
- **同目录必须串行**：`main: app/` 当前有 5 个在跑任务在写（含 `TimetableStore.kt`/`TimetableRepository.kt`/`TimetableSettingsModel.kt`），T1/T2/S1/W1 别各自声称改它；`composeP1: pages/sync/` 同期只允许一个泳道。

---

## 七、用户如何一秒给 Agent 派工

打开新对话窗口或有空闲 Agent 时，**不要解释复杂背景**，把下面这段复制发给他：

> **派工指令**：
> “请阅读 `docs/plans/2026-10-28-compose-master-dispatch-table.md`，认领其中的工作包 **【包编号】**（例如 **T1** 或 **I3**）。
> 先按 §零 核对 `.agents/compose-phase3/claims/` 里没有同域在跑，再新建认领文件；
> **只在 §二 给的写作用域内工作**（`[Lead]` 路径不要动），按 §三 的 agent 门槛交付并附 L0/L1 证据。
> 不要跑 `flutter build` / `assemble*` / `adb install`，也不要声明「能装上 / 已验证」。”

---

## 变更记录

- **2026-11-03 回填（文档追代码，逐条以当前工作区/HEAD 核实）**：① **云备份恢复改两步制**——`prepareRestore` 先下载+校验+算差异概要、确认后写回同一份快照字节（`8ee25744`/`27f8ac2e`/`c6e374cd`/`f11b5be6`，`CloudSyncController.kt:463-485`），「差异预览仍无」过期；② **局域网撤销点与整份恢复已提交**（`eb32ae25`/`45cfb149`/`6c4a40dd`），原「工作区未提交」过期；③ **`classReminders` 全链已提交**（字段 `50e8af4c`、课卡铃铛与课程弹层「已设提醒+取消」接线 `7adf26a2`），原「工作区未提交」过期；④ **文案三本账清零**——超宽 203 条 `5f21e99a`、死键清零（末条 `cloudSyncBaseUrlSecurityNote`）、复述 0 条，三份基线均只剩注释头；⑤ **页面样式基线 21 域 0 待还债**——仅 timetable 9 条例外（7×R5 数据色 + 2×R2 结构性，均注明原因，`206a10df`），弹层守卫基线两域 0 存量（`da42188c` 删最后一行）；⑥ **弹窗审计计数下探**——成就详情弹层 3 条由 `bcbc8ab6` 修掉（常驻组合 + per-id 语义色），复核结论改按 107 已不成立 / 26 仍成立 / 5 部分成立；⑦ §零 4 的「六条规则 R1..R6」改「七条 R1..R7」；⑧ **仍在途/仍缺**：宽屏适配 `AdaptiveTopAppBar`/`NavigationRail` 仍 0 处使用（`QingyuPageScaffold.kt:108-110` KDoc 自认，方案文档编写中）、埋点管道进行中（core `b9e5cdb6` + 接线 `9cd1e337` 已提交，工作区仍在调整文件落位）、截屏提示面板进行中（`ScreenshotSharePromptHost.kt` 未跟踪）、教务网页原生对话框进行中（`WarehouseBridgeDialogHost.kt` 未跟踪）、`pages/timetable` 域 L0 因跨域引用 `pages.settings`/`pages.shell` 符号跑不起来（`-Module pages/timetable` 只编本目录，跨域符号 Unresolved）。
- **2026-11-02 弹窗审核回填（文档追代码）**：`2026-11-02-compose-dialog-full-audit.md` 的 138 条弹层发现已逐条回填复核结果（已不成立 101 / 仍成立 30 / 部分成立 7，含当前行号、修复提交对照与 8 个待拍板决策点）。本表弹窗相关表述经核对无过时句，未改动。
- **2026-11-02 回填（文档追代码，HEAD `b596989c`）**：① **R1 已交付**——`1158ee20` 把正式包启动页切到 `PagesShellActivity`，回退方式写在 `main/AndroidManifest.xml:159-160` / `:191-193` 注释；② **I2 抓课写回已交付**——`83e8426a` 真写回当前档案（`WIRING-NOTE.md` §10），剩余原生 confirm/prompt/单选/保存配置；③ **`e.analysis` 点课已交付**——`58057a9c`（HEAD `ShellPageIndex.kt:1637`），并非工作区改动；④ **Compose 壳通知权限与点击路由已交付**——`bd1bbeb0`（`PagesShellActivity.kt:290-301`、`NotificationLaunchTarget.kt:35-49`），并非工作区改动；⑤ **云备份恢复撤销 UI 已交付**（`bc0a02c6`），差异预览仍无（`CloudBackupDetailHost.kt:53`）；⑥ **局域网撤销点与真实 `transferId` 已实现待提交**（`LanTransferUndo.kt` 未跟踪、`LanEditApiRouter.kt:281`、`:881-925`）；⑦ **单节课提醒 `classReminders` 已实现待提交**（`TimetableSettings.kt:34`、`StatisticsFeed.kt:121`）；⑧ 页面文件口径 63/160 → **63/165**（HEAD `b596989c` 实测）；⑨ `src/perf/AndroidManifest.xml`（工作区未提交）只关 `MainActivity`，启动页上移后**可能多余——只标注存疑，未删**。
- **2026-11-01 三次复核（收口，HEAD `25f972ef`）**：① **C1/§五 WebDAV 恢复已写回仓储**——`c701a6b7` 让 `CloudSyncController` 的 `effectiveSnapshotApplier` 调 `TimetableSnapshotBridge.applySnapshot`，壳两处控制器都注入 `repository`（`ShellPageIndex.kt:1596`、`:1650`），原「只下载快照不写回」证伪；② **I2 壳侧已接真宿主**——`g2.webLogin -> WarehouseWebLoginHost`（`ShellPageIndex.kt:1735-1740`，`416972d8`，该提交说明未提此行），原「因无学校数据源显示空态」证伪；剩余抓课写回/对话框仍未做；③ **`e.analysis` 点课程仍无落点**（`ShellPageIndex.kt:1553-1555`，`onOpenCourse` 未传），结论不变、行号更新；④ **通知换通道仍成立**：`PagesShellActivity.kt` 无 `POST_NOTIFICATIONS`、四处点击 Intent 仍指向 `MainActivity`（行号更新）。§五「局域网多档案被明确拒绝」复核仍成立（`LanTransferLogic.kt:106-109`）。

- **2026-11-01 二次复核（结清认领 + 逐条追代码）**：① §1.1 索引口径 87/0/1/88 → **88/0/1/89**（`ShellPageCatalogTest.kt:38`、`:46-48`），页面文件 62/149 → **63/160**（HEAD `177cba57`）；② **W1 改为「已接线」**：`WidgetRefreshHost.kt:95` 有 `WidgetRefreshBridge(` 构造点、`UmengApplication.kt:19` 启动 `initialize`（`480bf611`），原「生产代码无构造点」证伪；③ **毛玻璃改为「顶栏已接」**：`QingyuPageScaffold.kt` 已在 HEAD 引入 blur 三步配方（`08246e26`），原「HEAD 无 blur 引用、F24 未提交」证伪；④ **通知换通道改为「部分成立」**：四个渠道都在 Kotlin 侧真建，仍缺 Compose 壳的运行时权限申请与点击路由（`PagesShellActivity.kt` 无 `POST_NOTIFICATIONS`）；⑤ 修正上一条变更记录自相矛盾的「裸 `Card(` 更正为 26 处 / 2 文件」——实际 `grep` 只剩 2 处**注释文字**，真违例 0 处，与 §五 行文一致。
- **2026-11-01 复核修订（文档追代码）**：§1.1 索引口径由 78/3/82 改为 **87 可进入 / 0 暂不可用 / 1 常驻 / 合计 88**（`ShellPageCatalogTest.kt:36-45`），页面文件由 56/101 改为 **62/149**（实测）；§二 把 T1/T2/S1/S2/I1/I2/I3/C1/C2/ST1/W1 的状态从 10-28 快照更新为 11-01 代码实况（均标「真机未验」）；§五 **逐行核实**：局域网 `apply` 已由 `378b801f` 解决、网络图片层已接线、八个页面族已接真数据、壳内四类示例数据已清；task-14 改为「部分解决」并点明云端恢复仍不写回；**仍成立**的条目保留并补证据（通知换通道、超级岛判据、真机对照 0 页、页面顶栏毛玻璃、`fontWeight`、裸 `Card(`）；毛玻璃/`fontWeight` 当时仍成立（毛玻璃后由 `08246e26` 解决，见上一条），裸 `Card(` 更正为「真违例 0 处」（旧记 26 处 / 2 文件是 grep 把展厅豁免与注释文字数了进去）。
- **2026-10-28 复核修订**（本次）：总包数 10 → **13**（原表实为 13 行、路线图只排了 9 个）；ST1 补进流程图；S2/C2 补进波次；写作用域由 `...` 省略写法改为**可核对的真实路径**（并修掉 3 处错路径：I1 的 `transfer/camera/` 不存在、I2 少一层 `pages/`、W1 的 `TodayWidgetSupport.kt` 在根包而非 `app/`）；「当前状态」按认领区刷新（I1/T1/T2/C1/I2/S1 均已有人在跑或能力层已交付，不再标「可立即认领」）；新增 §三 agent/真机**双列门槛**；新增 §五**未覆盖清单**；「勾完即演示数据清零 / 1:1 对齐 Flutter」改为「勾完本表 ≠ 完工，还差 §五」。
- 修订依据：`2026-10-26-compose-phase3-page-ledger.md` §9.4/§9.5、`.agents/compose-phase3/claims/*`、`2026-10-27-compose-phase3-l4-checklist.md`、`2026-10-28-compose-phase35-wiring-plan.md`，以及 2026-10-28 对仓库的实测核对。