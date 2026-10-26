# 官方 Compose Miuix 组件对照表（迁移 Phase 3 选型依据）

> 调研日期：2026-10-26 · 由子代理调研，Lead 归档
> 结论有效性与上游版本绑定：**miuix-ui 0.9.4（2026-09-20）**。官方是 0.x 实验库，
> API 可能无通知变更——Phase 3 开工前重新核对一次版本与坐标。

## 库坐标与现状

- 仓库：compose-miuix-ui/miuix（原 miuix-kotlin-multiplatform/miuix，301 重定向）
- 文档：https://compose-miuix-ui.github.io/miuix/（miuix.in 已失效）；有 Web Demo 可试组件
- Maven：`top.yukonga.miuix.kmp:miuix-ui(-android)` 等多模块：miuix-ui（核心）、
  miuix-preference（设置行）、miuix-icons、**miuix-blur（毛玻璃，minSdk 33）**、
  miuix-squircle（超椭圆）、miuix-nav（导航转场）、miuix-window（仅桌面 JVM）、miuix-shader
- 本仓已拍板 minSdk 33 → **miuix-blur 可直接用，无需降级路径**

## 四个关键确认（全部有官方答案）

| 问题 | 结论 |
|---|---|
| 毛玻璃 | ✅ miuix-blur：`Modifier.layerBackdrop()` + `textureBlur()`（半径/40+混色/噪点/玻璃边光6预设/视差）+ `progressiveTextureBlur()`（导航栏渐隐）；API 33+ |
| 悬浮 dock | ✅ `FloatingNavigationBar`（胶囊 2–5 项纯图标，圆角/颜色/阴影可调）+ `FloatingToolbar`（8 方位）；无中间凸起形态 |
| 大标题收缩 | ✅ `TopAppBar(title, largeTitle, scrollBehavior=MiuixScrollBehavior())` + nestedScroll |
| 主题定制 | ✅ 颜色/字体全局覆写（lightColorScheme/darkColorScheme + defaultTextStyles）；圆角无全局 token，逐组件 cornerRadius |

## 选型结论（课表 App）

**直接用**：Scaffold / TopAppBar / NavigationBar+FloatingNavigationBar / Card(按压Sink) /
BasicComponent / Preference×6 / Button / TextField / SearchBar / Switch·Checkbox·Slider /
OverlayDialog·BottomSheet / OverlayDropdown·Spinner / PullToRefresh / ProgressIndicator /
TabRow / Badge / miuix-nav 全家桶 / miuix-blur / miuix-squircle。

**包一层**：① 主题桥（现 Flutter 色板 → colorScheme 映射）；② NumberPicker 拼 HH:mm
时间选择；③ Snackbar 统一入口（官方 Scaffold 无 snackbarHost 槽）；④ dock 与 miuix-nav 路由联动。

**必须自绘**（官方确实没有对应物，符合规格的自绘白名单）：
① 日期/日历/时间选择器（官方完全没有——课表核心输入件）；
② 课表网格/周视图（Canvas，对齐 MiuixTheme 色板）；
③ 中间凸起 notched 导航（如现版本 dock 有凸起）；④ 骨架屏 shimmer；
⑤ 滚动顶栏实时模糊的组合接线（TopAppBar 与 miuix-blur 两套系统需自行接）。

## 对照全表

（组件×40 的逐项参数与包名见调研原始输出，要点：基础控件 basic.*、设置行 preference.*、
弹层 overlay.*/window.*（Overlay 系需 Scaffold 内置 MiuixPopupHost，Window 系免）、
导航 nav.*（NavDisplay+NavKey+rememberNavBackStack；转场 MiuixDefault/Modal/None+
navGraphicsTransition 自定义；预测性返回手势；NavDisplayEffects 圆角裁剪/压暗）。
miuix-nav v1 不支持：dialog/bottom-sheet 目的地、共享元素转场、result 通道——需要时自搭。）

## 风险

0.x API 不稳（版本升级频繁，minSdk 曾 23→24）；锁定 0.9.4 起步，升级单独评估。
