import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:provider/provider.dart';

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
    final theme = context.theme;

    final upcomingExams = exams.where((e) => !e.isExpired).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final pastExams = exams.where((e) => e.isExpired).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                children: [
                  if (upcomingExams.isNotEmpty) ...[
                    _buildNextExamCountdown(context, upcomingExams.first, l10n),
                    const SizedBox(height: 12),
                    ...upcomingExams.map(
                      (exam) => _buildExamCard(context, provider, exam, false),
                    ),
                  ],
                  if (pastExams.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: theme.colors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              l10n.examPassed,
                              style: theme.typography.body.sm.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: theme.colors.border)),
                        ],
                      ),
                    ),
                    ...pastExams.map(
                      (exam) => _buildExamCard(context, provider, exam, true),
                    ),
                  ],
                  const SizedBox(height: 80),
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

  Widget _buildNextExamCountdown(
    BuildContext context,
    Exam exam,
    AppLocalizations l10n,
  ) {
    final theme = context.theme;
    final daysUntil = exam.daysUntil;

    final countdownText = daysUntil == 0
        ? l10n.examToday
        : l10n.daysUntilExam(daysUntil);

    return HyperosCard(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, color: theme.colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                countdownText,
                style: theme.typography.body.md.copyWith(
                  color: theme.colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context,
    TimetableProvider provider,
    Exam exam,
    bool isPast,
  ) {
    final theme = context.theme;
    final course = provider.getCourseForExam(exam);
    final color = course != null
        ? _parseColor(course.color)
        : theme.colors.primary;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(exam.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: theme.colors.destructive,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline,
            color: theme.colors.destructiveForeground,
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context, exam, l10n),
        onDismissed: (_) => provider.deleteExam(exam.id),
        child: HyperosCard(
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToEditExam(context, exam),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isPast ? color.withValues(alpha: 0.3) : color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.name,
                            style: theme.typography.body.md.copyWith(
                              color: isPast
                                  ? theme.colors.mutedForeground
                                  : null,
                              decoration: isPast
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (course != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  course.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.body.xs.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            _formatExamDateTime(exam, provider, l10n),
                            style: theme.typography.body.sm.copyWith(
                              color: theme.colors.mutedForeground,
                            ),
                          ),
                          if (exam.location?.isNotEmpty == true ||
                              (exam.location == null &&
                                  course?.location.isNotEmpty == true))
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                exam.location ?? course!.location,
                                style: theme.typography.body.xs.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                          if (exam.seatNumber?.isNotEmpty == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '${l10n.examSeatLabel}: ${exam.seatNumber}',
                                style: theme.typography.body.xs.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                          if (course != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${course.teacher} · ${course.weekDescription(l10n)}',
                                style: theme.typography.body.xs.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatExamDateTime(
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
        weekInfo = '${l10n.weekLabel(weekIndex)} ';
      }
    }

    return '$weekInfo$datePart $weekday ${exam.startTime}-${exam.endTime}';
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

  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    final value = int.parse(cleaned, radix: 16);
    if (cleaned.length == 6) {
      return Color(0xFF000000 | value);
    }
    return Color(value);
  }
}
