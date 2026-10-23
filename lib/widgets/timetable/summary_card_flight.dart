library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
import '../../utils/home_page_background.dart';
import 'day_view/day_view_agenda_surface.dart';
import 'day_view/day_view_ink_style.dart';
import 'day_view/day_view_summary_card.dart';

/// 摘要卡「从星期栏的当日格里长出来」的两端几何与内容（2026-10-23）。
///
/// ## 用户要的是什么
///
/// > 「日视图带叉叉的日期卡片，能不能从顶部星期栏的当日的星期里面，一对一缩放
/// > 出来，效果和课程卡片差不多」
///
/// 也就是说摘要卡也走**卡片对卡片**：起点是星期栏里那一天的那一格（约 50×40
/// 的小方块），终点是日视图顶部那张摘要卡。中间它自己长大、卡里的内容跟着连续
/// 变化，与课程卡同一套机制、同一条曲线、同起同落。
///
/// ## 起点是**算**出来的，不是量出来的
///
/// 星期栏的格子是纯布局产物：`时间列宽 + 下标 × 日宽`，日宽 =
/// `(视口宽 − 时间列宽) / 可见天数`，格子左右各 1dp 外边距。算出来的值与真实
/// 格子逐像素一致（`test/domain/summary_card_flight_test.dart` 对着真实
/// `TimetableWeekdayHeader` 校验）。
///
/// 为什么不去量：日视图里星期栏**同时存在两份**（覆盖层一份、下面周页各一份），
/// 用 `GlobalKey` 去量必然撞 `Duplicate GlobalKey` —— 本仓踩过这个坑。
///
/// ## 终点必须量
///
/// 摘要卡高度随内容变（有考试 / 有「正在进行」/ 有情侣空闲摘要时更高），算不出来。
/// 所以终点用 `MeasureFlightTarget` 实测，与课程卡同一套。
///
/// ## 实测锚点（392 屏宽 / 40 高 / 时间列 40）
///
/// 星期格（起点，相对格顶）：
///
/// | 元素 | 顶边 | 字号 | 字重 |
/// |---|---|---|---|
/// | 星期名「周五」 | 6.0 | 10 | w800 |
/// | 日期「03/20」 | 22.0 | 8.5 | w400 |
///
/// 摘要卡（终点，相对卡表面）：
///
/// | 元素 | 顶边 | 字号 | 字重 |
/// |---|---|---|---|
/// | 「今天 · 第 3 周」 | 14.5 | 14 | w500 |
/// | 日期标题 | 46.0 | 16 | w400 |
/// | 计数胶囊 | 72.0（高 21，内文字 75.0 / 11sp / w600） | | |
/// | 关闭叉 | 12.0（右内缩 14） | 18 | — |

/// 摘要卡转场的两端输入。
class SummaryFlightSpec {
  const SummaryFlightSpec({
    required this.startCell,
    required this.endRect,
    required this.weekdayLabel,
    required this.cellDateLabel,
    required this.titleLabel,
    required this.metaLabel,
    required this.countLabel,
    required this.fill,
    required this.ink,
    required this.mutedInk,
    this.startRadius = 14,
    this.endRadius = 20,
  });

  /// 起点：星期栏那一格在**转场层局部坐标**里的矩形。
  final Rect startCell;

  /// 终点：摘要卡**表面**在转场层局部坐标里的矩形（实测后换算）。
  final Rect endRect;

  /// 星期格里的星期名（「周五」）。
  final String weekdayLabel;

  /// 星期格里的日期（「03/20」）。
  final String cellDateLabel;

  /// 摘要卡的日期标题（「03月20日 周五」）—— 终点那一行的完整文案。
  final String titleLabel;

  /// 终点才有的「今天 · 第 3 周」。
  final String metaLabel;

  /// 终点才有的计数胶囊（「1 门课」）。
  final String countLabel;

  /// 卡面填充（摘要卡的 `foruiTheme.colors.background`）。
  final Color fill;

  /// 主文字色。
  final Color ink;

  /// 次要文字色（「今天 · 第几周」、胶囊文字）。
  final Color mutedInk;

  /// 圆角：星期格 `InkWell.borderRadius` 14 → 摘要卡 20。
  final double startRadius;
  final double endRadius;
}

