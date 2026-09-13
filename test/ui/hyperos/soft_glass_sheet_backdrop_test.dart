import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../helpers_test_app.dart';

/// 弹层（Overlay）里的柔光玻璃能不能拿到屏级采样源的快照。
///
/// 真机现象（2026-09-13，dev profile）：外观与配色 →「打开预览面板」，柔光档下
/// 弹窗看着是**透明的** —— 后面设置页的文字清晰可读、完全没有模糊。
///
/// 上游 `MiuixGlass.paint` 只有两条路：
/// 1. `ready && backdrop.snapshot != null && globalOffset != null` → 模糊 +
///    `blend` 三层混色。`miuix_os4_blend.frag` 返回 `vec4(d*a, src.a)`，输出 α 就是
///    背景图 α，而背景图来自页面的 `toImageSync`（不透明）→ **这条路上不可能透明**。
/// 2. 否则 → 画 `fill` = `SoftGlassTokens.tint(blurEnabled: true)`
///    = 252 灰 @ **α 0.675**，且不经模糊 → 后面的字清晰透出 = 真机上看到的「透明弹窗」。
///
/// 弹层画在 Overlay 上，页级 `HyperosGlassBackdropHost` 的 scope 不在它的祖先链里，
/// `SoftGlassSurface` 只能经 `HyperosGlassBackdropRegistry.active` 取采样源。这条
/// 「弹层 → 注册表 → 页级宿主录帧」的路此前没有任何用例覆盖。
///
/// 真机根因（2026-09-13，`hyperos_glass_backdrop_host.dart` `acquireZone`）：该页
/// **已经**有一块页内玻璃（预览卡里的 `HomePageChromeGlassFill` → `SoftGlassSurface`，
/// `timetable_week_preview.dart:258`）让 `capturing` 为 true；弹窗面板在屏底又开出
/// **第二块**采样区，而旧判据 `wasEmpty && capturing` 一次通知都不发 → 捕获节点没
/// 任何理由重绘 → 第二块的 `snapshot` 恒为 null → 上游走上面第 2 条兜底。所以下面
/// 第二个用例专门覆盖「页内已有块 + 弹层新开块」这个真机组合（第一个只有一块，所以
/// 它在修之前也是绿的 —— 这正是这条 bug 长期没被用例拦住的原因）。
///
/// ⚠️ 这里**不能**用 `HyperosSheetFrame` 走生产入参来测：它内部的
/// `HyperosBlurredHeader.backdropBlurEnabled` 经 `Platform.isAndroid` 判定，
/// 而 `flutter test` 跑在 Windows 上 → 恒 false → 玻璃连采样源都不绑（`backdrop`
/// 为 null），测出来的是宿主机的平台，不是真机。所以本用例显式构造
/// `SoftGlassSurface`（`blurEnabled` 默认 true），只验证「Overlay 里的玻璃能否经注册表拿到
/// 宿主录的快照」这一段 —— 这正是真机上弹层玻璃走的路径。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('弹层里的柔光玻璃经注册表拿到页级采样源，并在当帧末录到快照', (tester) async {
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);

    late BuildContext pageContext;
    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: const FrostedAppearance(
            sheetBlurSigma: 15,
            sheetTintAlpha: 0.70,
            sheetBarrierAlpha: 0.20,
            glassMode: FrostedGlassMode.softGlass,
          ),
          child: HyperosGlassBackdropHost(
            controller: controller,
            child: Builder(
              builder: (context) {
                pageContext = context;
                return const ColoredBox(
                  color: Color(0xFFE8E8E8),
                  child: SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      HyperosGlassBackdropRegistry.active,
      same(controller),
      reason: '页级宿主应占注册表栈顶，弹层才有采样源可取',
    );

    unawaited(
      showHyperosSheet<void>(
        context: pageContext,
        builder: (_) => const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 320,
            height: 120,
            child: SoftGlassSurface(
              enableShadows: false,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      controller.capturing,
      isTrue,
      reason: '弹层玻璃挂载后应请求页级宿主录帧',
    );
    expect(
      controller.zones,
      isNotEmpty,
      reason: '弹层玻璃要把自己占的区域登记给页级采样源',
    );
    expect(
      controller.zones.first.image,
      isNotNull,
      reason: '宿主应为弹层玻璃录到快照；否则上游走 fill 兜底'
          '（252 灰 @α 0.675、无模糊）→ 真机上就是「透明弹窗」',
    );
    expect(
      controller.zones.first.origin,
      isNotNull,
      reason: '快照要有全局原点，上游才能把采样对齐到玻璃位置',
    );
  });

  testWidgets('页内已有玻璃时，弹层新开的那一块也必须录到快照（真机回归）', (tester) async {
    final controller = HyperosGlassBackdropController();
    addTearDown(controller.dispose);

    late BuildContext pageContext;
    await tester.pumpWidget(
      TestApp(
        home: FrostedAppearanceScope(
          appearance: const FrostedAppearance(
            sheetBlurSigma: 15,
            sheetTintAlpha: 0.70,
            sheetBarrierAlpha: 0.20,
            glassMode: FrostedGlassMode.softGlass,
          ),
          child: HyperosGlassBackdropHost(
            controller: controller,
            child: Builder(
              builder: (context) {
                pageContext = context;
                return const Column(
                  children: [
                    // 页内先占一块 —— 等价于高级材质页预览卡里的玻璃带
                    // （`HomePageChromeGlassFill`），弹窗打开前它已让 capturing 为 true。
                    SizedBox(
                      height: 120,
                      child: SoftGlassSurface(
                        enableShadows: false,
                        child: SizedBox.expand(),
                      ),
                    ),
                    Expanded(child: ColoredBox(color: Color(0xFFE8E8E8))),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.zones, hasLength(1));
    expect(controller.zones.first.image, isNotNull, reason: '页内第一块应正常录到快照');

    unawaited(
      showHyperosSheet<void>(
        context: pageContext,
        builder: (_) => const Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 320,
            height: 120,
            child: SoftGlassSurface(
              enableShadows: false,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      controller.zones,
      hasLength(2),
      reason: '屏底的弹层玻璃与页顶那块相距远超 _joinGap，应单独成一块',
    );
    for (final zone in controller.zones) {
      expect(
        zone.image,
        isNotNull,
        reason: '每一块都得录到快照；新开的块漏录就是真机上的「透明弹窗」',
      );
    }
  });
}
