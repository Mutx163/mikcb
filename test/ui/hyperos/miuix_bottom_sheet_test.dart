import 'dart:async';

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
          const MiuixGlassShape(
            cornerRadius: hyperosMiuixBottomSheetCornerRadius,
          ),
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
    expect(
      glass.surfaceShadow,
      isFalse,
      reason: '浮影由注入面在 ClipRRect 外面自己衬（见下一条），玻璃面自己那层要关掉，否则叠两层',
    );
  });

  testWidgets('注入面：衬一层与右上角菜单弹窗**同源**的浮影（画在裁剪之外）', (tester) async {
    // 用户 2026-09-20 对比右上角菜单弹窗时指出「这块看起来明显不一样」：那个弹窗是
    // `surfaceShadow: true`（浮在页面上），而贴底弹窗换上的实底面板从来不带浮影。
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
        home: Center(
          child: hyperosMiuixBottomSheetSurface(
            hostContext,
            const MiuixGlassShape(
              cornerRadius: hyperosMiuixBottomSheetCornerRadius,
            ),
            const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );

    final shadowBoxes = find.byWidgetPredicate(
      (w) =>
          w is DecoratedBox &&
          w.decoration is BoxDecoration &&
          ((w.decoration as BoxDecoration).boxShadow ?? const []).contains(
            HyperosGlassShadow.shadow,
          ),
    );
    expect(
      shadowBoxes,
      findsOneWidget,
      reason: '浮影数值必须与弹层家族同源（HyperosGlassShadow.shadow），且只有一层',
    );
    // 浮影要盖在 `ClipRRect` 外面 —— 垫在里面会被裁掉，等于没有。
    final shadowRect = tester.getRect(shadowBoxes);
    final clipRect = tester.getRect(
      find
          .ancestor(
            of: find.byType(HyperosSelectPopupGlass),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    expect(shadowRect, clipRect, reason: '浮影矩形应当与面板轮廓一致（浮影靠 blur 溢到轮廓外）');
  });

  testWidgets('注入面：裁剪曲线与材质同源，只有底边外溢', (tester) async {
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
        home: Center(
          child: hyperosMiuixBottomSheetSurface(
            hostContext,
            const MiuixGlassShape(
              cornerRadius: hyperosMiuixBottomSheetCornerRadius,
            ),
            const SizedBox(
              key: ValueKey('sheet-content'),
              width: 100,
              height: 100,
            ),
          ),
        ),
      ),
    );

    // 2026-09-20 定稿：① 外面裁的曲线必须**就是材质画的那条**（上沿两角正圆角、底边直）
    // —— 拿上游那条贝塞尔曲线裁会在圆角处差 1.35px，露成「外框一个圆角、里面还有一个更小
    // 的圆角」；② 上沿与左右**不外溢**，留着材质那一圈边缘观感（推掉一点真机实测「没区别」，
    // 推光又读成平板子 —— 两档用户都报过，最后选定「留着」）；③ 面板**不自带任何材质参数**
    // （见下一条断言）。
    final clip = tester.widget<ClipRRect>(
      find
          .ancestor(
            of: find.byType(HyperosSelectPopupGlass),
            matching: find.byType(ClipRRect),
          )
          .first,
    );
    final glass = tester.widget<HyperosSelectPopupGlass>(
      find.byType(HyperosSelectPopupGlass),
    );
    final radius = glass.cornerRadius;
    expect(
      clip.borderRadius,
      BorderRadius.vertical(top: Radius.circular(radius)),
      reason: '裁剪曲线与材质不同源：圆角处会露出两条曲线之间那条缝',
    );

    final panel = tester.getRect(find.byKey(const ValueKey('sheet-content')));
    final glassRect = tester.getRect(find.byType(HyperosSelectPopupGlass));
    // 上沿与左右**不外溢**：材料边界与裁剪线是同一条线。
    //
    // 这条与下面那条 `maxRefraction == 0` 是**一套**，不能只改一边：恰恰因为上沿不外溢
    // （裁剪线压在形状边界上），朝外推的位移才会读空成暗线；真要重新外溢就得同时把位移放回
    // 去（2026-09-20 试过外溢 1/2/4 与"推光"，真机不是「没区别」就是「读成平板子」，
    // 完整沿革见 miuix_bottom_sheet.dart 的「上沿那条线」一节）。
    expect(glassRect.top, closeTo(panel.top, 0.01), reason: '上沿不该外溢');
    expect(glassRect.left, closeTo(panel.left, 0.01), reason: '左边不该外溢');
    expect(glassRect.right, closeTo(panel.right, 0.01), reason: '右边不该外溢');
    // 底边必须外溢：底角在裁剪上是直角、材质是正圆角，不外溢会各缺一小块。
    expect(
      glassRect.bottom,
      closeTo(panel.bottom + hyperosMiuixBottomSheetGlassBottomOverdraw, 0.01),
      reason: '底边不外溢的话两个底角会各缺一小块',
    );

    // 面板**不带材质参数**；唯一压在它身上的是**几何适配**：边缘一律不外推采样。
    //
    // 沿革（别看错方向）：这里一度挂着一个 `maxRefraction = 3`（"长直边上把面板外的内容
    // 整条拉进来就成了条纹，压小它"）—— 那是补"边光有方向性"那场病的药，方向性从材质层面
    // 去掉后（见两个 .frag 的文件头）连同 `HyperosSelectPopupGlass` 的透传口子一起撤了。
    //
    // 2026-09-22 又按用户口径（「改成和设置页面返回键的那个圆一样的边缘高光，不然现在顶部
    // 有暗色线」）**重新加了回来，但值不同、理由也不同**：这是**几何**问题，不是材质观感 ——
    // 面板上沿与它外面那层 `ClipRRect` 的裁剪线是同一条线（上沿刻意不外溢），而引擎给
    // backdrop filter 准备背景时把可采范围掐在「渲染目标 ∩ 当前裁剪区」
    // （Impeller `Canvas::GetLocalCoverageLimit → GetSourceCoverage`）⇒ 上沿那一圈朝外推的
    // 位移（标准档 8dp）第一步就读空、压在染色底上就是那条暗线。压到 0 = 板内每个像素只取
    // 正下方那一个，与返回键那颗圆钮同一取舍（`hyperos_back_button_test.dart` 钉着同一个值）。
    //
    // 注意这不是"给这块面板开材质口子"：受光高光照旧由材质画在贴边那一圈（`rimBand` 只由
    // "离边多远"算），所以上沿**既有边光、又没有那条线** —— 2026-09-20 记的"只有两个稳定
    // 状态（留着 / 推光）"是因为把高光与折射当成了一件事，这次把它们拆开了。
    final glassSurface = tester.widget<LiquidGlassSurface>(
      find.byType(LiquidGlassSurface),
    );
    expect(
      glassSurface.maxRefraction,
      hyperosMiuixBottomSheetMaxRefraction,
      reason:
          '上沿压在裁剪线上，朝外位移会读空成暗线；要改这个值先读 miuix_bottom_sheet.dart 的「上沿那条线」第十五轮',
    );
    expect(
      hyperosMiuixBottomSheetMaxRefraction,
      0,
      reason: '留一点位移就留一点暗线（可采余量就是 0）',
    );
    expect(
      glassSurface.role,
      LiquidGlassRole.pinnedChrome,
      reason: '与右上角菜单弹窗同属固定小件，锁同一档（标准档），这是"观感一致"的前提',
    );
  });

  testWidgets('注入面：回落材质（磨砂 / 实底）跟着同一个底边外溢', (tester) async {
    // 回落材质自己按**正圆**裁，与外面的裁剪曲线（同一个正圆角）一致；只剩底边那两个
    // 直角角点需要外溢盖住 —— 它与玻璃面共用同一个 `Positioned` 矩形，所以一起被盖住。
    // 测试环境恒无 shader 后端（`LiquidGlassSurface.isAvailable` 为假），这里画出来的
    // 就是回落材质，正好用它钉住这条。
    // 测试环境恒无 shader 后端（`LiquidGlassSurface.isAvailable` 为假），这里画出来的
    // 就是回落材质，正好用它钉住这条。
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
        home: Center(
          child: hyperosMiuixBottomSheetSurface(
            hostContext,
            const MiuixGlassShape(
              cornerRadius: hyperosMiuixBottomSheetCornerRadius,
            ),
            const SizedBox(
              key: ValueKey('sheet-content'),
              width: 100,
              height: 100,
            ),
          ),
        ),
      ),
    );

    final panel = tester.getRect(find.byKey(const ValueKey('sheet-content')));
    final fallback = tester.getRect(find.byType(StableFrostedSurface));
    expect(
      fallback,
      Rect.fromLTRB(
        panel.left,
        panel.top,
        panel.right,
        panel.bottom + hyperosMiuixBottomSheetGlassBottomOverdraw,
      ),
      reason: '回落材质没跟着底边外溢的话，两个底角会各缺一小块',
    );
  });

  group('底边外溢量的几何下界（2026-09-20）', () {
    test('要够盖住直角底角，且不多铺', () {
      const r = hyperosMiuixBottomSheetCornerRadius;
      const k = hyperosMiuixBottomSheetGlassBottomOverdraw;
      const sqrt2 = 1.4142135623730951;

      // 底边两角：裁剪是**直角**，材质是正圆角（圆心在 (r, H + k − r)、半径 r），
      // 要盖住角点 (0, H) → √2·(r − k) ≤ r → k ≥ (1 − 1/√2)·r。
      const needed = r * (1 - 1 / sqrt2);
      expect(
        k,
        greaterThanOrEqualTo(needed),
        reason: '外溢量不够：两个底角会露出材质圆角与直角裁剪之间那块缝',
      );
      expect(
        k,
        lessThan(needed + 1),
        reason: '多铺没有收益，而这个常量以后要是被拿去当四边外溢用，就会把边缘玻璃感切掉',
      );
    });
  });

  testWidgets('真开一次：面板是注入面、蒙层之前有捕获点、收起后跑后续动作', (tester) async {
    var afterDismissRan = false;
    var sheetFutureCompleted = false;
    late BuildContext hostContext;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return Center(
              child: TextButton(
                onPressed: () => unawaited(
                  showMiuixBottomSheet<void>(
                    context: context,
                    builder: (sheetContext, close) => TextButton(
                      onPressed: () =>
                          close(afterDismiss: () => afterDismissRan = true),
                      child: const Text('关闭'),
                    ),
                  ).then((_) => sheetFutureCompleted = true),
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
      find.byType(ModalBarrier),
      findsWidgets,
      reason: '弹窗打开时要保留底层语义隔离和首帧点击隔离',
    );
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

    expect(
      find.byType(MiuixWindowBottomSheet),
      findsNothing,
      reason: '收起后路由也要摘掉',
    );
    expect(
      afterDismissRan,
      isTrue,
      reason: '后续动作（push 页面 / 开 sheet）必须在退场动画结束之后才跑',
    );
    expect(hostContext.mounted, isTrue, reason: '宿主页面不该被弹层带走');
    expect(
      sheetFutureCompleted,
      isTrue,
      reason:
          'await showMiuixBottomSheet 的 Future 必须完成 —— 调用方在 await 它'
          '（`_showCourseActions` / `showCourseNoteSheet`），不完成就是静默挂起；'
          '收尾无论走 pop 还是 removeRoute 都得保证这一点',
    );
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

  testWidgets('内容与屏幕底之间留出安全区 + 16 的呼吸', (tester) async {
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showMiuixBottomSheet<void>(
                context: context,
                builder: (sheetContext, close) => const SizedBox(
                  key: ValueKey('sheet-content'),
                  width: 120,
                  height: 200,
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    // 上游面板只按键盘留底部内边距，不管系统手势区 —— 承载壳补的这层要是掉了，
    // 最后一行内容会贴死在屏幕最下沿（用户反馈过：「调课停课什么的都到底部屏幕外面去了」）。
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final contentBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('sheet-content')))
        .dy;
    expect(
      screenHeight - contentBottom,
      // 浮点误差留一点余量；测试窗口的系统安全区是 0，所以这里就是那道 16。
      greaterThanOrEqualTo(hyperosMiuixBottomSheetContentBottomGap - 0.5),
    );
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

  testWidgets('收起动画期间下层立刻能点到（不再等退场弹簧结算）', (tester) async {
    // 真机回归（2026-09-23）：周视图点开一节课、退出之后马上点另一节，第二下没反应。
    // 逐帧实测的两层原因，**都在"活得比看起来久"**：
    //   · 面板约 320ms 就滑出屏幕，而全屏蒙层与路由屏障要等退场弹簧**数学收敛**
    //     （容差 1e-4）才摘掉 —— 到约 832ms，中间约 500ms 点哪都被吃掉；
    //   · 蒙层那时已经是空操作（`_requestDismiss` → 已收起的 early return），
    //     屏障更是什么都不做 —— 纯粹是吞掉。
    // 于是两处一起改：上游那层蒙层收起即 IgnorePointer，本仓承载壳的路由屏障不挡点击。
    var opens = 0;
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () {
                opens++;
                showMiuixBottomSheet<void>(
                  context: context,
                  builder: (sheetContext, close) => SizedBox(
                    height: 160,
                    child: TextButton(
                      onPressed: () => close(),
                      child: const Text('关闭'),
                    ),
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(opens, 1);
    expect(find.byType(MiuixWindowBottomSheet), findsOneWidget);

    // 收起：这里**不** settle —— 要的就是退场动画还在放的那几帧。
    await tester.tap(find.text('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(
      find.byType(MiuixWindowBottomSheet),
      findsOneWidget,
      reason: '退场动画还没走完，面板仍在树上（只是不该再吃输入）',
    );

    // 用户「关掉这节课、马上点下一节」的那一下：
    await tester.tap(find.text('打开'));
    await tester.pump();
    expect(opens, 2, reason: '收起一开始，下层就该立刻收得到点击');

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('收起期间马上开下一个弹窗：前一个收完不会把新的弹掉', (tester) async {
    // 上一条把输入提前还给页面之后，用户完全可能在前一个还在退场时就点开下一个。
    // 那一刻新路由压在旧路由上面，而收尾原来是 `Navigator.pop()`（摘的是**栈顶**那条）
    // ⇒ 会把刚开的这个弹掉、旧路由反而留在栈上。所以收尾改成「摘自己这条路由」。
    var opens = 0;
    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () {
                final index = ++opens;
                showMiuixBottomSheet<void>(
                  context: context,
                  builder: (sheetContext, close) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('弹窗$index'),
                      TextButton(
                        onPressed: () => close(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('弹窗1'), findsOneWidget);

    // 收起第一个，然后在它退场动画期间点开第二个。
    await tester.tap(find.text('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('弹窗1'), findsOneWidget, reason: '第一个还在退场');
    await tester.tap(find.text('打开'));
    // 两帧：路由挂上 → 窗口层 entry 在帧末插入（`_ensureWindowEntry` 是 post-frame
    // 回调）→ 下一帧才建出面板内容。
    await tester.pump();
    await tester.pump();
    expect(find.text('弹窗2'), findsOneWidget, reason: '退场期间就该能开下一个');

    // 等第一个的退场弹簧走完（它这时才摘自己的路由）。
    await tester.pumpAndSettle();
    expect(
      find.text('弹窗2'),
      findsOneWidget,
      reason: '前一个收完摘的必须是它自己那条路由，不能把新开的这个弹掉',
    );
    expect(find.text('弹窗1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧弹窗被新弹窗压住时不再执行越级的 afterDismiss', (tester) async {
    var opens = 0;
    late BuildContext hostContext;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) {
            hostContext = context;
            return Center(
              child: TextButton(
                onPressed: () {
                  final index = ++opens;
                  showMiuixBottomSheet<void>(
                    context: context,
                    builder: (sheetContext, close) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('弹窗$index'),
                        TextButton(
                          onPressed: () {
                            if (index == 1) {
                              close(
                                afterDismiss: () {
                                  Navigator.of(hostContext).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          const Scaffold(body: Text('旧回调页')),
                                    ),
                                  );
                                },
                              );
                            } else {
                              close();
                            }
                          },
                          child: const Text('关闭'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('打开'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('弹窗2'), findsOneWidget);
    expect(find.text('旧回调页'), findsNothing);
  });

  testWidgets('退场期间重复 close 会收齐每个 afterDismiss', (tester) async {
    late MiuixBottomSheetClose close;
    var firstRan = false;
    var secondRan = false;

    await tester.pumpWidget(
      TestApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMiuixBottomSheet<void>(
              context: context,
              builder: (sheetContext, requestClose) {
                close = requestClose;
                return const SizedBox(height: 120);
              },
            ),
            child: const Text('打开'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    close(afterDismiss: () => firstRan = true);
    close(afterDismiss: () => secondRan = true);
    await tester.pumpAndSettle();

    expect(firstRan, isTrue);
    expect(secondRan, isTrue);
  });
}
