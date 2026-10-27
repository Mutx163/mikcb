import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/day_course_display_logic.dart';
import '../domain/week_calculator.dart';
import '../l10n/app_localizations.dart';
import '../models/timetable_settings.dart';
import '../providers/weather_provider.dart';
import '../widgets/course_weather_display.dart';

/// 飞行卡（转场中那一张）在**议程侧**（终点）要多画的两行：天气与本节备注。
///
/// ## 为什么单独一个文件
///
/// 这两行的判据必须与真实议程卡**逐条同源**，否则飞行卡会比真卡少一行 ——
/// 卡片落地那一帧底部凭空多出内容（2026-10-27 修）。判据本身是纯逻辑：
/// 开关、是否对方课程、这一周是否上课、有没有备注。把它们从
/// `timetable_day_view_part.dart` 抽出来有三个好处：
///
/// 1. `timetable_screen` 的行数棘轮是**只降不升**的，往 part 里摊会在 pre-commit
///    被架构守卫拦下（这次实测：主文件 +6 行、逻辑单元 +51 行，两条都红）；
/// 2. 纯函数可直接单测，不必泵起整个日视图；
/// 3. 真卡将来若改判据，这一处跟着改就行，不用在 State 里翻。
///
/// 真卡对照（只读参照物）：
/// `widgets/timetable/day_view/day_view_course_agenda_card_variants.dart` 里
/// `DayCourseWeatherRow.visible` 与 `sessionPreview` 那两处。
class FlightAgendaExtraLines {
  const FlightAgendaExtraLines._({
    required this.weatherText,
    required this.weatherIcon,
    required this.noteText,
  });

  /// 天气行文案（完整口径：现象 · 温度 · 概率）。null = 这一周不该有这一行。
  final String? weatherText;

  /// 天气行图标（随天气现象变，不是写死太阳）。
  final IconData? weatherIcon;

  /// 本节备注；null 或纯空白 = 不该有这一行。
  final String? noteText;

  static const FlightAgendaExtraLines empty = FlightAgendaExtraLines._(
    weatherText: null,
    weatherIcon: null,
    noteText: null,
  );

  /// 算这两行该不该有、写什么。
  ///
  /// [weatherProvider] 传 null 表示「没挂天气 provider」（组件级测试、天气未启用）
  /// —— 此时不画天气行，但**备注行照常**，因为备注不依赖天气。
  static FlightAgendaExtraLines resolve({
    required DayCourseDisplayItem item,
    required TimetableSettings settings,
    required int week,
    required DateTime? date,
    required AppLocalizations? l10n,
    required WeatherProvider? weatherProvider,
  }) {
    return FlightAgendaExtraLines._(
      weatherText: _weatherText(
        item: item,
        settings: settings,
        week: week,
        date: date,
        l10n: l10n,
        weatherProvider: weatherProvider,
      ),
      weatherIcon: _weatherIcon(
        item: item,
        settings: settings,
        week: week,
        date: date,
        l10n: l10n,
        weatherProvider: weatherProvider,
      ),
      noteText: _note(item: item, week: week),
    );
  }

  /// 从 `BuildContext` 直接算：日期、l10n、天气 provider 都在这里取齐。
  ///
  /// 给调用点留一个**一行调用**的口子 —— 判据全在本文件，part 里不再摊行数
  /// （见类注释第 1 点）。
  static FlightAgendaExtraLines fromContext({
    required BuildContext context,
    required DayCourseDisplayItem item,
    required TimetableSettings settings,
    required int week,
  }) {
    return resolve(
      item: item,
      settings: settings,
      week: week,
      date: dateForWeekDay(settings, week, item.course.dayOfWeek),
      l10n: AppLocalizations.of(context),
      weatherProvider: context.watch<WeatherProvider?>(),
    );
  }

  /// 这一周的某一天是哪一天；学期开始日未设置时返回 null。
  ///
  /// 原在 `timetable_screen.dart` 的 `_dateForWeekDay`，2026-10-27 搬到这里：
  /// 它只依赖 [settings] 与 [WeekCalculator]，是纯函数，而主文件的行数棘轮
  /// 只降不升 —— 搬出来让那边净减 19 行，正好抵消本次新增的 import。
  static DateTime? dateForWeekDay(
    TimetableSettings settings,
    int week,
    int dayOfWeek,
  ) {
    final semesterStart = settings.semesterStartDate;
    if (semesterStart == null) {
      return null;
    }

    final normalizedStart = DateTime(
      semesterStart.year,
      semesterStart.month,
      semesterStart.day,
    ).subtract(Duration(days: semesterStart.weekday - 1));

    return WeekCalculator.addDays(
      normalizedStart,
      (week - 1) * 7 + dayOfWeek - 1,
    );
  }

  /// 天气显示对象；null = 这一周这张卡不该有天气行。
  ///
  /// 条件与真卡逐条对齐：
  /// - `settings.weatherShowOnDayCard` 开着（不是 `weatherShowOnWeekCard`，
  ///   那是周网格卡的开关，两者可以各自独立）；
  /// - 不是情侣对方的课程（对方在别的城市，拿本地天气是错的）；
  /// - 这一周真的上课（非本周的灰卡代表的那一天并不上课，挂那天的天气会
  ///   让人以为当天要带伞）。
  static CourseWeatherDisplay? weatherDisplay({
    required DayCourseDisplayItem item,
    required TimetableSettings settings,
    required int week,
    required DateTime? date,
    required AppLocalizations? l10n,
    required WeatherProvider? weatherProvider,
  }) {
    if (!settings.weatherShowOnDayCard ||
        item.isPartnerCourse ||
        !item.course.isActiveInWeek(week)) {
      return null;
    }
    if (date == null || l10n == null || weatherProvider == null) {
      return null;
    }
    return courseWeatherDisplayFor(
      l10n: l10n,
      summary: weatherProvider.summaryForCourse(
        date: date,
        startTime: item.course.startTime,
        endTime: item.course.endTime,
      ),
      showPhenomenon: settings.weatherShowPhenomenon,
      showTemperature: settings.weatherShowTemperature,
      showProbability: settings.weatherShowProbability,
    );
  }

  static String? _weatherText({
    required DayCourseDisplayItem item,
    required TimetableSettings settings,
    required int week,
    required DateTime? date,
    required AppLocalizations? l10n,
    required WeatherProvider? weatherProvider,
  }) =>
      weatherDisplay(
        item: item,
        settings: settings,
        week: week,
        date: date,
        l10n: l10n,
        weatherProvider: weatherProvider,
      )?.text;

  static IconData? _weatherIcon({
    required DayCourseDisplayItem item,
    required TimetableSettings settings,
    required int week,
    required DateTime? date,
    required AppLocalizations? l10n,
    required WeatherProvider? weatherProvider,
  }) =>
      weatherDisplay(
        item: item,
        settings: settings,
        week: week,
        date: date,
        l10n: l10n,
        weatherProvider: weatherProvider,
      )?.icon;

  /// 本节备注那一行；条件与真卡 `sessionPreview` 同源（已取 `trimmedText`）。
  ///
  /// 单独暴露：备注不依赖天气 / 日期 / l10n，调用方拿它时不必凑齐那些输入。
  static String? noteTextFor({
    required DayCourseDisplayItem item,
    required int week,
  }) =>
      _note(item: item, week: week);

  static String? _note({required DayCourseDisplayItem item, required int week}) {
    final note = item.course.sessionNoteForWeek(week)?.trimmedText;
    if (note == null || note.isEmpty) {
      return null;
    }
    return note;
  }
}