/// 摘要卡飞行的输入（起点由**转场层自己算**，终点由调用方量）。
///
/// 起点为什么不在调用方算：转场层已经知道自己多宽、时间列多宽、可见几天、
/// 选中第几天（这些字段本来就有）。在调用方再算一遍等于把同一个公式抄两份，
/// 而 `timetable_screen.dart` / `timetable_day_view_part.dart` 都有行数棘轮。
class SummaryFlightInput {
  const SummaryFlightInput({
    required this.endRectOnScreen,
    required this.weekdayLabel,
    required this.cellDateLabel,
    required this.titleLabel,
    required this.metaLabel,
    required this.countLabel,
    required this.fill,
    required this.ink,
    required this.mutedInk,
  });

  /// 摘要卡**表面**的实测屏幕矩形（`MeasureFlightTarget` 的结果）。
  final Rect endRectOnScreen;

  /// 星期格里的星期名（「周五」）。
  final String weekdayLabel;

  /// 星期格里的日期（「03/20」）。
  final String cellDateLabel;

  /// 摘要卡的日期标题（「03月20日 周五」）。
  final String titleLabel;

  /// 终点才有的「今天 · 第 3 周」。
  final String metaLabel;

  /// 终点才有的计数胶囊（「1 门课」）。
  final String countLabel;

  final Color fill;
  final Color ink;
  final Color mutedInk;

  /// 换算成 [SummaryFlightSpec]（终点减层原点，起点按层宽算）。
  SummaryFlightSpec specInLayer({
    required Offset layerOrigin,
    required Rect startCell,
  }) => SummaryFlightSpec(
    startCell: startCell,
    endRect: endRectOnScreen.shift(-layerOrigin),
    weekdayLabel: weekdayLabel,
    cellDateLabel: cellDateLabel,
    titleLabel: titleLabel,
    metaLabel: metaLabel,
    countLabel: countLabel,
    fill: fill,
    ink: ink,
    mutedInk: mutedInk,
  );
}

/// 从 State 那侧的三样输入（终点矩形 / 设置 / 日期）拼出飞行所需的全部内容。
///
/// 放在这里而不是 `timetable_screen.dart`：那两个文件的行数棘轮已经贴顶
/// （只减不增），一段 20 行的组装会把守卫顶爆。
SummaryFlightInput buildSummaryFlightInput({
  required BuildContext context,
  required Rect endRect,
  required TimetableSettings settings,
  required int week,
  required int dayOfWeek,
  required DayViewInkEnvironment inkEnvironment,
  required bool isToday,
  required int courseCount,
  required int scheduleCount,
  required int taskCount,
}) {
  final fill = context.theme.colors.background;
  final l10n = AppLocalizations.of(context)!;
  final date = _dateForWeekDay(settings, week, dayOfWeek);
  final weekdayLabels = <String>[
    l10n.weekdayMon,
    l10n.weekdayTue,
    l10n.weekdayWed,
    l10n.weekdayThu,
    l10n.weekdayFri,
    l10n.weekdaySat,
    l10n.weekdaySun,
  ];
  final weekday = dayOfWeek >= 1 && dayOfWeek <= weekdayLabels.length
      ? weekdayLabels[dayOfWeek - 1]
      : '$dayOfWeek';
  final cellDate = date == null
      ? ''
      : '${date.month.toString().padLeft(2, '0')}/'
            '${date.day.toString().padLeft(2, '0')}';
  final title = date == null
      ? weekday
      : '${date.month}月${date.day}日 $weekday';
  // ⚠️ 判墨必须与真摘要卡**逐输入一致**，否则起飞与落定两端的字色不同。
  //
  // 三件事都要对齐（少一件都会偏）：
  // 1. 材质档：玻璃档的卡面亮度是「卡色 × 染色比例 + 壁纸 × 余量」，按实体档判
  //    会把字判成黑的，落定后又变白（用户口径「材质不一样」的色那一半）。
  // 2. **`cardRect`**：真卡传的是实测屏幕矩形，于是取的是「卡背后那一小块壁纸」
  //    的局部亮度；这里若传 null，就退化成整屏 body 带 —— 深浅壁纸交界处会判错。
  //    传终点矩形（= 真卡落定后的位置），两端取同一块壁纸。
  // 3. 底色 `fill`：真卡用 `foruiTheme.colors.background`，这里同一来源。
  final ink = resolveSummaryCardInk(
    context: context,
    settings: settings,
    inkEnvironment: inkEnvironment,
    // 与真卡落定后同一块壁纸：终点矩形就是它的实测位置。
    cardRect: endRect,
    fill: fill,
    surfaceStyle: dayViewContentCardSurfaceStyle(
      settings,
      backdropBlurOn: inkEnvironment.backdropBlurOn,
    ),
  );
  return SummaryFlightInput(
    endRectOnScreen: endRect,
    weekdayLabel: weekday,
    cellDateLabel: cellDate,
    titleLabel: title,
    metaLabel: isToday
        ? '${l10n.todayTimetableTitle} · ${l10n.weekLabel(week)}'
        : l10n.weekLabel(week),
    // 与真摘要卡同一条判据（有课说门课、无课有日程说日程、只有作业说作业）。
    countLabel: courseCount > 0
        ? l10n.courseCountSummary(courseCount)
        : scheduleCount > 0
        ? l10n.scheduleCountSummary(scheduleCount)
        : taskCount > 0
        ? l10n.dayTaskBandCountSummary(taskCount)
        : l10n.courseCountSummary(0),
    fill: fill,
    ink: ink.ink,
    mutedInk: ink.mutedInk,
  );
}

