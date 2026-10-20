/// 架构棘：test/widgets、test/screens、test/ui 是**冻结目录**。
///
/// AGENTS.md 的 TEST-POLICY 写明：这三处的存量测试一律保留（它们是廉价的
/// 回归网、不删不改），但**不许再新增**。理由不是「测试太多」，而是测试全押在
/// 不提供独立证据的那一层 —— widget/ui 测试改一行 UI 就可能红一片，而真机
/// 路径那一层（integration_test/）至今是空的。
///
/// 此前只有口头纪律：10-05 起这三处又新增了 17 个文件（10-10 审计记的是 16）。
/// 本守卫把它变成强制点。
///
/// 基线是本目录的 frozen_test_dirs_baseline.txt，一行一个仓库根相对路径。
/// - 允许**减少**（删测试要单独 review，通常伴随功能下线）；
/// - 不允许**新增**：新测试请写 integration_test/ 或
///   test/{services,domain,models,utils}/（纯逻辑层）。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guard_source.dart';

const _frozenDirs = <String>['test/widgets', 'test/screens', 'test/ui'];

String _normalize(String path) => path.replaceAll(r'\', '/');

Set<String> _actualFrozenTestFiles() {
  final files = <String>{};
  for (final dir in _frozenDirs) {
    final directory = Directory(GuardSource.resolve(dir));
    if (!directory.existsSync()) {
      continue;
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      // repoRelative 归一：快照模式下 listSync 给的是绝对路径，
      // 与基线（仓库相对）的集合比较只有归一后才成立。
      final path = GuardSource.repoRelative(entity.path);
      if (path.endsWith('.dart')) {
        files.add(path);
      }
    }
  }
  return files;
}

Set<String> _loadBaseline() {
  final file = File(
    GuardSource.resolve('test/architecture/frozen_test_dirs_baseline.txt'),
  );
  if (!file.existsSync()) {
    fail('冻结目录基线文件不存在：${file.path}');
  }
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(_normalize)
      .toSet();
}

void main() {
  test('冻结目录 baseline 自身合法（有序、无重复、只含三类目录）', () {
    final file = File(
      GuardSource.resolve('test/architecture/frozen_test_dirs_baseline.txt'),
    );
    final lines = file
        .readAsLinesSync()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    expect(
      lines.length,
      lines.toSet().length,
      reason: '基线文件有重复行，会让「新增」判断失真',
    );
    expect(lines, equals([...lines]..sort()), reason: '基线文件必须按字典序，diff 才干净');
    for (final line in lines) {
      expect(
        _frozenDirs.any((dir) => line.startsWith('$dir/')),
        isTrue,
        reason: '$line 不属于任何冻结目录，基线被污染',
      );
      expect(line.endsWith('_test.dart'), isTrue, reason: '$line 不是测试文件');
    }
  });

  test('冻结目录不许新增测试文件（只减不增）', () {
    final baseline = _loadBaseline();
    final actual = _actualFrozenTestFiles();

    final added = actual.difference(baseline).toList()..sort();
    final removed = baseline.difference(actual).toList()..sort();

    // 减少是允许的（删测试要单独 review）；把它打出来便于同步基线。
    if (removed.isNotEmpty) {
      // ignore: avoid_print
      print('冻结目录测试减少 ${removed.length} 个（记得同步基线文件）：');
      for (final path in removed) {
        // ignore: avoid_print
        print('  - $path');
      }
    }

    expect(
      added,
      isEmpty,
      reason:
          'test/widgets、test/screens、test/ui 已冻结，不许再新增测试（见 AGENTS.md '
          'TEST-POLICY）。${added.length} 个新文件：\n'
          '${added.map((path) => '  + $path').join('\n')}\n'
          '纯逻辑测试请放 test/services/、test/domain/、test/models/、test/utils/；'
          '端到端验证请放 integration_test/。真要在冻结目录新增，必须先改 '
          'TEST-POLICY 与 baseline，并说明为什么这一层能提供独立证据。',
    );
  });
}
