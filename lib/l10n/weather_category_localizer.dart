import '../domain/weather_logic.dart';
import 'app_localizations.dart';

/// 把天气分类与摘要翻成用户可见文案。
///
/// 单独放在 l10n 层而不是塞进 domain：分类与聚合是纯逻辑（可无 UI 单测），
/// 文案要跟着语言走，两者混在一起会让 domain 依赖 AppLocalizations。
abstract final class WeatherCategoryLocalizer {
  /// 天气现象的中文/本地化名称。
  static String label(AppLocalizations l10n, WeatherCategory category) {
    return switch (category) {
      WeatherCategory.clear => l10n.weatherClear,
      WeatherCategory.mainlyClear => l10n.weatherMainlyClear,
      WeatherCategory.partlyCloudy => l10n.weatherPartlyCloudy,
      WeatherCategory.overcast => l10n.weatherOvercast,
      WeatherCategory.fog => l10n.weatherFog,
      WeatherCategory.drizzle => l10n.weatherDrizzle,
      WeatherCategory.freezingDrizzle => l10n.weatherFreezingDrizzle,
      WeatherCategory.lightRain => l10n.weatherLightRain,
      WeatherCategory.rain => l10n.weatherRain,
      WeatherCategory.heavyRain => l10n.weatherHeavyRain,
      WeatherCategory.freezingRain => l10n.weatherFreezingRain,
      WeatherCategory.rainShowers => l10n.weatherRainShowers,
      WeatherCategory.heavyRainShowers => l10n.weatherHeavyRainShowers,
      WeatherCategory.lightSnow => l10n.weatherLightSnow,
      WeatherCategory.snow => l10n.weatherSnow,
      WeatherCategory.heavySnow => l10n.weatherHeavySnow,
      WeatherCategory.snowGrains => l10n.weatherSnowGrains,
      WeatherCategory.snowShowers => l10n.weatherSnowShowers,
      WeatherCategory.thunderstorm => l10n.weatherThunderstorm,
      WeatherCategory.thunderstormHail => l10n.weatherThunderstormHail,
    };
  }

  /// 课卡上的那一行，例如 `小雨 · 23° · 60%`。
  ///
  /// 降水概率偏低时用不带百分比的短句——`showPrecipitationProbability`
  /// 由聚合算法按阈值判定，这里只负责选模板。
  static String summary(AppLocalizations l10n, CourseWeatherSummary summary) {
    final phenomenon = label(l10n, summary.category);
    final probability = summary.precipitationProbability;
    if (!summary.showPrecipitationProbability || probability == null) {
      return l10n.courseWeatherSummaryNoProbability(
        phenomenon,
        summary.temperatureC,
      );
    }
    return l10n.courseWeatherSummary(
      phenomenon,
      summary.temperatureC,
      probability,
    );
  }
}
