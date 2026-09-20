import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/liquid_glass_tuning.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

import '../helpers_test_app.dart';

/// 在指定材质 / 调参下挂出这条带，返回玻璃那一层的 `Positioned`。
///
/// 顶层函数（不是 group 内的局部函数）：几何、外溢、折射位移三组用例都要用它挂同一个
/// 场景，各自复制一份会漂。
Future<Positioned> bandGlassPositioned(
  WidgetTester tester, {
  String material = 'liquid',
  LiquidGlassTuning? tuning,
}) async {
  const base = FrostedAppearance.defaults;
  await tester.pumpWidget(
    FrostedAppearanceScope(
      appearance: FrostedAppearance(
        sheetBlurSigma: base.sheetBlurSigma,
        sheetTintAlpha: base.sheetTintAlpha,
        sheetBarrierAlpha: base.sheetBarrierAlpha,
        homeBandGlassMaterial: material,
        liquidGlassTuning: tuning,
      ),
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: Stack(
              children: [
                HomePageContinuousChromeFrostedOverlay(
                  headerBlurEnabled: true,
                  weekdayBarBlurEnabled: true,
                  includeStatusBar: false,
                  weekdayBarHeight: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return tester.widget<Positioned>(
    find
        .ancestor(
          of: find.byType(HomePageChromeGlassFill),
          matching: find.byType(Positioned),
        )
        .first,
  );
}

/// 「顶栏/信息栏到底还算不算在走玻璃」的判定。
///
/// 它决定**下游**要不要跟着做玻璃：日课表顶上的摘要卡（日期 + 关闭叉）会据此
/// 决定自己与顶栏同款，还是跟课程卡一样走实底。判错的表现是真机上「课程卡
/// 是实心、上面那张日期卡还是透的」。
void main() {
  TimetableSettings settingsWith({
    required String bandMaterial,
    bool headerBlur = true,
    bool weekdayBarBlur = true,
  }) => TimetableSettings.defaults().copyWith(
    homeBandGlassMaterial: bandMaterial,
    homePageHeaderBlurEnabled: headerBlur,
    homePageWeekdayBarBlurEnabled: weekdayBarBlur,
  );

  test('顶栏材质选「实体」时不算铬玻璃在跑（带是不透明实心条）', () {
    final solid = settingsWith(bandMaterial: 'solid');
    // 两个旧开关仍开着 —— 它们只表达"要不要磨砂"，与材质档可以不一致，
    // 实体档必须压过它们，否则摘要卡会继续跟一条实心带"同款"。
    expect(solid.homePageHeaderBlurEnabled, isTrue);
    expect(solid.homePageWeekdayBarBlurEnabled, isTrue);
    expect(homePageHasAnyChromeBlur(solid, hasBackdrop: true), isFalse);
  });

  test('顶栏材质还是玻璃档时口径不变', () {
    for (final material in ['progressive', 'gaussian', 'soft', 'liquid']) {
      expect(
        homePageHasAnyChromeBlur(
          settingsWith(bandMaterial: material),
          hasBackdrop: true,
        ),
        isTrue,
        reason: '$material 档仍是玻璃，下游应继续跟顶栏同款',
      );
    }
  });

  test('没有壁纸 / 两个开关都关时不算玻璃', () {
    expect(
      homePageHasAnyChromeBlur(
        settingsWith(bandMaterial: 'gaussian'),
        hasBackdrop: false,
      ),
      isFalse,
    );
    expect(
      homePageHasAnyChromeBlur(
        settingsWith(
          bandMaterial: 'gaussian',
          headerBlur: false,
          weekdayBarBlur: false,
        ),
        hasBackdrop: true,
      ),
      isFalse,
    );
  });

  group('玻璃带的上下两条直边按材质决定外溢多少', () {
    testWidgets('实体档不往外画：实心条就是可见带本身', (tester) async {
      // 实体档没有形状边界那套折射，撑大盒子只是把实心条推出可见区。
      // （存量 progressive / gaussian / soft 也渲染液态玻璃，所以它们**不在这里** ——
      // 见下一条与 `homePageChromeGlassVerticalOverhang` 的说明。）
      final positioned = await bandGlassPositioned(tester, material: 'solid');
      expect(positioned.top, 0.0);
      expect(positioned.bottom, 0.0);
    });

    testWidgets('液态玻璃：上边盖过作用带宽度，下边与底栏药丸同为 0', (tester) async {
      // 两条边口径不同，理由不同：
      // * 上边压在屏幕顶边上，而着色器在作用带内是**朝形状外**采样的 —— 朝上就落到
      //   屏幕外，那圈空样本经 `mix(base, tint, α)` 读成近黑。⇒ 上边必须 ≥ 作用带宽度。
      // * 下边是这条带**唯一可见的形状边界**（左右被 48px 推出屏幕、上边被推开），
      //   所以它必须留在可见区边界上、**外溢为 0**：外溢 > 0 时可见区里只剩被截断的
      //   后半截位移曲线（边界上从 `profile(外溢)` 掉到 0 ⇒ 读成一条线），而且边光带宽
      //   2.1 < 外溢时那一圈也整条被推出去 —— 用户 2026-09-20 在「下边 4」那版上的
      //   原话就是「没有黑线，但也没有任何玻璃效果」。底栏药丸是同一份材质的活证据：
      //   它零外溢，整圈折射与边光都在可见区里，用户口径「折射效果特别好看」。
      final dflt = await bandGlassPositioned(tester);
      expect(dflt.top, -8.0);
      expect(dflt.bottom, 0.0);

      final wide = await bandGlassPositioned(
        tester,
        tuning: const LiquidGlassTuning(refractionBand: 20),
      );
      expect(wide.top, -21.0);
      expect(
        wide.bottom,
        0.0,
        reason: '下边不许跟着作用带宽度长大 —— 那正是把折射整圈推出可见区的做法',
      );
    });

    test('液态上边：任何滑杆取值下，可见区第一行都不该还在作用带里', () {
      for (
        var band = LiquidGlassTuning.minRefractionBand;
        band <= LiquidGlassTuning.maxRefractionBand;
        band += 1
      ) {
        final overhang = homePageChromeGlassVerticalOverhang(
          material: 'liquid',
          refractionBand: band,
          rimWidth: LiquidGlassTuning.defaultRimWidth,
        );
        expect(
          overhang.top,
          greaterThanOrEqualTo(band + 1),
          reason: '作用带 $band：上边外溢不够时可见区最上一行仍朝外采样，读成一条发丝线',
        );
      }
      // 边缘高光带也算在内（滑杆上限 12）。
      expect(
        homePageChromeGlassVerticalOverhang(
          material: 'liquid',
          refractionBand: LiquidGlassTuning.defaultRefractionBand,
          rimWidth: LiquidGlassTuning.maxRimWidth,
        ).top,
        greaterThanOrEqualTo(LiquidGlassTuning.maxRimWidth + 1),
      );
    });

    test('液态下边：固定 0（与底栏药丸同口径），绝不跟着作用带长', () {
      // 两个方向都要钉住：
      //  * **上界**：外溢一旦 ≥ 作用带，可见区里 `push ≡ 0`，整条带只剩玻璃本体；
      //    模糊 0 / 染色 0 时玻璃本体就是背景的 1:1 拷贝 ⇒ 用户读成「完全透明、没有
      //    折射功能」。所以它**绝不跟着作用带 / 高光带宽长大**（2026-09-20 第四轮那个
      //    `max(8, max(作用带, 高光带宽) + 1)` 就是这么撞上去的）。
      //  * **下界**：就是 0 —— 只要 > 0，可见区里剩下的就只有被截断的后半截位移曲线，
      //    边界上从 `profile(外溢)` 掉到 0，读成一条线；而且边光带宽 2.1 < 外溢时那一圈
      //    也整条被推出可见区。旧版注释里"外溢必须 ≥ 边光带宽，否则读成发丝线"那条
      //    依据是给**旧版边光**写的（贴边最亮、峰值压在边界上）；09-20 边光截面已改成
      //    「峰在带内」（峰值在离边 0.35 × 带宽处，边界上亮度本来就是 0），底栏药丸零
      //    外溢也不见硬线 ⇒ 那条依据已经过期，别再照着它把外溢抬上去。
      for (
        var band = LiquidGlassTuning.minRefractionBand;
        band <= LiquidGlassTuning.maxRefractionBand;
        band += 1
      ) {
        expect(
          homePageChromeGlassVerticalOverhang(
            material: 'liquid',
            refractionBand: band,
            rimWidth: LiquidGlassTuning.maxRimWidth,
          ).bottom,
          homePageChromeGlassBottomEdgeOverdraw,
          reason: '作用带 $band：下边外溢是个定值，不许跟着滑杆走',
        );
      }
      expect(
        homePageChromeGlassBottomEdgeOverdraw,
        0.0,
        reason: '外溢 > 0 = 把可见区里的位移曲线截断成一条线，且把边光那一圈推出可见区',
      );
      // 默认档（作用带 7）下可见区里留得下整条折射曲线。
      expect(
        homePageChromeGlassBottomEdgeOverdraw,
        lessThan(LiquidGlassTuning.defaultRefractionBand),
        reason: '外溢 ≥ 作用带 = 把边缘那一圈（折射 + 边光 + 色散）整圈删掉',
      );
    });

    test('只有实体档上下外溢恒为 0；存量档与液态同口径', () {
      // 判据是「非实体」（`homeBandUsesAdvancedGlass`），不是字面 `'liquid'`：
      // 2026-09-20 口径收成「液态 / 实体」两档后，存量 progressive / gaussian /
      // soft 也渲染液态玻璃。若这里漏掉它们，那些档会拿到 (0, 0) —— 上边不再推出
      // 可见区，真机那条发丝线立刻回来。
      for (final material in ['liquid', 'progressive', 'gaussian', 'soft']) {
        final overhang = homePageChromeGlassVerticalOverhang(
          material: material,
          refractionBand: LiquidGlassTuning.maxRefractionBand,
          rimWidth: LiquidGlassTuning.maxRimWidth,
        );
        expect(
          overhang.top,
          greaterThanOrEqualTo(LiquidGlassTuning.maxRefractionBand + 1),
          reason: '$material 渲染的是液态玻璃，上边必须推出可见区',
        );
        expect(overhang.bottom, 0.0, reason: material);
      }
      final solid = homePageChromeGlassVerticalOverhang(
        material: 'solid',
        refractionBand: LiquidGlassTuning.maxRefractionBand,
        rimWidth: LiquidGlassTuning.maxRimWidth,
      );
      expect(
        solid.top,
        0,
        reason: '实体档没有形状边界那套折射，撑大盒子只会把实心条推出可见区',
      );
      expect(solid.bottom, 0, reason: '实体档没有形状边界那套折射');
    });

    testWidgets('这条带必须采祖先组的整屏背景（否则只会在下边钳出一条黑线）', (tester) async {
      // 这条是 2026-09-20 用户实测「打开磨砂强度后星期栏底边一条黑线」的对策。
      // 推理链（三段都要成立才需要组采样）：
      //  ① 带级采样下，折射位移越过带自己的边界就会"钳在带自己的边上"；
      //  ② 这条带的左右被 48px 推到可见区之外，**只有下边留在可见区**（上边贴着屏幕顶）；
      //  ③ 下边的可见边界不能靠"再推远点"绕开 —— 外溢只有 0 这一个取值（> 0 就把位移曲线
      //     截断成一条线、并把边光那一圈推出可见区，见上一条测试）。所以位移一定会朝外
      //     越过下边，一定需要一份带外的真实背景可采。
      // ⇒ 换采样源：采祖先 BackdropGroup 那份整屏背景，位移取到的是真实背景而不是钳出来的边。
      // 首页为此早就搭好了 BackdropGroup + 全尺寸 UndimmedBackdropCapture，只是这个
      // 开关一直没接上。
      //
      // 底栏药丸（同样零外溢、同样 `grouped: true`）是这条推理的活证据：它折射效果正常
      // ⇒ 组采样这条路本身是通的。
      //
      // 首页与设置页预览**两处都开着**它（2026-09-20 第五轮起预览也接了）：两处的
      // 差别不在采样源，而在几何适配（预览带按带高压折射位移）。
      await bandGlassPositioned(tester);
      final fill = tester.widget<HomePageChromeGlassFill>(
        find.byType(HomePageChromeGlassFill),
      );
      expect(
        fill.useAncestorBackdropGroup,
        isTrue,
        reason: '带级采样会把折射位移钳在下边、读出一条黑线；这条带必须采祖先组的整屏背景',
      );
    });
  });

  group('转场期间这条带必须逐帧重画（否则形状跟着页面走偏，扫出一根细线）', () {
    testWidgets('宿主路由滑动期间每帧重画一次，落定后停手', (tester) async {
      // 真机现象（用户 2026-09-20）：「课表页面」设置页进场时，预览的顶栏 / 星期栏里
      // 扫出一根细竖线，位置每次还不太一样。
      //
      // 机制（两侧都要成立）：
      //  ① 转场外壳把整页包进重绘边界（`_HyperosTransitionPageShell`），滑动期间页面
      //     **只换图层偏移、不重画**（框架 `PaintingContext._compositeChild`）；
      //  ② 玻璃形状按 paint 期的屏幕坐标算（着色器契约），不重画就停在旧位置 ⇒ 形状
      //     偏移量 = 这段时间页面滑过的距离。左右各 48px 的外溢被扫进可见区时，那条
      //     直边就露出来 = 一根细线。
      // ⇒ 对策：转场期间每 tick 把这条带标脏一次（本组件的驱动），形状重新钉在带上。
      var wrappedPaints = 0;
      var plainPaints = 0;
      // 驱动只对非实体档生效（实体档不按屏幕坐标算形状），所以这里必须是非实体档
      // —— 用默认材质（2026-09-20 起默认就是液态玻璃）。
      const base = FrostedAppearance.defaults;
      await tester.pumpWidget(
        FrostedAppearanceScope(
          appearance: FrostedAppearance(
            sheetBlurSigma: base.sheetBlurSigma,
            sheetTintAlpha: base.sheetTintAlpha,
            sheetBarrierAlpha: base.sheetBarrierAlpha,
          ),
          child: TestApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      HyperosPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: Center(
                            child: SizedBox(
                              width: 200,
                              height: 120,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: HomePageChromeGlassTransitionRepaint(
                                      child: CustomPaint(
                                        painter: _CountingPainter(
                                          () => wrappedPaints++,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // 对照组：同一页里不包驱动的兄弟节点。
                                  Expanded(
                                    child: CustomPaint(
                                      painter: _CountingPainter(
                                        () => plainPaints++,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('进页'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('进页'));
      await tester.pump(); // 转场首帧
      // 首帧新页多半整页还在屏幕外（起点 offset = 1），引擎会把它的图层整个剔掉，
      // 计数可能还是 0 —— 所以基线取"页面已经滑进可见区之后"，不断言首帧一定画过。
      await tester.pump(const Duration(milliseconds: 120));
      final wrappedAtStart = wrappedPaints;
      final plainAtStart = plainPaints;
      expect(wrappedAtStart, greaterThan(0), reason: '页面滑进可见区后就应该画过');

      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }

      expect(
        wrappedPaints - wrappedAtStart,
        greaterThanOrEqualTo(3),
        reason: '转场每推进一帧，这条带就要按新的屏幕位置重画一次，否则形状会偏',
      );
      expect(
        plainPaints - plainAtStart,
        0,
        reason:
            '对照：转场外壳把整页包在重绘边界里，滑动期间页面本身不重画 —— '
            '这正是玻璃带会偏的原因',
      );

      await tester.pumpAndSettle();
      final settled = wrappedPaints;
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        wrappedPaints,
        settled,
        reason: '动画停住后不该再有额外重画（静止时零开销）',
      );
    });
  });
}

/// 数重画次数的探针：`shouldRepaint` 恒假 ⇒ 它自己不会引起重画，记到的次数只来自
/// 外面（转场驱动或页面重绘）。
class _CountingPainter extends CustomPainter {
  _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
