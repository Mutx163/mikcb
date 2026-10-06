import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/screens/settings/bing_wallpaper_gallery_page.dart';
import 'package:university_timetable/services/bing_wallpaper_service.dart';
import 'package:university_timetable/services/bing_wallpaper_store.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../helpers_test_app.dart';

/// Regression: the gallery page body used a bare `CustomScrollView` inside
/// [HyperosSubpage]. The subpage header is an **overlay** — content does not get
/// pushed down for it — so the top block ("下载画质" + the resolution chips) was
/// painted *underneath* the frosted title bar. Symptom the user reported: the
/// top of the wallpaper page was tucked into the page header.
///
/// A page body on an overlay subpage must add [HyperosBlurredHeaderScope]'s
/// `contentTopInset` itself (that is what `HyperosListView` /
/// `HyperosBlurredBodyInset` exist for).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const analyticsChannel = MethodChannel('com.mutx163.qingyu/umeng_analytics');

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    BingWallpaperStore.debugResetForTesting();
    // 图库会打列表请求；给一份合法响应，让页面进到「有内容」的状态。
    BingWallpaperService.testClientFactory = () => MockClient(
      (request) async => http.Response.bytes(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'images': <Object?>[
              <String, Object?>{
                'startdate': '20261005',
                'urlbase': '/th?id=OHR.A_EN-US1',
                'title': '今天',
                'copyright': '阿德利企鹅，南极洲',
              },
              <String, Object?>{
                'startdate': '20261004',
                'urlbase': '/th?id=OHR.B_EN-US2',
                'title': '昨天',
                'copyright': 'Artemis I 火箭',
              },
            ],
          }),
        ),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      ),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(analyticsChannel, null);
    BingWallpaperService.testClientFactory = null;
  });

  /// 把图库页推进去并等它把清单拉完。
  ///
  /// 必须走 [runRealAsync]：清单请求与 prefs 写入是**真实**异步 I/O，在
  /// `testWidgets` 的 FakeAsync 区里 `pump()` 推进不了它们（表现是页面永远停在
  /// 「加载中」，断言找不到任何一行内容）。这与 `helpers_test_app.dart` 里
  /// `runRealAsync` / `createInitializedTestProvider` 的理由相同。
  Future<void> pumpGallery(WidgetTester tester) async {
    await tester.pumpWidget(const TestApp(home: _GalleryHost()));
    await tester.pump();
    await runRealAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }

  testWidgets('顶部「下载画质」那一块落在悬浮顶栏之下，不被盖住', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpGallery(tester);

    final inset = tester
        .widgetList<HyperosBlurredHeaderScope>(
          find.byType(HyperosBlurredHeaderScope),
        )
        .first
        .contentTopInset;
    expect(
      inset,
      greaterThan(0),
      reason: '前提：这一页用的是悬浮顶栏（overlayHeader 默认 true），inset 必须非零',
    );

    final title = find.text('下载画质');
    expect(title, findsOneWidget, reason: '顶部那一块要真的画出来了');

    // 关键断言：这块的顶边必须在顶栏占位之下。
    final titleTop = tester.getTopLeft(title).dy;
    expect(
      titleTop,
      greaterThanOrEqualTo(inset),
      reason:
          '「下载画质」顶边 $titleTop 必须在顶栏 inset $inset 之下 —— '
          '裸 CustomScrollView 不带 inset，内容会被顶栏整块盖住',
    );
  });

  testWidgets('网格第一排也在顶栏之下（不留半张卡片被切）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await pumpGallery(tester);

    final inset = tester
        .widgetList<HyperosBlurredHeaderScope>(
          find.byType(HyperosBlurredHeaderScope),
        )
        .first
        .contentTopInset;

    // 用**版权说明**而不是日期当锚点：日期那一行会随运行日变化（10 月 5 日的图在
    // 10 月 6 日打开就显示成「昨天」），拿它当锚点等于让测试跟着日历翻车。
    final firstTileCopyright = find.text('阿德利企鹅，南极洲');
    expect(
      firstTileCopyright,
      findsOneWidget,
      reason: '首张卡片要真的画出来了（清单已拉到）',
    );
    expect(
      tester.getTopLeft(firstTileCopyright).dy,
      greaterThanOrEqualTo(inset),
      reason: '首张卡片的文字也不能被顶栏压住',
    );
  });

  testWidgets('失败态（拉不到清单）那一块同样让开顶栏', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 换成一份失败响应。
    BingWallpaperService.testClientFactory = () =>
        MockClient((request) async => http.Response('err', 503));

    await pumpGallery(tester);

    final inset = tester
        .widgetList<HyperosBlurredHeaderScope>(
          find.byType(HyperosBlurredHeaderScope),
        )
        .first
        .contentTopInset;
    final failure = find.text('没能取到 Bing 每日壁纸，请检查网络后重试');
    expect(failure, findsOneWidget);
    expect(
      tester.getTopLeft(failure).dy,
      greaterThanOrEqualTo(inset),
      reason: '居中块也要让开顶栏，否则视觉中心偏到顶栏底下',
    );
  });
}

/// 宿主：给一个带返回键的导航环境（页面自己带顶栏）。
///
/// [BingWallpaperGalleryPage.onImageDownloaded] 在这里返回 `false`（模拟用户从位置
/// 编辑页「退出」），于是图库页**不会**自己退出 —— 那条退栈行为由
/// `bing_wallpaper_gallery_back_test.dart` 单独盯。
class _GalleryHost extends StatelessWidget {
  const _GalleryHost();

  @override
  Widget build(BuildContext context) => const BingWallpaperGalleryPage(
    onImageDownloaded: _notApplied,
  );

  static Future<bool> _notApplied(String path) async => false;
}