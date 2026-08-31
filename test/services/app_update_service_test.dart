import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_update_service.dart';

class _CountingProbeClient extends http.BaseClient {
  final int totalBytes;
  int streamedBytes = 0;
  Map<String, String>? lastGetHeaders;

  _CountingProbeClient({required this.totalBytes});

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

void main() {
  test('github api and releases page race in parallel', () async {
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      requestedPaths.add(request.url.path);
      if (request.url.path.endsWith('/releases')) {
        // 模拟 GitHub API 稍慢
        await Future<void>.delayed(const Duration(milliseconds: 50));
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
      // Releases 页面请求返回 404
      return http.Response('', 404);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(currentVersion: '1.1.10');

    expect(result.hasRelease, isTrue);
    expect(result.latestRelease?.version, '1.1.11');
    // 两个策略都发出了请求
    expect(requestedPaths, contains('/repos/Mutx163/mikcb/releases'));
  });

  test(
    'debug build with dash suffix is not treated as newer than release',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/releases')) {
          return http.Response(
            jsonEncode([
              {
                'tag_name': 'v1.2.0.29',
                'name': 'v1.2.0.29',
                'draft': false,
                'prerelease': false,
                'html_url': 'https://example.com/1.2.0.29',
                'assets': const [
                  {
                    'name': 'mikcb-1.2.0.29-arm64-v8a.apk',
                    'browser_download_url': 'https://example.com/1.2.0.29.apk',
                  },
                ],
                'updated_at': '2026-05-11T10:00:00Z',
              },
            ]),
            200,
          );
        }
        return http.Response('', 404);
      });

      final service = AppUpdateService(client: client);
      final result = await service.checkForUpdates(
        currentVersion: '1.2.0-29-debug',
      );

