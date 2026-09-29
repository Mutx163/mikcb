// 弹窗面板顶部渐变带的「让开上角」回归测试（2026-09-28，第六版定稿）。
//
// ## 第六版钉的是什么
//
// 用户 2026-09-28 复验口径（三条一起报）：
//
// 1. 「渐变模糊变成了中间浓、上面透明、下面透明……应该是顶部浓、下面透明」
//    —— 竖直爬升（`topRampIn`，上沿 0 → 满）接通生效后的**三段式**，已打回删除；
// 2. 「拉杆区域变透明了」 —— 同一笔的直接后果（爬升让带顶强度从 0 起）；
// 3. 「页面滑动到中间位置的时候，卡片（=弹窗面板）的右上角左上角还会在圆角外面
//    出现模糊效果」 —— 圆角账，跨了五个版本，本版收口。
//
// 第六版的四件套（缺一件都会复现前面某一次的返工，版本表见
// `.agents/notes/implemented/bug-fix/2026-09-28-sheet-top-band-corner-ramp.md`）：
//
// * `cornerRampIn` = 面板圆角半径：**模糊层**矩形左右各内缩（与圆弧相切），
//   圆角区域没有模糊材料 —— 本文件第 1 条钉；
// * 横向渐隐的爬升宽度 = **同一个** `cornerRampIn`（内缩边从 0 爬进场，不切竖直
//   硬缝；第三版内缩开着但渐隐是死代码，真机失败就是那笔）—— 第 2、3 条钉；
// * **白纱满宽不缩**（带子树里不许有 ShaderMask —— 那是白纱被横向渐隐的标记，
//   另见 `sheet_top_band_ramp_engages_test.dart`）；
// * **竖直曲线 = 顶浓底清**（渐进档原样，不许再有上沿爬升）—— 分布与衬底两处的
//   形状钉在下面。
//
// ## 范围（用户 2026-09-28 拍板）
//
// 「设置页面顶部的渐变模糊视觉效果是非常好的，不要去改动导致他坏掉」—— 共享材料的
// 材料旋钮一个没动：sigma 22、衬底 70%、竖直渐变与带底归零的约定全在原值。另有一条
// 守卫在 `header_blur_style_wiring_test.dart`：子页顶栏那条不许被开。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inspire_blur/inspire_blur.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet_blur_top.dart';
import 'package:university_timetable/ui/hyperos/inspire/inspire_header_blur.dart';
import 'package:university_timetable/ui/hyperos/miuix_bottom_sheet.dart';

