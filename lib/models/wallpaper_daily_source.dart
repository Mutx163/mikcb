/// 「每天自动换壁纸」用哪个图源。
///
/// ## 为什么默认是 Bing（2026-10-07）
///
/// Wallhaven 的竖图是原生高清（实测常见 2250×4000 起），而 Bing 的原图只有 2160 高，
/// 竖屏必然放大 1.2～1.5 倍 —— 单论清晰度，Wallhaven 明显更好。
///
/// 但这个功能的名字是「**每天**自动换」，而两者的「每天」强度不一样：
///
/// * Bing 是**日历驱动**的：同一天 worldwide 就是那一张，判据是 `dateKey`；
/// * Wallhaven **没有每日端点**（实测 `/api/v1/random`、`/api/v1/featured` 都是 404），
///   「每天一张」只能按日期算出一个页码偏移去取，**今天和昨天可能撞同一张**。
///
/// 所以默认给 Bing（每天一定换、只是糊一点），把 Wallhaven 作为**可选**的清晰档 ——
/// 用户想要竖屏原生高清就去设置里切，而不是被默认塞一个可能重复的「每日」。
enum WallpaperDailySource {
  /// Bing 每日壁纸：日历驱动、每天必换，代价是竖屏要放大 1.2～1.5 倍。默认。
  bing('bing'),

  /// Wallhaven：原生竖图、**放大 1.0**（真正不糊），代价是「每天」靠翻页凑、
  /// 可能与昨天重复。
  wallhaven('wallhaven');

  const WallpaperDailySource(this.storageKey);

  final String storageKey;

  /// 反解 [storageKey]；未知键回退 [bing]（默认那个）。
  ///
  /// 与 `BingWallpaperResolution.fromStorageKey` 同一口径：坏值不该把设置页炸掉。
  static WallpaperDailySource fromStorageKey(String? raw) {
    for (final value in WallpaperDailySource.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return WallpaperDailySource.bing;
  }
}

/// 「Bing 换不成功时要不要退到另一个源」的行为。
///
/// 单独成枚举而不是布尔，是因为它对应两件**不同**的事，用户不该被一个开关同时决定：
/// * 断网 / 图源抽风时**静默**换源（体验：壁纸照常有，但可能不是最新）；
/// * 手动挑图时**不**换源（用户要的就是这张，替他换一张是错的）。
enum WallpaperSourceFallback {
  /// 任何情况下都只用选中的那个源。失败就是失败，如实告知。
  never('never'),

  /// 自动换失败时**换源再试一次**（手动挑图仍不换）。
  ///
  /// 默认这个：自动换是「锦上添花」，用户不会盯着它失败，而 Bing 偶发缺档 /
  /// 断网不该让首页背景停在昨天那张。
  onAutoApplyOnly('on_auto_apply_only');

  const WallpaperSourceFallback(this.storageKey);

  final String storageKey;

  bool get appliesToAutoApply => this == WallpaperSourceFallback.onAutoApplyOnly;

  static WallpaperSourceFallback fromStorageKey(String? raw) {
    for (final value in WallpaperSourceFallback.values) {
      if (value.storageKey == raw) {
        return value;
      }
    }
    return WallpaperSourceFallback.onAutoApplyOnly;
  }
}