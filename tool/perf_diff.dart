// A/B 帧率与能耗差分表。
//
// ## 它解决什么
//
// 探针在两个包里各采一份「每页帧账 + CPU/RSS 能耗代理」快照（JSON），本文件
// 把两份按页面 id 配对，算出每页的增减并给结论：到底是哪一页、在哪个相位、
// 是变卡还是更费电。用户问的是「这个版本加的东西让真实体验大范围下降」，
// 只有两版本同机同路径跑出来的差分才能回答，单份快照答不了。
//
// ## 三条判据口径（决定结论会不会骗人）
//
// 1. **样本下限**：一页只跑 5 帧时，janky 从 0 变 3 就是 60%「恶化」，但那是
//    噪音。帧数不足下限的页面标 `LOW_SAMPLE`，读数照给、不进恶化名单。
// 2. **只在两侧都存在的页上算增减**：head 新增页没有基线，比不出增减；
//    base 独有的页被删了也不算「变快」。这两类分别进 `added` / `removed`。
// 3. **缺读数 = null，不是 0**：0 会被读成「量过、没变化」，而真实含义是
//    「这一栏没量到」（未 root 的设备上 CPU 读数完全可能缺一侧）。
//    同理「判据不一致」必须顶到结论前面：一次跑 60Hz 空闲档、一次 120Hz
//    交互档时，两边的 janky 门槛根本不同，差出来的「恶化」可能只是阈值变了。
//
// 用法：`dart run tool/perf_diff.dart <base.json> <head.json> [--csv out.csv]`

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/perf_diff.dart <base.json> <head.json> '
        '[--csv <path>] [--min-frames <n>]');
    exit(64);
  }
  Map<String, Object?> load(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  final minFrames = _intFlag(args, '--min-frames');
  final diff = diffSnapshots(
    base: load(args[0]),
    head: load(args[1]),
    options: DiffOptions(minFrames: minFrames ?? 30),
  );
  stdout.write(formatDiffTable(diff));
  final csvPath = _stringFlag(args, '--csv');
  if (csvPath != null) {
    File(csvPath).writeAsStringSync(formatDiffCsv(diff));
    stdout.writeln('[perf-diff] csv written: $csvPath');
  }
}

int? _intFlag(List<String> args, String flag) =>
    int.tryParse(_stringFlag(args, flag) ?? '');

/// 取 `--flag <值>` 的值（不是数字，路径要原样留着）。
String? _stringFlag(List<String> args, String flag) {
  final i = args.indexOf(flag);
  if (i < 0 || i + 1 >= args.length) {
    return null;
  }
  return args[i + 1];
}

class DiffOptions {
  const DiffOptions({
    this.minFrames = 30,
    this.jankyPctDeltaThreshold = 5.0,
    this.cpuGrowthThresholdPct = 25.0,
  });

  /// 低于这个帧数的页面不进恶化名单（样本太小）。
  final int minFrames;

  /// 掉帧百分点涨这么多就算恶化（10% → 15% 记 +5.0）。
  final double jankyPctDeltaThreshold;

  /// CPU 时间相对增幅超过这个百分比算「更费电」。
  final double cpuGrowthThresholdPct;
}

class DiffRow {
  DiffRow({
    required this.pageId,
    required this.baseFrames,
    required this.headFrames,
    required this.baseJankyPct,
    required this.headJankyPct,
    required this.jankyPctDelta,
    required this.baseFps,
    required this.headFps,
    required this.fpsDelta,
    required this.baseCpuMs,
    required this.headCpuMs,
    required this.cpuGrowthPct,
    required this.lowSample,
    required this.status,
    this.skippedReason,
  });

  final String pageId;
  final int? baseFrames;
  final int? headFrames;
  final double? baseJankyPct;
  final double? headJankyPct;
  final double? jankyPctDelta;
  final double? baseFps;
  final double? headFps;
  final double? fpsDelta;
  final double? baseCpuMs;
  final double? headCpuMs;
  final double? cpuGrowthPct;
  final bool lowSample;

