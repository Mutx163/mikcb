/// 首页「三视图」的模式 ↔ 底栏内嵌页 id 的唯一映射口径（2026-10-24）。
///
/// ## 为什么存在
///
/// 周 / 日是首页 State 自己的两份选择（`selectedWeekForDayView` +
/// `selectedDayOfWeek`），月视图却是**底栏内嵌页**（`dockInlinePageId`）。
/// 于是「当前是哪个视图」这件事以前有两处各问各的：日/周问持久化枚举，月问内嵌 id。
/// 要把月视图升级成真正的第三个视图（能持久化、能冷启动恢复），必须把这两个
/// 表示法之间的换算收成一处 —— 否则「停在月视图」这件事会有两种写法，
/// 而两种写法必然会漂。
///
/// ## 一条容易写错的地方
///
/// 「切走内嵌页之后处在哪个视图」必须照**当前画面**判（[isDayView]），不能照
/// 持久化的旧值当 fallback：旧值可能停在 month，而画面上内嵌页已经关了 ——
/// 拿旧值当依据就写成「关掉月视图 → 又落回月视图」。
///
/// 本文件只做映射，不碰 UI，也不碰持久化：期望值是能人肉推出来的，
/// 契约测试在 `test/domain/home_view_mode_test.dart`。
library;

import '../models/timetable_settings.dart';

/// 月视图在底栏内嵌页登记表里的键。
///
/// ⚠️ 这个字符串不是本地发明的：它是 `kInlineDockPages` 的注册键
/// （见 `lib/screens/home_menu_route_registry.dart` 的 `id: 'monthView'`）。
/// 改了这里必须同步那边，否则恢复出来的是一个查不到的 id = 白屏。
const String kMonthViewInlinePageId = 'monthView';

/// 这个内嵌页 id 是不是月视图。
bool isMonthInlinePage(String? inlineId) => inlineId == kMonthViewInlinePageId;

/// 恢复时应摆回的内嵌页 id（null = 显示课表本体）。
///
/// 只问形态，不问底栏排列：经典形态下 `TimetableHomeDockShell` 在
/// `!glassDockForm` 直接返回 dockContent（:85），内嵌页那层连建都不建 ——
/// 摆回 month 只是往 State 里塞一个渲染不出来的 id。
///
/// ⚠️ 「底栏把日/周两格都撤掉后，月视图出不去」这条**故意不在这里管**：那个洞
/// 是既有的（当场点进月视图同样出不去——再点当前格无动作，系统返回是直接退出
/// App），持久化没让它变坏。要修该修底栏的出口判据，不该在恢复处加一条只在
/// 重启生效的特殊规则，否则同一操作当场与重启结果不同。
String? restoreInlinePageId(TimetableSettings settings) =>
    settings.homeNavigationForm == HomeNavigationForm.glassDock &&
            settings.timetableHomeViewMode == TimetableHomeViewMode.month
        ? kMonthViewInlinePageId
        : null;

/// 切内嵌页（含收回）之后，首页处在哪个视图模式。
///
/// [isDayView] 是**当前画面**的状态（`selectedDayOfWeek != null &&
/// selectedWeekForDayView != null`），不是持久化值：持久化值可能停在 month
/// 而画面上已经是周课表，拿它当依据会写出「关掉月视图又落回月视图」。
///
/// - [inlineId] 是月视图 ⇒ [TimetableHomeViewMode.month]；
/// - 是别的内嵌页（设置、统计…）⇒ 照 [isDayView]，那些页不是「视图」，
///   不该改写用户的浏览模式；
/// - 收回课表本体（null）⇒ 照 [isDayView]，此路**不可能**得到 month。
TimetableHomeViewMode homeViewModeForInlinePage({
  required String? inlineId,
  required bool isDayView,
}) {
  if (isMonthInlinePage(inlineId)) {
    return TimetableHomeViewMode.month;
  }
  return isDayView ? TimetableHomeViewMode.day : TimetableHomeViewMode.week;
}
