import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/webdav_client_service.dart';
import 'package:university_timetable/services/webdav_sync_config.dart';
import 'package:university_timetable/services/webdav_sync_service.dart';

/// 记录参数、不发网络请求的客户端替身：门禁必须在**进入网络层之前**生效，
/// 所以「有没有被调用」本身就是断言的一部分。
class _RecordingClientService extends WebdavClientService {
  _RecordingClientService();

  WebdavConnectionParams? lastParams;

  @override
  Future<void> testConnection(WebdavConnectionParams params) async {
    lastParams = params;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseConfig = WebdavSyncConfig(
    username: 'someone@example.com',
    baseUrl: 'https://dav.example.com/dav/',
  );

  WebdavSyncService buildService(_RecordingClientService client) {
    return WebdavSyncService(clientService: client);
  }

  group('WebdavSyncService.testConnection scheme 门禁（2026-10-20 补漏）', () {
    test('https 地址直接放行，参数原样传到客户端', () async {
      final client = _RecordingClientService();
      await buildService(client).testConnection(
        config: baseConfig,
        passwordOverride: 'secret',
      );
      expect(client.lastParams, isNotNull);
      expect(client.lastParams!.baseUrl, 'https://dav.example.com/dav/');
      expect(client.lastParams!.username, 'someone@example.com');
    });

    test('http 默认拒绝，且请求不会到达客户端（明文 Basic Auth 不外发）', () async {
      final client = _RecordingClientService();
      await expectLater(
        buildService(client).testConnection(
          config: baseConfig.copyWith(baseUrl: 'http://192.168.1.8:5005/dav/'),
          passwordOverride: 'secret',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'webdav_insecure_http_unconfirmed',
          ),
        ),
      );
      expect(client.lastParams, isNull);
    });

    test('http + 用户已确认（allowInsecureHttp）放行', () async {
      final client = _RecordingClientService();
      await buildService(client).testConnection(
        config: baseConfig.copyWith(baseUrl: 'http://192.168.1.8:5005/dav/'),
        passwordOverride: 'secret',
        allowInsecureHttp: true,
      );
      expect(client.lastParams, isNotNull);
      expect(client.lastParams!.baseUrl, 'http://192.168.1.8:5005/dav/');
    });

    test('非 http(s) 一律按 invalid 拒绝，allow 也不能放行', () async {
      final client = _RecordingClientService();
      await expectLater(
        buildService(client).testConnection(
          config: baseConfig.copyWith(baseUrl: 'ftp://files.example.com/dav'),
          passwordOverride: 'secret',
          allowInsecureHttp: true,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'webdav_invalid_base_url',
          ),
        ),
      );
      expect(client.lastParams, isNull);
    });

    test('空 baseUrl 按默认坚果云 https 处理，不触发明文确认', () async {
      final client = _RecordingClientService();
      await buildService(client).testConnection(
        config: baseConfig.copyWith(baseUrl: '   '),
        passwordOverride: 'secret',
      );
      expect(
        client.lastParams!.baseUrl,
        WebdavSyncConfig.defaultJianguoyunBaseUrl,
      );
    });
  });
}
