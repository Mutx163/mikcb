import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/sync_rollback_snapshot_store.dart';

/// 回滚点落盘的验收测试（2026-10-27）。
///
/// ## 为什么需要它
///
/// 快照恢复是逐批写盘的（`_applySnapshotData` 里十几处 `await`），而回滚点原先
/// 只存在内存里。用户在恢复途中杀掉进程，盘上就是「改了一半」的状态，而撤销入口
/// 随内存一起消失 —— 这正是 2026-09-26 审计里 A1-6 那条（「回滚只在内存」）。
///
/// 落盘这件事本身有三个容易写错的地方，所以逐条钉住：
/// 1. **写一半被杀**：直接覆写会留下半截 JSON（比没有记录更糟，撤销时才发现解不出）。
///    必须走临时文件 + rename。
/// 2. **状态机**：恢复途中是 `applying`，走完才是 `applied`。启动时靠前者判断
///    「上次没走完」—— 状态没改的话，每次启动都会误报。
/// 3. **超大快照**：超过上限不写盘（写了会让每次启动都去读一份巨大 JSON），
///    但要留 warn，让「本次只能内存撤销」这件事可查。
void main() {
  late Directory tmp;
  late SyncRollbackSnapshotStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('rollback_store_test');
    store = SyncRollbackSnapshotStore(directoryProvider: () async => tmp);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  String snapshotJson({String marker = 'v1'}) =>
      jsonEncode({'schemaVersion': 2, 'marker': marker});

  test('save → read 往返：内容与状态都对得上', () async {
    await store.save(
      undoId: 'undo-1',
      snapshotJson: snapshotJson(),
      state: SyncRollbackRecord.applyingState,
    );

    final record = await store.read();
    expect(record, isNotNull);
    expect(record!.undoId, 'undo-1');
    expect(record.state, SyncRollbackRecord.applyingState);
    expect(record.snapshotJson, snapshotJson());
  });

  test('markApplied 把状态从 applying 改成 applied，且内容不变', () async {
    await store.save(
      undoId: 'undo-2',
      snapshotJson: snapshotJson(marker: 'keep-me'),
      state: SyncRollbackRecord.applyingState,
    );
    await store.markApplied('undo-2');

    final record = await store.read();
    expect(record!.state, SyncRollbackRecord.appliedState);
    expect(
      record.snapshotJson,
      snapshotJson(marker: 'keep-me'),
      reason: '改状态不该动快照内容',
    );
  });

  test('markApplied 的 undoId 对不上时不动盘上的记录', () async {
    await store.save(
      undoId: 'undo-3',
      snapshotJson: snapshotJson(),
      state: SyncRollbackRecord.applyingState,
    );
    await store.markApplied('undo-other');

    final record = await store.read();
    expect(
      record!.state,
      SyncRollbackRecord.applyingState,
      reason: '别把「另一个恢复」的状态改掉',
    );
  });

  test('写盘走临时文件 + rename：不留下 .tmp 残留', () async {
    await store.save(
      undoId: 'undo-4',
      snapshotJson: snapshotJson(),
      state: SyncRollbackRecord.applyingState,
    );

    final leftovers = tmp
        .listSync()
        .where((e) => e.path.endsWith('.tmp'))
        .toList();
    expect(leftovers, isEmpty, reason: '临时文件必须被 rename 掉，不能留在盘上');
    expect(File('${tmp.path}/${SyncRollbackSnapshotStore.fileName}').existsSync(), isTrue);
  });

  test('文件损坏时返回 null 并把它挪走（不留着每次启动解析）', () async {
    final file = File('${tmp.path}/${SyncRollbackSnapshotStore.fileName}');
    file.writeAsStringSync('{ 这不是合法 JSON');

    final record = await store.read();
    expect(record, isNull);
    expect(
      file.existsSync(),
      isFalse,
      reason: '解不出来的记录救不回来，留着只会让每次启动都白解析一遍',
    );
  });

  test('空快照不落盘（撤销点指向空课表比没有更糟）', () async {
    await store.save(
      undoId: 'undo-5',
      snapshotJson: '',
      state: SyncRollbackRecord.applyingState,
    );
    expect(await store.read(), isNull);
  });

  test('超过上限的快照不落盘，且读回来是 null（不是半截）', () async {
    final huge = jsonEncode({
      'blob': 'x' * (SyncRollbackSnapshotStore.maxPersistBytes + 1024),
    });
    await store.save(
      undoId: 'undo-6',
      snapshotJson: huge,
      state: SyncRollbackRecord.applyingState,
    );
    expect(await store.read(), isNull);
  });

  test('clear 之后读不到', () async {
    await store.save(
      undoId: 'undo-7',
      snapshotJson: snapshotJson(),
      state: SyncRollbackRecord.applyingState,
    );
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('没有记录时 read 返回 null（不抛）', () async {
    expect(await store.read(), isNull);
  });
}
