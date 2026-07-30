import 'package:flutter/material.dart';

import '../hyperos_miuix_spec.dart';
import '../hyperos_theme.dart';
import '../hyperos_tokens.dart';

/// Solid circle used as a theme / color swatch prefix on choice rows.
class HyperosColorDot extends StatelessWidget {
  const HyperosColorDot({super.key, required this.color, this.size = 16});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Thin right chevron used on HyperOS list rows.
class HyperosChevron extends StatelessWidget {
  const HyperosChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final color = HyperosColors.actionIcon(context);
    return SizedBox(
      width: HyperosTokens.chevronWidth,
      height: HyperosTokens.chevronHeight,
      child: CustomPaint(
        painter: _HyperosChevronPainter(
          color: color,
          strokeWidth: HyperosTokens.chevronStrokeWidth,
        ),
      ),
    );
  }
}

class _HyperosChevronPainter extends CustomPainter {
  const _HyperosChevronPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HyperosChevronPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Up-down arrow for dropdown / select rows (Miuix `ArrowUpDown`, 10x16).
class HyperosUpDownChevron extends StatelessWidget {
  const HyperosUpDownChevron({super.key});

  @override
  Widget build(BuildContext context) {
    final color = HyperosColors.actionIcon(context);
    return SizedBox(
      width: HyperosMiuixDropdown.arrowWidth,
      height: HyperosMiuixDropdown.arrowHeight,
      child: CustomPaint(
        painter: _HyperosUpDownChevronPainter(
          color: color,
          strokeWidth: HyperosTokens.chevronStrokeWidth,
        ),
      ),
    );
  }
}

class _HyperosUpDownChevronPainter extends CustomPainter {
  const _HyperosUpDownChevronPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final midY = size.height / 2;
    final halfGap = HyperosMiuixDropdown.arrowChevronGap / 2;
    final chevronHalfHeight =
        (size.height - HyperosMiuixDropdown.arrowChevronGap) / 2 - strokeWidth;

    // Top chevron points up (^); bottom chevron points down (v).
    final upBaseline = midY - halfGap;
    final downBaseline = midY + halfGap;
    final up = Path()
      ..moveTo(0, upBaseline)
      ..lineTo(w / 2, upBaseline - chevronHalfHeight)
      ..lineTo(w, upBaseline);
    final down = Path()
      ..moveTo(0, downBaseline)
      ..lineTo(w / 2, downBaseline + chevronHalfHeight)
      ..lineTo(w, downBaseline);

    canvas.drawPath(up, paint);
    canvas.drawPath(down, paint);
  }

  @override
  bool shouldRepaint(covariant _HyperosUpDownChevronPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Colored rounded-square icon badge with white glyph.
class HyperosIconBadge extends StatelessWidget {
  const HyperosIconBadge({
    super.key,
    required this.icon,
    this.accent = HyperosIconColors.blue,
  });

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HyperosTokens.iconBadgeSize,
      height: HyperosTokens.iconBadgeSize,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(HyperosTokens.iconBadgeRadius),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: HyperosTokens.iconGlyphSize, color: Colors.white),
    );
  }
}

class HyperosSelectedCheckmark extends StatelessWidget {
  const HyperosSelectedCheckmark({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.check, size: size, color: HyperosColors.primary(context));
  }
}
