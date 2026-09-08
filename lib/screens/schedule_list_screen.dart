import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../domain/schedule_list_grouping.dart';
import '../l10n/app_localizations.dart';
import '../models/schedule_item.dart';
import '../providers/timetable_provider.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../utils/hex_color.dart';
import 'add_schedule_item_screen.dart';

/// 日程安排列表页：三类时间实体（任务/考试/日程）中日程的唯一浏览管理面。
///
/// 与任务清单、考试安排同构的 HyperosSubpage 列表：只收系列根条目
/// （单次覆盖是重复日程的实例级数据，不是独立条目），分组与排序收口在
/// [ScheduleListGrouper]（即将到来 / 已过期 / 已暂停）；编辑复用
/// [AddScheduleItemScreen] 系列模式，滑动删除走整系列确认。
class ScheduleListScreen extends StatelessWidget {
  const ScheduleListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final groups = ScheduleListGrouper.group(
      provider.scheduleItems,
      DateTime.now(),
    );

    final sections = <(String, List<ScheduleListEntry>, bool)>[
      (l10n.scheduleUpcomingSection, groups.upcoming, false),
      (l10n.schedulePastSection, groups.past, true),
      (l10n.schedulePausedSection, groups.paused, true),
    ];

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.scheduleListTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.add_rounded),
          semanticsLabel: l10n.addScheduleAction,
          onPress: () => _navigateToAdd(context),
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        color: HyperosColors.scaffoldBackground(context),
        child: groups.isEmpty
            ? _buildEmptyState(context, l10n)
            : HyperosListView(
                children: [
                  for (final (index, section) in sections.indexed) ...[
                    if (section.$2.isNotEmpty) ...[
                      if (index > 0) const HyperosSectionGap(),
                      HyperosSectionLabel(text: section.$1),
                      HyperosListGroup(
                        children: [
                          for (final entry in section.$2)
                            _ScheduleListRow(
                              key: ValueKey('schedule-list-row-${entry.item.id}'),
                              entry: entry,
                              dimmed: section.$3,
                              onTap: () => _navigateToEdit(context, entry.item),
                              confirmDismiss: () => _confirmDelete(
                                context,
                                entry.item,
                                l10n,
                              ),
                              onDismissed: () =>
                                  _deleteSchedule(context, entry, l10n),
                            ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return HyperosBlurredBodyInset(
      child: Center(
        child: HyperosEmptyState(
          icon: Icons.event_available_outlined,
          title: l10n.scheduleListEmptyTitle,
          action: HyperosButton(
            label: l10n.addScheduleAction,
            onPressed: () => _navigateToAdd(context),
          ),
        ),
      ),
    );
  }

  void _navigateToAdd(BuildContext context) {
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/schedule/add'),
        builder: (_) => const AddScheduleItemScreen(),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, ScheduleItem item) {
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/schedule/edit'),
        builder: (_) => AddScheduleItemScreen(scheduleItem: item),
      ),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    ScheduleItem item,
    AppLocalizations l10n,
  ) {
    return showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteScheduleTitle,
      message: l10n.deleteScheduleMessage(item.title),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    ).then((confirmed) => confirmed == true);
  }

  Future<void> _deleteSchedule(
    BuildContext context,
    ScheduleListEntry entry,
    AppLocalizations l10n,
  ) async {
    final provider = context.read<TimetableProvider>();
    await provider.deleteScheduleItem(entry.item.id);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.scheduleDeletedHint,
      kind: AppToastKind.success,
    );
  }
}

class _ScheduleListRow extends StatelessWidget {
  const _ScheduleListRow({
    super.key,
    required this.entry,
    required this.dimmed,
    required this.onTap,
    required this.confirmDismiss,
    required this.onDismissed,
  });

  final ScheduleListEntry entry;
  final bool dimmed;
  final VoidCallback onTap;
  final Future<bool> Function() confirmDismiss;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final item = entry.item;
    final primaryText = HyperosColors.primaryText(context);
    final secondaryText = HyperosColors.secondaryText(context);
    final mutedPrimary = primaryText.withValues(alpha: dimmed ? 0.45 : 1);
    final mutedSecondary = secondaryText.withValues(alpha: dimmed ? 0.55 : 1);
    final accent = parseHexColorOrFallback(
      item.color,
      fallback: HyperosIconColors.blue,
    );
    final badgeColor = dimmed ? accent.withValues(alpha: 0.45) : accent;
    final recurrenceBadge = _recurrenceBadgeLabel(l10n, item);
    final location = item.location?.trim();
    final reminderMinutes = item.reminderMinutesBefore;

    final row = HyperosPressableRow(
      onTap: onTap,
      holdHighlightThroughTransition: true,
      backgroundColor: HyperosColors.card(context),
      highlightColor: HyperosColors.rowHighlight(context),
      child: Padding(
        padding: hyperosChevronRowPadding(context),
        child: Row(
          children: [
            HyperosIconBadge(
              icon: Icons.event_available_rounded,
              accent: badgeColor,
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Text(
                          item.title.trim().isEmpty
                              ? l10n.scheduleBadgeLabel
                              : item.title,
                          style: HyperosTypography.listTitle(
                            context,
                          ).copyWith(color: mutedPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (recurrenceBadge != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: HyperosTag(label: recurrenceBadge),
                        ),
                      ],
                      if (entry.ongoing) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _OngoingBadge(dimmed: dimmed),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildScheduleMetaRow(context, l10n, entry, mutedSecondary),
                  if (location != null && location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _ScheduleMetaLine(
                      icon: Icons.place_outlined,
                      text: location,
                      color: mutedSecondary,
                    ),
                  ],
                  if (!dimmed && reminderMinutes != null) ...[
                    const SizedBox(height: 4),
                    _ScheduleMetaLine(
                      icon: Icons.notifications_active_outlined,
                      text: l10n.scheduleReminderMinutes(reminderMinutes),
                      color: mutedSecondary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: HyperosTokens.titleChevronGap),
            Opacity(
              opacity: dimmed ? 0.45 : 1,
              child: const HyperosChevron(),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('schedule-list-dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: HyperosColors.error(context),
        child: Icon(
          Icons.delete_outline_rounded,
          color: HyperosColors.onError(context),
        ),
      ),
      confirmDismiss: (_) => confirmDismiss(),
      onDismissed: (_) => onDismissed(),
      child: row,
    );
  }

  String? _recurrenceBadgeLabel(AppLocalizations l10n, ScheduleItem item) {
    return switch (item.recurrence) {
      ScheduleRecurrence.daily => l10n.scheduleRepeatDaily,
      ScheduleRecurrence.weekly => l10n.scheduleWeeklyWithDay(
        _weekdayLabel(l10n, item.startDate.weekday),
      ),
      ScheduleRecurrence.none => null,
    };
  }

  /// 元信息行：常规日程合并为「日期 · 时刻」单行灰字（参考样式）；
  /// 跨天单次日程的时刻标签已带首尾日期，单独成行避免与日期段重复。
  Widget _buildScheduleMetaRow(
    BuildContext context,
    AppLocalizations l10n,
    ScheduleListEntry entry,
    Color color,
  ) {
    final item = entry.item;
    if (_isCrossDayRange(item)) {
      return _ScheduleMetaLine(
        icon: Icons.event_outlined,
        text: _timeLabel(l10n, item),
        color: color,
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: _metaSegment(
            context,
            Icons.event_outlined,
            _dateLabel(l10n, entry),
            color,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '·',
            style: HyperosTypography.listDetail(context).copyWith(
              color: color,
            ),
          ),
        ),
        Flexible(
          child: _metaSegment(
            context,
            Icons.schedule_rounded,
            _timeLabel(l10n, item),
            color,
          ),
        ),
      ],
    );
  }

  Widget _metaSegment(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color.withValues(alpha: 0.85)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: HyperosTypography.listDetail(context).copyWith(
              color: color,
              height: 1.25,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  bool _isCrossDayRange(ScheduleItem item) {
    return !item.isRecurring &&
        ScheduleItem.dateOnly(item.endDate).isAfter(
          ScheduleItem.dateOnly(item.startDate),
        );
  }

  /// 时间行：同日日程「09:00 – 10:00」；跨天单次日程时刻各自带日期
  /// （「9月11日 08:00 – 9月14日 18:00」），否则一对时刻读起来像
  /// 「每天 08:00–18:00」，与连续区间语义相悖（用户反馈歧义）。
  String _timeLabel(AppLocalizations l10n, ScheduleItem item) {
    if (!_isCrossDayRange(item)) {
      return l10n.scheduleTimeRange(item.startTime, item.endTime);
    }
    final formatter = DateFormat.MMMd(l10n.localeName);
    return l10n.scheduleTimeRange(
      '${formatter.format(item.startDate)} ${item.startTime}',
      '${formatter.format(item.endDate)} ${item.endTime}',
    );
  }

  String _dateLabel(AppLocalizations l10n, ScheduleListEntry entry) {
    final item = entry.item;
    final formatter = DateFormat.MMMd(l10n.localeName);
    // 已过期行的下次发生日为空，回退展示结束日期（最近一次相关日）。
    final date = entry.nextDate ?? ScheduleItem.dateOnly(item.endDate);
    final dayLabel = formatter.format(date);
    final endsLater =
        !item.isRecurring &&
        ScheduleItem.dateOnly(item.endDate).isAfter(date);
    if (endsLater) {
      // 跨天日程：提前暴露完整区间（进行中的行同样落到这里，
      // 起点是过去的开始日；「进行中」状态由标题旁徽标承载）。
      return l10n.scheduleTimeRange(dayLabel, formatter.format(item.endDate));
    }
    return '$dayLabel ${_weekdayLabel(l10n, date.weekday)}';
  }

  String _weekdayLabel(AppLocalizations l10n, int weekday) {
    return [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ][weekday - 1];
  }
}

class _ScheduleMetaLine extends StatelessWidget {
  const _ScheduleMetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color.withValues(alpha: 0.85)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: HyperosTypography.listDetail(context).copyWith(
              color: color,
              height: 1.25,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 「进行中」状态徽标：绿点 + 绿字胶囊，紧贴标题展示（参考样式）。
class _OngoingBadge extends StatelessWidget {
  const _OngoingBadge({this.dimmed = false});

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const green = HyperosIconColors.green;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.scheduleOngoingLabel,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
