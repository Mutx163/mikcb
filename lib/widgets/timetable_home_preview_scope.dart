import 'package:flutter/material.dart';

/// 「把**真首页**嵌进别处缩尺预览」时用的外部控制器。
///
/// 「外观编辑」页要的是「整个首页原样缩小」——最忠实的做法就是把
/// `TimetableScreen` 本体按整屏尺寸渲染，再整体缩放居中。那样一来首页就不再是
/// 唯一的实例，会多出两件本来由它独占的事情，本 scope 就是把这两件事交出去：
///
/// * **日 / 周切换**：编辑页顶部的分段按钮要用 [dayView] / [dayOfWeek] 两个
///   notifier 驱动嵌进来的那份首页（首页的日视图状态是它自己的私有 State，
///   外面拨不动）。宿主改了值，首页那一份按同一套内部路径开合日视图。
/// * **不进「回访状态」**：预览里的开合**不算用户浏览过**——不能写进
///   `timetableHomeViewMode`，否则在编辑页点一下「日课表」，退回首页就成了日视图。
///   首页侧靠「预览模式」这个标记短路持久化与截屏监听（见 `_TimetableScreenState`）。
///
/// **只在预览里挂**：正常首页没有这个 scope，行为与接入前逐字一致。
class TimetableHomePreviewScope extends InheritedWidget {
  const TimetableHomePreviewScope({
    super.key,
    required this.dayView,
    required this.dayOfWeek,
    required super.child,
  });

  /// 预览要不要显示日视图（true = 日，false = 周）。
  ///
  /// 宿主**初始值照首页那份持久化的浏览状态给**（`timetableHomeViewMode`）：
  /// 两边一致，进页第一帧就不会出现「卡片先显示首页快照的那个视图、转场一结束
  /// 再跳成另一个」的闪跳。首页侧对这个 notifier 是**幂等**的 —— 值不变就不动，
  /// 值一致时重复下发也不会把已经开着的日视图关掉。
  final ValueNotifier<bool> dayView;

  /// 日视图看星期几（1 = 周一 … 7 = 周日）。
  ///
  /// 同源取 `timetableLastViewedDayOfWeek`（首页「日课表」Tab 看的就是它）；
  /// 落在不显示的日子里时首页会按可见日归一。
  final ValueNotifier<int> dayOfWeek;

  static TimetableHomePreviewScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TimetableHomePreviewScope>();
  }

  /// 内容变化一律走两个 notifier，scope 本身不需要触发重建。
  @override
  bool updateShouldNotify(TimetableHomePreviewScope oldWidget) => false;
}
