# CHEATSHEET：玻璃与手感（毛玻璃 / 按压反馈 / 液态玻璃与倾灯）

> 本文件是**上游 miuix 官方 demo 的精读笔记**，只读来源、不改上游。
> 目的：回答「我们迁到 Compose 后为什么用了正主反而更丑、点了没手感」，并给出**可直接照抄的最小接线**。
>
> **路径约定**（正文为省宽度用简写，含义固定）：
> - `PageUtils.kt` = `docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/utils/PageUtils.kt`
> - `BlurSection.kt` = `.../kotlin/component/BlurSection.kt`（其余 `component/*.kt`、`navigation/*.kt` 同理）
> - `docs/guide/blur.md` = `docs/reference/miuix-demo/docs/guide/blur.md`（`docs/components/*.md` 同理）
> - `build.gradle` = `android/app/build.gradle`（本仓）
> - `composeP1/...` = `android/app/src/composeP1/kotlin/com/mutx163/qingyu/...`（本仓）
>
> 第 4 节的每条出处写**完整路径**，可直接跳转。

---

## 0. 前置：这不是「一个 Modifier」，是一个独立模块

三块能力（毛玻璃、玻璃描边、倾灯）**全部来自 `miuix-blur` 这个独立发布物**，不在 `miuix-ui` 里：

```kotlin
// docs/guide/blur.md:15-33
implementation("top.yukonga.miuix.kmp:miuix-blur-android:<version>")   // Android-only
```

硬门槛与能力探测（**必须做**，否则低版本机上是黑屏/崩溃而不是「没效果」）：

| 事实 | 出处 |
| --- | --- |
| Android 侧 `miuix-blur` 要求 **minSdk 33**；blur / blend / noise / highlight **全部**依赖 `RuntimeShader`（API 33 才有） | `docs/guide/blur.md:5-11`、`:44-47` |
| `isRuntimeShaderSupported()`：API 33+ 与所有非 Android 目标返回 `true`；**任何** `blur(...)` / `blendColors(...)` / `noiseDither(...)` / `textureBlur(...)` / highlight / 自建 `RuntimeShader` 的代码路径都要用它门控 | `docs/guide/blur.md:56-69` |
| `isRenderEffectSupported()`：API 32+；只需要 backdrop 脚手架（如挂 `colorFilter`）时用它 | `docs/guide/blur.md:60-62` |

demo 的门控写法（两处，都要照抄）：

```kotlin
// PageUtils.kt:116-124 —— 不支持就返回 null，调用方一律走「无模糊」分支
@Composable
fun rememberBlurBackdrop(): LayerBackdrop? {
    val appState = LocalAppState.current
    if (!appState.enableBlur || !isRuntimeShaderSupported()) return null
    val surfaceColor = MiuixTheme.colorScheme.surface
    return rememberLayerBackdrop {
        drawRect(surfaceColor)   // ← 先铺不透明底，见 §1.3
        drawContent()
    }
}
```

```kotlin
// BlurSection.kt:60-74 —— 整节直接不渲染，而不是渲染出坏效果
fun LazyListScope.blurSection() {
    if (!isRuntimeShaderSupported()) return
    item(key = "blur") { SmallTitle(text = "Texture Blur"); BlurDemo() }
    item(key = "foreground_blur") { SmallTitle(text = "Foreground Blur"); ForegroundBlurDemo() }
    item(key = "progressive_blur") { SmallTitle(text = "Progressive Blur"); ProgressiveBlurDemo() }
}
```

> 顺带：`isRuntimeShaderSupported` 在 demo 里既从 `top.yukonga.miuix.kmp.blur` 导入（`PageUtils.kt:31`），
> 官方文档也从 `top.yukonga.miuix.kmp.shader` 导入（`docs/guide/blur.md:57-58`）——两条路都通。

---

## 1. 毛玻璃

### 1.1 三步接线：顺序不能换，依赖关系是「先录后采」

官方原文（`docs/guide/blur.md:71-77`）就是三步，且**第 2 步必须包住要被模糊的内容、第 3 步必须是另一个（叠在上面的）节点**：

1. `val backdrop = rememberLayerBackdrop()` —— 造一个「录像带」（`LayerBackdrop`），本身不画任何东西。
2. `Modifier.layerBackdrop(backdrop)` —— 挂在**背景内容容器**上，把它**已经画出来的像素**录进 `backdrop`。
3. `Modifier.textureBlur(backdrop = backdrop, shape = ...)` —— 挂在**前景（模糊面）**上，采样 `backdrop` 并模糊后绘制。

**依赖方向**：2 是 3 的输入。3 单独存在 = 采到空气（全透明/黑）；2 单独存在 = 毫无视觉变化。
`shape` 决定模糊区域的裁剪形状（`RectangleShape` 用于通栏，`RoundedCornerShape(24.dp)` 用于卡片）。

```kotlin
// docs/guide/blur.md:86-135（结构等价于 BlurSection.kt:118 / :132-138 / :144-151）
val backdrop = rememberLayerBackdrop()

Box {
    // ① 被捕获层：背景图/渐变/页面内容
    Box(Modifier.matchParentSize().layerBackdrop(backdrop)) { BlurBackground() }

    // ② 模糊面：叠在上面，采样 ① 并模糊
    Box(
        Modifier
            .fillMaxWidth(0.8f).height(140.dp).align(Alignment.Center)
            .textureBlur(
                backdrop = backdrop,
                shape = RoundedCornerShape(24.dp),
                blurRadiusX = 100f,
                blurRadiusY = 100f,
                noiseCoefficient = BlurDefaults.NoiseCoefficient,
                colors = BlurDefaults.blurColors(blendColors = currentBlend),
                highlight = highlight,          // ← 玻璃描边，见 §3
            ),
    )
}
```

**整页级接线**（demo 每个页面的统一姿势，`MainPage.kt:99` / `:256-302` / `:305`）：

```kotlin
val backdrop = rememberBlurBackdrop()                    // 不支持 → null
val blurActive = backdrop != null
val barColor = if (blurActive) Color.Transparent else MiuixTheme.colorScheme.surface

Scaffold(
    topBar = {
        BlurredBar(backdrop, blurActive) {               // 顶栏套模糊
            AdaptiveTopAppBar(title = "Home", color = barColor, /* ... */)
        }
    },
) { innerPadding ->
    Box(if (backdrop != null) Modifier.layerBackdrop(backdrop) else Modifier) {
        LazyColumn { /* 页面内容 */ }                     // 内容被录进 backdrop
    }
}
```

### 1.2 `BlurredBar`：官方顶栏/底栏的两种模糊档（**最值得直接抄的一段**）

`PageUtils.kt:126-168`。注意 `blurStyle == 1` 走**渐进模糊**，否则走**均匀模糊**，两者用的是同一份配色函数：

