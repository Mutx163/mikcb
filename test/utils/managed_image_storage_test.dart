import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:university_timetable/utils/managed_image_storage.dart';

/// 钉住 [downloadToManagedImage] 的 client 生命周期，重点是两个历史事故：
///
/// 1. **自建 client 分支在读流前关 client**（2026-10-20 修复）：`http` 的
///    `IOClient.close()` 落到 `HttpClient.close(force: true)`，会立刻掐断
///    在途响应流。修复前 close 挂在 send 之后的 finally 里，`client == null`
///    的默认分支还没开始读流就把 client 关了，逐块读取稳定抛
///    `ClientException`，整条分支永远返回 network 失败。
/// 2. **共享 client 被下载函数关闭**（2026-10-06 事故）：client 归调用方
///    所有，下载函数关掉它之后，调用方的后续请求全部失败。
///
/// [CloseDetectingClient] 模拟真实 IOClient 的 close 语义：close 之后
/// 流立刻报错——与生产 `HttpClient.close(force: true)` 行为同形。
class CloseDetectingClient extends http.BaseClient {
  CloseDetectingClient(this.bytes);

  final List<int> bytes;
  var closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final controller = StreamController<List<int>>();
    controller.onListen = () {
      if (closed) {
        controller.addError(
          http.ClientException(
            'Connection closed before full body was received '
            '(emulated IOClient force-close)',
          ),
        );
        controller.close();
        return;
      }
      controller.add(bytes);
      controller.close();
    };
    return http.StreamedResponse(
      controller.stream,
      200,
      contentLength: bytes.length,
      headers: {'content-type': 'image/png'},
    );
  }

  @override
  void close() {
    closed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // path_provider 的渠道替身（bing_wallpaper_service_test.dart 同款做法）：
  // 把「应用文档目录」指到临时目录，让下载走真实文件写入。
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );
  late Directory documentsDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('managed-img');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          pathProviderChannel,
          (call) async => documentsDir.path,
        );
  });

  tearDown(() async {
    managedImageOwnedHttpClientFactory = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
  });

  test('自建 client 在响应流读完之后才被关闭（回归：默认分支曾永远失败）', () async {
    final fake = CloseDetectingClient(List<int>.generate(64, (i) => i));
    managedImageOwnedHttpClientFactory = () => fake;

    final result = await downloadToManagedImage(
      url: Uri.parse('https://example.test/owned-branch.png'),
      directoryName: 'wallpapers',
      fileName: 'wallpaper_owned_client_regression.png',
    );

    expect(result.succeeded, isTrue, reason: result.describe());
    // 下载成功后自建 client 必须被关闭（防泄漏），但关闭只能发生在流读完之后。
    expect(fake.closed, isTrue);
    expect(File(result.path!).existsSync(), isTrue);
    expect(File(result.path!).lengthSync(), 64);
  });

  test('注入的共享 client 绝不被下载函数关闭（回归 2026-10-06 事故）', () async {
    final fake = CloseDetectingClient(List<int>.generate(16, (i) => i));

    final result = await downloadToManagedImage(
      url: Uri.parse('https://example.test/shared-client.png'),
      directoryName: 'wallpapers',
      fileName: 'wallpaper_shared_client_regression.png',
      client: fake,
    );

    expect(result.succeeded, isTrue, reason: result.describe());
    expect(fake.closed, isFalse, reason: '共享 client 归调用方所有');
  });

  test('send 失败（网络层异常）时自建 client 仍会被关闭', () async {
    managedImageOwnedHttpClientFactory = () => _ThrowingClient();

    final result = await downloadToManagedImage(
      url: Uri.parse('https://example.test/owned-throws.png'),
      directoryName: 'wallpapers',
      fileName: 'wallpaper_owned_throw.png',
    );

    expect(result.succeeded, isFalse);
    expect(result.failure, ManagedImageDownloadFailure.network);
  });
}

/// send 直接抛异常的最小 client。
class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw http.ClientException('network unreachable');
  }
}
