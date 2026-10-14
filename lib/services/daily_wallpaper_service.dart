import 'package:flutter/foundation.dart';

import 'bing_wallpaper_service.dart';
import 'bing_wallpaper_store.dart';

/// 「今天自动换」这次尝试的结局。
///
/// 与 [BingAutoApplyOutcome] 的语义一一对应，但它是一个**独立的类型**：设置页与
/// 启动路径消费的是「这一句提示」，不必知道 Bing 内部的结局枚举（两个类型曾经承担
/// 「多图源归一」的职责，2026-10-14 图源收敛回 Bing 之后它只剩这层薄薄的翻译 ——
/// 保留它是为了让调用方的 `switch` 与 `BingAutoApplyOutcome` 的演进解耦）。
enum DailyWallpaperApplyOutcome {
  /// 功能没开。
  disabled,

  /// 今天已经换过了。
  alreadyApplied,

  /// 换上了今天该换的那张。
  appliedToday,

  /// 换上了 Bing 手上最新的那张，但它不是「今天那张」。
  appliedStale,

  /// 拉不到清单，或图没下下来。
  failed,
}

@immutable
class DailyWallpaperApplyResult {
  const DailyWallpaperApplyResult(this.outcome, [this.path, this.itemId]);

  final DailyWallpaperApplyOutcome outcome;

  /// 真换上去时的本地路径。
  final String? path;

  /// 那张图的**身份**（Bing 是 `dateKey`，可能不是今天，见 appliedStale）。
  final String? itemId;

  bool get succeeded => path != null;
}

/// 「每天自动换壁纸」的**调度层**。
///
/// ## 为什么它还独立存在（2026-10-14）
///
/// Wallhaven 图源删除后只剩 Bing 一个源，这一层只剩「把结局类型翻译给调用方」一件事。
/// 保留它是因为两个调用点（`main.dart` 启动路径、设置页开关）都挂在 `applyDaily`
/// 上，而「吞掉一切意外」这条启动路径的铁律写在这里比写进 `BingWallpaperService`
/// 更清晰 —— 那个类的入口还服务图库页（不该静默吞错）。
class DailyWallpaperService {
  const DailyWallpaperService._();

  /// 执行「今天自动换」。
  ///
  /// [now] 只给测试用（单测把「今天」钉在固定日期上）。[inUsePaths] 是**所有课表**
  /// 当前的壁纸路径（见 `inUseWallpaperPaths`），清理台账溢出的文件时当白名单。
  static Future<DailyWallpaperApplyResult> applyDaily({
    DateTime? now,
    Set<String> inUsePaths = const <String>{},
  }) async {
    final store = BingWallpaperStore.instance;
    final clock = now ?? DateTime.now();
    if (!store.autoApplyEnabled) {
      return const DailyWallpaperApplyResult(
        DailyWallpaperApplyOutcome.disabled,
      );
    }
    try {
      return _fromBing(
        await BingWallpaperService.maybeApplyDaily(
          now: clock,
          inUsePaths: inUsePaths,
        ),
      );
    } on Object {
      // 启动路径上的任何意外都不该波及主流程（与 Bing service 的口径一致）。
      return const DailyWallpaperApplyResult(
        DailyWallpaperApplyOutcome.failed,
      );
    }
  }

  static DailyWallpaperApplyResult _fromBing(
    BingAutoApplyResult result,
  ) => switch (result.outcome) {
    BingAutoApplyOutcome.disabled => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.disabled,
    ),
    BingAutoApplyOutcome.alreadyApplied => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.alreadyApplied,
    ),
    BingAutoApplyOutcome.appliedToday => DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.appliedToday,
      result.path,
      result.dateKey,
    ),
    BingAutoApplyOutcome.appliedStale => DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.appliedStale,
      result.path,
      result.dateKey,
    ),
    BingAutoApplyOutcome.failed => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.failed,
    ),
  };
}
