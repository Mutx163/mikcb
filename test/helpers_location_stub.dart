import 'package:geolocator/geolocator.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/services/device_location_service.dart';

/// 假定位源：页面与 provider 级测试用它绕开真实平台通道。
///
/// 完整的失败矩阵（拒绝 / 永久拒绝 / 超时 / 插件抛异常）在
/// `test/services/device_location_service_test.dart` 里用更专门的假件覆盖；
/// 这里只解决「别真的去调 geolocator」这一件事。
class StubDeviceLocationSource implements DeviceLocationSource {
  StubDeviceLocationSource({
    this.serviceEnabled = true,
    this.latitude = 30.29365,
    this.longitude = 120.16142,
    this.delay,
    this.lastKnown,
  });

  bool serviceEnabled;
  double latitude;
  double longitude;

  /// 让取位置晚一点返回，用来在测试里观察「定位中」这一瞬间的状态。
  Duration? delay;

  /// 系统缓存的上一次位置；默认 null（走实时定位那条路）。
  Position? lastKnown;

  int positionCalls = 0;
  int lastKnownCalls = 0;

  /// 造一个「几分钟前」的缓存位置，用来测缓存年龄判定。
  static Position cachedAgo(
    Duration age, {
    double latitude = 30.29365,
    double longitude = 120.16142,
  }) {
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now().subtract(age),
      accuracy: 800,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition() async {
    lastKnownCalls++;
    return lastKnown;
  }

  @override
  Future<Position> getCurrentPosition(LocationSettings settings) async {
    positionCalls++;
    final wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
    return Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime(2026, 9, 18, 10),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

/// 定位反查会得到的杭州（带区级），用来断言「详细位置」确实显示出来了。
const stubLocatedHangzhou = WeatherLocation(
  name: '杭州市',
  admin1: '浙江省',
  country: '中国',
  district: '拱墅区',
  latitude: 30.29365,
  longitude: 120.16142,
);

/// 造一个只在「反查结果」上可配的定位服务；[resolvesTo] 传 null 模拟反查失败。
DeviceLocationService stubLocationService({
  WeatherLocation? resolvesTo = stubLocatedHangzhou,
  StubDeviceLocationSource? source,
}) {
  return DeviceLocationService(
    reverseGeocode: (_, _) async => resolvesTo,
    source: source ?? StubDeviceLocationSource(),
  );
}
