import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/weather_forecast.dart';
import 'app_log_service.dart';

/// 定位失败的原因。每一条都对应一句用户可见的引导文案（见 l10n 的
/// `weatherLocation*` 系列）。
enum DeviceLocationFailure {
  /// 系统定位开关没开。
  serviceDisabled,

  /// 权限被拒，但还能再次弹框申请。
  permissionDenied,

  /// 权限被永久拒绝，系统不再弹框，只能去系统设置里改。
  ///
  /// 注意：这是 [LocationPermission] 的**枚举值**，不是异常——geolocator 14 里
  /// 没有 `PermissionDeniedForeverException`，别写成 catch。
  permissionDeniedForever,

  /// 取位置超时。
  timeout,

  /// 其它异常（含插件未在清单里声明权限等）。
  failed,

  /// 拿到了坐标，但反查不出地名。
  addressUnavailable,
}

/// 定位 + 反查的结果：二者必有一个为 null。
class DeviceLocationOutcome {
  const DeviceLocationOutcome.success(WeatherLocation this.location)
    : failure = null;

  const DeviceLocationOutcome.failure(DeviceLocationFailure this.failure)
    : location = null;

  final WeatherLocation? location;
  final DeviceLocationFailure? failure;

  bool get isSuccess => location != null;
}

/// 设备定位能力的接缝。
///
/// 存在的唯一理由是**可测**：失败矩阵（系统开关没开 / 拒绝 / 永久拒绝 / 超时 /
/// 插件抛异常）没法通过真实平台通道覆盖，而这恰恰是最需要测的部分。真实实现
/// [GeolocatorDeviceLocationSource] 只做转发。
///
/// 刻意不替换 `GeolocatorPlatform.instance`：那要实现 geolocator 的整个平台接口
/// （几十个成员）才能跑一个用例，假件代码量远超被测逻辑，还会把测试绑到插件的
/// 内部类结构上。
abstract interface class DeviceLocationSource {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition(LocationSettings settings);
}

/// [DeviceLocationSource] 的真实实现：转发给 geolocator 插件。
///
/// Android 端不必设 `forceLocationManager`：插件会自己检测设备是否装了
/// Google Play Services，没装就回退到系统 LocationManager——国行设备因此可用。
class GeolocatorDeviceLocationSource implements DeviceLocationSource {
  const GeolocatorDeviceLocationSource();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition(LocationSettings settings) =>
      Geolocator.getCurrentPosition(locationSettings: settings);
}

/// 把「坐标 → 地名」这一步注入进来，好让本服务不直接依赖网络层。
typedef ReverseGeocode =
    Future<WeatherLocation?> Function(double latitude, double longitude);

/// 一次性获取当前位置并解析成可用的 [WeatherLocation]。
///
/// 流程：系统定位开关 → 权限（必要时弹框申请）→ 取一次坐标 → 反查地名。
/// **任何失败都返回 [DeviceLocationOutcome.failure]，绝不外抛**——定位是用户主动
/// 触发的一次性动作，失败该给一句人话提示，而不是把异常抛进界面。
class DeviceLocationService {
  DeviceLocationService({
    required ReverseGeocode reverseGeocode,
    DeviceLocationSource? source,
  }) : this._(
         reverseGeocode,
         source ?? const GeolocatorDeviceLocationSource(),
       );

  DeviceLocationService._(this._reverseGeocode, this._source);

  /// 定位精度与超时。用户选了「精确位置」，所以走 high；15 秒是给室内首次
  /// 冷启动留的余量（高精度室内常要十几秒），再久就该提示去开阔处了。
  static const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 15),
  );

  final ReverseGeocode _reverseGeocode;
  final DeviceLocationSource _source;

  Future<DeviceLocationOutcome> locate() async {
    try {
      final permissionFailure = await _ensureUsablePermission();
      if (permissionFailure != null) {
        return DeviceLocationOutcome.failure(permissionFailure);
      }

      final position = await _source.getCurrentPosition(locationSettings);

      final location = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (location == null) {
        return const DeviceLocationOutcome.failure(
          DeviceLocationFailure.addressUnavailable,
        );
      }
      return DeviceLocationOutcome.success(location);
    } on TimeoutException catch (error, stackTrace) {
      // 只有取位置会抛到这里：反查内部自己吞掉超时并返回 null（走
      // addressUnavailable），所以「已经拿到坐标但地名没解析出来」不会被
      // 误报成定位超时。
      unawaited(_log('weather_location_timeout', error, stackTrace));
      return const DeviceLocationOutcome.failure(DeviceLocationFailure.timeout);
    } catch (error, stackTrace) {
      unawaited(_log('weather_location_failed', error, stackTrace));
      return const DeviceLocationOutcome.failure(DeviceLocationFailure.failed);
    }
  }

  /// 定位服务可用且权限已授予时返回 null；否则返回对应的失败原因。
  Future<DeviceLocationFailure?> _ensureUsablePermission() async {
    if (!await _source.isServiceEnabled()) {
      return DeviceLocationFailure.serviceDisabled;
    }

    var permission = await _source.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _source.requestPermission();
    }

    return switch (permission) {
      LocationPermission.denied => DeviceLocationFailure.permissionDenied,
      LocationPermission.deniedForever =>
        DeviceLocationFailure.permissionDeniedForever,
      // 只在 web 上出现。当作失败，**绝不能当成「已授权」**——那样会走到取位置
      // 分支去拿一个必然失败的结果。
      LocationPermission.unableToDetermine => DeviceLocationFailure.failed,
      LocationPermission.whileInUse || LocationPermission.always => null,
    };
  }

  /// 留痕。日志通道自身失败也不外抛，与本项目其它服务的失败路径一致。
  Future<void> _log(String event, Object error, StackTrace stackTrace) async {
    try {
      await AppLogService.instance.warn(
        event,
        'device location failed',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (_) {
      // 忽略：日志不可用不该把定位结果带偏。
    }
  }
}
