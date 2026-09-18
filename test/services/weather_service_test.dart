import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/services/weather_preferences.dart';
import 'package:university_timetable/services/weather_service.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  country: '中国',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

/// 真实结构的 Open-Meteo 预报响应（截断到 3 小时）。
Map<String, dynamic> _forecastPayload() => {
  'latitude': 30.263618,
  'longitude': 120.14051,
  'utc_offset_seconds': 28800,
  'timezone': 'Asia/Shanghai',
  'hourly_units': {
    'time': 'iso8601',
    'temperature_2m': '°C',
    'precipitation_probability': '%',
    'precipitation': 'mm',
    'snowfall': 'cm',
    'weather_code': 'wmo code',
  },
  'hourly': {
    'time': ['2026-09-18T08:00', '2026-09-18T09:00', '2026-09-18T10:00'],
    'temperature_2m': [25.1, 25.8, 27.6],
    'precipitation_probability': [8, 0, 42],
    'precipitation': [0.0, 0.0, 0.2],
    'snowfall': [0.0, 0.0, 0.0],
    'weather_code': [3, 2, 61],
  },
};

/// 真实结构的地理编码响应：搜「杭州」会同时返回浙江杭州与四川甘孜的同名村。
Map<String, dynamic> _geocodingPayload() => {
  'results': [
    {
      'id': 1808926,
      'name': '杭州',
      'latitude': 30.29365,
      'longitude': 120.16142,
      'elevation': 12.0,
      'feature_code': 'PPLA',
      'country_code': 'CN',
      'timezone': 'Asia/Shanghai',
      'population': 9236032,
      'country': '中国',
      'admin1': '浙江',
      'admin2': '杭州市',
    },
    {
      'id': 6976333,
      'name': '杭州',
      'latitude': 30.06517,
      'longitude': 102.19527,
      'elevation': 2321.0,
      'feature_code': 'PPL',
      'country_code': 'CN',
      'timezone': 'Asia/Shanghai',
      'country': '中国',
      'admin1': '四川',
      'admin2': '甘孜藏族自治州',
    },
    // 畸形条目：缺经纬度，必须被跳过而不是整批失败。
    {'name': '坏数据'},
  ],
};

