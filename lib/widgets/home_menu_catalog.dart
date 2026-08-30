import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/about_screen.dart';
import 'package:university_timetable/screens/add_course_screen.dart';
import 'package:university_timetable/screens/add_exam_screen.dart';
import 'package:university_timetable/screens/add_schedule_item_screen.dart';
import 'package:university_timetable/screens/add_task_screen.dart';
import 'package:university_timetable/screens/advanced_material_settings_screen.dart';
import 'package:university_timetable/screens/changelog_screen.dart';
import 'package:university_timetable/screens/cloud_sync_screen.dart';
import 'package:university_timetable/screens/couple_timetable_settings_screen.dart';
import 'package:university_timetable/screens/course_conflict_screen.dart';
import 'package:university_timetable/screens/course_import_screen.dart';
import 'package:university_timetable/screens/course_overview_screen.dart';
import 'package:university_timetable/screens/course_statistics_screen.dart';
import 'package:university_timetable/screens/data_transfer_screen.dart';
import 'package:university_timetable/screens/exam_list_screen.dart';
import 'package:university_timetable/screens/feedback_screen.dart';
import 'package:university_timetable/screens/ics_export_screen.dart';
import 'package:university_timetable/screens/lan_edit_screen.dart';
import 'package:university_timetable/screens/location_time_match_screen.dart';
import 'package:university_timetable/screens/memory_stats_screen.dart';
import 'package:university_timetable/screens/open_source_licenses_screen.dart';
import 'package:university_timetable/screens/schedule_date_rule_screen.dart';
import 'package:university_timetable/screens/statistics_settings_screen.dart';
import 'package:university_timetable/screens/support_creator_screen.dart';
import 'package:university_timetable/screens/task_list_screen.dart';
import 'package:university_timetable/screens/time_scheme_management_screen.dart';
import 'package:university_timetable/screens/timetable_profiles_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/screens/user_guide_screen.dart';
import 'package:university_timetable/services/memory_stats_service.dart';
import 'package:university_timetable/widgets/course_recolor_sheet.dart';
import 'package:university_timetable/widgets/home_top_menu.dart';
import 'package:university_timetable/widgets/profile_quick_switch_sheet.dart';

export 'home_top_menu.dart'
    show HomeMenuEntry, HomeMenuEntryCategory, homeMenuEntryCategoryLabel;

