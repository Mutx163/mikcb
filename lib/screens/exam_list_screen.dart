import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:provider/provider.dart';

import '../models/course.dart';
import '../models/exam.dart';
import '../providers/timetable_provider.dart';
import 'add_exam_screen.dart';

class ExamListScreen extends StatelessWidget {
  const ExamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimetableProvider>();
    final exams = provider.exams;
    final l10n = AppLocalizations.of(context)!;

    final upcomingExams = exams.where((e) => !e.isExpired).toList()
      ..sort(Exam.compareByStart);
    final pastExams = exams.where((e) => e.isExpired).toList()
      ..sort((a, b) => Exam.compareByStart(b, a));
    final todayExamCount = upcomingExams.where((e) => e.daysUntil == 0).length;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.examListTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.add_rounded),
          semanticsLabel: l10n.addExam,
          onPress: () => _navigateToAddExam(context),
        ),
      ],
      child: Material(
        type: MaterialType.transparency,
        color: HyperosColors.scaffoldBackground(context),
        child: exams.isEmpty
            ? _buildEmptyState(context, l10n)
            : HyperosListView(
                children: [
                  if (upcomingExams.isNotEmpty) ...[
                    _ExamOverviewCard(
                      exam: upcomingExams.first,
                      todayExamCount: todayExamCount,
                      upcomingCount: upcomingExams.length,
                      dateLabel: _formatExamDate(
                        upcomingExams.first,
                        provider,
                        l10n,
                      ),
                      onTap: () =>
                          _navigateToEditExam(context, upcomingExams.first),
                    ),
                    const HyperosSectionGap(),
                    HyperosListGroup(
                      children: [
                        for (final exam in upcomingExams)
                          _ExamListRow(
                            exam: exam,
                            course: provider.getCourseForExam(exam),
                            isPast: false,
                            dateLabel: _formatExamDate(exam, provider, l10n),
                            onTap: () => _navigateToEditExam(context, exam),
                            onDismissed: () => provider.deleteExam(exam.id),
                            confirmDismiss: () =>
                                _confirmDelete(context, exam, l10n),
                          ),
                      ],
                    ),
                  ],
                  if (pastExams.isNotEmpty) ...[
                    if (upcomingExams.isNotEmpty) const HyperosSectionGap(),
                    HyperosSectionLabel(text: l10n.examPassed),
                    HyperosListGroup(
                      children: [
                        for (final exam in pastExams)
                          _ExamListRow(
                            exam: exam,
                            course: provider.getCourseForExam(exam),
                            isPast: true,
                            dateLabel: _formatExamDate(exam, provider, l10n),
                            onTap: () => _navigateToEditExam(context, exam),
                            onDismissed: () => provider.deleteExam(exam.id),
                            confirmDismiss: () =>
                                _confirmDelete(context, exam, l10n),
                          ),
                      ],
                    ),
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
          icon: Icons.school_outlined,
          title: l10n.noExams,
          action: HyperosButton(
            label: l10n.addExam,
            onPressed: () => _navigateToAddExam(context),
          ),
        ),
      ),
    );
  }

  String _formatExamDate(
    Exam exam,
    TimetableProvider provider,
    AppLocalizations l10n,
  ) {
    final date = exam.dateTime;
    final weekdays = [
      l10n.weekdayMon,
      l10n.weekdayTue,
      l10n.weekdayWed,
      l10n.weekdayThu,
      l10n.weekdayFri,
      l10n.weekdaySat,
      l10n.weekdaySun,
    ];
    final weekday = weekdays[date.weekday - 1];
    final datePart = DateFormat.MMMd(l10n.localeName).format(date);

    var weekInfo = '';
    final semesterStart = provider.semesterStartDate;
    if (semesterStart != null) {
      final weekIndex = provider.getWeekIndex(date, semesterStart);
      if (weekIndex != null && weekIndex >= 1) {
        weekInfo = '${l10n.weekLabel(weekIndex)} · ';
      }
    }

    return '$weekInfo$datePart $weekday';
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    Exam exam,
    AppLocalizations l10n,
  ) {
    return showHyperosConfirmDialog(
      context: context,
      title: l10n.deleteExam,
      message: l10n.deleteExamConfirm(exam.name),
      cancelLabel: l10n.cancelAction,
      confirmLabel: l10n.deleteAction,
      destructive: true,
    );
  }

  void _navigateToAddExam(BuildContext context) {
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/exams/add'),
        builder: (_) => const AddExamScreen(),
      ),
    );
  }

  void _navigateToEditExam(BuildContext context, Exam exam) {
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/exams/edit'),
        builder: (_) => AddExamScreen(exam: exam),
      ),
    );
  }
}

enum _ExamLivePhase { before, ongoing, after }

