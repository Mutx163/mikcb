/// 壁纸亮度采样的「同 key 限次重试」闸门（2026-10-08）。
///
/// 三处采样——首页顶栏墨色（`screens/timetable_screen.dart`）、设置页周预览
/// （`widgets/timetable_week_preview.dart`）、壁纸位置页极性
/// （`widgets/wallpaper_position_picker_sheet.dart`）——原先各写一份，且**同一个坑**：
/// 在 `await` **之前**就把 key 记成「采过了」，采样失败（返回 null / 抛错）时不清。
/// 后果一致：此后每次进入都以「命中缓存」早退，顶栏墨色 / 预览极性永久停在主题
/// 默认色，直到换壁纸或冷启动 —— 而用户看到的只是"这里颜色不对劲"。
///
/// 又不能无条件重试：解不开的图会变成**每帧重新解码一张大图**。所以按 key 限次：
/// 同一份 key 最多真的采 [maxRetries] 次，试满就认输（不再清标记）；换 key
/// （换图 / 视口 / 对齐 / 缩放变了）重新计数；成功一次即永久命中。
///
/// 抽成一份而不是继续复制：本仓的教训正是"同一件事留了几份副本，改的时候只改
/// 当时看到的那一份"（钟点字典序、材质参数都栽在这上面）。三处共用一份，也就有了
/// 一个能落钉子的地方 —— 三个调用点都在 widget 里，没有合规的单测落点。
class LuminanceSampleGate {
  LuminanceSampleGate({this.maxRetries = 3})
    : assert(maxRetries > 0, 'maxRetries must be >= 1, or nothing is ever sampled');

  /// 同一份 key 最多尝试几次（含第一次）。
  final int maxRetries;

  String? _sampledKey;
  String? _attemptKey;
  int _failures = 0;

  /// 现在是否需要为 [key] 发起一次采样。
  ///
  /// `false` 有两种含义，调用方都不必区分：这份 key 已经成功采过，或者同一份 key
  /// 已经失败到上限（再试就是白费电）。
  bool needsSample(String key) {
    if (_sampledKey == key) {
      return false;
    }
    if (_attemptKey == key && _failures >= maxRetries) {
      return false;
    }
    return true;
  }

  /// 记一次采样结果。[succeeded] 为 false 时累计失败次数（到 [maxRetries] 为止）。
  void record(String key, {required bool succeeded}) {
    if (succeeded) {
      _sampledKey = key;
      _attemptKey = null;
      _failures = 0;
      return;
    }
    _failures = _attemptKey == key ? _failures + 1 : 1;
    _attemptKey = key;
  }

  /// 背景整个没了（换成纯色 / 预设）时清空：下一次进入要重新采。
  void reset() {
    _sampledKey = null;
    _attemptKey = null;
    _failures = 0;
  }
}
