// 日视图顶部摘要卡（日期 + 关闭叉）的**材质来源**回归钉。
//
// 用户口径（2026-09-22）：「日视图顶部的日期卡片，带叉叉的那个，也要跟日视图的课程
// 卡片是一样的材质，选什么就是什么，不要第二种」。
//
// 两层判据：
//  1. **口径**（`dayViewContentCardSurfaceStyle`，纯函数）：内容卡的材质只跟课程卡那
//     一档走，顶栏 / 信息栏选什么与它无关 —— 摘要卡过去的例外正是"顶栏是玻璃时改成
//     跟顶栏同款"。纯函数这一层不受测试环境限制，所以真正的钉子在这里；
//  2. **实现**（组件测试）：那张卡的表层必须是课程卡用的 `CourseSurface`，不能再是
//     自绘的亮磨砂替身。
//
// ⚠️ 组件测试里**验不到档位**：`HyperosBlurredHeader.liveBlurSupported` 只认
// Android/iOS（`dart:io Platform`，宿主机上恒 false），于是组件测试里任何玻璃档都
// 被 `effectiveCourseCardSurfaceStyle` 算成实体 —— "选液态就长液态"这一步只有真机能验。
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/utils/home_page_background.dart';
import 'package:university_timetable/widgets/course_surface.dart';

import '../helpers_test_app.dart';

/// 真壁纸文件：`hasHomePageBackdrop` 要求文件真的在（缺文件按无背景算），
/// 而玻璃档只有在"有壁纸 + 模糊管线可用"时才成立。
Future<File> _writeWallpaper() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1000000, 1000000),
    Paint()..color = const Color(0xFF223344),
  );
  final image = await recorder.endRecording().toImage(16, 16);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final dir = await Directory.systemTemp.createTemp('day_summary_material');
  return File('${dir.path}/wall.png')
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _seedPrefs(TimetableSettings settings) {
  final now = DateTime(2026, 4, 12);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channels = [
    'com.mutx163.qingyu/home_widget',
    'com.mutx163.qingyu/umeng_analytics',
    'com.mutx163.qingyu/miui_live',
  ];

  late File wallpaper;

  setUpAll(() async {
    wallpaper = await _writeWallpaper();
  });

  tearDownAll(() {
    try {
      wallpaper.parent.deleteSync(recursive: true);
    } on FileSystemException {
      // 图片可能还被解码器持有（Windows 上会短暂锁文件）；断言不依赖这次清理。
    }
  });

  setUp(() {
    StorageService().resetForTesting();
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (c) async => null);
    }
  });

  tearDown(() {
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  TimetableSettings settingsWith({
    required CourseCardSurfaceStyle cardStyle,
    required String bandMaterial,
  }) => TimetableSettings.defaults().copyWith(
    homePageWallpaperPath: wallpaper.path,
    courseCardSurfaceStyle: cardStyle,
    homeBandGlassMaterial: bandMaterial,
  );

  test('卡片档选什么就是什么：顶栏 / 信息栏材质不参与', () {
    // 摘要卡过去的例外：顶栏是玻璃时改成"跟顶栏同款"的亮磨砂替身。这条钉住
    // 它不许回来 —— 内容卡的材质只由课程卡那一档决定。
    for (final style in CourseCardSurfaceStyle.values) {
      for (final band in ['solid', 'liquid']) {
        expect(
          dayViewContentCardSurfaceStyle(
            settingsWith(cardStyle: style, bandMaterial: band),
            backdropBlurOn: true,
          ),
          style,
          reason: '卡片档 $style + 顶栏 $band：内容卡必须还是 $style',
        );
      }
    }
  });

  test('模糊管线不可用或没有壁纸时，一律回落实体（老口径不变）', () {
    final glassCard = settingsWith(
      cardStyle: CourseCardSurfaceStyle.liquidGlass,
      bandMaterial: 'liquid',
    );
    expect(
      dayViewContentCardSurfaceStyle(glassCard, backdropBlurOn: false),
      CourseCardSurfaceStyle.solid,
      reason: '模糊管线不可用 ⇒ 玻璃档没有可采样的磨砂来源',
    );
    expect(
      dayViewContentCardSurfaceStyle(
        TimetableSettings.defaults().copyWith(
          courseCardSurfaceStyle: CourseCardSurfaceStyle.liquidGlass,
        ),
        backdropBlurOn: true,
      ),
      CourseCardSurfaceStyle.solid,
      reason: '没有壁纸 ⇒ 同样回落实体（课程卡实心，日期卡不能还透）',
    );
  });

  testWidgets('摘要卡走课程卡那张表层（不再是自绘的亮磨砂替身）', (tester) async {
    _seedPrefs(
      settingsWith(
        cardStyle: CourseCardSurfaceStyle.liquidGlass,
        bandMaterial: 'liquid',
      ),
    );
    final provider = await createInitializedTestProvider(tester);
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

    final today = DateTime.now();
    await tester.tap(find.byKey(ValueKey('weekday-header-1-${today.weekday}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 摘要卡的 key 就钉在它自己那张表层上（`_dayAgendaSurface(key: ...)`），
    // 所以直接读这个 widget，不要用 descendant（那样取不到根）。
    final summary = find.byKey(const ValueKey('day-view-summary'));
    expect(summary, findsOneWidget);
    expect(
      tester.widget(summary),
      isA<CourseSurface>(),
      reason: '摘要卡必须是课程卡那种表层，不能是那条"顶栏同款"的亮磨砂替身',
    );
  });
}
