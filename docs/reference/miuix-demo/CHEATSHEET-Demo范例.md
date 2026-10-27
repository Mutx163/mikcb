# miuix 官方 Demo 范例索引（可照抄的调用代码）

> **产出**：task-2 / miuix-examples，2026-10-27。
> **来源**：vendored 官方 demo（`docs/reference/miuix-demo/`，快照 commit `bb7bde3`，Apache-2.0）。
> **行号基准**：本快照。上游一升级行号会漂，以 `文件:行号` 就近的符号名为准。
> **读法**：先读 [我们的差距与修法.md](我们的差距与修法.md) 知道我们缺什么，再用本文抄具体调用；
> 组件属性表查 [CHEATSHEET-官方文档.md](CHEATSHEET-官方文档.md)，毛玻璃/按压/液态玻璃查 [CHEATSHEET-玻璃与手感.md](CHEATSHEET-玻璃与手感.md)。
> **纪律**：`docs/reference/miuix-demo/**` 是只读上游副本，任何笔记写在 `CHEATSHEET-*.md` 里。

## 路径缩写

本文所有 `文件:行号` 的基目录都是：

```
SRC = docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/
```

例如 `component/CardSection.kt:33` 指 `SRC/component/CardSection.kt` 第 33 行。
`utils/PageUtils.kt`、`MainPage.kt`、`SettingsPage.kt`、`AppContent.kt` 同理。

## 覆盖口径（先把「26 个 Section」这笔账对清楚）

`SRC/component/` 下实际是 **25 个 .kt**：

| 类别 | 数量 | 文件 |
|---|---|---|
| `*Section.kt`（真正注册进 `MainPage` 的 Section） | **23** | Arrow / Badge / BasicComponent / Blur / BottomSheet / BreadcrumbBar / Button / Card / Checkbox / ColorPicker / Dialog / Dropdown / NumberPicker / OtherPage / ProgressIndicator / RadioButton / Slider / Snackbar / Spinner / Switch / TabRow / TextField / Tooltip |
| 非 Section 的组件范例（被页面直接调用，不是 `LazyListScope` 扩展） | **2** | `SuperSearchBar.kt`、`BackNavigationIcon.kt` |
| 子目录（`animation/` `highlight/` `liquid/` `effect/` `blend/`，属「玻璃与手感」专题） | 11 | 见 CHEATSHEET-玻璃与手感.md |

`MainPage.kt:362-384` 依次注册了 **23 个** `xxxSection()`（顺序：basicComponent → switch → checkbox →
radioButton → button → tabRow → breadcrumbBar → arrow → dialog → bottomSheet → dropdown → spinner →
snackbar → textField → progressIndicator → slider → card → tooltip → badge → numberPicker →
colorPicker → blur → otherPage）。

> **核对结论**：本仓实际可精读的 component 范例文件是 **25 个**（23 Section + 2 组件），
> 另有 `BlurSection`/`SliderSection`/`ColorPickerSection` 各自内含多个 `SmallTitle` 子分组
> （Blur 3 组、Slider 3 组、ColorPicker 5 组），按「子分组」口径数才是 26+。
> 本文**逐条覆盖 25/25 个文件、以及全部子分组**，不遗漏。

---

# 0. 六条前置事实（不懂这六条，抄出来的页面一定错位）

全部有源码出处，均可复核（本地依赖 `miuix-*-0.9.4-sources.jar` 与官方 `docs/components/*.md`）。

| # | 事实 | 出处 | 后果 |
|---|---|---|---|
| 1 | `CardDefaults.InsideMargin = PaddingValues(0.dp)`；`Card` 只把内容包在 `Column(Modifier.padding(insideMargin))` 里，**对 Preference 没有任何特殊照顾** | `basic/Card.kt`；`docs/components/card.md:56` | Card 里塞 `SwitchPreference` 时**不要**再传 `insideMargin`，否则 16+16=32dp 双内边距 |
| 2 | 所有 `*Preference` 默认 `insideMargin = BasicComponentDefaults.InsideMargin = PaddingValues(16.dp)`，且 **BasicComponent 自己不画行间分割线** | `preference/SwitchPreference.kt`、`basic/Component.kt:266`；`docs/components/basiccomponent.md:162` | 设置行天生自带 16dp 内边距；行与行之间**没有**官方分割线 |
| 3 | `SmallTitleDefaults.InsideMargin = PaddingValues(28.dp, 8.dp)`（水平 28 / 垂直 8） | `docs/components/smalltitle.md:64` | **28 = 12（Card 外边距）+ 16（Preference 内边距）** —— 这就是「分组标题和设置行左对齐」的全部秘密 |
| 4 | `Scaffold` 默认注入 `popupHost = { MiuixPopupHost() }`，并有 `snackbarHost` 槽 | `basic/Scaffold.kt:87-88`；`docs/components/overlaydialog.md:1-9`（`requiresScaffoldHost: true`） | `Overlay*` 系（OverlayDialog / OverlayBottomSheet / OverlayDropdownPreference …）**必须在 `Scaffold` 子树里**，否则弹不出来；`Window*` 系不需要 |
| 5 | `PressFeedbackType` 三档：`None` / `Sink`（下沉缩放，`sinkAmount=0.94f, spring(0.8f,600f)`）/ `Tilt`（跟手倾斜，`tiltAmount=8f, spring(0.6f,400f)`） | `utils/PressFeedback.kt:176-184`（`SinkFeedback`/`TiltFeedback` 默认值在同文件 30、84 行） | 默认是 `None` + `showIndication = false`，**必须显式开**才有手感 |
| 6 | 官方页面骨架固定四件套：`Scaffold(topBar=BlurredBar{AdaptiveTopAppBar})` → `Box(layerBackdrop?){LazyColumn(pageScrollModifiers, pageContentPadding)}` → `SmallTitle` 分组 + `Card` 包行 → `VerticalScrollBar` 显式挂 | `MainPage.kt`、`SettingsPage.kt`、`utils/PageUtils.kt` | 见本文 §3 |

---

# 1. Section 逐条索引（23 条，按 `MainPage` 注册顺序）

每条格式：**演示的组件** → **`文件:行号`** → **可照抄代码** → **要点**。

---

## 1.1 basicComponentSection — `BasicComponent`

`component/BasicComponentSection.kt:18`（`SmallTitle` 20 / `Card` 21-25 / 两条 `BasicComponent` 26-72）

```kotlin
// BasicComponentSection.kt:20-48
SmallTitle(text = "Basic Component")
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    BasicComponent(
        title = "Title",
        summary = "Summary",
        startAction = {
            Text(
                text = "Start",
            )
        },
        endActions = {
            Text(
                text = "End1",
                fontSize = MiuixTheme.textStyles.body2.fontSize,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                text = "End2",
                fontSize = MiuixTheme.textStyles.body2.fontSize,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        enabled = true,
    )
    // 26-48 是 enabled 版本；49-72 是同结构 enabled = false 版本，
    // 颜色换成 MiuixTheme.colorScheme.disabledOnSecondaryVariant
}
```

**要点**：`BasicComponent` 是所有 `*Preference` 的底座（`SwitchPreference` 等内部就是调它）。
`endActions` 是 `RowScope`，多个尾部文本用 `Spacer(Modifier.width(8.dp))` 隔开；
尾部文本字号取 `MiuixTheme.textStyles.body2.fontSize`、颜色取 `onSurfaceVariantActions`——
**这两条是官方尾部文本的固定配色配方**，后续所有 Section 都在重复。

---

## 1.2 switchSection — `Switch` / `SwitchPreference`

`component/SwitchSection.kt:27`（`SmallTitle` 35 / `Card` 36-40 / 裸 `Switch` 41-68 / `SwitchPreference` 69-76 / 折叠嵌套 78-97 / disabled 98-103）

```kotlin
// SwitchSection.kt:35-76
SmallTitle(text = "Switch")
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    // 裸 Switch：只在「做组件展示页」时这样用；真实页面用 SwitchPreference
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Switch(
            checked = switch.value,
            onCheckedChange = { switch.value = it },
        )
        Switch(
            checked = switchTrue.value,
            onCheckedChange = { switchTrue.value = it },
            modifier = Modifier.padding(start = 6.dp),
        )
        Switch(
            checked = false,
            onCheckedChange = { },
            modifier = Modifier.padding(start = 6.dp),
            enabled = false,
        )
        Switch(
            checked = true,
            onCheckedChange = { },
            modifier = Modifier.padding(start = 6.dp),
            enabled = false,
        )
    }
    SwitchPreference(
        title = "Switch",
        summary = "Click to expand a Switch",
        checked = superSwitchAnimState.value,
        onCheckedChange = {
            superSwitchAnimState.value = it
        },
    )
```

```kotlin
// SwitchSection.kt:78-103 —— 官方「父开关展开子项」写法
AnimatedVisibility(
    visible = superSwitchAnimState.value,
    enter = fadeIn() + expandVertically(),
    exit = fadeOut() + shrinkVertically(),
) {
    SwitchPreference(
        title = "Switch",
        checked = superSwitchState.value,
        endActions = {
            Text(
                text = superSwitch.value,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        onCheckedChange = {
            superSwitchState.value = it
            superSwitch.value = "$it"
        },
    )
}
SwitchPreference(
    title = "Disabled Switch",
    checked = true,
    enabled = false,
    onCheckedChange = {},
)
```

**要点**：折叠展开用 `AnimatedVisibility(enter = fadeIn() + expandVertically(), exit = fadeOut() + shrinkVertically())`
——**这四个动画是官方统一写法**，后面所有「跟着开关出现的子项」都这么写（`SettingsPage.kt` 里 12 处）。
另外 `SettingsPage.kt:135` 等处直接写 `AnimatedVisibility(visible = ...)`（用默认动画）也能跑，但 demo 里的显式写法是标准。

---

## 1.3 checkboxSection — `Checkbox` / `CheckboxPreference`

`component/CheckboxSection.kt:27`（`Card` 30-34 / 裸 `Checkbox` 行 49-99 / `CheckboxLocation.End` 105-117 / 普通 124-129 / disabled 38-43）

```kotlin
// CheckboxSection.kt:30-44
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    CheckboxRow()
    CheckboxPreferenceEndDemo()
    CheckboxPreferenceDemo()
    CheckboxPreference(
        title = "Disabled Checkbox",
        checked = true,
        enabled = false,
        onCheckedChange = {},
    )
}
```

```kotlin
// CheckboxSection.kt:60-85 —— 裸 Checkbox 用 ToggleableState，三态是官方特性
Checkbox(
    state = ToggleableState(checkbox),
    onClick = { checkbox = !checkbox },
)
Checkbox(
    state = checkboxIndeterminate,           // ToggleableState.Indeterminate
    onClick = {
        checkboxIndeterminate = when (checkboxIndeterminate) {
            ToggleableState.Off -> ToggleableState.Indeterminate
            ToggleableState.Indeterminate -> ToggleableState.On
            ToggleableState.On -> ToggleableState.Off
        }
    },
    modifier = Modifier.padding(start = 8.dp),
)
```

```kotlin
// CheckboxSection.kt:105-117 —— 勾选框放右边的写法
CheckboxPreference(
    checkboxLocation = CheckboxLocation.End,
    title = "Checkbox",
    checked = checked,
    endActions = {
        Text(
            text = "$checked",
            fontSize = MiuixTheme.textStyles.body2.fontSize,
            color = MiuixTheme.colorScheme.onSurfaceVariantActions,
        )
    },
    onCheckedChange = { checked = it },
)
```

**要点**：`CheckboxLocation.End` 让勾选框去右侧（默认在左侧）；裸 `Checkbox` 的入参是
`ToggleableState` 而不是 `Boolean`。

---

## 1.4 radioButtonSection — `RadioButtonPreference`

`component/RadioButtonSection.kt:19`（`SmallTitle` 21 / 单选项各自一个 `Card` 40-56 / disabled 23-35）

```kotlin
// RadioButtonSection.kt:40-56 —— 注意：官方给每个选项各包一个 Card
@Composable
private fun RadioButtonCardsDemo() {
    var selectedIndex by remember { mutableIntStateOf(0) }

    listOf("Option A", "Option B", "Option C").forEachIndexed { index, title ->
        Card(
            modifier = Modifier
                .padding(horizontal = 12.dp)
                .padding(bottom = 12.dp),
        ) {
            RadioButtonPreference(
                title = title,
                summary = "Selected: ${selectedIndex == index}",
                selected = selectedIndex == index,
                onClick = { selectedIndex = index },
            )
        }
    }
}
```

```kotlin
// RadioButtonSection.kt:23-35 —— 同一张 Card 里也可以塞一个 disabled 项
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    RadioButtonPreference(
        title = "Disabled RadioButton",
        summary = "This option is unavailable",
        selected = true,
        enabled = false,
        onClick = {},
    )
}
```

**要点**：`RadioButtonPreference` 用 `selected: Boolean` + `onClick`（不是 `onCheckedChange`）。
官方 demo 把每个选项分卡（视觉上更重），也可以像 disabled 那条一样合并进一张 Card——两种都合法。

---

## 1.5 buttonSection — `TextButton`

`component/ButtonSection.kt:23`（`SmallTitle` 30 / 一组两枚 31-55 / disabled 组 56-76）

```kotlin
// ButtonSection.kt:31-55
SmallTitle(text = "Button")
Row(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    horizontalArrangement = Arrangement.SpaceBetween,
) {
    TextButton(
        text = buttonText,
        onClick = {
            clickCount++
            buttonText = "Click: $clickCount"
        },
        modifier = Modifier.weight(1f),
    )
    Spacer(Modifier.width(12.dp))
    TextButton(
        text = submitButtonText,
        onClick = {
            submitClickCount++
            submitButtonText = "Click: $submitClickCount"
        },
        modifier = Modifier.weight(1f),
        colors = ButtonDefaults.textButtonColorsPrimary(),
    )
}
```

