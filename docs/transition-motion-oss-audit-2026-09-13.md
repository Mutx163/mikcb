# 转场动画调研：我们的实现 vs 开源可替代方案

日期：2026-09-13 · 范围：`lib/ui/hyperos/`、`lib/screens/timetable_screen.dart`、`pubspec.yaml`

## 结论速览

1. **我们的路由转场不需要换开源库**。它是按 MIUI/HyperOS 系统设置的规格手写的（水平 shared-axis + 卡片圆角 + 视差 + 投影 + 系统动画缩放），pub.dev 上没有能 1:1 复刻这套语义的包（`page_transition` / `concentric_transition` / `go_transitions` / `page_route_animator` 等全是"换一套通用转场"，反而会丢掉卡片圆角、投影、速度缩放）。
2. **真正"差一口气"的是三件事，都不是"换个库"能解决的**：
   - **没有接 Android 预测性返回**（返回手势跟手 / 可取消）——SDK 3.44 已自带，我们**在 Manifest 里主动关掉了**；
   - **玻璃材质的形变转场（iOS 26 morph）没用**——`liquid_glass_widgets` 0.30.2 里就带着 `GlassMorphController` + `LiquidMorphState`（teardrop / 0.73 欠阻尼 / 375ms native profile），我们已经在依赖它，却一次都没用；
   - **一份运动参数两处维护**——`hyperos_miuix_spec.dart` 的 `HyperosMiuixAnim` 与已依赖的 `flutter_miuix` 的 `MiuixSpringDefaults` 逐值重复。
3. **我们比开源库多做的部分（别丢）**：接系统动画缩放/用户速度热更新（`AndroidAnimationScaleService`）、转场期间 `RepaintBoundary` 隔离页面像素、`OpenContainer` 的性能补丁（官方版每帧重建整页）。

## 一、我们项目实际在跑的转场（盘点）

### 1. 路由转场（子页推入/返回）— 自研，核心资产

| 项 | 规格 | 位置 |
|---|---|---|
| 类型 | 水平 shared-axis（非 Material fade-through），整屏从右滑入 | `hyperos_navigation.dart:136` |
| 入场/出场 | 新页 `Offset(1,0)→0`；旧页 `0→(-0.25,0)` 纯视差（不淡出），右侧 1.25× bleed 防露底 | `hyperos_navigation.dart:152-166` |
| 曲线/时长 | `Cubic(0.05,0,0.133333,1)`（= Android `fast_out_extra_slow_in`）/ 300ms | `hyperos_miuix_spec.dart:689+` |
| 卡片化 | 转场中裁 **40dp 圆角**（不小于屏幕物理圆角，`RoundedCorner` 实测 28dp 兜底）+ 投影（-8,12 / blur 28 / α0.20×正弦包络 `4p(1-p)`）；settle 后**完全移除**裁切与投影 | `hyperos_navigation.dart:229-308` |
| 速度缩放 | 系统动画缩放 × 用户速度 0.5–2.5×，且能对**栈上已有 route** 热更新 `controller.duration` | `hyperos_navigation.dart:355`、`android_animation_scale_service.dart` |
| 性能 | 页面本体独立 `RepaintBoundary`：转场期间只重合成"裁切+投影"，不重栅格化整页 | `hyperos_navigation.dart:169-175` |

### 2. 容器变形（Container Transform）

| 项 | 规格 | 位置 |
|---|---|---|
| 打开课表容器 | 从 `sourceRect` 出发：`scale 0.84→1` + 圆角 `22→0` + 从源中心位移到屏幕中心，420ms，`easeInOutCubicEmphasized`，**反向时长 0**（只开不关） | `timetable_screen.dart:8716` |
| 日视图锚点展开 | 360ms 自研：周网格 `opacity 1→0`、面板 `width 0.18→1`、`height 0.04→1`、`translateY -24→0`、圆角 `28→0`、描边色 lerp 到透明、阴影随进度消失；同时该 controller 兼作玻璃卡片的**每帧重采样信号** | `timetable_screen.dart:3383` |
| OpenContainer | **vendored 自 `animations` 2.2.0 + mikcb 性能补丁** | `lib/widgets/open_container.dart` |

> 性能实测（注释里记录的原始探针）：官方 `OpenContainer.buildPage` 在每帧 `AnimatedBuilder` 内部调用 `closedBuilder/openBuilder`，420ms 转场里重建整页表单 + 关闭态卡片 **20 次 / 300ms**，UI 线程爆预算，观感"像幻灯片"。这就是我们必须 vendored 的原因。

