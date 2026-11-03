# Compose 宽屏适配设计方案（交 Lead 排期）

日期：2026-11-03。撰写：页面一致性审计会话。本文只做方案，不动代码。

读者：Lead 与后续接手的批次负责人。读完可以按「迁移顺序」直接拆批次。

## 背景

全仓 `AdaptiveTopAppBar` 与 `NavigationRail` 使用数为 0。两处证据：

- `components/QingyuPageScaffold.kt:108` 的注释写着「壳层该用而未用」。
- `grep -r "NavigationRail" android/app/src/composeP1` 无命中。

手机竖屏下这不构成问题。平板、折叠屏展开态、桌面窗口这三类场景窗口宽度可达
600～1200 dp 以上，现在的界面是一根拉长的单列列表加一条 380 dp 居中的底部坞
（`GlassDockNavigationBar.kt:197` 的 `maxWidthDp = 380`），观感和操作密度都差。

另一个前置事实：`AndroidManifest.xml:166` 把 `PagesShellActivity` 锁了
`screenOrientation="portrait"`。手机上永远窄窗。所以本方案的第一批前提是
「解锁横屏 / 支持平板」，这件事需要产品先拍板，本文按「会解锁」来设计。

## 官方 demo 的做法（出处）

| 机制 | demo 实现 | 出处（`docs/reference/miuix-demo/example/shared/src/commonMain/kotlin/`） |
| --- | --- | --- |
| 双栏断点 | `widthDp >= 840.dp || (widthDp >= 600.dp && 高宽比 < 1.2)` | `utils/AdaptiveUtils.kt:12-21`（`shouldShowSplitPane`） |
| Rail 展开断点 | `widthDp >= 1200.dp` | `utils/AdaptiveUtils.kt:24-40` |
| Rail 位置 | `Row { if (isWideScreen) PersistentNavigationRail(...); Box(weight(1f)) { NavHost } }`，挂在 NavHost **左侧** | `AppContent.kt:251-269` |
| Rail 折叠态 | `rememberNavigationRailState`，跨过 1200 dp 时 `expand()/collapse()` | `AppContent.kt:350-363` |
| 顶栏自适应 | 宽屏用 `SmallTopAppBar(defaultWindowInsetsPadding = false)`，窄屏用 `TopAppBar` | `utils/PageUtils.kt:78-113`（`AdaptiveTopAppBar`） |
| 内容内边距 | `pageContentPadding(...)`：宽屏时底部补 `navigationBars + captionBar` | `utils/PageUtils.kt:50-75` |
| 双栏页内布局 | `WideScreenContent`：Scaffold 里按 `isWideScreen` 分支，pager 内容加 `imePadding` | `AppContent.kt:408-463` |

三条设计取向值得照抄：

1. **断点是窗口宽度，不是设备型号**。折叠屏展开、桌面分屏、平板横竖屏都自然工作。
2. **NavDisplay 保持单一组合位置**。宽窄切换只改外壳，不重建路由
   （`AppContent.kt:249-250` 注释原话：否则切分支会重建当前 route）。
3. **宽屏不限制内容宽度**。demo 列表在宽屏上仍然通栏，只把导航挪到左侧 rail。

## 断点方案（三档）

沿用 demo 数值，不发明新刻度：

| 档位 | 窗口宽 | 布局 |
| --- | --- | --- |
| 紧凑 | < 600 dp | 现状：单列 + 底部玻璃坞（`GlassDockNavigationBar`） |
| 中宽 | ≥ 600 dp 且不满足宽屏条件 | 单列，列表内容限宽居中（建议上限 640 dp），底部坞保持 |
| 宽屏 | ≥ 840 dp（或 ≥ 600 dp 且横扁，高宽比 < 1.2） | 左侧 `NavigationRail`，底部坞隐藏，顶栏切 `SmallTopAppBar` |
| 超宽 | ≥ 1200 dp | Rail 展开态（显示文字标签）；列表页可考虑双栏（本方案不展开，见「不做什么」） |

判据直接照抄 `shouldShowSplitPane` / `shouldExpandNavigationRail`，落一个
`components/QingyuAdaptive.kt`（Lead 专属目录），全仓唯一事实源。

## 接入点

### 1. 壳层：Rail 换掉底部坞

落点在 `PagesShellActivity.kt` 的 `PagesShell` 组合（约 `:640` 的 `NavDisplay` 外层）。
结构照抄 `AppContent.kt:251-269`：

```kotlin
Row {
    if (isWideScreen) {
        NavigationRail(state = railState, items = dockItems, /* … */)
    }
    Box(Modifier.weight(1f).fillMaxHeight().then(if (isWideScreen) Modifier.clipToBounds() else Modifier)) {
        NavDisplay(/* … */)   // 组合位置不动
    }
}
```

关键约束：

- `NavDisplay` 必须留在同一个组合位置。宽窄切换只增删外壳，否则当前页面路由被重建，
  返回栈与转场状态全丢。
- Rail 的条目直接复用底部坞的 `GlassDockItem` 清单，选中逻辑同源。
  「超级岛点击跳哪一页」的既有语义不改。
- 底部坞在宽屏档不组合（不是 `alpha = 0f` 藏起来），省一层图层。

### 2. 页面骨架：`QingyuPageScaffold` 加宽屏分支

