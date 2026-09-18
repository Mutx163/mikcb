import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/services/weather_preferences.dart';
import 'package:university_timetable/services/weather_service.dart';

/// 天气用例共用的城市。坐标必须与 [weatherPayload] 回填的一致，否则预报会被
/// `matchesLocation` 判为「不是这个城市」而丢弃。
const weatherTestCity = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

/// 窗口覆盖「今天 0 点起 96 小时」。
///
/// 天气码固定 61（小雨）、概率固定 60、温度固定 23，所以断言可以写死文案
/// `小雨 · 23°`（默认内容组合 = 现象 + 温度）。
Map<String, dynamic> weatherPayload({int temperature = 23, int probability = 60}) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  String two(int value) => value.toString().padLeft(2, '0');
  return {
    'latitude': weatherTestCity.latitude,
    'longitude': weatherTestCity.longitude,
    'timezone': 'Asia/Shanghai',
    'hourly': {
      'time': [
        for (var hour = 0; hour < 96; hour++)
          () {
            final time = start.add(Duration(hours: hour));
            return '${time.year}-${two(time.month)}-${two(time.day)}'
                'T${two(time.hour)}:00';
          }(),
      ],
      'temperature_2m': [for (var i = 0; i < 96; i++) temperature.toDouble()],
      'precipitation_probability': [for (var i = 0; i < 96; i++) probability],
      'precipitation': [for (var i = 0; i < 96; i++) 0.5],
      'snowfall': [for (var i = 0; i < 96; i++) 0.0],
      'weather_code': [for (var i = 0; i < 96; i++) 61],
    },
  };
}

/// 拉起一个已经拿到预报的 [WeatherProvider]（HTTP 与 prefs 都要跳出 FakeAsync）。
Future<WeatherProvider> readyWeatherProvider(
  WidgetTester tester, {
  bool enabled = true,
  Map<String, dynamic>? payload,
}) async {
  late WeatherProvider provider;
  await tester.runAsync(() async {
    await WeatherPreferences.setEnabled(enabled);
    await WeatherPreferences.saveLocation(weatherTestCity);
    provider = WeatherProvider(
      service: WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(payload ?? weatherPayload()),
            200,
            headers: _jsonHeaders,
          ),
        ),
      ),
    );
    await provider.initialize();
    await provider.ensureFresh();
  });
  return provider;
}
