import 'package:flutter/foundation.dart';

/// 首页壁纸「最近使用」历史条目。
///
/// 每设置/切换一次壁纸就记一条，供设置页的「最近使用」缩略图条一键切回。
/// 与 [ClassReminderEntry] 同款约定：随 TimetableSettings JSON 持久化，
/// 并经云同步 / 备份携带；脏条目在 [listFromJson] 内逐条丢弃，绝不因为
/// 单个坏值炸掉整个设置。
///
/// [key] 是**背景身份键**，与 [homePageBackdropKey] 同一口径：
/// 自选图片为文件绝对路径，内置壁纸为 builtin:<预设>。模型层只当它是
/// 不透明字符串，不理解前缀含义（保持对 ui 层零依赖）。
@immutable
class WallpaperHistoryEntry {
  const WallpaperHistoryEntry({
    required this.key,
    this.alignX = 0,
    this.alignY = 0,
    this.usedAt = 0,
  });

  /// 背景身份键：图片壁纸为文件绝对路径，内置壁纸为 \`builtin:<预设>\`。
  final String key;

  /// 使用该壁纸时的水平对齐（-1..1）；内置壁纸没有裁剪窗口，恒为 0。
  final double alignX;

  /// 使用该壁纸时的垂直对齐（-1..1）；内置壁纸没有裁剪窗口，恒为 0。
  final double alignY;

  /// 最近一次使用时间（epoch 毫秒），用于排序与「最近」语义。
  ///
  /// 旧数据缺失该字段时回退 0：列表顺序仍按数组本身的先后（最新的在前）。
  final int usedAt;

  /// 空 key 是无意义条目，直接视为脏数据。
  bool get isValid => key.trim().isNotEmpty;

  WallpaperHistoryEntry copyWith({
    String? key,
    double? alignX,
    double? alignY,
    int? usedAt,
  }) => WallpaperHistoryEntry(
    key: key ?? this.key,
    alignX: alignX ?? this.alignX,
    alignY: alignY ?? this.alignY,
    usedAt: usedAt ?? this.usedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key,
    'alignX': alignX,
    'alignY': alignY,
    'usedAt': usedAt,
  };

  /// 非法输入返回 null 而不是抛错：设置 JSON 可能来自旧版本或手改备份。
  ///
  /// ⚠️ 这里**必须**用类型判断（`v is num ? v : null`），不能用
  /// `raw['alignX'] as num?`：`as num?` 只在「null 或 num」时成立，遇到字符串
  /// 之类会**抛 TypeError**，然后一路冒出到 `TimetableSettings.fromJson`
  /// （见 `timetable_settings.dart` 的 `listFromJson` 调用点，那里没有
  /// try/catch），被 `TimetableProfile.fromJsonLenient` 捕获后**把整份课表设置
  /// 重置为默认**——单个坏值放大成整份设置丢失，与本函数上面那条承诺直接
  /// 矛盾。同款约定见 `class_reminder.dart` 的 `is! num` 写法。
  static WallpaperHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final key = raw['key'];
    if (key is! String) {
      return null;
    }
    final entry = WallpaperHistoryEntry(
      key: key,
      alignX: _numOrNull(raw['alignX'])?.toDouble() ?? 0,
      alignY: _numOrNull(raw['alignY'])?.toDouble() ?? 0,
      usedAt: _numOrNull(raw['usedAt'])?.toInt() ?? 0,
    );
    return entry.isValid ? entry : null;
  }

  /// 只放行 num；其余类型（含字符串数字）一律视为缺失，回退默认值。
  static num? _numOrNull(Object? value) => value is num ? value : null;

  static List<WallpaperHistoryEntry> listFromJson(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [
      for (final item in raw)
        if (fromJson(item) case final WallpaperHistoryEntry entry) entry,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is WallpaperHistoryEntry &&
      other.key == key &&
      other.alignX == alignX &&
      other.alignY == alignY &&
      other.usedAt == usedAt;

  @override
  int get hashCode => Object.hash(key, alignX, alignY, usedAt);

  @override
  String toString() => 'WallpaperHistoryEntry($key, $alignX, $alignY, $usedAt)';
}
