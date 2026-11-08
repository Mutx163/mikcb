# 接线说明：把 `WarehouseWebViewHost` 接进 `WarehouseWebLoginPage`

> 由 `cap-webview`（共享任务板 `task-4`，能力缺口 B3）在 **2026-10-28** 写。
> **接线动作由 Lead 执行**：`WarehouseWebLoginPage.kt` 当时有别的会话未提交的改动，本泳道不许改它。
>
> 写这份说明时该文件的指纹：`git hash-object` = **`baa48e316b44e7701f9927848920bb732e914b3b`**，**245 行**。
> 如果行号对不上（并发会话可能又改了它），请**按下面引用的原文匹配**——每处都给了原文。
> 本泳道交付的三个文件（都在你的写作用域之外，不会和这份说明冲突）：
> - 渲染层 `android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebViewHost.kt`
> - 纯逻辑 `android/app/src/main/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebViewLogic.kt`
> - 测试 `android/app/src/test/kotlin/com/mutx163/qingyu/pages/import/warehouse/WarehouseWebViewLogicTest.kt`

## 0. 一句话

把 **214–242 行**的「灰底占位 + 引导文案」整块换成 `WarehouseWebViewHost(...)`；
顶栏「刷新」改走 controller；再补一个桌面/移动切换按钮（Dart 有、Compose 侧目前没有）。

## 1. 前置：调用方必须先给 WebView 一个真地址

宿主的 `initialUrl` 就是 Dart 的 `widget.initialUrl`（适配器登录地址），**不是**页面里那个
`"https://..."` 占位串。调用方要在构造 `sessionState` 时把 `currentUrl` 填成真地址：

```kotlin
// 调用方（持有 sessionState 的那一层）
WarehouseWebLoginPage(
    title = ...,
    sessionState = sessionState.copy(currentUrl = adapterLoginUrl), // ← 必须
    ...
)
```

`initialUrl` 为空串时宿主**不加载任何地址**（`loadUrl` 会忽略空白，避免误加载 `about:blank`）。

## 2. 改动一：给页面签名加 7 个**带默认值**的参数（不破坏任何现有调用点）

在第 48–49 行附近：

```kotlin
fun WarehouseWebLoginPage(
    title: String,
    sessionState: WarehouseWebLoginSessionState,
    onBack: () -> Unit = {},
```

改成（新增的 7 行都带默认值，现有调用点不用动）：

```kotlin
fun WarehouseWebLoginPage(
    title: String,
    sessionState: WarehouseWebLoginSessionState,
    webViewController: WarehouseWebViewController = rememberWarehouseWebViewController(),
    onWebProgress: (Int) -> Unit = {},
    onWebPageStarted: (String) -> Unit = {},
    onWebPageFinished: (String) -> Unit = {},
    onWebError: (WarehouseWebViewError) -> Unit = {},
    onWebBridgeMessage: ((String) -> Unit)? = null,
    onBack: () -> Unit = {},
```

这四个类型（`WarehouseWebViewController` / `WarehouseWebViewError`）与页面**同包**
（`com.mutx163.qingyu.pages.import.warehouse`），**不需要加 import**。

## 3. 改动二：顶栏「刷新」按钮接上真视图

第 69–72 行原文：

```kotlin
                actions = {
                    IconButton(onClick = onReload) {
                        Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.zh)
                    }
```

改成：

```kotlin
                actions = {
                    IconButton(onClick = {
                        webViewController.reload()
                        onReload() // 保留原回调：调用方可能还要记日志
                    }) {
                        Icon(imageVector = MiuixIcons.Refresh, contentDescription = WarehouseStrings.reloadAction.zh)
                    }
```

## 4. 改动三：替换 **214–242 行**的占位块（本次接线的核心）

要删掉的原文（从注释行到该 `Box` 结束的 `}`，含 `when (sessionState.stage)` 那一段）：

```kotlin
            // WebView 视口占位与引导
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f)
                    .background(MiuixTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = when (sessionState.stage) { ... },
                        ...
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = sessionState.currentUrl.ifEmpty { "https://..." },
                        ...
                    )
                }
            }
```

换成：

```kotlin
            // 真 WebView 宿主（能力缺口 B3）：原来的灰底占位 + 引导文案整块换成平台 WebView。
            // 那几条 when(stage) 引导文案不再需要——加载进度/失败由下面两个回调驱动。
            WarehouseWebViewHost(
                initialUrl = sessionState.currentUrl,
                controller = webViewController,
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f),
                desktopMode = webViewController.isDesktopMode,
                onProgress = onWebProgress,
                onPageStarted = onWebPageStarted,
                onPageFinished = onWebPageFinished,
                onError = onWebError,
                onBridgeMessage = onWebBridgeMessage,
            )
```

