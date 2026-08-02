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
import 'package:university_timetable/utils/home_page_background.dart';

import '../helpers_test_app.dart';

/// Scope bits: timetable(1) | weekdayBar(2) | header(4) | statusBar(8).
const _scopeAll = 1 | 2 | 4 | 8;
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
  int width = 100,
  int height = 100,
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
}) async {
  await tester.runAsync(() async {
    await provider.updateTimetableSettings(
      provider.settings.copyWith(
        homePageWallpaperPath: wallpaperPath,
        homePageBackgroundScope: scope,
        homePageHeaderBlurEnabled: headerBlur,
        homePageWeekdayBarBlurEnabled: weekdayBlur,
        semesterStartDate: DateTime(2026, 7, 27),
      ),
    );
  });
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: const TestApp(
        home: TimetableScreen(
          enableUpdateCheck: false,
          enableProgressTimer: false,
        ),
      ),
    ),
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

  testWidgets(
    'dark wallpaper + all regions + no blur: chrome ink flips white '
    'everywhere (unchanged behaviour)',
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
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(dir, topLightFraction: 0.0),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpHome(tester, provider, wallpaper!.path, _scopeAll);

      expect(_textColor(tester, '轻屿课表'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '1周'), homePageChromeForegroundOnDark);
      expect(
        _textColor(tester, '07/27'),
        homePageChromeForegroundOnDark.withValues(alpha: 0.72),
      );
    },
  );

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
        () => _writeWallpaper(dir, topLightFraction: 0.12),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpHome(tester, provider, wallpaper!.path, _scopeAll);

      expect(_textColor(tester, '轻屿课表'), homePageChromeForegroundOnLight);
      expect(_textColor(tester, '周一'), homePageChromeForegroundOnDark);
      expect(_textColor(tester, '1周'), homePageChromeForegroundOnDark);
      expect(
        _textColor(tester, '07/27'),
        homePageChromeForegroundOnDark.withValues(alpha: 0.72),
      );
    },
  );

  testWidgets(
    'header/weekday scope off: chrome ink follows the opaque page '
    'background, not the wallpaper',
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
      // Dark wallpaper + 顶栏/信息栏 scope toggles off: those bands paint the
      // opaque light page background, so the logo must fall back to the theme
      // foreground (dark) instead of flipping white over the wallpaper.
      final wallpaper = await tester.runAsync(
        () => _writeWallpaper(dir, topLightFraction: 0.0),
      );
      final provider = await createInitializedTestProvider(tester);
      await _pumpHome(tester, provider, wallpaper!.path, _scopeNoChromeBars);

      final logo = _textColor(tester, '轻屿课表');
      expect(logo, isNotNull);
      expect(logo!.computeLuminance(), lessThan(0.3));
      // Default weekday ink on the opaque background: the configured default
      // black, not the wallpaper-flipped white.
      expect(_textColor(tester, '周一'), const Color(0xFF000000));
      expect(_textColor(tester, '1周'), const Color(0xFF000000));
    },
  );
}
