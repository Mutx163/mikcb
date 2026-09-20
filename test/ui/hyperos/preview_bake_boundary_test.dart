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
  }) =>
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 80,
            child: PreviewBakeBoundary(
              bakes: bakes,
              pixelRatio: 2,
              enabled: enabled,
              child: const ColoredBox(color: Color(0xFF112233)),
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
}
