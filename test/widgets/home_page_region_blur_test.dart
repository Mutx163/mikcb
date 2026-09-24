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
/// 它决定首页那条连续的顶栏玻璃带要不要自绘磨砂。判错的表现是真机上「顶栏是
/// 实心条、下面那层还透明」的分裂。
///
/// ⚠️ 2026-09-22 起**日课表顶上的摘要卡不再跟这条判据**：它整张改跟课程卡同材质
/// （`dayViewContentCardSurfaceStyle`），与本函数无关。
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

    testWidgets('液态玻璃：上边盖过作用带宽度，形状底边仍在可见带底', (tester) async {
      // 两条边口径不同，理由不同：
      // * 上边压在屏幕顶边上，而着色器在作用带内是**朝形状外**采样的 —— 朝上就落到
      //   屏幕外，那圈空样本经 `mix(base, tint, α)` 读成近黑。⇒ 上边必须 ≥ 作用带宽度。
      // * 下边是这条带**唯一可见的形状边界**（左右被 48px 推出屏幕、上边被推开），
      //   所以它必须留在可见区边界上、**外溢为 0**：外溢 > 0 时可见区里只剩被截断的
      //   后半截位移曲线（边界上从 `profile(外溢)` 掉到 0 ⇒ 读成一条线），而且边光带宽
      //   2.1 < 外溢时那一圈也整条被推出去 —— 用户 2026-09-20 在「下边 4」那版上的
      //   原话就是「没有黑线，但也没有任何玻璃效果」。底栏药丸是同一份材质的活证据：
      //   它零外溢，整圈折射与边光都在可见区里，用户口径「折射效果特别好看」。
      //   ⚠️ 2026-09-21 之后，这条"下边偏移 = 0"要读成"**形状底边落在可见带底**"：
      //   盒子被撑高了采样余量，偏移里就带着那一截（见下面那条断言）。
      final dflt = await bandGlassPositioned(tester);
      expect(dflt.top, -8.0);
      // 盒子被撑高了采样余量（[homePageChromeGlassCaptureMargin]），填充层要把那一截
      // 补回来 ⇒ 下边偏移**等于余量**（形状底边因此仍落在可见带底，不往外画）。
      expect(
        dflt.bottom,
        homePageChromeGlassCaptureMargin(
          material: 'liquid',
          refraction: LiquidGlassTuning.defaultRefraction,
        ),
      );

      final wide = await bandGlassPositioned(
        tester,
        tuning: const LiquidGlassTuning(refractionBand: 20),
      );
      expect(wide.top, -21.0);
      expect(
        wide.bottom,
        homePageChromeGlassCaptureMargin(
          material: 'liquid',
          refraction: LiquidGlassTuning.defaultRefraction,
        ),
        reason: '采样余量只跟**折射位移**走，不跟作用带宽度走（余量函数根本不收这个参数）',
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

    test('液态档上下外溢；frost 与实体档恒为 0', () {
      // 判据是 [homeBandUsesAdvancedGlass]（= 生效值为液态）：只有液态玻璃有
      // 折射位移，上边必须推出可见区。磨砂带（'frost'，跟随默认 + 默认档高斯）
      // 走渐进模糊链路，没有折射 —— 漏掉会拿到 (0,0) 外溢吗？不会，反过来：
      // 若误判成液态，实心/磨砂带会被白白撑出可见区。
      for (final material in ['liquid']) {
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
      final frost = homePageChromeGlassVerticalOverhang(
        material: 'frost',
        refractionBand: LiquidGlassTuning.maxRefractionBand,
        rimWidth: LiquidGlassTuning.maxRimWidth,
      );
      expect(
        frost.top,
        0,
        reason: '磨砂带同样没有折射位移，不该被撑出可见区',
      );
      expect(frost.bottom, 0);
    });

    testWidgets('这条带采祖先组捕获（管的是"采到哪一份"背景，不管范围）', (tester) async {
      // 2026-09-20 两处都接上 `useAncestorBackdropGroup: true`：采到的是组内
      // `UndimmedBackdropCapture` 缓存下来的**整屏壁纸**，而不是带子自己那一小块被压暗 /
      // 裁过的内容。
      //
      // **2026-09-21 真机订正了它的职责**：它管的是"采到哪一份背景"，**不管"能采到多大
      // 范围"** —— 真机上把它关掉（改实时采样），带底那条黑边**没有任何变化**。
      // 范围由 `homePageChromeGlassCaptureMargin` 撑盒子负责（见下面那组用例）。
      // ⇒ 两处调用保持 true（09-20 的口径不变），别再把它当成治黑线的药。
      await bandGlassPositioned(tester);
      final fill = tester.widget<HomePageChromeGlassFill>(
        find.byType(HomePageChromeGlassFill),
      );
      expect(
        fill.useAncestorBackdropGroup,
        isTrue,
        reason: '采到压暗过的带级内容会让这条带读起来像一块脏玻璃',
      );
    });
  });

  group('采样余量：把盒子撑高，让带底那截越界位移采得到内容（2026-09-21）', () {
    test('液态档：余量 ≥ 最大位移 + 1，且跟着「折射位移」滑杆走', () {
      // 带底朝外那几像素位移能探出裁剪区多少，就决定黑边多宽 —— 而位移整条曲线由
      // 「作用带宽度」缩放（所以用户看到的是「作用带调低、黑边变细」）。
      for (
        var refraction = LiquidGlassTuning.minRefraction;
        refraction <= LiquidGlassTuning.maxRefraction;
        refraction += 1
      ) {
        expect(
          homePageChromeGlassCaptureMargin(
            material: 'liquid',
            refraction: refraction,
          ),
          greaterThanOrEqualTo(refraction + 1),
          reason: '折射位移 $refraction：余量不够时带底那圈朝外采样的像素落在可采范围外，读到空',
        );
      }
      // 默认档（折射 8）取到的是下限 8：8 + 1 = 9 > 8。
      expect(
        homePageChromeGlassCaptureMargin(
          material: 'liquid',
          refraction: LiquidGlassTuning.defaultRefraction,
        ),
        LiquidGlassTuning.defaultRefraction + 1,
      );
      expect(homePageChromeGlassCaptureMarginFloor, 8.0);
    });

    test('表面自己的几何上限（窄带 / 预览带按带高折算那份）比调参更小时按它算', () {
      expect(
        homePageChromeGlassCaptureMargin(
          material: 'liquid',
          refraction: LiquidGlassTuning.maxRefraction,
          maxRefraction: 11,
        ),
        12.0,
        reason: '预览带把位移压到 11 ⇒ 余量只要盖过 11，多留的都是白花的绘制面积',
      );
    });

    test('实体 / frost 档不留余量；液态档照常', () {
      expect(
        homePageChromeGlassCaptureMargin(
          material: 'solid',
          refraction: LiquidGlassTuning.maxRefraction,
        ),
        0,
        reason: '实心条不采样任何东西，撑高盒子没有意义',
      );
      expect(
        homePageChromeGlassCaptureMargin(
          material: 'frost',
          refraction: LiquidGlassTuning.maxRefraction,
        ),
        0,
        reason: '磨砂带（跟随默认 + 默认档高斯）没有折射位移，同样不采样',
      );
      expect(
        homePageChromeGlassCaptureMargin(
          material: 'liquid',
          refraction: LiquidGlassTuning.maxRefraction,
        ),
        LiquidGlassTuning.maxRefraction + 1,
        reason: '液态带余量漏掉就是带底黑边回来',
      );
    });

    testWidgets('盒子（= 裁剪区）比可见带低一截，形状那一层一点不动', (tester) async {
      // 这两件事必须分开取（这条带来回改了六轮就是混成了一个量）：
      //  * **形状**（`HomePageChromeGlassFill` 那层）底边仍落在**可见带底**、下溢 0
      //    —— 挪它就是把可见区里的位移曲线截断成一条线；
      //  * **盒子**往下撑高 `captureMargin`（盒子的下边同时是 `Stack` 与 `ClipRect` 的
      //    裁剪线），让带外那块背景进到可采范围。
      // ⚠️ 必须是撑盒子：只把 `ClipRect` 的矩形放大没用 —— 里面的 `Stack` 是
      // `Clip.hardEdge`，按自己的边界裁孩子，交集仍是带子本体（2026-09-21 第九轮那一版
      // 就是这么白改的）。
      final positioned = await bandGlassPositioned(tester);
      final expected = homePageChromeGlassCaptureMargin(
        material: 'liquid',
        refraction: LiquidGlassTuning.defaults.refraction,
      );
      expect(
        expected,
        greaterThan(0),
        reason: '没有余量就是形状底边贴着裁剪线 —— 带底朝外的位移全采到空',
      );
      // 形状：底边仍在可见带底 ⇒ 下边偏移正好等于余量（盒子多出来的那一截）。
      expect(
        positioned.bottom,
        expected,
        reason: '形状底边仍在可见带底：盒子撑高了 `captureMargin`，这里要补回来',
      );

      // 裁剪区：`ClipRect` 的底边要比形状底边再低 `expected`，且宽高与可见带一致。
      final glassRect = tester.getRect(find.byType(HomePageChromeGlassFill));
      final clipRect = tester.getRect(
        find
            .ancestor(
              of: find.byType(HomePageChromeGlassFill),
              matching: find.byType(ClipRect),
            )
            .first,
      );
      expect(clipRect.left, glassRect.left + homePageChromeGlassEdgeOverdraw);
      expect(clipRect.right, glassRect.right - homePageChromeGlassEdgeOverdraw);
      expect(
        clipRect.bottom,
        closeTo(glassRect.bottom + expected, 0.5),
        reason: '裁剪区（= 可采范围）必须比形状底边低一截，否则那截位移读空 = 一条黑边',
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
