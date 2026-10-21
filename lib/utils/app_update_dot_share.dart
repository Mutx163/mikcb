/// 「有可用更新」这个状态的**跨页面共享登记**（2026-10-21 立）。
///
/// ## 为什么需要它
///
/// 用户口径：「为什么切换到月视图，右上角的球会闪一下，本来有更新红点，闪一下
/// 又不显示了」。
///
/// 红点画在「更多」那颗玻璃球上（`HomeMoreActionIcon.showUpdateDot`）。这个值
/// 来自 `UpdateCheckController.hasUpdate`，而那个 controller **只有首页创建**
/// （`TimetableScreen`），独立页面（月视图等）既拿不到它、也不该重新发起一次
/// 网络检查。
///
/// 于是独立页此前一律传 `showUpdateDot: false` —— 从首页切过去，红点凭空消失。
/// 用户读到的不是"这个页面没有更新"，而是"**球闪了一下、点丢了**"，因为那颗球
/// 本身在两条页面栈里都有、只有点不见了。
///
/// ## 设计：只登记结果的单向广播
///
/// 首页查到结果后 `publish` 一次；其他页面 `hasUpdate` 读取。
/// **不持有 controller、不触发检查** —— 检查仍是首页的职责，这里只解决
/// "同一个事实在别处读不到"的问题。
///
/// 为什么不注入 `ChangeNotifier`：独立页在坞内切换时会被重建，而检查结果的生命
/// 周期属于整个 App 会话（一次启动查一次）。做成静态登记与
/// `HomeWallpaperLuminanceShare` / `HomeStartupVisualPrimer` 同一套取舍 ——
/// 那几个都是"算了很久、只在内存里活一次"的小数据。
library;

/// 有可用更新的共享登记。
abstract final class AppUpdateDotShare {
  static bool _hasUpdate = false;
  static bool _known = false;

  /// 首页查到结果后登记。
  ///
  /// [hasUpdate] 为 false 也要登记（`_known` 置真）：否则独立页无法区分
  /// "确实没有更新"与"还没查过"，只能一律不画点或一律画点，两种都会错。
  static void publish({required bool hasUpdate}) {
    _hasUpdate = hasUpdate;
    _known = true;
  }

  /// 是否**已经**查到过结果。未查过时调用方应当按"不画点"处理（与首页首帧一致，
  /// 避免出现"别的页面有点、回首页反而没有"的倒挂）。
  static bool get isKnown => _known;

  /// 当前是否有可用更新；未查过时返回 false。
  static bool get hasUpdate => _known && _hasUpdate;

  /// 测试用：清空登记，免得上一条用例的值漏到下一条。
  static void resetForTesting() {
    _hasUpdate = false;
    _known = false;
  }
}