/// 星期栏那一格对应的日期（与 `TimetableWeekdayHeader._dateForWeekDay` 同口径）。
DateTime? _dateForWeekDay(TimetableSettings settings, int week, int dayOfWeek) {
  final start = settings.semesterStartDate;
  if (start == null) {
    return null;
  }
  final normalized = DateTime(
    start.year,
    start.month,
    start.day,
  ).subtract(Duration(days: start.weekday - 1));
  return normalized.add(Duration(days: (week - 1) * 7 + dayOfWeek - 1));
}

/// 起点那一格在转场层局部坐标里的矩形。
///
/// 星期栏在转场层**之上**（转场层的顶边就是星期栏的下沿），所以起点是负高度
/// 区间：`top = -headerHeight`。
Rect summaryStartCellRect({
  required double viewportWidth,
  required double timeColumnWidth,
  required int visibleDayCount,
  required int selectedDayIndex,
  required double headerHeight,
}) {
  if (visibleDayCount <= 0) {
    return const Rect.fromLTWH(0, 0, 0, 0);
  }
  // 越界不能只靠 assert：release 下 assert 被剥掉，`clamp` 之前会算出负宽或
  // 飞出屏外的格子。真实路径存在（日视图停周六 → 用户关掉「显示周末」→ 归一化
  // 之前那一帧仍可能读到 6），静默钳到可见范围内比崩掉好，但**不能**悄悄偏一格：
  // 所以钳到边界而不是 0。
  final index = selectedDayIndex.clamp(0, visibleDayCount - 1);
  final dayWidth = (viewportWidth - timeColumnWidth) / visibleDayCount;
  // 宽度取整格：飞到的那一格就是这一个 `Expanded`（`InkWell` 铺满它），
  // `AnimatedContainer` 的 1dp 外边距只是内部留白，不是格子边界。
  return Rect.fromLTWH(
    timeColumnWidth + index * dayWidth,
    -headerHeight,
    dayWidth,
    headerHeight,
  );
}

/// 一帧要画的东西。
class SummaryFlightFrame {
  const SummaryFlightFrame({
    required this.rect,
    required this.radius,
    required this.shadowOpacity,
    required this.fill,
    required this.ink,
    required this.mutedInk,
    required this.weekdayText,
    required this.weekdayCenterFactor,
    required this.weekdayTop,
    required this.weekdayFontSize,
    required this.weekdayWeight,
    required this.weekdayOpacity,
    required this.dateText,
    required this.dateCenterFactor,
    required this.dateTop,
    required this.dateFontSize,
    required this.dateWeight,
    required this.metaText,
    required this.countText,
    required this.surfaceOpacity,
    required this.metaOpacity,
    required this.countOpacity,
    required this.closeOpacity,
  });

  /// 当前帧的卡片表面矩形（转场层局部）。
  final Rect rect;
  final double radius;
  final double shadowOpacity;
  final Color fill;
  final Color ink;
  final Color mutedInk;

  final String weekdayText;

