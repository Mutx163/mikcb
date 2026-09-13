# 组件迁移质量审核（2026-09-13）

- **审核时间**：2026-09-13 21:52–22:20
- **审核基线**：`HEAD` = `fb1c72fc`（"优化(玻璃·性能): 捕获按「玻璃背后那条窄带」分块裁剪"）
- **上游基线**：`flutter_miuix 1.2.0`（pub.dev）
- **审核范围**：当天 50 次提交中的**组件迁移主线**，共 4 条
- **已有姊妹文档**：`docs/soft-glass-miuix-review-2026-09-13.md`（柔光玻璃专项，21:35 写）。
  本报告聚焦**迁移全貌**，§C 的 P0 与该文档 §1 是**独立复核**，结论一致。
- **验证方式**：`flutter analyze lib test`、7 个迁移相关测试文件实跑、
  全量调用点枚举（`grep -rn`）、上游源码交叉核对
- **未做**：真机渲染验证；全量测试（仅跑迁移相关文件）

---

## 0. 迁移清单与范围界定

| # | 迁移 | 提交 | 规模 |
|---|---|---|---|
| 1 | 依赖：fork `1.0.11` → 上游 pub.dev `flutter_miuix 1.2.0` | `df03d72b` | 4 文件 / +55 −28 |
| 2 | 首页右上角「更多」**列表形态** → 上游 OS4 玻璃弹层 | `69eeca34`、`1e5be056`、`8e404692` | 3 文件 / +290 −49 |
| 3 | **选择弹框** → 上游 OS4 锚定下拉弹层 | `35d09179` →回退`75c70261` →重做`76b79552` →`5058bf80` →`f9e57282` →`0765a1e0` | 累计 6 轮 |
| 4 | **柔光玻璃表面** → 上游 `MiuixGlass`，删自研折射链路 | `368da48b`(1/3)、`1801fa7b`(2/3)、`606d40ca`(3/3) | 8 文件 / +57 −526 |

---

## 1. 硬指标（可验证）

| 检查项 | 结果 | 评价 |
|---|---|---|
| `flutter analyze lib test` | **0 error / 0 warning / 1 info** | ✅ 优于记忆中 18 条 info 的基线 |
| 迁移相关测试（7 文件 / 67 用例） | **全部通过**，33s | ✅ 含 1 条 hit-test 警告（非失败） |
| 自研折射链路清理 | `shaders/` 空、`pubspec` 无 `shaders` 声明、lib/test **零引用** | ✅ 清理彻底，无半删残留 |
| 依赖切上游 | `pubspec: ^1.2.0` + `lock` 指向 `pub.dev`，无 fork 覆盖 | ✅ |
| 删除的自研文件 | `soft_glass_refraction.dart`(155行)、`soft_glass_refraction.frag`(205行) 已删 | ✅ |

唯一 1 条 info：`lib/models/soft_glass_tuning.dart:106:20 - avoid_redundant_argument_values`，
属迁移时留下的冗余实参，一条即可清掉。

**总评：方向正确、落地扎实。** 但留下 4 类问题，按严重度排列如下。

---

## 2. 【A】死代码与「测试护空」——成本最低、最该先清

### 事实

`lib/widgets/home_top_menu.dart:75` 的 `showHomeTopMenuSheet()`（旧「更多」列表形态入口，
约 40 行 + 依赖 `showHyperosListPopup` 的整条组装逻辑）在 **`lib/` 内已零调用者**——
首页列表形态在 `69eeca34` 迁到 `HomeTopMenuPopup` 后，这条入口就没人走了。

枚举结果：

```
$ grep -rn "showHomeTopMenuSheet" lib/ test/
lib/widgets/home_top_menu.dart:75        ← 仅定义处
test/ui/hyperos/hyperos_list_popup_submenu_test.dart:438
test/widgets/home_top_menu_test.dart:28,81,127,183,421
```

而 `test/widgets/home_top_menu_test.dart`（451 行）的 **9 个用例里有 5 个**在调它：
第 15 / 68 / 105 / 158 / 399 行；`hyperos_list_popup_submenu_test.dart` 另有 2 个
（"home top menu add-course submenu wiring"）。

### 危害

这些用例**全绿**，但它们测的是一段没有任何生产路径的代码。后果比"多几个测试"严重：

- 给出**"首页菜单有测试覆盖"的假信号**——真形态（`HomeTopMenuPopup` +
  `MiuixGlassTransformPopup`）反而只在 `hyperos_glass_backdrop_host_test.dart:161`、
  `soft_glass_tuning_test.dart:186` 被**间接**摸到；
