import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/wallpaper_daily_source.dart';
import 'bing_wallpaper_service.dart';
import 'bing_wallpaper_store.dart';
import 'wallhaven_wallpaper_service.dart';

/// 「今天自动换」这次尝试的结局（**与图源无关**的统一口径）。
///
/// ## 为什么要这一层归一
///
/// 两个源各有自己的结局枚举，而它们的用户可感知含义**是同一批**：没开 / 今天已换过 /
/// 今天换好了 / 换的不是今天那张（Bing 特有）/ 没换成。设置页与启动路径都只想要
/// 「这一句提示」，所以在这里把它们压成一个类型：
///
/// * 界面只写**一处** `switch`，将来加第三个源不必改它；
/// * `appliedStale` 保留成「Bing 才有」的一档（见 [WallpaperDailySource] 的注释：
///   Wallhaven 没有「今天那张还没放出来」这回事），所以 Wallhaven 那条永远不报它。
enum DailyWallpaperApplyOutcome {
  /// 功能没开。
  disabled,

  /// 今天已经换过了。
  alreadyApplied,

  /// 换上了今天该换的那张。
  appliedToday,

  /// 换上了图源手上最新的那张，但它不是「今天那张」（Bing 独有）。
  appliedStale,

  /// 拉不到清单，或图没下下来。
  failed,
}

@immutable
class DailyWallpaperApplyResult {
  const DailyWallpaperApplyResult(
    this.outcome, [
    this.path,
    this.itemId,
    this.source,
  ]);

  final DailyWallpaperApplyOutcome outcome;

  /// 真换上去时的本地路径。
  final String? path;

  /// 那张图的**身份**（Bing 是 `dateKey`、Wallhaven 是它的 id）。
  ///
  /// 两者形态不同但用途一样：给用户报「换的是哪一天 / 哪一张」。
  final String? itemId;

  /// 实际生效的图源。
  ///
  /// 换源重试成功时它**不等于**用户选的那个 —— 这正是它存在的理由：换源是对用户
  /// 透明的（用户只关心壁纸换了没），但日志与「这张是哪来的」需要如实记。
  final WallpaperDailySource? source;

  bool get succeeded => path != null;
}

/// 「每天自动换壁纸」的**调度层**：按用户选的图源执行，必要时换源重试。
///
/// ## 为什么不塞进 [BingWallpaperService]
///
/// 那个类的类注释把它写成「只负责 Bing 那条链路」，而它的入口
/// `maybeApplyDaily` 挂在启动路径上。让它认得「另一个源」会把两件不相干的事揉进
/// 一个已经很难读的文件里，而换图源这件事**不该**要求改动 Bing 的任何一行。
///
/// ## 三条口径
///
/// * **换源只对自动换生效**：手动挑图时用户要的就是那张（见 [WallpaperSourceFallback]）。
/// * **换源后报的是原源的结局**：两个源都失败时，用户看到的提示不该因为内部换过源
///   而说谎（他用的仍然是 Wallhaven）。
/// * **失败一律静默**：本类挂在启动路径上，异常自己吞，不抛给调用方。
class DailyWallpaperService {
  const DailyWallpaperService._();

  /// 按用户选的图源执行「今天自动换」。
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
      return switch (store.dailySource) {
        WallpaperDailySource.bing => _fromBing(
          await BingWallpaperService.maybeApplyDaily(
            now: clock,
            inUsePaths: inUsePaths,
          ),
        ),
        WallpaperDailySource.wallhaven => await _wallhaven(
          store,
          clock,
          inUsePaths,
        ),
      };
    } on Object {
      // 启动路径上的任何意外都不该波及主流程（与两个源 service 的口径一致）。
      return const DailyWallpaperApplyResult(
        DailyWallpaperApplyOutcome.failed,
      );
    }
  }

  /// 走 Wallhaven；按 [WallpaperSourceFallback] 决定要不要换 Bing 重试。
  static Future<DailyWallpaperApplyResult> _wallhaven(
    BingWallpaperStore store,
    DateTime now,
    Set<String> inUsePaths,
  ) async {
    final first = await WallhavenWallpaperService.maybeApplyDaily(
      now: now,
      inUsePaths: inUsePaths,
    );
    if (first.succeeded || !store.sourceFallback.appliesToAutoApply) {
      return _fromWallhaven(first);
    }
    final retry = await BingWallpaperService.maybeApplyDaily(
      now: now,
      inUsePaths: inUsePaths,
    );
    // 两个源都失败：报**原本**那个源的结局，用户看到的提示不能说谎。
    return retry.succeeded
        ? _fromBing(retry)
        : _fromWallhaven(first);
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
      WallpaperDailySource.bing,
    ),
    BingAutoApplyOutcome.appliedStale => DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.appliedStale,
      result.path,
      result.dateKey,
      WallpaperDailySource.bing,
    ),
    BingAutoApplyOutcome.failed => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.failed,
    ),
  };

  static DailyWallpaperApplyResult _fromWallhaven(
    WallhavenAutoApplyResult result,
  ) => switch (result.outcome) {
    WallhavenAutoApplyOutcome.disabled => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.disabled,
    ),
    WallhavenAutoApplyOutcome.alreadyApplied => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.alreadyApplied,
    ),
    WallhavenAutoApplyOutcome.appliedToday => DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.appliedToday,
      result.path,
      result.itemId,
      WallpaperDailySource.wallhaven,
    ),
    WallhavenAutoApplyOutcome.failed => const DailyWallpaperApplyResult(
      DailyWallpaperApplyOutcome.failed,
    ),
  };
}