// Debug automation only: callers always re-check context.mounted after awaits.
// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_log_service.dart';
import '../services/debug_deep_link_service.dart';
import '../services/live_testing_fixture_service.dart';
import '../services/miui_live_activities_service.dart';
import '../utils/app_toast.dart';

/// 深链要打开的一页：由组合根按**深链路径**构造页面并压栈。
///
/// 返回的 Future 只代表「这次 push 完成」，本层不 await（深链只要求页面在栈上，
/// 与改造前 `unawaited(HyperosNavigation.push(...))` 的口径一致）。
typedef DebugDeepLinkRoutePusher =
    Future<void> Function(BuildContext context, String routePath);

/// 调试深链的宿主端口：本文件在 services 层，不许反向认识 screens / providers /
/// ui，这三类能力由组合根（`lib/main.dart`）以回调注入。
///
/// 端口形状是「命令真正需要的最小面」，不是把上层对象整个传下来：
/// - [pushRoute]：页面类型与转场曲线全在上层（screens + ui），本层只按路径点名；
/// - [fixtureHost]：测试课表夹具的宿主端口。抽象 [LiveTestingFixtureHost] 由
///   services 层自己定义（合法方向），providers 层实现它、组合根构造；
/// - [onAppResume]：`handleAppResumed()` 的窄回调，本层不持有 provider。
///
/// 三个回调都在 `attach` 时一次给定；`detach` 后不再被调用。
class DebugDeepLinkBindings {
  const DebugDeepLinkBindings({
    required this.pushRoute,
    required this.fixtureHost,
    required this.onAppResume,
  });

  final DebugDeepLinkRoutePusher pushRoute;

  final LiveTestingFixtureHost Function() fixtureHost;

  final Future<void> Function() onAppResume;
}

/// Handles [DebugDeepLinkCommand] navigation and actions for debug automation.
///
/// ## 为什么这里一条上层 import 都没有
///
/// 2026-10-20 之前本文件直接 import 六个屏幕 + `ui/hyperos/hyperos.dart` +
/// `providers/timetable_provider.dart`，一个文件贡献 8 条分层违规
/// （services→screens 6、services→ui 1、services→providers 1）。
///
/// 改法不是搬家 —— 裁定 R1 禁止把它塞进 `lib/controllers/` 这类被
/// `dep_graph.py` 归 `root`、CROSS_CUTTING 直接跳过的目录，那是把真实依赖
/// 搬进免检区、账上消失而边还在。这里走**依赖倒置**：本文件只留命令分派骨架
/// 与压栈时序，页面构造 / provider 访问 / 转场曲线一律经 [DebugDeepLinkBindings]
/// 由组合根注入。边是真断的 —— 本文件里已不存在任何 screens / providers / ui
/// 符号，dep_graph 照常把本文件算进 services 层并逐条判定。
///
/// 唯一保留的「上层味道」是 `utils/app_toast`（提示条）：utils 是横切层，
/// 任何层都可依赖，不参与违规判定。
class DebugDeepLinkNavigator {
  DebugDeepLinkNavigator._();

  static StreamSubscription<DebugDeepLinkCommand>? _subscription;
  static bool _handling = false;

  static void attach(BuildContext context, DebugDeepLinkBindings bindings) {
    if (kReleaseMode) {
      return;
    }
    _subscription?.cancel();
    _subscription = DebugDeepLinkService.commands.listen((command) {
      unawaited(_handle(context, command, bindings));
    });
  }

  static void detach() {
    _subscription?.cancel();
    _subscription = null;
  }

  static Future<void> _handle(
    BuildContext context,
    DebugDeepLinkCommand command,
    DebugDeepLinkBindings bindings,
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

      // 每个 case 与改造前逐条对应。带层级的两条写成字面量路径链，方便与旧实现
      // 的调用嵌套一一对照：原 `_openLiveSettings` = `_openSettings` + push 自己，
      // 等价于 ['settings', 'settings/live']；testing / keep-alive 再多一层。
      switch (command.path) {
        case 'home':
          _popToRoot(context);
        case 'settings':
        case 'settings/couple':
        case 'settings/lan-edit':
        case 'courses/import':
          await _pushStack(context, bindings, <String>[command.path]);
        case 'settings/live':
          await _pushStack(context, bindings, const <String>[
            'settings',
            'settings/live',
          ]);
        case 'settings/live/testing':
          await _pushStack(context, bindings, const <String>[
            'settings',
            'settings/live',
            'settings/live/testing',
          ]);
        case 'settings/live/keep-alive':
          await _pushStack(context, bindings, const <String>[
            'settings',
            'settings/live',
            'settings/live/keep-alive',
          ]);
        case 'settings/live/perf-report':
          await _pushStack(context, bindings, const <String>[
            'settings',
            'settings/live',
            'settings/live/perf-report',
          ]);
        case 'action/resume':
          await _runResume(context, bindings);
        case 'action/seed-soon':
          await _seedSoon(context, bindings, command.queryInt('minutes') ?? 15);
        case 'action/dump-live-status':
          await _dumpLiveStatus(context);
        default:
          await AppLogService.instance.warn(
            'debug_deep_link_unknown',
            '未知调试深链：${command.path}',
            extras: {'path': command.path},
          );
          if (context.mounted) {
            showAppToast(context, message: '未知调试深链：${command.path}');
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

  /// 先回根，再按顺序逐层压栈；层与层之间等一次转场结算 —— 连续压栈不等待会
  /// 与上一层的转场赛跑，栈序会乱。
  static Future<void> _pushStack(
    BuildContext context,
    DebugDeepLinkBindings bindings,
    List<String> routePaths,
  ) async {
    _popToRoot(context);
    if (!context.mounted) {
      return;
    }
    for (var i = 0; i < routePaths.length; i++) {
      if (i > 0) {
        await _settleNavigation();
        if (!context.mounted) {
          return;
        }
      }
      unawaited(bindings.pushRoute(context, routePaths[i]));
    }
  }

  /// Wait for route transition frames so stacked deep-link pushes do not race.
  static Future<void> _settleNavigation() async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    await WidgetsBinding.instance.endOfFrame;
  }

  static Future<void> _runResume(
    BuildContext context,
    DebugDeepLinkBindings bindings,
  ) async {
    await bindings.onAppResume();
    await AppLogService.instance.info(
      'debug_deep_link_resume_done',
      '调试深链已触发 handleAppResumed',
    );
    if (context.mounted) {
      showAppToast(context, message: '已触发恢复自愈', kind: AppToastKind.success);
    }
  }

  static Future<void> _seedSoon(
    BuildContext context,
    DebugDeepLinkBindings bindings,
    int minutes,
  ) async {
    final host = bindings.fixtureHost();
    final now = DateTime.now();
    final leadMinutes = minutes.clamp(1, 120);
    final course = await LiveTestingFixtureService.upsertTimedFixtureCourse(
      host: host,
      sectionNumber: LiveTestingFixtureService.sectionNumberForTime(
        now,
        host.settings.sections,
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
