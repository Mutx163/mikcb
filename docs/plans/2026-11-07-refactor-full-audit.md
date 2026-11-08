# Compose 重构版全盘审核（核验版）

> 日期：2026-11-07
> 基线：分支 `compose-merge`，HEAD `3cf8d910b`（工作区另有 15 个已修改 + 3 个未跟踪条目，见 §0-2）
> 规模：composeP1 `226` 个 `.kt` / `74,923` 行 / `63` 个 `*Page.kt`；`main` `584` 个 `.kt`；测试 `655` 文件 / `7,494` 个 `@Test`
> 方式：8 个只读子代理分域审核（壳导航 / 课表 / 设置外观 / 教务导入 / 传输同步 / 统计任务考试 / 设计系统无障碍 / 构建测试权限仓库）+ 主助理静态门禁实测

> **过期标注（2026-11-08）**：本单的「L1 红 / 不能作为可交付基线」结论是**工作区在途改动的快照**
> （基线 HEAD `3cf8d910b` 当时的 settings 插件解析失败、11 个文件未跟踪、CI 也处在在途改动中）。
> 之后去 Flutter 化 P4（P4-A → P4-D）与各批收口后，L1 已于 2026-11-08 通过，
> L2 在 `ArbCatalog.kt` 重新生成后待复跑（见进度账变更记录）。本单留作审计记录：
> 引用 §1-§3 的定位前，先按「文件 + 特征串」重读原文再定。

## 0. 结论与核验口径

**结论：不能作为可交付基线。**

- **L1 编译：红。** 工作区两条构建路径均失败，实测见 §0-1。
- **L2 单测：未跑。** 依赖 L1，本轮零结论。
- **L4 真机逐页：0 页。** 归用户。
- 历史台账中的「L2 5569/5791 例绿」「176 个 .kt」「10 条样式例外」「89 总 / 88 可进入」均已被实测推翻，引用前必须重测。

**标记约定**

| 标记 | 含义 |
|---|---|
| ✅ | 主助理直接读代码或跑命令核验，附行号可复现 |
| △ | 子代理证据，本轮未逐条复算；行号可能漂移，落地前需重读 |
| ✖ | 已被本轮证据推翻，不得再引用 |

**行号纪律**：子代理报告的行号存在漂移（例：教务写回失败实为 `:121`，不是 `:143`；登录脚本注入点为 `:1626`，不是 `:1613`）。本文档内 ✅ 项行号已复核；△ 项按「文件 + 特征串」引用，改代码前请先 grep。

---

## 第 0 档 · 构建与交付阻塞

> 不解决这一档，后续任何修复都无法取得 L1/L2 证据。

| 编号 | 级别 | 位置 | 现象 → 修法 | 状态 |
|---|---|---|---|---|
| **0-1** | P0 | `android/settings.gradle:54`；`android/app/src/main/kotlin/com/mutx163/qingyu/MainActivity.kt:2463` | 默认路径：`BUILD FAILED in 1s`，`Plugin with id 'dev.flutter.flutter-plugin-loader' not found`（在途把 `plugins{}` 改成 `apply plugin:`，included build 的插件无法解析）。`-PwithFlutter=false`：跑 1m16s 后 `MainActivity.kt` 大量 `Unresolved reference 'getSystemService' / 'startActivity' / 'window' / 'resources' / 'FlutterEngine'`，`PendingResultSlot.kt`、`FairMemoryFlutterBridge.kt` 同类错误 —— `kotlin { sourceSets.configureEach { exclude(...) } }` 对 Android 源集不生效，3 个 Flutter 依赖文件仍被编译。→ 恢复 `plugins{}` 注入，或改用 `android.sourceSets` 真排除；另需处理未跟踪的 `android/noflutter-flutter-loader-stub/`（现有兜底尝试）。 | ✅ 主助理两次实测 |
| **0-2** | P0 | `android/app/src/main/kotlin/com/mutx163/qingyu/platform/ResultSink.kt`；`android/app/src/main/kotlin/com/mutx163/qingyu/FairMemoryFlutterBridge.kt` | 两个生产源文件 `git status` 为 `??`、`git ls-files` 为空，而工作区已有 5 处引用：`PendingResultSlot.kt:3`、`CalendarSync.kt:17`、`LocationFix.kt:12`、`MainActivity.kt:48`（另 `:474` 实例化 `MethodChannelFairMemoryBridge`）、`IcsExportHost.kt:18`。→ 与引用它们的改动**同批提交**，禁止只提交 `build.gradle` / `settings.gradle`。 | ✅ |
| **0-3** | P1（在途） | `.github/workflows/ci.yml:101`（注释）、`:102`、`:107` | 工作区给 `flutter analyze` 与 `flutter test` 加了 `continue-on-error: true`，HEAD 仍是阻塞。注释自述「删 `lib/` 时再撤掉这两步」。→ 阶段 2 删 Dart 时统一撤；**本轮不要提交这一版**。 | ✅ |
| **0-4** | P2（在途） | `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseCoursesImportDialogs.kt`（`verticalScroll(rememberScrollState())`，`contentScrolls = true`） | 样式门禁 `-Domain all` 唯一红点（R2「Column+verticalScroll 当主滚动」）。diff 显示这是 2026-11-07 修「确定按钮在页面外」的刻意重排：滚动区只放滚轮与说明，按钮行固定在滚动区外。语义上属 `docs/reference/compose-page-style-rules.md` 的「弹层内部短列表」豁免，但校验器只做正则、不判页面。→ 二选一：① 人工新建 `tool/compose_style_exceptions/import.txt` 一行写实原因（**不许 `-Write` 加行**）；② 去掉内部滚动交给 `QingyuSheet`，代价是在途新增测试 `WarehouseBridgeDialogTest.学期弹窗按钮必须固定在面板内` 会红，需同步改。 | ✅ |