**要点**：miuix 的按钮叫 `TextButton`（不是 Material 的 `Button`）；主按钮用
`colors = ButtonDefaults.textButtonColorsPrimary()`；并排两枚 = `Row` + 各 `weight(1f)` +
中间 `Spacer(Modifier.width(12.dp))`（不是 `Arrangement.spacedBy`）。禁用传 `enabled = false`。

---

## 1.6 tabRowSection — `TabRow` / `TabRowWithContour` + `HorizontalPager`

`component/TabRowSection.kt:30`（`TabRow` 37-47 / `Card` 内 `TabRowWithContour` + Pager 48-88）

```kotlin
// TabRowSection.kt:33-47
val tabTexts = remember { listOf("Tab 1", "Tab 2", "Tab 3") }
var selectedTabIndex by remember { mutableIntStateOf(0) }
val tabListState = rememberLazyListState()
TabRow(
    tabs = tabTexts,
    selectedTabIndex = selectedTabIndex,
    onTabSelected = {
        selectedTabIndex = it
    },
    listState = tabListState,
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
)
```

```kotlin
// TabRowSection.kt:48-88 —— 带轮廓的 TabRow + 可滑的 Pager，官方把两者用 springAnimateToPage 串起来
Card(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    insideMargin = PaddingValues(16.dp),      // 内容不是 Preference，必须自己给内边距
) {
    val scope = rememberCoroutineScope()
    val pagerState = rememberPagerState(pageCount = { tabTexts1.size })
    val contourTabListState = rememberLazyListState()
    TabRowWithContour(
        tabs = tabTexts1,
        selectedTabIndex = pagerState.currentPage,
        onTabSelected = {
            scope.launch {
                pagerState.springAnimateToPage(it)
            }
        },
        listState = contourTabListState,
    )
    val flingBehavior = PagerDefaults.flingBehavior(
        state = pagerState,
        snapAnimationSpec = PagerNavigationSpringSpec,
    )
    HorizontalPager(
        state = pagerState,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 12.dp),
        userScrollEnabled = true,
        flingBehavior = flingBehavior,
        key = { it },
        pageContent = { page ->
            Text(
                text = "Content of ${tabTexts1[page]}",
                modifier = Modifier
                    .fillMaxWidth(),
            )
        },
    )
}
```

**要点**：Tab 与 Pager 联动靠 `pagerState.springAnimateToPage(index)`（`top.yukonga.miuix.kmp.utils`）
+ `PagerNavigationSpringSpec` 作 `snapAnimationSpec`，**这是官方页面切换的「弹性」配方**，
`AppContent.kt:758-761` 的整页 Pager 用的是同一套。

---

## 1.7 breadcrumbBarSection — `BreadcrumbBar`

`component/BreadcrumbBarSection.kt:26`（`items` 29-40 / 裸放 43-51 / 包 `Card` 52-81）

```kotlin
// BreadcrumbBarSection.kt:29-51
val items = remember {
    listOf(
        BreadcrumbItem(
            path = "/storage/emulated/0",
            text = "Internal storage",
        ),
        BreadcrumbItem(path = "DataBackup"),
        BreadcrumbItem(path = "apps"),
        BreadcrumbItem(path = "com.tencent.mobileqq"),
        BreadcrumbItem(path = "user_0"),
    )
}
var highlightIndex by remember { mutableIntStateOf(items.size - 1) }

BreadcrumbBar(
    items = items,
    onItemClick = { index -> highlightIndex = index },
    highlightIndex = highlightIndex,
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
)
```

```kotlin
// BreadcrumbBarSection.kt:52-81 —— 放进 Card 时：Card 给 16dp，内部用 Column(spacedBy(12.dp))
Card(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    insideMargin = PaddingValues(16.dp),
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        BreadcrumbBar(
            items = items,
            onItemClick = { index -> highlightIndex = index },
            highlightIndex = highlightIndex,
            modifier = Modifier.fillMaxWidth(),
        )
        Text(
            text = "Full path: ${items.joinToPath()}",
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        )
        Text(
            text = "Current: ${items.subList(0, highlightIndex + 1).joinToPath()}",
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
        )
        BreadcrumbBar(
            items = items,
            onItemClick = {},
            modifier = Modifier.fillMaxWidth(),
            enabled = false,
        )
    }
}
```

**要点**：`items.joinToPath()` 是官方工具扩展函数（`top.yukonga.miuix.kmp.basic.joinToPath`），
拼路径用它，别自己 `joinToString("/")`。

---

## 1.8 arrowSection — `ArrowPreference` / `SliderPreference`

`component/ArrowSection.kt:37`（`Card` 44-48 / 带图标 `ArrowPreference` 49-70 / 带 `holdDownState` 的 `SliderPreference` 71-81 / disabled 82-92）

```kotlin
// ArrowSection.kt:43-92
SmallTitle(text = "Arrow")
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    ArrowPreference(
        title = "Arrow",
        startAction = {
            Box(
                modifier = Modifier.padding(end = 8.dp),
            ) {
                Icon(
                    imageVector = MiuixIcons.Contacts,
                    contentDescription = "Personal",
                    tint = MiuixTheme.colorScheme.onBackground,
                )
            }
        },
        endActions = {
            Text(
                text = "End",
                fontSize = MiuixTheme.textStyles.body2.fontSize,
                color = MiuixTheme.colorScheme.onSurfaceVariantActions,
            )
        },
        onClick = {},
    )
    SliderPreference(
        title = "Volume",
        valueText = "${(volume * 100).toInt()}%",
        value = volume,
        onValueChange = { volume = it },
        onClick = {
            showVolumeDialog.value = true
            volumeDialogHoldDown.value = true      // ← 关键：弹窗期间保持按下态
        },
        holdDownState = volumeDialogHoldDown.value,
    )
    ArrowPreference(
        title = "Disabled Arrow",
        endActions = {
            Text(
                text = "End",
                fontSize = MiuixTheme.textStyles.body2.fontSize,
                color = MiuixTheme.colorScheme.disabledOnSecondaryVariant,
            )
        },
        enabled = false,
    )
}
```

```kotlin
// ArrowSection.kt:95-100 —— 配套的弹窗关闭回调，负责松开按下态
SliderDialog(
    showVolumeDialog,
    volumeState = { volume },
    onVolumeChange = { volume = it },
    onDismissFinished = { volumeDialogHoldDown.value = false },
)
```

**要点**：`ArrowPreference` 的左侧图标要自己用 `Box(Modifier.padding(end = 8.dp))` 包一层——
官方固定 8dp；`SliderPreference` 既能拖（`onValueChange`）又能点开弹窗（`onClick`）。

---

## 1.9 dialogSection — `OverlayDialog` / `WindowDialog`

`component/DialogSection.kt:41`（入口 `Card` 55-105 / Overlay 141-165 / Window 174-199 / 居中 208-233 / 宽屏 245-255、267-277 / 宽屏内容 281-371）

```kotlin
// DialogSection.kt:55-105 —— 5 个入口全是「ArrowPreference + holdDownState」配方
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    ArrowPreference(
        title = "Dialog (O)",
        summary = "Click to show an OverlayDialog",
        onClick = {
            showOverlayDialog = true
            overlayDialogHoldDown = true
        },
        holdDownState = overlayDialogHoldDown,
    )
    ArrowPreference(
        title = "Dialog (W)",
        summary = "Click to show a WindowDialog",
        onClick = {
            showWindowDialog = true
            windowDialogHoldDown = true
        },
        holdDownState = windowDialogHoldDown,
    )
    // 另三条同构：Wide Dialog (O) 78-86 / Wide Dialog (W) 87-95 / Centered Dialog (O) 96-104
}
```

```kotlin
// DialogSection.kt:141-165 —— OverlayDialog（需要 Scaffold 提供 MiuixPopupHost）
OverlayDialog(
    show = show,
    title = "Dialog (O)",
    summary = "A dialog component inside MiuixPopupHost.",
    onDismissRequest = onDismissRequest,
    onDismissFinished = onDismissFinished,
    content = {
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(
                text = "Cancel",
                onClick = onDismissRequest,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(20.dp))
            TextButton(
                text = "Confirm",
                onClick = onDismissRequest,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.textButtonColorsPrimary(),
            )
        }
    },
)
```

```kotlin
// DialogSection.kt:174-199 —— WindowDialog（不需要 MiuixPopupHost，用 LocalDismissState 关闭）
WindowDialog(
    show = show,
    title = "Dialog (W)",
    summary = "A window-level dialog, no MiuixPopupHost required.",
    onDismissRequest = onDismissRequest,
    onDismissFinished = onDismissFinished,
    content = {
        val dismissState = LocalDismissState.current
        Row(
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            TextButton(
                text = "Cancel",
                onClick = { dismissState?.invoke() },
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(20.dp))
            TextButton(
                text = "Confirm",
                onClick = { dismissState?.invoke() },
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.textButtonColorsPrimary(),
            )
        }
    },
)
```

```kotlin
// DialogSection.kt:208-233 —— 强制「大屏居中」形态
OverlayDialog(
    show = show,
    title = "Centered Dialog",
    summary = "largeScreen = true forces the centered presentation on any window size.",
    largeScreen = true,
    onDismissRequest = onDismissRequest,
    onDismissFinished = onDismissFinished,
    content = { /* Cancel / Confirm 同上 */ },
)
```

```kotlin
// DialogSection.kt:242-255 —— 横屏自动变「左右两栏宽弹窗」
val windowSize = LocalWindowInfo.current.containerDpSize
val isLandscape = windowSize.width > windowSize.height

OverlayDialog(
    show = show,
    title = if (isLandscape) null else "Wide Dialog",
    summary = if (isLandscape) null else "Rotate to landscape to see the effect.",
    maxWidth = if (isLandscape) 560.dp else DialogDefaults.MaxWidth,
    onDismissRequest = onDismissRequest,
    onDismissFinished = onDismissFinished,
    content = {
        WideDialogContent(isLandscape = isLandscape)
    },
)
```

```kotlin
// DialogSection.kt:317-321 —— 两栏之间的竖分割线
VerticalDivider(
    modifier = Modifier
        .fillMaxHeight()
        .padding(horizontal = 20.dp),
)
```

**要点**：
1. 弹窗入口一律 `ArrowPreference(..., holdDownState = xxxHoldDown)`，`onClick` 里同时置
   `show = true` 与 `holdDown = true`，弹窗的 `onDismissFinished` 里置回 `false`
   —— **这是官方「点了之后行保持按下态直到弹窗消失」的唯一写法**，凡开弹窗的设置行都该照抄。
2. 用 `Overlay*` 系必须在 `Scaffold` 下（`Scaffold` 默认注入 `MiuixPopupHost`）。
3. 宽屏两栏形态靠 `maxWidth = 560.dp` + 内容里按 `isLandscape` 分支，不是另一个组件。

---

## 1.10 bottomSheetSection — `OverlayBottomSheet` / `WindowBottomSheet`

`component/BottomSheetSection.kt:47`（入口 `Card` 57-80 / Overlay 116-145 / Window 161-192 / 共用内容 200-268 / 动作按钮 271-285）

```kotlin
// BottomSheetSection.kt:57-80
SmallTitle(text = "BottomSheet")
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    ArrowPreference(
        title = "BottomSheet (O)",
        summary = "Click to show an OverlayBottomSheet",
        onClick = {
            showSuperBottomSheet = true
            superBottomSheetHoldDown = true
        },
        holdDownState = superBottomSheetHoldDown,
    )
    ArrowPreference(
        title = "BottomSheet (W)",
        summary = "Click to show a WindowBottomSheet",
        onClick = {
            showWindowBottomSheet = true
            windowBottomSheetHoldDown = true
        },
        holdDownState = windowBottomSheetHoldDown,
    )
}
```

```kotlin
// BottomSheetSection.kt:116-145 —— Overlay 版：startAction / endAction 是底部的取消/确认
OverlayBottomSheet(
    title = "BottomSheet (O)",
    show = show,
    allowDismiss = allowDismiss,
    enableNestedScroll = enableNestedScroll,
    onDismissRequest = onDismissRequest,
    onDismissFinished = onDismissFinished,
    startAction = {
        BottomSheetActionButton(MiuixIcons.Close, "Cancel", onClick = onDismissRequest)
    },
    endAction = {
        BottomSheetActionButton(MiuixIcons.Ok, "Confirm", onClick = onDismissRequest)
    },
) {
    BottomSheetContent(
        allowDismiss = allowDismiss,
        onAllowDismissChange = { allowDismiss = it },
        enableNestedScroll = enableNestedScroll,
        onEnableNestedScrollChange = { enableNestedScroll = it },
        switchChecked = switchChecked,
        onSwitchCheckedChange = onSwitchCheckedChange,
    ) {
        OverlayDropdownPreference(
            title = "DropdownPref (O)",
            items = BottomSheetDropdownOptions,
            selectedIndex = dropdownSelectedIndex,
            onSelectedIndexChange = onDropdownSelectedIndexChange,
        )
    }
}
```

