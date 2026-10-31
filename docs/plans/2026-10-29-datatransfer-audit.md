# Compose「数据备份与迁移」页 · 重构质量审核（2026-10-29）

> 触发：用户「数据备份迁移页面审核一下重构质量，功能有没有复刻完，页面有没有一模一样做过来，把他完善好」。
> 审核对象：路由 `g3.dataTransfer` ／ 渲染层 `pages/transfer/DataTransferPage.kt` ／ 模型层 `pages/transfer/DataTransferModel.kt` ／ 壳接线 `pages/ShellPageIndex.kt:1110-1137`。
> 对照物：Dart 正式版源码（`lib/screens/data_transfer_screen.dart` 838 行、`lib/screens/transfer_preview_dialog.dart` 56 行、
> `lib/ui/hyperos/**` 里本页用到的 12 个 widget、`lib/utils/app_toast.dart`）。
> **唯一判据是 Dart 源码与 ARB**；本仓文档（含 L4 清单、旧认领文件）只作线索。

---

## 零、结论（先看这段）

**判定：旧版「结构对了、细节大半没复刻、功能一处没接」。** 具体到可逐条数的程度：

| 维度 | 旧版实况 | 本次处置 |
|---|---|---|
| 页面结构 | 5 段顺序对；但多出**两段 Dart 里不存在的副标题正文**（`fullExportSubtitle` / `fullImportSubtitle`，这两个 ARB 键在 Dart 侧 `grep` 命中 0，是死键） | 删除；两处副标题不再上屏 |
| 卡片内自造元素 | 概览卡里插了 **6 条分割线** + 一个**常驻「撤销」按钮**（Dart 全页 0 条分割线、页面内 0 个撤销入口，撤销只在成功提示的尾部动作里活 2 秒） | 全部删除 |
| 按钮 | 次要操作用 `TextButton`（纯文字按钮）；导入按钮用**主色实心**；三个按钮被硬排成 2 行 | Dart 是 7 个 `HyperosButton`：次要=浅灰实心 `#E6E6E6`+深字、主=主题色实心、`Wrap(spacing 8, runSpacing 8)` 自动换行；导入按钮虽没写 `expand` 但因父级 stretch 而**通栏** |
| 忙碌态 | 转圈 + 文案并排；「完整导出...」这类忙碌文案会上屏 | Dart 忙碌时**标签被 18×18 转圈整个替换**（`hyperos_controls.dart:745-753`），忙碌文案永远不可见；照抄 |
| 二维码范围弹窗 | 4 个 `RadioButtonPreference`，`selected` 写死 `false`（永远不显示选中）、**没有取消**、点一下直接按空集合发送 | Dart 是 5 个竖排动作（取消 / 本周 / 勾选课程 / 时间模板 / 发送当前=主操作），正文用**主文本墨色**；选「勾选的课程」后还要再弹选课弹层 |
| 选课弹层 | **完全没有** | 新增：按科目聚合、整组勾选、空态、屏高 0.52 上限、完成整宽 |
| 概览区 | 行距 5dp + 分割线；两个「撤销」入口 | 行距按 Dart：普通行 `bottom 10`、末行 0；无分割线 |
| 导图入口 | `ArrowPreference` 单行 | 已是正解，保留（Dart `HyperosNavTile` 单行 = 官方 `ArrowPreference`） |
| 功能 | **9 个回调里 8 个是空实现**：导出三条、导入、二维码三条、撤销全部点不动；`timeSchemeCount` 写死 `1`（页面上「时间模板：1 套」与实际无关）；`g3.qrSend` 发出去的口罩内容是字符串 `"QingyuTimetable:<课表名>"`，不是传输包；扫码收到的字节被直接丢弃 | 见 §三：三条导出真实打包+分享、导入真实读文件+校验+预览+落盘、撤销真实可回滚、二维码发真包、扫码真落地、概览读真值 |
| 分层 | 渲染层自己判文案、自己排布局，模型层 `DataTransferLogic` 一半函数无人调用 | 渲染层只消费 `DataTransferViewState` 与 `DataTransferLogic`；打包/解析/差分/文案全在模型层（可 JVM 单测） |

