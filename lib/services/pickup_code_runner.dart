import 'dart:async';

import '../models/pickup_code_entry.dart';
import 'pickup_code_launcher.dart';

/// 一次点击最终走到了哪一级回退。
enum PickupCodeRunStatus {
  /// 直达链接被目标 App 接住（最好情况）。
  launched,

  /// 直达链接全失败，只拉起了官方 App（用户要自己在 App 里找页面）。
  openedApp,

  /// 应用级兜底也失败，最后用网页打开。
  openedWeb,

  /// 全部失败。
  failed,

  /// 当前平台没有外部跳转能力（桌面 / 测试环境）。
  unsupported,
}

class PickupCodeRunResult {
  const PickupCodeRunResult(this.status, {this.reason, this.elapsed});

  final PickupCodeRunStatus status;

  /// 最后一次失败的原因码；成功时为 null。
  final String? reason;

  /// 实际花掉的时间（排查「点了没反应」时有用）。
  final Duration? elapsed;

  bool get ok =>
      status == PickupCodeRunStatus.launched ||
      status == PickupCodeRunStatus.openedApp ||
      status == PickupCodeRunStatus.openedWeb;
}

/// 一次点击最多花多久。
///
/// 不设上限会出事：抖音那条入口有 4 条链接 + 2 个包名，通道单次超时 10 秒，
/// 最坏情况要把 10 秒等满好几轮 —— 用户站在柜子前看着进度圈转一两分钟。
/// 4 秒是「人还能忍」与「真机上绝大多数成功调用都在几百毫秒内」之间取的：
/// 超过这个时间说明原生侧已经卡住或全在超时，继续等也等不到成功。
const Duration kPickupCodeRunBudget = Duration(seconds: 4);

/// 快捷入口的执行器：把「多级回退」从页面里拿出来，单独可测。
///
/// 顺序照抄 QuickJump：
/// 1. [PickupCodeEntry.links] 按书写顺序逐条试（每条可限定包名）；
/// 2. 全失败后逐个拉起 [PickupCodeEntry.appPackages]；
/// 3. 还不行才用 [PickupCodeEntry.webUri] 的网页兜底；
/// 4. 全部失败才报错，并把最后一个原因码交给界面翻译成人话。
///
/// **总预算** [kPickupCodeRunBudget]：每步开始前检查还剩多少时间，用完就收手
/// 并返回 [PickupCodeRunStatus.failed]。单个 Platform 调用自己的 10 秒超时
/// 仍由通道层负责（见 `timed_method_channel.dart`），这里管的是**整条链**。
///
/// 平台能力经 [PickupCodePlatform] 注入：单测用一个记录调用顺序的假实现即可
/// 覆盖「第 1 条失败才会试第 2 条」「直达成功就不该再拉起 App」这类断言。
class PickupCodeRunner {
  PickupCodeRunner({PickupCodePlatform? platform, Duration? budget})
    : _platform = platform ?? const PickupCodeNativeChannel(),
      _budget = budget ?? kPickupCodeRunBudget;

  /// 生产侧共享实例（无状态，持有的是 const 通道实现）。
  static final PickupCodeRunner instance = PickupCodeRunner();

  final PickupCodePlatform _platform;
  final Duration _budget;

  bool get isSupported => _platform.supported;

  /// 跑一条入口。[alreadyInstalled] 是进页面时批量查到的「已安装包名」，
  /// 传了就跳过没装的 App（省掉必然失败的调用）；不传则逐个试。
  Future<PickupCodeRunResult> run(
    PickupCodeEntry entry, {
    Set<String>? alreadyInstalled,
  }) async {
    if (!_platform.supported) {
      return const PickupCodeRunResult(PickupCodeRunStatus.unsupported);
    }
    final stopwatch = Stopwatch()..start();
    PickupCodeRunResult finish(PickupCodeRunStatus status, [String? reason]) {
      stopwatch.stop();
      return PickupCodeRunResult(
        status,
        reason: reason,
        elapsed: stopwatch.elapsed,
      );
    }

    bool budgetLeft() => stopwatch.elapsed < _budget;

    String? lastReason;
    for (final link in entry.links) {
      if (!budgetLeft()) {
        return finish(PickupCodeRunStatus.failed, 'timeout');
      }
      final uri = link.uri.trim();
      if (uri.isEmpty) {
        continue;
      }
      final result = await _platform.launchUri(
        uri: uri,
        package: link.package,
        clearTask: entry.clearTask,
      );
      if (result.ok) {
        return finish(PickupCodeRunStatus.launched);
      }
      lastReason = result.reason ?? lastReason;
    }
    for (final package in entry.appPackages) {
      // 明确知道没装就不试了：getLaunchIntentForPackage 必然返回空，
      // 白等一轮（有些机型上这轮要走满通道超时）。
      if (alreadyInstalled != null && !alreadyInstalled.contains(package)) {
        lastReason = lastReason ?? 'app_not_found';
        continue;
      }
      if (!budgetLeft()) {
        return finish(PickupCodeRunStatus.failed, 'timeout');
      }
      final result = await _platform.launchApp(
        package: package,
        clearTask: entry.clearTask,
      );
      if (result.ok) {
        return finish(PickupCodeRunStatus.openedApp);
      }
      lastReason = result.reason ?? lastReason;
    }
    final webUri = entry.webUri?.trim();
    if (webUri != null && webUri.isNotEmpty) {
      if (!budgetLeft()) {
        return finish(PickupCodeRunStatus.failed, 'timeout');
      }
      final result = await _platform.launchUri(
        uri: webUri,
        clearTask: entry.clearTask,
      );
      if (result.ok) {
        return finish(PickupCodeRunStatus.openedWeb);
      }
      lastReason = result.reason ?? lastReason;
    }
    return finish(PickupCodeRunStatus.failed, lastReason);
  }

  /// 进页面时批量查「哪些 App 装了」，给 [run] 的 `alreadyInstalled` 用。
  ///
  /// 查不到（非 Android / 通道不可用）返回 null，调用方据此退回「逐个试」。
  Future<Set<String>?> installedPackages(List<String> packages) async {
    if (!_platform.supported || packages.isEmpty) {
      return null;
    }
    try {
      return await _platform.installedPackages(packages);
    } catch (_) {
      return null;
    }
  }
}
