import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';

Course _course({
  int startSection = 1,
  int endSection = 4,
  String startTime = '',
  String endTime = '',
  bool hasCustomTime = false,
  String location = 'A主215',
  String? timeSchemeIdOverride,
}) {
  return Course(
    id: 'c1',
    name: '机械控制工程',
    teacher: '芦玉琴',
    location: location,
    dayOfWeek: 4,
    startSection: startSection,
    endSection: endSection,
    startTime: startTime,
    endTime: endTime,
    hasCustomTime: hasCustomTime,
    timeSchemeIdOverride: timeSchemeIdOverride,
  );
}

void main() {
  group('Course.hasCustomTime persistence', () {
    test('round-trips through json', () {
      final course = _course(
        startTime: '08:20',
        endTime: '12:10',
        hasCustomTime: true,
      );
      final restored = Course.fromJson(course.toJson());
      expect(restored.hasCustomTime, isTrue);
      expect(restored.startTime, '08:20');
      expect(restored.endTime, '12:10');
    });

    test('legacy json without the key defaults to false', () {
      // 关键：历史存档里 startTime/endTime 可能是过期非空值，不能当成自定义时间。
      final json = _course(startTime: '07:00', endTime: '07:40').toJson()
        ..remove('hasCustomTime');
      final restored = Course.fromJson(json);
      expect(restored.hasCustomTime, isFalse);
      expect(restored.startTime, '07:00');
    });

    test('defaults to false', () {
      expect(_course().hasCustomTime, isFalse);
    });
  });
}
