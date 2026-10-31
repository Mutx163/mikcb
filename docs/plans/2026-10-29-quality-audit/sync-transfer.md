# 云同步与备份迁移族 · 质量审核（2026-10-29，独立复核）

审核基线：HEAD `3f3b7354`（2026-10-29 20:10 提交）；审核时刻：2026-10-29 20:34（开始）。
`git status --porcelain` 里未提交的文件一律按 `git show HEAD:<路径>` 判据，差异单列在 §在途改动，不入判。

## 结论（先看这段）

**审核页面清单**

| 页面 | 文件（相对 `android/app/src/`） | commit | 在途？ |
|---|---|---|---|
| 情侣课表设置（渲染） | `composeP1/kotlin/com/mutx163/qingyu/pages/sync/CoupleTimetableSettingsPage.kt` | `02698142` | 否（工作区 = HEAD） |
| 情侣课表设置（宿主） | `composeP1/.../pages/sync/CoupleTimetableSettingsHost.kt` | `02698142` | 否 |
| 连接坚果云弹层 | `composeP1/.../pages/sync/CoupleWebdavConnectSheet.kt` | `02698142` | 否 |
| 情侣课表（控制器 / 模型 / 文案 / 端口） | `main/.../pages/sync/CoupleTimetableSettingsController.kt`、`…Model.kt`、`CoupleStrings.kt`、`CoupleStores.kt`、`CouplePartnerPackage.kt` | `02698142` | 否 |
| 情侣课表（平台实现） | `main/.../platform/CoupleConfigStoreImpl.kt`、`CouplePartnerPortImpl.kt`、`CoupleTransferAdapter.kt` | `02698142` | 否 |
| 数据备份与迁移（首页） | `composeP1/.../pages/transfer/DataTransferPage.kt` | `7c8d11b6` | 否 |
| 数据备份与迁移（宿主） | `composeP1/.../pages/transfer/DataTransferHost.kt` | `7c8d11b6` | 否 |
| 数据迁移（模型层） | `main/.../pages/transfer/DataTransfer{Model,ApplyLogic,ImportLogic,PackageLogic}.kt`、`TransferServiceMessages.kt`、`Transfer{Strings,ExtStrings}.kt` | `7c8d11b6` | 否 |
| 数据迁移（平台） | `main/.../platform/AndroidTransfer{Document,Share}Adapter.kt`、`main/.../share/TransferShareContract.kt`、`res/xml/file_paths.xml`、`AndroidManifest.xml` | `7c8d11b6` | 否 |
| 二维码两页 + 宿主 | `composeP1/.../pages/transfer/QrTransfer{Send,Scan}Page.kt`、`QrTransferHosts.kt`、`QrCameraHost.kt` | `0801f743` / `5ca632d3` / `a49930cf`（10-28） | 否 |
| 局域网编辑 / 取件码 | `composeP1/.../pages/transfer/LanEditPage.kt`、`PickupCodesPage.kt` | 建 10-27，`a49930cf`（10-28）动过 | 否 |
| 壳分派 | `main/.../pages/ShellPageIndex.kt` | `c6012a18` 等 | **是（M）** ⇒ 全部按 `git show HEAD:` 判 |

**计数：P0 3 条 / P1 3 条 / P2 7 条。**

**与既有审核文档不一致的地方：3 条**（§五）。

**二轮（2026-10-29 晚，基线 HEAD bf0e5a57）：P0 1 条已修 / 2 条按分工移交 F03；P1 3 条全修；P2 7 条全处理。逐条验真与修法见 §八。**

**一句话总评**：情侣课表这条线是本族最扎实的一处——九个动作全部有落点、文案 212 条逐字对得上、宿主把阻塞调用都丢进了 `Dispatchers.IO`。数据迁移页的导出/二维码/撤销三条回路是真的，但**导入落盘只写回了一半数据**（时间模板 / 日程规则 / 作业 / 考试全丢），这是本族唯一会在真实使用中损坏用户数据的缺陷。同目录下另外两页（局域网编辑、取件码）仍然是全空回调的死页。

---

## 逐页结论

### 1. 情侣课表设置页（`composeP1/.../pages/sync/CoupleTimetableSettingsPage.kt` + `CoupleTimetableSettingsHost.kt`）

**D1 接线真实性：通过。**
壳分派在 HEAD 是 `"f.couple" -> CoupleTimetableSettingsHost(wiring = wiring, onBack = onBack)`（`ShellPageIndex.kt:1070`），不是旧版的 `binding = null` + 空回调。九个动作逐个有落点（`CoupleTimetableSettingsHost.kt:134-175`）：

```
136|                CoupleTimetableSettingsLogic.WEBDAV_CONNECT -> showConnectSheet = true
137|                CoupleTimetableSettingsLogic.WEBDAV_PULL -> scope.launch {
138|                    val result = withContext(Dispatchers.IO) { controller.pullNow() }
...
151|                CoupleTimetableSettingsLogic.COUPLE_EXPORT -> {
152|                    controller.exportMine()?.let {
156|                CoupleTimetableSettingsLogic.COUPLE_IMPORT -> {
157|                    openDocLauncher.launch(CoupleTransferAdapter.OPEN_MIME_TYPES)
159|                CoupleTimetableSettingsLogic.COUPLE_UNLINK -> scope.launch {
165|        onShiftWeekOffset = { delta -> controller.shiftWeekOffset(delta)?.let {
170|        onPickColor = { rowIndex, hex -> controller.pickColor(rowIndex, hex)?.let {
```

导入 / 导出是真 SAF（`rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument())` / `CreateDocument(MIME_JSON)`，`:69-83`、`:105-122`）；写入落真仓储（`CouplePartnerPortImpl.importPackage` → `repository.replaceAllProfiles`，`CouplePartnerPortImpl.kt:114`）；绑定与档案一次动作一起落（同文件 `:116-131`）。

**D2 功能复刻完整度：通过（一处已文档化的差异，见缺陷 P1-3）。**
逐条对 Dart `lib/screens/couple_timetable_settings_screen.dart`：分区顺序（`:78-177`）、绑定信息卡两行（`:94-107`，含「课程数量：N 门 → 上次导入时间」这个看着别扭但两边一致的口径）、坚果云四态按钮（`:180-248`）、周偏移 ±44dp 与 ±15 边界（`CoupleTimetableSettingsModel.kt:229-237`）、三行色板 / 19 色 / 选中色补行首（`:243-265`）、忙碌时文案接 `...`（`:268`）全部对得上。没有发现 Compose 自造、Dart 不存在的交互。

**D3 文案对拍：通过。** 见 §三 的机械对拍（212/212 逐字相等）；渲染层无中文字面量（`grep -n '"[^"]*[一-龥]' pages/sync/*.kt` 命中 0 行，只有 KDoc 中文）。

**D4 分层：通过（两处死件，记 P2-4）。** 渲染层只读 `CoupleTimetableSettingsViewState` + 抛 `onAction(actionId)`，不碰存储、不弹提示；判据全在 `CoupleTimetableSettingsLogic`（474 行，JVM 可测）。

**D5 样式：通过。** `compose-style-lint.ps1 -Domain sync` → 0 违规（§三）。

**D6 测试牙齿：通过。** `CoupleTimetableSettingsControllerTest.kt` 24 例断言的是行为而不是「页面能打开」，期望值直接对 Dart 文案对象（`:141` `assertEquals(CoupleStrings.coupleWebdavNotConnectedError.zh, toast.message)`、`:162-163` 断言**没有**触达导入 + 文案是「请导入单课表备份文件」、`:202-206` 断言落盘后的 `lastPulledAtIso` 与内容哈希）。`CoupleStringsParityTest` 3 例逐字对拍 ARB。

