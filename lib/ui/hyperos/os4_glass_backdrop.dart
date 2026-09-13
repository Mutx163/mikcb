import 'package:flutter_miuix/miuix.dart';

/// 全应用共享的 OS4 玻璃采样源（上游 `MiuixLayerBackdrop`）。
///
/// 上游玻璃（`MiuixGlass` / 各类 `MiuixGlass*Popup`）**不自己抓背景**，而是从
/// 一个 [MiuixLayerBackdrop] 取快照；快照由包在**宿主页内容**外侧的
/// `MiuixLayerBackdropCapture` 提供。上游原话：
///
/// > 必须放在 backdrop 捕获子树之外，防止反馈采样
///
/// 两点推论（决定了接入形态）：
/// 1. 捕获子树**不能包含玻璃自身** —— 所以不能做"应用级捕获"，只能"哪个宿主页
///    用玻璃，就用它自己的捕获包住页面内容"，且**弹层必须留在捕获之外**。
/// 2. 弹层按上游契约是「常驻挂载 + 切 `show`」（见 `HomeTopMenuPopup` 与
///    `HyperosSelectPopup`），其 OverlayPortal 把面板画到 Overlay 上，因此
///    "在捕获之外"是天然成立的。
///
/// 同一时刻只应有一个捕获在树上（同时可见的两个宿主会互相覆盖；
/// 本项目不存在该场景）。宿主没包捕获时，上游玻璃自我降级为纯色轮廓，
/// 不会报错 —— 所以这是"要不要模糊/材质"的开关，不是必需前置。
final MiuixLayerBackdrop os4GlassBackdrop = MiuixLayerBackdrop();
