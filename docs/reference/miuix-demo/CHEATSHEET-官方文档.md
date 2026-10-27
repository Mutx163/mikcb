# miuix 官方组件文档速查（CHEATSHEET-官方文档）

> **这份是本仓笔记，不是上游文件。** 逐组件精读 `docs/reference/miuix-demo/docs/components/` 下
> **全部 56 篇**官方文档后的速查表。上游文件（`docs/components/*.md`）只读，不许改。
>
> | 项 | 值 |
> |---|---|
> | 精读对象 | `docs/reference/miuix-demo/docs/components/*.md`（56 篇，共 11 356 行） |
> | 上游快照 | compose-miuix-ui/miuix @ `bb7bde3`（2026-10-27 取回） |
> | 本仓依赖 | `top.yukonga.miuix.kmp:*:0.9.4`——**快照可能领先于 0.9.4**，用新 API 前先确认本地依赖里有 |
> | 撰写 | agent `miuix-docs`，2026-10-27 |
>
> **本文只记录「官方文档怎么写」。** 官方 demo 里**实际怎么调**（能跑起来的那份、两者冲突时以它为准）
> 见同目录 `CHEATSHEET-Demo范例.md`；「我们漏了什么、怎么修」见 `我们的差距与修法.md`。
>
> 阅读约定：`⚠️ 默认关` = 该参数默认值是「关闭 / None / null / false」，**不显式传就等于没有**；
> `📦` = 包路径；`🔁 重载` = 该组件有多个重载，差异已写明。

---

## 0. 先看这一页：默认「关闭 / None」的参数总表

**这是本速查表最贵的一页。** 官方组件的交互与特效参数绝大多数**默认关闭**——文档给的是「配方」，
默认值给的是「空壳」。我们仓库的「点击没手感」就出在这一栏：`pressFeedbackType` / `showIndication` 全仓 0 处。

### 0.1 交互反馈（手感）类

| 组件 | 参数 | 默认值 | 官方推荐值 / 说明 |
|---|---|---|---|
| `Card`（可点） | `pressFeedbackType` | `PressFeedbackType.None` ⚠️ 默认关 | `PressFeedbackType.Sink`（下沉缩放）/ `Tilt`（倾斜） |
| `Card`（可点） | `showIndication` | `false` ⚠️ 默认关 | `true` |
| `Card`（可点） | `holdDownState` | `false` ⚠️ 默认关 | 弹窗打开期间传 `true` 保持按下态 |
| `IconButton` | `holdDownState` | `false` ⚠️ 默认关 | 同上（官方示例：`holdDownState = showDialog`） |
| `ArrowPreference` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `SwitchPreference` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `CheckboxPreference` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `RadioButtonPreference` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `SliderPreference` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `RangeSliderPreference` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `BasicComponent` | `holdDownState` | `false` ⚠️ 默认关 | 同上 |
| `TabRow` / `TabRowWithContour` | `indication` | `null` ⚠️ **默认无涟漪** | 传 `LocalIndication.current` 之类才有反馈 |
| `Button` / `TextButton` | `indication` | `LocalIndication.current` | 默认有；`interactionSource` 默认 `null` |
| `Surface`（可点） | `indication` | `LocalIndication.current` | 默认有 |
| `BreadcrumbBar` | `indication` | `LocalIndication.current` | 默认有 |

### 0.2 滑块 / 取色器（触感与刻度）类

| 组件 | 参数 | 默认值 | 说明 |
|---|---|---|---|
| `Slider` / `VerticalSlider` / `RangeSlider` / `SliderPreference` / `RangeSliderPreference` | `showKeyPoints` | `false` ⚠️ 默认关 | 只在 `keyPoints != null` 时才有意义 |
| 同上 | `keyPoints` | `null` ⚠️ 默认 None | 为 null 时用 `steps` 的位置；给了才画刻度点 |
| 同上 | `magnetThreshold` | `0.02f` | 磁吸阈值（0~1 的比例），仅 `keyPoints` 非空时生效 |
| 同上 | `hapticEffect` | `SliderDefaults.DefaultHapticEffect` | 默认值 = `SliderHapticEffect.Edge`（**只在两端震**）；要每档震得显式传 `Step`；`None` 完全不震 |
| 同上 | `onValueChangeFinished` | `null` ⚠️ 默认 None | 拖动结束回调，不传拿不到「松手」时机 |
| `VerticalSlider` | `effect` | `false` ⚠️ 默认关 | 是否显示特殊效果 |
| `Slider` / `VerticalSlider` | `reverseDirection` | `false` | false 跟随 `LayoutDirection`；VerticalSlider 的 false = 下→上递增 |
| `ColorPicker` / `ColorPalette` | `showPreview` | `true`（默认**开**） | 想关得显式 `false` |
| `ColorPalette` | `includeGrayColumn` | `true`（默认**开**） | 右侧灰阶列 |
| `ColorPalette` | alpha 滑条 | **内置且无法隐藏** | 文档明说 currently cannot be hidden |

### 0.3 弹层 / 对话框 / 面板类

| 组件 | 参数 | 默认值 | 说明 |
|---|---|---|---|
| 全部 Overlay / Window 弹层 | `onDismissRequest` | `null` ⚠️ 默认 None | 不传则「点外部 / 返回键」不会回调你 |
| 全部 Overlay / Window 弹层 | `onDismissFinished` | `null` ⚠️ 默认 None | 隐藏动画结束后才回调；**中途被 `show=true` 打断则不回调** |
| 全部 Overlay / Window 弹层 | `enableWindowDim` | `true`（默认**开**） | 关掉传 `false` |
| `OverlayListPopup` / `OverlayCascadingListPopup` / `OverlayDialog` / `OverlayDropdownPreference` / `OverlayDropdownMenu` / `OverlayIconDropdownMenu` / `OverlayIconCascadingDropdownMenu` / `OverlaySpinnerPreference` / `OverlayBottomSheet` | `renderInRootScaffold` | `true` | true = 渲染到最外层 Scaffold、盖满全屏；false = 限制在当前 Scaffold 范围内并做位置补偿 |
| `WindowDialog` / `OverlayDialog` | `largeScreen` | `null` ⚠️ 默认 None | null = 按窗口尺寸自动判定（大屏居中缩放淡入 / 否则底部滑入） |
| `WindowDialog` / `OverlayDialog` | `cornerRadius` | `null` ⚠️ 默认 None | null = 居中态用 `DialogDefaults.CornerRadius`，贴底态由屏幕圆角推导（夹在 32dp~48dp） |
| `WindowDialog` / `OverlayDialog` | `title` / `summary` | `null` ⚠️ 默认 None | 不传就没有标题/摘要区 |
| `WindowBottomSheet` / `OverlayBottomSheet` | `title` / `startAction` / `endAction` | `null` ⚠️ 默认 None | 头部三件套都是可选 |
| `WindowBottomSheet` / `OverlayBottomSheet` | `allowDismiss` | `true` | `false` = 拖拽/返回键都不能关，必须显式关 |
| `WindowBottomSheet` / `OverlayBottomSheet` | `enableNestedScroll` | `true` | |
| `WindowBottomSheet` / `OverlayBottomSheet` | `dragHandleColor` | `BottomSheetDefaults.dragHandleColor()` | |
| 各 Dropdown / Spinner 类 | `collapseOnSelection` | 单组重载 `true`；`entries` 重载 `entries.size <= 1` | **多组菜单默认选完不关**，要关得显式 `true` |
| 各 Dropdown / Spinner 类 | `onExpandedChange` | `null` ⚠️ 默认 None | 不传就观察不到展开/收起 |
| 各 Dropdown / Spinner 类 | `showValue` | `true` | `false` 则不显示当前选中值 |
| 各 Dropdown / Spinner 类 | `maxHeight` | `null` ⚠️ 默认 None | null = 由安全区兜底 |
| `WindowListPopup` | `maxHeight` | `null` ⚠️ 默认 None | |
| `OverlayIconDropdownMenu` 等图标菜单 | `backgroundColor` | `Color.Unspecified` | 底层 `IconButton` 的背景色，**不是透明**，是「交给主题」 |
| `OverlayIconDropdownMenu` 等图标菜单 | `onExpandedChange` | `null` ⚠️ 默认 None | |

### 0.4 文字 / 图标 / 输入类

| 组件 | 参数 | 默认值 | 说明 |
|---|---|---|---|
| `Text` | `style` | `MiuixTheme.textStyles.main` | **一旦显式传 `fontSize`/`fontWeight` 就整体覆盖主题样式**（字族、行高全丢）——我们 577 处裸 `fontSize` 的代价就在这 |
| `Text` | `color` | `Color.Unspecified` | Unspecified = 跟随主题/父级，不是「黑色」 |
| `Text` | `autoSize` | `null` ⚠️ 默认 None | 想自适应传 `TextAutoSize.StepBased(...)` |
| `Text` | `overflow` / `maxLines` / `minLines` | `Clip` / `Int.MAX_VALUE` / `1` | 截断必须显式给 `maxLines` + `TextOverflow.Ellipsis` |
| `Icon` | `tint` | `LocalContentColor.current` | 跟随父组件内容色；`Color.Unspecified` = 不染色保留原色 |
| `IconButton` | `backgroundColor` | `Color.Unspecified` | 同上语义 |
| `TextField` | `useLabelAsPlaceholder` | `false` ⚠️ 默认关 | false = label 浮到顶部；true = label 当占位符 |
| `TextField` | `singleLine` / `readOnly` | `false` / `false` ⚠️ 默认关 | 单行必须显式传 |
| `TextField` | `leadingIcon` / `trailingIcon` | `null` ⚠️ 默认 None | |
| `TextField` | `visualTransformation` | `VisualTransformation.None` | 密码框传 `PasswordVisualTransformation()` |
| `TextField` | `cursorBrush` | `SolidColor(colors.borderColor)` | |
| `TextField`（state-based 重载） | `inputTransformation` / `outputTransformation` / `onKeyboardAction` | `null` ⚠️ 默认 None | |
| `SearchBar` | `expanded` | `false` ⚠️ 默认关 | 展开态（显示结果区）要自己 hoist |
| `SearchBar` | `outsideEndAction` | `null` ⚠️ 默认 None | 展开时右侧的「取消」按钮槽 |
| `InputField` | `label` | `""` | 空串 = 无占位文字 |
| `InputField` | `leadingIcon` / `trailingIcon` | 有默认值（默认搜索图标 / 默认清除按钮） | 传 null 反而要显式 |
| `Snackbar`（showSnackbar） | `actionLabel` / `withDismissAction` | `null` / `false` ⚠️ 默认关 | 不传就没有动作按钮、没有关闭叉 |
| `Snackbar`（showSnackbar） | `duration` | `SnackbarDuration.Short` | 约 4 秒；`Long` 约 10 秒；`Indefinite` 直到手动关 |
| `SnackbarHost` | `canSwipeToDismiss` | `true` | |
| `TooltipBox` | `focusable` | `false` ⚠️ 默认关 | **RichTooltip 必须 `focusable = true`**，否则外部点击无法关闭、action 点不到 |
| `TooltipBox` | `enableUserInput` | `true` | false = 只能靠 `state.show()` 程序触发 |
| `PlainTooltip` / `RichTooltip` | `caretShape` | `null` ⚠️ 默认无尖角 | 要尖角传 `TooltipDefaults.caretShape()` |
| `rememberTooltipState` | `isPersistent` | `false` | plain 用 false（自动消失）；rich 用 true（`RichTooltipBox` 默认已 true） |
| `NumberPicker` | `wrapAround` | `false` ⚠️ 默认关 | 无限循环滚动要显式开 |
| `NumberPicker` | `visibleItemCount` | `5` | **必须是奇数且 ≥ 3** |

### 0.5 布局 / 容器类

| 组件 | 参数 | 默认值 | 说明 |
|---|---|---|---|
| `Surface` | `shadowElevation` | `0.dp` ⚠️ 默认无阴影 | 要阴影必须显式给 |
| `Surface` | `shape` | `RectangleShape` | 圆角要显式传 `RoundedCornerShape(...)` |
| `Surface` | `border` | `null` ⚠️ 默认无描边 | |
| `Scaffold` | `popupHost` | `{ MiuixPopupHost() }` | **默认已注入**，不用手动传 |
| `Scaffold` | `snackbarHost` | `{}`（空槽） | 槽位存在，官方 `SnackbarHost` 可直接放 |
| `Scaffold` | `floatingActionButtonPosition` / `floatingToolbarPosition` | `FabPosition.End` / `ToolbarPosition.BottomCenter` | |
| `FloatingToolbar` | `showDivider` | `false` ⚠️ 默认关 | |
| `FloatingNavigationBar` | `showDivider` | `false` ⚠️ 默认关 | 普通 `NavigationBar` 的 `showDivider` 默认 **true** |
| `TopAppBar` / `SmallTopAppBar` | `scrollBehavior` | `null` ⚠️ 默认 None | **不传就没有滚动联动**（大标题不会收合） |
| `TopAppBar` | `largeTitle` | 缺省取 `title` | 不传大标题就等于标题 |
| `TopAppBar` / `SmallTopAppBar` | `subtitle` | `""` | |
| `TopAppBar` / `SmallTopAppBar` | `bottomContent` | `{}` | |
| `TopAppBar` / `SmallTopAppBar` | `defaultWindowInsetsPadding` | `true` | 自己处理 insets 才传 false |
| `ProgressIndicator` | `progress` | `null` ⚠️ 默认 None | **null = 不定态动画**；给 0f~1f 才是确定进度 |
| `PullToRefresh` | `refreshThreshold`（`rememberPullToRefreshState`） | `0.25` | 拉过全行程 25% 触发；0.0 一拉就触发，1.0 要拉满 |
| `PullToRefresh` | `topAppBarScrollBehavior` / `onPullProgress` | `null` ⚠️ 默认 None | 不传则拿不到实时拖拽进度 |
| `BreadcrumbBar` | `highlightIndex` | `items.lastIndex` | **负数 = 关闭高亮与自动滚动** |
| `BreadcrumbBar` | `listState` | `null` ⚠️ 默认 None | 想跨重组保留横向滚动位置要外部 hoist |
| `NavigationRail` | `showDivider` | `true` | |
| `NavigationRail`（fixed 重载） | `expanded` | `false` ⚠️ 默认收起 | |
| `Card` | `onClick` / `onLongPress` | `null` ⚠️ 默认 None | **不传 `onClick` 就是静态卡片**，交互参数一律不生效 |
| `RadioButton` / `Checkbox` | `onClick` | 必填但可为 `null` | **`null` = 不可交互**（不是「无回调」） |
| `Switch` / `CheckboxPreference` | `onCheckedChange` | 可为 `null` | 同上 |

---

## 1. 两套弹层家族：Overlay 系 vs Window 系（官方原文前置条件）

**这是官方文档里唯一写进 frontmatter 的硬前置条件，原文照录。**

### 1.1 Overlay 系（9 个组件）——**必须有 Scaffold**

官方 frontmatter 原文：

```yaml
requiresScaffoldHost: true
prerequisites:
  - Must be used within `Scaffold` to provide `MiuixPopupHost`
  - Using outside `Scaffold` will cause popup content not to render
  - Multiple nested or side-by-side `Scaffold`s are supported without extra configuration
hostComponent: Scaffold
popupHost: MiuixPopupHost
```

