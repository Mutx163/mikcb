import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/utils/theme_seed_accent.dart';
import 'package:university_timetable/widgets/miuix_font_weight_scope.dart';

/// 主题 seed 接入的回归锚点：八宫格/弹窗/全局强调色统一口径。
void main() {
  group('resolveThemeSeedAccent', () {
    test('可读 seed 原样返回', () {
      final b = resolveThemeSeedAccent('#1447E6', Brightness.light)!;
      expect(b, const Color(0xFF1447E6));
      final dark = resolveThemeSeedAccent('#1447E6', Brightness.dark)!;
      expect(dark, const Color(0xFF1447E6));
    });

    test('浅色高亮 seed（亮黄）原样返回——所见尽可能', () {
      expect(
        resolveThemeSeedAccent('#FCC800', Brightness.light),
        const Color(0xFFFCC800),
      );
    });

    test('深色模式近黑 seed 不可读 → null', () {
      expect(
        resolveThemeSeedAccent('#171717', Brightness.dark),
        isNull,
      );
      // 同色在浅色模式下可读（黑墨按钮）。
      expect(
        resolveThemeSeedAccent('#171717', Brightness.light),
        isNotNull,
      );
    });

    test('null / 非法 hex → null', () {
      expect(resolveThemeSeedAccent(null, Brightness.light), isNull);
      expect(resolveThemeSeedAccent('not-a-color', Brightness.light), isNull);
    });
  });

  group('onAccentInk', () {
    test('高亮强调色用黑墨，深色强调色用白墨', () {
      expect(onAccentInk(const Color(0xFFFCC800)), Colors.black);
      expect(onAccentInk(const Color(0xFF1447E6)), Colors.white);
    });
  });

  group('resolveThemeSeedSurface', () {
    test('浅色亮黄保留原值（与前景可读回落不同）', () {
      final s = resolveThemeSeedSurface('#FCC800', Brightness.light)!;
      expect(s, const Color(0xFFFCC800));
    });

    test('深色近黑向白提亮到可辨识强调面', () {
      final s = resolveThemeSeedSurface('#171717', Brightness.dark)!;
      expect(s, isNot(const Color(0xFF171717)));
      expect(s, isNot(Colors.white));
      expect(s.computeLuminance(), greaterThan(0.2));
      // 同色在浅色下原样（黑底白字按钮天然可读）。
      expect(
        resolveThemeSeedSurface('#171717', Brightness.light),
        const Color(0xFF171717),
      );
    });

    test('深色可读蓝原样返回', () {
      expect(
        resolveThemeSeedSurface('#1447E6', Brightness.dark),
        const Color(0xFF1447E6),
      );
    });

    test('null / 非法 hex → null', () {
      expect(resolveThemeSeedSurface(null, Brightness.light), isNull);
      expect(resolveThemeSeedSurface('nope', Brightness.dark), isNull);
    });
  });

  group('HyperosColors.primary 经 ThemeSeedScope 跟随 seed', () {
    Future<Color> primaryWithSeed(WidgetTester tester, String? seedHex,
        {Brightness brightness = Brightness.light}) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: seedHex,
            child: Builder(
              builder: (context) {
                result = HyperosColors.primary(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return result;
    }

    testWidgets('可读 seed → 返回 seed 本身', (tester) async {
      final c = await primaryWithSeed(tester, '#1447E6');
      expect(c, const Color(0xFF1447E6));
    });

    testWidgets('浅色亮黄 seed → primary 即亮黄（所见即所得）', (tester) async {
      final c = await primaryWithSeed(tester, '#FCC800');
      expect(c, const Color(0xFFFCC800));
    });

    testWidgets('未挂 ThemeSeedScope → 维持 Miuix 固定蓝', (tester) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: Builder(
            builder: (context) {
              result = HyperosColors.primary(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, const Color(0xFF3482FF));
    });

    testWidgets('seed 变化触发依赖组件重建', (tester) async {
      final builder = _ScopeBuilder();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: _SeedChanger(recorder: builder),
        ),
      );
      expect(builder.count, 1);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(builder.count, 2);
    });
  });

  group('HyperosColors.primarySurface（表面强调色）', () {
    Future<Color> surfaceWithSeed(WidgetTester tester, String? seedHex,
        {Brightness brightness = Brightness.light}) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: seedHex,
            child: Builder(
              builder: (context) {
                result = HyperosColors.primarySurface(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return result;
    }

    testWidgets('浅色亮黄 seed → surface 保留亮黄（所见即所得）', (tester) async {
      final s = await surfaceWithSeed(tester, '#FCC800');
      expect(s, const Color(0xFFFCC800));
    });

    testWidgets('深色近黑 seed → 向白提亮的强调面（不是黑也不是固定蓝）', (tester) async {
      final s = await surfaceWithSeed(tester, '#171717',
          brightness: Brightness.dark);
      expect(s, isNot(const Color(0xFF277AF7))); // 非固定暗蓝
      expect(s, isNot(const Color(0xFF171717))); // 非原黑
      expect(s.computeLuminance(), greaterThan(0.2));
    });

    testWidgets('未挂 scope → 维持 Miuix 固定蓝', (tester) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: Builder(
            builder: (context) {
              result = HyperosColors.primarySurface(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, const Color(0xFF3482FF));
    });

    testWidgets('浅色近黑 seed 也原样（可读），黑底白字按钮', (tester) async {
      final s = await surfaceWithSeed(tester, '#171717');
      expect(s, const Color(0xFF171717));
    });
  });

  group('Miuix 开关色：只有开启轨道才是主题色', () {
    testWidgets('开轨道=主题色，关轨道保持包默认 secondary 不被污染', (tester) async {
      late MiuixColors colors;
      late MiuixSwitchColors switchColors;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: '#FCC800',
            child: MiuixFontWeightScope(
              child: Builder(
                builder: (context) {
                  colors = MiuixTheme.of(context).colors;
                  switchColors =
                      MiuixSwitchDefaults.switchColors(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );
      final base = MiuixThemeData.of(Brightness.light).colors;
      // 开态轨道是主题色：亮黄 #FCC800。
      expect(switchColors.checkedTrackColor, const Color(0xFFFCC800));
      // 关态轨道保持包默认 secondary——MiuixSwitch 关色用 secondary，
      // 若被刷成主题色会「关着也是黄的」。
      expect(colors.secondary, base.secondary);
      expect(switchColors.uncheckedTrackColor, base.secondary);
      expect(switchColors.uncheckedTrackColor, isNot(colors.primary));
    });
  });
}

class _ScopeBuilder {
  int count = 0;
}

class _SeedChanger extends StatefulWidget {
  const _SeedChanger({required this.recorder});
  final _ScopeBuilder recorder;

  @override
  State<_SeedChanger> createState() => _SeedChangerState();
}

class _SeedChangerState extends State<_SeedChanger> {
  String? _seed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ThemeSeedScope(
        seedHex: _seed,
        child: Builder(
          builder: (context) {
            HyperosColors.primary(context);
            widget.recorder.count += 1;
            return FilledButton(
              onPressed: () {
                setState(() => _seed = _seed == null ? '#1447E6' : null);
              },
              child: const Text('toggle'),
            );
          },
        ),
      ),
    );
  }
}
