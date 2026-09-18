import 'package:geolocator/geolocator.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/services/device_location_service.dart';

/// 假定位源：页面与 provider 级测试用它绕开真实平台通道。
///
/// 完整的失败矩阵（拒绝 / 永久拒绝 / 服务关闭 / 通道故障）在
/// `test/services/device_location_service_test.dart` 里用更专门的假件覆盖；
/// 这里只解决「别真的去调原生通道与 geolocator」这一件事。
class StubDeviceLocationSource implements DeviceLocationSource {
  StubDeviceLocationSource({
    this.serviceEnabled = true,
    this.fix = const DeviceFix(
      latitude: 30.29365,
      longitude: 120.16142,
      accuracyMeters: 12,
      source: 'network',
    ),
    this.delay,
  });

  bool serviceEnabled;

  /// 实时定位的返回值；**null 表示「实时定位拿不到」**，会走去 IP 估算那条路。
  DeviceFix? fix;

  /// 让实时定位晚一点返回，用来在测试里观察「定位中」这一瞬间的状态。
  Duration? delay;

  int fixCalls = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<DeviceFix?> getCurrentFix() async {
    fixCalls++;
    final wait = delay;
    if (wait != null) {
      await Future<void>.delayed(wait);
    }
    return fix;
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

/// 造一个可配的定位服务。
///
/// - [resolvesTo] 是坐标反查的返回值，传 null 模拟「有坐标但没地名」；
/// - [estimatesTo] 是 IP 估算的返回值，**默认 null**（等同于网络估算也不可用）；
///   想测「估算成功」就显式传一个地点。
DeviceLocationService stubLocationService({
  WeatherLocation? resolvesTo = stubLocatedHangzhou,
  WeatherLocation? estimatesTo,
  StubDeviceLocationSource? source,
}) {
  return DeviceLocationService(
    reverseGeocode: (_, _) async => resolvesTo,
    networkGeocode: () async => estimatesTo,
    source: source ?? StubDeviceLocationSource(),
  );
}