  /// `REGRESSED` / `IMPROVED` / `FLAT` / `LOW_SAMPLE` / `SKIPPED`。
  final String status;

  /// 非空表示这一行数字不可比（缺读数或读数坏掉），原因写在这里。
  final String? skippedReason;

  bool get isRegressed => status == 'REGRESSED';
}

class DiffSummary {
  DiffSummary({
    required this.baseFrames,
    required this.headFrames,
    required this.baseJankyPct,
    required this.headJankyPct,
    required this.jankyPctDelta,
  });

  final int baseFrames;
  final int headFrames;
  final double baseJankyPct;
  final double headJankyPct;
  final double jankyPctDelta;
}

class DiffResult {
  DiffResult({
    required this.baseVersion,
    required this.headVersion,
    required this.rows,
    required this.added,
    required this.removed,
    required this.summary,
    required this.comparabilityWarnings,
  });

  final String baseVersion;
  final String headVersion;

  /// **只有两侧都存在的页面**：增减与结论都算在这里。
  final List<DiffRow> rows;

  /// 仅 head 有（新增页，无基线可比）。
  final List<DiffRow> added;

  /// 仅 base 有（被删/改名的页）。
  final List<DiffRow> removed;

  final DiffSummary summary;

  /// 口径不一致的警告（预算不同 = 帧率增减不可比）。非空时结论必须打折看。
  final List<String> comparabilityWarnings;

  List<DiffRow> get regressed => rows.where((r) => r.isRegressed).toList();

  bool get sameBuild => baseVersion == headVersion;
}

DiffResult diffSnapshots({
  required Map<String, Object?> base,
  required Map<String, Object?> head,
  DiffOptions options = const DiffOptions(),
}) {
  final basePages = _pagesById(base);
  final headPages = _pagesById(head);

  final rows = <DiffRow>[];
  final added = <DiffRow>[];
  final removed = <DiffRow>[];

  for (final id in _orderedIds(basePages, headPages)) {
    final b = basePages[id];
    final h = headPages[id];
    if (b == null && h != null) {
      added.add(_oneSided(id, h, 'ADDED'));
    } else if (h == null && b != null) {
      removed.add(_oneSided(id, b, 'REMOVED'));
    } else if (b != null && h != null) {
      rows.add(_paired(id, b, h, options));
    }
  }

  return DiffResult(
    baseVersion: '${base['appVersion'] ?? '?'}',
    headVersion: '${head['appVersion'] ?? '?'}',
    rows: rows,
    added: added,
    removed: removed,
    summary: _summary(base, head),
    comparabilityWarnings: _warnings(base, head),
  );
}

Map<String, Map<String, Object?>> _pagesById(Map<String, Object?> snapshot) {
  final result = <String, Map<String, Object?>>{};
  final pages = snapshot['pages'];
  if (pages is! List) {
    return result; // 缺键 / 结构不对：当成没有数据，而不是抛。
  }
  for (final entry in pages) {
    if (entry is! Map) {
      continue;
    }
    final row = Map<String, Object?>.from(entry);
    final id = row['page'];
    if (id is String && id.isNotEmpty) {
      result[id] = row;
    }
  }
  return result;
}

/// 行序 = base 出现顺序优先、再补 head 独有的，保证两次跑出的表行序一致
/// （差分表要能左右对读，行序漂一次就得重看整张表）。
List<String> _orderedIds(
  Map<String, Map<String, Object?>> base,
  Map<String, Map<String, Object?>> head,
) {
  final ids = <String>[...base.keys];
  for (final id in head.keys) {
    if (!ids.contains(id)) {
      ids.add(id);
    }
  }
  return ids;
}

