import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';
import 'package:university_timetable/utils/hex_color.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/home_page_region_blur.dart';

import '../helpers_test_app.dart';

/// Scope bits: timetable(1) | weekdayBar(2) | header(4) | statusBar(8).
const _scopeAll = 1 | 2 | 4 | 8;

/// 开学锚固定取「下周一」：开学前对齐第 1 周（2026-08-31 周次口径），无论
/// 测试在哪天跑，周次芯片恒为「1周」、周一列永远不会命中「今天」的
/// accent 高亮，壁纸墨水断言与运行日期彻底解耦（旧硬编码 2026-07-27 在
/// 日历周对齐合入后，跨过第 1 周的任何一天都会让「1周」消失）。
DateTime _nextWeekMonday() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final currentMonday = today.subtract(Duration(days: today.weekday - 1));
  return currentMonday.add(const Duration(days: 7));
}

String _mmdd(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// 课表 + 状态栏 only — 顶栏/信息栏 display toggles turned off.
const _scopeNoChromeBars = 1 | 8;

void _seedInitializedPrefs() {
  final now = DateTime(2026, 4, 12);
  final settings = TimetableSettings.defaults();
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: settings,
    currentWeek: 1,
    createdAt: now,
    lastUsedAt: now,
  );
  SharedPreferences.setMockInitialValues({
    'did_migrate_app_logs_default': true,
    'did_migrate_live_hide_prefix_default': true,
    'timetable_profiles': jsonEncode([profile.toJson()]),
    'active_timetable_profile_id': profile.id,
    'time_schemes': '[]',
  });
}

/// Generates a [width]x[height] PNG: top [topLightFraction] rows white,
/// the rest black — a wallpaper whose top strip reads light and the band
/// below (weekday-bar region) reads dark.
Future<File> _writeWallpaper(
  Directory dir, {
  // Match Flutter's default 800×600 widget-test viewport so BoxFit.cover does
  // not crop away the synthetic top strip used by the chrome assertions.
  int width = 400,
  int height = 300,
  double topLightFraction = 0.12,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1000000, 1000000),
    Paint()..color = Colors.black,
  );
  final lightRows = (height * topLightFraction).round();
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), lightRows.toDouble()),
    Paint()..color = Colors.white,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final file = File('${dir.path}/wallpaper.png');
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  return file;
}

/// Alternates real-async time with fake pumps so multi-hop async chains
/// (file I/O → codec → pixel read → setState) all complete in widget tests.
Future<void> _settleAsyncChain(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
}

Color? _textColor(WidgetTester tester, String text) {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Text>(finder.first).style?.color;
}