正文里的 `::: danger Prerequisite` 原文：

> This component depends on `Scaffold` providing `MiuixPopupHost` to render popup content.
> It must be used within `Scaffold`, otherwise popup content will not render correctly.

**成员（9）**：`OverlayListPopup`、`OverlayCascadingListPopup`、`OverlayDropdownPreference`、
`OverlaySpinnerPreference`、`OverlayDropdownMenu`、`OverlayIconDropdownMenu`、
`OverlayIconCascadingDropdownMenu`、`OverlayBottomSheet`、`OverlayDialog`。

`index.md` 的 warning 也点名了其中几个：

> The Scaffold component provides a suitable container for cross-platform popup windows.
> Components such as `OverlayDialog`, `OverlayDropdownPreference`, `OverlaySpinnerPreference`,
> and `OverlayListPopup` are all implemented based on this and therefore need to be wrapped by this component.

`Scaffold` 文档补了两条我们容易忽略的事实（::: info / ::: tip 原文）：

> Why not use the official `Popup` and `Dialog` instead of creating our own popup window container?
> Because their cross-platform support is currently incomplete, with some parameters that cannot be modified.

> Each `Scaffold` automatically manages its own isolated popup state. Multiple nested or side-by-side
> `Scaffold`s work correctly without any extra configuration — no need to manually set `popupHost`.

### 1.2 Window 系（9 个组件）——**不需要 Scaffold**

官方 frontmatter 原文：

```yaml
requiresScaffoldHost: false
prerequisites:
  - Can be used anywhere, does not require `Scaffold` or `MiuixPopupHost`
  - Renders at window level
hostComponent: None
popupHost: None
```

**成员（9）**：`WindowListPopup`、`WindowCascadingListPopup`、`WindowDropdownPreference`、
`WindowSpinnerPreference`、`WindowDropdownMenu`、`WindowIconDropdownMenu`、
`WindowIconCascadingDropdownMenu`、`WindowBottomSheet`、`WindowDialog`。

实现方式官方说得很直白：**用平台 `Dialog` 渲染**（window level via `Dialog`），
所以自带大屏优化动画、系统返回手势关闭、以及 `LocalDismissState`。

### 1.3 同名兄弟的差异速查

| 能力 | Overlay 系 | Window 系 |
|---|---|---|
| 需要 `Scaffold` / `MiuixPopupHost` | **是（否则内容不渲染）** | 否 |
| 渲染层级 | Scaffold 内的 popup host（可用 `renderInRootScaffold` 调到最外层） | 平台 `Dialog`，window 层 |
| 大屏优化动画 / 系统返回手势 | 文档未单独声明（由 `Scaffold` 的 `MiuixPopupHost` 统一承载） | 组件文档明说自带 |
| 命名对应 | `OverlayXxx` | `WindowXxx` |

> **选型建议（依据官方前置条件）**：能用 Window 系就别引 Scaffold 依赖；但官方 demo 的页面骨架本来就是
> `Scaffold`，所以在页内用 Overlay 系更自然。**唯一硬红线：Overlay 系不许放在没有 Scaffold 的树里。**

---

## 2. Scaffold Components

### 2.1 Scaffold

- 📦 `top.yukonga.miuix.kmp.basic.Scaffold`
- **作用**：页面脚手架；同时是**全部 Overlay 系弹层的宿主**（见 §1.1）。
- **关键参数与默认值**

| 参数 | 默认值 | 说明 |
|---|---|---|
| `modifier` | `Modifier` | |
| `topBar` | `{}` | 一般放 `TopAppBar` / `SmallTopAppBar` |
| `bottomBar` | `{}` | 一般放 `NavigationBar` |
| `floatingActionButton` | `{}` | |
| `floatingActionButtonPosition` | `FabPosition.End` | `Start` / `Center` / `End` / `EndOverlay`（EndOverlay = 压在底栏上） |
| `floatingToolbar` | `{}` | |
| `floatingToolbarPosition` | `ToolbarPosition.BottomCenter` | 8 档：`TopStart` `CenterStart` `BottomStart` `TopEnd` `CenterEnd` `BottomEnd` `TopCenter` `BottomCenter` |
| `snackbarHost` | `{}` | ⚠️ 槽位**存在**；文档表格注释写「Miuix does not provide this component」，与 `snackbar.md` 冲突，见下方坑 |
| `popupHost` | `{ MiuixPopupHost() }` | **默认已注入**，不要手动覆盖 |
| `containerColor` | `MiuixTheme.colorScheme.surface` | |
| `contentWindowInsets` | `WindowInsets.systemBars.union(WindowInsets.displayCutout)` | |
| `content` | 必填 | `@Composable (PaddingValues) -> Unit`，**必须消费 padding** |

- **最小用法**

```kotlin
Scaffold(
    topBar = { SmallTopAppBar(title = "标题") },
    content = { paddingValues ->
        Box(Modifier.padding(paddingValues).fillMaxSize()) { Text("内容区") }
    },
)
```

- **坑**
  1. `content` 收到的是 `PaddingValues`，官方示例一律 `padding(top = paddingValues.calculateTopPadding(), start = 26.dp)`
     或 `LazyColumn(contentPadding = paddingValues)`——**不消费 padding 会被顶栏/底栏盖住**。
  2. 官方「Page Layout with Snackbar」示例用的是 **Material 的 `SnackbarHost`**（注释写着 requires Material components），
     而 `snackbar.md` 明确给了 miuix 自己的 `SnackbarHost`。**miuix 侧优先用 miuix 的**。
  3. 表格里 `snackbarHost` 的说明句「Miuix does not provide this component」是**文档自身的笔误**：
     `snackbar.md` 通篇在讲 miuix 的 `SnackbarHost` / `Snackbar` / `SnackbarHostState`。
     不要据此在计划文档里写「官方无 snackbarHost 槽」。

---

## 3. Basic Components

### 3.1 Surface

- 📦 `top.yukonga.miuix.kmp.basic.Surface`
- 🔁 **重载**：普通版（纯容器） / 可点版（多一个 `onClick`）。
- **关键参数与默认值**

| 参数 | 默认值 | 适用 |
|---|---|---|
| `shape` | `SurfaceDefaults.Shape` = `RectangleShape` | 两版 |
| `color` | `MiuixTheme.colorScheme.surface` | 两版 |
| `contentColor` | `MiuixTheme.colorScheme.onSurface` | 两版 |
| `border` | `null` ⚠️ | 两版 |
| `shadowElevation` | `SurfaceDefaults.ShadowElevation` = `0.dp` ⚠️ 默认无阴影 | 两版 |
| `onClick` | 必填（可点版） | 可点版 |
| `enabled` | `true` | 可点版 |
| `interactionSource` | `null` ⚠️ | 可点版 |
| `indication` | `LocalIndication.current` | 可点版 |

- **最小用法**

```kotlin
Surface(
    shape = RoundedCornerShape(16.dp),
    color = MiuixTheme.colorScheme.background,
    shadowElevation = 4.dp,
) { Text("Surface 内容", modifier = Modifier.padding(16.dp)) }
```

- **坑**：`Surface` **不是 Card**——默认 `RectangleShape` + 零阴影 + 零内边距，
  当卡片用必须自己给 shape/shadow/insideMargin；要「设置组卡片」请用 `Card`。

### 3.2 TopAppBar / SmallTopAppBar

- 📦 `top.yukonga.miuix.kmp.basic.TopAppBar`、`.SmallTopAppBar`、`.MiuixScrollBehavior`、`.rememberTopAppBarState`
- 🔁 **重载**：`TopAppBar`（大标题，可收合） / `SmallTopAppBar`（小标题，始终单行）。
- **关键参数与默认值**（两版基本一致）

| 参数 | 默认值 | 说明 |
|---|---|---|
| `title` | 必填 | 收合后显示的小标题 |
| `largeTitle` | **缺省取 `title`** | 仅 `TopAppBar` 有；展开时的大标题 |
| `color` | `MiuixTheme.colorScheme.surface` | 毛玻璃方案里传 `Color.Transparent` |
| `titleColor` | `MiuixTheme.colorScheme.onSurface` | |
| `largeTitleColor` | `MiuixTheme.colorScheme.onSurface` | 仅 `TopAppBar` |
| `subtitle` | `""` | 标题栏下方的副标题 |
| `subtitleColor` | `MiuixTheme.colorScheme.onSurfaceVariantSummary` | |
| `navigationIcon` | `{}` | |
| `actions` | `{}` | `RowScope` |
| `scrollBehavior` | `null` ⚠️ 默认 None | **不传就没有滚动联动** |
| `defaultWindowInsetsPadding` | `true` | |
| `titlePadding` | `TopAppBarDefaults.TitlePadding` = `26.dp` | |
| `navigationIconPadding` | `16.dp` | |
| `actionIconPadding` | `16.dp` | |
| `bottomContent` | `{}` | 标题栏下方的自定义区 |

- **默认常量**：`CollapsedHeight = 52.dp`、`SmallTopAppBarCenterHeight = 50.dp`、
  `LargeTitleBottomPadding = 4.dp`、`SubtitleBottomPadding = 8.dp`。
- **`MiuixScrollBehavior` 参数**：`state = rememberTopAppBarState()`、
  `canScroll = { true }`、`snapAnimationSpec = spring(stiffness = 2500f)`、`flingAnimationSpec = rememberSplineBasedDecay()`。
- **最小用法（带滚动联动）**

```kotlin
val scrollBehavior = MiuixScrollBehavior()
Scaffold(topBar = {
    TopAppBar(title = "标题", largeTitle = "大标题", scrollBehavior = scrollBehavior)
}) { padding ->
    LazyColumn(
        modifier = Modifier.fillMaxSize()
            .overScrollVertical()                                   // 官方：过度滚动要加在 scrollBehavior 之前
            .nestedScroll(scrollBehavior.nestedScrollConnection),   // 绑定顶栏联动
        contentPadding = PaddingValues(top = padding.calculateTopPadding()),
    ) { /* ... */ }
}
```

- **坑**
  1. **`scrollBehavior` 不传 = 大标题永远收不起来**（官方示例全靠这一条）。
  2. `nestedScroll` 必须在 `overScrollVertical()` **之后**——官方注释明写
     "If you want to add the overscroll effect, please add it before the scroll behavior"。
  3. 用 `SmallTopAppBar` 时没有 `largeTitle` / `largeTitleColor`。

### 3.3 NavigationBar / FloatingNavigationBar

- 📦 `top.yukonga.miuix.kmp.basic.NavigationBar`、`.NavigationBarDefaults`、`.NavigationBarItem`、
  `.FloatingNavigationBar`、`.FloatingNavigationBarItem`、`.NavigationBarDisplayMode`
- **作用**：底部导航；支持 **2~5 个 item**；`FloatingNavigationBar` 是浮动样式（仅图标+选中高亮）。
- **关键参数与默认值**

| 组件 | 参数 | 默认值 |
|---|---|---|
| `NavigationBar` | `color` | `MiuixTheme.colorScheme.surface` |
| `NavigationBar` | `showDivider` | `true` |
| `NavigationBar` | `defaultWindowInsetsPadding` | `true` |
| `NavigationBar` | `mode` | `NavigationBarDisplayMode.IconAndText` |
| `NavigationBarItem` / `FloatingNavigationBarItem` | `selected` / `onClick` / `icon` / `label` | 必填 |
| 同上 | `enabled` | `true` |
| 同上 | `colors` | `NavigationBarDefaults.navigationBarItemColors()` |
| 同上 | `badge` | `null` ⚠️ |
| `FloatingNavigationBar` | `color` | `MiuixTheme.colorScheme.surfaceContainer` |
| `FloatingNavigationBar` | `cornerRadius` | `FloatingToolbarDefaults.CornerRadius`（= `50.dp`） |
| `FloatingNavigationBar` | `horizontalAlignment` | `CenterHorizontally` |
| `FloatingNavigationBar` | `horizontalOutSidePadding` | `36.dp` |
| `FloatingNavigationBar` | `shadowElevation` | `1.dp` |
| `FloatingNavigationBar` | `showDivider` | `false` ⚠️ |

- **`NavigationBarDisplayMode`**：`IconAndText`（默认）/ `IconOnly` / `IconWithSelectedLabel`（始终显图标，选中才显文字）。
- **默认常量**：`ItemHeight = 64.dp`、`IconSize = 26.dp`、`LabelFontSize = 12.sp`、
  `IconTopPadding = 8.dp`、`BottomPadding = 8.dp`；
  透明度 `UnselectedAlpha = 0.4f`、`UnselectedPressedAlpha = 0.6f`、`SelectedPressedAlpha = 0.5f`。
  `FloatingNavigationBarDefaults`：`HorizontalOutSidePadding = 36.dp`、`ShadowElevation = 1.dp`、
  `HorizontalPadding = 12.dp`、`ItemSpacing = 12.dp`、`IconSize = 28.dp`、`IconPadding = 10.dp`。
- **颜色的透明度语义（文档明写）**：传入的是**基色**，未选中乘 `0.4`、未选中按下乘 `0.6`、
  选中按下乘 `0.5`；选中且未按下原样使用；`Color.Transparent` 在所有状态都保持透明。
- **最小用法**

```kotlin
var selectedIndex by remember { mutableIntStateOf(0) }
val items = listOf("首页", "我的", "设置")
val icons = listOf(MiuixIcons.VerticalSplit, MiuixIcons.Contacts, MiuixIcons.Settings)

Scaffold(bottomBar = {
    NavigationBar {
        items.forEachIndexed { index, label ->
            NavigationBarItem(
                selected = selectedIndex == index,
                onClick = { selectedIndex = index },
                icon = icons[index],
                label = label,
            )
        }
    }
})
```

- **坑**：普通栏默认 `showDivider = true`、浮动栏默认 `false`——想让两条栏观感统一必须显式对齐这一个参数。

### 3.4 NavigationRail

- 📦 `top.yukonga.miuix.kmp.basic.NavigationRail`、`.NavigationRailItem`、`.rememberNavigationRailState`
- 🔁 **两个重载（官方明写 "provides two overloads. Use one of them"）**
  1. **Fixed Layout**：`expanded: Boolean = false`（`false` = 固定收起）。
  2. **Expandable Layout**：`state: NavigationRailState`（必填）+ `expandContentDescription`
     （默认 `"Expand navigation rail"`）+ `collapseContentDescription`（默认 `"Collapse navigation rail"`），
     会显示展开/收起切换按钮并带过渡动画。
- **公共参数与默认值**

| 参数 | 默认值 |
|---|---|
| `modifier` | `Modifier` |
| `header` | `null` ⚠️（放 FAB / Logo） |
| `color` | `MiuixTheme.colorScheme.surface` |
| `showDivider` | `true` |
| `defaultWindowInsetsPadding` | `true` |
| `minWidth`（收起宽） | `80.dp` |
| `expandedWidth`（展开宽） | `240.dp` |
| `scrollState` | `rememberScrollState()` |

- **`NavigationRailItem`**：`selected` / `onClick` / `icon` / `label` 必填；`enabled = true`；`badge = null` ⚠️。
- **`NavigationRailState`**（`rememberNavigationRailState(initialValue)`）：`currentValue`、`isExpanded`、
  `expand()`、`collapse()`、`toggle()`。`NavigationRailValue` = `Collapsed` / `Expanded`。