- `weight(1f)` 仍在 `ColumnScope` 里，布局角色与原来的占位块一致（占满剩余高度）。
- 删掉这段后，`Spacer` / `CircleShape` / `RoundedCornerShape` / `size` / `width` / `height`
  等 import 可能变成未使用——**只是警告，不影响编译**；要不要顺手清由 Lead 定。
- `Alignment` 仍被底部按钮行用着，别删。

## 5. 改动四：补桌面/移动切换按钮（可选，但 Dart 有）

Dart 顶栏第二个动作就是这个开关（`_toggleWebPageMode`）。Compose 页面目前没有，所以
宿主暴露的 UA 切换在界面上点不到。加在「刷新」按钮前面：

```kotlin
                    IconButton(onClick = {
                        webViewController.toggleDesktopMode() // 换 UA + 重载当前页，对齐 Dart
                        onToggleDesktopMode()
                    }) {
                        Icon(
                            imageVector = if (webViewController.isDesktopMode) MiuixIcons.Phone else MiuixIcons.ScreenMirroring,
                            contentDescription = if (webViewController.isDesktopMode) {
                                WarehouseStrings.switchToMobileWebTooltip.zh
                            } else {
                                WarehouseStrings.switchToDesktopWebTooltip.zh
                            },
                        )
                    }
```

⚠️ **图标口径（已定）**：miuix-icons **0.9.4** 的扩展图标里**没有** desktop / monitor / smartphone
一类（157 个扩展图标全部离线渲染逐个比对过），所以：
- 切电脑版 → `ScreenMirroring`（显示器 + 投射三角，唯一带屏幕形状的）；
- 切手机版 → `Phone`（话筒，中文语境下「手机」的近邻）。

早先用 `GridView`（四个小方块＝宫格）充当电脑版，缩到 24dp 读作「宫格/应用抽屉」，已换掉。
文案键是对的（`switchToMobileWebTooltip` / `switchToDesktopWebTooltip`，语义与 Dart 一致：
**按钮描述的是「点了会切到哪边」**）。

## 6. 接线时必须一起做的两件事

### 6.1 进度 / 错误回写 `sessionState`

页面是无状态渲染（`sessionState` 由调用方持有），所以宿主回调要在调用方那层更新状态：

```kotlin
onWebProgress = { progress ->
    sessionState = sessionState.copy(
        stage = if (progress >= 100) WarehouseWebLoginStage.LOADED else WarehouseWebLoginStage.LOADING,
    )
},
onWebError = { error ->
    sessionState = sessionState.copy(
        stage = WarehouseWebLoginStage.ERROR,
        errorMessage = error.arbKey?.let { /* 取 ARB 文案 */ } ?: error.description,
    )
},
```

**文案的现实情况（重要，别踩空）**：

| 分类 | ARB 里有没有现成键 |
|---|---|
| `CLEARTEXT_BLOCKED` | 有：`importCleartextBlockedHint`（`lib/l10n/app_zh.arb:2614`），但 **Kotlin 的 `WarehouseStrings.kt` 里还没有这一条**（本泳道不许改那个文件）——要上屏得由 Lead 补一条并过 `WarehouseStringsParityTest` |
| 其余分类 | 没有专门的键（`WarehouseWebViewError.arbKey == null`）；要么复用 `importFailedWithError`，要么新加键，由 Lead 定 |

宿主**刻意不在 Kotlin 里硬写中文**（会被中文字面量棘轮门禁拦下），只给分类 + ARB 键名。

### 6.2 `QingyuBridge` 消息门禁（**必须**，否则重开 Dart 修过的钓鱼洞）

宿主对**任意页面**开放 `QingyuBridge`（与 Dart 一致），页面随时可以 `postMessage`。
UI 类消息（`toast` / `confirm` / `prompt` / `singleSelection` / `error`）的唯一合法生产者是
导入执行期的适配脚本，必须过滤：

```kotlin
onWebBridgeMessage = { raw ->
    val type = warehouseBridgeMessageType(raw)
    if (shouldProcessWarehouseBridgeMessage(
            type = type,
            importExecutionActive = sessionState.stage == WarehouseWebLoginStage.EXECUTING,
        )
    ) {
        handleBridgeMessage(raw) // 调用方自己的消息分发
    }
},
```

两个函数在纯逻辑层（`WarehouseWebViewLogic.kt`），**逐字对齐 Dart**
`lib/domain/warehouse_bridge_gate.dart`，并有对拍测试钉住。

## 7. 本泳道**没有**搬过来的东西（诚实清单，接线时别以为有）

