import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/image_export_capture.dart';

/// 一张「解码何时返回由测试说了算」的图片。
///
/// 真实图片的异步性没法在测试里复现，所以用一个 [gate] 卡住解码：门没开，
/// provider 就永远不吐 [ImageInfo]。
class _GatedImageProvider extends ImageProvider<_GatedImageProvider> {
  _GatedImageProvider({required this.gate, required this.image});

  final Future<void> gate;
  final ui.Image image;

  @override
  Future<_GatedImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_GatedImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _GatedImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      gate.then((_) => ImageInfo(image: image)),
    );
  }
}

/// 出图机制「拍照前先等图片解码」的契约。
///
/// 这里验的是 [ImageExportCapture.precacheDocumentImages] 本身：它必须在文档
/// 里的图片真正解码完之后才返回。回归表现是课表分享图底部的品牌 logo 空白
/// —— 光栅化赶在 `Image` 的异步解码之前，拍到的还是那个空盒子。
void main() {
  testWidgets('文档里的图片没解码完，precache 不返回', (tester) async {
    final gate = Completer<void>();
    final image = await tester.runAsync(() => createTestImage(width: 2, height: 2));
    final provider = _GatedImageProvider(gate: gate.future, image: image!);

    final rootKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(key: rootKey, child: Image(image: provider, width: 8)),
      ),
    );

    var finished = false;
    unawaited(
      ImageExportCapture.precacheDocumentImages(
        rootKey,
      ).then((_) => finished = true),
    );

    await tester.pump();
    expect(
      finished,
      isFalse,
      reason: '图片还在解码中，出图流程不能往下走（否则拍出来就是空盒子）',
    );

    gate.complete();
    await tester.pump();
    await tester.pump();
    expect(finished, isTrue, reason: '图片解码完成后就该放行');
  });

  testWidgets('文档里没有图片时是空操作', (tester) async {
    final rootKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(home: Center(key: rootKey, child: const Text('无图文档'))),
    );

    await ImageExportCapture.precacheDocumentImages(rootKey);
    expect(tester.takeException(), isNull);
  });
}