```kotlin
// BottomSheetSection.kt:200-268 —— 抽屉内容骨架：LazyColumn + SmallTitle + Card(secondaryContainer)
@Composable
private fun BottomSheetContent(
    allowDismiss: Boolean,
    onAllowDismissChange: (Boolean) -> Unit,
    enableNestedScroll: Boolean,
    onEnableNestedScrollChange: (Boolean) -> Unit,
    switchChecked: Boolean,
    onSwitchCheckedChange: (Boolean) -> Unit,
    dropdown: @Composable () -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxWidth()
            .scrollEndHaptic()
            .overScrollVertical(),
    ) {
        item {
            SmallTitle(
                text = "Behavior Settings",
                insideMargin = PaddingValues(16.dp, 8.dp),
            )
            Card(
                modifier = Modifier.padding(bottom = 12.dp),
                colors = CardDefaults.defaultColors(
                    color = MiuixTheme.colorScheme.secondaryContainer,
                ),
            ) {
                SwitchPreference(
                    title = "Allow Dismiss",
                    summary = "Drag or Back to dismiss",
                    checked = allowDismiss,
                    onCheckedChange = onAllowDismissChange,
                )
                SwitchPreference(
                    title = "Enable NestedScroll",
                    summary = "Scroll content vs Drag sheet",
                    checked = enableNestedScroll,
                    onCheckedChange = onEnableNestedScrollChange,
                )
            }
        }
        item {
            var textFieldValue by remember { mutableStateOf("") }
            TextField(
                value = textFieldValue,
                onValueChange = { textFieldValue = it },
                label = "TextField",
                modifier = Modifier.padding(bottom = 12.dp),
            )
            Card(
                modifier = Modifier.padding(bottom = 12.dp),
                colors = CardDefaults.defaultColors(
                    color = MiuixTheme.colorScheme.secondaryContainer,
                ),
            ) {
                dropdown()
                SwitchPreference(
                    title = "SwitchPref",
                    checked = switchChecked,
                    onCheckedChange = onSwitchCheckedChange,
                )
            }
            Spacer(
                Modifier.padding(
                    bottom = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() +
                        WindowInsets.captionBar.asPaddingValues().calculateBottomPadding(),
                ),
            )
        }
    }
}
```

**要点**：
1. 抽屉内部的 `SmallTitle` 用 `insideMargin = PaddingValues(16.dp, 8.dp)`——因为抽屉里 Card **没有**
   外面那 12dp，16dp 才对得齐（这是 §3 那条「28 = 12 + 16」的镜像用法）。
2. 抽屉里 Card 用 `secondaryContainer` 底色区分层级。
3. 底部要手动补 `WindowInsets.navigationBars + captionBar` 的 `Spacer`，否则最后一行被系统条压住。
4. 抽屉里的滚动修饰直接用 `Modifier.scrollEndHaptic().overScrollVertical()`（没有顶栏，所以不带 `nestedScroll`）。

---

## 1.11 dropdownSection — `OverlayDropdownPreference` / `WindowDropdownPreference`

`component/DropdownSection.kt:22`（`Card` 135-139 / 普通 140-149 / Window 150-159 / 分组 55-88 + 160-173 / disabled 174-187）

```kotlin
// DropdownSection.kt:140-159
OverlayDropdownPreference(
    title = "DropdownPref (O)",
    summary = if (overlayExpanded) "Expanded" else "Collapsed",
    items = dropdownOptions,                    // List<String>
    selectedIndex = overlayDropdownOptionSelected,
    onSelectedIndexChange = { newOption ->
        overlayDropdownOptionSelected = newOption
    },
    onExpandedChange = { overlayExpanded = it },   // 可选：想拿展开状态就传
)
WindowDropdownPreference(
    title = "DropdownPref (W)",
    summary = if (windowExpanded) "Expanded" else "Collapsed",
    items = dropdownLongOptions,
    selectedIndex = windowDropdownOptionSelected,
    onSelectedIndexChange = { newOption ->
        windowDropdownOptionSelected = newOption
    },
    onExpandedChange = { windowExpanded = it },
)
```

```kotlin
// DropdownSection.kt:55-88 —— 分组下拉的数据结构（DropdownEntry 分组，DropdownItem 是选项）
listOf(
    DropdownEntry(
        items = listOf("Option A-1", "Option A-2")
            .mapIndexed { index, text ->
                DropdownItem(
                    text = text,
                    selected = overlayGroup1DropdownOptionSelected == index,
                    onClick = { overlayGroup1DropdownOptionSelected = index },
                )
            },
    ),
    DropdownEntry(
        items = listOf("Option B-1", "Option B-2", "Option B-3")
            .mapIndexed { index, text ->
                DropdownItem(
                    text = text,
                    selected = overlayGroup2DropdownOptionSelected == index,
                    onClick = { overlayGroup2DropdownOptionSelected = index },
                )
            },
    ),
    DropdownEntry(
        items = listOf("Option C-1", "Option C-2", "Option C-3", "Option C-4")
            .mapIndexed { index, string ->
                DropdownItem(
                    text = string,
                    enabled = index % 2 == 0,      // ← 单个选项也能禁用
                    selected = overlayGroup3DropdownOptionSelected == index,
                    onClick = { overlayGroup3DropdownOptionSelected = index },
                )
            },
    ),
)
```

```kotlin
// DropdownSection.kt:160-173 —— 分组版调用（传 entries 而不是 items）
OverlayDropdownPreference(
    title = "Grouped DropdownPref (O)",
    summary = if (overlayGroupedExpanded) "Expanded" else "Collapsed",
    entries = overlayMultiGroupOptions,
    collapseOnSelection = false,               // 多选/分组时不要选完就收
    onExpandedChange = { overlayGroupedExpanded = it },
)
```

```kotlin
// DropdownSection.kt:174-187 —— 禁用
OverlayDropdownPreference(
    title = "Disabled DropdownPref (O)",
    items = listOf("Option 1"),
    selectedIndex = 0,
    onSelectedIndexChange = {},
    enabled = false,
)
```

**要点**：单层选项用 `items: List<String>` + `selectedIndex`；分组/多选/嵌套用
`entries: List<DropdownEntry>` + `collapseOnSelection = false`。**同一个组件两种入参，二选一。**

---

## 1.12 spinnerSection — `OverlaySpinnerPreference` / `WindowSpinnerPreference`

`component/SpinnerSection.kt:29`（选项数据 55-106 / `Card` 173-177 / 普通 178-193 / 对话框形态 194-211 / 分组 212-225 / disabled 240-255 / 数据构造 260-304）

```kotlin
// SpinnerSection.kt:55-106 —— 选项带图标 + 摘要（DropdownItem 的三件套）
val spinnerOptions = remember {
    listOf(
        DropdownItem(
            icon = {
                Icon(
                    RoundedRectanglePainter(),
                    "Icon",
                    Modifier.padding(end = 12.dp),
                    Color(0xFFFF5B29),
                )
            },
            text = "Option 1",
            summary = "Red",
        ),
        // Option 2 / 3 / 4 同构，颜色分别 0xFF36D167 / 0xFF3482FF / 0xFFFFB21D
    )
}
```

```kotlin
// SpinnerSection.kt:178-211
OverlaySpinnerPreference(
    title = "SpinnerPref (O)",
    summary = if (overlayExpanded) "Expanded" else "Collapsed",
    items = spinnerOptions,
    selectedIndex = superSpinnerOptionSelected.value,
    onSelectedIndexChange = { newOption -> superSpinnerOptionSelected.value = newOption },
    onExpandedChange = { overlayExpanded = it },
)
OverlaySpinnerPreference(
    title = "SpinnerPref (O)",
    summary = "As Dialog (O)" + if (overlayDialogExpanded) " (Expanded)" else " (Collapsed)",
    dialogButtonString = "OK",                 // ← 传了它就变成「对话框里滚轮选」
    items = spinnerOptions,
    selectedIndex = superSpinnerOptionSelectedDialog.value,
    onSelectedIndexChange = { newOption -> superSpinnerOptionSelectedDialog.value = newOption },
    onExpandedChange = { overlayDialogExpanded = it },
)
```

```kotlin
// SpinnerSection.kt:212-225 —— 分组滚轮
OverlaySpinnerPreference(
    title = "Grouped SpinnerPref (O)",
    summary = if (overlayGroupedExpanded) "Expanded" else "Collapsed",
    entries = overlayGroupedSpinnerOptions,    // List<DropdownEntry>
    collapseOnSelection = false,
    onExpandedChange = { overlayGroupedExpanded = it },
)
```

**要点**：`dialogButtonString = "OK"` 是从「内联滚轮」切到「对话框滚轮」的开关；
分组数据构造见 `groupedSpinnerOptions()`（260-304），核心是 `item.copy(selected = ..., onClick = ...)`。

---

## 1.13 snackbarSection — `SnackbarHostState.showSnackbar`

`component/SnackbarSection.kt:28`（`Card` + `Column` 32-42 / 各时长与形态 70-178）

```kotlin
// SnackbarSection.kt:32-42 —— 一屏按钮塞进一张 Card 的固定写法
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    Column(
        modifier = Modifier
            .padding(horizontal = 12.dp)
            .padding(vertical = 12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // 下面每行是 Row(horizontalArrangement = Arrangement.spacedBy(12.dp),
        //                          modifier = Modifier.fillMaxWidth())
        // + 每枚 TextButton(modifier = Modifier.weight(1f))
    }
}
```

```kotlin
// SnackbarSection.kt:70-91 —— 默认 4s / 显式 10s
scope.launch {
    snackbarHostState.showSnackbar("This message stays for 4 seconds.")
}
scope.launch {
    snackbarHostState.showSnackbar(
        message = "This is a longer message that stays for 10 seconds.",
        duration = SnackbarDuration.Long,
    )
}
```

```kotlin
// SnackbarSection.kt:96-107 —— 自定义时长
snackbarHostState.showSnackbar(
    message = "This message uses a custom 2-second duration.",
    duration = SnackbarDuration.Custom(2000L),
)
```

```kotlin
// SnackbarSection.kt:109-127 —— 带动作按钮 + 拿用户的选择结果
val result = snackbarHostState.showSnackbar(
    message = "This message has an action button.",
    actionLabel = "Undo",
    duration = SnackbarDuration.Short,
)
text = when (result) {
    SnackbarResult.ActionPerformed -> "Action: Undo"
    else -> "Action: Expired"
}
```

```kotlin
// SnackbarSection.kt:133-158 —— 可手动关 / 常驻
snackbarHostState.showSnackbar(
    message = "Tap the close button to dismiss this message.",
    withDismissAction = true,
    duration = SnackbarDuration.Long,
)
snackbarHostState.showSnackbar(
    message = "This message stays until you dismiss it manually.",
    withDismissAction = true,
    duration = SnackbarDuration.Indefinite,
)
```

```kotlin
// SnackbarSection.kt:164-177 —— 动作 + 关闭按钮同时要
snackbarHostState.showSnackbar(
    message = "This message has both an action and a close button.",
    actionLabel = "Undo",
    withDismissAction = true,
    duration = SnackbarDuration.Long,
)
```

**要点**：`SnackbarHostState` 由页面持有（`AppContent.kt:390`），挂在 `Scaffold(snackbarHost = { SnackbarHost(state = snackbarHostState) })`
（`AppContent.kt:402`、`500-502`）；`showSnackbar` 是挂起函数，必须 `scope.launch { }`。
`SnackbarHostState` 还提供 `oldestSnackbarData()` / `newestSnackbarData()?.dismiss()`（47-64）用于手动清。

---

## 1.14 textFieldSection — `TextField`

`component/TextFieldSection.kt:23`（四种入参形态 33-72）

```kotlin
// TextFieldSection.kt:33-72
TextField(
    value = text1,
    onValueChange = { text1 = it },
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
)
TextField(
    value = text2,                             // TextFieldValue 版
    onValueChange = { text2 = it },
    label = "With title",
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
)
TextField(
    state = text3,                             // rememberTextFieldState 版（无 value/onValueChange）
    label = "State-based",
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    onKeyboardAction = { focusManager.clearFocus() },
    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
)
TextField(
    value = text4,
    onValueChange = { text4 = it },
    label = "Placeholder & SingleLine",
    useLabelAsPlaceholder = true,               // label 同时当占位符，不另给 placeholder
    singleLine = true,
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    keyboardActions = KeyboardActions(onDone = { focusManager.clearFocus() }),
    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
)
```

**要点**：`TextField` **直接放 `LazyColumn` item 里**（不包 Card），自己带 `padding(horizontal = 12.dp)`
——这就是官方「整行输入框」的标准位置。要占位符就用 `useLabelAsPlaceholder = true`。

---

## 1.15 progressIndicatorSection — `Linear/Circular/InfiniteProgressIndicator`

`component/ProgressIndicatorSection.kt:25`（动画值 29-36 / 线性 38-50 / 一排圆环 52-71）

```kotlin
// ProgressIndicatorSection.kt:28-36 —— 不定进度用无限往复动画喂 progress
val progressValues = listOf(0.0f, 0.25f, 0.5f, 0.75f, 1.0f, null)
val animatedProgressValue by rememberInfiniteTransition().animateFloat(
    initialValue = 0f,
    targetValue = 1f,
    animationSpec = infiniteRepeatable(
        animation = tween(1000),
        repeatMode = RepeatMode.Reverse,
    ),
)
```

```kotlin
// ProgressIndicatorSection.kt:38-50
LinearProgressIndicator(
    progress = animatedProgressValue,
    modifier = Modifier
        .padding(horizontal = 15.dp)      // Increased from 12.dp.  ← 官方注释，横向 15 才对齐
        .padding(bottom = 12.dp),
)
```

```kotlin
// ProgressIndicatorSection.kt:52-71
FlowRow(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    horizontalArrangement = Arrangement.SpaceEvenly,
) {
    CircularProgressIndicator(
        progress = animatedProgressValue,
    )
    progressValues.forEach { progressValue ->
        CircularProgressIndicator(
            progress = progressValue,          // null = 不定进度
        )
    }
    InfiniteProgressIndicator(
        modifier = Modifier
            .align(alignment = Alignment.CenterVertically),
    )
}
```

**要点**：`progress = null` 表示不定进度；「无限转圈」是另一个组件 `InfiniteProgressIndicator`；
一排圆环用 `FlowRow` + `Arrangement.SpaceEvenly`。

---

## 1.16 sliderSection — `SliderPreference` / `RangeSliderPreference` / `VerticalSlider`

`component/SliderSection.kt:32`（Slider 组 35-91 / RangeSlider 组 94-140 / VerticalSlider 组 143-255）

