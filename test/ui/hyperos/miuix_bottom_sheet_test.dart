import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
// 捕获点（`UndimmedBackdropCapture`）住在液态玻璃那一层，桶文件没导出它 ——
// 这里按文件直取，与 `hyperos_sheet.dart` 用法一致。
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';

import '../../helpers_test_app.dart';

/// 上游通栏底部弹窗的承载壳（`miuix_bottom_sheet.dart`）与它的材质注入面。
///
/// 壳负责把上游**声明式**的 `MiuixWindowBottomSheet`（常驻 + `show` 切换、自己往根
/// 覆盖层插 entry）接到本仓**祈使式**的 `await showXxx(...)` 上，所以有几件事必须钉住：
/// 1. 面板真的是我们的注入面，且**进祖先共享组捕获** —— 弹窗自带压暗蒙层，不垫共享组
///    捕获的话玻璃会把蒙层一起折进去；
/// 2. 蒙层之前确实有捕获点（`UndimmedBackdropCapture` 在场）；
/// 3. 收起后路由被摘掉，且「退场动画结束才跑」的后续动作确实跑了。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('注入面：贴底玻璃 + 垫共享组捕获、不加浮影', (tester) async {
    late BuildContext hostContext;
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await tester.pumpWidget(
      TestApp(
        home: hyperosMiuixBottomSheetSurface(
          hostContext,
          const MiuixGlassShape(cornerRadius: hyperosMiuixBottomSheetCornerRadius),
          const SizedBox(width: 100, height: 100),
        ),
      ),
    );

    final glass = tester.widget<HyperosSelectPopupGlass>(
      find.byType(HyperosSelectPopupGlass),
    );
    expect(glass.cornerRadius, hyperosMiuixBottomSheetCornerRadius);
    expect(
      glass.useAncestorGroupCapture,
      isTrue,
      reason: '弹窗的蒙层画在面板之前，不进共享组捕获就会把蒙层折进玻璃里',
    );
    expect(glass.surfaceShadow, isFalse, reason: '贴底弹窗没有浮影（与 edge sheet 同口径）');
  });

  testWidgets('真开一次：面板是注入面、蒙层之前有捕获点、收起后跑后续动作', (tester) async {
    var afterDismissRan = false;
    late BuildContext hostContext;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return Center(
              child: TextButton(
                onPressed: () => showMiuixBottomSheet<void>(
                  context: context,
                  builder: (sheetContext, close) => TextButton(
                    onPressed: () =>
                        close(afterDismiss: () => afterDismissRan = true),
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

    expect(find.byType(MiuixWindowBottomSheet), findsOneWidget);
    expect(
      find.byType(HyperosSelectPopupGlass),
      findsOneWidget,
      reason: '面板应当是项目自己的注入面，而不是上游内置的实底面',
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

    expect(find.byType(MiuixWindowBottomSheet), findsNothing, reason: '收起后路由也要摘掉');
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
              onPressed: () => showMiuixBottomSheet<void>(
                context: context,
                builder: (sheetContext, close) =>
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
    expect(find.byType(MiuixWindowBottomSheet), findsOneWidget);

    // 蒙层铺满整屏、排在面板之下：点最上面必定落在面板之外。
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(MiuixWindowBottomSheet), findsNothing);
  });

  testWidgets('barrierDismissible: false 时点蒙层不关', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showMiuixBottomSheet<void>(
                context: context,
                barrierDismissible: false,
                builder: (sheetContext, close) =>
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
    expect(find.byType(MiuixWindowBottomSheet), findsOneWidget);
  });
}
