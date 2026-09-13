# 柔光玻璃（flutter_miuix 路线）代码审核

- **审核时间**：2026-09-13 21:35–22:00
- **审核基线**：`HEAD` = `f9ba002b`（"修复(玻璃·性能): 捕获子树含玻璃会自激重绘"）
  - 审核时工作区已有**两处并发重构正在进行**（玻璃采样分区、内置壁纸），
    因此所有结论以 HEAD 版本为准；工作区新增内容单独在 §4 讨论。
- **上游基线**：`flutter_miuix 1.2.0`（`D:\Cache\Pub\hosted\pub.dev\flutter_miuix-1.2.0`）
- **审阅范围**：`lib/ui/hyperos/soft_glass/*`、`lib/models/soft_glass_tuning.dart`、
  `lib/ui/hyperos/hyperos_glass_backdrop_host.dart`、`lib/ui/hyperos/os4_glass_backdrop.dart`、
  以及全部 `SoftGlassSurface` / `softGlassPopupVisualsFor` 接入点。

---

## 0. 结论摘要

方向是对的：把柔光玻璃的渲染实现整体删掉、改渲染上游 `MiuixGlass`，
并让「用户档位 → 上游材质」的映射单点维护（`softGlassMaterialFor`），
这比原来"每个表面各写一套观感"健康得多。

但**当前这版只完成了"接口替换"，没有完成"语义对齐"**，留下了三类问题：

| 级别 | 问题 | 一句话 |
|---|---|---|
| **P0** | 捕获子树包含玻璃自身 | 违反上游明确契约，玻璃在采样自己的上一帧影像；`f9ba002b` 的跳帧补丁只是止血，根因未解 |
| **P0** | `tint` 是死参数，且替身口径已与真实玻璃脱节 | 6 个入参里 4 个在生产代码中零消费者；静态替身算的是旧链路底色 |
| **P1** | 抽象与常量大面积腐化 | "全 app 唯一配方"实际只剩一个数字有用；注释仍在讲已删除的三套配方 |
| **P1** | `enableRefraction` 名实不符 + 死开关 | 它控制的是上游 `shading`（材质 token 族），不是折射 |
| **P1** | 默认档并不等于"菜单原样"，测试却声称是 | 描边被 ×0.95，测试只验了 radius 和首层 alpha |
| **P1** | `tintAlphaMultiplier` 对首层几乎无效 | 档位差异弱于预期，"清透/浓雾看不出区别"的候选成因 |
| **P2** | 采样源注册表无 stale 兜底、scope 不建立依赖 | 热重载 / 异常路径会踩；scope 晚于玻璃出现时不自愈 |

另有一个**与柔光玻璃无关但当下阻塞一切**的事实：工作区编译不过（§5）。

---

## 1. P0-1：捕获子树包含玻璃自身（反馈采样）

### 上游契约（明确禁止）

`flutter_miuix-1.2.0/lib/src/theme/miuix/components/miuix_glass.dart:54`

> 对应 Kotlin Modifier.glass。**必须放在 backdrop 捕获子树之外，防止反馈采样。**

`lib/src/theme/miuix/blur/miuix_backdrop.dart:32`

> 用 `MiuixLayerBackdropCapture` **包裹背景容器**来录制其渲染输出，再把本对象传给模糊组件。

上游官方形态是「捕获节点包住背景，玻璃与它**并列**」：

```dart
MiuixLayerBackdropCapture(backdrop: backdrop, child: MyBackground())
```

项目自己在 `lib/ui/hyperos/os4_glass_backdrop.dart:13-14` 把这条抄了一遍：

> 1. 捕获子树**不能包含玻璃自身** —— 所以不能做"应用级捕获"，只能"哪个宿主页
>    用玻璃，就用它自己的捕获包住页面内容"，且**弹层必须留在捕获之外**。

### 实现是反的

`lib/ui/hyperos/hyperos_glass_backdrop_host.dart:147-160`（HEAD）

```dart
return HyperosGlassBackdropScope(
  controller: _controller,
  child: HyperosLayerBackdropCapture(   // ← 捕获整页
    controller: _controller,
    child: widget.child,                // ← 里面就有顶栏带 / 玻璃坞 / 卡片 / 标签栏
  ),
);
```

