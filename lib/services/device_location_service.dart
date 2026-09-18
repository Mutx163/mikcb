import 'dart:async';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../models/weather_forecast.dart';
import 'app_log_service.dart';

/// 与 `android/app/src/main/kotlin/com/mutx163/qingyu/LocationFix.kt` 的 `CHANNEL`
/// 常量必须一致；改动要两边同批。
const String deviceLocationChannelName = 'com.mutx163.qingyu/location';

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

  /// 实时定位与网络估算都没拿到可用位置。
  timeout,

  /// 其它异常（含插件未在清单里声明权限等）。
  failed,

  /// 拿到了坐标，但反查不出地名。
  addressUnavailable,
}

/// 一次定位拿到的坐标。
///
/// 自定义而不是直接用 geolocator 的 `Position`：坐标有多个来源（原生通道 / geolocator
/// 兜底 / 原生内部缓存），用同一个轻量值类型收敛，测试里造假件也不必凑齐十个字段。
class DeviceFix {
  const DeviceFix({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.source,
  });

  final double latitude;
  final double longitude;

  /// 精度（米）；未知为 null。
  final double? accuracyMeters;

  /// `network` / `gps` / `cache` / `geolocator`——**只用于留痕**，不参与判定。
  final String? source;
}

/// 定位 + 反查的结果：坐标与失败原因必有一个为 null。
class DeviceLocationOutcome {
  const DeviceLocationOutcome.success(
    WeatherLocation this.location, {
    this.estimated = false,
  }) : failure = null;

  const DeviceLocationOutcome.failure(DeviceLocationFailure this.failure)
    : location = null,
      estimated = false;

  final WeatherLocation? location;
  final DeviceLocationFailure? failure;

  /// true 表示这是**按网络 IP 估算**出来的位置（可能指到运营商网关所在城市）。
  /// 界面必须明确标注，别让它冒充真实定位。
  final bool estimated;

  bool get isSuccess => location != null;
}

/// 设备定位能力的接缝。
///
/// 存在的唯一理由是**可测**：失败矩阵（系统开关没开 / 拒绝 / 永久拒绝 / 超时 /
/// 通道故障）没法通过真实平台通道覆盖，而这恰恰是最需要测的部分。
///
/// 刻意不替换 `GeolocatorPlatform.instance`：那要实现 geolocator 的整个平台接口
/// （几十个成员）才能跑一个用例，假件代码量远超被测逻辑，还会把测试绑到插件的
/// 内部类结构上。
abstract interface class DeviceLocationSource {
  Future<bool> isServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();

  /// 实时定位（原生通道：网络优先 + 总预算 + 内部缓存兜底）。拿不到返回 null。
  Future<DeviceFix?> getCurrentFix();
}

// ─────────────────────────────────────────────────────────────────────────────
// 真实实现
// ─────────────────────────────────────────────────────────────────────────────

/// 把「坐标 → 地名」这一步注入进来，好让本服务不直接依赖网络层。
typedef ReverseGeocode =
    Future<WeatherLocation?> Function(double latitude, double longitude);

/// 按网络出口 IP 估算所在地。
typedef NetworkGeocode = Future<WeatherLocation?> Function();

/// [DeviceLocationSource] 的真实实现。
///
/// 实时定位走**自建原生通道**：`geolocator_android` 在无可用 Google Play Services 的
/// 设备上会回退到系统 LocationManager，而它除「最低精度」外优先 GPS_PROVIDER，室内冷
/// 启动永远等不到；插件也没有提供选择 provider 的 API，所以调它的精度参数没用。
/// 原生通道网络优先，拿到够用的就收工。
///
/// 权限申请与系统开关仍用 geolocator——那部分真机验证过是好的，没必要重写。
class NativeDeviceLocationSource implements DeviceLocationSource {
  const NativeDeviceLocationSource();

  /// 原生通道的预算。与 `LocationFix.kt` 的 `DEFAULT_BUDGET_MS` 同量级；**显式传**
  /// 是为了避免两边默认值各改各的、悄悄漂移。
  static const Duration budget = Duration(seconds: 12);

  static const MethodChannel _channel = MethodChannel(
    deviceLocationChannelName,
  );

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<DeviceFix?> getCurrentFix() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'getCurrentPosition',
        {'budgetMs': budget.inMilliseconds},
      );
      // null 是「没拿到可用坐标」——正常结果，交给上层走网络估算。
      // **不要**在这里再兜一次 geolocator，否则预算翻倍（12 秒 + 12 秒）。
      if (raw == null) {
        return null;
      }
      final latitude = (raw['latitude'] as num?)?.toDouble();
      final longitude = (raw['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) {
        return null;
      }
      return DeviceFix(
        latitude: latitude,
        longitude: longitude,
        accuracyMeters: (raw['accuracy'] as num?)?.toDouble(),
        source: raw['source'] as String?,
      );
    } catch (error, stackTrace) {
      // 只有通道本身故障（未注册 / 平台不支持 / 解码失败）才兜底 geolocator，
      // 保证不会比「完全走插件」更差。
      unawaited(
        _recordWarn(
          'weather_location_channel_failed',
          'native channel unavailable, falling back to geolocator',
          error: error,
          stackTrace: stackTrace,
        ),
      );
      return _fromGeolocator();
    }
  }

  Future<DeviceFix?> _fromGeolocator() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: budget,
      ),
    );
    return DeviceFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      source: 'geolocator',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 服务
