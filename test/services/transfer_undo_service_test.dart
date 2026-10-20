import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:university_timetable/providers/unified_transfer_access.dart';
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

  test('第二次导入不吞掉上一次导入的撤销点（2026-10-20 多槽化）', () {
    final service = TransferUndoService();
    final firstToken = service.create(
      backupJson: '{"first":true}',
      incoming: _incomingPackage('incoming-1'),
      mode: TransferApplyMode.merge,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5),
    );
    final secondToken = service.create(
      backupJson: '{"second":true}',
      incoming: _incomingPackage('incoming-2'),
      mode: TransferApplyMode.overwrite,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5, 0, 0, 1),
    );

    // 最新一个仍是「撤销最近一次导入」的入口。
    expect(service.pending, same(secondToken));
    // 但上一次导入的撤销点仍可按自己的 id 取到——单槽时代这里是 null。
    expect(service.take(firstToken.id), same(firstToken));
    expect(service.pending, same(secondToken));
  });

  test('槽容量 3：最旧的撤销点被挤出', () {
    final service = TransferUndoService();
    final tokens = List.generate(4, (index) {
      return service.create(
        backupJson: '{"n":$index}',
        incoming: _incomingPackage('incoming-$index'),
        mode: TransferApplyMode.merge,
        preview: _preview,
        createdAt: DateTime(2026, 8, 5, 0, 0, index),
      );
    });

    expect(service.take(tokens.first.id), isNull, reason: '最旧的应被挤出');
    expect(service.pending, same(tokens.last));
    expect(service.take(tokens[1].id), same(tokens[1]));
    expect(service.take(tokens[2].id), same(tokens[2]));
  });

  test('remove(id) 只摘掉指定令牌，其余保留', () {
    final service = TransferUndoService();
    final firstToken = service.create(
      backupJson: '{"first":true}',
      incoming: _incomingPackage('incoming-1'),
      mode: TransferApplyMode.merge,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5),
    );
    final secondToken = service.create(
      backupJson: '{"second":true}',
      incoming: _incomingPackage('incoming-2'),
      mode: TransferApplyMode.merge,
      preview: _preview,
      createdAt: DateTime(2026, 8, 5, 0, 0, 1),
    );

    // 对应回滚成功后的清理：被回滚的那个令牌已不再描述一次变更。
    service.remove(secondToken.id);

    expect(service.pending, same(firstToken));
    expect(service.take(secondToken.id), isNull);
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

      final result = await transferService.undoToken(UnifiedTransferProviderAccess(provider), token.id);

      expect(result, isFalse);
      expect(undoService.pending, same(token));
    },
  );
}
