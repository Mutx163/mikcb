import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_import_session_log.dart';

void main() {
  late WarehouseImportSessionLog log;

  setUp(() {
    log = WarehouseImportSessionLog.instance;
    log.clear();
  });

  tearDown(() {
    log.clear();
  });

  test('starts empty and clear is idempotent', () {
    expect(log.isEmpty, isTrue);
    expect(log.entryCount, 0);
    log.clear();
    expect(log.isEmpty, isTrue);
  });

  test('append ignores blank messages', () {
    log.append(message: '   ');
    expect(log.isEmpty, isTrue);
  });

  test('append formats diagnostics block with normalized level and extras', () {
    log.append(
      message: '  import started  ',
      level: 'ERR',
      extras: {'school': 'demo', 'count': 3, 'optional': null},
    );

    expect(log.entryCount, 1);
    final text = log.readText();
    expect(text, contains('Warehouse import execution log'));
    expect(text, contains('entryCount=1'));
    expect(text, contains('level=error'));
    expect(text, contains('category=${WarehouseImportSessionLog.category}'));
    expect(text, contains('message=import started'));
    expect(text, contains('school=demo'));
    expect(text, contains('count=3'));
    expect(text, contains('optional=null'));
  });

  test('normalizes common level aliases', () {
    log.append(message: 'a', level: 'warning');
    log.append(message: 'b', level: 'trace');
    log.append(message: 'c', level: 'debug');
    log.append(message: 'd', level: 'mystery');

    final text = log.readText();
    expect(text, contains('level=warn'));
    expect(text, contains('level=verbose'));
    expect(text, contains('level=debug'));
    expect(text, contains('level=info'));
  });

  test('ring buffer drops oldest entries beyond maxEntries', () {
    const overflow = WarehouseImportSessionLog.maxEntries + 5;
    for (var index = 0; index < overflow; index++) {
      log.append(message: 'entry-$index');
    }

    expect(log.entryCount, WarehouseImportSessionLog.maxEntries);
    final text = log.readText();
    expect(text, isNot(contains('message=entry-0')));
    expect(text, contains('message=entry-${overflow - 1}'));
  });

  test('watchText emits current snapshot and updates on append', () async {
    final events = <String>[];
    final subscription = log.watchText(title: 'Watch title').listen(events.add);

    await Future<void>.delayed(Duration.zero);
    expect(events, isNotEmpty);
    expect(events.first, contains('Watch title'));
    expect(events.first, contains('entryCount=0'));

    log.append(message: 'first');
    await Future<void>.delayed(Duration.zero);
    expect(events.last, contains('message=first'));
    expect(events.last, contains('entryCount=1'));

    await subscription.cancel();
  });
}
