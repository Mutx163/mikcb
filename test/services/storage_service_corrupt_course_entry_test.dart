import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/storage_service.dart';

Course _course(String id) => Course(
  id: id,
  name: id,
  teacher: 't',
  location: 'l',
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  startTime: '08:00',
  endTime: '09:40',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
  });

  test('单条坏 JSON 不再清空整份课程列表，好条目全部保留', () async {
    final good = _course('good-1');
    final goodJson = good.toJsonString();
    SharedPreferences.setMockInitialValues({
      'courses': <String>[
        goodJson,
        '{not-valid-json',
        jsonEncode(<String, dynamic>{
          // 合法 JSON 但类型垃圾：id 非字符串会抛 TypeError。
          'id': 123,
        }),
      ],
    });
    final storage = StorageService();
    await storage.init();

    final courses = await storage.getCourses();

    expect(courses, hasLength(1));
    expect(courses.single.id, 'good-1');
    // 原始数据仍有好条目，不应被备份清除。
    final prefs = await SharedPreferences.getInstance();
    // courses 存的是 StringList， getStringList 读取（getString 会因类型
    // 不匹配抛 cast 错误，无法用来探测存在性）。有一个好条目时 key 不被
    // 清除，通过 getStringList 断言原始列表仍在。
    expect(prefs.getStringList('courses'), isNotNull);
    expect(prefs.getStringList('courses'), contains(goodJson));
  });

  test('全部条目都坏时备份原始数据并清 key（与 profiles 口径一致）', () async {
    SharedPreferences.setMockInitialValues({
      'courses': <String>['{bad', '{also-bad'],
    });
    final storage = StorageService();
    await storage.init();

    final courses = await storage.getCourses();
    expect(courses, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('courses'), isNull);
    final backupKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('courses_corrupt_backup_'))
        .toList();
    expect(backupKeys, hasLength(1));
  });

  test('坏条目修复后写路径不再丢好课程', () async {
    final good = _course('good-1');
    SharedPreferences.setMockInitialValues({
      'courses': <String>[good.toJsonString(), '{bad'],
    });
    final storage = StorageService();
    await storage.init();

    final courses = await storage.getCourses();
    expect(courses, hasLength(1));

    // 一次无害的保存（read-modify-write）必须保住好课程。
    await storage.saveCourses([...courses, _course('new-1')]);
    final reread = await storage.getCourses();
    expect(reread.map((c) => c.id), containsAll(['good-1', 'new-1']));
  });

  test('部分损坏时坏条目进隔离档（可整体解码还原原文），courses key 不清除', () async {
    final good = _course('good-1');
    final goodJson = good.toJsonString();
    const badJson = '{not-valid-json';
    SharedPreferences.setMockInitialValues({
      'courses': <String>[goodJson, badJson],
    });
    final storage = StorageService();
    await storage.init();

    final courses = await storage.getCourses();
    expect(courses, hasLength(1));

    final prefs = await SharedPreferences.getInstance();
    // 原始列表仍在盘上（条目级损坏刻意不写回清洗结果）。
    expect(prefs.getStringList('courses'), contains(goodJson));
    // 隔离档：滚动 key，结构化留档，原始坏条目可还原。
    final archived = prefs.getString(StorageService.coursesUnparsedItemsKey);
    expect(archived, isNotNull);
    final decoded = jsonDecode(archived!) as Map<String, dynamic>;
    expect(decoded['count'], 1);
    final items = (decoded['items'] as List).cast<String>();
    expect(items, hasLength(1));
    // 留档是 JSON 字符串字面量：decode 一次即还原原始坏条目文本。
    expect(jsonDecode(items.single), badJson);
    expect(decoded['archivedAt'], isA<String>());
  });

  test('隔离档有容量上限：50 条后不再追加，避免畸形数据撑爆留档', () async {
    final rawList = <String>['{bad'];
    for (var i = 0; i < 60; i++) {
      rawList.add('{bad-$i');
    }
    SharedPreferences.setMockInitialValues({'courses': rawList});
    final storage = StorageService();
    await storage.init();

    final courses = await storage.getCourses();
    expect(courses, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    // 全坏仍走 _backupAndRemoveCorruptStringList 原始整档备份。
    expect(prefs.getString('courses'), isNull);
    final decoded =
        jsonDecode(prefs.getString(StorageService.coursesUnparsedItemsKey)!)
            as Map<String, dynamic>;
    final items = (decoded['items'] as List).cast<String>();
    expect(items, hasLength(50));
    expect(decoded['count'], 50);
  });

  test('超长坏条目在隔离档内截断，单条不超过字符上限', () async {
    final oversized = '{"id":"${'a' * 5000}';
    SharedPreferences.setMockInitialValues({
      'courses': <String>[oversized],
    });
    final storage = StorageService();
    await storage.init();

    final courses = await storage.getCourses();
    expect(courses, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    final decoded =
        jsonDecode(prefs.getString(StorageService.coursesUnparsedItemsKey)!)
            as Map<String, dynamic>;
    final items = (decoded['items'] as List).cast<String>();
    expect(items, hasLength(1));
    // 4096 字符 + 截断标记（标记为英文 `…<truncated>`，避免占用 CJK 硬编码棘轮）。
    expect(items.single.length, lessThanOrEqualTo(4096 + 16));
    expect(items.single, contains('…<truncated>'));
  });
}
