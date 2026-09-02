import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 单个课表（profile）的对比条目
class ProfileCompareEntry {
  final String name;
  final bool isActive;
  final int currentWeek;
  final int totalSections;
  final int totalCourses;
  final double requiredRatio;
  final int longestStreak;

  /// 相对当前课表的课时差（当前课表为 null）
  final int? deltaSections;

  const ProfileCompareEntry({
    required this.name,
    required this.isActive,
    required this.currentWeek,
    required this.totalSections,
    required this.totalCourses,
    required this.requiredRatio,
    required this.longestStreak,
    this.deltaSections,
  });
}

/// 指标列宽：取表头（footnote2）与数值（metricMedium 18sp tabular）的
/// 最大需求宽度；右对齐让同一指标纵向可扫读——对比页的核心是
/// 「同一列比大小」，不是每张课表一块的自我介绍。
// 11px 中文「课程门数」恰占 44，44 列宽会把表头截成「课程…」——留出余量。
const double _colCourses = 48; // 课程门数
const double _colSections = 40; // 节课
const double _colRatio = 64; // 必修 / 选修（必修占比）
const double _colStreak = 36; // 天连续
const double _colGap = 8;

/// 课表对比卡：表格式平铺——指标做表头、课表做行，
/// 全部数据一屏尽览，无二次交互、无弹窗。
class ProfileCompareCard extends StatelessWidget {
  final List<ProfileCompareEntry> entries;

  const ProfileCompareCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                const Expanded(child: SizedBox()),
                _MetricCell(l10n.statisticsCourseCount, _colCourses, caption: true),
                const SizedBox(width: _colGap),
                _MetricCell(
                  l10n.statisticsSemesterLabelSections,
                  _colSections,
                  caption: true,
                ),
                const SizedBox(width: _colGap),
                _MetricCell(l10n.statisticsNatureRatio, _colRatio, caption: true),
                const SizedBox(width: _colGap),
                _MetricCell(
                  l10n.statisticsSemesterLabelDayStreak,
                  _colStreak,
                  caption: true,
                ),
              ],
            ),
          ),
          for (var i = 0; i < entries.length; i++) ...[
            const HyperosInsetDivider(indent: 16),
            _ProfileCompareRow(
              entry: entries[i],
              isLast: i == entries.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCompareRow extends StatelessWidget {
  final ProfileCompareEntry entry;
  final bool isLast;

  const _ProfileCompareRow({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final delta = entry.deltaSections;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, isLast ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: entry.isActive
                      ? HyperosColors.primary(context)
                      : HyperosColors.secondaryText(
                          context,
                        ).withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              // Expanded（而非 Flexible）把行内余量全部收进名字列，
              // 让后面四个定宽指标列与表头一样贴右缘——否则指标列
              // 紧跟名字排布，列位置随课表名长度漂移，与表头错位。
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 激活行 w600，非激活行常规体，圆点颜色区分状态
                  style: HyperosTypography.listTitle(context).copyWith(
                    fontWeight: entry.isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(width: _colGap),
              _MetricCell('${entry.totalCourses}', _colCourses),
              const SizedBox(width: _colGap),
              _MetricCell(
                '${entry.totalSections}',
                _colSections,
                highlight: entry.isActive,
              ),
              const SizedBox(width: _colGap),
              _MetricCell(
                // 必修占比；选修 = 100 − 必修，互补信息不重复占列宽
                '${(entry.requiredRatio * 100).round()}%',
                _colRatio,
              ),
              const SizedBox(width: _colGap),
              _MetricCell('${entry.longestStreak}', _colStreak),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              children: [
                Text(
                  l10n.statisticsWeekSelector(entry.currentWeek),
                  style: HyperosTypography.metricCaption(context),
                ),
                if (entry.isActive) ...[
                  const SizedBox(width: 6),
                  Text(
                    l10n.statisticsCompareActive,
                    style: HyperosTypography.metricCaption(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: HyperosColors.primary(context),
                    ),
                  ),
                ] else if (delta != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    l10n.statisticsCompareDelta(
                      delta > 0 ? '+$delta' : '$delta',
                    ),
                    style: HyperosTypography.metricCaption(context).copyWith(
                      // 语义色已足够区分正负，字重回归常规
                      color: delta > 0
                          ? HyperosIconColors.red
                          : (delta < 0
                                ? HyperosIconColors.green
                                : HyperosColors.secondaryText(context)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 表格单元：数值 / 表头共用，右对齐保证同一列纵向对齐。
class _MetricCell extends StatelessWidget {
  final String text;
  final double width;

  /// 表头小灰标签
  final bool caption;

  /// 当前课表的节数用主题色轻强调
  final bool highlight;

  const _MetricCell(this.text, this.width, {this.caption = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.right,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: caption
            ? HyperosTypography.metricCaption(context)
            : HyperosTypography.metricMedium(context).copyWith(
                color: highlight ? HyperosColors.primary(context) : null,
              ),
      ),
    );
  }
}