### 3. 弹层入场（Miuix 弹簧）

| 表面 | 规格 | 位置 |
|---|---|---|
| 下拉气泡 / 列表弹窗 / 右上角菜单 | `SpringDescription.withDampingRatio(mass:1, stiffness:362.5, ratio:0.82)`（= Miuix `ListPopupDefaults.fractionAnimationSpec`），scale + reveal；菜单为 0.15→1 | `hyperos_select.dart:164`、`hyperos_list_popup.dart:53` |
| 对话框 | dim 进入 300 / 退出 250、内容退出 260、大屏 `enterScaleFrom 0.8`、返回手势 `backGestureResetMs 150` + `backProgressScaleDelta 0.2` | `hyperos_miuix_spec.dart:515+` |
| 面板 | 350ms；玻璃坞相关 200 / 160ms | `hyperos_sheet.dart:609` 等 |

### 4. 底栏（玻璃坞）物理

| 项 | 规格 |
|---|---|
| 四套 Compose 弹簧 | settle `400/30`、press `1500/38.73`、stretch `10000/200`、panel `1500/77.46`（`soft_glass_tab_bar.dart:26-52`） |
| 速度估计 | 100ms 滑窗 + 最小二乘斜率（对齐 Compose `VelocityTracker`），替代逐帧差分（旧做法噪声导致拉伸乱跳） |
| 水滴合并槽 | 圆钮滑入药丸 + 圆形裁切贴合端帽弧度 |

### 5. 滚动 / 越界物理

| 项 | 规格 |
|---|---|
| 越界 | 临界阻尼弹簧（周期 0.4s，`stiffness=(2π/0.4)²`）+ 橡皮筋（自由区 16px、falloff 指数 3.4、最小传递 0.05、上限 50% 视口）`hyperos_overscroll.dart:31` |
| 首页下拉 | 立方根阻尼 `dampedFraction`、`visualOffset`、触摸↔位移双向映射，同一标准弹簧 `hyperos_home_pull.dart:45` |
| Fling 数字选择器 | `SpringDescription(mass:1, stiffness:400, damping:40)` |

## 二、开源候选逐一比对

### A. 路由转场 → 官方 `animations` 的 `SharedAxisTransition`

- 现状：`animations: ^2.0.11` **已是直接依赖，但只有 vendored 的 `OpenContainer` 被用到**；`SharedAxisTransition` / `PageTransitionSwitcher` 一次没引用（`grep package:animations` 为空）。
- 覆盖度：Material Motion 的横向 shared-axis 骨架能对上（slide + parallax + fadeThrough 阈值），但**没有** MIUI 的卡片圆角、投影、settle 后去裁切、显示物理圆角联动、系统动画缩放热更新。这些恰是"观感像 HyperOS"的部分。
- 版本风险：`animations` 最新 **3.0.0**（flutter.dev，24 天前）changelog 明确写 **"Migrates to `material_ui`"**，要求 Flutter 3.44 / Dart 3.12。我们 SDK 里没有 `material_ui`（`/opt/flutter/packages/material_ui` 不存在，pub 缓存也没有），升级会把 Material 换成另一条 lineage，**先别升**（要升需单独评估 `package:flutter/material.dart` 与 `material_ui` 的类型/主题混用）。
- 结论：**保持自研**；可以考虑顺手蹭的是 `SharedAxisTransition` 的成熟实现细节，而不是替换。

### B. 预测性返回（最大缺口，SDK 自带）

- 我们 Manifest 第 81 行：`android:enableOnBackInvokedCallback="false"` —— **主动关闭**。所以真机上返回是固定 300ms 自播，而 HyperOS 2 真机是"手指拖着走、松手可取消"。
- SDK 3.44 已就绪（本地 SDK 实测存在）：
  - `PredictiveBackPageTransitionsBuilder`（Android U+ 的 shared-element 预测性返回；其他平台回落 `FadeForwardsPageTransitionsBuilder`）
  - `PredictiveBackFullscreenPageTransitionsBuilder`、`FadeForwardsPageTransitionsBuilder`（Android 16 默认观感）
  - `PageTransitionsBuilder.delegatedTransition`（把二次转场交给"上一页"渲染，共享元素类转场用）
- **关键机制**（`widgets/routes.dart:563-604`）：`TransitionRoute`（`PageRoute` 的基类，我们的 `HyperosPageRoute` 继承链上有）**已经实现了预测性返回**：
  - `handleStartBackGesture(progress)` → `_controller.value = progress` + `navigator.didStartUserGesture()`
  - `handleUpdateBackGestureProgress` → 继续驱动**同一个** controller
  - `handleCancelBackGesture` → `controller.forward()` 回位；`handleCommitBackGesture` → `navigator.pop()`
  - 也就是说：**打开标志后，我们现在这套视觉规格会被手指逐帧驱动，零改动即"跟手"**。
