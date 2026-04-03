import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_timetable/services/app_update_service.dart';

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

  test('download can be cancelled and cleans up partial apk', () async {
    final tempDir = await Directory.systemTemp.createTemp('mikcb_update_test_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

    unawaited(() async {
      await for (final request in server) {
        request.response.statusCode = 200;
        request.response.headers.contentType =
            ContentType.binary;
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
    final result = await service.probeDownloadUrl('https://example.com/app.apk');

    expect(result.isSuccess, isTrue);
    expect(result.statusCode, 206);
  });
}
