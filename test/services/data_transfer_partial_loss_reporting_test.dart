import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/data_transfer_service.dart';
import 'package:university_timetable/services/transfer_package.dart';

/// 2026-10-08 审核实测：`parseBackupJson` 原先只区分「全丢」与「没丢」，
/// 中间那档一路静默。
///
/// 后果链条：100 门课里坏掉 40 门 → 返回 60 门 → 导入路径把 `backup.courses`
/// **整份替换**进课表并写盘 → 界面报「导入成功」→ 用户下次打开才发现少了
/// 几十节，而**原始文件已经被覆盖**，没有第二次核对的机会。
///
/// 逐条跳过本身是对的（部分损坏仍要能救回能读的部分，比整份拒收友好），
/// 但不能一声不响。现在跳过条数会被记下来并带出。
void main() {
  Map<String, dynamic> goodCourse(String id, String name) => <String, dynamic>{
        'id': id,
        'name': name,
        'teacher': '王老师',
        'location': 'A101',
        'dayOfWeek': 1,
        'startSection': 1,
        'endSection': 2,
        'startTime': '08:00',
        'endTime': '09:40',
      };

  String buildJson({
    required List<Object?> courses,
    List<Object?> exams = const [],
  }) {
    return jsonEncode(<String, dynamic>{
      'app': 'mikcb',
      'schemaVersion': DataTransferService.schemaVersion,
      'profileName': '测试课表',
      'courses': courses,
      'exams': exams,
      'settings': <String, dynamic>{},
      'currentWeek': 1,
      'exportedAt': '2026-10-08T00:00:00.000',
      'packageType': TransferPackage.packageType,
      // `scope` 在 packageType 匹配时是必填的：缺失会抛 transfer_scope_invalid。
      'scope': 'all_data',
      'channel': 'file',
    });
  }

  final service = DataTransferService();

  test('全部完好：不报跳过', () {
    final backup = service.parseBackupJson(
      buildJson(courses: [
        goodCourse('c-1', '高等数学'),
        goodCourse('c-2', '线性代数'),
      ]),
    );
    expect(backup.courses.length, 2);
    expect(backup.droppedCounts, isEmpty);
    expect(backup.droppedTotal, 0);
  });

  test('部分损坏：救回能读的部分，并如实报出跳过条数', () {
    final backup = service.parseBackupJson(
      buildJson(courses: [
        goodCourse('c-1', '高等数学'),
        // 非 Map 条目 → 解析时 continue 跳过
        'garbage',
        goodCourse('c-2', '线性代数'),
        42,
        goodCourse('c-3', '大学物理'),
      ]),
    );

    expect(
      backup.courses.length,
      3,
      reason: '能救回 3 门就该救 3 门，不因两条坏数据整份拒收',
    );
    expect(
      backup.droppedTotal,
      2,
      reason: '跳过的两条必须被记下来，否则界面会报「导入成功」而用户少了课',
    );
    expect(backup.droppedCounts['courses'], 2);
  });

  test('全丢仍然拒收（口径不变：不能让原课表被清空）', () {
    expect(
      () => service.parseBackupJson(
        buildJson(courses: ['garbage', 42, null]),
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'unrecognized_mikcb_data_file',
        ),
      ),
    );
  });

  test('考试那一栏的跳过也单独记，不会混进课程计数', () {
    final backup = service.parseBackupJson(
      buildJson(
        courses: [goodCourse('c-1', '高等数学')],
        exams: [
          // 一条能解析的考试 + 一条坏的 ⇒ 部分丢，走「记下来」而不是拒收。
          <String, dynamic>{
            'id': 'e-1',
            'courseId': 'c-1',
            'name': '期中考试',
            'dateTime': '2026-11-02T09:00:00.000',
            'startTime': '09:00',
            'endTime': '11:00',
          },
          'bad-exam',
        ],
      ),
    );
    expect(backup.exams.length, 1);
    expect(backup.droppedCounts.containsKey('courses'), isFalse);
    expect(backup.droppedCounts['exams'], 1);
    expect(backup.droppedTotal, 1);
  });

  test('干净文件不会往 droppedCounts 里塞 0 项', () {
    final backup = service.parseBackupJson(
      buildJson(courses: [goodCourse('c-1', '高等数学')], exams: const []),
    );
    expect(backup.droppedCounts.containsKey('exams'), isFalse);
    expect(backup.droppedCounts.containsKey('courses'), isFalse);
  });
}