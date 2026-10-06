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
/// 天气码固定 61（小雨）、概率固定 60、温度固定 23，所以断言可以写死文案：
/// 日视图与课程详情弹层是 `小雨 · 23°`（默认内容组合 = 现象 + 温度），
/// 周视图课卡与设置页预览是紧凑版 `23°`（见 `WeatherTextDensity.compact`）。
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

/// 一个**还停在加载中**的 [WeatherProvider]：开关与城市都就绪，数据请求还在路上。
///
/// 这正是用户看见的那段窗口（刚进 App、刚打开天气开关，预报还没到）：
/// `WeatherProvider.isAwaitingData` 为 true，三个显示面于是只画「预留的空位」。
/// 用它是为了把「位置留住了、数据到了不顶动」这条断言钉住，而不是只断言文案。
///
/// **为什么用「真定时器延迟」而不是「挂起请求 + 手动放行」**：请求是在
/// `runAsync` 的真实区里发出的，它的 continuation 也绑在那个区上；等测试体
/// （假时钟区）去 `Completer.complete` 是唤不醒它的，实测会一路卡到
/// `WeatherService` 的 10 秒超时。延迟是**同一个真实区里排的**，所以只要给
/// 真实时间过掉（见 [PendingWeather.awaitArrival]）它就会自己回来。
class PendingWeather {
  PendingWeather(this.provider);

  final WeatherProvider provider;

  /// 等这次请求真的回来（状态转 ready、预报落盘），然后重建一帧。
  ///
  /// 轮询而不是死等一个固定时长：机器忙的时候那 200ms 可能不够，用例会假红。
  /// 判据是「内存里已经有预报」——那正是界面开始画这一行的条件。
  Future<void> awaitArrival(WidgetTester tester) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (provider.forecast == null && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
    }
    await tester.pump();
  }
}

/// 「数据还在路上」这个假服务端要慢多久。测试体走的是假时钟，这段真实时间不会被
/// 推进，所以断言完之前它一定还没回来。
const Duration pendingWeatherDelay = Duration(milliseconds: 200);

/// 拉起一个 [PendingWeather]（已选城市、数据请求还在路上）。
Future<PendingWeather> pendingWeatherProvider(
  WidgetTester tester, {
  bool enabled = true,
}) async {
  late WeatherProvider provider;
  await tester.runAsync(() async {
    await WeatherPreferences.setEnabled(enabled);
    await WeatherPreferences.saveLocation(weatherTestCity);
    provider = WeatherProvider(
      service: WeatherService(
        client: MockClient((_) async {
          await Future<void>.delayed(pendingWeatherDelay);
          return http.Response(
            jsonEncode(weatherPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      ),
    );
    await provider.initialize();
  });
  return PendingWeather(provider);
}