- **默认常量**：`VerticalPadding = 24.dp`、`HeaderSpacing = 24.dp`、`IconSize = 28.dp`、
  `IconTextSpacing = 4.dp`、`ItemVerticalPadding = 12.dp`、`LabelFontSize = 12.sp`、
  `ExpandedLabelFontSize = 16.sp`、`ExpandedItemHorizontalMargin = 12.dp`、
  `ExpandedItemCornerRadius = 16.dp`、`CollapsedIndicatorVerticalPadding = 4.dp`、
  `ExpandedItemContentHorizontalPadding = 14.dp`、`ExpandedItemContentVerticalPadding = 14.dp`、
  `ExpandedItemIconTextSpacing = 16.dp`。
- **最小用法**

```kotlin
// 固定收起（默认）
NavigationRail { items.forEachIndexed { i, label ->
    NavigationRailItem(selected = i == 0, onClick = {}, icon = icons[i], label = label) } }

// 可展开
val railState = rememberNavigationRailState()
NavigationRail(state = railState) { /* NavigationRailItem(...) */ }
```

- **坑**：**两个重载只能用一个**；`state` 与 `expanded` 不要同时传。
  文档明写：Omit both `state` and `expanded` for a fixed collapsed rail。

### 3.5 TabRow / TabRowWithContour

- 📦 `top.yukonga.miuix.kmp.basic.TabRow`、`.TabRowWithContour`
- **作用**：横向可滚动标签栏；两种样式：标准 / 轮廓（contour）。
- 🔁 两个**独立组件**（不是重载），参数名相同但默认值不同：

| 参数 | `TabRow`（标准） | `TabRowWithContour`（轮廓） |
|---|---|---|
| `height` | `42.dp` | `45.dp` |
| `cornerRadius` | `12.dp` | `8.dp` |
| `minWidth` | `76.dp` | `62.dp` |
| `maxWidth` | `98.dp` | `84.dp` |
| `itemSpacing` | `9.dp` | `5.dp` |
| `contentAlignment` | `Alignment.Center` | `Alignment.Center` |
| `listState` | `null` ⚠️ | `null` ⚠️ |
| `interactionSource` | `null` ⚠️ | `null` ⚠️ |
| `indication` | `null` ⚠️ **默认无涟漪** | `null` ⚠️ |

- 必填：`tabs: List<String>`、`selectedTabIndex: Int`、`onTabSelected: (Int) -> Unit`；
  `colors` 默认 `TabRowDefaults.tabRowColors()`（`backgroundColor` / `contentColor` /
  `selectedBackgroundColor` / `selectedContentColor`）。
- **最小用法**

```kotlin
val tabs = listOf("推荐", "关注", "热门")
var selected by remember { mutableIntStateOf(0) }
TabRow(tabs = tabs, selectedTabIndex = selected, onTabSelected = { selected = it })
```

- **坑**
  1. `indication` 默认 `null`——**点击标签没有涟漪**，要反馈得显式传。
  2. 想跨重组保留横向滚动位置要自己 hoist `listState`（`rememberLazyListState()`）。
  3. 配合 Pager 时 `onTabSelected` 里要 `scope.launch { pagerState.animateScrollToPage(index) }`。

### 3.6 BreadcrumbBar

- 📦 `top.yukonga.miuix.kmp.basic.BreadcrumbBar`、`.BreadcrumbItem`、`.joinToPath`
- **作用**：面包屑路径条（胶囊项 + 箭头分隔）；**溢出时横向滚动，不折叠**（文档说明：因为 miuix 主要面向移动端）。
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `items: List<BreadcrumbItem>` | 必填 |
| `onItemClick: (Int) -> Unit` | 必填 |
| `highlightIndex` | `items.lastIndex`；**负数 = 关闭高亮与自动滚动** |
| `enabled` | `true`（禁用后仍可横向滚动） |
| `colors` | `BreadcrumbBarDefaults.breadcrumbBarColors()` |
| `insideMargin` | `PaddingValues(horizontal = 12.dp, vertical = 8.dp)` |
| `itemMaxWidth` | `160.dp`（超出截断） |
| `listState` | `null` ⚠️ |
| `interactionSource` | `null` ⚠️ |
| `indication` | `LocalIndication.current` |

- **`BreadcrumbItem`**：`path: String` 必填（`joinToPath` 用它拼完整路径）；`text: String? = null`（为 null 时显示 `path`）。
- **默认常量**：`ItemHeight = 32.dp`、`ItemHorizontalPadding = 10.dp`（= 圆角，做出半圆端）、`ItemMaxWidth = 160.dp`。
- **`joinToPath`**：`items.joinToPath("/")` → `"/storage/emulated/0/DataBackup/..."`。
- **最小用法**

```kotlin
val items = listOf(
    BreadcrumbItem(path = "/storage/emulated/0", text = "内部存储"),
    BreadcrumbItem(path = "DataBackup"),
)
BreadcrumbBar(items = items, onItemClick = { index -> /* 跳到第 index 段 */ })
```

- **坑**：`highlightIndex` 与 `items` **解耦**——可以展示完整路径却高亮任意一段（官方明确这是设计意图，
  用于「用户回退到父目录」）；条形会自动滚动让高亮项可见。

### 3.7 Card

- 📦 `top.yukonga.miuix.kmp.basic.Card`、`.CardDefaults`；`top.yukonga.miuix.kmp.utils.PressFeedbackType`
- **作用**：设置组 / 信息分组的标准容器；**静态**与**交互**两种用法共用一个签名。
- **关键参数与默认值**（表格「Applies To」列标注：`All` = 两用，`Interactive` = 仅可点卡片生效）

| 参数 | 默认值 | 适用 |
|---|---|---|
| `modifier` | `Modifier` | All |
| `cornerRadius` | `CardDefaults.CornerRadius` = `16.dp` | All |
| `insideMargin` | `CardDefaults.InsideMargin` = `PaddingValues(0.dp)` | All |
| `colors` | `CardDefaults.defaultColors()`（`color` / `contentColor`） | All |
| `pressFeedbackType` | **`PressFeedbackType.None`** ⚠️ 默认关 | Interactive |
| `showIndication` | **`false`** ⚠️ 默认关 | Interactive |
| `holdDownState` | `false` ⚠️ | Interactive |
| `onClick` | `null` ⚠️ | Interactive |
| `onLongPress` | `null` ⚠️ | Interactive |
| `content` | 必填（`ColumnScope`） | All |

- **官方原文警示**：`::: warning Some properties are only available when creating an interactive card! :::`
- **最小用法（官方 Interactive Card 配方，逐字照抄参数）**

```kotlin
Card(
    modifier = Modifier.padding(16.dp),
    pressFeedbackType = PressFeedbackType.Sink, // 下沉缩放反馈
    showIndication = true,                      // 点击指示
    onClick = { /* 处理点击 */ },
    onLongPress = { /* 处理长按 */ },
) { Text("Interactive Card") }
```

- **坑**
  1. **两个「手感参数」默认全关**：不传 `pressFeedbackType` / `showIndication` 时，
     即便传了 `onClick` 也是「能点但没反馈」。这就是我们仓库「点击没手感」的直接原因。
  2. `insideMargin` 默认是 `PaddingValues(0.dp)`——**Card 自己不给内边距**，
     设置行靠 `BasicComponentDefaults.InsideMargin`（`PaddingValues(16.dp)`）撑，自己拼 `Row { Text }` 就没有。
  3. `holdDownState` 用于「弹出对话框期间卡片保持按下态」（配 `IconButton` 的同类参数一起用）。

### 3.8 BasicComponent

- 📦 `top.yukonga.miuix.kmp.basic.BasicComponent`、`.BasicComponentDefaults`、`.BasicComponentColors`
- **作用**：所有 Preference 行（Arrow/Switch/Checkbox/RadioButton/Slider…）的基座；
  「标题+摘要+首尾槽+底部槽」的标准行。
- 🔁 **两个重载**
  1. **title/summary 版**：`title` / `summary` 走主题排版。
  2. **custom content 版**：没有 `title`/`summary`，改为 `content: @Composable ColumnScope.() -> Unit`（必填），
     用于完全自定义行内布局但仍复用容器与交互。

| 参数 | 默认值 |
|---|---|
| `title` / `summary` | `null` ⚠️（title/summary 版） |
| `titleColor` / `summaryColor` | `BasicComponentDefaults.titleColor()` / `.summaryColor()` |
| `startAction` | `null` ⚠️ |
| `endActions` | `null` ⚠️（`RowScope`） |
| `bottomAction` | `null` ⚠️ |
| `insideMargin` | `BasicComponentDefaults.InsideMargin` = `PaddingValues(16.dp)` |
| `onClick` | `null` ⚠️ |
| `onClickLabel` | `null` ⚠️（无障碍标签） |
| `role` | `null` ⚠️（无障碍语义角色） |
| `holdDownState` | `false` ⚠️ |
| `enabled` | `true` |
| `interactionSource` | `null` ⚠️ |

- **`BasicComponentColors`** = `color`（正常）+ `disabledColor`（禁用）。
- **最小用法**

```kotlin
BasicComponent(
    title = "Wi-Fi",
    summary = "已连接 MIUI-WiFi",
    startAction = { Icon(MiuixIcons.Contacts, null, Modifier.padding(end = 16.dp)) },
    onClick = { /* ... */ },
)
```

- **坑**：`endActions` 是 `RowScope`——里面直接写多个元素即可横向排列，不要自己再包一层 `Row`。
  想完全自定义行内容用第二个重载，**别再手拼 `Row { Text }`**（会丢掉官方内边距与按压语义）。

### 3.9 Button / TextButton

- 📦 `top.yukonga.miuix.kmp.basic.Button`、`.TextButton`、`.ButtonDefaults`
- 🔁 **两个组件**：`Button`（`content: @Composable RowScope.() -> Unit`，可放图标+文字）/
  `TextButton`（`text: String`，纯文字，更省事）。
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `onClick` | 必填 |
| `enabled` | `true` |
| `cornerRadius` | `ButtonDefaults.CornerRadius` = `16.dp` |
| `minWidth` | `58.dp` |
| `minHeight` | `40.dp` |
| `colors` | `Button` → `ButtonDefaults.buttonColors()`（次要）；`TextButton` → `textButtonColors()` |
| `insideMargin` | `PaddingValues(horizontal = 16.dp, vertical = 13.dp)` |
| `interactionSource` | `null` ⚠️ |
| `indication` | `LocalIndication.current` |
| `textStyle`（仅 TextButton） | `null` → 落到 `MiuixTheme.textStyles.button` |

- **`ButtonDefaults` 四个工厂**：`buttonColors()`（次要实心）、`buttonColorsPrimary()`（主实心）、
  `textButtonColors()`（次要文字）、`textButtonColorsPrimary()`（主文字，官方确认按钮首选）。
- **最小用法**

```kotlin
Button(onClick = {}, colors = ButtonDefaults.buttonColorsPrimary()) { Text("主按钮") }
TextButton(text = "文字按钮", onClick = {})
```

- **坑**：官方示例里「确认」一律 `colors = ButtonDefaults.textButtonColorsPrimary()`——
  不加这行，确认和取消长得一样，层级就没了。

### 3.10 IconButton

- 📦 `top.yukonga.miuix.kmp.basic.IconButton`、`.IconButtonDefaults`
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `onClick` | 必填 |
| `enabled` | `true` |
| `holdDownState` | `false` ⚠️ 默认关 |
| `backgroundColor` | `Color.Unspecified`（跟随主题，**不是透明**） |
| `cornerRadius` | `40.dp` |
| `minWidth` / `minHeight` | `40.dp` / `40.dp` |

- **最小用法**

```kotlin
IconButton(onClick = {}, holdDownState = showDialog) {
    Icon(MiuixIcons.Favorites, contentDescription = "收藏")
}
```

- **坑**：`holdDownState` 官方定位是「弹窗打开期间按钮保持按下态」——
  示例里就是 `holdDownState = showDialog`，和 `OverlayDialog` 的 `show` 绑同一个 state。

### 3.11 Text

- 📦 `top.yukonga.miuix.kmp.basic.Text`
- 🔁 **重载**：`Text(String)` / `Text(AnnotatedString)` / 各自的 **`ColorProducer` 版本**
  （`Text(text, color: ColorProducer, ...)`，参数与上面完全一致，只是颜色在绘制期读取）。
- **关键参数与默认值**

| 参数 | 默认值 | 说明 |
|---|---|---|
| `text` | 必填 | `String` 或 `AnnotatedString` |
| `color` | `Color.Unspecified` | 跟随主题 |
| `style` | **`MiuixTheme.textStyles.main`** | ★ 字阶入口 |
| `fontSize` / `fontWeight` / `fontFamily` / `lineHeight` / `letterSpacing` | 全部 `Unspecified` / `null` | **显式传就整体覆盖 style** |
| `autoSize` | `null` ⚠️ | `TextAutoSize.StepBased(minFontSize, maxFontSize, stepSize)` |
| `overflow` | `TextOverflow.Clip` | 截断要配 `Ellipsis` |
| `maxLines` / `minLines` | `Int.MAX_VALUE` / `1` | |
| `softWrap` | `true` | |
| `textAlign` / `textDecoration` / `fontStyle` | `null` | |
| `onTextLayout` | `null`（AnnotatedString 版为 `{}`） | |
| `inlineContent`（仅 AnnotatedString） | `mapOf()` | |

- **官方字阶示例**：`MiuixTheme.textStyles.headline1` / `.subtitle` / `.body2` / `.main`。
- **最小用法**

```kotlin
Text(text = "标题", style = MiuixTheme.textStyles.headline1, color = MiuixTheme.colorScheme.onBackground)
```

- **坑**
  1. **`fontSize` 一传，`style` 里的字族/字重/行高就全被顶掉**——这是「字阶不统一 → 廉价感」的机械原因。
     官方 demo 的口径是 `textStyles` 为主、裸 `fontSize` 是例外。
  2. 富文本混排用 `buildAnnotatedString { withStyle(...) { append(...) } }`；
     可点链接用 `addLink(LinkAnnotation.Url(...), start, end)`。
  3. 颜色每帧变（动画/滚动）时用 `ColorProducer` 重载 `color = { ... }`，避免重组。

### 3.12 SmallTitle

- 📦 `top.yukonga.miuix.kmp.basic.SmallTitle`、`.SmallTitleDefaults`
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `text` | 必填 |
| `textColor` | `MiuixTheme.colorScheme.onBackgroundVariant` |
| `insideMargin` | `SmallTitleDefaults.InsideMargin` = `PaddingValues(28.dp, 8.dp)` |

- **最小用法**

```kotlin
Column {
    SmallTitle(text = "设置")
    Card(Modifier.padding(horizontal = 12.dp).padding(bottom = 12.dp)) { SwitchPreference(...) }
    HorizontalDivider(Modifier.padding(horizontal = 12.dp))
    SmallTitle(text = "高级设置")
}
```

- **坑**：默认内边距是**左 28dp**（不是 16dp）——自己改 `insideMargin` 去对齐 16dp 网格时，
  会与官方设置页骨架不一致。官方骨架就是「`SmallTitle` + `Card(padding 12dp)`」这套组合。