**缺陷清单**
- **P1-3**：导出走 SAF「保存到…」，Dart 是系统分享面板（`share_plus`）。证据：`CoupleTransferAdapter.kt:19-27` KDoc + `CoupleTimetableSettingsHost.kt:42-47`；Dart 侧 `couple_timetable_settings_screen.dart` 的 `_exportForPartner` 用 `Share.shareXFiles`。**注意理由已过期**：KDoc 说「本仓没有 FileProvider 声明」，但 HEAD 的 `AndroidManifest.xml:143-151` 已注册（`7c8d11b6` 19:04 加入，比本页提交 `02698142` 19:07 早 3 分钟）。建议：现在具备条件，改回系统分享面板与 Dart 对齐；做不到就在文档里把理由改成真原因。
- **P2-3**：`DataTransferViewState` 三个字段 0 引用（不属于本页，见 §二 P2-3）。
- **P2-4**：`CoupleTimetableSettingsController.refresh()` / `isBusy()` / `sheetTexts()` 全仓 0 外部调用（grep 证据见 §三）。`refresh()` 从不被调 ⇒ 页面只在构造时读一次存储，从别处（如导入批次）改过绑定后回到本页仍是旧数据。建议：在宿主里挂 `Lifecycle.Event.ON_RESUME → controller.refresh()`（Dart 在 `initState` 之后每次动作都会 `_loadCoupleWebdavState`）。
- **P2-7**：结果提示用系统 `android.widget.Toast`（`CoupleTimetableSettingsHost.kt:76`、`:112`、`:120`…共 13 处），Dart 是应用内 `showAppToast`（自绘胶囊）。同一族里 `DataTransferHost` 自己实现了胶囊（`DataTransferHost.kt:544-583`），所以本仓内两页提示样式不一致。

### 2. 连接坚果云弹层（`composeP1/.../pages/sync/CoupleWebdavConnectSheet.kt`）

**D1：通过。** `onTest` / `onConfirm` 都接到控制器真动作（`CoupleTimetableSettingsHost.kt:185-223`），且**失败不假装成功**：`testConnection` 返回 false → 弹 `testFailed`（`:192-200`）；`connect` 返回 `ok=false` → 弹 `testFailed` 且不关弹层（`:215-221`）。

**D2：通过。** 与 `lib/widgets/couple_webdav_connect_sheet.dart` 对位：标题 / 副标题 / 账号 / 密码（`PasswordVisualTransformation`）/ 槽位 1-2 / 槽位说明 / 测试连接 + 连接并拉取，两项都填才可点（`:70` `credentialsFilled = username.trim().isNotEmpty() && password.isNotEmpty()`）。

**D3：通过。** 弹层 14 条文案全部经 `viewState.webdavSheetTexts`（`CoupleTimetableSettingsModel.kt:278-293`），零字面量。

**D4/D5/D6：通过**（无自有逻辑，无样式违规；控制器侧单测覆盖 testConnection 的三种 false 路径）。

### 3. 数据备份与迁移页（`composeP1/.../pages/transfer/DataTransferPage.kt` + `DataTransferHost.kt`）

**D1 接线真实性：四类动作全部有真落点，但导入的落点写不全（P0-1）。**

导出三条 → 拼包 → 写 `cacheDir/transfer-share` → FileProvider → 系统分享面板：

```
DataTransferHost.kt:156|            val failure = withContext(Dispatchers.IO) {
DataTransferHost.kt:157|                when (val built = DataTransferPackageLogic.build(snapshot, exportRequest(scope))) {
DataTransferHost.kt:158|                    is TransferPackageResult.Failure -> built.code
DataTransferHost.kt:159|                    is TransferPackageResult.Success -> when (
DataTransferHost.kt:160|                        val outcome = shareAdapter.share(
```

导入 → SAF `OpenDocument` → 20MB 限长读 → 解析 → 预览弹窗 → 落盘：

```
DataTransferHost.kt:197|    val importLauncher = rememberLauncherForActivityResult(
DataTransferHost.kt:198|        contract = ActivityResultContracts.OpenDocument(),
DataTransferHost.kt:204|                val result = withContext(Dispatchers.IO) { documentAdapter.readText(uri) }
DataTransferHost.kt:219|                            openImportPreview(result.text, TransferChannel.FILE)
DataTransferHost.kt:277|                            val outcome = withContext(Dispatchers.IO) { applyImport(repository, pending, mode) }
```

二维码发送 → 拼**真**传输包 + 资源上限预检 → 经壳内 `TransferShellBridge` 跳发送页（`:183-193`）；扫码 → 扫码页字节写回 `bridge.inboundBytes` → 回本页走**同一条**导入链路（`:227-239` + `ShellPageIndex.kt:1169-1179`）。撤销 → 落盘前抓仓储现场，提示尾部「撤销」整份写回（`:296-321`、`:459-477`）。

**没有空 lambda**：`DataTransferPage` 的 9 个回调全部由宿主提供实体（`:245-260`）。唯一的空落点是 `onOpenIcsExport`（`:248`）→ `g3.icsExport`，而那个页面全空 ⇒ 见 §在途改动（另一会话正在补 `IcsExportHost`）。

**D2 功能复刻完整度：有缺陷（P0-1）。** 版式与交互逐项对得上 Dart（13 项骨架、7 行概览、二维码范围 5 动作、选课弹层按科目聚合、预览弹窗三动作）。缺的是**写入范围**：

```
DataTransferHost.kt:430|        if (DataTransferApplyLogic.isFullBackupPlan(plan)) {
DataTransferHost.kt:431|            repository.replaceAllProfiles(plan.profiles, plan.activeProfileId)
DataTransferHost.kt:432|        } else {
DataTransferHost.kt:438|            repository.replaceActiveProfileContent(
DataTransferHost.kt:439|                courses = courses,
DataTransferHost.kt:440|                tasks = repository.tasks,
DataTransferHost.kt:441|                exams = repository.exams,
```

**D3 文案对拍：通过。** 渲染层零中文字面量（`grep` 只命中 KDoc）；`TransferStrings` / `TransferExtStrings` / `TransferServiceMessages` 共 212 条中的 150 条（transfer 侧）逐字等于 ARB（§三）。

**D4 分层：通过（一处死模型，记 P2-2）。** 渲染层只吃 `DataTransferViewState` + `DataTransferLogic` 纯函数；拼包 / 解析 / 差分 / 合并 / 撤销快照全在模型层。

**D5 样式：通过。** `-Domain transfer` → 0 违规；基线文件 `tool/compose_style_baseline/transfer.txt` 只有表头注释，无待还项。

**D6 测试牙齿：通过。** transfer 域 16 个测试文件 206 例，全部是模型层行为断言。`DataTransferApplyLogicTest.kt:33-46` 钉的是「全量包覆盖可用、合并明确拒绝」这条刻意差异（含机器码字面量），`DataTransferPackageLogicTest.kt` 484 行覆盖拼包/自校验/超限；`TransferStringsParityTest` 机械对拍 ARB。

**缺陷清单**
- **P0-1（最严重）**：导入不写回 `timeSchemes` / `scheduleDateRules` / `tasks` / `exams` / `scheduleItems`。
  - 导出侧**带**这些数据：`DataTransferPackageLogic.kt:263-271` `timeSchemesJson = if (isFullBackup) snapshot.timeSchemes.map { it.toJson() }`、`scheduleDateRulesJson` 同理；解析侧也**解析出来**了：`TransferImportPlan` 有 `timeSchemes` / `tasks` / `exams` / `scheduleItems` / `scheduleDateRules` 五个字段（`DataTransferImportLogic.kt:86-98`），但落盘只用了 `profiles` / `courses` / `settings` / `currentWeek`。
  - Dart 的对照物：`lib/services/unified_transfer_service.dart:663-744` 的 `_overwrite` 走 `buildBackupJson(tasks: incoming.tasks, exams: incoming.exams, scheduleItems: incoming.scheduleItems, …)` + `provider.importAppDataBackup(json)`；全量包走 `provider.importFullAppDataBackup(fullJson)`（含 `timeSchemes` / `scheduleDateRules` / `locationTimeGroups`）+ `_replaceRulesAndLocations`。
  - 后果：同一台手机「导出全部数据 → 再导入」，时间模板与日程规则蒸发；课程上的 `timeSchemeId` 指向不存在的模板。单课表包的路径里作业 / 考试被本机旧值顶掉（不是包的）。
  - 建议修法：仓储已有 `updateScheduleDateRules` / `createTimeScheme`（`TimetableRepository.kt:308`、`:341`），补一条批量入口后由宿主按 `plan` 逐块写；`tasks/exams` 对 `replaceActiveProfileContent` 直接传 `plan.tasks` / `plan.exams` 即可（该函数已接受这两个参数）。
  - 诚实说明：`docs/plans/2026-10-29-datatransfer-audit.md:248` 已把 `tasks/exams/scheduleItems/scheduleDateRules` 记成已知缺口，但**漏了 `timeSchemes`**（见 §五.2）；且「已知缺口」不改变它在 D2 上是缺陷。