```kotlin
@Composable
fun BlurredBar(backdrop: LayerBackdrop?, blurEnabled: Boolean, content: @Composable () -> Unit) {
    val progressive = LocalAppState.current.blurStyle == 1
    val blurActive = blurEnabled && backdrop != null
    Box(
        modifier = if (blurActive && !progressive) {
            Modifier.textureBlur(
                backdrop = backdrop,
                shape = RectangleShape,
                blurRadius = 25f,                    // ← 通栏顶栏用 25f
                colors = barBlurColors(),
            )
        } else Modifier,
    ) {
        if (blurActive && progressive) {
            Box(
                Modifier.matchParentSize().progressiveTextureBlur(
                    backdrop = backdrop,
                    shape = RectangleShape,
                    gradient = ProgressiveBlur.Top.copy(curve = 2.2f),  // ← 前重后轻的陡降
                    blurRadius = 10f,                                   // ← 渐进档只用 10f
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

要点：**通栏面用 `surface` 以 0.8 不透明度压一层**（否则背景花纹会「透」得字看不清）；
渐进档降到 0.3，因为渐进模糊本身在清晰端要跟内容无缝衔接。

同一模式在底部导航栏也有一份手写版：`AppContent.kt:527-559`（`textureBlur(blurRadius = 25f, colors = surface.copy(0.8f))` + `barColor = Transparent`）。

### 1.3 坑：`layerBackdrop` **只录自己这一层**

`docs/guide/blur.md:105-118` 明确警告：
`layerBackdrop` 捕获的是**它所在 composable 画的内容**，**不含父级背景**（例如 `Scaffold` 的 `Surface`）。
若被捕获内容有透明区（如没有背景的文字），模糊会把颜色扩散进透明像素 → **明显色块**。

修法是第 1 步的 lambda 里先铺不透明底（`PageUtils.kt:120-123`、`docs/guide/blur.md:110-116`）：

```kotlin
val backdrop = rememberLayerBackdrop {
    drawRect(MiuixTheme.colorScheme.surface)   // 保证捕获到不透明背景
    drawContent()
}
```

### 1.4 参数含义与 demo 实际取值

#### `blurRadius` / `blurRadiusX` / `blurRadiusY`

| 项 | 含义 | 默认 | 出处 |
| --- | --- | --- | --- |
| `blurRadius` | 模糊半径（dp），内部按屏幕密度换算成像素，**夹到 [0, 150]** | `20f` | `docs/guide/blur.md:411` |
| `blurRadiusX/Y` | 独立 X/Y 半径的重载（两个都必填） | — | `docs/guide/blur.md:412-413`、`:296-312` |
| `BlurDefaults.BlurRadius` | 默认半径常量 | `20f` | `docs/guide/blur.md:464` |
| `BlurDefaults.MaxBlurRadius` | 上限常量 | `150f` | `docs/guide/blur.md:466` |
| `noiseCoefficient` | 抗色带噪点，`0f` 关闭 | `0.0045f` | `docs/guide/blur.md:414`、`:334-347` |

demo 实际取值（滑块范围就是「能调到的极值」）：

| 场景 | 取值 | 出处 |
| --- | --- | --- |
| 顶栏通栏（均匀档） | `blurRadius = 25f` | `PageUtils.kt:139` |
| 顶栏通栏（渐进档） | `blurRadius = 10f` | `PageUtils.kt:154` |
| 底部导航栏 | `blurRadius = 25f` | `AppContent.kt:548` |
| Texture Blur 演示初始 | `blurRadiusX = blurRadiusY = 100f`（滑块上限 200） | `BlurSection.kt:223-224`、`:342-346` |
| Foreground Blur 演示初始 | `200f`（滑块上限 200） | `BlurSection.kt:386-387`、`:497` |
| Progressive 演示初始 | `blurRadius = 20f`，`noise = BlurDefaults.ProgressiveNoiseCoefficient` | `BlurSection.kt:78-79` |
| 噪点（均匀档） | `BlurDefaults.NoiseCoefficient`（0.0045） | `BlurSection.kt:225`、`:388` |

> 渐进模糊的 `noiseCoefficient` **默认就是 `0f`**（`docs/guide/blur.md:432`、`:284`）：
> 噪点叠在「模糊渐变」上比叠在均匀模糊上更显眼，别手贱打开。

#### `BlurColors` / `BlurDefaults.blurColors` / `BlendColorEntry`

| 项 | 含义 | 默认 | 出处 |
| --- | --- | --- | --- |
| `BlurColors.blendColors` | 叠在模糊背景上的颜色层，**按顺序绘制** | `emptyList()` | `docs/guide/blur.md:455` |
| `BlurColors.brightness` | 亮度，范围 [-1, 1] | `0f` | `docs/guide/blur.md:456` |
| `BlurColors.contrast` | 对比度倍数 | `1f` | `docs/guide/blur.md:457` |
| `BlurColors.saturation` | 饱和度倍数 | `1f` | `docs/guide/blur.md:458` |
| `BlendColorEntry(color, mode)` | 一层 = 颜色 + `BlurBlendMode`；`mode` 默认 `SrcOver` | — | `docs/guide/blur.md:147-153` |
| `BlurDefaults.blurColors(...)` | `@Composable` 版，内部 remember | — | `docs/guide/blur.md:171-182` |
| `BlurBlendMode` | 40+ 种：标准 SkBlendMode（0-28）+ 自定义 100+（Lab / LinearLight 等，**需 `isRuntimeShaderSupported()`**） | — | `docs/guide/blur.md:184-229` |

**demo 用的是「成套 token」而不是手搓颜色** —— `ColorBlendToken.kt`（212 行）把官方的
Info / Colored / Pured / Overlay 四系 × Thin / Regular / Thick × Light/Dark 全列好了，
`BlurSection.kt:246-262` 把它们装进下拉框：

```kotlin
// BlurSection.kt:246-262（Texture Blur 演示）
val blendConfigs = remember(isInDark, surface) {
    listOf(
        "None"            to emptyList(),
        "Info Thin"       to if (isInDark) ColorBlendToken.Info_Thin_Dark       else ColorBlendToken.Info_Thin_Light,
        "Info Regular"    to if (isInDark) ColorBlendToken.Info_Regular_Dark    else ColorBlendToken.Info_Regular_Light,
        "Colored Thin"    to if (isInDark) ColorBlendToken.Colored_Thin_Dark    else ColorBlendToken.Colored_Thin_Light,
        "Colored Regular" to if (isInDark) ColorBlendToken.Colored_Regular_Dark else ColorBlendToken.Colored_Regular_Light,
        "Colored Thick"   to if (isInDark) ColorBlendToken.Colored_Thick_Dark   else ColorBlendToken.Colored_Thick_Light,
        "Pured Regular"   to if (isInDark) ColorBlendToken.Pured_Regular_Dark   else ColorBlendToken.Pured_Regular_Light,
        "Pured Thick"     to if (isInDark) ColorBlendToken.Pured_Thick_Dark     else ColorBlendToken.Pured_Thick_Light,
        "Overlay Thin"    to ColorBlendToken.Overlay_Thin_Light,
        "Overlay Thick"   to if (isInDark) ColorBlendToken.Overlay_Thick_Dark   else ColorBlendToken.Overlay_Thick_Light,
    )
}
var blendModeIndex by remember { mutableIntStateOf(5) }   // ← 默认 "Colored Thick"
```

`BlurSection.kt:298-303` 把它接进 `textureBlur`：

```kotlin
colors = BlurDefaults.blurColors(
    blendColors = currentBlend.second,
    brightness = brightness,   // 默认 0f
    contrast = contrast,       // 默认 1f
    saturation = saturation,   // 默认 1f
),
```

**抄哪个 token**：卡片/面板类玻璃用 `Colored_Thick_*`（demo 默认，最像「有厚度的玻璃」）；
通栏顶栏用 `surface.copy(0.8f)` 单层（`PageUtils.kt:164-168`）；
想省事又不想难看，就 `Colored_Regular_Light/Dark`。

`ColorBlendToken` 里的真实取值举例（可直接照抄，注意 Light/Dark 用的是**不同 blend mode**）：

```kotlin
// ColorBlendToken.kt:62-70
val Colored_Thin_Light = listOf(
    BlendColorEntry(Color(0x991C1C1C), BlurBlendMode.Overlay),
    BlendColorEntry(Color(0x802B2B2B), BlurBlendMode.SoftLight),
)
val Colored_Thin_Dark = listOf(
    BlendColorEntry(Color(0x1A9C9C9C), BlurBlendMode.ColorBurn),
    BlendColorEntry(Color(0x337A7A7A), BlurBlendMode.PlusDarker),
)
```

#### `ProgressiveBlur`

含义（`docs/guide/blur.md:266-282`、`:440-449`）：一条**两点线性渐变**，模糊在 `startFraction` 满强度、
在 `endFraction` 归零，方向由 `angle`（度，从 +X 轴顺时针）决定。

| 属性 | 含义 | 默认 |
| --- | --- | --- |
| `angle` | 方向：0 = 左→右，90 = 上→下，180 = 右→左，270 = 下→上 | `90f` |
| `startFraction` | 满强度处的归一化位置 [0,1] | `0f` |
| `endFraction` | 归零处 [0,1]；**可以小于 startFraction 以反转**，但必须与它不等 | `1f` |
| `curve` | 幂曲线：<1 把半径变化集中到强端，>1 集中到清晰端；必须为正 | `1f` |

四个预设（`docs/guide/blur.md:271-275`、`:449`）：

```kotlin
ProgressiveBlur.Top      // angle = 90°，上边缘最强（顶栏用这个）
ProgressiveBlur.Bottom   // angle = 270°，下边缘最强（底栏用这个）
ProgressiveBlur.Left     // angle = 0°
ProgressiveBlur.Right    // angle = 180°