而挂载点是**整页**：

- `lib/ui/hyperos/hyperos_page.dart:694` → `HyperosGlassBackdropHost(child: _buildPage(context))`
- `lib/screens/timetable_screen.dart:8324` → `HyperosGlassBackdropHost(controller: _homeGlass, child: content)`

页内玻璃随后从这个包里取出 controller：

`lib/ui/hyperos/soft_glass/soft_glass_surface.dart:375-385`（HEAD）

```dart
final next = widget.blurEnabled
    ? HyperosGlassBackdropRegistry.resolve(context)
    : null;
...
next?.acquire();
```

`Registry.resolve`（host:69-70）= `HyperosGlassBackdropScope.maybeOf(context)?.controller ?? active`
→ 页内玻璃拿到的**正是包住它自己的那个 controller**。

**结论：Capture 是玻璃的祖先，玻璃既是采样者又是被采内容。**

### 后果

1. 快照里含玻璃**上一帧**的渲染结果 → 玻璃采样自己 → 边缘拖影 / 发灰，滚动与转场时最明显。
2. `f9ba002b` 加的 `_notifiedSinceCapture`（host:295、paint:297-305）只是把
   "录帧 → 通知 → 重绘 → 又录帧"的**无限循环**截断成两帧一次，
   它没有、也不可能把玻璃从快照里去掉。
   注释里写的"代价：连续滚动时最多两帧的采样延迟"是真的，
   但注释没写的是：**那两帧的快照本身就是脏的**。

反证：`os4_glass_backdrop.dart:15-17` 说弹层"常驻挂载 + 切 show"、
`OverlayPortal` 画到 Overlay 上，所以"在捕获之外**是天然成立的**"——
这句话恰好说明作者知道"玻璃要在捕获之外"这条规则，
但只把它用在了弹层上，页内玻璃没有对应处理。

### 为什么菜单看起来正常

`HomeTopMenuPopup` / `HyperosSelectPopup` 的面板经 `OverlayPortal` 画到 Overlay，
不在这棵捕获子树里 → 它们采到的是"被压在下面的页面"，**不含自己** ✓ 正确。
所以问题只暴露在**页内玻璃**：顶栏带、玻璃坞、标签栏、页内卡片、圆钮。

### 修复建议

真正满足契约只有一条路：**捕获只覆盖"玻璃之下"的内容**。

- 最小验证：在首页把结构改成 `Stack([ Capture(child: 背景层), 前景玻璃 ])`，
  先只让顶栏带按这个形态走，看拖影是否消失。
- 通用化：玻璃不能简单地"自己带一块背景"（它背后就是整页），
  所以要么**页面分层**（背景层 / 玻璃层），要么改成上游 Compose 的思路
  —— 让"可被采样的背景"成为一个独立的 GraphicsLayer，玻璃在另一个。
- ⚠️ 注意：并发进行中的「按 zone 分块捕获」**没有解决这一条**（见 §4）。

---

## 2. P0-2：`tint` 是死参数，替身口径已与真实玻璃脱节

### 2.1 `SoftGlassSurface` 的 6 个入参在生产代码里只剩 2 个有效

对全部 9 个 `SoftGlassSurface(` 调用点统计入参：

| 入参 | 生产调用点是否使用 |
|---|---|
| `child` / `borderRadius` / `blurEnabled` / `enableShadows` | ✅ 在用 |
| `polarity` | ✅ 仅 2 处（`soft_glass_tab_bar.dart:459`、`timetable_screen.dart:7107`） |
| `tint` | ❌ 0 处 |
| `materialAlpha` | ❌ 0 处 |
| `blurSigma` | ❌ 0 处 |
| `recipe` | ❌ 0 处（全部走默认 `SoftGlassRecipe.standard`） |
| `enableRefraction` | ❌ 0 处 |
| `enableEdgeHighlight` | ❌ 0 处（全部走默认 true） |

（`home_page_region_blur.dart:333/337` 的 `blurSigma` / `tint` 是传给
`FrostedHeaderBackground` 的，不是 `SoftGlassSurface`。）

### 2.2 `tint` 在默认路径下**根本不参与渲染**