/// 八宫格候选目录：应用内所有适合作为独立入口的二级页面与功能。
///
/// 原则：
/// - 只收「点进去就有用」的完整页面；中间态流程页（如扫码发送需要先
///   携带 payload）与调试/演示页不收；
/// - 内置九项沿用旧的 id（旧列表菜单的动作名），老用户已保存的
///   排列无需迁移；addCourse 与 update 的实际导航仍由首页宿主处理，
///   以保留日视图选中日期、更新检查等上下文；
/// - 新增入口只要在 [kHomeMenuCatalog] 追加一条即可进入编辑器候选。
final List<HomeMenuEntry> kHomeMenuCatalog = [
  // ── 功能入口 ──────────────────────────────────────────────
  HomeMenuEntry(
    id: 'update',
    title: (l10n) => l10n.homeMenuUpdateTitle,
    icon: Icons.system_update_alt_rounded,
    category: HomeMenuEntryCategory.features,
    // 宿主拦截后才会走这里；兜底直开更新详情页。
    open: (context) async {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!context.mounted) return;
      await pushHomeMenuPage(
        context,
        AboutUpdateScreen(packageInfo: packageInfo),
      );
    },
  ),
  HomeMenuEntry(
    id: 'overview',
    title: (l10n) => l10n.homeMenuOverviewTitle,
    icon: Icons.dashboard_customize_rounded,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const CourseOverviewScreen()),
  ),
  HomeMenuEntry(
    id: 'statistics',
    title: (l10n) => l10n.homeMenuStatisticsTitle,
    icon: Icons.bar_chart_rounded,
    category: HomeMenuEntryCategory.features,
    open: (context) =>
        pushHomeMenuPage(context, const CourseStatisticsScreen()),
  ),
  HomeMenuEntry(
    id: 'addCourse',
    title: (l10n) => l10n.homeMenuAddCourseTitle,
    icon: Icons.add_circle_outline_rounded,
    category: HomeMenuEntryCategory.features,
    // 首页宿主优先处理（弹出带日期上下文的添加弹层）；此处兜底直开表单。
    open: (context) => pushHomeMenuPage(context, const AddCourseScreen()),
  ),
  HomeMenuEntry(
    id: 'exams',
    title: (l10n) => l10n.examListTitle,
    icon: Icons.school_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const ExamListScreen()),
  ),
  HomeMenuEntry(
    id: 'importCourses',
    title: (l10n) => l10n.homeMenuImportTitle,
    icon: Icons.file_upload_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const CourseImportScreen()),
  ),
  HomeMenuEntry(
    id: 'courseRecolor',
    title: (l10n) => l10n.courseRecolorTileTitle,
    icon: Icons.style_rounded,
    category: HomeMenuEntryCategory.features,
    // 直接弹「课表重新配色」弹层（非页面）：八宫格/底栏圆钮/坞 Tab 的
    // 分发都走 entry.open，弹层在当前页上方浮现，空课表时内部 toast 提示。
    open: showCourseRecolorSheet,
  ),
  HomeMenuEntry(
    id: 'tasks',
    title: (l10n) => l10n.homeMenuTasksTitle,
    icon: Icons.checklist_rounded,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const TaskListScreen()),
  ),
  HomeMenuEntry(
    id: 'addExam',
    title: (l10n) => l10n.addExam,
    icon: Icons.event_note_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const AddExamScreen()),
  ),
  HomeMenuEntry(
    id: 'addTask',
    title: (l10n) => l10n.addTask,
    icon: Icons.add_task_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const AddTaskScreen()),
  ),
  HomeMenuEntry(
    id: 'addScheduleItem',
    title: (l10n) => l10n.addScheduleTitle,
    icon: Icons.event_available_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) =>
        pushHomeMenuPage(context, const AddScheduleItemScreen()),
  ),
  HomeMenuEntry(
    id: 'courseConflict',
    title: (l10n) => l10n.courseConflictDetailTitle,
    icon: Icons.rule_rounded,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const CourseConflictScreen()),
  ),
  HomeMenuEntry(
    id: 'locationTimeMatch',
    title: (l10n) => l10n.locationTimeMatchTitle,
    icon: Icons.location_on_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) =>
        pushHomeMenuPage(context, const LocationTimeMatchScreen()),
  ),
  HomeMenuEntry(
    id: 'scheduleDateRule',
    title: (l10n) => l10n.scheduleDateRuleSectionTitle,
    icon: Icons.event_repeat_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) =>
        pushHomeMenuPage(context, const ScheduleDateRuleScreen()),
  ),
  HomeMenuEntry(
    id: 'icsExport',
    title: (l10n) => l10n.icsExportTitle,
    icon: Icons.calendar_month_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) => pushHomeMenuPage(context, const IcsExportScreen()),
  ),
  HomeMenuEntry(
    id: 'timeSchemes',
    title: (l10n) => l10n.timeSchemeTitle,
    icon: Icons.schedule_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) =>
        pushHomeMenuPage(context, const TimeSchemeManagementScreen()),
  ),
  HomeMenuEntry(
    id: 'profiles',
    title: (l10n) => l10n.timetableProfilesTitle,
    icon: Icons.collections_bookmark_outlined,
    category: HomeMenuEntryCategory.features,
    open: (context) =>
        pushHomeMenuPage(context, const TimetableProfilesScreen()),
  ),
  HomeMenuEntry(
    id: 'quickSwitchTimetable',
    title: (l10n) => l10n.switchTimetableTitle,
    icon: Icons.swap_horiz_rounded,
    category: HomeMenuEntryCategory.features,
    // 直接弹「切换课表」弹层（非页面）：与点首页标题同一条弹层路径。
    // TA 课表靠情侣覆盖层叠加显示，不是切换对象，不出现在列表里。
    open: (context) async {
      final provider = context.read<TimetableProvider>();
      final selected = await showProfileQuickSwitchSheet(
        context,
        profiles: provider.profiles
            .where((profile) => !profile.isPartnerImported)
            .toList(growable: false),
        activeProfileId: provider.activeProfileId,
        onManageTimetables: (buttonContext) async {
          Navigator.of(buttonContext).pop();
          await pushHomeMenuPage(
            buttonContext,
            const TimetableProfilesScreen(),
          );
        },
      );
      if (selected == null || selected == provider.activeProfileId) {
        return;
      }
      await provider.switchProfile(selected);
    },
  ),

  // ── 数据与同步 ────────────────────────────────────────────
  HomeMenuEntry(
    id: 'dataTransfer',
    title: (l10n) => l10n.dataTransferEntryTitle,
    icon: Icons.backup_outlined,
    category: HomeMenuEntryCategory.data,
    open: (context) => pushHomeMenuPage(context, const DataTransferScreen()),
  ),
  HomeMenuEntry(
    id: 'cloudSync',
    title: (l10n) => l10n.cloudSyncTitle,
    icon: Icons.cloud_sync_outlined,
    category: HomeMenuEntryCategory.data,
    open: (context) => pushHomeMenuPage(context, const CloudSyncScreen()),
  ),
  HomeMenuEntry(
    id: 'lanEdit',
    title: (l10n) => l10n.lanEditTitle,
    icon: Icons.lan_outlined,
    category: HomeMenuEntryCategory.data,
    open: (context) => pushHomeMenuPage(context, const LanEditScreen()),
  ),
  HomeMenuEntry(
    id: 'coupleTimetable',
    title: (l10n) => l10n.coupleTimetableTitle,
    icon: Icons.favorite_outline_rounded,
    category: HomeMenuEntryCategory.data,
    open: (context) =>
        pushHomeMenuPage(context, const CoupleTimetableSettingsScreen()),
  ),

  // ── 偏好设置 ──────────────────────────────────────────────
  HomeMenuEntry(
    id: 'settings',
    title: (l10n) => l10n.homeMenuSettingsTitle,
    icon: Icons.tune_rounded,
    category: HomeMenuEntryCategory.preferences,
    open: (context) =>
        pushHomeMenuPage(context, const TimetableSettingsScreen()),
  ),
  _settingsSubpageEntry(
    id: 'generalSettings',
    title: (l10n) => l10n.generalSettingsTitle,
    icon: Icons.settings_suggest_outlined,
  ),
  _settingsSubpageEntry(
    id: 'appearanceSettings',
    title: (l10n) => l10n.appearanceTitle,
    icon: Icons.palette_outlined,
  ),
  _settingsSubpageEntry(
    id: 'timetablePageSettings',
    title: (l10n) => l10n.timetablePageSettingsTitle,
    icon: Icons.table_chart_outlined,
  ),
  _settingsSubpageEntry(
    id: 'courseCardSettings',
    title: (l10n) => l10n.courseCardSettingsTitle,
    icon: Icons.style_outlined,
  ),
  _settingsSubpageEntry(
    id: 'liveSettings',
    title: (l10n) => l10n.liveSettingsTitle,
    icon: Icons.notifications_active_outlined,
  ),
  _settingsSubpageEntry(
    id: 'holidaySettings',
    title: (l10n) => l10n.holidaySettingsTitle,
    icon: Icons.celebration_outlined,
  ),
  _settingsSubpageEntry(
    id: 'homeWidgetSettings',
    title: (l10n) => l10n.homeWidgetSettingsTitle,
    icon: Icons.widgets_outlined,
  ),
  _settingsSubpageEntry(
    id: 'diagnosticsSettings',
    title: (l10n) => l10n.diagnosticsEntryTitle,
    icon: Icons.bug_report_outlined,
  ),
  HomeMenuEntry(
    id: 'statisticsSettings',
    title: (l10n) => l10n.statisticsSettingsTitle,
    icon: Icons.query_stats_rounded,
    category: HomeMenuEntryCategory.preferences,
    open: (context) =>
        pushHomeMenuPage(context, const StatisticsSettingsScreen()),
  ),
  HomeMenuEntry(
    id: 'advancedMaterialSettings',
    title: (l10n) => l10n.advancedMaterialTitle,
    icon: Icons.auto_awesome_outlined,
    category: HomeMenuEntryCategory.preferences,
    open: (context) =>
        pushHomeMenuPage(context, const AdvancedMaterialSettingsScreen()),
  ),

  // ── 关于与支持 ────────────────────────────────────────────
  HomeMenuEntry(
    id: 'support',
    title: (l10n) => l10n.homeMenuCoffeeTitle,
    icon: Icons.favorite_border_rounded,
    category: HomeMenuEntryCategory.about,
    open: (context) =>
        pushHomeMenuPage(context, const SupportCreatorScreen()),
  ),
  HomeMenuEntry(
    id: 'aboutApp',
    title: (l10n) => l10n.aboutTitle,
    icon: Icons.info_outline_rounded,
    category: HomeMenuEntryCategory.about,
    open: (context) => pushHomeMenuPage(context, const AboutScreen()),
  ),
  HomeMenuEntry(
    id: 'changelog',
    title: (l10n) => l10n.aboutChangelogTitle,
    icon: Icons.history_rounded,
    category: HomeMenuEntryCategory.about,
    open: (context) => pushHomeMenuPage(context, const ChangelogScreen()),
  ),
  HomeMenuEntry(
    id: 'userGuide',
    title: (l10n) => l10n.userGuideEntryTitle,
    icon: Icons.menu_book_outlined,
    category: HomeMenuEntryCategory.about,
    open: (context) => pushHomeMenuPage(context, const UserGuideScreen()),
  ),
  HomeMenuEntry(
    id: 'feedback',
    title: (l10n) => l10n.feedbackTitle,
    icon: Icons.mail_outline_rounded,
    category: HomeMenuEntryCategory.about,
    open: (context) => pushHomeMenuPage(context, const FeedbackScreen()),
  ),
  HomeMenuEntry(
    id: 'openSourceLicenses',
    title: (l10n) => l10n.aboutOpenSourceLicensesTitle,
    icon: Icons.code_rounded,
    category: HomeMenuEntryCategory.about,
    open: (context) =>
        pushHomeMenuPage(context, const OpenSourceLicensesScreen()),
  ),
  // 内存监控与设置页开发者组同源门控：仅 .debug/.profile 包名（调试版、
  // 性能版）可见，正式版用户不得经八宫格绕过该限制。
  HomeMenuEntry(
    id: 'memoryStats',
    title: (l10n) => l10n.memoryStatsEntryTitle,
    icon: Icons.memory_outlined,
    category: HomeMenuEntryCategory.about,
    open: (context) => pushHomeMenuPage(context, const MemoryStatsScreen()),
    visible: () => MemoryStatsService.isDiagnosticsBuildCached,
  ),
];