ProgressiveBlur.Top.copy(startFraction = 0.3f, endFraction = 0.9f)  // 自定义带宽
ProgressiveBlur.Top.copy(curve = 2.2f)                              // 官方顶栏用的陡降
```

**性能警告**（`docs/guide/blur.md:286-288`）：清晰端每帧要多一个**全分辨率覆盖 pass**，
GPU 带宽高于同面积 `textureBlur` —— **只用于栏 / 边缘带，不要铺大面积**。

#### 前景模糊（文字吃背景模糊）：`contentBlendMode = DstIn`

`BlurSection.kt:436-468` 是「文字本身被背景模糊填充」的做法：把 `textureBlur` 直接挂到 `Text` 上，
`contentBlendMode = DstIn` 让**文字的 alpha 通道当遮罩**：

```kotlin
Text(
    text = "Foreground Blur\nMiuix Demo",
    fontSize = 32.sp, fontWeight = FontWeight.Black,
    modifier = Modifier.fillMaxWidth().align(Alignment.Center)
        .textureBlur(
            backdrop = backdrop,
            shape = RoundedCornerShape(0.dp),
            blurRadiusX = blurRadiusX,     // 200f
            blurRadiusY = blurRadiusY,
            noiseCoefficient = noiseCoefficient,
            colors = BlurDefaults.blurColors(blendColors = currentBlend.second, /* ... */),
            contentBlendMode = ComposeBlendMode.DstIn,   // ← 关键
        ),
)
```

配套的 `logoBlend`（`BlurSection.kt:398-412`，官方调出来的「金属 logo」配色，直接抄）：

```kotlin
val logoBlend = if (isInDark) listOf(
    BlendColorEntry(Color(0xe6a1a1a1), BlurBlendMode.ColorDodge),
    BlendColorEntry(Color(0x4de6e6e6), BlurBlendMode.LinearLight),
    BlendColorEntry(Color(0xff1af500), BlurBlendMode.Lab),
) else listOf(
    BlendColorEntry(Color(0xcc4a4a4a), BlurBlendMode.ColorBurn),
    BlendColorEntry(Color(0xff4f4f4f), BlurBlendMode.LinearLight),
    BlendColorEntry(Color(0xff1af200), BlurBlendMode.Lab),
)
```

### 1.5 毛玻璃最小接线（照抄即可）

```kotlin
// 1) build.gradle：加依赖（minSdk 必须 ≥ 33）
implementation("top.yukonga.miuix.kmp:miuix-blur-android:0.9.4")

// 2) 页面顶部
val backdrop = rememberBlurBackdrop()               // 内部已做 isRuntimeShaderSupported 门控
val blurActive = backdrop != null
val barColor = if (blurActive) Color.Transparent else MiuixTheme.colorScheme.surface

// 3) 顶栏套 BlurredBar(backdrop, blurActive) { ...TopAppBar(color = barColor) }
// 4) 内容容器套 Modifier.layerBackdrop(backdrop)
```

---

## 2. 按压反馈

### 2.1 `PressFeedbackType`：三种取值、视觉表现

| 取值 | 视觉表现 | 出处 |
| --- | --- | --- |
| `None` | 无视觉反馈（默认） | `docs/guide/utils.md:253` |
| `Sink` | **下沉**：组件被按下时平滑缩小 | `docs/guide/utils.md:254`、`:211-215` |
| `Tilt` | **倾斜**：按触摸点位置倾斜，一角「沉下去」、对角「不动」 | `docs/guide/utils.md:255`、`:226-228` |

`Card` 上的语义（`docs/components/card.md:36-38`）：

| 参数 | 类型 | 含义 | 默认 |
| --- | --- | --- | --- |
| `pressFeedbackType` | `PressFeedbackType` | 按压反馈类型 | `PressFeedbackType.None` |
| `showIndication` | `Boolean` | 是否显示点击指示效果（水波纹/高亮） | `false` |
| `holdDownState` | `Boolean` | 卡片是否处于**按下态**（外部强制的视觉态） | `false` |

> 三个参数**只在「交互式 Card」上生效**——即传了 `onClick` 或 `onLongPress` 的重载
> （`docs/components/card.md:39-45` 的 "Applies To: Interactive" 与 `:43-45` 的警告）。

### 2.2 Card 三种形态的官方代码（`CardSection.kt`）

**形态一：静态展示 + `None` + `showIndication = true`**（`CardSection.kt:36-60`）

```kotlin
Card(
    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp).padding(bottom = 12.dp),
    colors = CardDefaults.defaultColors(color = MiuixTheme.colorScheme.primaryVariant),
    insideMargin = PaddingValues(16.dp),
    pressFeedbackType = PressFeedbackType.None,
    showIndication = true,
) {
    Text("Card", fontSize = 19.sp, fontWeight = FontWeight.SemiBold)
    Text("ShowIndication: true", fontSize = 17.sp)
}
```

**形态二：`Sink`（点了会缩）与 `Tilt`（点了会倾）并排**（`CardSection.kt:68-105`）

```kotlin
Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp).padding(bottom = 12.dp),
    horizontalArrangement = Arrangement.spacedBy(12.dp)) {
    Card(                                          // ← Sink：必须有 onClick
        modifier = Modifier.weight(1f),
        insideMargin = PaddingValues(16.dp),
        pressFeedbackType = PressFeedbackType.Sink,
        onClick = { println("Card click") },
        content = { /* 标题 + "PressFeedback\nType: Sink" */ },
    )
    Card(                                          // ← Tilt：这里配的是 onLongPress
        modifier = Modifier.weight(1f),
        insideMargin = PaddingValues(16.dp),
        pressFeedbackType = PressFeedbackType.Tilt,
        onLongPress = { println("Card long press") },
        content = { /* 标题 + "PressFeedback\nType: Tilt" */ },
    )
}
```

**形态三：`holdDownState`（长按弹窗期间保持「按下」外观）**（`CardSection.kt:111-149`）

```kotlin
var showDialog by rememberSaveable { mutableStateOf(false) }
var holdDown by rememberSaveable { mutableStateOf(false) }

Card(
    modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp).padding(bottom = 12.dp),
    insideMargin = PaddingValues(16.dp),
    pressFeedbackType = PressFeedbackType.Sink,
    showIndication = true,
    holdDownState = holdDown,          // ← 由外部状态强制「按住」外观
    onLongPress = { showDialog = true; holdDown = true },
    content = { /* 标题 + "Long press to show dialog" */ },
)

OverlayDialog(
    show = showDialog,
    title = "Long Press Action",
    summary = "Triggered by long pressing the card.",
    onDismissRequest = { showDialog = false },
    onDismissFinished = { holdDown = false },   // ← 弹窗真正消失后才松手
    content = { /* 取消 / 确认 */ },
)
```

**`holdDownState` 的语义**：它不是「你按住」的事实，而是**外部告诉组件「现在看起来应该像被按住」**。
典型用途就是长按唤出对话框——手指抬起后对话框还在，卡片必须继续显示按下态，
否则会「一闪」；`onDismissFinished`（不是 `onDismissRequest`）才复位，保证动画播完。
同样的用法遍布官方：`DialogSection.kt:67-103`、`BottomSheetSection.kt:69-78`、`ArrowSection.kt:80`、
`docs/components/arrowpreference.md:51-61`、`iconbutton.md:48-56`。

### 2.3 非 Card 组件：`Modifier.pressable()` + `SinkFeedback` / `TiltFeedback`

`docs/guide/utils.md:196-245`：`pressable()` 是通用按压反馈 Modifier，**默认效果就是 `SinkFeedback`**。

```kotlin
// Sink（默认）
Box(Modifier.pressable().background(Color.Blue).size(100.dp))