### 3.13 TextField

- 📦 `top.yukonga.miuix.kmp.basic.TextField`、`.TextFieldDefaults`
- 🔁 **两个重载**：**value/onValueChange 版**（`value: String` 或 `TextFieldValue`）与
  **state-based 版**（`state: TextFieldState`，官方提示参考 Android 官方 state-based 文档）。
- **关键参数与默认值**

| 参数 | 默认值 | 两版差异 |
|---|---|---|
| `value` + `onValueChange` | 必填 | 仅 value 版 |
| `state: TextFieldState` | 必填 | 仅 state 版 |
| `insideMargin` | `TextFieldDefaults.InsideMargin` = `DpSize(16.dp, 16.dp)` | 两版 |
| `cornerRadius` | `16.dp` | 两版 |
| `colors` | `textFieldColors()` | 两版 |
| `label` | `""` | 两版 |
| `useLabelAsPlaceholder` | `false` ⚠️ | 两版 |
| `enabled` / `readOnly` | `true` / `false` ⚠️ | 两版 |
| `textStyle` | `MiuixTheme.textStyles.main` | 两版 |
| `leadingIcon` / `trailingIcon` | `null` ⚠️ | 两版 |
| `singleLine` / `maxLines` / `minLines` | `false` / (单行时 1，否则 `Int.MAX_VALUE`) / `1` | 仅 value 版 |
| `visualTransformation` | `VisualTransformation.None` | 仅 value 版 |
| `keyboardActions` | `KeyboardActions.Default` | 仅 value 版 |
| `inputTransformation` / `outputTransformation` / `onKeyboardAction` | `null` ⚠️ | 仅 state 版 |
| `lineLimits` | `TextFieldLineLimits.Default` | 仅 state 版 |
| `cursorBrush` | `SolidColor(colors.borderColor)` | 两版 |
| `interactionSource` | `null` ⚠️ | 两版 |

- **`textFieldColors()` 默认值**：`backgroundColor = secondaryContainer`、`labelColor = onSecondaryContainer`、
  `borderColor = primary`（未指定的参数回落到主题默认）。
- **最小用法**

```kotlin
var text by remember { mutableStateOf("") }
TextField(value = text, onValueChange = { text = it }, label = "用户名")
```

- **坑**
  1. label 默认**浮到顶部**；想让 label 当占位符必须 `useLabelAsPlaceholder = true`。
  2. 单行输入要显式 `singleLine = true`（或 `maxLines = 1`）。
  3. 密码框三件套：`visualTransformation = PasswordVisualTransformation()` +
     `keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)` + `trailingIcon` 切换显隐。

### 3.14 Switch

- 📦 `top.yukonga.miuix.kmp.basic.Switch`、`.SwitchDefaults`、`.SwitchColors`
- **关键参数与默认值**：`checked` 必填；`onCheckedChange` **可为 `null`**；`colors = SwitchDefaults.switchColors()`；`enabled = true`。
- **`SwitchColors` 八个必填项**：`checkedThumbColor`、`uncheckedThumbColor`、
  `disabledCheckedThumbColor`、`disabledUncheckedThumbColor`、
  `checkedTrackColor`、`uncheckedTrackColor`、`disabledCheckedTrackColor`、`disabledUncheckedTrackColor`。
- **最小用法**

```kotlin
var checked by remember { mutableStateOf(false) }
Switch(checked = checked, onCheckedChange = { checked = it })
```

- **坑**：`onCheckedChange` 传 `null` 表示**不可交互**（不是「无回调但仍可拨动」）；
  设置页里应当用 `SwitchPreference`（自带标题/摘要/整行点击），不要裸 `Switch` + 手拼 `Row`。

### 3.15 Checkbox

- 📦 `top.yukonga.miuix.kmp.basic.Checkbox`、`.CheckboxDefaults`、`.CheckboxColors`
- **三态**：`ToggleableState.On` / `Off` / `Indeterminate`（不定态画一道横杠；**配色与选中态共用**）。
- **关键参数与默认值**：`state: ToggleableState` 必填；`onClick` 必填但**可为 `null`（不可交互）**；
  `colors = CheckboxDefaults.checkboxColors()`；`enabled = true`。
- **最小用法**

```kotlin
var state by remember { mutableStateOf(ToggleableState.Off) }
Checkbox(
    state = state,
    onClick = { state = if (state == ToggleableState.On) ToggleableState.Off else ToggleableState.On },
)
```

- **坑**：不定态**没有单独颜色**（文档明写 shares the same colors as the checked state）——
  想区分只能自己换 `colors`。父子勾选联动用 `derivedStateOf` 推父态。

### 3.16 RadioButton

- 📦 `top.yukonga.miuix.kmp.basic.RadioButton`、`.RadioButtonDefaults`、`.RadioButtonColors`
- **关键参数与默认值**：`selected` 必填；`onClick` 必填但**可为 `null`（不可交互）**；
  `colors = RadioButtonDefaults.radioButtonColors()`；`enabled = true`。
- **`RadioButtonColors`**：`selectedColor`（选中勾色）、`disabledSelectedColor`（禁用且选中）。
- **最小用法**

```kotlin
RadioButton(selected = true, onClick = { /* ... */ })
// 单选组用 RadioButtonPreference 更省事
```

- **坑**：单选组必须自己维护 `selectedIndex`，组件**不管理互斥**；
  官方示例一律用 `RadioButtonPreference` 而不是裸 `RadioButton`。

### 3.17 Slider / VerticalSlider / RangeSlider

- 📦 `top.yukonga.miuix.kmp.basic.Slider`、`.VerticalSlider`、`.RangeSlider`、`.SliderDefaults`
- 🔁 **三个组件**：水平单值 / 垂直单值 / 区间双值。参数几乎一致，差异见下表。
- **关键参数与默认值**

| 参数 | `Slider` | `VerticalSlider` | `RangeSlider` |
|---|---|---|---|
| `value` | `Float` | `Float` | `ClosedFloatingPointRange<Float>` |
| `onValueChange` | `(Float) -> Unit` | `(Float) -> Unit` | `(Range) -> Unit` |
| `valueRange` | `0f..1f` | `0f..1f` | `0f..1f` |
| `steps` | `0`（连续） | `0` | `0` |
| `onValueChangeFinished` | `null` ⚠️ | `null` ⚠️ | `null` ⚠️ |
| `reverseDirection` | `false` | `false`（false = 下→上递增） | — |
| 尺寸参数 | `height = 28.dp` | `width = 28.dp` | `height = 28.dp` |
| `colors` | `sliderColors()` | `sliderColors()` | `sliderColors()` |
| `hapticEffect` | `DefaultHapticEffect`（= `Edge`） | 同 | 同 |
| `showKeyPoints` | `false` ⚠️ | `false` ⚠️ | `false` ⚠️ |
| `keyPoints` | `null` ⚠️ | `null` ⚠️ | `null` ⚠️ |
| `magnetThreshold` | `0.02f` | `0.02f` | `0.02f` |
| `effect`（仅 Vertical） | — | `false` ⚠️ | — |

- **`SliderHapticEffect`**：`None`（不震）/ `Edge`（默认，两端震）/ `Step`（每档震）。
- **默认常量**：`MinHeight = 28.dp`、`KeyPointRadius = 3.855.dp`、`DefaultHapticEffect = SliderHapticEffect.Edge`。
- **`SliderColors`**：`foregroundColor`、`disabledForegroundColor`、`backgroundColor`、
  `disabledBackgroundColor`、`thumbColor`、`disabledThumbColor`、`keyPointColor`、`keyPointForegroundColor`。
- **最小用法**

```kotlin
var value by remember { mutableFloatStateOf(0.5f) }
Slider(value = value, onValueChange = { value = it })
```

- **坑**
  1. **触感默认只有两端**（`Edge`）；「每档一格」要 `hapticEffect = SliderDefaults.SliderHapticEffect.Step`。
  2. 刻度点要**两个参数一起给**：`showKeyPoints = true` **且** `keyPoints = listOf(...)`；
     只开 `showKeyPoints` 什么都不画。
  3. `steps = 3` 配 `1f..5f` 得到 5 个离散值（含两端），不是 3 个——官方注释里写明了这点。

### 3.18 NumberPicker

- 📦 `top.yukonga.miuix.kmp.basic.NumberPicker`、`.NumberPickerDefaults`、`.NumberPickerColors`
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `value` / `onValueChange` | 必填（越界会被 coerce） |
| `enabled` | `true` |
| `range` | `0..10` |
| `label` | `{ it.toString() }` |
| `visibleItemCount` | `5`（**必须奇数且 ≥ 3**） |
| `wrapAround` | `false` ⚠️ 默认关 |
| `colors` | `NumberPickerDefaults.colors()` |
| `textStyle` | `MiuixTheme.textStyles.title1` |
| `itemHeight` | `NumberPickerDefaults.ItemHeight` = `45.dp` |

- **`NumberPickerColors`**：`selectedTextColor` / `unselectedTextColor` / `disabledSelectedTextColor` / `disabledUnselectedTextColor`。
- **最小用法**

```kotlin
var value by remember { mutableIntStateOf(5) }
NumberPicker(value = value, onValueChange = { value = it }, range = 0..10)
```

- **坑**：`wrapAround = true` 才无限循环（默认关）；做时间选择器用两个 Picker + `Modifier.weight(1f)` + `label` 补零。

### 3.19 ProgressIndicator（三种）

- 📦 `top.yukonga.miuix.kmp.basic.LinearProgressIndicator`、`.CircularProgressIndicator`、`.InfiniteProgressIndicator`、`.ProgressIndicatorDefaults`
- 🔁 **三个独立组件**：线性条 / 圆环 / 无限旋转（轨道+小圆点）。

| 组件 | 参数与默认值 |
|---|---|
| `LinearProgressIndicator` | `progress = null` ⚠️（null = 不定态）；`colors = progressIndicatorColors()`；`height = 6.dp` |
| `CircularProgressIndicator` | `progress = null` ⚠️；`colors = progressIndicatorColors()`；`strokeWidth = 4.dp`；`size = 30.dp` |
| `InfiniteProgressIndicator` | `color = Color.Gray`；`size = 20.dp`；`strokeWidth = 2.dp`；`orbitingDotSize = 2.dp` |

- **`ProgressIndicatorColors`**：`foregroundColor` / `disabledForegroundColor` / `backgroundColor`。
- **最小用法**

```kotlin
LinearProgressIndicator(progress = 0.3f)   // 确定进度
CircularProgressIndicator()                // 不传 progress = 不定态
InfiniteProgressIndicator(color = MiuixTheme.colorScheme.primary)
```

- **坑**：`progress` 默认就是 `null`——**不传不是「0%」，而是「转圈动画」**。
  确定进度必须给 0f~1f。

### 3.20 Snackbar / SnackbarHost / SnackbarHostState

- 📦 `top.yukonga.miuix.kmp.basic.Snackbar`、`.SnackbarHost`、`.SnackbarHostState`、
  `.SnackbarDuration`、`.SnackbarResult`、`.SnackbarDefaults`、`.SnackbarColors`
- **关键参数与默认值**

`SnackbarHostState.showSnackbar(...)`（suspend）：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `message` | 必填 | |
| `actionLabel` | `null` ⚠️ | 不传就没有动作按钮 |
| `withDismissAction` | `false` ⚠️ | 不传就没有关闭叉 |
| `duration` | `SnackbarDuration.Short` | 约 4 秒；`Long` 约 10 秒；`Indefinite` 直到手动关；`Custom(ms)` |

`SnackbarHost`：`state` 必填；`canSwipeToDismiss = true`；`content = { Snackbar(it) }`。
`Snackbar`：`cornerRadius = 16.dp`；`colors = snackbarColors()`；`insideMargin = PaddingValues(all = 12.dp)`。

- **`SnackbarDefaults` 常量**：`CornerRadius = 16.dp`、`InsideMargin = PaddingValues(all = 12.dp)`、
  `OuterPadding = PaddingValues(start = 12.dp, end = 12.dp, top = 8.dp)`、
  `ActionCornerRadius = 50.dp`、`ActionInsideMargin = PaddingValues(horizontal = 12.dp, vertical = 0.dp)`。
- **`SnackbarColors`**：`containerColor`、`contentColor`、`actionContentColor`、
  `dismissActionContentColor`、`actionContainerColor`。默认用**反色表面**（浅色主题下是深条）。
  动作标签渲染成实心胶囊：`actionContainerColor` 是底、`actionContentColor` 是字，**要改就一起改**。
- **辅助 API**：`newestSnackbarData()` / `oldestSnackbarData()`（配 `dismiss()` / `performAction()`）。
- **最小用法**

```kotlin
val snackbarHostState = remember { SnackbarHostState() }
val scope = rememberCoroutineScope()

Scaffold(snackbarHost = { SnackbarHost(state = snackbarHostState) }) { padding ->
    TextButton(text = "提示", onClick = {
        scope.launch { snackbarHostState.showSnackbar("这是一条短消息") }
    }, modifier = Modifier.padding(padding))
}
```

- **坑**：`showSnackbar` 是 **suspend**，必须在协程里调；
  带动作时要读返回值 `SnackbarResult.ActionPerformed` / `.Dismissed` 区分「点了」和「超时了」。

### 3.21 Tooltip（TooltipBox / PlainTooltip / RichTooltip）

- 📦 `top.yukonga.miuix.kmp.basic.TooltipBox`、`.RichTooltipBox`、`.PlainTooltip`、`.RichTooltip`、
  `.TooltipState`、`.rememberTooltipState`、`.TooltipDefaults`、`.TooltipAnchorPosition`
- 🔁 **重载三档**
  1. `TooltipBox(positionProvider, tooltip, state, ...)`：全手动。
  2. `TooltipBox(text = ..., ...)`：纯文字便利版，`state = rememberTooltipState(isPersistent = false)`。
  3. `RichTooltipBox(text, title, actionText, onActionClick, ...)`：富提示便利版，
     `state = rememberTooltipState(isPersistent = true)`，**且自带 `focusable = true`**。
- **关键参数与默认值**

`TooltipBox`：`positionProvider` / `tooltip` / `state` 必填；`focusable = false` ⚠️；
`enableUserInput = true`。`rememberTooltipState`：`initialIsVisible = false`、`isPersistent = false`、
`mutatorMutex = BasicTooltipDefaults.GlobalMutatorMutex`（全局只有一个 tooltip 可见）。

- **`TooltipDefaults` 常量**：`SpacingBetweenTooltipAndAnchor = 8.dp`、`PlainTooltipMaxWidth = 200.dp`、
  `PlainTooltipCornerRadius = 12.dp`、`PlainTooltipInsideMargin = PaddingValues(horizontal = 12.dp, vertical = 8.dp)`、
  `RichTooltipMaxWidth = 320.dp`、`RichTooltipCornerRadius = 16.dp`、
  `RichTooltipInsideMargin = PaddingValues(all = 16.dp)`、`RichTooltipActionCornerRadius = 8.dp`、
  `RichTooltipActionInsideMargin = PaddingValues(horizontal = 12.dp, vertical = 6.dp)`、
  `caretSize = DpSize(16.dp, 8.dp)`。