```kotlin
// SliderSection.kt:41-90 —— 五种 SliderPreference
var sliderValue by remember { mutableFloatStateOf(0.3f) }
SliderPreference(
    value = sliderValue,
    onValueChange = { sliderValue = it },
    title = "Normal",
    valueText = "${(sliderValue * 100).toInt()}%",
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),   // ← 底部留 0，与下一行贴紧
)
var stepsValue by remember { mutableFloatStateOf(100f) }
SliderPreference(
    value = stepsValue,
    onValueChange = { stepsValue = it },
    title = "Steps",
    valueText = "${stepsValue.toInt()}/200",
    valueRange = 0f..200f,
    steps = 199,
    hapticEffect = SliderDefaults.SliderHapticEffect.Step,      // ← 每档轻震
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),
)
var stepsWithKeyPointsValue by remember { mutableFloatStateOf(5f) }
SliderPreference(
    value = stepsWithKeyPointsValue,
    onValueChange = { stepsWithKeyPointsValue = it },
    title = "Steps with Key Points",
    valueText = "${stepsWithKeyPointsValue.toInt()}/8",
    valueRange = 0f..8f,
    steps = 7,
    hapticEffect = SliderDefaults.SliderHapticEffect.Step,
    showKeyPoints = true,                                       // ← 轨道上显示刻度点
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),
)
var customKeyPointsValue by remember { mutableFloatStateOf(25f) }
SliderPreference(
    value = customKeyPointsValue,
    onValueChange = { customKeyPointsValue = it },
    title = "Custom Key Points",
    valueText = "${customKeyPointsValue.toInt()}%",
    valueRange = 0f..100f,
    showKeyPoints = true,
    hapticEffect = SliderDefaults.SliderHapticEffect.Step,
    keyPoints = listOf(0f, 25f, 50f, 75f, 100f),                 // ← 自定义刻度位置
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),
)
val disabledValue = 0.7f
SliderPreference(
    value = disabledValue,
    onValueChange = {},
    title = "Disabled",
    valueText = "${(disabledValue * 100).toInt()}%",
    enabled = false,
)
```

```kotlin
// SliderSection.kt:101-139 —— 区间滑块
var rangeValue by remember { mutableStateOf(0.2f..0.8f) }
RangeSliderPreference(
    value = rangeValue,                                        // ClosedFloatingPointRange<Float>
    onValueChange = { rangeValue = it },
    title = "Range",
    valueText = "${(rangeValue.start * 100).toInt()}% - ${(rangeValue.endInclusive * 100).toInt()}%",
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),
)
RangeSliderPreference(
    value = rangeStepsValue,
    onValueChange = { rangeStepsValue = it },
    title = "Range with Key Points",
    valueText = "${rangeStepsValue.start.toInt()} - ${rangeStepsValue.endInclusive.toInt()}",
    valueRange = 0f..8f,
    steps = 7,
    hapticEffect = SliderDefaults.SliderHapticEffect.Step,
    showKeyPoints = true,
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),
)
RangeSliderPreference(
    value = customRangeValue,
    onValueChange = { customRangeValue = it },
    title = "Custom Range Points",
    valueText = "${customRangeValue.start.toInt()}% - ${customRangeValue.endInclusive.toInt()}%",
    valueRange = 0f..100f,
    showKeyPoints = true,
    hapticEffect = SliderDefaults.SliderHapticEffect.Step,
    keyPoints = listOf(0f, 20f, 40f, 60f, 80f, 100f),
    insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp),
)
RangeSliderPreference(
    value = disabledRangeValue,
    onValueChange = {},
    title = "Disabled",
    valueText = "${(disabledRangeValue.start * 100).toInt()}% - ${(disabledRangeValue.endInclusive * 100).toInt()}%",
    enabled = false,
)
```

```kotlin
// SliderSection.kt:162-166 —— 竖滑块（自己给尺寸）
VerticalSlider(
    value = verticalValue1,
    onValueChange = { verticalValue1 = it },
    modifier = Modifier.size(25.dp, 160.dp),
)
```

**要点**：官方对连续多条 Slider 统一用 `insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp)`
（左/上/右 16、**下 0**）来收紧行距；滑动的「手感」来自 `hapticEffect = SliderDefaults.SliderHapticEffect.Step`。

---

## 1.17 cardSection — `Card`（三种按压形态）

`component/CardSection.kt:33`。**本节内容全部在本文 §4 展开**（三种按压形态 + `holdDownState` 的
确切写法与行号），此处只登记入口：

```kotlin
// CardSection.kt:33-109
fun LazyListScope.cardSection() {
    item(key = "card") {
        SmallTitle(text = "Card")
        Card(...)                    // 36-60  静态 + showIndication
        Row(...) { Card(Sink) ; Card(Tilt) }   // 61-106 两种按压并排
        LongPressHoldDownCardDemo()  // 107     holdDownState 形态（定义在 111-169）
    }
}
```

---

## 1.18 tooltipSection — `TooltipBox` / `RichTooltipBox`

`component/TooltipSection.kt:25`（`state` 28 / 简版 42-46 / 富文本版 47-58）

```kotlin
// TooltipSection.kt:28-58
val richState = rememberTooltipState(isPersistent = true)
Card(
    modifier = Modifier
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
) {
    Column(
        modifier = Modifier.padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        FlowRow(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
        ) {
            TooltipBox(text = "Edit") {
                IconButton(onClick = {}) {
                    Icon(imageVector = MiuixIcons.Edit, contentDescription = "Edit")
                }
            }
            RichTooltipBox(
                title = "Rich tooltip",
                text = "Rich tooltips show a title, supporting text, and an optional action. " +
                    "Move onto the tooltip to use the action, or tap outside to dismiss.",
                actionText = "Got it",
                onActionClick = {},
                state = richState,
            ) {
                IconButton(onClick = {}) {
                    Icon(imageVector = MiuixIcons.Info, contentDescription = "Rich tooltip")
                }
            }
        }
    }
}
```

**要点**：简版 `TooltipBox(text = ...) { 任意可点内容 }`；富文本版要先
`rememberTooltipState(isPersistent = true)`（点一下常驻，而不是悬停即走）再传给 `RichTooltipBox(state = ...)`。
`MainPage.kt:266-298` 里顶栏图标的长按提示用的就是简版 `TooltipBox`。

---

## 1.19 badgeSection — `BadgedBox` / `Badge`

`component/BadgeSection.kt:27`（`Card` 30-34 / 四种角标 44-71）

```kotlin
// BadgeSection.kt:44-71
BadgedBox(badge = { Badge() }) {                      // 小红点
    Icon(
        imageVector = MiuixIcons.Messages,
        contentDescription = "Messages",
        modifier = Modifier.size(28.dp),
    )
}
BadgedBox(badge = { Badge { Text("8") } }) {          // 数字
    Icon(
        imageVector = MiuixIcons.Email,
        contentDescription = "Email",
        modifier = Modifier.size(28.dp),
    )
}
BadgedBox(badge = { Badge { Text("99+") } }) {        // 溢出文案
    Icon(
        imageVector = MiuixIcons.Settings,
        contentDescription = "Settings",
        modifier = Modifier.size(28.dp),
    )
}
```

**要点**：`Badge()` 空内容 = 小红点；`Badge { Text("99+") }` = 文字角标。
`AppContent.kt:743-748` 的 `navigationItemBadge()` 是「按索引决定要不要角标」的现成实现。

---

## 1.20 numberPickerSection — `NumberPicker`

`component/NumberPickerSection.kt:25`（`Card` 28-32 / 时:分 双滚轮 35-64）

```kotlin
// NumberPickerSection.kt:35-64
Row(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(vertical = 12.dp),
    horizontalArrangement = Arrangement.Center,
    verticalAlignment = Alignment.CenterVertically,
) {
    NumberPicker(
        value = hourValue,
        onValueChange = { hourValue = it },
        range = 0..23,
        label = { it.toString().padStart(2, '0') },     // ← 补零靠 label lambda
        wrapAround = true,                              // ← 循环滚动
        modifier = Modifier.weight(1f),
    )
    Text(
        text = ":",
        fontSize = 20.sp,
        fontWeight = FontWeight.Bold,
    )
    NumberPicker(
        value = minuteValue,
        onValueChange = { minuteValue = it },
        range = 0..59,
        label = { it.toString().padStart(2, '0') },
        wrapAround = true,
        modifier = Modifier.weight(1f),
    )
}
```

**要点**：`NumberPicker` 是 `Card` 内的**普通内容**（Card 默认 insideMargin 为 0，所以自己写
`padding(horizontal = 12.dp).padding(vertical = 12.dp)`）；`label` 是显示格式化，`wrapAround` 是循环。

---

## 1.21 colorPickerSection — `ColorPicker` / `ColorPalette`

`component/ColorPickerSection.kt:32`（四个色彩空间的 item 33-51 / `ColorPalette` 53-92 / `ColorPickerCard` 96-135 / HEX 输入 138-163）

```kotlin
// ColorPickerSection.kt:32-51 —— 四种色彩空间，各一个 item + SmallTitle
fun LazyListScope.colorPickerSection() {
    item(key = "colorPicker-HSV") {
        SmallTitle(text = "ColorPicker (HSV)")
        ColorPickerCard(colorSpace = ColorSpace.HSV)
    }

    item(key = "colorPicker-OKHSV") {
        SmallTitle(text = "ColorPicker (OKHSV)")
        ColorPickerCard(colorSpace = ColorSpace.OKHSV)
    }

    item(key = "colorPicker-OKLAB") {
        SmallTitle(text = "ColorPicker (OKLAB)")
        ColorPickerCard(colorSpace = ColorSpace.OKLAB)
    }

    item(key = "colorPicker-OKLCH") {
        SmallTitle(text = "ColorPicker (OKLCH)")
        ColorPickerCard(colorSpace = ColorSpace.OKLCH)
    }
    // 第 5 组 colorPalette 见 53-92
}
```

```kotlin
// ColorPickerSection.kt:105-134 —— Card + 16dp 内边距 + 取色器 + HEX 输入
Card(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    insideMargin = PaddingValues(16.dp),          // 内容是取色器，不是 Preference
) {
    Row(
        modifier = Modifier.padding(bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "RGBA: ${(selectedColor.red * 255).toInt()}, " +
                "${(selectedColor.green * 255).toInt()}, " +
                "${(selectedColor.blue * 255).toInt()}, " +
                "${(round(selectedColor.alpha * 100) / 100.0)}",
            modifier = Modifier.weight(1f),
        )
    }
    ColorPicker(
        color = selectedColor,
        onColorChanged = { selectedColor = it },
        colorSpace = colorSpace,
        showPreview = false,
    )
    ColorHexTextField(colorHex) { newHex, newColor ->
        colorHex = newHex
        if (newColor != null) selectedColor = newColor
    }
}
```

```kotlin
// ColorPickerSection.kt:82-90 —— 调色板形态
ColorPalette(
    color = selectedColor,
    onColorChanged = { selectedColor = it },
    showPreview = false,
)
```

```kotlin
// ColorPickerSection.kt:142-163 —— HEX 输入框（leadingIcon 放前缀）
TextField(
    value = colorHex,
    onValueChange = { newHex ->
        if (newHex.length <= 8 && newHex.all { it.isDigit() || it in 'a'..'f' || it in 'A'..'F' }) {
            val upperHex = newHex.uppercase()
            val newColor = if (newHex.length == 8) {
                Color(upperHex.toUInt(16).toInt())
            } else {
                null
            }
            onUpdate(upperHex, newColor)
        }
    },
    leadingIcon = {
        Text(
            "HEX: #",
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(start = 16.dp),
        )
    },
    modifier = Modifier.padding(top = 12.dp),
)
```

**要点**：`ColorSpace.HSV / OKHSV / OKLAB / OKLCH` 是同一组件的四种色彩空间；
`showPreview = false` 表示不显示内置预览块（自己在上方画 RGBA 文本）。

---

## 1.22 blurSection — `textureBlur` / `progressiveTextureBlur` / `layerBackdrop`

`component/BlurSection.kt:60`（守卫 61 / 三个子分组 62-73 / 渐进模糊 77-219 / 纹理模糊 222-382 / 前景模糊 385-547）

```kotlin
// BlurSection.kt:60-74 —— 三组：Texture Blur / Foreground Blur / Progressive Blur
fun LazyListScope.blurSection() {
    if (!isRuntimeShaderSupported()) return          // ← 官方先做能力守卫，不支持就整段不渲染
    item(key = "blur") {
        SmallTitle(text = "Texture Blur")
        BlurDemo()
    }
    item(key = "foreground_blur") {
        SmallTitle(text = "Foreground Blur")
        ForegroundBlurDemo()
    }
    item(key = "progressive_blur") {
        SmallTitle(text = "Progressive Blur")
        ProgressiveBlurDemo()
    }
}
```

```kotlin
// BlurSection.kt:269-305 —— 纹理模糊：底层打 layerBackdrop，上层打 textureBlur
Card(
    modifier = Modifier.padding(bottom = 12.dp),
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(280.dp),
    ) {
        // Background layer (captured by layerBackdrop)
        Box(
            modifier = Modifier
                .matchParentSize()
                .layerBackdrop(backdrop),
        ) {
            BlurBackground()
        }

        // Blur overlay
        Box(
            modifier = Modifier
                .fillMaxWidth(0.8f)
                .height(140.dp)
                .align(Alignment.Center)
                .textureBlur(
                    backdrop = backdrop,
                    shape = RoundedCornerShape(24.dp),
                    blurRadiusX = blurRadiusX,
                    blurRadiusY = blurRadiusY,
                    noiseCoefficient = noiseCoefficient,
                    colors = BlurDefaults.blurColors(
                        blendColors = currentBlend.second,
                        brightness = brightness,
                        contrast = contrast,
                        saturation = saturation,
                    ),
                    highlight = highlight,
                ),
        ) { /* ... */ }
    }
    // 下面接 OverlayDropdownPreference / HorizontalDivider / SliderPreference 调参
}
```