- **P1-2**：全量包点「合并更改」→ 屏上「发生未知错误」。`DataTransferApplyLogic.kt:49` 返回机器码 `full_backup_merge_unsupported`，`DataTransferHost.kt:271-273` 交给 `TransferServiceMessages.localize`，该码未登记且形如内部码 ⇒ 兜底成 `quickImportUnknownError`（"发生未知错误"，`TransferServiceMessages.kt:55`、`:115`）。Dart 对全量包合并是**支持**的（`unified_transfer_service.dart:541-545`）。建议：登记一条 ARB（如「完整备份不支持合并导入，请选择覆盖」），或在预览弹窗里对全量包隐藏「合并」。
- **P2-5**：`QrCameraHost.kt:250` 写死颜色（`Color(if (dark) 0xFFB0B0B8.toInt() else 0xFF5A5A62.toInt())`）。这是 R5「不许写死 Color(0xFF…)」的精神违规，但样式守卫没抓到——因为它写成 `Color(if (…) 0xFF…` 而不是 `Color(0xFF…)`。建议改 `QingyuTheme.secondaryText(dark)`，并顺手补守卫的匹配形态。

### 4. 二维码发送 / 扫码两页 + 宿主（`QrTransfer{Send,Scan}Page.kt`、`QrTransferHosts.kt`、`QrCameraHost.kt`）

**D1 接线真实性：通过，且台账里「缺宿主槽位」的说法已经过期。**
`g3.qrSend` / `g3.qrScan` 都换成了真宿主（HEAD `ShellPageIndex.kt:1155-1179`）：

```
1155|        "g3.qrSend" -> {
1159|            val payload = transferBridge.outboundPayload ?: ByteArray(0)
1161|                if (payload.isEmpty()) null else QrTransferSendSession.prepare(payload)
1163|            QrTransferSendHost(
1169|        "g3.qrScan" -> {
1172|            QrTransferScanHost(
1174|                onImportFullBackup = { raw ->
1175|                    transferBridge.inboundBytes = raw
1176|                    onBack()
```

`QrTransferScanHost`（`QrTransferHosts.kt:133-173`）把每个识别结果喂 `QrTransferReceiveSession`，收齐后 `consumeRawPayload()` 取原始字节交回壳；`cameraSlot` 里是真 CameraX + MLKit（`QrCameraHost.kt:13-46` 导入 `ProcessCameraProvider` / `PreviewView` / `BarcodeScanning`，依赖在 `android/app/build.gradle:363-368`：camera-core/camera2/lifecycle/view 1.6.1 + `com.google.mlkit:barcode-scanning:17.3.0`）。权限拒绝走 `CameraPermissionStateMachine`，给 `PermissionHint` + 系统弹框 / 跳应用设置（`:115-150`、`:188-203`）。**结论：`QrTransferScanPage` 现在有真宿主，不再是「一张空白卡片」。**

**D2：有缺陷（P1-1）。** 发送页标题固定成「二维码面对面传输」。
**D3：通过**（两页文案全来自 `QrTransferSendModel` / `QrTransferScanModel`）。
**D4/D5/D6：通过**（`QrTransferSendModelTest` 12 例、`QrTransferScanModelTest` 16 例、`QrTransferReceiveSessionTest` 13 例、`QrTransferSendSessionTest` 12 例、`QrScanSessionCoordinatorTest` 10 例、`QrFountainLtTest` 20 例）。

**缺陷清单**
- **P1-1**：二维码发送页顶栏标题与 Dart 不一致。Compose：`QrTransferSendModel.kt:44` `val title: String get() = TransferStrings.qrTransferSectionTitle.zh`（＝「二维码面对面传输」）；Dart：`data_transfer_screen.dart:474-477` / `:490-493` 把 `l10n.qrTransferSendCurrent`（「二维码发送当前课表」）或 `l10n.qrTransferSendAll`（「二维码发送全部数据」）当 `title` 传进 `QrTransferSendScreen`（`:517`），屏幕 `:264` 直接用它当顶栏。宿主其实**算好了**这个标题（`DataTransferHost.kt:189-190` `bridge.outboundTitle = result.title`），但没人读：`grep -rn "outboundTitle" android/app/src/` 只有两行——声明 + 赋值，`QrTransferSendHost` 连 `title` 参数都没有。建议：给 `QrTransferSendHost` / `QrTransferSendModel` 加 `title` 入参，壳里读 `transferBridge.outboundTitle`。
- **P2-6**：`TransferShellBridge.outboundTitle` 是死写（同上证据）。要么接上，要么删掉。

### 5. 局域网编辑页（`composeP1/.../pages/transfer/LanEditPage.kt`）

**D1：有缺陷（P0-2）。** HEAD `ShellPageIndex.kt:1200-1206`：

```
1200|        "g3.lanEdit" -> LanEditPage(
1201|            model = LanEditModel(),
1202|            onBack = onBack,
1203|            onToggleRunning = {},
1204|            onCopyAddress = {},
1205|            onKeepAliveChange = {},
1206|        )
```

`LanEditModel()` 是**默认值**（`running = false`、`ipAddress = null`、`pin = null`、`connectedClients = 0`，`LanEditModel.kt:25-39`）⇒ 永远渲染「未开启」；三个回调全空 ⇒ 开关点了不动、复制地址是空操作、保活开关无效。入口是活的（`ShellWiring.kt:721` `"/settings/lan-edit" -> "g3.lanEdit"`），用户点得到。

**D2-D6**：无法评（页面本身是纯渲染层，判据全在空回调上）。模型层有内容（`LanEditModel`，16 例单测），所以是「模型层已备、壳没接」。
**归属说明**：这不是本批（`7c8d11b6`）引入的，页面 2026-10-27 建、`a49930cf`（10-28）动过大标题；按 rubric §0「10-28~29 动过的页面都要审」与 D1「空 lambda 一个都不许留」判 P0。建议修法：壳里按 `LanEditForegroundService`（`main/.../LanEditForegroundService.kt` 已存在）接状态与动作。

### 6. 取件码页（`composeP1/.../pages/transfer/PickupCodesPage.kt`）

**D1：有缺陷（P0-3）。** HEAD `ShellPageIndex.kt:1207-1210`：

```
1207|        "g3.pickupCodes" -> PickupCodesPage(
1208|            onBack = onBack,
1209|            onEntryClick = {},
1210|        )
```

每一行点了没反应。`installedOf` 用默认值 `{ true }`（`PickupCodesPage.kt` 签名），所以即使宿主 App 没装也一律显示成「已安装」。真能力在 `main/.../PickupCodeLauncher.kt`（已存在），未接。
**归属说明**：同 P0-2，存量死页，非本批引入。
**建议修法**：`onEntryClick` 接 `PickupCodeLauncher`（含 `PickupCodesModel.REASON_*` 六种失败码 → `reasonText`），`installedOf` 用 `PackageManager` 真探测。

---

## 二、缺陷清单（合并视图，按级别）

