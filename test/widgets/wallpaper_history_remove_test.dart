// 「最近使用」长按删除 + 「壁纸文件已丢失」提示（2026-09-27）。
//
// 这两条都挂在 `_HomeBackdropFlow` 上，而那个 mixin 同时服务两个宿主（「课表
// 页面」设置里的壁纸行、「外观编辑」页底部那颗「调整壁纸」的弹窗）。这里从
// **课表页面**那条进去：那一处是内联的，不经过底部弹层，测试最不容易被弹层
// 动画 / 覆盖层顺序带偏；两个宿主共用同一套 builder 与同一个 mixin，行为一致。
//
// 钉的是五件容易悄悄退化的事：
// ① 提示条只在「路径还在、文件没了」时出现，且给出重新选图的出口；
// ② 移除必须**走两步**：先点角标，再按列表下面那条确认条上的「删除」（直接
//    销毁是不可逆的破坏性操作，不能让隐藏手势当主入口）；
// ③ 确认按钮必须在**卡片外面**、且是设置页同款的正常大小按钮 —— 塞进 78 宽的
//    卡里只剩 24px 高，远小于最小点击区，而且会被卡片自己的圆角裁出"某个角
//    圆得不一样"；
// ④ 同一时刻只有一张卡能待确认，待确认那张的单击是「取消」而不是切壁纸，
//    正在用的那张根本没有角标；
// ⑤ 确认之后文件仍留 2.5s 反悔窗口，撤销期间不许没。
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
import 'package:university_timetable/providers/timetable_provider.dart';
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

/// 某张壁纸在条里那张卡（key 由设置侧的卡片 key 约定，见 _WallpaperThumbnailCard）。
Finder _cardOf(String wallpaperKey) =>
    find.byKey(ValueKey<String>('wallpaper-recent-card:$wallpaperKey'));

/// 某张卡右上角那颗「×」（正在用的那张没有这颗角标）。
Finder _removeBadgeOf(String wallpaperKey) => find.descendant(
  of: _cardOf(wallpaperKey),
  matching: find.byIcon(Icons.close_rounded),
);

