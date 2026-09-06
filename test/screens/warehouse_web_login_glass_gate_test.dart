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
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers_test_app.dart';

/// 闸门契约：可见登录页的 WebView 是平台视图，置位全局玻璃降级；下拉快捷
/// 导入的 runInBackground 实例挂在 Offstage 1×1 里、paint 整棵跳过，平台视图
/// 不进合成帧，必须**不**置位——否则首页下拉导入期间玻璃全部陪葬降级，且
/// dispose 在帧末执行、闸门归零无通知，玻璃恢复还要等下一次任意重建。
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

  Widget buildLoginScreen({required bool runInBackground}) {
    return TestApp(
      home: WarehouseAdapterWebLoginScreen(
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
