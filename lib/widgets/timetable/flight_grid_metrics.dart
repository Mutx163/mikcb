/// 日视图「卡片飞行」用的**网格几何**（2026-10-21 建，2026-10-23 收窄）。
///
/// 抽成独立文件的理由：`timetable_screen.dart` 有行数棘轮（只减不增），而这段
/// 计算属于几何、不属于课表页的业务状态；同时它有三个消费者（周页、转场壳、
/// 屏幕），放在任何一侧都会让另外两处「照抄一份」。
///
/// ## 为什么必须收口到一处
///
/// 「卡片对卡片」的起点 = 某节课在网格里占的那个矩形。只要节高或网格原点差一点，
/// 卡片第一帧就不在卡片上，读作「动画和卡片不是一对一」（用户 2026-10-21 的原话）。
/// 而这两个量都由**周页的真实布局**决定，不是想当然的常量：
///
/// - 节高见 [flightGridSectionHeight]（含玻璃缝隙）；
/// - 网格原点见 [flightGridOriginYInLayer]（星期栏下方 + 玻璃缝隙）。
///
/// ## 2026-10-23 收窄
///
/// 原先这里还存着一整套「手写近似锚点」（`flightEndTitleTop = 50`、
/// `flightEndSubtitleTop = 78.5`、`flightStartTitleTop(...)` …）与合成它们的
/// `flightCardEndsFor`。它们已被 `flight_text_metrics.dart` 的**按真实排版复算**
/// 取代：近似值与真值差几像素，起飞/落定就会各跳一次（用户口径「三个位置」）。
/// 手写常量不再保留 —— 留着只会让下一个人以为它们还有效。
library;

import 'package:flutter/material.dart';

import '../../domain/timetable_layout.dart';
import '../../models/timetable_settings.dart';
import '../../utils/home_page_background.dart';
import '../home_page_region_blur.dart';
import 'timetable_weekday_header.dart';

/// 星期栏与网格之间那条玻璃缝隙的高度。
///
/// 判据与周页 `TimetableWeekPage` 完全同源：**有壁纸**并且星期栏开了模糊时，
/// 两者之间会插一条 [homePageFrostedRegionSeamOverlap]；否则为 0。
///
/// 漏掉它的后果是可累积的：缝隙被算成 0 时，自适应节高会偏大 `4 / 节数`，
/// 12 节时每节差 0.33dp、第 12 节累计偏 4dp —— 越靠后的课偏得越多。
double flightChromeSeam(TimetableSettings settings) {
  final hasBackdrop =
      hasHomePageBackdrop(settings) && settings.homePageWeekdayBarBlurEnabled;
  return hasBackdrop ? homePageFrostedRegionSeamOverlap : 0;
}

/// 网格节高 —— 与周页交给网格的那个值**必须是同一个**。
///
/// [surfaceHeight] 是课表区域（`timetableSurfaceKey` 那个 Padding）的真实高度，
/// **不是**整屏高度：整屏高比课表区域多出「状态栏 + 标题栏」，拿它算出来的节高
/// 会偏大，于是飞行起点的高度全错（实测起点只有 1px，卡片像从星期栏那条线上
/// 冒出来）。
double flightGridSectionHeight({
  required TimetableSettings settings,
  required double surfaceHeight,
}) {
  return gridSectionHeight(
    settings: settings,
    availableHeight: surfaceHeight,
    weekdayHeaderHeight: TimetableWeekdayHeader.height,
    chromeSeam: flightChromeSeam(settings),
  );
}

/// 网格内容区相对**转场层顶部**（= 星期栏底）的纵向偏移。
///
/// 转场层顶在星期栏下方，而网格又在「星期栏 vs 网格」那条缝隙之下，所以两者
/// 之间正好差一条 [flightChromeSeam]。
double flightGridOriginYInLayer(TimetableSettings settings) =>
    flightChromeSeam(settings);

/// 周网格卡的圆角（`course_card.dart` 的 `_buildCompactCard` 写死 8）。
const double flightStartCardRadius = 8;

/// 日视图议程卡的圆角 —— 正源是 `_TimetableScreenState._dayViewCardRadius`。
///
/// 必须与那边同值：飞行卡落地那一帧会换成真议程卡，两边不同值就是一次圆角跳变
/// （用户口径「三个环节的圆角也是，圆角应该是渐变的才对」）。
const double flightEndCardRadius = 20;

/// 日视图摘要卡（带关闭叉那张）的高度。
///
/// 实测（`probe_summary_card_test`：落定后摘要卡 `T98.0 H107.0`）。它随当天课程数
/// 变化，推不出来；转场里只用它决定「拉出来露到哪儿」，107 足够（露到卡片底边
/// 即可，多一点少一点都在卡片内部，不影响观感）。
const double kDayViewSummaryCardHeight = 107;

/// 日视图议程卡的课名字号。
///
/// 议程卡用的是 `Theme.of(context).textTheme.titleMedium`（不是写死的数），所以
/// 这里必须**问主题**而不是抄一个常数：主题换字体方案时，抄来的数会让飞行卡
/// 落地那一帧字号跳一下。
double flightEndTitleSize(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium?.fontSize ?? 16;
