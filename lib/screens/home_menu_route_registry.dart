import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../screens/about_screen.dart';
import '../widgets/home_menu_route_catalog.dart';
import '../widgets/home_top_menu.dart' show pushHomeMenuPage;
import 'add_course_screen.dart';
import 'add_exam_screen.dart';
import 'add_schedule_item_screen.dart';
import 'add_task_screen.dart';
import 'campus_tools_screen.dart';
import 'changelog_screen.dart';
import 'cloud_sync_screen.dart';
import 'couple_timetable_settings_screen.dart';
import 'course_conflict_screen.dart';
import 'course_overview_screen.dart';
import 'course_statistics_screen.dart';
import 'data_transfer_screen.dart';
import 'exam_list_screen.dart';
import 'feedback_screen.dart';
import 'ics_export_screen.dart';
import 'import/course_import_entry_screen.dart';
import 'lan_edit_screen.dart';
import 'location_time_match_screen.dart';
import 'memory_stats_screen.dart';
import 'month_view_screen.dart';
import 'open_source_licenses_screen.dart';
import 'schedule_date_rule_screen.dart';
import 'schedule_list_screen.dart';
import 'statistics_settings_screen.dart';
import 'support_creator_screen.dart';
import 'task_list_screen.dart';
import 'time_scheme_management_screen.dart';
import 'timetable_profiles_screen.dart';
import 'user_guide_screen.dart';

/// 八宫格 / 玻璃坞的页面路由表：**页面构造这里是唯一真源**。
///
/// ## 为什么这张表住 screens 层
///
/// 路由目录（`widgets/home_menu_route_catalog.dart`）原先直接 import 28 个
/// 页面，构成 `widgets → screens` 反向依赖（dep_graph 实测 38 条里的 28 条）。
/// 要真消掉这条边，页面构造就必须搬到**上层**去：`screens → widgets` 合法
/// （页面当然可以组装控件），`widgets → screens` 违规。于是：
///
/// - screens 层（本文件）持有 `id → Widget Function()`，是唯一认识页面类型的
///   地方；
/// - widgets 层的路由目录只认识 [HomeMenuPageDescriptor]，运行时查表；
/// - 表在 `TimetableScreen.initState` 经 [registerHomeMenuRoutes] 注入。
///
/// 注意这**不是**把 import 搬到「度量看不见的目录」：本文件在 `lib/screens/`，
/// dep_graph 照常把它算进 screens 层且逐条判定，边是**真的没了**（widgets
/// 侧不再有任何 screens 符号），不是账上不见了。裁定 R1 禁止的是躲进
/// `lib/controllers/` 那种被 CROSS_CUTTING 跳过的目录。
///
/// ## 为什么描述符里没有 icon / title
///
/// 计划草案写的是 `{id, icon, title, builder}`，实际只留 `{id, build}`：
/// 标题绑着 l10n（`(l10n) => l10n.xxx`）、图标是主题色渲染的入参，两者都已经
/// 住在 `HomeMenuEntry`（`widgets/home_menu_catalog.dart`）里，是八宫格/底栏
/// 渲染的**唯一真源**。搬一份到路由表等于同一句文案两处维护，改一处就会漂。
/// 路由表只负责「怎么造这个页面」，元数据仍归目录条目。
///
/// ## 维护约定
///
/// 新增入口 = 在 `kHomeMenuCatalog`（元数据）+ 这里的 `catalogPages`（页面）
/// 各追加一条，id 必须对齐；坞内嵌页再加 `inlineDockPages` 一条。
/// `homePage` 对未知 id 抛异常，漏登记是启动即炸的编程错误，不会静默退化。
///
/// 逐条迁自 `widgets/home_menu_route_catalog.dart`（2026-10-20 路由表化），
/// id 与页面映射零变化。
final HomeMenuRouteRegistry kHomeMenuRouteRegistry = HomeMenuRouteRegistry(
  inlineDockPages: _inlineDockPageDescriptors,
  catalogPages: _catalogPageDescriptors,
  pushUpdateEntry: _pushUpdateEntry,
);

