# 柔光玻璃代码审核 —— 交给高级模型的审查角度清单

- 生成时间：2026-09-13 22:05
- 前置材料：`docs/soft-glass-miuix-review-2026-09-13.md`（我做完的审核 + 已落地修复）
- 已落地修复的 commit：`1bd613e`（"修复(柔光玻璃): 标准档描边对齐菜单 + 兜底实底接回 tint + 清理死参数"）
- 代码基线：`fb1c72fc`（zone 分块捕获）+ `1bd613e`
- 上游基线：`flutter_miuix 1.2.0`（`D:\Cache\Pub\hosted\pub.dev\flutter_miuix-1.2.0`）

> **2026-09-18 更新（本文其余部分仍是 09-13 的快照）：** `liquid_glass_widgets` 已从依赖中
> 整体移除，原第三方液态玻璃实现被本仓自研的折射着色器材质取代（`LiquidGlassSurface` +
> `shaders/glass_surface_refraction.frag`，见
> `.agents/notes/implemented/architecture/2026-09-18-liquid-glass-surface.md`）。
> 因此 §G1「两条玻璃路线是否该收敛」**已不再是「自研 vs 第三方」的重复投资**：液态这一档
> 现在和柔光一样都是本仓自研材质，共用同一套降级判据与调参出口；文中出现的
> `HyperosLiquidGlassSurface` / `liquid_glass_widgets` 字样一律读作历史名称。

## 怎么用这份东西

下面 §1 是可直接粘贴给高级模型的角色与产出要求；§2 起是审查角度，每条都带
**切入点**（文件 / 符号 / 行号）和**判定标准**，高级模型可以逐条独立作答。
§4 是我**自己结论里需要被复核**的部分——请明确要求它去证伪，而不是复述。

**我这一轮已经修了什么、别让它改回去**，见文末 §5。

---

## 1. 给高级模型的角色与产出要求（可粘贴）

