import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/bing_wallpaper.dart';
import 'package:university_timetable/screens/settings/bing_wallpaper_gallery_page.dart';
import 'package:university_timetable/services/bing_wallpaper_service.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';

import '../helpers_test_app.dart';

/// Regression: tapping a wallpaper used to **pop the gallery first**, then push
/// the position editor — so「退出」landed back in settings instead of back in the
/// wallpaper list.
///
/// User 2026-10-06: 「点击看完大屏，点击退出的时候，直接返回到最开始的地方了，
/// 而不是壁纸列表」—— picking another wallpaper meant walking back through
/// 设置 → Bing 每日壁纸 every time.
///
/// Contract now: the gallery **stays on the stack** and the position editor is
/// pushed *above* it, so
/// * handler returns `false` (user hit 退出) → gallery is still there;
/// * handler returns `true` (user hit 完成) → gallery closes itself.
///
/// ## 这条测试**完全不走网络**
///
/// 清单与已下载文件都预先塞进 store（缓存命中 → `findExisting` 命中），所以不需要
/// MockClient。原因是实测踩到的：在 `testWidgets` 的 FakeAsync 里跑真实 HTTP 下载，
/// 那个 `await` 链**永远推进不到底**（只有 `download start` 一行日志）——
/// `flutter test` 里凡是要真下载，都得挪到纯 `test()` + `runRealAsync` 那套去。
/// 本条要验的是退栈顺序，跟网络无关，不该被它拖累。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  late Directory tempDir;
  late String alreadyDownloaded;

  const item = BingWallpaperItem(
    dateKey: '20261005',
    urlBase: '/th?id=OHR.A_EN-US1',
    title: '今天',
    copyright: '阿德利企鹅，南极洲',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BingWallpaperStore.debugResetForTesting();
    tempDir = await Directory.systemTemp.createTemp('bing-gallery-back');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => tempDir.path,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);

    final store = BingWallpaperStore.instance;
    // 清单走缓存（loadItems 命中 TTL → 不发请求）；
    await store.saveCachedItems(const <BingWallpaperItem>[item]);
    // 假装那张已经下好了 —— findExisting 命中，`_pick` 直接进宿主回调，不碰网络。
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}home_page_wallpaper'
      '${Platform.pathSeparator}wallpaper_bing_20261005_standard.jpg',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('x');
    alreadyDownloaded = file.path;
    await store.recordApplied(
      dateKey: item.dateKey,
      resolution: BingWallpaperResolution.standard,
      path: file.path,
      autoApplied: false,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    BingWallpaperService.testClientFactory = null;
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// 清单与已下载文件都命中缓存，pump 完就该看到那张卡片的版权说明。
  Future<void> pumpGallery(
    WidgetTester tester, {
    required Future<bool> Function(String path) onImageDownloaded,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      TestApp(home: _GalleryHost(onImageDownloaded: onImageDownloaded)),
    );
    await tester.pump();
    expect(
      find.text('阿德利企鹅，南极洲'),
      findsOneWidget,
      reason: '前提：那张卡片画出来了（清单命中缓存）',
    );
  }

  testWidgets('宿主返回「未落盘」时图库页留在栈上（用户可继续挑）', (tester) async {
    final handled = <String>[];
    await pumpGallery(
      tester,
      onImageDownloaded: (path) async {
        handled.add(path);
        return false; // 模拟位置页「退出」
      },
    );

    await tester.tap(find.text('阿德利企鹅，南极洲'));
    await tester.pumpAndSettle();

    expect(handled, <String>[alreadyDownloaded]);
    expect(
      find.text('阿德利企鹅，南极洲'),
      findsOneWidget,
      reason: '⭐ 返回 false 时图库页**不能**退出 —— 退出就回不到壁纸列表了',
    );
  });

  testWidgets('宿主返回「已落盘」时图库页自己退出', (tester) async {
    await pumpGallery(tester, onImageDownloaded: (path) async => true);

    await tester.tap(find.text('阿德利企鹅，南极洲'));
    await tester.pumpAndSettle();

    expect(
      find.text('阿德利企鹅，南极洲'),
      findsNothing,
      reason: '用户已确认落盘，图库就没必要再挡在前面',
    );
  });

  testWidgets('测试自身没偷偷发网络请求', (tester) async {
    var requests = 0;
    BingWallpaperService.testClientFactory = () => MockClient((request) async {
      requests++;
      return http.Response('', 500);
    });
    await pumpGallery(tester, onImageDownloaded: (path) async => false);
    await tester.tap(find.text('阿德利企鹅，南极洲'));
    await tester.pumpAndSettle();
    expect(
      requests,
      0,
      reason: '这条测试要验退栈顺序，不该被网络状态影响（也不该真下载）',
    );
  });
}

class _GalleryHost extends StatelessWidget {
  const _GalleryHost({required this.onImageDownloaded});

  final Future<bool> Function(String path) onImageDownloaded;

  @override
  Widget build(BuildContext context) =>
      BingWallpaperGalleryPage(onImageDownloaded: onImageDownloaded);
}