import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/models/warehouse_repository_models.dart';
import 'package:university_timetable/screens/course_import_screen.dart';
import 'package:university_timetable/services/warehouse_repository_service.dart';
import 'package:university_timetable/ui/hyperos/frosted/liquid_glass_degradation.dart';
import 'package:university_timetable/ui/hyperos/hyperos_navigation.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers_test_app.dart';

/// 闸门契约：可见登录页的 WebView 是平台视图，置位全局玻璃降级；下拉快捷
/// 导入的 runInBackground 实例挂在 Offstage 1×1 里、paint 整棵跳过，平台视图
/// 不进合成帧，必须**不**置位——否则首页下拉导入期间玻璃全部陪葬降级。
/// 闸门为响应式（LiquidGlassDegradationScope）：dispose 在帧末归零时通知依赖
/// 的玻璃表面重建，导入返回首页后玻璃立即恢复。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WebViewPlatform? previousWebViewPlatform;
  late FlutterSecureStoragePlatform previousSecureStoragePlatform;

  setUp(() {
    previousWebViewPlatform = WebViewPlatform.instance;
    previousSecureStoragePlatform = FlutterSecureStoragePlatform.instance;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    WebViewPlatform.instance = _FakeWebViewPlatform();
    FlutterSecureStoragePlatform.instance = _FakeSecureStoragePlatform();
  });

  tearDown(() {
    // instance= 断言拒绝 null，测试环境原始值本就是 null，保持 fake 即可。
    if (previousWebViewPlatform != null) {
      WebViewPlatform.instance = previousWebViewPlatform;
    }
    FlutterSecureStoragePlatform.instance = previousSecureStoragePlatform;
  });

  WarehouseAdapterWebLoginScreen buildLoginPage({
    required bool runInBackground,
  }) {
    return WarehouseAdapterWebLoginScreen(
      title: '测试教务',
      initialUrl: 'https://example.edu/login',
      source: WarehouseRepositorySource.fromGitHubUrl(
        'https://github.com/Mutx163/qingyu_warehouse',
      ),
      school: const WarehouseSchoolEntry(
        id: 'demo',
        name: '测试教务',
        initial: '测',
        resourceFolder: 'demo',
      ),
      adapter: const WarehouseAdapterEntry(
        adapterId: 'demo-adapter',
        adapterName: '测试适配器',
        category: 'macro',
        assetJsPath: 'macro/demo-adapter.js',
        importUrl: 'https://example.edu/login',
        maintainer: 'macro',
        description: '测试适配器',
      ),
      fetchOptions: const WarehouseFetchOptions(
        downloadSource: AppUpdateDownloadSource.original,
        mirrorPreset: AppUpdateMirrorPreset.ghfast,
        customMirrorUrlPrefix: '',
      ),
      runInBackground: runInBackground,
    );
  }

  Widget buildLoginScreen({required bool runInBackground}) {
    return TestApp(home: buildLoginPage(runInBackground: runInBackground));
  }

  /// 把登录页当二级页面推上来的宿主：只有它是被推上来的路由，才测得到
  /// "返回时摘平台视图"这件事（直接当 home 没有反向动画）。
  Widget buildPushHost() {
    return TestApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                HyperosPageRoute<void>(
                  builder: (_) => buildLoginPage(runInBackground: false),
                ),
              ),
              child: const Text('打开登录页'),
            ),
          ),
        ),
      ),
    );
  }
  testWidgets('runInBackground 实例不置位平台视图玻璃闸门', (tester) async {
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);

    await tester.pumpWidget(buildLoginScreen(runInBackground: true));
    await tester.pump();

    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);
  });

  testWidgets('可见登录页置位闸门且卸载后复位', (tester) async {
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);

    await tester.pumpWidget(buildLoginScreen(runInBackground: false));
    await tester.pump();

    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);
  });

  testWidgets('返回动画滑出大半即摘掉平台视图，玻璃闸门同步结束（不等 dispose）', (
    tester,
  ) async {
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);

    await tester.pumpWidget(buildPushHost());
    await tester.tap(find.text('打开登录页'));
    await tester.pump();
    // 300ms 进入动画走完：页面就位，平台视图与闸门都在。
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(WarehouseAdapterWebLoginScreen), findsOneWidget);
    expect(find.byType(WebViewWidget), findsOneWidget);
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isTrue);

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pump();
    // 反向动画走到 240ms（全程 300ms）：页面还在滑，但平台视图该已经离场。
    await tester.pump(const Duration(milliseconds: 240));

    expect(
      find.byType(WarehouseAdapterWebLoginScreen),
      findsOneWidget,
      reason: '返回动画还没走完，页面本身应该还在',
    );
    expect(
      find.byType(WebViewWidget, skipOffstage: false),
      findsNothing,
      reason: 'Hybrid Composition 的原生视图必须在动画落地前摘出树，'
          '否则动画结束它还会停在"滑到一半"的位置闪一帧',
    );
    expect(
      LiquidGlassDegradation.platformViewSurfaceUnsafe,
      isFalse,
      reason: '平台视图离屏即结束闸门；等 dispose 会让首页玻璃在落地那一帧从实底跳变',
    );

    await tester.pumpAndSettle();
    expect(
      find.byType(WarehouseAdapterWebLoginScreen, skipOffstage: false),
      findsNothing,
    );
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);
  });

  testWidgets('被别的路由盖住时不摘平台视图：登录流程得能接着用', (tester) async {
    await tester.pumpWidget(buildPushHost());
    await tester.tap(find.text('打开登录页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push<void>(
      HyperosPageRoute<void>(
        builder: (_) =>
            const Scaffold(body: Center(child: Text('盖在上面的页'))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(WebViewWidget, skipOffstage: false),
      findsOneWidget,
      reason: '只是被盖住（动的是次级动画）不该触发摘除，否则回来还剩一块空白',
    );
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isTrue);

    // 收尾：两层都拆掉，别把闸门计数留给后面的用例。
    navigator.pop();
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();
    expect(LiquidGlassDegradation.platformViewSurfaceUnsafe, isFalse);
  });
}

class _FakeWebViewController extends PlatformWebViewController {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakeWebViewController(PlatformWebViewControllerCreationParams params)
    : super.implementation(params);

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}

  @override
  Future<void> enableZoom(bool enabled) async {}

  @override
  Future<void> setUserAgent(String? value) async {}

  @override
  Future<void> addJavaScriptChannel(
    JavaScriptChannelParams javaScriptChannelParams,
  ) async {}

  @override
  Future<void> setOnConsoleMessage(
    void Function(JavaScriptConsoleMessage consoleMessage) onMessage,
  ) async {}

  @override
  Future<void> setPlatformNavigationDelegate(
    covariant PlatformNavigationDelegate platformNavigationDelegate,
  ) async {}

  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakeWebViewWidget(PlatformWebViewWidgetCreationParams params)
    : super.implementation(params);

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _FakeWebViewPlatform extends WebViewPlatform {
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return _FakeWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) {
    return _FakePlatformNavigationDelegate(params);
  }
}

class _FakePlatformNavigationDelegate extends PlatformNavigationDelegate {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakePlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params)
    : super.implementation(params);

  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback onNavigationRequest,
  ) async {}

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async {}

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async {}

  @override
  Future<void> setOnWebResourceError(
    WebResourceErrorCallback onWebResourceError,
  ) async {}

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback onHttpAuthRequest) async {}

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback onSslAuthError) async {}
}

class _FakeSecureStoragePlatform extends FlutterSecureStoragePlatform {
  @override
  Future<String?> read({required String key, required Map<String, String> options}) =>
      Future<String?>.value();

  @override
  Future<Map<String, String>> readAll({required Map<String, String> options}) =>
      Future<Map<String, String>>.value(const {});

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {}

  @override
  Future<void> delete({required String key, required Map<String, String> options}) async {}

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {}

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) => Future<bool>.value(false);
}