- 需要补的只有一件事：谁把平台的 back 事件转给 route。SDK 的 Material 版做法是 `_PredictiveBackGestureDetector`（`WidgetsBindingObserver` + `handleStartBackGesture/Update/Cancel/Commit`，返回 `true` 认领手势），我们的 `HyperosPageRoute` **不会**被 Material 的 detector 接管（它不是 `MaterialPageRoute`），所以要自己写一份约 30 行的 observer，或者把 `HyperosPageRoute` 改成继承 `MaterialPageRoute`（`opaque`/`barrierColor` 与我们现在的覆写一致，可行）。
- 风险面（必须逐项回归）：全 app 有 5 处 `PopScope`（miuix 展示页、用户指南、列表弹窗、壁纸选择器 + 1 处）；`webview_flutter` 页面的返回拦截；三键导航与手势导航两种模式；`android:enableOnBackInvokedCallback` 一旦为 true，未处理的返回会走"预测性返回 → 直接 finish Activity"，行为与旧的 `onBackPressed` 不同。

### C. Miuix 弹簧/曲线 → `flutter_miuix`（已依赖）

- 依赖：`flutter_miuix`（git，`github.com/Mutx163/flutter_miuix`，v1.0.11，**ported from `compose-miuix-ui/miuix`**），全项目已在 `lib/screens/miuix_showcase/*` 等 15+ 文件使用。
- 它提供（实测包源码）：
  - `MiuixSpringDefaults`：`maxFrameDeltaSeconds 0.016` / `minFrameDeltaSeconds 0.001` / `highVelocityThreshold 5000` / `criticalDampingRatio 1.0` / `standardSpringPeriod 0.4` / `slowerSpringPeriodForHighVelocity 0.55`
  - `MiuixSpringOperator`（显式欧拉步进）、`MiuixSpringEngine`（临界阻尼逐帧引擎 + `runSettleAnimation` Ticker 驱动）
  - `MiuixMotion`：`DecelerateEasing` / `AccelerateEasing` / `SinOutEasing`
  - **没有**页面转场 / 导航助手（包内 `grep PageRoute|Navigator.of` 为空）⇒ 路由转场这条腿只能自研，与我们现状一致。
