import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/services/course_recolor_history_service.dart';
import 'package:university_timetable/utils/course_color_palette.dart';
import 'package:university_timetable/utils/course_recolor.dart';

Course _course({
  required String id,
  required String name,
  String color = '#2196F3',
  int dayOfWeek = 1,
}) {
  return Course(
    id: id,
    name: name,
    teacher: '张老师',
    location: 'A101',
    dayOfWeek: dayOfWeek,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: color,
    startWeek: 1,
    endWeek: 16,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('空历史：未保存过时返回空状态', () async {
    final state = await CourseRecolorHistoryService.load('profile-1');
    expect(state.isEmpty, isTrue);
    expect(state.index, -1);
    expect(state.current, isNull);
  });

  test('保存/加载往返：种子记录+快照记录+导航指向', () async {
    final snapshot = captureCourseRecolorSnapshot(
      [_course(id: '1', name: 'A', color: '#E91E63')],
      now: DateTime(2026, 8, 30, 9, 0),
    );
    final seed = CourseRecolorScheme.seed(
      seed: 4242,
      colorGroupId: 'pastel',
      assignMatchingTextColor: true,
      createdAt: DateTime(2026, 8, 30, 9, 5),
    );

    await CourseRecolorHistoryService.save('profile-1', [snapshot, seed], 1);
    final state = await CourseRecolorHistoryService.load('profile-1');

    expect(state.schemes.length, 2);
    expect(state.index, 1);
    expect(state.canGoBack, isTrue);
    expect(state.canGoForward, isFalse);

    final loadedSnapshot = state.schemes[0];
    expect(loadedSnapshot.isSnapshot, isTrue);
    expect(
      loadedSnapshot.snapshotEntries!['name\u0000a'],
      snapshot.snapshotEntries!['name\u0000a'],
    );

    final loadedSeed = state.schemes[1];
    expect(loadedSeed.isSnapshot, isFalse);
    expect(loadedSeed.seed, 4242);
    expect(loadedSeed.colorGroupId, 'pastel');
    expect(loadedSeed.assignMatchingTextColor, isTrue);
  });

  test('作用域按课表 profile 隔离', () async {
    final seed = CourseRecolorScheme.seed(
      seed: 1,
      colorGroupId: kCourseColorGroupAllId,
      assignMatchingTextColor: false,
      createdAt: DateTime(2026, 8, 30),
    );
    await CourseRecolorHistoryService.save('profile-1', [seed], 0);

    final other = await CourseRecolorHistoryService.load('profile-2');
    expect(other.isEmpty, isTrue);

    final same = await CourseRecolorHistoryService.load('profile-1');
    expect(same.schemes.length, 1);
  });

  test('超过上限丢最旧记录，指向同步前移', () async {
    final schemes = [
      for (var i = 0; i < CourseRecolorHistoryService.maxSchemes + 5; i++)
        CourseRecolorScheme.seed(
          seed: i,
          colorGroupId: kCourseColorGroupAllId,
          assignMatchingTextColor: false,
          createdAt: DateTime(2026, 8, 30).add(Duration(minutes: i)),
        ),
    ];

    await CourseRecolorHistoryService.save(
      'profile-1',
      schemes,
      schemes.length - 1,
    );
    final state = await CourseRecolorHistoryService.load('profile-1');

    expect(
      state.schemes.length,
      CourseRecolorHistoryService.maxSchemes,
    );
    // 丢掉了最旧 5 条（含第 0 条种子 0），指向同步前移后仍指最后一套。
    expect(state.schemes.first.seed, 5);
    expect(state.schemes.last.seed, schemes.length - 1);
    expect(state.index, state.schemes.length - 1);
  });

  test('坏 JSON / 非 List 数据兜底为空历史', () async {
    SharedPreferences.setMockInitialValues({
      CourseRecolorHistoryService.schemesPreferenceKey('p1'): 'not-json',
      CourseRecolorHistoryService.schemesPreferenceKey('p2'): '{"a":1}',
    });

    expect((await CourseRecolorHistoryService.load('p1')).isEmpty, isTrue);
    expect((await CourseRecolorHistoryService.load('p2')).isEmpty, isTrue);
  });

  test('坏记录被跳过，好记录保留；指向缺省落到最后一套', () async {
    final good = CourseRecolorScheme.seed(
      seed: 7,
      colorGroupId: kCourseColorGroupAllId,
      assignMatchingTextColor: false,
      createdAt: DateTime(2026, 8, 30),
    );
    SharedPreferences.setMockInitialValues({
      CourseRecolorHistoryService.schemesPreferenceKey('p1'): jsonEncode([
        {'bad': 1},
        good.toJson(),
        {'createdAt': 'nope'},
      ]),
    });

    final state = await CourseRecolorHistoryService.load('p1');
    expect(state.schemes.length, 1);
    expect(state.schemes.single.seed, 7);
    expect(state.index, 0);
  });
}
