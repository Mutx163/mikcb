import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/services/holiday_service.dart';

class _FakeClient extends http.BaseClient {
  final Map<String, http.Response> responses;

  _FakeClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = responses[request.url.toString()];
    if (response == null) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('not found')),
        404,
        request: request,
      );
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

const _remoteUrl2026 = 'https://api.haoshenqi.top/holiday?date=2026';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('convertApiEntriesForTest', () {
    test('groups consecutive holidays and attaches makeup workdays', () {
      final service = HolidayService();
      final raw = [
        {'date': '2026-10-01', 'status': 3},
        {'date': '2026-10-02', 'status': 3},
        {'date': '2026-10-10', 'status': 2},
        {'date': '2026-10-11', 'status': 0},
      ];

      final entries = service.convertApiEntriesForTest(raw, 2026);

      expect(entries.where((e) => e.type == HolidayType.vacation), hasLength(2));
      expect(
        entries.where((e) => e.type == HolidayType.adjustedWorkday),
        hasLength(1),
      );
      expect(entries.firstWhere((e) => e.date.day == 1).name, '国庆节');
      expect(
        entries.firstWhere((e) => e.type == HolidayType.adjustedWorkday).name,
        '调休上班',
      );
    });

    test('returns empty list when API has no holiday or makeup days', () {
      final service = HolidayService();
      final raw = [
        {'date': '2026-03-02', 'status': 0},
        {'date': '2026-03-03', 'status': 1},
      ];

      final entries = service.convertApiEntriesForTest(raw, 2026);

      expect(entries, isEmpty);
    });
  });

  group('getDataForYear', () {
    test('loads remote data when request succeeds', () async {
      final remoteBody = jsonEncode([
        {'date': '2026-01-01', 'status': 3},
        {'date': '2026-01-02', 'status': 3},
        {'date': '2026-01-04', 'status': 2},
      ]);
      final service = HolidayService(
        client: _FakeClient({
          _remoteUrl2026: http.Response(remoteBody, 200),
        }),
      );

      final data = await service.getDataForYear(2026);

      expect(data.year, 2026);
      expect(data.entries, isNotEmpty);
      expect(data.isHoliday(DateTime(2026, 1, 1)), isTrue);
      expect(data.isAdjustedWorkday(DateTime(2026, 1, 4)), isTrue);
    });

    test('falls back to builtin asset when remote returns 400', () async {
      final service = HolidayService(
        client: _FakeClient({
          _remoteUrl2026: http.Response('bad request', 400),
        }),
      );

      final data = await service.getDataForYear(2026);

      expect(data.entries, isNotEmpty);
      expect(data.isHoliday(DateTime(2026, 10, 1)), isTrue);
      expect(
        service.logs.any((entry) => entry.message.contains('远程响应 400')),
        isTrue,
      );
    });

    test('uses local cache before hitting remote', () async {
      final cached = HolidayData(
        year: 2026,
        version: 1,
        entries: [
          HolidayEntry(
            date: DateTime(2026, 12, 31),
            name: '缓存假期',
            type: HolidayType.vacation,
            groupId: 'cached-2026',
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        'holiday_data_2026': cached.toJsonString(),
      });
      final service = HolidayService(
        client: _FakeClient({
          _remoteUrl2026: http.Response('should not be used synchronously', 500),
        }),
      );

      final data = await service.getDataForYear(2026);

      expect(data.entries.single.name, '缓存假期');
    });

    test('clearCache forces reload from remote', () async {
      final remoteBody = jsonEncode([
        {'date': '2026-05-01', 'status': 3},
      ]);
      final service = HolidayService(
        client: _FakeClient({
          _remoteUrl2026: http.Response(remoteBody, 200),
        }),
      );
      await service.getDataForYear(2026);
      await service.clearCache(2026);

      final data = await service.getDataForYear(2026);

      expect(data.isHoliday(DateTime(2026, 5, 1)), isTrue);
    });
  });

  group('custom holidays', () {
    test('persists add, update, and remove by groupId', () async {
      final service = HolidayService();

      await service.addCustomHoliday(
        HolidayEntry(
          date: DateTime(2026, 7, 1),
          name: '暑假',
          type: HolidayType.vacation,
          groupId: 'custom-summer',
        ),
      );
      expect((await service.loadCustomHolidays()), hasLength(1));

      await service.updateCustomHoliday('custom-summer', [
        HolidayEntry(
          date: DateTime(2026, 7, 1),
          name: '暑假',
          type: HolidayType.vacation,
          groupId: 'custom-summer',
        ),
        HolidayEntry(
          date: DateTime(2026, 7, 2),
          name: '暑假',
          type: HolidayType.vacation,
          groupId: 'custom-summer',
        ),
      ]);
      expect((await service.loadCustomHolidays()), hasLength(2));

      await service.removeCustomHoliday('custom-summer');
      expect(await service.loadCustomHolidays(), isEmpty);
    });
  });
}
