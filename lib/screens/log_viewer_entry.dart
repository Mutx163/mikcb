import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../providers/timetable_provider.dart';
import '../services/app_log_service.dart';
import '../services/miui_live_activities_service.dart';
import '../services/warehouse_import_session_log.dart';
import '../utils/app_toast.dart';
import 'live_diagnostics_log_viewer_screen.dart';

/// Which log feeds [LiveDiagnosticsLogViewerScreen].
enum AppLogSource {
  /// App runtime log merged with the native live-update diagnostics.
  merged,

  /// Native live-update (超级岛) diagnostics only.
  live,

  /// In-memory trace of the current warehouse course-import session.
  warehouseImport,
}

/// Single door to the log viewer.
///
/// The viewer widget was always shared, but each of its five call sites built
/// its own config — including two byte-for-byte copies in the about screen that
/// had already started to drift (one of them double-toasted on clear). Route
/// names and share text live here now; the recording toggle lives in the
/// diagnostics settings page, so the viewer stays a pure reader.
Future<void> openLogViewer(BuildContext context, AppLogSource source) async {
  if (_opening) {
    return;
  }
  _opening = true;
  try {
    await Navigator.of(context).push(
      HyperosPageRoute(
        settings: RouteSettings(name: _routeNameOf(source)),
        builder: (_) => _buildViewer(context, source),
      ),
    );
  } finally {
    _opening = false;
  }
}

/// Guards against a double tap pushing the viewer twice.
bool _opening = false;

String _routeNameOf(AppLogSource source) {
  return switch (source) {
    AppLogSource.merged => '/logs/app',
    AppLogSource.live => '/logs/live',
    AppLogSource.warehouseImport => '/logs/warehouse-import',
  };
}

Widget _buildViewer(BuildContext context, AppLogSource source) {
  final l10n = AppLocalizations.of(context)!;
  return switch (source) {
    AppLogSource.merged => _buildMergedViewer(context, l10n),
    AppLogSource.live => _buildLiveViewer(context, l10n),
    AppLogSource.warehouseImport => _buildWarehouseImportViewer(context, l10n),
  };
}

/// 分享**用户当前看到的那份**日志。
///
/// `text` 是查看器的 `_buildFullLogText()`
/// （live_diagnostics_log_viewer_screen.dart:969-973），它已经按当前等级筛选：
/// `buildFilteredDiagnosticsRawText(parsed, filterDiagnosticsEntries(..., _selectedLevel))`，
/// 并保留头部设备信息段。复制按钮用的就是同一份文本。
///
/// 这里原先的两个回调把参数丢掉、改成重新读全量文件
/// （`exportMergedLogsFile` / `exportLiveDiagnosticsFile`），于是
/// 「只看错误 → 分享」发出去的仍是含课程名与教室的 info 全文：
/// 屏幕上没有的内容被当作可分享内容交了出去。
Future<void> _shareViewedLogText(
  BuildContext context, {
  required String text,
  required String fileName,
  required String shareText,
  required String shareSubject,
  required String emptyMessage,
}) async {
  if (text.trim().isEmpty) {
    if (context.mounted) {
      showAppToast(
        context,
        message: emptyMessage,
        kind: AppToastKind.warning,
      );
    }
    return;
  }
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(text, flush: true);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(file.path)],
      text: shareText,
      subject: shareSubject,
    ),
  );
}

Widget _buildMergedViewer(BuildContext context, AppLocalizations l10n) {
  final liveService = MiuiLiveActivitiesService();
  final settings = context.read<TimetableProvider>().settings;

  return LiveDiagnosticsLogViewerScreen(
    title: l10n.aboutAppLogsTitle,
    watchRawLog: () => AppLogService.instance.watchMergedLogsText(
      loadNativeRawLog: liveService.readLiveDiagnosticsText,
    ),
    isRecordingEnabled: settings.liveEnableLocalDiagnostics,
    onExport: (text) async {
      await _shareViewedLogText(
        context,
        text: text,
        fileName:
            'mikcb-app-logs-${DateTime.now().millisecondsSinceEpoch}.log',
        shareText: l10n.appLogsShareText,
        shareSubject: l10n.appLogsShareSubject,
        emptyMessage: l10n.aboutNoDiagnosticsExportYet,
      );
    },
    // No toast here — the viewer reports the outcome itself. Returning a toast
    // from this callback is what produced two stacked toasts on the old
    // advanced-options path.
    onClear: () async {
      final clearedAppLogs = await AppLogService.instance.clearAppLogs();
      if (defaultTargetPlatform != TargetPlatform.android) {
        return clearedAppLogs;
      }
      final clearedNativeLogs = await liveService.clearLiveDiagnostics();
      return clearedAppLogs && clearedNativeLogs;
    },
  );
}

Widget _buildLiveViewer(BuildContext context, AppLocalizations l10n) {
  final liveService = MiuiLiveActivitiesService();

  return LiveDiagnosticsLogViewerScreen(
    title: l10n.liveDiagnosticsViewerTitle,
    watchRawLog: liveService.watchLiveDiagnosticsText,
    onLoadEmpty: () {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.liveDiagnosticsUnavailable,
        kind: AppToastKind.warning,
      );
      Navigator.of(context).pop();
    },
    onExport: (text) async {
      await _shareViewedLogText(
        context,
        text: text,
        fileName:
            'mikcb-live-diagnostics-${DateTime.now().millisecondsSinceEpoch}.log',
        shareText: l10n.liveDiagnosticsShareText,
        shareSubject: l10n.liveDiagnosticsShareSubject,
        emptyMessage: l10n.liveDiagnosticsNothingToExport,
      );
    },
    // Deliberately no onClear: this feed pops itself via [onLoadEmpty] the
    // moment it goes empty, so clearing from inside would close the page under
    // the user. 超级岛自检 owns the clear action.
  );
}

Widget _buildWarehouseImportViewer(
  BuildContext context,
  AppLocalizations l10n,
) {
  final sessionLog = WarehouseImportSessionLog.instance;
  final title = l10n.warehouseImportExecutionLogTitle;

  return LiveDiagnosticsLogViewerScreen(
    title: title,
    watchRawLog: () => sessionLog.watchText(title: title),
    onLoadEmpty: () {
      if (context.mounted) {
        showAppLightTip(
          context,
          message: l10n.warehouseImportExecutionLogEmpty,
        );
      }
    },
    onExport: (text) async {
      final directory = await getTemporaryDirectory();
      final fileName =
          'qingyu-warehouse-import-log-${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(text, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: l10n.warehouseImportExecutionLogShareText,
          subject: l10n.warehouseImportExecutionLogShareSubject,
        ),
      );
    },
    onClear: () async {
      sessionLog.clear();
      return true;
    },
  );
}