**还差的（不在本页能力范围内，见 §六）**：真机一次都没验（agent 只能声明编译与 JVM 单测）；diff 计算是「按 id 比对两份包文本」的近似，
不是 Dart 那套按 scope 比对仓储内容的算法；`tasks/exams/scheduleItems` 导入不写回；撤销只活在内存（杀进程即失效）。

---

## 一、审核方法

1. 逐行读 Dart 侧：页面本体 838 行、预览弹窗 56 行、`HyperosButton` / `HyperosControlCard` / `HyperosSectionLabel` /
   `HyperosListView` / `HyperosChoiceTile` / `HyperosDialog` / `HyperosSheetFrame` / `HyperosNavTile` 的实现与
   `HyperosMiuixSpec` 常量表（字号、内边距、圆角、行高的唯一出处）；
2. 逐项对照 Compose 渲染层，把「Dart 有 Kotlin 没有 / Kotlin 自造 / 两边口径不同」三类分开记；
3. 用 ARB（`lib/l10n/app_zh.arb`）逐字对拍屏上文案，52 个键全部核过；
4. 功能面按「打包 → 分享 → 选文件 → 解析 → 预览 → 应用 → 撤销」逐段对照 Dart 服务层，并在 Kotlin 侧清点现成零件；
5. 改完用 **L0（模块 JVM 单测）+ L1（编译闸门）+ 样式/骨架守卫 + 咬合探针** 四道证据收口。

---

## 二、逐项对照（Dart 出处 → 旧 Compose → 现在）

### A. 页面骨架

| # | Dart 行为（出处） | 旧 Compose | 现在 |
|---|---|---|---|
| A1 | `HyperosSubpage` 可折叠大标题 + `HyperosListView`，横向 padding **16**、上 4 下 24（`hyperos_miuix_spec.dart:79`） | 手写 `Scaffold` + `TopAppBar`，横向 12 | 改用共享骨架 `QingyuPageScaffold`（顶栏三件齐 + `QingyuPageTheme` 兜深色）；横向仍用套件的 12，**登记为全局口径差异**（见 §七） |
| A2 | 分组间距 `HyperosSectionGap` = **12**（`miuix_spec.dart:78`） | `spacedBy(12)` 已对 | 保留，改用套件常量 `QingyuSectionGap` |
| A3 | 列表底部 24（`hyperos_page.dart:974-991`） | `bottom = 24` 已对 | 改成 `手势条 + 24`（旧版把手势条漏了） |
| A4 | 卡片圆角 **16** squircle（`adaptive_card.dart:76-78`；`HyperosTokens.cardRadius=24` **不决定卡片形状**） | 用默认 16 已对 | 保留默认 16（此处不是设置组 24） |
| A5 | 无 header 卡内边距 **16/16/16/12**（`hyperos_controls.dart:78-83`） | 四边等 16 | 按 Dart 给底部 12 |

### B. 分组顺序与卡片内容（`data_transfer_screen.dart:53-195`，13 个 children）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| B1 | 「完整导出」label + 卡（3 按钮，`Wrap 8/8`）+ 12 间距 | 有，但卡里多一段副标题；按钮排成 2 个 `Row` | 删副标题；改 `FlowRow(8/8)` |
| B2 | 日历组：**无 label**（源码注释：标签已删）+ 单行导航 | 有（`ArrowPreference`） | 保留 |
| B3 | 「完整导入」label + 卡（1 按钮） | 有，但多一段副标题、按钮为主色实心、非通栏 | 删副标题；改次要色 + 通栏 |
| B4 | 「二维码面对面传输」label + 卡：说明句 → 8dp → error 色警告 → 12dp → 3 按钮 | 结构对，但按钮排成两个 `Row`；次要按钮用 `TextButton` | 按 Dart 改 |
| B5 | 「当前可迁移内容」label + 卡：7 行概览，**无分割线** | 有 6 条 `HorizontalDivider` + 一个「撤销」按钮 | 全部删除，按 Dart 排 7 行 |

### C. 按钮（7 个，逐个）

