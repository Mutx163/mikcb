// Debug automation only: callers always re-check context.mounted after awaits.
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../screens/couple_timetable_settings_screen.dart';
import '../screens/course_import_screen.dart';
import '../screens/lan_edit_screen.dart';
import '../screens/live_settings_subpages.dart';
import '../screens/timetable_settings_screen.dart';
import '../services/app_log_service.dart';
import '../services/debug_deep_link_service.dart';
import '../services/live_testing_fixture_service.dart';
import '../services/miui_live_activities_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

/// Handles [DebugDeepLinkCommand] navigation and actions for debug automation.
class DebugDeepLinkNavigator {
  DebugDeepLinkNavigator._();

  static StreamSubscription<DebugDeepLinkCommand>? _subscription;
  static bool _handling = false;

  static void attach(BuildContext context) {
    if (kReleaseMode) {
      return;
    }
    _subscription?.cancel();
    _subscription = DebugDeepLinkService.commands.listen((command) {
      unawaited(_handle(context, command));
    });
  }

  static void detach() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<void> _handle(
    BuildContext context,
    DebugDeepLinkCommand command,
  ) async {
    if (!context.mounted || _handling) {
      return;
    }
    _handling = true;
    try {
      await AppLogService.instance.info(
        'debug_deep_link_received',
        '收到调试深链：${command.path}',
        extras: {'path': command.path, ...command.query},
      );
      if (!context.mounted) {
        return;
      }

      switch (command.path) {
        case 'home':
          _popToRoot(context);
        case 'settings':
          await _openSettings(context);
        case 'settings/live':
          await _openLiveSettings(context);
        case 'settings/live/testing':
          await _openLiveTesting(context);
        case 'settings/live/keep-alive':
          await _openKeepAlive(context);
        case 'settings/couple':
          await _openCouple(context);
        case 'settings/lan-edit':
          await _openLanEdit(context);
        case 'courses/import':
          await _openCourseImport(context);
        case 'action/resume':
          await _runResume(context);
        case 'action/seed-soon':
          await _seedSoon(context, command.queryInt('minutes') ?? 15);
        case 'action/dump-live-status':
          await _dumpLiveStatus(context);
        default:
          await AppLogService.instance.warn(
            'debug_deep_link_unknown',
            '未知调试深链：${command.path}',
            extras: {'path': command.path},
          );
          if (context.mounted) {
            showAppToast(
              context,
              message: '未知调试深链：${command.path}',
            );
          }
      }
    } catch (error, stackTrace) {
      await AppLogService.instance.error(
        'debug_deep_link_failed',
        '调试深链处理失败',
        error: error,
        stackTrace: stackTrace,
        extras: {'path': command.path},
      );
      if (context.mounted) {
        showAppToast(
          context,
          message: '调试深链失败：${command.path}',
          kind: AppToastKind.error,
        );
      }
    } finally {
      _handling = false;
    }
  }

  static void _popToRoot(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Push without awaiting pop — deep links only need the route on the stack.
  static void _pushRoute(
    BuildContext context, {
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) {
    unawaited(
      HyperosNavigation.push(context, settings: settings, builder: builder),
    );
  }

  /// Wait for route transition frames so stacked deep-link pushes do not race.
  static Future<void> _settleNavigation() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await WidgetsBinding.instance.endOfFrame;
  }

  static Future<void> _openSettings(BuildContext context) async {
    _popToRoot(context);
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/settings'),
      builder: (_) => const TimetableSettingsScreen(),
    );
  }

  static Future<void> _openLiveSettings(BuildContext context) async {
    await _openSettings(context);
    await _settleNavigation();
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/settings/live'),
      builder: (_) => createLiveSettingsScreen(),
    );
  }

  static Future<void> _openLiveTesting(BuildContext context) async {
    await _openLiveSettings(context);
    await _settleNavigation();
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/settings/live/testing'),
      builder: (_) => createLiveTestingSettingsScreen(),
    );
  }

  static Future<void> _openKeepAlive(BuildContext context) async {
    await _openLiveSettings(context);
    await _settleNavigation();
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/settings/live/keep-alive'),
      builder: (_) => const LiveKeepAliveSettingsScreen(),
    );
  }

  static Future<void> _openCouple(BuildContext context) async {
    _popToRoot(context);
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/settings/couple'),
      builder: (_) => const CoupleTimetableSettingsScreen(),
    );
  }

  static Future<void> _openLanEdit(BuildContext context) async {
    _popToRoot(context);
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/settings/lan-edit'),
      builder: (_) => const LanEditScreen(),
    );
  }

  static Future<void> _openCourseImport(BuildContext context) async {
    _popToRoot(context);
    if (!context.mounted) {
      return;
    }
    _pushRoute(
      context,
      settings: const RouteSettings(name: '/courses/import'),
      builder: (_) => const CourseImportScreen(),
    );
  }

  static Future<void> _runResume(BuildContext context) async {
    final provider = context.read<TimetableProvider>();
    await provider.handleAppResumed();
    await AppLogService.instance.info(
      'debug_deep_link_resume_done',
      '调试深链已触发 handleAppResumed',
    );
    if (context.mounted) {
      showAppToast(context, message: '已触发恢复自愈', kind: AppToastKind.success);
    }
  }

  static Future<void> _seedSoon(BuildContext context, int minutes) async {
    final provider = context.read<TimetableProvider>();
    final now = DateTime.now();
    final leadMinutes = minutes.clamp(1, 120);
    final course = await LiveTestingFixtureService.upsertTimedFixtureCourse(
      provider: provider,
      sectionNumber: LiveTestingFixtureService.sectionNumberForTime(
        now,
        provider.settings.sections,
      ),
      now: now,
      lead: Duration(minutes: leadMinutes),
      note: '调试深链 seed-soon（$leadMinutes 分钟后）',
    );
    await AppLogService.instance.info(
      'debug_deep_link_seed_soon_done',
      '调试深链已写入即将开始的测试课',
      extras: {
        'courseId': course.id,
        'startTime': course.startTime,
        'endTime': course.endTime,
        'minutes': leadMinutes,
      },
    );
    if (context.mounted) {
      showAppToast(
        context,
        message:
            '已写入 $leadMinutes 分钟后测试课 ${course.startTime}-${course.endTime}',
        kind: AppToastKind.success,
      );
    }
  }

  static Future<void> _dumpLiveStatus(BuildContext context) async {
    final status = await MiuiLiveActivitiesService().getLiveUpdateDebugStatus();
    final encoded = const JsonEncoder.withIndent('  ').convert(status);
    await AppLogService.instance.info(
      'debug_deep_link_live_status',
      '超级岛调试状态快照',
      extras: {'statusJson': encoded},
    );
    // Also print to console for adb logcat filtering.
    debugPrint('DEBUG_LIVE_STATUS_BEGIN');
    debugPrint(encoded);
    debugPrint('DEBUG_LIVE_STATUS_END');
    if (context.mounted) {
      showAppToast(context, message: '已导出超级岛状态到日志', kind: AppToastKind.success);
    }
  }
}
