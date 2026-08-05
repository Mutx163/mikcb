// 深色主题 + 首页壁纸回归测试。
//
// 历史缺陷：hasHomePageBackdropImage 等在 isDark 时返回 false，深色模式
// 下整张壁纸被隐藏、信息栏露出 1px 亮线（forui 浅灰边框叠在深色底上），
// 整页内容观感异常。修复后壁纸在两种主题下都显示，墨水/玻璃 scrim 按
// 壁纸亮度自适应——这里锁死该行为。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/utils/home_page_background.dart';

import '../helpers_test_app.dart';

/// Scope bits: timetable(1) | weekdayBar(2) | header(4) | statusBar(8).
const _scopeAll = 1 | 2 | 4 | 8;

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

/// Generates a [width]x[height] PNG. [topLightFraction] rows of the top are
/// white, the rest black — a dark wallpaper when 0.0, a light one when 1.0.
/// [fillColor] overrides both for a fully uniform wallpaper (used by the
/// seam test so the wallpaper itself never contributes a brightness step).
Future<File> _writeWallpaper(
  Directory dir, {
  int width = 100,
  int height = 100,
  double topLightFraction = 0.0,
  Color fillColor = const Color(0xFF000000),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1000000, 1000000),
    Paint()..color = fillColor,
  );
  if (fillColor == const Color(0xFF000000)) {
    final lightRows = (height * topLightFraction).round();
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), lightRows.toDouble()),
      Paint()..color = Colors.white,
    );
  }
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

/// Pumps the home timetable in **dark** theme over a real wallpaper file.
Future<void> _pumpDarkHome(
  WidgetTester tester,
  TimetableProvider provider,
  String wallpaperPath, {
  bool headerBlur = false,
  bool weekdayBlur = false,
}) async {
  await tester.runAsync(() async {
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homePageWallpaperPath: wallpaperPath,
        homePageBackgroundScope: _scopeAll,
        homePageHeaderBlurEnabled: headerBlur,
        homePageWeekdayBarBlurEnabled: weekdayBlur,
        semesterStartDate: DateTime(2026, 7, 27),
      ),
    );
  });
  await tester.binding.setSurfaceSize(const Size(400, 800));
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.dark,
        home: RepaintBoundary(
          key: const ValueKey('dark-home-shot'),
          child: TimetableScreen(
            enableUpdateCheck: false,
            enableProgressTimer: false,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await _settleAsyncChain(tester);
}

/// Asserts no 1px bright seam row crosses the weekday-chrome band.
///
/// The old dark-mode bug painted the weekday bar's light-gray bottom border
/// over the dark surface as a full-width bright line. With the wallpaper
/// showing, the bar's bottom border is hidden — so in the band region every
/// row must either be non-uniform (text / icons) or equal to its neighbours
/// (continuous wallpaper). A uniform row that differs from both neighbours is
/// exactly the hairline seam we are guarding against.
Future<void> _expectNoBrightSeamRow(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('dark-home-shot')),
  );
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: 1.0),
  );
  final byteData = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  image!.dispose();
  final width = image.width;
  final height = image.height;
  final buffer = byteData!.buffer.asUint8List();

  double luminanceAt(int y) {
    final off = y * width * 4;
    var total = 0.0;
    var count = 0;
    for (var x = 0; x < width; x++) {
      final r = buffer[off + x * 4] / 255.0;
      final g = buffer[off + x * 4 + 1] / 255.0;
      final b = buffer[off + x * 4 + 2] / 255.0;
      total += 0.2126 * r + 0.7152 * g + 0.0722 * b;
      count++;
    }
    return count == 0 ? 0 : total / count;
  }

  double spreadAt(int y) {
    final off = y * width * 4;
    var minLum = 1.0;
    var maxLum = 0.0;
    for (var x = 0; x < width; x++) {
      final r = buffer[off + x * 4] / 255.0;
      final g = buffer[off + x * 4 + 1] / 255.0;
      final b = buffer[off + x * 4 + 2] / 255.0;
      final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (lum < minLum) {
        minLum = lum;
      }
      if (lum > maxLum) {
        maxLum = lum;
      }
    }
    return maxLum - minLum;
  }

  // The band region between the app header and the course grid. Exact chrome
  // heights vary, so scan generously; text rows have high spread and are
  // skipped by the uniformity guard.
  for (var y = 30; y < 200 && y < height; y++) {
    final lum = luminanceAt(y);
    final prev = luminanceAt(y - 1);
    final next = luminanceAt(y + 1);
    final isSeam =
        spreadAt(y) < 0.05 &&
        (lum - prev).abs() > 0.12 &&
        (lum - next).abs() > 0.12;
    expect(
      isSeam,
      isFalse,
      reason: 'unexpected bright seam row at y=$y (lum=$lum, '
          'prev=$prev, next=$next) in dark home render',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    StorageService().resetForTesting();
  });

  testWidgets(
    'dark theme + dark wallpaper: wallpaper layer paints and chrome ink '
    'flips white',
    (tester) async {
      _seedInitializedPrefs();
      final dir = Directory.systemTemp.createTempSync('mikcb_dark_');
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignored
        }
      });
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(dir, topLightFraction: 0.0),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpDarkHome(tester, provider, wallpaper!.path);

      // The wallpaper itself must still be on screen in dark mode.
      // The backdrop Image carries `ValueKey<String?>` (the settings path is
      // nullable), so the finder must use the same generic type to match.
      expect(
        find.byKey(ValueKey<String?>(wallpaper.path)),
        findsWidgets,
        reason: 'wallpaper layer must paint in dark theme',
      );
      // Dark wallpaper → light chrome ink everywhere, like light mode.
      expect(_textColor(tester, '轻屿课表'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '1周'), homePageChromeForegroundOnDark);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'dark theme + light wallpaper: chrome ink flips dark over the photo',
    (tester) async {
      _seedInitializedPrefs();
      final dir = Directory.systemTemp.createTempSync('mikcb_dark_');
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignored
        }
      });
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(dir, topLightFraction: 1.0),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpDarkHome(tester, provider, wallpaper!.path);

      // Light band → the default dark-mode ink (white) must NOT stay: the
      // wallpaper luminance flips it to dark so text never reads white-on-
      // white under a dark theme.
      expect(_textColor(tester, '轻屿课表'), homePageChromeForegroundOnLight);
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnLight);
      expect(_textColor(tester, '1周'), homePageChromeForegroundOnLight);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'dark theme + wallpaper: no bright hairline under the weekday bar',
    (tester) async {
      _seedInitializedPrefs();
      final dir = Directory.systemTemp.createTempSync('mikcb_dark_');
      addTearDown(() {
        PaintingBinding.instance.imageCache.clear();
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignored
        }
      });
      // A fully uniform mid-tone wallpaper: no brightness step inside the
      // photo itself, so the only possible "line" is a UI hairline (the old
      // dark-mode bug painted the weekday bar's bottom border as a bright
      // full-width row over the dark surface).
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(
          dir,
          fillColor: const Color(0xFF808080),
        ),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpDarkHome(tester, provider, wallpaper!.path);

      await _expectNoBrightSeamRow(tester);
      await tester.binding.setSurfaceSize(null);
    },
  );
}
