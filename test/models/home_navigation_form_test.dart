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

  group('TimetableHomeViewMode（首页三个同级视图）', () {
    // 落盘串取的是枚举名（`TimetableHomeViewModeX.value => name`）。这几条把
    // **字面串**钉住：万一哪天有人把枚举项改名（week → weekly），存档键会静默
    // 变掉，老用户重启后「停在哪个视图」被 orElse 回落成 week —— 不崩、不报错，
    // 只是用户的视图没了，属于最难被察觉的那类回归。
    test('defaults to week', () {
      expect(
        TimetableSettings.defaults().timetableHomeViewMode,
        TimetableHomeViewMode.week,
      );
    });

    test('落盘串就是这三个字面值（改名会静默丢老存档的视图状态）', () {
      expect(TimetableHomeViewMode.week.value, 'week');
      expect(TimetableHomeViewMode.day.value, 'day');
      expect(TimetableHomeViewMode.month.value, 'month');
    });

    test('三档都能 round-trip 过 json', () {
      for (final mode in TimetableHomeViewMode.values) {
        final settings = TimetableSettings.defaults().copyWith(
          timetableHomeViewMode: mode,
        );
        final restored = TimetableSettings.fromJsonString(
          settings.toJsonString(),
        );
        expect(restored.timetableHomeViewMode, mode, reason: '$mode 落盘读回');
      }
    });

    test('旧存档（只有 week / day 那份时代写的）照读不误', () {
      // month 是 2026-10-24 后加的档，老版本根本不会写出 'month'；升级后老存档
      // 必须原样读回，不能被当成脏数据重置。
      for (final (raw, expected) in [
        ('week', TimetableHomeViewMode.week),
        ('day', TimetableHomeViewMode.day),
      ]) {
        final json = TimetableSettings.defaults().toJson()
          ..['timetableHomeViewMode'] = raw;
        expect(
          TimetableSettings.fromJson(json).timetableHomeViewMode,
          expected,
        );
      }
      // 整把键都没有（更早的存档）：回落 week。
      final json = TimetableSettings.defaults().toJson()
        ..remove('timetableHomeViewMode');
      expect(
        TimetableSettings.fromJson(json).timetableHomeViewMode,
        TimetableHomeViewMode.week,
      );
    });

    test('fromValue 对未知值一律回落 week（不崩、不跳错视图）', () {
      expect(
        TimetableHomeViewModeX.fromValue(null),
        TimetableHomeViewMode.week,
      );
      expect(
        TimetableHomeViewModeX.fromValue('unknown_mode'),
        TimetableHomeViewMode.week,
      );
      expect(TimetableHomeViewModeX.fromValue('month'), TimetableHomeViewMode.month);
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