- 我们 `hyperos_miuix_spec.dart:HyperosMiuixAnim` 的常量与它**逐值重复**（我们自己抄了一份）。可以收敛成一处（包为源），减少 drifting 风险。
- upstream：Compose Multiplatform 的 [compose-miuix-ui/miuix](https://github.com/compose-miuix-ui/miuix)（小米 HyperOS 风格组件库）—— 这是"官方风格源头"，Flutter 侧只有我们这个 fork。

### D. 玻璃形变转场（iOS 26 morph）→ `liquid_glass_widgets` 自带的 Morph 引擎

这是最"意外"的一条：**我们依赖的包里已经有一整套 iOS 26 玻璃形变转场引擎，而我们完全没用**。

实测 `liquid_glass_widgets-0.30.2` 源码：

| 能力 | 细节 |
|---|---|
| `GlassMorphController` | 用法类似 `AnimationController`：`open()` / `close()` / `computeState({finalDx, finalDy, horizontalOffset, verticalOffset})` / `setDisableAnimations`（Reduce Motion） |
| `MorphSpeed` | `slow` / `normal`（**native-parity 375ms profile**）/ `fast` / `instant`；每档都保持 **0.73 欠阻尼比**（关闭时的橡皮筋回弹在所有速度下都在） |
| `MorphStyle` | `teardrop`（iOS 26 经典水滴：Blob B 沿 **J 曲线**拉离 Blob A，SDF metaball shader 生成中间"脖子"）/ `bloom`（保留） |
| `LiquidMorphState` / `MorphPhase` | 逐帧预算好的几何 + 相位状态机 `idle→detaching→travelling→arriving→settled`（关闭方向带回弹） |
| 谁在用 | 包内自己的 `GlassMenu`、glass popover（`widgets/overlays/*`）用的就是它 |

我们的现状：玻璃弹窗/菜单/日视图入场都是自研的 **scale + 圆角 + 透明度**补间（还会被用户吐槽"像是带背景的卡片出来了，而不是玻璃出来了"）；`grep -rn "GlassMorph|morph" lib` 只命中无关的局部变量名 ⇒ **一次都没用**。

补充：包的 `GlassMenu` 是公开 widget（`items` / `menuWidth` / `menuBorderRadius` / `stretch` / `interactionScale` / `glow*` / `morphFromZero` / `GlassMenuController`），**但不支持二级子菜单**——这正是我们自研 `hyperos_list_popup` 的原因（右上角菜单有二级）。所以可行路径是：**保留自研弹窗逻辑，只把入场换成 `GlassMorphController`**（约 25 行集成）。

#### D.1 这个"形变转场"到底是什么效果（按源码逐帧拆解）

两个 blob：

- **Blob A**（触发控件的"幽灵"）留在原位，在前 **40%**（`_anchorEaseDuration = 0.4`）缩到 0，让液体桥**干净断开**；关闭时再长回来"接住"面板。
- **Blob B**（面板本体）沿 **J 曲线**从按钮中心飞向面板中心，同时从按钮尺寸长到面板尺寸。

**那根"脖子"不是画出来的**：`blend`（SDF metaball 融合强度，clamp 0–28）= `|pathT − sizeT| × 150`。两个圆角矩形在 SDF 里融成一滴，中间自然长出连接的颈；`pathT/sizeT` 分离最大时脖子最长。源码注释原文："The metaball SDF shader automatically creates the teardrop neck between the two blobs — **there is no explicit neck geometry**."

**过冲**：位置用 `_BackOutCurve(amplitude 2.5)` → 面板冲过目标再弹回（源码称 "string pull"，正是脖子被拉到最长的时刻）。

**关闭才是重点**（同一根弹簧 `mass 1 / stiffness 120 / damping 16` → ζ≈0.73 略欠阻尼，另注入初速 **−2.5**）：

- 面板**挤一下**：`containerScale = 1 + rawValue × 0.55`（rawValue<0，肉眼可见的压扁）
- **按钮被顶一下**：`pushDx/pushDy = (finalDx + offset) × rawValue`（只在关闭过冲时非零）
- 幽灵按钮重新长回来接住面板 —— 就是 iOS 那种橡皮筋回弹手感

**时长与旋钮**：`MorphSpeed.normal` = iOS 26 原生对齐的 **375ms profile**；slow / normal / fast / instant 四档都保持 ζ=0.73（只改频率）；系统"减少动效"时切 instant 硬弹簧（单帧、无脖子）。`_backOutAmplitude` / `_blendMultiplier` / `_maxBlend` 等物理常数**故意不公开**（注释："暴露会产生物理上破碎的动画"），安全旋钮只有 `MorphSpeed`。

**谁在用它**：包内 `GlassMenu`（`widgets/overlays/shared/glass_menu_internal.dart:369` → `_morphController.computeState(...)`）与 glass popover 内部；`open()` 从静止起步、`close()` 注入 −2.5。

**怎么亲眼看**：published 包的 `example/example.dart` 只是通用首页（没有 morph 演示），要看真效果得 clone 仓库跑 Apple Messages 演示：`github.com/sdegenaar/liquid_glass_widgets` → `cd example && flutter run -t lib/apple_messages/apple_messages_demo.dart`（README：「点顶部菜单或 Edit 按钮，实时看 teardrop 开合物理」）。

**和我们现在的差别**：我们是"玻璃卡片缩放着出现/消失"（`_listPopupSpring` 362.5/0.82 的 scale + reveal 补间）；morph 是"一滴液体从按钮里被扯出来"。差别就在那根脖子、J 曲线过冲，以及关闭时按钮被顶的那一下。

### E. 其他 pub 包（不推荐）

pub.dev 搜 "page transition" 返回：`page_transition`、`concentric_transition`、`turn_page_transition`、`go_transitions`、`page_animation_transition`、`page_route_animator`、`page_route_transition`、`page_curl_flip`、`bottom_bar_page_transition`。

共同问题：它们卖的是"一套通用转场动画"（fade / slide / cupertino / 3D 翻转），语义停留在 Material/Cupertino，**没有一个实现 MIUI/HyperOS 系统设置的卡片滑入语义**，也没有一个处理"系统动画缩放 + 用户速度 + 显示物理圆角"。换上去只会更不像 HyperOS。

### F. 弹层入场 → 没有更优开源

Miuix 的 ListPopup / Dialog / Sheet 弹簧与时长规格只有 **Compose 原版**（`compose-miuix-ui/miuix`）是上游；Flutter 侧我们是"移植方"。这块保持自研是正确的，唯一可优化的是把弹簧常量收敛到 `flutter_miuix`。

## 三、建议：不动转场本体，补三处"完美度"

按性价比排序，每步都能独立验证、独立回滚：

### 第 1 步（收益最大）：接预测性返回

- 改动点：
  1. `android/app/src/main/AndroidManifest.xml` → `android:enableOnBackInvokedCallback="true"`
  2. 新增一个 ~30 行 `_HyperosPredictiveBackDetector`（`StatefulWidget` + `WidgetsBindingObserver`，照 SDK `_PredictiveBackGestureDetector` 的做法：`route.popGestureEnabled && route.isCurrent` 时认领手势并转发 `handleStartBackGesture/Update/Cancel/Commit`），包在 `HyperosNavigation.buildSharedAxisTransition` 外层；或让 `HyperosPageRoute extends MaterialPageRoute` 复用 SDK 的 builder。
- 视觉规格**零改动**（controller 被手势驱动，我们的裁切/投影/视差照旧逐帧算）。
- 回归清单：5 处 `PopScope`、WebView 页返回、三键/手势两种导航、`durationScaler` 与手势并存（手势进行中不应再自播）。
- 验证：真机（HyperOS 2）拖着返回手势应看到**目标页**随手指露出、松手可取消；`flutter test` 加"手势进度驱动 controller 值"的纯逻辑用例。

### 第 2 步：玻璃弹窗/详情入场换 `GlassMorphController`

- 落点：`hyperos_list_popup.dart`（右上角菜单，含二级）、`hyperos_select.dart`（下拉气泡）、日视图锚点展开（`timetable_screen.dart:3383`）。
- 收益：拿到 iOS 26 native profile（375ms / 0.73 欠阻尼 / J 曲线 / SDF 脖子）+ `MorphPhase` 状态机，替换自研补间；顺带把"卡片出来了而不是玻璃出来了"这个历史吐槽从根上解决（形变本身就是玻璃语义）。
- 注意：morph 期间每帧要重采样底面，**premium 档成本会叠加**（我们刚把全 app 统一到 premium），必须在真机 Profile 下量一遍帧时间；`MorphSpeed.instant` + 系统"减少动效"时走 `setDisableAnimations`。

### 第 3 步：参数收敛 + 依赖瘦身

- 把 `HyperosMiuixAnim` 的六个常量改为引用 `MiuixSpringDefaults`（一份源），并让 `HyperosHomePullPhysics` / `HyperosOverscrollPhysics` 复用 `MiuixSpringEngine`。
- `animations`：既然只用到 vendored 的 `OpenContainer`，要么把它降为 `dev_dependencies`/删掉（改引用本地文件），要么升到 2.2.0+ 但**别升 3.0.0**（`material_ui` 迁移）。
- 路由转场保持自研，把"为什么不换开源库"的原因写进 `hyperos_navigation.dart` 头注释（避免以后有人再问一遍）。

## 四、风险与验证清单

| 项 | 风险 | 验证方式 |
|---|---|---|
| 预测性返回 | 行为面最广：`PopScope`、WebView、三键导航、Activity 直接 finish | 真机四种路径回归 + 现有 `header_blur_style_wiring_test` / 导航相关测试全量跑 |
| glass morph | 与 premium glass 叠加的每帧成本；形变期间底面重采样 | 真机 Profile：`rasterizer` / `UI` 帧时间，480p/1080p 两档 |
| `animations` 3.0.0 | `material_ui` 双 Material lineage | 只在独立分支试，看 pub 解析与主题类型是否冲突 |
| 参数收敛 | 改常量后与线上观感漂移 | 逐值对比测试（我们已有 `*_test.dart` 里"模型默认值 = 渲染常量"的守卫写法，照抄） |

## 五、一句话回答"有没有开源项目能实现一样的"

- **视觉效果**：没有现成库能"一模一样"，我们这套已经是 MIUI/HyperOS 规格的移植（参数与插值器都可溯源），换库只会更不像 —— 但**官方 `animations` 可以覆盖它的一部分**（shared-axis 骨架、container transform），代价是丢掉卡片化与速度缩放。
- **"高性能 + 完美"的真正缺口**不在视觉，而在上面三件事：**预测性返回没接**、**玻璃 morph 引擎没用**、**参数两处维护**。前两件都是"开源侧已经提供、我们没用"的情况，改动量都不大。
- 顺带强调：`RepaintBoundary` 转场隔离、`OpenContainer` 性能补丁、系统动画缩放/显示圆角的原生桥接，是**我们比开源库做得更好的部分**，这三样别在换库时丢掉。