`soft_glass_surface.dart:406`（HEAD）：`shading: widget.enableRefraction`，默认 `false`。

上游 `miuix_glass.dart`：

- `tint` 只在 `glassUniforms()`（约 394-400 行 `in_tint`）里被读，
  而 `glassUniforms` **只**在 `if (cfg.shading)` 分支里调用（579-592 行）；
- 另一个用到 `tint` 的地方是 rim 分支（625 行），条件同样是 `cfg.shading && ...`；
- `shading == false` 时走 `canvas.drawImageRect(image, ...)`（593-605 行），
  `tint` 一次都没被读。

所以：**传 `tint` 给默认配置的 `SoftGlassSurface` 是完全无效的**。
`fill` 参数同理——`fill` 只在"没有 backdrop / shader 未就绪"的兜底分支
（606-611 行）用作实底色，与玻璃观感无关。

当前真正生效的只有两条：

- `material.blurRadius` ← `recipe.blurRadiusDp × tuning.blurRadiusMultiplier`
- `material.{first,second,third}.alpha` ← `tuning.tintAlphaMultiplier`
- 以及 `stroke` ← `tuning.edgeHighlight`

### 2.3 后果：静态替身与真实玻璃两套口径

`lib/widgets/home_page_region_blur.dart:275-301`

```dart
static Color standInWashColor(BuildContext context) {
  ...
  if (material == 'soft' && useBlur) {
    // 底色倍率 = 配方倍率 × 用户调参（与 SoftGlassSurface 的 fill 同口径）。
    return SoftGlassTokens.tint(
      context,
      blurEnabled: useBlur,
      tintAlphaMultiplier:
          SoftGlassRecipe.standard.tintAlphaMultiplier *
          appearance.softGlassTuning.tintAlphaMultiplier,
    );
  }
```

注释写着"与 `SoftGlassSurface` 的 `fill` 同口径"，但：

- 真实玻璃**没有**走 `fill`（同文件 324 行的 `SoftGlassSurface` 一个 `tint:` 都没传）；
- 真实玻璃的底色来自上游 blend shader 的三层混色
  （`miuix_glass_material.dart:55-69`：`0x05000000` plusDarker /
  `0x99FFFFFF` softLight / `0x66FFFFFF` hardLight），
  而 `SoftGlassTokens.tint()` 算的是"灰 252、alpha 0.675"。

两者是完全不同的成像方式，**不可能对上**。
`standInWashColor` 是给转场 / 降级时的静态替身用的，它现在算出来的颜色
与真实玻璃不一致 → 转场时会有可见的底色跳变。

### 修复建议

- 要么把 `tint` / `materialAlpha` / `blurSigma` / `recipe` / `enableRefraction`
  **从 `SoftGlassSurface` 删掉**（连同 §3 的死常量一起），让接口只剩真实生效项；
- 要么明确保留并让替身与真实玻璃共用同一个"上游材质 → 等效底色"的函数
  （可以按 `material.layers` 在 `fill` 色上做一次等效混合）。
  推荐前者：删掉比"维护一条没人走的路"便宜。

---

## 3. P1：抽象 / 常量 / 注释腐化

### 3.1 `SoftGlassTokens` 里大部分常量已无消费者

`soft_glass_surface.dart:12-199`（HEAD，共 188 行）中，**没有任何生产消费者的**：

| 常量 | 位置 | 说明 |
|---|---|---|
| `radiusToSigmaScale` / `radiusToSigmaBias` | 54-55 | 只服务已死的 `blurSigma` 反算 |
| `defaultBlurSigma` | 73 | 同上 |
| `postRefractionBlurDp` | 81 | 注释自己写了"已无消费者，只作为历史数值留档" |
| `edgeHighlightAlpha` / `edgeDarkHighlightMultiplier` / `edgeHighlightGray` / `edgeWidth` / `edgeGradientStops` / `edgeGradientAlphas` | 88-101 | 旧自绘描边参数；上游描边走 `MiuixGlassStrokes` |
| `navigationTintAlpha` / `navigationTintAlphaMultiplier` / `tintLightGray` / `tintDarkGray` / `tintAlpha` / `tintAlphaNoBlur` | 107-133 | 只在 `tint()` 里用，而 `tint()` 只被替身调用（§2.3） |
| `shadows()` | 175-189 | 上游走 `MiuixGlassShadows.floating` |
| `edgeAlphaOf()` / `edgeAlpha()` | 192-198 | 无消费者 |