- 旧入口一旦有人误用，测试照样绿（因为它本身就测旧路径），**保护方向是反的**。

### 建议

二选一，不要维持现状：

1. **删**（推荐）：删 `showHomeTopMenuSheet` + 7 个对应用例；`showHyperosListPopup`
   本体仍有生产使用者（`course_import_screen`、`time_scheme_management_screen`），**保留**。
2. **留**：加 `@Deprecated`，并在文件头注明"仅历史兼容，生产已走 `HomeTopMenuPopup`"，
   同时把对应用例标注为"覆盖已弃用路径"。

---

## 3. 【B】提交信息与实现存在落差（3 处）

这类问题不导致 bug，但会**误导后续维护者**，且当天有多处注释也复述了同样的错误口径。

### B-1 `5058bf80`「HyperosSelectTile **全面**改用 OS4 玻璃弹层」

实现是**有条件分流**，不是全面。`lib/ui/hyperos/hyperos_select.dart:1093-1100`：

```dart
HyperosGlassBackdropScope? _os4ScopeFor(BuildContext context) {
  if (widget.useSheetForPopup ||                 // ① 显式要求底部 sheet
      widget.items.length > widget.sheetItemThreshold ||  // ② 选项多于阈值（默认 6）
      widget.itemTitleStyleBuilder != null) {    // ③ 逐项自定义字号（字体预览）
    return null;                                 // → 退回旧弹层
  }
  return HyperosGlassBackdropScope.maybeOf(context);  // ④ 所在页无页级宿主也退回
}
```

实测覆盖率：53 个 `HyperosSelectTile<...>` 调用点中，`useSheetForPopup: true` **6 个**、
`itemTitleStyleBuilder` **1 个**、另有若干超阈值项 → **约 85% 走 OS4**。

**可见后果**：同一个控件在 app 内存在**两种弹层观感**（OS4 玻璃 vs 旧弹层）。
分流本身设计合理（上游 `MiuixGlassPopupItem` 确实不支持覆盖文字样式），
但提交信息与类文档若宣称"全面"，会让人以为旧路径已无人走、进而误删兼容分支。

### B-2 `69eeca34`「**去掉**逐帧整页捕获」

实现是**减少**，不是去掉。`lib/ui/hyperos/hyperos_glass_backdrop_host.dart:503-511`：

```dart
if (_controller.wantsPlainBackdrop) {
  final image = offsetLayer.toImageSync(mine, pixelRatio: dpr);  // ← mine = 整屏
  _controller.plainBackdrop.updateSnapshot(image, localToGlobal(Offset.zero), dpr);
}
```

`fb1c72fc` 的分块裁剪只作用于**页内 zone**；菜单 / 弹层（面板在 Overlay 里、
拿不到"自己背后那块"）仍走 **整屏** `toImageSync`。
真实改善是"**只在弹层打开期间录**，而非旧实现的每帧录"，
叠加 `_notifiedSinceCapture` 的两帧一次，量级差异很大 —— 但"去掉"是过强的表述。

### B-3 `606d40ca`「柔光玻璃材质**对齐首页菜单同款**」

默认档 ≠ 菜单原样。`lib/models/soft_glass_tuning.dart:126` 的
`defaultEdgeHighlight = 0.95`，经 `scaleSoftGlassStroke` 把描边的
`color / primary / secondary` 三处 alpha **全部 ×0.95**；
而菜单侧（`popup_presenter.dart:511`）是 `MiuixGlassStrokes.forTheme(dark)` **原样**。

配套测试 `test/ui/hyperos/soft_glass_tuning_test.dart:57-71` 用例名叫
"默认档位 = 上游弹层材质原样（与首页菜单 / 选择弹层同款）"，
**断言却只验了 `blurRadius` 与首层 alpha**，`stroke` 完全没验 → 无法发现上述偏差。
（此条与姊妹文档 §5 一致，我复核属实。）

---

## 4. 【C】P0 架构缺陷：捕获子树包含玻璃自身（反馈采样）

### 契约（项目自己写的）

`lib/ui/hyperos/os4_glass_backdrop.dart:13-14`：

> 捕获子树**不能包含玻璃自身** —— 所以不能做"应用级捕获"……

### 实现是反的

`lib/ui/hyperos/hyperos_glass_backdrop_host.dart:307-317`：