/// 某张卡里那张缩略图（含确认态的压暗层）。
Finder _thumbnailOf(String wallpaperKey) => find.descendant(
  of: _cardOf(wallpaperKey),
  matching: find.byKey(
    const ValueKey<String>('wallpaper-card-thumbnail'),
  ),
);

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

  testWidgets('移除要走两步：先点角标，再按下面那条上的「删除」才真删', (
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

    // 当前壁纸已被历史收录，不会再合出一张，所以正好两张、可移除的只有一张。
    final cards = find.text(_kRecentCardLabel);
    expect(cards, findsNWidgets(2));
    // 正在用的那张**没有**角标：可移除入口要靠角标表达"哪张能删"。
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(
      find.descendant(of: _cardOf(inUse), matching: find.byIcon(Icons.close_rounded)),
      findsNothing,
    );
    // 没发起移除时，确认条整条都不在。
    expect(find.text('删除'), findsNothing);
    expect(find.text('取消'), findsNothing);
    final thumbnailSizeBeforeArm = tester.getSize(_thumbnailOf(other));

    await tester.tap(_removeBadgeOf(other));
    await tester.pumpAndSettle();

    // 第一步只发起移除：确认条出现，但什么都不能少、什么都不该动。
    expect(find.text('删除'), findsOneWidget, reason: '确认条要给出那颗删除键');
    expect(find.text('取消'), findsOneWidget);
    expect(
      find.text('将从最近使用中移除，图片文件也会一起删除'),
      findsOneWidget,
      reason: '破坏性动作要把后果说清（含文件一起删）',
    );
    expect(cards, findsNWidgets(2), reason: '标签位没有被按钮挤掉');
    expect(File(other).existsSync(), isTrue);
    expect(find.text('已从最近使用中删除'), findsNothing, reason: '还没确认');
    // 确认键必须在卡片**外面**：塞进 78 宽的卡里只剩 24px 高，远小于最小点击区。
    expect(
      find.descendant(of: _cardOf(other), matching: find.text('删除')),
      findsNothing,
      reason: '确认按钮不许塞回卡内',
    );
    // 缩略图在发起 / 取消之间**不变大小**。
    expect(
      tester.getSize(_thumbnailOf(other)),
      thumbnailSizeBeforeArm,
      reason: '发起移除不许让缩略图改尺寸',
    );

    // 取消 → 回到常态，条目与文件都还在。
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(cards, findsNWidgets(2));
    expect(find.text('删除'), findsNothing);
    expect(find.text('取消'), findsNothing);
    expect(File(other).existsSync(), isTrue);

    // 再来一次，这次按「删除」。
    await tester.tap(_removeBadgeOf(other));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(cards, findsNWidgets(1), reason: '确认之后必须真的把这张摘掉');
    expect(
      File(other).existsSync(),
      isTrue,
      reason: '反悔窗口内不许删文件 —— 撤销还要把它放回去',
    );
    expect(find.text('已从最近使用中删除'), findsOneWidget);
    expect(find.text('撤销'), findsOneWidget);
  });

  testWidgets('同一时刻只有一张卡能处于待确认（对另一张发起即取消这一张）', (
    tester,
  ) async {
    final a = _createTempWallpaper('a.png');
    final b = _createTempWallpaper('b.png');
    final inUse = _createTempWallpaper('current.png');
    _seedPrefs(
      settings: TimetableSettings.defaults().copyWith(
        homePageWallpaperPath: inUse,
      ),
      history: [
        WallpaperHistoryEntry(key: inUse, usedAt: 300),
        WallpaperHistoryEntry(key: a, usedAt: 200),
        WallpaperHistoryEntry(key: b, usedAt: 100),
      ],
    );
    await pumpSettings(tester);
    await _openTimetablePageSettings(tester);

    // 正在用的那张没有角标：可移除的只有 a、b 两张。
    expect(find.text(_kRecentCardLabel), findsNWidgets(3));
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));

    await tester.tap(_removeBadgeOf(a));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);
    expect(
      find.descendant(of: _cardOf(a), matching: find.byIcon(Icons.close_rounded)),
      findsNothing,
      reason: '待确认后这张自己的角标要收起（确认条已经接管）',
    );

    // 对 b 发起：a 的待确认必须让位，不能两张同时待确认。
    await tester.tap(_removeBadgeOf(b));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget, reason: '仍然只该有一个确认条');
    expect(find.text('取消'), findsOneWidget);
    // 此刻两张都还在，确认键还只是提议。
    expect(find.text(_kRecentCardLabel), findsNWidgets(3));
    expect(File(a).existsSync(), isTrue);
    expect(File(b).existsSync(), isTrue);
  });

  testWidgets('待确认那张的单击是「取消」，不许顺手把壁纸也换了', (tester) async {
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

    await tester.tap(_removeBadgeOf(other));
    await tester.pumpAndSettle();
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(_thumbnailOf(other));
    await tester.pumpAndSettle();

    expect(
      find.text('删除'),
      findsNothing,
      reason: '单击那张卡是取消，不是切换壁纸',
    );
    // 壁纸没被换掉：设置里的路径仍是原来那张。
    final provider = Provider.of<TimetableProvider>(
      tester.element(find.byType(HyperosListView).last),
      listen: false,
    );
    expect(provider.settings.homePageWallpaperPath, inUse);
  });

  testWidgets('正在用的那张没有角标，长按只解释一句、不进确认态', (tester) async {
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
    expect(
      find.byIcon(Icons.close_rounded),
      findsNothing,
      reason: '可删入口要靠角标表达"哪张能删"，正在用的那张不能有',
    );

    await tester.longPress(cards.at(0));
    await tester.pumpAndSettle();

    expect(find.text('正在使用这张壁纸，请先换成别的再删除'), findsOneWidget);
    expect(find.text('删除'), findsNothing, reason: '不许发起移除');
    expect(cards, findsOneWidget, reason: '条目必须留着');
    expect(File(inUse).existsSync(), isTrue);
    expect(find.text('已从最近使用中删除'), findsNothing);
  });
}
