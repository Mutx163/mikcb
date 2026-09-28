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

  group('resolveThemeSeedDisabled：禁用/被屏蔽态 = 对应颜色浅色', () {
    test('浅色绿 seed → 浅绿（非包默认浅蓝）', () {
      final c =
          resolveThemeSeedDisabled(const Color(0xFF5CA502), Brightness.light)!;
      expect(c, Color.lerp(const Color(0xFF5CA502), Colors.white, 0.7));
      expect(c, isNot(const Color(0xFFC2D9FF)));
      expect(c.r, greaterThan(c.b)); // 暖绿色浅底，非冷蓝
    });

    test('深色绿 seed → 深绿（非包默认暗蓝）', () {
      final c =
          resolveThemeSeedDisabled(const Color(0xFF5CA502), Brightness.dark)!;
      expect(c, Color.lerp(const Color(0xFF5CA502), const Color(0xFF242424), 0.7));
      expect(c, isNot(const Color(0xFF253E64)));
      expect(c.g, greaterThan(c.b));
    });

    test('accent 为 null → null（调用方回落包默认）', () {
      expect(resolveThemeSeedDisabled(null, Brightness.light), isNull);
      expect(resolveThemeSeedDisabledInk(null, Brightness.dark), isNull);
    });
  });

  group('resolveThemeSeedDisabledInk：禁用底上的墨水', () {
    test('浅色近白；深色为比禁用底更亮的强调色混色', () {
      expect(
        resolveThemeSeedDisabledInk(const Color(0xFF5CA502), Brightness.light),
        const Color(0xFFFCFCFC),
      );
      final track =
          resolveThemeSeedDisabled(const Color(0xFF5CA502), Brightness.dark)!;
      final ink =
          resolveThemeSeedDisabledInk(const Color(0xFF5CA502), Brightness.dark)!;
      expect(ink, Color.lerp(const Color(0xFF5CA502), const Color(0xFF242424), 0.35));
      // 深色墨水比 0.7 混色的禁用底更亮：被屏蔽 thumb 压在底上可见。
      expect(ink.computeLuminance(), greaterThan(track.computeLuminance()));
    });
  });

  group('disabledInkOn：禁用按钮的字色从底色推出来', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    /// 用户实际能选到的 seed（含中性灰 / 近黑——旧实现在这两种下最惨）。
    const seeds = <String>[
      '#3482FF',
      '#277AF7',
      '#5CA502',
      '#F5C518',
      '#FF6B00',
      '#808080',
      '#7F7F7F',
      '#4A4A4A',
      '#2A2A2A',
      '#000000',
      '#FFFFFF',
    ];

    /// 走生产路径取禁用底色：[HyperosColors.disabledSecondary] 会先解析
    /// accent，解析不到（深色模式的近黑 seed 按设计返回 null）就回落包默认。
    /// 这里直接复用它，别在测试里重抄一遍回落逻辑——抄一遍就会漏掉这条分支。
    Future<Color> disabledFillFor(
      WidgetTester tester,
      String seed,
      Brightness brightness,
    ) async {
      late Color fill;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: seed,
            child: Builder(
              builder: (context) {
                fill = HyperosColors.disabledSecondary(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return fill;
    }

    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('${brightness.name}：每个 seed 的禁用底色上都达到 4.5:1', (tester) async {
        for (final seed in seeds) {
          final bg = await disabledFillFor(tester, seed, brightness);
          final ink = disabledInkOn(bg);
          expect(
            contrast(ink, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'seed=$seed brightness=$brightness bg=$bg ink=$ink',
          );
        }
      });
    }

    test('无 seed 的包默认底色同样达标', () {
      for (final bg in const [Color(0xFFF2F2F2), Color(0xFF404040)]) {
        expect(contrast(disabledInkOn(bg), bg), greaterThanOrEqualTo(4.5));
      }
    });

    // 旧实现的字色是写死的 Miuix 灰（浅色 #B2B2B2），而底色跟着 seed 走，
    // 两者不同源必然撞色。这条把当时的实测值钉住，说明为什么要改。
    test('回归锚点：旧固定灰在中性灰/近黑 seed 下确实不可读', () {
      const oldInk = Color(0xFFB2B2B2);
      for (final seed in const ['#2A2A2A', '#000000', '#808080']) {
        final bg = resolveThemeSeedDisabled(
          resolveThemeSeedAccent(seed, Brightness.light),
          Brightness.light,
        )!;
        expect(contrast(oldInk, bg), lessThan(3.0), reason: 'seed=$seed');
      }
    });

    // 中等亮度底色上只按 luminance>0.5 选黑/白会翻车：底色偏亮时往白混只会更近，
    // 怎么混都到不了 4.5（#B3B3B3 就是这种）。所以两个方向都要试。
    test('中等亮度底色也达标（#B3B3B3 这一类，单方向会失败）', () {
      const bg = Color(0xFFB3B3B3);
      expect(bg.computeLuminance(), lessThan(0.5));
      expect(contrast(disabledInkOn(bg), bg), greaterThanOrEqualTo(4.5));
    });

    test('取最小达标混比，不会一律压成纯黑', () {
      const bg = Color(0xFFF2F2F2);
      final ink = disabledInkOn(bg);
      expect(ink, isNot(Colors.black));
      // 更亮的底色应当得到更浅的字（离达标线更近）
      expect(
        disabledInkOn(const Color(0xFFFFFFFF)).computeLuminance(),
        greaterThan(ink.computeLuminance()),
      );
    });

    test('墨水带着主题色的色相，不是与主题无关的 foreign gray', () {
      final blueBg = resolveThemeSeedDisabled(
        resolveThemeSeedAccent('#3482FF', Brightness.light),
        Brightness.light,
      )!;
      final blueInk = disabledInkOn(blueBg);
      expect(blueInk.b, greaterThan(blueInk.r));
    });
  });

  group('Miuix 被屏蔽开关（disabled）：开启侧轨道 = 主题色浅色状态', () {
    testWidgets('屏蔽开关开/关两侧轨道均为绿浅色，可操作关轨道仍中性', (tester) async {
      late MiuixColors colors;
      late MiuixSwitchColors switchColors;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: '#5CA502', // 绿色，对应线上截图的场景
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
      // 被屏蔽开关（开态）轨道 = 绿浅色，而非包默认浅蓝 #C2D9FF。
      expect(
        switchColors.disabledCheckedTrackColor,
        Color.lerp(const Color(0xFF5CA502), Colors.white, 0.7),
      );
      expect(switchColors.disabledCheckedTrackColor, isNot(base.disabledPrimary));
      // 开态被屏蔽 thumb = 近白墨水。
      expect(switchColors.disabledCheckedThumbColor, const Color(0xFFFCFCFC));
      // 仍可操作的关闭轨道保持中性规范色（正常关着不是主题色）。
      expect(switchColors.uncheckedTrackColor, base.secondary);
      // 被屏蔽的关闭侧轨道 = 绿浅色（与开侧同口径），而非中性灰。
      expect(
        switchColors.disabledUncheckedTrackColor,
        Color.lerp(const Color(0xFF5CA502), Colors.white, 0.7),
      );
      expect(
        switchColors.disabledUncheckedTrackColor,
        isNot(base.disabledSecondary),
      );
      // 禁用滑杆底色同步跟随 seed（非包默认浅蓝）。
      expect(colors.disabledPrimarySlider, isNot(base.disabledPrimarySlider));
    });
  });

  group('HyperosColors.disabled 家族跟随 seed（浅色状态）', () {
    testWidgets('浅色绿 seed → disabledPrimary 为绿浅色', (tester) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: '#5CA502',
            child: Builder(
              builder: (context) {
                result = HyperosColors.disabledPrimary(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(result, Color.lerp(const Color(0xFF5CA502), Colors.white, 0.7));
      expect(result, isNot(const Color(0xFFC2D9FF)));
    });

    testWidgets('未挂 ThemeSeedScope → 维持 Miuix 固定浅蓝', (tester) async {
      late Color result;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
          home: Builder(
            builder: (context) {
              result = HyperosColors.disabledPrimary(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(result, const Color(0xFFC2D9FF));
    });

    testWidgets('深色绿 seed → disabledOnPrimary 为绿暗色且亮于禁用底',
        (tester) async {
      late Color ink;
      late Color track;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
          home: ThemeSeedScope(
            seedHex: '#5CA502',
            child: Builder(
              builder: (context) {
                ink = HyperosColors.disabledOnPrimary(context);
                track = HyperosColors.disabledPrimary(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(ink, isNot(const Color(0xFF677993))); // 非包默认灰蓝
      expect(ink.computeLuminance(), greaterThan(track.computeLuminance()));
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
