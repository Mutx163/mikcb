# 轻屿课表 Compose 迁移 · 全景直通派工大表

> **定位**：Phase 3（页面搬运）已完工，当前瓶颈是「页面还没被接上真实仓储与系统服务」。
> 本表是**接线期的派工看板**：**7 个业务域 / 13 个工作包**，每个包给「真实写作用域 + agent 可自证门槛 + 用户真机验收」。
>
> **口径（2026-10-28 复核后修订）**：**本表勾完 ≠ 全仓完工**。表外仍有能力没被任何一行覆盖（见 §五）；「演示数据清零 / 1:1 对齐 Flutter」这类话要等 §五 也清空、且用户走完真机逐页对照之后再说。
> 唯一进度真相是 `docs/plans/2026-10-26-compose-phase3-page-ledger.md` §9（进度快照）与 §9.5（接线进展），本表只是派工看板，**不替代台账**。

---

## 零、开工前 30 秒（照做，别跳）

1. **先看认领区** `.agents/compose-phase3/claims/`：**有文件的批次 = 有人在做，别碰**。
   本表「当前状态」列是 2026-10-28 的快照，认领前一律以认领区为准。
2. **只在 §二 给的写作用域里写文件**（写作 `源集: 相对路径`，源集根见 §二 表头）。
   标 **[Lead]** 的路径属 Lead 专属，泳道不得改。
3. **交付证据按 §三 的门槛走**：L0 模块单测 → L1 编译 → 需要时 L2 单测；
   **L3 出包 / L4 真机归用户**。agent 只能声明「编译通过 / JVM 单测通过」，
   **不得**声明「能装上 / 已验证」。L1/L2 一律走 `scripts/safe-gradle.ps1`，裸跑 `./gradlew` 违规。

---

## 一、派工总览看板

### 1.1 可复核的底座数字（口径写清，免得被误读）

| 说法 | 真实口径 | 出处 |
|---|---|---|
| 「78 屏」 | **索引里可进入的条目数 = 78**（此外暂不可用 3、常驻 1，合计 82，四个数字被 JVM 测试钉住）；**不是**页面文件数 | `2026-10-27-compose-phase3-l4-checklist.md` |
| 页面文件 | `composeP1/.../pages/` 下 `*Page.kt` **56** 个、`.kt` 共 **101** 个 | 实测（2026-10-28） |
| 小组件 | **10 个** `appwidget-provider`：10 份 `widget_*_info.xml` ↔ manifest 里 10 个 receiver（第 11 处 `APPWIDGET_UPDATE` 是刷新广播，不是 Provider） | `AndroidManifest.xml` |
| 还进不去的 3 条 | 二维码发送、二维码扫码（缺宿主槽位与实现）、月视图（缺壳侧月网格数据源） | l4-checklist 缺口表 |
| 相机依赖 | CameraX `1.6.1` + MLKit `barcode-scanning:17.3.0` **已进**两个 compose 变体（`0b97f20c`）——台账 §9.4「相机真依赖未加」**已过期** | `android/app/build.gradle` |

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