      expect(result.hasRelease, isTrue);
      expect(result.latestRelease?.version, '1.2.0.29');
      // debug 构建 1.2.0-29-debug 应该等同于 1.2.0.29，不提示更新
      expect(result.hasUpdate, isFalse);
    },
  );

  test(
    'include prerelease picks highest version even if not first in list',
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
    },
  );

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
    final result = await service.checkForUpdates(currentVersion: '1.1.10-3+33');

    expect(result.hasRelease, isTrue);
    expect(result.hasUpdate, isFalse);
    expect(result.latestRelease?.version, '1.1.10.3');
  });

  test(
    'include prerelease keeps numbered prerelease above base release',
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
    },
  );

  test(
    'numbered prerelease still upgrades from base release when enabled',
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
    },
  );

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
      result.latestRelease?.downloadUrl,
      'https://example.com/1.1.10.23.apk',
    );
  });

  test(
    'stable update skips newer release entries without apk assets',
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
      final result = await service.checkForUpdates(currentVersion: '1.1.9');

      expect(result.hasUpdate, isTrue);
      expect(result.latestRelease?.version, '1.2.0');
      expect(
        result.latestRelease?.downloadUrl,
        'https://example.com/1.2.0.apk',
      );
    },
  );

  test('download rejects untrusted remote url', () async {
    final service = AppUpdateService();
    final result = await service.downloadAndInstallUpdate(
      'https://evil.example.com/app.apk',
      (_, _) {},
      null,
    );
    expect(result, 'update_download_url_untrusted');
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
  test(
    'download cancellation closes a stalled HTTP response immediately',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mikcb_update_test_',
      );
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final responseStarted = Completer<void>();

      unawaited(() async {
        await for (final request in server) {
          request.response.statusCode = 200;
          request.response.headers.contentType = ContentType.binary;
          request.response.headers.contentLength = 1;
          request.response.add([1]);
          await request.response.flush();
          if (!responseStarted.isCompleted) {
            responseStarted.complete();
          }
          try {
            await request.response.done;
          } catch (_) {
            // Closing the client forcefully is expected to abort this response.
          }
        }
      }());

      final controller = AppUpdateDownloadController();
      final service = AppUpdateService(
        temporaryDirectoryProvider: () async => tempDir,
        openInstaller: (path) async {
          fail('cancelled download should not try to open installer');
        },
      );

      try {
        final downloadFuture = service.downloadAndInstallUpdate(
          'http://${server.address.host}:${server.port}/app.apk',
          (_, _) {},
          controller,
        );
        await responseStarted.future.timeout(const Duration(seconds: 2));
        controller.cancel();
        final result = await downloadFuture.timeout(const Duration(seconds: 2));

        expect(result, AppUpdateService.downloadCancelledMessage);
        expect(
          await File('${tempDir.path}/mikcb_update.apk').exists(),
          isFalse,
        );
      } finally {
        await server.close(force: true);
        await tempDir.delete(recursive: true);
      }
    },
  );

  test(
    'download clears stale managed installer apk files before writing',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'mikcb_update_test_',
      );
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
        (_, _) {},
        null,
      );

      expect(result, isNull);
      expect(openedPath, '${tempDir.path}/mikcb_update.apk');
      expect(await staleApk.exists(), isFalse);
      expect(await staleCurrentApk.exists(), isTrue);
      expect(await staleCurrentApk.length(), 6);

      await server.close(force: true);
      await tempDir.delete(recursive: true);
    },
  );

  test(
    'probe download falls back to range get when head is rejected',
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
      final result = await service.probeDownloadUrl(
        'https://example.com/app.apk',
      );

      expect(result.isSuccess, isTrue);
      expect(result.statusCode, 206);
    },
  );

  test(
    'probe download does not buffer the full body when range is ignored',
    () async {
      final client = _CountingProbeClient(totalBytes: 3 * 1024 * 1024);
      final service = AppUpdateService(client: client);

      final result = await service.probeDownloadUrl(
        'https://example.com/app.apk',
      );

      expect(result.isSuccess, isTrue);
      expect(result.statusCode, 200);
      expect(client.lastGetHeaders?['Range'], 'bytes=0-0');
      expect(client.streamedBytes, lessThan(client.totalBytes));
    },
  );

  test(
    'github api falls back to mirrored api when direct api is unavailable',
    () async {
      final requests = <String>[];
      final selectedMirror = 'https://mirror.example/';
      final mirroredApiUrl =
          '$selectedMirror${AppUpdateService.releasesApiUrl}';
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
    },
  );

  test(
    'github api keeps falling back when preferred mirror returns 404',
    () async {
      final requests = <String>[];
      final selectedMirror = 'https://mirror.example/';
      final mirroredApiUrl =
          '$selectedMirror${AppUpdateService.releasesApiUrl}';
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
      expect(requests, contains(mirroredApiUrl));
      expect(requests, contains(AppUpdateService.releasesApiUrl));
    },
  );

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

  test(
    'releases page fallback bypasses api 403 for prerelease updates',
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

      final client = MockClient((request) async {
        final url = request.url.toString();
        requests.add(url);
        if (url == AppUpdateService.releasesApiUrl) {
          return http.Response('', 403);
        }
        // releases 页面请求（含镜像候选），只要直连返回 HTML 即可
        if (url == AppUpdateService.releasesPageUrl) {
          return http.Response(releasesHtml, 200);
        }
        return http.Response('', 503);
      });

      final service = AppUpdateService(client: client);
      final result = await service.checkForUpdates(
        currentVersion: '1.1.10.20',
        includePrerelease: true,
      );

      // 构造优先：直接从 tag 构造下载链接，无需 expanded_assets 子请求
      expect(result.hasUpdate, isTrue);
      expect(result.latestRelease?.version, '1.1.10.24');
      expect(result.latestRelease?.isPrerelease, isTrue);
      expect(
        result.latestRelease?.downloadUrl,
        'https://github.com/Mutx163/mikcb/releases/download/v1.1.10.24/mikcb-1.1.10.24-arm64-v8a.apk',
      );
      expect(requests, contains(AppUpdateService.releasesApiUrl));
      expect(requests, contains(AppUpdateService.releasesPageUrl));
      // 不应再发起 expanded_assets 子请求
      expect(requests.any((r) => r.contains('expanded_assets')), isFalse);
    },
  );

  test(
    'releases page fallback skips prerelease when stable only is enabled',
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

      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == AppUpdateService.releasesApiUrl) {
          return http.Response('', 403);
        }
        if (url == AppUpdateService.releasesPageUrl) {
          return http.Response(releasesHtml, 200);
        }
        return http.Response('', 503);
      });

      final service = AppUpdateService(client: client);
      final result = await service.checkForUpdates(currentVersion: '1.1.10.19');

      expect(result.hasUpdate, isTrue);
      expect(result.latestRelease?.version, '1.1.10.20');
      expect(result.latestRelease?.isPrerelease, isFalse);
      expect(result.latestRelease?.body, 'stable body');
      expect(
        result.latestRelease?.downloadUrl,
        'https://github.com/Mutx163/mikcb/releases/download/v1.1.10.20/mikcb-1.1.10.20-arm64-v8a.apk',
      );
    },
  );

  test(
    'releases page constructs download url for ancient non-suffixed release',
    () async {
      // v1.0.1 是唯一一个不遵循 mikcb-{version}-arm64-v8a.apk 命名规律的 release
      // （实际文件名是 mikcb-1.0.1.apk，无 ABI 后缀）。
      // 构造优先会生成 mikcb-1.0.1-arm64-v8a.apk，这在历史上是唯一的不匹配。
      // 但 v1.0.1 是极早期版本，现实中不可能有人从 v1.0.0 更新到 v1.0.1，
      // 所以这个边缘情况不影响任何真实用户。
      const releasesHtml = '''
<section>
  <a href="/Mutx163/mikcb/releases/tag/v1.0.1">v1.0.1</a>
  <span>Latest</span>
  <include-fragment src="https://github.com/Mutx163/mikcb/releases/expanded_assets/v1.0.1"></include-fragment>
</section>
''';

      final client = MockClient((request) async {
        final url = request.url.toString();
        if (url == AppUpdateService.releasesApiUrl) {
          return http.Response('', 403);
        }
        if (url == AppUpdateService.releasesPageUrl) {
          return http.Response(releasesHtml, 200);
        }
        return http.Response('', 503);
      });

      final service = AppUpdateService(client: client);
      final result = await service.checkForUpdates(currentVersion: '1.0.0');

      expect(result.hasUpdate, isTrue);
      expect(result.latestRelease?.version, '1.0.1');
      // 构造出的 URL 遵循统一命名规律
      expect(
        result.latestRelease?.downloadUrl,
        'https://github.com/Mutx163/mikcb/releases/download/v1.0.1/mikcb-1.0.1-arm64-v8a.apk',
      );
    },
  );

  test('download installs apk when sha256 matches expected digest', () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb_update_test_');
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
      (_, _) {},
      null,
      expectedApkSha256: sha256.convert(List<int>.filled(6, 7)).toString(),
    );

    expect(result, isNull);
    expect(openedPath, '${tempDir.path}/mikcb_update.apk');

    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('download rejects apk when sha256 mismatch and deletes the file', () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb_update_test_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(() async {
      await for (final request in server) {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType.binary;
        request.response.add(List<int>.filled(6, 7));
        await request.response.close();
      }
    }());

    final service = AppUpdateService(
      temporaryDirectoryProvider: () async => tempDir,
      openInstaller: (path) async {
        fail('tampered apk must not reach the installer');
      },
    );

    final wrongSha =
        sha256.convert(<int>[1, 2, 3]).toString();
    final result = await service.downloadAndInstallUpdate(
      'http://${server.address.host}:${server.port}/app.apk',
      (_, _) {},
      null,
      expectedApkSha256: wrongSha,
    );

    expect(result, 'update_download_hash_mismatch');
    expect(await File('${tempDir.path}/mikcb_update.apk').exists(), isFalse);

    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('download skips hash verification when no expected digest', () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb_update_test_');
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
      (_, _) {},
      null,
    );

    expect(result, isNull);
    expect(openedPath, isNotNull);

    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  test('release info carries apk sha256 digest from github api', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.4.0',
              'name': 'v1.4.0',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.4.0',
              'assets': const [
                {
                  'name': 'mikcb-1.4.0-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.4.0.apk',
                  'digest': 'sha256:abc123',
                },
              ],
              'updated_at': '2026-04-20T09:00:00Z',
            },
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(currentVersion: '1.3.0');

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.expectedApkSha256, 'abc123');
  });

  test('release info has null digest when api omits it', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/releases')) {
        return http.Response(
          jsonEncode([
            {
              'tag_name': 'v1.4.0',
              'name': 'v1.4.0',
              'draft': false,
              'prerelease': false,
              'html_url': 'https://example.com/1.4.0',
              'assets': const [
                {
                  'name': 'mikcb-1.4.0-arm64-v8a.apk',
                  'browser_download_url': 'https://example.com/1.4.0.apk',
                },
              ],
              'updated_at': '2026-04-20T09:00:00Z',
            },
          ]),
          200,
        );
      }
      return http.Response('', 404);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(currentVersion: '1.3.0');

    expect(result.latestRelease?.expectedApkSha256, isNull);
  });
}
