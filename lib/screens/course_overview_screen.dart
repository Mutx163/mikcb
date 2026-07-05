import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../providers/timetable_provider.dart';
import '../utils/hex_color.dart';
import 'add_course_screen.dart';

enum _SortMode { name, schedule, added }

class CourseOverviewScreen extends StatefulWidget {
  const CourseOverviewScreen({super.key});

  @override
  State<CourseOverviewScreen> createState() => _CourseOverviewScreenState();
}

class _CourseOverviewScreenState extends State<CourseOverviewScreen> {
  _SortMode _sortMode = _SortMode.added;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final groups = provider.courseGroups;
    final conflictMap = provider.courseConflictMap;
    final conflictingCourseCount = conflictMap.length;

    final sorted = _sortGroups(List.of(groups), conflictMap);

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.courseOverviewTitle),
        suffixes: [
          _buildSortButton(l10n),
          FHeaderAction(
            icon: const Icon(Icons.add_rounded),
            semanticsLabel: l10n.addNewCourseTooltip,
            onPress: () => _navigateToAddCourse(context),
          ),
        ],
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: sorted.isEmpty
            ? _buildEmptyState(context, l10n)
            : Column(
                children: [
                  if (conflictingCourseCount > 0)
                    _buildConflictBanner(context, l10n, conflictingCourseCount),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        return _buildGroupCard(
                          context,
                          l10n,
                          sorted[index],
                          conflictMap,
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------

  List<CourseGroup> _sortGroups(
    List<CourseGroup> groups,
    Map<String, List<Course>> conflictMap,
  ) {
    switch (_sortMode) {
      case _SortMode.name:
        groups.sort((a, b) => a.name.compareTo(b.name));
      case _SortMode.schedule:
        groups.sort((a, b) {
          final dayCmp = a.earliestDayOfWeek.compareTo(b.earliestDayOfWeek);
          if (dayCmp != 0) return dayCmp;
          return a.earliestStartSection.compareTo(b.earliestStartSection);
        });
      case _SortMode.added:
        // keep provider order (insertion order)
        break;
    }
    return groups;
  }

  Widget _buildSortButton(AppLocalizations l10n) {
    return PopupMenuButton<_SortMode>(
      icon: const Icon(Icons.sort_rounded),
      tooltip: l10n.sortAction,
      onSelected: (mode) => setState(() => _sortMode = mode),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(
          value: _SortMode.added,
          checked: _sortMode == _SortMode.added,
          child: Text(l10n.sortByAdded),
        ),
        CheckedPopupMenuItem(
          value: _SortMode.name,
          checked: _sortMode == _SortMode.name,
          child: Text(l10n.sortByName),
        ),
        CheckedPopupMenuItem(
          value: _SortMode.schedule,
          checked: _sortMode == _SortMode.schedule,
          child: Text(l10n.sortBySchedule),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    final theme = context.theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 64,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text(l10n.emptyCourseOverviewHint, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FButton(
              variant: FButtonVariant.primary,
              onPress: () => _navigateToAddCourse(context),
              prefix: const Icon(Icons.add),
              child: Text(l10n.addNewCourseTooltip),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Conflict banner
  // ---------------------------------------------------------------------------

  Widget _buildConflictBanner(
    BuildContext context,
    AppLocalizations l10n,
    int count,
  ) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FCard.raw(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colors.destructive.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: theme.colors.destructive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: theme.colors.destructive,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.conflictDetectedMessage(count),
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.destructive,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Group card
  // ---------------------------------------------------------------------------

  Widget _buildGroupCard(
    BuildContext context,
    AppLocalizations l10n,
    CourseGroup group,
    Map<String, List<Course>> conflictMap,
  ) {
    final theme = context.theme;
    final courseColor = parseHexColorOrFallback(
      group.color,
      fallback: theme.colors.primary,
    );
    final hasConflict = group.courses.any((c) => conflictMap.containsKey(c.id));
    final chipLabels = group.scheduleChipLabels(l10n);

    final conflictCount = group.courses
        .where((c) => conflictMap.containsKey(c.id))
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: FCard.raw(
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _navigateToEditGroup(context, group),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: hasConflict
                      ? theme.colors.destructive.withValues(alpha: 0.35)
                      : theme.colors.border,
                  width: hasConflict ? 1.4 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            group.name +
                                (group.shortName != null &&
                                        group.shortName!.isNotEmpty
                                    ? ' (${group.shortName})'
                                    : ''),
                            style: theme.typography.body.lg.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildNatureChip(l10n, group.courseNature),
                        if (hasConflict) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colors.destructive.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.conflictCountLabel(conflictCount),
                              style: theme.typography.body.xs.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colors.destructive,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (group.teacher.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        group.teacher,
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: chipLabels
                          .map(
                            (label) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: courseColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: theme.typography.body.sm.copyWith(
                                  color: courseColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
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

  Widget _buildNatureChip(AppLocalizations l10n, CourseNature nature) {
    final theme = context.theme;
    final isRequired = nature == CourseNature.required;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isRequired
            ? theme.colors.primary.withValues(alpha: 0.12)
            : theme.colors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        nature.label,
        style: theme.typography.body.xs.copyWith(
          fontWeight: FontWeight.w600,
          color: isRequired
              ? theme.colors.primary
              : theme.colors.secondaryForeground,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _navigateToAddCourse(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/create'),
        builder: (_) => const AddCourseScreen(),
      ),
    );
  }

  void _navigateToEditGroup(BuildContext context, CourseGroup group) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: '/course/edit'),
        builder: (_) => AddCourseScreen(courseGroup: group),
      ),
    );
  }
}
