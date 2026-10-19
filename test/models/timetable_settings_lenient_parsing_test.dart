import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';

/// 2026-10-19 容错解析加固：fromJson 里原本大量 `json['x'] as T?` 硬转换，
/// 任一字段类型不符（手改备份 / 旧版本数据 / 云同步 / 局域网传输包）会抛
/// TypeError 冒到 TimetableProfile.fromJsonLenient 的顶层 catch，把**整份**
/// 设置重置为默认。本文件钉住新口径：类型不符按「缺键」处理，其余字段照常。
///
/// 期望值均为人工推导（按字段各自的缺省值与归一口径），不从实现回抄。
void main() {
  /// 一份合法的完整 JSON（defaults 的 toJson），测试里只覆写单个键制造坏值。
  /// 带上开学日，供「坏值不牵连其余字段」类断言交叉验证。
  Map<String, dynamic> validJson() =>
      TimetableSettings.defaults()
          .copyWith(semesterStartDate: DateTime(2026, 9, 7))
          .toJson();

  /// 把 [key] 换成类型不符的 [bad] 后解析。解析本身不允许抛。
  TimetableSettings parseWithBad(String key, Object? bad) {
    final json = validJson()..[key] = bad;
    return TimetableSettings.fromJson(json);
  }

  group('类型不符的单个字段退回默认，其余字段不受影响', () {
    test('semesterWeekCount 是字符串 → 回默认 20，开学日仍在', () {
      final restored = parseWithBad('semesterWeekCount', 'twenty');
      expect(restored.semesterWeekCount, 20);
      // 整份设置没有跟着回退：其余字段保留原 JSON 里的合法值。
      // （themeSeedColor 的合法值是 #3482FF；#2563EB 只是缺键时的兜底。）
      expect(restored.themeSeedColor, '#3482FF');
    });

    test('semesterWeekCount 为 0/负数 → 至少 1 周（既有不变式经由容错读取仍成立）',
        () {
      expect(parseWithBad('semesterWeekCount', 0).semesterWeekCount, 1);
      expect(parseWithBad('semesterWeekCount', -3).semesterWeekCount, 1);
    });

    test('semesterStartDate 写成字符串（毫秒键坏）→ 文本键优先，日期不丢', () {
      final restored = parseWithBad('semesterStartDate', 'soon');
      expect(restored.semesterStartDate, DateTime(2026, 9, 7));
    });

    test('semesterStartDateText 写成数字（文本键坏）→ 回落到毫秒键', () {
      final restored = parseWithBad('semesterStartDateText', 123);
      expect(restored.semesterStartDate, DateTime(2026, 9, 7));
    });

    test('frostedBlurEnabled 写成 \'yes\' → 回默认开；liquidGlassDockEnabled 写成 0 → 不猜成关',
        () {
      expect(parseWithBad('frostedBlurEnabled', 'yes').frostedBlurEnabled,
          TimetableSettings.defaultFrostedBlurEnabled);
      expect(parseWithBad('liquidGlassDockEnabled', 0).liquidGlassDockEnabled,
          TimetableSettings.defaultLiquidGlassDockEnabled);
    });

    test('savedThemes 写成 \'oops\' → 空列表，主题字段完好', () {
      final restored = parseWithBad('savedThemes', 'oops');
      expect(restored.savedThemes, isEmpty);
      expect(restored.themeSeedColor, '#3482FF');
      expect(restored.courseCardTitleColorLight,
          TimetableSettings.defaultCourseCardTitleColor);
    });

    test('sections 写成 Map → 整表回落内置模板', () {
      final restored = parseWithBad('sections', {'0': '08:00'});
      expect(restored.sections, TimetableSettings.defaults().sections);
    });

    test('sections 条目坏值按位补齐（一条脏不拖走其余）', () {
      final restored = parseWithBad('sections', [
        {'startTime': '08:30', 'endTime': '09:15'},
        42,
        {'startTime': '10:00', 'endTime': '10:45'},
      ]);
      expect(restored.sections, hasLength(3));
      expect(restored.sections[0].startTime, '08:30');
      // 中间的坏条目按位补成模板节次，不把后面的节次整体前移。
      expect(restored.sections[1].startTime,
          TimetableSettings.defaults().sections[1].startTime);
      expect(restored.sections[2].startTime, '10:00');
    });

    test('themeSeedColor 写成非数字字符串 \'blue\' → 有值就收，原样通过', () {
      // 「有值就收」口径：字符串一律原样保留；非法颜色串由渲染端既有
      // 逻辑兜底（与其它未知字符串取值同待遇），解析层不猜。
      expect(parseWithBad('themeSeedColor', 'blue').themeSeedColor, 'blue');
    });

    test('themeSeedColor 写成数字 → 「有值就收」成字符串，不抛不回默认', () {
      expect(parseWithBad('themeSeedColor', 123).themeSeedColor, '123');
    });

    test('timetablePageBackgroundColor 写成字符串 \'dark\' → 收下原值（口径如此）',
        () {
      expect(parseWithBad('timetablePageBackgroundColor', 'dark')
          .timetablePageBackgroundColor, 'dark');
    });

    test('pageTransitionSpeed 写成 \'fast\' → 回默认 1.0', () {
      expect(
        parseWithBad('pageTransitionSpeed', 'fast').pageTransitionSpeed,
        TimetableSettings.defaultPageTransitionSpeed,
      );
    });

    test('liveMiuiIslandLabelFontSize 写成 \'big\' → 回默认 14', () {
      expect(parseWithBad('liveMiuiIslandLabelFontSize', 'big')
          .liveMiuiIslandLabelFontSize, 14);
    });

    test('glassDockActions 写成字符串 → 走旧键推导，回默认 day/week', () {
      expect(parseWithBad('glassDockActions', 'day,week').glassDockActions,
          ['day', 'week']);
    });

    test('homeGridMenuActions 写成 Map → 空表（渲染层回退默认排列）', () {
      expect(
        parseWithBad('homeGridMenuActions', {'0': 'overview'})
            .homeGridMenuActions,
        isEmpty,
      );
    });

    test('wallpaperHistory 写成数字 → 空历史', () {
      expect(parseWithBad('wallpaperHistory', 42).wallpaperHistory, isEmpty);
    });

    test('classReminders 写成字符串 → 空列表', () {
      expect(parseWithBad('classReminders', 'none').classReminders, isEmpty);
    });

    test('themeCheckpointConfig 写成 List → 检查点丢弃', () {
      final restored = parseWithBad('themeCheckpointConfig', const ['x']);
      expect(restored.themeCheckpointConfig, isNull);
    });
    test('liquidGlassTuning 写成数字 → 参数为 null、档位回标准', () {
      final restored = parseWithBad('liquidGlassTuning', 5);
      expect(restored.liquidGlassTuning, isNull);
      expect(restored.liquidGlassPreset, LiquidGlassPreset.standard);
    });

    test('liquidGlassTuningDark 写成字符串 → 深色参数丢弃（null = 跟随浅色）', () {
      expect(parseWithBad('liquidGlassTuningDark', 'dark').liquidGlassTuningDark,
          isNull);
    });

    test('appLocaleTag 数字 9 → 「有值就收」成字符串 \'9\'（非 system/空，原样保留）',
        () {
      expect(parseWithBad('appLocaleTag', 9).appLocaleTag, '9');
    });

    test('liveExpandedDetailFields 写成字符串 → 按缺键处理为 null', () {
      expect(
        parseWithBad('liveExpandedDetailFields', 'time').liveExpandedDetailFields,
        isNull,
      );
    });
  });

  group('_boolOrNull 口径（经由 enableHaptics / timetableHideWeekends）', () {
    test('合法 bool 原样', () {
      expect(parseWithBad('enableHaptics', false).enableHaptics, isFalse);
      expect(parseWithBad('timetableHideWeekends', true).timetableHideWeekends,
          isTrue);
    });

    test('\'true\' / \'False\' 字符串收下（大小写不敏感）', () {
      // enableHaptics 默认 true，必须用「显式字符串 → 翻转默认」来验证方向：
      expect(parseWithBad('enableHaptics', 'false').enableHaptics, isFalse);
      expect(
        parseWithBad('timetableHideWeekends', 'true').timetableHideWeekends,
        isTrue,
      );
      expect(
        parseWithBad('timetableHideWeekends', 'False').timetableHideWeekends,
        isFalse,
      );
    });

    test('不猜：1 / 0 / \'1\' / \'yes\' 都不是 bool，按缺键回默认', () {
      expect(parseWithBad('timetableHideWeekends', 1).timetableHideWeekends,
          isFalse);
      expect(parseWithBad('timetableHideWeekends', 0).timetableHideWeekends,
          isFalse);
      expect(parseWithBad('timetableHideWeekends', '1').timetableHideWeekends,
          isFalse);
      expect(parseWithBad('enableHaptics', 'yes').enableHaptics, isTrue);
    });
  });

  group('_intOrNull 口径（经由 classAlarmLeadMinutes，默认 30）', () {
    test('int 原样；double 截断（等价旧 (num)?.toInt() 口径）', () {
      expect(parseWithBad('classAlarmLeadMinutes', 15).classAlarmLeadMinutes, 15);
      expect(
        parseWithBad('classAlarmLeadMinutes', 15.9).classAlarmLeadMinutes,
        15,
      );
    });

    test('数字字符串收下（去首尾空白）', () {
      expect(
        parseWithBad('classAlarmLeadMinutes', '25').classAlarmLeadMinutes,
        25,
      );
      expect(
        parseWithBad('classAlarmLeadMinutes', ' 25 ').classAlarmLeadMinutes,
        25,
      );
    });

    test('\'25.5\' / \'abc\' / null 解析失败 → 按缺键回默认', () {
      expect(
        parseWithBad('classAlarmLeadMinutes', '25.5').classAlarmLeadMinutes,
        30,
      );
      expect(
        parseWithBad('classAlarmLeadMinutes', 'abc').classAlarmLeadMinutes,
        30,
      );
    });
  });

  group('_doubleOrNull 口径（经由 sectionHeight，默认 68）', () {
    test('int / double 都收下', () {
      expect(parseWithBad('sectionHeight', 72).sectionHeight, 72.0);
      expect(parseWithBad('sectionHeight', 72.5).sectionHeight, 72.5);
    });

    test('数字字符串收下；非数字字符串回默认', () {
      expect(parseWithBad('sectionHeight', '70.5').sectionHeight, 70.5);
      expect(parseWithBad('sectionHeight', '70').sectionHeight, 70.0);
      expect(parseWithBad('sectionHeight', 'tall').sectionHeight, 68.0);
    });
  });

  group('_stringOrNull 口径（「有值就收」）', () {
    test('字符串原样', () {
      expect(
        parseWithBad('timetablePageBackgroundColor', '#ABCDEF')
            .timetablePageBackgroundColor,
        '#ABCDEF',
      );
    });

    test('非字符串（数字）按 toString 收下——数字漂移成字符串可救回', () {
      expect(parseWithBad('themeSeedColor', 34082).themeSeedColor, '34082');
    });

    test('null 按缺键回默认', () {
      expect(parseWithBad('themeSeedColor', null).themeSeedColor, '#2563EB');
    });
  });

  group('_listOrNull 口径（经由 homeGridMenuActions）', () {
    test('List 原样交给下游归一（含非字符串项剔除）', () {
      final restored = parseWithBad('homeGridMenuActions', <Object?>[
        'exams',
        42,
        null,
        'support',
      ]);
      // normalize 剔除非字符串并补钉住项。
      expect(restored.homeGridMenuActions, [
        'exams',
        'support',
        HomeGridMenu.pinnedActionId,
      ]);
    });

    test('非 List（字符串 / Map）按缺键处理', () {
      expect(
        parseWithBad('homeGridMenuActions', 'exams').homeGridMenuActions,
        isEmpty,
      );
      expect(
        parseWithBad('homeGridMenuActions', {'a': 1}).homeGridMenuActions,
        isEmpty,
      );
    });
  });

  test('多类坏值同时出现：每个字段各自按口径兜底，整份设置不回退', () {
    final json = validJson()
      ..['semesterWeekCount'] = 'twenty'
      ..['glassDockShowWeekTab'] = 'yes'
      ..['savedThemes'] = 'oops'
      ..['themeSeedColor'] = 123
      ..['pageTransitionSpeed'] = 'fast'
      ..['wallpaperHistory'] = 42
      ..['sections'] = {'bad': 'shape'}
      ..['enableHaptics'] = 1;

    final restored = TimetableSettings.fromJson(json);

    // 解析没抛（能走到这里就是证据），且每个坏字段都按口径落地：
    // 数字字符串被「有值就收」转成 '123'，其余按缺键回默认。
    expect(restored.semesterWeekCount, 20);
    expect(restored.glassDockShowWeekTab, isTrue);
    expect(restored.savedThemes, isEmpty);
    expect(restored.themeSeedColor, '123');
    expect(
      restored.pageTransitionSpeed,
      TimetableSettings.defaultPageTransitionSpeed,
    );
    expect(restored.wallpaperHistory, isEmpty);
    expect(restored.sections, TimetableSettings.defaults().sections);
    expect(restored.enableHaptics, isTrue);
    // 没被破坏的字段仍然读得出来。
    expect(restored.timetableHideWeekends, isFalse);
    expect(restored.courseCardFontSize, 9);
  });

  test('合法对象 toJson → fromJson → toJson：两次 JSON 完全相等', () {
    final original = TimetableSettings.defaults().copyWith(
      semesterStartDate: DateTime(2026, 9, 7),
      semesterWeekCount: 18,
      activeTimeSchemeId: 'summer',
      sectionHeight: 72.5,
      compactFontSize: 10,
      themeSeedColor: '#FF0000',
      timetablePageBackgroundColor: '#112233',
      courseCardTitleColorLight: '#0D47A1',
      weekdayBarAccentColorDark: '#93C5FD',
      enableHaptics: false,
      timetableHideWeekends: true,
      glassDockShowWeekTab: false,
      glassDockButtonIconName: 'star',
      homeGridMenuActions: ['overview', 'tasks'],
      liveEnableMiuiIslandLabelImage: true,
      liveMiuiIslandLabelFontColor: '#FDE68A',
      liveMiuiIslandLabelFontSize: 18,
      liveShowBeforeClassMinutes: 5,
      appLocaleTag: 'en',
      appFontWeight: 350,
      appTextScale: 1.25,
      // 档位与参数必须成对设置：fromJson 会把「参数对不上档位」的存档
      // 收敛成 custom / 反推档位（LiquidGlassPresetX.reconcileStoredPreset，
      // 2026-10-07 口径），只设参数不设档位时第二次 toJson 的档位键就会变。
      liquidGlassPreset: LiquidGlassPreset.dense,
      liquidGlassTuning: LiquidGlassTuning.presetDense,
      liquidGlassTuningDark: LiquidGlassTuning.presetClear,
      linkLiquidGlassTuning: false,
      wallpaperHistory: const [
        WallpaperHistoryEntry(key: '/data/a.png', usedAt: 10),
      ],
    );

    final first = original.toJson();
    final roundTripped = TimetableSettings.fromJson(
      jsonDecode(jsonEncode(first)) as Map<String, dynamic>,
    );
    final second = roundTripped.toJson();

    // 深比较 + 编码串逐字节比较，双保险。
    expect(second, equals(first));
    expect(jsonEncode(second), jsonEncode(first));

    // 第三轮仍稳定（收敛，不再漂移）。
    final third = TimetableSettings.fromJson(second).toJson();
    expect(jsonEncode(third), jsonEncode(first));
  });
}
