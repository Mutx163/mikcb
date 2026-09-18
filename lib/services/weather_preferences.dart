import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_forecast.dart';

/// 天气功能的设备本地配置（开关 / 所选城市 / 预报缓存）。
///
/// 刻意**不放进 `TimetableSettings`**：那份设置会随课表 profile 进备份与云同步
/// payload，而「所在城市」是设备属性——两台设备一台在杭州一台在成都，同步一个
/// 城市必然有一台是错的。放在这里与 [WallpaperHistoryService] 等设备级配置同档。
/// 代价：换机恢复备份后需要重选城市。
///
/// 路径与结论见 .agents/notes/implemented/feature/2026-09-18-day-view-course-weather.md。
class WeatherPreferences {
  WeatherPreferences._();

  /// 是否在日视图课卡上显示天气。
  static const String enabledKey = 'weather_enabled_v1';

  /// 默认关闭：未选城市前打开开关只会得到一排空白，不如让用户先选城市。
  static const bool defaultEnabled = false;

  /// 所选城市（[WeatherLocation] 的 JSON 串）。
  static const String locationKey = 'weather_city_v1';

  /// 预报缓存（[WeatherForecast] 的列式 JSON 串）。
  static const String forecastKey = 'weather_forecast_v1';

  static Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(enabledKey) ?? defaultEnabled;
  }

  static Future<void> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(enabledKey, enabled);
  }

  static Future<WeatherLocation?> loadLocation() async {
    final preferences = await SharedPreferences.getInstance();
    return WeatherLocation.tryDecode(preferences.getString(locationKey));
  }

  static Future<void> saveLocation(WeatherLocation location) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(locationKey, location.toJsonString());
  }

  static Future<WeatherForecast?> loadForecast() async {
    final preferences = await SharedPreferences.getInstance();
    return WeatherForecast.tryDecode(preferences.getString(forecastKey));
  }

  static Future<void> saveForecast(WeatherForecast forecast) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(forecastKey, forecast.toJsonString());
  }

  static Future<void> clearForecast() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(forecastKey);
  }
}
