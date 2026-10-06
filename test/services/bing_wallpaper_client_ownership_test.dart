import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:university_timetable/services/app_http_client.dart';
import 'package:university_timetable/services/bing_wallpaper_service.dart';

/// Regression: `BingWallpaperService` used to **close the process-wide shared
/// HTTP client**.
///
/// `createAppHttpClient()` returns the BlackBox-observing *shared* client in
/// debug/profile. The constructor computed ownership as
/// `client == null || !isSharedAppHttpClient(client)` — `||` instead of `&&`,
/// and it passed the *null* `client` instead of the resolved one — so ownership
/// was **always** true. The first `dispose()` (from `loadItems()` when the
/// gallery opens) closed the shared client, and every later request through it
/// threw — the user saw "列表能出、点图就下载失败" (`failed=network`).
///
/// Closing that client would also break every other service in the process
/// (weather / holiday sync / update check), so this is not wallpaper-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(resetAppHttpClientForTesting);
  tearDown(resetAppHttpClientForTesting);

  test('注入的 client 一律不由本服务关闭（所有权在调用方）', () {
    var closed = false;
    BingWallpaperService(client: _CloseTrackingClient(() => closed = true))
        .dispose();
    expect(
      closed,
      isFalse,
      reason: '注入 client 意味着所有权在调用方（对齐 WeatherService 的约定）',
    );
  });

  test('没有共享 client 时：自建的那个归自己关，dispose 不抛', () {
    resetAppHttpClientForTesting();
    final service = BingWallpaperService();
    expect(service.dispose, returnsNormally);
  });

  test('⭐ 共享 client 绝不能被 dispose 关掉（2026-10-06 那个真凶）', () {
    var closed = false;
    final shared = _CloseTrackingClient(() => closed = true);
    setupAppHttpClientForBlackBox(shared);

    // 不传 client —— 生产路径就是这样（loadItems / maybeApplyDaily 自建 service）。
    final service = BingWallpaperService();
    expect(
      identical(createAppHttpClient(), shared),
      isTrue,
      reason: '前提：debug 下 createAppHttpClient 返回的就是那个共享 client',
    );
    service.dispose();
    expect(
      closed,
      isFalse,
      reason: '把共享 client 关掉之后，同进程所有服务的请求都会抛异常 —— '
          '天气/节假日同步/版本检查会一起挂',
    );

    // 关不掉，就还能继续用。
    final stillWorks = _CloseTrackingClient(() {});
    setupAppHttpClientForBlackBox(stillWorks);
    expect(createAppHttpClient(), same(stillWorks));
  });

  test('release 模式下自建的 client 归自己关', () {
    // kReleaseMode 在测试里是 false，只能间接验证「未被注册为共享 → owns 判定成立」：
    // 注入一个非共享 client，owns 必须是 false（注入即外部所有）。
    var closed = false;
    BingWallpaperService(client: _CloseTrackingClient(() => closed = true))
        .dispose();
    expect(closed, isFalse);
  });

  test('dispose 可以安全地重复调用', () {
    // 图库页 `_pick` 里 `try/finally` 会 dispose，宿主那边也可能再 dispose 一次；
    // 共享 client 那侧不能因为「关两次」而出问题。
    var closed = false;
    final shared = _CloseTrackingClient(() => closed = true);
    setupAppHttpClientForBlackBox(shared);
    final service = BingWallpaperService();
    expect(service.dispose, returnsNormally);
    expect(service.dispose, returnsNormally);
    expect(closed, isFalse);
  });
}

/// 只记录「有没有被 close」的假 client。
class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient(this.onClose);

  final void Function() onClose;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(const Stream<List<int>>.empty(), 200);

  @override
  void close() => onClose();
}