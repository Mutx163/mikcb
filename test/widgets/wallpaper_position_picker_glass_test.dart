import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/ui/hyperos/liquid/liquid_glass_surface.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/utils/home_startup_visual_primer.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

/// 壁纸位置选择页（「调整壁纸显示位置」）的悬浮按钮材质 / 几何守护。
///
/// 这一页是**裸 `Scaffold`**（不是 `HyperosPage`），四颗悬浮按钮（退出 / 完成 /
/// 重置 / 换壁纸）**锁液态玻璃的标准档**（`LiquidGlassRole.pinnedChrome`），与设置页
/// 左上角返回键同一档 —— 用户 2026-09-21 口径：「这个应该和设置界面左上角返回键保持
/// 强制同材质」。所以本文件的场景刻意选**柔光档**（`glassMode: softGlass`）：四颗
/// 按钮必须无视它，一颗柔光面都不许出现。
///
/// 历史上这一页踩过的两个坑，仍由本文件守着：
///
/// 1. **没有本屏采样源**：`HyperosGlassBackdropHost` 注册进
///    `HyperosGlassBackdropRegistry`，弹在本页之上的 modal（sheet / dialog）才能
///    取到**本页**画面；缺了它，注册表会回落到压在下面的设置页（已被视差左移、
///    且被盖住后连 paint 都停了）。
/// 2. **玻璃误入捕获子树**：上游要求玻璃必须在捕获子树之外（防反馈采样），所以按钮层
///    与 `HyperosGlassBackdropHost` 平级。
/// 3. **转场帧里画活玻璃**（真机 2026-09-21「按钮被分成两层、玻璃跑到右边、原位剩一个
///    透明按钮」）：折射层按屏幕绝对坐标摆形状，侧滑转场途中画过的那一帧会被烤进缓存
///    ⇒ 落定后玻璃永久偏在一侧。落定前一律退回磨砂顶着，见
///    `_WallpaperPositionPickerPageState._routeSettled`。
///
/// 另外底部按钮曾被 `Center` 的 maxWidth 撑满：`Container` 带 `alignment` 时在
/// 有界约束下会占满可用宽度，`minWidth` 只管下限。
void main() {
  const screenSize = Size(1280, 2772);
  const screenDpr = 3.2;

  // 刻意选柔光档：四颗按钮锁标准档液态玻璃，这个档位不该影响它们一分一毫。
  const appearance = FrostedAppearance(
    sheetBlurSigma: 20,
    sheetTintAlpha: 0.5,
    sheetBarrierAlpha: 0.3,
    glassMode: FrostedGlassMode.softGlass,
  );

  /// [imagePath] 不存在的路径：本测试只关心材质 / 几何 / 极性，占位分支更省事
  /// （真实文件 I/O 在 testWidgets 里需要 runAsync）。
  const wallpaperPath = 'C:/definitely/not/here.png';

  Future<void> pumpPicker(
    WidgetTester tester, {
    String imagePath = wallpaperPath,
    /// false = 只把转场推几帧（停在侧滑途中），用来验"转场帧里不画活玻璃"。
    bool settle = true,
  }) async {
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = screenDpr;
    addTearDown(tester.view.reset);

    // 外观作用域必须在 Navigator **之上**：路由里的页面读的是同一个 scope。
    await tester.pumpWidget(
      FrostedAppearanceScope(
        appearance: appearance,
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          // 造一条「自带宿主的被盖住页」：其余页面就压在这种宿主之上。
          home: Builder(
            builder: (context) => HyperosGlassBackdropHost(
              child: Scaffold(
                backgroundColor: const Color(0xFFF2F2F2),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SoftGlassSurface(
                        borderRadius: BorderRadius.circular(18),
                        child: const SizedBox(width: 200, height: 40),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () {
                          pushWallpaperPositionPickerPage(
                            context,
                            imagePath: imagePath,
                            initialAlignX: 0,
                            initialAlignY: 0,
                            onPickNewImage: () async => null,
                          );
                        },
                        child: const Text('open'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    // 不用 pumpAndSettle：转场期间玻璃在自激重绘，settle 不下来。
    final frames = settle ? 12 : 3;
    for (var i = 0; i < frames; i++) {
      await tester.pump(settle
          ? const Duration(milliseconds: 60)
          : const Duration(milliseconds: 30));
    }
  }

  Finder pickerSurfaces() => find.descendant(
    of: find.byType(WallpaperPositionPickerPage),
    matching: find.byType(LiquidGlassSurface),
  );

  testWidgets('四颗按钮锁标准档液态玻璃：场景选柔光也不参与', (tester) async {
    await pumpPicker(tester);

    final picker = find.byType(WallpaperPositionPickerPage);
    expect(picker, findsOneWidget);

    final surfaces = pickerSurfaces();
    expect(surfaces, findsNWidgets(4));
    for (final element in surfaces.evaluate()) {
      expect(
        (element.widget as LiquidGlassSurface).role,
        LiquidGlassRole.pinnedChrome,
        reason: '必须与设置页左上角返回键同档 —— 全局档位 / 模糊开关 / 滑杆都不参与',
      );
    }
    expect(
      find.descendant(of: picker, matching: find.byType(SoftGlassSurface)),
      findsNothing,
      reason: '全局选了柔光也不该把这几颗按钮分派成柔光面',
    );
  });

  testWidgets('转场帧里一帧都不画活玻璃：落定前磨砂顶着，落定后才上玻璃', (tester) async {
    // 真机口径（2026-09-21）：「按钮好像被分成了两层，玻璃那层跑到了右边，原位置
    // 剩下了一个透明按钮」，而且**不动它就一直在**。
    //
    // 成因（见页面 `_routeSettled` 的注释）：折射层的形状按**屏幕绝对坐标**算，
    // 本页进场走共享轴侧滑（页面从右边滑进来），转场帧里算出来的坐标带着中途的
    // 位移；那一帧画过的结果会被烤进缓存，落定后没有新的重绘（本页只有一次亮度
    // 采样会重建，且它通常落在转场途中）⇒ 玻璃永久偏在右侧，原位只剩按钮自己的
    // 衬底与文字 = "透明按钮"。
    //
    // 这条用例先把"转场中"那一帧钉住：一颗活玻璃都不许有，但四个位置都要有材质面
    // 顶着（留空就是用户看到的"透明按钮"）。
    await pumpPicker(tester, settle: false);

    final picker = find.byType(WallpaperPositionPickerPage);
    expect(picker, findsOneWidget);
    expect(
      pickerSurfaces(),
      findsNothing,
      reason: '转场还没落定，活玻璃一帧都不许画 —— 画了就会被烤到转场坐标上',
    );
    expect(
      find.descendant(
        of: picker,
        matching: find.byType(FrostedHeaderBackground),
      ),
      findsNWidgets(4),
      reason: '四个位置都要有材质面顶着，否则就是"原位置剩下一个透明按钮"',
    );

    // 把转场走完：落定后才放行活玻璃，而且四颗都必须是锁档的。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(pickerSurfaces(), findsNWidgets(4));
    for (final element in pickerSurfaces().evaluate()) {
      expect(
        (element.widget as LiquidGlassSurface).role,
        LiquidGlassRole.pinnedChrome,
      );
    }
  });

  testWidgets('按钮层与捕获子树平级，且钉在本页采样源上', (tester) async {
    await pumpPicker(tester);

    final picker = find.byType(WallpaperPositionPickerPage);
    final captureHost = find.descendant(
      of: picker,
      matching: find.byType(HyperosGlassBackdropHost),
    );
    expect(
      captureHost,
      findsOneWidget,
      reason: '本页必须有自己的屏级采样源：它注册进注册表，弹在本页之上的 modal 才采得到本页画面',
    );
    expect(
      find.descendant(of: captureHost, matching: find.byType(LiquidGlassSurface)),
      findsNothing,
      reason: '玻璃不能在捕获子树里，否则会采到自己上一帧的合成结果',
    );

    final active = HyperosGlassBackdropRegistry.active;
    expect(active, isNotNull);
    final elements = pickerSurfaces().evaluate();
    for (var i = 0; i < elements.length; i++) {
      final scope = HyperosGlassBackdropScope.maybeOf(elements.elementAt(i));
      expect(scope, isNotNull, reason: '按钮 $i 没有本页作用域');
      expect(
        identical(scope!.controller, active),
        isTrue,
        reason: '按钮 $i 绑到了别的屏的采样源',
      );
    }
  });

  testWidgets('底部「重置 / 换壁纸」都是内容宽胶囊，不会被撑成整屏宽', (tester) async {
    await pumpPicker(tester);

    final screenWidth = screenSize.width / screenDpr;
    final widths = [
      for (final e in pickerSurfaces().evaluate())
        (e.renderObject! as RenderBox).size.width,
    ];
    expect(widths, hasLength(4));

    // 前两个是顶部「退出 / 完成」（在 Row 里，无界约束，本来就是内容宽）。
    expect(widths[0], lessThan(screenWidth / 4));
    expect(widths[1], lessThan(screenWidth / 4));

    // 后两个是底部「重置 / 换壁纸」：「换壁纸」`minWidth: 120` + 文字宽 → 约 120。
    // 回归现象：这里会是整屏宽（约 400），字浮在一条横贯全屏的灰长条中间。
    expect(
      widths[2],
      lessThan(screenWidth / 2),
      reason: '底部「重置」被撑满了',
    );
    expect(
      widths[3],
      lessThan(screenWidth / 2),
      reason: '底部按钮被撑满了：Container 带 alignment 时会占满有界约束',
    );
    expect(widths[3], greaterThanOrEqualTo(120));
  });

  testWidgets('首帧极性直接用启动预热好的亮度带（不再按主题猜，也就不会闪）', (tester) async {
    // 暗顶壁纸：正确极性是"白字 + 深衬底"。按主题猜（浅色主题）会先给"深字 + 浅衬底"，
    // 等异步采样落地再翻过来 —— 真机反馈的"进 / 出页面闪一下"就是那一翻（见
    // SoftGlassPolarityFade）。首页首帧早就在用启动预热的亮度带消这个闪变，这一页现在
    // 接上同一条口径。
    HomeStartupVisualPrimer.debugSeedBands(
      wallpaperPath,
      (top: 0.2, weekday: 0.2, body: 0.2),
    );
    addTearDown(
      () => HomeStartupVisualPrimer.debugSeedBands(
        '',
        (top: 0, weekday: 0, body: 0),
      ),
    );

    await pumpPicker(tester);

    for (final label in ['退出', '完成', '重置', '换壁纸']) {
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        homePageChromeForegroundOnDark,
        reason: '「$label」首帧就该是暗顶壁纸的墨色（而不是主题猜出来的深色）',
      );
    }
  });
}
