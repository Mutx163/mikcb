import 'package:flutter/material.dart';

/// 把白色面板画在**日期表格底部**，并让它的上沿两条角**向上弯**（2026-10-21）。
///
/// ## 用户口径
///
/// 「还有整个拉杆区域，左右不是有那个圆角吗，他应该是向上弯的，容器应该是上面的
/// 表格，而不是的信息区域」。
///
/// 这句话在讲**容器归属**：那圈圆角属于**上面那张表格**的底边，白底从表格下沿
/// 开始并托住它。首版把圆角画在下面信息面板的**上沿**（`BorderRadius.vertical(top:)`），
/// 读起来是「下面这块板子有圆角、从下面升上来」—— 又是一次把归属讲反。
///
/// ## 几何
///
/// 白色面板的顶边只有中间那一段露在表格下方；左右两角用一段 **向外张开的弧**
/// 连到屏幕两侧 —— 视觉上就是"表格的白色托底从下面兜住两角、弧线向上翘"。
///
/// 用 [CustomClipper] 而不是 `BorderRadius` 的原因：`BorderRadius` 只会把
/// **外角**削圆（凹进去），做不出这种"从面板顶边向两侧张开的弧"。这里的路径是：
///
/// ```text
///   (0, r) ──────────────── (w, r)     ← 顶边两侧各留 r 的余量（弧的起点）
///      ╲                    ╱
///       ╲  (r, 0)   (w-r, 0)          ← 弧向中间收，形成"向上翘"的两角
///        ╲______________╱
///        │                │
///        │   面板主体      │
/// ```
///
/// 即在顶边两端各画一段二次贝塞尔，控制点落在「顶边外侧 + 内侧下移」处，
/// 使弧线朝**上**凸出 —— 这就是用户说的"向上弯"。
class MonthPanelTopCurveClipper extends CustomClipper<Path> {
  const MonthPanelTopCurveClipper({required this.cornerRadius});

  /// 两角弧的半径（逻辑 px）。取值接近圆角观感即可，40 在手机上读起来自然。
  final double cornerRadius;

  @override
  Path getClip(Size size) {
    final r = cornerRadius.clamp(0.0, size.width / 2);
    if (r <= 0) {
      return Path()..addRect(Offset.zero & size);
    }
    final path = Path()
      // 从左上角的弧末端开始（顶边左端向内收 r）。
      ..moveTo(0, r)
      // 左角：从上往下、向右收，弧向上凸。
      ..quadraticBezierTo(0, 0, r, 0)
      // 顶边中段。
      ..lineTo(size.width - r, 0)
      // 右角：对称。
      ..quadraticBezierTo(size.width, 0, size.width, r)
      // 右侧下行、底部封闭。
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant MonthPanelTopCurveClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius;
}
