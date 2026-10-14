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

/// 图库页的**退栈顺序**回归（2026-10-06 用户口径）：
/// * 宿主返回「已落盘」→ 图库页自己退出（没必要再挡着）；
/// * 宿主返回「未落盘」（用户在位置页点了「退出」）→ 图库页**留在栈上**，用户继续挑。
///
/// 台账与清单全部命中缓存，所以点击不碰网络 —— 只验栈行为。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');
  const pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

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
    // 键必须与 `_pick` 现在算出的一致：2026-10-14 起画质恒为 high，
    // 尺寸取 `downloadTargetSize`（测试视口下 = 1440×3200 下限抬升的结果）。
    const resolution = BingWallpaperResolution.high;
    final targetSize = resolution.downloadTargetSize;
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}home_page_wallpaper'
      '${Platform.pathSeparator}'
      'wallpaper_bing_${item.dateKey}_${resolution.storageKey}'
      '_${targetSize.width}x${targetSize.height}.jpg',
    );
    await file.parent.create(recursive: true);
    await file.writeAsString('x');
    alreadyDownloaded = file.path;
    await store.recordApplied(
      dateKey: item.dateKey,
      resolution: resolution,
      path: file.path,
      autoApplied: false,
      targetSize: targetSize,
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
  ///
  /// ⚠️ 用 **`textContaining`**：测试环境里缩略图必然加载失败（HttpClient 被
  /// flutter_test 拦成 400），失败后卡片文案会带「轻点重试」后缀（2026-10-14 起），
  /// 钉整串会假红。
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
      find.textContaining('阿德利企鹅，南极洲'),
      findsOneWidget,
      reason: '前提：那张卡片画出来了（清单命中缓存）',
    );
  }

  /// 点卡片。⚠️ 同上用 `textContaining` 定位。
  Future<void> tapCard(WidgetTester tester) async {
    await tester.tap(find.textContaining('阿德利企鹅，南极洲'));
    await tester.pumpAndSettle();
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

    await tapCard(tester);

    expect(handled, <String>[alreadyDownloaded]);
    expect(
      find.textContaining('阿德利企鹅，南极洲'),
      findsOneWidget,
      reason: '⭐ 返回 false 时图库页**不能**退出 —— 退出就回不到壁纸列表了',
    );
  });

  testWidgets('宿主返回「已落盘」时图库页自己退出', (tester) async {
    await pumpGallery(tester, onImageDownloaded: (path) async => true);

    await tapCard(tester);

    expect(
      find.textContaining('阿德利企鹅，南极洲'),
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
    await tapCard(tester);
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