/// 设置库内部的私有子页通过该工厂暴露给八宫格目录，避免为导航把一批
/// 子页类改成公有。
HomeMenuEntry _settingsSubpageEntry({
  required String id,
  required String Function(AppLocalizations l10n) title,
  required IconData icon,
}) {
  return HomeMenuEntry(
    id: id,
    title: title,
    icon: icon,
    category: HomeMenuEntryCategory.preferences,
    open: (context) {
      final page = settingsSubpageById(id);
      if (page == null) {
        return Future<void>.value();
      }
      return pushHomeMenuPage(context, page);
    },
  );
}

/// 按 id 查目录条目；未知 id（旧版本残留、拼写变化）返回 null 由调用方丢弃。
/// 底栏内嵌页注册表：这些 id 点选时不再推入新路由，而是在首页栈内
/// 切换内容区，玻璃坞保持悬浮（对齐旧「设置 Tab」的常驻体验）。
/// 未登记的 id（表单类/需要上下文的流程页）仍走普通推入。
final Map<String, WidgetBuilder> kInlineDockPages = {
  'settings': (context) => const TimetableSettingsScreen(),
  'overview': (context) => const CourseOverviewScreen(),
  'statistics': (context) => const CourseStatisticsScreen(),
  'exams': (context) => const ExamListScreen(),
  'tasks': (context) => const TaskListScreen(),
  'dataTransfer': (context) => const DataTransferScreen(),
  'cloudSync': (context) => const CloudSyncScreen(),
  'lanEdit': (context) => const LanEditScreen(),
  'coupleTimetable': (context) => const CoupleTimetableSettingsScreen(),
  'timeSchemes': (context) => const TimeSchemeManagementScreen(),
  'icsExport': (context) => const IcsExportScreen(),
  'profiles': (context) => const TimetableProfilesScreen(),
  'feedback': (context) => const FeedbackScreen(),
  'changelog': (context) => const ChangelogScreen(),
  'openSourceLicenses': (context) => const OpenSourceLicensesScreen(),
  'userGuide': (context) => const UserGuideScreen(),
  'support': (context) => const SupportCreatorScreen(),
  'statisticsSettings': (context) => const StatisticsSettingsScreen(),
  'locationTimeMatch': (context) => const LocationTimeMatchScreen(),
  'scheduleDateRule': (context) => const ScheduleDateRuleScreen(),
  'memoryStats': (context) => const MemoryStatsScreen(),
  // 软件更新页构造需要 PackageInfo：用 FutureBuilder 在内嵌壳内自取。
  'update': (context) => FutureBuilder(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return AboutUpdateScreen(packageInfo: snapshot.data!);
        },
      ),
};