DiffRow _paired(
  String id,
  Map<String, Object?> b,
  Map<String, Object?> h,
  DiffOptions options,
) {
  final baseFrames = _int(b['frames']);
  final headFrames = _int(h['frames']);
  final baseJanky = _int(b['janky']);
  final headJanky = _int(h['janky']);

  if (baseFrames == null || headFrames == null) {
    // 读数坏掉（缺字段 / 类型不对）时**不做任何计算**：拿 0 去算会把
    // 「没量到」显示成 100% 恶化，那比缺一行危险得多。
    return DiffRow(
      pageId: id,
      baseFrames: baseFrames,
      headFrames: headFrames,
      baseJankyPct: null,
      headJankyPct: null,
      jankyPctDelta: null,
      baseFps: _double(b['fps']),
      headFps: _double(h['fps']),
      fpsDelta: null,
      baseCpuMs: _double(b['cpuMs']),
      headCpuMs: _double(h['cpuMs']),
      cpuGrowthPct: null,
      lowSample: false,
      status: 'SKIPPED',
      skippedReason: 'frames unreadable on ${baseFrames == null ? 'base' : 'head'}',
    );
  }

  final basePct = _pct(baseJanky, baseFrames);
  final headPct = _pct(headJanky, headFrames);
  final jankyDelta = (basePct != null && headPct != null) ? headPct - basePct : null;

  final baseFps = _double(b['fps']);
  final headFps = _double(h['fps']);
  final fpsDelta = (baseFps != null && headFps != null) ? headFps - baseFps : null;

  final baseCpu = _double(b['cpuMs']);
  final headCpu = _double(h['cpuMs']);
  // 增幅按 base 归一：base 为 0 或缺失都算不出（除零不是「无限大」）。
  final cpuGrowth = (baseCpu != null && headCpu != null && baseCpu > 0)
      ? (headCpu - baseCpu) * 100 / baseCpu
      : null;

  final lowSample =
      baseFrames < options.minFrames || headFrames < options.minFrames;

  final jankyBad = jankyDelta != null &&
      jankyDelta >= options.jankyPctDeltaThreshold;
  final cpuBad = cpuGrowth != null && cpuGrowth >= options.cpuGrowthThresholdPct;
  final jankyGood = jankyDelta != null &&
      jankyDelta <= -options.jankyPctDeltaThreshold;
  final cpuGood = cpuGrowth != null && cpuGrowth <= -options.cpuGrowthThresholdPct;

  String status;
  if (jankyBad || cpuBad) {
    status = 'REGRESSED';
  } else if (jankyGood || cpuGood) {
    status = 'IMPROVED';
  } else if (lowSample) {
    status = 'LOW_SAMPLE';
  } else {
    status = 'FLAT';
  }
  // 样本不足时结论一律降级：读数留在表里（看得见），但不当恶化/改善说。
  if (lowSample && (jankyBad || cpuBad || jankyGood || cpuGood)) {
    status = 'LOW_SAMPLE';
  }

  return DiffRow(
    pageId: id,
    baseFrames: baseFrames,
    headFrames: headFrames,
    baseJankyPct: basePct,
    headJankyPct: headPct,
    jankyPctDelta: jankyDelta,
    baseFps: baseFps,
    headFps: headFps,
    fpsDelta: fpsDelta,
    baseCpuMs: baseCpu,
    headCpuMs: headCpu,
    cpuGrowthPct: cpuGrowth,
    lowSample: lowSample,
    status: status,
  );
}

/// 构造单侧行（ADDED / REMOVED）。
///
/// 所有读数都必须落在「这一页真实存在的那一侧」：把新增页的 fps 填进 base 栏，
/// 读表的人会得出「旧版本这一页是 45fps」的结论 —— 而旧版本里这页根本不存在。
/// frames 先踩过这个坑（已按侧分栏），其余字段必须同口径：一列对得上、另一列
/// 对不上，比整列都缺更难查。
DiffRow _oneSided(String id, Map<String, Object?> row, String status) {
  final onBase = status == 'REMOVED';
  final frames = _int(row['frames']);
  final jankyPct = _pct(_int(row['janky']), frames);
  final fps = _double(row['fps']);
  final cpu = _double(row['cpuMs']);
  return DiffRow(
    pageId: id,
    baseFrames: onBase ? frames : null,
    headFrames: onBase ? null : frames,
    baseJankyPct: onBase ? jankyPct : null,
    headJankyPct: onBase ? null : jankyPct,
    // 单侧没有「增减」：给 0 会被读成「没变化」，而真实含义是没得比。
    jankyPctDelta: null,
    baseFps: onBase ? fps : null,
    headFps: onBase ? null : fps,
    fpsDelta: null,
    baseCpuMs: onBase ? cpu : null,
    headCpuMs: onBase ? null : cpu,
    cpuGrowthPct: null,
    lowSample: false,
    status: status,
  );
}

