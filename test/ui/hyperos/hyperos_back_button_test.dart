import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

/// 子页左上角返回键的契约：**上游圆形钮的骨架 + 我们自己那块标准档液态玻璃**。
///
/// 2026-09-19 起材质换成液态玻璃（用户口径：「返回按钮……只能永远是玻璃然后标准档位」），
/// 但上游那颗 `MiuixGlassIconButton` 留着只负责图标、44×44 命中区与按压缩放
/// （它的 `surfaceAlpha` 恒为 0，那层材质一次都不画）。这里同时钉住两件事：
/// 骨架照旧，圆底那块是 pinned 的液态玻璃。
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

  /// 圆底那块玻璃（停在页顶时不存在）。
  Finder glassCircle() => find.descendant(
    of: find.byType(HyperosBackButton),
    matching: find.byType(LiquidGlassSurface),
  );

  /// 外浮影：按钮层统一垫的那一份（key 精确钉住）。实底兜底在测试环境里会
  /// 渲染且旧版自带阴影 —— 谓词类匹配分不清两者，所以用 key。
  Finder backShadow() => find.byKey(const ValueKey('hyperos-back-button-shadow'));

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
    // 骨架留着，但它自己那层材质必须一次都不画（换成下面那块玻璃）。
    expect(tester.widget<MiuixGlassIconButton>(button).surfaceAlpha, 0);
  });

  testWidgets('circle stays hidden at rest and shows once content tucks under '
      'the header', (WidgetTester tester) async {
    await pumpSubpage(tester, onBack: () {}, rows: 20);

    // 停在页顶：没有圆底，也没有浮影 —— 光箭头不带阴影（用户口径 2026-09-23）。
    expect(glassCircle(), findsNothing);
    expect(backShadow(), findsNothing);

    final scrollable = find.descendant(
      of: find.byType(HyperosListView),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -160));
    await tester.pump();

    // 内容压到顶栏带下面（与顶栏磨砂同一判据）：圆底出现，且是**锁标准档**的玻璃。
    expect(
      HyperosHeaderUnderContentScope.of(
        tester.element(find.byType(HyperosBackButton)),
      ),
      isTrue,
    );
    expect(glassCircle(), findsOneWidget);
    final glass = tester.widget<LiquidGlassSurface>(glassCircle());
    expect(
      glass.role,
      LiquidGlassRole.pinnedChrome,
      reason: '返回键永远是液态玻璃的标准档，用户改不动它的材质',
    );
    expect(glass.borderRadius, 22, reason: '44 直径的圆：圆角取半径');
    expect(
      glass.maxRefraction,
      0,
      reason: '边缘不外推采样：标准档那 8dp 位移会让最外一圈读到圆外约 8dp 处的内容，'
          '圆钮顶到带顶只有 4dp，于是顶部读成一条暗弧（真机口径 2026-09-21）',
    );
    // 圆底在显影：垫一圈**同源**浮影（与首页球 / 弹窗同一处定义），用户口径
    // 「圈圈显示的时候加一点点阴影」——不多垫、也不在玻璃兜底里各画一份。
    expect(backShadow(), findsOneWidget);
    // 上游那层材质始终不画，圆底只由我们的玻璃负责。
    expect(surfaceAlphaOf(tester), 0);

    // 滑回页顶：圆底收回，仍是同一颗按钮（没有换 widget、没有重挂）。
    await tester.drag(scrollable, const Offset(0, 160));
    await tester.pump();

    expect(glassCircle(), findsNothing);
    expect(backShadow(), findsNothing, reason: '圆底收回，浮影也跟着收');
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
    expect(glassCircle(), findsOneWidget);

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
