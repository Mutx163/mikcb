import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/timetable_settings.dart';

void main() {
  group('HomeNavigationForm', () {
    test('defaults to classic', () {
      expect(
        TimetableSettings.defaults().homeNavigationForm,
        HomeNavigationForm.classic,
      );
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
        settings
            .copyWith(homeNavigationForm: HomeNavigationForm.classic)
            .timetableHomeViewMode,
        TimetableHomeViewMode.day,
      );
    });
  });

  group('底栏材质：独立开关已下线', () {
    // 底栏材质现在跟随「全局材质 + 作用范围 → 玻璃坞导航」，
    // 不再有独立的 glassDockStyle 字段；带旧键的存量 JSON 必须能正常读取
    // （旧键被忽略，不走迁移分支，因为迁移只针对首页玻璃带的 liquid 键）。
    test('存量 JSON 里的 glassDockStyle 键被忽略且不报错', () {
      final json = TimetableSettings.defaults().toJson()
        ..['glassDockStyle'] = 'soft';
      final restored = TimetableSettings.fromJson(json);
      expect(restored.homeNavigationForm, HomeNavigationForm.classic);
    });

    test('toJson 不再写出 glassDockStyle 键', () {
      final json = TimetableSettings.defaults().toJson();
      expect(json.containsKey('glassDockStyle'), isFalse);
    });
  });
}
