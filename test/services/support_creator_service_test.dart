import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:university_timetable/services/support_creator_service.dart';

void main() {
  test(
    'fetchDonors prefers mirror result when mirror responds first',
    () async {
      final client = MockClient((request) async {
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
    },
  );

  test(
    'fetchDonors falls back to raw GitHub when mirror request fails',
    () async {
      final client = MockClient((request) async {
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
    },
  );

  test('fetchDonors decodes utf8 donor names correctly', () async {
    final body = utf8.encode(
      jsonEncode({
        'donors': [
          {'name': '小明同学'},
        ],
      }),
    );
    final client = MockClient((request) async {
      return http.Response.bytes(
        body,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final service = SupportCreatorService(client: client);
    final data = await service.fetchDonors();

    expect(data.donors.single.name, '小明同学');
  });
}