_ExamLivePhase _resolveExamLivePhase(Exam exam, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final start = exam.examStartDateTime;
  final endParts = Exam.parseTimeOfDayParts(
    exam.endTime,
    fallbackHour: 23,
    fallbackMinute: 59,
  );
  final end = DateTime(
    exam.dateTime.year,
    exam.dateTime.month,
    exam.dateTime.day,
    endParts.$1,
    endParts.$2,
  );
  if (current.isBefore(start)) {
    return _ExamLivePhase.before;
  }
  if (current.isBefore(end) || current.isAtSameMomentAs(end)) {
    return _ExamLivePhase.ongoing;
  }
  return _ExamLivePhase.after;
}

String _examReminderSummary(AppLocalizations l10n, Exam exam) {
  final minutes = exam.effectiveReminderMinutes;
  if (minutes.isEmpty) {
    return l10n.examOverviewReminderOff;
  }
  if (exam.reminderPreset != ExamReminderPreset.custom) {
    return examReminderPresetLabel(l10n, exam.reminderPreset);
  }
  final labels = minutes.take(2).map((value) {
    return _examReminderOffsetLabel(l10n, value);
  }).toList();
  if (minutes.length > 2) {
    labels.add('+${minutes.length - 2}');
  }
  return labels.join(' · ');
}

String _examReminderOffsetLabel(AppLocalizations l10n, int minutes) {
  if (minutes > 0 && minutes % 1440 == 0) {
    return l10n.examReminderOffsetDays(minutes ~/ 1440);
  }
  if (minutes > 0 && minutes % 60 == 0) {
    return l10n.examReminderOffsetHours(minutes ~/ 60);
  }
  final days = minutes ~/ 1440;
  final hours = (minutes % 1440) ~/ 60;
  final remainMinutes = minutes % 60;
  if (days > 0 || hours > 0) {
    return [
      if (days > 0) l10n.examReminderOffsetDays(days),
      if (hours > 0) l10n.examReminderOffsetHours(hours),
      if (remainMinutes > 0) l10n.examReminderOffsetMinutes(remainMinutes),
    ].join(' + ');
  }
  return l10n.examReminderOffsetMinutes(minutes);
}

/// Nearest-exam overview: quiet HyperOS card, no logo / no colored hero block.
class _ExamOverviewCard extends StatelessWidget {
  const _ExamOverviewCard({
    required this.exam,
    required this.todayExamCount,
    required this.upcomingCount,
    required this.dateLabel,
    required this.onTap,
  });

  final Exam exam;
  final int todayExamCount;
  final int upcomingCount;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryText = HyperosColors.primaryText(context);
    final secondaryText = HyperosColors.secondaryText(context);
    final daysUntil = exam.daysUntil;
    final livePhase = _resolveExamLivePhase(exam);
    final isToday = daysUntil == 0;
    final isLive = livePhase == _ExamLivePhase.ongoing;

    final statusLabel = switch (livePhase) {
      _ExamLivePhase.ongoing => l10n.examOverviewInProgress,
      _ExamLivePhase.before when isToday => l10n.examToday,
      _ExamLivePhase.before => l10n.daysUntilExam(daysUntil),
      _ExamLivePhase.after => l10n.examPassed,
    };

    final examName = exam.name.trim().isEmpty
        ? l10n.examNameLabel
        : exam.name.trim();
    final timeRange = l10n.examTimeRange(exam.startTime, exam.endTime);
    final location = exam.location?.trim();
    final seat = exam.seatNumber?.trim();
    final reminderEnabled = exam.effectiveReminderMinutes.isNotEmpty;
    final reminderLabel = _examReminderSummary(l10n, exam);

    final secondaryBits = <String>[
      dateLabel,
      if (location != null && location.isNotEmpty) location,
      if (seat != null && seat.isNotEmpty) '${l10n.examSeatLabel} $seat',
    ];

    final statusAccent = isLive || isToday
        ? HyperosColors.primary(context)
        : secondaryText;

