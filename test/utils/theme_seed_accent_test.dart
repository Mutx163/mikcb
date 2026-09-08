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