真正有用的只有：底栏几何（16-24）、动效（29-33）、
`baseBlurRadius`（44）、`maximumBlurRadius`（47）、`indicatorFill`（168）、
以及 `_dark()`（139）。

`SoftGlassRecipe`（223-267）同样：
- 只有 `standard` 一个实例；
- `cornerRadiusDp` 恒 `null`（无调用方传，`_radius` 的 `recipeRadius` 分支是死分支）；
- `blurSigma` / `blurSigmaWithMultiplier` 无消费者；
- `tintAlphaMultiplier` 只被 §2.3 那个替身用。

**"全 app 唯一配方"这个抽象，实际只剩下一个数字 `baseBlurRadius = 60`。**

### 3.2 注释仍在描述已删除的实现

- `SoftGlassRecipe` 类注释（201-222 行）在讲
  "上游对浮空导航/底部面板/对话框用三套不同配方：底栏 radius 23dp，
  对话框与底部面板 92dp / 184dp，圆角 40dp / 36dp" ——
  这段在 `606d40ca` 之后已经不成立（基线已统一为 `popupViewGlass` 的 60）。
  它甚至还在提示"⚠️ 不要被上游 `GlassBlurSpec` 的字面值骗了"，
  而代码路径早已不再读 `GlassBlurSpec`。
- `os4_glass_backdrop.dart:8-17` 的契约说明与实现相反（§1）。
- `hyperos_list_popup.dart:442-446`：

  > 柔光玻璃面的底色由 app 主题明暗决定（见 `SoftGlassTokens.tint`，
  > 亮色 252@67.5% / 暗色 31@67.5%）

  实际底色由上游 blend 三层色决定，与这条描述无关。

  这一处的**结论**（柔光面不该用壁纸感知墨色）仍是对的，
  但**依据**是错的，读代码的人会被带到旧链路上。

### 3.3 `SoftGlassSurface` 的类注释同样是过期的

`soft_glass_surface.dart:272-289`：

> 保留原入参契约，内部换成上游玻璃

"保留契约"在接口层面成立，但契约里**大半参数已经没有语义**（§2）。
这类注释比没有注释更危险——它会让人以为参数是通的。

### 建议

按"要么真、要么删"处理：删掉死常量与死入参，把
`SoftGlassRecipe` 收敛成一个 `baseBlurRadius` 常量 + 档位倍率；
注释重写成描述**当前实现**（上游 `MiuixGlass` + `popupViewGlass`）。

---

## 4. P1：`enableRefraction` 名实不符

`soft_glass_surface.dart:321-324 / 406`：

```dart
/// true = 上游「仿生折射」档（bionic GlassToken）；false（默认）= OS4 栏 / 菜单的
/// MaterialToken
final bool enableRefraction;
...
shading: widget.enableRefraction,
```

它实际控制的是上游 `MiuixGlass.shading`，语义是"用 MaterialToken 还是 bionic GlassToken"
——**不是**折射开关。上游 `miuix_glass.dart:57` 也是这么写的。

副作用：一旦有人传 `true`，§2.2 里那些"死"的 tint / rim 路径会**同时复活**，
观感在开关两侧不连续，且没有任何 UI 暴露 → 现在的状态是"一个必然踩坑的死开关"。

**建议**：改名为 `shading`（对齐上游）并显式标注"仅调试用"，
或者直接删掉、把 `shading` 钉死为 `false`（这正是 `606d40ca` 的本意：
"想试折射档可显式传 `enableRefraction: true`" 这句话没有对应的使用者）。

---

## 5. P1：默认档并不等于"菜单原样"，测试给了假安全感

`606d40ca` 的提交信息与多处注释都称"标准档 = 菜单原样"。实际：

`lib/models/soft_glass_tuning.dart:126` → `defaultEdgeHighlight = 0.95`