| # | 文案（ARB） | Dart variant | 旧 Compose | 现在 |
|---|---|---|---|---|
| C1 | 导出当前课表 `exportCurrentTimetable` | primary + `loading = _isExporting` | `Button` + 转圈+文案 | primary + 转圈替换标签 |
| C2 | 导出全部数据 `exportAllData` | secondary，禁用跟随 `_isExporting` | `TextButton` | 浅灰实心 `QingyuTheme.secondary` + 深字 |
| C3 | 导出时间模板 `exportTimeTemplate` | secondary，**无模板时仍在、只是禁用** | `TextButton` | 同上，`canExportTimeTemplate` 判据来自真实模板数 |
| C4 | 选择文件并导入 `chooseFileAndImport` | secondary + `loading = _isImporting`，视觉通栏 | primary + `fillMaxWidth` | secondary + 通栏 + 转圈替换标签 |
| C5 | 二维码发送当前课表 `qrTransferSendCurrent` | primary，禁用跟随 `_isExporting` | `Button` | 不变（对） |
| C6 | 二维码发送全部数据 `qrTransferSendAll` | secondary | `TextButton` | 浅灰实心 |
| C7 | 扫码接收课表数据 `qrTransferScanReceive` | secondary，禁用只看 `_isImporting` | `TextButton` | 浅灰实心 + 只看导入态 |

> 已知不可对齐的两处：Dart 按钮圆角经 `clampCornerRadius(16, 40)` 收敛为 **14dp**、高约 45dp；
> miuix `Button` 是 16dp 圆角 / 40dp 高。属组件库差异，**不为了 1~4dp 去手搓按钮**（违反 miuix-first）。

### D. 概览区（`data_transfer_screen.dart:158-194, 220-245`）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| D1 | 7 行顺序：课程数 / 当前课表 / 全部课表 / 时间模板 / 当前周 / 开学日期 / 文件后缀 | 顺序对 | 不变 |
| D2 | 时间模板数取 `provider.timeSchemes.length` | 壳里**写死 1** | 取 `snapshot.timeSchemes.size`，并跟随仓储 `observe` 变化 |
| D3 | 行距 `bottom 10`，末行 0 | `padding(vertical = 5)` + 分割线 | 按 Dart |
| D4 | 左右两栏同一套 `listDetail`（14/w400/次级灰），只有对齐方式不同 | 两栏都 `footnote1`(13) 次级灰 | 改 `body2`(14) |
| D5 | 无「撤销」按钮 | 卡尾有一个 `TextButton(撤销)` | 删除（撤销改到成功提示的动作里） |

### E. 弹层（3 个）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| E1 | 预览弹窗：标题居中 + **多行正文**（段间空行、居中、14sp 次级灰）+ 3 个按钮竖排（取消 / 合并更改 / 覆盖当前课表=primary） | `OverlayDialog` + 左对齐正文 + 3 个主色按钮（primary 标记错） | 按 Dart 重排 |
| E2 | 二维码范围弹窗：标题 + **主文本墨色**正文 + 5 个竖排动作（最后一个是 primary） | 4 个 `RadioButtonPreference`（`selected=false` 恒不显示）、无取消、点了立刻发送 | 5 个动作 + 主文本墨色正文；选「勾选的课程」再弹选课弹层 |
| E3 | 选课弹层：标题 / 空态（上下 32dp）/ 列表最大高 = 屏高×0.52 / 整组勾选 / 完成整宽 | 无 | 新增（`OverlayBottomSheet` + `CheckboxPreference`，列表用 `LazyColumn`） |

### F. 文案（52 个 ARB 键）

- 屏上文案全部走 `TransferStrings`（ARB 逐字），本页新增/沿用的键与 ARB 逐条对拍由 `TransferStringsParityTest` 守着；
- 两个 Dart 死键（`fullExportSubtitle` / `fullImportSubtitle`）**不再上屏**，函数保留在 `TransferStrings` 里以便将来 Dart 侧真用到时再对拍。

### G. 状态与提示（`data_transfer_screen.dart:305-377, 585-694`）

