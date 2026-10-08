import 'package:flutter/foundation.dart';

import '../models/timetable_settings.dart';
import '../providers/timetable_provider.dart';

/// 教务导入的作息恢复点（2026-10-08）。
///
/// 脚本下发的作息表在**课程写库之前**就被切/建成当前生效的那套
/// （`warehouse_adapter_web_login_screen` 的 `_applyImportedSections` →
/// `createTimeScheme(applyToActiveProfile: true)` / `applyTimeScheme`）。于是导入
/// 半途中止时（用户取消、容量弹窗返回 false、学期映射取消、写盘抛错、中途 unmount），
/// 用户的作息已经被换掉了 —— 他"什么都没干"，而重启后 `_ensureTimeSchemes` 还会
/// 照着盘上那份把节次对齐进各课表，变成永久的。
///
/// 为什么恢复整份 [TimetableSettings] 而不是只切回 schemeId：
/// 原本"没有启用任何模板"时 `activeTimeSchemeId` 就是 null，而
/// `TimetableSettings.copyWith` 的参数是 `?? this.activeTimeSchemeId`，清不掉它 ——
/// 只切 id 的话，一个本来没有模板的用户会被永久留在一个教务模板上。
class ImportTimeSchemeRestorePoint {
  ImportTimeSchemeRestorePoint._({
    required this.provider,
    required this.settings,
  });

  /// 记下"切作息之前"那一份设置。调用点必须在**应用教务作息之前**。
  factory ImportTimeSchemeRestorePoint.capture(TimetableProvider provider) =>
      ImportTimeSchemeRestorePoint._(
        provider: provider,
        settings: provider.settings,
      );

  final TimetableProvider provider;
  final TimetableSettings settings;

  /// 把作息切回捕获时那一份。
  ///
  /// 恢复失败**不抛出**：调用点在 `finally` 里，抛出去会把原始错误盖掉，
  /// 而且行程已经结束，用户不该再看到第二个错。
  Future<void> restore() async {
    try {
      final rejected = await provider.updateTimetableSettings(settings);
      if (rejected != null && kDebugMode) {
        // 正常路径不该走到这里：中止时课程没落地，捕获的那份节次表本来就合法，
        // 撞不上 `section_count_below_usage`。真撞上了留个痕，便于回捞。
        debugPrint('import time scheme restore rejected: $rejected');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('import time scheme restore failed: $error');
      }
    }
  }
}
