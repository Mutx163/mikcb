import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/domain/schedule_list_grouping.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/storage_service.dart';

/// 回归钉（第二十四轮，钟点排序仍有几份副本在用 `String.compareTo`）：
///
/// `domain/clock_order.dart:5-11` 把这条规则的来由写得很清楚：
/// `Course.fromJson`（models/course.dart:298）与 `ScheduleItem.fromJson`
/// （models/schedule_item.dart:226 `json['startTime'] as String? ?? '08:00'`）
/// 都是**原样收下**，"备份 JSON、局域网传输包、别的工具导出的课表里 `9:00` 很常见"，
/// 而字符串序下 `"10:00" < "9:00"`。第七轮为此立了正源 `compareClockText`，
/// 并把当时的两处排序改了过去（`schedule_item_expander.dart:82/89`、
/// `schedule_list_grouping.dart:107/114`）。**剩下的副本没跟着改**，
/// 其中最刺眼的是同一个文件里的 `_sortPast`（:135）—— 同一个类里
/// "即将到来"用正源、"已过期"用字典序。
///
/// 写路径也不补零：`_normalizeScheduleItem`（timetable_provider.dart:4098-4120）
/// 只 trim 标题/地点/备注并归一日期，**不碰 startTime/endTime**，
/// 所以外来数据里的 `9:00` 会一路留在 `_scheduleItems` 里。
///
/// 复核后**排除**的两处（避免误修）：
/// * `timetable_screen.dart:4627` 排的是 `Exam.startTime`，而 `Exam.fromJson`
///   （models/exam.dart:168）走 `normalizeTimeOfDay(...)` → 恒为补零串，安全；
/// * `timetable_provider.dart:4312 getCurrentCourse()` / `:4375 getNextCourse()`
///   确实用字典序比钟点，但**全仓零调用方**（`storage_service.dart:925/941` 那两个
///   同名方法是另一个类的另一个签名）→ 属死代码，不是可达缺陷。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ScheduleItem item({
    required String id,
    required DateTime startDate,
    required String startTime,
    required String endTime,
    DateTime? endDate,
  }) => ScheduleItem(
    id: id,
    title: '日程$id',
    startDate: startDate,
    endDate: endDate ?? startDate,
    startTime: startTime,
    endTime: endTime,
    createdAt: DateTime(2026, 8),
    updatedAt: DateTime(2026, 8),
  );

  group('已过期日程的排序按分钟数而不是字典序', () {
    test('同日两条已过期日程：晚的在前，9:00 不会因为 '
        '\'9\' > \'1\' 被当成最晚', () {
      // 参考时刻 2026-09-10 12:00；两条日程都在 09-09 结束 → 都是 past。
      final groups = ScheduleListGrouper.group([
        item(
          id: 'late',
          startDate: DateTime(2026, 9, 9),
          endDate: DateTime(2026, 9, 9),
          startTime: '10:00',
          endTime: '11:00',
        ),
        item(
          id: 'early',
          startDate: DateTime(2026, 9, 9),
          endDate: DateTime(2026, 9, 9),
          startTime: '9:00',
          endTime: '9:45',
        ),
      ], DateTime(2026, 9, 10, 12));

      expect(groups.past, hasLength(2));
      // 「已过期：结束日期新的在前，同日按开始时间倒序」——同一天时，
      // 10:00 那条应当排在 9:00 之前。字典序下 '10:00' < '9:00'，
      // 倒序就把 9:00 排到了前面（修复前的实际结果）。
      expect(groups.past.first.item.id, 'late');
      expect(groups.past.last.item.id, 'early');
    });

    test('同一天三条混着补零与不补零，顺序仍按真实钟点倒序', () {
      final groups = ScheduleListGrouper.group([
        item(
          id: 'a',
          startDate: DateTime(2026, 9, 9),
          startTime: '8:45',
          endTime: '9:00',
        ),
        item(
          id: 'b',
          startDate: DateTime(2026, 9, 9),
          startTime: '14:00',
          endTime: '15:00',
        ),
        item(
          id: 'c',
          startDate: DateTime(2026, 9, 9),
          startTime: '09:30',
          endTime: '10:00',
        ),
      ], DateTime(2026, 9, 10, 12));

      expect(
        groups.past.map((entry) => entry.item.id).toList(),
        ['b', 'c', 'a'],
      );
    });
  });

  group('日程列表（provider 存量顺序）按分钟数排序', () {
    late TimetableProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = TimetableProvider(
        storageService: StorageService.forTesting(),
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await provider.initialize();
    });

    test('外来数据里的 9:00 不会排在 10:00 之后', () async {
      // 同一天的两条日程：字典序下 '10:00' < '9:00' → 10:00 被排到前面。
      await provider.addScheduleItem(
        item(
          id: 'late',
          startDate: DateTime(2026, 9, 9),
          startTime: '10:00',
          endTime: '11:00',
        ),
      );
      await provider.addScheduleItem(
        item(
          id: 'early',
          startDate: DateTime(2026, 9, 9),
          startTime: '9:00',
          endTime: '9:45',
        ),
      );

      final ids = provider.scheduleItems.map((i) => i.id).toList();
      expect(
        ids.indexOf('early'),
        lessThan(ids.indexOf('late')),
        reason: '同日两条日程应按真实钟点升序：$ids',
      );
    });

    test('改一条日程之后整列仍然有序（排序发生在写入点，不只在读侧）', () async {
      await provider.addScheduleItem(
        item(
          id: 'x',
          startDate: DateTime(2026, 9, 9),
          startTime: '8:00',
          endTime: '8:45',
        ),
      );
      await provider.addScheduleItem(
        item(
          id: 'y',
          startDate: DateTime(2026, 9, 9),
          startTime: '13:00',
          endTime: '14:00',
        ),
      );
      await provider.addScheduleItem(
        item(
          id: 'z',
          startDate: DateTime(2026, 9, 9),
          startTime: '9:30',
          endTime: '10:00',
        ),
      );

      expect(
        provider.scheduleItems.map((i) => i.id).toList(),
        ['x', 'z', 'y'],
      );
    });

    test('profile 里存的外来钟点在 initialize 之后仍按分钟序给出', () async {
      // 走真实的 fromJson 读路径：先落一份含未补零钟点的存档，再重新装配 provider。
      final storage = StorageService.forTesting();
      final seeded = TimetableProvider(
        storageService: storage,
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await seeded.initialize();
      await seeded.addScheduleItem(
        item(
          id: 'p',
          startDate: DateTime(2026, 9, 9),
          startTime: '9:00',
          endTime: '9:45',
        ),
      );
      await seeded.addScheduleItem(
        item(
          id: 'q',
          startDate: DateTime(2026, 9, 9),
          startTime: '10:00',
          endTime: '11:00',
        ),
      );

      final reopened = TimetableProvider(
        storageService: storage,
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      await reopened.initialize();

      final ids = reopened.scheduleItems.map((i) => i.id).toList();
      expect(
        ids.first,
        'p',
        reason: '重新读盘后的顺序也必须按真实钟点：$ids',
      );
      expect(ids, ['p', 'q']);
    });
  });
}
