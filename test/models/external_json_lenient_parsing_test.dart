import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/partner_timetable_binding.dart';
import 'package:university_timetable/models/timetable_profile.dart';

/// 2026-10-08 审核实测：这几处是**裸强制转换**，而它们都在**外部数据的入口**上
/// （教务 CSV / ICS / .mikcb 备份 / 局域网 / WebDAV 恢复）。
/// 一个字段类型不对就抛 TypeError；在备份恢复那条路上，
/// `data_transfer_service.dart` 的 `_parseListWithTotalLossGuard` 会把
/// 「解析结果为空」当成整份文件全损 → 抛 `unrecognized_mikcb_data_file`，
/// 于是**一条课程坏掉，整份备份都恢复不出来**。
///
/// 同族的局域网路径早就改成了 `(json[k] as String?)?.trim() ?? ''`
/// （`lan_edit_provider_host.dart:522-525`），此前两个解析器并不一致。
void main() {
  group('Course.fromJson：字段类型不对不再带走整份备份', () {
    Map<String, dynamic> base() => <String, dynamic>{
          'id': 'c-1',
          'name': '高等数学',
          'teacher': '张老师',
          'location': 'A101',
          'dayOfWeek': 1,
          'startSection': 1,
          'endSection': 2,
          'startTime': '08:00',
          'endTime': '09:40',
        };

    test('正常数据解析不变', () {
      final c = Course.fromJson(base());
      expect(c.id, 'c-1');
      expect(c.name, '高等数学');
      expect(c.teacher, '张老师');
      expect(c.location, 'A101');
      expect(c.startTime, '08:00');
    });

    test('name 是数字时收下它，而不是抛异常', () {
      final c = Course.fromJson({...base(), 'name': 123});
      expect(c.name, '123');
    });

    test('整份坏字段缺失会抛（好让「坏条目留档」自愈机制接住）', () {
      // ⚠️ 必填字段缺失**不能**一律放宽：本仓有一条「坏条目留档、不写回」的
      // 自愈机制（storage_service_profiles_integrity_test.dart:104 钉着），
      // 它靠「解析器对结构性缺失抛错」把可疑记录留档。放宽了就再也留不下档。
      expect(
        () => Course.fromJson(<String, dynamic>{}),
        throwsA(isA<FormatException>()),
      );
    });

    test('location 缺失抛错（必填字段，不是空串）', () {
      final json = base()..remove('location');
      expect(
        () => Course.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('teacher 缺失同样抛错', () {
      final json = base()..remove('teacher');
      expect(
        () => Course.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('description 缺失时回落到旧键 note（且 note 是数字也不抛）', () {
      final c = Course.fromJson({...base(), 'note': 456});
      expect(c.description, '456');
      expect(c.note, '456');
    });

    test('courseNature 类型不对不抛，退回默认', () {
      final c = Course.fromJson({...base(), 'courseNature': 7});
      expect(c.courseNature, isNotNull);
    });

    test('timeSchemeIdOverride 是数字时收下它', () {
      final c = Course.fromJson({...base(), 'timeSchemeIdOverride': 9});
      expect(c.timeSchemeIdOverride, '9');
    });
  });

  group('TimetableProfile.fromJson：id 缺失/类型不对一律拒收（口径刻意）', () {
    // ⚠️ 与 Course 的宽松口径**相反**，这是刻意的：一份课表 = 课 + 考试 +
    // 作业 + 设置，静默丢掉整档比拒收整份危险得多
    // （`full_backup_profile_salvage_test.dart:72` 钉着这条）。
    // 本次只把裸 `as String` 换成显式类型判定 ——
    // TypeError 变成可读的 FormatException，拒收的口径一个字没放松。
    test('数字型 id 抛 FormatException（不是 TypeError）', () {
      expect(
        () => TimetableProfile.fromJson(<String, dynamic>{
          'id': 12345,
          'name': '我的课表',
        }),
        throwsA(
          isA<FormatException>()
              .having((e) => e.message, 'message', 'profile_id_invalid'),
        ),
      );
    });

    test('id 缺失同样拒收', () {
      expect(
        () => TimetableProfile.fromJson(<String, dynamic>{'name': '我的课表'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('id 是字符串时正常解析', () {
      final p = TimetableProfile.fromJson(<String, dynamic>{
        'id': 'p-1',
        'name': '我的课表',
      });
      expect(p.id, 'p-1');
      expect(p.name, '我的课表');
    });

    test('name 类型不对退回「未命名课表」（这条仍是宽松的）', () {
      final p = TimetableProfile.fromJson(<String, dynamic>{
        'id': 'p-1',
        'name': 42,
      });
      expect(p.name, '未命名课表');
    });
  });

  group('PartnerTimetableBinding.fromJson：脏数据不再让绑定读不出来', () {
    test('类型不对（有值）也能构造', () {
      final b = PartnerTimetableBinding.fromJson(<String, dynamic>{
        'partnerProfileId': 123,
        'partnerName': 456,
        'linkedAt': 789,
        'mineColorHex': 1,
      });
      expect(b.partnerProfileId, '123');
      expect(b.partnerName, '456');
      // linkedAt 解析不了就用现在，不抛。
      expect(b.linkedAt, isNotNull);
      expect(b.mineColorHex, '1');
    });

    test('颜色缺失退回默认色', () {
      final b = PartnerTimetableBinding.fromJson(<String, dynamic>{
        'partnerProfileId': 'p-2',
      });
      expect(b.mineColorHex, '#2196F3');
      expect(b.partnerColorHex, '#E91E63');
      expect(b.togetherColorHex, '#9C27B0');
      expect(b.partnerName, 'TA的课表');
    });
  });
}