`soft_glass_surface.dart:407-412` → 描边走
`scaleSoftGlassStroke(MiuixGlassStrokes.forTheme(isDark), tuning.edgeHighlight)`，
而 `scaleSoftGlassStroke`（459-472）把 `color` + `primary` + `secondary`
**三处高光的 alpha 全部 × 0.95**。

菜单侧（`popup_presenter.dart:511`）是 `MiuixGlassStrokes.forTheme(dark)` **原样**。

→ 默认档的描边比菜单暗 5%，`edgeHighlight = 1.0` 才真正等于菜单。

而 `test/ui/hyperos/soft_glass_tuning_test.dart:57-71` 的用例名叫
"默认档位 = 上游弹层材质原样（与首页菜单 / 选择弹层同款）"，
断言却只有两条：

```dart
expect(material.blurRadius, MiuixGlassMaterials.popupViewGlassLight.blurRadius);
expect(material.first.color.a, closeTo(...puredThinGlassLight.first.color.a, 1e-6));
```

`material` 与 `stroke` 都没验 → 这条测试**无法**发现上面的偏差，
但它给出的信号是"已经和菜单一模一样了"。

**建议**：
- 把 `defaultEdgeHighlight` 改成 `1.0`（真正的原样），或
- 把"标准档 = 菜单原样"改成"标准档 = 菜单材质 + 描边 ×0.95"并同步注释；
- 测试补 `stroke` 断言（与 `MiuixGlassStrokes.forTheme` 逐字段等值）。

---

## 6. P1：`tintAlphaMultiplier` 对首层几乎无效

上游 `popupViewGlassLight` 三层（`miuix_glass_material.dart:55-69`）：

| 层 | 颜色 | α | 模式 |
|---|---|---|---|
| first | `0x05000000` | 0.020 | plusDarker |
| second | `0x99FFFFFF` | 0.600 | softLight |
| third | `0x66FFFFFF` | 0.400 | hardLight |

`softGlassMaterialFor`（soft_glass_surface.dart:441-455）的 `scale()` 只做
`layer.color.a × tintScale` 线性缩放：

- 首层 0.020 → 0.55 档下是 0.011，**视觉上不可辨**；
- 档位差异**全部**落在 second / third 上。

再叠加 §5 的描边 ×0.95、以及档位本身只动这两层，
"清透 / 浓雾"的实际观感差可能明显弱于用户预期
（用户在 `12249795` 的真机反馈正是"选最透明和最浓，看着差不多"——
那次修的是"弹层没接档位"，但接上之后**幅度**是否够，还没有验证）。

另外 `plusDarker` 是"变暗"合成，用 α 线性缩放来近似"通透度"，
语义本身也不精确。

**建议**：真机上用「清透 / 标准 / 浓雾」各截一张同场景图做像素对比，
确认档位可见性；若不够，改为直接给 `presetClear/standard/dense` 各自
**独立的颜色层配方**（而不是倍率缩放），或提高滑杆上限的作用范围。

---

## 7. P2：采样源的生命周期与解析

### 7.1 注册表无 stale 兜底

`hyperos_glass_backdrop_host.dart:51-71`（HEAD）

```dart
static final List<HyperosGlassBackdropController> _screens = ...;
static void register(...) { _screens.remove(c); _screens.add(c); }
static void unregister(...) { _screens.remove(c); }
static HyperosGlassBackdropController? get active =>
    _screens.isEmpty ? null : _screens.last;
```

`_screens` 是全局可变 static，只靠 `dispose()`（host:139-145）清理。
一旦 `dispose` 因异常 / 热重载 / 页面被非常规移除而没跑到，
栈里就留下一个**已 `dispose()`（`backdrop` 已释放）**的 controller，
而 `active` 会把它交给下一个打开弹层的页面 → 用已释放的 backdrop 采样。

`resolve()` 也没有校验 controller 是否还活着（没有 `disposed` 标记 / `hasListeners` 检查）。

**建议**：给 controller 加 `bool get disposed`，`active` 取栈顶时跳过已释放项；
`register/unregister` 用 `try/finally` 或在 `attach/detach` 上也挂钩。

### 7.2 `HyperosGlassBackdropScope` 不建立依赖 + 玻璃只在两处重绑

