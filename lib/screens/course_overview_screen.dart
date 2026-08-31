import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/enum_localizations.dart';
import 'package:provider/provider.dart';
import '../models/course.dart';
import '../providers/timetable_provider.dart';
import 'add_course_screen.dart';
import 'course_conflict_screen.dart';

enum _SortMode { name, schedule, added }

class CourseOverviewScreen extends StatefulWidget {
  const CourseOverviewScreen({super.key});

  @override
  State<CourseOverviewScreen> createState() => _CourseOverviewScreenState();
}

class _CourseOverviewScreenState extends State<CourseOverviewScreen> {
  _SortMode _sortMode = _SortMode.added;
  final GlobalKey _sortActionKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final groups = provider.courseGroups;
    final conflictMap = provider.courseConflictMap;

    final sorted = _sortGroups(List.of(groups));
    final conflictScheduleCount = conflictMap.length;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.courseOverviewTitle),
      suffixes: [
        KeyedSubtree(
          key: _sortActionKey,
          child: FHeaderAction(
            icon: const Icon(Icons.sort_rounded),
            semanticsLabel: l10n.sortAction,
            onPress: _showSortPopup,
          ),
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
                // Conflicts: single entry only — details live on the dedicated page.
                if (conflictScheduleCount > 0) ...[
                  HyperosListGroup(
                    children: [
                      HyperosListTile(
                        icon: Icons.warning_amber_rounded,
                        iconAccent: HyperosIconColors.orange,
                        title: l10n.courseConflictDetailEntryTitle,
                        details: l10n.conflictCountLabel(conflictScheduleCount),
                        onTap: () => _openConflictDetail(context),
                      ),
                    ],
                  ),
                  const HyperosSectionGap(),
                ],
                // Main course list: no section caption (this is the primary list).
                HyperosListGroup(
                  children: [
                    for (final group in sorted)
                      _CourseGroupTile(
                        group: group,
                        hasConflict: _groupHasConflict(group, conflictMap),
                        onTap: () => _navigateToEditGroup(context, group),
                      ),
                  ],
                ),
              ],
            ),
    );
  }

  void _openConflictDetail(BuildContext context) {
    Navigator.of(context).push(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/course/conflicts'),
        builder: (_) => const CourseConflictScreen(),
      ),
    );
  }

  bool _groupHasConflict(
    CourseGroup group,
    Map<String, List<Course>> conflictMap,
  ) {
    return group.courses.any((course) => conflictMap.containsKey(course.id));
  }

  List<CourseGroup> _sortGroups(List<CourseGroup> groups) {
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

  Future<void> _showSortPopup() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showHyperosSelectPopup<_SortMode>(
      context: context,
      anchorRect: hyperosSelectPopupAnchorRect(context, _sortActionKey),
      currentValue: _sortMode,
      items: {
        l10n.sortByAdded: _SortMode.added,
        l10n.sortByName: _SortMode.name,
        l10n.sortBySchedule: _SortMode.schedule,
      },
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _sortMode = selected);
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
    required this.hasConflict,
    required this.onTap,
  });

  final CourseGroup group;
  final bool hasConflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final primaryText = HyperosColors.primaryText(context);

    final row = hyperosListRowShell(
      padding: hyperosChevronRowPadding(context),
      minHeight: HyperosTokens.listRowTwoLineMinHeight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _displayName(group),
                        style: HyperosTypography.listTitle(
                          context,
                        ).copyWith(color: primaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasConflict) ...[
                      const SizedBox(width: 6),
                      HyperosTag(
                        label: l10n.conflictLabel,
                        backgroundColor: theme.colors.destructive.withValues(
                          alpha: 0.12,
                        ),
                        textStyle: HyperosTypography.listDetail(context)
                            .copyWith(
                              color: theme.colors.destructive,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitle(group, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HyperosTypography.listDetail(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            courseNatureLabel(l10n, group.courseNature),
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(width: HyperosTokens.titleChevronGap),
          const HyperosChevron(),
        ],
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