> 你是 Flutter 渲染与 GPU 性能方向的资深工程师。项目是「轻屿课表」
> （`C:\cursor\mikcb`，Flutter 3.44.8 / Dart 3.12.2，Android + HyperOS），
> 玻璃材质走上游包 `flutter_miuix 1.2.0` 的 OS4 玻璃（`MiuixGlass`）。
> 入口文件：`lib/ui/hyperos/soft_glass/soft_glass_surface.dart`
> （材质映射 + 表面组件）、`lib/ui/hyperos/hyperos_glass_backdrop_host.dart`
> （屏级采样源 + zone 分块捕获）。
>
> 请按下文每条角度独立作答，输出格式固定为：
>
> ```
> [编号] 结论：成立 / 不成立 / 不确定
>        证据：<文件:行号，或实验步骤与结果>
>        影响：<会不会被用户看到；严重度>
>        建议：<改哪几个文件、改动量级（行数/风险）>
> ```
>
> 硬性要求：
> 1. **不确定就写"不确定"**，并给出"怎么才能确定"的具体实验。
>    禁止凭直觉写真机结论——你没有真机。
> 2. 每条结论必须能落到**具体代码位置或可执行实验**，不接受"建议加强测试"这类空话。
> 3. 需要跑命令时用：`D:\Flutter\flutter\bin\dart.bat analyze`、
>    `D:\Flutter\flutter\bin\flutter.bat test`（跑 `flutter test` 前需补齐
>    `ProgramFiles` / `ProgramFiles(x86)` / `ProgramW6432` / `SystemRoot`，
>    并清空 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY`，否则会误报加载失败）。
> 4. 上游源码在 `D:\Cache\Pub\hosted\pub.dev\flutter_miuix-1.2.0`，
>    可以也应该直接读它来核对契约。
> 5. 不要改动代码，只做审查与验证实验；需要写一次性测试来验证结论时，写到
>    `tmp/` 或明确标注为实验文件。

---

## 2. 审查角度

### A. 采样与捕获（最高优先级——这里是问题最密集的地方）

**A1. 捕获子树包含玻璃自身（我已定位，未修，需要方案而非确认）**

- 现象：`HyperosGlassBackdropHost` 把 `HyperosLayerBackdropCapture` 包在
  **整页**外面（`hyperos_glass_backdrop_host.dart` 的 `build`，
  `child: HyperosLayerBackdropCapture(controller: _controller, child: widget.child)`），
  而页内玻璃就在那棵子树里 → 玻璃采到的窄带含**自己上一帧**的合成结果。
- 上游契约：`miuix_glass.dart` 类注释「必须放在 backdrop 捕获子树之外，防止反馈采样」；
  `miuix_backdrop.dart` 的 `MiuixLayerBackdropCapture` 官方示例是
  `Capture(child: MyBackground())`，即**捕获背景、玻璃与它并列**。
- **要高级模型给的东西**：
  1. 一个**最小可行**的分层方案（只覆盖首页顶栏带），要写出具体树形代码骨架；
  2. 该方案对 `hyperos_page.dart:694` / `timetable_screen.dart:8320` 两个宿主挂载点的侵入程度；
  3. 是否有第三条路（例如把页内玻璃改用 `OverlayPortal` 画到 Overlay，
     像上游弹层那样"天然在捕获之外"）——评估其代价（定位、命中测试、动画）。
- ⚠️ 提醒它：`fb1c72fc` 的 zone 分块**没有解决这一条**（只改"录多大"，
  没改"录的是谁"），别把它当成已修。

**A2. 快照余量（`sampleMargin=96`）可能小于上游采样窗口（我的新怀疑，未验证）**

- 数据推演：
  - zone 快照 = 「成员并集 + `sampleMargin`」→
    `hyperos_glass_backdrop_host.dart:99`（`sampleMargin = 96`）、`:189`（`inflate(sampleMargin)`）。
  - 上游取纹理时用的 padding 是
    `padding = math.max(blurRadius * 1.5, 24.0)`（`miuix_glass.dart` 的 `paint`），
    裁出的源区域是 `size + 2 * padding`。
  - 于是需要的余量 ≈ `padding`。代入档位：
    | 档位 | radius | padding = radius×1.5 | 需要余量 | sampleMargin=96 |
    |---|---|---|---|---|
    | 清透 0.6 | 36 | 54 | 54 | ✅ |
    | 标准 1.0 | 60 | 90 | 90 | ✅（勉强） |
    | 浓雾 1.6 | 96 | 144 | 144 | ❌ |
    | 滑杆上限 2.7 | 162 | 243 | 243 | ❌❌ |
- **要它验证**：大半径档下玻璃边缘是否**渗透明/发暗**（快照不够大 → `drawImageRect`
  的目标区域超出源图 → 取到透明）。给出可写成测试的判据
  （例如断言 `zone.captureRectOf(zone).size >= 玻璃 size + 2 * padding`）。
- 若成立，给两种修法并比较：把 `sampleMargin` 提升到「档位上限对应 padding」
  （= 243，会放大离屏目标、吃掉性能红利）；或让 `sampleMargin` 随当前档位动态计算。

**A3. zone 归并逻辑可能实际不生效（我的新怀疑，未验证）**

- 证据链：
  - `acquireZone` 的归并分支被 `if (rect != null)` 门住
    （`hyperos_glass_backdrop_host.dart:117-128`）；
  - `_globalRectOf` 在 `!box.attached || !box.hasSize` 时返回 null（`:171-174`）；
  - 唯一调用 `acquireZone` 的路径是 `_RenderHyperosGlassBackdropReporter._register()`
    （`:596-601`），而 `_register()` 只在 `attach()`（`:610-614`）与 setter 变化时调用；
  - **`attach` 发生在 mount 期，此时尚未 layout** → `hasSize == false` → rect 恒为 null
    → 归并分支永不执行 → 每块玻璃都新建一个 zone（封顶 4），
    第 5 块起被塞进 `_zones.last`（`:129-136`）。
- 后果推断：注释声称的"按矩形就近归并成最多 4 块"实际是"每块玻璃一块、封顶 4"；
  一旦页面玻璃数 > 4，`_zones.last` 的并集会横跨多块玻璃 → 该 zone 的捕获矩形
  退化成大范围（性能红利消失）。
- **要它验证**：首页（`timetable_screen.dart`）到底有几块 `SoftGlassSurface`／
  `HyperosGlassBackdropReporter`；超过 4 块时 `zones` 的实际矩形面积。
  并判断作者注释里"先登记成员，位置在录帧时按成员现算"是否意味着
  **归并本来就被有意放弃**（若是，则应删掉死分支与注释，而不是留着误导）。

**A4. `_maxZones = 4` / `_joinGap = 2 * sampleMargin` 两个魔数的依据**

- `:102`、`:105`。要它回答：4 是怎么定的？192px 的"算同一块"阈值与玻璃实际间距分布
  是否匹配（顶栏带与玻璃坞的间距有多大）？有没有实测支撑。

**A5. `_notifiedSinceCapture` 跳帧逻辑在 zone 结构下的语义**

- `hyperos_glass_backdrop_host.dart` 的 `paint` / `_capture`。
- 旧结构下：一次 `_capture()` = 一张图 = 一次通知 → 跳过下一帧。
- 新结构下：一次 `_capture()` 会遍历所有 zone，**每块都 `zone.update` + 对成员
  `zoneUpdated()`（notifyListeners）**，且 `wrote` 为真时才置位 `_notifiedSinceCapture`。
- 要它回答：多 zone 时"一帧录、下一帧跳"的取舍是否仍成立？连续滚动时是否会出现
  "某些 zone 更新、某些滞后"的撕裂（同一屏内几块玻璃采到不同时刻的画面）。

**A6. 弹层整层采样（`plainBackdrop`）与 zone 并存的录帧成本**

- `:86-96`、`_capture()` 里 `if (_controller.wantsPlainBackdrop)` 分支。
- 弹层打开时**同时**录「每块窄带」+「一张整层图」。要它评估：此时成本是否回到了
  `fb1c72fc` 想解决的那个量级；是否应该在弹层打开时**只**录整层（窄带暂停）。

---

### B. 材质与档位映射

**B1. 用「α 线性缩放」表达"通透度"，对三种混合模式是否语义等价（我认为不等价，未验证）**

- 事实：`popupViewGlass` 的三层是
  `0x05000000` + `plusDarker` / `0x99FFFFFF` + `softLight` / `0x66FFFFFF` + `hardLight`
  （`miuix_glass_material.dart`）；`softGlassMaterialFor` 只缩放每层的 `color.a`
  （`soft_glass_surface.dart` 的 `scale()`）。
- 我的怀疑：`plusDarker` / `softLight` / `hardLight` 都是**非线性**混合模式，
  缩放 α 与"整体通透度"之间不是单调等价关系；档位数值单调 ≠ 视觉单调。
- 要它回答：这是否会导致某些档位组合出现"非预期方向"的观感（例如"更浓"反而更亮）；
  要给出论证或反例，最好用真实混合公式算一遍。

**B2. 首层 α=0.02 → 档位的视觉差异幅度是否够**

- 数值推演：首层 α 仅 0.020，乘任何倍率都不可辨；差异全在二三层
  （0.600 / 0.400）。`presetClear` 的 `tintAlphaMultiplier = 0.55`、
  `presetDense = 1.3`。
- 要它回答：0.33 → 0.78 / 0.22 → 0.52 的 α 变化，在真实混合下能否产生
  **肉眼可辨**的"清透 ↔ 浓雾"差异？如果不够，建议怎么改
  （给 preset 各自独立的颜色层配方？调滑杆范围？）
- 关联：用户曾在 `12249795` 反馈"选最透明和最浓看着一样"（那次修的是
  "弹层没接档位"），**幅度是否够从未验证过**。

**B3. 浮点精确相等做预设反查是否可靠**

- `SoftGlassTuning.matchPreset` 用 `preset.recommendedTuning == tuning`
  （`==` 是逐字段浮点精确比较，见 `soft_glass_tuning.dart` 的 `operator ==`）。
- 要它审：滑杆拖动（连续值）、JSON 往返（`toJson`/`fromJson` 的 double 序列化）、
  跨平台浮点差异之后，用户"明明调回了预设档位"是否会被判成 `custom`
  （或反之：微调后仍被判成预设，导致设置页高亮跳变）。给出复现路径。

**B4. 四档在视觉上是否真的可分**

- `clear (0.6, 0.55, 0.8)` / `light (0.8, 0.75, 0.9)` / `standard (1, 1, 1)` /
  `dense (1.6, 1.3, 1)`（`soft_glass_tuning.dart`）。
- 注意 `dense` 与 `standard` 的 `edgeHighlight` 现在**都是 1.0**（我修完之后），
  也就是这两档在"边缘高光"这一维无差异。要它判断这是否合理，以及
  `matchPreset` 的区分度是否还够。

**B5. 复核我的一个论断：`defaultEdgeHighlight = 1.0` 才是"菜单原样"**

- 我把 0.95 改成 1.0，理由是"1.0 = 不缩放上游描边"。
- 要它核对上游弹层路径（`glass/internal/popup_presenter.dart`）里
  `stroke: v.stroke ?? MiuixGlassStrokes.forTheme(dark)` 是否就是**原样**
  （没有任何额外缩放），以及 `MiuixGlass` 内部是否还有别的描边系数
  （`in_alphaEdge` / `cfg.alpha` 等）会让"1.0 也不等于菜单"。

**B6. 上游材质是 `static final`（非 const），存在静默漂移风险**

- `MiuixGlassMaterials.popupViewGlassLight = puredThinGlassLight.copyWith(blurRadius: 60)`
  是 `static final`。
- `pubspec.yaml` 是 `flutter_miuix: ^1.2.0`（caret 范围）。
- 要它评估：上游 1.3 若改颜色层数值/模式，我们会在**没有任何测试报警**的情况下
  跟着变。是否需要加"材质快照测试"（把三层的颜色与模式写死断言）。
  这是我最建议加的一类测试。

---

### C. 性能与内存

**C1. zone 三参数（96 / 4 / 192）有没有实测依据**（同 A4）

**C2. 每帧最多 4 次 `toImageSync` 的开销量级**

- `_capture()` 对每个 zone 各调一次 `offsetLayer.toImageSync(target, pixelRatio: dpr)`。
- 要它评估：4 次窄带录制的固定开销（每次都有图层读回 + GPU→CPU 同步）
  是否可能**比 1 次整屏更慢**？什么条件下会更慢？给出判断方法与建议的录制策略。

**C3. 每个 `_RenderGlass` 各持一份 `FragmentShader`**

- 上游 `miuix_glass.dart` 的 `_RenderGlass` 有 `_shaders` map，
  `shader(key) => _shaders.putIfAbsent(key, () => program.fragmentShader())`；
  `FragmentProgram` 是 static 共享，但 `fragmentShader()` 是**每实例一份**。
- 要它回答：一块页面上 N 个玻璃 = N × 4 份 shader 实例，内存/GPU 资源占用如何？
  有没有办法共享（上游没给）？这是否是我们该提给上游的 issue？

**C4. `prepare()` 纹理缓存的 key 里含未实现 `==` 的对象（我初判"每帧必 miss"，再推演后降级为"存疑"）**

- 缓存 key 含 `(image, origin, size, ratio, blur, cfg.material, cfg.underlayMaterial, cfg.alpha)`
  （上游 `miuix_glass.dart` 的 `prepare`）。
- 疑点：`material` 是**每次 build 新建的对象**（`softGlassMaterialFor` 返回新实例），
  而 `MiuixGlassMaterial` 只有 `@immutable` 注解、**没有重写 `==` / `hashCode`**
  （`miuix_glass_material.dart:29-50` 只有构造与 `copyWith`）。
  Record 的 `==` 逐字段比较 → `material` 走 identity → key 必然不等。
- **但我重新推演后认为这条可能无害**：`prepare` 只在 `paint` 里被调用，
  而它被调用时 `backdrop.snapshot` 通常已经换过了（`image` 变 → 本就该重算）。
  真正会出问题的是"**image 未变、只因 material 是新对象就重算**"的场景。
- 要它回答：这种场景**是否真实存在**（例如同一次 capture 通知多个玻璃、
  或 `alpha` / `theme` 变化触发 rebuild 但快照没换）？若存在，代价是每帧一次
  多余的整块纹理合成（GPU）；若不存在，请明确说"此条不成立"，
  不要因为它看起来可疑就写进优化建议。
- 顺带确认：`dispose()` 后的 `ui.Image` 继续作为 key 的 identity 比较是否安全
  （应安全，但请核对 `prepare` 里 `source.snapshot!` 有无同帧读到已释放图的路径，
  即 C5）。

**C5. `zone.update` 释放旧图 vs 上游 `prepare` 仍持有该 image**

- `HyperosGlassBackdropZone.update` 会 `old.dispose()`
  （`hyperos_glass_backdrop_host.dart:34-40`），注释说"多消费者共享同一张，不能各自 dispose"。
- 上游 `_RenderGlass._textureKey` 会持有 `image` 引用作为 key。
- 要它核对：`dispose()` 后仍作为 key 比较是否安全（应当只是 identity 比较，安全）；
  但有没有路径会让 `prepare` 在**同一帧内**读到已 dispose 的 image（`snapshot!`）→ 抛异常。

**C6. `HyperosGlassBackdropReporter` 是否会引入额外 layout/paint 开销**

- 它是 `RenderProxyBox`，紧包在 `MiuixGlass` 的 child 位置。

---

### D. 与上游契约的耦合

**D1. 全量核对上游契约（我只读了下游用到的那几个类）**

- 请它把 `MiuixGlass` / `MiuixGlassPanel` / `miuixGlassSurface` helper /
  `MiuixGlassShape.smoothing` / `underlayMaterial` / `enabled` 的语义全读一遍，
  找出我们**用错或没用上**的参数。
- 特别问：`MiuixGlassShape` 的 `smoothing` 默认 1.0（超级椭圆），我们没显式传
  —— 旧自研实现是否是普通圆角？这会造成观感差异（但要先确认真机上是否可见）。

**D2. 复核"两种明暗判据实际一致"的结论**

- 我一度判断"`SoftGlassSurface` 用 `Theme.brightness`、上游菜单用
  `MiuixTheme.colors.background` 亮度 → 判据不同"，后来发现项目在
  `lib/widgets/miuix_font_weight_scope.dart:113-158` 注入了 `MiuixTheme` 且
  `baseTheme = existing ?? MiuixThemeData.of(Theme.of(context).brightness)`，
  于是**改口为"实际同结论"**。
- 要它独立复核（不要采信我的结论），特别是：被显式 `MiuixTheme` 包住的子树
  （`lib/screens/miuix_showcase/*`）、以及 `ThemeSeedScope` 覆盖色板时
  `colors.background` 是否仍与 brightness 对应。

**D3. 依赖升级路径**

- `pubspec.yaml: flutter_miuix: ^1.2.0`。caret 允许 1.x 内自动升级。
- 要它评估：上游若在 1.3 改玻璃材质/描边/shader uniform，我们有没有任何测试会报警。
  （与 B6 同源，建议合并成"把上游数值锁进测试"这一条。）

---

### E. 我完全没审的部分（空白区，优先补）

**E1. 设置页 UI 层**

- `lib/screens/advanced_material_settings_screen.dart`（柔光玻璃的滑杆 / 预设 /
  自定义入口）。我只审了模型层（`soft_glass_tuning.dart`）与渲染层，
  **UI 层一行没看**。要它审：滑杆范围与 clamp 是否一致、
  `preset` 与 `custom` 的切换是否会把用户值清掉、实时预览的成本
  （每拖一格都会重建玻璃 → 材质 + 描边 + 纹理全重算，会不会卡）。

**E2. 作用范围开关与柔光玻璃的交互**

- `lib/screens/settings/settings_appearance.dart` 里的"作用范围"选项
  （弹窗 / 全屏选择面板 / 对话框 / 玻璃坞 / 选择按钮）与
  `softGlassPopupVisualsFor` / `softSurfaceActive` 的判断是否一致。

**E3. i18n / 无障碍**

- `lib/l10n/*.arb` 里玻璃档位名称与说明的多语言一致性；
  `enableEdgeHighlight` / 档位描述是否都接进了 l10n（项目有
  `tool/cjk_hardcode_baseline.txt` 硬编码中文基线，可对照）。
- 无障碍：玻璃面在 `highContrast` / `disableAnimations` 下的降级路径
  （`LiquidGlassDegradation`）是否覆盖柔光玻璃；`SoftGlassSurface` 是否有语义标签。

**E4. 超级岛（HyperOS 主线）与柔光玻璃的交集**

- 项目主线是 HyperOS 超级岛适配，要它确认玻璃材质在超级岛相关页面上的表现路径
  是否与普通页面一致（有没有另一套走法）。

---

### F. 测试有效性

**F1. 现有测试是否只是"参数搬运"**

- 例如 `test/ui/hyperos/soft_glass_tuning_test.dart` 断言
  `glass.material!.blurRadius == 期望` —— 这类断言只能证明"我们把参数传下去了"，
  不能证明"观感对"。要它评估测试的价值密度，指出哪些是**复述实现**的伪测试。

**F2. 有没有测试锁死了实现细节、会阻碍合理重构**

- 例如断言内部常量、断言 zone 数量、断言 `shading` 值等。

**F3. 快照面积红线是否可被绕开**

- `hyperos_glass_backdrop_host_test.dart` 的"快照面积 < 整屏 40%"这类断言，
  构造条件是什么？换成真实首页布局（多块玻璃、> 4 块）是否仍成立？

**F4. 能否加"材质快照测试"**

- 把 `popupViewGlass` 三层的颜色 + blend mode + blurRadius 写死断言，
  上游升级时报警（见 B6 / D3）。

---

### G. 与项目其它玻璃路线的关系

**G1. 液态玻璃与柔光玻璃是否重复投资**

- 项目里同时有 `HyperosLiquidGlassSurface`（`liquid_glass_widgets`）和柔光玻璃
  （`flutter_miuix`）两条"玻璃"路线，各自有 tuning、降级、捕获逻辑。
  要它评估是否该收敛成一条，以及收敛的成本。

**G2. 自研 `Hyperos*` 层里的 glass 残留**

- `lib/ui/hyperos/hyperos_list_popup.dart` 里对"柔光玻璃面"的墨色判断仍引用
  `SoftGlassTokens.tint` 的旧口径（"亮色 252@67.5%"）。
- 我这一轮修了 `fill` 的接法，但**没有逐处核对**下游对 `tint()` 的语义依赖。
  要它扫一遍 `SoftGlassTokens` 的消费者，确认口径都对齐了。

**G3. 刚发生的内置壁纸删除（`bc1e20fe`）的影响**

- 内置壁纸已整体移除，首页背景只剩用户自选图片。
- 要它审：`lib/widgets/home_page_region_blur.dart` 里那些"按壁纸亮度决定墨色 /
  替身底色"的逻辑（`wallpaperTopLuminance` 等）是否还有效？
  以及"用户没设壁纸 → 纯色底"这条路径下，柔光玻璃（半透明）的观感是否需要
  重新评估（可能透出并不可控的纯色底）。

**G4. 与刚删掉的 `BuiltInWallpaper` 相关的死代码**

- `home_page_region_blur.dart` 的注释里可能还提"内置壁纸"前提。

---

## 3. 明确要求高级模型给出的三样东西

1. **A1 的最小分层方案**（可执行的代码骨架 + 侵入评估）——这是唯一一条我判断
   "必须动架构"的问题，需要它拿出具体路径。
2. **A2 / A3 两条的验证结论**——这两条是我这一轮用数值/时序推演新发现的，
   成立与否直接决定要不要改 `sampleMargin` 与 zone 归并逻辑
   （A5 的"多 zone 通知时序"是连带问题，请一并看）。
3. **一份"值得提给上游的 issue 清单"**——例如 C3（`FragmentShader` 无法在
   多个 render object 间共享）、C5（快照释放时序）。
   注意 C4 我自己已降级为"存疑"：它可能因为"image 变了本就该重算"而无害，
   请先判定它是否真的成立，再决定要不要写进 issue。

---

## 4. 请复核我自己的结论（我可能错的地方）

我上一轮报告里有些判断是**代码推演**而非实测，还有一条我**中途改过口**。
请明确要求高级模型独立复核、必要时证伪：

| # | 我的结论 | 我的置信度 | 请它做什么 |
|---|---|---|---|
| H1 | 捕获含玻璃 → 滚动时玻璃每帧多叠一层色、持续变厚变白 | 中（纯推演；我论证过"静止时会收敛、滚动时不收敛"） | 用最小实验（打印某块玻璃在滚动 1s 前后的材质输出/纹理像素）证实或证伪 |
| H2 | `MiuixTheme` 判据与 `Theme.brightness` 判据**实际同结论** | 中（我先判"不一致"，查 `miuix_font_weight_scope.dart` 后改口） | 独立复核，别采信我 |
| H3 | `tint` 在 `shading == false` 下完全不参与渲染 | 高（依据上游 `paint` 的两条互斥分支） | 核对 rim 分支与 `prepare` 有没有遗漏读取 |
| H4 | `defaultEdgeHighlight = 1.0` 才等于"菜单原样" | 中高 | 见 B5 |
| H5 | 把 `fill` 从 `widget.tint` 改成 `SoftGlassTokens.tint()` **不改变"有 backdrop 时"的行为** | 高（上游 fill 只在无 backdrop / shader 未就绪分支用） | 复核 shader 未就绪（`_ready == false`）那一帧是否会因此改变观感 |
| H6 | `os4GlassBackdrop` 没有任何捕获者 → 走到它的地方等于实底 | 中（grep 没有 `updateSnapshot` 指向它，但没有穷尽） | 穷举它的全部消费者，判断哪几处实际是"没玻璃" |

---

## 5. 已修项（别改回去）

commit `1bd613e`，详见 `docs/soft-glass-miuix-review-2026-09-13.md` 的「修复记录」一节。

- `SoftGlassTuning.defaultEdgeHighlight` = **1.0**（不要再改回 0.95）。
- `SoftGlassSurface`：**没有** `tint` / `blurSigma` / `enableRefraction` 三个入参了，
  它们是 0 消费者的旧链路残留；`shading` 在 build 里**钉死 `false`**。
- `SoftGlassSurface.fill` 走 `SoftGlassTokens.tint(...)`，**不要**改回上游默认
  （上游默认是纯白，深色壁纸上会糊一块白）。
- `SoftGlassRecipe` 只剩 `blurRadiusDp` 一个字段。
- `SoftGlassTokens` 删掉了一批零消费者常量（`postRefractionBlurDp` /
  `edgeWidth` / `edgeHighlightAlpha` / `shadows()` / `edgeAlpha()` 等）。
  若高级模型要"加回某个常量"，请要求它先证明有消费者。
- `HyperosGlassBackdropController` 有 `disposed` 标志，注册表栈顶会跳过僵尸条目。
- `SoftGlassSurface.didUpdateWidget` 现在**每次父级重建都重解析采样源**
  （不要改回"只在 blurEnabled 变化时"）。

---

## 6. 操作约束（转告高级模型）

- 禁止破坏性 git 命令（`reset --hard` / `clean -fd` / `push -f` / `checkout --`）。
- 工作区可能有其他并行 Agent 的未提交改动（l10n、壁纸、site 文档等），
  **不要提交、不要覆盖**；只看与自己任务相关的文件。
- 验证用 `dart analyze lib test` + 定向 `flutter test`（单文件带 `--timeout`）。
- 结论写文件时放 `docs/` 或 `tmp/`，不要散落在对话里。
