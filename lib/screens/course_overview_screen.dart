import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
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
      child: sorted.isEmpty
          ? _buildEmptyState(context, l10n)
          : HyperosListView(
              children: [
                if (conflictingCourseCount > 0) ...[
                  _buildConflictBanner(context, l10n, conflictingCourseCount),
                  const HyperosSectionGap(),
                ],
                HyperosListGroup(
                  children: [
                    for (final group in sorted)
                      _CourseGroupTile(
                        group: group,
                        conflictMap: conflictMap,
                        onTap: () => _navigateToEditGroup(context, group),
                      ),
                  ],
                ),
              ],
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
    await showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: l10n.sortAction,
        child: HyperosChoiceGroup(
          children: [
            HyperosChoiceTile(
              title: l10n.sortByAdded,
              selected: _sortMode == _SortMode.added,
              onTap: () {
                setState(() => _sortMode = _SortMode.added);
                Navigator.of(sheetContext).pop();
              },
            ),
            HyperosChoiceTile(
              title: l10n.sortByName,
              selected: _sortMode == _SortMode.name,
              onTap: () {
                setState(() => _sortMode = _SortMode.name);
                Navigator.of(sheetContext).pop();
              },
            ),
            HyperosChoiceTile(
              title: l10n.sortBySchedule,
              selected: _sortMode == _SortMode.schedule,
              onTap: () {
                setState(() => _sortMode = _SortMode.schedule);
                Navigator.of(sheetContext).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 56,
              color: HyperosColors.secondaryText(context),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.emptyCourseOverviewHint,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context),
            ),
            const SizedBox(height: 20),
            HyperosButton(
              label: l10n.addNewCourseTooltip,
              onPressed: () => _navigateToAddCourse(context),
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
    return HyperosListGroup(
      children: [
        HyperosPressableRow(
          backgroundColor: HyperosColors.card(context),
          highlightColor: HyperosColors.rowHighlight(context),
          child: Padding(
            padding: HyperosTokens.rowPaddingUniform,
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: theme.colors.destructive,
                ),
                const SizedBox(width: HyperosTokens.rowContentGap),
                Expanded(
                  child: Text(
                    l10n.conflictDetectedMessage(count),
                    style: HyperosTypography.listTitle(context).copyWith(
                      color: theme.colors.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToAddCourse(BuildContext context) {
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/create'),
        builder: (_) => const AddCourseScreen(),
      ),
    );
  }

  void _navigateToEditGroup(BuildContext context, CourseGroup group) {
    Navigator.push(
      context,
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/edit'),
        builder: (_) => AddCourseScreen(courseGroup: group),
      ),
    );
  }
}

class _CourseGroupTile extends StatelessWidget {
  const _CourseGroupTile({
    required this.group,
    required this.conflictMap,
    required this.onTap,
  });

  final CourseGroup group;
  final Map<String, List<Course>> conflictMap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final scope = HyperosListTileScope.maybeOf(context);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPadding(
          isFirst: scope?.isFirst ?? true,
          isLast: scope?.isLast ?? true,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
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
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _displayName(group),
                    style: HyperosTypography.listTitle(context),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(group, l10n),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: HyperosTypography.listDetail(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              hasConflict
                  ? l10n.conflictCountLabel(conflictCount)
                  : group.courseNature.label,
              style: HyperosTypography.listDetail(context).copyWith(
                fontWeight: hasConflict ? FontWeight.w700 : FontWeight.w400,
                color: hasConflict
                    ? theme.colors.destructive
                    : HyperosColors.secondaryText(context),
              ),
            ),
            SizedBox(width: HyperosTokens.titleChevronGap),
            const HyperosChevron(),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: onTap,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }

  static String _displayName(CourseGroup group) {
    final shortName = group.shortName;
    if (shortName != null && shortName.isNotEmpty) {
      return '${group.name} ($shortName)';
    }
    return group.name;
  }

  static String _subtitle(CourseGroup group, AppLocalizations l10n) {
    final schedules = group.scheduleChipLabels(l10n).join(' · ');
    if (group.teacher.isEmpty) {
      return schedules;
    }
    return '${group.teacher} · $schedules';
  }
}
