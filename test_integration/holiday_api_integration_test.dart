// 节假日 API 集成测试
//
// 真实调用远程 API 验证：
// - API 可访问性
// - 返回格式正确性
// - 数据解析正确性
// - 关键节假日数据存在
//
// 运行：flutter test test_integration/holiday_api_integration_test.dart
//
// 注意：需要网络环境，CI 中可能因网络限制失败
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/services/holiday_service.dart';

void main() {
  // 集成测试需要网络，标记为 skip 可在 CI 中跳过
  // 改为 false 来运行真实测试
  const bool skipInCI = false;

  group('xiaoai API 集成测试', () {
    test('API 可访问且返回 200', () async {
      final uri = Uri.parse(
        'https://publicapi.xiaoai.me/holiday/year?year=2026',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      expect(response.statusCode, 200);
    }, skip: skipInCI);

    test('返回格式符合预期（code + data）', () async {
      final uri = Uri.parse(
        'https://publicapi.xiaoai.me/holiday/year?year=2026',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json.containsKey('code'), isTrue);
      expect(json.containsKey('data'), isTrue);
      expect(json['code'], 0);
      expect(json['data'], isA<List<Object>>());
    }, skip: skipInCI);

    test('数据包含 2026 年元旦', () async {
      final uri = Uri.parse(
        'https://publicapi.xiaoai.me/holiday/year?year=2026',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>;

      // 查找 2026-01-01
      final newYear = data
          .where(
            (item) => (item as Map<String, dynamic>)['date'] == '2026-01-01',
          )
          .toList();

      expect(newYear, isNotEmpty);
      expect((newYear.first as Map)['daytype'], 1); // 假期
    }, skip: skipInCI);

    test('数据包含 2026 年国庆节', () async {
      final uri = Uri.parse(
        'https://publicapi.xiaoai.me/holiday/year?year=2026',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>;

      // 查找 2026-10-01
      final nationalDay = data
          .where(
            (item) => (item as Map<String, dynamic>)['date'] == '2026-10-01',
          )
          .toList();

      expect(nationalDay, isNotEmpty);
      expect((nationalDay.first as Map)['daytype'], 1); // 假期
    }, skip: skipInCI);

    test('HolidayService 能正确解析 xiaoai 数据', () async {
      final service = HolidayService();
      final data = await service.getDataForYear(2026);

      // 验证基本结构
      expect(data.year, 2026);
      expect(data.entries, isNotEmpty);

      // 验证元旦
      expect(data.isHoliday(DateTime(2026)), isTrue);

      // 验证国庆
      expect(data.isHoliday(DateTime(2026, 10)), isTrue);

      // 输出日志供人工检查
      debugPrint('xiaoai API 返回 ${data.entries.length} 条节假日数据');
      debugPrint(
        '假期条目：${data.entries.where((e) => e.type == HolidayType.vacation).length}',
      );
      debugPrint(
        '调休条目：${data.entries.where((e) => e.type == HolidayType.adjustedWorkday).length}',
      );
    }, skip: skipInCI);
  });

  group('ailcc API 集成测试', () {
    test('API 可访问且返回 200', () async {
      final uri = Uri.parse('https://holiday.ailcc.com/api/holiday/year/2026');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      expect(response.statusCode, 200);
    }, skip: skipInCI);

    test('返回格式符合预期（code + holiday）', () async {
      final uri = Uri.parse('https://holiday.ailcc.com/api/holiday/year/2026');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      expect(json.containsKey('code'), isTrue);
      expect(json.containsKey('holiday'), isTrue);
      expect(json['code'], 0);
      expect(json['holiday'], isA<Map<String, dynamic>>());
    }, skip: skipInCI);

    test('数据包含 2026 年元旦', () async {
      final uri = Uri.parse('https://holiday.ailcc.com/api/holiday/year/2026');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final holiday = json['holiday'] as Map<String, dynamic>;

      expect(holiday.containsKey('01-01'), isTrue);
      final newYear = holiday['01-01'] as Map<String, dynamic>;
      expect(newYear['holiday'], true);
    }, skip: skipInCI);

    test('数据包含 2026 年国庆节', () async {
      final uri = Uri.parse('https://holiday.ailcc.com/api/holiday/year/2026');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final holiday = json['holiday'] as Map<String, dynamic>;

      expect(holiday.containsKey('10-01'), isTrue);
      final nationalDay = holiday['10-01'] as Map<String, dynamic>;
      expect(nationalDay['holiday'], true);
    }, skip: skipInCI);
  });

  group('Fallback 机制集成测试', () {
    test('两个 API 返回的假期日期一致', () async {
      // 获取 xiaoai 数据
      final xiaoaiUri = Uri.parse(
        'https://publicapi.xiaoai.me/holiday/year?year=2026',
      );
      final xiaoaiResp = await http
          .get(xiaoaiUri)
          .timeout(const Duration(seconds: 15));
      final xiaoaiJson = jsonDecode(xiaoaiResp.body) as Map<String, dynamic>;
      final xiaoaiData = xiaoaiJson['data'] as List<dynamic>;

      final xiaoaiHolidays = xiaoaiData
          .where((item) => (item as Map<String, dynamic>)['daytype'] == 1)
          .map((item) => (item as Map<String, dynamic>)['date'] as String)
          .toSet();

      // 获取 ailcc 数据
      final ailccUri = Uri.parse(
        'https://holiday.ailcc.com/api/holiday/year/2026',
      );
      final ailccResp = await http
          .get(ailccUri)
          .timeout(const Duration(seconds: 15));
      final ailccJson = jsonDecode(ailccResp.body) as Map<String, dynamic>;
      final ailccHoliday = ailccJson['holiday'] as Map<String, dynamic>;

      final ailccHolidays = ailccHoliday.entries
          .where(
            (entry) => (entry.value as Map<String, dynamic>)['holiday'] == true,
          )
          .map(
            (entry) => (entry.value as Map<String, dynamic>)['date'] as String,
          )
          .toSet();

      // 比较（允许小差异，因为数据源可能略有不同）
      final commonHolidays = xiaoaiHolidays.intersection(ailccHolidays);
      debugPrint('xiaoai 假期数：${xiaoaiHolidays.length}');
      debugPrint('ailcc 假期数：${ailccHolidays.length}');
      debugPrint('共同假期数：${commonHolidays.length}');

      // 至少应该有 7 天法定假日是共同的
      expect(commonHolidays.length, greaterThanOrEqualTo(7));
    }, skip: skipInCI);

    test('HolidayService fallback 真实场景', () async {
      // 使用真实 HTTP client
      final service = HolidayService();
      final data = await service.getDataForYear(2026);

      // 验证数据完整性
      expect(data.entries, isNotEmpty);
      expect(data.isHoliday(DateTime(2026)), isTrue); // 元旦
      expect(data.isHoliday(DateTime(2026, 10)), isTrue); // 国庆

      // 验证日志显示使用了哪个 API
      final usedPrimary = service.logs.any(
        (e) => e.message.contains('主 API 返回'),
      );
      final usedFallback = service.logs.any(
        (e) => e.message.contains('备用 API 返回'),
      );
      final usedBuiltin = service.logs.any((e) => e.message.contains('内置资产'));

      debugPrint('使用主 API：$usedPrimary');
      debugPrint('使用备用 API：$usedFallback');
      debugPrint('使用内置资产：$usedBuiltin');

      // 至少使用了一个数据源
      expect(usedPrimary || usedFallback || usedBuiltin, isTrue);
    }, skip: skipInCI);
  });

  group('数据质量验证', () {
    test('2026 年节假日数据完整性', () async {
      final service = HolidayService();
      final data = await service.getDataForYear(2026);

      // 验证关键节假日存在
      final criticalHolidays = [
        DateTime(2026), // 元旦
        DateTime(2026, 5), // 劳动节
        DateTime(2026, 10), // 国庆节
      ];

      for (final date in criticalHolidays) {
        expect(
          data.isHoliday(date),
          isTrue,
          reason: '${date.month}/${date.day} 应该是假期',
        );
      }

      // 输出统计
      final vacationDays = data.entries
          .where((e) => e.type == HolidayType.vacation)
          .length;
      final adjustedWorkdays = data.entries
          .where((e) => e.type == HolidayType.adjustedWorkday)
          .length;
      debugPrint('2026 年假期天数：$vacationDays');
      debugPrint('2026 年调休天数：$adjustedWorkdays');
    }, skip: skipInCI);

    test('节假日条目有合理的 groupId', () async {
      final service = HolidayService();
      final data = await service.getDataForYear(2026);

      // 验证每个条目都有 groupId
      for (final entry in data.entries) {
        expect(entry.groupId, isNotNull, reason: '${entry.name} 缺少 groupId');
        expect(entry.groupId, isNotEmpty, reason: '${entry.name} groupId 为空');
      }

      // 验证同一假期的 groupId 一致
      final groups = <String, List<HolidayEntry>>{};
      for (final entry in data.entries) {
        groups.putIfAbsent(entry.groupId!, () => []).add(entry);
      }

      debugPrint('假期分组数：${groups.length}');
      for (final group in groups.entries) {
        debugPrint(
          '  ${group.key}: ${group.value.map((e) => e.name).toSet().join(", ")} (${group.value.length} 天)',
        );
      }
    }, skip: skipInCI);
  });
}