| # | 缺什么 | 影响 |
|---|---|---|
| 1 | IME insets 处理（Dart `setInsetsForWebContentToIgnore(ime)`） | 键盘弹出时网页视口可能被压缩，强智一类底部固定版权条会顶到「登录」按钮上。**只有真机能验** |
| 2 | 登录态探活 / 自动填充脚本（Dart `_installLoginWatcher`、`_requestLoginStateProbe`、`_injectImeScrollHelperJs`） | 自动填充浮条拿不到网页输入框内容。宿主只提供 `injectJavaScript` / `evaluateJavaScript` 两个口子 |
| 3 | 宏录制 / 回放脚本与 `PlaybackOverlay` | 属导入执行链路，不在本任务范围 |
| 4 | 退出动画尾段提前摘平台视图（Dart `_detachPlatformViewIfExitReached`） | Compose 侧未做；宿主离开组合即 `destroy()` |
| 5 | 后台导入（Dart `runInBackground`，挂在 1×1 离屏容器） | 宿主没有离屏模式；要用就把宿主放在尺寸 >0 的离屏容器里，并保证**它不离开组合**（离开组合 = 销毁视图 = JS 上下文没了，后台导入会断） |
| 6 | 地址栏（Dart 有 URL 输入框 + 「前往」） | Compose 页面本来就没有；`webViewController.liveUrl()` / `currentUrl` 已经能取到地址，UI 由 Lead 决定 |
| 7 | `setAcceptThirdPartyCookies` | 没显式设置，用平台默认（false）。跨主域 SSO 可能需要开；**与 webview_flutter 的默认是否一致未核实** |
| 8 | `mixedContentMode`（https 页面里的 http 子资源） | 没设，用平台默认 |
| 9 | `onReceivedSslError` / `onReceivedHttpError` | 没覆盖（Dart 也没有） |
| 10 | 明文白名单（NSC） | WebView 不负责；`ERR_CLEARTEXT_NOT_PERMITTED` 由仓库的网络安全配置决定，宿主只把它**分类**出来 |
| 11 | `QingyuBridge.postMessage` 的**返回形状** | Dart 侧是 `webview_flutter` 的 JS 通道（返回 Promise，适配脚本常写 `await QingyuBridge.postMessage(…)`）；宿主用的是平台 `addJavascriptInterface`，方法**同步返回 undefined**。`await undefined` 不报错，所以现有脚本不会因此挂，但**行为不完全等价**，真机上要留意 |

## 8. 验收方式（接线后）

```bash
# 纯逻辑（约 25 秒，39 例）
pwsh -File scripts/test-kotlin-module.ps1 -Module "pages/import/warehouse"

# 渲染层能编（L1；本机有别的会话在构建，闸门排队是正常的）
pwsh -NoProfile -File scripts/safe-gradle.ps1 :app:compileComposeUiDebugKotlin -x :app:compileFlutterBuildComposeUiDebug
```

本泳道交付时这两条的实测结果见认领文件 `.agents/compose-phase3/claims/GAP-webview.md`。
**真机逐页对照（L4）没有做**——设备铁律：未经用户明确允许不碰真机。

## 9. F28（2026-11-01）：`g2.webLogin` 学校/登录地址数据源收尾

### 现在的链路

`g2.warehouseImport`（选校）→ `g2.schoolAdapters`（选适配器）→ `g2.webLogin`：

- 学校清单来自仓库 `index/root_index.yaml`（`WarehouseRepositoryService.loadRootIndex()`，真网络，
  GitHub raw 为主、GitCode/镜像回退）；**没有打包进 assets**，断网时是失败态 + 重试，不是旧缓存。
- 适配器清单来自 `resources/<学校>/adapters.yaml`，`import_url` 已经解析进模型。
- `g2.webLogin` 的新宿主 `WarehouseWebLoginHost.kt` 用
  `resolveWarehouseWebLoginTarget(adapter, prefs.customImportUrl(adapter.id))` 决定地址：
  用户自定义覆盖 > 仓库 `import_url`；两者都不合法时显示诚实空态（不加载空白 WebView）。
- 「执行导入脚本」会 `WarehouseRepositoryService.loadAdapterScript(...)` 真拉脚本（含 SHA-256 校验，
  上游当前没有 `sha256` 键时跳过），包 `warehouseImportScriptWrapper(...)` 垫片后注入 WebView。

### 壳侧还需 Lead 落的一行（本泳道不改 `ShellPageIndex.kt`）

把：

```kotlin
// ShellPageIndex.kt 当前（F23 空态）
"g2.webLogin" -> ShellWarehouseEmptyPage(
    title = ShellPageCatalog.find(pageId)?.title.orEmpty(),
    message = WarehouseStrings.noValidWarehouseLoginUrl.zh,
    onBack = onBack,
)
```

改成（并补 import `...warehouse.WarehouseWebLoginHost`）：

```kotlin
"g2.webLogin" -> WarehouseWebLoginHost(
    state = warehouseState,
    prefs = warehousePrefs,
    onBack = onBack,
    onOpenPage = onOpenPage,
)
```

