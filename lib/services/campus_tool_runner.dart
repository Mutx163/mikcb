import '../models/campus_tool_entry.dart';
import 'campus_tool_launcher.dart';

/// 一次点击最终走到了哪一级回退。
enum CampusToolRunStatus {
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

class CampusToolRunResult {
  const CampusToolRunResult(this.status, {this.reason});

  final CampusToolRunStatus status;

  /// 最后一次失败的原因码；成功时为 null。
  final String? reason;

  bool get ok =>
      status == CampusToolRunStatus.launched ||
      status == CampusToolRunStatus.openedApp ||
      status == CampusToolRunStatus.openedWeb;
}

/// 快捷入口的执行器：把「多级回退」从页面里拿出来，单独可测。
///
/// 顺序照抄 QuickJump：
/// 1. [CampusToolEntry.links] 按书写顺序逐条试（每条可限定包名）；
/// 2. 全失败后逐个拉起 [CampusToolEntry.appPackages]；
/// 3. 还不行才用 [CampusToolEntry.webUri] 的网页兜底；
/// 4. 全部失败才报错，并把最后一个原因码交给界面翻译成人话。
///
/// 平台能力经 [CampusToolPlatform] 注入：单测用一个记录调用顺序的假实现即可
/// 覆盖「第 1 条失败才会试第 2 条」「直达成功就不该再拉起 App」这类断言。
class CampusToolRunner {
  CampusToolRunner({CampusToolPlatform? platform})
    : _platform = platform ?? const CampusToolNativeChannel();

  /// 生产侧共享实例（无状态，持有的是 const 通道实现）。
  static final CampusToolRunner instance = CampusToolRunner();

  final CampusToolPlatform _platform;

  bool get isSupported => _platform.supported;

  Future<CampusToolRunResult> run(CampusToolEntry entry) async {
    if (!_platform.supported) {
      return const CampusToolRunResult(CampusToolRunStatus.unsupported);
    }
    String? lastReason;
    for (final link in entry.links) {
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
        return const CampusToolRunResult(CampusToolRunStatus.launched);
      }
      lastReason = result.reason ?? lastReason;
    }
    for (final package in entry.appPackages) {
      final result = await _platform.launchApp(
        package: package,
        clearTask: entry.clearTask,
      );
      if (result.ok) {
        return const CampusToolRunResult(CampusToolRunStatus.openedApp);
      }
      lastReason = result.reason ?? lastReason;
    }
    final webUri = entry.webUri?.trim();
    if (webUri != null && webUri.isNotEmpty) {
      final result = await _platform.launchUri(
        uri: webUri,
        clearTask: entry.clearTask,
      );
      if (result.ok) {
        return const CampusToolRunResult(CampusToolRunStatus.openedWeb);
      }
      lastReason = result.reason ?? lastReason;
    }
    return CampusToolRunResult(
      CampusToolRunStatus.failed,
      reason: lastReason,
    );
  }
}