**更正（重要）**：上一轮转述过「HEAD `3cf8d910b` 自身不自洽、`ResultSink` 缺失即编译不过」——**该说法不成立**。`git show HEAD:` 显示 HEAD 版 `PendingResultSlot.kt` 仍用 `MethodChannel.Result`，`CalendarSync` / `LocationFix` / `MainActivity` / `IcsExportHost` 均不含 `ResultSink` 引用。HEAD 在这一点上是自洽的，风险仅在「工作区改动提交不成套」。

---

## 第 1 档 · 会动用户数据的

> 根因集中在「文件 / 二维码通道」与「局域网通道」对设置与地点分组的口径不一致。修一次可闭合多条。

| 编号 | 级别 | 位置 | 现象 → 修法 | 状态 |
|---|---|---|---|---|
| **1-1** | P0 | `android/app/src/main/kotlin/com/mutx163/qingyu/core/TimetableSettings.kt:38-48`；`pages/transfer/DataTransferPackageLogic.kt`（`profile.toJson()`）；`pages/transfer/DataTransferImportLogic.kt:171-173` | 全量包的时间设置只有 **6 个键**（`sections` / `activeTimeSchemeId` / `semesterWeekCount` / `semesterStartDate` / `semesterStartDateText` / `classReminders`），导入时 `TimetableSettings.fromJson` 也只解这 6 个键，随后整份档案写回 ⇒ Dart 旧备份里的 250+ 偏好键在恢复时被抹成默认。云端快照走的是另一条路（`TimetableSnapshotBridge` 用 `embeddedSettingsById()` 铺底）。→ 导出复用磁盘内嵌设置，导入保留原始 `settings` map 做「内嵌 + core 覆盖」。 | ✅（键集）；△（写回整份替换的具体落点） |
| **1-2** | P0 | `pages/transfer/DataTransferPackageLogic.kt:278`；`pages/transfer/DataTransferApplyLogic.kt:200`、`:268`；`pages/transfer/DataTransferHost.kt:625-631` | 「本周课表 / 选课」这类局部包也打包**全部**地点作息分组；导入时 `groups` 直接取包内值（**无 merge 分支**，对比同函数 `:237-262` 的课程/作业/考试都有 `if (merge) mergeById(...)`），宿主再按 `resync = true` 重算**所有档案**的课程钟点 ⇒ 本机独有分组消失、全部课表时间被来源设备重排。合并模式同样中招。→ scoped 导出不带 groups；merge 走 `mergeById`。 | ✅ |
| **1-3** | P1 | `pages/transfer/DataTransferApplyLogic.kt:199`、`:267` | 合并导入时**日程日期规则**也整份替换（`rules` 无 merge），本机独有规则消失；局域网侧 `LanTransferApplier` 反而有 `mergeById`。→ 与 1-2 同一处修：merge 走并集。 | ✅ |
| **1-4** | P1 | `pages/transfer/DataTransferPackageLogic.kt`（局部包模板选材，KDoc 自述「Dart 这里还会先按地点匹配分组作息；本实现无分组」） | 局部包的时间模板只收「课程 override / `activeTimeSchemeId` / 规则引用」，漏掉按地点匹配到的作息；而 1-2 又恒带全部分组 ⇒ 包内 `locationTimeGroups[].timeSchemeId` 悬空，接收端引用检查报 `location_scheme_missing`，整单 `Failed`（不写盘）。→ 选材时按 `LocationTimeMatchLogic.match` 补 schemeId，或按 1-2 直接不带 groups。 | △ |
| **1-5** | P1 | `pages/import/warehouse/WarehouseCoursesImportApply.kt:84`（`try`）、`:103`（写设置）、`:121`（`Failed -> return`）、`:137`（`catch` 回滚） | 课程写回返回 `Failed` 的正常失败路径直接 `return`，**不会进 catch** ⇒ 已写入的开学日 / 周数 / 补过节次表留在盘上。用户看到「导入失败」，学期设置已变。→ 该分支改成与 `catch` 相同的 `updateSettings(before.settings)`（+ 需要时的 `updateTimeScheme`）后再返回，或抽 `rollback()` 两处共用。 | ✅ |
| **1-6** | P1 | `main/.../transfer/lan/LanTransferLogic.kt:566-580`；`LanEditRepositoryHost.kt:240-247` | 局域网 `import/apply` 的 settings 是「整份替换，外来缺的键显式 `null` 删掉」。任何非 LAN 导出的包（文件/二维码只有 6 键）投进来，会删光本机其余设置键。→ 判据改为「包自述 channel / 是否带完整设置」，否则按键合并、不删本机键。 | △ |