/// 底栏玻璃坞内嵌页：点选不推路由，在首页栈内切换内容区（坞保持悬浮）。
///
/// `settings` 不在此表：它由 `registerSettingsPages` 那套依赖倒置另行登记
/// （设置首页在 `main()` 里注入，路由目录启动时并进同一张表）。
final List<HomeMenuPageDescriptor> _inlineDockPageDescriptors = [
  HomeMenuPageDescriptor(id: 'overview', build: () => const CourseOverviewScreen()),
  HomeMenuPageDescriptor(
    id: 'statistics',
    build: () => const CourseStatisticsScreen(),
  ),
  HomeMenuPageDescriptor(id: 'exams', build: () => const ExamListScreen()),
  HomeMenuPageDescriptor(id: 'tasks', build: () => const TaskListScreen()),
  HomeMenuPageDescriptor(
    id: 'dataTransfer',
    build: () => const DataTransferScreen(),
  ),
  HomeMenuPageDescriptor(id: 'cloudSync', build: () => const CloudSyncScreen()),
  HomeMenuPageDescriptor(id: 'lanEdit', build: () => const LanEditScreen()),
  HomeMenuPageDescriptor(
    id: 'coupleTimetable',
    build: () => const CoupleTimetableSettingsScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'timeSchemes',
    build: () => const TimeSchemeManagementScreen(),
  ),
  HomeMenuPageDescriptor(id: 'icsExport', build: () => const IcsExportScreen()),
  // 月视图：玻璃坞内嵌页（坞常驻、首页栈内切换，翻月/选中日状态不丢）。
  HomeMenuPageDescriptor(
    id: 'monthView',
    build: () => const MonthViewScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'profiles',
    build: () => const TimetableProfilesScreen(),
  ),
  HomeMenuPageDescriptor(id: 'feedback', build: () => const FeedbackScreen()),
  HomeMenuPageDescriptor(id: 'changelog', build: () => const ChangelogScreen()),
  HomeMenuPageDescriptor(
    id: 'openSourceLicenses',
    build: () => const OpenSourceLicensesScreen(),
  ),
  HomeMenuPageDescriptor(id: 'userGuide', build: () => const UserGuideScreen()),
  HomeMenuPageDescriptor(
    id: 'support',
    build: () => const SupportCreatorScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'statisticsSettings',
    build: () => const StatisticsSettingsScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'locationTimeMatch',
    build: () => const LocationTimeMatchScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'scheduleDateRule',
    build: () => const ScheduleDateRuleScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'scheduleList',
    build: () => const ScheduleListScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'memoryStats',
    build: () => const MemoryStatsScreen(),
  ),
  // 软件更新页构造需要 PackageInfo：用 FutureBuilder 在内嵌壳内自取
  // （与迁移前逐字一致；取包信息失败时仍停在转圈，旧行为未改）。
  HomeMenuPageDescriptor(
    id: 'update',
    build: () => FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return AboutUpdateScreen(packageInfo: snapshot.data);
      },
    ),
  ),
];

/// 八宫格 / 顶部菜单的推入路由页（`xxxPage` 命名与迁移前逐字一致）。
final List<HomeMenuPageDescriptor> _catalogPageDescriptors = [
  HomeMenuPageDescriptor(
    id: 'overviewPage',
    build: () => const CourseOverviewScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'statisticsPage',
    build: () => const CourseStatisticsScreen(),
  ),
  HomeMenuPageDescriptor(id: 'addCoursePage', build: () => const AddCourseScreen()),
  HomeMenuPageDescriptor(id: 'examListPage', build: () => const ExamListScreen()),
  HomeMenuPageDescriptor(
    id: 'courseImportPage',
    build: () => const CourseImportScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'campusToolsPage',
    build: () => const CampusToolsScreen(),
  ),
  HomeMenuPageDescriptor(id: 'taskListPage', build: () => const TaskListScreen()),
  HomeMenuPageDescriptor(id: 'addExamPage', build: () => const AddExamScreen()),
  HomeMenuPageDescriptor(id: 'addTaskPage', build: () => const AddTaskScreen()),
  HomeMenuPageDescriptor(
    id: 'addScheduleItemPage',
    build: () => const AddScheduleItemScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'courseConflictPage',
    build: () => const CourseConflictScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'locationTimeMatchPage',
    build: () => const LocationTimeMatchScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'scheduleDateRulePage',
    build: () => const ScheduleDateRuleScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'scheduleListPage',
    build: () => const ScheduleListScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'icsExportPage',
    build: () => const IcsExportScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'monthViewPage',
    build: () => const MonthViewScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'timeSchemesPage',
    build: () => const TimeSchemeManagementScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'timetableProfilesPage',
    build: () => const TimetableProfilesScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'dataTransferPage',
    build: () => const DataTransferScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'cloudSyncPage',
    build: () => const CloudSyncScreen(),
  ),
  HomeMenuPageDescriptor(id: 'lanEditPage', build: () => const LanEditScreen()),
  HomeMenuPageDescriptor(
    id: 'coupleTimetablePage',
    build: () => const CoupleTimetableSettingsScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'statisticsSettingsPage',
    build: () => const StatisticsSettingsScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'supportCreatorPage',
    build: () => const SupportCreatorScreen(),
  ),
  HomeMenuPageDescriptor(id: 'aboutPage', build: () => const AboutScreen()),
  HomeMenuPageDescriptor(
    id: 'changelogPage',
    build: () => const ChangelogScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'userGuidePage',
    build: () => const UserGuideScreen(),
  ),
  HomeMenuPageDescriptor(id: 'feedbackPage', build: () => const FeedbackScreen()),
  HomeMenuPageDescriptor(
    id: 'openSourceLicensesPage',
    build: () => const OpenSourceLicensesScreen(),
  ),
  HomeMenuPageDescriptor(
    id: 'memoryStatsPage',
    build: () => const MemoryStatsScreen(),
  ),
];

/// 「软件更新」八宫格条目的 open 逻辑（原 `pushHomeMenuUpdateEntry` 本体）：
/// 先取包信息再进更新详情页，context 失活时静默放弃。
Future<void> _pushUpdateEntry(BuildContext context) async {
  final packageInfo = await PackageInfo.fromPlatform();
  if (!context.mounted) {
    return;
  }
  await pushHomeMenuPage(context, AboutUpdateScreen(packageInfo: packageInfo));
}