// Tilt：用同一个 interactionSource 串起 pressable + combinedClickable
val interactionSource = remember { MutableInteractionSource() }
Box(
    Modifier
        .pressable(interactionSource = interactionSource, indication = TiltFeedback())
        .combinedClickable(
            interactionSource = interactionSource,
            indication = LocalIndication.current,
            onClick = {}, onLongClick = {},
        )
        .background(Color.Green).size(100.dp),
)
```

### 2.4 手感的两台「发动机」：官方 demo 的 `animation/` 两个类

这两个类**不在 miuix 库里**，是 demo 自己带的上游适配（注释写明
`Adapted from Kyant0/AndroidLiquidGlass`, Apache 2.0），但它们是「按压有手感」的真正来源，
液态玻璃导航栏完全靠它们驱动。要用就得**整段抄进本仓**。

#### `DampedDragAnimation`（`component/animation/DampedDragAnimation.kt:36-180`）

一条拖拽手势 → **五个弹簧通道**：

| 通道 | 弹簧参数 | 用途 | 行号 |
| --- | --- | --- | --- |
| `value` | `spring(1f, 1000f, visibilityThreshold)` | 浮点「当前页/当前档位」位置 | `:50` |
| `velocity` | `spring(0.5f, 300f, visibilityThreshold*10f)` | 速度（用于形变） | `:51` |
| `pressProgress` | `spring(1f, 1000f, 0.001f)` | 按下进度 0→1 | `:52` |
| `scaleX` | `spring(0.6f, 250f, 0.001f)` | 按下横向缩放 | `:53` |
| `scaleY` | `spring(0.7f, 250f, 0.001f)` | 按下纵向缩放 | `:54` |

关键语义：

- `press()`（`:103-112`）：三路并发 —— `pressProgress → 1`、`scaleX/scaleY → pressedScale`。
- `release()`（`:114-126`）：**先 `withFrameMillis { }` 让过一帧**，再等值动画逼近目标
  （`snapshotFlow{...}.first { abs(it - target) < 0.025 * range }`）才回弹。
  这个「等值先落定、再收缩放」的顺序是「松手不抽搐」的关键。
- `animateToValue()`（`:135-147`）：`mutatorMutex.mutate { press(); 值动画; release() }` ——
  点一下 tab，视觉上是**按下去 + 滑过去 + 弹回来**一整套。
- 手势识别用的是自定义 `inspectDragGestures`（`:159-180`）：在 `PointerEventPass.Initial` 拿
  `awaitFirstDown`（先于子节点拿到手势），并用 `changedToUpIgnoreConsumed()` 判抬手，
  所以**子节点消费了事件也能正确收尾**。

#### `InteractiveHighlight`（`component/animation/InteractiveHighlight.kt:26-118`）

「按下时从手指位置亮起一团光斑，松手弹回按下点」：

- 两个弹簧：`spring(0.5f, 300f, 0.001f)`（进度）与 `spring(0.5f, 300f, Offset.VisibilityThreshold)`（位置）——`:31-32`。
- 绘制（`:43-81`）：
  - 整块叠 `Color.White.copy(alpha = 0.06f * progress)`，`BlendMode.Plus`（`:46-49`）；
  - 半径 = `size.minDimension * 1.2f`（`:51`），中心被 `coerceIn(0f, size)` 夹住（`:52-55`）；
  - 光斑色 `Color.White.copy(alpha = 0.12f * progress)`（`:56`）。
- **能力降级**：有 RuntimeShader 就用 AGSL `SPOT_SHADER`（`smoothstep` S 曲线衰减，`:109-118`），
  否则退化成 `Brush.radialGradient`（线性衰减，「几乎看不出差别」，`:38-41`、`:65-78`）。
- 手势（`:83-97`）：按下 → 进度弹到 1、位置 snap 到按下点；拖动 → 位置 snap 跟随；
  松手 → 进度弹回 0，**位置同时弹回最初按下点**（`:100-105`）。

### 2.5 触觉反馈：`scrollEndHaptic`

`docs/guide/utils.md:180-194`：

```kotlin
LazyColumn(
    modifier = Modifier.fillMaxSize().scrollEndHaptic(
        hapticFeedbackType = HapticFeedbackType.TextHandleMove,   // 默认值
    ),
)
```

demo 把它做成开关（`PageUtils.kt:39-47` 的 `pageScrollModifiers`，由 `appState.enableScrollEndHaptic` 控制）。

---

## 3. 液态玻璃与倾灯

### 3.1 `Highlight` 预设：六个 token + `Default` 别名

`docs/guide/blur.md:520-533`：

| Token | `innerBlurRadius` | 视觉 |
| --- | --- | --- |
| `Highlight.GlassStrokeBigLight` | 3.5 dp | 最厚最柔 —— 大号浅色卡片 |
| `Highlight.GlassStrokeMiddleLight` | 2.8 dp | 标准浅色卡片（**默认**） |
| `Highlight.GlassStrokeSmallLight` | 2.6 dp | 紧凑锐利 —— 小号浅色卡片 |
| `Highlight.GlassStrokeBigDark` | 1.7 dp | 最薄 —— 大号深色卡片 |
| `Highlight.GlassStrokeMiddleDark` | 2.0 dp | 标准深色卡片 |
| `Highlight.GlassStrokeSmallDark` | 2.3 dp | 最锐利 —— 小号深色卡片 |

`Highlight.Default` = `GlassStrokeMiddleLight`（`docs/guide/blur.md:533`）。

**按尺寸+主题选 token** 的官方封装（`component/highlight/HighlightConfig.kt:10-22`）：

```kotlin
enum class Container(val displayName: String) {
    Disabled("Disabled"), Large("Large Container"),
    Medium("Medium Container"), Small("Small Container"),
}

fun get(container: Container, isDark: Boolean): Highlight? = when (container) {
    Container.Disabled -> null
    Container.Large  -> if (!isDark) Highlight.GlassStrokeBigLight    else Highlight.GlassStrokeBigDark
    Container.Medium -> if (!isDark) Highlight.GlassStrokeMiddleLight else Highlight.GlassStrokeMiddleDark
    Container.Small  -> if (!isDark) Highlight.GlassStrokeSmallLight  else Highlight.GlassStrokeSmallDark
}
```

两种接法（`docs/guide/blur.md:472-518`）：

```kotlin
// 恒定：挂在 textureBlur 上
Box(Modifier.size(200.dp, 100.dp).textureBlur(
    backdrop = backdrop, shape = RoundedCornerShape(24.dp),
    highlight = Highlight.GlassStrokeMiddleLight,
))

// 响应式：挂在 drawBackdrop 上，lambda 跑在同一个 BackdropEffectScope 里，
// 可以随状态（如按压进度）变化，并自动拿到当前 size / shape
Box(Modifier.size(200.dp, 100.dp).drawBackdrop(
    backdrop = backdrop,
    shape = { RoundedCornerShape(24.dp) },
    effects = { blur(20.dp.toPx()) },
    highlight = { Highlight.GlassStrokeMiddleLight.copy(alpha = pressProgress) },
))
```

> 关掉高亮：传 `null`，或给一个 `width = 0.dp` 的 `Highlight`（`docs/guide/blur.md:514`）。
> **高亮同样需要 `isRuntimeShaderSupported()`**，不支持时静默跳过（`:516-518`）。

**自定义 `BloomStroke`**（`docs/guide/blur.md:535-564`）—— 关键几何约定：

- `LightPosition` 是**归一化 UV**，参考原点 `(0.5, 0.7, 0)`；shader 把 `(x-0.5, y-0.7, z)` 归一成 3D 单位方向。
- **`z < 0` = 光在表面之后**，照亮「朝内的边缘」；官方所有内置 token 都是 `z < 0`。
- 两盏灯被 shader 限制在**对侧半球**：`primaryLight` 照圆角矩形的上半，`secondaryLight` 照下半。
  `y < 0.7` 偏上、`y > 0.7` 偏下。

```kotlin
val custom = Highlight(
    width = 1.dp, alpha = 0.8f,
    style = BloomStroke(
        color = Color.White.copy(alpha = 0.05f),
        innerBlurRadius = 3.dp,
        primaryLight   = LightSource(LightPosition(0.5f, 0.4f, -0.5f), intensity = 0.4f),
        secondaryLight = LightSource(LightPosition(0.5f, 0.85f, -0.5f), intensity = 0.3f),
    ),
)
```

属性默认值见 `docs/guide/blur.md:596-631`（`Highlight.width` 默认 `0.8.dp`、
`BloomStroke.innerBlurRadius` 默认 `2.8.dp`、`blendMode` 默认 `BlendMode.Plus` 等）。

### 3.2 `rememberTiltLight`：把旋转传感器接进高光

**API 层**（`docs/guide/blur.md:566-594`、`:632-639`）：`rememberTiltLight` 按设备旋转传感器
实时平移光的位置；Android 上是视差边缘，Desktop/iOS/macOS/Web 上 tilt 恒为 0（光就固定在基准位）。
`sensitivity` = **每弧度倾斜平移的 UV 比例**，`0.1f` ≈ 1 rad 平移 10% 边界。

```kotlin
val baseStyle = Highlight.GlassStrokeMiddleLight.style as BloomStroke

