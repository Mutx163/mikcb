import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/course_recolor.dart';

/// 配色历史 + 当前指向的快照。
class CourseRecolorHistoryState {
  const CourseRecolorHistoryState({
    required this.schemes,
    required this.index,
  });

  /// 空历史（该课表从未重刷过）。
  const CourseRecolorHistoryState.empty()
    : schemes = const [],
      index = -1;

  final List<CourseRecolorScheme> schemes;

  /// 当前指向 [schemes] 的下标；-1 表示尚无历史。
  final int index;

  bool get isEmpty => schemes.isEmpty;

  bool get canGoBack => index > 0;

  bool get canGoForward => index >= 0 && index < schemes.length - 1;

  CourseRecolorScheme? get current =>
      index >= 0 && index < schemes.length ? schemes[index] : null;
}

/// 「课表重新配色」的方案历史持久化。
///
/// 只存方案记录（随机种子或颜色快照），不存课程数据本身；当前指向哪一套
/// （导航位置）一并持久化，弹层重开后才能继续往返。历史按课表 profile
/// 作用域隔离——不同课表互不串色。
class CourseRecolorHistoryService {
  CourseRecolorHistoryService._();

  static const String _schemesKeyPrefix = 'course_recolor_history_v1:';
  static const String _indexKeyPrefix = 'course_recolor_history_index_v1:';

  static String schemesPreferenceKey(String scope) =>
      '$_schemesKeyPrefix$scope';

  static String indexPreferenceKey(String scope) => '$_indexKeyPrefix$scope';

  /// 历史上限：超过时丢最旧的记录（包括最旧的导入原色快照）。
  static const int maxSchemes = 20;

  static Future<CourseRecolorHistoryState> load(String scope) async {
    final preferences = await SharedPreferences.getInstance();
    final schemes = await _loadSchemes(preferences, scope);
    if (schemes.isEmpty) {
      return const CourseRecolorHistoryState.empty();
    }
    final rawIndex = preferences.getInt(indexPreferenceKey(scope)) ?? -1;
    // 旧数据/坏数据没有有效指向时，当前观感大概率就是最后一套。
    final index = rawIndex < 0 ? schemes.length - 1 : rawIndex;
    return CourseRecolorHistoryState(
      schemes: schemes,
      index: index.clamp(0, schemes.length - 1),
    );
  }

  /// 保存历史与指向；超过 [maxSchemes] 时丢最旧记录并同步前移指向。
  static Future<void> save(
    String scope,
    List<CourseRecolorScheme> schemes,
    int index,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    var bounded = schemes;
    var boundedIndex = index;
    if (schemes.length > maxSchemes) {
      final dropCount = schemes.length - maxSchemes;
      bounded = schemes.sublist(dropCount);
      boundedIndex = (index - dropCount).clamp(0, bounded.length - 1);
    }
    await preferences.setString(
      schemesPreferenceKey(scope),
      jsonEncode([for (final scheme in bounded) scheme.toJson()]),
    );
    await preferences.setInt(indexPreferenceKey(scope), boundedIndex);
  }

  static Future<List<CourseRecolorScheme>> _loadSchemes(
    SharedPreferences preferences,
    String scope,
  ) async {
    final raw = preferences.getString(schemesPreferenceKey(scope));
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      final schemes = <CourseRecolorScheme>[];
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final scheme = CourseRecolorScheme.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (scheme != null) {
          schemes.add(scheme);
        }
      }
      return schemes;
    } catch (_) {
      return const [];
    }
  }
}
