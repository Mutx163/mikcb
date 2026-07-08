import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/sync_operation_gate.dart';

void main() {
  test('runExclusive serializes overlapping operations', () async {
    final gate = SyncOperationGate();
    var inFlight = 0;
    var maxInFlight = 0;

    Future<void> job() => gate.runExclusive(() async {
      inFlight += 1;
      if (inFlight > maxInFlight) {
        maxInFlight = inFlight;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
      inFlight -= 1;
    });

    await Future.wait([job(), job(), job()]);
    expect(maxInFlight, 1);
    expect(inFlight, 0);
  });

  test('runExclusive propagates errors without blocking the gate', () async {
    final gate = SyncOperationGate();

    await expectLater(
      gate.runExclusive<int>(() async => throw StateError('boom')),
      throwsStateError,
    );

    final value = await gate.runExclusive(() async => 42);
    expect(value, 42);
  });
}