```kotlin
// BlurSection.kt:118-151 —— 渐进模糊：gradient 由方向 + start/end/curve 拼
val backdrop = rememberLayerBackdrop()
// ...
Box(
    modifier = Modifier
        .matchParentSize()
        .progressiveTextureBlur(
            backdrop = backdrop,
            shape = RectangleShape,
            blurRadius = blurRadius,
            gradient = gradient,                 // ProgressiveBlur.Top.copy(startFraction=..., endFraction=..., curve=...)
            noiseCoefficient = noiseCoefficient,
            colors = BlurDefaults.blurColors(blendColors = currentBlend.second),
        ),
    contentAlignment = Alignment.Center,
)
```

```kotlin
// BlurSection.kt:114-116 —— 方向/曲线是 copy 出来的，不是新对象
val gradient = remember(baseDirection, startFraction, endFraction, curve) {
    baseDirection.copy(startFraction = startFraction, endFraction = endFraction, curve = curve)
}
```

```kotlin
// BlurSection.kt:446-468 —— 前景模糊（把文字本身做成玻璃）靠 contentBlendMode = DstIn
Text(
    text = "Foreground Blur\nMiuix Demo",
    fontSize = 32.sp,
    fontWeight = FontWeight.Black,
    textAlign = TextAlign.Center,
    modifier = Modifier
        .fillMaxWidth()
        .align(Alignment.Center)
        .textureBlur(
            backdrop = backdrop,
            shape = RoundedCornerShape(0.dp),
            blurRadiusX = blurRadiusX,
            blurRadiusY = blurRadiusY,
            noiseCoefficient = noiseCoefficient,
            colors = BlurDefaults.blurColors(
                blendColors = currentBlend.second,
                brightness = brightness,
                contrast = contrast,
                saturation = saturation,
            ),
            contentBlendMode = ComposeBlendMode.DstIn,      // ← 关键：只保留被内容遮住的部分
        ),
)
```

```kotlin
// BlurSection.kt:177 / 337 / 492 —— Card 里把「预览区/下拉」和「滑杆组」隔开的分割线
HorizontalDivider(Modifier.fillMaxWidth().padding(horizontal = 16.dp))
```

**要点**：
1. 顶层页面用 `BlurredBar` + `layerBackdrop`（见 §3.3）；**组件级毛玻璃**才是这里的三件套：
   `rememberLayerBackdrop()` 拿 backdrop → 底层 `Modifier.layerBackdrop(backdrop)` 采集 →
   上层 `Modifier.textureBlur(backdrop = ..., shape = ..., blurRadiusX/Y, noiseCoefficient, colors, highlight)`。
2. 一律先 `if (!isRuntimeShaderSupported()) return`。
3. 前景（文字/图标）玻璃 = `textureBlur` + `contentBlendMode = ComposeBlendMode.DstIn`。
4. 调参面板就是普通 `OverlayDropdownPreference` + `SliderPreference`，滑杆用
   `insideMargin = PaddingValues(16.dp, 16.dp, 16.dp, 0.dp)`。
5. 更深的混合模式（`ColorBlendToken`）、玻璃描边高亮（`rememberContainerHighlight`）在
   `component/blend/`、`component/highlight/`，归 [CHEATSHEET-玻璃与手感.md](CHEATSHEET-玻璃与手感.md)。

---

## 1.23 otherPageSection — `ArrowPreference` 做页面跳转入口

`component/OtherPageSection.kt:17`（`Card` 21-52）

```kotlin
// OtherPageSection.kt:17-53
fun LazyListScope.otherPageSection() {
    item(key = "other") {
        val navigator = LocalNavigator.current
        SmallTitle(text = "Other")
        Card(
            modifier = Modifier
                .padding(horizontal = 12.dp),
        ) {
            ArrowPreference(
                title = "PullToRefresh Test",
                summary = "Navigate to a PullToRefresh Page",
                onClick = {
                    navigator.push(Route.PullToRefresh)
                },
            )
            ArrowPreference(
                title = "Navigation test",
                summary = "Navigate to a Navigation Page",
                onClick = { navigator.push(Route.Navigation(Random.nextLong().toString())) },
            )
            ArrowPreference(
                title = "MultiScaffold Test",
                summary = "Navigate to a MultiScaffold Page",
                onClick = { navigator.push(Route.MultiScaffold) },
            )
            ArrowPreference(
                title = "Nested Navigation Test",
                summary = "A NavDisplay nested inside an entry",
                onClick = { navigator.push(Route.NestedNav) },
            )
            ArrowPreference(
                title = "Overscroll + Load More Test",
                summary = "Fling to the bottom, then fling again",
                onClick = { navigator.push(Route.OverscrollLoadMore) },
            )
        }
    }
}
```

**要点**：这一组的 Card 只写了 `padding(horizontal = 12.dp)`（**没有** `bottom = 12.dp`），
因为它是页面最后一组，收尾由 `MainPage.kt:385` 的 `Spacer(modifier = Modifier.height(12.dp))` 负责。
**跳转入口用 `ArrowPreference`**（自带右箭头），不要自己 `Row { Text + Icon }`。

---

# 2. 非 Section 的组件范例

## 2.1 `component/SuperSearchBar.kt` — 搜索栏与搜索结果页

`SuperSearchBar.kt:75`（`SearchPager` 75-223 / `SearchBar` 226-298 / `SearchBarFake` 301-331 / `topInset` 334-340）

```kotlin
// SuperSearchBar.kt:240-291 —— 搜索输入框（InputField 形态）
InputField(
    query = searchStatus.searchText,
    onQueryChange = { onSearchStatusChange(searchStatus.copy(searchText = it)) },
    label = searchStatus.label,
    leadingIcon = {
        Icon(
            imageVector = MiuixIcons.Basic.Search,
            contentDescription = "back",
            modifier = Modifier
                .size(44.dp)
                .padding(start = 16.dp, end = 8.dp),
            tint = MiuixTheme.colorScheme.onSurfaceContainerHigh,
        )
    },
    trailingIcon = {
        AnimatedVisibility(
            searchStatus.searchText.isNotEmpty(),
            enter = fadeIn() + scaleIn(),
            exit = fadeOut() + scaleOut(),
        ) {
            Icon(
                imageVector = MiuixIcons.Basic.SearchCleanup,
                tint = MiuixTheme.colorScheme.onSurface,
                contentDescription = "Clean",
                modifier = Modifier
                    .size(44.dp)
                    .padding(start = 8.dp, end = 16.dp)
                    .clickable(
                        interactionSource = null,
                        indication = null,
                        onClick = onClearSearch,
                    ),
            )
        }
    },
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 6.dp)
        .topInset(searchBarTopPadding)
        .focusRequester(focusRequester),
    color = color,
    onSearch = {},
    expanded = searchStatus.shouldExpand(),
    onExpandedChange = {
        onSearchStatusChange(
            searchStatus.copy(
                current = if (it) SearchStatus.Status.EXPANDED else SearchStatus.Status.COLLAPSED,
            ),
        )
    },
)
```

```kotlin
// SuperSearchBar.kt:198-221 —— 展开时把结果盖上来（fadeIn/fadeOut + zIndex）
AnimatedVisibility(
    visible = searchStatus.isExpand(),
    modifier = Modifier
        .fillMaxSize()
        .zIndex(1f),
    enter = fadeIn(),
    exit = fadeOut(),
) {
    when (searchStatus.resultStatus) {
        SearchStatus.ResultStatus.DEFAULT -> defaultResult()

        SearchStatus.ResultStatus.EMPTY -> {}

        SearchStatus.ResultStatus.LOAD -> {}

        SearchStatus.ResultStatus.SHOW -> LazyColumn(
            Modifier
                .fillMaxSize()
                .overScrollVertical(),
        ) {
            result()
        }
    }
}
```

```kotlin
// SuperSearchBar.kt:333-340 —— 顶栏高度变化时「只重排版不重组」的官方小工具
/** Reserves [inset] above the content, read during layout so a changing value never recomposes the caller. */
private fun Modifier.topInset(inset: () -> Dp): Modifier = layout { measurable, constraints ->
    val insetPx = inset().roundToPx()
    val placeable = measurable.measure(constraints.offset(vertical = -insetPx))
    layout(placeable.width, placeable.height + insetPx) {
        placeable.placeRelative(0, insetPx)
    }
}
```

**要点**：`MainPage.kt:315-360` 用的是**简版**——`SearchBar(inputField = { InputField(...) }, outsideEndAction = { Text("Cancel") }, expanded, onExpandedChange) { 建议列表 }`。
`SuperSearchBar` 是「搜索态是一个独立页面」的完整版（含 `SearchStatus` 状态机、返回键处理
`NavigationBackHandler`、`focusRequester` 自动聚焦）。要抄哪个看需求：**列表页顶部搜索条抄 `MainPage`，独立搜索页抄 `SuperSearchBar`**。

## 2.2 `component/BackNavigationIcon.kt` — 返回键（含 RTL 镜像）

`BackNavigationIcon.kt:18-36`

```kotlin
// BackNavigationIcon.kt:17-36
@Composable
fun BackNavigationIcon(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val layoutDirection = LocalLayoutDirection.current
    IconButton(
        modifier = modifier,
        onClick = onClick,
    ) {
        Icon(
            modifier = Modifier.graphicsLayer {
                if (layoutDirection == LayoutDirection.Rtl) scaleX = -1f
            },
            imageVector = MiuixIcons.Back,
            contentDescription = null,
            tint = colorScheme.onBackground,
        )
    }
}
```

**要点**：RTL 下用 `graphicsLayer { scaleX = -1f }` 镜像箭头——官方没有单独的 RTL 图标。
`contentDescription = null`（装饰性图标，读屏不该念）。

---

# 3. 页面骨架配方（照抄就能搭出新页面）

> 这一节的目的：**另一个 agent 不用再读 demo，照抄 §3.6 的模板 + §3.4 的节奏表就能搭出一页。**
> 权威出处：`MainPage.kt`（列表页）、`SettingsPage.kt`（设置页）、`utils/PageUtils.kt`（工具）、`AppContent.kt`（外壳）。

## 3.0 五步骨架

| 步 | 做什么 | 官方出处 |
|---|---|---|
| ① | `Scaffold(topBar = { BlurredBar(backdrop, blurActive) { AdaptiveTopAppBar(...) } })` | `MainPage.kt:256-302`、`SettingsPage.kt:72-84` |
| ② | 内容外层 `Box(modifier = if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier)` | `MainPage.kt:305`、`SettingsPage.kt:110` |
| ③ | `LazyColumn(state = lazyListState, modifier = Modifier.pageScrollModifiers(haptic, showBar, scrollBehavior), contentPadding = pageContentPadding(innerPadding, padding, isWideScreen))` | `MainPage.kt:304-314`、`SettingsPage.kt:109-119` |
| ④ | 每组一个 `item(key = "...")`：`SmallTitle("组名")` + `Card(Modifier.padding(horizontal = 12.dp).padding(bottom = 12.dp)) { Preference 行... }` | `SettingsPage.kt:303-351` |
| ⑤ | 同级再挂 `VerticalScrollBar(adapter = rememberScrollBarAdapter(lazyListState), modifier = Modifier.align(Alignment.CenterEnd).fillMaxHeight(), trackPadding = contentPadding)` | `MainPage.kt:388-392`、`SettingsPage.kt:354-358` |

## 3.1 `contentPadding` 怎么算 —— `pageContentPadding`（逐字照抄）

`utils/PageUtils.kt:49-75`

```kotlin
@Composable
fun pageContentPadding(
    innerPadding: PaddingValues,
    outerPadding: PaddingValues,
    isWideScreen: Boolean,
    extraTop: Dp = 0.dp,
    extraStart: Dp = 0.dp,
    extraEnd: Dp = 0.dp,
    extraBottom: Dp = 0.dp,
): PaddingValues {
    val topPadding = innerPadding.calculateTopPadding() + extraTop
    val bottomPadding = outerPadding.calculateBottomPadding() + extraBottom + if (isWideScreen) {
        WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding() + WindowInsets.captionBar.asPaddingValues()
            .calculateBottomPadding()
    } else {
        0.dp
    }

    return remember(topPadding, bottomPadding, extraStart, extraEnd, extraBottom) {
        PaddingValues(
            top = topPadding,
            start = extraStart,
            end = extraEnd,
            bottom = bottomPadding,
        )
    }
}
```

**算法读法（这就是「怎么算」的答案）**：

| 边 | 取值 | 为什么 |
|---|---|---|
| `top` | `Scaffold` 给的 `innerPadding.top`（= 顶栏高度）`+ extraTop` | 列表第一项不能钻到顶栏底下；`extraTop` 给「顶栏下方还想留白」的场景 |
| `bottom` | **外层** `padding.calculateBottomPadding()`（= 底栏/导航条高度）`+ extraBottom`；**宽屏再叠加** `navigationBars + captionBar` | 窄屏底栏已由 Scaffold 的 `padding` 让位；宽屏走 NavigationRail，底部没有底栏，得自己补系统条 |
| `start` / `end` | 只取 `extraStart` / `extraEnd`（默认 0） | **左右不留 padding**——12dp 的横向留白由每个 `Card` / 组件自己带，这样滚动条能贴到屏幕右边缘 |
| `remember(...)` | 按算出来的值缓存 | 避免每帧新建 `PaddingValues` 触发重组 |

调用点只有一种写法（`MainPage.kt:304`、`SettingsPage.kt:109`、`TextStylePage.kt:101` 一致）：

```kotlin
val contentPadding = pageContentPadding(innerPadding, padding, isWideScreen)
```

