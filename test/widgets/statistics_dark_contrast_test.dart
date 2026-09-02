// 统计页 Dark Mode 对比度回归（Ref: #84）。
//
// 历史缺陷：
// 1. 图表 tooltip 文字硬编码 Colors.white，而 fl_chart 1.2.0 默认 tooltip
//    面板底色与主题无关（恒为深色）；修复后底色/字色成对走
//    HyperosColors.inverseSurface / onInverseSurface，亮暗各自成立。
// 2. 解锁徽章图标硬编码 Colors.white；修复后走 HyperosColors.onAccent。
// 3. 未解锁徽章 14% 彩色淡填充叠在暗色深灰卡（#2D2D2D）上几乎不可见；
//    修复后暗色下填充 26% / 描边 44% / 图标 86%。
//
// 策略：tooltip 颜色在 painter 内部无法从 widget 树读取，锁 token 解析值；
// 徽章锁定填充用 RepaintBoundary 截图反解叠加 alpha，验证暗色可见度提升。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/statistics_models.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/statistics/achievement_badge.dart';

import '../helpers_test_app.dart';

Widget _host({required Brightness brightness, required Widget child}) {
  return TestApp(
    home: Theme(
      data: ThemeData(brightness: brightness, useMaterial3: true),
      child: Builder(builder: (context) => child),
    ),
  );
}

const Color _darkOnSurface = Color(0xFFF2F2F2);
const Color _lightOnPrimary = Color(0xFFFFFFFF);

void main() {
  testWidgets('onAccent: 亮色白、暗色近白（非纯白 glare）', (tester) async {
    late final Color lightValue;
    late final Color darkValue;

    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        child: Builder(
          builder: (context) {
            lightValue = HyperosColors.onAccent(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        child: Builder(
          builder: (context) {
            darkValue = HyperosColors.onAccent(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(lightValue, _lightOnPrimary);
    expect(darkValue, _darkOnSurface);
  });

  testWidgets('inverseSurface/onInverseSurface 成对换档（tooltip 依赖）',
      (tester) async {
    late final Color lightBg;
    late final Color lightInk;
    late final Color darkBg;
    late final Color darkInk;

    await tester.pumpWidget(
      _host(
        brightness: Brightness.light,
        child: Builder(
          builder: (context) {
            lightBg = HyperosColors.inverseSurface(context);
            lightInk = HyperosColors.onInverseSurface(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        child: Builder(
          builder: (context) {
            darkBg = HyperosColors.inverseSurface(context);
            darkInk = HyperosColors.onInverseSurface(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // 亮色：深底白字（inverseSurface = onSurface 深色）。
    expect(lightBg.computeLuminance(), lessThan(0.3));
    expect(lightInk, _lightOnPrimary);
    // 暗色：浅灰底（surfaceContainerHighest）+ 亮字。
    expect(darkBg, const Color(0xFF2D2D2D));
    expect(darkInk.computeLuminance(), greaterThan(0.8));
    // 任何一档都不允许「底字同色」（白底白字即 tooltip 消失缺陷）。
    expect(
      (lightBg.computeLuminance() - lightInk.computeLuminance()).abs(),
      greaterThan(0.3),
    );
    expect(
      (darkBg.computeLuminance() - darkInk.computeLuminance()).abs(),
      greaterThan(0.3),
    );
  });

  testWidgets('未解锁徽章：暗色填充叠加度高于亮色（深灰卡上可见）',
      (tester) async {
    const achievements = [
      Achievement(
        id: 'scholar',
        icon: Icons.auto_stories_rounded,
        isUnlocked: false,
        progressCurrent: 30,
        progressTarget: 100,
      ),
    ];

    final lightAlpha = await _captureBadgeFillAlpha(
      tester,
      achievements: achievements,
      brightness: Brightness.light,
    );
    final darkAlpha = await _captureBadgeFillAlpha(
      tester,
      achievements: achievements,
      brightness: Brightness.dark,
    );

    // 暗色档（26% 填充）叠加效果必须显著高于亮色档（14%），
    // 否则徽章在深灰卡上不可见（#84 的核心缺陷）。
    expect(darkAlpha, greaterThan(lightAlpha));
    expect(darkAlpha, greaterThan(0.05));
  });

  testWidgets('解锁徽章图标在暗色下走 onAccent，不是硬编码纯白', (tester) async {
    const achievements = [
      Achievement(
        id: 'scholar',
        icon: Icons.auto_stories_rounded,
        isUnlocked: true,
      ),
    ];

    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        child: const AchievementGrid(achievements: achievements),
      ),
    );
    await tester.pumpAndSettle();

    final iconFinder = find.byIcon(Icons.auto_stories_rounded);
    final icon = tester.widget<Icon>(iconFinder);
    expect(
      icon.color,
      HyperosColors.onAccent(tester.element(iconFinder)),
    );
    expect(icon.color, isNot(const Color(0xFFFFFFFF)));
  });
}

/// 渲染锁定徽章并反解徽章填充色相对已知底色的叠加 alpha。
///
/// 采样点取徽章上沿内侧（图标中心上方 12px）：只含填充色，够不到图标。
Future<double> _captureBadgeFillAlpha(
  WidgetTester tester, {
  required List<Achievement> achievements,
  required Brightness brightness,
}) async {
  final cardColor = brightness == Brightness.dark
      ? const Color(0xFF2D2D2D)
      : const Color(0xFFF2F2F2);
  // scholar → HyperosIconColors.blue (#3482FF)，ar/ag/ab 即其 RGB 分量。

  final key = GlobalKey();
  await tester.pumpWidget(
    _host(
      brightness: brightness,
      child: RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: cardColor,
          child: AchievementGrid(achievements: achievements),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  // toImageSync/toByteData 依赖真实 GPU 光栅化回调，须逃出 FakeAsync。
  final snapshot = await runRealAsync(tester, () async {
    final img = boundary.toImageSync();
    final bytes = await img.toByteData();
    return (img, bytes);
  });
  final ui.Image snapshotImage = snapshot.$1;
  final data = snapshot.$2!.buffer.asUint8List();

  final badgeCenter = tester.getCenter(find.byIcon(Icons.auto_stories_rounded));
  final sampleX = badgeCenter.dx.round();
  final sampleY = (badgeCenter.dy - 12).round();

  final boxOrigin = boundary.localToGlobal(Offset.zero);
  final px = (sampleY - boxOrigin.dy).round() * snapshotImage.width +
      (sampleX - boxOrigin.dx).round();

  final r = data[px * 4];
  final g = data[px * 4 + 1];
  final b = data[px * 4 + 2];

  // 反解 alpha：sample = accent*a + card*(1-a)
  final double cr = cardColor.r * 255.0;
  final double cg = cardColor.g * 255.0;
  final double cb = cardColor.b * 255.0;
  const double ar = 0xFF; // accent.r
  const double ag = 0x82; // accent.g
  const double ab = 0xFF; // accent.b
  return ((r - cr) / (ar - cr) +
          (g - cg) / (ag - cg) +
          (b - cb) / (ab - cb)) /
      3;
}
