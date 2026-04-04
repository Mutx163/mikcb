import 'package:flutter/material.dart';
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
                    '支持 Markdown 与原文两种查看方式，排查时可以直接在手机上看完整日志。',
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
                segments: const [
                  ButtonSegment(
                    value: DiagnosticsLogViewMode.markdown,
                    icon: Icon(Icons.article_outlined),
                    label: Text('Markdown'),
                  ),
                  ButtonSegment(
                    value: DiagnosticsLogViewMode.raw,
                    icon: Icon(Icons.code_rounded),
                    label: Text('原文'),
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
  final text = rawLog.trim();
  if (text.isEmpty) {
    return '# 暂无日志\n\n当前没有可显示的超级岛诊断日志。';
  }

  final lines = text.split(RegExp(r'\r?\n'));
  final separatorIndex = lines.indexOf('----');
  final headerLines =
      separatorIndex >= 0 ? lines.take(separatorIndex).toList() : <String>[];
  final bodyLines =
      separatorIndex >= 0 ? lines.skip(separatorIndex + 1).toList() : lines;
  final sections = _splitDiagnosticSections(bodyLines);

  final buffer = StringBuffer();
  final title = headerLines.isNotEmpty ? headerLines.first.trim() : '超级岛诊断日志';
  buffer.writeln('# $title');
  buffer.writeln();

  final headerEntries = _parseIndentedKeyValueBlock(headerLines.skip(1).toList());
  if (headerEntries.isNotEmpty) {
    buffer.writeln('## 设备与导出信息');
    buffer.writeln();
    headerEntries.forEach((key, value) {
      buffer.writeln('- **${_prettyKey(key)}**：${_inlineValue(value)}');
    });
    buffer.writeln();
  }

  if (sections.isEmpty) {
    buffer.writeln('## 日志内容');
    buffer.writeln();
    buffer.writeln('```text');
    buffer.writeln(text);
    buffer.writeln('```');
    return buffer.toString().trim();
  }

  buffer.writeln('## 最近日志');
  buffer.writeln();

  for (var i = 0; i < sections.length; i++) {
    final section = _parseIndentedKeyValueBlock(sections[i]);
    final time = _formatMillis(section['time']);
    final category = section['category']?.trim().isNotEmpty == true
        ? section['category']!.trim()
        : '未分类事件';
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
  switch (key) {
    case 'exportedAt':
      return '导出时间';
    case 'time':
      return '时间';
    case 'category':
      return '类别';
    case 'message':
      return '消息';
    case 'stackTrace':
      return '堆栈';
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
