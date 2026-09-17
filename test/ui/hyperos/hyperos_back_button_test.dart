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
  }) async {
    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          onBack: onBack,
          title: const Text('Settings'),
          child: const HyperosListView(
            children: [
              HyperosListTile(icon: Icons.dark_mode_outlined, title: 'Dark'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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

  testWidgets('tapping the back button invokes onBack', (
    WidgetTester tester,
  ) async {
    var taps = 0;
    await pumpSubpage(tester, onBack: () => taps++);

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
