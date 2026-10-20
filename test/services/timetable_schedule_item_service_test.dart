import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/course.dart';
import 'package:university_timetable/models/schedule_item.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_schedule_item_service.dart';

/// 假端口：日程与课表放内存里，钩子只记次数。
class _FakePort implements TimetableScheduleItemPort {
  _FakePort({
    List<ScheduleItem> items = const <ScheduleItem>[],
    List<TimetableProfile> profiles = const <TimetableProfile>[],
  }) : _items = List<ScheduleItem>.from(items),
       _profiles = List<TimetableProfile>.from(profiles);

  List<ScheduleItem> _items;
  List<TimetableProfile> _profiles;

  int itemWrites = 0;
  int profileWrites = 0;
  int persistCalls = 0;
  int notifyCalls = 0;
  int syncCalls = 0;
  int initializeCalls = 0;
  bool failPersist = false;
  final List<String> events = <String>[];
  final Map<String, Map<String, Object>> eventPayloads =
      <String, Map<String, Object>>{};

  @override
  List<ScheduleItem> get scheduleItems => _items;

  @override
  set scheduleItems(List<ScheduleItem> value) {
    _items = value;
    itemWrites++;
  }

  @override
  List<TimetableProfile> get profiles => _profiles;

  @override
  set profiles(List<TimetableProfile> value) {
    _profiles = value;
    profileWrites++;
  }

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<void> persistActiveProfileState() async {
    persistCalls++;
    if (failPersist) {
      throw StateError('disk down');
    }
  }

  @override
  void notifyStateChanged() => notifyCalls++;

  @override
  void logEvent(String name, Map<String, Object> parameters) {
    events.add(name);
    eventPayloads[name] = parameters;
  }

  @override
  Future<void> syncExamReminders() async => syncCalls++;
}

final DateTime _day1 = DateTime(2026, 10, 20);
final DateTime _day2 = DateTime(2026, 10, 27);

ScheduleItem _item(
  String id, {
  String title = '事项',
  String startTime = '08:00',
  String? seriesId,
  DateTime? startDate,
  DateTime? endDate,
  ScheduleRecurrence recurrence = ScheduleRecurrence.none,
  Iterable<DateTime> exceptions = const <DateTime>[],
  DateTime? occurrenceDate,
}) {
  return ScheduleItem(
    id: id,
    title: title,
    startTime: startTime,
    endTime: '09:00',
    startDate: startDate ?? _day1,
    endDate: endDate ?? startDate ?? _day1,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    recurrence: recurrence,
    exceptionDates: exceptions,
    seriesId: seriesId,
    occurrenceDate: occurrenceDate,
  );
}

TimetableProfile _profile(String id) => TimetableProfile(
  id: id,
  name: '课表$id',
  courses: const <Course>[],
  settings: TimetableSettings.defaults(),
  currentWeek: 1,
  createdAt: DateTime(2026),
  lastUsedAt: DateTime(2026),
);