val tiltPrimary = rememberTiltLight(
    basePosition = baseStyle.primaryLight.position,
    intensity = baseStyle.primaryLight.intensity,
    sensitivity = 0.15f,
)
val tiltSecondary = rememberTiltLight(
    basePosition = baseStyle.secondaryLight.position,
    intensity = baseStyle.secondaryLight.intensity,
    sensitivity = 0.12f,
)

val highlight = Highlight.GlassStrokeMiddleLight.copy(
    style = baseStyle.copy(primaryLight = tiltPrimary, secondaryLight = tiltSecondary),
)
```

**demo 的完整接线**（`component/highlight/ContainerHighlight.kt:22-58`）——
注意两处工程细节：

```kotlin
@Composable
internal fun rememberContainerHighlight(
    container: HighlightConfig.Container,
    isDark: Boolean,
    tiltDriven: Boolean,
    primarySensitivity: Float = 0.15f,     // ← 主光 0.15
    secondarySensitivity: Float = 0.12f,   // ← 副光 0.12
): Highlight? {
    val highlightBase = HighlightConfig.get(container, isDark)
    // ① 传感器必须无条件接线（Composable 不能条件调用）；
    //    container == Disabled 时用一个占位 style 喂传感器，最后再把结果 gate 成 null。
    val baseStyle = (highlightBase?.style as? BloomStroke) ?: BloomStroke.GlassStrokeMiddleLight

    val tiltPrimary   = rememberTiltLight(baseStyle.primaryLight.position,   baseStyle.primaryLight.color,   baseStyle.primaryLight.intensity,   primarySensitivity)
    val tiltSecondary = rememberTiltLight(baseStyle.secondaryLight.position, baseStyle.secondaryLight.color, baseStyle.secondaryLight.intensity, secondarySensitivity)

    return remember(highlightBase, baseStyle, tiltDriven, tiltPrimary, tiltSecondary) {
        when {
            highlightBase == null -> null                       // ② 最后才 gate
            tiltDriven -> highlightBase.copy(style = baseStyle.copy(primaryLight = tiltPrimary, secondaryLight = tiltSecondary))
            else -> highlightBase                               // 不动传感器，用原始 token
        }
    }
}
```

调用侧（`BlurSection.kt:232-244`）：`tiltDriven` 是一个 UI 开关，默认 `true`；
容器下拉默认 `HighlightConfig.Container.Small`。

**另一条更「重」的传感器路线**（液态玻璃导航栏用的，见下节）：
不用 `rememberTiltLight`，而是直接吃重力向量 `rememberDeviceTilt()`，自己算角度并**量化到 3°**。

### 3.3 `LiquidGlassNavigationBar` 结构要点

`component/liquid/LiquidGlassNavigationBar.kt:194-581`（`IosLiquidGlassNavigationBar`）。
它同时用到：`LayerBackdrop` + `drawBackdrop` + `blur` + `lens` + `vibrancy` + `Highlight` +
`innerShadow` + `CombinedBackdrop` + `DampedDragAnimation` + `InteractiveHighlight` + 重力传感器。
**这是「液态玻璃」的完整参考实现，缺任何一块都会退化成一块半透明色板。**

**层叠结构（自下而上）**：

| 层 | 做法 | 行号 |
| --- | --- | --- |
| ① 整栏外壳（胶囊底） | `dropShadow` + `drawBackdrop(backdrop, pillShape, effects = { padding = maxOf(padding, 40.dp.toPx()); vibrancy(); blur(4dp,4dp); lens(refractionHeight = 24dp, refractionAmount = 24dp) }, highlight = { baseHighlight.copy(alpha = 0.75f) }, layerBlock = { 按 pressProgress 放大 } , onDrawSurface = { drawRect(containerColor) })`；无模糊时退化成 `.background(containerColor, pillShape)` | `:408-448` |
| ② 图标/文字「被折射」副本 | 同一个 Row 再画一遍，`.alpha(0f)` + `.layerBackdrop(tabsBackdrop)` + `drawBackdrop` 同款 effects（**不带 highlight**），用来让文字也跟着折射；`LocalIosTabScale` 让按下的 tab 放大到 1.2 | `:464-495` |
| ③ 滑动指示器胶囊 | `drawBackdrop(combinedBackdrop, ...)` + `lens(refractionHeight = 10dp*progress, refractionAmount = 14dp*progress, depthEffect = true, chromaticAberration = 0.5f)` + `highlight = { pillHighlight.copy(alpha = pressProgress) }` + `innerShadow(radius = 8dp*progress)`；`layerBlock` 里用 `velocity` 做形变 | `:499-546` |
| ④ 无模糊降级 | `.clip(pillShape).background(accentColor.copy(alpha = 0.15f))` + 一份 `requiredWidth` 的彩色内容副本 | `:547-577` |

**驱动逻辑**：

- `DampedDragAnimation`（`:245-288`）：`initialValue = selectedIndex`、`valueRange = 0..tabsCount-1`、
  `pressedScale = 78f / 56f`（按下去放大到 78/56）、`canDrag` 限在栏内。
  `onDragStopped` 里**先算目标 tab、回调 `onItemClick`、再 `updateValue(target)`**（`:259-269`）。
- `InteractiveHighlight`（`:306-320`）：位置 lambda 把 `dampedDrag.value`（浮点 tab 下标）
  换算成像素 x —— 注释明确写「**必须 key on `dampedDrag`**，否则旧闭包会冻住光斑」。
- 重力倾灯（`:144-192`）：
  - `rememberQuantizedGravityAngle()`（`:144-161`）：读 `rememberDeviceTilt()` 的
    `gravityX/gravityY`；`|g_xy|² > 0.01`（≈6° 倾斜）才用 `atan2(gy,gx)`，否则钉在 `-π/2`；
    角度**量化到 3°**（`GRAVITY_ANGLE_STEP_RAD`）——「更细的变化看不出来」。
  - 返回值是 `State<Float>`，注释解释：传感器约 50Hz 无节流写入，**组合期读取会让整个调用方
    重组**，所以延迟到绘制期读（`:136-143`）。
  - `rememberGravityRotatedHighlight(base, extraDegrees)`（`:168-192`）：把 `dualPeak` 主光
    绕参考点 `(0.5, 0.7)` 旋转到重力角 + 偏移量，**只在角度跨量化步时重新分配对象**。
  - 两盏灯用不同偏移：`baseHighlight` = `-45f`、`pillHighlight` = `+90f`（`:323-324`）。

- 指示器专用的自定义高亮（`:108-126`，`dualPeak = true`，`color = White.copy(0.12f)`，
  `innerBlurRadius = 2.0.dp`，主光 `(0.5, -0.3, -0.05)` 强度 1f、副光 `(0.5, 0.8, -0.5)` 强度 0.4f）
  —— **可以直接抄成「小米胶囊指示器」的描边**。

- `CombinedBackdrop`（`:326`）：`rememberCombinedBackdrop(backdrop, tabsBackdrop)`，
  把「应用背景」与「这一栏自己录的第二层」合成**一个采样源**，指示器才有正确的折射内容。

### 3.4 液态玻璃的三个零件（都在 `component/liquid/`）

| 零件 | 作用 | 关键实现 / 坑 | 出处 |
| --- | --- | --- | --- |
| `lens(refractionHeight, refractionAmount, depthEffect, chromaticAberration)` | 圆角矩形**折射透镜**：边缘一圈按 SDF 梯度位移采样坐标，做出玻璃厚度 | ① `!isRuntimeShaderSupported()` 直接 return；② `refractionHeight/Amount <= 0` 直接 return；③ **`padding` 自动抬到 `max(padding, refractionAmount)`**（否则采样出界）；④ 只支持 `CornerBasedShape`；⑤ 所有像素量都要 `/ downscaleFactor`；⑥ `chromaticAberration > 0` 才走色散 shader（`0.1` 微妙 / `0.2` 类 Apple 胶囊 / `0.3+` 明显彩虹） | `Lens.kt:23-70`（doc `:15-22`） |
| `Modifier.innerShadow(shape) { InnerShadow(...) }` | 圆角形状的**内阴影**（玻璃内侧的暗边） | `InnerShadow(radius = 24.dp, offset = DpOffset(0.dp, radius), color = Black.copy(0.15f), alpha = 1f)`；实现是离屏 `GraphicsLayer` + `BlurEffect` + `BlendMode.Clear` 挖洞 | `InnerShadow.kt:35-46`、`:48-51`、`:100-144` |
| `vibrancy()` | 玻璃「通透感」：饱和度增益 | 就是 `colorControls(brightness = 0f, contrast = 1f, saturation = 1.5f)` —— **只这一行，但没有它玻璃会发灰** | `Vibrancy.kt:12-18` |
| `CombinedBackdrop` / `rememberCombinedBackdrop` | 把两个 `Backdrop` 按顺序画成一个采样源 | `isCoordinatesDependent` 取或；`offsetResidual` 取 `first` 的 | `CombinedBackdrop.kt:23-46` |

### 3.5 低阶管线 `drawBackdrop`（要自定义就靠它）

`docs/guide/blur.md:349-401`：`Modifier.drawBackdrop(backdrop, shape = { ... }, effects = { ... })`，
`effects` 块里可用的扩展：`blur(radius, edgeTreatment)`、`colorFilter(...)`、
`colorControls(brightness, contrast, saturation)`、`effect(effect)`、
`runtimeShaderEffect(key, shaderString, uniformShaderName, block)`。

**必须记住的一条**（`docs/guide/blur.md:387-389`）：
一旦 `runtimeShaderEffect` 链在 `blur` 之后，backdrop 层是在 `1/downscaleFactor` 分辨率录制的，
shader 拿到的 `coord` 是**降采样后的像素空间** —— 所有像素量 uniform（size / padding / 圆角 /
折射带宽）都要除以 `downscaleFactor`，否则采样落到层外、返回透明黑。
`Lens.kt:47-53` 就是这么干的（`scaledSizeW/H`、`scaledPadding`、`scaledRadii`…）。

### 3.6 跨页转场（参考价值，非必需）

`navigation/CrossActivityTransition.kt` 是**把 AOSP WM Shell 的跨 Activity 动画逐点复刻**的示范，
证明 miuix-nav 的公开自定义面足够表达完整平台转场（`:340-348` 注释明说「放在 example 里，
不在 miuix-nav 里」）。

- `FastOutExtraSlowIn`（`:36-54`）：`fast_out_extra_slow_in` 的**两段三次曲线**精确移植
  （单条三次曲线在中段偏差最大 0.14，肉眼可见「滑出的前脸变慢」）。
- 组合出口（`:350-354`）：`navDirectionalTransition(push = ClassicActivityOpen, pop = ClassicActivityClose, predictivePop = CrossActivityPredictive)`。
- 经典推入/弹出（`:129-157` / `:167-195`）：两层都滑 96dp、固定 450ms 缓动，
  顶层走**独立的 83ms 墙钟 alpha 轨**（开偏移 50ms / 关偏移 35ms），无暗化、无缩放。
- 手势预测返回（`:227-325`）：提交前按 `BackGestureEasing` 整形手势进度（卡片前段行程更多）、
  居中缩到 0.9、贴边；提交后走固定 450ms 缓动轨 + **闭式解速度弹跳**（`:75-87`，
  stiffness 200 / damping 0.75 / kick 夹在 [120, 1000]，边缘滑动翻倍）、卡片 90ms 内淡完、
  scrim 线性同步；取消走刚性无弹跳弹簧（`Spring(1500)`）。
- 两个像素对齐工具（`:383-392`）：`snapScaleToPixelWidth` / `snapEdgeTranslation`
  —— 不这么干，圆角裁剪的抗锯齿边在移动时会闪一条细线。

### 3.7 液态玻璃最小接线（照抄即可）

**第一步：只上「玻璃描边 + 倾灯」**（最便宜、观感提升最大，不用抄 animation/liquid 那两个目录）：

```kotlin
// 1) build.gradle：+ implementation("top.yukonga.miuix.kmp:miuix-blur-android:0.9.4")
// 2) 把 ContainerHighlight.kt:22-58 的 rememberContainerHighlight 整段抄进本仓
// 3) 卡片/面板上用响应式高亮（随按压进度亮起）
Box(
    Modifier
        .drawBackdrop(
            backdrop = backdrop,                       // §1 的 backdrop
            shape = { RoundedCornerShape(24.dp) },
            effects = {
                blur(20.dp.toPx())
                colorControls(brightness = 0f, contrast = 1f, saturation = 1.5f)  // = vibrancy()
            },
            highlight = { highlight.copy(alpha = pressProgress) },   // ← 倾灯高亮
        ),
)
```

**第二步：真「液态玻璃」栏/卡片**（整段抄 `component/liquid/` + `component/animation/`，按 §3.3 的四层结构接）：

```kotlin
val backdrop = rememberBlurBackdrop()
val tabsBackdrop = rememberLayerBackdrop()
val combinedBackdrop = backdrop?.let { rememberCombinedBackdrop(it, tabsBackdrop) }
val dampedDrag = remember { DampedDragAnimation(/* 见 :245-288 */) }
val interactiveHighlight = remember(animationScope, isLtr, dampedDrag) { InteractiveHighlight(/* :306-320 */) }

