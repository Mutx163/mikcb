import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_timetable/services/support_creator_service.dart';

void main() {
  test('fetchDonors prefers mirror before raw GitHub when mirror is configured',
      () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(
        jsonEncode({
          'donors': [
            {'name': 'Mirror Donor'},
          ],
        }),
        200,
      );
    });

    final service = SupportCreatorService(client: client);
    final data = await service.fetchDonors(
      mirrorUrlPrefix: 'https://mirror.example.com/',
    );

    expect(data.donors.single.name, 'Mirror Donor');
    expect(requests, hasLength(1));
    expect(requests.single.toString(), startsWith('https://mirror.example.com/'));
  });

  test('fetchDonors falls back to raw GitHub when mirror request fails',
      () async {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      if (request.url.host == 'mirror.example.com') {
        return http.Response('mirror unavailable', 502);
      }
      return http.Response(
        jsonEncode({
          'donors': [
            {'name': 'Raw Donor'},
          ],
        }),
        200,
      );
    });

    final service = SupportCreatorService(client: client);
    final data = await service.fetchDonors(
      mirrorUrlPrefix: 'https://mirror.example.com/',
    );

    expect(data.donors.single.name, 'Raw Donor');
    expect(
      requests.map((request) => request.host).toList(),
      ['mirror.example.com', 'raw.githubusercontent.com'],
    );
  });
}