void main() {
  group('fetchForecast', () {
    test('解析逐小时各字段', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(_forecastPayload()), 200, headers: _jsonHeaders),
        ),
      );

      final forecast = await service.fetchForecast(_hangzhou);
      expect(forecast, isNotNull);
      expect(forecast!.hourly.length, 3);

      final first = forecast.hourly.first;
      expect(first.time, DateTime(2026, 9, 18, 8));
      expect(first.temperatureC, closeTo(25.1, 1e-9));
      expect(first.precipitationProbability, 8);
      expect(first.precipitationMm, closeTo(0.0, 1e-9));
      expect(first.snowfallCm, closeTo(0.0, 1e-9));
      expect(first.weatherCode, 3);

      expect(forecast.hourly.last.weatherCode, 61);
      expect(forecast.hourly.last.precipitationProbability, 42);
    });

    test('经纬度取响应回填的格点中心，便于缓存判同城', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(_forecastPayload()), 200, headers: _jsonHeaders),
        ),
      );
      final forecast = await service.fetchForecast(_hangzhou);
      expect(forecast!.latitude, closeTo(30.263618, 1e-9));
      expect(forecast.longitude, closeTo(120.14051, 1e-9));
    });

    test('请求带上必需参数：变量表、城市时区、回溯与窗口天数', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.fetchForecast(_hangzhou);
      expect(captured, isNotNull);
      expect(captured!.host, 'api.open-meteo.com');
      expect(captured!.path, '/v1/forecast');
      expect(
        captured!.queryParameters['hourly'],
        'temperature_2m,precipitation_probability,precipitation,snowfall,weather_code',
      );
      expect(captured!.queryParameters['timezone'], 'Asia/Shanghai');
      expect(captured!.queryParameters['past_days'], '1');
      expect(captured!.queryParameters['forecast_days'], '16');
      expect(captured!.queryParameters['latitude'], '30.29365');
      expect(captured!.queryParameters['longitude'], '120.16142');
    });

    test('城市没带时区时退回 auto', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.fetchForecast(
        const WeatherLocation(name: '杭州', latitude: 30.29, longitude: 120.16),
      );
      expect(captured!.queryParameters['timezone'], 'auto');
    });

    test('非 200 返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('网络异常返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('超时返回 null 而不抛', () async {
      final service = WeatherService(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response(
            jsonEncode(_forecastPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('畸形 JSON 返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('{not json', 200, headers: _jsonHeaders),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('响应是数组而非对象时返回 null', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('[1,2,3]', 200, headers: _jsonHeaders),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('缺 hourly 块返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'latitude': 30.26, 'longitude': 120.14}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });

    test('hourly 块里没有任何小时点返回 null', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'latitude': 30.26,
              'longitude': 120.14,
              'hourly': {'time': <String>[]},
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );
      expect(await service.fetchForecast(_hangzhou), isNull);
    });
  });

  group('searchLocations', () {
    test('解析候选地点，中文名不乱码且保留行政区', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async =>
              http.Response(jsonEncode(_geocodingPayload()), 200, headers: _jsonHeaders),
        ),
      );

      final locations = await service.searchLocations('杭州');
      expect(locations.length, 2);
      expect(locations.first.name, '杭州');
      expect(locations.first.admin1, '浙江');
      expect(locations.first.country, '中国');
      expect(locations.first.timezone, 'Asia/Shanghai');
      expect(locations.first.regionLabel, '浙江 · 中国');
      expect(locations.last.admin1, '四川');
      expect(
        locations.first.isSamePlaceAs(locations.last),
        isFalse,
        reason: '同名不同地必须靠经纬度区分开',
      );
    });

    test('请求带 language=zh 与 count', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode(_geocodingPayload()),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.searchLocations('杭州');
      expect(captured!.host, 'geocoding-api.open-meteo.com');
      expect(captured!.queryParameters['name'], '杭州');
      expect(captured!.queryParameters['language'], 'zh');
      expect(captured!.queryParameters['count'], '10');
      expect(captured!.queryParameters['format'], 'json');
    });

    test('关键字不足两个字符时不发请求', () async {
      var calls = 0;
      final service = WeatherService(
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );

      expect(await service.searchLocations('杭'), isEmpty);
      expect(await service.searchLocations('   '), isEmpty);
      expect(await service.searchLocations(''), isEmpty);
      expect(calls, 0);
    });

    test('无 results 字段时返回空列表', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('{}', 200, headers: _jsonHeaders),
        ),
      );
      expect(await service.searchLocations('杭州'), isEmpty);
    });

    test('非 200 返回空列表而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('boom', 500)),
      );
      expect(await service.searchLocations('杭州'), isEmpty);
    });

    test('网络异常返回空列表而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );
      expect(await service.searchLocations('杭州'), isEmpty);
    });
  });

  group('reverseGeocode', () {
    test('解析出省 / 市 / 区（杭州实测结构）', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'latitude': 30.29365,
              'longitude': 120.16142,
              'countryName': '中华人民共和国',
              'principalSubdivision': '浙江省',
              'city': '杭州市',
              'locality': '拱墅区',
              'postcode': '',
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(
        latitude: 30.29365,
        longitude: 120.16142,
      );

      expect(location, isNotNull);
      expect(location!.name, '杭州市');
      expect(location.admin1, '浙江省');
      expect(location.country, '中华人民共和国');
      expect(location.district, '拱墅区');
      expect(location.displayName, '杭州市 · 拱墅区');
      // 时区留空，让预报接口用 timezone=auto 按坐标自行解析。
      expect(location.timezone, isNull);
      expect(location.latitude, closeTo(30.29365, 1e-9));
      expect(location.longitude, closeTo(120.16142, 1e-9));
    });

    test('请求带 zh-Hans（传 zh / zh-CN 会返回繁体）', () async {
      Uri? captured;
      final service = WeatherService(
        client: MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode({'city': '杭州市'}),
            200,
            headers: _jsonHeaders,
          );
        }),
      );

      await service.reverseGeocode(latitude: 30.29, longitude: 120.16);

      expect(captured!.host, 'api.bigdatacloud.net');
      expect(
        captured!.path,
        '/data/reverse-geocode-client',
      );
      expect(captured!.queryParameters['localityLanguage'], 'zh-Hans');
      expect(captured!.queryParameters['latitude'], '30.29');
      expect(captured!.queryParameters['longitude'], '120.16');
    });

    test('city 缺失时退到 locality', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'locality': '铜梁区', 'principalSubdivision': '重庆市'}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(
        latitude: 29.86,
        longitude: 106.03,
      );

      expect(location!.name, '铜梁区');
      // 市名与区名来自同一个字段，不该再当成两段重复显示。
      expect(location.district, isNull);
      expect(location.displayName, '铜梁区');
    });

    test('区名与市名相同时不重复记 district', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'city': '铜梁区', 'locality': '铜梁区'}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(
        latitude: 29.86,
        longitude: 106.03,
      );

      expect(location!.district, isNull);
      expect(location.displayName, '铜梁区');
    });

    test('空串与缺失字段都按缺失处理', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'city': '   ',
              'locality': '   ',
              'principalSubdivision': '',
              'countryName': null,
            }),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      // 地名全空 → 没有可用名字，返回 null。
      expect(
        await service.reverseGeocode(latitude: 30.29, longitude: 120.16),
        isNull,
      );
    });

    test('缺行政区与国家时仍能给出市名', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'city': '杭州市'}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(
        latitude: 30.29,
        longitude: 120.16,
      );

      expect(location!.name, '杭州市');
      expect(location.admin1, isNull);
      expect(location.country, isNull);
      expect(location.district, isNull);
      expect(location.regionLabel, '');
    });

    test('中文不乱码', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({'city': '杭州市', 'locality': '拱墅区'}),
            200,
            headers: _jsonHeaders,
          ),
        ),
      );

      final location = await service.reverseGeocode(
        latitude: 30.29,
        longitude: 120.16,
      );
      expect(location!.displayName, '杭州市 · 拱墅区');
      expect(location.displayName, isNot(contains('�')));
    });

    test('非 200 返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => http.Response('nope', 503)),
      );
      expect(
        await service.reverseGeocode(latitude: 30.29, longitude: 120.16),
        isNull,
      );
    });

    test('网络异常返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient((_) async => throw const SocketExceptionStub()),
      );
      expect(
        await service.reverseGeocode(latitude: 30.29, longitude: 120.16),
        isNull,
      );
    });

    test('超时返回 null 而不抛', () async {
      final service = WeatherService(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          return http.Response(
            jsonEncode({'city': '杭州市'}),
            200,
            headers: _jsonHeaders,
          );
        }),
      );
      expect(
        await service.reverseGeocode(latitude: 30.29, longitude: 120.16),
        isNull,
      );
    });

    test('畸形 JSON 返回 null 而不抛', () async {
      final service = WeatherService(
        client: MockClient(
          (_) async => http.Response('{not json', 200, headers: _jsonHeaders),
        ),
      );
      expect(
        await service.reverseGeocode(latitude: 30.29, longitude: 120.16),
        isNull,
      );
    });
  });

  group('WeatherPreferences', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('默认关闭，开关可读写', () async {
      expect(await WeatherPreferences.isEnabled(), isFalse);
      await WeatherPreferences.setEnabled(true);
      expect(await WeatherPreferences.isEnabled(), isTrue);
    });

    test('未设置城市时返回 null', () async {
      expect(await WeatherPreferences.loadLocation(), isNull);
    });

    test('城市往返一致', () async {
      await WeatherPreferences.saveLocation(_hangzhou);
      final restored = await WeatherPreferences.loadLocation();
      expect(restored, isNotNull);
      expect(restored!.name, '杭州');
      expect(restored.admin1, '浙江');
      expect(restored.timezone, 'Asia/Shanghai');
      expect(restored.latitude, closeTo(30.29365, 1e-9));
    });

    test('城市数据损坏时按未设置处理', () async {
      SharedPreferences.setMockInitialValues({
        WeatherPreferences.locationKey: 'not json',
      });
      expect(await WeatherPreferences.loadLocation(), isNull);
    });

    test('预报往返一致，清空后回到 null', () async {
      final forecast = WeatherForecast.fromOpenMeteoResponse(
        _forecastPayload(),
        fetchedAt: DateTime(2026, 9, 18, 6, 30),
      );
      expect(forecast.hourly.length, 3);

      await WeatherPreferences.saveForecast(forecast);
      final restored = await WeatherPreferences.loadForecast();
      expect(restored, isNotNull);
      expect(restored!.hourly.length, 3);
      expect(restored.hourly.last.time, DateTime(2026, 9, 18, 10));
      expect(restored.hourly.last.precipitationProbability, 42);
      expect(restored.hourly.last.weatherCode, 61);
      expect(restored.fetchedAt, DateTime(2026, 9, 18, 6, 30));

      await WeatherPreferences.clearForecast();
      expect(await WeatherPreferences.loadForecast(), isNull);
    });

    test('预报缓存损坏时按无缓存处理', () async {
      SharedPreferences.setMockInitialValues({
        WeatherPreferences.forecastKey: '{"latitude":1}',
      });
      expect(await WeatherPreferences.loadForecast(), isNull);
    });
  });
}

/// 用一个本地异常类型代替 dart:io 的 SocketException，避免测试文件依赖 IO。
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub: simulated network failure';
}
