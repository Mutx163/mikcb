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
    expect(prefs.getString('courses'), isNotNull);
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
}
