import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/services/timetable_theme_service.dart';

class _FakeThemePort implements TimetableThemePort {
  _FakeThemePort(this.settings);

  @override
  TimetableSettings settings;
  int updateCount = 0;
  int notifyCount = 0;

  @override
  Future<void> updateSettings(TimetableSettings value) async {
    settings = value;
    updateCount += 1;
  }

  @override
  Future<T> runMutation<T>(Future<T> Function() operation) => operation();

  @override
  Future<void> replaceSavedThemes(
    List<SavedTheme> Function(TimetableSettings settings) build,
  ) async {
    settings = settings.copyWith(savedThemes: build(settings));
  }

  @override
  void notifyStateChanged() {
    notifyCount += 1;
  }
}

void main() {
  test('applyThemeWithUndo 记录撤销点并写新设置', () async {
    final port = _FakeThemePort(TimetableSettings.defaults());
    final service = TimetableThemeService(port);
    addTearDown(service.dispose);

    final next = port.settings.copyWith(themeSeedColor: '#FF0000');
    await service.applyThemeWithUndo(next, themeName: '测试主题');

    expect(service.hasPendingUndo, isTrue);
    expect(service.undoThemeName, '测试主题');
    expect(port.settings.themeSeedColor, '#FF0000');
    expect(port.updateCount, 1);
  });

  test('undoThemeChange 只回滚主题字段', () async {
    final port = _FakeThemePort(TimetableSettings.defaults());
    final service = TimetableThemeService(port);
    addTearDown(service.dispose);

    final originalSeed = port.settings.themeSeedColor;
    final next = port.settings.copyWith(
      themeSeedColor: '#FF0000',
      semesterWeekCount: 20,
    );
    await service.applyThemeWithUndo(next, themeName: '测试主题');
    await service.undoThemeChange();

    expect(port.settings.themeSeedColor, originalSeed);
    // 非主题字段不该被撤销带回。
    expect(port.settings.semesterWeekCount, 20);
    expect(service.hasPendingUndo, isFalse);
    expect(port.updateCount, 2);
  });

  test('没有撤销点时 undoThemeChange 是 no-op', () async {
    final port = _FakeThemePort(TimetableSettings.defaults());
    final service = TimetableThemeService(port);
    addTearDown(service.dispose);

    await service.undoThemeChange();

    expect(port.updateCount, 0);
    expect(service.hasPendingUndo, isFalse);
  });

  test('save/rename/delete 都走 replaceSavedThemes', () async {
    final port = _FakeThemePort(TimetableSettings.defaults());
    final service = TimetableThemeService(port);
    addTearDown(service.dispose);

    await service.saveTheme('主题 A', <String, dynamic>{});
    expect(port.settings.savedThemes, hasLength(1));
    final id = port.settings.savedThemes.single.id;

    await service.renameTheme(id, '主题 B');
    expect(port.settings.savedThemes.single.name, '主题 B');

    await service.deleteTheme(id);
    expect(port.settings.savedThemes, isEmpty);
  });

  test('撤销窗口 2 秒后过期并刷新界面', () {
    fakeAsync((async) {
      final port = _FakeThemePort(TimetableSettings.defaults());
      final service = TimetableThemeService(port);

      unawaited(
        service.applyThemeWithUndo(
          port.settings.copyWith(themeSeedColor: '#FF0000'),
          themeName: '测试主题',
        ),
      );
      async.flushMicrotasks();
      expect(service.hasPendingUndo, isTrue);

      async.elapse(const Duration(seconds: 1));
      expect(service.hasPendingUndo, isTrue);

      async.elapse(const Duration(seconds: 2));
      expect(service.hasPendingUndo, isFalse);
      expect(service.undoThemeName, isNull);
      expect(port.notifyCount, 1);

      service.dispose();
    });
  });
}