void main() {
  group('弹窗顶部渐变带：模糊让开圆角、白纱满宽、竖直顶浓底清（第六版）', () {
    const taper = 0.2;

    test('让位区 = 面板圆角半径：模糊层矩形与圆弧相切', () {
      // 第六版把钉从 0 翻回半径 —— 但语义与第三版不同：这次**只缩模糊**，
      // 白纱满宽（见文件头第四条）。「每端 56px 无料」的反对理由缩的是白纱，
      // 白纱不缩之后不再成立。
      expect(
        HyperosSheetBlurTop.cornerRampIn,
        hyperosMiuixBottomSheetCornerRadius,
        reason: '模糊层必须让开圆角半径，与上沿圆弧相切',
      );
    });

    test('模糊的横向渐隐是活的：爬升宽度取 cornerRampIn（= 半径），内缩边不断料', () {
      // 第三版的死账：内缩开着、渐隐却没接进 `distribution`，内缩边齐刷刷断掉。
      // 本条钉「渐隐宽度 = 内缩宽度」这个同源关系（一个旋钮，见 cornerRampIn 文档）。
      const taperIn = HyperosSheetBlurTop.cornerRampIn;
      expect(taperIn, greaterThan(0));
      final fraction = InspireHeaderBlur.sideTaperFractionFor(
        materialWidth: 393,
        taperIn: taperIn,
      );
      expect(
        fraction,
        greaterThan(0),
        reason: '内缩边要有横向渐隐，否则材料在离边处切出竖直接缝',
      );
      // 爬升段要**盖满**让位那一截宽度，才不会在弧内侧留一条满强度窄边。
      expect(
        fraction * 393,
        closeTo(taperIn, 1e-9),
        reason: '爬升段物理宽度必须等于传进去的那个宽度',
      );
    });

    test('横向爬升段的物理宽度 = 渐隐宽度（分母是材料盒宽，不是整条带宽）', () {
      // 「渐隐要吃掉的宽度」与分母必须同源 ⇒ 爬升段的物理宽度必须等于 taperIn。
      //
      // ⚠️ 这条钉的是一处真 bug：分母曾写成 `width + cornerRampIn * 2`（整条带宽
      // **加**两个让位区），与「占材料盒宽度的比例」这份契约正好相反，算出来的爬升段
      // 只有 21px 而不是 28px（393 宽的屏）。观感只差一点点所以真机看不出来，但代码
      // 与注释对不上，而且推导埋在 `build` 的 `LayoutBuilder` 里、没有任何用例覆盖得到。
      const taperIn = 28.0;
      for (final width in <double>[320, 393, 412, 600]) {
        for (final inset in const <double>[0, 28]) {
          final materialWidth = width - inset * 2;
          final fraction = InspireHeaderBlur.sideTaperFractionFor(
            materialWidth: materialWidth,
            taperIn: taperIn,
          );
          expect(
            fraction * materialWidth,
            closeTo(taperIn, 1e-9),
            reason: '带宽 $width、内缩 $inset：爬升段应正好等于 $taperIn',
          );
        }
      }
    });

    test('不给爬升宽度 / 材料盒不剩正宽：退回「只有竖直那一份」', () {
      // 没开爬升 ⇒ 横向渐变无处可爬。
      expect(
        InspireHeaderBlur.sideTaperFractionFor(
          materialWidth: 393,
          taperIn: 0,
        ),
        0,
      );
      // 负数同样退回（不该发生，但别给出负比例）。
      expect(
        InspireHeaderBlur.sideTaperFractionFor(
          materialWidth: 393,
          taperIn: -5,
        ),
        0,
      );
      // 材料盒不剩正宽度 ⇒ 无处可爬，退回竖直那一份，而不是给出 >1 或负数的比例。
      expect(
        InspireHeaderBlur.sideTaperFractionFor(
          materialWidth: 0,
          taperIn: 28,
        ),
        0,
        reason: '材料盒正好 0 宽',
      );
      expect(
        InspireHeaderBlur.sideTaperFractionFor(
          materialWidth: -16,
          taperIn: 28,
        ),
        0,
        reason: '材料盒为负宽',
      );
      // 还剩一点正宽度 ⇒ 夹到 1（爬升段吃掉整个材料盒），不许越界。
      expect(
        InspireHeaderBlur.sideTaperFractionFor(
          materialWidth: 4,
          taperIn: 28,
        ),
        1,
        reason: '材料盒只剩 4px，比例夹到 1',
      );
    });

    test('分布 = 竖直渐变 × 横向渐变：竖直顶浓底清，横向两端渐隐', () {
      final config = InspireHeaderBlur.configFor(
        HeaderBlurStyle.inspire,
        gaussianSigma: 15,
        sideTaperFraction: taper,
      );
      final product = config.distribution as ProductDistribution;

      // 竖直那份**逐字复用**渐进档那条（`progressiveExtent` = 带底恒 0 是这块带子
      // 的地基，不能另写一套值）。上沿满强度 = 用户口径「顶部浓」+ 滚上去的行在
      // 那儿化开。**不许**再出现 [0, 1, 0] 那种上沿爬升形状（三段式的成因）。
      expect(product.first, InspireHeaderBlur.verticalProgressiveProfile);
      final vertical = product.first;
      expect(vertical.values.first, 1, reason: '上沿必须是满强度（顶部浓）');
      expect(vertical.stops.first, 0);
      expect(
        vertical.values.last,
        0,
        reason: '带底必须归 0（底部透明），与下方清晰内容无残留切边',
      );

      // 横向那份：两端 0、爬升段占 [taper]、中间满。
      final horizontal = product.second;
      expect(horizontal.values, <double>[0, 1, 1, 0]);
      expect(horizontal.stops, <double>[0, taper, 1 - taper, 1]);
    });

    test('不设让位区 = 旧行为逐字不变（首页玻璃带 / 子页顶栏走这一支）', () {
      final legacy = InspireHeaderBlur.configFor(
        HeaderBlurStyle.inspire,
        gaussianSigma: 15,
      );
      expect(legacy.distribution, isA<DirectionalDistribution>());
      expect(legacy.distribution, isNot(isA<ProductDistribution>()));
      expect(
        (legacy.distribution as DirectionalDistribution).values.first,
        1,
        reason: '旧行为：上沿即满强度',
      );
      // 高斯档是均匀分布，方向乘积对它没有意义 —— 不该被改。
      final gaussian = InspireHeaderBlur.configFor(
        HeaderBlurStyle.gaussian,
        gaussianSigma: 15,
        sideTaperFraction: taper,
      );
      expect(gaussian.distribution, isA<UniformDistribution>());
      expect(gaussian.effectiveSigmaX, 15);
    });

    test('衬底的横向渐变与模糊那份 stops 逐字同源（将来重开时必须同源）', () {
      // ⚠️ 现网**衬底不开**横向渐隐（2026-09-28 分家，见 [sideTaperFractionFor]），
      // 这条钉的是「万一将来重开」：模糊那份写在分布里、衬底那份写在 ShaderMask 里，
      // 两处各写一遍必然漂 —— stops 必须是同一组数。
      final mask = InspireHeaderBlur.tintSideTaper(taper);
      final profile = InspireHeaderBlur.sideTaperProfile(taper);
      // 同一组 stop：模糊在分布里，衬底在 ShaderMask 里，两处各写一遍必然漂。
      expect(mask.stops, profile.stops);
      expect(mask.colors.length, profile.values.length);
      // 两端透明、中段不透明 = dstIn 之后正好是「横向渐隐」。
      expect(mask.colors.first.a, 0);
      expect(mask.colors[1].a, 1);
      expect(mask.colors.last.a, 0);
    });

    test('衬底的竖直渐变 = 顶浓底清（两段，上沿满浓度、带底恒透明）', () {
      // 三段式回归钉（用户口径「渐变模糊应该是顶部浓，下面透明」）：衬底只许是
      // [满, 透明] 两段 —— 曾经的四段 [透明, 满, 收, 透明] 就是「上面透明、
      // 中间浓、下面透明」的成因，`topRampFraction` 参数已删。
      const top = Color(0xB3FFFFFF);
      final gradient = InspireHeaderBlur.tintGradient(
        top,
        InspireHeaderBlur.progressiveTintBottomScale,
      );
      expect(gradient.colors.length, 2);
      // 「顶浓」= 顶边就是衬底色原浓度（0xB3 ≈ 70% 白），一点不衰减。
      expect(gradient.colors.first, top, reason: '顶边必须满浓度（顶部浓）');
      expect(gradient.colors.last.a, 0, reason: '带底恒透明，不切横向硬边');
      expect(gradient.stops, isNull);
    });
  });
}