Modifier
    .dropShadow(shape = pillShape, shadow = Shadow(radius = 10.dp, color = Color.Black,
        alpha = if (isDark) 0.2f else 0.1f))                       // :408-416
    .drawBackdrop(
        backdrop = backdrop, shape = { pillShape },
        effects = {
            padding = maxOf(padding, 40.dp.toPx())                // :423-424 折射 + 按压放大都要留够
            vibrancy()                                            // :425
            blur(4.dp.toPx(), 4.dp.toPx())                        // :426-429
            lens(refractionHeight = 24.dp.toPx(), refractionAmount = 24.dp.toPx())  // :430-433
        },
        highlight = { baseHighlight.value.copy(alpha = 0.75f) },  // :435（baseHighlight 见 :323）
        layerBlock = {                                            // :436-441 按按下进度放大
            val s = lerp(1f, 1f + 16.dp.toPx() / size.width.coerceAtLeast(1f), dampedDrag.pressProgress)
            scaleX = s; scaleY = s
        },
        onDrawSurface = { drawRect(containerColor) },             // :442
    )
    .then(interactiveHighlight.modifier.then(interactiveHighlight.gestureModifier))  // :449-455
    .then(dampedDrag.modifier)                                    // :456
    .height(64.dp).padding(4.dp)                                  // :457-458