```dart
return HyperosGlassBackdropScope(
  controller: _controller,
  child: HyperosLayerBackdropCapture(   // ← 捕获整页
    controller: _controller,
    child: widget.child,                // ← 顶栏带 / 玻璃坞 / 标签栏 / 页内卡片都在里面
  ),
);
```

页内玻璃经 `HyperosGlassBackdropReporter` 包在 `SoftGlassSurface` 外侧，
`_register()` → `controller.acquireZone(this, backdrop)`，拿到的是
**包住它自己的那个 controller** 的 zone 图。
而 zone 图来自 `offsetLayer.toImageSync(...)`，`offsetLayer` 正是捕获节点自己的图层
（`hyperos_glass_backdrop_host.dart:479`）→ **玻璃采到自己本帧的渲染结果**。

### 为什么看起来还正常

| 对象 | 是否在捕获子树内 | 结果 |
|---|---|---|
| 首页菜单 / 选择弹层 | ❌ 在 Overlay（`timetable_screen.dart:8317-8337` Stack 第二子项） | 采样正确 ✓ |
| 页内玻璃（顶栏带 / 玻璃坞 / 标签栏 / 卡片） | ✅ 在捕获子树内 | 反馈采样 ✗ |

**弹层被正确地放在 Host 之外**，说明规则是被理解的 —— 只是没有同步应用到页内玻璃。

`f9ba002b` 加的 `_notifiedSinceCapture`（host:453-463）把"录帧 → 通知 → 重绘 → 又录帧"
的自激循环从每帧截断成两帧一次，**是有效的止血**，但它**不可能**把玻璃从快照里去掉；
注释里"代价：连续滚动时最多两帧的采样延迟"是真的，未写明的是
**那两帧的快照本身就是脏的**。

**影响**：页内玻璃边缘拖影 / 发灰，滚动与转场时最明显。

**修复方向**：捕获只覆盖"玻璃之下"的内容 ——
`Stack([Capture(child: 背景层), 前景玻璃])` 形态，先只让首页顶栏带走一遍验证是否可感知，
再决定是否做页面分层。注意：`fb1c72fc` 的分块裁剪**没有**解决这一条（它只改"录多大"）。

> **已可执行地证实（2026-09-13 22:12）。** `test/ui/hyperos/hyperos_glass_backdrop_host_test.dart`
> 新增用例「捕获子树不含玻璃自身（上游契约，防反馈采样）」，断言
> `find.descendant(of: HyperosLayerBackdropCapture, matching: HyperosGlassBackdropReporter)`
> 为 `findsNothing`。**临时去掉 `skip` 后实测失败**：
>
> ```
> Expected: no matching candidates
>   Actual: _DescendantWidgetFinder:<Found 1 widget with type "HyperosGlassBackdropReporter">
> ```
>
> 于是"页内玻璃落在捕获子树内"不再是读代码得出的推断，而是可复现的断言。
> 用例现以 `skip`（挂在 `group` 上以携带理由）留在套件里，**修好分层后去掉 `skip`
> 即成为守卫**。之所以用 `skip` 而不是"断言当前错误行为"，是因为后者会变成我在 §2
> 批评的那种「给出假信号的测试」—— 这里宁可让它显式地"待修"。

> **最小修复路径（未执行，需先真机确认可感知）**
> 1. 页面分层：把"玻璃之下的内容"与"玻璃层"拆成两棵子树，
>    `Stack([Capture(child: 背景层), 玻璃层])`，玻璃层移到捕获之外。
> 2. ⚠️ 玻璃层一旦离开 `HyperosGlassBackdropScope`，`resolve()` 会走
>    `Registry.active` 兜底（`hyperos_glass_backdrop_host.dart:227-228`）；
>    需确认宿主注册（`didChangeDependencies`）早于玻璃构建，否则玻璃会绑到**别的屏**。
> 3. 页内卡片（region glass）若仍留在背景层里，反馈依旧存在 ——
>    分层要按"这块玻璃背后是什么"逐层拆，不是一刀切。
> 4. 验证顺序：先只让首页顶栏带走第 1 步，真机对比拖影；确认可感知再推广。
> 5. **未执行的理由**：`timetable_screen.dart` 是 8000+ 行且刚被并发改动（移除内置壁纸），
>    在拿到真机反馈前重构其渲染层次，风险大于收益。

---

## 5. 【D】生命周期与边界（P2，修起来都不贵）

### D-1 注册表无 stale 兜底

`hyperos_glass_backdrop_host.dart:209-228`：

