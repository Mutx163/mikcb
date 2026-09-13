import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/os4_glass_backdrop.dart';
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

  /// 「排序」选择弹层的常驻状态。上游 OS4 弹层的契约是「常驻挂载 + 切 show」，
  /// 所以由宿主持有 show 与锚定矩形，而不是 await 一个路由的返回值。
  bool _sortPopupOpen = false;
  Rect? _sortAnchorRect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final groups = provider.courseGroups;
    final conflictMap = provider.courseConflictMap;

    final sorted = _sortGroups(List.of(groups));
    final conflictScheduleCount = conflictMap.length;

    return Stack(
      children: [
        // 弹层玻璃要从「宿主页内容」采样，故页面内容包一层捕获；
        // **弹层留在捕获之外**（上游要求捕获子树不含玻璃自身，防反馈采样）。
        MiuixLayerBackdropCapture(
          backdrop: os4GlassBackdrop,
          child: HyperosSubpage(
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
        ),
        ),
        // 「排序」选择弹层：常驻挂载、由 _sortPopupOpen 切 show。
        HyperosSelectPopup<_SortMode>(
          show: _sortPopupOpen,
          anchorRect: _sortAnchorRect ?? Rect.zero,
          currentValue: _sortMode,
          items: {
            l10n.sortByAdded: _SortMode.added,
            l10n.sortByName: _SortMode.name,
            l10n.sortBySchedule: _SortMode.schedule,
          },
          onSelected: _onSortSelected,
          onDismiss: () {
            if (_sortPopupOpen) {
              setState(() => _sortPopupOpen = false);
            }
          },
        ),
      ],
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

  /// 打开「排序」选择弹层。
  ///
  /// 2026-09-13：选择弹层改用上游 OS4 锚定弹层后，必须按上游契约
  /// 「**常驻挂载 + 切 show**」使用 —— 弹层**不自己 pop 任何路由**。
  /// 上一版把它塞进 `showGeneralDialog` 且 show 恒 true，导致弹层内部关闭记账
  /// 与路由栈错位：点条目会 pop 掉宿主页、点空白也关不掉，故改为本形态。
  void _showSortPopup() {
    setState(() {
      _sortAnchorRect = hyperosSelectPopupAnchorRect(context, _sortActionKey);
      _sortPopupOpen = true;
    });
  }

  void _onSortSelected(_SortMode mode) {
    setState(() {
      _sortMode = mode;
      _sortPopupOpen = false;
    });
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