// ─────────────────────────────────────────────────────────────────────────────

/// 一次性获取当前位置并解析成可用的 [WeatherLocation]。
///
/// 顺序（这一版是**对上一版的纠正**）：
/// ```
/// 权限/开关 → 实时定位（原生通道：网络优先、12 秒总预算、内部缓存兜底）
///          → 网络 IP 估算（标注为估算）
///          → 才失败
/// ```
/// 上一版把「系统缓存」放在最前面当首选，方向错了：用户点「使用当前位置」要的是**现在**
/// 在哪，缓存只该在前面的实时定位拿不到时兜底——否则换了城市仍会停在旧定位。现在缓存
/// 策略在原生侧一处维护（见 `LocationFix.kt`）。
///
/// **任何失败都返回 [DeviceLocationOutcome.failure]，绝不外抛**——定位是用户主动触发的
/// 一次性动作，失败该给一句人话，而不是把异常抛进界面。
class DeviceLocationService {
  DeviceLocationService({
    required ReverseGeocode reverseGeocode,
    required NetworkGeocode networkGeocode,
    DeviceLocationSource? source,
  }) : this._(
         reverseGeocode,
         networkGeocode,
         source ?? const NativeDeviceLocationSource(),
       );

  DeviceLocationService._(
    this._reverseGeocode,
    this._networkGeocode,
    this._source,
  );

  final ReverseGeocode _reverseGeocode;
  final NetworkGeocode _networkGeocode;
  final DeviceLocationSource _source;

  Future<DeviceLocationOutcome> locate() async {
    final startedAt = DateTime.now();
    try {
      final permissionFailure = await _ensureUsablePermission();
      if (permissionFailure != null) {
        return _failed(
          permissionFailure,
          step: 'permission',
          startedAt: startedAt,
        );
      }

      final fix = await _source.getCurrentFix();
      final bool estimated;
      final WeatherLocation? location;
      if (fix != null) {
        estimated = false;
        location = await _reverseGeocode(fix.latitude, fix.longitude);
      } else {
        // 实时定位拿不到才估算。估算结果必须带标记，界面要如实告诉用户。
        estimated = true;
        location = await _networkGeocode();
      }

      if (location == null) {
        return _failed(
          // 没有任何坐标 → 超时；有坐标但没地名 → 反查失败。两种要给不同的话。
          fix == null
              ? DeviceLocationFailure.timeout
              : DeviceLocationFailure.addressUnavailable,
          step: fix == null ? 'position' : 'reverseGeocode',
          startedAt: startedAt,
        );
      }

      _logInfo('weather_location_ok', {
        'source': fix?.source ?? 'networkEstimate',
        'estimated': estimated,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'accuracyMeters': fix?.accuracyMeters,
      });
      return DeviceLocationOutcome.success(location, estimated: estimated);
    } on TimeoutException catch (error, stackTrace) {
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
  /// 这条纪律是被真机坑出来的——原先只在超时和未知异常时记日志，结果用户反馈
  /// 「定位半天没反应然后失败」时日志里一片空白，完全判不出卡在权限、服务开关、
  /// 取位置还是反查。事件名统一是 `weather_location_<失败原因>`，grep 一个前缀就能
  /// 看到完整故事。
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
  /// 不 await 是被测试逼出来的：`AppLogService` 的调用在 `testWidgets` 的 FakeAsync
  /// 里永远不会完成（实测探针：推进 2 秒假时间后仍未 completes），一旦 await 就会把
  /// 整条定位流程卡死——表现是「权限弹了、进度圈转了、然后永远没结果」。日志本该只
  /// 观测、不决定业务结果，所以写成 `unawaited` 才是正确形态，不只是为了测试好过。
  void _logWarn(
    String event,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> extra = const {},
  }) {
    unawaited(
      _recordWarn(
        event,
        message,
        error: error,
        stackTrace: stackTrace,
        extra: extra,
      ),
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

/// 与 [DeviceLocationService] 的留痕同样的「发出即走」原则；抽成文件级函数是为了让
/// [NativeDeviceLocationSource] 也能用（它是独立的类，拿不到私有方法）。
Future<void> _recordWarn(
  String event,
  String message, {
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> extra = const {},
}) {
  return AppLogService.instance
      .warn(event, message, error: error, stackTrace: stackTrace, extras: extra)
      .catchError((Object _) {});
}