```

指示器层（`:499-546`）叠 `combinedBackdrop` + 带 `chromaticAberration = 0.5f` 的 `lens` +
`innerShadow`；无模糊时走 `:547-577` 的 `background(accentColor.copy(0.15f))` 降级。

---

## 4. 对照：官方 demo 有、我们仓库没有（**本节最重要**）

### 4.0 我们仓库现状（已用 grep/read 在本仓核实）

核实命令与结论（搜索范围 `android/app/src/composeP1/kotlin/com/mutx163/qingyu/`，共 66 个 .kt）：

| 能力点 | 命中数 | 证据 |
| --- | --- | --- |
| `pressFeedbackType` / `PressFeedbackType` | **0** | grep 全目录无匹配 |
| `layerBackdrop` / `textureBlur` / `drawBackdrop` | **0** | grep 全目录无匹配 |
| `HapticFeedback` / `scrollEndHaptic` | **0** | grep 全目录无匹配 |
| `showIndication` / `holdDownState` | **0** | grep 全目录无匹配 |
| `rememberTiltLight` / `Highlight.` / `innerShadow` / `CombinedBackdrop` | **0** | grep 全目录无匹配 |
| `pressable` / `SinkFeedback` / `TiltFeedback` | **0** | grep 全目录无匹配 |
| `top.yukonga.miuix.kmp.blur.*` / `miuix.kmp.shader.*` 导入 | **0** | 直接 grep 该模式全目录无匹配；已用的是 `miuix.kmp.basic` / `.preference` / `.icon` / `.theme` / `.overlay` / `.utils` |
| `miuix-blur` / `miuix-shader` 依赖 | **未引入** | `build.gradle:367-377` 只声明 `miuix-ui-android` / `miuix-preference-android` / `miuix-icons-android`（composeP1 与 composeUi 各一份） |
| `minSdk` | **33（已达标）** | `build.gradle:49`（defaultConfig）、`:146`（composeP1）、`:168`（composeUi）——**门槛早就抬好了，只差依赖那一行** |

两个**具体的「假实现」证据**（比「0 处」更能说明问题）：

1. **假模糊**：showcase 的「模糊 Blur」分类是**用主色 alpha 冒充**的，没有任何背景捕获与高斯模糊：

   ```kotlin
   // composeP1/.../pages/showcase/MiuixShowcaseSubpages.kt:935-951
   Box(
       modifier = Modifier.fillMaxWidth().height(110.dp)
           .clip(RoundedCornerShape(16.dp))
           .background(primaryColor.copy(alpha = (state.blurRadius / 100f).coerceIn(0.15f, 0.85f))),
       contentAlignment = Alignment.Center,
   ) { Text(text = "液态玻璃预览\nR=${state.blurRadius.toInt()} · Sat=${state.blurSaturation}", ...) }
   ```

   而它的文案声称的是**真模糊**：

   ```kotlin
   // composeP1/.../pages/showcase/ShowcaseStrings.kt:142-149
   val catBlurTitle = ShowcaseText("catBlurTitle", "模糊 Blur")
   val catBlurSummary = ShowcaseText("catBlurSummary",
       "MiuixTextureBlur / 液态玻璃（背景捕获 + 高斯模糊 + 颜色控制）")   // ← 与实现不符
   ```

   > 这既是能力缺口，也是**文案与实现不符**（AGENTS.md「COPY-STYLE」要求发现就改）。
   > 另见 `MiuixShowcaseSubpages.kt:931` 标题「TextureBlur · 液态玻璃与模糊控制」。

2. **交互 Card 完全没有按压反馈**：所有「能点的 Card」都只是裸 `onClick`，没有 `pressFeedbackType`：

   ```kotlin
   // composeP1/.../pages/about/PagesCommon.kt:192-196
   if (onClick == null) {
       Card(modifier = Modifier.fillMaxWidth(), insideMargin = margin) { content() }
   } else {
       Card(modifier = Modifier.fillMaxWidth(), insideMargin = margin, onClick = onClick) { content() }   // ← 无 pressFeedbackType
   }

   // composeP1/.../pages/import/ImportCommon.kt:142
   Card(modifier = Modifier.fillMaxWidth(), onClick = onClick) { /* ... */ }
   ```

**对照的旧版（Flutter）**——这些能力在迁移前是**真做了的**，迁移时被丢掉：
`lib/ui/hyperos/hyperos_collapsible_top_app_bar.dart:1505-1511`（真 `BackdropFilter` + `ImageFilter.blur`）、
`lib/ui/hyperos/liquid/liquid_glass_surface.dart:1099-1110`（`BackdropFilterLayer` + 折射 shader）、
`lib/ui/hyperos/soft_glass/soft_glass_tab_bar.dart:356-368`（按下/松手弹簧）、
同文件 `:596`（`pressScale`）、`lib/ui/hyperos/hyperos_miuix_spec.dart:1015`（统一弹簧周期常量）。

### 4.1 缺口清单（逐条带官方出处）

> 编号 G1…G21。每条 = 「官方有的能力」+ 官方出处（完整路径:行号）+ 我们的现状。
> 建议实施顺序：**G20 → G21 → G1 → G2 → G11 → G13**（先通依赖与最普遍的点击手感，再上玻璃）。

| # | 官方有的能力 | 官方出处（完整路径:行号） | 我们仓库现状 |
| --- | --- | --- | --- |
| **G20** | `miuix-blur` 依赖本身（毛玻璃/描边/倾灯的全部前置） | `docs/reference/miuix-demo/docs/guide/blur.md:15-33`（依赖写法）、`:5-11`（minSdk 33 硬要求） | `android/app/build.gradle:367-377` 只有 ui/preference/icons 三个模块，**无 miuix-blur**；`minSdk 33` 已在 `:49`/`:146`/`:168` 达标 |
| **G21** | `isRuntimeShaderSupported()` 能力探测 + 不支持时整段降级（返回 `null` / 不渲染） | `docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/utils/PageUtils.kt:118`、`.../component/BlurSection.kt:61`、`docs/.../guide/blur.md:49-68` | 0 处（无 `blur` 导入，自然也没有门控） |
| **G1** | 真毛玻璃三步管线：`rememberLayerBackdrop` → `Modifier.layerBackdrop(backdrop)` → `Modifier.textureBlur(backdrop, shape, ...)` | `.../utils/PageUtils.kt:116-124`（造+录）、`:126-161`（用）；`.../component/BlurSection.kt:118`、`:132-138`、`:144-151`；`docs/.../guide/blur.md:71-77`、`:86-135` | `layerBackdrop` 0 处、`textureBlur` 0 处；顶栏/底栏仍是纯色 |
| **G2** | 整页级统一接线：`BlurredBar`（顶栏模糊）+ 内容容器 `layerBackdrop` + `barColor = Transparent` | `.../utils/PageUtils.kt:126-168`；`.../MainPage.kt:99`、`:256-302`、`:305`；`.../AppContent.kt:527-559` | 无（`Scaffold`/`TopAppBar` 直接用 `MiuixTheme.colorScheme.surface` 实色） |
| **G3** | 渐进模糊 `progressiveTextureBlur` + `ProgressiveBlur.Top.copy(curve = 2.2f)`（顶栏边缘淡出，清晰端像素级锐利） | `.../utils/PageUtils.kt:146-157`；`.../component/BlurSection.kt:114-116`、`:144-151`；`docs/.../guide/blur.md:243-292`、`:422-449` | 0 处 |
| **G4** | 前景模糊：`contentBlendMode = BlendMode.DstIn`，让文字本身被背景模糊填充 | `.../component/BlurSection.kt:436-468`（尤其 `:466`）；`docs/.../guide/blur.md:314-332` | 0 处 |
| **G5** | 模糊配色：`BlurColors` / `BlendColorEntry` / `BlurDefaults.blurColors()` + 成套 `ColorBlendToken`（Info/Colored/Pured/Overlay × Thin/Regular/Thick × Light/Dark） | `.../component/BlurSection.kt:246-262`、`:298-303`；`.../component/blend/ColorBlendToken.kt:10-212`；`docs/.../guide/blur.md:138-241`、`:451-470` | 0 处（showcase 只有单色 alpha，见 §4.0 证据 1） |
| **G6** | 玻璃描边高亮 `Highlight` 六预设（`GlassStrokeBig/Middle/Small × Light/Dark`）+ `Highlight.Default` + 按尺寸/主题选择的 `HighlightConfig` | `.../component/highlight/HighlightConfig.kt:10-22`；`.../component/BlurSection.kt:236-244`、`:304`；`docs/.../guide/blur.md:472-533` | `Highlight.` 0 处 |
| **G7** | 传感器倾灯 `rememberTiltLight(basePosition, color, intensity, sensitivity)`（主光 0.15 / 副光 0.12），含「传感器必须无条件接线、最后再 gate 成 null」的写法 | `.../component/highlight/ContainerHighlight.kt:22-58`（尤其 `:32-43`、`:45-58`）；`docs/.../guide/blur.md:566-594`、`:632-639` | `rememberTiltLight` 0 处 |
| **G8** | 重力驱动的量化倾灯：`rememberDeviceTilt()` → `atan2(gy,gx)` → 量化 3° → 旋转 `dualPeak` 主光；且只在**绘制期**读 `State` 以免 50Hz 传感器触发重组 | `.../component/liquid/LiquidGlassNavigationBar.kt:129-134`、`:136-161`、`:163-192`、`:323-324` | 0 处（无 `rememberDeviceTilt`） |
| **G9** | 低阶管线 `Modifier.drawBackdrop(backdrop, shape, effects, highlight, layerBlock, onDrawSurface)` + `BackdropEffectScope`（`blur` / `colorControls` / `runtimeShaderEffect`；像素量必须 `/ downscaleFactor`） | `.../component/liquid/LiquidGlassNavigationBar.kt:417-443`、`:499-546`；`docs/.../guide/blur.md:349-401`（含 `:387-389` 警告） | `drawBackdrop` 0 处 |
| **G10** | 折射透镜 `lens(refractionHeight, refractionAmount, depthEffect, chromaticAberration)`（圆角 SDF 位移采样；`padding` 自动抬升；仅支持 `CornerBasedShape`） | `.../component/liquid/Lens.kt:15-70`（`:29` 能力门控、`:32-34` padding） | 0 处 |
| **G11** | `PressFeedbackType.Sink`（按下平滑缩小）与 `.Tilt`（按触摸点倾斜）在 Card 上的用法 | `.../component/CardSection.kt:68-86`（Sink + `onClick`）、`:87-105`（Tilt + `onLongPress`）；`docs/.../components/card.md:36`、`:142-150`；`docs/.../guide/utils.md:247-255` | `pressFeedbackType` 0 处；交互 Card 只有裸 `onClick`（`composeP1/.../pages/about/PagesCommon.kt:195`、`.../pages/import/ImportCommon.kt:142`） |
| **G12** | `Modifier.pressable()` + `SinkFeedback()` / `TiltFeedback()`（非 Card 组件的通用按压反馈；默认即 Sink） | `docs/.../guide/utils.md:196-245` | `pressable` / `SinkFeedback` / `TiltFeedback` 均 0 处 |
| **G13** | `showIndication = true`（点击指示效果） | `.../component/CardSection.kt:46`、`:123`；`.../PullToRefreshPage.kt:166`；`docs/.../components/card.md:37` | `showIndication` 0 处 |
| **G14** | `holdDownState`（外部强制「按下态」外观；配 `onLongPress` + `onDismissFinished` 复位，避免弹窗期间卡片「一闪」） | `.../component/CardSection.kt:116-149`（`:124`、`:149`）；`docs/.../components/card.md:38`；同类用法 `.../component/DialogSection.kt:67-103`、`.../component/BottomSheetSection.kt:69-78`、`.../component/ArrowSection.kt:80` | `holdDownState` 0 处 |
| **G15** | `DampedDragAnimation`：一条手势 → 值/速度/按下进度/scaleX/scaleY **五通道弹簧**；`release()` 先让过一帧再等值落定才回弹；`animateToValue()` = 按下+滑行+回弹一整套 | `.../component/animation/DampedDragAnimation.kt:36-48`、`:50-54`、`:103-112`、`:114-126`、`:135-147`、`:159-180` | 0 处（无 `component/animation` 对应物） |
| **G16** | `InteractiveHighlight`：按下从指尖亮起光斑（`Plus` 混合，0.06 底光 + 0.12 光斑，半径 = 1.2×minDimension），AGSL `smoothstep` S 曲线，无 shader 时退化为 `radialGradient`；松手位置弹回按下点 | `.../component/animation/InteractiveHighlight.kt:26-118`（`:31-32`、`:40-41`、`:43-81`、`:100-105`、`:109-118`） | 0 处 |
| **G17** | `innerShadow(shape) { InnerShadow(...) }` 内阴影（玻璃内侧暗边） | `.../component/liquid/InnerShadow.kt:35-46`、`:48-51`；用在 `.../component/liquid/LiquidGlassNavigationBar.kt:537-543` | `innerShadow` 0 处 |
| **G18** | `vibrancy()` = `colorControls(saturation = 1.5f)`（没有它玻璃发灰） | `.../component/liquid/Vibrancy.kt:12-18`；用在 `.../LiquidGlassNavigationBar.kt:425`、`:479` | 0 处 |
| **G19** | `CombinedBackdrop` / `rememberCombinedBackdrop(first, second)`：两个 backdrop 合成一个采样源（指示器折射才有正确内容） | `.../component/liquid/CombinedBackdrop.kt:23-46`；用在 `.../LiquidGlassNavigationBar.kt:326` | `CombinedBackdrop` 0 处 |
| **G20b** | 整块 `IosLiquidGlassNavigationBar`（胶囊底 + 折射图标副本 + 滑动指示器 + 倾灯 + 降级路径，四层结构） | `.../component/liquid/LiquidGlassNavigationBar.kt:194-581` | 0 处（无 `component/liquid` 对应物） |
| **G21b** | `scrollEndHaptic`（滚动到末端触觉反馈） | `.../utils/PageUtils.kt:39-47`；`docs/.../guide/utils.md:180-194` | `HapticFeedback` / `scrollEndHaptic` 均 0 处 |
| **G21c** | 跨页转场 `CrossActivityTransition`（AOSP 两段三次曲线 + 墙钟 alpha 轨 + 闭式速度弹跳 + 像素对齐） | `.../navigation/CrossActivityTransition.kt:36-54`、`:129-157`、`:167-195`、`:227-325`、`:350-354`、`:383-392` | 0 处 |

### 4.2 「我们缺什么」一句话总结

**缺的不是组件，是三样东西**：

1. **依赖与门控**（G20/G21）——`miuix-blur` 没进 `build.gradle`，所以后面全部无从谈起；
   `minSdk 33` 这个坑其实早就填了，只差一行 `implementation`。
2. **「采样」这条管线**（G1–G5、G9、G10、G17–G20b）——我们把 miuix 当成「好看的静态控件库」在用，
   而它的观感**长在 backdrop 采样上**：没有 `layerBackdrop` 就没有东西可糊，玻璃就退化成半透明色块。
3. **「反馈」这条管线**（G6–G8、G11–G16、G21b）——按压反馈、玻璃描边、倾灯、光斑、拖拽弹簧
   **一个都没接**；而老版 Flutter 是**真做了的**（`soft_glass_tab_bar` 的按下弹簧、
   `hyperos_collapsible_top_app_bar` 的真 `BackdropFilter`、`liquid_glass_surface` 的折射 shader）。
   所以「用了正主反而更丑、点击没手感」的根因是**迁移时只搬了外观、没搬交互与材质管线**。

---

## 5. 照抄清单（实施顺序）

```text
① build.gradle：+ implementation("top.yukonga.miuix.kmp:miuix-blur-android:0.9.4")
   （minSdk 33 已达标；composeP1 与 composeUi 两个变体都要加）
