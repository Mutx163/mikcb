import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/class_reminder.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_reminder_service.dart';

ClassReminderEntry _entry(String courseId, String date, int minuteOfDay) =>
    ClassReminderEntry(
      courseId: courseId,
      date: date,
      minuteOfDay: minuteOfDay,
    );

class _FakeReminderPort implements TimetableReminderPort {
  _FakeReminderPort(TimetableSettings initial) : _settings = initial;

  TimetableSettings _settings;
  bool failPersist = false;
  int updateCount = 0;
  int syncCount = 0;

  /// 记录「门内读设置」与「写设置」的顺序：读必须发生在拿锁之后，
  /// 否则并发写会被旧快照覆盖（本域抽离前修过的那条竞态）。
  final List<String> events = [];

  List<ClassReminderEntry> get reminders => _settings.classReminders;

  @override
  TimetableSettings get settings {
    events.add('read-settings');
    return _settings;
  }

  @override
  Future<T> runMutation<T>(Future<T> Function() operation) async {
    events.add('gate-enter');
    try {
      return await operation();
    } finally {
      events.add('gate-exit');
    }
  }

  @override
  Future<void> updateSettings(TimetableSettings settings) async {
    events.add('update');
    updateCount += 1;
    if (failPersist) {
      throw StateError('disk full');
    }
    _settings = settings;
  }

  @override
  void syncExamReminders() => syncCount += 1;
}

void main() {
  test('setClassReminder 在门内读当前设置，按日期与分钟排序后整份写回', () async {
    final port = _FakeReminderPort(TimetableSettings.defaults());
    final service = TimetableReminderService(port);

    await service.setClassReminder(_entry('c2', '2026-10-20', 600));
    await service.setClassReminder(_entry('c1', '2026-10-19', 480));
    await service.setClassReminder(_entry('c3', '2026-10-19', 300));

    expect(
      port.reminders.map((entry) => '${entry.date}@${entry.minuteOfDay}'),
      ['2026-10-19@300', '2026-10-19@480', '2026-10-20@600'],
    );
    expect(port.updateCount, 3);
    expect(port.syncCount, 3, reason: '每次写入后都要重排考试提醒');
    expect(
      port.events.take(3),
      ['gate-enter', 'read-settings', 'update'],
      reason: '取快照必须发生在门内（门外的旧快照会覆盖并发写入）',
    );
  });

  test('同课同日重复设置只保留一条（覆盖为最新时间）', () async {
    final port = _FakeReminderPort(TimetableSettings.defaults());
    final service = TimetableReminderService(port);

    await service.setClassReminder(_entry('c1', '2026-10-19', 480));
    await service.setClassReminder(_entry('c1', '2026-10-19', 600));
    await service.setClassReminder(_entry('c1', '2026-10-20', 480));

    expect(port.reminders, hasLength(2));
    final today = port.reminders.firstWhere((e) => e.date == '2026-10-19');
    expect(today.minuteOfDay, 600);
  });

  test('设置写盘失败：异常上抛，且不重排考试提醒', () async {
    final original = TimetableSettings.defaults();
    final port = _FakeReminderPort(original)..failPersist = true;
    final service = TimetableReminderService(port);

    await expectLater(
      service.setClassReminder(_entry('c1', '2026-10-19', 480)),
      throwsA(isA<StateError>()),
    );
    expect(port.reminders, isEmpty, reason: '写盘失败时设置回到原值');
    expect(port.syncCount, 0, reason: '没落盘成功就不该重排提醒');
  });

  test('removeClassReminder 删除命中项并重排考试提醒', () async {
    final port = _FakeReminderPort(TimetableSettings.defaults());
    final service = TimetableReminderService(port);
    await service.setClassReminder(_entry('c1', '2026-10-19', 480));
    await service.setClassReminder(_entry('c2', '2026-10-20', 600));
    port.syncCount = 0;

    await service.removeClassReminder('c1', '2026-10-19');

    expect(port.reminders.map((entry) => entry.courseId), ['c2']);
    expect(port.syncCount, 1);
  });

  test('removeClassReminder 未命中时静默幂等：不重排提醒、条目不变', () async {
    final port = _FakeReminderPort(TimetableSettings.defaults());
    final service = TimetableReminderService(port);
    await service.setClassReminder(_entry('c1', '2026-10-19', 480));
    port.syncCount = 0;

    await service.removeClassReminder('c1', '2026-99-99');
    await service.removeClassReminder('missing', '2026-10-19');

    expect(port.reminders, hasLength(1));
    expect(port.syncCount, 0, reason: '没删掉任何一条就不该重排');
  });
}
