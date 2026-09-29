// 顶部渐变带的**新契约**回归（2026-09-28 第六版；原文件名保留，内容已换）。
//
// ## 这个文件历史上钉过什么、为什么换
//
// 原来钉的是「竖直上沿爬升（`topRampIn`）真的生效」——当时带子在
// `HyperosSheetBlurTop._stackChildren` 里挂的是
// `Positioned(top: -bleedTop, left: -bleed, right: -bleed)`（没有 `bottom` 也没有
// `height`），`RenderStack.positionedChildConstraints` 把高度算成 `null` ⇒ 高度方向
// 无界 ⇒ `topRampFractionFor` 恒 0 ⇒ 爬升是死代码。给 `Positioned` 显式 `height`
// 之后爬升接通了，真机复验却是**三段式**（上面透明、中间浓、下面透明）+ 拉杆区
// 透明 —— 用户打回，`topRampIn` 参数整个删除。
//
// 现在钉的是删除之后的契约：
//
// 1. **衬底竖直渐变 = 两段 [满, 透明]**（顶浓底清，用户口径「渐变模糊应该是顶部浓，
//    下面透明」）—— 谁再把四段爬升接回来，这条立刻红；
// 2. **带子的让位接线是活的**（`InspireHeaderBlur.cornerRampIn` = 面板圆角半径，
//    模糊层矩形与圆弧相切）—— 治「滑到中间时面板圆角外面出现模糊」的那条几何；
// 3. 白纱不吃横向渐隐（带子树里不许有 `ShaderMask`，第二版保留）。
//
// 「约束必须有界」这条教训仍然有效：带子的 `Positioned` 继续显式给 `height`
// （`hyperos_sheet_blur_top.dart` 里那条注释），只是它现在服务的是几何稳定性。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet_blur_top.dart';
import 'package:university_timetable/ui/hyperos/inspire/inspire_header_blur.dart';
import 'package:university_timetable/ui/hyperos/miuix_bottom_sheet.dart';

void main() {
  Widget harness() => const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            // HyperosSheetBlurTop 自己 assert「要有确定高度」，给它一个有界的壳。
            height: 420,
            child: HyperosSheetBlurTop(
              headerHeight: 64,
              header: SizedBox.shrink(),
              body: SingleChildScrollView(child: SizedBox(height: 900)),
            ),
          ),
        ),
      );

  testWidgets('衬底是顶浓底清两段形，不许再出现四段爬升（三段式回归钉）', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    final tintGradients = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.gradient)
        .whereType<LinearGradient>()
        // 只看「带底恒为透明」的竖直渐变（`InspireHeaderBlur.tintGradient` 的契约）。
        .where((g) => g.colors.last.a == 0)
        .toList();

    expect(
      tintGradients,
      isNotEmpty,
      reason: '带子的衬底应该是一条「带底恒透明」的竖直线性渐变',
    );

    final tint = tintGradients.single;
    expect(
      tint.colors.length,
      2,
      reason: '三段式回归：衬底只许 [满浓度, 透明] 两段 —— 四段 [透明, 满, 收, 透明] '
          '就是「上面透明、中间浓、下面透明 + 拉杆区透明」的成因（topRampIn 已删）',
    );
    expect(
      tint.colors.first.a,
      1.0,
      reason: '顶边必须满浓度（用户口径：渐变模糊应该是顶部浓）',
    );
    expect(
      tint.stops,
      isNull,
      reason: '两段渐变没有显式 stops；有 stops 就是接回了爬升形状',
    );
  });

  testWidgets('带子的让位接线是活的：InspireHeaderBlur.cornerRampIn = 面板圆角半径', (
    tester,
  ) async {
    // 治「页面滑动到中间位置时，面板右上角左上角在圆角外面出现模糊」的那条几何：
    // 模糊层矩形左右各内缩一个半径、与上沿圆弧相切，圆角区域里没有模糊材料。
    // 断链的历史形态是「常量在、转发断了」——所以这条要在**泵出来的树**上钉
    // （纯常量测试 corner_ramp_test 替代不了：它看不到 HyperosSheetBlurTop →
    // FrostedHeaderBackground → InspireHeaderBlur 这两跳转发）。
    await tester.pumpWidget(harness());
    await tester.pump();

    final band = tester.widget<InspireHeaderBlur>(
      find.byType(InspireHeaderBlur),
    );
    expect(
      band.cornerRampIn,
      hyperosMiuixBottomSheetCornerRadius,
      reason: '带子的模糊层要与圆弧相切，否则圆角区域还有模糊材料',
    );
  });

  testWidgets('白纱不吃横向渐隐（带子树里不许出现 ShaderMask）', (tester) async {
    // 2026-09-28 分家：模糊收横向（内缩 + 渐隐），白纱不收不缩、满宽铺。白纱一旦
    // 跟着收，矩形 + 渐隐叠起来让两端只剩玻璃，深色壁纸上直接读成「透明」——
    // 第三版就是这么被打回的。
    //
    // 模糊那份是写进 `InspireBlurConfig.distribution` 的（`ProductDistribution`），
    // 树里没有对应控件；**衬底**那份才走 `ShaderMask`，所以这条钉树里没有它。
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(
      find.byType(ShaderMask),
      findsNothing,
      reason: '衬底不许被横向渐隐 —— 两端一分料都不能少',
    );
  });
}