> ⚠️ `SettingsPage` 的传参略有不同：它在 `Scaffold` 的 lambda 里先把内外两层合成一个
> （`SettingsPage.kt:86-93` 把 `innerPadding.top` 与 `padding.bottom` 拼成 `PaddingValues`），
> 再调 `pageContentPadding(padding, padding, isWideScreen)`（`:109`）。
> **新页面直接照 `MainPage` 的写法**（内外分开传）即可。

## 3.2 `pageScrollModifiers` 挂什么 —— `utils/PageUtils.kt:39-47`

```kotlin
fun Modifier.pageScrollModifiers(
    enableScrollEndHaptic: Boolean,
    showTopAppBar: Boolean,
    topAppBarScrollBehavior: ScrollBehavior,
): Modifier = this
    .then(if (enableScrollEndHaptic) Modifier.scrollEndHaptic() else Modifier)
    .overScrollVertical()
    .then(if (showTopAppBar) Modifier.nestedScroll(topAppBarScrollBehavior.nestedScrollConnection) else Modifier)
    .fillMaxHeight()
```

三件事，缺一不可：

| 修饰 | 作用 | 来源 |
|---|---|---|
| `scrollEndHaptic()` | 滚到顶/底时的轻震（可开关） | `top.yukonga.miuix.kmp.utils.scrollEndHaptic` |
| `overScrollVertical()` | 官方过度滚动（回弹）效果 | `top.yukonga.miuix.kmp.utils.overScrollVertical` |
| `nestedScroll(topAppBarScrollBehavior.nestedScrollConnection)` | 滚动时顶栏折叠/联动 | `MiuixScrollBehavior()` 的 `nestedScrollConnection` |

`MiuixScrollBehavior()` 在页面里 remember 一次（`MainPage.kt:103`、`SettingsPage.kt:70`）：

```kotlin
val topAppBarScrollBehavior = MiuixScrollBehavior()
```

> 抽屉里的滚动没有顶栏，官方只用两件（`BottomSheetSection.kt:209-213`）：
> `Modifier.fillMaxWidth().scrollEndHaptic().overScrollVertical()`。

## 3.3 顶栏三件套 —— `AdaptiveTopAppBar` / `BlurredBar` / `rememberBlurBackdrop`

`utils/PageUtils.kt:115-161`

```kotlin
@Composable
fun rememberBlurBackdrop(): LayerBackdrop? {
    val appState = LocalAppState.current
    if (!appState.enableBlur || !isRuntimeShaderSupported()) return null
    val surfaceColor = MiuixTheme.colorScheme.surface
    return rememberLayerBackdrop {
        drawRect(surfaceColor)
        drawContent()
    }
}

@Composable
fun BlurredBar(
    backdrop: LayerBackdrop?,
    blurEnabled: Boolean,
    content: @Composable () -> Unit,
) {
    val progressive = LocalAppState.current.blurStyle == 1
    val blurActive = blurEnabled && backdrop != null
    Box(
        modifier = if (blurActive && !progressive) {
            Modifier.textureBlur(
                backdrop = backdrop,
                shape = RectangleShape,
                blurRadius = 25f,
                colors = barBlurColors(),
            )
        } else {
            Modifier
        },
    ) {
        if (blurActive && progressive) {
            Box(
                modifier = Modifier
                    .matchParentSize()
                    .progressiveTextureBlur(
                        backdrop = backdrop,
                        shape = RectangleShape,
                        gradient = ProgressiveBlur.Top.copy(curve = 2.2f),
                        blurRadius = 10f,
                        colors = barBlurColors(progressive = true),
                    ),
            )
        }
        content()
    }
}

@Composable
private fun barBlurColors(progressive: Boolean = false): BlurColors = BlurDefaults.blurColors(
    blendColors = listOf(
        BlendColorEntry(color = MiuixTheme.colorScheme.surface.copy(if (progressive) 0.3f else 0.8f)),
    ),
)
```

页面侧的固定四行（`MainPage.kt:99-104`、`SettingsPage.kt:67-70`）：

```kotlin
val backdrop = rememberBlurBackdrop()
val blurActive = backdrop != null
val barColor = if (blurActive) Color.Transparent else MiuixTheme.colorScheme.surface
val topAppBarScrollBehavior = MiuixScrollBehavior()
```

**要点**：`barColor` 的这条三元表达式是关键——**毛玻璃生效时顶栏必须透明**（否则挡住玻璃），
不生效时退回 `surface` 实色。`BlurredBar` 里 `textureBlur(blurRadius = 25f)` 是官方顶栏参数。

`AdaptiveTopAppBar`（`PageUtils.kt:77-113`）是「宽屏用 `SmallTopAppBar`、窄屏用 `TopAppBar`」的
自适应包装，注意宽屏分支传了 `defaultWindowInsetsPadding = false`：

```kotlin
if (showTopAppBar) {
    if (isWideScreen) {
        SmallTopAppBar(
            title = title,
            subtitle = subtitle,
            color = color,
            scrollBehavior = scrollBehavior,
            defaultWindowInsetsPadding = false,
            navigationIcon = navigationIcon,
            actions = actions,
            bottomContent = bottomContent,
        )
    } else {
        TopAppBar(
            title = title,
            subtitle = subtitle,
            color = color,
            scrollBehavior = scrollBehavior,
            navigationIcon = navigationIcon,
            actions = actions,
            bottomContent = bottomContent,
        )
    }
}
```

## 3.4 分组节奏表（`SmallTitle` 怎么分组、`Card(insideMargin=...)` 怎么包一组设置行）

**这是整个骨架里最容易做错的一节。** 三档内边距必须配对使用：

| 层 | 内边距 | 出处 | 说明 |
|---|---|---|---|
| 页面横向 | **0**（`pageContentPadding` 的 start/end 默认 0） | `PageUtils.kt:70-71` | 留白交给每个块自己带 |
| 分组标题 `SmallTitle` | **28dp**（默认，不用传） | `SmallTitleDefaults.InsideMargin = PaddingValues(28.dp, 8.dp)` | 28 = **12 + 16**，与下面的设置行左对齐 |
| 一组设置行的 `Card` | `Modifier.padding(horizontal = 12.dp).padding(bottom = 12.dp)` | `SettingsPage.kt:305-307`、每个 Section | 左 12 让出屏幕边距，下 12 是组间距 |
| Card 内的 `*Preference` 行 | **16dp**（默认，不用传） | `BasicComponentDefaults.InsideMargin = PaddingValues(16.dp)` | 12 + 16 = 28 = `SmallTitle` 的 28 ✅ |
| Card 内的**非 Preference** 内容 | 显式 `insideMargin = PaddingValues(16.dp)` | `TabRowSection.kt:53`、`ColorPickerSection.kt:68`、`BreadcrumbBarSection.kt:57` | Card 默认 insideMargin 是 **0**，不给就是贴边 |
| 页面最后一项 | `Spacer(modifier = Modifier.height(12.dp))` | `MainPage.kt:385`、`SettingsPage.kt:352` | 补最后 12dp |

**两条硬规则**：

1. **Card 包 `*Preference` 时，绝不传 `insideMargin`**（Preference 自带 16dp；再传就变 32dp，
   左边缘会与 `SmallTitle` 错开 16dp）。
2. **Card 包普通内容（`Text`/`Row`/`Column`/`TextField`/`NumberPicker`/`ColorPicker`/`TabRow`）时，
   必须自己给 `insideMargin = PaddingValues(16.dp)` 或 `Modifier.padding(...)`**（Card 默认 0）。

`SmallTitle` 还可以在**抽屉里**改用 16dp（`BottomSheetSection.kt:215-218`），
因为抽屉里的 Card 没有外面那 12dp：

```kotlin
SmallTitle(
    text = "Behavior Settings",
    insideMargin = PaddingValues(16.dp, 8.dp),
)
```

**分组方式**：每个分组 = `LazyColumn` 里的**一个 `item(key = "...")`**，里面按
`SmallTitle → Card → (Card 内多行 Preference)` 排列。`SettingsPage.kt` 的三组就是三个 item
（`"settingsUi"` 120、`"settingsTransition"` 303、`"settingsAbout"` 340）。
**不要**把多个分组塞进同一个 item，也不要给 `SmallTitle` 加 `key`（key 给 item）。

## 3.5 `VerticalScrollBar` 怎么挂

`MainPage.kt:388-392`（与 `LazyColumn` 同级、同在 `Box` 里）：

```kotlin
VerticalScrollBar(
    adapter = rememberScrollBarAdapter(lazyListState),
    modifier = Modifier.align(Alignment.CenterEnd).fillMaxHeight(),
    trackPadding = contentPadding,
)
```

四件事：

1. **必须在 `Box` 里**（要 `Modifier.align(Alignment.CenterEnd)` 贴右边）；
2. `adapter = rememberScrollBarAdapter(lazyListState)` —— 传的是**同一个** `lazyListState`；
3. `trackPadding = contentPadding` —— 轨道上下留白与列表内容一致，滚动条不会顶到顶栏/底栏；
4. 文件顶要加 opt-in（`MainPage.kt:4`、`SettingsPage.kt:4`）：

```kotlin
@file:OptIn(ExperimentalScrollBarApi::class)
```

## 3.6 完整模板（照抄即用）

### 3.6.1 列表/设置页模板（最常用）

```kotlin
@file:OptIn(ExperimentalScrollBarApi::class)

@Composable
fun MyPage(
    padding: PaddingValues,          // 外壳传进来的底栏/导航条让位
) {
    val appState = LocalAppState.current                 // 本项目里换成你自己的状态源
    val isWideScreen = LocalIsWideScreen.current
    val backdrop = rememberBlurBackdrop()
    val blurActive = backdrop != null
    val barColor = if (blurActive) Color.Transparent else MiuixTheme.colorScheme.surface
    val topAppBarScrollBehavior = MiuixScrollBehavior()
    val lazyListState = rememberLazyListState()

    Scaffold(
        topBar = {
            BlurredBar(backdrop, blurActive) {
                AdaptiveTopAppBar(
                    title = "页面标题",
                    showTopAppBar = appState.showTopAppBar,
                    isWideScreen = isWideScreen,
                    scrollBehavior = topAppBarScrollBehavior,
                    color = barColor,
                    // navigationIcon = { BackNavigationIcon(onClick = { navigator.pop() }) },
                    // actions = { ... },
                    // subtitle = "v1.0.0",
                )
            }
        },
    ) { innerPadding ->
        val contentPadding = pageContentPadding(innerPadding, padding, isWideScreen)
        Box(modifier = if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier) {
            LazyColumn(
                state = lazyListState,
                modifier = Modifier.pageScrollModifiers(
                    appState.enableScrollEndHaptic,
                    appState.showTopAppBar,
                    topAppBarScrollBehavior,
                ),
                contentPadding = contentPadding,
            ) {
                // —— 分组 1：开关类 ——
                item(key = "group1") {
                    SmallTitle(text = "分组一")                      // 自带 28dp 左对齐
                    Card(
                        modifier = Modifier
                            .padding(horizontal = 12.dp)
                            .padding(bottom = 12.dp),
                        // 不要传 insideMargin：里面是 Preference，自带 16dp
                    ) {
                        SwitchPreference(
                            title = "开关项",
                            summary = "打开后会怎样",
                            checked = xxx,
                            onCheckedChange = { xxx = it },
                        )
                        AnimatedVisibility(
                            visible = xxx,
                            enter = fadeIn() + expandVertically(),
                            exit = fadeOut() + shrinkVertically(),
                        ) {
                            OverlayDropdownPreference(
                                title = "跟随项",
                                items = listOf("A", "B"),
                                selectedIndex = idx,
                                onSelectedIndexChange = { idx = it },
                            )
                        }
                    }
                }

                // —— 分组 2：跳转/弹窗类（记住 holdDownState 三件套）——
                item(key = "group2") {
                    SmallTitle(text = "分组二")
                    Card(
                        modifier = Modifier
                            .padding(horizontal = 12.dp)
                            .padding(bottom = 12.dp),
                    ) {
                        var showDialog by rememberSaveable { mutableStateOf(false) }
                        var holdDown by rememberSaveable { mutableStateOf(false) }
                        ArrowPreference(
                            title = "打开弹窗",
                            summary = "点了之后行保持按下态直到弹窗关闭",
                            onClick = {
                                showDialog = true
                                holdDown = true
                            },
                            holdDownState = holdDown,
                        )
                        OverlayDialog(
                            show = showDialog,
                            title = "标题",
                            summary = "说明",
                            onDismissRequest = { showDialog = false },
                            onDismissFinished = { holdDown = false },
                            content = { /* 按钮行 */ },
                        )
                    }
                }

                // —— 分组 3：普通内容（要自己给 16dp）——
                item(key = "group3") {
                    SmallTitle(text = "分组三")
                    Card(
                        modifier = Modifier
                            .padding(horizontal = 12.dp)
                            .padding(bottom = 12.dp),
                        insideMargin = PaddingValues(16.dp),      // ← 内容不是 Preference，必须给
                    ) {
                        Text(text = "任意内容")
                    }
                }

                item { Spacer(modifier = Modifier.height(12.dp)) }     // 收尾 12dp
            }
            VerticalScrollBar(
                adapter = rememberScrollBarAdapter(lazyListState),
                modifier = Modifier.align(Alignment.CenterEnd).fillMaxHeight(),
                trackPadding = contentPadding,
            )
        }
    }
}
```

### 3.6.2 带搜索栏的列表页（`MainPage` 的做法）

搜索条是 `LazyColumn` 的**第一个 item**，其余分组用 `if (notExpanded) { ... }` 包住
（搜索展开时整页分组不渲染，`MainPage.kt:361-386`）：

```kotlin
// MainPage.kt:88-97
var searchValue by remember { mutableStateOf("") }
var expanded by remember { mutableStateOf(false) }
val notExpanded by remember { derivedStateOf { !expanded } }
val onCancelSearch = remember {
    {
        expanded = false
        searchValue = ""
    }
}
```

