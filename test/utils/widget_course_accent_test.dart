import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/course_color_palette.dart';
import 'package:university_timetable/utils/widget_course_accent.dart';

/// 对比度用引擎自带的 Color.computeLuminance：被测实现的输出由引擎判定，
/// 而不是由测试自己复算一份可能写错的公式。
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

Color _argb(int value) => Color(value);

/// 浅色小组件卡底（solid #F8FAFC / glass #E6FFFFFF 落在白壁纸上的等效值）。
const List<Color> kLightWidgetBgs = [
  Color(0xFFF8FAFC),
  Color(0xFFF0F0EE),
  Color(0xFFFFFFFF),
];

/// 夜间卡底（solid #FF1E293B / 常见深色壁纸近似）。
const List<Color> kDarkWidgetBgs = [
  Color(0xFF1E293B),
  Color(0xFF101828),
  Color(0xFF2A3341),
];

void main() {
  group('WidgetCourseAccentMode', () {
    test('three modes map to stable values', () {
      expect(WidgetCourseAccentMode.off.value, 'off');
      expect(WidgetCourseAccentMode.bar.value, 'bar');
      expect(WidgetCourseAccentMode.barAndText.value, 'bar_and_text');
    });

    test('unknown value falls back to bar+text (legacy boolean true)', () {
      expect(
        WidgetCourseAccentModeX.fromValue(null),
        WidgetCourseAccentMode.barAndText,
      );
      expect(
        WidgetCourseAccentModeX.fromValue('legacy'),
        WidgetCourseAccentMode.barAndText,
      );
      expect(
        WidgetCourseAccentModeX.fromValue('off'),
        WidgetCourseAccentMode.off,
      );
    });

    test('semantic flags: bar mode never tints text', () {
      expect(WidgetCourseAccentMode.off.showsBar, isFalse);
      expect(WidgetCourseAccentMode.off.showsText, isFalse);
      expect(WidgetCourseAccentMode.bar.showsBar, isTrue);
      expect(WidgetCourseAccentMode.bar.showsText, isFalse);
      expect(WidgetCourseAccentMode.barAndText.showsBar, isTrue);
      expect(WidgetCourseAccentMode.barAndText.showsText, isTrue);
    });
  });

  group('accent bar contrast over the full preset palette', () {
    test('light background: every palette color clears 3:1', () {
      for (final hex in kPresetCourseColorHexes) {
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: false,
        );
        expect(bar, isNotNull, reason: '$hex should resolve a bar color');
        for (final bg in kLightWidgetBgs) {
          final ratio = _contrast(_argb(bar!), bg);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: 'bar of $hex on $bg is only ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('gradient background: every palette color clears 3:1', () {
      const gradientEnds = [Color(0xFF0F766E), Color(0xFF2563EB)];
      for (final hex in kPresetCourseColorHexes) {
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'gradient',
          darkMode: false,
        );
        expect(bar, isNotNull, reason: '$hex should resolve a bar color');
        for (final bg in gradientEnds) {
          final ratio = _contrast(_argb(bar!), bg);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                'gradient bar of $hex on $bg is only ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });

    test('dark background: every palette color clears 3:1', () {
      for (final hex in kPresetCourseColorHexes) {
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: true,
        );
        expect(bar, isNotNull, reason: '$hex should resolve a bar color');
        for (final bg in kDarkWidgetBgs) {
          final ratio = _contrast(_argb(bar!), bg);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: 'dark bar of $hex on $bg is only ${ratio.toStringAsFixed(2)}:1',
          );
        }
      }
    });
  });

  group('accent text contrast', () {
    test('light chips: beats the current fixed grey ink (3.94:1)', () {
      const chipStrong = Color(0xFFE0EAFF);
      const chipDim = Color(0xFFEEF2F7);
      var worst = 99.0;
      for (final hex in kPresetCourseColorHexes) {
        final text = WidgetCourseAccent.accentTextArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: false,
        );
        expect(text, isNotNull);
        worst = [
          worst,
          _contrast(_argb(text!), chipStrong),
          _contrast(_argb(text), chipDim),
        ].reduce((a, b) => a < b ? a : b);
      }
      // 现状固定灰字 #64748B 对 #E0EAFF 仅 3.94:1。
      expect(worst, greaterThanOrEqualTo(4.5));
    });

    test('gradient style keeps white text (never tints the hero title)', () {
      for (final hex in kPresetCourseColorHexes) {
        expect(
          WidgetCourseAccent.accentTextArgb(
            hex,
            backgroundStyle: 'gradient',
            darkMode: false,
          ),
          isNull,
          reason: 'gradient text must stay white, got a tint for $hex',
        );
      }
    });

    test('light bar never brightens a dark course', () {
      for (final hex in kPresetCourseColorHexes) {
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: false,
        );
        if (bar == null) continue;
        final before = Color(int.parse('FF${hex.substring(1)}', radix: 16));
        expect(
          _argb(bar).computeLuminance(),
          lessThanOrEqualTo(before.computeLuminance() + 0.001),
          reason: '$hex was brightened on a light card',
        );
      }
    });

    test('dark bar never darkens a bright course', () {
      for (final hex in kPresetCourseColorHexes) {
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: true,
        );
        if (bar == null) continue;
        final before = Color(int.parse('FF${hex.substring(1)}', radix: 16));
        expect(
          _argb(bar).computeLuminance(),
          greaterThanOrEqualTo(before.computeLuminance() - 0.001),
          reason: '$hex was darkened on a dark card',
        );
      }
    });

    test('dark mode text clears 4.5:1 on night chips', () {
      const nightChipStrong = Color(0xFF2C4A73);
      const nightChipDim = Color(0xFF324561);
      for (final hex in kPresetCourseColorHexes) {
        final text = WidgetCourseAccent.accentTextArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: true,
        );
        expect(text, isNotNull);
        expect(
          _contrast(_argb(text!), nightChipStrong),
          greaterThanOrEqualTo(4.5),
          reason: '$hex on night chip strong is too low',
        );
        expect(
          _contrast(_argb(text), nightChipDim),
          greaterThanOrEqualTo(4.5),
          reason: '$hex on night chip dim is too low',
        );
      }
    });
  });

  group('hue preservation', () {
    test('clamping never shifts the hue family (drift < 3 deg)', () {
      for (final hex in kPresetCourseColorHexes) {
        final before = Color(int.parse('FF${hex.substring(1)}', radix: 16));
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: false,
        );
        if (bar == null) continue;
        final after = _argb(bar);
        final hslBefore = HSLColor.fromColor(before);
        final hslAfter = HSLColor.fromColor(after);
        // 极低饱和的灰系没有色相可言，跳过。
        // 低饱和的灰系没有「色相家族」可言，四舍五入后漂移不具意义。
        if (hslBefore.saturation < 0.12) continue;
        var drift = (hslAfter.hue - hslBefore.hue).abs();
        if (drift > 180) drift = 360 - drift;
        expect(
          drift,
          lessThan(3.0),
          reason: '$hex drifted ${drift.toStringAsFixed(2)} deg',
        );
      }
    });

    test('already-readable dark colors are left untouched (one-sided clamp)', () {
      // 单向钳制：浅卡上只压暗，绝不把深色提亮（提亮会朝底色靠、反而更糊）。
      // #1D4ED8 / #334155 这类本来就在带内的深色必须原样输出。
      for (final hex in ['#1D4ED8', '#334155', '#047857', '#B91C1C']) {
        final bar = WidgetCourseAccent.accentBarArgb(
          hex,
          backgroundStyle: 'solid',
          darkMode: false,
        );
        expect(
          bar,
          0xFF000000 | int.parse(hex.substring(1), radix: 16),
          reason: '$hex should pass through unchanged',
        );
      }
    });
  });

  group('missing / malformed colors', () {
    test('blank or malformed hex yields no accent (silent fallback)', () {
      for (final bad in ['', '   ', 'null', '#12345', 'rgb(1,2,3)', '#GGGGGG']) {
        expect(
          WidgetCourseAccent.accentBarArgb(
            bad,
            backgroundStyle: 'solid',
            darkMode: false,
          ),
          isNull,
          reason: '$bad should be treated as no course color',
        );
        expect(
          WidgetCourseAccent.accentTextArgb(
            bad,
            backgroundStyle: 'solid',
            darkMode: false,
          ),
          isNull,
        );
      }
      expect(
        WidgetCourseAccent.accentBarArgb(
          null,
          backgroundStyle: 'solid',
          darkMode: false,
        ),
        isNull,
      );
    });

    test('shorthand-free 6-digit hex without # is accepted', () {
      final bar = WidgetCourseAccent.accentBarArgb(
        '2196F3',
        backgroundStyle: 'solid',
        darkMode: false,
      );
      expect(bar, isNotNull);
    });
  });
}
