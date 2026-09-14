import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// 首页顶栏「更多」「爱心」那颗**常驻玻璃球**的契约。
///
/// 这颗球必须与首页菜单弹窗的形变终点同源：弹窗在 progress=0 时把面板摆成
/// 「锚点矩形、圆角 = 短边/2」，画它的是 `hyperosGlassPopupSurface` →
/// [HyperosSelectPopupGlass]。所以按钮侧必须用**同一个组件、同一个半径** ——
/// 一旦有人退回 `MiuixIconButton(backgroundColor:)`（平涂色：没有模糊、没有
/// 边缘高光，颜色还得按壁纸反相）或把半径改成别的值，打开/关闭菜单的交接
/// 瞬间就会露馅（材质不一样 / 圆角跳一档）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget ballAction({bool ball = true}) => TestApp(
    home: FrostedAppearanceScope(
      appearance: const FrostedAppearance(
        sheetBlurSigma: 15,
        sheetTintAlpha: 0.70,
        sheetBarrierAlpha: 0.20,
        glassMode: FrostedGlassMode.softGlass,
      ),
      child: Scaffold(
        body: Center(
          child: FHeaderAction(
            icon: const Icon(Icons.more_vert_rounded),
            semanticsLabel: '更多',
            glassBall: ball,
          ),
        ),
      ),
    ),
  );

  testWidgets('glassBall：与弹窗同一组件、同一半径，走真玻璃材质', (tester) async {
    await tester.pumpWidget(ballAction());
    await tester.pump();

    final ball = tester.widget<HyperosSelectPopupGlass>(
      find.byType(HyperosSelectPopupGlass),
    );
    // 半径 = 图标按钮的最小边长 / 2 = 正圆，与弹窗「锚点短边 / 2」同口径。
    expect(ball.cornerRadius, MiuixIconButtonDefaults.minWidth / 2);

    // 盒子必须正好是那个最小边长：弹窗那颗球的半径是按**锚点短边**算的，
    // 锚点就是这颗按钮的矩形 —— 盒子一变，两边的圆角就对不上。
    expect(
      tester.getSize(find.byType(HyperosSelectPopupGlass)),
      const Size(
        MiuixIconButtonDefaults.minWidth,
        MiuixIconButtonDefaults.minHeight,
      ),
    );

    // 柔光档下必须真的是那块柔光玻璃（而不是平涂色）。
    expect(
      find.descendant(
        of: find.byType(HyperosSelectPopupGlass),
        matching: find.byType(SoftGlassSurface),
      ),
      findsOneWidget,
      reason: '球要跟弹窗一样按全局档位分派材质',
    );
  });

  testWidgets('默认不画球：其它调用点保持透明底', (tester) async {
    await tester.pumpWidget(ballAction(ball: false));
    await tester.pump();

    expect(find.byType(HyperosSelectPopupGlass), findsNothing);
    expect(find.byType(SoftGlassSurface), findsNothing);
  });
}
