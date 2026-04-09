import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/app_update_service.dart';

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

void main() {
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
              'assets': const [],
              'updated_at': '2026-03-26T10:00:00Z',
            },
            {
              'tag_name': 'v1.1.9.4',
              'name': 'v1.1.9.4',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.9.4',
              'assets': const [],
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
      if (request.url.path.endsWith('/releases/latest')) {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.1.10.3',
            'name': 'v1.1.10.3',
            'draft': false,
            'prerelease': false,
            'html_url': 'https://example.com/1.1.10.3',
            'assets': const [],
            'updated_at': '2026-03-30T10:00:00Z',
          }),
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
              'assets': const [],
              'updated_at': '2026-03-29T09:00:00Z',
            },
            {
              'tag_name': 'v1.1.10.4',
              'name': 'v1.1.10.4',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.10.4',
              'assets': const [],
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
              'assets': const [],
              'updated_at': '2026-03-29T09:00:00Z',
            },
            {
              'tag_name': 'v1.1.10.4',
              'name': 'v1.1.10.4',
              'draft': false,
              'prerelease': true,
              'html_url': 'https://example.com/1.1.10.4',
              'assets': const [],
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

  test(
      'update check prefers configured mirror manifest when mirror source is selected',
      () async {
    final requestedUrls = <String>[];
    final mirrorPrefix = ghproxyCnMirrorUrlPrefix;
    final client = MockClient((request) async {
      requestedUrls.add(request.url.toString());
      if (request.url.toString() ==
          '$mirrorPrefix${AppUpdateService.rawReleaseManifestUrl}') {
        return http.Response(
          jsonEncode({
            'stable': {
              'version': '1.2.0',
              'title': 'v1.2.0',
              'body': 'stable body',
              'releaseUrl': 'https://example.com/1.2.0',
              'downloadUrl': 'https://example.com/1.2.0.apk',
              'updatedAt': '2026-04-08T10:00:00Z',
              'isPrerelease': false,
            },
          }),
          200,
        );
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.0',
      preferredSource: AppUpdateDownloadSource.mirror,
      mirrorUrlPrefix: mirrorPrefix,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.2.0');
    expect(
      requestedUrls.first,
      '$mirrorPrefix${AppUpdateService.rawReleaseManifestUrl}',
    );
  });

  test(
      'update check falls back to mirrored manifest when primary manifest endpoints fail',
      () async {
    final requestedUrls = <String>[];
    final client = MockClient((request) async {
      final url = request.url.toString();
      requestedUrls.add(url);
      if (url == AppUpdateService.docsReleaseManifestUrl ||
          url == AppUpdateService.rawReleaseManifestUrl) {
        return http.Response('', 502);
      }
      if (url ==
          '$defaultAppUpdateMirrorUrlPrefix${AppUpdateService.rawReleaseManifestUrl}') {
        return http.Response(
          jsonEncode({
            'stable': {
              'version': '1.3.0',
              'title': 'v1.3.0',
              'body': 'stable body',
              'releaseUrl': 'https://example.com/1.3.0',
              'downloadUrl': 'https://example.com/1.3.0.apk',
              'updatedAt': '2026-04-09T10:00:00Z',
              'isPrerelease': false,
            },
          }),
          200,
        );
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.2.0',
      preferredSource: AppUpdateDownloadSource.original,
      mirrorUrlPrefix: defaultAppUpdateMirrorUrlPrefix,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.3.0');
    expect(requestedUrls.take(3).toList(), [
      AppUpdateService.docsReleaseManifestUrl,
      AppUpdateService.rawReleaseManifestUrl,
      '$defaultAppUpdateMirrorUrlPrefix${AppUpdateService.rawReleaseManifestUrl}',
    ]);
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

  test('manifest check can prefer the selected mirror source first', () async {
    final requests = <String>[];
    final selectedMirror = 'https://mirror.example/';
    final mirroredManifestUrl =
        '$selectedMirror${AppUpdateService.rawReleaseManifestUrl}';
    final client = MockClient((request) async {
      requests.add(request.url.toString());
      if (request.url.toString() == mirroredManifestUrl) {
        return http.Response(
          jsonEncode({
            'stable': {
              'version': '1.2.0',
              'title': 'v1.2.0',
              'releaseUrl': 'https://example.com/releases/v1.2.0',
              'isPrerelease': false,
            },
          }),
          200,
        );
      }
      return http.Response('', 503);
    });

    final service = AppUpdateService(client: client);
    final result = await service.checkForUpdates(
      currentVersion: '1.1.0',
      preferredSource: AppUpdateDownloadSource.mirror,
      mirrorUrlPrefix: selectedMirror,
    );

    expect(result.hasUpdate, isTrue);
    expect(result.latestRelease?.version, '1.2.0');
    expect(requests.first, mirroredManifestUrl);
  });

  test('github api falls back to mirrored api when direct api is unavailable',
      () async {
    final requests = <String>[];
    final selectedMirror = 'https://mirror.example/';
    final mirroredApiUrl =
        '$selectedMirror${AppUpdateService.latestReleaseApiUrl}';
    final client = MockClient((request) async {
      requests.add(request.url.toString());
      final url = request.url.toString();
      if (url == AppUpdateService.latestReleaseApiUrl) {
        return http.Response('', 503);
      }
      if (url == mirroredApiUrl) {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.3.0',
            'name': 'v1.3.0',
            'draft': false,
            'prerelease': false,
            'html_url': 'https://example.com/1.3.0',
            'assets': const [],
            'updated_at': '2026-04-09T10:00:00Z',
          }),
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
    expect(requests, contains(AppUpdateService.latestReleaseApiUrl));
    expect(requests, contains(mirroredApiUrl));
  });
}
