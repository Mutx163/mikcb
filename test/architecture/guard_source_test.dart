import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

/// GuardSource 自身的两道守卫。
///
/// 1. 口径一致性：快照物化（checkout-index）与工作区直读对同一文件必须给出
///    同一行数 —— 行数棘轮在两种模式下才可比。样本文件有在途改动时跳过
///    （此时两边本就该不同）；CI 干净检出下三个样本全比。
/// 2. 纪律扫描：test/architecture 的守卫一律经 GuardSource.resolve 读文件。
///    直读 File/Directory 会让守卫在工作区（混着别人的在途改动）上判定，
///    而不是在提交快照上 —— 快照机制就被绕过了。
void main() {
  test('索引内容与工作区对干净文件行数一致（两种模式可比）', () {
    const samples = [
      'lib/models/class_reminder.dart',
      'lib/services/storage_service.dart',
      'test/architecture/god_file_unit_guard_test.dart',
    ];
    var compared = 0;
    for (final path in samples) {
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
      final worktreeLines = File(path).readAsLinesSync().length;
      final blob = Process.runSync('git', ['show', ':$path']);
      expect(blob.exitCode, 0, reason: '索引里没有 $path');
      final indexLines = const LineSplitter().convert(blob.stdout as String).length;
      expect(
        indexLines,
        worktreeLines,
        reason:
            '$path 索引/工作区行数不一致（$indexLines vs $worktreeLines）——'
            '快照物化的行数口径与工作区漂了，行数棘轮在两种模式下不可比。',
      );
      compared++;
    }
    expect(compared, greaterThanOrEqualTo(1), reason: '三个样本全被跳过，检查形同虚设');
  });

  test('守卫纪律：test/architecture 的守卫一律经 GuardSource.resolve 读文件', () {
    const directRead = RegExp(
      r'\b(File|Directory)\(\s*(?!GuardSource\.resolve)',
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
