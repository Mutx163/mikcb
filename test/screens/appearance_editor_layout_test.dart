// 「外观编辑」页的**布局回归钉**（按真机视口渲染，量的是几何而不是文字）。
//
// 为什么要有这一份：用户真机反馈过两类「看起来不对」——
// ① 顶部右边那颗按钮「跟左边不齐」，② 底栏那排按钮「乱」。
// 量化之后发现坐标其实是对称的，真正的原因是**视觉重量不一致**（完成用了纯白实心、
// 取消是半透明深色）与**多余的竖杠隔断**；这两条已在实现里改掉，本文件把它们钉住，
// 免得以后有人再把两枚胶囊做成不同形。
//
// 视口取真机实测值：1280×2772 @520dpi → 393.8×852.9 逻辑像素；安全区按状态栏
// 104 物理像素、手势条 84 物理像素给（与截图一致）。
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/providers/weather_provider.dart';
import 'package:university_timetable/screens/timetable_screen.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

import '../helpers_test_app.dart';

const _viewport = Size(393.8, 852.9);

void _seedPrefs() {
  final now = DateTime(2026, 4, 12);
  final profile = TimetableProfile(
    id: 'profile-1',
    name: '默认课表',
    courses: const [],
    settings: TimetableSettings.defaults(),
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

  setUp(() {
    StorageService().resetForTesting();
    _seedPrefs();
    for (final channel in const [
      'com.mutx163.qingyu/home_widget',
      'com.mutx163.qingyu/umeng_analytics',
      'com.mutx163.qingyu/miui_live',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), (c) async => null);
    }
  });

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 2772);
    tester.view.devicePixelRatio = 3.25;
    // 状态栏 104 物理像素 = 32 逻辑像素；手势条 84 物理像素 ≈ 25.8 逻辑像素。
    tester.view.padding = const FakeViewPadding(top: 104, bottom: 84);
    addTearDown(tester.view.reset);

    final provider = await createInitializedTestProvider(tester);
    final page = settingsSubpageById('appearanceEditor')!;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TimetableProvider>.value(value: provider),
          ChangeNotifierProvider<WeatherProvider?>.value(value: null),
        ],
        child: TestApp(home: page),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('缩略卡：保持整屏比例、左右居中、完整落在上下 chrome 之间', (
    tester,
  ) async {
    await pumpEditor(tester);

    final card = tester.getRect(find.byType(TimetableScreen));
    // 等比：卡片宽高比 == 屏幕宽高比（所以是「原样缩小」而不是被拉扁/裁切）。
    expect(
      card.width / card.height,
      closeTo(_viewport.width / _viewport.height, 0.001),
      reason: '卡片必须与整屏同比（否则观感与首页不一致）',
    );
    // 左右留白相等。
    expect(card.left, closeTo(_viewport.width - card.right, 0.5));
    // 上下都在安全区加 chrome 的净空之内（不顶状态栏、不压手势条）。
    const topReserve = 32 + 16 + 40 + 12 + 36 + 18;
    const bottomReserve = 25.8 + 34 + 56 + 8 + 18;
    expect(card.top, greaterThanOrEqualTo(topReserve - 1));
    expect(card.bottom, lessThanOrEqualTo(_viewport.height - bottomReserve + 1));
  });

  testWidgets('顶部两枚胶囊：同高、同尺寸、离两边等距（不许视觉上错位）', (
    tester,
  ) async {
    await pumpEditor(tester);

    final cancel = tester.getRect(find.text('取消'));
    final done = tester.getRect(find.text('完成'));

    // 同一高度（同一行基线）。
    expect(cancel.top, closeTo(done.top, 0.5));
    expect(cancel.bottom, closeTo(done.bottom, 0.5));
    // 中心到各自屏幕边缘的距离相等。
    expect(
      cancel.center.dx,
      closeTo(_viewport.width - done.center.dx, 0.5),
      reason: '左右两枚必须对称，否则真机上看就是「右边那颗错位」',
    );
    // 标题在屏幕正中（不被任何一枚挤偏）。
    final title = tester.getRect(find.text('外观编辑'));
    expect(title.center.dx, closeTo(_viewport.width / 2, 1));
  });

  testWidgets('底部一排：两个入口等距、整组居中、名字在安全区之上', (tester) async {
    await pumpEditor(tester);

    final wallpaper = tester.getRect(find.text('调整壁纸'));
    final material = tester.getRect(find.text('材质'));
    final groupCenter = (wallpaper.center.dx + material.center.dx) / 2;

    expect(groupCenter, closeTo(_viewport.width / 2, 1));
    // 两个名字的中心间距要够开（等距留白 40 + 圆钮 56）。
    expect(material.center.dx - wallpaper.center.dx, closeTo(96, 1));
    // 名字整体在底部安全区之上（不被手势条压住）。
    expect(wallpaper.bottom, lessThan(_viewport.height - 25.8));
    expect(material.bottom, lessThan(_viewport.height - 25.8));
  });
}
