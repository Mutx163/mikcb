import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_course_import_logic.dart';
import 'package:university_timetable/models/course.dart';

List<Course> _parse(List<dynamic> items) =>
    WarehouseCourseImportLogic.parse(
      items,
      idFactory: _nextId,
      unknownTeacher: '未知教师',
      unknownLocation: '未知地点',
    );

int _seq = 0;
String _nextId() => 'id-${_seq++}';

void main() {
  setUp(() => _seq = 0);

  group('normalizeClock', () {
    test('accepts HH:mm and H:mm', () {
      expect(WarehouseCourseImportLogic.normalizeClock('08:20'), '08:20');
      expect(WarehouseCourseImportLogic.normalizeClock('8:05'), '08:05');
    });

    test('tolerates whitespace and a trailing seconds part', () {
      expect(WarehouseCourseImportLogic.normalizeClock(' 09:15 '), '09:15');
      expect(WarehouseCourseImportLogic.normalizeClock('10:30:00'), '10:30');
    });

    test('rejects garbage and out-of-range values', () {
      expect(WarehouseCourseImportLogic.normalizeClock(null), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock(''), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('abc'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('25:00'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('08:99'), isNull);
      expect(WarehouseCourseImportLogic.normalizeClock('0800'), isNull);
    });
  });

  group('parse', () {
    test('keeps a normal course unchanged (no custom time)', () {
      final courses = _parse([
        {
          'name': '机械控制工程',
          'teacher': '芦玉琴',
          'position': 'A主215',
          'day': 4,
          'startSection': 1,
          'endSection': 4,
          'weeks': [7, 11],
        },
      ]);
      expect(courses, hasLength(1));
      final c = courses.single;
      expect(c.name, '机械控制工程');
      expect(c.startSection, 1);
      expect(c.endSection, 4);
      expect(c.startTime, '');
      expect(c.endTime, '');
      expect(c.hasCustomTime, isFalse);
      expect(c.customWeeks, [7, 11]);
    });

    test('早读：没有节次但有真实钟点 —— 过去会被整条丢弃，现在保留', () {
      final courses = _parse([
        {
          'name': '早读',
          'teacher': '张三',
          'position': 'A主101',
          'day': 1,
          'weeks': [1, 2, 3],
          'isCustomTime': true,
          'customStartTime': '07:30',
          'customEndTime': '08:00',
        },
      ]);
      // 关键回归：以前 startSection/endSection 缺失 → 直接 continue，课凭空消失。
      expect(courses, hasLength(1));
      final c = courses.single;
      expect(c.hasCustomTime, isTrue);
      expect(c.startTime, '07:30');
      expect(c.endTime, '08:00');
      // 无节次可落位，固定占第 1 节，显示位置是第 1 节但钟点用真实值。
      expect(c.startSection, 1);
      expect(c.endSection, 1);
    });

    test('带节次 + 自定义钟点（永川「其他教学楼」第 1-4 节）', () {
      final courses = _parse([
        {
          'name': '工装夹具设计及应用课程设计',
          'teacher': '付世强',
          'position': 'A综204',
          'day': 5,
          'startSection': 1,
          'endSection': 4,
          'weeks': [11, 12],
          'isCustomTime': true,
          'customStartTime': '08:20',
          'customEndTime': '12:00',
        },
      ]);
      expect(courses, hasLength(1));
      final c = courses.single;
      expect(c.hasCustomTime, isTrue);
      expect(c.startTime, '08:20');
      expect(c.endTime, '12:00');
      expect(c.startSection, 1);
      expect(c.endSection, 4);
    });

    test('没有 isCustomTime 但给了钟点，也能推断出来', () {
      final courses = _parse([
        {
          'name': '连堂实验',
          'day': 2,
          'weeks': [5],
          'customStartTime': '13:00',
          'customEndTime': '16:40',
        },
      ]);
      expect(courses.single.hasCustomTime, isTrue);
      expect(courses.single.endTime, '16:40');
    });

    test('isCustomTime=true 但钟点非法 → 当作无自定义时间处理', () {
      final courses = _parse([
        {
          'name': '坏数据',
          'day': 2,
          'startSection': 1,
          'endSection': 2,
          'weeks': [1],
          'isCustomTime': true,
          'customStartTime': 'oops',
          'customEndTime': '',
        },
      ]);
      expect(courses.single.hasCustomTime, isFalse);
      expect(courses.single.startTime, '');
    });

    test('isCustomTime=false 即使给了钟点也不采纳', () {
      final courses = _parse([
        {
          'name': '显式关闭',
          'day': 2,
          'startSection': 1,
          'endSection': 2,
          'weeks': [1],
          'isCustomTime': false,
          'customStartTime': '08:20',
          'customEndTime': '10:00',
        },
      ]);
      expect(courses.single.hasCustomTime, isFalse);
    });

    test('既无节次又无钟点 → 仍然丢弃（无据可依）', () {
      final courses = _parse([
        {
          'name': '无信息',
          'day': 2,
          'weeks': [1],
        },
      ]);
      expect(courses, isEmpty);
    });

    test('缺 name / day / weeks 仍然丢弃', () {
      final courses = _parse([
        {'day': 1, 'startSection': 1, 'endSection': 1, 'weeks': [1]},
        {
          'name': 'x',
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
        },
        {
          'name': 'y',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
        },
      ]);
      expect(courses, isEmpty);
    });

    test('position 缺失时回退 location，再回退占位文案', () {
      final courses = _parse([
        {
          'name': 'a',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
          'location': 'B303',
        },
        {
          'name': 'b',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
        },
      ]);
      expect(courses[0].location, 'B303');
      expect(courses[1].location, '未知地点');
    });

    test('周次去重排序并丢弃越界值', () {
      final courses = _parse([
        {
          'name': 'w',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [5, 1, 5, 999, 0, -2],
        },
      ]);
      expect(courses.single.customWeeks, [1, 5]);
    });

    test('非 Map 记录被跳过而不影响其余', () {
      final courses = _parse([
        'garbage',
        42,
        null,
        {
          'name': 'ok',
          'day': 1,
          'startSection': 1,
          'endSection': 1,
          'weeks': [1],
        },
      ]);
      expect(courses, hasLength(1));
      expect(courses.single.name, 'ok');
    });

    test('空数组返回空列表', () {
      expect(_parse([]), isEmpty);
    });
  });
}
