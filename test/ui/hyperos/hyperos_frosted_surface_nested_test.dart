// 弹窗面板实体回退时嵌套 tile 着色的同步回归测试。
//
// 回归背景（2026-09-12）：面板走 solid 分支回退**纯白实体卡片**时，嵌套 tile
// 若仍走玻璃面板的白色水洗（白 28% / 白 22–72%），叠白底整个隐形——课程弹窗
// 「只剩字、小框框没了」。修复后实体面板内的 tile 改走中性水洗。
//
// 触发条件变化（2026-09-19）：原先靠「作用范围 → 弹窗」开关关掉来触发实体
// 回退，那批开关已整体删除（弹窗家族锁标准档）。现在**只剩系统降级**能把它
// 摘成实体（[LiquidGlassDegradation.shouldDegradeFor]：减动效 / 高对比），
// 所以这里用 MediaQuery 打开这两个信号来复现同一条分支。
//
// 测试环境（VM）liveBlurSupported=false，withBlur:true 的白色水洗分支无法
// 在此复现（那需要真实模糊能力）；这里钉住的是**分支选择契约**：面板是玻璃 =
// 玻璃水洗分支，面板被降级成实体 = 中性水洗分支。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_background.dart';
import 'package:university_timetable/ui/hyperos/hyperos_sheet.dart';

Widget _harness({required FrostedGlassMode mode, bool degraded = false}) {
  Widget app = MaterialApp(
    home: FrostedAppearanceScope(
      appearance: FrostedAppearance(
        sheetBlurSigma: 18,
        sheetTintAlpha: 0.5,
        sheetBarrierAlpha: 0.4,
        glassMode: mode,
      ),
      child: HyperosFrostedPanelScope(
        child: Center(
          child: HyperosFrostedSurface(
            borderRadius: BorderRadius.circular(12),
            child: const Text('tile'),
          ),
        ),
      ),
    ),
  );
  if (degraded) {
    app = MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: app,
    );
  }
  return app;
}

void main() {
  testWidgets('soft glass：嵌套 tile 走柔光玻璃水洗', (tester) async {
    await tester.pumpWidget(_harness(mode: FrostedGlassMode.liquidGlass));
    await tester.pump();

    // 柔光面板内：父面板自带模糊，tile 只上一层白色水洗（浅色主题 28%）。
    final tile = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byType(HyperosFrostedSurface),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(tile.color, Colors.white.withValues(alpha: 0.28));
  });

  testWidgets('soft glass + 系统降级：嵌套 tile 弃白色水洗改中性水洗', (tester) async {
    await tester.pumpWidget(
      _harness(mode: FrostedGlassMode.liquidGlass, degraded: true),
    );
    await tester.pump();

    // 面板已回退纯白实体：白色水洗会白底白框隐形，必须走 withBlur:false
    // 的中性水洗（浅色主题 = 黑 5%）。
    final surface = tester.widget<FrostedHeaderBackground>(
      find.descendant(
        of: find.byType(HyperosFrostedSurface),
        matching: find.byType(FrostedHeaderBackground),
      ),
    );
    expect(surface.tint, Colors.black.withValues(alpha: 0.05));
  });

  testWidgets('liquid glass + 系统降级：嵌套 tile 同样改中性水洗', (tester) async {
    await tester.pumpWidget(
      _harness(mode: FrostedGlassMode.liquidGlass, degraded: true),
    );
    await tester.pump();

    final surface = tester.widget<FrostedHeaderBackground>(
      find.descendant(
        of: find.byType(HyperosFrostedSurface),
        matching: find.byType(FrostedHeaderBackground),
      ),
    );
    expect(surface.tint, Colors.black.withValues(alpha: 0.05));
  });

  testWidgets('基础高斯档：嵌套 tile 保持既有通用分支', (tester) async {
    await tester.pumpWidget(_harness(mode: FrostedGlassMode.gaussian));
    await tester.pump();

    // 基础档不受降级矩阵约束：VM 上模糊不可用 → withBlur:false，
    // 与修复前行为一致（真机上模糊可用时仍走白水洗磨砂分支）。
    final surface = tester.widget<FrostedHeaderBackground>(
      find.descendant(
        of: find.byType(HyperosFrostedSurface),
        matching: find.byType(FrostedHeaderBackground),
      ),
    );
    expect(surface.tint, Colors.black.withValues(alpha: 0.05));
  });
}
