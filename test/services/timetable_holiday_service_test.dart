import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/holiday_resolver.dart';
import 'package:university_timetable/models/holiday_entry.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/holiday_service.dart';
import 'package:university_timetable/services/timetable_holiday_service.dart';

HolidayEntry _entry(
  String date,
  String name, {
  HolidayType type = HolidayType.vacation,
  String? groupId,
}) => HolidayEntry(
  date: DateTime.parse(date),
  name: name,
  type: type,
  groupId: groupId,
);

HolidayData _data(int year, List<HolidayEntry> entries) =>
    HolidayData(year: year, version: 7, entries: entries);

class _FakeHolidayPort implements TimetableHolidayPort {
  _FakeHolidayPort({this.customHolidays = const []});

  final Map<int, HolidayData> remote = {};
  List<HolidayEntry>? customHolidays;
  bool failFetch = false;
  bool failSave = false;

  @override
  HolidayData? holidayData;

  @override
  TimetableSettings settings = TimetableSettings.defaults();

  /// 记录副作用顺序，断言「先通知界面、再重置签名、最后重推 live surface」。
  final List<String> events = [];
  final List<int> fetchedYears = [];
  final List<int> clearedYears = [];
  int saveCount = 0;

  @override
  Future<HolidayData> fetchHolidayData(int year) async {
    fetchedYears.add(year);
    if (failFetch) {
      throw StateError('network down');
    }
    return remote[year] ?? _data(year, const []);
  }

  @override
  Future<void> clearCache(int year) async {
    clearedYears.add(year);
  }

  @override
  Future<List<HolidayEntry>?> loadCustomHolidays() async {
    // 与真实 HolidayService 一致：每次返回新列表，调用方 append 不会
    // 顺手改掉端口里那一份。
    final current = customHolidays;
    return current == null ? null : List<HolidayEntry>.of(current);
  }

  @override
  Future<void> saveCustomHolidays(List<HolidayEntry> entries) async {
    saveCount += 1;
    if (failSave) {
      throw const HolidayCustomSaveException('disk full');
    }
    customHolidays = entries;
  }

  @override
  Future<void> addCustomHoliday(HolidayEntry entry) async {
    customHolidays = [...?customHolidays, entry];
  }

  @override
  Future<void> removeCustomHoliday(String groupId) async {
    customHolidays = (customHolidays ?? const [])
        .where((entry) => entry.groupId != groupId)
        .toList();
  }

  @override
  Future<void> updateCustomHoliday(
    String groupId,
    List<HolidayEntry> newEntries,
  ) async {
    customHolidays = [
      ...(customHolidays ?? const [])
          .where((entry) => entry.groupId != groupId),
      ...newEntries,
    ];
  }

  @override
  Future<T> runLiveSurfaceExclusive<T>(Future<T> Function() action) async {
    events.add('gate-enter');
    final result = await action();
    events.add('gate-exit');
    return result;
  }

  @override
  void resetLiveSurfaceTracking() => events.add('reset');

  @override
  Future<void> updateLiveActivity() async => events.add('live');

  @override
  void notifyStateChanged() => events.add('notify');
}

