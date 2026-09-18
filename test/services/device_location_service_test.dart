import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/services/device_location_service.dart';

/// 假定位源：让失败矩阵不用真实平台通道也能测。
///
/// 契约只有四件事：开关、查权限、申权限、取一次实时坐标。原先那套
/// `getLastKnownPosition` / `LocationSettings` 的参数断言已经随「缓存优先」方案一起
/// 退场——缓存策略现在由原生侧一处维护（见 `LocationFix.kt`），Dart 侧看不到也不该测。
class _FakeSource implements DeviceLocationSource {
  _FakeSource({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.permissionAfterRequest,
    this.fix = const DeviceFix(
      latitude: 30.29365,
      longitude: 120.16142,
      accuracyMeters: 12,
      source: 'network',
    ),
    this.fixThrower,
  });

  bool serviceEnabled;
  LocationPermission permission;

  /// `requestPermission()` 的返回值；null 表示与 [permission] 相同。
  LocationPermission? permissionAfterRequest;

  /// 实时定位的返回值；**null = 拿不到**，会走去 IP 估算那条路。
  DeviceFix? fix;

  /// 让 `getCurrentFix` 抛出指定异常（超时 / 通道故障等）。
  void Function()? fixThrower;

  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int fixCalls = 0;

  @override
  Future<bool> isServiceEnabled() async {
    serviceChecks++;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    permissionChecks++;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permissionAfterRequest ?? permission;
  }

  @override
  Future<DeviceFix?> getCurrentFix() async {
    fixCalls++;
    fixThrower?.call();
    return fix;
  }
}

WeatherLocation _hangzhou({String? district = '拱墅区'}) => WeatherLocation(
  name: '杭州市',
  admin1: '浙江省',
  country: '中国',
  district: district,
  latitude: 30.29365,
  longitude: 120.16142,
);

/// IP 估算会得到的另一座城市，用来证明「估算」与「反查」的结果确实分得开。
const _nanjing = WeatherLocation(
  name: '南京市',
  admin1: '江苏省',
  country: '中国',
  latitude: 32.0603,
  longitude: 118.7969,
);