  /// 1 = 在卡片里居中（星期格那一端），0 = 靠左 14dp（摘要卡那一端）。
  ///
  /// 用「对齐」而不是「算好的 left」：文字宽度只有真实排版知道，估算必然有误差
  /// （实测 `03/20` 会偏 10px）。插值这个因子 = 文字一边长大一边从居中挪到左边，
  /// 两端都精确。
  final double weekdayCenterFactor;
  final double weekdayTop;
  final double weekdayFontSize;
  final FontWeight weekdayWeight;
  final double weekdayOpacity;

  final String dateText;

  /// 同 [weekdayCenterFactor]。
  final double dateCenterFactor;
  final double dateTop;
  final double dateFontSize;
  final FontWeight dateWeight;

  /// 终点才有的文案（「今天 · 第 3 周」/「1 门课」）。
  final String metaText;
  final String countText;

  /// 卡面本身的可见度 0..1（起点是 0 —— 星期栏那一格**没有卡面**，只有一行字）。
  ///
  /// 起点就把不透明卡面画上去，会在星期栏上凭空冒出一块卡（它明明只是几行字）。
  /// 所以卡面按这个值淡入，文字始终画 —— 读起来是「那两个字在原地长大，卡面
  /// 随之包上来」。
  final double surfaceOpacity;

  /// 终点才有的三块：后段淡入。
  final double metaOpacity;
  final double countOpacity;
  final double closeOpacity;
}

/// 文案切换点：0.45 之前用星期格那份紧凑文案，之后换成摘要卡那份完整文案。
///
/// 与课程卡「只有起点才有的行」的淡出起点一致，整条转场只有一个节奏。
const double kSummaryTextSwitchAt = 0.45;

