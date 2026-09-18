import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/weather_forecast.dart';

WeatherForecast _buildForecast({
  List<HourlyWeatherPoint>? hourly,
  double latitude = 30.29365,
  double longitude = 120.16142,
  DateTime? fetchedAt,
}) {
  return WeatherForecast(
    latitude: latitude,
    longitude: longitude,
    fetchedAt: fetchedAt ?? DateTime(2026, 9, 18, 6, 30),
    hourly:
        hourly ??
        [
          HourlyWeatherPoint(
            time: DateTime(2026, 9, 18, 8),
            temperatureC: 23.4,
            precipitationProbability: 60,
            precipitationMm: 0.4,
            snowfallCm: 0,
            weatherCode: 61,
          ),
          // 全字段缺报的一行：序列化往返必须保住这些 null。
          HourlyWeatherPoint(time: DateTime(2026, 9, 18, 9)),
        ],
  );
}

void main() {
  group('WeatherLocation', () {
    test('副标题拼接行政区与国家', () {
      const location = WeatherLocation(
        name: '杭州',
        admin1: '浙江',
        country: '中国',
        latitude: 30.29,
        longitude: 120.16,
      );
      expect(location.regionLabel, '浙江 · 中国');
    });

    test('副标题跳过空值、与主标题重复的值和重复项', () {
      const noAdmin = WeatherLocation(
        name: '杭州',
        country: '中国',
        latitude: 30.29,
        longitude: 120.16,
      );
      expect(noAdmin.regionLabel, '中国');

      // 行政区与国家都与主标题同名，副标题应彻底留空而不是复读一遍。
      const cityState = WeatherLocation(
        name: 'Singapore',
        admin1: 'Singapore',
        country: 'Singapore',
        latitude: 1.29,
        longitude: 103.85,
      );
      expect(cityState.regionLabel, '');

      // 行政区与主标题同名时只跳过它，国家照常显示。
      const sameAsName = WeatherLocation(
        name: '香港',
        admin1: '香港',
        country: '中国',
        latitude: 22.32,
        longitude: 114.17,
      );
      expect(sameAsName.regionLabel, '中国');

      const blank = WeatherLocation(
        name: '杭州',
        admin1: '   ',
        latitude: 30.29,
        longitude: 120.16,
      );
      expect(blank.regionLabel, '');
    });

    test('同名不同地靠经纬度区分', () {
      const hangzhouZhejiang = WeatherLocation(
        name: '杭州',
        admin1: '浙江',
        latitude: 30.29365,
        longitude: 120.16142,
      );
      const hangzhouSichuan = WeatherLocation(
        name: '杭州',
        admin1: '四川',
        latitude: 30.06517,
        longitude: 102.19527,
      );
      expect(hangzhouZhejiang.isSamePlaceAs(hangzhouZhejiang), isTrue);
      expect(hangzhouZhejiang.isSamePlaceAs(hangzhouSichuan), isFalse);
    });

    test('经纬度微小抖动仍视为同一地点', () {
      const location = WeatherLocation(
        name: '杭州',
        latitude: 30.29365,
        longitude: 120.16142,
      );
      const nudged = WeatherLocation(
        name: '杭州',
        latitude: 30.2936500001,
        longitude: 120.1614200001,
      );
      expect(location.isSamePlaceAs(nudged), isTrue);
    });

    test('序列化往返一致', () {
      const location = WeatherLocation(
        name: '杭州',
        admin1: '浙江',
        country: '中国',
        latitude: 30.29365,
        longitude: 120.16142,
        timezone: 'Asia/Shanghai',
      );
      final restored = WeatherLocation.tryDecode(location.toJsonString());
      expect(restored, isNotNull);
      expect(restored!.name, '杭州');
      expect(restored.admin1, '浙江');
      expect(restored.country, '中国');
      expect(restored.timezone, 'Asia/Shanghai');
      expect(restored.latitude, closeTo(30.29365, 1e-9));
      expect(restored.longitude, closeTo(120.16142, 1e-9));
    });

    test('缺名称或经纬度时抛 FormatException', () {
      expect(
        () => WeatherLocation.fromJson(const {'latitude': 1.0, 'longitude': 2.0}),
        throwsFormatException,
      );
      expect(
        () => WeatherLocation.fromJson(const {'name': '杭州'}),
        throwsFormatException,
      );
    });

    test('损坏的持久化数据返回 null 而不抛', () {
      expect(WeatherLocation.tryDecode(null), isNull);
      expect(WeatherLocation.tryDecode(''), isNull);
      expect(WeatherLocation.tryDecode('not json'), isNull);
      expect(WeatherLocation.tryDecode('[1,2,3]'), isNull);
      expect(WeatherLocation.tryDecode('{"name":"杭州"}'), isNull);
    });
  });

  group('WeatherForecast', () {
    test('构造时按时间升序重排', () {
      final forecast = _buildForecast(
        hourly: [
          HourlyWeatherPoint(time: DateTime(2026, 9, 18, 10), temperatureC: 1),
          HourlyWeatherPoint(time: DateTime(2026, 9, 18, 8), temperatureC: 2),
          HourlyWeatherPoint(time: DateTime(2026, 9, 18, 9), temperatureC: 3),
        ],
      );
      expect(
        forecast.hourly.map((point) => point.time.hour).toList(),
        [8, 9, 10],
      );
    });

    test('covers 含端点', () {
      final forecast = _buildForecast();
      expect(forecast.covers(DateTime(2026, 9, 18, 8)), isTrue);
      expect(forecast.covers(DateTime(2026, 9, 18, 9)), isTrue);
      expect(forecast.covers(DateTime(2026, 9, 18, 8, 30)), isTrue);
      expect(forecast.covers(DateTime(2026, 9, 18, 7, 59)), isFalse);
      expect(forecast.covers(DateTime(2026, 9, 18, 9, 1)), isFalse);
    });

    test('空序列时 covers 为 false、窗口端点为空', () {
      final forecast = _buildForecast(hourly: const []);
      expect(forecast.covers(DateTime(2026, 9, 18, 8)), isFalse);
      expect(forecast.windowStart, isNull);
      expect(forecast.windowEnd, isNull);
      expect(forecast.hasLapsedAt(DateTime(2026, 9, 18, 8)), isTrue);
    });

    test('窗口走完后 hasLapsedAt 为 true', () {
      final forecast = _buildForecast();
      expect(forecast.hasLapsedAt(DateTime(2026, 9, 18, 8, 30)), isFalse);
      expect(forecast.hasLapsedAt(DateTime(2026, 9, 18, 9)), isFalse);
      expect(forecast.hasLapsedAt(DateTime(2026, 9, 18, 9, 1)), isTrue);
    });

    test('matchesLocation 靠经纬度判定', () {
      final forecast = _buildForecast();
      const nearby = WeatherLocation(
        name: '杭州',
        latitude: 30.29365,
        longitude: 120.16142,
      );
      const elsewhere = WeatherLocation(
        name: '成都',
        latitude: 30.5728,
        longitude: 104.0668,
      );
      expect(forecast.matchesLocation(nearby), isTrue);
      expect(forecast.matchesLocation(elsewhere), isFalse);
    });

    test('列式序列化往返一致，且保留墙钟与缺报的 null', () {
      final forecast = _buildForecast();
      final restored = WeatherForecast.tryDecode(forecast.toJsonString());
      expect(restored, isNotNull);
      expect(restored!.hourly.length, 2);
      expect(restored.fetchedAt, forecast.fetchedAt);
      expect(restored.latitude, closeTo(forecast.latitude, 1e-9));

      final first = restored.hourly.first;
      expect(first.time, DateTime(2026, 9, 18, 8));
      expect(first.temperatureC, closeTo(23.4, 1e-9));
      expect(first.precipitationProbability, 60);
      expect(first.precipitationMm, closeTo(0.4, 1e-9));
      expect(first.snowfallCm, 0);
      expect(first.weatherCode, 61);

      final second = restored.hourly.last;
      expect(second.time, DateTime(2026, 9, 18, 9));
      expect(second.temperatureC, isNull);
      expect(second.precipitationProbability, isNull);
      expect(second.precipitationMm, isNull);
      expect(second.snowfallCm, isNull);
      expect(second.weatherCode, isNull);
    });

    test('序列化用不带 Z 的墙钟串，避免时区漂移', () {
      final forecast = _buildForecast();
      final json =
          jsonDecode(forecast.toJsonString()) as Map<String, dynamic>;
      expect(json['time'], ['2026-09-18T08:00', '2026-09-18T09:00']);
      expect((json['time'] as List).first, isNot(contains('Z')));
    });

    test('列长度不一致时按最短可用值逐条降级', () {
      final decoded = WeatherForecast.fromJson({
        'latitude': 30.29,
        'longitude': 120.16,
        'fetchedAt': DateTime(2026, 9, 18, 6).millisecondsSinceEpoch,
        'time': ['2026-09-18T08:00', '2026-09-18T09:00'],
        'temperature_2m': [23.0],
        'weather_code': [61, 63],
      });
      expect(decoded.hourly.length, 2);
      expect(decoded.hourly.first.temperatureC, 23.0);
      expect(decoded.hourly.last.temperatureC, isNull);
      expect(decoded.hourly.first.weatherCode, 61);
      expect(decoded.hourly.last.weatherCode, 63);
    });

    test('畸形时间行被跳过', () {
      final decoded = WeatherForecast.fromJson({
        'latitude': 30.29,
        'longitude': 120.16,
        'fetchedAt': 0,
        'time': ['nonsense', '2026-09-18T09:00', 42],
        'temperature_2m': [1.0, 2.0, 3.0],
      });
      expect(decoded.hourly.length, 1);
      expect(decoded.hourly.single.time, DateTime(2026, 9, 18, 9));
      expect(decoded.hourly.single.temperatureC, 2.0);
    });

    test('缺头部字段时抛 FormatException', () {
      expect(
        () => WeatherForecast.fromJson(const {'latitude': 1.0}),
        throwsFormatException,
      );
    });

    test('损坏或无小时点的缓存返回 null 而不抛', () {
      expect(WeatherForecast.tryDecode(null), isNull);
      expect(WeatherForecast.tryDecode('not json'), isNull);
      expect(WeatherForecast.tryDecode('{"latitude":1}'), isNull);
      expect(
        WeatherForecast.tryDecode(
          jsonEncode({
            'latitude': 30.29,
            'longitude': 120.16,
            'fetchedAt': 0,
            'time': <String>[],
          }),
        ),
        isNull,
      );
    });
  });
}
