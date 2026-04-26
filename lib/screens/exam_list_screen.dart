import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
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

    final upcomingExams = exams.where((e) => !e.isExpired).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final pastExams = exams.where((e) => e.isExpired).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.examListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addExam,
            onPressed: () => _navigateToAddExam(context),
          ),
        ],
      ),
      body: exams.isEmpty
          ? _buildEmptyState(context, l10n)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            l10n.examPassed,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline,
                                ),
                          ),
                        ),
                        const Expanded(child: Divider()),
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
      floatingActionButton: exams.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _navigateToAddExam(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noExams,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _navigateToAddExam(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.addExam),
          ),
        ],
      ),
    );
  }

  Widget _buildNextExamCountdown(
    BuildContext context,
    Exam exam,
    AppLocalizations l10n,
  ) {
    final daysUntil = exam.daysUntil;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    String countdownText;
    if (daysUntil == 0) {
      countdownText = l10n.examToday;
    } else {
      countdownText = l10n.daysUntilExam(daysUntil);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: colorScheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              countdownText,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(
    BuildContext context,
    TimetableProvider provider,
    Exam exam,
    bool isPast,
  ) {
    final course = provider.getCourseForExam(exam);
    final color = course != null
        ? _parseColor(course.color)
        : Theme.of(context).colorScheme.primary;
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
            color: Theme.of(context).colorScheme.error,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.onError,
          ),
        ),
        confirmDismiss: (_) => _confirmDelete(context, exam, l10n),
        onDismissed: (_) => provider.deleteExam(exam.id),
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _navigateToEditExam(context, exam),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 56,
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: isPast
                                    ? Theme.of(context)
                                        .colorScheme
                                        .outline
                                    : null,
                                decoration:
                                    isPast ? TextDecoration.lineThrough : null,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatExamDateTime(exam),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        if (exam.location?.isNotEmpty == true ||
                            (exam.location == null &&
                                course?.location.isNotEmpty == true))
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              exam.location ?? course!.location,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                            ),
                          ),
                        if (exam.seatNumber?.isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '座位: ${exam.seatNumber}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                            ),
                          ),
                        if (course != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${course.teacher} · ${course.weekDescription}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
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
    );
  }

  String _formatExamDateTime(Exam exam) {
    final date = exam.dateTime;
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[date.weekday - 1];
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month月$day日 $weekday ${exam.startTime}-${exam.endTime}';
  }

  Future<bool?> _confirmDelete(
    BuildContext context,
    Exam exam,
    AppLocalizations l10n,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteExam),
        content: Text(l10n.deleteExamConfirm(exam.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
  }

  void _navigateToAddExam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/exams/add'),
        builder: (_) => const AddExamScreen(),
      ),
    );
  }

  void _navigateToEditExam(BuildContext context, Exam exam) {
    Navigator.push(
      context,
      MaterialPageRoute(
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