| 包 | 覆盖功能与页面 | 写作用域（真实路径，可直接核对） | 当前状态（2026-10-28） |
|---|---|---|---|
| **T1** | 课程操作弹层：首页点课呼出 6 个动作（编辑/删除/…）。壳 KDoc 诚实清单第 ① 条自己写明「建议单列一批」 | `composeP1: pages/course/`、`composeP1: pages/timetable/`（仅新增回调）＋ **[Lead]** 壳挂接 | **【可立即认领】**：宿主层与收口已交付（`c374ca64`/`78abfc53`），**只剩弹层渲染层** |
| **T2** | `TimetableProfilesPage`：切换活动课表、新建、重命名、删除 | `composeP1: pages/timetable/`、`main: pages/timetable/TimetableProfilesModel.kt`＋ **[Lead]** 壳路由。仓储已带 `profiles`/`activeProfileId`，**不必动 `main: app/`** | **【可立即认领·仅页内动作】** |
| **S1** | 课表显示偏好：隐藏周末、节次行高、时间列宽、长按空档加课。现状：壳用的是宿主默认值，**不是**读用户存档 | `main: app/TimetableSettingsModel.kt`（**仅追加**显示偏好键）、`composeP1: app/TimetableHost.kt`、`main: pages/settings/`、`composeP1: pages/settings/` | **【等前置收口】**：设置模型批次（`P35-settings-model`）在改同一个文件，必须**串行**。注：4 键里「长按加课」已在模型内，缺的是另 3 键；`core/TimetableSettings.kt` 只是四键子集 |
| **S2** | 设置族其余页面：`ShellPageIndex` 的 `b.*` 页面 id 共 **25** 个，已接真宿主 **4** 个（`SettingsPageBridge.SUPPORTED_PAGE_IDS`），其余仍是演示数据（其中 `b.weather`/`b.diagnostics`/`b.live` 等严格说不是设置页，归 §五 的未覆盖清单） | `main: app/SettingsActionDispatcher.kt`、`composeP1: app/SettingsHost.kt`、`main: pages/settings/`、`composeP1: pages/settings/` | **【进行中】**：认领区 `P35-settings-*` 系列在跑（第一刀 4 页 `43272737`），**别重复认领** |
| **I1**<br>*(原 B6)* | 扫码取景：相机预览槽位 + 解码。二维码**生成**已交付（`2a77c08f`）；`QrTransferScanPage` 本身是槽位参数页面（`cameraSlot: @Composable () -> Unit`） | `composeP1: pages/transfer/`、`test: pages/transfer/` ＋ **[Lead]** 壳注入 `cameraSlot`。**注意：没有 `transfer/camera/` 这个目录** | **【进行中】**：`P35-B6`（2026-10-28 13:31 开工，已落地 `QrCameraHost.kt`/`QrScanSessionCoordinator.kt`） |
| **I2** | 教务导入 WebView 桥接：网页登录、Cookie 保持、触发已有抓取适配器 | `composeP1: pages/import/warehouse/`、`main: pages/import/warehouse/`、`main: platform/` ＋ **[Lead]** 壳 | **【待接线】**：宿主已交付（`ca94d1a6`），接界面被「他人未提交改动」挡着（台账 §9.5） |
| **I3** | `IcsExportPage`：生成 `.ics` 并通过系统分享导出 | `composeP1: pages/export/`、`main: platform/`（需**新建**分享/文件适配器，如 `AndroidShareAdapter.kt`）＋ **[Lead]** 壳 Activity 注册 `FileProvider` 与分享 Intent | **【可认领·仅渲染层+适配器】**：全仓目前 `FileProvider` **0** 处、`createChooser` **0** 处；manifest 与壳 Activity 属 **[Lead]** |
| **C1** | `CloudSyncPage`、`CoupleTimetableSettingsPage`：WebDAV 备份/恢复真收发 | `main: sync/`（**已交付** `c339330d`）、`composeP1: pages/sync/`、`main: pages/sync/` ＋ **[Lead]** 壳接线 | **【等收回认领后开工】**：`pages/sync/` 被 `P3-F` 独占声明（该文件最后更新 2026-10-27 13:37，**已超 24h**，可按 §六 申请回收）。剩余=**接线到界面**，传输层不用重写 |
| **C2** | 备份还原页：SAF 选文件、导入/导出全量 JSON | `main: platform/`（SAF 适配器）、`composeP1: pages/sync/` ＋ **[Lead]** 壳 Activity 注册 `registerForActivityResult` | **【可认领·仅解析层+适配器】**：全仓仅 1 处 `ActivityResultContracts`（在 I1 新文件里），SAF 入口尚不存在 |
| **ST1** | `StatisticsSessionPage`（+ 统计族 5 页 / 10 个图表件）：换掉假数据，读真实课表 | `composeP1: pages/statistics/`、`main: pages/statistics/`（模型层**已存在**）＋ **[Lead]** 壳喂数与二级页路由 | **【可认领·仅接线】**：渲染层与模型层均已交付，缺的是数据源。<br>⚠️ **2026-10-28 定位到具体位置**（只读普查 `_CENSUS-dead-entries.md`）：壳 `ShellPageIndex.kt` 仍喂 `courses = emptyList()`（`:532` / `:545` / `:787`），`e.session` 也是 `courseNames = emptyList()`。<br>⚠️ `4ab773e0`（「统计族改读真实课表快照」）**只改了模型层**（`CourseStatisticsModel` / `StatisticsFeed`），**没动壳** ⇒ 用户打开统计看到的仍是空页。**别把该提交读成已完工。** |
| **W1** | 课表变更后广播唤醒桌面小组件与实时活动刷新 | `main: *.kt`（**根包**：`TodayWidgetSupport.kt`、`WidgetRefreshWorker.kt`、`HomeWidgetRefreshReceiver.kt`、`WidgetBindingStore.kt`、`WidgetProviderCatalog.kt`）、`main: app/`（事件源） | **【后置依赖】**：等 T1/T2 的仓储事件源稳定。注：本行只覆盖桌面小组件与刷新广播；**超级岛判据未定**（`P3-L` 仍 ⏸ 待拍板） |
| **R1** | 主 `MainActivity` 从 `FlutterActivity` 切到 Compose 入口，保留回退 | **[Lead]** `main: MainActivity.kt`、`composeUi: pages/`、`android/app/build.gradle` | **【Lead 专属】**：等 I/C/W 组收口 |
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
| **Wave 1** | I1（进行中）、T1、C1（等 `P3-F` 回收）、I3 | I1 与 I3 都要动壳 Activity 注册 → **两件壳侧改动一次报 Lead 一起做**，别各自改壳 |
| **Wave 2** | T2、S1、I2、S2（持续在跑）、C2、ST1 | S1 必须等设置模型批次收口；S1 与 S2 同泳道，别并行 |
| **Wave 3** | W1 | 依赖 Wave 1/2 的仓储事件源 |
| **Wave 4** | R1、R2 | Lead + 用户；R2 的删除动作等 Phase 5 回退窗口关闭 |

