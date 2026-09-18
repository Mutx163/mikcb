import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/services/device_location_service.dart';

/// 假定位源：让失败矩阵不用真实平台通道也能测。
class _FakeSource implements DeviceLocationSource {
  _FakeSource({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.permissionAfterRequest,
    this.positionThrower,
    this.lastKnown,
    this.lastKnownThrower,
  });

  bool serviceEnabled;
  LocationPermission permission;

  /// `requestPermission()` 的返回值；null 表示与 [permission] 相同。
  LocationPermission? permissionAfterRequest;

  /// 让 `getCurrentPosition` 抛出指定异常（超时 / 插件故障等）。
  void Function()? positionThrower;

  /// 系统缓存的上一次位置。
  Position? lastKnown;

  /// 让 `getLastKnownPosition` 抛出异常（验证它不会拖垮主流程）。
  void Function()? lastKnownThrower;

  int serviceChecks = 0;
  int permissionChecks = 0;
  int permissionRequests = 0;
  int positionCalls = 0;
  int lastKnownCalls = 0;
  LocationSettings? lastSettings;

  /// 若干分钟前的缓存位置。
  static Position cachedAgo(Duration age) => Position(
    latitude: 30.29365,
    longitude: 120.16142,
    timestamp: DateTime.now().subtract(age),
    accuracy: 800,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

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
  Future<Position?> getLastKnownPosition() async {
    lastKnownCalls++;
    lastKnownThrower?.call();
    return lastKnown;
  }

  @override
  Future<Position> getCurrentPosition(LocationSettings settings) async {
    positionCalls++;
    lastSettings = settings;
    positionThrower?.call();
    return Position(
      latitude: 30.29365,
      longitude: 120.16142,
      timestamp: DateTime(2026, 9, 18, 10),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
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

void main() {
  group('权限与系统状态', () {
    test('系统定位开关没开时直接失败，不申请权限也不取位置', () async {
      final source = _FakeSource(serviceEnabled: false);
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.serviceDisabled);
      expect(outcome.location, isNull);
      expect(source.permissionChecks, 0);
      expect(source.permissionRequests, 0);
      expect(source.positionCalls, 0);
    });

    test('首次是 denied 时会弹框申请，授予后继续', () async {
      final source = _FakeSource(
        permission: LocationPermission.denied,
        permissionAfterRequest: LocationPermission.whileInUse,
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
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
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.permissionDenied);
      expect(source.positionCalls, 0);
    });

    test('永久拒绝 → permissionDeniedForever，且不再申请、不取位置', () async {
      final source = _FakeSource(permission: LocationPermission.deniedForever);
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.permissionDeniedForever);
      expect(source.permissionRequests, 0);
      expect(source.positionCalls, 0);
    });

    test('unableToDetermine 归为 failed，绝不当成已授权', () async {
      final source = _FakeSource(permission: LocationPermission.unableToDetermine);
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
      expect(source.positionCalls, 0);
    });
  });

  group('取位置', () {
    test('超时 → timeout，且不反查', () async {
      var reverseCalled = 0;
      final source = _FakeSource(positionThrower: () => throw TimeoutException('too slow'));
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async {
          reverseCalled++;
          return _hangzhou();
        },
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.timeout);
      expect(reverseCalled, 0);
    });

    test('插件抛其它异常 → failed', () async {
      final source = _FakeSource(positionThrower: () => throw StateError('plugin blew up'));
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
    });

    test('用高精度与 25 秒上限，且坐标透传给反查', () async {
      final source = _FakeSource();
      double? seenLatitude;
      double? seenLongitude;
      final service = DeviceLocationService(
        reverseGeocode: (latitude, longitude) async {
          seenLatitude = latitude;
          seenLongitude = longitude;
          return _hangzhou();
        },
        source: source,
      );

      await service.locate();

      expect(source.lastSettings?.accuracy, LocationAccuracy.high);
      expect(source.lastSettings?.timeLimit, const Duration(seconds: 25));
      expect(seenLatitude, closeTo(30.29365, 1e-9));
      expect(seenLongitude, closeTo(120.16142, 1e-9));
    });
  });

  group('反查', () {
    test('反查失败（返回 null）→ addressUnavailable，不当成定位失败', () async {
      final source = _FakeSource();
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => null,
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.addressUnavailable);
      expect(outcome.location, isNull);
      // 坐标是拿到了的，所以取位置这一步确实走过了。
      expect(source.positionCalls, 1);
    });

    test('反查抛异常也不外抛，落成 failed', () async {
      final source = _FakeSource();
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => throw StateError('boom'),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.failure, DeviceLocationFailure.failed);
    });
  });

  group('成功', () {
    test('返回带区级的地点，且原始经纬度原样保留', () async {
      final source = _FakeSource();
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
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
    });
  });

  group('系统缓存位置优先（真机室内等不到 GPS 的修法）', () {
    test('有新鲜缓存时直接用，不再等实时定位', () async {
      final source = _FakeSource(
        lastKnown: _FakeSource.cachedAgo(const Duration(minutes: 3)),
        // 实时定位故意抛超时：只要走了它就会失败，用来证明这条路没被走。
        positionThrower: () => throw TimeoutException('should not be used'),
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.isSuccess, isTrue);
      expect(source.lastKnownCalls, 1);
      expect(source.positionCalls, 0);
    });

    test('缓存太旧则不用，改为等实时定位', () async {
      final source = _FakeSource(
        lastKnown: _FakeSource.cachedAgo(const Duration(hours: 3)),
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.isSuccess, isTrue);
      expect(source.lastKnownCalls, 1);
      expect(source.positionCalls, 1);
    });

    test('缓存刚好在可接受年龄内就用它', () async {
      final source = _FakeSource(
        lastKnown: _FakeSource.cachedAgo(
          DeviceLocationService.lastKnownMaxAge - const Duration(minutes: 1),
        ),
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      await service.locate();

      expect(source.positionCalls, 0);
    });

    test('没有缓存时等实时定位', () async {
      final source = _FakeSource();
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.isSuccess, isTrue);
      expect(source.lastKnownCalls, 1);
      expect(source.positionCalls, 1);
    });

    test('查缓存本身抛异常也不影响主流程', () async {
      final source = _FakeSource(
        lastKnownThrower: () => throw StateError('cache blew up'),
      );
      final service = DeviceLocationService(
        reverseGeocode: (_, _) async => _hangzhou(),
        source: source,
      );

      final outcome = await service.locate();

      expect(outcome.isSuccess, isTrue);
      expect(source.positionCalls, 1);
    });

    test('缓存命中也走反查，坐标用缓存里的那一份', () async {
      final source = _FakeSource(
        lastKnown: _FakeSource.cachedAgo(const Duration(minutes: 5)),
      );
      double? seenLatitude;
      final service = DeviceLocationService(
        reverseGeocode: (latitude, _) async {
          seenLatitude = latitude;
          return _hangzhou();
        },
        source: source,
      );

      await service.locate();

      expect(seenLatitude, closeTo(30.29365, 1e-9));
    });
  });
}
