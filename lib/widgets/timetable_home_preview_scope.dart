import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 首页纵向滚动位置（按 `PageStorageKey` 的字符串值索引）的对外快照。
///
/// 为什么需要它：缩尺预览里那份首页是**另一条路由里的另一个实例**，它的滚动
/// 位置走自己的 `PageStorage`（`ModalRoute` 每条路由一份桶），与真实首页那份
/// **毫无关系**。于是「在首页滑下去再进编辑页」时，卡片先显示的是首页快照
/// （滑下去的样子），落定后换成预览自己烤的图 —— 预览那份停在 0，用户读到的
/// 就是「进编辑页，预览突然置顶」（用户 2026-09-27 反馈）。
///
/// 交接方式与日 / 周完全同源：**真实首页报、预览取**，两边用同一套 key 字符串
/// （见 `timetable_screen.dart` 的 `_dayAgendaScrollKey` / `_weekGridScrollKey`）。
/// 只报**活着的**滚动体：没访问过的日子 / 周没有滚动位置可言，与真实首页一致
/// （0）。
@immutable
class HomeScrollOffsets {
  const HomeScrollOffsets(this.offsets);

  const HomeScrollOffsets.empty() : offsets = const <String, double>{};

  /// `PageStorageKey` 的字符串值 → 纵向滚动偏移（像素）。
  final Map<String, double> offsets;

  /// 取某个 key 的偏移；没有就是 0（与真实首页那份一致）。
  double operator [](String key) => offsets[key] ?? 0;

  bool get isEmpty => offsets.isEmpty;

  HomeScrollOffsets withOffset(String key, double pixels) =>
      HomeScrollOffsets(<String, double>{...offsets, key: pixels});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is HomeScrollOffsets && mapEquals(other.offsets, offsets);
  }

  @override
  int get hashCode => Object.hashAllUnordered(
    offsets.entries.map((e) => Object.hash(e.key, e.value)),
  );
}

/// 真实首页当前报上来的纵向滚动位置（全局，见类注释）。
final ValueNotifier<HomeScrollOffsets> homeScrollOffsets = ValueNotifier(
  const HomeScrollOffsets.empty(),
);

/// 真实首页报一块纵向滚动体的位置（`timetable_screen.dart` 在滚动时调）。
///
/// **只有真实首页那份会报**：缩尺预览里那份自己就是被喂的一方，再报回去会把
/// 真实首页的位置覆盖成预览的（见 `TimetableHomePreviewScope` 类注释）。
///
/// 值没变就不发：滚动通知每帧都来，而这份快照没人监听（编辑页只在进页那一刻读
/// 一次），没必要每帧造一个新 map。
void publishHomeScrollOffset(String key, double pixels) {
  final current = homeScrollOffsets.value;
  final existing = current.offsets[key];
  if (existing != null && (existing - pixels).abs() < 0.5) {
    return;
  }
  homeScrollOffsets.value = current.withOffset(key, pixels);
}

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
/// * **滚动位置**：预览那份的滚动位置来自自己的 `PageStorage` 桶（每条路由一份），
///   与真实首页那份无关，于是进页后卡片会「突然置顶」。宿主把真实首页的滚动位置
///   经 [scrollOffsets] 递进来，预览那份按同一套 key 建自己的滚动控制器
///   （详见 [HomeScrollOffsets]）。
///
/// **只在预览里挂**：正常首页没有这个 scope，行为与接入前逐字一致。
class TimetableHomePreviewScope extends InheritedWidget {
  const TimetableHomePreviewScope({
    super.key,
    required this.dayView,
    required this.dayOfWeek,
    this.scrollOffsets = const HomeScrollOffsets.empty(),
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

  /// 预览那份首页的纵向滚动**初值**（按 `PageStorageKey` 的字符串值索引）。
  ///
  /// 宿主在**进页那一刻**把真实首页报上来的 [homeScrollOffsets] 原样递进来
  /// （编辑页：`_homeScrollAtEntry`）。首页那份按 key 取初值给自己的滚动控制器，
  /// 于是预览第一帧就和首页快照逐像素同源 —— 既不闪跳，也确实是「你现在看到
  /// 的那一屏」。
  final HomeScrollOffsets scrollOffsets;

  static TimetableHomePreviewScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TimetableHomePreviewScope>();
  }

  /// 内容变化一律走两个 notifier，scope 本身不需要触发重建。
  @override
  bool updateShouldNotify(TimetableHomePreviewScope oldWidget) => false;
}
