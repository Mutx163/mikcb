/// 文案风格自查 CLI：`dart run tool/copy_style_lint.dart`
///
/// 只报不拦（永远退出 0）。**拦人是守卫的工作**
/// （`test/architecture/copy_style_guard_test.dart`）；这里的定位是
/// 「改文案之前先看一眼，别写完了才发现要返工」。
///
/// 用法：
/// - `dart run tool/copy_style_lint.dart`：列新增违规 + 死键；
/// - `--all`：连基线里已豁免的存量一起列（看全貌）；
/// - `--violations` / `--dead`：只看其中一类；
/// - `--baseline`：只列基线里「已不再违规」的项——一条都不剩时该清空基线；
/// - `--write-baseline`：把当前**存量**冻结进基线（只增不减地重写）。
///   只在「故意批量放过一批存量」时用，并把数量与理由写进提交信息。
library;

import 'dart:io';

import 'copy_style_rules.dart';

const _baselinePath = 'tool/copy_style_baseline.txt';
const _deadBaselinePath = 'tool/copy_style_dead_keys_baseline.txt';
const _restatingBaselinePath = 'tool/copy_style_restating_baseline.txt';

/// 开发者专用页：技术字段本来就长，且只对调试构建可见。
///
/// 与 `bfc6b6bf` 的取舍一致（「内存监测页 / HyperOS 展厅页——开发者页面，
/// 技术字段本就长」），但**不算基线豁免**：它们单独计数、单独打印，
/// 以后要收也看得见。
const _devOnlySources = <String>[
  'lib/screens/memory_stats_screen.dart',
  'lib/screens/hyperos_showcase_screen.dart',
  'lib/screens/miuix_showcase_screen.dart',
  'lib/screens/import/warehouse/warehouse_custom_debug_screen.dart',
  'lib/screens/live_diagnostics_log_viewer_screen.dart',
];

String _identity(String path) => path;

void main(List<String> args) {
  final wantViolations =
      !args.contains('--dead') || args.contains('--violations');
  final wantDead =
      !args.contains('--violations') || args.contains('--dead');
  final wantRestating = args.contains('--restating') ||
      (!args.contains('--dead') &&
          !args.contains('--violations') &&
          !args.contains('--restating'));
  final showAll = args.contains('--all');
  final baselineOnly = args.contains('--baseline');

  final arbByLocale = loadArbs(_identity);
  final sources = loadSources(_identity);
  final violations = findViolations(
    sources: sources,
    arbByLocale: arbByLocale,
  );
  final baseline = _loadBaseline();

  final devOnly = <CopyViolation>[];
  final live = <CopyViolation>[];
  for (final v in violations) {
    (_devOnlySources.contains(v.source) ? devOnly : live).add(v);
  }

  if (args.contains('--write-baseline')) {
    final ids = live.map(violationId).toSet().toList()..sort();
    _writeBaseline(ids);
    final template = arbByLocale['zh']!;
    final dead = findDeadKeys(
      template: template,
      codeCorpus: sources.values.join('\n'),
    ).toList()
      ..sort();
    _writeDeadBaseline(dead);
    stdout.writeln('已写入基线：${ids.length} 条超宽存量 → $_baselinePath');
    stdout.writeln('已写入基线：${dead.length} 条死键存量 → $_deadBaselinePath');
    stdout.writeln('（只冻结存量、不改变判据；请在提交信息里说明数量与理由）');
    exit(0);
  }

  if (baselineOnly) {
    final current = live.map(violationId).toSet();
    final stale = (baseline.difference(current).toList()..sort());
    stdout.writeln('基线里已不再违规的项（该清理的豁免）：${stale.length} 条');
    for (final id in stale) {
      stdout.writeln('  - $id');
    }
    exit(0);
  }

  if (wantViolations) {
    final unapproved =
        live.where((v) => !baseline.contains(violationId(v))).toList();
    final approved =
        live.where((v) => baseline.contains(violationId(v))).toList();
    stdout.writeln(
      '== 行内文案超宽：${live.length} 条'
      '（存量已冻结 ${approved.length}，新增 ${unapproved.length}）==',
    );
    for (final v in unapproved) {
      stdout.writeln('  ✗ $v');
    }
    if (unapproved.isEmpty) {
      stdout.writeln('  ✓ 没有新增违规');
    }
    if (showAll && approved.isNotEmpty) {
      stdout.writeln('  --- 基线里已冻结的存量（待逐批清理）---');
      for (final v in approved) {
        stdout.writeln('  · $v');
      }
    }
    if (devOnly.isNotEmpty) {
      stdout.writeln('  --- 开发者页 ${devOnly.length} 条（不计入）---');
      if (showAll) {
        for (final v in devOnly) {
          stdout.writeln('  · $v');
        }
      }
    }
  }

  if (wantDead) {
    final template = arbByLocale['zh']!;
    final dead = findDeadKeys(
      template: template,
      codeCorpus: sources.values.join('\n'),
    );
    final deadBaseline = _loadDeadBaseline();
    final added = dead.difference(deadBaseline).toList()..sort();
    stdout.writeln(
      '== 死键（ARB 有、代码从不引用）：${dead.length} 条'
      '（存量已冻结 ${dead.length - added.length}，新增 ${added.length}）==',
    );
    if (added.isNotEmpty) {
      for (final key in added) {
        stdout.writeln('  ✗ $key = ${template[key]}');
      }
    } else {
      stdout.writeln('  ✓ 没有新增死键');
    }
    if (showAll) {
      stdout.writeln('  --- 存量（逐族清理，清一条删一行基线）---');
      for (final key in (dead.intersection(deadBaseline).toList()..sort())) {
        stdout.writeln('  · $key = ${template[key]}');
      }
    }
  }

  if (wantRestating) {
    final restating = findRestatingSubtitles(
      sources: sources,
      arbByLocale: arbByLocale,
    );
    final frozen = _loadRestatingBaseline();
    final live = restating
        .where((v) => !_devOnlySources.contains(v.source))
        .toList();
    final added = live
        .where((v) => !frozen.contains(restatingId(v)))
        .toList();
    stdout.writeln(
      '== 说明句复述标题：${live.length} 条'
      '（存量已冻结 ${live.length - added.length}，新增 ${added.length}）==',
    );
    if (added.isNotEmpty) {
      for (final v in added) {
        stdout.writeln('  ✗ $v');
      }
    } else {
      stdout.writeln('  ✓ 没有新增复述');
    }
    if (showAll && live.isNotEmpty) {
      stdout.writeln('  --- 全部命中 ---');
      for (final v in live) {
        stdout.writeln('  · $v');
      }
    }
  }
}

