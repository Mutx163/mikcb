import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';

void main() {
  group('TimetableProvider undo functionality', () {
    late TimetableProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = TimetableProvider();
      // Wait for initialization
      await Future.delayed(Duration.zero);
    });

    tearDown(() {
      provider.dispose();
    });

    test('initial state has no pending undo', () {
      expect(provider.hasPendingUndo, isFalse);
      expect(provider.undoThemeName, isNull);
    });

    test('applyThemeWithUndo sets pending undo state', () async {
      final originalSettings = provider.settings;
      final newSettings = originalSettings.copyWith(
        themeSeedColor: '#FF0000',
      );

      await provider.applyThemeWithUndo(newSettings, themeName: 'Test Theme');

      expect(provider.hasPendingUndo, isTrue);
      expect(provider.undoThemeName, 'Test Theme');
      expect(provider.settings.themeSeedColor, '#FF0000');
    });

    test('undoThemeChange restores original settings', () async {
      final originalSettings = provider.settings;
      final newSettings = originalSettings.copyWith(
        themeSeedColor: '#FF0000',
      );

      await provider.applyThemeWithUndo(newSettings, themeName: 'Test Theme');
      expect(provider.settings.themeSeedColor, '#FF0000');

      await provider.undoThemeChange();

      expect(provider.settings.themeSeedColor, originalSettings.themeSeedColor);
      expect(provider.hasPendingUndo, isFalse);
      expect(provider.undoThemeName, isNull);
    });

    test('undoThemeChange does nothing when no pending undo', () async {
      final originalSettings = provider.settings;

      await provider.undoThemeChange();

      expect(provider.settings.themeSeedColor, originalSettings.themeSeedColor);
      expect(provider.hasPendingUndo, isFalse);
    });

    test('undo state expires after timeout', () {
      fakeAsync((async) {
        final originalSettings = provider.settings;
        final newSettings = originalSettings.copyWith(
          themeSeedColor: '#FF0000',
        );

        // Apply theme with undo
        provider.applyThemeWithUndo(newSettings, themeName: 'Test Theme');
        expect(provider.hasPendingUndo, isTrue);

        // Advance time to just before timeout
        async.elapse(const Duration(seconds: 7));
        expect(provider.hasPendingUndo, isTrue);

        // Advance past timeout
        async.elapse(const Duration(seconds: 2));
        expect(provider.hasPendingUndo, isFalse);
        expect(provider.undoThemeName, isNull);
      });
    });

    test('multiple applyThemeWithUndo calls only keep last undo', () async {
      final originalSettings = provider.settings;
      final settings1 = originalSettings.copyWith(
        themeSeedColor: '#FF0000',
      );
      final settings2 = originalSettings.copyWith(
        themeSeedColor: '#00FF00',
      );

      await provider.applyThemeWithUndo(settings1, themeName: 'Theme 1');
      expect(provider.undoThemeName, 'Theme 1');

      await provider.applyThemeWithUndo(settings2, themeName: 'Theme 2');
      expect(provider.undoThemeName, 'Theme 2');
      expect(provider.settings.themeSeedColor, '#00FF00');

      // Undo should restore to settings before the last applyThemeWithUndo
      await provider.undoThemeChange();
      expect(provider.settings.themeSeedColor, '#FF0000');
    });

    test('dispose cancels undo timer without crash', () async {
      // Use a separate provider for this test
      final testProvider = TimetableProvider();
      await Future.delayed(Duration.zero);
      
      final newSettings = testProvider.settings.copyWith(
        themeSeedColor: '#FF0000',
      );

      // Apply theme with undo
      await testProvider.applyThemeWithUndo(newSettings, themeName: 'Test Theme');
      expect(testProvider.hasPendingUndo, isTrue);

      // Dispose provider - should not throw
      testProvider.dispose();
    });
  });
}
