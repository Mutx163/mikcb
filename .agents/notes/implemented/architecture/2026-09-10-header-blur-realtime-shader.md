# Agent Note: 顶栏模糊走实时 GPU shader，弃用 CFH 位图管线与两阶段渲染

Status: implemented

## Problem

设置首页与子页顶栏要在列表内容滚到栏下时呈现毛玻璃。2026-07 的实现不是实时采样，而是
**CFH（Cached Frosted Header）位图管线**：`RepaintBoundary.toImage(0.72×)` → 裁标题条 →
`FrostedBlurService.blurImage` → `RawImage` + tint 叠在顶栏下。这条管线自带两个绕不开的问题：

1. **滞后**——模糊结果要等捕获 + blur 完成才可用，用户感知是「不跟手，停手才变」。
2. **预算**——每帧产出位图的算力开销，以及快滑时的捕获代次雪崩。

当时的诊断与三方案对比见 `docs/reference/2号高斯模糊总结.md`（2026-07-06，§3「候选方案对比」
在第 70 行），其结论是**方案 C 两阶段渲染**：滚动相位只显示 sharp preview，静止后再做全量
捕获与单次 blur。

## Decision

顶栏模糊不再走任何位图管线，改为**对下层实时采样 GPU 着色器**：

- 唯一入口是 `InspireHeaderBlur`（`lib/ui/hyperos/inspire/inspire_header_blur.dart`），
  它在带内渲染 `Inspire.backdropBlur`（该文件第 171 行），参数由
  `configFor(style, gaussianSigma, tuning)` 决定，做的是**变量**模糊——强度沿方向连续变化。
- 两档 `HeaderBlurStyle`（`lib/models/header_blur_style.dart`）**共用同一条 shader 链路**，
  差别只在过渡形态：`gaussian` 整带均匀 + 底边渐隐收边，`inspire` 自顶边向下连续衰减（默认档）。
- 旧入口 `FrostedHeaderBackground` 已收敛成一层纯转发——`build()` 直接返回
  `InspireHeaderBlur`（`lib/ui/hyperos/frosted/frosted_header_background.dart:60`）。
  首页玻璃带与子页顶栏外壳共用此入口，**不存在第二条模糊路径**。

上游依赖是 `inspire_blur ^0.4.1`（`pubspec.yaml:59`）。

**方案 C 没有成为终态。** 它的载体——`lib/ui/hyperos/frosted/frosted_header_controller.dart`
（628 行）、`frosted_capture.dart`（240 行）与 128 行对应测试——已在 `86dc1248`
（2026-08-02「清理未接入的旧代码和 BlackBox 依赖」）整体删除。那次提交信息里的**「未接入」**
是关键事实：到 2026-08-02，两阶段渲染已经没有任何调用点，它是在被推荐后自行搁浅的，
不是被这次改动强拆的。

## 现状机制

```
FrostedHeaderBackground.build()            ← 转发，无逻辑
  └─ InspireHeaderBlur.build()             ← 唯一的模糊实现
       useBlur = blurEnabled && canRender(context)        (第 161 行)
       ClipRect > Stack
         ├─ if (useBlur) IgnorePointer(Inspire.backdropBlur(...))   (第 171 行)
         ├─ _tintLayer(tuning)             ← 衬底画在模糊之上
         └─ child                          ← 顶栏内容
```

分工是刻意的：**模糊负责「糊」，衬底负责可读对比度**，两者分开调参（`_tintLayer` 由
`tuning` 驱动，模糊由 `configFor` 驱动）。

## 失效与降级链

生效判定收在 `HyperosBlurredHeader`（`lib/ui/hyperos/hyperos_blurred_header.dart`）：

- `backdropBlurEnabled(context)`（第 233 行）= `liveBlurSupported && _appearanceOf(context).blurEnabled`
- `liveBlurSupported`（第 128 行）= `!kIsWeb && (Platform.isAndroid || Platform.isIOS)`

再叠上 `InspireHeaderBlur` 自身的降级（该文件第 20 行的注释列明）：系统无障碍 / 降动效 /
高对比度、全局模糊开关关闭、Web 与桌面、设备不支持 shader filter
（`ImageFilter.isShaderFilterSupported`）——命中任意一条即**只画 tint 衬底**。

这条链是「实时」路线的**代价**：模糊能力依赖运行时能力探测，任何一环不满足就直接退化成
纯色衬底，没有中间档。

