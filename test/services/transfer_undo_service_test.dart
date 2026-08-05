import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/timetable_provider.dart';
import 'package:university_timetable/services/transfer_diff_service.dart';
import 'package:university_timetable/services/transfer_package.dart';
import 'package:university_timetable/services/transfer_undo_service.dart';
import 'package:university_timetable/services/unified_transfer_service.dart';

TransferPackage _incomingPackage(String packageId) {
  return TransferPackage(
    packageId: packageId,
    scope: TransferScope.currentTimetable,
  );
}

const _preview = TransferDiff(mode: TransferApplyMode.merge, summaries: []);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores a token after an undo attempt fails', () {
    final service = TransferUndoService();
    final token = service.create(
      backupJson: '{}',
      incoming: _incomingPackage('incoming-1'),
      mode: TransferApplyMode.merge,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5),
    );

    expect(service.take(token.id), same(token));
    expect(service.pending, isNull);

    service.restore(token);

    expect(service.pending, same(token));
  });

  test('does not replace a newer token when restoring an older token', () {
    final service = TransferUndoService();
    final firstToken = service.create(
      backupJson: '{}',
      incoming: _incomingPackage('incoming-1'),
      mode: TransferApplyMode.merge,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5),
    );
    final takenToken = service.take(firstToken.id);
    final newerToken = service.create(
      backupJson: '{}',
      incoming: _incomingPackage('incoming-2'),
      mode: TransferApplyMode.overwrite,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5, 0, 0, 1),
    );

    service.restore(takenToken!);

    expect(service.pending, same(newerToken));
  });

  test(
    'keeps the token when UnifiedTransferService cannot restore it',
    () async {
      SharedPreferences.setMockInitialValues({});
      final provider = TimetableProvider(
        autoInitialize: false,
        enableLiveActivitySync: false,
      );
      addTearDown(provider.dispose);

      final undoService = TransferUndoService();
      final transferService = UnifiedTransferService(undoService: undoService);
      final token = undoService.create(
        backupJson: 'not-json',
        incoming: _incomingPackage('incoming-1'),
        mode: TransferApplyMode.merge,
        preview: _preview,
        createdAt: DateTime(2026, 8, 5),
      );

      final result = await transferService.undoToken(provider, token.id);

      expect(result, isFalse);
      expect(undoService.pending, same(token));
    },
  );
}
