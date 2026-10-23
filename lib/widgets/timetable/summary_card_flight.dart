library;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/timetable_settings.dart';
import '../../ui/hyperos/hyperos.dart';
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
  final ink = resolveSummaryCardInk(
    context: context,
    settings: settings,
    inkEnvironment: inkEnvironment,
    fill: fill,
    surfaceStyle: CourseCardSurfaceStyle.solid,
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
  assert(visibleDayCount > 0, 'visibleDayCount must be positive');
  assert(
    selectedDayIndex >= 0 && selectedDayIndex < visibleDayCount,
    'selectedDayIndex out of range',
  );
  final dayWidth = (viewportWidth - timeColumnWidth) / visibleDayCount;
  // 宽度取整格：飞到的那一格就是这一个 `Expanded`（`InkWell` 铺满它），
  // `AnimatedContainer` 的 1dp 外边距只是内部留白，不是格子边界。
  return Rect.fromLTWH(
    timeColumnWidth + selectedDayIndex * dayWidth,
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
    required this.weekdayLeft,
    required this.weekdayTop,
    required this.weekdayFontSize,
    required this.weekdayWeight,
    required this.weekdayOpacity,
    required this.dateText,
    required this.dateLeft,
    required this.dateTop,
    required this.dateFontSize,
    required this.dateWeight,
    required this.metaText,
    required this.countText,
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
  final double weekdayLeft;
  final double weekdayTop;
  final double weekdayFontSize;
  final FontWeight weekdayWeight;
  final double weekdayOpacity;

  final String dateText;
  final double dateLeft;
  final double dateTop;
  final double dateFontSize;
  final FontWeight dateWeight;

  /// 终点才有的文案（「今天 · 第 3 周」/「1 门课」）。
  final String metaText;
  final String countText;

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
  const endPadLeft = 14.0;

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
  final weekdayLeft = _lerp(
    (spec.startCell.width - _estimateTextWidth(spec.weekdayLabel, startWeekdaySize)) / 2,
    endPadLeft,
    k,
  );
  final dateLeft = _lerp(
    (spec.startCell.width - _estimateTextWidth(spec.cellDateLabel, startDateSize)) / 2,
    endPadLeft,
    k,
  );

  return SummaryFlightFrame(
    rect: Rect.fromLTWH(left, top, width, height),
    radius: _lerp(spec.startRadius, spec.endRadius, k),
    shadowOpacity: 0.08 * k,
    fill: spec.fill,
    ink: spec.ink,
    mutedInk: spec.mutedInk,
    weekdayText: spec.weekdayLabel,
    weekdayLeft: weekdayLeft,
    weekdayTop: startWeekdayTop,
    weekdayFontSize: startWeekdaySize,
    weekdayWeight: FontWeight.w800,
    // 终点的完整日期里已经含「周五」，所以星期名后段淡出。
    weekdayOpacity: (1 - (k - 0.25) / 0.3).clamp(0.0, 1.0),
    dateText: useEndText ? spec.titleLabel : spec.cellDateLabel,
    dateLeft: dateLeft,
    dateTop: _lerp(startDateTop, endTitleTop, k),
    dateFontSize: _lerp(startDateSize, endTitleSize, k),
    dateWeight: FontWeight.w400,
    metaText: spec.metaLabel,
    countText: spec.countLabel,
    metaOpacity: ((k - 0.55) / 0.35).clamp(0.0, 1.0),
    countOpacity: ((k - 0.65) / 0.3).clamp(0.0, 1.0),
    closeOpacity: ((k - 0.6) / 0.4).clamp(0.0, 1.0),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// 粗估一段文字的渲染宽度（只给「起点居中」用）。
///
/// 不建 `TextPainter`：起点只有 8~10sp 的两行短文案，而这段代码转场每帧都会
/// 跑到 —— 建 painter 的代价远大于它带来的 1~2dp 精度。终点侧不依赖估算。
double _estimateTextWidth(String text, double fontSize) {
  var em = 0.0;
  for (final rune in text.runes) {
    final code = rune;
    final wide = (code >= 0x3000 && code <= 0x9FFF) ||
        (code >= 0xFF00 && code <= 0xFFEF) ||
        (code >= 0x3040 && code <= 0x30FF);
    em += wide ? 1.0 : 0.55;
  }
  return em * fontSize;
}

/// 飞行中的摘要卡。
///
/// ## 为什么自己画，而不是塞一张缩小的真卡
///
/// 真摘要卡的文字宽度依赖卡宽（胶囊会换行、标题会省略）。塞进 50dp 宽的格子会
/// 立刻触发溢出与截断，读起来是一团乱码。所以这里只画两端都有的那几样，位置与
/// 字号逐项插值 —— 与课程卡的做法一致。
///
/// ## 玻璃铁律
///
/// `Opacity` 只包**文字与图标**；卡面是**不透明**的 `DecoratedBox`。全程没有
/// 半透明卡面，所以磨砂不会塌（`CourseSurface` 铁律）。
class SummaryFlightCard extends StatelessWidget {
  const SummaryFlightCard({super.key, required this.frame});

  final SummaryFlightFrame frame;

  @override
  Widget build(BuildContext context) {
    final ink = frame.ink;
    final muted = frame.mutedInk;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: frame.fill,
        borderRadius: BorderRadius.circular(frame.radius),
        boxShadow: frame.shadowOpacity <= 0.001
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: frame.shadowOpacity),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(frame.radius),
        child: Stack(
          children: [
            if (frame.weekdayOpacity > 0.001)
              Positioned(
                left: frame.weekdayLeft,
                top: frame.weekdayTop,
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
                ),
              ),
            Positioned(
              left: frame.dateLeft,
              top: frame.dateTop,
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
        ),
      ),
    );
  }
}
