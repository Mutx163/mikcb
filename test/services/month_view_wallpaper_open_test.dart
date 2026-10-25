import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/screens/month_view_screen.dart';
import 'package:university_timetable/services/storage_service.dart';

/// **设置壁纸后，月视图必须能打开**。
///
/// ## 这条用例守的是什么（2026-10-25 撞出来的真 bug）
///
/// `TimetablePageChromeShell` 的壁纸层原先写成
/// `Positioned.fill(child: _wallpaperLayer(chrome))`，而 `_wallpaperLayer`
/// 在「有壁纸」分支返回的 `homePageBackdropLayer(...)` **本身已经是
/// `Positioned.fill(Image)`**。于是同一个 `Image` 的 RenderObject 收到两个
/// `Positioned` 的 `StackParentData` —— debug 下立刻抛
/// `Competing ParentDataWidgets are providing parent data to the same RenderObject`。
///
/// 这个洞一直活着，是因为**所有既有月视图用例都没有设置壁纸**：
/// 无壁纸分支返回 `ColoredBox`，一层 `Positioned` 完全合法。也就是说
/// 「带壁纸的月视图」这条最常见的真实路径，测试网里一格都没有。
///
/// 所以本用例的全部价值在于**必须真的设一张壁纸**。如果有人图省事把
/// `homePageWallpaperPath` 那行删掉，这条用例会变得永远绿 —— 反向验证时
/// 请删掉 `takingException()` 的断言，确认它真的会红。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TimetableProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    provider = TimetableProvider(
      storageService: StorageService.forTesting(),
      autoInitialize: false,
      enableLiveActivitySync: false,
    );
    await provider.initialize();
  });

  tearDown(() => provider.dispose());

  /// 造一个**真实存在**的图片文件当壁纸。
  ///
  /// `homePageBackdropKey` 会 `_homePageFileExistsSync(path)` 判存在，
  /// 路径不存在就返回 null、`hasBackdrop` 为 false —— 那样又走回无壁纸分支，
  /// 用例就白写了（这条坑同样要留住：光设置路径不建文件是不生效的）。
  Future<String> writeWallpaper(WidgetTester tester) async {
    final written = await tester.runAsync<File>(() async {
      final dir = await Directory.systemTemp.createTemp('month_wallpaper');
      final f = File('${dir.path}/wall.png');
      await f.writeAsBytes(_kOnePixelPng);
      return f;
    });
    final file = written!;
    addTearDown(() async {
      await tester.runAsync(() async {
        final parent = Directory(file.parent.path);
        if (parent.existsSync()) {
          await parent.delete(recursive: true);
        }
      });
    });
    return file.path;
  }

  testWidgets('设了壁纸之后，进月视图不抛 ParentData 断言', (tester) async {
    final wallpaper = await writeWallpaper(tester);

    await tester.runAsync(() async {
      await provider.updateSettings(
        provider.settings.copyWith(homePageWallpaperPath: wallpaper),
      );
    });

    // 前提必须成立：壁纸真的被认成"有壁纸"，否则测的其实是无壁纸分支。
    expect(
      provider.settings.homePageWallpaperPath,
      wallpaper,
      reason: '壁纸路径必须落进 settings，否则下面的断言测不到真实分支',
    );

    tester.view.physicalSize = const Size(393 * 3, 851 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<TimetableProvider>.value(
        value: provider,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: MonthViewScreen(),
        ),
      ),
    );
    await tester.pump();

    // ParentData 冲突是在 mount 期抛的，tester 会把它收集到 takeException。
    expect(
      tester.takeException(),
      isNull,
      reason:
          '带壁纸的月视图抛异常了 —— 多半是壁纸层又被包了一层 Positioned。'
          '`homePageBackdropLayer` 自己就返回 Positioned.fill，外面不能再包',
    );

    // 再 pump 几帧：有些 ParentData 冲突要到后续 build 才暴露。
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(tester.takeException(), isNull);
  });
}

/// 1×1 透明 PNG。只为让 `File.existsSync()` 为真，内容不重要 ——
/// 本用例断言的是**结构**（ParentData），不是像素。
const List<int> _kOnePixelPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];
