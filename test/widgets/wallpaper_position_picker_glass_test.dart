import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/utils/home_startup_visual_primer.dart';
import 'package:university_timetable/widgets/wallpaper_position_picker_sheet.dart';

/// 壁纸位置选择页（「调整壁纸显示位置」）的悬浮按钮材质 / 几何守护。
///
/// 这一页是**裸 `Scaffold`**（不是 `HyperosPage`），历史上漏了两件事，真机现象
/// 是「底部换壁纸按钮变成横贯整屏的长条，且左半边灰、右半边透出壁纸」：
///
/// 1. **没有本屏采样源**：柔光玻璃（`SoftGlassSurface` → 上游 `MiuixGlass`，
///    `shading: false`）把采样源给的窄带快照按 `origin` 贴进自己的形状，快照
///    盖不到的地方 alpha=0 → 直接透出壁纸。缺宿主时
///    `HyperosGlassBackdropRegistry.resolve` 回落到「栈顶那一屏」= 压在下面的
///    设置页（已被视差左移、且被盖住后不再 paint），于是采到的是别屏画面。
/// 2. **玻璃误入捕获子树**：上游要求玻璃必须在捕获子树之外（防反馈采样），
///    所以按钮层必须与 `HyperosGlassBackdropHost` 平级、并显式用
///    `HyperosGlassBackdropScope` 钉在本页采样源上（同 `timetable_screen.dart`
///    里常驻玻璃球的做法）。
///
/// 另外底部按钮曾被 `Center` 的 maxWidth 撑满：`Container` 带 `alignment` 时在
/// 有界约束下会占满可用宽度，`minWidth` 只管下限。
void main() {
  const screenSize = Size(1280, 2772);
  const screenDpr = 3.2;

  // 依赖「液态玻璃作用范围 → 壁纸选点按钮」的默认开启值（柔光与液态共用这一档）。
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
  }) async {
    tester.view.physicalSize = screenSize;
    tester.view.devicePixelRatio = screenDpr;
    addTearDown(tester.view.reset);

    // 外观作用域必须在 Navigator **之上**：路由里的页面读的是同一个 scope，
    // 否则按钮根本走不到柔光分支（会退化成高斯磨砂）。
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
          // 造一条「自带宿主的被盖住页」：修复前选择页的玻璃就会绑到它身上。
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
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  testWidgets('三个悬浮按钮的材质层不在捕获子树内，且钉在本页采样源上', (tester) async {
    await pumpPicker(tester);

    final picker = find.byType(WallpaperPositionPickerPage);
    expect(picker, findsOneWidget);

    final surfaces = find.descendant(
      of: picker,
      matching: find.byType(SoftGlassSurface),
    );
    expect(surfaces, findsNWidgets(3));

    final captureHost = find.descendant(
      of: picker,
      matching: find.byType(HyperosGlassBackdropHost),
    );
    expect(captureHost, findsOneWidget, reason: '本页必须有自己的屏级采样源宿主');
    expect(
      find.descendant(of: captureHost, matching: find.byType(SoftGlassSurface)),
      findsNothing,
      reason: '玻璃不能在捕获子树里，否则会采到自己上一帧的合成结果',
    );

    // 三个按钮都必须显式绑在本页宿主上。缺这一条时（真机 bug）玻璃按注册表取
    // 「栈顶那一屏」——此处栈顶就是被盖住的首页，采到的是别的屏。
    final active = HyperosGlassBackdropRegistry.active;
    expect(active, isNotNull);
    final elements = surfaces.evaluate();
    for (var i = 0; i < 3; i++) {
      final scope = HyperosGlassBackdropScope.maybeOf(elements.elementAt(i));
      expect(scope, isNotNull, reason: '按钮 $i 没有本页作用域');
      expect(
        identical(scope!.controller, active),
        isTrue,
        reason: '按钮 $i 绑到了别的屏的采样源',
      );
    }
  });

  testWidgets('底部换壁纸按钮是内容宽胶囊，不会被 Center 撑成整屏宽', (tester) async {
    await pumpPicker(tester);

    final screenWidth = screenSize.width / screenDpr;
    final widths = [
      for (final e in find
          .descendant(
            of: find.byType(WallpaperPositionPickerPage),
            matching: find.byType(SoftGlassSurface),
          )
          .evaluate())
        (e.renderObject! as RenderBox).size.width,
    ];
    expect(widths, hasLength(3));

    // 前两个是顶部「退出 / 完成」（在 Row 里，无界约束，本来就是内容宽）。
    expect(widths[0], lessThan(screenWidth / 4));
    expect(widths[1], lessThan(screenWidth / 4));

    // 第三个是底部「换壁纸」：`minWidth: 120` + 文字宽 → 约 120。
    // 回归现象：这里会是整屏宽（约 400），字浮在一条横贯全屏的灰长条中间。
    expect(
      widths[2],
      lessThan(screenWidth / 2),
      reason: '底部按钮被撑满了：Container 带 alignment 时会占满有界约束',
    );
    expect(widths[2], greaterThanOrEqualTo(120));
  });

  testWidgets('首帧极性直接用启动预热好的亮度带（不再按主题猜，也就不会闪）', (tester) async {
    // 暗顶壁纸：正确极性是"白字 + 深衬底"。按主题猜（浅色主题）会先给"深字 +
    // 浅衬底"，等异步采样落地再翻过来 —— 真机反馈的"进 / 出页面闪一下"就是那一翻
    // （见 SoftGlassPolarityFade）。首页首帧早就在用启动预热的亮度带消这个闪变，
    // 这一页现在接上同一条口径。
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

    for (final label in ['退出', '完成', '换壁纸']) {
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        homePageChromeForegroundOnDark,
        reason: '「$label」首帧就该是暗顶壁纸的墨色（而不是主题猜出来的深色）',
      );
    }
  });
}
