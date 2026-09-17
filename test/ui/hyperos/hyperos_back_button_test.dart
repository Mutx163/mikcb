import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// 子页左上角返回键的上游一致性契约。
///
/// 上游 OS4 的返回键是 `MiuixGlassIconButton`（直径 44 的圆）+ OS4 的
/// `chevronBackward` 图标（`example/lib/showcase/os4.dart` 的
/// `MiuixGlassTopAppBar.navigationIcon`）。本仓由 [HyperosBackButton] 承接，
/// [HyperosSubpage] 在顶栏的导航位渲染它。
void main() {
  Future<void> pumpSubpage(
    WidgetTester tester, {
    required VoidCallback onBack,
    int rows = 1,
  }) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: onBack,
          title: const Text('Settings'),
          child: HyperosListView(
            children: [
              for (var i = 0; i < rows; i++)
                HyperosListTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Item $i',
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double surfaceAlphaOf(WidgetTester tester) {
    return tester
        .widget<MiuixGlassIconButton>(find.byType(MiuixGlassIconButton))
        .surfaceAlpha;
  }

  testWidgets('subpage nav icon is the upstream circular glass back button', (
    WidgetTester tester,
  ) async {
    await pumpSubpage(tester, onBack: () {});

    final button = find.byType(MiuixGlassIconButton);
    expect(button, findsOneWidget);

    // 上游默认尺寸（`MiuixGlassIconButton` 的 `size` 省略时为 44），
    // 圆角由上游取 `size / 2` —— 这里只锁尺寸，形状是上游的事。
    expect(tester.getSize(button), const Size(44, 44));

    final icon = tester.widget<MiuixIcon>(
      find.descendant(of: button, matching: find.byType(MiuixIcon)),
    );
    expect(icon.vector, same(MiuixIcons.os4.chevronBackward));
  });

  testWidgets('circle stays hidden at rest and shows once content tucks under '
      'the header', (WidgetTester tester) async {
    await pumpSubpage(tester, onBack: () {}, rows: 20);

    // 停在页顶：表面 alpha 为 0，`MiuixGlass.paint` 整块跳过 —— 只有一根箭头。
    expect(surfaceAlphaOf(tester), 0);

    final scrollable = find.descendant(
      of: find.byType(HyperosListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pump();

    // 内容压到顶栏带下面（与顶栏磨砂同一判据）：圆底出现。
    expect(
      HyperosHeaderUnderContentScope.of(
        tester.element(find.byType(HyperosBackButton)),
      ),
      isTrue,
    );
    expect(surfaceAlphaOf(tester), 1);

    // 滑回页顶：圆底收回，仍是同一颗按钮（没有换 widget、没有重挂）。
    await tester.drag(scrollable, const Offset(0, 160));
    await tester.pump();

    expect(surfaceAlphaOf(tester), 0);
    expect(find.byType(MiuixGlassIconButton), findsOneWidget);
  });

  testWidgets('tapping the back button invokes onBack', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await pumpSubpage(tester, onBack: () => taps++);

    await tester.tap(find.byType(MiuixGlassIconButton));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('tapping still works while the circle is showing', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await pumpSubpage(tester, onBack: () => taps++, rows: 20);

    final scrollable = find.descendant(
      of: find.byType(HyperosListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pump();
    expect(surfaceAlphaOf(tester), 1);

    await tester.tap(find.byType(MiuixGlassIconButton));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('HyperosSubpageNoBack still suppresses the back button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpageNoBack(
          child: HyperosSubpage(
            onBack: () {},
            title: const Text('Embedded'),
            child: const HyperosListView(children: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MiuixGlassIconButton), findsNothing);
  });
}
