import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/performance_settings_snapshot.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';

/// 断言的是**日志里会出现的那些键与值**（读日志的人看到的东西），不是内部实现。
///
/// 最该守住的两条：
/// * 快照只读「有效值」。渲染侧拿到的材质参数与这里写进日志的必须同源，
///   否则日志会写一个「看起来对、实际不是这样」的档位，比没有日志更误导；
/// * 改设置时的指纹守卫要准。漏报会丢掉「改完这项之后开始卡」的因果，
///   误报会把日志刷满 —— 两个方向都有用例。
void main() {
  Map<String, Object?> snapshotOf(TimetableSettings s) =>
      buildPerformanceSettingsSnapshot(s);

  group('默认档位', () {
    test('出厂默认是经典磨砂 + 高斯档', () {
      final snapshot = snapshotOf(TimetableSettings.defaults());

      expect(snapshot['glassMode'], 'gaussian');
      expect(snapshot['blurEnabled'], isTrue);
    });

    test('八个表面各自的材质都写进快照', () {
      final snapshot = snapshotOf(TimetableSettings.defaults());

      // 顶栏 2026-09-20 起只有「液态 / 实体」两档，出厂默认是液态玻璃；
      // 子页顶栏是**另一根轴**（`subpageHeaderBlurStyle`），仍是渐进模糊；坞是
      // 基础磨砂（跟随全局档位）；弹窗家族那四个读数 2026-09-19 起锁标准档，
      // 恒为液态玻璃（与用户设置无关）；出厂卡片是实体（高斯卡要用户显式开）。
      expect(snapshot['surfaceHomeBand'], 'liquidGlass');
      expect(snapshot['surfaceSubpageHeader'], 'frostProgressive');
      expect(snapshot['surfaceDock'], 'frost');
      expect(snapshot['surfaceSheetDialog'], 'liquidGlass');
      expect(snapshot['surfaceSelectSheet'], 'liquidGlass');
      expect(snapshot['surfacePopup'], 'liquidGlass');
      expect(snapshot['surfacePickerButtons'], 'liquidGlass');
      expect(snapshot['surfaceCourseCard'], 'solid');
    });

    test('关掉模糊总开关后跟随用户的表面回落实体，弹窗家族仍是液态玻璃', () {
      final snapshot = snapshotOf(
        TimetableSettings.defaults().copyWith(frostedBlurEnabled: false),
      );

      expect(snapshot['glassMode'], 'solid');
      expect(snapshot['surfaceDock'], 'solid');
      // 弹窗家族锁标准档：模糊总开关不参与它的材质判定（唯一能摘下来的是
      // 设备级的技术 / 系统降级，不在本推导范围内）。
      expect(snapshot['surfacePopup'], 'liquidGlass');
      expect(snapshot['surfaceSubpageHeader'], 'solid');
    });
  });

  group('材质参数取的是有效值（含回落）', () {
    test('液态调参为 null 时走内置常量，仍能读到真实光学参数', () {
      final snapshot = snapshotOf(TimetableSettings.defaults());

      expect(snapshot['lgTuningSource'], 'builtin');
      // 内置兜底档的实测值（LiquidGlassTuning.defaults）。
      expect(snapshot['lgRefraction'], LiquidGlassTuning.defaultRefraction);
      expect(snapshot['lgRefractionBand'], LiquidGlassTuning.defaultRefractionBand);
      expect(
        snapshot['lgRefractionEdgePow'],
        LiquidGlassTuning.defaultRefractionEdgePow,
      );
      expect(snapshot['lgRimStrength'], LiquidGlassTuning.defaultRimStrength);
      expect(snapshot['lgRimWidth'], LiquidGlassTuning.defaultRimWidth);
      expect(snapshot['lgBlurSigma'], LiquidGlassTuning.defaultBlurSigma);
      expect(snapshot['lgTintAlpha'], LiquidGlassTuning.defaultTintAlpha);
    });

    test('液态调参非空时标记为 custom 并写出该档的数值', () {
      final dense = LiquidGlassPreset.dense.recommendedTuning;
      final snapshot = snapshotOf(
        TimetableSettings.defaults().copyWith(
          liquidGlassPreset: LiquidGlassPreset.dense,
          liquidGlassTuning: dense,
        ),
      );

      expect(snapshot['lgTuningSource'], 'custom');
      expect(snapshot['lgPreset'], 'dense');
      expect(snapshot['lgRefraction'], dense.refraction);
      expect(snapshot['lgBlurSigma'], dense.blurSigma);
    });
  });

  group('不写进存档的字段也要收集到', () {
    test('壁纸透出范围在快照里（序列化时被刻意丢掉，只能读内存值）', () {
      final settings = TimetableSettings.defaults().copyWith(
        homePageBackgroundScope: HomePageBackgroundScope.header,
      );
      final snapshot = snapshotOf(settings);

      expect(snapshot['backgroundScope'], HomePageBackgroundScope.header);
      expect(snapshot['backgroundScopeRegions'], 'header');
    });

    test('四个区域全开时是可读的列表而不是数字', () {
      final snapshot = snapshotOf(TimetableSettings.defaults());

      expect(
        snapshot['backgroundScopeRegions'],
        'statusBar,header,weekdayBar,timetable',
      );
    });

    test('范围为空时报 none，不是空串', () {
      final snapshot = snapshotOf(
        TimetableSettings.defaults().copyWith(homePageBackgroundScope: 0),
      );

      expect(snapshot['backgroundScopeRegions'], 'none');
    });
  });

  group('课卡文本行', () {
    test('默认只列开启的字段', () {
      final snapshot = snapshotOf(TimetableSettings.defaults());

      // 出厂开：课程名 / 教师 / 地点 / 时间标签 / 周视图课卡的天气行。
      expect(
        snapshot['cardTextFields'],
        'name,teacher,location,timeLabels,weather',
      );
    });

    test('逐项关掉后跟着变', () {
      final snapshot = snapshotOf(
        TimetableSettings.defaults().copyWith(courseCardShowTeacher: false),
      );

      expect(snapshot['cardTextFields'], 'name,location,timeLabels,weather');
    });

    test('全关时报 none', () {
      final snapshot = snapshotOf(
        TimetableSettings.defaults().copyWith(
          courseCardShowName: false,
          courseCardShowTeacher: false,
          courseCardShowLocation: false,
          courseCardShowTime: false,
          courseCardShowTimeLabels: false,
          courseCardShowWeeks: false,
          courseCardShowDescription: false,
          // 天气也是一行文本，不关掉就永远到不了 none。
          weatherShowOnWeekCard: false,
        ),
      );

      expect(snapshot['cardTextFields'], 'none');
    });
  });

  group('环境量（不看你设置但也决定掉帧）', () {
    test('测试环境自报 debug，转场时长按倍率合成', () {
      final snapshot = snapshotOf(TimetableSettings.defaults());

      expect(snapshot['buildMode'], 'debug');
      // 系统缩放 1.0 ÷ 用户速度 1.0 × 300ms 基准。
      expect(snapshot['transitionDurationMs'], 300);
      expect(snapshot['wallpaperConfigured'], isFalse);
    });

    test('用户转场速度会改变实际生效的转场时长', () {
      final snapshot = snapshotOf(
        TimetableSettings.defaults().copyWith(pageTransitionSpeed: 2),
      );

      // _settingsDerivedSnapshot 里也有这项，两边都要跟着变。
      expect(snapshot['pageTransitionSpeed'], 2.0);
    });
  });

  group('改设置时的指纹守卫', () {
    final base = TimetableSettings.defaults();

    test('影响帧率的字段变了要打', () {
      expect(
        shouldLogPerformanceSettingsChange(
          base,
          base.copyWith(frostedSheetBlurSigma: 24),
        ),
        isTrue,
      );
      expect(
        shouldLogPerformanceSettingsChange(
          base,
          base.copyWith(pageTransitionSpeed: 1.5),
        ),
        isTrue,
      );
      expect(
        shouldLogPerformanceSettingsChange(
          base,
          base.copyWith(homePageBackgroundScope: 1),
        ),
        isTrue,
      );
    });

    test('与渲染无关的字段变了不打（否则一次调参会刷一屏）', () {
      expect(
        shouldLogPerformanceSettingsChange(
          base,
          base.copyWith(enableHaptics: false),
        ),
        isFalse,
      );
      expect(
        shouldLogPerformanceSettingsChange(
          base,
          base.copyWith(screenshotSharePromptEnabled: false),
        ),
        isFalse,
      );
    });

    test('一模一样的设置不打', () {
      expect(shouldLogPerformanceSettingsChange(base, base), isFalse);
    });
  });
}