- **定位**：`TooltipAnchorPosition` = `Above` / `Below`（默认）/ `Left` / `Right` / `Start` / `End`；
  十字轴居中，空间不够自动翻到对侧。
- **颜色**：plain 用反色表面（`onSecondaryVariant` / `secondaryVariant`）；
  rich 用普通 `surfaceContainer`（`richTooltipColors()`：`containerColor` / `contentColor` /
  `titleContentColor` / `actionContentColor`）。
- **最小用法**

```kotlin
TooltipBox(text = "搜索") {
    IconButton(onClick = {}) { Icon(MiuixIcons.Basic.Search, contentDescription = "搜索") }
}
```

- **坑**
  1. **尖角默认没有**（`caretShape = null`）——要指向锚点必须传 `caretShape = TooltipDefaults.caretShape()`。
  2. **RichTooltip 必须 `focusable = true`**，否则外部点击关不掉、action 也点不到
     （`RichTooltipBox` 已经替你设好；手写 `TooltipBox` + `RichTooltip` 时要自己加）。
  3. `isPersistent = false` 会自动消失；`true` 要 `dismiss()` / 外部点击 / 返回键才消失。
  4. `show()` 是 suspend，要 `scope.launch { state.show() }`。

### 3.22 Badge / BadgedBox

- 📦 `top.yukonga.miuix.kmp.basic.Badge`、`.BadgedBox`、`.BadgeDefaults`
- **关键参数与默认值**

| 组件 | 参数 | 默认值 |
|---|---|---|
| `Badge` | `containerColor` | `BadgeDefaults.containerColor` = `MiuixTheme.colorScheme.error` |
| `Badge` | `contentColor` | `BadgeDefaults.contentColor` = `MiuixTheme.colorScheme.onError` |
| `Badge` | `content` | `null` ⚠️ **为 null 时渲染成小圆点**；有内容则撑开 |
| `BadgedBox` | `badge` / `content` | 必填（均为 `BoxScope` 槽） |

- **尺寸常量**：`BadgeDefaults.Size = 6.dp`（无内容的小点）、`LargeSize = 16.dp`（有内容）。
- **最小用法**

```kotlin
BadgedBox(badge = { Badge { Text("99+") } }) {
    Icon(MiuixIcons.Settings, contentDescription = "设置")
}
// 无内容 = 小圆点：BadgedBox(badge = { Badge() }) { ... }
```

- **坑**：`content` 为 `null` 与传空 lambda **不是一回事**——前者是小圆点，后者会撑成 16dp 的空壳。

### 3.23 Icon

- 📦 `top.yukonga.miuix.kmp.basic.Icon`
- 🔁 **四个重载**：`ImageVector` / `ImageBitmap` / `Painter` / `Painter + ColorProducer`
  （最后一个把颜色读取推迟到绘制期，用于每帧变化的 tint，避免重组）。
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `imageVector` / `bitmap` / `painter` | 必填（三选一） |
| `tint` | **`LocalContentColor.current`**（跟随父组件内容色） |
| `tint: ColorProducer?`（第四重载） | 必填；`null` = 不染色 |
| `contentDescription` | 必填（可为 null，但无障碍应给） |
| `modifier` | `Modifier` |

- **最小用法**

```kotlin
Icon(imageVector = MiuixIcons.Favorites, contentDescription = "收藏")
Icon(painter = painterResource(Res.drawable.ic_custom), contentDescription = "自定义", tint = Color.Unspecified)
```

- **坑**
  1. `Icon` 是**单色图标专用**组件，会染色。多色图片、或者不想跟随图标尺寸的图，
     官方明说要改用 `androidx.compose.foundation.Image`。
  2. 想保留原色传 `tint = Color.Unspecified`。
  3. 需要可点就**包 `IconButton`**（自带 miuix 触感），不要自己加 `clickable`。

### 3.24 FloatingActionButton

- 📦 `top.yukonga.miuix.kmp.basic.FloatingActionButton`、`.FloatingActionButtonDefaults`
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `onClick` | 必填 |
| `shape` | `CircleShape` |
| `containerColor` | `MiuixTheme.colorScheme.primary` |
| `shadowElevation` | `4.dp` |
| `minWidth` / `minHeight` | `60.dp` / `60.dp` |

- **最小用法**

```kotlin
FloatingActionButton(onClick = {}) { Icon(MiuixIcons.Add, contentDescription = "添加") }
```

- **坑**：**扩展 FAB 不是另一个组件**——官方做法是 `shape = RoundedCornerShape(16.dp)` +
  `minWidth = 120.dp` + 内部 `Row { Icon; Spacer; Text }`。放到页面里用 `Scaffold(floatingActionButton = {...})`。

### 3.25 FloatingToolbar

- 📦 `top.yukonga.miuix.kmp.basic.FloatingToolbar`、`.FloatingToolbarDefaults`、`.ToolbarPosition`
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `color` | `FloatingToolbarDefaults.defaultColor()` = `MiuixTheme.colorScheme.surfaceContainer` |
| `cornerRadius` | `50.dp` |
| `outSidePadding` | `PaddingValues(12.dp, 8.dp)` |
| `shadowElevation` | `4.dp` |
| `showDivider` | `false` ⚠️ 默认关 |
| `content` | 必填 |

- **位置由父级决定**：放 `Scaffold(floatingToolbar = { ... }, floatingToolbarPosition = ...)`；
  `ToolbarPosition` 8 档见 §2.1（默认 `BottomCenter`）。
- **最小用法**

```kotlin
Scaffold(
    floatingToolbar = {
        FloatingToolbar {
            Row(Modifier.padding(8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                IconButton(onClick = {}) { Icon(MiuixIcons.Edit, contentDescription = "编辑") }
                IconButton(onClick = {}) { Icon(MiuixIcons.Delete, contentDescription = "删除") }
            }
        }
    },
    floatingToolbarPosition = ToolbarPosition.BottomCenter,
)
```

- **坑**：横向还是纵向排布**由你自己在 content 里用 `Row`/`Column` 决定**，
  组件本身只管圆角容器、阴影与位置。默认圆角 `50.dp` 已接近胶囊，改小了会失去 miuix 观感。

### 3.26 Divider（HorizontalDivider / VerticalDivider）

- 📦 `top.yukonga.miuix.kmp.basic.HorizontalDivider`、`.VerticalDivider`、`.DividerDefaults`
- **关键参数与默认值**（两者一致）：`thickness = DividerDefaults.Thickness` = **`0.75.dp`**；
  `color = MiuixTheme.colorScheme.dividerLine`；`modifier = Modifier`。
- **最小用法**

```kotlin
Column { Text("上"); HorizontalDivider(); Text("下") }
Row { Text("左"); VerticalDivider(Modifier.height(24.dp)); Text("右") }
```

- **坑**：厚度是 **0.75dp**（不是 1dp）——为了在 2x/3x 屏上渲染成 1.5~2.25px 的「细线」。
  自己写 `1.dp` 会比官方粗一档。行间分割线官方一律配 `Modifier.padding(horizontal = 12.dp)`。

### 3.27 PullToRefresh

- 📦 `top.yukonga.miuix.kmp.basic.PullToRefresh`、`.rememberPullToRefreshState`、`.PullToRefreshDefaults`、`.PullToRefreshState`
- **官方前置条件**：`::: warning This component is only available in touch-enabled environments. :::`
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `isRefreshing` | 必填 |
| `onRefresh` | 必填 |
| `pullToRefreshState` | `rememberPullToRefreshState()` |
| `contentPadding` | `PaddingValues(0.dp)` |
| `topAppBarScrollBehavior` | `null` ⚠️ |
| `color` | `PullToRefreshDefaults.color` = `Color.Gray` |
| `circleSize` | `20.dp` |
| `refreshTexts` | `["Pull down to refresh", "Release to refresh", "Refreshing...", "Refreshed successfully"]` |
| `refreshTextStyle` | `TextStyle(fontSize = 14.sp, fontWeight = Bold, color = color)` |
| `onPullProgress` | `null` ⚠️（实时全行程拖拽进度 0~1） |

- **`rememberPullToRefreshState(refreshThreshold)`**：`refreshThreshold = 0.25`
  （0.25 = 拉过全行程 25% 触发；0.0 一拉就触发；1.0 要拉满）。
- **`PullToRefreshState` 暴露**：`refreshState`、`pullProgress`、`fullDragProgress`、`visualProgress`。
  文档明确：**它只管 UI 状态，刷新逻辑由 `isRefreshing` + `onRefresh` 控制。**
- **状态机（官方 5 态）**：`Idle` → `Pulling` → `ThresholdReached` → `Refreshing` → `RefreshComplete`。
- **`isRefreshing` 契约（官方 ::: tip 原文要点）**：它是唯一真相源，双向同步——
  空闲时置 `true` 会**程序化显示指示器**（例如进入页面就刷新）；置 `false` 结束刷新。
  **必须在 `onRefresh` 里「及时」置 `true`**（同步置，或在 UI scope 里首个挂起点之前置）；
  若指示器进入 refreshing 态时它仍是（或又变回）`false`，刷新会被判定为已完成、立刻播完动画；
  之后才到的 `true` 会再次显示指示器。
- **最小用法**

```kotlin
var isRefreshing by rememberSaveable { mutableStateOf(false) }
val state = rememberPullToRefreshState()
LaunchedEffect(isRefreshing) { if (isRefreshing) { delay(500); isRefreshing = false } }

PullToRefresh(isRefreshing = isRefreshing, onRefresh = { isRefreshing = true }, pullToRefreshState = state) {
    LazyColumn(Modifier.fillMaxSize()) { /* ... */ }
}
```

- **坑**
  1. `onRefresh` 里**不同步置 `true`**（比如先 `launch` 再置）会让刷新瞬间被判完成——官方专门写了这一段。
  2. 指示器显示期间**内容区的嵌套滚动会被消费**（与手势触发一致）。
  3. 想「进入页面自动刷新」：`LaunchedEffect(Unit) { isRefreshing = true }`。

### 3.28 SearchBar / InputField

- 📦 `top.yukonga.miuix.kmp.basic.SearchBar`、`.InputField`、`.SearchBarDefaults`
- 🔁 **两个组件配合**：`SearchBar` 是外框（含展开态结果区），`InputField` 是里面那个输入胶囊。
- **`SearchBar` 参数与默认值**

| 参数 | 默认值 |
|---|---|
| `inputField`（槽） | 必填 |
| `onExpandedChange` | 必填 |
| `insideMargin` | `SearchBarDefaults.InsideMargin` = `DpSize(12.dp, 0.dp)` |
| `expanded` | `false` ⚠️ |
| `outsideEndAction` | `null` ⚠️（展开时右侧动作槽，如「取消」） |
| `content` | 必填（`ColumnScope`，展开时显示） |

- **`InputField` 参数与默认值**：`query` / `onQueryChange` / `onSearch` / `expanded` / `onExpandedChange` 必填；
  `label = ""`；`enabled = true`；`textStyle = null`；
  `color = surfaceContainerHigh`（**要自己做背景（如毛玻璃）时传 `Color.Transparent`**）；
  `leadingIcon` = 默认搜索图标；`trailingIcon` = 默认清除按钮；`interactionSource = null` ⚠️。
- **`SearchBarDefaults` 常量**：`InputFieldMinHeight = 45.dp`、`InputFieldFontSize = 17.sp`、
  `LeadingIconStartPadding = 16.dp`、`LeadingIconEndPadding = 8.dp`、
  `TrailingIconStartPadding = 8.dp`、`TrailingIconEndPadding = 16.dp`。
- **最小用法**

```kotlin
var text by remember { mutableStateOf("") }
var expanded by remember { mutableStateOf(false) }

SearchBar(
    inputField = {
        InputField(query = text, onQueryChange = { text = it }, onSearch = {},
            expanded = expanded, onExpandedChange = { expanded = it })
    },
    expanded = expanded,
    onExpandedChange = { expanded = it },
) { Column { /* 搜索结果 */ } }
```

- **坑**：`expanded` 要在 `SearchBar` 与 `InputField` **两边都传**（官方示例就是两处同源），
  只传一边会出现「输入框展开了但结果区没出来」。

### 3.29 ColorPalette

- 📦 `top.yukonga.miuix.kmp.basic.ColorPalette`
- **作用**：HSV 色格 + **内置 alpha 滑条** + 可选灰阶列 + 实时预览。
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `color` / `onColorChanged` | 必填 |
| `rows` | `7`（上亮/低饱和 → 下暗/高饱和） |
| `hueColumns` | `12` |
| `includeGrayColumn` | `true`（默认开） |
| `showPreview` | `true`（默认开） |
| `cornerRadius` | `16.dp` |
| `indicatorRadius` | `10.dp` |

- **最小用法**

```kotlin
var selectedColor by remember { mutableStateOf(Color.Red) }
ColorPalette(color = selectedColor, onColorChanged = { selectedColor = it })
```

- **坑**：**alpha 滑条内置且无法隐藏**（文档 `> Note:` 明写 currently cannot be hidden）——
  不接受 alpha 的场景请改用 `ColorPicker`（它的四个滑条可以只用其中几个）。

### 3.30 ColorPicker

- 📦 `top.yukonga.miuix.kmp.basic.ColorPicker`
- **作用**：按色相/饱和/明度/透明度调色的滑条组；带触感与实时预览。
- **关键参数与默认值**

| 参数 | 默认值 |
|---|---|
| `color` / `onColorChanged` | 必填 |
| `showPreview` | `true`（默认开） |
| `hapticEffect` | `SliderDefaults.DefaultHapticEffect`（= `Edge`） |
| `colorSpace` | `ColorSpace.HSV` |

- **四个独立滑条（HSV 族）**：`HsvHueSlider`（`currentHue` / `onHueChanged`）、
  `HsvSaturationSlider`（`currentHue` / `currentSaturation` / `onSaturationChanged`）、
  `HsvValueSlider`（+ `currentValue` / `onValueChanged`）、
  `HsvAlphaSlider`（+ `currentAlpha` / `onAlphaChanged`）。
- **其它色彩空间的对应滑条**：`OkHSV` → `OkHsv*Slider`；`OkLCH` → `OkLchLightnessSlider` /
  `OkLchChromaSlider` / `OkLchHueSlider` / `OkLchAlphaSlider`；
  `OkLab` → `OkLabLightnessSlider` / `OkLabAChannelSlider` / `OkLabBChannelSlider` / `OkLabAlphaSlider`。
  参数形状与 HSV 版一致（当前值 + `on*Changed` + 可选 `hapticEffect`），精确签名看源码 KDoc。
- **`ColorSpace` 四个取值**：`HSV`（经典）、`OKHSV`（感知更均匀的色相步进）、
  `OKLAB`（明度/a/b）、`OKLCH`（明度/彩度/色相，彩度夹在 sRGB 色域内）。
- **最小用法**

```kotlin
var color by remember { mutableStateOf(Color.Red) }
ColorPicker(color = color, onColorChanged = { color = it }, colorSpace = ColorSpace.OKLCH)
```

- **坑**：`overlaydialog.md` 的示例里写的是 `ColorPicker(initialColor = ...)`，
  而 `colorpicker.md` 的参数表是 `color`——**上游两份文档不一致，以 `colorpicker.md` 的参数表为准**
  （demo 才是最终裁决，见 `CHEATSHEET-Demo范例.md`）。