- `maybeOf` 用 `getInheritedWidgetOfExactType`（host:185-186，**不建立依赖**）；
- 玻璃的绑定只在 `didChangeDependencies`（surface:354-357）
  与 `blurEnabled` 变化时（surface:360-365）发生；
- `didUpdateWidget` **不比较 controller**。

如果一个玻璃首次构建时 scope 还没出现（Overlay / 异步插入的子树场景），
它会绑到 `Registry.active`（此时可能是**别的页面**），
此后没有任何机制把它改回来，直到某次无关的依赖变化。

**建议**：`didUpdateWidget` 增加"解析结果是否变化"的判断，
或在 `build` 里比对一次 `identical(resolved, _controller)`（`resolve` 是纯查表，很便宜）。

### 7.3 弹层 `visuals` 缺少 `alpha`，与页内口径不齐

`softGlassPopupVisualsFor`（surface:476-495）只给 `material` + `stroke`，
`MiuixGlassPopupVisuals.alpha` 保持默认 `1`；
而页内 `SoftGlassSurface` 会把 `materialAlpha` 传给上游 `alpha`
（surface:403 → `MiuixGlass.alpha`，参与 blend 与 stroke/shadow/mask 的透明度）。

目前生产调用点没人传 `materialAlpha`（§2.1），所以**暂时无害**，
但两套入口的默认口径不一致，一旦有人给页内传 `materialAlpha`，
弹层与页内就会不同步。

---

## 8. 关于并发进行中的「按 zone 分块捕获」

审阅时工作区已有未提交改动（`hyperos_glass_backdrop_host.dart` 336 → 591 行），
方向是**把整屏快照改为按玻璃所在窄带分块录制**：

```dart
/// 整屏快照在 2.75x 的 1280×2772 上是 ~100MB 级离屏目标，每帧一次就烧掉一个核
/// （真机实测 106~129% CPU、Mali 驱动线程满载）
```

**这个性能判断是对的**，`f9ba002b` 只治了"自激"，没治"整屏离屏目标"。

但要提醒两点：

1. **它没有解决 §1（反馈采样）**。新的 `_capture()` 仍然是
   `offsetLayer.toImageSync(target)`，而 `offsetLayer` 是**捕获节点自己的图层**，
   捕获节点仍是玻璃的祖先 → 裁出来的窄带里**照样有玻璃上一次的渲染结果**。
   zone 只改变了"录多大"，没改变"录的是谁"。
2. HEAD 版本的 `_RenderHyperosLayerBackdropCapture` 里
   `_notifiedSinceCapture` 跳帧逻辑在新结构下**语义变了**：
   现在一次 `_capture()` 会给每个 zone 各发一次通知，
   仍是"一帧录、下一帧跳"，这个取舍在新结构下需要重新核对（尤其是
   `wrote` 为 false 时不置位、连续多帧不录的分支）。

另外，该改动在审阅期间处于**不可编译**状态（`acquireRect` / `releaseRect` /
`captureBoundsIn` / `wantsPlainBackdrop` / `plainBackdrop` / `backdrop` getter
尚未在 controller 上定义）。这属于在制品，不作结论，仅记录。

---

## 9. 建议的修复顺序

1. **先补齐并发改动使其可编译**（§8 尾），否则一切验证都跑不起来。
2. **确认 §1 是否在真机可感知**：只让首页顶栏带按
   `Stack([Capture(child: 背景层), 玻璃])` 走一遍，对比拖影。
   这决定是否要动架构 —— 也是最值得先做的一件事。
3. **清理 §2 / §3**：删死入参 + 死常量 + 改注释，
   把替身口径与真实玻璃对齐（或直接删掉替身路径）。
4. **对齐 §5**：`defaultEdgeHighlight` → 1.0（或改口径），测试补 stroke 断言。
5. **真机验证 §6**：档位可见性截图对比。
6. **补 §7 的兜底**：controller 存活检查、`didUpdateWidget` 重解析。

---

## 10. 核对无误的部分（供对照，避免误伤）

以下是审阅中**确认正确**的实现，不要一起改：

- `MiuixLayerBackdrop.updateSnapshot`（上游 `miuix_backdrop.dart:79-89`）
  在替换快照时会 `dispose()` 旧图 —— **没有 native 内存泄漏**。
