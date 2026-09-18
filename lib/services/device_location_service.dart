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

  /// 系统缓存的上一次位置；没有则 null。毫秒级返回，不触发新的定位。
  Future<Position?> getLastKnownPosition();

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
  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

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

  /// 取实时位置时的精度与上限。
  ///
  /// 精度**不改变 provider 选择**（实测 geolocator_android 的
  /// `LocationManagerClient.determineProvider`：只有 `lowest` 会换成
  /// PASSIVE_PROVIDER，其余一律优先 fused → GPS → NETWORK），所以别指望调低精度
  /// 能让室内更快拿到。真正解决室内等待的是 [lastKnownMaxAge] 那条缓存快路。
  ///
  /// 25 秒是冷启动 GPS 的余量；用户选了「精确位置」，所以请求 high。
  static const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 25),
  );

  /// 系统缓存位置的可接受年龄。
  ///
  /// 超过这个年龄就不再信任它（可能已经是另一个城市了），改为等实时定位。
  /// 天气按区级算，半小时内的缓存完全够用。
  static const Duration lastKnownMaxAge = Duration(minutes: 30);

  final ReverseGeocode _reverseGeocode;
  final DeviceLocationSource _source;

  Future<DeviceLocationOutcome> locate() async {
    final startedAt = DateTime.now();
    try {
      final permissionFailure = await _ensureUsablePermission();
      if (permissionFailure != null) {
        return _failed(permissionFailure, step: 'permission', startedAt: startedAt);
      }

      final cached = await _tryLastKnownPosition();
      final String positionSource;
      final Position position;
      if (cached != null) {
        positionSource = 'lastKnown';
        position = cached;
      } else {
        positionSource = 'current';
        position = await _source.getCurrentPosition(locationSettings);
      }

      final location = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (location == null) {
        return _failed(
          DeviceLocationFailure.addressUnavailable,
          step: 'reverseGeocode',
          startedAt: startedAt,
          extra: {'positionSource': positionSource},
        );
      }

      _logInfo('weather_location_ok', {
        'positionSource': positionSource,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'accuracyMeters': position.accuracy,
      });
      return DeviceLocationOutcome.success(location);    } on TimeoutException catch (error, stackTrace) {
      // 只有取位置会抛到这里：反查内部自己吞掉超时并返回 null（走
      // addressUnavailable），所以「已经拿到坐标但地名没解析出来」不会被
      // 误报成定位超时。
      return _failed(
        DeviceLocationFailure.timeout,
        step: 'position',
        startedAt: startedAt,
        error: error,
        stackTrace: stackTrace,
      );
    } catch (error, stackTrace) {
      return _failed(
        DeviceLocationFailure.failed,
        step: 'unknown',
        startedAt: startedAt,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 先试系统缓存的上一次位置。
  ///
  /// 这条快路是**真机踩出来的**：设备没有可用的 Google Play Services 时，插件回退
  /// 到系统 LocationManager，而它在 `determineProvider` 里除 `lowest` 之外**优先选
  /// GPS_PROVIDER**——室内冷启动等不到定位，只能超时失败（用户反馈：「允许了精确
  /// 位置，定位半天没反应然后失败」）。系统缓存里通常有一份网络定位结果，毫秒级
  /// 返回；天气按区级算，[lastKnownMaxAge] 内的缓存完全够用。
  ///
  /// 任何异常都吞掉返回 null，绝不影响后面等实时定位。
  Future<Position?> _tryLastKnownPosition() async {
    try {
      final cached = await _source.getLastKnownPosition();
      if (cached == null) {
        _logInfo('weather_location_last_known_empty', const {});
        return null;
      }
      final age = DateTime.now().difference(cached.timestamp);
      if (age > lastKnownMaxAge) {
        _logInfo('weather_location_last_known_stale', {
          'ageMinutes': age.inMinutes,
        });
        return null;
      }
      return cached;
    } catch (error, stackTrace) {
      _logWarn(
        'weather_location_last_known_failed',
        'last known position unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
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

  /// 失败出口：**每个分支都留一条日志**。
  ///
  /// 这条纪律也是被真机坑出来的——原先只在超时和未知异常时记日志，结果用户反馈
  /// 「定位半天没反应然后失败」时，日志里一片空白，完全判不出卡在权限、服务开关
  /// 还是取位置。事件名统一是 `weather_location_<失败原因>`，grep 一个前缀就能看到
  /// 完整故事。
  DeviceLocationOutcome _failed(
    DeviceLocationFailure failure, {
    required String step,
    required DateTime startedAt,
    Map<String, Object?> extra = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logWarn(
      'weather_location_${failure.name}',
      'failed at $step',
      error: error,
      stackTrace: stackTrace,
      extra: {
        'step': step,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        ...extra,
      },
    );
    return DeviceLocationOutcome.failure(failure);
  }

  /// 留痕。**发出即走，绝不 await**。
  ///
  /// 不 await 是被测试逼出来的：`AppLogService` 的调用在 `testWidgets` 的
  /// FakeAsync 里永远不会完成（实测探针：2 秒推进后仍未 completes），一旦 await
  /// 就会把整条定位流程卡死——表现是「权限弹了、进度圈转了、然后永远没结果」，
  /// 而这不是 AppLogService 的 bug，是「日志不该决定业务结果」这条原则在测试里
  /// 被放大了。日志失败或悬挂都不影响定位返回值。
  void _logWarn(
    String event,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extra = const {},
  }) {
    unawaited(
      AppLogService.instance
          .warn(
            event,
            message,
            error: error,
            stackTrace: stackTrace,
            extras: extra,
          )
          .catchError((Object _) {}),
    );
  }

  void _logInfo(String event, Map<String, Object?> extra) {
    unawaited(
      AppLogService.instance
          .info(event, event, extras: extra)
          .catchError((Object _) {}),
    );
  }
}