② 抄 PageUtils.kt:116-168 的 rememberBlurBackdrop / BlurredBar / barBlurColors
③ 页面：backdrop = rememberBlurBackdrop()；顶栏 BlurredBar(backdrop, blurActive){ TopAppBar(color = barColor) }；
   内容容器 Modifier.layerBackdrop(backdrop)；barColor = if (blurActive) Transparent else surface
④ 交互 Card：+ pressFeedbackType = PressFeedbackType.Sink, showIndication = true
   （PagesCommon.kt:195、ImportCommon.kt:142 是第一批）
⑤ 长按弹窗类：+ holdDownState = holdDown，并在 onDismissFinished 复位
⑥ 玻璃卡片：textureBlur(shape = RoundedCornerShape(24.dp), colors = BlurDefaults.blurColors(
      blendColors = ColorBlendToken.Colored_Thick_Light/Dark), highlight = Highlight.GlassStrokeMiddleLight/Dark)
⑦ 顶栏想要边缘淡出：改用 progressiveTextureBlur + ProgressiveBlur.Top.copy(curve = 2.2f)
⑧ 要真「液态玻璃」：整段抄 component/animation/ + component/liquid/（含 Lens/InnerShadow/Vibrancy/CombinedBackdrop）
⑨ 顺手修 MiuixShowcaseSubpages.kt:935-951 的假模糊与 ShowcaseStrings.kt:145 的虚假文案
```

> 所有官方实现均为 Apache-2.0（`component/animation/*` 与 `component/liquid/*` 的头部注释注明
> `Adapted from Kyant0/AndroidLiquidGlass`, Apache 2.0）；照抄请保留版权头。
