import 'package:flutter/foundation.dart';

enum DiagnosticsLogLevel { all, error, warn, info, debug, verbose }

// 解析热路径的正则一律提为常量：日志文件动辄几千行/几千条，若在循环里
// 每次 new RegExp，一次全量解析就要构造上万次正则（debug/JIT 下是秒级开销，
// 且 watchMergedLogsText 的轮询会反复触发），这是日志页打开卡死的元凶之一。
final RegExp diagnosticsBodySeparatorRegex = RegExp(
  r'\n----\n|\r\n----\r\n|\n----\r\n|\r\n----\n',
);
final RegExp _logLineSplitRegex = RegExp(r'\r?\n');
final RegExp _logKvLineRegex = RegExp(r'^([A-Za-z0-9_.-]+)=(.*)$');
final RegExp _logErrorHintRegex = RegExp(
  r'\b(error|exception|crash|fatal|failed|failure)\b',
);
final RegExp _logWarnHintRegex = RegExp(
  r'\b(warn|warning|denied|blocked|invalid|missing)\b',
);
final RegExp _logVerboseHintRegex = RegExp(r'\b(verbose|trace)\b');
final RegExp _logDebugHintRegex = RegExp(
  r'\b(debug|diagnostic|snapshot|payload|test)\b',
);

@immutable
class DiagnosticsLogEntry {
  final String rawBlock;
  final Map<String, String> fields;
  final DiagnosticsLogLevel level;
  final bool isLevelInferred;

  const DiagnosticsLogEntry({
    required this.rawBlock,
    required this.fields,
    required this.level,
    required this.isLevelInferred,
  });

  String get category => fields['category']?.trim() ?? '';

  String get message => fields['message']?.trim() ?? rawBlock.trim();

  String get sourceKey {
    final explicit = fields['source']?.trim();
    if (explicit == 'app' || explicit == 'native') {
      return explicit!;
    }
    final categoryLower = category.toLowerCase();
    if (categoryLower.startsWith('live_update') ||
        categoryLower.startsWith('miui_live') ||
        categoryLower.startsWith('diagnostics_')) {
      return 'native';
    }
    return 'app';
  }

  bool get isNativeSource => sourceKey == 'native';

  String? get formattedTime => formatDiagnosticsMillis(fields['time']);

  int get timeMillis => int.tryParse(fields['time'] ?? '') ?? 0;

  Iterable<MapEntry<String, String>> get detailEntries => fields.entries.where(
    (entry) => !const {
      'time',
      'category',
      'message',
      'level',
      'severity',
      'source',
    }.contains(entry.key),
  );

  String get stableId => '$timeMillis|${category.hashCode}|${message.hashCode}';
}

@immutable
class DiagnosticsLogSnapshot {
  final String title;
  final String rawHeader;
  final String fullText;
  final Map<String, String> headerEntries;
  final List<DiagnosticsLogEntry> entries;

  const DiagnosticsLogSnapshot({
    required this.title,
    required this.rawHeader,
    required this.fullText,
    required this.headerEntries,
    required this.entries,
  });

  static const empty = DiagnosticsLogSnapshot(
    title: '',
    rawHeader: '',
    fullText: '',
    headerEntries: <String, String>{},
    entries: <DiagnosticsLogEntry>[],
  );

  DiagnosticsLogSnapshot copyWith({
    String? title,
    String? rawHeader,
    String? fullText,
    Map<String, String>? headerEntries,
    List<DiagnosticsLogEntry>? entries,
  }) {
    return DiagnosticsLogSnapshot(
      title: title ?? this.title,
      rawHeader: rawHeader ?? this.rawHeader,
      fullText: fullText ?? this.fullText,
      headerEntries: headerEntries ?? this.headerEntries,
      entries: entries ?? this.entries,
    );
  }
}

