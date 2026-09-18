import 'package:flutter/material.dart';

import '../domain/weather_logic.dart';
import '../l10n/app_localizations.dart';
import '../l10n/weather_category_localizer.dart';

/// 天气现象 → 图标。
///
/// 放在 widget 层而不是 domain：[IconData] 来自 material，而 `lib/domain` 被
/// `test/architecture/dependency_guards_test.dart` 禁止依赖 UI 框架。
///
/// 图标名全部对 `flutter/lib/src/material/icons.dart` 逐个核对过存在
/// （`Icons.rainy`、`Icons.partly_cloudy_day` 并不存在，勿改成它们）。
IconData weatherIconFor(WeatherCategory category) => switch (category) {
  WeatherCategory.clear || WeatherCategory.mainlyClear => Icons.wb_sunny_outlined,
  WeatherCategory.partlyCloudy => Icons.wb_cloudy_outlined,
  WeatherCategory.overcast => Icons.cloud_outlined,
  WeatherCategory.fog => Icons.foggy,
  WeatherCategory.drizzle ||
  WeatherCategory.snowGrains => Icons.grain,
  WeatherCategory.freezingDrizzle ||
  WeatherCategory.freezingRain ||
  WeatherCategory.lightSnow => Icons.ac_unit,
  WeatherCategory.lightRain ||
  WeatherCategory.rain ||
  WeatherCategory.heavyRain => Icons.water_drop_outlined,
  WeatherCategory.rainShowers ||
  WeatherCategory.heavyRainShowers => Icons.umbrella_outlined,
  WeatherCategory.snow ||
  WeatherCategory.heavySnow ||
  WeatherCategory.snowShowers => Icons.snowing,
  WeatherCategory.thunderstorm ||
  WeatherCategory.thunderstormHail => Icons.thunderstorm_outlined,
};

/// 天气行要画的东西：一个图标 + 一行已经本地化好的文字。
///
/// 做成值对象而不是两个并列参数（`weatherIcon` + `weatherText`），是因为它俩必须
/// 同进同出——三个渲染面（日视图课卡、周视图课卡、课程详情弹窗）都只判断
/// 「有没有这个对象」，不会出现「有文字没图标」的半截状态。
@immutable
class CourseWeatherDisplay {
  const CourseWeatherDisplay({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is CourseWeatherDisplay &&
      other.icon == icon &&
      other.text == text;

  @override
  int get hashCode => Object.hash(icon, text);
}

/// 摘要 + 三个内容开关 → 要画的那一行；不该画时返回 null。
///
/// 返回 null 的三种情况（调用方一律据此**整行不渲染**，不留空档）：
/// - [summary] 为 null（没开天气 / 没挂 provider / 该日超出 16 天预报窗口）；
/// - 三个开关全关（用户把天气行掏空了，只剩个图标没有信息量）；
/// - 选了降水概率但摘要里没有可用概率（全缺报，或低于显示阈值）。
///
/// [showPhenomenon] 同时管图标与现象文字：图标就是现象的可视形态，把它单独留成
/// 「永远显示」会让关掉现象后剩一个说不出所以然的图标。
CourseWeatherDisplay? courseWeatherDisplayFor({
  required AppLocalizations l10n,
  required CourseWeatherSummary? summary,
  required bool showPhenomenon,
  required bool showTemperature,
  required bool showProbability,
}) {
  if (summary == null) {
    return null;
  }
  if (!showPhenomenon && !showTemperature && !showProbability) {
    return null;
  }
  final probability = summary.precipitationProbability;
  final probabilityUsable =
      showProbability &&
      summary.showPrecipitationProbability &&
      probability != null;

  final parts = <String>[
    if (showPhenomenon) WeatherCategoryLocalizer.label(l10n, summary.category),
    if (showTemperature) l10n.weatherTemperatureValue(summary.temperatureC),
    if (probabilityUsable) l10n.weatherProbabilityValue(probability),
  ];
  if (parts.isEmpty) {
    // 只剩「勾了降水概率但这节课没有可用概率」这一种组合会走到这里。
    return null;
  }

  return CourseWeatherDisplay(
    icon: weatherIconFor(summary.category),
    text: parts.join(l10n.weatherSummarySeparator),
  );
}
