import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/weather_provider.dart';
import 'course_weather_display.dart';
import 'day_agenda_info_row.dart';

/// 日视图课卡上的天气行：那节课时段内的天气。
///
/// **不接收天气数据**，自己去 [WeatherProvider] 取——这样 `timetable_screen.dart`
/// 里只需要在地点行后面插一个无参部件，不必把天气一路透过列表、分发器、
/// 两张卡片的签名传下来。
///
/// 任何前提下拿不到数据都返回 [SizedBox.shrink]（连同自带的上间距一起消失），
/// 所以调用点不必写条件展开，失败时也不会在卡片上留下半格空隙。
///
/// 「显示哪几项」由调用方把设置里的三个开关传进来，不在内部读 `TimetableProvider`：
/// 这个部件因此可以脱离课表 provider 单独测，也不多一条隐式依赖。
class DayCourseWeatherRow extends StatefulWidget {
  const DayCourseWeatherRow({
    super.key,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.ink,
    this.visible = true,
    this.showPhenomenon = true,
    this.showTemperature = true,
    this.showProbability = false,
  });

  /// 这节课所在的具体日期；为 null（学期开始日未设置）时不显示。
  final DateTime? date;

  /// `HH:mm` 格式的上课时间。
  final String startTime;

  /// `HH:mm` 格式的下课时间。
  final String endTime;

  /// 卡片调色板算好的前景色。
  final Color ink;

  /// 是否允许显示（停课、情侣对方课程、非本周等场景传 false）。
  final bool visible;

  /// 显示内容（天气现象 / 温度 / 降水概率），与设置页同名的三个开关一一对应。
  final bool showPhenomenon;
  final bool showTemperature;
  final bool showProbability;

  /// 与课卡里其他信息行一致的上间距。
  static const double topGap = 5.5;

  @override
  State<DayCourseWeatherRow> createState() => _DayCourseWeatherRowState();
}

class _DayCourseWeatherRowState extends State<DayCourseWeatherRow> {
  @override
  void initState() {
    super.initState();
    // 挂载时补一次「过期就刷」：App 在后台挂了一夜再切回日视图时，内存里的
    // 预报可能已经跨天。provider 内部有单飞 + TTL + 失败退避三重守卫，一屏
    // N 张卡各调一次也只有第 1 次真的可能发请求。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final provider = context.read<WeatherProvider?>();
      if (provider != null) {
        unawaited(provider.ensureFresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }
    final date = widget.date;
    if (date == null) {
      return const SizedBox.shrink();
    }

    // 可空类型查 provider：没挂载时返回 null 而不是抛 ProviderNotFoundException。
    // 这让所有直接 pump 日视图、没挂天气 provider 的既有测试继续可用。
    final provider = context.watch<WeatherProvider?>();
    final summary = provider?.summaryForCourse(
      date: date,
      startTime: widget.startTime,
      endTime: widget.endTime,
    );
    if (summary == null) {
      return const SizedBox.shrink();
    }

    // 只有在真的有数据时才取 l10n：上面的 null 分支已经把「没挂 provider /
    // 超出预报窗口」的情形挡掉，不会去碰可能缺失的 AppLocalizations。
    final l10n = AppLocalizations.of(context);
    if (l10n == null) {
      return const SizedBox.shrink();
    }
    final display = courseWeatherDisplayFor(
      l10n: l10n,
      summary: summary,
      showPhenomenon: widget.showPhenomenon,
      showTemperature: widget.showTemperature,
      showProbability: widget.showProbability,
    );
    if (display == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: DayCourseWeatherRow.topGap),
      child: DayAgendaInfoRow(
        icon: display.icon,
        text: display.text,
        ink: widget.ink,
      ),
    );
  }
}
