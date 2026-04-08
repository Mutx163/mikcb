import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

enum DiagnosticsLogViewMode {
  markdown,
  raw,
}

class LiveDiagnosticsLogViewerScreen extends StatefulWidget {
  final String title;
  final String rawLog;

  const LiveDiagnosticsLogViewerScreen({
    super.key,
    required this.title,
    required this.rawLog,
  });

  @override
  State<LiveDiagnosticsLogViewerScreen> createState() =>
      _LiveDiagnosticsLogViewerScreenState();
}

class _LiveDiagnosticsLogViewerScreenState
    extends State<LiveDiagnosticsLogViewerScreen> {
  DiagnosticsLogViewMode _viewMode = DiagnosticsLogViewMode.markdown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final markdown = buildDiagnosticsMarkdown(widget.rawLog);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.diagnosticsLogIntro,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<DiagnosticsLogViewMode>(
                segments: [
                  ButtonSegment(
                    value: DiagnosticsLogViewMode.markdown,
                    icon: Icon(Icons.article_outlined),
                    label: Text('Markdown'),
                  ),
                  ButtonSegment(
                    value: DiagnosticsLogViewMode.raw,
                    icon: Icon(Icons.code_rounded),
                    label: Text(l10n.diagnosticsRawTab),
                  ),
                ],
                selected: <DiagnosticsLogViewMode>{_viewMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _viewMode = selection.first;
                  });
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _viewMode == DiagnosticsLogViewMode.markdown
                ? Markdown(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    data: markdown,
                    selectable: true,
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    child: SelectableText(
                      widget.rawLog,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.45,
                          ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String buildDiagnosticsMarkdown(String rawLog) {
  final zh = _DiagnosticsL10nFallback();
  final text = rawLog.trim();
  if (text.isEmpty) {
    return '# ${zh.emptyTitle}\n\n${zh.emptySubtitle}';
  }

  final lines = text.split(RegExp(r'\r?\n'));
  final separatorIndex = lines.indexOf('----');
  final headerLines =
      separatorIndex >= 0 ? lines.take(separatorIndex).toList() : <String>[];
  final bodyLines =
      separatorIndex >= 0 ? lines.skip(separatorIndex + 1).toList() : lines;
  final sections = _splitDiagnosticSections(bodyLines);

  final buffer = StringBuffer();
  final title = headerLines.isNotEmpty ? headerLines.first.trim() : zh.logTitleFallback;
  buffer.writeln('# $title');
  buffer.writeln();

  final headerEntries = _parseIndentedKeyValueBlock(headerLines.skip(1).toList());
  if (headerEntries.isNotEmpty) {
    buffer.writeln('## ${zh.deviceInfoTitle}');
    buffer.writeln();
    headerEntries.forEach((key, value) {
      buffer.writeln('- **${_prettyKey(key)}**：${_inlineValue(value)}');
    });
    buffer.writeln();
  }

  if (sections.isEmpty) {
    buffer.writeln('## ${zh.contentTitle}');
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln(text);
    buffer.writeln('```');
    return buffer.toString().trim();
  }

  buffer.writeln('## ${zh.recentLogsTitle}');
  buffer.writeln();

  for (var i = 0; i < sections.length; i++) {
    final section = _parseIndentedKeyValueBlock(sections[i]);
    final time = _formatMillis(section['time']);
    final category = section['category']?.trim().isNotEmpty == true
        ? section['category']!.trim()
        : zh.unknownCategory;
    buffer.writeln('### ${i + 1}. $category');
    buffer.writeln();
    if (time != null) {
      buffer.writeln('- **时间**：$time');
    }

    final message = section['message']?.trim();
    if (message != null && message.isNotEmpty) {
      buffer.writeln('- **消息**：$message');
    }

    section.forEach((key, value) {
      if (key == 'time' || key == 'category' || key == 'message') {
        return;
      }
      final trimmedValue = value.trim();
      if (trimmedValue.isEmpty) {
        return;
      }

      if (trimmedValue.contains('\n')) {
        buffer.writeln('- **${_prettyKey(key)}**：');
        buffer.writeln();
        buffer.writeln('```text');
        buffer.writeln(trimmedValue);
        buffer.writeln('```');
      } else {
        buffer.writeln('- **${_prettyKey(key)}**：${_inlineValue(trimmedValue)}');
      }
    });
    buffer.writeln();
  }

  return buffer.toString().trim();
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
    final match = RegExp(r'^([A-Za-z0-9_.-]+)=(.*)$').firstMatch(line);
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

String _prettyKey(String key) {
  final zh = _DiagnosticsL10nFallback();
  switch (key) {
    case 'exportedAt':
      return zh.exportedAt;
    case 'time':
      return zh.time;
    case 'category':
      return zh.category;
    case 'message':
      return zh.message;
    case 'stackTrace':
      return zh.stackTrace;
    case 'throwable':
      return '异常';
    case 'extras':
      return '附加信息';
    case 'context':
      return '上下文';
    case 'truncated':
      return '已截断';
    case 'truncatedHint':
      return '截断说明';
    default:
      return key;
  }
}

class _DiagnosticsL10nFallback {
  String get exportedAt => '导出时间';
  String get time => '时间';
  String get category => '类别';
  String get message => '消息';
  String get stackTrace => '堆栈';
  String get emptyTitle => '暂无日志';
  String get emptySubtitle => '当前没有可显示的超级岛诊断日志。';
  String get logTitleFallback => '超级岛诊断日志';
  String get deviceInfoTitle => '设备与导出信息';
  String get contentTitle => '日志内容';
  String get recentLogsTitle => '最近日志';
  String get unknownCategory => '未分类事件';
}

String _inlineValue(String value) {
  final formattedTime = _formatMillis(value);
  return formattedTime ?? value;
}

String? _formatMillis(String? raw) {
  final millis = int.tryParse(raw ?? '');
  if (millis == null) {
    return null;
  }
  final dateTime = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} ${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
}