- `softGlassMaterialFor` 作为"档位 → 上游材质"的**单点维护**设计是合理的，
  页内表面与两处 OS4 弹层共用它，`12249795` 修的正是这个方向。
- `softGlassPopupVisualsFor` 在非柔光档 / 降级时返回**空 visuals**
  （= 上游默认），不误伤实体 / 高斯 / 液态档 ✓。
- `HyperosGlassBackdropHost._syncRegistration` 的"最外层 + TickerMode 为真"
  两条门槛（host:126-136）判据正确：限定了只有真正在跑的那一屏占栈顶，
  与注释里"菜单变透明"的真机现象因果一致 ✓。
- `MiuixTheme` 的明暗判据：项目侧由 `MiuixFontWeightScope`
  （`lib/widgets/miuix_font_weight_scope.dart:113-158`）注入，
  且 `baseTheme = existing ?? MiuixThemeData.of(Theme.of(context).brightness)`
  —— 跟随 Material brightness。因此上游菜单的
  `colors.background.computeLuminance() < .5` 与项目侧
  `Theme.of(context).brightness` **实际同结论**，
  不存在"暗色下菜单变白"的问题。
  唯一例外是被显式 `MiuixTheme` 包住的子树（如 `miuix_showcase`）。
- 启动预热已接上：`lib/main.dart:375` → `MiuixGlassRendering.load()` ✓。
- `test/ui/hyperos/soft_glass_tuning_test.dart` 对
  倍率映射 / 显式覆盖优先 / clamp / 模糊关闭不接采样源 的守卫是有效的，
  只是覆盖面停在"材质参数"这一层（见 §5）。

---

## 附：本次审核的验证方式

- 静态分析：`dart analyze lib test`（工具链 `D:\Flutter\flutter`，与 `.fvmrc` 一致）
- 交叉核对上游源码：`flutter_miuix 1.2.0`
  （`miuix_glass.dart` / `miuix_glass_material.dart` / `miuix_backdrop.dart` /
  `miuix_layer_backdrop.dart` / `popup_presenter.dart` / `miuix_glass_styles.dart`）
- 全量调用点枚举：`grep -rn "SoftGlassSurface\|softGlassMaterialFor\|softGlassPopupVisualsFor\|scaleSoftGlassStroke" lib/`
- 入参使用统计：对 9 个 `SoftGlassSurface(` 调用点逐个核对实参
- 未做：真机渲染验证（§1、§6 的观感结论需真机确认，已在文中标注）

---

# 修复记录（2026-09-13 22:10）

本轮已落地的改动（`dart analyze lib test` 0 issue；定向测试 561 passed / 0 failed）。

## 已修

