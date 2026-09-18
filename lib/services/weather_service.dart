import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/weather_forecast.dart';
import 'app_http_client.dart';
import 'app_log_service.dart';

/// Open-Meteo 天气数据访问（预报 + 地理编码）。
///
/// Open-Meteo 免费开放、**不需要密钥**，免费额度 10000 次/天、600 次/分，
/// 数据许可 CC BY 4.0（要求署名，见设置子页的 attribution）。
///
/// 本服务只负责发请求与解析成模型，不做缓存、不做节流、不判过期——那些策略在
/// [WeatherProvider] 里。失败一律返回 null / 空列表并留日志，绝不向上抛：
/// 天气是课卡的装饰性信息，任何故障都不该让界面报错。
class WeatherService {
  WeatherService({http.Client? client, Duration? timeout})
    : this._internal(
        client ?? createAppHttpClient(),
        client == null,
        timeout ?? requestTimeout,
      );

  WeatherService._internal(this._client, bool ownsCandidate, this._timeout)
    : _ownsClient = ownsCandidate && !isSharedAppHttpClient(_client);

  static const String _forecastBaseUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String _geocodingBaseUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  /// 请求的逐小时变量。**字段名即接口契约**，改动前先看 domain 的聚合算法注释。
  static const String hourlyVariables =
      'temperature_2m,precipitation_probability,precipitation,snowfall,weather_code';

  /// 实测首字节约 2.1 秒（服务器在欧美），10 秒留了约 5 倍余量。
  static const Duration requestTimeout = Duration(seconds: 10);

  /// 回溯 1 天：当天已经上完的课也能显示天气。
  static const int pastDays = 1;

  /// 预报窗口 16 天（接口上限）。日视图能翻到第 20 周，超出窗口时静默不显示。
  static const int forecastDays = 16;

  final http.Client _client;
  final bool _ownsClient;
  final Duration _timeout;

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'User-Agent': 'mikcb-weather',
  };

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// 按关键字搜索地点。
  ///
  /// 名字不足 2 个字符时接口只会返回空结果，这里直接短路省一次请求。
  /// 失败返回空列表。
  Future<List<WeatherLocation>> searchLocations(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      return const <WeatherLocation>[];
    }

    final uri = Uri.parse(_geocodingBaseUrl).replace(
      queryParameters: {
        'name': trimmed,
        'count': '10',
        'language': 'zh',
        'format': 'json',
      },
    );

    final json = await _getJson(uri, 'weather_geocoding');
    if (json == null) {
      return const <WeatherLocation>[];
    }
    final results = json['results'];
    if (results is! List) {
      return const <WeatherLocation>[];
    }

    final locations = <WeatherLocation>[];
    for (final item in results) {
      if (item is! Map) {
        continue;
      }
      try {
        locations.add(WeatherLocation.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // 单条畸形结果跳过，不影响其余候选。
        continue;
      }
    }
    return locations;
  }

  /// 拉取 [location] 的逐小时预报；失败或没有有效数据时返回 null。
  Future<WeatherForecast?> fetchForecast(WeatherLocation location) async {
    final uri = Uri.parse(_forecastBaseUrl).replace(
      queryParameters: {
        'latitude': '${location.latitude}',
        'longitude': '${location.longitude}',
        // 显式用城市自己的时区，别让服务端按请求 IP 猜：返回的 hourly.time 是
        // 不带偏移量的墙钟串，与课程时间同为墙钟语义，直接比较即可。
        'timezone': location.timezone ?? 'auto',
        'hourly': hourlyVariables,
        'past_days': '$pastDays',
        'forecast_days': '$forecastDays',
      },
    );

    final json = await _getJson(uri, 'weather_forecast');
    if (json == null) {
      return null;
    }
    try {
      final forecast = WeatherForecast.fromOpenMeteoResponse(
        json,
        fetchedAt: DateTime.now(),
      );
      return forecast.hourly.isEmpty ? null : forecast;
    } catch (error, stackTrace) {
      await _logFailure('weather_forecast_parse_failed', error, stackTrace);
      return null;
    }
  }

  /// GET 一个 JSON 对象；任何失败都返回 null 并留痕。
  Future<Map<String, dynamic>?> _getJson(Uri uri, String logTag) async {
    try {
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode != 200) {
        await _logMessage(
          '${logTag}_status',
          'weather request returned ${response.statusCode}',
        );
        return null;
      }
      // 显式按 UTF-8 解码而不是用 response.body：中文城市名（如「杭州」）一旦
      // 落在 latin1 兜底解码上就会变成乱码，而 charset 声明是服务端可选的。
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (error, stackTrace) {
      await _logFailure('${logTag}_failed', error, stackTrace);
      return null;
    }
  }

  Future<void> _logFailure(
    String event,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      await AppLogService.instance.warn(
        event,
        'weather request failed',
        error: error,
        stackTrace: stackTrace,
      );
    } catch (_) {
      // 日志通道不可用时不外抛：与 holiday_service 的失败路径一致。
    }
  }

  Future<void> _logMessage(String event, String message) async {
    try {
      await AppLogService.instance.warn(event, message);
    } catch (_) {
      // 同上。
    }
  }
}