void main() {
  group('权限与系统状态', () {
    test('系统定位开关没开时直接失败，不申请权限也不取位置', () async {
      final source = _FakeSource(serviceEnabled: false);
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.serviceDisabled);
      expect(outcome.location, isNull);
      expect(source.permissionChecks, 0);
      expect(source.permissionRequests, 0);
      expect(source.fixCalls, 0);
    });

    test('首次是 denied 时会弹框申请，授予后继续', () async {
      final source = _FakeSource(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.whileInUse,
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: source,
      );

      final outcome = await service.locate();

      expect(source.permissionChecks, 1);
      expect(source.permissionRequests, 1);
      expect(outcome.isSuccess, isTrue);
    });

    test('已经授权时不再弹框', () async {
      final source = _FakeSource(permission: LocationPermission.always);
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: source,
      );

      final outcome = await service.locate();

      expect(source.permissionRequests, 0);
      expect(outcome.isSuccess, isTrue);
    });

    test('申请后仍被拒 → permissionDenied，且不取位置', () async {
      final source = _FakeSource(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.denied,
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.permissionDenied);
      expect(source.fixCalls, 0);
    });

    test('永久拒绝 → permissionDeniedForever，且不再申请、不取位置', () async {
      final source = _FakeSource(permission: LocationPermission.deniedForever);
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.permissionDeniedForever);
      expect(source.permissionRequests, 0);
      expect(source.fixCalls, 0);
    });

    test('unableToDetermine 归为 failed，绝不当成已授权', () async {
      final source = _FakeSource(
        permission: LocationPermission.unableToDetermine,
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
      expect(source.fixCalls, 0);
    });
  });

  group('实时定位', () {
    test('拿到实时坐标 → 反查，坐标原样透传，且不碰网络估算', () async {
      var networkCalls = 0;
      double? seenLatitude;
      double? seenLongitude;
      final service = DeviceLocationService(
        reverseGeocode: (latitude, longitude) async {
          seenLatitude = latitude;
          seenLongitude = longitude;
          return _hangzhou();
        },
        networkGeocode: () async {
          networkCalls++;
          return _nanjing;
        },
        source: _FakeSource(),
      );

      final outcome = await service.locate();

      expect(seenLatitude, closeTo(30.29365, 1e-9));
      expect(seenLongitude, closeTo(120.16142, 1e-9));
      // 关键：实时定位成功就绝不能再发一次 IP 估算请求。
      expect(networkCalls, 0);
      expect(outcome.estimated, isFalse);
      expect(outcome.isSuccess, isTrue);
    });

    test('实时定位超时 → timeout，且不反查、不估算', () async {
      var reverseCalls = 0;
      var networkCalls = 0;
      final source = _FakeSource(
        fixThrower: () => throw TimeoutException('too slow'),
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async {
          reverseCalls++;
          return _hangzhou();
        },
        networkGeocode: () async {
          networkCalls++;
          return _nanjing;
        },
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.timeout);
      expect(reverseCalls, 0);
      // 抛异常是「流程坏了」，不是「拿不到」——不该再悄悄走估算把异常盖掉。
      expect(networkCalls, 0);
    });

    test('实时定位抛其它异常 → failed', () async {
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: _FakeSource(
          fixThrower: () => throw StateError('channel blew up'),
        ),
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
    });
  });

  group('反查', () {
    test('反查失败（返回 null）→ addressUnavailable，不当成定位失败', () async {
      var networkCalls = 0;
      final source = _FakeSource();
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => null,
        networkGeocode: () async {
          networkCalls++;
          return _nanjing;
        },
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.addressUnavailable);
      expect(outcome.location, isNull);
      // 坐标是拿到了的，所以取位置这一步确实走过了。
      expect(source.fixCalls, 1);
      // 有坐标但没地名 ≠ 没坐标：不该退化成估算。
      expect(networkCalls, 0);
    });

    test('反查抛异常也不外抛，落成 failed', () async {
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => throw StateError('boom'),
        networkGeocode: () async => _nanjing,
        source: _FakeSource(),
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
    });
  });

  group('IP 估算（实时定位拿不到时的兜底）', () {
    test('实时定位返回 null → 走估算，结果标记 estimated', () async {
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: _FakeSource(fix: null),
      );

      final outcome = await service.locate();

      expect(outcome.isSuccess, isTrue);
      expect(outcome.estimated, isTrue);
      expect(outcome.location!.name, '南京市');
    });

    test('实时定位拿不到、估算也没结果 → timeout', () async {
      var reverseCalls = 0;
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async {
          reverseCalls++;
          return _hangzhou();
        },
        networkGeocode: () async => null,
        source: _FakeSource(fix: null),
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.timeout);
      expect(outcome.location, isNull);
      expect(reverseCalls, 0);
    });

    test('估算抛异常 → failed，不外抛', () async {
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => throw StateError('offline'),
        source: _FakeSource(fix: null),
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
    });
  });

  group('成功', () {
    test('返回带区级的地点，且原始经纬度原样保留', () async {
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        networkGeocode: () async => _nanjing,
        source: _FakeSource(),
      );

      final outcome = await service.locate();

      expect(outcome.isSuccess, isTrue);
      final location = outcome.location!;
      expect(location.name, '杭州市');
      expect(location.admin1, '浙江省');
      expect(location.country, '中国');
      expect(location.district, '拱墅区');
      expect(location.displayName, '杭州市 · 拱墅区');
      // 反查给的是坐标本身，不是格点中心：天气请求以它为准。
      expect(location.latitude, closeTo(30.29365, 1e-9));
      expect(location.longitude, closeTo(120.16142, 1e-9));
      expect(outcome.failure, isNull);
      expect(outcome.estimated, isFalse);
    });

    test('没有区级时 displayName 退回地名，不出现悬空的分隔符', () async {
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(district: null),
        networkGeocode: () async => _nanjing,
        source: _FakeSource(),
      );

      final outcome = await service.locate();

      expect(outcome.location!.district, isNull);
      expect(outcome.location!.displayName, '杭州市');
    });
  });
}
