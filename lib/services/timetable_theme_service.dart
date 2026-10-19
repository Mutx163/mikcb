import 'dart:async';

import '../models/timetable_settings.dart';

/// 主题写入口需要的最小依赖面。
///
/// 由 `TimetableProvider` 侧的小适配器实现：读当前设置、走统一设置写入口、
/// 走统一 mutation 串行队列、按「快照 → 落盘 → 失败回滚」写主题列表、发通知。
/// 服务本身不碰 provider 私有字段，可用假端口单测。
abstract interface class TimetableThemePort {
  TimetableSettings get settings;
  Future<void> updateSettings(TimetableSettings settings);
  Future<T> runMutation<T>(Future<T> Function() operation);
  Future<void> replaceSavedThemes(
    List<SavedTheme> Function(TimetableSettings settings) build,
  );
  void notifyStateChanged();
}

/// 主题域用例：应用/撤销、保存/删除/重命名。
///
/// 2026-10-19 从 `TimetableProvider` 的主题族方法搬出；行为与写入纪律保持
/// 原样：撤销窗口仍是 2 秒，主题列表写入仍由端口负责快照/回滚。
class TimetableThemeService {
  TimetableThemeService(this._port);

  final TimetableThemePort _port;

  // 主题撤销状态（仅保存主题相关字段，避免误回滚其他设置）
  ThemeConfig? _undoThemeConfig;
  String? _undoThemeName;
  Timer? _undoTimer;

  /// 是否有待撤销的主题变更
  bool get hasPendingUndo => _undoThemeConfig != null;

  /// 撤销主题名称
  String? get undoThemeName => _undoThemeName;

  /// 应用主题并保存撤销状态
  Future<void> applyThemeWithUndo(
    TimetableSettings newSettings, {
    String? themeName,
  }) async {
    _undoThemeConfig = ThemeConfig.fromSettings(_port.settings);
    _undoThemeName = themeName;
    _undoTimer?.cancel();
    _undoTimer = Timer(const Duration(seconds: 2), () {
      _undoThemeConfig = null;
      _undoThemeName = null;
      _port.notifyStateChanged();
    });
    await _port.updateSettings(newSettings);
  }

  /// 撤销主题变更
  Future<void> undoThemeChange() async {
    final undo = _undoThemeConfig;
    if (undo == null) {
      return;
    }
    final restored = undo.applyToSettings(_port.settings);
    _undoThemeConfig = null;
    _undoThemeName = null;
    _undoTimer?.cancel();
    await _port.updateSettings(restored);
  }

  /// 保存主题
  Future<void> saveTheme(String name, Map<String, dynamic> themeData) {
    return _port.runMutation(() async {
      final theme = SavedTheme(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        config: ThemeConfig.fromJson(themeData),
        createdAt: DateTime.now(),
      );
      await _port.replaceSavedThemes(
        (settings) => [...settings.savedThemes, theme],
      );
    });
  }

  /// 删除主题
  Future<void> deleteTheme(String themeId) {
    return _port.runMutation(
      () => _port.replaceSavedThemes(
        (settings) =>
            settings.savedThemes.where((theme) => theme.id != themeId).toList(),
      ),
    );
  }

  /// 重命名主题
  Future<void> renameTheme(String themeId, String newName) {
    return _port.runMutation(() async {
      await _port.replaceSavedThemes(
        (settings) => settings.savedThemes.map((theme) {
          if (theme.id == themeId) {
            return SavedTheme(
              id: theme.id,
              name: newName,
              config: theme.config,
              createdAt: theme.createdAt,
            );
          }
          return theme;
        }).toList(),
      );
    });
  }

  void dispose() {
    _undoTimer?.cancel();
  }
}
