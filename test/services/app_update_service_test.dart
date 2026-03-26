import 'dart:convert';

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
}