`warehouseState` / `warehousePrefs` 在 `ShellPageIndex.kt` 里已经存在（三页列表宿主在用）。

### 仍未接（诚实清单）

- ~~脚本回传的 `courses` 只记日志~~：已由 F32 写回（见 §10）；
- ~~桥接对话框（confirm/prompt/单选框）没有原生 UI~~：已由 I2-1 接原生弹窗
  （`WarehouseBridgeDialogs.kt`，回答经 `warehouseBridgeResolveScript` 回网页）；
- 登录态探针/自动填充仍缺（见 §7 #2）；
- ~~`saveCourseConfig` / `savePresetTimeSlots` 需要落盘，未接~~：`saveCourseConfig`
  已由 I2-2 落盘（学期周数/开学日）；`savePresetTimeSlots` 仍诚实回 `false`（作息切换链路未移植）；
- 真机全未验。

## 10. F32（2026-11-01）：抓回课程写入仓储 + 网页对话框降级

### 现在的链路

```text
执行导入脚本 → 拉脚本 → 注入（包 AndroidBridge 垫片）
  → 脚本 postMessage {type:'courses', payload:'[…]'}
  → warehouseBridgeCoursesPayload 解包
  → WarehouseCourseImportLogic.parse（对齐 Dart 的宽松解析）
  → WarehouseCourseWriteBack.applyPayload
  → TimetableRepository.replaceActiveProfileContent（一次落盘、一次通知）
  → Toast：新增强调 / 覆盖 / 无变化 / 失败 / 丢弃条数
```

写回策略（[WarehouseCourseWriteBack.Mode]）：

| 当前档案已有课 | 默认 |
|---|---|
| 没有 | `REPLACE` |
| 有 | `MERGE`（绝不静默清空用户已有课表） |

显式替换入口已由 I2-3 接上：当前档案已有课时，解析后先弹「替换/合并」（复用导入域
`ImportPreviewDialog`，`requestedMode` 按选择传入），用户取消则本次导入中止、不写盘。
解析后没有可导入课程时**不写盘**，避免一键清空。

### 网页对话框（I2-1/I2-2 已接原生；降级只剩一条兜底）

| 网页调用 | 原生行为 | 说明 |
|---|---|---|
| `confirm` / `showAlert` | 原生确认弹窗（`WarehouseScriptConfirmDialog`） | 取消/点外部 resolve `false` |
| `prompt` | 原生输入弹窗（`validateYearInput` 本地校验 4 位年份） | 取消 resolve `null` |
| `singleSelection` | 原生单选弹窗 | 取消 resolve `null`；录制期存「选中项文字」 |
| `saveCourseConfig` | 真落盘（学期周数/开学日，无效值不覆盖）后回 `true`；失败回 `false` | I2-2 |
| `savePresetTimeSlots` | 仍回 `false` | 诚实不可用：作息切换链路未移植 |

降级回答（`warehouseBridgeFallbackAnswer`）只剩两个用途：`savePresetTimeSlots`，
以及「已有弹窗待答时并发到来第二个弹窗」的防挂起兜底。
以上都记 `WarehouseWebLogin` 日志；`requestId` 与原有 resolve 共用同一份白名单校验。

### 壳侧必须补的一个参数（本泳道不改 `ShellPageIndex.kt`）

```kotlin
"g2.webLogin" -> WarehouseWebLoginHost(
    state = warehouseState,
    prefs = warehousePrefs,
    repository = wiring.timetable,   // ← F32 新增，不传则抓回的课不落库
    onBack = onBack,
    onOpenPage = onOpenPage,
)
```

### 仍未接（诚实清单）

- 「开学日 / 周次映射」弹窗：当前周次按脚本原值写入，不做 `firstCourseWeek` 平移
  （「替换/合并」选择已由 I2-3 接上：已有课时弹 `ImportPreviewDialog` 的替换/合并分支，
  空表仍直接 REPLACE 不问）；
- ~~原生 confirm / prompt / 单选界面~~：已由 I2-1 接上（`WarehouseBridgeDialogs.kt`；
  录制期应答按 Dart 口径记入宏的 `dialogResponses`）；
- ~~`saveCourseConfig` 落盘~~：已由 I2-2 接上（`resolveWarehouseCourseConfig` →
  `TimetableRepository.updateSettings`；无效值不覆盖用户设置；`firstDayOfWeek` 等
  不支持键记日志后忽略）。`savePresetTimeSlots` 仍回答 `false`（作息切换链路未移植）；
- 宏录制已由 I2-4 接上（录制 JS 注入/重注、`macro:event` 收集、事件转步骤、
  保存到与 Dart 同一份 prefs 键）；**快捷导入（宏回放）仍未移植**——
  列表页「快捷导入」入口按真值显示，但点了仍是「不可用」实话；
- 真机全未验：只能声明「L0 单测通过」。

