// PreviewBakeBoundary：渲染源「按帧快照」的出图链路与重烤触发。
//
// 测试环境没有 GPU 后端，`toImageSync` 走 CPU 光栅但**能出真图**（与玻璃的
// 片段着色器不同），所以这里可以端到端钉住「重绘 → 帧末出图 → 换新图」。
//
// 出图密度的口径（必须严格等于设备 dpr，不能乘显示缩放）钉在
// `PreviewBakeBoundary` 的类注释里——它由真机玻璃几何实锤（2026-09-19），不是
// 能在本环境验证的推导，因此这里不再有「比例纯函数」可测。
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/preview_bake_boundary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget host(
    ValueNotifier<ui.Image?> bakes, {
    bool enabled = true,
    Listenable? repaintSignal,
  }) =>
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: PreviewBakeBoundary(
              bakes: bakes,
              pixelRatio: 2,
              repaintSignal: repaintSignal,
              enabled: enabled,
              child: const RepaintBoundary(
                child: ColoredBox(color: Color(0xFF112233)),
              ),
            ),
          ),
        ),
      );

  testWidgets('子树重绘后帧末出图；换内容换新图', (tester) async {
    final bakes = ValueNotifier<ui.Image?>(null);
    addTearDown(() {
      bakes.value?.dispose();
      bakes.dispose();
    });

    await tester.pumpWidget(host(bakes));
    expect(bakes.value, isNull, reason: '首烤延一帧：挂载帧不出图（该帧 layer 里玻璃还是退化态）');
    await tester.pump();
    final first = bakes.value;
    expect(first, isNotNull, reason: '延一帧后必须烤出图');
    expect(first!.width, 200, reason: '100 逻辑像素 × 出图密度 2');
    expect(first.height, 160, reason: '80 逻辑像素 × 出图密度 2');

    // 内容变了 → 重绘 → 节流间隔（200ms）后补拍出新图（旧图由边界释放，
    // 这里只核对换了实例）。
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: PreviewBakeBoundary(
              bakes: bakes,
              pixelRatio: 2,
              child: const ColoredBox(color: Color(0xFF332211)),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(bakes.value, isNotNull);
    expect(identical(bakes.value, first), isFalse, reason: '重绘后必须烤新图');
  });

  testWidgets('节流：间隔内的连续重绘合并，收尾必补拍最新帧', (tester) async {
    var bakeCount = 0;
    final bakes = ValueNotifier<ui.Image?>(null);
    bakes.addListener(() => bakeCount++);
    addTearDown(() {
      bakes.value?.dispose();
      bakes.dispose();
    });

    Widget host(Color color) => MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: PreviewBakeBoundary(
                bakes: bakes,
                pixelRatio: 2,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(const Color(0xFF000001)));
    await tester.pump();
    await tester.pump();
    final countAfterFirst = bakeCount;
    expect(countAfterFirst, greaterThanOrEqualTo(1), reason: '首烤（延一帧）后必须有图');

    // 间隔内连着重绘两次：合并，不得逐帧出图（2026-09-19 真机实锤：切日
    // 视图逐帧出整屏图把 UI 线程堵到 2fps 的教训）。
    await tester.pumpWidget(host(const Color(0xFF000002)));
    await tester.pump();
    await tester.pumpWidget(host(const Color(0xFF000003)));
    await tester.pump();
    expect(
      bakeCount - countAfterFirst,
      lessThanOrEqualTo(1),
      reason: '节流间隔内不得逐帧出图',
    );

    // 间隔过后补拍收尾：最终内容必有一张。
    await tester.pump(const Duration(milliseconds: 250));
    expect(bakeCount, greaterThan(countAfterFirst), reason: '收尾必补拍');
  });

  testWidgets('enabled=false 不烤图；转正后整层重画并烤出第一张', (tester) async {
    final bakes = ValueNotifier<ui.Image?>(null);
    addTearDown(() {
      bakes.value?.dispose();
      bakes.dispose();
    });

    // 门控关着：宿主路由还在进场转场（玻璃/壁纸 uniform 带转场坐标），
    // 这期间烤出来的图必是歪的，所以干脆不烤。
    await tester.pumpWidget(host(bakes, enabled: false));
    await tester.pump();
    expect(bakes.value, isNull, reason: '门控关闭期间不得烤图');

    // 落定转正：整层重画（按落定坐标重录）→ 首烤延一帧 → 下一帧末烤出第一张。
    await tester.pumpWidget(host(bakes));
    expect(bakes.value, isNull, reason: '首烤延一帧：转正帧不出图');
    await tester.pump();
    final first = bakes.value;
    expect(first, isNotNull, reason: '转正后必须重画并烤出图');
    expect(first!.width, 200, reason: '100 逻辑像素 × 出图密度 2');
    expect(first.height, 160, reason: '80 逻辑像素 × 出图密度 2');

    // 门控再关：已有图保持显示（不清空）。
    await tester.pumpWidget(host(bakes, enabled: false));
    await tester.pump();
    expect(bakes.value, isNotNull, reason: '关 门控不清空已有快照');
  });

  testWidgets('内容只在子级重绘边界内变化：必须靠 repaintSignal 才重烤', (tester) async {
    // 这条钉的是 2026-09-22 真机上报的「外观编辑页整个定格」的机制：玻璃面与
    // 壁纸层各自带重绘边界，它们的内容变化只在边界内部重绘、**传不到烤图边界**
    // ——本节点没被标脏，`paint` 就不再被调到，重烤也就停了。日志上表现为
    // 「草稿改了上百次，烤图计数一动不动」。所以内容源必须走 [repaintSignal]
    // 显式喊一声。
    final bakes = ValueNotifier<ui.Image?>(null);
    final dirty = ValueNotifier<int>(0);
    addTearDown(() {
      bakes.value?.dispose();
      bakes.dispose();
      dirty.dispose();
    });

    Widget host(int revision) => MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: PreviewBakeBoundary(
                bakes: bakes,
                pixelRatio: 2,
                repaintSignal: dirty,
                // 子级自己一层重绘边界：内容变化被它挡在里面，正是真机里
                // 玻璃面 / 壁纸层的形状。
                child: RepaintBoundary(
                  child: ColoredBox(color: Color(0xFF112200 + revision)),
                ),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(1));
    await tester.pump();
    final first = bakes.value;
    expect(first, isNotNull, reason: '首烤（延一帧）后必须有图');

    // 只改子级重绘边界里面的内容：到不了烤图边界 → 不该重烤（这就是"定格"）。
    await tester.pumpWidget(host(2));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      identical(bakes.value, first),
      isTrue,
      reason: '子级重绘边界内的变化传不到烤图边界，没有信号就不该重烤',
    );

    // 显式喊一声 → 本节点标脏 → 整层重录 → 烤出新图。
    dirty.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      identical(bakes.value, first),
      isFalse,
      reason: 'repaintSignal 必须强制重烤（否则预览定格）',
    );
  });

  testWidgets('重烤也延一帧：内容变了的那一帧不出图，下一帧才出', (tester) async {
    // 玻璃面在 paint 里读的是**上一帧末**才落地的快照，按新快照的重画要等下一帧
    // —— 任何一帧里的玻璃画的都是上一帧的内容。所以"改了就在本帧出图"必然烤到
    // 「上一帧的画面」，真机读数就是「预览和实际差一帧」（用户 2026-09-22）。
    // 这条钉住"每一张都延一帧"，而不只是首张。
    final bakes = ValueNotifier<ui.Image?>(null);
    addTearDown(() {
      bakes.value?.dispose();
      bakes.dispose();
    });

    // 子级**不套**重绘边界：这样内容一变，本边界就会重绘（走"子树重绘"这条腿）。
    Widget host(Color color) => MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: PreviewBakeBoundary(
                bakes: bakes,
                pixelRatio: 2,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host(const Color(0xFF000001)));
    await tester.pump();
    final first = bakes.value;
    expect(first, isNotNull, reason: '首烤（延一帧）后必须有图');

    await tester.pumpWidget(host(const Color(0xFF000002)));
    expect(
      identical(bakes.value, first),
      isTrue,
      reason: '内容变了的那一帧不得出图 —— 此刻 layer 里的玻璃还是上一帧的内容',
    );

    // 下一帧末才出图（带时长的 pump 顺带放行 200ms 节流）。
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      identical(bakes.value, first),
      isFalse,
      reason: '下一帧必须补上最新画面（否则卡片永远差一帧）',
    );
  });
}