| # | 级别 | 页面 | 一句话 | 文件:行号 |
|---|---|---|---|---|
| P0-1 | P0 | 数据迁移 | 导入只写回档案/课表/设置，时间模板、日程规则、作业、考试、日程条目全丢（导出却带了） | `DataTransferHost.kt:430-445`；`DataTransferImportLogic.kt:86-98`（解析有）；`DataTransferPackageLogic.kt:263-271`（导出有）；Dart `unified_transfer_service.dart:663-744` |
| P0-2 | P0 | 局域网编辑 | 死页：默认模型 + 3 个空回调 | `ShellPageIndex.kt:1200-1206`（HEAD） |
| P0-3 | P0 | 取件码 | 死页：`onEntryClick = {}` + `installedOf` 恒 true | `ShellPageIndex.kt:1207-1210`（HEAD） |
| P1-1 | P1 | 二维码发送 | 顶栏标题写成「二维码面对面传输」，Dart 是「二维码发送当前课表 / 全部数据」；宿主算好的 `outboundTitle` 无人读 | `QrTransferSendModel.kt:44`；`DataTransferHost.kt:189-190`；`ShellPageIndex.kt:1163-1167` |
| P1-2 | P1 | 数据迁移 | 全量包选「合并更改」→ 屏上「发生未知错误」（机器码未登记 + 功能本身缺失） | `DataTransferApplyLogic.kt:49`；`DataTransferHost.kt:271-273`；`TransferServiceMessages.kt:115` |
| P1-3 | P1 | 情侣课表 | 导出用 SAF 保存对话框，Dart 是系统分享面板；且 KDoc 的理由（没有 FileProvider）已过期 | `CoupleTransferAdapter.kt:19-27`；`CoupleTimetableSettingsHost.kt:42-47` |
| P2-1 | P2 | 文档 | 三处「本仓没有 FileProvider」与 HEAD 不符 | `2026-10-29-compose-couple-audit.md:259`；`CoupleTransferAdapter.kt:22-27`；`CoupleTimetableSettingsHost.kt:42-47` |
| P2-2 | P2 | 数据迁移 | 预览正文有**三份**实现、只有一份在用：`TransferPreviewModel`（115 行）与 `DataTransferLogic.previewContent`（`DataTransferModel.kt:303-326`）都只被自己的测试引用；真正上屏的是 `DataTransferImportLogic.previewMessage`。三份里有格式差异（单换行连接 vs 空行分段），后来者极易改错那一份 | `TransferPreviewModel.kt:28`；`DataTransferModel.kt:303`（grep 证据见 §3.4） |
| P2-3 | P2 | 数据迁移 | `DataTransferViewState.profileShareSubject` / `exportCurrentLabel` / `importLabel` 0 引用 | `DataTransferModel.kt:357`、`:371`、`:373` |
| P2-4 | P2 | 情侣课表 | `refresh()` / `isBusy()` / `sheetTexts()` 0 外部调用；`refresh()` 从不被调 ⇒ 回前台不重读存储 | `CoupleTimetableSettingsController.kt:92`、`:99`、`:101` |
| P2-5 | P2 | 扫码 | 权限提示写死颜色，样式守卫抓不到这种形态 | `QrCameraHost.kt:250` |
| P2-6 | P2 | 二维码 | `TransferShellBridge.outboundTitle` 死写（只写不读） | `DataTransferHost.kt:190`、`:525` |
| P2-7 | P2 | 情侣课表 | 结果提示用系统 Toast，Dart 是应用内胶囊；同族另一页自建了胶囊 ⇒ 族内不一致 | `CoupleTimetableSettingsHost.kt:76`、`:112`、`:120` 等 13 处 |

---

## 三、证据（命令与真实输出）

### 3.1 文案逐字对拍（D3）：212 条 ArbText vs HEAD 的 `app_zh.arb`，0 处不符

```
$ python - <<'PY'   # 读 git show HEAD:lib/l10n/app_zh.arb，与 4 个 *Strings.kt 的 ArbText("key","值") 机械比对
--- CoupleStrings.kt: 63 ArbText call-sites
--- TransferStrings.kt: 84 ArbText call-sites
--- TransferExtStrings.kt: 52 ArbText call-sites
--- TransferServiceMessages.kt: 14 ArbText call-sites
HEAD-ARB parity: checked=212 problems=0
ARB keys total=3470
```

（工作区的 `lib/l10n/app_zh.arb` 正在被别的会话改，所以按 Lead 要求钉 HEAD 版本比对。）

### 3.2 渲染层无中文字面量（D3）

```
$ grep -n '"[^"]*[一-龥]' android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/sync/*.kt
（0 行）
$ grep -n '"[^"]*[一-龥]' android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/transfer/*.kt
DataTransferHost.kt:518: * （要读仓储）。壳原先拿 `"QingyuTimetable:<课表名>"` 当载荷，就是这一步没接的后果。
LanEditPage.kt:46: * - 顶栏：返回 + "局域网编辑"；
PickupCodesPage.kt:46: * - 顶栏：返回 + "取件码"；
QrTransferScanPage.kt:43: * - 顶栏：返回 + "扫码接收"；
```

4 处全部在 KDoc 注释里，不是字符串字面量。

### 3.3 样式守卫（D5）：两域均 0 违规，且基线无待还项

```
$ pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain sync
=== sync 域：0 处 ===
合计：0 处
$ pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain transfer
=== transfer 域：0 处 ===
合计：0 处
$ cat tool/compose_style_baseline/transfer.txt
# transfer 域的 Compose 页面样式基线（棘轮）…（仅 4 行表头，无待还项）
```

### 3.4 分层查死件（D4）

```
$ grep -rn "TransferPreviewModel" android/app/src --include=*.kt
…/pages/transfer/TransferPreviewModel.kt:28:object TransferPreviewModel {
…/test/.../transfer/TransferPreviewModelTest.kt:20/22/32/43/45/46/55/63/65 …（全是测试）
$ grep -rn "previewContent" android/app/src --include=*.kt
…/transfer/DataTransferHost.kt:91/138/265/268  （**局部变量**名，不是这个函数）
…/transfer/DataTransferModel.kt:303:    fun previewContent(      ← 定义
…/test/.../DataTransferModelTest.kt:265,286  ← 只有测试调用
…/transfer/DataTransferImportLogic.kt:239:    fun previewMessage(      ← 真正上屏的那一份
…/transfer/DataTransferHost.kt:140:  message = DataTransferImportLogic.previewMessage(
$ grep -rn "exportCurrentLabel\|importLabel\|profileShareSubject" android/app/src --include=*.kt
…/DataTransferModel.kt:357  val profileShareSubject: String
…/DataTransferModel.kt:371  val exportCurrentLabel: String get() = …
…/DataTransferModel.kt:373  val importLabel: String get() = …
（无调用方；`DataTransferPackageLogic.kt:122-143` 里同名的是**另一个对象**的私有常量）
$ grep -rn "\.refresh()\|\.isBusy()\|\.sheetTexts()" android/app/src --include=*.kt
（只有 HolidayProvider 的 refresh，与情侣控制器无关）
```

### 3.5 二维码标题（P1-1）

```
$ grep -rn "outboundTitle" android/app/src/
android/app/src/composeP1/.../pages/transfer/DataTransferHost.kt:190:  bridge.outboundTitle = result.title
android/app/src/composeP1/.../pages/transfer/DataTransferHost.kt:525:  var outboundTitle by mutableStateOf<String?>(null)
$ grep -n "title" android/app/src/main/kotlin/.../pages/transfer/QrTransferSendModel.kt
44:    val title: String get() = TransferStrings.qrTransferSectionTitle.zh
$ sed -n '474,493p' lib/screens/data_transfer_screen.dart
474|      await _openQrSender(
475|        Uint8List.fromList(utf8.encode(content)),
476|        l10n.qrTransferSendCurrent,
477|      );
490|    await _openQrSender(
491|      Uint8List.fromList(utf8.encode(content)),
492|      l10n.qrTransferSendAll,
493|    );
```

### 3.6 导入写入范围（P0-1）