| # | Dart | 旧 Compose | 现在 |
|---|---|---|---|
| G1 | `_isExporting` 同时禁用 3 个导出按钮 + 2 个二维码发送按钮，**不禁用扫码** | 状态位从不置真（壳里没有状态机） | 宿主持有两个状态位，判据逐条照抄 |
| G2 | `_isImporting` 禁用导入按钮 + 扫码按钮 | 同上 | 同上 |
| G3 | 导出失败：`sendFailedWithError(本地化原因)` | 无提示（空回调） | 宿主 toast（分享失败按分类给文案） |
| G4 | 导入失败分支：取消选文件=无提示；读不到/超大/空文件/解析失败各有文案 | 无 | 逐分支补齐（读不到→`importFileReadFailed`、超 20MB→`importFileTooLarge`、解析/应用失败→`TransferServiceMessages.localize`） |
| G5 | 成功：基础句 + 「超出作息」后缀 + 「跳过条目」后缀，任一出现降级 warning；有撤销令牌时带「撤销」动作 | 无 | 宿主拼装 + 带动作提示（撤销） |
| G6 | 撤销结果：成功 `已撤销本次导入`、失败 `撤销失败` | 无 | 同上 |
| G7 | 所有 toast 不传图标 ⇒ **三种 kind 在屏上零可见差别** | — | 不按 kind 改配色（登记，避免后人「顺手优化」成红绿） |

### H. 分层

| # | 旧 | 现在 |
|---|---|---|
| H1 | 渲染层直接用中文 `TransferStrings.xxx.zh` 拼句子、自己判 `isExporting` | 渲染层只读 `DataTransferViewState` + `DataTransferLogic` 的纯函数 |
| H2 | 打包/解析/差分逻辑在 Kotlin 侧**不存在** | 新增模型层三件（拼包 / 导入解析与差分 / 错误码文案），全部 JVM 单测 |
| H3 | 平台能力（分享、选文件）**零调用点**，FileProvider 未注册 | 新增 Android 胶水两件 + FileProvider 声明，壳里按需构造 |

---

## 三、功能面：从「点不动」到真跑通

| 功能 | Dart 实现 | 交付前实况 | 现在 |
|---|---|---|---|
| 导出当前课表 | `buildCurrentPackage` → `SharePlus.share(XFile.fromData)` | 空回调 | 真拼包（`buildTransferPackageJson`）→ 写 `cacheDir/transfer-share/` → FileProvider → 系统分享面板 |
| 导出全部数据 | `buildFullPackage`（scope=all_data, isFullBackup, 带 profiles） | 空回调 | 同上（全量拼包，含全部档案 + 时间模板） |
| 导出时间模板 | `buildCurrentPackage(scope: timeTemplate)` | 空回调（按钮还是「永远可点」） | 同上；无模板时按钮禁用 |
| 导出日历 | 跳 ICS 页 | 已通 | 不变（ICS 页自身仍是空回调，另案） |
| 完整导入 | FilePicker → 限长读 → `parseCompatible` → 预览 → `applyToProvider` | 空回调 | SAF 选文件 → 限长读（20MB，先按 SIZE 短路）→ 校验+解析 → 预览弹窗 → 落盘（覆盖 / 合并）→ 提示（带撤销） |
| 二维码发送当前 / 全部 | 打包 → `QrTransferSendScreen` | 发送假字符串 `"QingyuTimetable:<名>"` | 发真传输包字节 |
| 扫码接收 | 收齐 → `_handleQrReceivedBytes` → 预览 → 应用 | 字节被丢弃 | 走同一条导入链路（UTF-8 解码 → 校验 → 预览 → 落盘） |
| 撤销 | `undoToken(id)` 回滚上一份备份 | 空回调（且页面上多一个假撤销按钮） | 应用前抓仓储现场（档案表或当前档案三块+设置+周）→ 撤销时整份写回 |

### 落盘口径（决定用户数据会不会被无声吃掉，逐条明示）

| 包类型 | 覆盖 | 合并 |
|---|---|---|
| 全量备份（`backupType=full` / 带 `profiles`） | `repository.replaceAllProfiles(profiles, activeProfileId)` 整份替换 | **不支持**：明确提示、一个字节不动（Dart 支持逐实体合并，Kotlin 侧无 diff/apply 服务） |
| 单课表包（当前课表/本周/选课/时间模板） | 清空当前档案课表 → 逐门写入 + 写设置 + 写当前周 | 同 id 更新、新 id 追加、**缺的不删** + 写设置 + 写当前周 |

