// 顶部渐变带的**新契约**回归（2026-09-29 第九轮；原文件名保留，内容随契约演进）。
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
// 第六版钉的「模糊层内缩让位 + 横向渐隐」在 2026-09-29 被第九轮推翻：它防的两笔
// （`u_size` 采样退化 = fork 补丁 3、白纱越出圆弧 = 白纱自绘圆角）都已真正修掉，
// 用户口径「不是应该是上下渐变吗」—— 模糊层回到**满宽 + 纯竖直**。
//
// 现在钉的是第九轮契约：
//
// 1. **衬底竖直渐变 = 两段 [满, 透明]**（顶浓底清）—— 谁再把四段爬升接回来，立刻红；
// 2. **白纱自绘圆角的接线是活的**（`InspireHeaderBlur.cornerRampIn` = 面板圆角半径，
//    `shapeTopInset` = 带盒上移量）—— 白纱的形状不依赖引擎裁剪的 Replacement 钉；
// 3. 白纱不吃横向渐隐（带子树里不许有 `ShaderMask`）；
// 4. **模糊层满宽、分布纯竖直**（第六版的内缩 + 横向渐隐已撤）。
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

  testWidgets('衬底 = [满, 透明] 两段，与设置页顶栏同一份形状（tintBottomScale 出厂 0）', (
    tester,
  ) async {
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
    // 2026-09-29 用户口径定案（撤回 a5c437fc 的 0.4 补浓）：弹窗带的白纱浓度
    // 必须与设置页顶栏**完全一致**（tintBottomScale = 出厂 0），渐变就是
    // [满浓度, 带底透明] 两段。谁再把补浓接回来（三段/带 stops），这条立刻红。
    expect(tint.colors.length, 2);
    expect(tint.colors.first.a, 1.0, reason: '顶边必须满浓度（顶部浓）');
    expect(tint.stops, isNull, reason: '两段形没有显式 stops；有 stops 就是接回了补浓/爬升形状');
    expect(tint.colors.last.a, 0, reason: '带底恒透明，不切横向硬边');
  });

  testWidgets('白纱自绘圆角的接线是活的：cornerRampIn = 半径、shapeTopInset = 带盒上移量', (
    tester,
  ) async {
    // 治「有内容滚到带下时，面板圆角外面出现填充」的真凶（白纱普通绘制越出
    // 面板圆弧，引擎对 BackdropFilter 兄弟内容的圆弧裁剪不总可靠）的那笔修复：
    // 白纱的形状自己画。断链的历史形态是「常量在、转发断了」——所以这条要在
    // **泵出来的树**上钉（纯常量测试 corner_ramp_test 替代不了：它看不到
    // HyperosSheetBlurTop → FrostedHeaderBackground → InspireHeaderBlur 这两跳转发）。
    await tester.pumpWidget(harness());
    await tester.pump();

    final band = tester.widget<InspireHeaderBlur>(
      find.byType(InspireHeaderBlur),
    );
    expect(
      band.cornerRampIn,
      hyperosMiuixBottomSheetCornerRadius,
      reason: '白纱的圆弧半径 = 面板圆角半径',
    );
    expect(
      band.shapeTopInset,
      0,
      reason: '本宿主 bleedTop = 0（把手条悬浮后带子不再上移），'
          '若将来恢复上移，这里应跟着等于 bleedTop',
    );
  });

  testWidgets('模糊层满宽、分布纯竖直（第六版的内缩+横向渐隐已撤，第九轮口径）', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    // 模糊层的 Positioned 必须满宽（left/right 都是 0）：用户口径「不是应该是
    // 上下渐变吗」—— 左右渐隐是第六版为防圆角越界加的保护，根因修掉后已撤。
    final blurPositioned = tester
        .widgetList<Positioned>(find.byType(Positioned))
        .where((p) => p.left == 0 && p.right == 0 && p.top == 0)
        .toList();
    expect(
      blurPositioned,
      isNotEmpty,
      reason: '模糊层应该是一条满宽、从带顶铺下来的 Positioned',
    );
    expect(
      blurPositioned.any((p) => p.left != 0 || p.right != 0),
      isFalse,
      reason: '不许再出现左右内缩的模糊层（内缩 + 横向渐隐已随根因修复撤除）',
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
