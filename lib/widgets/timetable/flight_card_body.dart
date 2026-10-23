import 'package:flutter/material.dart';

import '../../models/timetable_settings.dart';
import 'day_view/day_view_agenda_surface.dart';
import 'flight_text_metrics.dart';

/// 转场中「正在飞的那张卡」的渲染（2026-10-23 重写）。
///
/// ## 用户要的到底是什么
///
/// > 「课程卡片里面的字不是平移过去的，而是开始的、动画上的、最终的，是三个
/// > 位置，还有三个环节的圆角也是，圆角应该是渐变的才对，从周课表圆角，渐变
/// > 到日课表圆角，这样才丝滑，还有卡片上的字也要是这样才可以」
///
/// 这段话落到实现上是四件事，缺一件就还是「三个位置」：
///
/// 1. **外框**矩形连续（`MorphFlightCard` 的 `Rect.lerp`，已经在做）；
/// 2. **每一行字的位置与字号连续**（本文件 + `flight_text_metrics.dart`）；
/// 3. **圆角连续**（8 → 20，线性）；
/// 4. **表面材质连续**（底色、渐变、投影、字色都与议程卡同源）。
///
/// 第 2 条以前是手写近似值（`52` / `78.5` / `50`），真值与它差几像素，于是起飞
/// 和落定各跳一次。现在每行字的矩形都由 `measureCompactCardText` /
/// `measureAgendaCardText` **按两端真实排版复算**，本组件只做插值。
///
/// ## 为什么文字用 `Positioned` 而不是复刻两端的排版树
///
/// 两端的排版树完全不同（网格卡是 `FittedBox` + 居中的 `Column`，议程卡是
/// 固定顺序的 `Column`）。要让它们「中间连续」，唯一稳的做法是**两端各自算出
/// 行的矩形**，中间按矩形摆 —— 复刻任何一端的排版树都会在另一端落地时跳。
///
/// ## 玻璃铁律
///
/// `Opacity` 只包**文字与图标**，绝不包 [DayViewAgendaSurface]（`CourseSurface`
/// 的 `BackdropFilter` 进半透明层采不到身后内容，磨砂会塌成透明）。
class FlightCardBody extends StatelessWidget {
  const FlightCardBody({
    super.key,
    required this.settings,
    required this.progress,
    required this.layout,
    required this.color,
    required this.gradientColors,
    required this.radius,
    required this.shadowOpacity,
    this.opacityScale = 1,
    this.onCardColor,
  });

  final TimetableSettings settings;

  /// 飞行进度 0..1（**已过曲线**）。
  final double progress;

  /// 当前帧的卡内布局（每行字的位置/字号/字重/透明度）。
  final FlightLayout layout;

  /// 卡片主色（已按主题/课程色解析，与议程卡的 `fillColor` 同源）。
  final Color color;

  /// 实体档的渐变（与议程卡 `cardDecoration.gradient` 同源）。
  ///
  /// 议程卡在实体档下是 `baseColor → fillColor` 的两段渐变，飞行卡若只给纯色，
  /// 落地那一帧会看到「卡片忽然出现一层渐变」。
  final Gradient? gradientColors;

  /// 当前帧的圆角（8 → 20 插值）。
  final double radius;

  /// 当前帧的投影强度（0 → 议程卡的 0.18，插值）。
  final double shadowOpacity;

  /// 压暗系数（非本周 / 停课）—— 与议程卡的 `opacityScale` 同源。
  final double opacityScale;

  /// 卡面文字色（`palette.foregroundColor`）。
  final Color? onCardColor;

  @override
  Widget build(BuildContext context) {
    final ink = onCardColor ?? const Color(0xFF1A1A1A);
    return DayViewAgendaSurface(
      settings: settings,
      color: color,
      radius: radius,
      opacityScale: opacityScale,
      gradient: gradientColors,
      // 投影跟着进度长出来：0 时不画（`outerShadow` 为空），落定那帧与
      // 议程卡同款 16px / alpha 0.18。中途用同一份几何、只改 alpha，
      // 不会出现「阴影突然变形状」。
      shadow: shadowOpacity <= 0.001
          ? null
          : [
              BoxShadow(
                color: color.withValues(alpha: shadowOpacity),
                blurRadius: _lerp(0, 16, shadowOpacity / 0.18),
                offset: Offset(0, _lerp(0, 4, shadowOpacity / 0.18)),
              ),
            ],
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          for (final item in layout.items)
            if (item.opacity > 0.001)
              Positioned(
                left: item.rect.left,
                top: item.rect.top,
                width: item.rect.width > 0 ? item.rect.width : null,
                height: item.isIcon ? item.rect.height : null,
                child: Opacity(
                  // 只包文字/图标：玻璃面在本层之外，不会被拖进离屏层。
                  opacity: item.opacity,
                  child: item.isIcon
                      ? Icon(
                          item.icon,
                          size: item.fontSize,
                          color: ink.withValues(alpha: 0.82),
                        )
                      : Text(
                          item.text,
                          maxLines: item.maxLines,
                          overflow: item.maxLines == null
                              ? TextOverflow.clip
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontSize: item.fontSize,
                            fontWeight: item.weight,
                            height: item.lineHeightFactor,
                          ),
                        ),
                ),
              ),
        ],
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