> 这两条是「能证明的行为」，不是「应该如此」：写入前后都有单测钉着合并算法（`DataTransferApplyLogicTest`），
> 但**真机上用户数据是否真回来属 L4，未验**（见 §六）。

---

## 四、本次改动清单

| 文件 | 性质 | 说明 |
|---|---|---|
| `composeP1/.../pages/transfer/DataTransferPage.kt` | 重写 | 按 Dart 逐项复刻渲染层；删两段副标题、6 条分割线、页面内撤销按钮；按钮/弹层/选课弹层/概览按 Dart |
| `composeP1/.../pages/transfer/DataTransferHost.kt` | 新增 | 宿主：仓储订阅、两个忙碌状态位、SAF 选文件、分享、导入预览与应用、撤销、toast |
| `main/.../pages/transfer/DataTransferModel.kt` | 扩 | 二维码范围 5 动作、选课科目组（聚合/整组勾选/勾选判据）、`courseGroups` 投影；删掉两个「永远不可见」的忙碌文案分支 |
| `main/.../pages/transfer/DataTransferPackageLogic.kt` | 新增（模型层） | scope 感知拼包 + 文件名 + 分享文案；自产包必须过 `validateTransferPackageJson` |
| `main/.../pages/transfer/DataTransferImportLogic.kt` | 新增（模型层） | 校验+解析成写入计划、8 类差分、预览正文（逐字对齐 Dart） |
| `main/.../pages/transfer/DataTransferApplyLogic.kt` | 新增（模型层） | 可应用性判据、合并算法、撤销快照模型 |
| `main/.../pages/transfer/TransferServiceMessages.kt` | 新增（模型层） | `transfer_*` 机器码 → 屏上文案（对齐 Dart 兜底口径） |
| `share/TransferShareContract.kt` | 新增 | FileProvider authority / 缓存目录 / MIME / 限长判据（纯 Kotlin，可 JVM 单测） |
| `platform/AndroidTransferShareAdapter.kt` | 新增 | 写缓存文件 → FileProvider → 系统分享（失败**分类**返回） |
| `platform/AndroidTransferDocumentAdapter.kt` | 新增 | 系统文档选择器 + 按上限读文本（先 SIZE 短路） |
| `res/xml/file_paths.xml` | 新增 | FileProvider 路径（`ics-export/` + `transfer-share/`） |
| `AndroidManifest.xml` | 改 | 注册 `${applicationId}.fileprovider`（此前全仓 6 个 manifest 0 命中 ⇒ 任何分享必然失败） |
| `pages/ShellPageIndex.kt` | 改 | `g3.dataTransfer` 换成宿主；`g3.qrSend` 换真 payload；`g3.qrScan` 把收到的字节接回导入链路 |
| `test/.../pages/transfer/*Test.kt` | 新增 | 拼包/解析/差分/文案/合并/撤销快照/范围动作/科目组 |

---

## 五、证据

### 5.1 L0（模块 JVM 单测，真 JVM）

```
pwsh -NoProfile -File scripts/test-kotlin-module.ps1 -Module 'pages/transfer' \
  -ExtraSources @('./android/app/src/main/kotlin/com/mutx163/qingyu/pages/task/TaskModel.kt',
                 './android/app/src/main/kotlin/com/mutx163/qingyu/pages/task/TaskStrings.kt',
                 './android/app/src/main/kotlin/com/mutx163/qingyu/WidgetRefreshDecisionLogic.kt')
→ OK (206 tests)
```

206 = 既有 24（`DataTransferModelTest` 等）＋ 本轮新增 182。
新增测试类：`DataTransferPackageLogicTest`、`DataTransferImportLogicTest`、`TransferServiceMessagesTest`、
`DataTransferSelectionLogicTest`、`DataTransferApplyLogicTest`、`TransferShareContractTest`（在 `share/` 模块跑）。
**期望值全部人推**（手写包 JSON、手算文件名与字节边界、手推合并结果），没有从实现里抄。