> 旧版路线图只列了 9 个包，**S2、C2 从未出现在任何波次里**——已补齐。

---

## 五、本表覆盖不到的（**别以为勾完本表就完工**）

| 缺口 | 现状 |
|---|---|
| 局域网编辑收发 | `GAP-lan` 在跑；`LanEditApiRouter` 的 B 组/`apply` 仍回 **501**（台账 §9.4 ② 自认「唯一真缺的能力」） |
| 备份里 `tasks`/`exams` 写回、多档案恢复等**仓储原子入口** | 台账 §9.4 ③（`task-14`），**表内无任何一行覆盖** |
| 网络图片加载层 | `P35-B4` 已交付 `platform/AndroidImageLoader.kt`，接线随各页做 |
| 诊断族、考试、日程、任务、冲突、天气、引导、关于·更新日志 | 页面在、真数据未接，13 行无一行覆盖 |
| 前台服务与保活 | `LanEditForegroundService`/`KeepAlive*` 等原生件在，接线未列行 |
| 通知换通道 | 接线计划排在 Phase 4，不在本表 |
| 超级岛（实时活动） | `P3-L` ⏸ 待拍板（RemoteViews vs Compose Glance），**本表无验收判据**（W1 的验收句里没有岛） |
| 真机逐页对照 / 毛玻璃 / `fontWeight` / 余 26 个裸 `Card(` | 台账 §9.4 ①⑤：**一页都没真机对照过** |
| 壳里现存的演示数据 | 示例学校、示例适配器（学校适配器页）、示例日程（日程页）、示例任务（任务页）——**没有任何一行覆盖它们**，所以现在不能说「演示数据已全部清零」 |

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

- **2026-10-28 复核修订**（本次）：总包数 10 → **13**（原表实为 13 行、路线图只排了 9 个）；ST1 补进流程图；S2/C2 补进波次；写作用域由 `...` 省略写法改为**可核对的真实路径**（并修掉 3 处错路径：I1 的 `transfer/camera/` 不存在、I2 少一层 `pages/`、W1 的 `TodayWidgetSupport.kt` 在根包而非 `app/`）；「当前状态」按认领区刷新（I1/T1/T2/C1/I2/S1 均已有人在跑或能力层已交付，不再标「可立即认领」）；新增 §三 agent/真机**双列门槛**；新增 §五**未覆盖清单**；「勾完即演示数据清零 / 1:1 对齐 Flutter」改为「勾完本表 ≠ 完工，还差 §五」。
- 修订依据：`2026-10-26-compose-phase3-page-ledger.md` §9.4/§9.5、`.agents/compose-phase3/claims/*`、`2026-10-27-compose-phase3-l4-checklist.md`、`2026-10-28-compose-phase35-wiring-plan.md`，以及 2026-10-28 对仓库的实测核对。