DiffSummary _summary(Map<String, Object?> base, Map<String, Object?> head) {
  final bt = _totals(base);
  final ht = _totals(head);
  final basePct = _pct(bt.janky, bt.frames) ?? 0;
  final headPct = _pct(ht.janky, ht.frames) ?? 0;
  return DiffSummary(
    baseFrames: bt.frames,
    headFrames: ht.frames,
    baseJankyPct: basePct,
    headJankyPct: headPct,
    jankyPctDelta: headPct - basePct,
  );
}

class _Totals {
  _Totals({required this.frames, required this.janky});
  final int frames;
  final int janky;
}

_Totals _totals(Map<String, Object?> snapshot) {
  var frames = 0;
  var janky = 0;
  final pages = snapshot['pages'];
  if (pages is List) {
    for (final entry in pages) {
      if (entry is! Map) {
        continue;
      }
      final row = Map<String, Object?>.from(entry);
      frames += _int(row['frames']) ?? 0;
      janky += _int(row['janky']) ?? 0;
    }
  }
  return _Totals(frames: frames, janky: janky);
}

/// 口径一致性检查。不通过时必须把警告顶到结论前面。
List<String> _warnings(Map<String, Object?> base, Map<String, Object?> head) {
  final warnings = <String>[];
  final bp = _probe(base);
  final hp = _probe(head);
  final bBudget = bp['budgetMs'];
  final hBudget = hp['budgetMs'];
  if (bBudget is String && hBudget is String && bBudget != hBudget) {
    warnings.add(
      'budgetMs differs (base=$bBudget head=$hBudget): the janky threshold '
      'itself changed between runs, so janky deltas are NOT comparable',
    );
  }
  final bRate = base['refreshRateHz'];
  final hRate = head['refreshRateHz'];
  if (bRate is num && hRate is num && bRate != hRate) {
    warnings.add('refreshRateHz differs (base=$bRate head=$hRate)');
  }
  if (base['appVersion'] == head['appVersion']) {
    warnings.add(
      'same appVersion on both sides (${base['appVersion']}): this diff is a '
      'no-op unless two builds were genuinely swapped',
    );
  }
  return warnings;
}

Map<String, Object?> _probe(Map<String, Object?> snapshot) {
  final probe = snapshot['probe'];
  return probe is Map
      ? Map<String, Object?>.from(probe)
      : const <String, Object?>{};
}

double? _pct(int? janky, int? frames) {
  if (janky == null || frames == null || frames == 0) {
    return null;
  }
  return janky * 100 / frames;
}

int? _int(Object? value) => value is int ? value : null;

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

String _num(double? value, {String nullText = '-'}) =>
    value == null ? nullText : value.toStringAsFixed(1);