```kotlin
// MainPage.kt:315-360
item(key = "searchbar") {
    SmallTitle(text = "SearchBar")
    SearchBar(
        modifier = Modifier.padding(bottom = 12.dp),
        inputField = {
            InputField(
                query = searchValue,
                onQueryChange = { searchValue = it },
                onSearch = { expanded = false },
                expanded = expanded,
                onExpandedChange = { expanded = it },
                label = "Search",
            )
        },
        outsideEndAction = {
            Text(
                modifier = Modifier
                    .padding(end = 12.dp)
                    .clickable(
                        interactionSource = null,
                        indication = null,
                        onClick = onCancelSearch,
                    ),
                text = "Cancel",
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = MiuixTheme.colorScheme.primary,
            )
        },
        expanded = expanded,
        onExpandedChange = { expanded = it },
    ) {
        Column {
            repeat(4) { idx ->
                val resultText = "Suggestion $idx"
                BasicComponent(
                    title = resultText,
                    onClick = {
                        searchValue = resultText
                        expanded = false
                    },
                )
            }
        }
    }
}
if (notExpanded) {
    // 各分组 Section...
    item { Spacer(modifier = Modifier.height(12.dp)) }
}
```

### 3.6.3 外壳怎么把 `padding` 传进来（`AppContent.kt`）

新页面如果要接进 demo 那套外壳，照 `AppPager` 的分发方式（`AppContent.kt:782-790`）：

```kotlin
pageContent = { page ->
    when (page) {
        UIConstants.MAIN_PAGE_INDEX -> MainPage(snackbarHostState = snackbarHostState, padding = padding)
        UIConstants.ICON_PAGE_INDEX -> IconsPage(padding = padding)
        UIConstants.COLOR_PAGE_INDEX -> ColorPage(padding = padding)
        UIConstants.TEXT_STYLE_PAGE_INDEX -> TextStylePage(padding = padding)
        else -> SettingsPage(padding = padding)
    }
}
```

外壳侧另外几件值得抄的：

| 件 | 出处 | 写法 |
|---|---|---|
| 底栏（含毛玻璃） | `AppContent.kt:541-582` | `Box(Modifier.textureBlur(backdrop, RectangleShape, blurRadius = 25f, colors = BlurDefaults.blurColors(blendColors = listOf(BlendColorEntry(MiuixTheme.colorScheme.surface.copy(0.8f))))).background(barColor)) { NavigationBar(color = barColor, mode = ...) { NavigationBarItem(...) } }` |
| 悬浮导航栏 | `AppContent.kt:584-634` | `FloatingNavigationBar(color = ..., horizontalAlignment = ...) { FloatingNavigationBarItem(...) }`，圆角用 `RoundedCornerShape(FloatingToolbarDefaults.CornerRadius)`，可叠 `textureBlur(..., highlight = floatingHighlight)` |
| 悬浮工具条 | `AppContent.kt:668-671` | `FloatingToolbar(color = MiuixTheme.colorScheme.primary, cornerRadius = 20.dp) { ... }` |
| 整页 Pager | `AppContent.kt:757-791` | `PagerDefaults.flingBehavior(state, snapAnimationSpec = PagerNavigationSpringSpec)` + `HorizontalPager(flingBehavior = ...)` |
| 页码动画（防连点） | `AppContent.kt:816-865` | `MainPagerState.animateToPage` 用 `navJob?.cancel()` + `springAnimateToPage`，`isNavigating` 期间忽略 `syncPage()` |
| Snackbar | `AppContent.kt:390`、`402`、`500-502` | `val snackbarHostState = remember { SnackbarHostState() }` → `Scaffold(snackbarHost = { SnackbarHost(state = snackbarHostState) })` |
| 返回键拦截 | `AppContent.kt:794-814` | `NavigationBackHandler(state = navEventState, isBackEnabled = ..., onBackCompleted = ...)` |

## 3.7 骨架的六个坑（都是官方 demo 里明确避开的）

| # | 坑 | 官方怎么做 | 出处 |
|---|---|---|---|
| 1 | Card 包 Preference 还传 `insideMargin` | 不传（Preference 自带 16dp） | `SettingsPage.kt:121-123`、`305-307` |
| 2 | Card 包普通内容不传 `insideMargin` | 显式 `PaddingValues(16.dp)` | `TabRowSection.kt:53`、`ColorPickerSection.kt:68` |
| 3 | 用 `Column` + `verticalScroll` 代替 `LazyColumn` | 一律 `LazyColumn` + `item(key=)` + `VerticalScrollBar` | `MainPage.kt:306-387` |
| 4 | 手写 `padding(horizontal = 16.dp)` 当屏幕边距 | 页面横向 0，块自己带 12dp | `PageUtils.kt:70-71` |
| 5 | 忘了 `trackPadding = contentPadding` | 传，滚动条与内容同高 | `MainPage.kt:391` |
| 6 | 顶部搜索条没把内容 `if (notExpanded)` 包住 | 包住，展开时不分页渲染 | `MainPage.kt:361-386` |

---

# 4. Card 的三种按压形态（+ `holdDownState`）

> 权威出处：`component/CardSection.kt:33-169`。库侧默认值出处：本地依赖
> `miuix-ui-android-0.9.4-sources.jar` 的 `utils/PressFeedback.kt:176-184`、`:30`、`:84`。
> 三档枚举：`None` / `Sink`（下沉缩放）/ `Tilt`（跟手倾斜）。

## 4.1 形态一：静态 + `showIndication`（`None`）

`CardSection.kt:36-60` —— 没有 `onClick` 的展示卡，但**开了指示**：

```kotlin
Card(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 12.dp)
        .padding(bottom = 12.dp),
    colors = CardDefaults.defaultColors(
        color = MiuixTheme.colorScheme.primaryVariant,
    ),
    insideMargin = PaddingValues(16.dp),
    pressFeedbackType = PressFeedbackType.None,
    showIndication = true,
) {
    Text(
        color = MiuixTheme.colorScheme.onPrimaryVariant,
        text = "Card",
        fontSize = 19.sp,
        fontWeight = FontWeight.SemiBold,
    )
    Text(
        color = MiuixTheme.colorScheme.onPrimaryVariant,
        text = "ShowIndication: true",
        fontSize = 17.sp,
        fontWeight = FontWeight.Normal,
    )
}
```

**行号**：`pressFeedbackType` 45、`showIndication` 46、`colors` 41-43、`insideMargin` 44。

## 4.2 形态二：`Sink` + `onClick`（**最该抄的一种**）

`CardSection.kt:68-86`：

```kotlin
Card(
    modifier = Modifier.weight(1f),
    insideMargin = PaddingValues(16.dp),
    pressFeedbackType = PressFeedbackType.Sink,
    onClick = { println("Card click") },
    content = {
        Text(
            color = MiuixTheme.colorScheme.onSurface,
            text = "Card",
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            text = "PressFeedback\nType: Sink",
            style = MiuixTheme.textStyles.paragraph,
        )
    },
)
```

**行号**：`pressFeedbackType = PressFeedbackType.Sink` 71、`onClick` 72。
**注意**：这里**没有**传 `showIndication`——官方对 Sink 的示例只开 `pressFeedbackType`
（`showIndication` 是 Material 风格的涟漪指示，与 Sink 缩放是两个东西；要一起开也可以，见 4.4）。

## 4.3 形态三：`Tilt` + `onLongPress`

`CardSection.kt:87-105`：

```kotlin
Card(
    modifier = Modifier.weight(1f),
    insideMargin = PaddingValues(16.dp),
    pressFeedbackType = PressFeedbackType.Tilt,
    onLongPress = { println("Card long press") },
    content = {
        Text(
            color = MiuixTheme.colorScheme.onSurface,
            text = "Card",
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium,
        )
        Text(
            color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
            text = "PressFeedback\nType: Tilt",
            style = MiuixTheme.textStyles.paragraph,
        )
    },
)
```

**行号**：`pressFeedbackType = PressFeedbackType.Tilt` 90、`onLongPress` 91。
`Tilt` 是**跟手倾斜**（按在哪里往哪边倒），适合大卡片；`onClick` 与 `onLongPress` 可以只给一个。

## 4.4 形态四：`holdDownState`（长按/弹窗期间保持按下态）

`CardSection.kt:111-169`（`LongPressHoldDownCardDemo`）：

```kotlin
@Composable
private fun LongPressHoldDownCardDemo() {
    var showDialog by rememberSaveable { mutableStateOf(false) }
    var holdDown by rememberSaveable { mutableStateOf(false) }

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp)
            .padding(bottom = 12.dp),
        insideMargin = PaddingValues(16.dp),
        pressFeedbackType = PressFeedbackType.Sink,
        showIndication = true,
        holdDownState = holdDown,                 // ← 由外部状态决定「是否维持按下态」
        onLongPress = {
            showDialog = true
            holdDown = true                       // ← 弹窗前把状态顶起来
        },
        content = {
            Text(
                color = MiuixTheme.colorScheme.onSurface,
                text = "Card",
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
            )
            Text(
                color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                text = "Long press to show dialog",
                style = MiuixTheme.textStyles.paragraph,
            )
        },
    )

    OverlayDialog(
        show = showDialog,
        title = "Long Press Action",
        summary = "Triggered by long pressing the card.",
        onDismissRequest = { showDialog = false },
        onDismissFinished = { holdDown = false },  // ← 弹窗动画结束后才松开
        content = {
            Row(
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                TextButton(
                    text = "Cancel",
                    onClick = { showDialog = false },
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(20.dp))
                TextButton(
                    text = "Confirm",
                    onClick = { showDialog = false },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.textButtonColorsPrimary(),
                )
            }
        },
    )
}
```

**行号**：`holdDownState` 124、`onLongPress` 125-128、`onDismissFinished = { holdDown = false }` 149。

**这条配方在 demo 里被反复使用**（凡「点了开弹窗/抽屉」的行都这么写）：

| 用在哪 | 文件:行号 |
|---|---|
| `SliderPreference` 点开输入弹窗 | `component/ArrowSection.kt:71-81`（`holdDownState` 80，松开在 99） |
| `ArrowPreference` 点开 Dialog | `component/DialogSection.kt:60-104`（5 条，`holdDownState` 67/76/85/94/103，松开 110/115/120/125/130） |
| `ArrowPreference` 点开 BottomSheet | `component/BottomSheetSection.kt:62-79`（`holdDownState` 69/78，松开 89/98） |

**`PressFeedbackType` 库侧默认值（写自定义卡片时用得上）**：

```kotlin
// utils/PressFeedback.kt:30-32
data class SinkFeedback(
    val sinkAmount: Float = 0.94f,
    val animationSpec: AnimationSpec<Float> = spring(0.8f, 600f),
)

// utils/PressFeedback.kt:84-86
data class TiltFeedback(
    val tiltAmount: Float = 8f,
    val animationSpec: AnimationSpec<Float> = spring(0.6f, 400f),
)
```

即：`Sink` 默认缩到 **0.94 倍**、`spring(0.8f, 600f)`；`Tilt` 默认倾 **8°**、`spring(0.6f, 400f)`。
要「更沉」就把 `sinkAmount` 调小、`dampingRatio` 调大——但**官方 demo 一处都没自定义**，
默认值就是 MIUI 的手感基准，别乱调。

## 4.5 选哪个：决策表

| 场景 | `pressFeedbackType` | `showIndication` | `holdDownState` |
|---|---|---|---|
| 纯展示卡（不可点） | `None`（默认） | 不需要 | 不需要 |
| 可点卡片 / 可点设置组 | **`Sink`** | 可选（官方 `Card` 示例不加） | 不需要 |
| 大块内容卡、想跟手 | `Tilt` | 可选 | 不需要 |
| 点了要开弹窗/抽屉的行 | `Sink` | `true`（官方在 `Card`/`ArrowPreference` 场景常开） | **要**（`onClick` 置 true → `onDismissFinished` 置 false） |

> ⚠️ `Card` 的 `pressFeedbackType` / `showIndication` / `holdDownState` / `onClick` / `onLongPress`
> **只在「可交互重载」上存在**（`docs/components/card.md:36-40` 标注 `Applies To: Interactive`）。
> 静态那个重载传这些参数**编译不过**——必须先给 `onClick` 或 `onLongPress`。
> 另外：`Card` 的 `showIndication` 默认 `false`、`pressFeedbackType` 默认 `None`
> （`basic/Card.kt`），**什么都不传就是「按下去零反应」**——这正是我们 213 处 `Card` 的现状。

---

# 5. Preference 族的正确嵌套

## 5.1 三类容器的关系（先记住这张表）

| 容器 | 默认内边距 | 里面能放什么 |
|---|---|---|
| `Card` | **`PaddingValues(0.dp)`**（`CardDefaults.InsideMargin`） | 什么都能放；**放 Preference 时不要再给 insideMargin** |
| `*Preference`（`Switch/Arrow/Checkbox/RadioButton/OverlayDropdown/WindowDropdown/OverlaySpinner/WindowSpinner/Slider/RangeSlider`） | **`PaddingValues(16.dp)`**（`BasicComponentDefaults.InsideMargin`） | 只能作为 `Card`（或 `Column`）的直接子项；`endActions`/`startAction`/`bottomAction` 是它的插槽 |
| `BasicComponent` | 同上 16dp | 所有 Preference 的底座；想自造「一行设置」就调它 |

**结论**：官方 demo 里 **Preference 行一律包在 `Card` 里**，而那个 `Card` **不传 `insideMargin`**。
`Card` 提供圆角/底色/按压语义，Preference 提供行内 16dp 与内容布局——**两者各管一半，不要重复**。

## 5.2 哪些必须放 Card 里