---

## 4. Extended Components

### 4.1 概览与共同点

`index.md` 的 Extended Components 表把这一族分成三段，且**逐条标了是否依赖 Scaffold**：

| 子族 | 成员 | 依赖 |
|---|---|---|
| Preference 行 | `ArrowPreference`、`SwitchPreference`、`CheckboxPreference`、`RadioButtonPreference`、`SliderPreference`、`RangeSliderPreference` | 无（不需要 Scaffold） |
| Overlay 系 | `OverlayListPopup`、`OverlayCascadingListPopup`、`OverlayDropdownPreference`、`OverlaySpinnerPreference`、`OverlayDropdownMenu`、`OverlayIconDropdownMenu`、`OverlayIconCascadingDropdownMenu`、`OverlayBottomSheet`、`OverlayDialog` | **需 Scaffold**（表中逐条写着 uses MiuixPopupUtils; requires `Scaffold`） |
| Window 系 | `WindowListPopup`、`WindowCascadingListPopup`、`WindowDropdownPreference`、`WindowSpinnerPreference`、`WindowDropdownMenu`、`WindowIconDropdownMenu`、`WindowIconCascadingDropdownMenu`、`WindowBottomSheet`、`WindowDialog` | 无 |

**六个 Preference 行的共同参数骨架**（各组件差异在后面的条目里单列）：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `modifier` | `Modifier` | |
| `titleColor` / `summaryColor` | `BasicComponentDefaults.titleColor()` / `.summaryColor()` | `BasicComponentColors` |
| `startAction` | `null` ⚠️ | 起始侧自定义内容 |
| `endActions` | `null` ⚠️（`ArrowPreference`/`SwitchPreference` 为 `{}`） | 末尾侧槽，`RowScope` |
| `bottomAction` | `null` ⚠️ | 底部自定义内容 |
| `insideMargin` | `BasicComponentDefaults.InsideMargin` = `PaddingValues(16.dp)` | |
| `holdDownState` | `false` ⚠️ 默认关 | 弹窗期间保持按下态 |
| `enabled` | `true` | |
| `onClick` | `null` ⚠️ | 非 null 时**末尾显示箭头**（Slider/RangeSlider 文档明写） |

### 4.2 ArrowPreference

- 📦 `top.yukonga.miuix.kmp.preference.ArrowPreference`
- **参数与默认值**：`title` 必填；`summary = null` ⚠️；`onClick = null` ⚠️；
  `endActions = {}`；其余见 §4.1。
- **箭头着色（文档明写，不可关）**：**箭头始终显示并自动着色**——
  `enabled = true` 时用 `MiuixTheme.colorScheme.onSurfaceVariantActions`；
  `enabled = false` 时用 `MiuixTheme.colorScheme.disabledOnSecondaryVariant`。
  `ArrowPreferenceDefaults.endActionColors` 提供该 tint。
- **最小用法**

```kotlin
ArrowPreference(
    title = "无线网络",
    summary = "已连接 WIFI-HOME",
    endActions = { Text("12.5 GB") },
    onClick = { /* 进入下一级 */ },
    holdDownState = showDialog,
)
```

- **坑**：箭头**没有开关**（想只要标题+摘要就用 `BasicComponent`）；
  右侧展示当前值用 `endActions`，不要塞进 `summary`。

### 4.3 SwitchPreference

- 📦 `top.yukonga.miuix.kmp.preference.SwitchPreference`
- **参数与默认值**：`checked` / `onCheckedChange` / `title` 必填（`onCheckedChange` 类型为 `(Boolean) -> Unit`）；
  `summary = null` ⚠️；`endActions = {}`（**排在开关左边**）；`switchColors = SwitchDefaults.switchColors()`；
  其余见 §4.1。
- **最小用法**

```kotlin
var checked by remember { mutableStateOf(false) }
SwitchPreference(
    title = "WiFi",
    summary = "打开后连接到无线网络",
    checked = checked,
    onCheckedChange = { checked = it },
)
```

- **坑**：`endActions` 渲染在开关**之前**（文档明写 before switch）——想显示「已开启/已关闭」
  这类状态文字要放这里，且官方配色用 `MiuixTheme.colorScheme.onSurfaceVariantActions`。

### 4.4 CheckboxPreference

- 📦 `top.yukonga.miuix.kmp.preference.CheckboxPreference`、`.CheckboxLocation`
- **参数与默认值**：`title` / `checked` 必填；`onCheckedChange: ((Boolean) -> Unit)?` **可为 null**；
  `summary = null` ⚠️；`checkboxColors = CheckboxDefaults.checkboxColors()`；
  `checkboxLocation = CheckboxLocation.Start`（可选 `End`）；`startAction` / `endActions` / `bottomAction = null` ⚠️；
  其余见 §4.1。
- **最小用法**

```kotlin
var checked by remember { mutableStateOf(false) }
CheckboxPreference(title = "通知", summary = "接收推送", checked = checked, onCheckedChange = { checked = it })
```

- **坑**：参数表里 `startAction` 的描述是 **"Custom content after checkbox"**、`endActions` 是
  **"Custom content before checkbox"**——**描述是相对勾选框位置的**，所以改 `checkboxLocation` 时
  这两槽的实际落点跟着变，换位置前先照官方原话确认。

### 4.5 RadioButtonPreference

- 📦 `top.yukonga.miuix.kmp.preference.RadioButtonPreference`、`.RadioButtonPreferenceDefaults`
- **参数与默认值**：`title` / `selected` / `onClick` 必填；
  `summary = null` ⚠️；`colors = RadioButtonPreferenceDefaults.radioButtonPreferenceColors()`；
  `radioButtonColors = RadioButtonDefaults.radioButtonColors()`；
  `radioButtonLocation = RadioButtonLocation.Start`（可选 `End`）；
  `startAction` / `endActions` / `bottomAction = null` ⚠️；其余见 §4.1。
- **`RadioButtonPreferenceColors`**：`titleColor` / `selectedTitleColor` / `summaryColor` / `selectedSummaryColor`
  （均为 `BasicComponentColors`）。选中时标题与摘要会被主题色染上。
- **最小用法**

```kotlin
val options = listOf("浅色", "深色", "跟随系统")
var selected by remember { mutableIntStateOf(0) }
options.forEachIndexed { index, option ->
    RadioButtonPreference(title = option, selected = selected == index, onClick = { selected = index })
}
```

- **坑**：互斥要自己维护（组件不管组）；官方对话框里的单选组是
  「`OverlayDialog` + `Card { RadioButtonPreference(...) }`」这套组合。

### 4.6 SliderPreference

- 📦 `top.yukonga.miuix.kmp.preference.SliderPreference`
- **参数与默认值**（与裸 `Slider` 相比多了行容器相关参数）

| 参数 | 默认值 |
|---|---|
| `value` / `onValueChange` | 必填 |
| `title` / `summary` | `null` ⚠️ |
| `valueText` | `null` ⚠️（末尾显示当前值，摘要样式、居中、带 weight） |
| `endActions` | `null` ⚠️（渲染在 `valueText` 之后，同一行） |
| `bottomAction` | `null` ⚠️（底部区顶部、滑条之上） |
| `onClick` | `null` ⚠️（非 null 时末尾出现箭头） |
| `valueRange` | `0f..1f` |
| `steps` | `0` |
| `onValueChangeFinished` | `null` ⚠️ |
| `reverseDirection` | `false` |
| `sliderHeight` | `SliderDefaults.MinHeight` = `28.dp` |
| `sliderColors` | `SliderDefaults.sliderColors()` |
| `hapticEffect` | `SliderDefaults.DefaultHapticEffect`（= `Edge`） |
| `showKeyPoints` | `false` ⚠️ |
| `keyPoints` | `null` ⚠️ |
| `magnetThreshold` | `0.02f` |
| `insideMargin` | `BasicComponentDefaults.InsideMargin` |

- **最小用法**

```kotlin
var brightness by remember { mutableFloatStateOf(0.8f) }
SliderPreference(
    value = brightness,
    onValueChange = { brightness = it },
    title = "亮度",
    summary = "调整屏幕亮度",
    valueText = "${(brightness * 100).roundToInt()}%",
)
```

- **坑**：与裸 `Slider` 一样，**`showKeyPoints` 与 `keyPoints` 必须成对给**；
  默认触感是 `Edge`（只两端震），要每档震得显式 `hapticEffect = SliderDefaults.SliderHapticEffect.Step`。

### 4.7 RangeSliderPreference

- 📦 `top.yukonga.miuix.kmp.preference.RangeSliderPreference`
- **参数与默认值**：与 `SliderPreference` 几乎相同，差别是
  `value: ClosedFloatingPointRange<Float>` / `onValueChange: (Range) -> Unit`；
  且**没有** `reverseDirection`。
- **最小用法**

```kotlin
var range by remember { mutableStateOf(0.2f..0.8f) }
RangeSliderPreference(
    value = range,
    onValueChange = { range = it },
    title = "价格区间",
    summary = "$${range.start.roundToInt()} - $${range.endInclusive.roundToInt()}",
    valueRange = 0f..1000f,
    steps = 99,
)
```

- **坑**：`steps` 与裸滑块同义（`steps = 99` 配 `0f..1000f` 得到 101 个离散值）；
  区间两端的值越界会被 coerce，不会报错。

### 4.8 OverlayListPopup

- 📦 `top.yukonga.miuix.kmp.overlay.OverlayListPopup`；配套 `top.yukonga.miuix.kmp.basic.ListPopupColumn`、`.DropdownImpl`、`.ListPopupDefaults`
- **前置条件**：**必须放在 `Scaffold` 内**（§1.1 原文：否则弹层内容不渲染）。
- **参数与默认值**

| 参数 | 默认值 |
|---|---|
| `show` | 必填 |
| `popupModifier` | `Modifier` |
| `popupPositionProvider` | `ListPopupDefaults.DropdownPositionProvider` |
| `alignment` | `PopupPositionProvider.Align.Start` |
| `enableWindowDim` | `true` |
| `onDismissRequest` | `null` ⚠️ |
| `onDismissFinished` | `null` ⚠️ |
| `maxHeight` | `null` ⚠️ |
| `minWidth` | `ListPopupDefaults.MinWidth` |
| `renderInRootScaffold` | `true` |
| `content` | 必填 |

- **`DropdownImpl`**（`ListPopupColumn` 里的标准行）：`text` / `optionSize` / `isSelected` / `index` /
  `onSelectedIndexChange` 必填；`dropdownColors = DropdownDefaults.dropdownColors()`；`enabled = true`。
  文档明写：`enabled = false` 的行不可点、用禁用文字色。
- **最小用法**

```kotlin
Scaffold {
    var show by remember { mutableStateOf(false) }
    var selected by remember { mutableIntStateOf(0) }
    val items = listOf("选项 1", "选项 2", "选项 3")

    Box {
        TextButton(text = "打开菜单", onClick = { show = true })
        OverlayListPopup(show = show, onDismissRequest = { show = false }) {
            ListPopupColumn {
                items.forEachIndexed { index, text ->
                    DropdownImpl(text = text, optionSize = items.size,
                        isSelected = selected == index, index = index,
                        onSelectedIndexChange = { selected = index; show = false })
                }
            }
        }
    }
}
```

- **坑**
  1. **`onDismissRequest` 默认 `null`**：不传的话点外部弹层不会关、你的 state 也不会复位。
  2. `ListPopupColumn` 里每一行必须给 `optionSize`（总选项数）——它决定选中指示的动画尺寸。
  3. `renderInRootScaffold = true` 时弹层盖满全屏；嵌套 Scaffold 场景想限制在局部要传 `false`。

### 4.9 OverlayCascadingListPopup

- 📦 `top.yukonga.miuix.kmp.overlay.OverlayCascadingListPopup`（数据类用 `basic.DropdownEntry` / `.DropdownItem`）
- **前置条件**：**必须放在 `Scaffold` 内**。
- **能力**：两级级联菜单；`DropdownItem.children` 非空的项变成子菜单触发器，点它弹层「变形成」
  二级列表（主列表在半透明遮罩后缩小）。**级联深度上限 2**，二级项的 `children` 会被静默忽略。
- **参数与默认值**

| 参数 | 默认值 |
|---|---|
| `show` / `entries` / `onDismissRequest` | 必填 |
| `popupModifier` | `Modifier` |
| `onDismissFinished` | `null` ⚠️ |
| `popupPositionProvider` | `ListPopupDefaults.DropdownPositionProvider` |
| `alignment` | `PopupPositionProvider.Align.End` |
| `enableWindowDim` | `true` |
| `maxHeight` | `null` ⚠️ |
| `minWidth` | `200.dp` |
| `renderInRootScaffold` | `true` |
| `dropdownColors` | `DropdownDefaults.dropdownColors()` |
| `collapseOnSelection` | `true` |

- **最小用法**

```kotlin
val entries = listOf(
    DropdownEntry(items = listOf(DropdownItem(text = "按拍摄日期", selected = true, onClick = {}))),
    DropdownEntry(items = listOf(DropdownItem(text = "视图模式", children = listOf(
        DropdownItem(text = "按日期分组", onClick = {}), DropdownItem(text = "紧凑", onClick = {}))))),
)
Scaffold {
    OverlayCascadingListPopup(show = show, entries = entries, onDismissRequest = { show = false })
}
```

- **坑**：`DropdownItem.onClick` 在 `children` 非空时**被忽略**（点它是展开子菜单）；
  深度超过 2 不会报错，只是「静默忽略」——排菜单结构时要自己守住两层。

### 4.10 OverlayDropdownPreference

- 📦 `top.yukonga.miuix.kmp.preference.OverlayDropdownPreference`
- **前置条件**：**必须放在 `Scaffold` 内**。
- 🔁 **三个重载**
  1. **items 版**：`items: List<String>` + `selectedIndex: Int` + `onSelectedIndexChange`（**组件持有单一选中索引**）。
  2. **entry 版**：`entry: DropdownEntry` + `collapseOnSelection = true`。
  3. **entries 版**：`entries: List<DropdownEntry>` + `collapseOnSelection = entries.size <= 1` + `renderInRootScaffold = true`。
- **公共参数与默认值**：`title` 必填；`summary = null` ⚠️；
  `dropdownColors = DropdownDefaults.dropdownColors()`；`startAction` / `bottomAction = null` ⚠️；
  `maxHeight = null` ⚠️；`enabled = true`；`showValue = true`；
  `onExpandedChange = null` ⚠️；`onSelectedIndexChange = null` ⚠️（items 版必填）；
  `insideMargin = BasicComponentDefaults.InsideMargin`；`renderInRootScaffold = true`。
- **最小用法**

```kotlin
Scaffold {
    var selected by remember { mutableIntStateOf(0) }
    OverlayDropdownPreference(
        title = "语言",
        summary = "选择界面语言",
        items = listOf("中文", "English", "日本語"),
        selectedIndex = selected,
        onSelectedIndexChange = { selected = it },
    )
}
```

- **坑**：**items 版与 entry/entries 版是两种心智模型**——items 版组件替你管索引；
  entry/entries 版索引在 `DropdownItem.selected` + `onClick` 上，可以多选。
  多组菜单默认**选完不关**（`entries.size <= 1` 才为 true）。