String formatDiffTable(DiffResult diff) {
  final buffer = StringBuffer();
  buffer.writeln(
    '[perf-diff] base=${diff.baseVersion} head=${diff.headVersion} '
    'totalJanky ${_num(diff.summary.baseJankyPct)}% -> '
    '${_num(diff.summary.headJankyPct)}% '
    '(delta ${_signed(diff.summary.jankyPctDelta)}pp) '
    'frames ${diff.summary.baseFrames} -> ${diff.summary.headFrames}',
  );
  for (final warning in diff.comparabilityWarnings) {
    buffer.writeln('[perf-diff] WARNING $warning');
  }
  final sorted = [...diff.rows]..sort(_bySeverity);
  for (final row in sorted) {
    buffer.writeln(
      '[perf-diff] page=${row.pageId} status=${row.status} '
      'jankyPct ${_num(row.baseJankyPct)}->${_num(row.headJankyPct)} '
      'delta=${_signed(row.jankyPctDelta)}pp '
      'fps ${_num(row.baseFps)}->${_num(row.headFps)} '
      'cpu ${_num(row.baseCpuMs)}->${_num(row.headCpuMs)}ms '
      'cpuGrow=${_signed(row.cpuGrowthPct)}% '
      'frames ${row.baseFrames}->${row.headFrames}'
      '${row.skippedReason == null ? '' : ' skip=${row.skippedReason}'}',
    );
  }
  for (final row in diff.added) {
    buffer.writeln('[perf-diff] page=${row.pageId} status=ADDED '
        'headFrames=${row.headFrames} (no baseline, not comparable)');
  }
  for (final row in diff.removed) {
    buffer.writeln('[perf-diff] page=${row.pageId} status=REMOVED '
        'baseFrames=${row.baseFrames} (gone in head)');
  }
  return buffer.toString();
}

String _signed(double? value) {
  if (value == null) {
    return '-';
  }
  return (value >= 0 ? '+' : '') + value.toStringAsFixed(1);
}

/// 排序：先看能不能算（SKIPPED 垫底），再看恶化幅度，最后按页名保证稳定。
int _bySeverity(DiffRow a, DiffRow b) {
  final rank = _statusRank(a) - _statusRank(b);
  if (rank != 0) {
    return rank;
  }
  // 算不出增减（SKIPPED / 单侧）按 -1e9 垫到最后：它们不该插进"最恶化"里。
  final av = a.jankyPctDelta ?? -1e9;
  final bv = b.jankyPctDelta ?? -1e9;
  final byDelta = bv.compareTo(av);
  if (byDelta != 0) {
    return byDelta;
  }
  return a.pageId.compareTo(b.pageId);
}

int _statusRank(DiffRow row) => switch (row.status) {
  'REGRESSED' => 0,
  'IMPROVED' => 1,
  'LOW_SAMPLE' => 2,
  'FLAT' => 3,
  _ => 4,
};

const List<String> _csvHeader = <String>[
  'page',
  'base_frames',
  'head_frames',
  'base_janky_pct',
  'head_janky_pct',
  'janky_pct_delta',
  'base_fps',
  'head_fps',
  'fps_delta',
  'base_cpu_ms',
  'head_cpu_ms',
  'cpu_growth_pct',
  'low_sample',
  'status',
];

String formatDiffCsv(DiffResult diff) {
  final lines = <String>[_csvHeader.join(',')];
  final all = <DiffRow>[...diff.rows, ...diff.added, ...diff.removed]
    ..sort(_bySeverity);
  for (final row in all) {
    lines.add([
      _csvCell(row.pageId),
      _csvNum(row.baseFrames),
      _csvNum(row.headFrames),
      _csvValue(row.baseJankyPct),
      _csvValue(row.headJankyPct),
      _csvValue(row.jankyPctDelta),
      _csvValue(row.baseFps),
      _csvValue(row.headFps),
      _csvValue(row.fpsDelta),
      _csvValue(row.baseCpuMs),
      _csvValue(row.headCpuMs),
      _csvValue(row.cpuGrowthPct),
      row.lowSample ? 'true' : 'false',
      row.status,
    ].join(','));
  }
  return lines.join('\n');
}

/// 页面名可能含逗号（深链路径型名字），必须加引号，否则整列错位。
String _csvCell(String value) =>
    value.contains(',') || value.contains('"')
    ? '"${value.replaceAll('"', '""')}"'
    : value;

String _csvValue(double? value) => value == null ? '' : value.toStringAsFixed(1);

String _csvNum(int? value) => value == null ? '' : '$value';