void main() {
  test('load 合并当前年 + 跨年邻年 + 自定义条目，并按序重推 live surface', () async {
    final port = _FakeHolidayPort(
      customHolidays: [
        _entry('2027-01-05', '用户自建假', groupId: 'custom-1'),
      ],
    );
    port.remote[2026] = _data(2026, [
      _entry('2026-10-01', '国庆节', groupId: 'national-day-2026'),
    ]);
    port.remote[2027] = _data(2027, [
      _entry('2027-01-01', '元旦', groupId: 'new-year-2027'),
    ]);
    // 2026-12-30 所在周跨年：必须把 2027 的元旦那一段一起取回。
    final service = TimetableHolidayService(
      port,
      now: () => DateTime(2026, 12, 30),
    );

    await service.load();

    expect(port.fetchedYears, containsAll(<int>[2026, 2027]));
    final loaded = port.holidayData;
    expect(loaded, isNotNull);
    expect(loaded!.year, 2026);
    expect(
      loaded.entries.map((entry) => entry.name).toList(),
      ['国庆节', '元旦', '用户自建假'],
    );
    expect(port.events, ['gate-enter', 'notify', 'reset', 'live', 'gate-exit']);
    expect(
      loaded.isHoliday(DateTime.parse('2026-10-01')),
      isTrue,
      reason: '合并后的假期数据必须能被展示判定直接使用',
    );
  });

  test('load 失败只留痕：不覆盖已加载数据、不通知、不重推 live surface', () async {
    final port = _FakeHolidayPort();
    port.remote[2026] = _data(2026, [_entry('2026-10-01', '国庆节')]);
    port.failFetch = true;
    final existing = _data(2025, [_entry('2025-10-01', '旧数据')]);
    port.holidayData = existing;
    final service = TimetableHolidayService(
      port,
      now: () => DateTime(2026, 10, 19),
    );

    await service.load();

    expect(port.holidayData, same(existing));
    expect(port.events, ['gate-enter', 'gate-exit']);
  });

  test('自定义假期存储损坏时 addCustomHolidays 拒写，不落盘也不触发重载', () async {
    final port = _FakeHolidayPort(customHolidays: null);
    final service = TimetableHolidayService(
      port,
      now: () => DateTime(2026, 10, 19),
    );

    await expectLater(
      service.addCustomHolidays([_entry('2026-12-31', '自建假')]),
      throwsA(isA<HolidayCustomSaveException>()),
    );
    expect(port.saveCount, 0);
    expect(port.fetchedYears, isEmpty, reason: '拒写后不得进入加载路径');
  });

  test('落盘失败上抛，且不把本次条目当成已保存', () async {
    final port = _FakeHolidayPort(customHolidays: <HolidayEntry>[]);
    port.failSave = true;
    final service = TimetableHolidayService(
      port,
      now: () => DateTime(2026, 10, 19),
    );

    await expectLater(
      service.addCustomHolidays([_entry('2026-12-31', '自建假')]),
      throwsA(isA<HolidayCustomSaveException>()),
    );
    expect(port.customHolidays, isEmpty);
    expect(port.fetchedYears, isEmpty);
  });

  test('addCustomHoliday / removeCustomHoliday / updateCustomHoliday 都走「写后重载」', () async {
    final port = _FakeHolidayPort(
      customHolidays: [
        _entry('2026-12-31', '旧名', groupId: 'g1'),
      ],
    );
    port.remote[2026] = const HolidayData(year: 2026, version: 1, entries: []);
    final service = TimetableHolidayService(
      port,
      now: () => DateTime(2026, 10, 19),
    );

    await service.addCustomHoliday(_entry('2027-01-02', '新增', groupId: 'g2'));
    expect(port.holidayData!.entries, hasLength(2));

    await service.updateCustomHoliday('g1', [
      _entry('2026-12-31', '新名', groupId: 'g1'),
    ]);
    expect(
      port.holidayData!.entries.singleWhere((e) => e.groupId == 'g1').name,
      '新名',
    );

    await service.removeCustomHoliday('g2');
    expect(port.holidayData!.entries, hasLength(1));
    expect(port.fetchedYears.length, 3, reason: '三个写入口各触发一次重载');
  });

  test('refresh 先清 holidayYearsToLoad 覆盖的年份再重载', () async {
    final port = _FakeHolidayPort();
    port.remote[2026] = const HolidayData(year: 2026, version: 1, entries: []);
    final now = DateTime(2026, 10, 19);
    final service = TimetableHolidayService(port, now: () => now);

    await service.refresh();

    expect(port.clearedYears.toSet(), holidayYearsToLoad(now));
    expect(port.fetchedYears, containsAll(holidayYearsToLoad(now)));
  });

  test('损坏的自定义假期：只读口区分「暂无」与「损坏」', () async {
    final port = _FakeHolidayPort(customHolidays: null);
    final service = TimetableHolidayService(port);

    expect(await service.getCustomHolidays(), isEmpty);
    expect(await service.loadCustomHolidaysOrNull(), isNull);
  });

  test('isHoliday / isAdjustedWorkday 用端口上的数据与设置判定', () async {
    final port = _FakeHolidayPort();
    port.holidayData = _data(2026, [
      _entry('2026-10-01', '国庆节'),
      _entry(
        '2026-10-11',
        '调休上班',
        type: HolidayType.adjustedWorkday,
      ),
    ]);
    final service = TimetableHolidayService(port);

    expect(service.isHoliday(DateTime.parse('2026-10-01')), isTrue);
    expect(service.isAdjustedWorkday(DateTime(2026, 10, 11)), isTrue);
    expect(service.isHoliday(DateTime(2026, 10, 11)), isFalse);
    expect(service.getHolidayForDate(DateTime.parse('2026-10-01'))?.name, '国庆节');

    // 假期标记关闭时不隐藏课程（设置读自端口）。
    port.settings = port.settings.copyWith(enableHolidayMarking: false);
    expect(service.isHoliday(DateTime.parse('2026-10-01')), isFalse);
  });
}