### 4.11 OverlaySpinnerPreference

- 📦 `top.yukonga.miuix.kmp.preference.OverlaySpinnerPreference`
- **前置条件**：**必须放在 `Scaffold` 内**。
- **与 `OverlayDropdownPreference` 的区别**：官方原文——similar to `OverlayDropdownPreference`
  but offers richer functionality and interaction experience；选项是 `DropdownItem`
  （**可带 `icon` 与 `summary`**），且多一个**对话框模式**。
- 🔁 **重载**：弹层模式（`items` / `entry` / `entries`）与对话框模式（同样三种，但必传 `dialogButtonString`）。
- **参数与默认值**

| 参数 | 弹层模式 | 对话框模式 |
|---|---|---|
| `items` / `selectedIndex` / `title` | 必填 | 必填 |
| `dialogButtonString` | — | **必填**（提供它即进入对话框模式） |
| `popupModifier` | — | `Modifier` |
| `spinnerColors` | `DropdownDefaults.dropdownColors()` | `DropdownDefaults.dialogDropdownColors()` |
| `maxHeight` | `null` ⚠️ | — |
| `showValue` | `true` | `true` |
| `renderInRootScaffold` | `true` | `true` |
| `onExpandedChange` / `onSelectedIndexChange` | `null` ⚠️ | `null` ⚠️ |
| `startAction` / `bottomAction` | `null` ⚠️ | `null` ⚠️ |
| `insideMargin` | `BasicComponentDefaults.InsideMargin` | 同 |
| `collapseOnSelection` | entry 版 `true` / entries 版 `entries.size <= 1` | 同 |

- **最小用法（弹层 + 图标摘要）**

```kotlin
Scaffold {
    var selected by remember { mutableIntStateOf(0) }
    OverlaySpinnerPreference(
        title = "主题",
        items = listOf(
            DropdownItem(text = "红色主题", summary = "热情的红"),
            DropdownItem(text = "蓝色主题", summary = "沉静的青"),
        ),
        selectedIndex = selected,
        onSelectedIndexChange = { selected = it },
    )
}
```

- **坑**：`dialogButtonString` **一给就切成对话框模式**（底部按钮文字由你定），
  两套模式的颜色默认值不同（`dropdownColors()` vs `dialogDropdownColors()`）。

### 4.12 OverlayDropdownMenu

- 📦 `top.yukonga.miuix.kmp.menu.OverlayDropdownMenu`
- **前置条件**：**必须放在 `Scaffold` 内**。
- **与 `OverlayDropdownPreference` 的关键区别（官方原文）**：
  **它不持有单一选中索引**——选中状态完全落在每个 `DropdownItem` 的 `selected` / `onClick` 上。
  适合动作菜单、多选菜单、或选项之间没有互斥关系的场景。
- **参数与默认值**：`title` 必填；`entries` 版 `collapseOnSelection = entries.size <= 1`、
  entry 版 `collapseOnSelection = true`；`titleColor` / `summaryColor` 走 `BasicComponentDefaults`；
  `summary = null` ⚠️；`dropdownColors = DropdownDefaults.dropdownColors()`；
  `startAction` / `bottomAction = null` ⚠️；`maxHeight = null` ⚠️；`enabled = true`；
  `renderInRootScaffold = true`；`onExpandedChange = null` ⚠️。
- **最小用法**

```kotlin
Scaffold {
    var selected by remember { mutableStateOf(setOf("A1")) }
    val entries = listOf(DropdownEntry(items = listOf("A1", "A2").map { text ->
        DropdownItem(text = text, selected = text in selected,
            onClick = { selected = if (text in selected) selected - text else selected + text })
    })))
    OverlayDropdownMenu(title = "多选菜单", entries = entries, collapseOnSelection = false)
}
```

- **坑**：多选必须 `collapseOnSelection = false`，否则选一次就关；
  该组件没有 `selectedIndex` 参数，别照 `Preference` 版的写法抄。

### 4.13 OverlayIconDropdownMenu

- 📦 `top.yukonga.miuix.kmp.menu.OverlayIconDropdownMenu`
- **前置条件**：**必须放在 `Scaffold` 内**（可以不在 `TopAppBar` 里，只要所在树有 Scaffold）。
- **作用**：`IconButton` 包装器，点开一个 `OverlayDropdownPopup`；用于工具栏动作槽
  （如 `TopAppBar` 的 `actions`）——一个图标展开成一列动作/排序/筛选。
- 🔁 **两个重载**：`entries: List<DropdownEntry>`（`collapseOnSelection = entries.size <= 1`） /
  `entry: DropdownEntry`（`collapseOnSelection = true`）；其余参数相同。
- **参数与默认值**：`modifier = Modifier`；`enabled = true`；`maxHeight = null` ⚠️；
  `dropdownColors = DropdownDefaults.dropdownColors()`；`renderInRootScaffold = true`；
  `onExpandedChange = null` ⚠️；`backgroundColor = Color.Unspecified`；
  `cornerRadius = IconButtonDefaults.CornerRadius`；`minHeight` / `minWidth = IconButtonDefaults`（`40.dp`）；
  `content`（图标）必填。
- **隐式禁用**：**当没有任何 `DropdownEntry` 含 item 时，菜单自动禁用**（官方明写）。
- **最小用法**

```kotlin
Scaffold(topBar = {
    SmallTopAppBar(title = "收件箱", actions = {
        OverlayIconDropdownMenu(entry = DropdownEntry(items = listOf("编辑", "复制", "删除")
            .map { DropdownItem(text = it, onClick = {}) })) {
            Icon(imageVector = MiuixIcons.Edit, contentDescription = "动作菜单")
        }
    })
})
```

- **坑**：排序/单选靠每个 `DropdownItem.selected`，并依赖 entry 版默认 `collapseOnSelection = true` 选完自关；
  多选要显式 `false` 并自己维护 `Set`。

### 4.14 OverlayIconCascadingDropdownMenu

- 📦 `top.yukonga.miuix.kmp.menu.OverlayIconCascadingDropdownMenu`
- **前置条件**：**必须放在 `Scaffold` 内**。
- **作用**：`IconButton` + `OverlayCascadingListPopup`，工具栏图标展开**带子菜单**的菜单；
  `children` 非空即子菜单触发器，**深度上限 2**。
- 🔁 **两个重载**：`entries` / `entry`（`collapseOnSelection` 默认 `entries.size <= 1` / `true`）。
- **参数与默认值**：与 §4.13 一致，外加 `renderInRootScaffold = true`、`maxHeight = null` ⚠️。
- **最小用法**

```kotlin
Scaffold(topBar = {
    SmallTopAppBar(title = "图库", actions = {
        OverlayIconCascadingDropdownMenu(entries = listOf(
            DropdownEntry(items = listOf(
                DropdownItem(text = "视图模式", children = listOf(
                    DropdownItem(text = "按日期分组", onClick = {}),
                    DropdownItem(text = "紧凑", onClick = {}))),
                DropdownItem(text = "刷新", onClick = {}))))) {
            Icon(imageVector = MiuixIcons.Tune, contentDescription = "调整")
        }
    })
})
```

- **坑**：二级项不能再带 `children`（静默忽略）；触发器行的 `onClick` 不生效。

### 4.15 OverlayBottomSheet

- 📦 `top.yukonga.miuix.kmp.overlay.OverlayBottomSheet`、`top.yukonga.miuix.kmp.theme.LocalDismissState`
- **前置条件**：**必须放在 `Scaffold` 内**。
- **参数与默认值**（与 `WindowBottomSheet` 同构，仅多一个 `renderInRootScaffold`）

| 参数 | 默认值 |
|---|---|
| `show` | 必填 |
| `title` | `null` ⚠️ |
| `startAction` / `endAction` | `null` ⚠️ |
| `backgroundColor` | `BottomSheetDefaults.backgroundColor()` |
| `enableWindowDim` | `true` |
| `cornerRadius` | `BottomSheetDefaults.cornerRadius`（`28.dp`） |
| `sheetMaxWidth` | `BottomSheetDefaults.maxWidth`（`640.dp`） |
| `onDismissRequest` | `null` ⚠️ |
| `onDismissFinished` | `null` ⚠️ |
| `outsideMargin` / `insideMargin` | `BottomSheetDefaults` 对应值 |
| `defaultWindowInsetsPadding` | `true` |
| `dragHandleColor` | `BottomSheetDefaults.dragHandleColor()` |
| `allowDismiss` | `true` |
| `enableNestedScroll` | `true` |
| `renderInRootScaffold` | `true` |

- **`LocalDismissState`（所有弹层共用）**：提供 `(() -> Unit)?`，
  在内容/动作槽里 `val dismiss = LocalDismissState.current; onClick = { dismiss?.invoke() }` 即可关闭。
- **最小用法**

```kotlin
Scaffold {
    var show by remember { mutableStateOf(false) }
    TextButton(text = "打开", onClick = { show = true })
    OverlayBottomSheet(show = show, title = "选择", onDismissRequest = { show = false }) {
        val dismiss = LocalDismissState.current
        Text("内容")
        TextButton(text = "关闭", onClick = { dismiss?.invoke() })
    }
}
```

- **坑**：`startAction` / `endAction` / `content` **三处都能拿到 `LocalDismissState`**（官方明写）；
  `allowDismiss = false` 时拖拽和返回键都关不掉，必须显式改 `show`。

### 4.16 OverlayDialog

- 📦 `top.yukonga.miuix.kmp.overlay.OverlayDialog`、`top.yukonga.miuix.kmp.theme.LocalDismissState`
- **前置条件**：**必须放在 `Scaffold` 内**。
- **参数与默认值**

| 参数 | 默认值 |
|---|---|
| `show` | 必填 |
| `title` / `summary` | `null` ⚠️ |
| `titleColor` / `summaryColor` / `backgroundColor` | `DialogDefaults.titleColor()` / `.summaryColor()` / `.backgroundColor()` |
| `enableWindowDim` | `true` |
| `onDismissRequest` | `null` ⚠️ |
| `onDismissFinished` | `null` ⚠️ |
| `outsideMargin` / `insideMargin` | `DialogDefaults.outsideMargin` / `.insideMargin` |
| `defaultWindowInsetsPadding` | `true` |
| `renderInRootScaffold` | `true` |
| `maxWidth` | `DialogDefaults.MaxWidth` |
| `largeScreen` | `null` ⚠️（null = 按窗口尺寸自动判定） |
| `cornerRadius` | `null` ⚠️（null = 居中态用 `DialogDefaults.CornerRadius`；贴底态由屏幕圆角推导，夹 32~48dp） |
| `content` | 必填 |

- **最小用法**

```kotlin
Scaffold {
    var show by remember { mutableStateOf(false) }
    TextButton(text = "打开", onClick = { show = true })
    OverlayDialog(
        title = "确认",
        summary = "此操作不可撤销，是否继续？",
        show = show,
        onDismissRequest = { show = false },
    ) {
        Row(horizontalArrangement = Arrangement.SpaceBetween) {
            TextButton(text = "取消", onClick = { show = false }, modifier = Modifier.weight(1f))
            Spacer(Modifier.width(20.dp))
            TextButton(text = "确认", onClick = { show = false }, modifier = Modifier.weight(1f),
                colors = ButtonDefaults.textButtonColorsPrimary())
        }
    }
}
```

- **坑**：`largeScreen` / `cornerRadius` 默认 `null` 是「自动」而非「无」——
  想强制某种呈现才显式传；对话框里的表单要自己包 `Card` 并配
  `CardDefaults.defaultColors(color = MiuixTheme.colorScheme.secondaryContainer)`（官方示例配方）。

### 4.17 WindowListPopup

- 📦 `top.yukonga.miuix.kmp.window.WindowListPopup`；配套 `basic.ListPopupColumn`、`.DropdownImpl`
- **前置条件**：**不需要 `Scaffold` 或 `MiuixPopupHost`，可用在任何位置；用平台 `Dialog` 渲染在 window 层。**
- **参数与默认值**：与 `OverlayListPopup` 完全一致，**但没有 `renderInRootScaffold`**。
- **最小用法**

```kotlin
var show by remember { mutableStateOf(false) }
Box {
    TextButton(text = "打开菜单", onClick = { show = true })
    WindowListPopup(show = show, onDismissRequest = { show = false }) {
        val dismiss = LocalDismissState.current
        ListPopupColumn { DropdownImpl(text = "选项 1", optionSize = 3, isSelected = true,
            index = 0, onSelectedIndexChange = { dismiss?.invoke() }) }
    }
}
```

- **坑**：`LocalDismissState` 在 Window 系同样可用（官方示例就是这么关的）；
  因为不依赖 Scaffold，**可以放在 `Overlay` 系放不了的地方**（比如没有 Scaffold 的独立 Composable）。

### 4.18 WindowCascadingListPopup

- 📦 `top.yukonga.miuix.kmp.window.WindowCascadingListPopup`
- **前置条件**：**不需要 Scaffold；window 层渲染。**
- **参数与默认值**：与 `OverlayCascadingListPopup` 一致（`alignment = Align.End`、
  `minWidth = 200.dp`、`enableWindowDim = true`、`collapseOnSelection = true`、
  `maxHeight = null` ⚠️、`onDismissFinished = null` ⚠️），**没有 `renderInRootScaffold`**。
- **最小用法**：与 §4.9 相同，只是把 `OverlayCascadingListPopup` 换成
  `WindowCascadingListPopup` 且**去掉外层 `Scaffold`**。
- **坑**：级联深度同样**上限 2**，深层 `children` 静默忽略。

### 4.19 WindowDropdownPreference

- 📦 `top.yukonga.miuix.kmp.preference.WindowDropdownPreference`
- **前置条件**：**不需要 Scaffold；window 层渲染。**
- 🔁 **三个重载**：`items`+`selectedIndex` 版 / `entry` 版 / `entries` 版
  （与 `OverlayDropdownPreference` 同构，**无 `renderInRootScaffold`**）。
- **参数与默认值**：`items` / `selectedIndex` / `title` 必填（items 版）；
  `summary = null` ⚠️；`titleColor` / `summaryColor` 走 `BasicComponentDefaults`；
  `dropdownColors = DropdownDefaults.dropdownColors()`；`startAction` / `bottomAction = null` ⚠️；
  `insideMargin = BasicComponentDefaults.InsideMargin`；`maxHeight = null` ⚠️；`enabled = true`；
  **`showValue = true`**；`onExpandedChange = null` ⚠️；`onSelectedIndexChange = null` ⚠️；
  entry 版 `collapseOnSelection = true`；entries 版 `collapseOnSelection = entries.size <= 1`。
- **`DropdownEntry.title` 未开放（官方明写）**：Group titles are reserved for future use.
  The original MIUI dropdown style currently has no matching group-title presentation,
  so the `title` field is not exposed yet.
- **最小用法**

```kotlin
var selected by remember { mutableIntStateOf(0) }
WindowDropdownPreference(
    title = "语言设置",
    summary = "选择界面语言",
    items = listOf("中文", "English", "日本語"),
    selectedIndex = selected,
    onSelectedIndexChange = { selected = it },
)
```

- **坑**：`DropdownItem.enabled = false` 的项不可点，**文字与选中指示都用禁用色**（官方明写）；
  组标题暂时无法显示，别指望 `DropdownEntry.title`。