```dart
static HyperosGlassBackdropController? get active =>
    _screens.isEmpty ? null : _screens.last;
```

`_screens` 是全局可变 static，只靠 `dispose()`（host:297-303）清理。
一旦 `dispose` 因异常 / 热重载 / 非常规移除没跑到，栈里就留下一个
**已 dispose（`plainBackdrop` 已释放）**的 controller，而 `resolve()` 不校验存活，
会把它交给下一个打开弹层的页面 → 用已释放的 backdrop 采样。

**建议**：controller 加 `bool get disposed`，`active` 取栈顶时跳过已释放项。

### D-2 `_maxZones = 4` 溢出时并入「最后创建的那块」

`hyperos_glass_backdrop_host.dart:130-135`：

```dart
if (_zones.length >= _maxZones) {
  target = _zones.last;   // ← 不保证是空间上最近的一块
}
```

`_zones.last` 是"最后**创建**的"，不是"最近的"。第 5 块玻璃会被硬塞进一块
可能离它很远的 zone → 该 zone 的并集矩形膨胀（极端情况退化回大区域捕获），
反而抵消了分块的意义。

**建议**：溢出时按 union 距离选最近的块；或加一条 debug 断言 / 日志，
让"真的发生了溢出"可见（目前是静默降级）。

> **已修复（`d0355e86`）。** 补测试时发现这条比报告写的更严重：我原以为是"边角情况"，
> 实测确认 `acquireZone` 发生在 **attach 阶段、那时还没布局**，
> `_globalRectOf` 恒为 `null` —— 所以"按矩形就近选块"在**首次挂载时根本量不到依据**，
> `_zones.last` 兜底是**常态路径**。新增用例在改前实测该块采样矩形高 **2332**
> （整屏 2600），确实是整屏级。
> 修法：满员且有矩形时按「并集膨胀最小」选块；量不到矩形时先临时并入最后一块
> 保证它有采样源，记入 `_deferredMerge`，在**首次录帧前**调用
> `resolveDeferredMerges()` 改判（那时已布局，量得到远近）。
> 改判需先把自己从原块排除，否则原地增量恒为 0、永远选回原块。

### D-3 scope 不建立依赖 + 玻璃只在两处重绑

- `HyperosGlassBackdropScope.maybeOf` 用 `getInheritedWidgetOfExactType`（**不建立依赖**）；
- 玻璃绑定只在 `didChangeDependencies` 与 `blurEnabled` 变化时发生；
- `didUpdateWidget` **不比较 controller**。

若玻璃首次构建时 scope 尚未出现（Overlay / 异步插入子树），它会绑到
`Registry.active`（此时可能是**别的页面**），此后无机制自愈。
（与姊妹文档 §7.2 一致，我复核属实。）

---

## 6. 做得好的地方（避免误伤，勿一并改动）

这些是当天迁移中**质量明显偏高**的部分，值得保留：

1. **回退/重做的决策记录是范本**：`75c70261` 明确写"接入方式错了，导致无法选择"并回退，
   `76b79552` 按上游契约（常驻挂载 + 切 `show`）重做，`hyperos_select.dart:693-708`
   把"为什么**不能**塞进 `showGeneralDialog`（内部关闭记账与路由栈错位）"写清楚了。
   敢回退 + 写清原因，比硬撑强得多。
2. **滚动手势隔离一次治两个真 bug**：`0765a1e0` 的 `HyperosGlassPopupScrollGuard`
   同时断掉"继承页面橡皮筋（没超高也能拖）"与"通知冒泡驱动宿主页大标题收起"，
   两条因果都写进注释，并配了专项测试 `os4_glass_popup_scroll_guard_test.dart`。
3. **宽度回归用对了工具**：`f9e57282` 针对上游 `mainAxisSize.max` 撑满 `maxWidth` 的问题，
   用 `IntrinsicWidth` 夹到"最宽一条的自然宽度"，并补齐测试断言。
4. **`HyperosZoneBackdrop` 不复用 `MiuixLayerBackdrop`**（host:48-76）——
   理由是上层 `updateSnapshot` 会在替换时释放旧图，多消费者共享会被释放两次；
   改由 zone 统一持有与释放、玻璃只做转发。**对上游生命周期的理解到位。**
5. **预热策略**：按下 `acquire` / 抬手未展开即 `release`（`hyperos_select.dart:1114-1129`、
   `timetable_screen.dart:8342-8354`），既保证弹层首帧有玻璃，又避免页面空转录帧。
