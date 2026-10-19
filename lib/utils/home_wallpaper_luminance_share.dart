import 'package:flutter/foundation.dart';

/// 本进程里**已经真的采到过**的壁纸亮度带（按采样缓存键索引，只留最新一份）。
///
/// ## 为什么需要它
///
/// 首页上「直接压在壁纸上的墨色」（底栏玻璃坞的标签与圆钮图标、左侧时间轴的
/// 数字、星期栏、顶栏…）用白墨还是黑墨，是由**壁纸对应那条带的亮度**推出来的。
/// 那个亮度得先把整张照片解码 + 读像素才算得出，是异步的；在它落地之前，代码
/// 只能**按主题明暗先猜一个极性**（见 `SoftGlassPolarityFade` 与
/// `HomeStartupVisualPrimer` 的类注释，两处都是同一个「先猜再修正」）。
///
/// 冷启动那一次由启动预热器兜住（开机时就把带子算好，首页首帧直接用）。但
/// **第二份首页**没这个兜底 —— 「外观编辑」页中间那块缩尺预览不是首页本体的
/// 缩小，而是一份整屏 1:1 的**真首页新实例**（`TimetableScreen` 的另一个
/// State，见 `timetable_home_preview_scope.dart`）。它的亮度字段是从零开始的，
/// 而预热器只认**开机时那张壁纸**：壁纸是开机之后才换的（每日自动换壁纸、
/// 在「课表页面」设置里换壁纸）就取不到，于是它先按主题猜 —— 浅色主题猜深墨。
///
/// 后果（用户 2026-10-10 报的）：点底栏「外观编辑」，首页缩进那张预览卡的过程
/// 里放的是首页的静态快照（墨色正确），**缩到位、卡片换成预览自己烤的第一张图
/// 那一帧**，底栏标签与时间轴数字按主题猜成了深色/灰色 —— 读起来就是「白色的
/// 字闪了一下黑」，等预览自己的采样落地（一两百毫秒）才翻回白。
///
/// ## 口径
///
/// 真实首页**采样成功**时把结果登记进来（`publish`），此后新建的首页实例
/// （缩尺预览）在首帧取用同一份键上的同一个值 —— 两边墨色从第一帧起就同源，
/// 交接处不会出现「猜 → 修正」那一次翻面。
///
/// * 键就是采样缓存键本身（`homePageBackdropSampleKey`：路径 + 视口 + 取景 +
///   放大倍数）。**不能只按路径索引**：取景变了（拖动位置 / 双指缩放）时
///   同一条路径上的亮度带会变，只认路径就会把旧取景的极性塞给新取景。
/// * 只留最新一份：同一时刻只有一张壁纸在显示，登记与取用都发生在帧内，不值得
///   养一张表（也避免这个全局悄悄长成缓存）。
/// * 采样失败（解不开的图 / 文件正在写）**不登记**，也不清除旧值：取用方按键
///   匹配不上自然回落到主题兜底，与旧行为一致。
abstract final class HomeWallpaperLuminanceShare {
  static String? _key;

  static ({double top, double weekday, double body})? _bands;

  /// 取 [key] 这份采样键上已登记的亮度带；没登记过（或键不同）返回 null。
  static ({double top, double weekday, double body})? bandsFor(String key) =>
      _key == key ? _bands : null;

  /// 取亮度带：**精确键优先；不命中时忽略视口再比一次**。
  ///
  /// 调用方应当用它，而不是直接调 [bandsFor] —— 后者不命中就返回 null，调用方
  /// 随之回落到「按主题猜极性」，首页 chrome 会闪一次墨色翻面（用户 2026-10-19
  /// 报的「进设置时星期栏与标题闪白再闪回来」）。
  ///
  /// 为什么只放掉**视口**这一维：键里的取景（alignX / alignY）与倍率会真的改变
  /// 那三条带的平均亮度，旧值必须作废（见 [bandsFor] 的用例）；而视口尺寸变化
  /// （进出页面时状态栏 / 导航栏 inset 变了）几乎不影响平均值，却足以让精确键
  /// 不命中 —— 那正是"本来知道却退回去猜"的场景。
  static ({double top, double weekday, double body})? resolve(String key) {
    final exact = bandsFor(key);
    if (exact != null) {
      return exact;
    }
    final recorded = _key;
    final bands = _bands;
    if (recorded == null || bands == null) {
      return null;
    }
    return _withoutViewport(recorded) == _withoutViewport(key) ? bands : null;
  }

  /// 把键里的**视口**那一段挖空（键格式见 `homePageBackdropSampleKey`：
  /// `路径|视口|alignX|alignY|scale`）。
  static String _withoutViewport(String key) {
    final parts = key.split('|');
    if (parts.length < 2) {
      // 不是本仓的键格式：不做兜底（原样返回 ⇒ 只有完全相等才算命中）。
      return key;
    }
    parts[1] = '';
    return parts.join('|');
  }

  /// 登记一次**成功**的采样结果（见类注释：失败不要调）。
  static void publish(
    String key,
    ({double top, double weekday, double body}) bands,
  ) {
    _key = key;
    _bands = bands;
  }

  /// 测试用：清空登记，免得上一条用例的值漏到下一条。
  @visibleForTesting
  static void resetForTesting() {
    _key = null;
    _bands = null;
  }
}
