import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:university_timetable/screens/about_screen.dart';
import 'package:university_timetable/widgets/home_top_menu.dart'
    show pushHomeMenuPage;
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
import 'package:university_timetable/screens/schedule_list_screen.dart';
import 'package:university_timetable/screens/statistics_settings_screen.dart';
import 'package:university_timetable/screens/support_creator_screen.dart';
import 'package:university_timetable/screens/task_list_screen.dart';
import 'package:university_timetable/screens/time_scheme_management_screen.dart';
import 'package:university_timetable/screens/timetable_profiles_screen.dart';
import 'package:university_timetable/screens/user_guide_screen.dart';

/// 八宫格/玻璃坞的页面路由目录：集中维护「入口 id → 目标页面」映射。
///
/// 拆分自 `home_menu_catalog.dart`：目录本体只保留条目元数据与分发逻辑，
/// 屏幕类 import 集中到这里，消除 widgets → screens 的 27 处依赖以及
/// `timetable_settings_screen ↔ home_menu_catalog` 的循环。
/// 两份注册表共用同一批 id（见 `kHomeMenuCatalog` / `kInlineDockPages`），
/// 新增页面入口时两处同步追加。
///
/// 导航壳 `pushHomeMenuPage` 仍在 home_top_menu.dart（未动）；本文件的
/// `kInlineDockPages` 逐行迁入、key 与页面映射零变化。

/// 底栏内嵌页注册表（原样迁自 home_menu_catalog.dart）：这些 id 点选时
/// 不再推入新路由，而是在首页栈内切换内容区，玻璃坞保持悬浮（对齐旧
/// 「设置 Tab」的常驻体验）。未登记的 id（表单类/需要上下文的流程页）
/// 仍走普通推入。
final Map<String, WidgetBuilder> kInlineDockPages = {
  // 「设置」由设置库启动时登记（见 _buildSettingsScreen），避免本文件
  // 反向 import 设置页构成循环。
  'settings': (context) => _buildSettingsScreen(),
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
  'scheduleList': (context) => const ScheduleListScreen(),
  'memoryStats': (context) => const MemoryStatsScreen(),
  // 软件更新页构造需要 PackageInfo：用 FutureBuilder 在内嵌壳内自取。
  'update': (context) => FutureBuilder(
    future: PackageInfo.fromPlatform(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return AboutUpdateScreen(packageInfo: snapshot.data);
    },
  ),
};

/// id 对应的内嵌页构建器；未登记返回 null（调用方回退为推入路由）。
WidgetBuilder? inlineDockPageFor(String id) => kInlineDockPages[id];

/// 目录页构造器注册表：id → 页面实例。八宫格条目经 [homePage] 取页，
/// 拆分后 home_menu_catalog.dart 不再直接 import 任何 screen。
final Map<String, Widget Function()> kHomeCatalogPages = {
  'overviewPage': () => const CourseOverviewScreen(),
  'statisticsPage': () => const CourseStatisticsScreen(),
  'addCoursePage': () => const AddCourseScreen(),
  'examListPage': () => const ExamListScreen(),
  'courseImportPage': () => const CourseImportScreen(),
  'taskListPage': () => const TaskListScreen(),
  'addExamPage': () => const AddExamScreen(),
  'addTaskPage': () => const AddTaskScreen(),
  'addScheduleItemPage': () => const AddScheduleItemScreen(),
  'courseConflictPage': () => const CourseConflictScreen(),
  'locationTimeMatchPage': () => const LocationTimeMatchScreen(),
  'scheduleDateRulePage': () => const ScheduleDateRuleScreen(),
  'scheduleListPage': () => const ScheduleListScreen(),
  'icsExportPage': () => const IcsExportScreen(),
  'timeSchemesPage': () => const TimeSchemeManagementScreen(),
  'timetableProfilesPage': () => const TimetableProfilesScreen(),
  'dataTransferPage': () => const DataTransferScreen(),
  'cloudSyncPage': () => const CloudSyncScreen(),
  'lanEditPage': () => const LanEditScreen(),
  'coupleTimetablePage': () => const CoupleTimetableSettingsScreen(),
  'settingsPage': _buildSettingsScreen,
  'statisticsSettingsPage': () => const StatisticsSettingsScreen(),
  'advancedMaterialSettingsPage': () => const AdvancedMaterialSettingsScreen(),
  'supportCreatorPage': () => const SupportCreatorScreen(),
  'aboutPage': () => const AboutScreen(),
  'changelogPage': () => const ChangelogScreen(),
  'userGuidePage': () => const UserGuideScreen(),
  'feedbackPage': () => const FeedbackScreen(),
  'openSourceLicensesPage': () => const OpenSourceLicensesScreen(),
  'memoryStatsPage': () => const MemoryStatsScreen(),
};

/// 按注册表 key 取目录页；key 必然存在（目录与注册表同步维护），
/// 缺失视为编程错误，抛出而不是静默返回 null。
Widget homePage(String key) {
  final builder = kHomeCatalogPages[key];
  if (builder == null) {
    throw StateError('home_menu_route_catalog: unknown page key "$key"');
  }
  return builder();
}

/// 「软件更新」八宫格条目的 open 逻辑（原样迁自目录 update 条目）：
/// 先取包信息再进更新详情页，context 失活时静默放弃。
Future<void> pushHomeMenuUpdateEntry(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) return;
  await pushHomeMenuPage(context, AboutUpdateScreen(packageInfo: packageInfo));
}

/// 设置页注册表（依赖倒置）：timetable_settings_screen.dart 在库加载即
/// 登记设置首页构造器与私有子页工厂，八宫格/玻璃坞目录经此回调取页，
/// 避免本文件反向 import 设置页构成目录 ↔ 设置页的循环依赖。
Widget? Function(String id)? _settingsSubpageResolver;
Widget Function()? _settingsScreenBuilderOverride;

/// 由 timetable_settings_screen.dart 调用：登记设置首页构造器与子页工厂。
void registerSettingsPages({
  required Widget Function() settingsScreen,
  required Widget? Function(String id) subpageById,
}) {
  _settingsScreenBuilderOverride = settingsScreen;
  _settingsSubpageResolver = subpageById;
}

/// 按稳定 id 取设置库私有子页；未登记或未知 id 返回 null。
///（命名避开设置库公开的 settingsSubpageById，防止双 import 歧义。）
Widget? resolveSettingsSubpage(String id) => _settingsSubpageResolver?.call(id);

/// 取设置首页；未登记视为编程错误（main 未完成启动登记）。
Widget _buildSettingsScreen() {
  final builder = _settingsScreenBuilderOverride;
  if (builder == null) {
    throw StateError(
      'home_menu_route_catalog: settings screen not registered; '
      'main() must call registerSettingsPages at startup',
    );
  }
  return builder();
}