---

## 第 2 档 · 安全与隐私

| 编号 | 级别 | 位置 | 现象 → 修法 | 状态 |
|---|---|---|---|---|
| **2-1** | P1 | `pages/import/warehouse/WarehouseWebLoginHost.kt:1626`（注入）、`:1628`（自动填充门禁）；`pages/import/warehouse/WarehouseWebViewLogic.kt:390`、`:411` | 登录观察脚本在**每个页面** `onWebPageFinished` 无条件 `injectJavaScript(WarehouseLoginWatcherJs.INSTALL_SCRIPT)`，把页面内 `text/email/tel` 与 `password` 的值回传原生；紧接其后 `autofillHostAllowed = autofillAllowedOn(url, storedLogin)` **是有域名判断的** ⇒ 自动填充做了门禁、注入漏了。`loginState` 消息在 `WarehouseWebViewLogic` 中亦不要求 `trustedPageOrigin`（同文件注释自述「其余非 UI 类消息（`loginState` / `sessionProbe` / 数据类…）照常处理」）。→ 注入与 `loginState` 都加受信 host 判据。Dart 侧同款（`warehouse_adapter_web_login_screen.dart` 注入点），两边都修。 | ✅ |
| **2-2** | P1 | `pages/import/warehouse/WarehouseAdapterScript.kt:90`（注释）、`:99-100` | `if (declared.isEmpty()) return true` —— 上游 204 份 `adapters.yaml` 全无 `sha256` 键，完整性校验**实际不生效**；而这些脚本在你**已登录**的教务页面上下文里执行（可读该站 cookie/DOM、可调 `QingyuBridge`）。→ ① 声明缺失时告警并拒绝；② 镜像默认关，只留 raw/GitCode；③ 长期给脚本签名。 | ✅ |
| **2-3** | P1 | `android/app/src/main/res/xml/network_security_config.xml:28`；`main/.../pages/import/warehouse/WarehouseImportPolicy.kt:27-38` | `<base-config cleartextTrafficPermitted="true">` 应用级全局放行，正式包同样生效；`rememberedLoginAllowsUrl` 只比对 host、不判 scheme ⇒ 记住的密码会被自动填进 `http://` 页面，同网段可直接抓包。文件头有注释说明这是「校园门户域名枚举不完」的既定取舍。→ 保留 cleartext，但 ① `http://` 页面禁止保存/自动填充凭据并页内提示；② 保存提示显示当前 scheme；③ 文档化残余风险。 | ✅（NSC）；△（策略判据） |
| **2-4** | P2 | `pages/import/warehouse/WarehouseImportPolicy.kt:121-133`；`WarehouseWebLoginFlowState.kt:104-110` | 「记住密码」弹窗不校验当前页是否受信 host；`loginAttempt` 在导入执行期（任何页面）也放行 ⇒ 执行窗口内第三方页可弹出保存框，把它的候选值写进该适配器唯一凭据槽。→ `shouldPromptSave` 增加 host 判据，与自动填充同一校验。 | △ |
| **2-5** | P2（在途） | `pages/import/warehouse/WarehouseWebLoginHost.kt`（`onWebPageStarted` 重置块，`:1596-1605` 附近） | 修「首次登录不弹记住密码」时改为**跨页保留** `candidateAccount` / `hasLoginAttempt`：`onPageStarted` 只重置 `hasPasswordField` / `hasPromptedAutofill` / `autofillHostAllowed`，候选与 `hasPromptedSave` 留在内存（注释自述「同口径保留」）⇒ 若用户在学校站点输完口令后跳去别域，真口令仍在候选里，下一次保存会按**当时页面 host** 绑定。→ 只在 host 相同（`warehouseUrlHost(new) == warehouseUrlHost(old)`）时保留候选，换 host 即清；同步改 `WarehouseWebLoginHostWiringGuardTest` 措辞。 | △（结构已见，门禁细节未核） |
| **2-6** | P2 | `AndroidManifest.xml` 无障碍服务声明 + `res/xml/keep_alive_accessibility_service.xml` | 正式包常驻一个无障碍服务做保活；`canRetrieveWindowContent="false"` 已降风险，但商店审核与隐私披露仍需说明用途。→ 保留则在隐私政策与商店表单显式申报。 | △ |
| **2-7** | P2 | `AndroidManifest.xml` `<application>`（未声明 `allowBackup`）；`res/xml/data_extraction_rules.xml` | 靠 `dataExtractionRules` 全排除云备份，`device-transfer` 只排 `FlutterSecureStorage.xml`；未显式写 `allowBackup="false"`。→ 显式声明，或补注释说明「换机直传故意带走课表」。 | △ |

