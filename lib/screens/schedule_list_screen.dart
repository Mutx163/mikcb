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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: HyperosIconBadge(
                icon: Icons.event_available_rounded,
                accent: badgeColor,
              ),
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ScheduleMetaLine(
                    icon: Icons.event_outlined,
                    text: _dateLabel(l10n, entry),
                    color: mutedSecondary,
                  ),
                  const SizedBox(height: 4),
                  _ScheduleMetaLine(
                    icon: Icons.schedule_rounded,
                    text: l10n.scheduleTimeRange(item.startTime, item.endTime),
                    color: mutedPrimary,
                    emphasis: !dimmed,
                  ),
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
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Opacity(
                opacity: dimmed ? 0.45 : 1,
                child: const HyperosChevron(),
              ),
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

  String _dateLabel(AppLocalizations l10n, ScheduleListEntry entry) {
    final item = entry.item;
    final formatter = DateFormat.MMMd(l10n.localeName);
    if (entry.ongoing) {
      // 跨天进行中：区间整体覆盖今天，展示起止日而非单日。
      final range = l10n.scheduleTimeRange(
        formatter.format(item.startDate),
        formatter.format(item.endDate),
      );
      return '${l10n.scheduleOngoingLabel} · $range';
    }
    // 已过期行的下次发生日为空，回退展示结束日期（最近一次相关日）。
    final date = entry.nextDate ?? ScheduleItem.dateOnly(item.endDate);
    final dayLabel = formatter.format(date);
    final endsLater =
        !item.isRecurring &&
        ScheduleItem.dateOnly(item.endDate).isAfter(date);
    if (endsLater) {
      // 未来开始的跨天日程：提前暴露完整区间。
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
    this.emphasis = false,
  });

  final IconData icon;
  final String text;
  final Color color;
  final bool emphasis;

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
            style:
                (emphasis
                        ? HyperosTypography.listTitle(context)
                        : HyperosTypography.listDetail(context))
                    .copyWith(
                      color: color,
                      fontSize: emphasis ? 15 : null,
                      fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
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