```
$ sed -n '429,445p' android/app/src/composeP1/.../pages/transfer/DataTransferHost.kt
429|    return runCatching {
430|        if (DataTransferApplyLogic.isFullBackupPlan(plan)) {
431|            repository.replaceAllProfiles(plan.profiles, plan.activeProfileId)
432|        } else {
433|            val courses = if (mode == TransferApplyMode.MERGE) {
434|                DataTransferApplyLogic.mergeCourses(before.courses, plan.courses)
435|            } else {
436|                plan.courses
437|            }
438|            repository.replaceActiveProfileContent(
439|                courses = courses,
440|                tasks = repository.tasks,
441|                exams = repository.exams,
442|            )
$ grep -n "fun replaceAllProfiles" -A 8 android/app/src/main/.../app/TimetableRepository.kt
236|    fun replaceAllProfiles(profiles: List<TimetableProfile>, activeProfileId: String?) {
237|        // 先落盘：失败则内存与监听者都不动。
238|        store.saveProfiles(profiles)
239|        store.saveActiveProfileId(activeProfileId)
（不含 timeSchemes / scheduleDateRules / locationTimeGroups）
$ grep -n "timeSchemesJson\|scheduleDateRulesJson" android/app/src/main/.../transfer/DataTransferPackageLogic.kt
263|            timeSchemesJson = if (isFullBackup) {
264|                snapshot.timeSchemes.map { it.toJson() }
268|            scheduleDateRulesJson = if (isFullBackup) {
269|                snapshot.scheduleDateRules.map { it.toJson() }
```

### 3.7 死页（P0-2 / P0-3）

```
$ git show HEAD:android/app/src/main/kotlin/.../pages/ShellPageIndex.kt | sed -n '1200,1210p'
1200|        "g3.lanEdit" -> LanEditPage(
1201|            model = LanEditModel(),
1202|            onBack = onBack,
1203|            onToggleRunning = {},
1204|            onCopyAddress = {},
1205|            onKeepAliveChange = {},
1206|        )
1207|        "g3.pickupCodes" -> PickupCodesPage(
1208|            onBack = onBack,
1209|            onEntryClick = {},
1210|        )
$ grep -rn "g3.lanEdit\|g3.pickupCodes" android/app/src --include=*.kt
.../main/.../pages/ShellWiring.kt:721:    "/settings/lan-edit" -> "g3.lanEdit"        ← 入口是活的
.../test/.../guide/MoreFeaturesNavigationGuardTest.kt:112:  "pickupCode" to "g3.pickupCodes"
```

### 3.8 二维码宿主已闭合（重点 5 的核实）

```
$ grep -n "QrTransferSendHost\|QrTransferScanHost\|inboundBytes" <HEAD 版 ShellPageIndex.kt>
1155:        "g3.qrSend" -> {
1159|            val payload = transferBridge.outboundPayload ?: ByteArray(0)
1169:        "g3.qrScan" -> {
1172|            QrTransferScanHost(
1175|                    transferBridge.inboundBytes = raw
$ grep -n "camera\|mlkit\|barcode" android/app/build.gradle
363|    def cameraxVersion = '1.6.1'
364|    implementation "androidx.camera:camera-core:$cameraxVersion"
365|    implementation "androidx.camera:camera-camera2:$cameraxVersion"
366|    implementation "androidx.camera:camera-lifecycle:$cameraxVersion"
367|    implementation "androidx.camera:camera-view:$cameraxVersion"
368|    implementation 'com.google.mlkit:barcode-scanning:17.3.0'
```

### 3.9 测试清单（D6）

```
$ for f in .../test/.../pages/transfer/*.kt .../test/.../pages/sync/*.kt; do echo "$f: $(grep -c '@Test' $f)"; done
transfer: DataTransferApplyLogic 11 / DataTransferImportLogic 12 / DataTransferModel 24 /
          DataTransferPackageLogic 10 / DataTransferSelectionLogic 13 / LanEditModel 16 /
          PickupCodesModel 16 / QrFountainLt 20 / QrScanSessionCoordinator 10 /
          QrTransferReceiveSession 13 / QrTransferScanModel 16 / QrTransferSendModel 12 /
          QrTransferSendSession 12 / TransferPreviewModel 11 / TransferServiceMessages 8 /
          TransferStringsParity 2            → 206 例
sync:     CoupleTimetableSettingsController 24 / CoupleTimetableSettingsModel 21 /
          CouplePartnerPackage 13 / CoupleBindingCodec 7 / CoupleStringsParity 3 /
          CloudSync* 46 / BackupFile* 52 / SyncResultToasts 16 …   → 213 例
```

---

## 四、在途改动（他人，不入判）

按 Lead 的基线规则，下列文件在 `git status` 里未提交，**全部未参与本报告的判定**；其中 `ShellPageIndex.kt` 的关系最直接，单列说明。

| 文件 | 状态 | 与本族的关系 |
|---|---|---|
| `android/app/src/main/kotlin/.../pages/ShellPageIndex.kt` | `M`（+47 / −70） | 本族所有路由都在这个文件里。已用 `git diff HEAD -- <file>` 逐行确认：差异全部落在 `d1.*` / `d2.*` 区域（课程编辑、任务列表），**`f.couple`（1070）、`g3.dataTransfer`（1147）、`g3.qrSend`（1155）、`g3.qrScan`（1169）四段一字未动**，所以本报告引用的行号与内容对 HEAD 与工作区同时成立 |
| `lib/l10n/app_zh.arb` 等 12 个 l10n 文件 | `M` | 我按 HEAD 版本做的逐字对拍（§3.1）。若这些改动落库，需要复跑对拍 |
| `android/app/src/composeP1/.../app/IcsExportHost.kt` | `??` 新文件 | 另一会话正在给 `g3.icsExport` 补真宿主。**因此 `g3.icsExport` 的 11 个空回调不计入本报告**（HEAD 里它确实是全空，`ShellPageIndex.kt:1180-1199`） |
| `android/app/src/main/kotlin/.../pages/export/IcsEventCollection.kt` / `test/.../IcsEventCollectionTest.kt` | `??` | 同上，ICS 导出族 |
| `settings/**`、`task/**`、`course/**`、`ShellWiring.kt`、`PagesShellActivity.kt`、`lib/widgets/timetable/month_view/**` 等 | `M` / `MM` / `??` | 与本族无关 |

---

## 五、与既有审核文档不一致的地方（3 条）

1. **`docs/plans/2026-10-29-compose-couple-audit.md:259`**：「本仓 `AndroidManifest.xml` 没有 `FileProvider` 声明，分享文件必然在 `getUriForFile` 那一步失败」。
   **复核不成立**：HEAD 的 `AndroidManifest.xml:143-151` 里已经有 `<provider android:name="androidx.core.content.FileProvider" android:authorities="${applicationId}.fileprovider">` + `@xml/file_paths`，是 `7c8d11b6`（19:04）加的，比该文档所属提交 `02698142`（19:07）早 3 分钟。同一句错误还写进了产品 KDoc：`CoupleTransferAdapter.kt:22-27`、`CoupleTimetableSettingsHost.kt:42-47`。⇒ P2-1 + 支撑 P1-3。

2. **`docs/plans/2026-10-29-datatransfer-audit.md:248`**：「`tasks` / `exams` / `scheduleItems` / `scheduleDateRules` 导入不写回」。
   **复核：属实但漏项**——`timeSchemes`（时间模板）同样不写回，而且导出侧确实带上了它（`DataTransferPackageLogic.kt:263-266`）。这是本族最影响可用性的那一条，却不在文档的缺口清单里。⇒ 支撑 P0-1。

3. **`.agents/compose-phase3/claims/RECON-L4.md:75-76`** 与 **`docs/plans/2026-10-26-compose-phase3-page-ledger.md:658`**（`ShellBlockReason`：缺整页渲染层 4 / **缺宿主槽位 2** / 缺依赖 0）：「`QrTransferScanPage(cameraSlot)` 是无默认值的必传参数，全仓无调用方」「全仓无 CameraX/ZXing/MLKit」。
   **复核不成立**：`QrTransferHosts.kt:133-173` 是 `QrTransferScanHost`，`ShellPageIndex.kt:1169-1179` 已挂上；CameraX 1.6.1 四件 + `com.google.mlkit:barcode-scanning:17.3.0` 在 `android/app/build.gradle:363-368`；`QrCameraHost.kt:13-46` 真实使用 `ProcessCameraProvider` / `PreviewView` / `BarcodeScanning`。「缺宿主槽位 2」应降为 0。

（另：`docs/plans/2026-10-29-datatransfer-audit.md:255` 说「`g3.icsExport` 仍然全是空回调」——复核**属实**，但另一会话正在补 `IcsExportHost.kt`，所以只记在 §四，不算文档失真。）

---

## 六、我没能验的