void _writeDeadBaseline(List<String> keys) {
  final buffer = StringBuffer()
    ..writeln('# 死键：ARB 里有、但 lib/ 与 test/ 的代码从不引用（只减不增）')
    ..writeln('#')
    ..writeln('# 一行一个键名，按字典序。')
    ..writeln('# 判据见 tool/copy_style_rules.dart 的 findDeadKeys；守卫是')
    ..writeln('# test/architecture/copy_style_guard_test.dart。')
    ..writeln('#')
    ..writeln('# 同样是**待办清单不是豁免记录**：清掉一条删一行，不许加回来。')
    ..writeln('#')
    ..writeln('# 2026-10-21 立基线：539 条，横跨三轮 UI 重构（forui 迁移 /')
    ..writeln('# 设置页重排 / 入口目录化）。清理按前缀逐族做，一族的键一起删、')
    ..writeln('# 六份 ARB 同步删，跑 gen-l10n 后确认 dart analyze 干净。');
  for (final key in keys) {
    buffer.writeln(key);
  }
  File(_deadBaselinePath).writeAsStringSync(buffer.toString());
}

Set<String> _loadDeadBaseline() {
  final file = File(_deadBaselinePath);
  if (!file.existsSync()) {
    return <String>{};
  }
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

Set<String> _loadRestatingBaseline() {
  final file = File(_restatingBaselinePath);
  if (!file.existsSync()) {
    return <String>{};
  }
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

Set<String> _loadBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) {
    return <String>{};
  }
  return file
      .readAsLinesSync()
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toSet();
}

void _writeBaseline(List<String> ids) {
  final buffer = StringBuffer()
    ..writeln('# 行内文案超宽：已冻结的存量（逐批清理，只减不增）')
    ..writeln('#')
    ..writeln('# 格式：`语言/键名`，一行一条，按字典序。')
    ..writeln('# 判据与上限见 tool/copy_style_rules.dart；守卫是')
    ..writeln('# test/architecture/copy_style_guard_test.dart。')
    ..writeln('#')
    ..writeln('# 这份清单**不是豁免理由**，是待办：清掉一条就从这里删一行。')
    ..writeln('# 守卫只拦「新增」，所以清掉后不能把行加回来——加回来必红。')
    ..writeln('#')
    ..writeln('# 2026-10-21 立基线：202 条，其中中文仅 5 条、外语 197 条。');
  for (final id in ids) {
    buffer.writeln(id);
  }
  File(_baselinePath).writeAsStringSync(buffer.toString());
}
