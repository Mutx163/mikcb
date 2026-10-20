import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/timetable_settings.dart';
import '../services/app_log_service.dart';
import '../services/app_update_service.dart';

/// 首页更新检查控制器（2026-10-20 从 `TimetableScreen` State 搬出）。
///
/// 只负责「按设置查一次更新」并把结果缓存在 `hasUpdate`；是否弹首页提示、
/// 如何展示由 State 收到结果后决定。
class UpdateCheckController extends ChangeNotifier {
  UpdateCheckController({AppUpdateService? service})
    : _service = service ?? AppUpdateService();

  final AppUpdateService _service;
  bool _hasUpdate = false;
  bool _disposed = false;

  bool get hasUpdate => _hasUpdate;

  /// 返回非空结果时由调用方决定是否弹提示；错误/调试/未查都返回 null。
  Future<AppUpdateCheckResult?> check({
    required TimetableSettings settings,
    required bool includePrerelease,
  }) async {
    if (!kReleaseMode) {
      _setHasUpdate(true);
      return null;
    }
    try {
      final downloadSource = AppUpdateDownloadSourceX.fromValue(
        settings.appUpdateDownloadSource,
      );
      final mirrorPreset = AppUpdateMirrorPresetX.fromValue(
        settings.appUpdateMirrorPreset,
      );
      final effectiveMirrorUrlPrefix = resolveAppUpdateMirrorUrlPrefix(
        preset: mirrorPreset,
        customUrlPrefix: settings.appUpdateMirrorUrlPrefix,
      );
      final packageInfo = await PackageInfo.fromPlatform();
      final result = await _service.checkForUpdates(
        currentVersion: packageInfo.version,
        includePrerelease: includePrerelease,
        preferredSource: downloadSource,
        mirrorUrlPrefix: effectiveMirrorUrlPrefix,
      );
      if (_disposed) return null;
      _setHasUpdate(result.hasUpdate);
      return result;
    } catch (e, stackTrace) {
      // Ignore update check failures on home screen; About page provides
      // details. Log a warning so a "no update prompt" report has a trace.
      debugPrint('checkForAppUpdate failed: $e');
      await AppLogService.instance.warn(
        'home_update_check_failed',
        e.toString(),
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  void _setHasUpdate(bool value) {
    if (_disposed || _hasUpdate == value) return;
    _hasUpdate = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