### 5.2 咬合探针（改坏判据 → 必红 → 还原 → 必绿）

| 改坏什么 | 红的结果 | 还原后 |
|---|---|---|
| 拼包 `exportedAtIso` 从 `DartTime.toIso(now)` 换成带 `Z` 的瞬时串 | `Tests run: 182, Failures: 6`，失败原因全是 `transfer_exported_at_invalid`（被**自产包自校验**那道门抓住） | 6 个文件 `cmp` 逐字相同 → `OK (182 tests)` |
| `TransferShareContract.exceedsLimit` 的 `>` 改 `>=` | `Tests run: 84, Failures: 2`（恰好等于上限被判超） | 逐字相同 → `OK (84 tests)` |

### 5.3 样式守卫

```
pwsh -File scripts/compose-style-lint.ps1 -Domain transfer
→ transfer 域 0 处违规（可删）
```

即重写后的 `DataTransferPage.kt` 与新增 `DataTransferHost.kt` 都不碰裸 `Card` / 裸 `LazyColumn` /
写死字号与颜色 / 手搓顶栏（R1–R6 全过）。

### 5.4 L1（编译闸门）

`pwsh -File scripts/safe-gradle.ps1 :app:compileDevDebugKotlin`
→ **`BUILD SUCCESSFUL in 56s`，`e:` 行数 = 0**。

过程如实记录：前三次都是 **BUILD FAILED**，但 15 条报错**全部落在其它会话当时在途的文件**上
（`composeP1/app/TimeSchemeHost.kt`、`composeP1/pages/time_scheme/TimeSchemeManagementPage.kt`、
`main/pages/ShellWiring.kt`——时间模板族接线进行中的签名不匹配），
按 `grep "^e: " | grep -E "pages/transfer/|AndroidTransfer|TransferShareContract"` 命中 **0 条**。
等那几条泳道收口后复跑即绿，说明本批文件（含 `DataTransferPage.kt` / `DataTransferHost.kt`
两个 Compose 文件）能过 Kotlin + Compose 编译器。

### 5.5 L2（权威单测闸门）

`pwsh -File scripts/safe-gradle.ps1 :app:testDevDebugUnitTest`
→ **`4983 tests completed, 2 failed`**，两条都**不在本批**：

| 失败用例 | 归属 |
|---|---|
| `CjkLiteralGateTest > 渲染层…硬编码手机号` | 其它域的页面文案（本批文件里没有这类字面量） |
| `ComposePageStyleGuardTest > 基线里已经修好的行要删掉` | 别的域修好了一处存量债但没同步删基线行 |

隔几分钟**单独复跑这两个类** → `BUILD SUCCESSFUL`（源码在那两次运行之间已被对应泳道修正）；
随后全量任务再跑 → `BUILD SUCCESSFUL`（up-to-date）。
本批新增的 6 个测试类（182 例）在全量那一轮里 **0 失败**。

> 口径提醒：L0/L1/L2 都只证明「编译过 / JVM 逻辑对」，**不证明真机可用**（见 §六·1）。


---

## 六、还差什么（诚实清单）

1. **真机一次都没验**：agent 只能声明「编译过 / JVM 单测过」（L0/L1）。
   「选文件能导入」「分享面板真能弹出」「恢复后课表真的回来」全部是 **L4，需用户配合**。
2. **FileProvider 是新加的**：manifest 里从来没有过 provider，本次首次注册。真机上分享面板能否起来、
   接收方能打开 `.mikcb`，属 L4；代码路径上的 `PROVIDER_UNAVAILABLE` 已从「必然发生」变为「理论上不会发生」。
3. **diff 是近似**：Dart 的 `TransferDiffService` 按 scope 比对仓储真实内容，并且 `overwriteUsesMergeSemantics`
   对 4 个 scope 有不同语义；Kotlin 侧是「两份包文本按 id 比对」。所以预览弹窗里的 `+a / ~u / -r`
   **可能与 Flutter 正式版数字不同**（合并模式一律按 `removed=0` 处理）。
