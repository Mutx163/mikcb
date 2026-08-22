import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/memory_stats_service.dart';
import 'package:university_timetable/widgets/home_menu_catalog.dart';

void main() {
  test('catalog ids are unique and non-empty', () {
    final ids = kHomeMenuCatalog.map((entry) => entry.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id 重复会导致瓷贴互相顶替');
    expect(ids.every((id) => id.isNotEmpty), isTrue);
  });

  test('default order resolves entirely from catalog', () {
    for (final id in HomeGridMenu.defaultActions) {
      expect(homeMenuEntryById(id), isNotNull, reason: '默认排列含未知 id: $id');
    }
  });

  test('pinned settings entry stays resolvable', () {
    expect(homeMenuEntryById(HomeGridMenu.pinnedActionId), isNotNull);
  });

  test('memory stats entry is hidden for release users', () {
    final memoryEntry = homeMenuEntryById('memoryStats');
    expect(memoryEntry, isNotNull);

    // 正式版（非诊断包名）：条目不可见，解析时被丢弃。
    MemoryStatsService.debugSetCachedDiagnosticsBuild(false);
    addTearDown(() => MemoryStatsService.debugSetCachedDiagnosticsBuild(null));
    expect(memoryEntry!.visible(), isFalse);
    final releaseResolved = resolveHomeGridMenuEntries(
      TimetableSettings.defaults().copyWith(
        homeGridMenuActions: ['overview', 'memoryStats', 'support'],
      ),
    );
    expect(releaseResolved.map((e) => e.id), isNot(contains('memoryStats')));
    expect(releaseResolved.map((e) => e.id), contains('overview'));

    // 调试/性能版（诊断包名）：条目恢复可见、可被解析进八宫格。
    MemoryStatsService.debugSetCachedDiagnosticsBuild(true);
    expect(memoryEntry.visible(), isTrue);
    final debugResolved = resolveHomeGridMenuEntries(
      TimetableSettings.defaults().copyWith(
        homeGridMenuActions: ['overview', 'memoryStats', 'support'],
      ),
    );
    expect(debugResolved.map((e) => e.id), contains('memoryStats'));
  });

  test('resolver falls back to defaults on empty config and drops junk', () {
    final fallback = resolveHomeGridMenuEntries(TimetableSettings.defaults());
    expect(fallback.length, HomeGridMenu.maxSlots);

    final cleaned = resolveHomeGridMenuEntries(
      TimetableSettings.defaults().copyWith(
        homeGridMenuActions: ['overview', 'no_such_entry'],
      ),
    );
    expect(cleaned.map((e) => e.id), containsAll(['overview']));
    expect(cleaned.map((e) => e.id), isNot(contains('no_such_entry')));
  });
}