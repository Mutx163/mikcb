import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// 上游 OS4 弹层的**面板材质注入**契约（`os4_glass_popup_surface.dart`）。
///
/// 注入面本身只是"换个面板"，但有两件事必须钉住：
/// 1. 圆角取上游**已经算好**的形状标量（`transform` 动效期间逐帧 lerp），
///    不能按进度重算，否则注入面与上游几何错开；
/// 2. 二级面板浮在另一块玻璃之上，必须垫共享组捕获的磨砂底，否则液态档会
///    采样到一级面板的玻璃输出（玻璃叠玻璃再折射一遍、读感浑浊）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('圆角直接取上游算好的形状，不按进度重算', () {
    // transform 动效期间上游交下来的就是每帧 lerp 过的 MiuixGlassShape。
    expect(
      os4GlassPopupCornerRadiusOf(const MiuixGlassShape(cornerRadius: 18)),
      18,
    );
    expect(
      os4GlassPopupCornerRadiusOf(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      12,
    );
    // 认不出来的形状退回上游默认圆角，不猜。
    expect(
      os4GlassPopupCornerRadiusOf(const StadiumBorder()),
      MiuixGlassPopupDefaults.cornerRadius,
    );
  });

  testWidgets('一级直接采样，二级垫共享组捕获的磨砂底', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const shape = MiuixGlassShape(cornerRadius: 18);
    const child = SizedBox.shrink();

    final primary =
        hyperosGlassPopupSurface(context, shape, child)
            as HyperosSelectPopupGlass;
    expect(primary.cornerRadius, 18);
    expect(
      primary.useAncestorGroupCapture,
      isFalse,
      reason: '一级面板站在页面上，自己采样背后即可',
    );

    final secondary =
        hyperosGlassPopupSecondarySurface(context, shape, child)
            as HyperosSelectPopupGlass;
    expect(
      secondary.useAncestorGroupCapture,
      isTrue,
      reason: '二级面板浮在一级玻璃之上，不垫底会把一级玻璃的输出折射进去',
    );
    expect(secondary.cornerRadius, 18, reason: '二级与一级同一份几何');
  });

  testWidgets('选择弹层真的换上了注入面（上游内置面板不再出图）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      TestApp(
        home: HyperosSubpage(
          title: const Text('卡片外观设置'),
          onBack: () {},
          child: HyperosListView(
            children: [
              HyperosSelectTile<String>(
                label: '卡片外观',
                items: const {'实体卡片': 'solid', '高斯模糊': 'gaussian'},
                value: 'solid',
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('卡片外观'));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixGlassDropdownPopup), findsOneWidget);

    // 注入面把上游 `MiuixGlassPanel` 整块换成了按全局档位分派的玻璃面。
    // 这条断言是 `surfaceBuilder` 真的接上了的证据 —— 只跑"没回归"的既有用例
    // 是看不出注入有没有生效的。
    expect(
      find.descendant(
        of: find.byType(MiuixGlassDropdownPopup),
        matching: find.byType(HyperosSelectPopupGlass),
      ),
      findsOneWidget,
      reason: '弹层面板应当是项目自己的注入面，而不是上游内置面板',
    );
  });
}
