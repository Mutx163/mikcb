// 「杀进程重开」两阶段测试共用的数据定义。
//
// 为什么单独一个文件：写阶段与读阶段必须用**完全一样**的课程数据与名字，
// 各自抄一份迟早写歪（改了 A 忘了 B），而那种错会以「测试莫名变红」的形式
// 出现，排查成本远高于多一个文件。
//
// 注意：本文件不含 `main()`，不是测试文件本身——被两个测试文件 import。

import 'package:university_timetable/models/course.dart';

/// 跨进程存活验证所用的课程名。
///
/// 带 `itest_` 前缀与版本号，保证不与任何真实课程重名。
const String kPersistCourseName = 'itest_persist_course_v1';

/// 那门课的全部字段。
///
/// 星期/节次刻意选**默认值之外**（默认 1/1）：万一读取链路某处把字段丢了、
/// 回落到默认值，断言会立刻红，而不是因为「默认值恰好也是这个」假通过。
Course persistFixtureCourse() {
  return Course(
    id: 'itest-persist-course-0001',
    name: kPersistCourseName,
    teacher: '持久化测试',
    location: '测试地点B',
    dayOfWeek: 4,
    startSection: 6,
    endSection: 7,
    startTime: '14:00',
    endTime: '15:30',
    color: '#4CAF50',
  );
}
