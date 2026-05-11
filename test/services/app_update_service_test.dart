import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_update_service.dart';
import 'package:university_timetable/services/pgyer_api_service.dart';

class _CountingProbeClient extends http.BaseClient {
  final int totalBytes;
  int streamedBytes = 0;
  Map<String, String>? lastGetHeaders;

  _CountingProbeClient({
    required this.totalBytes,
  });

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'HEAD') {
      return http.StreamedResponse(
        Stream<List<int>>.empty(),
        405,
        request: request,
      );
    }
    if (request.method == 'GET') {
      lastGetHeaders = Map<String, String>.from(request.headers);
      return http.StreamedResponse(_streamBody(), 200, request: request);
    }
    throw UnsupportedError('Unexpected method: ${request.method}');
  }

  Stream<List<int>> _streamBody() async* {
    const chunkSize = 1024 * 1024;
    var remaining = totalBytes;
    while (remaining > 0) {
      final size = remaining > chunkSize ? chunkSize : remaining;
      streamedBytes += size;
      yield Uint8List(size);
      remaining -= size;
      await Future<void>.delayed(Duration.zero);
    }
  }
}

class _FakePgyerApiService extends PgyerApiService {
  final PgyerAppInfo? appInfo;
  var checkCount = 0;

  _FakePgyerApiService(this.appInfo) : super(config: null);

  @override
  Future<PgyerAppInfo?> checkForUpdate() async {
    checkCount += 1;
    return appInfo;
  }
}

