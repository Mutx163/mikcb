import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

enum DiagnosticsLogViewMode { structured, raw }

enum DiagnosticsLogLevel { all, error, warn, info, debug, verbose }

class LiveDiagnosticsLogViewerScreen extends StatefulWidget {
  final String title;
  final String rawLog;
  final bool? isRecordingEnabled;
  final ValueChanged<bool>? onRecordingChanged;
  final Future<void> Function(String text)? onExport;
  final Future<bool> Function()? onClear;

  const LiveDiagnosticsLogViewerScreen({
    super.key,
    required this.title,
    required this.rawLog,
    this.isRecordingEnabled,
    this.onRecordingChanged,
    this.onExport,
    this.onClear,
  });

  @override
  State<LiveDiagnosticsLogViewerScreen> createState() =>
      _LiveDiagnosticsLogViewerScreenState();
}

class _LiveDiagnosticsLogViewerScreenState
    extends State<LiveDiagnosticsLogViewerScreen> {
  DiagnosticsLogViewMode _viewMode = DiagnosticsLogViewMode.structured;
  DiagnosticsLogLevel _selectedLevel = DiagnosticsLogLevel.all;
  late String _rawLog;
  bool _clearing = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _rawLog = widget.rawLog;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final parsed = _parseDiagnosticsLog(_rawLog, fallbackTitle: widget.title);
    final filteredEntries = _filterEntries(parsed.entries, _selectedLevel);
    final filteredRawText = _buildFilteredRawText(
      parsed,
      filteredEntries,
      _selectedLevel,
    );

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(widget.title),
        suffixes: [
          FHeaderAction(
            icon: const Icon(Icons.copy_all_rounded),
            semanticsLabel: l10n.appLogsCopyAction,
            onPress: () => _copyLogs(filteredRawText),
          ),
          FHeaderAction(
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            semanticsLabel: l10n.appLogsExportAction,
            onPress: widget.onExport == null || _exporting
                ? null
                : () => _exportLogs(filteredRawText),
          ),
          FHeaderAction(
            icon: _clearing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded),
            semanticsLabel: l10n.appLogsClearAction,
            onPress: widget.onClear == null || _clearing ? null : _clearLogs,
          ),
        ],
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                l10n.diagnosticsLogIntro,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (widget.isRecordingEnabled != null)
                    _RecordingToggleChip(
                      isRecording: widget.isRecordingEnabled!,
                      l10n: l10n,
                      onToggle: widget.onRecordingChanged == null
                          ? null
                          : () => widget.onRecordingChanged!(
                              !widget.isRecordingEnabled!,
                            ),
                    ),
                  SegmentedButton<DiagnosticsLogViewMode>(
                    segments: <ButtonSegment<DiagnosticsLogViewMode>>[
                      ButtonSegment<DiagnosticsLogViewMode>(
                        value: DiagnosticsLogViewMode.structured,
                        icon: const Icon(Icons.view_agenda_outlined),
                        label: Text(l10n.diagnosticsStructuredTab),
                      ),
                      ButtonSegment<DiagnosticsLogViewMode>(
                        value: DiagnosticsLogViewMode.raw,
                        icon: const Icon(Icons.code_rounded),
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final level in DiagnosticsLogLevel.values) ...[
                      _LevelFilterChip(
                        label:
                            '${_levelLabel(l10n, level)} ${_levelCount(parsed.entries, level)}',
                        selected: _selectedLevel == level,
                        color: _levelColor(context, level),
                        onSelected: () {
                          setState(() {
                            _selectedLevel = level;
                          });
                        },
                      ),
                      if (level != DiagnosticsLogLevel.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.diagnosticsShowingCount(
                      filteredEntries.length,
                      parsed.entries.length,
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (_viewMode == DiagnosticsLogViewMode.raw &&
                      _selectedLevel != DiagnosticsLogLevel.all) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.diagnosticsRawFilteredHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: parsed.entries.isEmpty
                  ? _buildEmptyState(context, l10n)
                  : _viewMode == DiagnosticsLogViewMode.raw
                  ? _buildRawView(context, l10n, parsed, filteredEntries)
                  : _buildStructuredView(
                      context,
                      l10n,
                      parsed,
                      filteredEntries,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  List<_DiagnosticsLogEntry> _filterEntries(
    List<_DiagnosticsLogEntry> entries,
    DiagnosticsLogLevel level,
  ) {
    if (level == DiagnosticsLogLevel.all) {
      return entries;
    }
    return entries
        .where((entry) => entry.level == level)
        .toList(growable: false);
  }

  int _levelCount(
    List<_DiagnosticsLogEntry> entries,
    DiagnosticsLogLevel level,
  ) {
    if (level == DiagnosticsLogLevel.all) {
      return entries.length;
    }
    return entries.where((entry) => entry.level == level).length;
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsEmptyTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.diagnosticsEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredView(
    BuildContext context,
    AppLocalizations l10n,
    _DiagnosticsParsedLog parsed,
    List<_DiagnosticsLogEntry> filteredEntries,
  ) {
    if (filteredEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.diagnosticsNoMatchingTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.diagnosticsNoMatchingSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (parsed.headerEntries.isNotEmpty)
          _DiagnosticsHeaderCard(parsed: parsed, l10n: l10n),
        if (parsed.headerEntries.isNotEmpty) const SizedBox(height: 12),
        for (var i = 0; i < filteredEntries.length; i++) ...[
          _DiagnosticsLogEntryCard(entry: filteredEntries[i], l10n: l10n),
          if (i != filteredEntries.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildRawView(
    BuildContext context,
    AppLocalizations l10n,
    _DiagnosticsParsedLog parsed,
    List<_DiagnosticsLogEntry> filteredEntries,
  ) {
    if (filteredEntries.isEmpty) {
      return _buildStructuredView(context, l10n, parsed, filteredEntries);
    }

    final rawText = _buildFilteredRawText(
      parsed,
      filteredEntries,
      _selectedLevel,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: SelectableText(
        rawText,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.45),
      ),
    );
  }

  Future<void> _copyLogs(String text) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.appLogsCopied)));
  }

  Future<void> _exportLogs(String text) async {
    if (widget.onExport == null) {
      return;
    }
    setState(() {
      _exporting = true;
    });
    try {
      await widget.onExport!(text);
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    if (widget.onClear == null) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _clearing = true;
    });
    final cleared = await widget.onClear!();
    if (!mounted) {
      return;
    }
    setState(() {
      _clearing = false;
      if (cleared) {
        _rawLog = '';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleared ? l10n.appLogsCleared : l10n.appLogsClearFailed),
      ),
    );
  }
}

class _RecordingToggleChip extends StatelessWidget {
  final bool isRecording;
  final AppLocalizations l10n;
  final VoidCallback? onToggle;

  const _RecordingToggleChip({
    required this.isRecording,
    required this.l10n,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording
        ? Colors.green
        : Theme.of(context).colorScheme.outline;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isRecording
                  ? Icons.fiber_manual_record_rounded
                  : Icons.pause_circle_outline_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              isRecording
                  ? l10n.appLogsRecordingEnabled
                  : l10n.appLogsRecordingDisabled,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onSelected;

  const _LevelFilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? color : Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide(
        color: selected
            ? color.withValues(alpha: 0.35)
            : Theme.of(context).colorScheme.outlineVariant,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: color.withValues(alpha: 0.12),
    );
  }
}

class _DiagnosticsHeaderCard extends StatelessWidget {
  final _DiagnosticsParsedLog parsed;
  final AppLocalizations l10n;

  const _DiagnosticsHeaderCard({required this.parsed, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            parsed.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.diagnosticsDeviceInfoTitle,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: parsed.headerEntries.entries
                .map(
                  (item) => Container(
                    constraints: const BoxConstraints(minWidth: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _prettyKey(item.key, l10n),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _inlineValue(item.value),
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsLogEntryCard extends StatelessWidget {
  final _DiagnosticsLogEntry entry;
  final AppLocalizations l10n;

  const _DiagnosticsLogEntryCard({required this.entry, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _levelColor(context, entry.level);
    final details = entry.detailEntries.toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_levelIcon(entry.level), color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _levelLabel(l10n, entry.level),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (entry.isLevelInferred)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.diagnosticsLevelInferred,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (entry.category.isNotEmpty)
                            Text(
                              entry.category,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      if (entry.formattedTime != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.formattedTime!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (entry.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              SelectableText(
                entry.message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 4),
                    title: Text(
                      l10n.diagnosticsContentTitle,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    children: [
                      for (var i = 0; i < details.length; i++) ...[
                        _DiagnosticsDetailRow(
                          label: _prettyKey(details[i].key, l10n),
                          value: _inlineValue(details[i].value),
                        ),
                        if (i != details.length - 1) const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DiagnosticsDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.25,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: value.contains('\n') ? 'monospace' : null,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsParsedLog {
  final String title;
  final String rawHeader;
  final String fullText;
  final Map<String, String> headerEntries;
  final List<_DiagnosticsLogEntry> entries;

  const _DiagnosticsParsedLog({
    required this.title,
    required this.rawHeader,
    required this.fullText,
    required this.headerEntries,
    required this.entries,
  });
}

class _DiagnosticsLogEntry {
  final String rawBlock;
  final Map<String, String> fields;
  final DiagnosticsLogLevel level;
  final bool isLevelInferred;

  const _DiagnosticsLogEntry({
    required this.rawBlock,
    required this.fields,
    required this.level,
    required this.isLevelInferred,
  });

  String get category => fields['category']?.trim() ?? '';

  String get message => fields['message']?.trim() ?? rawBlock.trim();

  String? get formattedTime => _formatMillis(fields['time']);

  Iterable<MapEntry<String, String>> get detailEntries => fields.entries.where(
    (entry) => !const {
      'time',
      'category',
      'message',
      'level',
      'severity',
    }.contains(entry.key),
  );
}

_DiagnosticsParsedLog _parseDiagnosticsLog(
  String rawLog, {
  String fallbackTitle = '',
}) {
  final normalizedText = rawLog.trim();
  if (normalizedText.isEmpty) {
    return _DiagnosticsParsedLog(
      title: fallbackTitle,
      rawHeader: '',
      fullText: '',
      headerEntries: const <String, String>{},
      entries: const <_DiagnosticsLogEntry>[],
    );
  }

  final lines = normalizedText.split(RegExp(r'\r?\n'));
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
      .whereType<_DiagnosticsLogEntry>()
      .toList(growable: false);

  return _DiagnosticsParsedLog(
    title: headerLines.isNotEmpty
        ? headerLines.first.trim()
        : (fallbackTitle.isNotEmpty ? fallbackTitle : 'Diagnostics Log'),
    rawHeader: headerLines.join('\n').trim(),
    fullText: normalizedText,
    headerEntries: headerEntries,
    entries: entries,
  );
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

_DiagnosticsLogEntry? _parseDiagnosticsLogEntry(List<String> lines) {
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

  return _DiagnosticsLogEntry(
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
      RegExp(
        r'\b(error|exception|crash|fatal|failed|failure)\b',
      ).hasMatch(haystack)) {
    return DiagnosticsLogLevel.error;
  }
  if (RegExp(
    r'\b(warn|warning|denied|blocked|invalid|missing)\b',
  ).hasMatch(haystack)) {
    return DiagnosticsLogLevel.warn;
  }
  if (RegExp(r'\b(verbose|trace)\b').hasMatch(haystack)) {
    return DiagnosticsLogLevel.verbose;
  }
  if (RegExp(
    r'\b(debug|diagnostic|snapshot|payload|test)\b',
  ).hasMatch(haystack)) {
    return DiagnosticsLogLevel.debug;
  }
  return DiagnosticsLogLevel.info;
}

String _buildFilteredRawText(
  _DiagnosticsParsedLog parsed,
  List<_DiagnosticsLogEntry> filteredEntries,
  DiagnosticsLogLevel selectedLevel,
) {
  if (selectedLevel == DiagnosticsLogLevel.all) {
    return parsed.fullText;
  }

  final blocks = filteredEntries
      .map((entry) => entry.rawBlock.trim())
      .join('\n\n');
  if (parsed.rawHeader.isEmpty) {
    return blocks;
  }
  return '${parsed.rawHeader}\n----\n$blocks'.trim();
}

String _levelLabel(AppLocalizations l10n, DiagnosticsLogLevel level) {
  return switch (level) {
    DiagnosticsLogLevel.all => l10n.diagnosticsLevelAll,
    DiagnosticsLogLevel.error => l10n.diagnosticsLevelError,
    DiagnosticsLogLevel.warn => l10n.diagnosticsLevelWarn,
    DiagnosticsLogLevel.info => l10n.diagnosticsLevelInfo,
    DiagnosticsLogLevel.debug => l10n.diagnosticsLevelDebug,
    DiagnosticsLogLevel.verbose => l10n.diagnosticsLevelVerbose,
  };
}

IconData _levelIcon(DiagnosticsLogLevel level) {
  return switch (level) {
    DiagnosticsLogLevel.all => Icons.library_books_outlined,
    DiagnosticsLogLevel.error => Icons.error_outline_rounded,
    DiagnosticsLogLevel.warn => Icons.warning_amber_rounded,
    DiagnosticsLogLevel.info => Icons.info_outline_rounded,
    DiagnosticsLogLevel.debug => Icons.bug_report_outlined,
    DiagnosticsLogLevel.verbose => Icons.subject_outlined,
  };
}

Color _levelColor(BuildContext context, DiagnosticsLogLevel level) {
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    DiagnosticsLogLevel.all => scheme.primary,
    DiagnosticsLogLevel.error => scheme.error,
    DiagnosticsLogLevel.warn => Colors.orange,
    DiagnosticsLogLevel.info => Colors.teal,
    DiagnosticsLogLevel.debug => Colors.indigo,
    DiagnosticsLogLevel.verbose => scheme.secondary,
  };
}

String _prettyKey(String key, AppLocalizations l10n) {
  switch (key) {
    case 'exportedAt':
      return l10n.diagnosticsExportedAt;
    case 'time':
      return l10n.diagnosticsTime;
    case 'category':
      return l10n.diagnosticsCategory;
    case 'message':
      return l10n.diagnosticsMessage;
    case 'stackTrace':
      return l10n.diagnosticsStackTrace;
    case 'level':
    case 'severity':
      return l10n.diagnosticsLevelLabel;
    case 'throwable':
      return 'Throwable';
    case 'extras':
      return 'Extras';
    case 'context':
      return 'Context';
    case 'truncated':
      return 'Truncated';
    case 'truncatedHint':
      return 'Truncation hint';
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
