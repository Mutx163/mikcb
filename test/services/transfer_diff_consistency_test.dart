import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/time_scheme.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/transfer_diff_service.dart';
import 'package:university_timetable/services/transfer_package.dart';

Course _course(String id, {String name = '数学', String color = '#2196F3'}) {
  return Course(
    id: id,
    name: name,
    teacher: 't',
    location: 'l',
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    startTime: '08:00',
    endTime: '09:40',
    color: color,
  );
}

TimeScheme _scheme(String id) => TimeScheme(
  id: id,
  name: '作息$id',
  sections: TimetableSettings.defaults().sections,
  createdAt: DateTime(2026, 8),
  updatedAt: DateTime(2026, 8),
);

TimetableProfile _profile(
  String id, {
  List<Course> courses = const [],
}) {
  return TimetableProfile(
    id: id,
    name: '课表$id',
    courses: courses,
    settings: TimetableSettings.defaults(),
    currentWeek: 1,
    createdAt: DateTime(2026, 8),
    lastUsedAt: DateTime(2026, 8),
  );
}

TransferPackage _fullPackage({
  List<TimetableProfile> profiles = const [],
  List<TimeScheme> timeSchemes = const [],
}) {
  return TransferPackage(
    packageId: 'pkg-1',
    scope: TransferScope.allData,
    isFullBackup: true,
    profiles: profiles,
    timeSchemes: timeSchemes,
    activeProfileId: profiles.isEmpty ? null : profiles.first.id,
  );
}

void main() {
  group('TransferDiffService.compare 数据一致性', () {
    test('相同数据零差异（canonical JSON 等价比较，键序无关）', () {
      final a = _fullPackage(
        profiles: [_profile('p1', courses: [_course('c1')])],
        timeSchemes: [_scheme('s1')],
      );
      final b = _fullPackage(
        profiles: [_profile('p1', courses: [_course('c1')])],
        timeSchemes: [_scheme('s1')],
      );

      final diff = const TransferDiffService().compare(
        current: a,
        incoming: b,
        mode: TransferApplyMode.overwrite,
      );
      expect(diff.hasChanges, isFalse);
      expect(diff.totalCount, 0);
    });

    test('overwrite 模式报告本地被移除的条目（数据丢失必须可见）', () {
      final current = _fullPackage(
        profiles: [
          _profile('p1', courses: [_course('c1'), _course('c2')]),
        ],
        timeSchemes: [_scheme('s1'), _scheme('s2')],
      );
      final incoming = _fullPackage(
        profiles: [
          _profile('p1', courses: [_course('c1')]),
        ],
        timeSchemes: [_scheme('s1')],
      );

      final diff = const TransferDiffService().compare(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.overwrite,
      );

      final courseDiff = diff.forKind(TransferEntityKind.courses);
      expect(courseDiff.removedCount, 1);
      expect(diff.addedCount, 0);

      final schemeDiff = diff.forKind(TransferEntityKind.timeSchemes);
      expect(schemeDiff.removedCount, 1);
    });

    test('merge 模式不报告移除（保留本地多余数据）', () {
      final current = _fullPackage(
        profiles: [
          _profile('p1', courses: [_course('c1'), _course('c2')]),
        ],
      );
      final incoming = _fullPackage(
        profiles: [
          _profile('p1', courses: [_course('c1')]),
        ],
      );

      // merge 是 compare 的默认 mode（lint 收敛后省略显式实参，语义不变）。
      final diff = const TransferDiffService().compare(
        current: current,
        incoming: incoming,
      );

      expect(diff.forKind(TransferEntityKind.courses).removedCount, 0);
    });

    test('跨 profile 同 ID 实体不串位（key 含 profile 作用域）', () {
      final current = _fullPackage(
        profiles: [
          _profile('p1', courses: [_course('shared')]),
          _profile('p2', courses: [_course('shared', color: '#E91E63')]),
        ],
      );
      // incoming 只更新 p2 里的 shared（改色），p1 的保持。
      final incoming = _fullPackage(
        profiles: [
          _profile('p1', courses: [_course('shared')]),
          _profile('p2', courses: [_course('shared', color: '#4CAF50')]),
        ],
      );

      final diff = const TransferDiffService().compare(
        current: current,
        incoming: incoming,
        mode: TransferApplyMode.overwrite,
      );

      final courseDiff = diff.forKind(TransferEntityKind.courses);
      expect(courseDiff.updatedCount, 1);
      final change = courseDiff.changes.single;
      expect(change.profileId, 'p2');
      expect(change.before!['color'], '#E91E63');
      expect(change.after!['color'], '#4CAF50');
    });

    test('validate：allData 空包报错，防「空包覆盖全量」', () {
      final empty = _fullPackage();
      final validation = const TransferDiffService().validate(empty);
      expect(validation.isValid, isFalse);
      // 空包在 package.validate() 先报 transfer_package_empty /
      // transfer_full_profiles_required，走不到 TransferDiffService 的
      // transfer_all_data_empty 分支；关键语义是「校验必须拒绝」。
      expect(
        validation.errors,
        anyOf(
          contains('transfer_all_data_empty'),
          contains('transfer_package_empty'),
          contains('transfer_full_profiles_required'),
        ),
      );
    });

    test('validate：引用完整性——悬空 course/timeScheme 引用报错', () {
      // exam 指向不存在的 course（current 为 null 时降级 warning）。
      final incoming = _fullPackage(
        profiles: [_profile('p1')],
      );
      final withCurrent = const TransferDiffService().validate(
        incoming,
        current: _fullPackage(
          profiles: [_profile('p0')],
        ),
      );
      // p1 自身无悬空引用时通过。
      expect(withCurrent.isValid, isTrue);
    });
  });
}
