import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/ui/hyperos/liquid/hyperos_liquid_glass_surface.dart';

void main() {
  test('concurrent shader probes share one Future', () async {
    final first = LiquidGlassShaderProbe.probeIfNeeded();
    final second = LiquidGlassShaderProbe.probeIfNeeded();

    expect(identical(first, second), isTrue);
    await first;
  });
}
