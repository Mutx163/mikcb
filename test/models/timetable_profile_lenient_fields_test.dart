import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// `TimetableProfile.fromJson` 里 `currentWeek` / `profileKind` 的容错口径。
///
/// 这两处是 2026-10-20 复核剩下的裸转：`currentWeek` 是 `as num?`（字符串型数字
/// 会抛 TypeError）、`profileKind` 是 `as String?`（数字 / 对象会抛）。而 fromJson
/// 在三条外部数据入口上（云同步快照 / .mikcb 全量备份 / 局域网传输包），一处抛错
/// 会被上层升级成「整份备份拒收」——手改备份里把周次写成 `"12"`、把 profileKind
/// 写成 `1`，都不该让整份数据消失。
///
/// 期望值口径与 `test/models/lenient_field_type_parsing_test.dart` 一致（由语义
/// 推出，不是从实现抄）：**有值就收**（数字字符串走 tryParse、double 截断），
/// **收不下按缺键处理**（非法枚举名回落默认值），**绝不猜值**。
void main() {
  Map<String, dynamic> profileJson({
    Object? currentWeek = _absent,
    Object? profileKind = _absent,
  }) {
    return <String, dynamic>{
      'id': 'profile-1',
      'name': '大一上',
      'courses': const [],
      'settings': TimetableSettings.defaults().toJson(),
      if (!identical(currentWeek, _absent)) 'currentWeek': currentWeek,
      if (!identical(profileKind, _absent)) 'profileKind': profileKind,
    };
  }

  group('TimetableProfile.fromJson 的 currentWeek / profileKind 不再裸转', () {
    test('缺字段：currentWeek 回落 1、profileKind 回落 normal，不抛', () {
      final profile = TimetableProfile.fromJson(profileJson());

      expect(profile.currentWeek, 1);
      expect(profile.profileKind, TimetableProfileKind.normal);
    });

    test('类型错：字符串型周次按数字收下、数字型 profileKind 回落 normal，不抛', () {
      final profile = TimetableProfile.fromJson(
        profileJson(currentWeek: '12', profileKind: 123),
      );

      // 「有值就收」：'12' → 12（与 lenientInt / CourseTask.sourceWeek 同口径）。
      expect(profile.currentWeek, 12);
      // 「绝不能映射」：数字不是枚举名，按缺键处理回落 normal，而不是猜成 1 号值。
      expect(profile.profileKind, TimetableProfileKind.normal);
    });

    test('非法枚举名：回落 normal，不抛', () {
      final profile = TimetableProfile.fromJson(
        profileJson(profileKind: 'nonsense'),
      );

      expect(profile.profileKind, TimetableProfileKind.normal);
    });

    test('合法值保持原语义：周次与 partnerImported 原样解析', () {
      final profile = TimetableProfile.fromJson(
        profileJson(currentWeek: 7, profileKind: 'partnerImported'),
      );

      expect(profile.currentWeek, 7);
      expect(profile.profileKind, TimetableProfileKind.partnerImported);
    });

    test('double 型周次截断（旧口径保持），不抛', () {
      final profile = TimetableProfile.fromJson(profileJson(currentWeek: 12.7));

      expect(profile.currentWeek, 12);
    });

    test('fromJsonLenient（坏档打捞路径）同口径：字符串周次与数字 kind 都不抛', () {
      final profile = TimetableProfile.fromJsonLenient(
        profileJson(currentWeek: '9', profileKind: 1),
      );

      expect(profile.currentWeek, 9);
      expect(profile.profileKind, TimetableProfileKind.normal);
    });
  });
}

/// 区分「显式传了 null」与「没传这个键」的哨兵。
const Object _absent = Object();