`QingyuPageScaffold` 已经有 `maxContentWidth` 参数（默认 null，`QingyuPageScaffold.kt:113`），
这是中宽档「限宽居中」的现成钩子。要补的是宽屏档的顶栏切换，把 demo 的
`AdaptiveTopAppBar` 分支搬进 `QingyuBlurredTopBar` 的内容槽：

- 宽屏：`SmallTopAppBar(defaultWindowInsetsPadding = false, color = barColor, …)`，
  毛玻璃照常（模糊面在 `QingyuBlurredTopBar`，与顶栏变体无关）。
- 紧凑：现状 `TopAppBar`（可折叠大标题）。

页面侧零改动：`isWide` 由 scaffold 内部读 `QingyuLocalIsWideScreen`（壳层
`CompositionLocalProvider` 注入，同 `AppContent.kt:154` 的 `LocalIsWideScreen`）。
约 70 个子页自动继承。

中宽档的 `maxContentWidth` 是否默认打开（640 dp）由 Lead 拍板。注意 `QingyuPageScaffold.kt:114`
的注释：官方大标题左对齐不受限宽约束，默认打开会让大标题与内容列错开——
如果打开，宽屏分支换 `SmallTopAppBar` 后这个矛盾自然消失，两件事建议同一批做。

### 3. 列表内边距：`QingyuPageList` 不动

demo 的 `pageContentPadding` 在宽屏补 `navigationBars + captionBar`，那是因为它的
Rail 是 Scaffold 外的常驻条，页面要自己兜底部。我们的 Rail 只在宽屏出现且底部坞同时
消失，`QingyuPageList` 现有 `innerPadding` 算法已覆盖。唯一要验证的是横屏下
`captionBar`（任务栏高度）在桌面上是否被 `innerPadding` 吃到——验收时真机看一眼列表
最后一行不被遮即可。

### 4. 表单 / 弹层：已有基础

`imePadding` 已在表单页铺开（2026-11-03 批次补齐 8 处）。宽屏横扁窗口下键盘高度占比
更大，`imePadding` 的行为不变，无需额外处理。

## 迁移顺序

四批，每批可独立交付、独立验收：

| 批 | 内容 | 触碰目录 | 验收 |
| --- | --- | --- | --- |
| 1 | `components/QingyuAdaptive.kt`：断点判据 + `QingyuLocalIsWideScreen`；`PagesShellActivity` 横屏解锁与 `resizeableActivity` 评估 | `components/`、壳 Activity、清单 | 平板/折叠屏窗口宽下 `isWide` 值正确；手机竖屏行为零变化 |
| 2 | 壳层 Rail：宽屏显示 `NavigationRail`、隐藏底部坞；`NavDisplay` 组合位置不动 | 壳 | 宽屏切 tab、返回栈、转场正常；窄屏回归无差异 |
| 3 | `QingyuPageScaffold` 宽屏顶栏：`SmallTopAppBar` 分支 + `maxContentWidth` 默认值决策 | `components/` | 毛玻璃在两种顶栏下都工作；大标题页在宽屏收成小标题；样式守卫 L2 绿 |
| 4 | 中宽档限宽居中（可选）；首页课表网格的宽屏列数（需课程域批次配合） | `components/`、`pages/timetable/`（另行认领） | 真机/平板逐页对照 |

## 风险

1. **横屏解锁的连带面**：清单解锁后，所有假设竖屏的硬编码（如按屏高比例限高的弹层
   `screenHeightDp * 0.5`）在横扁窗口下表现要复查。`ImportPreviewDialog` 这类限高弹层
   是重点。
2. **毛玻璃 backdrop 与 Rail 共存**：顶栏采样链路（`rememberQingyuBlurBackdrop` →
   `layerBackdrop`）挂在页面内容容器上，Rail 在页面外面，理论上互不影响。
   但 `GlassDockNavigationBar` 的采样源如果被壳层复用给 Rail，要按 demo
   `AppContent.kt:527-559` 重接，不能直接共用一个 backdrop。
3. **返回手势**：宽屏双栏时 Android 预测性返回的边缘在屏幕左侧，Rail 会吃掉手势带。
   demo 用 `clipToBounds()` 隔离转场层，手势区域要真机验证。
4. **配置变更重建**：解锁 orientation 后旋转会走 `configChanges` 自理路径，壳层
   `remember` 的状态（选中的 tab、backdrop）要确认能跨宽度档存活；`LocalWindowInfo`
   驱动的断点天然响应，不需要手动处理。
5. **守卫面**：`ComposePageStyleGuardTest` 是源码文本守卫，不感知宽屏分支；
   `shell/` 域本就豁免 R1。新增的 `QingyuAdaptive.kt` 在 `components/`，不在扫描范围。

## 不做什么（本方案边界）

- 不做平板三栏（`shouldShowThreePanes`，demo 也没有实际使用它）。
- 不做页面级双栏（demo 的 `WideScreenContent` 双栏是 pager 主页专属；我们的子页
  全部保持单列限宽）。
- 不动首页课表网格的列数逻辑（归课程域批次）。
- 不改底部坞在紧凑档的任何表现。

## 给 Lead 的两个决策点

1. 是否解锁横屏 / 平板。解锁前本方案只有第 3 批（限宽）可先行，其余无意义。
2. 中宽档 `maxContentWidth` 默认值（建议 640 dp，与第 3 批同批落地）。
