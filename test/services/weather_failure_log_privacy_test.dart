import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/weather_forecast.dart';
import 'package:university_timetable/services/app_log_service.dart';
import 'package:university_timetable/services/weather_service.dart';

/// 回归钉（第二十二轮，天气失败日志把 GPS 坐标写进可导出的日志）：
///
/// `WeatherService._getJson`（weather_service.dart:249-253）任何异常都
/// `_logFailure(tag, error, stackTrace)`，而 `_logFailure`（:258-267）把
/// **异常对象原样**交给 `AppLogService.warn(error: …)`；
/// `app_log_service.dart:549-551` 又是 `writeln('error=$error')`，
/// 落盘与导出都不做任何抹除（`_buildEntryPayload` 里没有任何 redact 调用，
/// 全仓唯一的 `redactPersonalFields` 只挂在 debugPrint 上）。
///
/// 异常文本里为什么一定带坐标：http 1.6.0 的
/// `ClientException.toString()`（src/exception.dart:15-21）返回
/// `'ClientException: $message, uri=$uri'`，`IOClient` 又把 SocketException
/// 包成 `_ClientSocketException(e, request.url)`（src/io_client.dart:27-44、:227），
/// 其 `toString()` 是 `'ClientException with $cause, uri=$uri'` —— 两条都拼上完整 URL，
/// 而 `fetchForecast`(:203-205) 与 `reverseGeocode`(:129-132) 的 URL 查询串就是
/// `latitude=&longitude=`。后者拿的是**设备定位**，也就是家/学校的精确坐标。
///
/// 后果：弱网或断网时每次天气刷新写一行精确坐标，而 `app_runtime.log` 正是
/// `exportMergedLogsFile`(:363) 让用户导出、发群、附在 issue 里的那份文件。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const tempCoordinates = '30.2936512';
  const tempCoordinatesEast = '120.1614213';

  late Directory tempDir;
  late MethodChannel pathProviderChannel;

  setUp(() async {
    AppLogService.instance.resetForTesting();
    tempDir = await Directory.systemTemp.createTemp('mikcb-weather-log-');
    pathProviderChannel = const MethodChannel(
      'plugins.flutter.io/path_provider',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => tempDir.path,
        );
    // 开关走真实读取路径：`_canWrite = _privacyAccepted && _loggingEnabled`
    // （app_log_service.dart:425）。不满足的话本用例只会"假绿"——
    // 什么都不写，自然也不含坐标。
    SharedPreferences.setMockInitialValues({
      'accepted_privacy_policy': true,
      'timetable_profiles':
          '[{"id":"p1","settings":{"liveEnableLocalDiagnostics":true}}]',
    });
    await AppLogService.instance.initialize();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 抛出一条**真实形状**的失败：http 会把请求 URL 拼进异常文本。
  WeatherService serviceThrowing(String url) => WeatherService(
    client: MockClient((request) async {
      throw http.ClientException(
        'Connection failed (OS Error: Network is unreachable, '
        'address = ${Uri.parse(url).host}, port = 443)',
        Uri.parse(url),
      );
    }),
  );

  Future<String> writtenLogs() => AppLogService.instance.readAppLogsText();

  test('预报请求失败时，落盘日志不留查询串里的坐标', () async {
    final forecast = await serviceThrowing(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$tempCoordinates&longitude=$tempCoordinatesEast'
      '&timezone=Asia%2FShanghai&hourly=temperature_2m'
      '&past_days=1&forecast_days=16',
    ).fetchForecast(
      const WeatherLocation(
        name: '杭州',
        admin1: '浙江',
        country: '中国',
        latitude: 30.2936512,
        longitude: 120.1614213,
        timezone: 'Asia/Shanghai',
      ),
    );

    expect(forecast, isNull);
    final logs = await writtenLogs();
    // 缝隙被命中的证据：这一行确实写进去了。
    expect(logs, contains('weather_forecast_failed'));
    expect(logs, contains('error='), reason: '失败日志必须仍然留痕');
    expect(logs, isNot(contains(tempCoordinates)));
    expect(logs, isNot(contains(tempCoordinatesEast)));
    expect(logs, isNot(contains('latitude=3')));
    expect(logs, contains('latitude=**'));
    // 丢坐标不等于丢诊断：域名与原因还得在。
    expect(logs, contains('api.open-meteo.com'));
    expect(logs, contains('Network is unreachable'));
  });

  test('设备定位反查失败时，落盘日志不留 GPS 坐标', () async {
    final location = await serviceThrowing(
      'https://api.bigdatacloud.net/data/reverse-geocode-client'
      '?latitude=$tempCoordinates&longitude=$tempCoordinatesEast'
      '&localityLanguage=zh-Hans',
    ).reverseGeocode(30.2936512, 120.1614213);

    expect(location, isNull);
    final logs = await writtenLogs();
    expect(logs, contains('weather_reverse_geocode_failed'));
    expect(logs, isNot(contains(tempCoordinates)));
    expect(logs, isNot(contains(tempCoordinatesEast)));
    expect(logs, isNot(contains('latitude=3')));
    expect(logs, contains('latitude=**'));
    expect(logs, contains('longitude=**'));
    expect(logs, contains('api.bigdatacloud.net'));
  });

  test('IP 估算路径本来就不带坐标，留痕不变', () async {
    final location = await serviceThrowing(
      'https://api.bigdatacloud.net/data/reverse-geocode-client'
      '?localityLanguage=zh-Hans',
    ).networkGeocode();

    expect(location, isNull);
    final logs = await writtenLogs();
    expect(logs, contains('weather_network_geocode_failed'));
    expect(
      logs,
      contains('reverse-geocode-client?localityLanguage=zh-Hans'),
      reason: '无坐标的请求不必抹掉 URL：诊断信息保持完整',
    );
  });
}