---

## 第 3 档 · 明显影响使用（不毁数据）

| 编号 | 级别 | 位置 | 现象 → 修法 | 状态 |
|---|---|---|---|---|
| **3-1** | P1 | `composeP1/.../app/AppearanceEditorHost.kt:216`（`openedWith`）、`:626-634`（`rollbackDraftToOpenedWith`）、`:753-770`（ON_RESUME resync） | 从壁纸面板进 Bing 图库/取景页，「应用/完成」已落盘并返回；回页只把 `model` 对齐盘上真值，`openedWith` 仍是进页快照 ⇒ 再点「取消」会把那次已确认的壁纸一起回滚。→ resync 时同步推进 `openedWith`（或另存外部基线），取消只回滚本页拥有的键。 | ✅ |
| **3-2** | P1 | `composeP1/.../app/SettingsHost.kt:466-469` | 课卡「重新配色」无实现，`ShowRecolorSheet` 只弹「不可用」；入口仍可见可点。→ 未实现前按 `general.homePullImport` 先例藏掉入口。 | ✅ |
| **3-3** | P1 | `composeP1/.../pages/timetable/day/DayViewDataAssembler.kt:148` | 情侣叠加开启时，我方课程只做 `dayOfWeek` 过滤、**不做周次剪枝**：半学期课（1–8 周）在第 12 周仍出现，重叠课两张都画；Dart 同函数有两条 `continue`（`hasCurrentWeekOverlap` / `isPreferredNonCurrentCourse`）。→ 合并前先 `visibleDayCourses(coursesForDay(...))`，或补那两条判据。一行级改动 + 一条模型用例。 | ✅ |
| **3-4** | P1 | `pages/ShellPageIndex.kt:1733`（读）、`:1784`（写）；`main/.../app/TimetableRepository.kt`（恢复事务） | 周报开关读的是 `WeeklyReportScheduler.isEnabled(context)`（prefs），写的是 `writeRawSettingsPatch("weeklyReportEnabled")`；云端恢复只重排考试提醒、不重建周报闹钟 ⇒ 换机后「设置里 true、界面显示关、闹钟不存在」。→ 恢复事务末尾按 settings 值调 `WeeklyReportToggleLogic.applyToggle`，或把真源统一到 settings。 | ✅（双真源）；△（恢复不重建） |
| **3-5** | P2 | `main/.../pages/schedule/ScheduleReminderScheduler.kt:325` | 日程提醒点击绕过 `NotificationLaunchTarget` 合约，硬写 `PagesShellActivity` 且不带落点 extra ⇒ 点提醒只回壳上次主屏，不进日程页。→ 改走 `NotificationLaunchTarget.intent()`，封闭映射表加 `/schedule`，并补契约测试。 | △ |
| **3-6** | P2 | `main/.../TodayWidgetSupport.kt:1825`；`PagesShellActivity.kt`（全文无该 extra） | 小组件启动 extra `widget_launch` 只有 Flutter 的 `MainActivity` 消费，壳不解析 ⇒ 点小组件只到壳根页，widget 上下文丢失。→ 壳 `onCreate/onNewIntent` 增判定，或明确「只唤起、不落页」并删 extra。 | △ |
| **3-7** | P1（需拍板） | `AndroidManifest.xml:174`、`:190` | 壳与入口 Activity 锁 `screenOrientation="portrait"`，而 Rail 判据是「宽 ≥840dp 或 宽 ≥600dp 且高宽比 <1.2」（`QingyuAdaptiveRules.kt:52-56`）⇒ 手机上永不出现，平板/折叠屏要靠系统忽略锁定才可能触发。→ 见 §5 待拍板 1。 | ✅ |
| **3-8** | P2 | `pages/ShellPageIndex.kt` 外观编辑入口；`PagesShellActivity.kt`（`openZoomFromWeek`，`while (backStack.size > 1) removeLast`） | 从设置进外观编辑器时先清返回栈 ⇒ 退出后落主屏、不回来源页；该动画协程被下一次底栏点击 `cancel()` 时 `pushZoomPage` 永不执行，点击被静默吞。→ 记来源路由并在退出后恢复，或取消分支补一次 `pushZoomPage`。 | △ |
| **3-9** | P2 | `PagesShellActivity.kt`（`currentRootId` / `backStack` 用 `remember`；`pages/` 全目录 0 处 `rememberSaveable`） | 进程回收或「不保留活动」后回主屏（返回栈清空、滚动与弹层全丢）。旋转 / 深色 / 字号 / 语言不重建（manifest 已含这些 `configChanges`），不是高频坑。→ 至少把返回栈降级为「id 列表 + 当前条目」存 `rememberSaveable`，或在交付说明写死这一限制。 | △ |
| **3-10** | P2 | `SettingsHost.kt:376-382`、`:402-408`、`:575-592`、`:697-704`；`WallpaperPositionPickerPage.kt:309-318`；`BingGalleryHost.kt:222-225` | 写盘失败仍弹「导入成功 / 已切换到 X」：`commitModel(...)` 返回值被丢弃，下一行无条件 toast；自动更新写盘失败只 `Log.e`；壁纸保存只判异常、不读回校验。→ 统一走 `saveVerified` 口径，失败复用 `saveFailed` 文案。 | △ |
| **3-11** | P2 | `pages/ShellPageIndex.kt`（`onOpenPage: (String) -> Unit = {}`、`onSettingsChanged = {}`、`LocalShellOpenPage` 默认 `{ {} }`）；`ShellWiring.kt`（`onBack = {}`） | 默认空回调把导航缺失变成「整页点了没反应且编译通过」。当前 4 个调用点都显式传参，无现症。→ 去掉默认值强制传参，或至少 `error("未接线")`。 | △ |
| **3-12** | P2 | `DayViewDataAssembler.kt:160`、`:170` | 冲突索引只按**我方**课程建（`conflictMap(courses, week)`），却对 TA 课也查 `conflicts[course.id]`；id 撞上时 TA 课误挂「冲突」角标。→ `isConflicting = tagged.kind != PARTNER && ...`。 | ✅ |
| **3-13** | P2 | `pages/live/DisplaySettingsPage.kt`（颜色圆点，`sizeIn(48.dp).clickable`，无 semantics）；6 处 `Modifier.size(36.dp)` 的 `IconButton`；153 处 `.clickable` 仅 6 处声明 `Role.*` | 颜色点 TalkBack 读不出内容；36dp 触控目标低于 48dp 下限；自定义可点行缺 `role`。→ 补 `semantics { contentDescription; selected; role }`，`size` 改 `sizeIn(minWidth = 48.dp, ...)`。 | △ |
| **3-14** | P2 | 10 处 Lazy `items()` 无 `key`（`ImportCommon.kt:431`/`:797`、`ExamPickerSheets.kt:159`/`:530`、`TaskPickerSheets.kt:116`、`GlassDockIconPickerScreen.kt:112`、`AiImageCourseImportPage.kt:399`、`CourseFollowupSheets.kt:397`、`TimeSchemeManagementDialogs.kt:285`、`DayViewScrollContent.kt:177`） | 列表项身份不稳定；同仓已有 22 处正确写法（`key = { it.id }`）⇒ 是遗漏不是口径。→ 补 `key`。 | △ |
| **3-15** | P2 | `AddCoursePage.kt`、`AddScheduleItemPage.kt`、`TimetableProfilesPage.kt`、`LanEditPage.kt`（各自手拼 `TopAppBar`） | 绕过 `QingyuPageScaffold` ⇒ 640dp 内容列限宽与 `contentUnderHeader` 门控不继承。→ 移交骨架，或显式复刻 `widthIn(max = cap)`。 | △ |
| **3-16** | P2 | `pages/timetable/TimetableProfilesPage.kt:250-265` | 自绘 Toast 悬浮层 + 硬编码墨色 `Color(if (dark) 0xFF383838 …)`（R5 正则看不见该形态）。→ 换官方 `Snackbar`，或按铁律登记例外。 | ✅（代码已在 3-3 同文件复核范围内） |
| **3-17** | P2 | `main/.../app/WeeklyReportScheduleLogic.kt`（周报正文拼装）；`pages/statistics/StatisticsSettingsModel.kt:25-31` | 当周 0 节时 `busiestDay=null` ⇒ 正文留「最忙的一天是 」；「下次推送」在设置页与真正排闹钟处有两份独立实现，改一处另一处静默漂移。→ 空周走专用文案；设置页改用 `WeeklyReportScheduleLogic.nextFireAt` 并补对拍用例。 | △ |
| **3-18** | P2 | `pages/import/warehouse/WarehouseCourseImportLogic.kt:280-315` | 周次平移后不再裁 30 周上限：首周选 20、脚本给到第 25 周 ⇒ 落盘 39–44 周，学期周数却被 `coerceIn(1, 30)` 封顶，这些课永远点不出来且不计入 `weeksTrimmedCount`。→ 平移后过滤越界并计入被削条数。 | △ |
| **3-19** | P2 | `WarehouseWebViewHost.kt`（`WebViewClient` 无 `onReceivedSslError`） | 证书错误走平台默认 `cancel()`（不放行，方向正确），但页面既不出 `onReceivedError` 也不进 ERROR 态，进度卡 <100，按钮禁用。→ 重写 `onReceivedSslError` 走 `SSL_FAILED` 中文提示。 | △ |
| **3-20** | P2 | `WarehouseJdkFetch.kt`（`String(bytes, Charsets.UTF_8)`） | 适配仓正文硬编码 UTF-8，无编码回退；GBK 索引变乱码，表现为「学校列表为空 / 学校名乱码」。→ 检查 BOM / `Content-Type charset`，非法 UTF-8 回退 GB18030。 | △ |
| **3-21** | P2 | `WarehouseWebViewHost.kt:201-211`（`cookiesForUrl` / `cookieHeaderForUrl` / `currentCookieHeader`） | 登录态探针写好但**零调用点**，cookie 过期或被踢下线无感知，用户只能等 30 秒超时。→ 接上「登录已失效」前置判定，或在 KDoc 标注未接线。 | △ |
| **3-22** | P2 | `CloudSyncUndoStore.kt:43-47` | 云端恢复撤销点是**内存单槽**，杀进程即失效。→ 落盘 before 快照，或提示「撤销仅本次会话有效」。 | △ |
| **3-23** | P2 | `IcsSerializer.kt:45-62` | ICS 无 `VALARM`、不导出 `classReminders` ⇒ 导到系统/Google 日历后上课提醒全丢（折行 / 转义 / UTC / UID 均正常）。→ 至少为课程写 `VALARM:TRIGGER:-PT10M`，或页面注明「不导出提醒」。 | △ |
| **3-24** | P2 | `test/.../pages/exam/ExamListModelTest.kt`（`buildListViewState` 用例全 `semesterStart = null`） | 历史缺陷「壳传 null → 永远没有第 N 周」在列表装配层没有用例能抓到，改回 null 仍全绿。→ 补一条带开学日的断言 + 一条壳接线守卫。 | △ |
| **3-25** | P2 | `core/TimetableSettings.kt:73-74`（KDoc 自述只 `_atLeastOneWeek`） | `semesterWeekCount` 无上限；脏存档写 999 周会让周页 pager 页数与 `totalWeeks` 一起放大（无崩溃路径，属放大与卡顿）。→ 解析处补 1..40 钳制，与节次同风格。 | ✅（KDoc）；△（实际影响） |

