import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

/// GuardSource 自身的两道守卫。
///
/// 1. 口径一致性：快照物化（checkout-index）与工作区/索引对同一文件必须给出
///    同一行数 —— 行数棘轮在两种模式下才可比。工作区模式下样本有在途改动时
///    跳过（此时两边本就该不同）；快照模式下物化快照就是提交内容，任何样本
///    都应与索引 blob 一致，不存在跳过。
/// 2. 纪律扫描：test/architecture 的守卫一律经 GuardSource.resolve 读文件。
///    直读 File/Directory 会让守卫在工作区（混着别人的在途改动）上判定，
///    而不是在提交快照上 —— 快照机制就被绕过了。
void main() {
  test('索引内容与工作区/快照对同一文件行数一致（两种模式可比）', () {
    const samples = [
      'lib/models/class_reminder.dart',
      'lib/services/storage_service.dart',
      'test/architecture/god_file_unit_guard_test.dart',
    ];
    final snapshotMode =
        (Platform.environment['MIKCB_GUARD_SNAPSHOT'] ?? '').trim().isNotEmpty;
    var compared = 0;
    for (final path in samples) {
      // 工作区模式：样本有在途改动时跳过（两边本就该不同）。
      // 快照模式：物化快照就是提交内容，任何样本都应与索引 blob 一致，不存在跳过。
      if (!snapshotMode) {
        final status = Process.runSync('git', [
          'status',
          '--porcelain',
          '--',
          path,
        ]);
        expect(status.exitCode, 0, reason: 'git status 失败：${status.stderr}');
        if ((status.stdout as String).trim().isNotEmpty) {
          continue; // 该样本有在途改动，跳过（CI 干净检出下不会走到这里）
        }
      }
      final actualPath = snapshotMode ? GuardSource.resolve(path) : path;
      final actualLines = File(actualPath).readAsLinesSync().length;
      final blob = Process.runSync('git', ['show', ':$path'],
          stdoutEncoding: utf8);
      expect(blob.exitCode, 0, reason: '索引里没有 $path');
      final indexLines = const LineSplitter().convert(blob.stdout as String).length;
      expect(
        indexLines,
        actualLines,
        reason:
            '$path 索引/快照行数不一致（$indexLines vs $actualLines）——'
            '快照物化的行数口径与索引漂了，行数棘轮在两种模式下不可比。',
      );
      compared++;
    }
    if (!snapshotMode && compared == 0) {
      // 本地直跑、三个样本都在途脏：没有干净样本可比，跳过而不是误报。
      return;
    }
    expect(compared, greaterThanOrEqualTo(1), reason: '三个样本全被跳过，检查形同虚设');
  });

  test('守卫纪律：test/architecture 的守卫一律经 GuardSource.resolve 读文件', () {
    // \s* 必须放在 lookahead 里：放外面时贪心回溯会让 "File(\n  GuardSource..." 
    // 在中间空白处匹配成功（负 lookahead 在空格位置成立）。
    final directRead = RegExp(
      r'\b(File|Directory)\((?!\s*GuardSource\.resolve)',
    );
    final offenders = <String>[];
    for (final entity in Directory(
      GuardSource.resolve('test/architecture'),
    ).listSync()) {
      if (entity is! File || !entity.path.endsWith('_test.dart')) {
        continue;
      }
      if (entity.path.endsWith('guard_source_test.dart')) {
        continue; // 本文件自身（读守卫源码正是本测试的工作）
      }
      if (directRead.hasMatch(entity.readAsStringSync())) {
        offenders.add(GuardSource.repoRelative(entity.path));
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '这些守卫直读了文件系统：$offenders\n'
          '守卫测的是「这次提交」，不是工作区——pre-commit 会把提交快照物化到 '
          'MIKCB_GUARD_SNAPSHOT，直读 File/Directory 会绕过它，在工作区上判定'
          '（那里混着并行会话的在途改动，既会误伤也会被顶爆）。'
          '请把路径包进 GuardSource.resolve(...)；与仓库相对字面量比较的路径'
          '再过一层 GuardSource.repoRelative(...)。',
    );
  });
}
