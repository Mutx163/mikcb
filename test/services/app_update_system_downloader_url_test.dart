import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:university_timetable/models/settings/timetable_settings_enums.dart';
import 'package:university_timetable/services/app_update_service.dart';

const String _githubApkUrl =
    'https://github.com/Mutx163/mikcb/releases/download/v2.1.4/'
    'mikcb-2.1.4-arm64-v8a.apk';

AppReleaseInfo _release({
  String? downloadUrl = _githubApkUrl,
  String? gitcodeDownloadUrl,
  String? pgyerDownloadUrl,
  String version = '2.1.4',
}) {
  return AppReleaseInfo(
    version: version,
    title: 'title',
    body: 'body',
    releaseUrl: 'https://github.com/Mutx163/mikcb/releases/tag/v$version',
    downloadUrl: downloadUrl,
    gitcodeDownloadUrl: gitcodeDownloadUrl,
    pgyerDownloadUrl: pgyerDownloadUrl,
    updatedAt: DateTime.utc(2026, 10, 20),
    isPrerelease: false,
  );
}

void main() {
  late AppUpdateService service;

  setUp(() {
    service = AppUpdateService(
      client: MockClient((request) async {
        fail('getSystemDownloaderUrl 是纯取值方法，不应发起网络请求: ${request.url}');
      }),
    );
  });

  group('getSystemDownloaderUrl（系统下载器只走官方直连，2026-10-20）', () {
    test('默认镜像设置下清单链接是 ghfast 外壳，系统下载器 URL 仍是 github 直连', () {
      final release = _release();

      // 先钉住「默认设置确实会产出镜像外壳」——这正是原缺陷的触发条件
      // （timetable_settings.dart 默认 source=mirror、预设 ghfast）。
      final effective = service.getEffectiveDownloadUrl(
        release: release,
        channel: AppUpdateDownloadChannel.github,
        source: AppUpdateDownloadSource.mirror,
        mirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
      );
      expect(effective, contains('ghfast.top'));

      final direct = service.getSystemDownloaderUrl(
        release: release,
        channel: AppUpdateDownloadChannel.github,
      );
      expect(direct, _githubApkUrl);
      expect(Uri.parse(direct!).host, 'github.com');
      expect(Uri.parse(direct).scheme, 'https');
      expect(direct, isNot(contains('ghfast')));
      expect(direct, isNot(contains('http://ghfast')));
    });

    test('gitcode 渠道优先发行版附件直链，缺失时按版本构造', () {
      const gitcodeApk =
          'https://gitcode.com/mutx/qingyu/releases/download/v2.1.4/'
          'mikcb-2.1.4-arm64-v8a.apk';

      expect(
        service.getSystemDownloaderUrl(
          release: _release(gitcodeDownloadUrl: gitcodeApk),
          channel: AppUpdateDownloadChannel.gitcode,
        ),
        gitcodeApk,
      );

      final constructed = service.getSystemDownloaderUrl(
        release: _release(),
        channel: AppUpdateDownloadChannel.gitcode,
      );
      expect(constructed, isNotNull);
      expect(Uri.parse(constructed!).host, 'gitcode.com');
      expect(constructed, contains('v2.1.4'));
      expect(constructed, contains('mikcb-2.1.4-arm64-v8a.apk'));
    });

    test('pgyer 渠道优先接口给的页面地址，缺失时回落固定页面', () {
      expect(
        service.getSystemDownloaderUrl(
          release: _release(pgyerDownloadUrl: 'https://www.pgyer.com/abc123'),
          channel: AppUpdateDownloadChannel.pgyer,
        ),
        'https://www.pgyer.com/abc123',
      );
      expect(
        service.getSystemDownloaderUrl(
          release: _release(),
          channel: AppUpdateDownloadChannel.pgyer,
        ),
        'https://www.pgyer.com/qingyu',
      );
    });

    test('github 渠道缺下载链接（null / 空白）时返回 null，不回退镜像', () {
      expect(
        service.getSystemDownloaderUrl(
          release: _release(downloadUrl: null),
          channel: AppUpdateDownloadChannel.github,
        ),
        isNull,
      );
      expect(
        service.getSystemDownloaderUrl(
          release: _release(downloadUrl: '   '),
          channel: AppUpdateDownloadChannel.github,
        ),
        isNull,
      );
      expect(
        service.getSystemDownloaderUrl(
          release: null,
          channel: AppUpdateDownloadChannel.github,
        ),
        isNull,
      );
    });
  });
}