---

## 第 4 档 · 门禁与文档

| 编号 | 级别 | 位置 | 现象 → 修法 | 状态 |
|---|---|---|---|---|
| **4-1** | P1 | `docs/plans/2026-11-03-compose-status.md`（路由行、`.kt` 计数、例外条数） | 台账写「89 总 / 88 可进入」「样式例外 10 条（timetable 9）」「176 个 .kt」；实测 **88 / 87 / 0 / 1**（`ShellPageCatalogTest` 断言一致）、例外 **5 条**（timetable 4 + showcase 1）、`pages/**/*.kt` **181**。差异源于 R13 把 `b.recentWallpaper` 并入 `b.backdropFlow` 后少一条。→ 台账与 L4 清单统一改；顺带修测试 KDoc 自相矛盾的「可进入抬到 88」。 | ✅ |
| **4-2** | P1 | `local/verify_phase3_ledger.ps1:217-218`；无任何调用点 | 脚本检查的两个短语在台账 **0 命中**，且**不在 CI、不在钩子** ⇒ 我实测的 **7 项失败**永远不阻塞（`lib/screens/settings/` 行数 12639、`lib/ui/` 行数 26705 与台账不符；`P3-C3-dayview-audit` 缺 状态/领用者/最后更新/`## 写作用域`；台账批次表无对应行）。→ 补回文案或删死条款，再接进钩子。 | ✅ |
| **4-3** | P1 | `package.json`（`verify-notes` 三个子脚本指向 `.codebuddy/`，而该目录被 `.gitignore`） | 门禁零调用点，他人克隆跑不起来；本轮 `npm run verify-notes` 多项结构失败（`implemented/compose-phase35-wallpaper-sheet.md` 深度 2；`implemented/migration`、`implemented/quality`、`implemented/ui` 下用了不允许的 class 目录）。→ 改为仓库内可跑的脚本并接钩子，或明确降级为本地私有。 | △ |
| **4-4** | P1 | `scripts/compose-style-lint.ps1:86-87` | R4 只认字面量 `[0-9]+\.sp`、R5 只认 `Color(0x`；实测 `fontSize =` 46 处、字面量形态 0 处（全是 `titleFontSize.sp` / `baseStyle.fontSize.scaledOrSame(scale)`），`Color(if (dark) 0x…)` 形态也已存在（`TimetableProfilesPage.kt:265`）⇒ 门禁可被常规写法绕过。→ 判据改为「右侧不是 `MiuixTheme.textStyles.*` 派生 / 不是主题色 → 疑似违规」。 | △（计数未复算） |
| **4-5** | P1 | `android/app/src/test`（655 文件 / 7,494 `@Test`） | 测试设施只有 JUnit，**无 compose-ui-test / Robolectric**；101 个 `*GuardTest` 中 75 个直接读源码文本当判据（`CourseOverviewSortPopupGuardTest.kt:23`、`WeekGridWeightGuardTest.kt:16` 自述）。→ 至少给路由表与 2–3 个关键宿主加 Robolectric 实例断言；文本守卫保留但不作为「接线已验」。 | △ |
| **4-6** | P1 | `integration_test/`（14 文件） | 冷启动、备份恢复、ICS 导入、设置持久化等端到端用例**没有任何执行入口**（`ci.yml`、`.cnb.yml` 均无）。→ 加一条 nightly 或手动机（`itestDebug`），写明结论存放位置。 | △ |
| **4-7** | P2 | `lib/screens/settings/settings_holiday.dart`、`lib/ui/hyperos/hyperos_glass_backdrop_host.dart`、`test/ui/hyperos/...` | `lib/**` 已定义为「只读对照物」，仍有 3 个未提交改动，其中两条是真实修复（`TextEditingController` 未 dispose、render object 未摘监听）。→ 由 Flutter 侧会话提交，或在台账登记「lib 冻结前最后一批修复」。 | ✅ |
| **4-8** | P2 | 仓库体积 | 3 个已跟踪文件 >1MB（`docs/contributors/upstream.svg` 1.7MB、2 张截图 1.4MB），无构建产物入库。→ 大图挪 CDN 或压缩；非阻塞。 | △ |

