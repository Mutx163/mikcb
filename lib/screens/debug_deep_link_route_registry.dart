import 'package:flutter/material.dart';

import '../providers/live_testing_fixture_access.dart';
import '../providers/timetable_provider.dart';
import '../services/debug_deep_link_navigator.dart';
import '../ui/hyperos/hyperos.dart';
import 'couple_timetable_settings_screen.dart';
import 'import/course_import_entry_screen.dart';
import 'lan_edit_screen.dart';
import 'live_settings_subpages.dart';
import 'perf_report_screen.dart';
import 'settings/settings_live.dart';
import 'timetable_settings_screen.dart';

/// 调试深链的**页面表与宿主适配**：深链路径 → 页面 / provider 能力的唯一真源。
///
/// ## 为什么这张表住 screens 层
///
/// `services/debug_deep_link_navigator.dart` 原先直接 import 六个屏幕 +
/// `ui/hyperos/hyperos.dart` + `providers/timetable_provider.dart`，一个文件
/// 贡献 8 条分层违规（services→screens 6、services→ui 1、services→providers 1）。
///
/// 改法是**依赖倒置**，不是搬家：导航器只留命令分派骨架，页面构造、转场曲线、
/// provider 访问一律经 `DebugDeepLinkBindings` 注入；本文件在上层把三者接上。
/// `screens → services / providers / ui` 三个方向都合法，边是真断的 ——
/// 导航器里已不存在任何 screens / providers / ui 符号。
///
/// 刻意**不**搬进 `lib/controllers/`（裁定 R1）：那目录被 `dep_graph.py` 归
/// `root`、CROSS_CUTTING 直接跳过判定，搬进去只是让边从账上消失而依赖还在。
///
/// ## 为什么单独成文件而不是写在 main.dart
///
/// 与 `screens/home_menu_route_registry.dart`（泳道路由表化）同一个理由：
/// 装配根 `main.dart` 已 1,857 行、是并行会话最常撞上的热文件，把七条页面的
/// 构造细节塞进去只会让它继续膨胀。这里只依赖「组合根调用一次」这一个契约。
///
/// ## 路径口径
///
/// [pushRoute] 收的是**深链路径**（`settings/live/testing` 这种无前导 `/` 的
/// 形式，与 `DebugDeepLinkCommand.path` 一致），不是 Flutter 的路由名：
/// `RouteSettings(name:)` 里的 `/settings/...` 带前导斜杠，两者刻意分开，
/// 免得有人以为深链可以直接当命名路由用。
DebugDeepLinkBindings buildDebugDeepLinkBindings({
  required TimetableProvider provider,
}) {
  return DebugDeepLinkBindings(
    pushRoute: (context, routePath) {
      switch (routePath) {
        case 'settings':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings'),
            builder: (_) => const TimetableSettingsScreen(),
          );
        case 'settings/live':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings/live'),
            builder: (_) => createLiveSettingsScreen(),
          );
        case 'settings/live/testing':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings/live/testing'),
            builder: (_) => createLiveTestingSettingsScreen(),
          );
        case 'settings/live/keep-alive':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings/live/keep-alive'),
            builder: (_) => const LiveKeepAliveSettingsScreen(),
          );
        case 'settings/live/perf-report':
          // 每页帧率 + 能耗代理排行。正式版探针未装，这一页只会显示
          // 「probe not installed」，不构成绕过诊断门控的通道。
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings/live/perf-report'),
            builder: (_) => const PerfReportScreen(),
          );
        case 'settings/couple':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings/couple'),
            builder: (_) => const CoupleTimetableSettingsScreen(),
          );
        case 'settings/lan-edit':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/settings/lan-edit'),
            builder: (_) => const LanEditScreen(),
          );
        case 'courses/import':
          return HyperosNavigation.push<void>(
            context,
            settings: const RouteSettings(name: '/courses/import'),
            builder: (_) => const CourseImportScreen(),
          );
        default:
          // 深链路径由 services 侧的 switch 给出；走到这里说明两张表漂了。
          // 抛错让上层 catch 记 debug_deep_link_failed，好过静默不动。
          throw StateError('debug deep link: 未登记的页面路径 $routePath');
      }
    },
    // 夹具宿主端口每次现构造：适配器只包一层 provider（一行转发），无状态。
    fixtureHost: () => LiveFixtureProviderAccess(provider),
    onAppResume: provider.handleAppResumed,
  );
}
