import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:university_timetable/screens/qr_transfer_scan_screen.dart';
import 'package:university_timetable/services/app_migration_service.dart';
import 'package:university_timetable/services/qr_transfer/qr_transfer_codec.dart';
import 'package:university_timetable/utils/managed_image_storage.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import '../helpers_test_app.dart';

class _FakeMobileScannerPlatform extends MobileScannerPlatform {
  final StreamController<BarcodeCapture?> _barcodes =
      StreamController<BarcodeCapture?>.broadcast();
  final StreamController<TorchState> _torch =
      StreamController<TorchState>.broadcast();
  final StreamController<double> _zoom = StreamController<double>.broadcast();
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  StartOptions? lastStartOptions;

  @override
  Stream<BarcodeCapture?> get barcodesStream => _barcodes.stream;

  @override
  Stream<TorchState> get torchStateStream => _torch.stream;

  @override
  Stream<double> get zoomScaleStateStream => _zoom.stream;

  @override
  Widget buildCameraView() => const SizedBox.expand();

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    startCalls++;
    lastStartOptions = startOptions;
    return const MobileScannerViewAttributes(
      cameraDirection: CameraFacing.back,
      currentTorchMode: TorchState.off,
      numberOfCameras: 1,
      size: Size(640, 480),
    );
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await _barcodes.close();
    await _torch.close();
    await _zoom.close();
  }

  void emit(BarcodeCapture capture) {
    _barcodes.add(capture);
  }
}

class _FakeWebViewController extends PlatformWebViewController {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakeWebViewController(PlatformWebViewControllerCreationParams params)
    : super.implementation(params);

  Uri? loadedUri;
  JavaScriptMode? javaScriptMode;
  String? userAgent;
  bool? zoomEnabled;

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loadedUri = params.uri;
  }

  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {
    javaScriptMode = mode;
  }

  @override
  Future<void> setUserAgent(String? value) async {
    userAgent = value;
  }

  @override
  Future<void> enableZoom(bool enabled) async {
    zoomEnabled = enabled;
  }
}

class _FakeWebViewWidget extends PlatformWebViewWidget {
  // ignore: use_super_parameters, the platform interface requires a named protected constructor.
  _FakeWebViewWidget(PlatformWebViewWidgetCreationParams params)
    : super.implementation(params);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey<String>('fake-webview'),
      color: Color(0xFF101820),
    );
  }
}

class _FakeWebViewPlatform extends WebViewPlatform {
  _FakeWebViewController? controller;

  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) {
    return controller = _FakeWebViewController(params);
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(
    PlatformWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MobileScannerPlatform previousScannerPlatform;

  setUp(() {
    previousScannerPlatform = MobileScannerPlatform.instance;
  });

  tearDown(() {
    MobileScannerPlatform.instance = previousScannerPlatform;
    MobileScannerController.resetPlatformSessionOwner();
  });

  testWidgets('QR scan imports a complete stream and tears down the camera', (
    tester,
  ) async {
    final fakePlatform = _FakeMobileScannerPlatform();
    MobileScannerPlatform.instance = fakePlatform;

    Uint8List? imported;
    await tester.pumpWidget(
      TestApp(
        home: QrTransferScanScreen(
          onComplete: (bytes) async {
            imported = bytes;
          },
        ),
      ),
    );
    await tester.pump();

    expect(fakePlatform.startCalls, 1);
    expect(
      fakePlatform.lastStartOptions?.formats,
      contains(BarcodeFormat.qrCode),
    );

    final original = Uint8List.fromList(
      List<int>.generate(800, (index) => (index * 37 + 11) & 0xff),
    );
    final encoder = QrTransferEncoder.prepare(original);
    final frames = List<String>.generate(
      encoder.info.sourceSymbolCount * 8,
      encoder.frameTextFor,
    )..shuffle(Random(7));

    for (final frame in frames) {
      fakePlatform.emit(BarcodeCapture(barcodes: [Barcode(rawValue: frame)]));
      await tester.pump();
      if (imported != null) {
        break;
      }
    }
    await tester.runAsync(() async {
      for (var i = 0; i < 50 && imported == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pump();

    expect(imported, orderedEquals(original));
    expect(fakePlatform.stopCalls, greaterThanOrEqualTo(1));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(fakePlatform.disposeCalls, greaterThanOrEqualTo(1));
  });

  test(
    'photo picker cancellation and byte reads use the platform seam',
    () async {
      const pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      final documentsDirectory = await Directory.systemTemp.createTemp(
        'mikcb-plugin-smoke-',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            pathProviderChannel,
            (call) async => documentsDirectory.path,
          );
      addTearDown(() async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
        if (await documentsDirectory.exists()) {
          await documentsDirectory.delete(recursive: true);
        }
      });

      var pickerCalls = 0;
      XFile? nextImage;
      Future<XFile?> pickImage() async {
        pickerCalls++;
        return nextImage;
      }

      final cancelled = await pickAndStoreManagedImage(
        directoryName: 'plugin-smoke-cancel',
        filePrefix: 'wallpaper',
        imagePicker: pickImage,
      );
      expect(cancelled, isNull);
      expect(pickerCalls, 1);

      final bytes = Uint8List.fromList([0, 1, 2, 3, 4]);
      final sourceFile = File(
        '${documentsDirectory.path}${Platform.pathSeparator}picked.JPG',
      );
      await sourceFile.writeAsBytes(bytes);
      nextImage = XFile(sourceFile.path);
      final directoryName =
          'plugin-smoke-${DateTime.now().microsecondsSinceEpoch}';
      final path = await pickAndStoreManagedImage(
        directoryName: directoryName,
        filePrefix: 'wallpaper',
        imagePicker: pickImage,
      );

      expect(path, isNotNull);
      final storedFile = File(path!);
      expect(storedFile.path.toLowerCase(), endsWith('.jpg'));
      expect(await storedFile.readAsBytes(), bytes);
      await storedFile.parent.delete(recursive: true);
    },
  );

  testWidgets('WebView controller loads through a replaceable platform', (
    tester,
  ) async {
    final fakePlatform = _FakeWebViewPlatform();
    WebViewPlatform.instance = fakePlatform;

    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.enableZoom(true);
    await controller.setUserAgent('test-agent');
    await controller.loadRequest(Uri.parse('https://example.test/login'));

    expect(
      fakePlatform.controller?.javaScriptMode,
      JavaScriptMode.unrestricted,
    );
    expect(fakePlatform.controller?.zoomEnabled, isTrue);
    expect(fakePlatform.controller?.userAgent, 'test-agent');
    expect(
      fakePlatform.controller?.loadedUri,
      Uri.parse('https://example.test/login'),
    );

    await tester.pumpWidget(
      MaterialApp(home: WebViewWidget(controller: controller)),
    );
    expect(find.byKey(const ValueKey<String>('fake-webview')), findsOneWidget);
  });

  test('MethodChannel migration flow forwards arguments and results', () async {
    const channel = MethodChannel('com.mutx163.qingyu/migration');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'findInstalledPackage' => 'com.example.legacy',
            'openPackage' => true,
            _ => null,
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final service = AppMigrationService();
    expect(
      await service.findInstalledLegacyPackage(
        candidates: const ['com.example.legacy'],
      ),
      'com.example.legacy',
    );
    expect(await service.openPackage('com.example.legacy'), isTrue);
    expect(calls.map((call) => call.method), [
      'findInstalledPackage',
      'openPackage',
    ]);
    expect(calls.first.arguments, ['com.example.legacy']);
    expect(calls.last.arguments, 'com.example.legacy');
  });
}