/// id 对应的内嵌页构建器；未登记返回 null（调用方回退为推入路由）。
WidgetBuilder? inlineDockPageFor(String id) => kInlineDockPages[id];

HomeMenuEntry? homeMenuEntryById(String? id) {
  if (id == null || id.isEmpty) {
    return null;
  }
  for (final entry in kHomeMenuCatalog) {
    if (entry.id == id) {
      return entry;
    }
  }
  return null;
}

/// 把设置里持久化的八宫格排列解析成目录条目：丢弃未知 id、保持用户
/// 排序；空表或全部失效时回退到 v2.0.5.5 的默认排列。
List<HomeMenuEntry> resolveHomeGridMenuEntries(TimetableSettings settings) {
  final resolved = <HomeMenuEntry>[];
  for (final id in settings.homeGridMenuActions) {
    final entry = homeMenuEntryById(id);
    // visible() 门控：调试/性能版专属条目在正式版被就地丢弃，即使 id
    // 是从旧设备迁移过来的持久化数据。
    if (entry != null && entry.visible() && !resolved.contains(entry)) {
      resolved.add(entry);
    }
  }
  // 自愈：历史版本对「空排列」执行 normalize 时会钉入 'settings'，把
  // 从未配置过的档位固化成单入口；叠加八宫格编辑器入口一度缺失，用户
  // 无法自行恢复。这种「只剩钉住项」的档位视作未配置，回退默认八项。
  final degenerate = resolved.length == 1 &&
      resolved.single.id == HomeGridMenu.pinnedActionId;
  if (resolved.isEmpty || degenerate) {
    return [
      for (final id in HomeGridMenu.defaultActions) homeMenuEntryById(id),
    ]
        .whereType<HomeMenuEntry>()
        .where((entry) => entry.visible())
        .toList(growable: false);
  }
  return List.unmodifiable(resolved);
}

