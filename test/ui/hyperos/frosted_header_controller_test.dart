import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_controller.dart';

Future<ui.Image> _createTestImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 1, 1),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(1, 1);
  picture.dispose();
  return image;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ui.Image preview;
  late ui.Image blurred;

  setUpAll(() async {
    preview = await _createTestImage();
    blurred = await _createTestImage();
  });

  tearDownAll(() {
    preview.dispose();
    blurred.dispose();
  });

  test('captureEnabled toggles without throwing', () {
    final controller = FrostedHeaderController();
    addTearDown(controller.dispose);

    controller.captureEnabled = true;
    controller.captureEnabled = false;
    expect(controller.displayImage, isNull);
  });

  test('scheduleRefresh when disabled does not capture', () {
    final controller = FrostedHeaderController();
    addTearDown(controller.dispose);

    controller.captureEnabled = false;
    controller.scheduleRefresh(source: 'test');
    expect(controller.isCapturing, isFalse);
  });

  group('resolveDisplayImage', () {
    test('always prefers blurred when available', () {
      expect(
        FrostedHeaderController.resolveDisplayImage(
          preview: preview,
          blurred: blurred,
        ),
        blurred,
      );
    });

    test('falls back to preview when blurred missing', () {
      expect(
        FrostedHeaderController.resolveDisplayImage(
          preview: preview,
          blurred: null,
        ),
        preview,
      );
    });
  });

  group('resolvePreviewActive', () {
    test('inactive while blurred exists', () {
      expect(
        FrostedHeaderController.resolvePreviewActive(
          preview: preview,
          blurred: blurred,
        ),
        isFalse,
      );
    });

    test('active when only preview exists', () {
      expect(
        FrostedHeaderController.resolvePreviewActive(
          preview: preview,
          blurred: null,
        ),
        isTrue,
      );
    });
  });

  group('shouldScheduleBlur', () {
    test('blocks blur when scroll throttle active', () {
      expect(
        FrostedHeaderController.shouldScheduleBlur(
          allowBlur: true,
          throttleScrollBlur: true,
        ),
        isFalse,
      );
    });

    test('allows blur when not throttled', () {
      expect(
        FrostedHeaderController.shouldScheduleBlur(
          allowBlur: true,
          throttleScrollBlur: false,
        ),
        isTrue,
      );
    });

    test('respects allowBlur gate', () {
      expect(
        FrostedHeaderController.shouldScheduleBlur(
          allowBlur: false,
          throttleScrollBlur: false,
        ),
        isFalse,
      );
    });
  });
}