DiagnosticsLogSnapshot parseDiagnosticsLog(
  String rawLog, {
  String fallbackTitle = '',
}) {
  final normalizedText = rawLog.trim();
  if (normalizedText.isEmpty) {
    return DiagnosticsLogSnapshot(
      title: fallbackTitle,
      rawHeader: '',
      fullText: '',
      headerEntries: const <String, String>{},
      entries: const <DiagnosticsLogEntry>[],
    );
  }

  final lines = normalizedText.split(_logLineSplitRegex);
  final separatorIndex = lines.indexWhere((line) => line.trim() == '----');
  final headerLines = separatorIndex >= 0
      ? lines.take(separatorIndex).toList(growable: false)
      : <String>[];
  final bodyLines = separatorIndex >= 0
      ? lines.skip(separatorIndex + 1).toList(growable: false)
      : lines;
  final headerEntries = _parseIndentedKeyValueBlock(
    headerLines.skip(1).toList(growable: false),
  );
  final rawSections = _splitDiagnosticSections(bodyLines);
  final entries = rawSections
      .map(_parseDiagnosticsLogEntry)
      .whereType<DiagnosticsLogEntry>()
      .toList(growable: false);

  return DiagnosticsLogSnapshot(
    title: headerLines.isNotEmpty
        ? headerLines.first.trim()
        : (fallbackTitle.isNotEmpty ? fallbackTitle : 'Diagnostics Log'),
    rawHeader: headerLines.join('\n').trim(),
    fullText: normalizedText,
    headerEntries: headerEntries,
    entries: entries,
  );
}

DiagnosticsLogSnapshot parseDiagnosticsLogIsolate(String rawLog) {
  return parseDiagnosticsLog(rawLog);
}

String extractDiagnosticsLogBody(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return '';
  }
  final parts = normalized.split(diagnosticsBodySeparatorRegex);
  if (parts.length <= 1) {
    return normalized;
  }
  return parts.sublist(1).join('\n----\n').trim();
}

List<DiagnosticsLogEntry> parseDiagnosticsLogSections(String bodyText) {
  final normalized = bodyText.trim();
  if (normalized.isEmpty) {
    return const <DiagnosticsLogEntry>[];
  }
  final lines = normalized.split(_logLineSplitRegex);
  return _splitDiagnosticSections(lines)
    .map(_parseDiagnosticsLogEntry)
    .whereType<DiagnosticsLogEntry>()
    .toList(growable: false);
}

DiagnosticsLogSnapshot appendDiagnosticsLogBody(
  DiagnosticsLogSnapshot current,
  String appendedBody, {
  required String mergedFullText,
}) {
  if (appendedBody.trim().isEmpty) {
    return current.copyWith(fullText: mergedFullText);
  }
  final newEntries = parseDiagnosticsLogSections(appendedBody);
  if (newEntries.isEmpty) {
    return current.copyWith(fullText: mergedFullText);
  }
  return current.copyWith(
    fullText: mergedFullText,
    entries: [...current.entries, ...newEntries],
  );
}

String buildFilteredDiagnosticsRawText(
  DiagnosticsLogSnapshot parsed,
  List<DiagnosticsLogEntry> filteredEntries,
) {
  final blocks = filteredEntries
      .map((entry) => entry.rawBlock.trim())
      .join('\n\n');
  if (parsed.rawHeader.isEmpty) {
    return blocks;
  }
  if (blocks.isEmpty) {
    return parsed.rawHeader;
  }
  return '${parsed.rawHeader}\n----\n$blocks'.trim();
}

List<DiagnosticsLogEntry> filterDiagnosticsEntries(
  List<DiagnosticsLogEntry> entries,
  DiagnosticsLogLevel level,
) {
  if (level == DiagnosticsLogLevel.all) {
    return entries;
  }
  return entries
      .where((entry) => entry.level == level)
      .toList(growable: false);
}

List<DiagnosticsLogEntry> sortDiagnosticsEntries(
  List<DiagnosticsLogEntry> entries, {
  required bool ascending,
}) {
  final sorted = entries.toList(growable: true);
  sorted.sort((a, b) {
    final cmp = a.timeMillis.compareTo(b.timeMillis);
    return ascending ? cmp : -cmp;
  });
  return sorted;
}

Map<DiagnosticsLogLevel, int> countDiagnosticsLevels(
  List<DiagnosticsLogEntry> entries,
) {
  final counts = <DiagnosticsLogLevel, int>{
    DiagnosticsLogLevel.all: entries.length,
    DiagnosticsLogLevel.error: 0,
    DiagnosticsLogLevel.warn: 0,
    DiagnosticsLogLevel.info: 0,
    DiagnosticsLogLevel.debug: 0,
    DiagnosticsLogLevel.verbose: 0,
  };
  for (final entry in entries) {
    counts[entry.level] = (counts[entry.level] ?? 0) + 1;
  }
  return counts;
}