| 原编号 | 问题 | 改法 | 涉及文件 |
|---|---|---|---|
| §5 | 默认描边 ≠ 菜单原样（0.95） | `defaultEdgeHighlight` 0.95 → **1.0**（= 不缩放上游描边）；`presetDense` 去掉冗余的 `edgeHighlight: 1`；补测试断言「标准档描边三处高光 = 上游 `MiuixGlassStrokes.forTheme` 原样」 | `lib/models/soft_glass_tuning.dart`、`test/models/soft_glass_tuning_test.dart`、`test/ui/hyperos/soft_glass_tuning_test.dart` |
| §2 | `tint` 是死参数，兜底实底走了上游纯白 | 删掉 `SoftGlassSurface.tint`；`fill` 改为 `SoftGlassTokens.tint(context, blurEnabled:…, polarity:…)` —— 让 §3.1 里那批"死常量"真正服务于**无 backdrop 时的实底**；补测试「模糊关闭时 fill = tint() 且 alpha = tintAlphaNoBlur」 | `lib/ui/hyperos/soft_glass/soft_glass_surface.dart`、测试 |
| §2.3 | 静态替身口径与真实玻璃脱节 | `standInWashColor` 改为与 `fill` **同源**（都走 `SoftGlassTokens.tint`，配方倍率 0.90 移入函数内部），注释改成"近似等效底色"的准确说法 | `lib/widgets/home_page_region_blur.dart`、`soft_glass_surface.dart` |
| §2.1 | `blurSigma` 入参 0 调用点、语义是旧链路 sigma 反算 | 删掉 `SoftGlassSurface.blurSigma` 与 `softGlassMaterialFor(blurSigma:)`；连带删 `radiusToSigmaScale` / `radiusToSigmaBias` / `defaultBlurSigma` | `soft_glass_surface.dart` |
| §4 | `enableRefraction` 名实不符 + 死开关 | 删掉该入参，`shading` 钉死 `false` 并注明理由（柔光玻璃的承诺就是"与菜单同一份材质"） | `soft_glass_surface.dart` |
| §3.1 | 死常量 | 删 `postRefractionBlurDp`、`edgeHighlightAlpha`、`edgeDarkHighlightMultiplier`、`edgeHighlightGray`、`edgeWidth`、`edgeGradientStops`、`edgeGradientAlphas`、`tintAlpha`、`shadows()`、`edgeAlphaOf()`、`edgeAlpha()`；`SoftGlassRecipe` 收缩为只剩 `blurRadiusDp`（删恒 null 的 `cornerRadiusDp`、`tintAlphaMultiplier`、`blurSigma`、`blurSigmaWithMultiplier`） | `soft_glass_surface.dart`、`home_page_region_blur.dart` |
| §3.2 | 注释腐化 | 重写 `SoftGlassRecipe` 类注释（不再讲已删除的三套配方）；`SoftGlassTokens` 分节注释改成当前口径；`SoftGlassSurface` 类注释补「采样源怎么来的」+「已知偏差」；`os4_glass_backdrop.dart` 改成准确描述（含"这个全局兜底没有任何捕获者 = 等于实底"）；`hyperos_page.dart` 宿主注释更新 | 多个 |
| §7.1 | 注册表无 stale 兜底 | `HyperosGlassBackdropController` 加 `disposed` 标志；`Registry.active` 改为从栈顶向下找第一个存活项并顺手清僵尸；`register` 拒绝已释放的控制器 | `hyperos_glass_backdrop_host.dart` |
| §7.2 | scope 不建立依赖 → 采样源不自愈 | `SoftGlassSurface.didUpdateWidget` 改为**每次父级重建都重解析**（不再只盯 `blurEnabled`）；`_bindController` 额外把已释放的 controller 视作 null | `soft_glass_surface.dart` |
| §7.3 | 弹层 `visuals` 缺 `alpha` | 不改行为（当前无人传 `materialAlpha`），改为在 `materialAlpha` 上写明"要用就得两边一起加" | `soft_glass_surface.dart` |
| §6 | 档位可见性无实测 | `SoftGlassTuning` 类头补一张「三层颜色层 α / 模式」表 + 明确"首层 α=0.02，档位差异全在二三层" | `lib/models/soft_glass_tuning.dart` |

## 未修（需要决策）

| 原编号 | 问题 | 为什么没修 | 建议 |
|---|---|---|---|
| **§1** | **捕获子树包含玻璃自身（反馈采样）** | 架构级：修它必须让"玻璃在捕获子树之外"，也就是页面分层（背景层被捕获 / 玻璃层在其外）或把页内玻璃也画到 Overlay。涉及 `hyperos_page.dart`、`timetable_screen.dart` 的树形重组，且这两个文件同期正被壁纸重构改动。 | 先做**最小验证**：只让首页顶栏带按 `Stack([Capture(child: 背景层), 玻璃])` 走，对比"滚动时玻璃是否变白 / 边缘拖影"。确认收益后再决定是否全量分层。**注意 `fb1c72fc` 的 zone 分块没有解决这一条**（它只改了"录多大"，没改"录的是谁"）。 |

## 新增/更新的验证

- `dart analyze lib test` → `No issues found!`
- `flutter test test/models test/ui/hyperos` + 6 个玻璃坞 / 外观相关文件 → **561 passed / 0 failed**
- 新增断言：`SoftGlassRecipe.standard.blurRadiusDp == SoftGlassTokens.baseBlurRadius`（配方与 token 同源）
- 新增断言：默认档**描边**三处高光 = 上游原样（补上原先只验 radius / 颜色层的盲区）
- 新增断言：模糊关闭时 `fill == SoftGlassTokens.tint(...)` 且 `alpha == tintAlphaNoBlur`
