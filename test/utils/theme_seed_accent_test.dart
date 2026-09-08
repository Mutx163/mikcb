import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/utils/theme_seed_accent.dart';

/// 主题 seed 接入的回归锚点：八宫格/弹窗/全局强调色统一口径。
void main() {
  group('resolveThemeSeedAccent', () {
    test('可读 seed 原样返回', () {
      final b = resolveThemeSeedAccent('#1447E6', Brightness.light)!;
      expect(b, const Color(0xFF1447E6));
      final dark = resolveThemeSeedAccent('#1447E6', Brightness.dark)!;
      expect(dark, const Color(0xFF1447E6));
    });

    test('浅色模式高亮 seed（亮黄）不可读 → null', () {
      expect(
        resolveThemeSeedAccent('#FCC800', Brightness.light),
        isNull,
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

    testWidgets('不可读 seed → 回落墨色（非固定蓝）', (tester) async {
      final c = await primaryWithSeed(tester, '#FCC800');
      expect(c, isNot(const Color(0xFF3482FF))); // 未回落到固定蓝
      expect(c, isNot(const Color(0xFFFCC800))); // 也未保留亮黄
      // 浅色模式墨色落在较暗侧。
      expect(c.computeLuminance(), lessThan(0.5));
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

    testWidgets('浅色亮黄 seed → 黄底原色（不像 primary 那样回落墨色）', (tester) async {
      final s = await surfaceWithSeed(tester, '#FCC800');
      expect(s, const Color(0xFFFCC800)); // surface 保留亮黄（不与 primary 的墨色回落混同）
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

    testWidgets('浅色近黑 seed 也原样（黑底白字按钮）', (tester) async {
      final s = await surfaceWithSeed(tester, '#171717');
      expect(s, const Color(0xFF171717));
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