1. **真机一条都没验**。本报告所有「能用」判断都止于「代码路径闭合」。具体未验：系统分享面板真的弹出、接收方能打开 `.mikcb`、SAF 选文件/存文件真的写进去、CameraX 预览在真机上真的出画面、WebDAV 真的能连坚果云（我按纪律**没有连任何网络**）。
2. **导入后课表是否错乱**（P0-1 的可见后果）。我能证明「`timeSchemes` 没写回」，但「课程上的 `timeSchemeId` 悬空后周视图渲染成什么样」需要跑起来看——我不许跑 Gradle/真机，也不许改代码造夹具。这一条我按最坏情况判了 P0，若实际渲染有兜底（回落默认作息）可降为 P1。
3. **`CoupleTimetableSettingsHost` 的 SAF 两段式导出在真机上的时序**：`pendingExport` 只经一格 `mutableStateOf` 在「点击」与「回调」之间传正文，`exportSink` 里 `saveDocLauncher.launch(...)` 后直接 `return true`（`:89-93`）。进程被系统在选文件对话框期间杀掉会丢这次导出——这是设计取舍，不是缺陷，但我没有在真机上制造这个场景。
4. **`.agents/compose-phase3/claims/C1.md`、`C2.md`、`P3-F.md`** 我读了 P3-F，C1/C2 只按任务要求当线索看过标题与目录，没有逐条复核它们对模型层的自述（本次证据一律回源码取）。
5. **L0/L1/L2 一次都没跑**（硬约束）。所以「代码能编译」「206+213 例单测绿」都是**别人文档里的数字**，本报告不引用它们作为结论依据；测试的「有牙」是我**读断言**读出来的（§3.9）。
6. `settings` 只带 5 个键、`locationTimeGroups` 恒空这两条（datatransfer 审核文档 §10/§11）我**复核属实**（`DataTransferPackageLogic.kt:274` `locationTimeGroupsJson = emptyList()`），但它们是编制层缺口，已超出本页范围，未展开。

---

## 七、审核方法

**读了什么（文件 / 行数）**

- 判据：`docs/plans/2026-10-29-quality-audit/_RUBRIC.md`（70 行，全文）。
- 渲染层 6 个文件 1 361 行：`CoupleTimetableSettingsPage.kt`(502)、`CoupleTimetableSettingsHost.kt`(226)、`CoupleWebdavConnectSheet.kt`(204)、`DataTransferPage.kt`(496)、`DataTransferHost.kt`(586)、`QrTransferScanPage.kt`(219)、`QrTransferHosts.kt`(173)。
- 模型层 8 个文件约 1 900 行：`CoupleTimetableSettingsModel.kt`(474)、`CoupleTimetableSettingsController.kt`(444)、`CoupleStrings.kt`(206)、`DataTransferModel.kt`(374)、`DataTransferApplyLogic.kt`(127)、`TransferPreviewModel.kt`(115)、`TransferServiceMessages.kt`(126)、`QrTransferSendModel.kt`/`QrTransferScanModel.kt`（节选）。
- 平台层 5 个文件：`CouplePartnerPortImpl.kt`(179)、`CoupleConfigStoreImpl.kt`(97)、`CoupleTransferAdapter.kt`(112)、`AndroidTransferShareAdapter.kt`(节选)、`AndroidManifest.xml`(provider 段)、`res/xml/file_paths.xml`(全文)、`QrCameraHost.kt`(400，节选权限段)。
- 壳分派：`ShellPageIndex.kt`（HEAD 版，997-1210 逐段读）。
- Dart 对照物：`lib/screens/couple_timetable_settings_screen.dart`(777，读 55-274)、`lib/screens/data_transfer_screen.dart`(838，读 53-227 / 440-549)、`lib/services/unified_transfer_service.dart`(1129，读 485-574 / 663-800)。
- 既有文档（只作线索）：`2026-10-29-compose-couple-audit.md`(274)、`2026-10-29-datatransfer-audit.md`(276)、`.agents/compose-phase3/claims/P3-F.md`、`RECON-L4.md`、`2026-10-26-compose-phase3-page-ledger.md`(节选)。
- ARB：`git show HEAD:lib/l10n/app_zh.arb`（3470 键）。

**跑了什么（全部只读）**

1. `git status --porcelain` / `git rev-parse HEAD` / `git log -1 --date=iso`：定基线（`3f3b7354`）与在途清单。
2. `git show --stat 7c8d11b6 02698142 c6012a18`：定位三个提交的真实文件与行数（23 / 15 / 1 个文件）。
3. `git log --since="2026-10-28 00:00" --name-only -- pages/sync/ pages/transfer/`：确认二维码两页是 10-28 的 `0801f743`/`5ca632d3` 改动，属审核范围。
4. `git diff HEAD -- ShellPageIndex.kt`：确认在途差异不落在本族的四段路由上。
5. `pwsh -NoProfile -File scripts/compose-style-lint.ps1 -Domain sync|transfer`：0 / 0。
6. `grep -n '"[^"]*[一-龥]'`、`grep -rn <符号>` 共 20 余次：中文硬编码、死件、落点逐个核。
7. Python 脚本（`python -` 走 stdin，不落盘）机械对拍 212 条 `ArbText` 与 HEAD 的 ARB。

**没跑什么（按硬约束）**：Gradle（L1/L2）、`scripts/test-kotlin-module.ps1`（L0）、任何网络请求、任何真机/模拟器操作、任何产品代码或 `.arb` 的写入。本报告是本次审核**唯一**写入的文件。

---

## 八、二轮：验真 + 修复（2026-10-29 晚，基线 HEAD `bf0e5a57`）

> 触发：Lead 派 task-8「进入修复阶段」，并中途收窄分工——`g3.lanEdit` / `g3.pickupCodes` 归 F03 批次（另一泳道），本报告只做「导入丢数据 + 其余 P1/P2」。
> 工作树状态：本族（`pages/{sync,transfer}`、`main/platform/**`、本族 strings）在开工时**干净**；同一目录下另有 F03 泳道的未跟踪文件（`LanEditHost.kt` / `PickupCodesHost.kt` / `PickupCodeLaunchLogic.kt` 等）与 `PickupCodesModel.kt` 的改动，**一律未碰**。

### 8.1 逐条验真

| # | 原结论 | 状态 | 复核实证 |
|---|---|---|---|
| P0-1 | 导入丢 5 类数据 | **仍存在 → 已修（本轮）** | `DataTransferHost.applyImport` 原文仍是 `tasks = repository.tasks` / `exams = repository.exams`，全量包只 `replaceAllProfiles`。Dart 侧 `unified_transfer_service.dart:663-744` 把 tasks/exams/scheduleItems 全写回 |
| P0-2 | `g3.lanEdit` 死页 | **仍存在 → 移交 F03** | HEAD `ShellPageIndex.kt:1218-1224` 仍是 `LanEditModel()` + 三个空 lambda；按 Lead 分工不修（另一泳道已在写 `LanEditHost.kt`） |
| P0-3 | `g3.pickupCodes` 死页 | **仍存在 → 移交 F03** | HEAD `ShellPageIndex.kt:1225-1228` 仍是 `onEntryClick = {}`；同上 |
| P1-1 | 二维码发送页标题写死 | **仍存在 → 已修（页面侧）** | `QrTransferSendModel.kt:44` 仍是 `TransferStrings.qrTransferSectionTitle.zh`；`outboundTitle` 仍只写不读（2 处） |
| P1-2 | 全量包「合并」弹未知错误 | **仍存在 → 已修** | `DataTransferApplyLogic.kt:49` + `DataTransferHost.kt:271-273` 未变 |
| P1-3 | 情侣导出走 SAF 而非分享面板 | **仍存在 → 已修** | `CoupleTimetableSettingsHost.kt` 原文件只有 SAF 两段式；manifest 的 FileProvider 确实已注册（`grep -c FileProvider` = 2） |
| P2-1 | 三处「没有 FileProvider」 | **仍存在 → 已修（3 处就地改正）** | 见 §8.5 |
| P2-2 | 预览正文三份实现 | **仍存在 → 已修** | `grep -rn TransferPreviewModel` 仍只有定义 + 自己的测试 |
| P2-3 | viewState 三个死字段 | **仍存在 → 已修** | `grep` 仍只有三行定义 |
| P2-4 | 控制器三个方法 0 引用 | **仍存在 → 已修** | `grep -rn "\.refresh()\|\.isBusy()\|\.sheetTexts()"` 命中 0 处调用 |
| P2-5 | `QrCameraHost` 写死颜色 | **仍存在 → 已修** | `QrCameraHost.kt:250` 原文 `Color(if (dark) 0xFFB0B0B8.toInt() else 0xFF5A5A62.toInt())` |
| P2-6 | `outboundTitle` 死写 | **仍存在 → 已修一半** | 页面侧已接好（`QrTransferSendHost(title=)`），差壳里传一行 ⇒ §8.4 |
| P2-7 | 情侣页用系统 Toast | **仍存在 → 已修** | 原文 13 处 `Toast.makeText` |

