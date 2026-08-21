import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  group('HomeNavigationForm', () {
    test('defaults to classic', () {
      expect(TimetableSettings.defaults().homeNavigationForm,
          HomeNavigationForm.classic);
    });

    test('round-trips through json', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
      );
      final restored = TimetableSettings.fromJsonString(
        settings.toJsonString(),
      );
      expect(restored.homeNavigationForm, HomeNavigationForm.glassDock);
    });

    test('fromValue falls back to classic for unknown values', () {
      expect(HomeNavigationFormX.fromValue(null), HomeNavigationForm.classic);
      expect(
        HomeNavigationFormX.fromValue('unknown_form'),
        HomeNavigationForm.classic,
      );
      expect(
        HomeNavigationFormX.fromValue('glass_dock'),
        HomeNavigationForm.glassDock,
      );
    });

    test('copyWith keeps other settings intact', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        timetableHomeViewMode: TimetableHomeViewMode.day,
      );
      expect(settings.homeNavigationForm, HomeNavigationForm.glassDock);
      expect(settings.timetableHomeViewMode, TimetableHomeViewMode.day);
      expect(
        settings.copyWith(homeNavigationForm: HomeNavigationForm.classic)
            .timetableHomeViewMode,
        TimetableHomeViewMode.day,
      );
    });
  });

  group('GlassDockInsetClearance', () {
    test('defaults to pill occupancy + compact gap', () {
      expect(TimetableSettings.defaults().glassDockInsetClearance,
          glassDockInsetClearanceDefault);
      expect(glassDockInsetClearanceMin, 62);
      expect(glassDockInsetClearanceMax, greaterThan(glassDockInsetClearanceMin));
    });

    test('round-trips through json', () {
      final settings = TimetableSettings.defaults().copyWith(
        glassDockInsetClearance: 100,
      );
      final restored = TimetableSettings.fromJsonString(
        settings.toJsonString(),
      );
      expect(restored.glassDockInsetClearance, 100);
    });

    test('fromJson clamps out-of-range values', () {
      final base =
          TimetableSettings.defaults().copyWith(glassDockInsetClearance: 100);
      final smallMap = base.toJson()..['glassDockInsetClearance'] = 10;
      expect(
        TimetableSettings.fromJson(smallMap).glassDockInsetClearance,
        glassDockInsetClearanceMin,
      );

      final largeMap = base.toJson()..['glassDockInsetClearance'] = 9999;
      expect(
        TimetableSettings.fromJson(largeMap).glassDockInsetClearance,
        glassDockInsetClearanceMax,
      );

      final missingMap = base.toJson()..remove('glassDockInsetClearance');
      expect(
        TimetableSettings.fromJson(missingMap).glassDockInsetClearance,
        glassDockInsetClearanceDefault,
      );
    });

    test('copyWith updates clearance only', () {
      final settings = TimetableSettings.defaults().copyWith(
        homeNavigationForm: HomeNavigationForm.glassDock,
        glassDockInsetClearance: 120,
      );
      expect(settings.glassDockInsetClearance, 120);
      expect(
        settings.copyWith(glassDockLayout: GlassDockLayout.overlay)
            .glassDockInsetClearance,
        120,
      );
    });
  });
}
