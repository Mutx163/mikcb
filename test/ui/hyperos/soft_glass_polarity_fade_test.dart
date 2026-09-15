import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// 压在壁纸上的玻璃表面，其极性（衬底 + 墨色）要等**异步的壁纸亮度采样**落地才能
/// 定；落地前只能按主题猜。猜错时直接切换就是一次可见跳变 —— 真机反馈
/// （2026-09-15）：柔光档进 / 出壁纸位置选择页，三个悬浮按钮"先冒浅色实底再变玻璃",
/// 闪一下。这条守的是"修正必须走渐变"。
void main() {
  const lightInk = Color(0xFF1A1A1A);
  const darkInk = Color(0xFFFFFFFF);
  const lightWash = Color(0x4DFFFFFF);
  const darkWash = Color(0x47000000);

  Future<void> pumpPolarity(
    WidgetTester tester, {
    required Color ink,
    required Color wash,
  }) {
    return tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SoftGlassPolarityFade(
          ink: ink,
          wash: wash,
          builder: (context, ink, wash) => ColoredBox(
            color: wash,
            child: Text('x', style: TextStyle(color: ink)),
          ),
        ),
      ),
    );
  }

  Color renderedWash(WidgetTester tester) =>
      tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

  Color renderedInk(WidgetTester tester) =>
      tester.widget<Text>(find.text('x')).style!.color!;

  testWidgets('首帧直接落在传入极性上（不做动画）', (tester) async {
    await pumpPolarity(tester, ink: lightInk, wash: lightWash);
    expect(renderedInk(tester), lightInk);
    expect(renderedWash(tester), lightWash);
  });

  testWidgets('极性翻转时走渐变：中途既不等于旧值也不等于新值', (tester) async {
    await pumpPolarity(tester, ink: lightInk, wash: lightWash);

    // 采样落地：极性翻转。
    await pumpPolarity(tester, ink: darkInk, wash: darkWash);
    // 动画启动帧（t=0）仍是旧值。
    expect(renderedInk(tester), lightInk);

    await tester.pump(const Duration(milliseconds: 120));
    final midInk = renderedInk(tester);
    final midWash = renderedWash(tester);
    expect(midInk, isNot(lightInk));
    expect(midInk, isNot(darkInk));
    expect(midWash, isNot(lightWash));
    expect(midWash, isNot(darkWash));

    await tester.pump(const Duration(milliseconds: 400));
    expect(renderedInk(tester), darkInk);
    expect(renderedWash(tester), darkWash);
  });

  testWidgets('极性没变时不产生多余动画', (tester) async {
    await pumpPolarity(tester, ink: darkInk, wash: darkWash);
    await pumpPolarity(tester, ink: darkInk, wash: darkWash);
    await tester.pump(const Duration(milliseconds: 120));
    expect(renderedInk(tester), darkInk);
    expect(renderedWash(tester), darkWash);
  });
}
