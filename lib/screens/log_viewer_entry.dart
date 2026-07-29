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
/// names, share text, and the recording toggle all live here now.
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

Widget _buildMergedViewer(BuildContext context, AppLocalizations l10n) {
  final liveService = MiuiLiveActivitiesService();
  final settings = context.read<TimetableProvider>().settings;

  return LiveDiagnosticsLogViewerScreen(
    title: l10n.aboutAppLogsTitle,
    watchRawLog: () => AppLogService.instance.watchMergedLogsText(
      loadNativeRawLog: liveService.readLiveDiagnosticsText,
    ),
    isRecordingEnabled: settings.liveEnableLocalDiagnostics,
    onRecordingChanged: (value) =>
        _updateRecordingPreference(context, l10n, value),
    onExport: (_) async {
      final nativeRawLog = await liveService.readLiveDiagnosticsText();
      final path = await AppLogService.instance.exportMergedLogsFile(
        nativeRawLog: nativeRawLog,
      );
      if (path == null || path.isEmpty) {
        if (context.mounted) {
          showAppToast(
            context,
            message: l10n.aboutNoDiagnosticsExportYet,
            kind: AppToastKind.warning,
          );
        }
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: l10n.appLogsShareText,
          subject: l10n.appLogsShareSubject,
        ),
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
      final path = await liveService.exportLiveDiagnosticsFile();
      if (path == null || path.isEmpty) {
        if (context.mounted) {
          showAppToast(
            context,
            message: l10n.liveDiagnosticsNothingToExport,
            kind: AppToastKind.warning,
          );
        }
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: l10n.liveDiagnosticsShareText,
          subject: l10n.liveDiagnosticsShareSubject,
        ),
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

Future<void> _updateRecordingPreference(
  BuildContext context,
  AppLocalizations l10n,
  bool value,
) async {
  final provider = context.read<TimetableProvider>();
  final message = await provider.updateTimetableSettings(
    provider.settings.copyWith(liveEnableLocalDiagnostics: value),
  );
  if (!context.mounted) {
    return;
  }
  if (message != null) {
    showAppToast(context, message: message);
    return;
  }
  showAppToast(
    context,
    message: value
        ? l10n.aboutLiveDiagnosticsEnabled
        : l10n.aboutLiveDiagnosticsDisabled,
    kind: AppToastKind.success,
  );
}