/// 玻璃坞底栏的特殊视图动作 id（非目录页，走首页宿主切换）。
const String kGlassDockActionDay = 'day';
const String kGlassDockActionWeek = 'week';

/// 解析底栏按钮排列：丢弃不可见/未知 id、去重保序；空排列回退
/// [HomeDockMenu.defaultActions]（'day'+'week'）。
List<String> resolveGlassDockActionIds(TimetableSettings settings) {
  final resolved = <String>[];
  for (final id in settings.glassDockActions) {
    if (id == kGlassDockActionDay || id == kGlassDockActionWeek) {
      if (!resolved.contains(id)) {
        resolved.add(id);
      }
      continue;
    }
    final entry = homeMenuEntryById(id);
    if (entry != null && entry.visible() && !resolved.contains(id)) {
      resolved.add(id);
    }
  }
  if (resolved.isEmpty) {
    return List.unmodifiable(HomeDockMenu.defaultActions);
  }
  return resolved;
}

/// 底栏按钮的展示标题（特殊动作用 Tab 文案，其余取目录标题）。
String glassDockActionLabel(AppLocalizations l10n, String id) {
  switch (id) {
    case kGlassDockActionDay:
      return l10n.glassDockTabDay;
    case kGlassDockActionWeek:
      return l10n.glassDockTabWeek;
  }
  return homeMenuEntryById(id)?.title(l10n) ?? id;
}

/// 底栏按钮的展示图标（特殊动作用视图图标，其余取目录图标）。
 IconData glassDockActionIcon(String id) {
  switch (id) {
    case kGlassDockActionDay:
      return Icons.today_rounded;
    case kGlassDockActionWeek:
      return Icons.calendar_view_week_rounded;
  }
  return homeMenuEntryById(id)?.icon ?? Icons.circle_outlined;
}