## Alternatives considered

### 方案 A：实时 `BackdropFilter` / `ImageFiltered` 直接采样下层 —— 当年否掉，终态其实是它的同类

**它最强的理由**：天然跟手，无需快照，也不必维护位图管线的相位与代次；实现最简单。

**当年为什么不用**（`docs/reference/2号高斯模糊总结.md` 第 82 行的结论）：Android 上全屏
ListView + `BackdropFilter` 极易掉帧；与 CFH 架构冲突、需大改页面层级；模糊区域外缘与透明
像素行为难控。原话是「不适合作为 mikcb 主路径（设置页列表重、目标中低端机）」。

**转折**：这条路最终**成了**，但换掉了实现手段——不是通用 `ImageFilter.blur`，而是
`inspire_blur` 的自定义 shader filter，且只作用在玻璃带内、不是全屏。所以当年那个更大的
结论（「实时模糊不可行」）已被推翻，只有更窄的那条（「通用 `BackdropFilter` 打全屏
ListView 不可行」）仍然成立。`header_blur_style.dart:7` 的注释自己承认了这层延续：
`gaussian` 档「等价于过去的 `BackdropFilter` 均匀模糊观感」。

### 方案 B：维持 CFH，滚动与静止统一走「裁条 + 每帧 blur」

**它最强的理由**：改动面最小——只在现有管线上调节流参数，不动架构与页面层级。

**为什么不用**（同文档第 96 行）：算力上不可行，blur 吞吐远低于 60fps；且它不解决
`displayImage` 的优先级问题，快滑时 generation 雪崩依旧。当时的定位是「可作为修 bug 后的
补充，不能单靠它解决跟手」。

### 方案 C：两阶段渲染（滚动 preview / 静止 blur）—— 当年推荐，最终弃用

**它最强的理由**：在保留 CFH 架构的前提下引入明确的交互相位——滚动期优先显示 sharp 的
`_previewImage`、不启动 blur；settled 后切回 `_blurredImage`，做一次全量捕获 + 单次 blur。
对「跟手」与「算力」这对矛盾，它是当时改动最省的解，也确实避开了方案 A/B 各自的硬伤。

**为什么最终不用**：它把**观感**绑在**相位判定**上——滚动结束后必须完成一次全量捕获与 blur
才能切图，观感好坏取决于这次切换赶不赶得上；而且模糊强度是均匀的，表达不了「越靠上越朦胧」。
实时 shader 同时消掉了相位机与位图预算两个约束，代价还更低。换言之方案 C 不是被否掉，
而是被一个约束更少的解法绕过了。

## Consequences

**收益**

- 无位图管线：不再有捕获、裁剪、代次作废与逐帧位图预算，模糊与滚动天然同帧。
- 两档统一口径：`gaussian` / `inspire` 共用一条 shader 链路，只有过渡形态不同。
- 观感上限更高：变量模糊（强度连续变化）是均匀模糊表达不了的。

**代价**

- 多一个第三方依赖（`inspire_blur`）与一条四条件降级链；降级即退回纯 tint 衬底，无中间档。
- 模糊正确性依赖 `ImageFilter.isShaderFilterSupported` 的运行时可探测性。

**遗留（未清）**

- `lib/services/frosted_blur_service.dart` 的 `blurImage` 已无调用点
  （`grep -rn 'blurImage' lib/ test/` 只命中定义行本身），该文件 133 行里只剩
  `probeNativeSupport()` 还被 `lib/main.dart:432` 使用。属于死代码，待裁剪。
- **同主题文档已与代码脱节**，改这段代码前不要照文档走：
  - `docs/reference/2号高斯模糊总结.md`（2026-07-06）仍在推荐方案 C，且它引用的
    `lib/ui/hyperos/frosted/frosted_header_controller.dart`（第 38、183、187 行）已删除，
    符号 `displayImage` / `isPreviewActive` 在 `lib/` 下 0 命中。
  - `docs/reference/hyperos-blurred-header.md` 仍以 CFH 为现役机制描述（该文件被
    `.gitignore:118` 忽略、未入库）。
  - `docs/reference/hyperos-audit-checklist.yaml`、`hyperos-audit-user-history.yaml`、
    `hyperos-page-compliance.md` 亦提到 CFH，未逐条核。