void main() {
  group('sort：钟点按分钟比，不按字典序', () {
    test('9:00 排在 10:00 前面（外来存档会原样收下 9:00）', () {
      final items = <ScheduleItem>[
        _item('late', startTime: '10:00'),
        _item('early', startTime: '9:00'),
      ];

      final sorted = TimetableScheduleItemService.sort(items);

      expect(sorted.map((item) => item.id), <String>['early', 'late']);
    });

    test('同一天同一钟点按 id 稳定排', () {
      final items = <ScheduleItem>[
        _item('b'),
        _item('a'),
      ];

      final sorted = TimetableScheduleItemService.sort(items);

      expect(sorted.map((item) => item.id), <String>['a', 'b']);
    });
  });

  group('normalize：落盘前归一', () {
    test('trim 文本、空串归 null、结束日不早于开始日', () {
      final item = ScheduleItem(
        id: 'x',
        title: '  写论文  ',
        location: '   ',
        note: '',
        startTime: '08:00',
        endTime: '09:00',
        startDate: DateTime(2026, 10, 20, 13, 45),
        endDate: DateTime(2026, 10, 18, 9, 30),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final normalized = TimetableScheduleItemService.normalize(item);

      expect(normalized.title, '写论文');
      expect(normalized.location, isNull);
      expect(normalized.note, isNull);
      expect(normalized.startDate, DateTime(2026, 10, 20));
      expect(normalized.endDate, DateTime(2026, 10, 20));
    });
  });

  group('add：归一 + 排序 + 落盘 + 通知 + 埋点 + 提醒同步', () {
    test('新日程进列表并落盘', () async {
      final port = _FakePort(
        items: <ScheduleItem>[_item('a', startTime: '10:00')],
      );

      await TimetableScheduleItemService.add(
        port,
        _item('b', title: '  新事项  ', startTime: '9:00'),
      );

      expect(port.initializeCalls, 1);
      expect(port.scheduleItems.map((item) => item.id), <String>['b', 'a']);
      expect(port.scheduleItems.first.title, '新事项');
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.events, <String>['schedule_item_created']);
      expect(port.syncCalls, 1);
    });
  });

  group('update：改系列根会摘掉覆盖行，失败要一起退回', () {
    test('成功时摘掉覆盖行、落盘并通知', () async {
      final port = _FakePort(
        items: <ScheduleItem>[
          _item('root'),
          _item('over', seriesId: 'root', occurrenceDate: _day1),
        ],
      );

      await TimetableScheduleItemService.update(
        port,
        _item('root', title: '  改过  '),
      );

      expect(port.scheduleItems.map((item) => item.id), <String>['root']);
      expect(port.scheduleItems.single.title, '改过');
      expect(port.persistCalls, 1);
      expect(port.notifyCalls, 1);
      expect(port.events, <String>['schedule_item_updated']);
      expect(port.syncCalls, 1);
    });

    test('落盘失败时日程与课表一起退回，且不通知不埋点', () async {
      final original = <ScheduleItem>[
        _item('root'),
        _item('over', seriesId: 'root', occurrenceDate: _day1),
      ];
      final port = _FakePort(
        items: original,
        profiles: <TimetableProfile>[_profile('p1')],
      )..failPersist = true;

      await expectLater(
        TimetableScheduleItemService.update(
          port,
          _item('root', title: '改过'),
        ),
        throwsA(isA<StateError>()),
      );

      expect(port.scheduleItems.map((item) => item.id), <String>['root', 'over']);
      expect(port.scheduleItems.first.title, '事项');
      expect(port.profileWrites, greaterThan(0));
      expect(port.profiles.single.id, 'p1');
      expect(port.notifyCalls, 0);
      expect(port.events, isEmpty);
      expect(port.syncCalls, 0);
    });

    test('目标不存在时什么都不做', () async {
      final port = _FakePort(items: <ScheduleItem>[_item('a')]);

      await TimetableScheduleItemService.update(port, _item('missing'));

      expect(port.persistCalls, 0);
      expect(port.itemWrites, 0);
      expect(port.notifyCalls, 0);
    });
  });

  group('delete：按 seriesId ?? id 整系列摘除', () {
    test('成功时根与覆盖一起消失', () async {
      final port = _FakePort(
        items: <ScheduleItem>[
          _item('root'),
          _item('over', seriesId: 'root', occurrenceDate: _day1),
          _item('other'),
        ],
      );

      await TimetableScheduleItemService.delete(port, 'over');

      expect(port.scheduleItems.map((item) => item.id), <String>['other']);
      expect(port.events, <String>['schedule_item_deleted']);
      expect(
        port.eventPayloads['schedule_item_deleted'],
        <String, Object>{'remaining_schedule_item_count': 1},
      );
    });

    test('落盘失败时整系列退回', () async {
      final port = _FakePort(
        items: <ScheduleItem>[
          _item('root'),
          _item('over', seriesId: 'root', occurrenceDate: _day1),
        ],
      )..failPersist = true;

      await expectLater(
        TimetableScheduleItemService.delete(port, 'root'),
        throwsA(isA<StateError>()),
      );

      expect(port.scheduleItems, hasLength(2));
      expect(port.notifyCalls, 0);
    });
  });

  group('单次日程：编辑/删除直接落在原来那一行', () {
    test('updateOccurrence 走 update，不生成覆盖行', () async {
      final port = _FakePort(
        items: <ScheduleItem>[_item('one', title: '旧')],
      );

      await TimetableScheduleItemService.updateOccurrence(
        port,
        'one',
        _day1,
        _item('one', title: '新'),
      );

      expect(port.scheduleItems, hasLength(1));
      expect(port.scheduleItems.single.title, '新');
      expect(port.events, <String>['schedule_item_updated']);
    });

    test('deleteOccurrence 走 delete，整行摘除', () async {
      final port = _FakePort(items: <ScheduleItem>[_item('one')]);

      await TimetableScheduleItemService.deleteOccurrence(port, 'one', _day1);

      expect(port.scheduleItems, isEmpty);
      expect(port.events, <String>['schedule_item_deleted']);
    });
  });

  group('重复系列：改一次生成带日期后缀的覆盖行', () {
    test('根加例外日期，覆盖行带 seriesId 与 occurrenceDate', () async {
      final port = _FakePort(
        items: <ScheduleItem>[
          _item(
            'root',
            startDate: _day1,
            endDate: DateTime(2026, 12, 31),
            recurrence: ScheduleRecurrence.daily,
          ),
        ],
      );

      await TimetableScheduleItemService.updateOccurrence(
        port,
        'root',
        _day2,
        _item('root', title: '这一天改', startDate: _day2, endDate: _day2),
      );

      expect(port.scheduleItems, hasLength(2));
      final root = port.scheduleItems.firstWhere((item) => item.id == 'root');
      expect(root.exceptionDates, <DateTime>[_day2]);
      final override = port.scheduleItems.firstWhere(
        (item) => item.id != 'root',
      );
      expect(override.seriesId, 'root');
      expect(override.occurrenceDate, _day2);
      expect(override.title, '这一天改');
      expect(
        override.id,
        ScheduleItem.buildOccurrenceId('root', _day2),
      );
      expect(port.events, <String>['schedule_item_occurrence_updated']);
      expect(port.syncCalls, 1);
    });
  });
}