4. **合并模式不支持全量包**：Dart 能逐实体合并，Kotlin 侧明确拒绝并保持数据不动（宁可不动，也不猜着写）。
5. ~~**`tasks` / `exams` / `scheduleItems` / `scheduleDateRules` 导入不写回**~~ **已于二轮修复（2026-10-29 晚）**。
   ⚠️ 原文的缺口清单**漏了 `timeSchemes`（时间模板）**——它同样「导出带、导入丢」，而且后果最重：
   课程上的 `timeSchemeIdOverride` 与设置里的 `activeTimeSchemeId` 会指向不存在的模板。
   现在 `DataTransferApplyLogic.planWrites()` 一次算全写入范围（五类数据全在），
   宿主按它落盘、时间模板走「id 已存在则更新、不存在则新建 + 改写引用」，
   单测 `DataTransferRoundTripTest` 钉住「导出 → 解析 → 计划」三段落数据不丢。
   仍未覆盖：`locationTimeGroups`（`TimetableSnapshot` 没有该字段，编制层缺口，见第 11 条）。
6. **撤销只活在内存**：杀进程即失效（Dart 的 undo token 也是内存态 + 容量上限，但通过服务层统一管理）。
   撤销窗口照抄 Dart 的 **2 秒**（`HyperosMiuixSnackbar.durationShortMs`），真机上够不够用需用户看了再说。
7. **按 scope 的细粒度导出仍有风险**：本周课表 / 勾选课程走的是 `TransferScopeWindow` + id 过滤，
   与 Dart 的 `buildCurrentPackage` 在同一 scope 下是否逐字段一致，**只做了结构级单测**
   （scope / 是否带设置 / 课程 id 集合 / 自产包过校验），没有做「同一份数据在 Flutter 与 Compose 下导出字节相同」的对拍。
8. **`g3.icsExport` 仍然全是空回调**（同域另一页），本批未动，避免一次提交变成一次重构。
9. **L1/L2 的时效性**：本页的编译证据是在「其它泳道收口之后」才拿到的（§5.4）；
   共享工作区里别人一动半成品，闸门就会红在与本页无关的文件上——复跑时先看报错文件属谁。
10. **`settings` 只带 core 子集**：Kotlin `TimetableSettings.toJson` 目前只有 5 个键（节次表 / 作息 id /
    学期周数 / 开学日期），Dart 是 250+ 键。所以「导出的设置比 Flutter 少」是编制层缺口，不是本页漏调。
11. **`locationTimeGroups` 恒空**：`TimetableSnapshot` 没有这个字段，按「不臆造数据」处理。
12. **`TransferPreviewModel`（模型）仍留着一份旧的正文拼法**（`\n` 连接 vs Dart 的 `\n\n` 空行）：
    它已无渲染方（原 `TransferPreviewContent.kt` 那个自绘卡片弹窗本批删除，页面改用 Dart 口径的
    `TransferPreviewDialog`），属死代码，留给下一次碰 LAN 预览时统一。


---

## 七、与 Dart 的已知口径差异（登记，不是缺陷单）

| # | 差异 | 为什么保留 |
|---|---|---|
| 1 | 页面横向留白：套件 12+16=**28** 轴线，Dart 16+16=**32** 轴线 | 全站 60 个 Compose 页共用套件轴线（官方 miuix demo 的 28），单页改 16 会让分组标题（`SmallTitle` 自带 28）与卡片正文错开 4dp，比整体差 4dp 更难看。属套件级决定 |
| 2 | 按钮圆角 16 / 高 40（Dart 14 / 45）、次要按钮底色取 `QingyuTheme.secondary` | miuix-first：不为了 1~4dp 手搓按钮（手搓即自研，违反组件优先标准） |
| 3 | 选课弹层用 `CheckboxPreference`（官方 preference 行） | Dart 的 `HyperosChoiceTile` 是 miuix 移植件；官方对应物是 checkbox 行。语义一致（整组勾选），视觉是官方样式 |
| 4 | 忙碌时只有转圈、没有文案 | **不是差异，是照抄**：Dart 的忙碌文案被 spinner 顶掉，永远不可见（`hyperos_controls.dart:745-753`） |
| 5 | toast 三种 kind 视觉相同 | 照抄：Dart 本页所有 toast 都不传 `showKindIcon`（`app_toast.dart:60-63`） |