Future<void> _pumpHome(
  WidgetTester tester,
  TimetableProvider provider,
  String? wallpaperPath,
  int scope, {
  bool headerBlur = false,
  bool weekdayBlur = false,
  String? weekdayHex,
  String? bandMaterial,
  String? pageBgHex,
  bool wrapFrostedScope = false,
}) async {
  await tester.runAsync(() async {
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homePageWallpaperPath: wallpaperPath,
        homePageBackgroundScope: scope,
        homePageHeaderBlurEnabled: headerBlur,
        homePageWeekdayBarBlurEnabled: weekdayBlur,
        weekdayBarFontColorLight: weekdayHex,
        homeBandGlassMaterial: bandMaterial,
        timetablePageBackgroundColor: pageBgHex,
        semesterStartDate: _nextWeekMonday(),
      ),
    );
  });
  const app = TestApp(
    home: TimetableScreen(
      enableUpdateCheck: false,
      enableProgressTimer: false,
    ),
  );
  // 顶栏玻璃带的**材质**是从 `FrostedAppearanceScope` 读的（app 根部按设置下发，
  // 见 `main.dart`），不是从 TimetableSettings 直接读 —— 只有要验材质分支的用例
  // 才需要把这层补上（其余用例沿用「无 scope ⇒ 出厂液态档」的既有前提）。
  final Widget root = ChangeNotifierProvider.value(value: provider, child: app);
  await tester.pumpWidget(
    wrapFrostedScope
        ? FrostedAppearanceScope(
            appearance: provider.settings.frostedAppearance,
            child: root,
          )
        : root,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await _settleAsyncChain(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
  });

  testWidgets('dark wallpaper + all regions + no blur: chrome ink flips white '
      'everywhere (unchanged behaviour)', (tester) async {
    _seedInitializedPrefs();
    final dir = Directory.systemTemp.createTempSync('mikcb_ink_');
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // ignored
      }
    });
    final wallpaper = await tester.runAsync(
      () => _writeWallpaper(dir, topLightFraction: 0),
    );
    final provider = await createInitializedTestProvider(tester);
    await _pumpHome(tester, provider, wallpaper!.path, _scopeAll);

    expect(_textColor(tester, '轻屿课表'), homePageChromeForegroundOnDark);
    expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
    expect(_textColor(tester, '1 周'), homePageChromeForegroundOnDark);
    expect(
      _textColor(tester, _mmdd(_nextWeekMonday())),
      homePageChromeForegroundOnDark.withValues(alpha: 0.72),
    );
  });

  testWidgets(
    'light strip only at the very top: weekday bar flips white by its own '
    'band while the logo stays dark on the strip',
    (tester) async {
      _seedInitializedPrefs();
      final dir = Directory.systemTemp.createTempSync('mikcb_ink_');
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignored
        }
      });
      // Top 12% light (sky), rest dark (ground): the old top-band sample
      // (0–22%) read 12/22 ≈ 0.55 → black ink everywhere → black weekday
      // text over the dark ground. The weekday band (7–20%) reads dark, so
      // the weekday chrome must flip white while the logo keeps dark ink on
      // the light strip.
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(dir),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpHome(tester, provider, wallpaper!.path, _scopeAll);

      expect(_textColor(tester, '轻屿课表'), homePageChromeForegroundOnLight);
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '1 周'), homePageChromeForegroundOnDark);
      expect(
        _textColor(tester, _mmdd(_nextWeekMonday())),
        homePageChromeForegroundOnDark.withValues(alpha: 0.72),
      );
    },
  );

  testWidgets('weekday blur uses the top band for ink and contrast warnings', (
    tester,
  ) async {
    _seedInitializedPrefs();
    final dir = Directory.systemTemp.createTempSync('mikcb_ink_');
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // ignored
      }
    });
    // Keep the top/header strip white and the weekday band below it black.
    // With weekday blur enabled, the glass scrim follows the top sample, so
    // custom white weekday ink must flip to dark ink and explain the change.
    // The old warning path sampled the weekday band instead and missed it.
    final wallpaper = await tester.runAsync(
      () => _writeWallpaper(dir, topLightFraction: 0.09),
    );
    final provider = await createInitializedTestProvider(tester);
    await _pumpHome(
      tester,
      provider,
      wallpaper!.path,
      _scopeAll,
      weekdayBlur: true,
      weekdayHex: '#FFFFFF',
    );

    expect(find.text('文字对比度不足'), findsOneWidget);
    expect(find.textContaining('浅色壁纸'), findsOneWidget);
    expect(_textColor(tester, '周一'), homePageChromeForegroundOnLight);
    expect(_textColor(tester, '1 周'), homePageChromeForegroundOnLight);
    expect(
      _textColor(tester, _mmdd(_nextWeekMonday())),
      homePageChromeForegroundOnLight.withValues(alpha: 0.70),
    );
  });

  testWidgets('header/weekday scope off: chrome ink follows the opaque page '
      'background, not the wallpaper', (tester) async {
    _seedInitializedPrefs();
    final dir = Directory.systemTemp.createTempSync('mikcb_ink_');
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // ignored
      }
    });
    // Dark wallpaper + 顶栏/信息栏 scope toggles off: those bands paint the
    // opaque light page background, so the logo must fall back to the theme
    // foreground (dark) instead of flipping white over the wallpaper.
    final wallpaper = await tester.runAsync(
      () => _writeWallpaper(dir, topLightFraction: 0),
    );
    final provider = await createInitializedTestProvider(tester);
    await _pumpHome(tester, provider, wallpaper!.path, _scopeNoChromeBars);

    final logo = _textColor(tester, '轻屿课表');
    expect(logo, isNotNull);
    expect(logo!.computeLuminance(), lessThan(0.3));
    // Default weekday ink on the opaque background: the configured default
    // black, not the wallpaper-flipped white.
    expect(_textColor(tester, '周一'), const Color(0xFF000000));
    expect(_textColor(tester, '1 周'), const Color(0xFF000000));
  });

  testWidgets('实体顶栏：带子照画、星期栏压在实底上，日期照旧不翻白', (
    tester,
  ) async {
    _seedInitializedPrefs();
    final dir = Directory.systemTemp.createTempSync('mikcb_solid_band_');
    addTearDown(() {
      PaintingBinding.instance.imageCache.clear();
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // ignored
      }
    });
    // 全黑壁纸 + 顶栏材质选「实体」+ 自定义页面底色。真机 2026-09-30 报的就是
    // 这一格：标题行因为另有兜底看着实心，星期栏却把底色让给了那条**根本没挂上**
    // 的带子，于是直接透出壁纸（截图里那层颗粒）。三条断言分别钉住根因与两个
    // 连带项：带子必须挂、实底颜色与标题行同源、墨色不再按壁纸翻黑白。
    final wallpaper = await tester.runAsync(
      () => _writeWallpaper(dir, topLightFraction: 0),
    );
    // 页面背景色只认 6 位 hex（`tryParseHexColor` 拒 8 位），所以用深蓝这一档，
    // 与黑壁纸差得开。
    const pageBg = '#102030';
    final provider = await createInitializedTestProvider(tester);
    await _pumpHome(
      tester,
      provider,
      wallpaper!.path,
      _scopeAll,
      headerBlur: true,
      weekdayBlur: true,
      bandMaterial: 'solid',
      pageBgHex: pageBg,
      wrapFrostedScope: true,
    );

    // ① 带子必须挂上（此前实体档整条不挂 ⇒ `HomePageChromeGlassFill` 查不到）。
    final bandFill = find.byType(HomePageChromeGlassFill);
    expect(bandFill, findsOneWidget);
    // ② 实底颜色 = 页面底色（与标题行那份 `resolveHomePageHeaderBackground` 同源；
    // 退回主题底色的话，用户自定义过页面背景色时两段之间会差出一条色带）。
    final solid = tester.widget<ColoredBox>(
      find.descendant(of: bandFill, matching: find.byType(ColoredBox)),
    );
    expect(solid.color, parseHexColorOrFallback(pageBg, fallback: Colors.white));
    expect(solid.color.a, 1, reason: '实体档必须完全不透明，否则还是透出壁纸');

    // ③ 墨色：实体档下星期栏不在壁纸上 ⇒ 保持配置墨色（默认黑），不跟着黑壁纸翻白。
    expect(_textColor(tester, '周一'), const Color(0xFF000000));
    expect(_textColor(tester, '1 周'), const Color(0xFF000000));
    // 那条「文字对比度不足」提醒是拿壁纸亮度判的，实体档下不该弹。
    expect(find.text('文字对比度不足'), findsNothing);
  });

  testWidgets(
    'custom dark weekday ink over a dark wallpaper: auto-flips to white and '
    'explains itself once',
    (tester) async {
      _seedInitializedPrefs();
      final dir = Directory.systemTemp.createTempSync('mikcb_ink_');
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignored
        }
      });
      // A hand-picked dark grey (#3C3C3C ≈ 1.9:1 against the black band)
      // would render invisible over the dark wallpaper; the readability
      // fallback must flip it to auto white instead of showing the ugly
      // dark-on-dark the user complained about.
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(dir, topLightFraction: 0),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpHome(
        tester,
        provider,
        wallpaper!.path,
        _scopeAll,
        weekdayHex: '#3C3C3C',
      );

      // The one-shot explainer dialog is up: it tells the user the colour is
      // temporarily auto-flipped and offers resetting the default.
      expect(find.text('文字对比度不足'), findsOneWidget);
      expect(find.text('知道了'), findsOneWidget);
      expect(find.text('恢复默认'), findsOneWidget);

      // The weekday chrome renders the auto white ink, not the custom grey.
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '1 周'), homePageChromeForegroundOnDark);
      expect(
        _textColor(tester, _mmdd(_nextWeekMonday())),
        homePageChromeForegroundOnDark.withValues(alpha: 0.72),
      );

      await tester.tap(find.text('知道了'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('文字对比度不足'), findsNothing);
      // Still white after dismissing — the fallback is not tied to the dialog.
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
    },
  );
}
