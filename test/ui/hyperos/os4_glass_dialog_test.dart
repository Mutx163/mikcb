import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
// 捕获点（`UndimmedBackdropCapture`）住在液态玻璃那一层，桶文件没导出它 ——
// 这里按文件直取，与 `hyperos_sheet.dart` 用法一致。
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

/// 居中玻璃对话框（`os4_glass_dialog.dart`）的承载与材质契约。
///
/// 它把上游**声明式**的 `MiuixGlassDialog`（常驻 + `visible` 切换）接到本仓
/// **祈使式**的 `await showXxx(...)` 上，所以有两件事必须钉住：
/// 1. 面板真的是我们的注入面，且**进祖先共享组捕获** —— 对话框自带压暗蒙层，
///    不垫共享组捕获的话玻璃会把蒙层一起折进去；
/// 2. 遮罩之外的那层捕获点确实建在蒙层之前（`UndimmedBackdropCapture` 在场）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('对话框注入面与二级面板同口径：垫共享组捕获 + 带浮影', (tester) async {
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

    final surface =
        hyperosGlassDialogSurface(
              context,
              const MiuixGlassShape(cornerRadius: 28),
              const SizedBox.shrink(),
            )
            as HyperosSelectPopupGlass;
    expect(surface.cornerRadius, 28);
    expect(
      surface.useAncestorGroupCapture,
      isTrue,
      reason: '对话框的蒙层画在面板之前，不进共享组捕获就会把蒙层折进玻璃里',
    );
    expect(surface.surfaceShadow, isTrue, reason: '与其余 OS4 注入面同门禁');
  });

  testWidgets('真开一次：面板是注入面、蒙层之前有捕获点、外壳仍在', (tester) async {
    var afterDismissRan = false;
    late BuildContext hostContext;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return Center(
              child: TextButton(
                onPressed: () => showOs4GlassDialog<void>(
                  context: context,
                  builder: (dialogContext, close) => TextButton(
                    onPressed: () => close(
                      afterDismiss: () => afterDismissRan = true,
                    ),
                    child: const Text('关闭'),
                  ),
                ),
                child: const Text('打开'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.byType(MiuixGlassDialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(MiuixGlassDialog),
        matching: find.byType(HyperosSelectPopupGlass),
      ),
      findsOneWidget,
      reason: '面板应当是项目自己的注入面，而不是上游内置面板',
    );
    expect(
      find.byType(UndimmedBackdropCapture),
      findsOneWidget,
      reason: '捕获点要排在压暗蒙层之前，否则玻璃会采到压暗后的页面',
    );
    expect(find.text('关闭'), findsOneWidget);
    expect(afterDismissRan, isFalse, reason: '还没收起');

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    expect(find.byType(MiuixGlassDialog), findsNothing, reason: '收起后路由也要摘掉');
    expect(
      afterDismissRan,
      isTrue,
      reason: '后续动作（push 页面 / 开 sheet）必须在退场动画结束之后才跑',
    );
    expect(hostContext.mounted, isTrue, reason: '宿主页面不该被弹层带走');
  });

  testWidgets('点面板外的蒙层收起（barrierDismissible 默认开）', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showOs4GlassDialog<void>(
                context: context,
                builder: (dialogContext, close) =>
                    const SizedBox(width: 120, height: 80),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixGlassDialog), findsOneWidget);

    // 蒙层画在覆盖层最上层、且铺满整屏：点左上角必定落在面板之外。
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixGlassDialog), findsNothing);
  });

  testWidgets('barrierDismissible: false 时点蒙层不关', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showOs4GlassDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (dialogContext, close) =>
                    const SizedBox(width: 120, height: 80),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixGlassDialog), findsOneWidget);
  });
}