**误判：0 条。** 但有一处**二审补正**：原报告 P0-1 里把「作业 / 考试」当成与单课表包同一路径处理；实际全量包的 `tasks/exams/scheduleItems` 是**装在档案里**（`DataTransferPackageLogic.kt:256-262` 对全量包把顶层写成空），所以修复要分两条路径写——原结论没错，只是描述不够精确。

### 8.2 修了什么（P0-1，核心）

**新增模型层纯函数 `DataTransferApplyLogic.planWrites()`**：一次算出「这次导入要写哪些块」，宿主只负责照着写。这样「写什么」变成可测数据，而不是散在宿主里的几行调用。

```kotlin
data class TransferApplyWrites(
    val isFullBackup: Boolean,
    val profiles: List<TimetableProfile> = emptyList(),   // 全量包走这条
    val activeProfileId: String? = null,
    val courses: List<Course> = emptyList(),
    val tasks: List<CourseTask> = emptyList(),            // ← 原来被丢掉
    val exams: List<Exam> = emptyList(),                  // ← 原来被丢掉
    val scheduleItems: List<ScheduleItem> = emptyList(),  // ← 原来被丢掉
    val settings: TimetableSettings? = null,
    val currentWeek: Int? = null,
    val timeSchemes: List<TimeScheme> = emptyList(),      // ← 原来被丢掉
    val scheduleDateRules: List<ScheduleDateRule> = emptyList(), // ← 原来被丢掉
)
```

宿主侧（`DataTransferHost.applyImport`）：

1. `reconcileTimeSchemes(repository, plan.timeSchemes)` —— 包里模板 id 本机不存在时新建一套，得到「包 id → 本机 id」映射；存在则按 `updateTimeScheme` 整份更新（id 不变，引用不用改）；更新被仓储拒就保留本机那套、不动映射（宁可回落默认作息，也不塞坏模板）。
2. `planWrites(plan, mode, current, schemeIdMap)` —— 合并模式对 courses/tasks/exams 都走「同 id 更新、新 id 追加、缺的不删」；引用按映射改写（`Course.timeSchemeIdOverride`、`TimetableSettings.activeTimeSchemeId`、档案级同样处理）。
3. 落盘：全量包 `replaceAllProfiles` + `updateSettings`；单课表包 `replaceActiveProfileContent` → `scheduleItems` → `updateSettings` → `setCurrentWeek` → `persistActiveProfileState()`（日程条目的 setter 只改内存，落盘在最后这步）。
4. 日程规则非空才 `updateScheduleDateRules`（包缺该键时不清空用户规则）。
5. 撤销快照同步扩到 `scheduleItems` + `scheduleDateRules`，撤销能整份还原；时间模板刻意不进撤销（删模板要走「是否被引用」判据，半还原更糟），已在 KDoc 写明。

**顺带修掉的真 bug（差点造成编译红）**：清理死代码时我一度把 `DataTransferLogic.diffSummary` / `diffSummaryLine` 一并删了，`grep` 复查发现 **`DataTransferImportLogic.previewMessage` 正在用它们**（预览弹窗正文靠它拼）——已恢复，并在函数 KDoc 与测试里写明「这两个是在用的，别删」。

### 8.3 其余修复

| # | 修法 | 文件 |
|---|---|---|
| P1-1 + P2-6 | 页面加 `title` 入参（默认值 = 旧行为，保证壳不改也能编），宿主 `QrTransferSendHost(title=)` 透传；壳里传 `bridge.outboundTitle` 即对齐 Dart | `QrTransferSendPage.kt`、`QrTransferHosts.kt` |
| P1-2 | 全量包**不再提供**「合并更改」（`previewActions(canMerge)`），用户不可能点到必然失败的按钮；`rejectionCode` 保留作防御 | `DataTransferModel.kt`、`DataTransferPage.kt`、`DataTransferHost.kt` |
| P1-3 | 导出改为**分享面板优先**（`AndroidTransferShareAdapter`，与 Dart `share_plus` 同口径），失败才退回 SAF「保存到…」；`CoupleTransferAdapter` 的过期 KDoc 一并改写 | `CoupleTimetableSettingsHost.kt`、`CoupleTransferAdapter.kt` |
| P2-2 | 删 `TransferPreviewModel.kt`（115 行）+ 其测试；删只被它用的 `DataTransferLogic.previewContent` 与其 3 个用例（**保留在用的** `diffSummaryLine` / `diffSummary` 及其用例） | 见 §8.6 |
| P2-3 | 删 `DataTransferViewState.profileShareSubject` / `exportCurrentLabel` / `importLabel` | `DataTransferModel.kt` |
| P2-4 | `refresh()` 接到 `Lifecycle.Event.ON_RESUME`（回前台重读绑定与坚果云配置）；删 `isBusy()` / `sheetTexts()`（`viewState` 已带文案，重复口径） | `CoupleTimetableSettingsHost.kt`、`CoupleTimetableSettingsController.kt` |
| P2-5 | `QingyuTheme.secondaryText(dark)` 替掉写死的两张灰 | `QrCameraHost.kt` |
| P2-7 | 抽出共享件 `AppToastCapsule`（数据迁移页原本自绘的那颗胶囊），情侣页 13 处系统 Toast 全部换成它 | 新增 `AppToastCapsule.kt`；`DataTransferHost.kt` 改为委托；`CoupleTimetableSettingsHost.kt` |

### 8.4 壳接线请求（`ShellPageIndex.kt`，本批不许改）

**唯一必须改的一处**：`g3.qrSend` 把标题传下去（HEAD `ShellPageIndex.kt:1191-1204`）。

```kotlin
        "g3.qrSend" -> {
            val payload = transferBridge.outboundPayload ?: ByteArray(0)
            val session = remember(payload) {
                if (payload.isEmpty()) null else QrTransferSendSession.prepare(payload)
            }
            QrTransferSendHost(
                session = session,
                onBack = onBack,
                onStop = onBack,
                // ← 新增这一行（DataTransferHost 在跳转前已经写好 outboundTitle）
                title = transferBridge.outboundTitle,
            )
        }
```

接上之后：从「二维码发送当前课表」进来顶栏显示「二维码发送当前课表」，从「二维码发送全部数据」进来显示「二维码发送全部数据」；不接则两处都显示分组标题「二维码面对面传输」（旧行为，不会崩）。

**不需要壳改的**：`DataTransferHost` / `CoupleTimetableSettingsHost` 的签名都没变；`g3.lanEdit` / `g3.pickupCodes` 归 F03，本报告不提供它们的接线请求。

### 8.5 ARB 新增请求

**本批不需要新 ARB 键**（全部复用已有键：`coupleTimetableShareSubject` 早在 `app_zh.arb` 里，本轮只是把它加进 `CoupleStrings` 的清单参与逐字对拍）。

若将来想**保留**「合并」入口并给出正确答案（而不是像现在这样直接不显示），需要新增 1 条：

| 键名 | 中文值 | 用在哪 |
|---|---|---|
| `transferFullBackupMergeUnsupported` | 完整备份不支持合并导入，请选择覆盖当前课表 | `DataTransferApplyLogic.ERROR_FULL_BACKUP_MERGE_UNSUPPORTED` 的本地化（`TransferServiceMessages` 登记表） |

