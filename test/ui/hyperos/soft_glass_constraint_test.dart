import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/soft_glass/soft_glass_surface.dart';

/// 柔光玻璃容器**不得改变内容的布局约束**。
///
/// 回归背景：锚定选择弹窗（`HyperosSelectPopup`）用
/// `ConstrainedBox(minWidth: …)` + `IntrinsicWidth` + `Column(stretch)` 排版，
/// 靠 `stretch` + 行内 `Expanded` 把勾推到右边。`SoftGlassSurface` 内部的
/// `Stack` 在非紧约束下走 `StackFit.loose`，会把父约束的 `minWidth` 松成 0，
/// 于是 `IntrinsicWidth` 收缩到内容宽度、`Expanded` 无处可撑——弹窗切到
/// 「柔光玻璃」档后，勾从贴容器右边变成紧跟文字。同等约束下两种容器的
/// 内容宽度必须一致。
void main() {
  const minWidth = 200.0;
  const maxWidth = 320.0;

  Widget content() => const IntrinsicWidth(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text('柔光玻璃')),
            SizedBox(width: 6),
            Icon(Icons.check, size: 22),
          ],
        ),
      ],
    ),
  );

  Future<double> contentWidthOf(WidgetTester tester, Widget container) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: minWidth,
                maxWidth: maxWidth,
              ),
              child: container,
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(IntrinsicWidth)).width;
  }

  testWidgets('普通容器：内容被 minWidth 撑到下限', (tester) async {
    final width = await contentWidthOf(
      tester,
      ClipRRect(borderRadius: BorderRadius.circular(20), child: content()),
    );
    expect(width, minWidth);
  });

  testWidgets('SoftGlassSurface：内容宽度必须与普通容器一致', (tester) async {
    final plain = await contentWidthOf(
      tester,
      ClipRRect(borderRadius: BorderRadius.circular(20), child: content()),
    );
    final soft = await contentWidthOf(
      tester,
      SoftGlassSurface(
        borderRadius: BorderRadius.circular(20),
        blurEnabled: false,
        enableShadows: false,
        recipe: SoftGlassRecipe.dialog,
        child: content(),
      ),
    );
    expect(soft, plain);
  });
}