/// 按进度插值出一帧。
SummaryFlightFrame lerpSummaryFlight({
  required SummaryFlightSpec spec,
  required double t,
}) {
  final k = t.clamp(0.0, 1.0);
  final useEndText = k >= kSummaryTextSwitchAt;

  // 起点（相对格顶，实测值）。
  const startWeekdayTop = 6.0;
  const startDateTop = 22.0;
  const startWeekdaySize = 10.0;
  const startDateSize = 8.5;
  // 终点（相对卡表面，实测值）。
  const endTitleTop = 46.0;
  const endTitleSize = 16.0;

  final width = spec.startCell.width +
      (spec.endRect.width - spec.startCell.width) * k;
  final left = spec.startCell.left + (spec.endRect.left - spec.startCell.left) * k;
  final top = spec.startCell.top + (spec.endRect.top - spec.startCell.top) * k;
  final height =
      spec.startCell.height + (spec.endRect.height - spec.startCell.height) * k;

  // 起点两行是**居中**的，终点标题是**左对齐**的。
  //
  // 用「左偏移随进度平移」而不是切换 `textAlign`：切换会让文字在中途横向跳一格
  // （0.45 处字号已到 11.9sp，跳半张卡宽，读作抽了一下）。改成左偏移连续插值，
  // 文字是「一边长大一边挪到左边」。（文字自身 shrink-wrap，所以终点那一侧不
  // 依赖任何宽度估算；起点居中才用得上估算值，误差 1~2dp 在 50dp 格里看不见。）
  return SummaryFlightFrame(
    rect: Rect.fromLTWH(left, top, width, height),
    radius: _lerp(spec.startRadius, spec.endRadius, k),
    shadowOpacity: 0.08 * k,
    fill: spec.fill,
    ink: spec.ink,
    mutedInk: spec.mutedInk,
    weekdayText: spec.weekdayLabel,
    // 起点居中（对齐因子 1）→ 终点靠左（0）。前 40% 就挪到位，与字号长大同步。
    weekdayCenterFactor: 1 - (k / 0.4).clamp(0.0, 1.0),
    weekdayTop: startWeekdayTop,
    weekdayFontSize: startWeekdaySize,
    weekdayWeight: FontWeight.w800,
    // 终点的完整日期里已经含「周五」，所以星期名后段淡出。
    weekdayOpacity: (1 - (k - 0.25) / 0.3).clamp(0.0, 1.0),
    dateText: useEndText ? spec.titleLabel : spec.cellDateLabel,
    dateCenterFactor: 1 - (k / 0.4).clamp(0.0, 1.0),
    dateTop: _lerp(startDateTop, endTitleTop, k),
    dateFontSize: _lerp(startDateSize, endTitleSize, k),
    dateWeight: FontWeight.w400,
    metaText: spec.metaLabel,
    countText: spec.countLabel,
    // 卡面前 30% 淡入：起点那颗字先自己长，长大一点卡面才包上来。
    surfaceOpacity: (k / 0.30).clamp(0.0, 1.0),
    metaOpacity: ((k - 0.55) / 0.35).clamp(0.0, 1.0),
    countOpacity: ((k - 0.65) / 0.3).clamp(0.0, 1.0),
    closeOpacity: ((k - 0.6) / 0.4).clamp(0.0, 1.0),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

// 这里曾经有一个 `_estimateTextWidth`（按「CJK 1em、其余 0.55em」粗估宽度），
// 用来把起点那两行字在格子里居中。**已删除**（2026-10-23 审核发现）。
//
// 实测误差：`周五`（10sp）真实宽 20.5、估算 20.0 → 偏 0.25px（可接受）；
// 但 `03/20`（8.5sp）真实宽 **43.75**、估算 23.375 → 居中偏 **10.19px**。
// 原因是数字与斜杠在多数无衬线字体里的实际 advance 远大于 0.55em。
//
// 10px 在 50dp 的格子里是明显偏移 —— 起飞那一帧文字不在星期格的字上。
// 换字体/换语言/两位数日期还会更糟，靠调系数永远治不好。
//
// 现在起点那一侧直接用 `Align(alignment: center)` 让 Flutter 自己居中
// （它用的是真实排版宽度），终点那一侧保持左对齐，中间用**对齐因子**插值。
// 见 `SummaryFlightFrame.weekdayCenterFactor` / `dateCenterFactor`。

/// 飞行中的摘要卡。
///
/// ## 为什么自己画，而不是塞一张缩小的真卡
///
/// 真摘要卡的文字宽度依赖卡宽（胶囊会换行、标题会省略）。塞进 50dp 宽的格子会
/// 立刻触发溢出与截断，读起来是一团乱码。所以这里只画两端都有的那几样，位置与
/// 字号逐项插值 —— 与课程卡的做法一致。
///
/// ## 材质必须与真摘要卡**同一档**（2026-10-23 修）
///
/// 第一版这里自己画了个 `DecoratedBox(color: 白)`：玻璃档下真卡是磨砂玻璃，
/// 飞行卡是实心白卡 —— 起飞那一瞬间材质就换了，落定又换回来。用户口径：
/// 「这个新卡的是实体卡材质不一样」。
///
/// 现在走 [DayViewAgendaSurface]（= 真摘要卡用的同一个 [CourseSurface] 出口），
/// 再给同一套描边与投影。于是「档位 / 磨砂 / 染色 / 描边 / 投影」全部同源，
/// 中间不会换任何一种。
///
/// ## 玻璃铁律
///
/// `Opacity` 只包**文字与图标**；卡面本身是 `CourseSurface`，全程不进半透明层。
class SummaryFlightCard extends StatelessWidget {
  const SummaryFlightCard({
    super.key,
    required this.frame,
    required this.settings,
  });

  final SummaryFlightFrame frame;

  /// 真摘要卡用的那套设置（材质档位由它 + 模糊管线共同决定）。
  final TimetableSettings settings;

  @override
  Widget build(BuildContext context) {
    final ink = frame.ink;
    final muted = frame.mutedInk;

    // 文字层：**始终画**（起点那两行字必须看得见）。
    final content = Stack(
      children: [
        if (frame.weekdayOpacity > 0.001)
          Positioned(
            left: 0,
            right: 0,
            top: frame.weekdayTop,
            child: _FlightAlignedText(
              centerFactor: frame.weekdayCenterFactor,
              child: Opacity(
              opacity: frame.weekdayOpacity,
              child: Text(
                frame.weekdayText,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: ink,
                  fontSize: frame.weekdayFontSize,
                  fontWeight: frame.weekdayWeight,
                  height: 1.4,
                ),
              ),
            )),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: frame.dateTop,
          child: _FlightAlignedText(
            centerFactor: frame.dateCenterFactor,
            child: Text(
              frame.dateText,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: ink,
                fontSize: frame.dateFontSize,
                fontWeight: frame.dateWeight,
                height: 1.15,
              ),
            ),
          ),
        ),
        if (frame.metaOpacity > 0.001)
          Positioned(
            left: 14,
            top: 14.5,
            child: Opacity(
              opacity: frame.metaOpacity,
              child: Text(
                frame.metaText,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ),
        if (frame.countOpacity > 0.001)
          Positioned(
            left: 14,
            top: 72,
            child: Opacity(
              opacity: frame.countOpacity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ink.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  child: Text(
                    frame.countText,
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (frame.closeOpacity > 0.001)
          Positioned(
            right: 14,
            top: 12,
            child: Opacity(
              opacity: frame.closeOpacity,
              child: Icon(Icons.close_rounded, size: 18, color: muted),
            ),
          ),
      ],
    );

    // 卡面：起点可见度为 0（星期栏那一格根本没有卡面，只有一行字）。
    //
    // 起点就画不透明卡面，会在星期栏上凭空冒出一块白卡 —— 它明明只是几行字。
    // 所以卡面按 `surfaceOpacity` 淡入（前 30%），文字从头到尾都在。
    final surfaceAlpha = frame.surfaceOpacity.clamp(0.0, 1.0);
    // ⚠️ **不要**在这里按可见度分叉返回两种 widget。
    //
    // 分叉会让 30% 处外层从 `ClipRect` 变成 `DayViewAgendaSurface`：widget 类型
    // 一变，`Element` 就重建整棵子树，卡里那几行字会闪一下（转场里最刺眼的那类）。
    // 所以外层恒定，可见度只作为**参数**进去 —— 0 时那些参数正好让它什么都不画。
    return DayViewAgendaSurface(
      settings: settings,
      color: frame.fill,
      radius: frame.radius,
      // 与真摘要卡同一条渐变（同色两段：摘要卡没有课程色可依托）。实体档读的
      // 就是这里的 alpha —— 所以卡面可见度对实体档也是真的渐变。
      gradient: LinearGradient(
        colors: [
          frame.fill.withValues(alpha: surfaceAlpha),
          frame.fill.withValues(alpha: surfaceAlpha),
        ],
      ),
      // 玻璃档的染色强度由 opacityScale 缩放（`CourseSurface` 内部按它算 tint
      // 的 alpha），所以同一份「可见度」在两种档位下都成立。
      opacityScale: surfaceAlpha,
      // 与真摘要卡同一套中性细描边，可见度同步。
      border: Border.all(color: ink.withValues(alpha: 0.12 * surfaceAlpha)),
      // 真摘要卡是黑色 0.08 / 16px / (0,4)。这里只让 alpha 随进度长到 0.08 ——
      // 几何同源，落定同值，不会「忽然变形状」。
      shadow: frame.shadowOpacity <= 0.001
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: frame.shadowOpacity * surfaceAlpha,
                ),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frame.radius),
        child: content,
      ),
    );
  }
}

/// 在「水平居中」与「靠左 14dp」之间连续移动的文字容器。
///
/// ## 为什么不用算好的 left
///
/// 文字宽度只有真实排版知道。曾经用「CJK 1em / 其余 0.55em」粗估，实测 `03/20`
/// 在 8.5sp 下真实宽 **43.75**、估算 23.375 —— 居中偏 **10.19px**，在 50dp 的
/// 星期格里一眼能看出文字不在格子的字上。
///
/// 这里改成：左内边距随 [centerFactor] 从 14（终点）变到 0（起点），
/// 内层用 `Align` 在**剩下的宽度**里居中/靠左，让 Flutter 用真实排版宽度摆。
/// 两端都精确，中间连续。
class _FlightAlignedText extends StatelessWidget {
  const _FlightAlignedText({
    required this.centerFactor,
    required this.child,
  });

  /// 1 = 在整张卡里居中；0 = 距左边 14dp（摘要卡的内边距）。
  final double centerFactor;

  final Widget child;

  /// 摘要卡的内边距（`Padding(fromLTRB(14,12,14,14))` 的左右值）。
  static const double _endInset = 14;

  @override
  Widget build(BuildContext context) {
    final f = centerFactor.clamp(0.0, 1.0);
    return Padding(
      // 两端都留出终点内边距，只在中间连续收回：这样「居中」时左右对称，
      // 「靠左」时正好落在 14dp 上，中途不会出现文字突然贴边。
      padding: EdgeInsets.symmetric(horizontal: _endInset * f),
      child: Align(
        alignment: Alignment(f * 2 - 1, 0),
        child: child,
      ),
    );
  }
}
