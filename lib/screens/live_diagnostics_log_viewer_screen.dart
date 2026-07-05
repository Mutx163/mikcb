import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../widgets/settings_section_widgets.dart';

enum DiagnosticsLogViewMode { structured, raw }

enum DiagnosticsLogLevel { all, error, warn, info, debug, verbose }

class LiveDiagnosticsLogViewerScreen extends StatefulWidget {
  final String title;
  final String rawLog;
  final Future<String> Function()? loadRawLog;
  final VoidCallback? onLoadEmpty;
  final bool? isRecordingEnabled;
  final ValueChanged<bool>? onRecordingChanged;
  final Future<void> Function(String text)? onExport;
  final Future<bool> Function()? onClear;

  const LiveDiagnosticsLogViewerScreen({
    super.key,
    required this.title,
    this.rawLog = '',
    this.loadRawLog,
    this.onLoadEmpty,
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
  bool? _recordingEnabled;
  bool _loading = false;
  String? _loadError;
  bool _clearing = false;
  bool _exporting = false;
  _DiagnosticsParsedLog? _parsedCache;

  @override
  void initState() {
    super.initState();
    _rawLog = widget.rawLog;
    _recordingEnabled = widget.isRecordingEnabled;
    if (widget.loadRawLog != null) {
      unawaited(_loadLogs());
    } else {
      _refreshParsedCache();
    }
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.loadRawLog!();
      if (!mounted) {
        return;
      }
      if (loaded.trim().isEmpty && widget.onLoadEmpty != null) {
        widget.onLoadEmpty!();
        return;
      }
      setState(() {
        _rawLog = loaded;
        _loading = false;
      });
      _refreshParsedCache();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadError = error.toString();
      });
    }
  }

  void _refreshParsedCache() {
    _parsedCache = _parseDiagnosticsLog(_rawLog, fallbackTitle: widget.title);
  }

  _DiagnosticsParsedLog get _parsed {
    return _parsedCache ??
        _parseDiagnosticsLog(_rawLog, fallbackTitle: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(widget.title),
        suffixes: _buildHeaderActions(l10n),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: _loading
            ? const Center(child: FProgress())
            : _loadError != null
            ? _buildLoadError(context, l10n)
            : _buildBody(context, l10n),
      ),
    );
  }

  List<FHeaderAction> _buildHeaderActions(AppLocalizations l10n) {
    if (_loading || _loadError != null) {
      return const [];
    }

    final parsed = _parsed;
    final filteredEntries = _filterEntries(parsed.entries, _selectedLevel);
    final filteredRawText = _buildFilteredRawText(
      parsed,
      filteredEntries,
      _selectedLevel,
    );

    return [
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
    ];
  }

  Widget _buildLoadError(BuildContext context, AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: colors.destructive,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsEmptyTitle,
              style: typo.lg.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: typo.sm.copyWith(color: colors.mutedForeground),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FButton.icon(
              onPress: _loadLogs,
              child: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    final parsed = _parsed;
    final filteredEntries = _filterEntries(parsed.entries, _selectedLevel);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildControlsSection(context, l10n, parsed),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: parsed.entries.isEmpty
              ? _buildEmptyState(context, l10n)
              : _viewMode == DiagnosticsLogViewMode.raw
              ? _buildRawView(context, l10n, parsed, filteredEntries)
              : _buildStructuredView(context, l10n, parsed, filteredEntries),
        ),
      ],
    );
  }

  Widget _buildControlsSection(
    BuildContext context,
    AppLocalizations l10n,
    _DiagnosticsParsedLog parsed,
  ) {
    final filteredEntries = _filterEntries(parsed.entries, _selectedLevel);
    final typo = context.theme.typography.body;

    return SettingsSectionCard(
      subtitle: l10n.diagnosticsLogIntro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recordingEnabled != null) ...[
            FTileGroup(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SettingSwitchTile(
                  title: Text(l10n.aboutRecordDiagnosticsTitle),
                  subtitle: Text(
                    _recordingEnabled!
                        ? l10n.appLogsRecordingEnabled
                        : l10n.appLogsRecordingDisabled,
                  ),
                  value: _recordingEnabled!,
                  onChanged: widget.onRecordingChanged == null
                      ? null
                      : (value) {
                          widget.onRecordingChanged!(value);
                          setState(() {
                            _recordingEnabled = value;
                          });
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: FButton(
                  variant: _viewMode == DiagnosticsLogViewMode.structured
                      ? FButtonVariant.primary
                      : FButtonVariant.outline,
                  onPress: () {
                    setState(() {
                      _viewMode = DiagnosticsLogViewMode.structured;
                    });
                  },
                  prefix: const Icon(Icons.view_agenda_outlined, size: 18),
                  child: Text(l10n.diagnosticsStructuredTab),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FButton(
                  variant: _viewMode == DiagnosticsLogViewMode.raw
                      ? FButtonVariant.primary
                      : FButtonVariant.outline,
                  onPress: () {
                    setState(() {
                      _viewMode = DiagnosticsLogViewMode.raw;
                    });
                  },
                  prefix: const Icon(Icons.code_rounded, size: 18),
                  child: Text(l10n.diagnosticsRawTab),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final level in DiagnosticsLogLevel.values) ...[
                  _LevelFilterButton(
                    label:
                        '${_levelLabel(l10n, level)} ${_levelCount(parsed.entries, level)}',
                    selected: _selectedLevel == level,
                    color: _levelColor(context, level),
                    onPress: () {
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
          const SizedBox(height: 10),
          Text(
            l10n.diagnosticsShowingCount(
              filteredEntries.length,
              parsed.entries.length,
            ),
            style: typo.xs2.copyWith(
              color: context.theme.colors.mutedForeground,
            ),
          ),
          if (_viewMode == DiagnosticsLogViewMode.raw &&
              _selectedLevel != DiagnosticsLogLevel.all) ...[
            const SizedBox(height: 4),
            Text(
              l10n.diagnosticsRawFilteredHint,
              style: typo.xs2.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ],
        ],
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
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: colors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsEmptyTitle,
              style: typo.lg.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.diagnosticsEmptySubtitle,
              textAlign: TextAlign.center,
              style: typo.sm.copyWith(color: colors.mutedForeground),
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
      return _buildNoMatchingState(context, l10n);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        if (parsed.headerEntries.isNotEmpty)
          _DiagnosticsHeaderCard(parsed: parsed, l10n: l10n),
        if (parsed.headerEntries.isNotEmpty) const SizedBox(height: 12),
        for (var i = 0; i < filteredEntries.length; i++) ...[
          _DiagnosticsLogEntryCard(entry: filteredEntries[i], l10n: l10n),
          if (i != filteredEntries.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildNoMatchingState(BuildContext context, AppLocalizations l10n) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: colors.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsNoMatchingTitle,
              style: typo.lg.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.diagnosticsNoMatchingSubtitle,
              textAlign: TextAlign.center,
              style: typo.sm.copyWith(color: colors.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawView(
    BuildContext context,
    AppLocalizations l10n,
    _DiagnosticsParsedLog parsed,
    List<_DiagnosticsLogEntry> filteredEntries,
  ) {
    if (filteredEntries.isEmpty) {
      return _buildNoMatchingState(context, l10n);
    }

    final rawText = _buildFilteredRawText(
      parsed,
      filteredEntries,
      _selectedLevel,
    );
    final typo = context.theme.typography.body;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: FCard.raw(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            rawText,
            style: typo.xs2.copyWith(fontFamily: 'monospace', height: 1.45),
          ),
        ),
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
        _refreshParsedCache();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cleared ? l10n.appLogsCleared : l10n.appLogsClearFailed),
      ),
    );
  }
}

class _LevelFilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onPress;

  const _LevelFilterButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return FButton(
      variant: selected ? FButtonVariant.secondary : FButtonVariant.outline,
      onPress: onPress,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? color : context.theme.colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DiagnosticsHeaderCard extends StatelessWidget {
  final _DiagnosticsParsedLog parsed;
  final AppLocalizations l10n;

  const _DiagnosticsHeaderCard({required this.parsed, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return SettingsSectionCard(
      title: parsed.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.diagnosticsDeviceInfoTitle,
            style: typo.sm.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.mutedForeground,
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
                      color: colors.secondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _prettyKey(item.key, l10n),
                          style: typo.xs2.copyWith(
                            color: colors.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _inlineValue(item.value),
                          style: typo.xs2.copyWith(height: 1.35),
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
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;
    final levelColor = _levelColor(context, entry.level);
    final details = entry.detailEntries.toList(growable: false);

    return FCard.raw(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _levelIcon(entry.level),
                    color: levelColor,
                    size: 18,
                  ),
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
                          FBadge(
                            variant: FBadgeVariant.secondary,
                            child: Text(_levelLabel(l10n, entry.level)),
                          ),
                          if (entry.isLevelInferred)
                            FBadge(
                              variant: FBadgeVariant.outline,
                              child: Text(l10n.diagnosticsLevelInferred),
                            ),
                          if (entry.category.isNotEmpty)
                            Text(
                              entry.category,
                              style: typo.sm.copyWith(
                                color: colors.mutedForeground,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      if (entry.formattedTime != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.formattedTime!,
                          style: typo.xs2.copyWith(
                            color: colors.mutedForeground,
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
                style: typo.sm.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: Material(
                  color: Colors.transparent,
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 4),
                    title: Text(
                      l10n.diagnosticsContentTitle,
                      style: typo.sm.copyWith(fontWeight: FontWeight.w600),
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
    final typo = context.theme.typography.body;
    final colors = context.theme.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: typo.xs2.copyWith(
              color: colors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            value,
            style: typo.xs2.copyWith(
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
  final colors = context.theme.colors;
  return switch (level) {
    DiagnosticsLogLevel.all => colors.primary,
    DiagnosticsLogLevel.error => colors.destructive,
    DiagnosticsLogLevel.warn => Colors.orange,
    DiagnosticsLogLevel.info => Colors.teal,
    DiagnosticsLogLevel.debug => Colors.indigo,
    DiagnosticsLogLevel.verbose => colors.secondary,
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
