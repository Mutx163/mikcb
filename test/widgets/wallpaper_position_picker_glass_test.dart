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
/// 强制同材质」。所以本文件的场景刻意选**液态档**（`glassMode: liquidGlass`）：四颗
/// 按钮必须无视它，一颗磨砂面都不许出现。
///
/// 历史上这一页踩过的两个坑，仍由本文件守着：
///
/// 1. **没有本屏采样源**：`HyperosGlassBackdropHost` 注册进
///    `HyperosGlassBackdropRegistry`，弹在本页之上的 modal（sheet / dialog）才能
///    取到**本页**画面；缺了它，注册表会回落到压在下面的设置页（已被视差左移、
///    且被盖住后连 paint 都停了）。
/// 2. **玻璃误入捕获子树**：上游要求玻璃必须在捕获子树之外（防反馈采样），所以按钮层
///    与 `HyperosGlassBackdropHost` 平级。
/// 3. **转场期间玻璃要逐帧重算坐标**（真机 2026-09-21 两轮：「按钮被分成两层、玻璃跑到
///    右边、原位剩一个透明按钮」→「进入退出的时候，按钮一直在变材质」）：折射层按屏幕
///    绝对坐标摆形状，而转场外壳把整页包进了重绘边界（滑入时整页像素复用）⇒ 不逐帧重画
///    就会把形状钉在旧坐标上。修法是 `LiquidGlassTransitionRepaint`（**照旧画、每帧重
///    算**），不是"转场期间先不画"—— 后者本仓 2026-09-20 就给首页玻璃带否过。
///
/// 另外底部按钮曾被 `Center` 的 maxWidth 撑满：`Container` 带 `alignment` 时在
/// 有界约束下会占满可用宽度，`minWidth` 只管下限。
void main() {
  const screenSize = Size(1280, 2772);
  const screenDpr = 3.2;

  // 刻意选磨砂档：四颗按钮锁标准档液态玻璃，这个档位不该影响它们一分一毫。
  const appearance = FrostedAppearance(
    sheetBlurSigma: 20,
    sheetTintAlpha: 0.5,
    sheetBarrierAlpha: 0.3,
    glassMode: FrostedGlassMode.gaussian,
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
                      const StableFrostedSurface(
                        cornerRadius: 16,
                        child: SizedBox(width: 200, height: 40),
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

  testWidgets('四颗按钮锁标准档液态玻璃：场景选磨砂也不参与', (tester) async {
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
      find.descendant(of: picker, matching: find.byType(StableFrostedSurface)),
      findsNothing,
      reason: '全局选了磨砂也不该把这几颗按钮分派成磨砂面',
    );
  });

  testWidgets('整段转场里按钮材质一帧都不变，且玻璃由转场重绘驱动逐帧重算', (tester) async {
    // 真机口径（2026-09-21）分两轮：
    //   1.「按钮好像被分成了两层，玻璃那层跑到了右边，原位置剩下了一个透明按钮」，
    //      而且**不动它就一直在** —— 成因是折射层按屏幕绝对坐标摆形状，而本页进场
    //      走共享轴侧滑：转场外壳把整页包进了重绘边界（滑入时整页像素复用），不逐帧
    //      重画就会把形状钉在旧坐标上，玻璃整块偏在一侧；
    //   2. 照"转场期间先不画、落定后再画"改完之后，用户立刻报「进入退出的时候，
    //      按钮一直在变材质」—— 那条本仓 2026-09-20 就给首页玻璃带否过（不要进场时
    //      的任何闪动），见 `LiquidGlassTransitionRepaint` 的类注释。
    //
    // 所以正确口径是：**照旧画，但每帧按当前位置重算**。这条用例把两件事一起钉住 ——
    // 材质一路不变（每一步都仍是四颗锁档液态玻璃），以及驱动节点确实罩着这四颗。
    //
    // 驱动节点**数几个**不钉：本仓后来让 `LiquidGlassSurface` 自己默认套一层
    // [LiquidGlassTransitionRepaint]（见其 `build`），于是本页从「外层一个、四颗
    // 按钮都挂在它下面」变成「四颗各带一个」。本页原来额外套的那层因此撤掉了 ——
    // 它与每颗玻璃自带的那层重复。该钉的口径是「四颗玻璃各自都被驱动罩着」，
    // 数量随页面玻璃数走，不该跟着变。
    await pumpPicker(tester, settle: false);

    final picker = find.byType(WallpaperPositionPickerPage);
    expect(picker, findsOneWidget);
    final driver = find.descendant(
      of: picker,
      matching: find.byType(LiquidGlassTransitionRepaint),
    );
    expect(
      driver,
      findsNWidgets(4),
      reason: '四颗按钮玻璃各自都要有转场重绘驱动：形状按屏幕坐标算，不逐帧重画就会偏在一侧',
    );

    // 转场途中每一步采样：材质必须一帧都不变（不许磨砂 ↔ 玻璃来回切）。
    for (var step = 0; step < 6; step++) {
      expect(
        pickerSurfaces(),
        findsNWidgets(4),
        reason: '转场第 $step 步的材质与前后不一致 —— 用户会读成"按钮一直在变材质"',
      );
      await tester.pump(const Duration(milliseconds: 30));
    }

    // 四颗玻璃各自都要带一层驱动节点（玻璃是父、驱动是子 ——
    // `LiquidGlassSurface.build` 返回的就是「驱动包着自己的绘制内容」）。
    // 罩错层 = 重画的不是它们，转场期间形状会停在旧坐标。
    for (final element in pickerSurfaces().evaluate()) {
      expect(
        find.descendant(
          of: find.byElementPredicate((candidate) => candidate == element),
          matching: find.byType(LiquidGlassTransitionRepaint),
        ),
        findsOneWidget,
        reason: '有一颗玻璃自己没带驱动节点，转场期间它不会按新坐标重算',
      );
    }

    // 走完转场：材质依旧不变，四颗都还是锁档液态玻璃。
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
