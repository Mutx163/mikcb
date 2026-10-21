import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../controllers/course_auto_refresh_controller.dart';
import '../../domain/course_timetable_signature.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/timetable_provider.dart';
import '../../services/app_log_service.dart';
import '../../services/course_auto_refresh_store.dart';
import '../../services/warehouse_macro_service.dart';
import '../../utils/app_toast.dart';
import 'home_pull_quick_import.dart';

/// 正在跑的自动更新。同一时刻只允许一场 —— 冷启动与回前台可能挨得很近
/// （冷启动后系统立刻投一次 resumed），两场叠起来会同时挂两个隐形 WebView。
bool _inFlight = false;

/// 冷启动 / 回前台时调用：到点就在**后台静默**抓一次课表。
///
/// ## 静默的含义
///
/// 用户口径（2026-10-21）：「静默跑，只在失败或拿到新课表时提示」。所以这里
/// **不挂下拉那颗药丸**，也不弹任何进度：复用下拉快捷导入的后台模式（它本来
/// 就把 WebView 挂在 1×1 的 Offstage 里跑），只在两种结局各说一句：
/// 抓到新课表 → 一句成功提示；没成功 → 一句「可下拉手动重试」。
///
/// 中间态（没到点、没有快捷导入记录、内容和上次一样）一律不出声。
Future<void> runCourseAutoRefreshIfDue(
  BuildContext context, {
  required TimetableProvider provider,
}) async {
  if (_inFlight) {
    return;
  }
  final store = CourseAutoRefreshStore.instance;
  if (!store.isLoaded) {
    await store.load();
  }
  if (!store.schedule.enabled) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  _inFlight = true;
  try {
    final l10n = AppLocalizations.of(context);
    final controller = CourseAutoRefreshController(
      // 「本机有没有录好的快捷导入记录」：没有就安静跳过。用户还没配过这项功能
      // 时弹「自动更新失败」会让人以为坏了。
      preflight: () async {
        final entries = await WarehouseMacroService().getAllMacroEntries();
        return entries.isNotEmpty;
      },
      // 真的去抓：复用下拉快捷导入那一条（后台模式，不弹登录页、不挡操作）。
      // `silent: true` 关掉前置提示：这一路是用户没盯着的时候跑的，
      // 结局统一由下面那句提示承担。
      runImport: () =>
          runHomePullWarehouseQuickImport(context, silent: true),
      // 抓完拿课表内容指纹比一比，判断「有没有真的拿到新课表」。
      captureSignature: () => timetableContentSignature(provider.courses),
    );

    final outcome = await controller.maybeRunNow();
    if (!context.mounted || l10n == null) {
      return;
    }
    switch (outcome) {
      case CourseAutoRefreshOutcome.updated:
        showAppLightTip(context, message: l10n.courseAutoRefreshUpdatedTip);
      case CourseAutoRefreshOutcome.failed:
        showAppLightTip(
          context,
          message: l10n.courseAutoRefreshFailedTip,
          kind: AppToastKind.warning,
        );
      case CourseAutoRefreshOutcome.disabled:
      case CourseAutoRefreshOutcome.notDue:
      case CourseAutoRefreshOutcome.noSource:
      case CourseAutoRefreshOutcome.busy:
      case CourseAutoRefreshOutcome.unchanged:
        break;
    }
  } catch (error, stackTrace) {
    // 自动更新是后台行为，任何异常都不该冒到启动管线上去（那会触发
    // 「启动失败」的降级路径）。留一条日志即可。
    await AppLogService.instance.warn(
      'course_auto_refresh_crashed',
      '课表自动更新异常',
      error: error,
      stackTrace: stackTrace,
    );
  } finally {
    _inFlight = false;
  }
}

/// 设置页里「立即试一次」用：不判时间窗，直接跑一次。
///
/// 与 [runCourseAutoRefreshIfDue] 分开是因为判定与执行在
/// [CourseAutoRefreshController] 里已经拆开了：这里的语义是「用户手点，
/// 无论到没到点都要跑」，所以绕过 `decideCourseAutoRefresh`。
Future<CourseAutoRefreshOutcome> runCourseAutoRefreshNow(
  BuildContext context, {
  required TimetableProvider provider,
}) async {
  if (_inFlight) {
    return CourseAutoRefreshOutcome.busy;
  }
  _inFlight = true;
  try {
    final before = timetableContentSignature(provider.courses);
    final ok = await runHomePullWarehouseQuickImport(context);
    if (!ok) {
      return CourseAutoRefreshOutcome.failed;
    }
    final changed = timetableContentSignature(provider.courses) != before;
    return changed
        ? CourseAutoRefreshOutcome.updated
        : CourseAutoRefreshOutcome.unchanged;
  } finally {
    _inFlight = false;
  }
}
