import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/widgets/week_selector_picker_sheet.dart';

import '../helpers_test_app.dart';

/// 液态玻璃通透面板上平涂 #E8E8E8 格子与 99 灰说明字跟玻璃底融成一片
/// （用户报告：按钮文字发灰看不清、按钮与底色同色无边框）。回归锚点：
/// 液态玻璃下格子必须用半透明白井 + 描边 + onSurface 纯黑墨；磨砂/实底
/// 保持原 Miuix 平涂样式不受影响。
void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    required FrostedGlassMode mode,
  }) async {
    await tester.pumpWidget(
      FrostedAppearanceScope(
        appearance: FrostedAppearance(
          sheetBlurSigma: 15,
          sheetTintAlpha: 0.7,
          sheetBarrierAlpha: 0.2,
          glassMode: mode,
        ),
        child: TestApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showWeekSelectorPickerSheet(
                context,
                availableWeeks: const [1, 2, 3, 4],
                visibleWeek: 2,
                currentSemesterWeek: 2,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Material cellMaterial(WidgetTester tester, String label) {
    return tester.widget<Material>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Material))
          .first,
    );
  }

  Ink? cellInk(WidgetTester tester, String label) {
    final ink = find
        .ancestor(of: find.text(label), matching: find.byType(Ink));
    return ink.evaluate().isEmpty
        ? null
        : tester.widget<Ink>(ink.first);
  }

  Color cellTextColor(WidgetTester tester, String label) {
    return tester.widget<Text>(find.text(label)).style!.color!;
  }

  testWidgets('liquid glass: cells use translucent well + edge + black ink', (
    tester,
  ) async {
    await pumpSheet(tester, mode: FrostedGlassMode.liquidGlass);

    // 非选中格子：白井 + 描边 + 纯黑墨（用户预期「显示为黑色」）。
    final material = cellMaterial(tester, '第 1 周');
    expect(material.color, Colors.white.withValues(alpha: 0.55));
    final ink = cellInk(tester, '第 1 周');
    expect(ink, isNotNull);
    expect(ink!.decoration, isA<BoxDecoration>());
    final decoration = ink.decoration! as BoxDecoration;
    expect(decoration.border, isA<Border>());
    expect(cellTextColor(tester, '第 1 周'), const Color(0xFF000000));

    // 当前周格子维持主题蓝 + 白字，不加描边。
    expect(cellMaterial(tester, '第 2 周').color, const Color(0xFF3482FF));
    expect(cellTextColor(tester, '第 2 周'), const Color(0xFFFFFFFF));
    expect(cellInk(tester, '第 2 周')!.decoration, isNull);

    // 「共 N 周」说明字改主墨色（99 灰在通透玻璃上看不清）。
    expect(find.byType(HyperosSectionDescription), findsNothing);
    expect(
      tester.widget<Text>(find.text('共 4 周')).style!.color,
      const Color(0xFF333333),
    );
  });

  testWidgets('frosted mode: legacy flat Miuix chip is unchanged', (
    tester,
  ) async {
    await pumpSheet(tester, mode: FrostedGlassMode.frosted);

    expect(cellMaterial(tester, '第 1 周').color, const Color(0xFFE8E8E8));
    expect(cellTextColor(tester, '第 1 周'), const Color(0xFF303030));
    expect(cellInk(tester, '第 1 周')!.decoration, isNull);

    expect(find.byType(HyperosSectionDescription), findsOneWidget);
  });
}
