import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/weather_logic.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/services/device_location_service.dart';
import 'package:university_timetable/services/weather_preferences.dart';
import 'package:university_timetable/services/weather_service.dart';

import '../helpers_location_stub.dart';

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

const _hangzhou = WeatherLocation(
  name: '杭州',
  admin1: '浙江',
  latitude: 30.29365,
  longitude: 120.16142,
  timezone: 'Asia/Shanghai',
);

const _chengdu = WeatherLocation(
  name: '成都',
  admin1: '四川',
  latitude: 30.5728,
  longitude: 104.0668,
  timezone: 'Asia/Shanghai',
);

/// 造一份窗口覆盖「今天 0 点起 96 小时」的响应，让 now 一定落在窗口内。
///
/// 风向很关键：`hasLapsedAt(now)` 一旦为真就会一直判过期，TTL 类断言会失真。
Map<String, dynamic> _payload({
  double latitude = 30.29365,
  double longitude = 120.16142,
}) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  String two(int value) => value.toString().padLeft(2, '0');
  final times = <String>[
    for (var hour = 0; hour < 96; hour++)
      () {
        final time = start.add(Duration(hours: hour));
        return '${time.year}-${two(time.month)}-${two(time.day)}'
            'T${two(time.hour)}:00';
      }(),
  ];
  return {
    'latitude': latitude,
    'longitude': longitude,
    'timezone': 'Asia/Shanghai',
    'hourly': {
      'time': times,
      'temperature_2m': [for (var i = 0; i < 96; i++) 20.0 + (i % 5)],
      'precipitation_probability': [for (var i = 0; i < 96; i++) 60],
      'precipitation': [for (var i = 0; i < 96; i++) 0.5],
      'snowfall': [for (var i = 0; i < 96; i++) 0.0],
      'weather_code': [for (var i = 0; i < 96; i++) 61],
    },
  };
}

/// 可计数的假服务端。[fail] 为 true 时一律返回 500。
class _Server {
  _Server({this.fail = false});

  bool fail;
  int calls = 0;
  final List<Uri> uris = [];

  WeatherService get service => WeatherService(client: _client);

  late final MockClient _client = MockClient((request) async {
    calls++;
    uris.add(request.url);
    if (fail) {
      return http.Response('boom', 500);
    }
    if (request.url.host == 'geocoding-api.open-meteo.com') {
      return http.Response(
        jsonEncode({
          'results': [
            {
              'name': '杭州',
              'latitude': 30.29365,
              'longitude': 120.16142,
              'country': '中国',
              'admin1': '浙江',
              'timezone': 'Asia/Shanghai',
            },
          ],
        }),
        200,
        headers: _jsonHeaders,
      );
    }
    final latitude =
        double.tryParse(request.url.queryParameters['latitude'] ?? '') ??
        _hangzhou.latitude;
    final longitude =
        double.tryParse(request.url.queryParameters['longitude'] ?? '') ??
        _hangzhou.longitude;
    return http.Response(
      jsonEncode(_payload(latitude: latitude, longitude: longitude)),
      200,
      headers: _jsonHeaders,
    );
  });
}

/// 今天（与 [_payload] 的窗口起点同一天）的一个课程时刻。
DateTime get _today => DateTime.now();
String _timeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

CourseWeatherSummary? _summaryOf(WeatherProvider provider, {int hour = 8}) {
  return provider.summaryForCourse(
    date: _today,
    startTime: _timeOfDay(hour, 0),
    endTime: _timeOfDay(hour + 1, 35),
  );
}

Future<void> _seed({
  bool enabled = true,
  WeatherLocation? location = _hangzhou,
  WeatherForecast? forecast,
}) async {
  await WeatherPreferences.setEnabled(enabled);
  if (location != null) {
    await WeatherPreferences.saveLocation(location);
  }
  if (forecast != null) {
    await WeatherPreferences.saveForecast(forecast);
  }
}

/// 定位反查会得到的地点。
const _located = WeatherLocation(
  name: '成都市',
  admin1: '四川省',
  country: '中国',
  district: '武侯区',
  latitude: 30.5728,
  longitude: 104.0668,
);

/// 定位源固定在 [_located] 的坐标上（断言「请求打在新坐标上」要用）。
StubDeviceLocationSource _source({bool serviceEnabled = true}) =>
    StubDeviceLocationSource(
      serviceEnabled: serviceEnabled,
      latitude: _located.latitude,
      longitude: _located.longitude,
    );