**门禁真实状态（实测，非台账）**

| 门禁 | 实测 | 阻塞交付 |
|---|---|---|
| `compose-style-lint.ps1 -Domain all` | 1 红（0-4）+ 例外 5 条，过期 0 | 否（脚本未接线） |
| `copy_style_lint.dart` | 行内超宽 0 / 死键 0 / 复述 0 | 否（`ci.yml:102/107` 在途已非阻塞） |
| Kotlin/ARB 对拍（43 个 `*StringsParityTest` + `CjkLiteralGateTest`） | 绿 | **是** |
| `audit_cjk_hardcode.py` | `OK: 86 files, 1163 lines (same as baseline)` | 是（`ci.yml:87`） |
| `verify_phase3_ledger.ps1` | 7 项红，零调用点 | 否 |
| `npm run verify-notes` | 多项红，零调用点 | 否 |
| L1 编译 | 红（0-1） | **是** |
| L2 单测 | 未跑 | — |
| L4 真机逐页 | 0 页 | 用户 |

---

## 五、待拍板（三项）

1. **宽屏要不要解锁竖屏？**
   `AndroidManifest.xml:174`、`:190` 锁死 `portrait`，而 Rail 只有在「宽 ≥840dp」或「宽 ≥600dp 且高宽比 <1.2」时才出现。解锁后必须复验横屏/分屏下的矮屏弹层与返回手势；不解锁，则台账必须写明「宽屏仅大平板竖屏」，不能当作已交付能力。