6. **上游交叉引用详尽**：注释里给到上游文件、行号、Apache-2.0 许可、契约原文，
   可维护性远高于平均水平。
7. **测试增量与实现同步**：`hyperos_select_test.dart`(+88/+43)、
   `os4_glass_popup_scroll_guard_test.dart`(+85) 都是**随迁移一起**落的，不是事后补。

---

## 7. 建议修复顺序

| 序 | 事项 | 成本 | 收益 |
|---|---|---|---|
| 1 | 清 §2 死代码与 7 个空测试用例 | 低 | 消除假信号，测试量还降了 |
| 2 | 真机验证 §4 是否可感知（先只让顶栏带走 `Stack([Capture(背景层), 玻璃])`） | 低 | **决定是否要动架构**，最值得先做 |
| 3 | §5-D1 加 `disposed` 兜底 | 极低 | 防用已释放 backdrop 采样 |
| 4 | §3 三处表述对齐（改注释或改实现，`defaultEdgeHighlight` 改 `1.0` 或改口径） | 低 | 消除误导 |
| 5 | §5-D2 溢出选块策略 + §5-D3 重解析 | 中 | 边界健壮性 |
| 6 | 清 `soft_glass_tuning.dart:106` 那条 info | 极低 | analyze 归零 |

---

## 8. 执行记录（审核后同日落地的改动）

| 项 | 状态 | 落地内容 |
|---|---|---|
| §2 A 死代码 | ✅ 已做 | 删 `showHomeTopMenuSheet`；5 个空用例删除；**2 个 wiring 用例改为移植到现役实现**（见下） |
| §5-D1 stale 兜底 | ✅ 并发 Agent 同时在做 | `disposed` 标记 + 注册表跳过僵尸条目 |
| §3 B-3 描边口径 | ✅ 并发 Agent 同时在做 | `defaultEdgeHighlight` 0.95 → 1 |
| §1 那条 info | ✅ 并发 Agent 同时在做 | 移除冗余实参 |
| §4 C 反馈采样 | ⚠️ 证据已落地，修复待定 | 契约断言已可执行（`skip` 用例，去掉 `skip` 即失败）；修法需真机确认后再动架构 |
| §5-D2 zone 溢出 | ✅ 已做（`d0355e86`） | 满员按「并集膨胀最小」选块 + 首次录帧改判；实测原为常态路径而非边角 |

**A 项的执行比原建议更进了一步。** 原建议是"删 7 个用例"，但核查发现
`HomeTopMenuPopup` 的二级面板（`MiuixGlassSecondaryPopup`）在 `test/` 里
**零引用** —— 那 2 个 wiring 用例其实是「『添加』行 → 二级面板 → 回传子项 id」
这条行为的**唯一**覆盖，只是恰好测在已删除的实现上。
所以对它们不是删除而是**移植**：改写为驱动现役 `HomeTopMenuPopup`
（`show: true` 常驻挂载 + `MiuixGlassPopupAnchor`），断言原样保留。
移植后实跑通过，这条行为重新获得保护 —— 若当初照原建议直接删，就会净损失一块覆盖。

（另 5 个用例测的是"行渲染 / 可点 / 自定义排列 / 液态衬底 / 实体面墨色回退"，
新形态已由 grid 组 4 个用例 + `hyperos_glass_backdrop_host_test.dart` 覆盖，故删除。）

---

## 附：本次审核的验证命令

```bash
# 静态分析
env -u http_proxy -u https_proxy "PROGRAMFILES(X86)=C:\Program Files (x86)" \
  D:/Flutter/flutter/bin/flutter.bat analyze lib test

# 迁移相关测试（7 文件 / 67 用例）
flutter.bat test --timeout 180s \
  test/ui/hyperos/hyperos_select_test.dart \
  test/ui/hyperos/os4_glass_popup_scroll_guard_test.dart \
  test/ui/hyperos/hyperos_glass_backdrop_host_test.dart \
  test/ui/hyperos/soft_glass_tuning_test.dart \
  test/ui/hyperos/soft_glass_constraint_test.dart \
  test/widgets/home_top_menu_test.dart \
  test/ui/hyperos/hyperos_list_popup_submenu_test.dart

# 死代码 / 残留枚举
grep -rn "showHomeTopMenuSheet" lib/ test/
grep -rn "soft_glass_refraction\|SoftGlassBackdrop" lib/ test/ pubspec.yaml
grep -rn "HyperosSelectTile<" lib/ | wc -l
grep -rn "useSheetForPopup: true" lib/screens/ | wc -l
```
