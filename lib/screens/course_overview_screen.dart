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
          FHeaderAction(
            icon: const Icon(Icons.sort_rounded),
            semanticsLabel: l10n.sortAction,
            onPress: _showSortSheet,
          ),
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
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (conflictingCourseCount > 0) ...[
                    _buildConflictBanner(context, l10n, conflictingCourseCount),
                    const SizedBox(height: 12),
                  ],
                  FTileGroup(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      for (final group in sorted)
                        _buildCourseTile(context, l10n, group, conflictMap),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

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
        break;
    }
    return groups;
  }

  Future<void> _showSortSheet() async {
    final l10n = AppLocalizations.of(context)!;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      useSafeArea: true,
      draggable: true,
      builder: (sheetContext) {
        final theme = sheetContext.theme;
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colors.background,
            border: Border(top: BorderSide(color: theme.colors.border)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: FTileGroup(
                label: Text(l10n.sortAction),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSortOptionTile(
                    sheetContext,
                    l10n.sortByAdded,
                    _SortMode.added,
                  ),
                  _buildSortOptionTile(
                    sheetContext,
                    l10n.sortByName,
                    _SortMode.name,
                  ),
                  _buildSortOptionTile(
                    sheetContext,
                    l10n.sortBySchedule,
                    _SortMode.schedule,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  FTile _buildSortOptionTile(
    BuildContext context,
    String label,
    _SortMode mode,
  ) {
    final selected = _sortMode == mode;
    return FTile(
      title: Text(label),
      suffix: selected
          ? Icon(
              Icons.check_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onPress: () {
        setState(() => _sortMode = mode);
        Navigator.of(context).pop();
      },
    );
  }

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
              size: 56,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.emptyCourseOverviewHint,
              textAlign: TextAlign.center,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 20),
            FButton(
              onPress: () => _navigateToAddCourse(context),
              prefix: const Icon(Icons.add_rounded, size: 18),
              child: Text(l10n.addNewCourseTooltip),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictBanner(
    BuildContext context,
    AppLocalizations l10n,
    int count,
  ) {
    final theme = context.theme;
    return FTileGroup(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        FTile(
          prefix: Icon(
            Icons.warning_amber_rounded,
            color: theme.colors.destructive,
          ),
          title: Text(
            l10n.conflictDetectedMessage(count),
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.destructive,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  FTile _buildCourseTile(
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
    final conflictCount = group.courses
        .where((c) => conflictMap.containsKey(c.id))
        .length;
    final initial = group.name.isNotEmpty ? group.name[0] : '?';

    return FTile(
      prefix: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: courseColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: hasConflict
              ? Border.all(
                  color: theme.colors.destructive.withValues(alpha: 0.55),
                  width: 1.5,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: theme.typography.body.sm.copyWith(
            color: courseColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(_groupDisplayName(group)),
      subtitle: Text(
        _groupSubtitle(group, l10n),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      details: hasConflict
          ? Text(
              l10n.conflictCountLabel(conflictCount),
              style: theme.typography.body.xs.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colors.destructive,
              ),
            )
          : Text(
              group.courseNature.label,
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
      suffix: const Icon(Icons.chevron_right_rounded),
      onPress: () => _navigateToEditGroup(context, group),
    );
  }

  String _groupDisplayName(CourseGroup group) {
    final shortName = group.shortName;
    if (shortName != null && shortName.isNotEmpty) {
      return '${group.name} ($shortName)';
    }
    return group.name;
  }

  String _groupSubtitle(CourseGroup group, AppLocalizations l10n) {
    final schedules = group.scheduleChipLabels(l10n).join(' · ');
    if (group.teacher.isEmpty) {
      return schedules;
    }
    return '${group.teacher} · $schedules';
  }

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