### 4.20 WindowSpinnerPreference

- 📦 `top.yukonga.miuix.kmp.preference.WindowSpinnerPreference`
- **前置条件**：**不需要 Scaffold；window 层渲染。**
- 🔁 **重载（共 6 种组合）**：弹层模式（`items` / `entry` / `entries`）+
  对话框模式（同三种，均必传 `dialogButtonString`）。
- **参数与默认值**：与 `OverlaySpinnerPreference` 同构（`spinnerColors` 弹层用
  `dropdownColors()`、对话框用 `dialogDropdownColors()`；`maxHeight = null` ⚠️；`showValue = true`；
  `onExpandedChange` / `onSelectedIndexChange = null` ⚠️），**无 `renderInRootScaffold`**。
- **最小用法（对话框模式）**

```kotlin
var selected by remember { mutableIntStateOf(0) }
WindowSpinnerPreference(
    title = "选择器",
    dialogButtonString = "取消",
    items = listOf(DropdownItem(text = "A"), DropdownItem(text = "B"), DropdownItem(text = "C")),
    selectedIndex = selected,
    onSelectedIndexChange = { selected = it },
)
```

- **坑**：选项是 `DropdownItem`，**可以带 `icon` 与 `summary`**（官方给了自绘 `Painter` 作圆角色块的示例）——
  这是它比 `DropdownPreference` 强的点；`dialogButtonString` 一给即切对话框模式。

### 4.21 WindowDropdownMenu

- 📦 `top.yukonga.miuix.kmp.menu.WindowDropdownMenu`
- **前置条件**：**不需要 Scaffold。**
- **与 `WindowDropdownPreference` 的关键区别**：**不持有单一选中索引**，选中状态在 `DropdownItem` 上。
- **参数与默认值**：`title` 必填；`entries` 版 `collapseOnSelection = entries.size <= 1`、
  entry 版 `= true`；`summary = null` ⚠️；`dropdownColors = DropdownDefaults.dropdownColors()`；
  `startAction` / `bottomAction = null` ⚠️；`maxHeight = null` ⚠️；`enabled = true`；
  `onExpandedChange = null` ⚠️。
- **最小用法**

```kotlin
var selected by remember { mutableStateOf(setOf("A1", "B2")) }
WindowDropdownMenu(
    title = "多选菜单",
    entries = listOf(DropdownEntry(items = listOf("A1", "A2").map { text ->
        DropdownItem(text = text, selected = text in selected,
            onClick = { selected = if (text in selected) selected - text else selected + text }) })),
    collapseOnSelection = false,
)
```

- **坑**：多选要 `collapseOnSelection = false`；没有任何 entry 含 item 时**整行隐式禁用**。

### 4.22 WindowIconDropdownMenu

- 📦 `top.yukonga.miuix.kmp.menu.WindowIconDropdownMenu`
- **前置条件**：**不需要 Scaffold**（但 `TopAppBar` 的天然宿主还是 Scaffold）。
- **作用**：`IconButton` + `WindowDropdownPopup`（window 层 `Dialog`）。
- 🔁 **两个重载**：`entries`（`collapseOnSelection = entries.size <= 1`）/ `entry`（`= true`）。
- **参数与默认值**：`modifier = Modifier`；`enabled = true`；`maxHeight = null` ⚠️；
  `dropdownColors = DropdownDefaults.dropdownColors()`；`onExpandedChange = null` ⚠️；
  `backgroundColor = Color.Unspecified`；`cornerRadius` / `minHeight` / `minWidth` 走 `IconButtonDefaults`（`40.dp`）。
- **最小用法**

```kotlin
val entry = DropdownEntry(items = listOf("编辑", "复制", "分享", "删除")
    .map { DropdownItem(text = it, onClick = {}) })

SmallTopAppBar(title = "收件箱", actions = {
    WindowIconDropdownMenu(entry = entry) {
        Icon(imageVector = MiuixIcons.Edit, contentDescription = "动作菜单")
    }
})
```

- **坑**：与 Overlay 版行为一致（含「无 item 时隐式禁用」），差别只在**不需要 Scaffold**。

### 4.23 WindowIconCascadingDropdownMenu

- 📦 `top.yukonga.miuix.kmp.menu.WindowIconCascadingDropdownMenu`
- **前置条件**：**不需要 Scaffold。**
- **作用**：`IconButton` + `WindowCascadingListPopup`；`children` 非空即子菜单触发器，**深度上限 2**。
- 🔁 **两个重载**：`entries`（`collapseOnSelection = true`）/ `entry`（`= true`）；
  其余参数同 §4.22。
- **最小用法**

```kotlin
SmallTopAppBar(title = "图库", actions = {
    WindowIconCascadingDropdownMenu(entries = listOf(DropdownEntry(items = listOf(
        DropdownItem(text = "视图模式", children = listOf(
            DropdownItem(text = "按日期分组", onClick = {}),
            DropdownItem(text = "紧凑", onClick = {}))))))) {
        Icon(imageVector = MiuixIcons.Tune, contentDescription = "调整")
    }
})
```

- **坑**：二级项不能再带 `children`；无 item 时整行隐式禁用。

### 4.24 WindowBottomSheet

- 📦 `top.yukonga.miuix.kmp.window.WindowBottomSheet`、`top.yukonga.miuix.kmp.theme.LocalDismissState`
- **前置条件**：**不需要 Scaffold 或 MiuixPopupHost；可用在任何 Composable 作用域**（官方 `::: tip` 原文），
  用平台 `Dialog` 渲染，自带大屏优化动画与系统返回手势关闭。
- **参数与默认值**：与 `OverlayBottomSheet` 相同，**但没有 `renderInRootScaffold`**：
  `title = null` ⚠️、`startAction` / `endAction = null` ⚠️、`enableWindowDim = true`、
  `cornerRadius = 28.dp`、`sheetMaxWidth = 640.dp`、`onDismissRequest = null` ⚠️、
  `onDismissFinished = null` ⚠️、`defaultWindowInsetsPadding = true`、`allowDismiss = true`、
  `enableNestedScroll = true`。
- **最小用法**

```kotlin
var show by remember { mutableStateOf(false) }
TextButton(text = "打开", onClick = { show = true })   // 任何位置都能用，不需要 Scaffold

WindowBottomSheet(show = show, title = "标题", onDismissRequest = { show = false }) {
    val dismiss = LocalDismissState.current
    Text("内容")
    TextButton(text = "关闭", onClick = { dismiss?.invoke() })
}
```

- **坑**：`LocalDismissState` 在 `startAction` / `endAction` / `content` 三处都可用；
  内容高度自适应但**不会盖住状态栏区域**（官方示例注释）。

### 4.25 WindowDialog

- 📦 `top.yukonga.miuix.kmp.window.WindowDialog`、`top.yukonga.miuix.kmp.theme.LocalDismissState`
- **前置条件**：**不需要 Scaffold 或 MiuixPopupHost；可用在任何 Composable 作用域**，window 层渲染。
- **参数与默认值**：与 `OverlayDialog` 相同，**但没有 `renderInRootScaffold`**：
  `title` / `summary = null` ⚠️；`enableWindowDim = true`；`onDismissRequest` / `onDismissFinished = null` ⚠️；
  `defaultWindowInsetsPadding = true`；`largeScreen = null` ⚠️；`cornerRadius = null` ⚠️；
  `maxWidth = DialogDefaults.MaxWidth`；`outsideMargin` / `insideMargin` 走 `DialogDefaults`。
- **最小用法**

```kotlin
var show by remember { mutableStateOf(false) }
TextButton(text = "打开", onClick = { show = true })

WindowDialog(title = "标题", summary = "一段说明", show = show, onDismissRequest = { show = false }) {
    val dismiss = LocalDismissState.current
    TextButton(text = "确定", onClick = { dismiss?.invoke() }, modifier = Modifier.fillMaxWidth())
}
```

- **坑**：`DialogDefaults` 的 `outsideMargin` / `insideMargin` / `MaxWidth` / `CornerRadius` 是**属性**，
  而 `titleColor()` / `summaryColor()` / `backgroundColor()` 是**函数**（`@Composable` 取值）——别写错调用形式。

---

## 5. 共享数据结构与工具（跨组件复用）

### 5.1 `DropdownEntry` / `DropdownItem`（所有 Dropdown / Spinner / 级联菜单共用）

📦 `top.yukonga.miuix.kmp.basic.DropdownEntry`、`.DropdownItem`

| 类型 | 字段 | 默认值 | 说明 |
|---|---|---|---|
| `DropdownEntry` | `items: List<DropdownItem>` | 必填 | 一组选项 |
| `DropdownEntry` | `enabled` | `true` | `false` 禁用全组；`true` 时仍看每项自己的 `enabled` |
| `DropdownEntry` | `title` | **未开放** | 官方：Group titles are reserved for future use（MIUI 原样式没有对应呈现） |
| `DropdownItem` | `text: String` | 必填 | |
| `DropdownItem` | `enabled` | `true` | `false` 不可点、灰显 |
| `DropdownItem` | `selected` | `false` | 选中态 |
| `DropdownItem` | `onClick` | `null` ⚠️ | **`children` 非空时被忽略**（点击改为展开子菜单） |
| `DropdownItem` | `icon` | `null` ⚠️ | `@Composable ((Modifier) -> Unit)?` |
| `DropdownItem` | `summary` | `null` ⚠️ | 文字下方的摘要 |
| `DropdownItem` | `children` | `null` ⚠️ | **只有级联变体渲染为子菜单，深度限 2** |

### 5.2 `DropdownColors`（7 个颜色槽）

`contentColor`、`summaryColor`、`containerColor`、`selectedContentColor`、`selectedSummaryColor`、
`selectedContainerColor`、`selectedIndicatorColor`。
工厂：`DropdownDefaults.dropdownColors()`（弹层）/ `DropdownDefaults.dialogDropdownColors()`（对话框模式）。

### 5.3 `PopupPositionProvider.Align`（6 档）

`Start`（默认用于 `ListPopup` 系）/ `End`（默认用于级联系）/ `TopStart` / `TopEnd` / `BottomStart` / `BottomEnd`。

### 5.4 `LocalDismissState`（所有弹层共用）

📦 `top.yukonga.miuix.kmp.theme.LocalDismissState`

提供 `(() -> Unit)?`，用于**从内容里关闭当前弹层**：

```kotlin
val dismiss = LocalDismissState.current
TextButton(text = "关闭", onClick = { dismiss?.invoke() })
```

官方原话：This is a unified dismiss state provided by all overlay components.

### 5.5 `PressFeedbackType`（手感总开关）

📦 `top.yukonga.miuix.kmp.utils.PressFeedbackType`
三档：`None`（默认，无反馈）/ `Sink`（下沉缩放）/ `Tilt`（倾斜）。
**`Card` 的 `pressFeedbackType` 默认是 `None`**——这是「点击没手感」的第一现场。

### 5.6 `SliderDefaults.SliderHapticEffect`

`None` / `Edge`（**默认**，只在两端震）/ `Step`（每档震）。被 `Slider` / `VerticalSlider` / `RangeSlider` /
`SliderPreference` / `RangeSliderPreference` / `ColorPicker` 共用。

### 5.7 `DialogDefaults` / `BottomSheetDefaults` 取值方式差异（易错）

| 对象 | 属性（直接取） | 函数（`@Composable` 取值） |
|---|---|---|
| `DialogDefaults` | `MaxWidth`、`CornerRadius`、`outsideMargin`、`insideMargin` | `titleColor()`、`summaryColor()`、`backgroundColor()` |
| `BottomSheetDefaults` | `cornerRadius`（28.dp）、`maxWidth`（640.dp）、`outsideMargin`、`insideMargin` | `backgroundColor()`、`dragHandleColor()` |

---

## 6. 本文覆盖的文档清单（56 / 56）

逐条核对 `docs/reference/miuix-demo/docs/components/` 下全部 `.md`，一篇不漏：

- [x] `arrowpreference.md`
- [x] `badge.md`
- [x] `basiccomponent.md`
- [x] `breadcrumbbar.md`
- [x] `button.md`
- [x] `card.md`
- [x] `checkbox.md`
- [x] `checkboxpreference.md`
- [x] `colorpalette.md`
- [x] `colorpicker.md`
- [x] `divider.md`
- [x] `floatingactionbutton.md`
- [x] `floatingtoolbar.md`
- [x] `icon.md`
- [x] `iconbutton.md`
- [x] `index.md`
- [x] `navigationbar.md`
- [x] `navigationrail.md`
- [x] `numberpicker.md`
- [x] `overlaybottomsheet.md`
- [x] `overlaycascadinglistpopup.md`
- [x] `overlaydialog.md`
- [x] `overlaydropdownmenu.md`
- [x] `overlaydropdownpreference.md`
- [x] `overlayiconcascadingdropdownmenu.md`
- [x] `overlayicondropdownmenu.md`
- [x] `overlaylistpopup.md`
- [x] `overlayspinnerpreference.md`
- [x] `progressindicator.md`
- [x] `pulltorefresh.md`
- [x] `radiobutton.md`
- [x] `radiobuttonpreference.md`
- [x] `rangesliderpreference.md`
- [x] `scaffold.md`
- [x] `searchbar.md`
- [x] `slider.md`
- [x] `sliderpreference.md`
- [x] `smalltitle.md`
- [x] `snackbar.md`
- [x] `surface.md`
- [x] `switch.md`
- [x] `switchpreference.md`
- [x] `tabrow.md`
- [x] `text.md`
- [x] `textfield.md`
- [x] `tooltip.md`
- [x] `topappbar.md`
- [x] `windowbottomsheet.md`
- [x] `windowcascadinglistpopup.md`
- [x] `windowdialog.md`
- [x] `windowdropdownmenu.md`
- [x] `windowdropdownpreference.md`
- [x] `windowiconcascadingdropdownmenu.md`
- [x] `windowicondropdownmenu.md`
- [x] `windowlistpopup.md`
- [x] `windowspinnerpreference.md`

**合计 56 篇，全部覆盖。** 其中 `index.md` 是组件总览（不单独对应某个组件），
其余 55 篇按文档逐篇成条；**有 6 篇一篇里含多个组件**，本文也都逐个写了：
`progressindicator.md`（3 个）、`divider.md`（2 个）、`slider.md`（3 个）、
`searchbar.md`（2 个）、`tooltip.md`（4 个）、`colorpicker.md`（含 HSV/OkHSV/OkLCH/OkLab 四族滑条）。

### 读到的上游文档自身矛盾（照实记录，别照抄）

1. `scaffold.md` 的 `snackbarHost` 表格注释写「Miuix does not provide this component」，
   但 `snackbar.md` 通篇在讲 miuix 自己的 `SnackbarHost` / `Snackbar` / `SnackbarHostState`，
   且官方 demo 就是这么用的——**注释是笔误**。
2. `overlaydialog.md` 的示例写 `ColorPicker(initialColor = ...)`，
   `colorpicker.md` 的参数表写 `color`——**以参数表 / demo 为准**。
3. `scaffold.md` 的「Page Layout with Snackbar」示例用的是 **Material** 的 `SnackbarHost`
   （注释明写 requires Material components），与 miuix 自带的不是同一个——别混用。
