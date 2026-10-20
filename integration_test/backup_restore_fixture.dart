// 「备份 → 清空 → 恢复 → 数据回来」两阶段测试共用的定义。
//
// 与 `persist_fixture.dart` / `settings_persist_fixture.dart` 同理：
// 两个阶段必须用完全一样的数据，各抄一份迟早写歪。
//
// 注意：本文件不含 `main()`，不是测试文件本身——被两个测试文件 import。

import 'package:university_timetable/models/course.dart';

/// 备份里那门课的**唯一标记名**。
const String kBackupCourseName = 'itest_backup_restore_course_v1';

/// 备份时的当前周次。
///
/// 选 7 而不是 1：默认值是 1（`TimetableSettings`/`StorageService` 的
/// `_currentWeekKey` 缺省即 1）。若恢复根本没发生、读到的是默认值 1，
/// 断言 `== 7` 会立刻红；写成 1 就变成永远绿。
const int kBackupFixtureWeek = 7;

/// 备份里那门课的全部字段。
///
/// 星期/节次刻意选**默认值之外**（默认 1/1）：万一恢复时某处把字段丢了、
/// 回落到默认值，断言会立刻红，而不是因为「默认值恰好也是这个」假通过。
Course backupFixtureCourse() {
  return Course(
    id: 'itest-backup-course-0001',
    name: kBackupCourseName,
    teacher: '备份测试老师',
    location: '备份测试地点',
    dayOfWeek: 5,
    startSection: 8,
    endSection: 9,
    startTime: '16:00',
    endTime: '17:30',
    color: '#9C27B0',
  );
}