String? formatDiagnosticsMillis(String? raw) {
  final millis = int.tryParse(raw ?? '');
  if (millis == null) {
    return null;
  }
  final dateTime = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} ${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
}

List<List<String>> _splitDiagnosticSections(List<String> lines) {
  final sections = <List<String>>[];
  var current = <String>[];

  for (final line in lines) {
    if (line.trim().isEmpty) {
      if (current.isNotEmpty) {
        sections.add(current);
        current = <String>[];
      }
      continue;
    }
    current.add(line);
  }

  if (current.isNotEmpty) {
    sections.add(current);
  }

  return sections;
}

DiagnosticsLogEntry? _parseDiagnosticsLogEntry(List<String> lines) {
  final rawBlock = lines.join('\n').trimRight();
  if (rawBlock.isEmpty) {
    return null;
  }

  final fields = _parseIndentedKeyValueBlock(lines);
  final normalizedFields = fields.isEmpty
      ? <String, String>{'message': rawBlock}
      : Map<String, String>.from(fields);
  final explicitLevel = _parseDiagnosticsLogLevel(
    normalizedFields['level'] ?? normalizedFields['severity'],
  );
  final level =
      explicitLevel ?? _inferDiagnosticsLogLevel(normalizedFields, rawBlock);

  return DiagnosticsLogEntry(
    rawBlock: rawBlock,
    fields: normalizedFields,
    level: level,
    isLevelInferred: explicitLevel == null,
  );
}

Map<String, String> _parseIndentedKeyValueBlock(List<String> lines) {
  final result = <String, String>{};
  String? currentKey;
  final currentValue = StringBuffer();

  void commit() {
    if (currentKey == null) {
      return;
    }
    result[currentKey!] = currentValue.toString().trimRight();
    currentKey = null;
    currentValue.clear();
  }

  for (final line in lines) {
    final match = _logKvLineRegex.firstMatch(line);
    if (match != null && !line.startsWith('  ')) {
      commit();
      currentKey = match.group(1);
      currentValue.write(match.group(2)?.trimLeft() ?? '');
      continue;
    }

    if (currentKey == null) {
      continue;
    }

    final normalized = line.startsWith('  ') ? line.substring(2) : line;
    if (currentValue.isNotEmpty) {
      currentValue.writeln();
    }
    currentValue.write(normalized);
  }

  commit();
  return result;
}

DiagnosticsLogLevel? _parseDiagnosticsLogLevel(String? raw) {
  final normalized = (raw ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'error':
    case 'err':
    case 'fatal':
      return DiagnosticsLogLevel.error;
    case 'warn':
    case 'warning':
      return DiagnosticsLogLevel.warn;
    case 'info':
      return DiagnosticsLogLevel.info;
    case 'debug':
      return DiagnosticsLogLevel.debug;
    case 'verbose':
    case 'trace':
      return DiagnosticsLogLevel.verbose;
    case 'all':
      return DiagnosticsLogLevel.all;
    default:
      return null;
  }
}

DiagnosticsLogLevel _inferDiagnosticsLogLevel(
  Map<String, String> fields,
  String rawBlock,
) {
  final haystack = [
    rawBlock,
    fields['category'],
    fields['message'],
    fields['throwable'],
    fields['stackTrace'],
    fields['truncatedHint'],
  ].whereType<String>().join('\n').toLowerCase();

  if (fields.containsKey('throwable') ||
      fields.containsKey('stackTrace') ||
      _logErrorHintRegex.hasMatch(haystack)) {
    return DiagnosticsLogLevel.error;
  }
  if (_logWarnHintRegex.hasMatch(haystack)) {
    return DiagnosticsLogLevel.warn;
  }
  if (_logVerboseHintRegex.hasMatch(haystack)) {
    return DiagnosticsLogLevel.verbose;
  }
  if (_logDebugHintRegex.hasMatch(haystack)) {
    return DiagnosticsLogLevel.debug;
  }
  return DiagnosticsLogLevel.info;
}
