import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_models.dart';

/// 学期总览区域（大数字展示）
class OverviewSection extends StatelessWidget {
  final SemesterStats stats;

  const OverviewSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (stats.totalCourses == 0) {
      return const SizedBox.shrink();
    }

    final dividerColor = HyperosColors.dividerLine(context);

    // 2×2 metrics with a continuous crosshair (not two broken segments).
    return HyperosControlCard(
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.menu_book_rounded,
                      accent: HyperosIconColors.blue,
                      value: '${stats.totalCourses}',
                      label: l10n.statisticsSemesterLabelCourses,
                    ),
                  ),
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.schedule_rounded,
                      accent: HyperosIconColors.teal,
                      value: '${stats.totalSections}',
                      label: l10n.statisticsSemesterLabelSections,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.calendar_today_rounded,
                      accent: HyperosIconColors.indigo,
                      value: '${stats.totalWeeks}',
                      label: l10n.statisticsSemesterLabelWeeks,
                    ),
                  ),
                  Expanded(
                    child: _MetricCell(
                      icon: Icons.local_fire_department_rounded,
                      accent: HyperosIconColors.orange,
                      value: '${stats.longestStreak}',
                      label: l10n.statisticsSemesterLabelDayStreak,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _OverviewCrosshairPainter(color: dividerColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws a continuous cross through the card center (full height + full width).
class _OverviewCrosshairPainter extends CustomPainter {
  const _OverviewCrosshairPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..isAntiAlias = false;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), paint);
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), paint);
  }

  @override
  bool shouldRepaint(covariant _OverviewCrosshairPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MetricCell extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String value;
  final String label;

  const _MetricCell({
    required this.icon,
    required this.accent,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HyperosIconBadge(icon: icon, accent: accent),
          const SizedBox(height: 8),
          Text(
            value,
            style: HyperosTypography.listTitle(context).copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
              color: HyperosColors.primaryText(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HyperosTypography.listDetail(context),
          ),
        ],
      ),
    );
  }
}