DeviceLocationService _locationService(
  StubDeviceLocationSource source, {
  required WeatherLocation? resolvesTo,
}) => stubLocationService(resolvesTo: resolvesTo, source: source);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('一键定位', () {
    test('成功：换城市、落盘、重拉预报、清空失败原因', () async {
      await _seed();
      final server = _Server();
      final source = _source();
      final provider = WeatherProvider(
        service: server.service,
        locationService: _locationService(source, resolvesTo: _located),
      );
      await provider.initialize();
      await provider.ensureFresh();
      expect(provider.location!.name, '杭州');
      final callsBefore = server.calls;

      final failure = await provider.locateCurrentPosition();
      // 定位成功后 provider 是在后台重拉预报的（界面不该等网络），测试里补一次
      // await 把它落定；单飞会返回同一个在飞的 future。
      await provider.ensureFresh();

      expect(failure, isNull);
      expect(provider.lastLocateFailure, isNull);
      expect(provider.isLocating, isFalse);
      expect(provider.location!.name, '成都市');
      expect(provider.location!.district, '武侯区');
      expect(provider.location!.displayName, '成都市 · 武侯区');
      // 换了城市 → 旧预报作废并重拉，且请求打在新坐标上。
      expect(server.calls, greaterThan(callsBefore));
      expect(
        server.uris.last.queryParameters['latitude'],
        '${_located.latitude}',
      );
      // 也落了盘：重启后不必重新定位。
      final persisted = await WeatherPreferences.loadLocation();
      expect(persisted!.district, '武侯区');
    });

    test('失败：记录原因，且**不动**用户原来选好的城市', () async {
      await _seed();
      final server = _Server();
      final source = _source();
      final provider = WeatherProvider(
        service: server.service,
        locationService: _locationService(source, resolvesTo: null),
      );
      await provider.initialize();
      await provider.ensureFresh();
      final original = provider.location!;

      final failure = await provider.locateCurrentPosition();

      expect(failure, DeviceLocationFailure.addressUnavailable);
      expect(provider.lastLocateFailure, DeviceLocationFailure.addressUnavailable);
      expect(provider.location!.name, original.name);
      expect(provider.location!.latitude, original.latitude);
      final persisted = await WeatherPreferences.loadLocation();
      expect(persisted!.name, original.name);
    });

    test('系统定位开关没开时透传 serviceDisabled', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(
        service: server.service,
        locationService: _locationService(
          _source(serviceEnabled: false),
          resolvesTo: _located,
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        await provider.locateCurrentPosition(),
        DeviceLocationFailure.serviceDisabled,
      );
      expect(provider.location!.name, '杭州');
    });

    test('连点两次只跑一次（单飞）', () async {
      await _seed();
      final server = _Server();
      final source = _source();
      final provider = WeatherProvider(
        service: server.service,
        locationService: _locationService(source, resolvesTo: _located),
      );
      await provider.initialize();
      await provider.ensureFresh();

      final first = provider.locateCurrentPosition();
      final second = provider.locateCurrentPosition();
      final results = await Future.wait([first, second]);

      expect(source.positionCalls, 1);
      expect(results, [isNull, isNull]);
    });

    test('定位期间 isLocating 为 true 并通知监听者，结束后复位', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(
        service: server.service,
        locationService: _locationService(
          _source(),
          resolvesTo: _located,
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      var notifications = 0;
      provider.addListener(() => notifications++);

      final future = provider.locateCurrentPosition();
      // 同步就能看到「进行中」——界面据此立刻禁用入口。
      expect(provider.isLocating, isTrue);

      await future;
      expect(provider.isLocating, isFalse);
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test('失败后再点会重试，成功后清空失败原因', () async {
      await _seed();
      final server = _Server();
      var resolves = false;
      final provider = WeatherProvider(
        service: server.service,
        locationService: DeviceLocationService(
          reverseGeocode: (_, _) async => resolves ? _located : null,
          source: _source(),
        ),
      );
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        await provider.locateCurrentPosition(),
        DeviceLocationFailure.addressUnavailable,
      );
      expect(provider.lastLocateFailure, isNotNull);

      resolves = true;
      expect(await provider.locateCurrentPosition(), isNull);
      expect(provider.lastLocateFailure, isNull);
      expect(provider.location!.name, '成都市');
    });
  });

  group('初始化', () {
    test('没有城市时 summaryForCourse 返回 null 且一次请求都不发', () async {
      await _seed(location: null);
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 0);
      expect(_summaryOf(provider), isNull);
      expect(provider.status, WeatherStatus.idle);
    });

    test('开关关闭时不发请求，summaryForCourse 返回 null', () async {
      await _seed(enabled: false);
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 0);
      expect(_summaryOf(provider), isNull);
    });

    test('有城市且开关打开时拉一次，之后能取到摘要', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(provider.status, WeatherStatus.ready);
      final summary = _summaryOf(provider);
      expect(summary, isNotNull);
      expect(summary!.category, WeatherCategory.lightRain);
      expect(summary.precipitationProbability, 60);
      expect(summary.showPrecipitationProbability, isTrue);
    });

    test('缓存被读回，重启后不必等网络就有数据', () async {
      final cached = WeatherForecast.fromOpenMeteoResponse(
        _payload(),
        fetchedAt: DateTime.now(),
      );
      await _seed(forecast: cached);

      final hanging = WeatherService(
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('{}', 200, headers: _jsonHeaders);
        }),
      );
      final provider = WeatherProvider(service: hanging);

      await provider.initialize();
      // 刻意不 await ensureFresh：验证首帧就有数据，不等网络。
      expect(_summaryOf(provider), isNotNull);
    });

    test('缓存城市与所选城市不一致时被丢弃', () async {
      final cached = WeatherForecast.fromOpenMeteoResponse(
        _payload(latitude: _chengdu.latitude, longitude: _chengdu.longitude),
        fetchedAt: DateTime.now(),
      );
      // 所选城市用 _seed 的默认值（杭州），而缓存是成都的。
      await _seed(forecast: cached);

      final server = _Server();
      final provider = WeatherProvider(
        service: server.service,
        // 把时钟推远，让「过期就刷」在这次 initialize 里不会补上数据。
        clock: () => DateTime.now().add(const Duration(hours: 4)),
      );

      await provider.initialize();
      expect(provider.forecast, isNull);
    });

    test('重复 initialize 只生效一次', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 1);
    });

    test('未 initialize 时 summaryForCourse 返回 null 而不是抛', () {
      final server = _Server();
      final provider = WeatherProvider(service: server.service);
      expect(_summaryOf(provider), isNull);
    });
  });

  group('刷新策略', () {
    test('ensureFresh 连调三次只发一次（单飞）', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      final first = provider.ensureFresh();
      final second = provider.ensureFresh();
      final third = provider.ensureFresh();
      await Future.wait([first, second, third]);

      expect(server.calls, 1);
    });

    test('TTL 内不再发请求', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(
        service: server.service,
        clock: () => DateTime.now().add(const Duration(hours: 2)),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.ensureFresh();
      await provider.ensureFresh();
      expect(server.calls, 1);
    });

    test('超过 TTL 会重拉', () async {
      await _seed();
      final server = _Server();
      var offset = Duration.zero;
      final provider = WeatherProvider(
        service: server.service,
        clock: () => DateTime.now().add(offset),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      offset = const Duration(hours: 4);
      await provider.ensureFresh();
      expect(server.calls, 2);
    });

    test('预报窗口走完会重拉', () async {
      await _seed();
      final server = _Server();
      var offset = Duration.zero;
      final provider = WeatherProvider(
        service: server.service,
        clock: () => DateTime.now().add(offset),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      // 窗口是今天 0 点起 96 小时，推到第 100 小时即已走完。
      offset = const Duration(hours: 100);
      await provider.ensureFresh();
      expect(server.calls, 2);
    });
  });

  group('失败降级', () {
    test('失败且无缓存：状态为 failed，摘要为 null，不抛', () async {
      await _seed();
      final server = _Server(fail: true);
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(provider.status, WeatherStatus.failed);
      expect(_summaryOf(provider), isNull);
      expect(provider.forecast, isNull);
    });

    test('失败但有缓存：旧数据继续用，卡片不受影响', () async {
      final cached = WeatherForecast.fromOpenMeteoResponse(
        _payload(),
        fetchedAt: DateTime.now().subtract(const Duration(hours: 6)),
      );
      await _seed(forecast: cached);
      final server = _Server(fail: true);
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();

      expect(provider.status, WeatherStatus.failed);
      expect(_summaryOf(provider), isNotNull);
    });

    test('失败后进入退避，退避期内不再撞服务器', () async {
      await _seed();
      final server = _Server(fail: true);
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.ensureFresh();
      await provider.ensureFresh();
      expect(server.calls, 1);
    });

    test('退避过期后会再试', () async {
      await _seed();
      final server = _Server(fail: true);
      var offset = Duration.zero;
      final provider = WeatherProvider(
        service: server.service,
        clock: () => DateTime.now().add(offset),
      );

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      offset = WeatherProvider.failureRetryDelay + const Duration(minutes: 1);
      await provider.ensureFresh();
      expect(server.calls, 2);
    });

    test('retry 清掉退避并立即重试', () async {
      await _seed();
      final server = _Server(fail: true);
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.retry();
      expect(server.calls, 2);
    });

    test('retry 在恢复成功后转为 ready', () async {
      await _seed();
      final server = _Server(fail: true);
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      expect(provider.status, WeatherStatus.failed);

      server.fail = false;
      await provider.retry();
      expect(provider.status, WeatherStatus.ready);
      expect(_summaryOf(provider), isNotNull);
    });
  });

  group('设置变更', () {
    test('打开开关时补拉数据', () async {
      await _seed(enabled: false);
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      expect(server.calls, 0);

      await provider.setEnabled(true);
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(_summaryOf(provider), isNotNull);
    });

    test('关闭开关后 summaryForCourse 立即返回 null', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      expect(_summaryOf(provider), isNotNull);

      await provider.setEnabled(false);
      expect(_summaryOf(provider), isNull);
    });

    test('换城市会作废旧缓存并立刻重拉', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);
      expect(server.uris.single.queryParameters['latitude'], '30.29365');

      await provider.setLocation(_chengdu);
      await provider.ensureFresh();

      expect(server.calls, 2);
      expect(server.uris.last.queryParameters['latitude'], '30.5728');
      expect(_summaryOf(provider), isNotNull);
    });

    test('换城市后磁盘上留下的必须是新城市的数', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      final beforeSwitch = await WeatherPreferences.loadForecast();
      expect(beforeSwitch!.latitude, closeTo(_hangzhou.latitude, 1e-6));

      await provider.setLocation(_chengdu);
      await provider.ensureFresh();

      // 假服务端把请求坐标回填进响应，所以落盘的坐标就是「这份数据是谁的」。
      final onDisk = await WeatherPreferences.loadForecast();
      expect(onDisk, isNotNull);
      expect(onDisk!.latitude, closeTo(_chengdu.latitude, 1e-6));
      expect(onDisk.longitude, closeTo(_chengdu.longitude, 1e-6));
    });

    test('选同一个地点不重拉（幂等）', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.ensureFresh();
      expect(server.calls, 1);

      await provider.setLocation(_hangzhou);
      await provider.ensureFresh();

      expect(server.calls, 1);
      expect(_summaryOf(provider), isNotNull);
    });

    test('重复设置同一个开关值不触发请求', () async {
      await _seed(enabled: false);
      final server = _Server();
      final provider = WeatherProvider(service: server.service);

      await provider.initialize();
      await provider.setEnabled(false);
      await provider.ensureFresh();

      expect(server.calls, 0);
    });

    test('设置变更会通知监听者', () async {
      await _seed(enabled: false);
      final server = _Server();
      final provider = WeatherProvider(service: server.service);
      await provider.initialize();

      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.setEnabled(true);
      expect(notifications, greaterThan(0));
    });
  });

  group('城市搜索转发', () {
    test('searchLocations 转发给 service 并返回候选', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);
      await provider.initialize();
      await provider.ensureFresh();

      final results = await provider.searchLocations('杭州');
      expect(results, isNotEmpty);
      expect(results.first.name, '杭州');
      expect(results.first.admin1, '浙江');
      expect(server.uris.last.host, 'geocoding-api.open-meteo.com');
      expect(server.uris.last.queryParameters['name'], '杭州');
    });

    test('关键字不足两个字符时转发也不发请求', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);
      await provider.initialize();
      await provider.ensureFresh();
      final callsBefore = server.calls;

      expect(await provider.searchLocations('杭'), isEmpty);
      expect(await provider.searchLocations('  '), isEmpty);
      expect(server.calls, callsBefore);
    });
  });

  group('summaryForCourse 入参防御', () {
    test('畸形的时间串返回 null', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        provider.summaryForCourse(
          date: _today,
          startTime: 'oops',
          endTime: '09:35',
        ),
        isNull,
      );
      expect(
        provider.summaryForCourse(
          date: _today,
          startTime: '08:00',
          endTime: '25:00',
        ),
        isNull,
      );
    });

    test('预报窗口之外的日子返回 null', () async {
      await _seed();
      final server = _Server();
      final provider = WeatherProvider(service: server.service);
      await provider.initialize();
      await provider.ensureFresh();

      expect(
        provider.summaryForCourse(
          date: _today.add(const Duration(days: 30)),
          startTime: '08:00',
          endTime: '09:35',
        ),
        isNull,
      );
    });
  });
}