同时需要六份 ARB 同步 + `gen-l10n` 重新生成。**在那之前**，全量包的预览弹窗只有「取消 / 覆盖当前课表」两个动作，不会再出现「发生未知错误」。

### 8.6 改动文件清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `main/.../pages/transfer/DataTransferApplyLogic.kt` | 改 | `planWrites` / `TransferApplyWrites` / `mergeById` / 引用改写 / 撤销快照扩字段 |
| `main/.../pages/transfer/DataTransferModel.kt` | 改 | `previewActions(canMerge)`；删 3 个死字段与死 `previewContent`；保留在用的 `diffSummary*` |
| `main/.../pages/transfer/TransferPreviewModel.kt` | **删** | 死代码（只被自己的测试引用） |
| `composeP1/.../pages/transfer/DataTransferHost.kt` | 改 | `applyImport` 重写 + `reconcileTimeSchemes` + 撤销扩字段 + 透传 `canMerge` |
| `composeP1/.../pages/transfer/DataTransferPage.kt` | 改 | `TransferPreviewDialog(canMerge = true)` |
| `composeP1/.../pages/transfer/AppToastCapsule.kt` | **新增** | 共享提示胶囊（Dart `showAppToast` 对位件） |
| `composeP1/.../pages/transfer/QrTransferSendPage.kt` | 改 | `title` 入参 → 顶栏 |
| `composeP1/.../pages/transfer/QrTransferHosts.kt` | 改 | `QrTransferSendHost(title=)` 透传 |
| `composeP1/.../pages/transfer/QrCameraHost.kt` | 改 | 写死颜色 → 主题色 |
| `composeP1/.../pages/sync/CoupleTimetableSettingsHost.kt` | 改 | 分享面板优先 + 胶囊提示 + ON_RESUME 刷新 + KDoc 改正 |
| `main/.../pages/sync/CoupleTimetableSettingsController.kt` | 改 | 删 `isBusy` / `sheetTexts`；`refresh()` KDoc 写清调用点 |
| `main/.../pages/sync/CoupleStrings.kt` | 改 | 增 `coupleTimetableShareSubject`（ARB 已有键，参与逐字对拍） |
| `main/.../platform/CoupleTransferAdapter.kt` | 改 | KDoc 改正（FileProvider 已注册；SAF 只剩导入 + 导出兜底） |
| `test/.../pages/transfer/DataTransferRoundTripTest.kt` | **新增** | 7 例，见 §8.7 |
| `test/.../pages/transfer/DataTransferModelTest.kt` | 改 | 删 3 个死实现的用例；补回 `diffSummary*` 用例；新增「全量包不给合并动作」 |
| `test/.../pages/transfer/TransferPreviewModelTest.kt` | **删** | 随死代码一起删 |
| `docs/plans/2026-10-29-compose-couple-audit.md` | 改 | §7.6 第 1 条：FileProvider 理由已过期，标注二轮已修 |
| `docs/plans/2026-10-29-datatransfer-audit.md` | 改 | §5：缺口清单补 `timeSchemes`，标注二轮已修 + 修法 |
| `.agents/compose-phase3/claims/RECON-L4.md` | 改 | 相机 / 二维码两行标注已过期（CameraX + 真宿主已到位） |

**没有碰**：`ShellPageIndex.kt`、`ShellWiring.kt`、`ShellPageCatalog.kt`、`build.gradle`、`AndroidManifest.xml`、`theme/`、壳 Activity、`LanEditPage.kt` / `PickupCodesPage.kt`（F03）、`PickupCodesModel.kt`（F03 正在改）、`course/**`、`guide/**`、`settings/**`、`PerfProbe.kt`（他人未提交）。

### 8.7 新测试的断言（`DataTransferRoundTripTest`，7 例）

链路：`TimetableSnapshot` →`DataTransferPackageLogic.build`→ 包 JSON →`DataTransferImportLogic.parse`→ `TransferImportPlan` →`DataTransferApplyLogic.planWrites`→ 要写的内容。

| 用例 | 钉住的断言 |
|---|---|
| 单个课表包 导出再导入 作业与考试都还在 | `writes.tasks == [task-1]`、标题逐字 `作业-task-1`、`courseId` 不丢；`writes.exams == [exam-1]`、考试时间逐字 |
| 单个课表包 导出再导入 日程条目与时间模板都还在 | `writes.scheduleItems == [item-1]`、`writes.timeSchemes == [ts1]` 且节次 3 条、`writes.scheduleDateRules == [rule-1]` 且规则绑的模板 id 不变 |
| 单个课表包 导出再导入 课表 设置与当前周都在 | `courses == [c1]`、`currentWeek == 3`、`settings.activeTimeSchemeId == "ts1"`、`isFullBackup == false` |
| 全量包 导出再导入 档案里的作业考试日程都还在 | 全量包走 `profiles` 分支：档案内 tasks/exams/scheduleItems/courses 全在，`activeProfileId == p1`，模板与规则也在 |
| 合并模式 本机作业不丢 包里的作业也进来 | 合并后 `tasks == [task-local, task-1]`、`exams` 同理、`courses == [c9, c1]`（同 id 更新 / 新 id 追加 / 缺的不删） |
| 合并模式 空包不动本机数据 | 空包合并后本机课与作业原样、`scheduleDateRules` 不被清空 |
| 模板 id 在本机不存在时 引用按映射改写 | `schemeIdMap = {ts1 → ts-local-new}` 时，`settings.activeTimeSchemeId` 与课程 `timeSchemeIdOverride` 都改成新 id |

**反向验证（咬合探针）**：把 `planWrites` 里 `tasks = plan.tasks` 改回 `tasks = current.tasks`，「作业与考试都还在」必须红（expected `[task-1]` but was `[]`）；把 `timeSchemes = plan.timeSchemes` 删掉，模板那条必须红（expected `[ts1]` but was `[]`）。本报告不跑 Gradle（硬约束），这两条留待 Lead 串行跑闸门时顺手做一次。

另：`DataTransferModelTest` 新增「全量包不给合并动作 免得点出未知错误」——断言 `previewActions(canMerge = false)` 只有「取消 / 覆盖当前课表」且不含 `MERGE`。

### 8.8 二轮没能验的

1. **一次 Gradle 都没跑**（硬约束）：改动的 Kotlin 能否编译、新单测能否通过，全部要由 Lead 的 L0/L1 闸门确认。我做的是逐行 API 核对（构造器参数名、返回类型、可见性都回源码查过），不是编译证明。
2. **真机仍未验**：分享面板是否弹出、接收方能否打开 `.mikcb`、导入后课表是否真的回来、SAF 兜底是否触发，都需要用户配合。
3. **时间模板跨设备导入的实际效果**：`createTimeScheme` 生成新 UUID、引用按映射改写这条路只在纯逻辑层验了映射；真机上 `updateTimeScheme` 的「节次收窄」拒绝对导入的影响（跳过该模板、引用悬空 → 回落默认作息）没有实测。
4. **同目录他人在途文件**（F03 的 `LanEditHost.kt` / `PickupCodesHost.kt` / `PickupCodesModel.kt`）会不会与本批改动冲突，我无法预判；我碰过的文件里没有它们。

### 8.9 二轮跑过的只读命令（摘）

```
$ git rev-parse --short HEAD            → bf0e5a57
$ git status --porcelain | grep -E "pages/(sync|transfer)|platform/"   → 本族开工干净（F03 的未跟踪文件除外）
$ grep -n "tasks = repository.tasks" …  → 证实 P0-1 仍在
$ grep -n 'g3.lanEdit' -A 8 …           → 证实 P0-2 仍在（移交 F03）
$ grep -rn "outboundTitle" android/app/src → 仍只有声明 + 赋值（P1-1/P2-6）
$ grep -c "Toast.makeText" …CoupleTimetableSettingsHost.kt → 13（P2-7）
$ grep -rn "TransferPreviewModel" …     → 只剩定义（P2-2）
$ grep -rn "diffSummaryLine|diffSummary(" … → 发现 previewMessage 在用（阻止了一次误删）
```
