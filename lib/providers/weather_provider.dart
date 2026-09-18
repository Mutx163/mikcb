import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/weather_logic.dart';
import '../models/weather_forecast.dart';
import '../services/weather_preferences.dart';
import '../services/weather_service.dart';

/// 天气数据的加载状态（仅设置页展示，卡片不显示任何错误态）。
enum WeatherStatus { idle, loading, ready, failed }

/// 天气状态：开关、所选城市、预报缓存与刷新策略。
///
/// **刻意独立于 [TimetableProvider]**：天气不属于课表领域，塞进去会顶破
/// `test/architecture/dependency_guards_test.dart` 里的行数棘轮，也会让上帝类
/// 拆分更难。挂在 `lib/main.dart` 的 `MultiProvider` 上（必须在 Navigator 之上，
/// 否则设置页与日视图会各拿一份实例，改了城市卡片不刷新）。
///
/// 不变式（卡片只读内存，永远不等网络）：
/// - 构造函数不发任何请求；网络只在 [initialize] / [ensureFresh] 里发生。
/// - [summaryForCourse] 是纯读，无副作用、不 await，可以在 build 里每帧调用。
/// - 失败**从不**向上抛：拿不到数据就返回 null，由调用方决定不渲染。
class WeatherProvider extends ChangeNotifier {
  WeatherProvider({WeatherService? service, DateTime Function()? clock})
    : _service = service ?? WeatherService(),
      _ownsService = service == null,
      _clock = clock ?? DateTime.now;

  /// 预报的保鲜期。Open-Meteo 逐小时更新，3 小时内取值变化用户无感；单城市 +
  /// 3 小时 → 一天最多 8 次请求，离免费额度 10000 次/天极远。
  static const Duration forecastTtl = Duration(hours: 3);

  /// 失败后的退避。日视图一屏有 5~8 张卡，每张都会请求一次「过期就刷」；
  /// 没有退避时服务器一挂，每次重建都会去撞一次。
  static const Duration failureRetryDelay = Duration(minutes: 15);

  final WeatherService _service;
  final bool _ownsService;
  final DateTime Function() _clock;

  bool _enabled = WeatherPreferences.defaultEnabled;
  WeatherLocation? _location;
  WeatherForecast? _forecast;
  WeatherStatus _status = WeatherStatus.idle;
  bool _initialized = false;
  Future<void>? _inFlight;
  DateTime? _nextRetryNotBefore;

  bool get enabled => _enabled;

  WeatherLocation? get location => _location;

  /// 当前内存里的预报（可能来自缓存、可能已过期）；没有则为 null。
  WeatherForecast? get forecast => _forecast;

  WeatherStatus get status => _status;

  /// 读本地配置进内存，然后后台补一次「过期就刷」。
  ///
  /// 幂等：重复调用直接返回。**不阻塞首帧**——读完就 notify，网络在后台跑。
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _enabled = await WeatherPreferences.isEnabled();
    _location = await WeatherPreferences.loadLocation();
    final cached = await WeatherPreferences.loadForecast();
    // 缓存的城市与所选城市不一致时必须丢弃：用户换过城市，拿旧城市的数冒充
    // 新城市是最坏的一种错。
    final location = _location;
    _forecast = (cached != null &&
            location != null &&
            cached.matchesLocation(location))
        ? cached
        : null;

    notifyListeners();
    unawaited(ensureFresh());
  }

  /// 过期就刷新。单飞 + TTL + 失败退避三重守卫，重复调用是廉价空转。
  ///
  /// 日视图每张卡挂载时都会调一次，因此这里必须是幂等的。
  /// [force] 为 true 时跳过 TTL 判定（设置页的「重试」用）。
  Future<void> ensureFresh({bool force = false}) {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }
    if (!force && !_shouldRefresh()) {
      return Future<void>.value();
    }
    if (_location == null) {
      return Future<void>.value();
    }
    final future = _refresh().whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  /// 手动重试：清掉失败退避并忽略 TTL，立刻拉一次。
  Future<void> retry() {
    _nextRetryNotBefore = null;
    return ensureFresh(force: true);
  }

  /// 开关。打开时才补拉数据（关着的时候一次请求都不该发）。
  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) {
      return;
    }
    _enabled = enabled;
    _nextRetryNotBefore = null;
    notifyListeners();
    await WeatherPreferences.setEnabled(enabled);
    if (enabled) {
      unawaited(ensureFresh());
    }
  }

  /// 选城市。换到不同地点时旧预报立即作废并落盘清除，随后立刻重拉。
  Future<void> setLocation(WeatherLocation location) async {
    final samePlace = _location?.isSamePlaceAs(location) ?? false;
    _location = location;
    _nextRetryNotBefore = null;
    if (!samePlace) {
      _forecast = null;
      _status = WeatherStatus.idle;
      await WeatherPreferences.clearForecast();
    }
    await WeatherPreferences.saveLocation(location);
    notifyListeners();
    unawaited(ensureFresh());
  }

  /// 这节课时段内的天气摘要；任何前提不满足都返回 null（调用方据此不渲染）。
  ///
  /// 纯读：不发起请求、不改状态，可以在 build 里安全调用。
  CourseWeatherSummary? summaryForCourse({
    required DateTime date,
    required String startTime,
    required String endTime,
  }) {
    if (!_enabled) {
      return null;
    }
    final forecast = _forecast;
    if (forecast == null) {
      return null;
    }
    final start = combineDateAndTime(date, startTime);
    final end = combineDateAndTime(date, endTime);
    if (start == null || end == null) {
      return null;
    }
    return summarizeCourseWeather(forecast: forecast, start: start, end: end);
  }

  /// 是否需要刷新。
  ///
  /// 四条失效条件：没有预报、城市对不上、窗口已走完（跨天）、超过 TTL。
  /// 外加失败退避：刚失败过就等一会儿再试。
  bool _shouldRefresh() {
    if (!_enabled || _location == null) {
      return false;
    }
    final now = _clock();
    final nextRetry = _nextRetryNotBefore;
    if (nextRetry != null && now.isBefore(nextRetry)) {
      return false;
    }
    final forecast = _forecast;
    if (forecast == null) {
      return true;
    }
    if (!forecast.matchesLocation(_location!)) {
      return true;
    }
    if (forecast.hasLapsedAt(now)) {
      return true;
    }
    return now.difference(forecast.fetchedAt) > forecastTtl;
  }

  Future<void> _refresh() async {
    final location = _location;
    if (location == null) {
      return;
    }
    _status = WeatherStatus.loading;
    notifyListeners();

    final forecast = await _service.fetchForecast(location);
    if (forecast == null) {
      // 失败降级：有旧缓存就继续用它（哪怕过期），卡片上不显示任何错误。
      _status = WeatherStatus.failed;
      _nextRetryNotBefore = _clock().add(failureRetryDelay);
    } else {
      _forecast = forecast;
      _status = WeatherStatus.ready;
      _nextRetryNotBefore = null;
      await WeatherPreferences.saveForecast(forecast);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }
}