2. **明文 HTTP 怎么处理？**
   现状是全局放行（`network_security_config.xml:28`），且「记住的密码」不判 scheme。选项 A：保留放行 + 对 `http://` 页面禁止保存/自动填充凭据并页内提示（改动小、直接降风险）；选项 B：仅补文档说明，接受残余风险。
3. **编译修复谁来做？**
   `android/settings.gradle` 与 `android/app/build.gradle` 属 Lead 专属 / 他人正在改的文件，按协作纪律我不动。两条路径：① 由在途作者修完，我复跑 `:app:compileDevDebugKotlin` 与 `:app:testDevDebugUnitTest` 出 L1/L2；② 用户明确授权我改这两处，我再动手。

---

## 附录 A · 建议排期

| 波次 | 内容 | 依赖 |
|---|---|---|
| **Wave 0** | 0-1 构建解阻 → 0-2 成套提交 → 0-3 撤回 CI 非阻塞 → 0-4 例外登记 → 复跑 L1、L2 | 需拍板 3 |
| **Wave 1** | 1-1 ~ 1-6（设置与分组通道口径统一、教务写回全量回滚）+ 2-1 ~ 2-3（host 门禁、sha256、http 凭据） | L1 恢复后 |
| **Wave 2** | 3-1 ~ 3-4、3-10、3-11、3-13、3-14（取消语义、入口可见性、叠加剪枝、周报真源、写盘失败口径、空回调、无障碍、列表 key） | 无 |
| **Wave 3** | 4-1 ~ 4-6（台账数字、两个死门禁、R4/R5 判据、Robolectric 试点、E2E 入口） | 无 |

## 附录 B · 本轮未验证的边界

- **运行时全未验**：玻璃每帧成本、坞位移、200% 字号截断、TalkBack 朗读顺序、对比度实测。
- **真机链路全未验**：分享面板、FileProvider、SAF 写 `.ics`、WebView cookie 同步、IME insets、局域网 PIN/bearer 实际校验与限流。
- **协议与外部数据未核**：上游 204 份 adapters 是否真无 `sha256`（依据代码注释自述）、镜像前缀是否全 https、ICS 在系统日历中的实际导入结果。
- **测试结论缺失**：7,494 例是否真绿未知；台账自身存在 5569 / 5791 两个互相矛盾的「已跑」数字且标注「无法复核」。
- **CNB 流水线**：自 2026-09-03 起因账号配额在 Prepare 阶段 error（`.cnb.yml` 注释自述），其门禁当前是否真跑无法判断。