    return HyperosAdaptiveCard(
      color: HyperosColors.card(context),
      child: HyperosPressableRow(
        onTap: onTap,
        holdHighlightThroughTransition: true,
        backgroundColor: HyperosColors.card(context),
        highlightColor: HyperosColors.rowHighlight(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: HyperosTypography.listDetail(context).copyWith(
                        color: statusAccent,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (todayExamCount > 0)
                    Text(
                      l10n.examOverviewTodayCount(todayExamCount),
                      style: HyperosTypography.listDetail(
                        context,
                      ).copyWith(color: secondaryText, fontSize: 12),
                    )
                  else if (upcomingCount > 1)
                    Text(
                      l10n.examOverviewUpcomingCount(upcomingCount),
                      style: HyperosTypography.listDetail(
                        context,
                      ).copyWith(color: secondaryText, fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                examName,
                style: HyperosTypography.listTitle(context).copyWith(
                  color: primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                isLive ? l10n.examOverviewUntilTime(exam.endTime) : timeRange,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  height: 1.15,
                  letterSpacing: -0.4,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isLive) ...[
                const SizedBox(height: 4),
                Text(
                  timeRange,
                  style: HyperosTypography.listDetail(
                    context,
                  ).copyWith(color: secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (secondaryBits.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  secondaryBits.join('  ·  '),
                  style: HyperosTypography.listDetail(
                    context,
                  ).copyWith(color: secondaryText, height: 1.35),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Container(height: 1, color: HyperosColors.dividerLine(context)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    reminderEnabled
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    size: 16,
                    color: secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reminderEnabled
                          ? '${l10n.examOverviewReminderOn}  ·  $reminderLabel'
                          : l10n.examOverviewReminderOff,
                      style: HyperosTypography.listDetail(
                        context,
                      ).copyWith(color: secondaryText, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isLive && !isToday && daysUntil > 0) ...[
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$daysUntil',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' ${l10n.examOverviewCountdownUnit}',
                            style: HyperosTypography.listDetail(
                              context,
                            ).copyWith(color: secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamMetaLine extends StatelessWidget {
  const _ExamMetaLine({
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

class _ExamListRow extends StatelessWidget {
  const _ExamListRow({
    required this.exam,
    required this.course,
    required this.isPast,
    required this.dateLabel,
    required this.onTap,
    required this.onDismissed,
    required this.confirmDismiss,
  });

  final Exam exam;
  final Course? course;
  final bool isPast;
  final String dateLabel;
  final VoidCallback onTap;
  final VoidCallback onDismissed;
  final Future<bool?> Function() confirmDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final primaryText = HyperosColors.primaryText(context);
    final secondaryText = HyperosColors.secondaryText(context);
    final mutedPrimary = primaryText.withValues(alpha: isPast ? 0.45 : 1);
    final mutedSecondary = secondaryText.withValues(alpha: isPast ? 0.55 : 1);
    final accent = course != null
        ? _parseColor(course!.color)
        : HyperosIconColors.blue;
    final livePhase = isPast
        ? _ExamLivePhase.after
        : _resolveExamLivePhase(exam);

    final location = exam.location?.trim().isNotEmpty == true
        ? exam.location!.trim()
        : course?.location.trim();
    final metaParts = <String>[
      if (location != null && location.isNotEmpty) location,
      if (exam.seatNumber?.trim().isNotEmpty == true)
        '${l10n.examSeatLabel} ${exam.seatNumber!.trim()}',
      if (course != null && course!.teacher.trim().isNotEmpty)
        course!.teacher.trim(),
    ];

    final countdownBadge = !isPast
        ? switch (livePhase) {
            _ExamLivePhase.ongoing => l10n.examOverviewLiveBadge,
            _ExamLivePhase.before when exam.daysUntil == 0 =>
              l10n.examCountdownToday,
            _ExamLivePhase.before => l10n.examCountdownDays(exam.daysUntil),
            _ExamLivePhase.after => null,
          }
        : null;

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
                icon: Icons.school_rounded,
                accent: isPast ? accent.withValues(alpha: 0.45) : accent,
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
                          exam.name,
                          style: HyperosTypography.listTitle(
                            context,
                          ).copyWith(color: mutedPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (countdownBadge != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: HyperosTag(
                            label: countdownBadge,
                            backgroundColor: livePhase == _ExamLivePhase.ongoing
                                ? HyperosIconColors.orange.withValues(
                                    alpha: 0.14,
                                  )
                                : null,
                            textStyle: livePhase == _ExamLivePhase.ongoing
                                ? const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: HyperosIconColors.orange,
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (course != null) ...[
                    const SizedBox(height: HyperosTokens.titleCaptionGap),
                    Text(
                      course!.name,
                      style: HyperosTypography.listDetail(
                        context,
                      ).copyWith(color: mutedSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _ExamMetaLine(
                    icon: Icons.event_outlined,
                    text: dateLabel,
                    color: mutedSecondary,
                  ),
                  const SizedBox(height: 4),
                  _ExamMetaLine(
                    icon: Icons.schedule_rounded,
                    text: l10n.examTimeRange(exam.startTime, exam.endTime),
                    color: mutedPrimary,
                    emphasis: !isPast,
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _ExamMetaLine(
                      icon: Icons.place_outlined,
                      text: metaParts.join(' · '),
                      color: mutedSecondary,
                    ),
                  ],
                  if (!isPast && exam.effectiveReminderMinutes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _ExamMetaLine(
                      icon: Icons.notifications_active_outlined,
                      text: _examReminderSummary(l10n, exam),
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
                opacity: isPast ? 0.45 : 1,
                child: const HyperosChevron(),
              ),
            ),
          ],
        ),
      ),
    );

    return Dismissible(
      key: ValueKey(exam.id),
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

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(cleaned, radix: 16);
    if (cleaned.length == 6) {
      return Color(0xFF000000 | value);
    }
    return Color(value);
  }
}
