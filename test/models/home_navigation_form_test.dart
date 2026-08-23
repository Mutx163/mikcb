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

}
