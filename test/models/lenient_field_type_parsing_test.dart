import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/course_task.dart';
import 'package:university_timetable/models/location_time_group.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';

/// 2026-10-19 审核补充：CourseTask / ScheduleItem / TimetableProfile 的
/// `fromJson` 此前还残留裸强制转换（`json['x'] as String` 系），而这三个模型
/// 都在**外部数据入口**上（云同步 profile / .mikcb 备份 / 局域网传输包）。
///
/// 期望值口径（与 test/models/external_json_lenient_parsing_test.dart 一致，
/// 由「必填缺失要抛、类型不对但有值要收」的既定设计推出来，不是从实现抄）：
/// - 身份字段 `id`：缺失或空白 → FormatException（坏条目留档机制靠它接住）；
/// - 其余字符串字段：类型不对但有值 → toString 收下；确实没有 → 默认值；
/// - bool 字段：'true'/'false' 这类字符串无法安全映射 → 退缺省，不猜；
/// - 合法数据的解析结果与序列化输出必须与改动前逐字节一致（格式冻结）。
void main() {
  group('CourseTask.fromJson：字段类型不符不再丢整条任务', () {
    test('数字型 title / courseId / note 都按 toString 收下', () {
      final task = CourseTask.fromJson(<String, dynamic>{
        'id': 'task-1',
        'title': 12345,
        'courseId': 42,
        'note': 9.5,
      });
      expect(task.id, 'task-1');
      expect(task.title, '12345');
      expect(task.courseId, '42');
      expect(task.note, '9.5');
      expect(task.isCompleted, isFalse);
      expect(task.source, CourseTaskSource.manual);
    });

    test('字符串型 sourceWeek 与数字型 sourceWeek 都能解析', () {
      expect(
        CourseTask.fromJson({'id': 'a', 'sourceWeek': '7'}).sourceWeek,
        7,
      );
      expect(
        CourseTask.fromJson({'id': 'a', 'sourceWeek': 12}).sourceWeek,
        12,
      );
      // 解析不了的字符串 → null，而不是抛。
      expect(
        CourseTask.fromJson({'id': 'a', 'sourceWeek': '第三周'}).sourceWeek,
        isNull,
      );
    });

    test('字符串型 isCompleted 无法安全映射，退缺省 false（不猜）', () {
      expect(
        CourseTask.fromJson({'id': 'a', 'isCompleted': 'true'}).isCompleted,
        isFalse,
      );
      // 真 bool 的两种取值都保持原语义。
      expect(
        CourseTask.fromJson({'id': 'a', 'isCompleted': true}).isCompleted,
        isTrue,
      );
      expect(
        CourseTask.fromJson({'id': 'a', 'isCompleted': false}).isCompleted,
        isFalse,
      );
    });

    test('未知 source 枚举值退 manual（既有 fromValue 口径）', () {
      expect(
        CourseTask.fromJson({'id': 'a', 'source': 'homework_mark'}).source,
        CourseTaskSource.homeworkMark,
      );
      expect(
        CourseTask.fromJson({'id': 'a', 'source': 7}).source,
        CourseTaskSource.manual,
      );
    });

    test('字符串型 dueDate 照常解析；毫秒数字不炸、退 null', () {
      expect(
        CourseTask.fromJson({'id': 'a', 'dueDate': '2026-11-05'}).dueDate,
        DateTime(2026, 11, 5),
      );
      expect(
        CourseTask.fromJson({'id': 'a', 'dueDate': 1730000000000}).dueDate,
        isNull,
      );
    });

    test('id 缺失 / 空白抛 FormatException（坏条目留档机制依赖）', () {
      expect(
        () => CourseTask.fromJson(<String, dynamic>{'title': 'x'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CourseTask.fromJson(<String, dynamic>{'id': '   '}),
        throwsA(isA<FormatException>()),
      );
    });

    test('数字型 id 收下为 toString（有值不丢）', () {
      expect(CourseTask.fromJson({'id': 123}).id, '123');
    });

    test('合法数据 round-trip：序列化输出逐键不变（格式冻结）', () {
      final task = CourseTask(
        id: 'task-9',
        title: '交作业',
        courseId: 'c-1',
        sourceWeek: 3,
        dueDate: DateTime(2026, 11, 8, 18),
        note: '记得带',
        isCompleted: true,
        source: CourseTaskSource.homeworkMark,
        createdAt: DateTime(2026, 11, 1, 9),
        updatedAt: DateTime(2026, 11, 2, 10),
      );
      final json = task.toJson();
      final restored = CourseTask.fromJson(json);
      expect(restored.toJson(), json);
    });
  });

  group('ScheduleItem.fromJson：字段类型不符不再丢整条日程', () {
    test('数字型 title/location 按 toString 收下，字符串时间照常', () {
      final item = ScheduleItem.fromJson(<String, dynamic>{
        'id': 'item-1',
        'title': 99,
        'location': 7,
        'startTime': '09:30',
        'endTime': '10:20',
        'color': '#123456',
        'startDate': '2026-10-01',
        'endDate': '2026-12-31',
        'recurrence': 'weekly',
      });
      expect(item.id, 'item-1');
      expect(item.title, '99');
      expect(item.location, '7');
      expect(item.startTime, '09:30');
      expect(item.endTime, '10:20');
      expect(item.color, '#123456');
      expect(item.startDate, DateTime(2026, 10));
      expect(item.endDate, DateTime(2026, 12, 31));
      expect(item.recurrence, ScheduleRecurrence.weekly);
    });

    test('startTime/endTime 缺失退默认钟点（既有口径）', () {
      final item = ScheduleItem.fromJson({'id': 'a'});
      expect(item.startTime, '08:00');
      expect(item.endTime, '09:00');
    });

    test('id 缺失 / 空白抛 FormatException', () {
      expect(
        () => ScheduleItem.fromJson(<String, dynamic>{'title': 'x'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ScheduleItem.fromJson(<String, dynamic>{'id': ''}),
        throwsA(isA<FormatException>()),
      );
    });

    test('enabled：非 bool 退缺省 true；真 bool 的 false 仍生效', () {
      expect(ScheduleItem.fromJson({'id': 'a', 'enabled': 'no'}).enabled,
          isTrue);
      expect(ScheduleItem.fromJson({'id': 'a', 'enabled': false}).enabled,
          isFalse);
    });

    test('合法数据 round-trip：序列化输出逐键不变（格式冻结）', () {
      final item = ScheduleItem(
        id: 'item-9',
        title: '班会',
        location: 'A101',
        startDate: DateTime(2026, 10),
        endDate: DateTime(2026, 12, 31),
        startTime: '14:00',
        endTime: '15:00',
        createdAt: DateTime(2026, 9, 30, 8),
        updatedAt: DateTime(2026, 9, 30, 8),
        recurrence: ScheduleRecurrence.weekly,
        exceptionDates: [DateTime(2026, 10, 7)],
      );
      final json = item.toJson();
      final restored = ScheduleItem.fromJson(json);
      expect(restored.toJson(), json);
    });
  });

  group('TimetableProfile.fromJson：辅助时间戳不再弄丢整档课表', () {
    Map<String, dynamic> baseProfile() => <String, dynamic>{
          'id': 'p-1',
          'name': '大一上',
          'courses': [
            {
              'id': 'c-1',
              'name': '高等数学',
              'teacher': '张老师',
              'location': 'A101',
              'startTime': '08:00',
              'endTime': '09:40',
            },
          ],
          'currentWeek': 2,
        };

    test('毫秒型 createdAt 不再抛 TypeError，整档课表（课程）保住', () {
      final profile = TimetableProfile.fromJson(
        baseProfile()..['createdAt'] = 1730000000000,
      );
      expect(profile.id, 'p-1');
      expect(profile.courses, hasLength(1));
      expect(profile.courses.single.name, '高等数学');
      expect(profile.createdAt, isNotNull);
    });

    test('lastUsedAt 为对象等非法值同样不抛', () {
      final profile = TimetableProfile.fromJson(
        baseProfile()..['lastUsedAt'] = <String, dynamic>{'ms': 1},
      );
      expect(profile.id, 'p-1');
      expect(profile.lastUsedAt, isNotNull);
    });

    test('合法 ISO 时间戳解析不变', () {
      final profile = TimetableProfile.fromJson(
        baseProfile()
          ..['createdAt'] = '2026-03-22T09:00:00.000'
          ..['lastUsedAt'] = '2026-03-22T10:00:00.000',
      );
      expect(profile.createdAt, DateTime(2026, 3, 22, 9));
      expect(profile.lastUsedAt, DateTime(2026, 3, 22, 10));
    });
  });

  group('Course.fromJson：bool 字段字符串型不再炸整门课', () {
    // Course 的必填字段（id/name/teacher/location/startTime/endTime）缺失仍抛，
    // 这里只喂足必填、逐个污染 bool 字段。
    Map<String, dynamic> baseCourse() => <String, dynamic>{
          'id': 'c-1',
          'name': '高等数学',
          'teacher': '张老师',
          'location': 'A101',
          'startTime': '08:00',
          'endTime': '09:40',
        };

    test('字符串型 "true" 不抛、退缺省 false（不替用户猜真值）', () {
      final c = Course.fromJson({...baseCourse(), 'isOddWeek': 'true'});
      expect(c.isOddWeek, isFalse);
      expect(c.isEvenWeek, isFalse);
      expect(c.hasCustomTime, isFalse);
    });

    test('真 bool 的取值保持原语义', () {
      final c = Course.fromJson({
        ...baseCourse(),
        'isOddWeek': true,
        'isEvenWeek': false,
        'hasCustomTime': true,
      });
      expect(c.isOddWeek, isTrue);
      expect(c.isEvenWeek, isFalse);
      expect(c.hasCustomTime, isTrue);
    });
  });

  group('LocationTimeGroup.fromJson：数字型 sourceSchoolId 不再炸整组', () {
    test('数字型来源校 ID 按 toString 收下', () {
      final g = LocationTimeGroup.fromJson({'id': 'g', 'sourceSchoolId': 42});
      expect(g.sourceSchoolId, '42');
    });

    test('空白串仍归一为 null（既有 _cleanOptional 口径）', () {
      expect(
        LocationTimeGroup.fromJson({'id': 'g', 'sourceSchoolId': '  '})
            .sourceSchoolId,
        isNull,
      );
      expect(
        LocationTimeGroup.fromJson({'id': 'g'}).sourceSchoolId,
        isNull,
      );
    });
  });
}
