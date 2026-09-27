// 「最近使用」长按删除 + 「壁纸文件已丢失」提示（2026-09-27）。
//
// 这两条都挂在 `_HomeBackdropFlow` 上，而那个 mixin 同时服务两个宿主（「课表
// 页面」设置里的壁纸行、「外观编辑」页底部那颗「调整壁纸」的弹窗）。这里从
// **课表页面**那条进去：那一处是内联的，不经过底部弹层，测试最不容易被弹层
// 动画 / 覆盖层顺序带偏；两个宿主共用同一套 builder 与同一个 mixin，行为一致。
//
// 钉的是三件容易悄悄退化的事：
// ① 提示条只在「路径还在、文件没了」时出现，且给出重新选图的出口；
// ② 长按删掉的是**历史条目**，不是当前壁纸 —— 正在用的那张必须被挡住；
// ③ 删除会连带删文件，但留 2.5s 反悔窗口，撤销期间文件不许没。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_profile.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/wallpaper_history.dart';
import 'package:university_timetable/screens/timetable_settings_screen.dart';
import 'package:university_timetable/services/storage_service.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

const _kHistoryPrefKey = 'wallpaper_history_v1';

/// 真实的临时壁纸文件：条目可用性判定会摸盘，假的路径一律被判成"丢失"。
String _createTempWallpaper(String name) {
  final dir = Directory.systemTemp.createTempSync('mikcb-wallpaper-ui-test');
  final file = File('${dir.path}${Platform.pathSeparator}$name')
    ..writeAsStringSync('x');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  return file.path;
}

void _seedPrefs({
  required TimetableSettings settings,
  List<WallpaperHistoryEntry> history = const [],
}) {
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
    _kHistoryPrefKey: jsonEncode([
      for (final entry in history) entry.toJson(),
    ]),
  });
}

/// 「最近使用」里每张缩略图的标签（条目带的是"照片"这种类目名，不是文件名）。
const _kRecentCardLabel = '照片';

/// 起好 App 并进到「课表页面」子页，滚到「背景」组（壁纸行 + 最近使用都在里面）。
Future<void> _openTimetablePageSettings(WidgetTester tester) async {
  final homeList = find.byType(HyperosListView).first;
  await tester.scrollUntilVisible(
    find.text('课表页面'),
    200,
    scrollable: find
        .descendant(of: homeList, matching: find.byType(Scrollable))
        .first,
  );
  await tester.tap(find.text('课表页面'));
  await tester.pumpAndSettle();
  // 「背景」组在页面下半部分。滚到壁纸那一行就停 —— 它是「最近使用」的正上方，
  // 后面那个条要不要出现由数据决定（有可用条目才有），拿它当锚点会在"没有历史"
  // 的用例里直接找不到元素。
  final editorList = find.byType(HyperosListView).last;
  await tester.scrollUntilVisible(
    find.text('背景图片'),
    300,
    scrollable: find
        .descendant(of: editorList, matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const homeWidgetChannel = MethodChannel('com.mutx163.qingyu/home_widget');
  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const liveChannel = MethodChannel('com.mutx163.qingyu/miui_live');

  setUp(() {
    StorageService().resetForTesting();
    for (final channel in const [
      homeWidgetChannel,
      analyticsChannel,
      liveChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => null);
    }
  });

  tearDown(() {
    for (final channel in const [
      homeWidgetChannel,
      analyticsChannel,
      liveChannel,
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final provider = await createInitializedTestProvider(tester);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const TestApp(home: TimetableSettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('壁纸路径还在但文件没了：给出「已丢失」提示，可点回选图', (
    tester,
  ) async {
    final missing = _createTempWallpaper('vanishes.png');
    await tester.runAsync(() => File(missing).delete());
    _seedPrefs(
      settings: TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: missing,
      ),
    );
    await pumpSettings(tester);

    expect(find.text('图片文件已丢失'), findsNothing, reason: '没进到那页');
    await _openTimetablePageSettings(tester);

    expect(find.text('图片文件已丢失'), findsOneWidget);
    expect(
      find.textContaining('纯色背景'),
      findsOneWidget,
      reason: '要说清首页现在看到的是什么，否则用户以为壁纸坏了',
    );
    // 失效的路径不能进「最近使用」：那一栏只列文件真在的条目。
    expect(find.text('最近使用'), findsNothing);
  });

  testWidgets('长按「最近使用」里的一张：条目消失、文件仍在（反悔窗口内）', (
    tester,
  ) async {
    final inUse = _createTempWallpaper('current.png');
    final other = _createTempWallpaper('other.png');
    _seedPrefs(
      settings: TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: inUse,
      ),
      history: [
        WallpaperHistoryEntry(key: inUse, usedAt: 200),
        WallpaperHistoryEntry(key: other, usedAt: 100),
      ],
    );
    await pumpSettings(tester);
    await _openTimetablePageSettings(tester);

    // 当前壁纸已被历史收录，不会再合出一张，所以正好两张、下标即身份：
    // 0 = 正在用的 current，1 = 另一张 other。
    final cards = find.text(_kRecentCardLabel);
    expect(cards, findsNWidgets(2));

    await tester.longPress(cards.at(1));
    await tester.pumpAndSettle();

    expect(
      cards,
      findsNWidgets(1),
      reason: '长按必须真的把这张从「最近使用」里摘掉',
    );
    expect(
      File(other).existsSync(),
      isTrue,
      reason: '反悔窗口内不许删文件 —— 撤销还要把它放回去',
    );
    expect(find.text('已从最近使用中删除'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
  });

  testWidgets('长按当前正在用的那张：只提示，不删条目也不删文件', (tester) async {
    final inUse = _createTempWallpaper('current.png');
    _seedPrefs(
      settings: TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: inUse,
      ),
      history: [WallpaperHistoryEntry(key: inUse, usedAt: 200)],
    );
    await pumpSettings(tester);
    await _openTimetablePageSettings(tester);

    final cards = find.text(_kRecentCardLabel);
    expect(cards, findsOneWidget);
    await tester.longPress(cards.at(0));
    await tester.pumpAndSettle();

    expect(find.text('正在使用这张壁纸，请先换成别的再删除'), findsOneWidget);
    expect(cards, findsOneWidget, reason: '条目必须留着');
    expect(File(inUse).existsSync(), isTrue);
    expect(find.text('已从最近使用中删除'), findsNothing);
  });
}
