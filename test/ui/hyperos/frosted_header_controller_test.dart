import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_header_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('captureEnabled toggles without throwing', () {
    final controller = FrostedHeaderController();
    addTearDown(controller.dispose);

    controller.captureEnabled = true;
    controller.captureEnabled = false;
    expect(controller.blurredImage, isNull);
  });

  test('scheduleRefresh when disabled does not capture', () {
    final controller = FrostedHeaderController();
    addTearDown(controller.dispose);

    controller.captureEnabled = false;
    controller.scheduleRefresh(source: 'test');
    expect(controller.isCapturing, isFalse);
  });
}