void main() {
  test('github api lookup is used after releases page misses', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.1.11',
              'name': 'v1.1.11',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.1.11',
              'assets': const [
                {
                  'name': 'mikcb-1.1.11-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.11.apk',
                },
              ],
              'updated_at': '2026-04-20T09:00:00Z',
            },
          ]),
          200,
        );
      }
      fail('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(currentVersion: '1.1.10');

    expect(result.hasRelease, isTrue);
    expect(result.latestRelease?.version, '1.1.11');
    expect(requestedPaths, [
      '/Mutx163/mikcb/releases',
      '/repos/Mutx163/mikcb/releases',
    ]);
  });

  test('include prerelease picks highest version even if not first in list',
      () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.1.9.3',
              'name': 'v1.1.9.3',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.1.9.3',
              'assets': const [
                {
                  'name': 'mikcb-1.1.9.3-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.9.3.apk',
                },
              ],
              'updated_at': '2026-03-26T10:00:00Z',
            },
            {
              'tag_name': 'v1.1.9.4',
              'name': 'v1.1.9.4',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.9.4',
              'assets': const [
                {
                  'name': 'mikcb-1.1.9.4-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.9.4.apk',
                },
              ],
              'updated_at': '2026-03-26T11:00:00Z',
            },
          ]),
          200,
        );
      }
      throw UnsupportedError('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.9.3',
      includePrerelease: true,
    );

    expect(result.hasRelease, isTrue);
    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.1.9.4');
    expect(result.latestRelease?.isPrerelease, isTrue);
  });

  test('dotted tag suffix matches pubspec prerelease format', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.1.10.3',
              'name': 'v1.1.10.3',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.1.10.3',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10.3-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.3.apk',
                },
              ],
              'updated_at': '2026-03-30T10:00:00Z',
            },
          ]),
          200,
        );
      }
      throw UnsupportedError('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.10-3+33',
    );

    expect(result.hasRelease, isTrue);
    expect(result.hasUpdate, isFalse);
    expect(result.latestRelease?.version, '1.1.10.3');
  });

  test('include prerelease keeps numbered prerelease above base release',
      () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.1.10',
              'name': 'v1.1.10',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.1.10',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.apk',
                },
              ],
              'updated_at': '2026-03-29T09:00:00Z',
            },
            {
              'tag_name': 'v1.1.10.4',
              'name': 'v1.1.10.4',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.10.4',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10.4-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.4.apk',
                },
              ],
              'updated_at': '2026-03-31T09:00:00Z',
            },
          ]),
          200,
        );
      }
      throw UnsupportedError('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.10-4+34',
      includePrerelease: true,
    );

    expect(result.hasRelease, isTrue);
    expect(result.hasUpdate, isFalse);
    expect(result.latestRelease?.version, '1.1.10.4');
    expect(result.latestRelease?.isPrerelease, isTrue);
  });

  test('numbered prerelease still upgrades from base release when enabled',
      () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.1.10',
              'name': 'v1.1.10',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.1.10',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.apk',
                },
              ],
              'updated_at': '2026-03-29T09:00:00Z',
            },
            {
              'tag_name': 'v1.1.10.4',
              'name': 'v1.1.10.4',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.10.4',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10.4-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.4.apk',
                },
              ],
              'updated_at': '2026-03-31T09:00:00Z',
            },
          ]),
          200,
        );
      }
      throw UnsupportedError('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.10',
      includePrerelease: true,
    );

    expect(result.hasRelease, isTrue);
    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.1.10.4');
  });

  test('include prerelease skips higher versions without apk assets', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.1.10.20',
              'name': 'v1.1.10.20',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.1.10.20',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10.20-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.20.apk',
                },
              ],
              'updated_at': '2026-04-06T10:00:00Z',
            },
            {
              'tag_name': 'v1.1.10.24',
              'name': 'v1.1.10.24',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.10.24',
              'assets': const [],
              'updated_at': '2026-04-09T10:00:00Z',
            },
            {
              'tag_name': 'v1.1.10.23',
              'name': 'v1.1.10.23',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.10.23',
              'assets': const [
                {
                  'name': 'mikcb-1.1.10.23-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.1.10.23.apk',
                },
              ],
              'updated_at': '2026-04-08T10:00:00Z',
            },
          ]),
          200,
        );
      }
      throw UnsupportedError('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.10.20',
      includePrerelease: true,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.1.10.23');
    expect(
        result.latestRelease?.downloadUrl, 'https://example.com/1.1.10.23.apk');
  });

  test('stable update skips newer release entries without apk assets',
      () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.2.1',
              'name': 'v1.2.1',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.2.1',
              'assets': const [],
              'updated_at': '2026-04-09T10:00:00Z',
            },
            {
              'tag_name': 'v1.2.0',
              'name': 'v1.2.0',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.2.0',
              'assets': const [
                {
                  'name': 'mikcb-1.2.0-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.2.0.apk',
                },
              ],
              'updated_at': '2026-04-08T10:00:00Z',
            },
          ]),
          200,
        );
      }
      throw UnsupportedError('Unexpected url: ${request.url}');
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.9',
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.2.0');
    expect(result.latestRelease?.downloadUrl, 'https://example.com/1.2.0.apk');
  });

  test('download can be cancelled and cleans up partial apk', () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb_update_test_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    unawaited(() async {
      await for (final request in server) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.binary;
        request.response.headers.contentLength = 12;
        request.response.add(List<int>.filled(4, 1));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        request.response.add(List<int>.filled(4, 2));
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 40));
        request.response.add(List<int>.filled(4, 3));
        await request.response.close();
      }
    }());

    final controller = AppUpdateDownloadController();
    final progressEvents = <int>[];
    final service = AppUpdateService(
      temporaryDirectoryProvider: () async => tempDir,
      openInstaller: (path) async {
        fail('cancelled download should not try to open installer');
      },
    );

    final downloadFuture = service.downloadAndInstallUpdate(
      'http://${server.address.host}:${server.port}/app.apk',
      (downloadedBytes, totalBytes) {
        progressEvents.add(downloadedBytes);
        if (downloadedBytes >= 4) {
          controller.cancel();
        }
      },
      controller,
    );

    final result = await downloadFuture;
    final apkFile = File('${tempDir.path}/mikcb_update.apk');

    expect(result, AppUpdateService.downloadCancelledMessage);
    expect(progressEvents, isNotEmpty);
    expect(await apkFile.exists(), isFalse);

    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('download clears stale managed installer apk files before writing',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb_update_test_');
    final staleApk = File('${tempDir.path}/mikcb_update_old.apk');
    await staleApk.writeAsString('stale');
    final staleCurrentApk = File('${tempDir.path}/mikcb_update.apk');
    await staleCurrentApk.writeAsString('old-current');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(() async {
      await for (final request in server) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.binary;
        request.response.add(List<int>.filled(6, 7));
        await request.response.close();
      }
    }());

    String? openedPath;
    final service = AppUpdateService(
      temporaryDirectoryProvider: () async => tempDir,
      openInstaller: (path) async {
        openedPath = path;
        return OpenResult(type: ResultType.done);
      },
    );

    final result = await service.downloadAndInstallUpdate(
      'http://${server.address.host}:${server.port}/app.apk',
      (_, __) {},
      null,
    );

    expect(result, isNull);
    expect(openedPath, '${tempDir.path}/mikcb_update.apk');
    expect(await staleApk.exists(), isFalse);
    expect(await staleCurrentApk.exists(), isTrue);
    expect(await staleCurrentApk.length(), 6);

    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('probe download falls back to range get when head is rejected',
      () async {
    final client = MockClient((request) async {
      if (request.method == 'HEAD') {
        return http.Response('', 405);
      }
      if (request.method == 'GET') {
        expect(request.headers['Range'], 'bytes=0-0');
        return http.Response('', 206);
      }
      throw UnsupportedError('Unexpected method: ${request.method}');
    });

    final service = AppUpdateService(client: client);
    final result =
        await service.probeDownloadUrl('https://example.com/app.apk');

    expect(result.isSuccess, isTrue);
    expect(result.statusCode, 206);
  });

  test('probe download does not buffer the full body when range is ignored',
      () async {
    final client = _CountingProbeClient(totalBytes: 3 * 1024 * 1024);
    final service = AppUpdateService(client: client);

    final result =
        await service.probeDownloadUrl('https://example.com/app.apk');

    expect(result.isSuccess, isTrue);
    expect(result.statusCode, 200);
    expect(client.lastGetHeaders?['Range'], 'bytes=0-0');
    expect(client.streamedBytes, lessThan(client.totalBytes));
  });

  test('github api falls back to mirrored api when direct api is unavailable',
      () async {
    final requests = <String>[];
    final selectedMirror = 'https://mirror.example/';
    final mirroredApiUrl = '$selectedMirror${AppUpdateService.releasesApiUrl}';
    final client = MockClient((request) async {
      requests.add(request.url.toString());
      final url = request.url.toString();
      if (url == AppUpdateService.releasesApiUrl) {
        return http.Response('', 503);
      }
      if (url == mirroredApiUrl) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.3.0',
              'name': 'v1.3.0',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.3.0',
              'assets': const [
                {
                  'name': 'mikcb-1.3.0-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.3.0.apk',
                },
              ],
              'updated_at': '2026-04-09T10:00:00Z',
            },
          ]),
          200,
        );
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.2.0',
      mirrorUrlPrefix: selectedMirror,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.3.0');
    expect(requests, contains(AppUpdateService.releasesApiUrl));
    expect(requests, contains(mirroredApiUrl));
  });

  test('github api keeps falling back when preferred mirror returns 404',
      () async {
    final requests = <String>[];
    final selectedMirror = 'https://mirror.example/';
    final mirroredApiUrl = '$selectedMirror${AppUpdateService.releasesApiUrl}';
    final client = MockClient((request) async {
      requests.add(request.url.toString());
      final url = request.url.toString();
      if (url == mirroredApiUrl) {
        return http.Response('', 404);
      }
      if (url == AppUpdateService.releasesApiUrl) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.3.1',
              'name': 'v1.3.1',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.3.1',
              'assets': const [
                {
                  'name': 'mikcb-1.3.1-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.3.1.apk',
                },
              ],
              'updated_at': '2026-04-09T10:00:00Z',
            },
          ]),
          200,
        );
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.3.0',
      preferredSource: AppUpdateDownloadSource.mirror,
      mirrorUrlPrefix: selectedMirror,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.3.1');
    expect(requests.first, AppUpdateService.releasesPageUrl);
    expect(requests[1], mirroredApiUrl);
    expect(requests, contains(AppUpdateService.releasesApiUrl));
  });

  test('github api does not wait for a stalled preferred mirror', () async {
    final requests = <String>[];
    final selectedMirror = 'https://mirror.example/';
    final mirroredApiUrl = '$selectedMirror${AppUpdateService.releasesApiUrl}';
    final stalledMirror = Completer<http.Response>();
    final client = MockClient((request) {
      requests.add(request.url.toString());
      final url = request.url.toString();
      if (url == mirroredApiUrl) {
        return stalledMirror.future;
      }
      if (url == AppUpdateService.releasesApiUrl) {
        return Future.value(
          http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.3.2',
                'name': 'v1.3.2',
                'draft': false,
                'prerelease': false,
                'html_url': 'https://example.com/1.3.2',
                'assets': const [
                  {
                    'name': 'mikcb-1.3.2-arm64-v8a.apk',
                    'browser_download_url': 'https://example.com/1.3.2.apk',
                  },
                ],
                'updated_at': '2026-04-09T10:30:00Z',
              },
            ]),
            200,
          ),
        );
      }
      return Future.value(http.Response('', 503));
    });

    final service = AppUpdateService(
      client: client,
      releaseApiRequestTimeout: const Duration(milliseconds: 20),
    );
    final result = await service.checkForUpdates(
      currentVersion: '1.3.1',
      preferredSource: AppUpdateDownloadSource.mirror,
      mirrorUrlPrefix: selectedMirror,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.3.2');
    expect(requests, contains(mirroredApiUrl));
    expect(requests, contains(AppUpdateService.releasesApiUrl));
  });

  test('releases page fallback bypasses api 403 for prerelease updates',
      () async {
    final requests = <String>[];
    const releasesHtml = '''
<section>
  <a href="/Mutx163/mikcb/releases/tag/v1.1.10.24">v1.1.10.24</a>
  <span>Pre-release</span>
  <div data-test-selector="body-content"><h1>v1.1.10.24</h1><ul><li>fallback body</li></ul></div>
  <relative-time datetime="2026-04-09T10:57:31Z"></relative-time>
  <include-fragment src="https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.24"></include-fragment>
</section>
<section>
  <a href="/Mutx163/mikcb/releases/tag/v1.1.10.23">v1.1.10.23</a>
  <span>Pre-release</span>
  <div data-test-selector="body-content"><h1>v1.1.10.23</h1><ul><li>usable body</li></ul></div>
  <relative-time datetime="2026-04-09T02:45:15Z"></relative-time>
  <include-fragment src="https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.23"></include-fragment>
</section>
''';
    const assets24Html = '''
<ul>
  <li><a href="/Mutx163/mikcb/archive/refs/tags/v1.1.10.24.zip">Source code</a></li>
</ul>
''';
    const assets23Html = '''
<ul>
  <li><a href="/Mutx163/mikcb/releases/download/v1.1.10.23/mikcb-1.1.10.23-arm64-v8a.apk">mikcb-1.1.10.23-arm64-v8a.apk</a></li>
</ul>
''';

    final client = MockClient((request) async {
      final url = request.url.toString();
      requests.add(url);
      if (url == AppUpdateService.releasesApiUrl) {
        return http.Response('', 403);
      }
      if (url == AppUpdateService.releasesPageUrl) {
        return http.Response(releasesHtml, 200);
      }
      if (url ==
          'https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.24') {
        return http.Response(assets24Html, 200);
      }
      if (url ==
          'https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.23') {
        return http.Response(assets23Html, 200);
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.10.20',
      includePrerelease: true,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.1.10.23');
    expect(result.latestRelease?.isPrerelease, isTrue);
    expect(
      result.latestRelease?.downloadUrl,
      'https://github.com/Mutx163/mikcb/releases/download/v1.1.10.23/mikcb-1.1.10.23-arm64-v8a.apk',
    );
    expect(requests, isNot(contains(AppUpdateService.releasesApiUrl)));
    expect(requests, contains(AppUpdateService.releasesPageUrl));
  });

  test('pgyer factory is used when credentials are configured', () async {
    late PgyerApiConfig capturedConfig;
    final fakePgyer = _FakePgyerApiService(
      const PgyerAppInfo(
        buildKey: 'build-key',
        buildVersion: '1.4.0',
        buildVersionNo: '90',
        buildUpdateDescription: 'pgyer body',
        buildCreated: '2026-04-10 10:00:00',
        buildFileSize: '1048576',
        buildShortcutUrl: 'qingyu',
        buildName: '轻屿课表',
        buildIcon: '',
      ),
    );
    final client = MockClient((request) async {
      fail('GitHub should not be requested when Pgyer returns a release');
    });

    final service = AppUpdateService(
      client: client,
      pgyerApiServiceFactory: (config) {
        capturedConfig = config;
        return fakePgyer;
      },
    );
    final result = await service.checkForUpdates(
      currentVersion: '1.3.0',
      pgyerApiKey: 'api-key',
      pgyerAppKey: 'app-key',
    );

    expect(fakePgyer.checkCount, 1);
    expect(capturedConfig.apiKey, 'api-key');
    expect(capturedConfig.appKey, 'app-key');
    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.4.0');
    expect(
      result.latestRelease?.pgyerDownloadUrl,
      'https://www.pgyer.com/qingyu',
    );
  });

  test('releases page fallback skips prerelease when stable only is enabled',
      () async {
    const releasesHtml = '''
<section>
  <a href="/Mutx163/mikcb/releases/tag/v1.1.10.23">v1.1.10.23</a>
  <span>Pre-release</span>
  <include-fragment src="https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.23"></include-fragment>
</section>
<section>
  <a href="/Mutx163/mikcb/releases/tag/v1.1.10.20">v1.1.10.20</a>
  <span>Latest</span>
  <div data-test-selector="body-content"><p>stable body</p></div>
  <relative-time datetime="2026-04-06T17:33:26Z"></relative-time>
  <include-fragment src="https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.20"></include-fragment>
</section>
''';
    const assets20Html = '''
<ul>
  <li><a href="/Mutx163/mikcb/releases/download/v1.1.10.20/mikcb-1.1.10.20-arm64-v8a.apk">mikcb-1.1.10.20-arm64-v8a.apk</a></li>
</ul>
''';

    final client = MockClient((request) async {
      final url = request.url.toString();
      if (url == AppUpdateService.releasesApiUrl) {
        return http.Response('', 403);
      }
      if (url == AppUpdateService.releasesPageUrl) {
        return http.Response(releasesHtml, 200);
      }
      if (url ==
          'https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.1.10.20') {
        return http.Response(assets20Html, 200);
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.10.19',
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.1.10.20');
    expect(result.latestRelease?.isPrerelease, isFalse);
    expect(result.latestRelease?.body, 'stable body');
  });
}