| 组件 | 是否必须包 Card | 依据 |
|---|---|---|
| `SwitchPreference` / `ArrowPreference` / `CheckboxPreference` / `RadioButtonPreference` | **是**（官方 100% 包） | `SettingsPage.kt:121-301`、`ArrowSection.kt:44-93`、`CheckboxSection.kt:30-44`、`RadioButtonSection.kt:23-35` |
| `OverlayDropdownPreference` / `WindowDropdownPreference` | **是** | `SettingsPage.kt:129-142`、`DropdownSection.kt:135-188` |
| `OverlaySpinnerPreference` / `WindowSpinnerPreference` | **是** | `SpinnerSection.kt:173-256` |
| `SliderPreference` / `RangeSliderPreference` | **是** | `SliderSection.kt:35-91`、`95-140` |
| `BasicComponent` | 是（它是一行） | `BasicComponentSection.kt:21-73`、`MainPage.kt:350-356`（搜索结果也放在 `Column` 里） |
| `RadioButtonPreference` 每个选项 | 官方**每项一张 Card**（也可合并，见 1.4） | `RadioButtonSection.kt:43-56` |
| `TextField` | **不包**，直接放 `LazyColumn` item | `TextFieldSection.kt:33-72`、`BottomSheetSection.kt:241-246` |
| `BreadcrumbBar` / `ColorPicker` / `NumberPicker` / `TabRow` / `ProgressIndicator` | 包，但**要自己给 `insideMargin = PaddingValues(16.dp)`** | `BreadcrumbBarSection.kt:52-58`、`ColorPickerSection.kt:105-111`、`NumberPickerSection.kt:35-39`、`TabRowSection.kt:48-54`、`ProgressIndicatorSection.kt:38-43` |

**「必须放 Card 里」的三条实质理由**（不是审美）：

1. **按压/指示语义**：`Card` 才有 `pressFeedbackType`/`showIndication`/`holdDownState`；裸放 Preference
   没有卡片级的按压反馈；
2. **底色与圆角**：设置组需要 `surfaceContainer` 之类的分组底色与 16dp 圆角（`CardDefaults.CornerRadius`）；
3. **内边距配对**：`12 + 16 = 28` 才和 `SmallTitle` 对齐（§3.4）。

## 5.3 `HorizontalDivider` 怎么分隔

**先纠正一个常见误解**：`*Preference` **不会**自动画行间分割线（`basic/Component.kt` 里没有
任何 Divider），官方 demo 也**从不**在 Preference 行之间插 `HorizontalDivider`。
实测全 demo 只有两处文件用了它：

```
docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/
  component/BlurSection.kt:177, 337, 492
  TextStylePage.kt:124, 142, 160, 178, 196
```

于是官方一共只有三种合法用法：

### 用法 A：Card 内，「非 Preference 内容块」与「Preference 行组」之间

`component/BlurSection.kt:177`（`337`、`492` 同）：

```kotlin
HorizontalDivider(Modifier.fillMaxWidth().padding(horizontal = 16.dp))
```

**`padding(horizontal = 16.dp)` 是关键**：与 `BasicComponentDefaults.InsideMargin`（16dp）对齐，
分割线两端才和上面的下拉/下面的滑杆左右对齐。

### 用法 B：Card 内，任意内容行之间（非 Preference）

`TextStylePage.kt:122-127`（`142`、`160`、`178`、`196` 同）：

```kotlin
styleEntries.subList(0, 4).forEachIndexed { index, entry ->
    if (index > 0) {
        HorizontalDivider(modifier = Modifier.padding(vertical = 2.dp))
    }
    TextStyleItem(entry)
}
```

**`padding(vertical = 2.dp)`** 是官方给「内容行」用的行距；注意这种 Card 本身是
`insideMargin = PaddingValues(horizontal = 16.dp)`（`TextStylePage.kt:120`），所以分割线不用再给横向。

### 用法 C：两个**分组之间**（官方文档示例，不是 demo 代码）

`docs/components/smalltitle.md:70-89`：

```kotlin
Column {
    SmallTitle(text = "Settings")
    Card(
        modifier = Modifier.padding(horizontal = 12.dp).padding(bottom = 12.dp)
    ) {
        SwitchPreference(
            title = "Bluetooth",
            checked = checked,
            onCheckedChange = { checked = it }
        )
    }
    HorizontalDivider(
        modifier = Modifier.padding(horizontal = 12.dp)
    )
    SmallTitle(text = "Advanced Settings")
    // Other settings items
}
```

注意这里 `padding(horizontal = 12.dp)`（与 Card 同宽），而且是**在两张 Card 之间**，
不是行与行之间。

### 用法速查

| 想分隔什么 | 怎么写 | 官方出处 |
|---|---|---|
| Card 内：预览/下拉 与 滑杆组 | `HorizontalDivider(Modifier.fillMaxWidth().padding(horizontal = 16.dp))` | `BlurSection.kt:177` |
| Card 内：普通内容行之间 | `HorizontalDivider(modifier = Modifier.padding(vertical = 2.dp))` | `TextStylePage.kt:124` |
| 两张 Card / 两个分组之间 | `HorizontalDivider(modifier = Modifier.padding(horizontal = 12.dp))` | `docs/components/smalltitle.md:84-86` |
| **Preference 行之间** | **不加**（官方从不加；要加就用「用法 A/B」的横向 16dp 版本） | 全 demo 无此写法 |
| 两栏之间（竖） | `VerticalDivider(modifier = Modifier.fillMaxHeight().padding(horizontal = 20.dp))` | `DialogSection.kt:317-321` |

> 📌 **与 Lead 文档的一处口径差异（待确认）**：`我们的差距与修法.md:217` 的骨架示例里，
> 在 `Card { ArrowPreference(...); HorizontalDivider(); SwitchPreference(...) }` 之间插了
> `HorizontalDivider()`（无 padding）。**官方 demo 里没有这种写法**：
> 它要么不给 Preference 行加分割线，要么用 `padding(horizontal = 16.dp)` 的版本。
> 若确定要在行间加，建议照 `BlurSection.kt:177` 的横向 16dp 写法，否则分割线会顶到卡片圆角边。
> 本文只记录证据，是否改 Lead 那份由 Lead 定。

## 5.4 嵌套折叠（父子项）的正确写法

官方用 `AnimatedVisibility` + `Column` 包裹，**子项不另开 Card**（仍在外层 Card 内）：

```kotlin
// SettingsPage.kt:238-266 —— 三层嵌套（开关 → 子开关 → 子下拉），每层一个 Column
AnimatedVisibility(visible = appState.showNavigationBar && !isWideScreen) {
    Column {
        SwitchPreference(
            title = "Use FloatingNavigationBar",
            checked = appState.useFloatingNavigationBar,
            onCheckedChange = { updateAppState { state -> state.copy(useFloatingNavigationBar = it) } },
        )
        AnimatedVisibility(visible = appState.useFloatingNavigationBar) {
            Column {
                OverlayDropdownPreference(
                    title = "FloatingNavigationBar Style",
                    items = FloatingNavigationBarStyleOptions,
                    selectedIndex = appState.floatingNavigationBarStyle,
                    onSelectedIndexChange = { updateAppState { state -> state.copy(floatingNavigationBarStyle = it) } },
                )
                AnimatedVisibility(visible = appState.floatingNavigationBarStyle == 0) {
                    Column {
                        OverlayDropdownPreference(
                            title = "FloatingNavigationBar Position",
                            items = FloatingNavigationBarPositionOptions,
                            selectedIndex = appState.floatingNavigationBarPosition,
                            onSelectedIndexChange = { updateAppState { state -> state.copy(floatingNavigationBarPosition = it) } },
                        )
                    }
                }
            }
        }
    }
}
```

**要点**：**每多一层 `AnimatedVisibility`，就多套一个 `Column`**（因为 `AnimatedVisibility` 的
内容作用域不是 `ColumnScope`，直接塞两个 Preference 会横着排）。

## 5.5 Overlay 系 vs Window 系（选型表）

| | `Overlay*`（Dialog / BottomSheet / Dropdown / Spinner） | `Window*`（同上） |
|---|---|---|
| 依赖 | **必须在 `Scaffold` 子树里**（`Scaffold` 默认注入 `MiuixPopupHost`；`docs/components/overlaydialog.md:1-9`） | 不依赖，窗口级 |
| 关闭方式 | 自己的 `onDismissRequest` / `onClick` 回调 | 内容里取 `LocalDismissState.current?.invoke()`（`DialogSection.kt:181`、`BottomSheetSection.kt:169`） |
| 官方 demo 用途 | 主推（每个组件都给 O/W 两版对照） | 对照展示 |

**选型**：应用内弹层用 `Overlay*`；需要脱离当前 `Scaffold`（多 Scaffold、跨窗口）时用 `Window*`。

---

# 6. 速查表：组件 → 文件:行号

路径基目录 `SRC = docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/`

| 组件 | 文件:行号 | 备注 |
|---|---|---|
| `BasicComponent` | `component/BasicComponentSection.kt:26` | enabled/disabled 两版 |
| `Switch` | `component/SwitchSection.kt:47` | 裸控件，5 态 |
| `SwitchPreference` | `component/SwitchSection.kt:69` | + 折叠嵌套 78 |
| `Checkbox` | `component/CheckboxSection.kt:60` | `ToggleableState` 三态 |
| `CheckboxPreference` | `component/CheckboxSection.kt:105` | `CheckboxLocation.End` |
| `RadioButtonPreference` | `component/RadioButtonSection.kt:28` | 每项一卡 49 |
| `TextButton` | `component/ButtonSection.kt:37` | 主按钮 53 |
| `TabRow` | `component/TabRowSection.kt:37` | |
| `TabRowWithContour` + `HorizontalPager` | `component/TabRowSection.kt:58` | `springAnimateToPage` |
| `BreadcrumbBar` | `component/BreadcrumbBarSection.kt:43` | `joinToPath()` 67 |
| `ArrowPreference` | `component/ArrowSection.kt:49` | 图标槽 51 |
| `SliderPreference` | `component/SliderSection.kt:41` | keyPoints 72 / 弹窗 71 |
| `RangeSliderPreference` | `component/SliderSection.kt:101` | |
| `VerticalSlider` | `component/SliderSection.kt:162` | |
| `OverlayDialog` | `component/DialogSection.kt:141` | 居中 208 / 宽屏 245 |
| `WindowDialog` | `component/DialogSection.kt:174` | `LocalDismissState` 181 |
| `VerticalDivider` | `component/DialogSection.kt:317` | 两栏之间 |
| `OverlayBottomSheet` | `component/BottomSheetSection.kt:116` | |
| `WindowBottomSheet` | `component/BottomSheetSection.kt:161` | |
| `OverlayDropdownPreference` | `component/DropdownSection.kt:140` | 分组 160 |
| `WindowDropdownPreference` | `component/DropdownSection.kt:150` | |
| `OverlaySpinnerPreference` | `component/SpinnerSection.kt:178` | 对话框态 194（`dialogButtonString`） |
| `WindowSpinnerPreference` | `component/SpinnerSection.kt:186` | |
| `SnackbarHostState.showSnackbar` | `component/SnackbarSection.kt:74` | 各形态 70-178 |
| `TextField` | `component/TextFieldSection.kt:33` | 四种入参 |
| `LinearProgressIndicator` | `component/ProgressIndicatorSection.kt:38` | |
| `CircularProgressIndicator` | `component/ProgressIndicatorSection.kt:59` | `progress = null` 不定 |
| `InfiniteProgressIndicator` | `component/ProgressIndicatorSection.kt:67` | |
| `Card`（静态 + indication） | `component/CardSection.kt:36` | |
| `Card`（`Sink`） | `component/CardSection.kt:68` | |
| `Card`（`Tilt`） | `component/CardSection.kt:87` | |
| `Card`（`holdDownState`） | `component/CardSection.kt:116` | 弹窗 144 |
| `TooltipBox` | `component/TooltipSection.kt:42` | |
| `RichTooltipBox` | `component/TooltipSection.kt:47` | `rememberTooltipState(isPersistent = true)` 28 |
| `BadgedBox` / `Badge` | `component/BadgeSection.kt:44` | 四种角标 |
| `NumberPicker` | `component/NumberPickerSection.kt:43` | 时:分 双滚轮 |
| `ColorPicker` | `component/ColorPickerSection.kt:124` | 4 种 `ColorSpace` 33-51 |
| `ColorPalette` | `component/ColorPickerSection.kt:82` | |
| `textureBlur` | `component/BlurSection.kt:292` | 前景版 454（`contentBlendMode = DstIn`） |
| `progressiveTextureBlur` | `component/BlurSection.kt:144` | gradient 114 |
| `layerBackdrop` | `component/BlurSection.kt:281` | `rememberLayerBackdrop()` 232 |
| `HorizontalDivider`（16dp 横向） | `component/BlurSection.kt:177` | 337 / 492 同 |
| `HorizontalDivider`（2dp 纵向） | `TextStylePage.kt:124` | 142/160/178/196 同 |
| `ArrowPreference`（跳转入口） | `component/OtherPageSection.kt:25` | |
| `SearchBar` + `InputField`（简版） | `MainPage.kt:317` | |
| `SearchPager` / `SearchBar`（完整版） | `component/SuperSearchBar.kt:75` / `:226` | `topInset` 334 |
| `BackNavigationIcon` | `component/BackNavigationIcon.kt:18` | RTL 镜像 28-30 |
| 页面骨架工具 | `utils/PageUtils.kt:39` / `:50` / `:78` / `:116` / `:127` | 滚动 / 内边距 / 顶栏 / backdrop / 模糊栏 |
| 列表页骨架 | `MainPage.kt:256-395` | |
| 设置页骨架 | `SettingsPage.kt:72-360` | |
| 外壳（底栏/悬浮栏/Pager） | `AppContent.kt:157-865` | 底栏 520 / 悬浮栏 584 / 工具条 659 / Pager 751 / 返回键 795 |
