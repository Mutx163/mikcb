import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../logging/app_log_message_localizer.dart';
import '../services/diagnostics_log_viewer_preferences.dart';
import '../utils/app_toast.dart';

enum DiagnosticsLogViewMode { structured, raw }

enum DiagnosticsLogLevel { all, error, warn, info, debug, verbose }

enum DiagnosticsLogTimeSort { ascending, descending }

class LiveDiagnosticsLogViewerScreen extends StatefulWidget {
  final String title;
  final String rawLog;
  final Future<String> Function()? loadRawLog;
  final Stream<String> Function()? watchRawLog;
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
    this.watchRawLog,
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
  DiagnosticsLogTimeSort _timeSort = DiagnosticsLogTimeSort.ascending;
  late String _rawLog;
  bool? _recordingEnabled;
  bool _loading = false;
  String? _loadError;
  bool _clearing = false;
  bool _exporting = false;
  _DiagnosticsParsedLog? _parsedCache;
  StreamSubscription<String>? _logSubscription;
  final ScrollController _structuredScrollController = ScrollController();
  final ScrollController _rawScrollController = ScrollController();
  bool _stickToLatest = true;
  bool _isStreaming = false;
  bool _autoScrollPending = false;
  bool _displayOptionsExpanded = false;

  @override
  void initState() {
    super.initState();
    _rawLog = widget.rawLog;
    _recordingEnabled = widget.isRecordingEnabled;
    _structuredScrollController.addListener(_onStructuredScroll);
    _rawScrollController.addListener(_onRawScroll);
    unawaited(_loadViewerPreferences());
    if (widget.watchRawLog != null) {
      _isStreaming = true;
      _startWatching();
    } else if (widget.loadRawLog != null) {
      unawaited(_loadLogs());
    } else {
      _refreshParsedCache();
    }
  }

  Future<void> _loadViewerPreferences() async {
    final results = await Future.wait([
      DiagnosticsLogViewerPreferences.loadTimeSort(),
      DiagnosticsLogViewerPreferences.loadDisplayOptionsExpanded(),
    ]);
    if (!mounted) {
      return;
    }
    final sort = results[0] as String;
    final displayExpanded = results[1] as bool;
    setState(() {
      _timeSort = sort == DiagnosticsLogViewerPreferences.descending
          ? DiagnosticsLogTimeSort.descending
          : DiagnosticsLogTimeSort.ascending;
      _displayOptionsExpanded = displayExpanded;
    });
  }

  void _toggleDisplayOptionsExpanded() {
    setState(() {
      _displayOptionsExpanded = !_displayOptionsExpanded;
    });
    unawaited(
      DiagnosticsLogViewerPreferences.saveDisplayOptionsExpanded(
        _displayOptionsExpanded,
      ),
    );
  }

  String _displayOptionsSummary(AppLocalizations l10n) {
    final mode = _viewMode == DiagnosticsLogViewMode.structured
        ? l10n.diagnosticsStructuredTab
        : l10n.diagnosticsRawTab;
    final sort = _timeSort == DiagnosticsLogTimeSort.ascending
        ? l10n.diagnosticsTimeSortAscending
        : l10n.diagnosticsTimeSortDescending;
    return '$mode · $sort';
  }

  void _setTimeSort(DiagnosticsLogTimeSort sort) {
    if (_timeSort == sort) {
      return;
    }
    setState(() {
      _timeSort = sort;
    });
    unawaited(
      DiagnosticsLogViewerPreferences.saveTimeSort(
        sort == DiagnosticsLogTimeSort.descending
            ? DiagnosticsLogViewerPreferences.descending
            : DiagnosticsLogViewerPreferences.ascending,
      ),
    );
    if (_stickToLatest) {
      _scheduleAutoScroll();
    }
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _structuredScrollController
      ..removeListener(_onStructuredScroll)
      ..dispose();
    _rawScrollController
      ..removeListener(_onRawScroll)
      ..dispose();
    super.dispose();
  }

  void _startWatching() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    var isFirstEmission = true;
    _logSubscription = widget.watchRawLog!().listen(
      (loaded) {
        if (!mounted) {
          return;
        }
        _applyLoadedLog(
          loaded,
          isFirstEmission: isFirstEmission,
        );
        isFirstEmission = false;
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _loading = false;
          _loadError = error.toString();
        });
      },
    );
  }

  void _applyLoadedLog(String loaded, {required bool isFirstEmission}) {
    if (isFirstEmission && loaded.trim().isEmpty && widget.onLoadEmpty != null) {
      widget.onLoadEmpty!();
      return;
    }
    if (!isFirstEmission && loaded == _rawLog) {
      return;
    }
    final previousCount = _parsedCache?.entries.length ?? 0;
    setState(() {
      _rawLog = loaded;
      _loading = false;
      _loadError = null;
    });
    _refreshParsedCache();
    final shouldFollowLatest = _stickToLatest &&
        (isFirstEmission ||
            (_isStreaming && _parsed.entries.length > previousCount));
    if (shouldFollowLatest) {
      _scheduleAutoScroll();
    }
  }

  bool get _latestAtBottom => _timeSort == DiagnosticsLogTimeSort.ascending;

  void _onStructuredScroll() {
    if (!_structuredScrollController.hasClients) {
      return;
    }
    final position = _structuredScrollController.position;
    if (_latestAtBottom) {
      _stickToLatest =
          position.pixels >= position.maxScrollExtent - 48;
    } else {
      _stickToLatest = position.pixels <= 48;
    }
  }

  void _onRawScroll() {
    if (!_rawScrollController.hasClients) {
      return;
    }
    final position = _rawScrollController.position;
    if (_latestAtBottom) {
      _stickToLatest =
          position.pixels >= position.maxScrollExtent - 48;
    } else {
      _stickToLatest = position.pixels <= 48;
    }
  }

  void _scheduleAutoScroll() {
    if (_autoScrollPending) {
      return;
    }
    _autoScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollPending = false;
      if (!mounted) {
        return;
      }
      _safeScrollToEdge(attempt: 0);
    });
  }

  void _safeScrollToEdge({required int attempt}) {
    if (!_stickToLatest || attempt > 3) {
      return;
    }
    final controller = _viewMode == DiagnosticsLogViewMode.raw
        ? _rawScrollController
        : _structuredScrollController;
    if (!controller.hasClients) {
      return;
    }
    final position = controller.position;
    if (!position.hasContentDimensions || !position.hasViewportDimension) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _safeScrollToEdge(attempt: attempt + 1);
        }
      });
      return;
    }
    final maxExtent = position.maxScrollExtent;
    if (!maxExtent.isFinite) {
      return;
    }
    final target = _latestAtBottom ? maxExtent : 0.0;
    if ((position.pixels - target).abs() < 1) {
      return;
    }
    controller.jumpTo(target.clamp(0.0, maxExtent));
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
      _applyLoadedLog(loaded, isFirstEmission: true);
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
    final showControls = !_loading && _loadError == null;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.title),
      suffixes: _buildHeaderActions(l10n),
      headerExtension: showControls
          ? HyperosBlurredHeaderExtension(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildControlsSection(context, l10n, _parsed),
            )
          : null,
      child: HyperosBlurredBodyInset(
        child: _loading
            ? const Center(child: HyperosCircularProgress())
            : _loadError != null
            ? _buildLoadError(context, l10n)
            : _buildLogBody(context, l10n),
      ),
    );
  }

  List<FHeaderAction> _buildHeaderActions(AppLocalizations l10n) {
    if (_loading || _loadError != null) {
      return const [];
    }

    final parsed = _parsed;
    final visibleEntries = _visibleEntries(parsed.entries);
    final filteredRawText = _buildFilteredRawText(parsed, visibleEntries);

    return [
      FHeaderAction(
        icon: const Icon(Icons.copy_all_rounded),
        semanticsLabel: l10n.appLogsCopyAction,
        onPress: () => _copyLogs(filteredRawText),
      ),
      FHeaderAction(
        icon: _exporting
            ? const HyperosCircularProgress(size: 18, strokeWidth: 2)
            : const Icon(Icons.ios_share_rounded),
        semanticsLabel: l10n.appLogsExportAction,
        onPress: widget.onExport == null || _exporting
            ? null
            : () => _exportLogs(filteredRawText),
      ),
      FHeaderAction(
        icon: _clearing
            ? const HyperosCircularProgress(size: 18, strokeWidth: 2)
            : const Icon(Icons.delete_outline_rounded),
        semanticsLabel: l10n.appLogsClearAction,
        onPress: widget.onClear == null || _clearing ? null : _clearLogs,
      ),
    ];
  }

  Widget _buildLoadError(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: HyperosTokens.error,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsEmptyTitle,
              style: HyperosTypography.sectionLabel(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _loadError!,
              style: HyperosTypography.listDetail(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            HyperosButton(
              label: l10n.liveTestingRefreshAction,
              variant: HyperosButtonVariant.secondary,
              onPressed: _loadLogs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogBody(BuildContext context, AppLocalizations l10n) {
    final parsed = _parsed;
    final visibleEntries = _visibleEntries(parsed.entries);

    if (parsed.entries.isEmpty) {
      return _buildEmptyState(context, l10n);
    }
    if (_viewMode == DiagnosticsLogViewMode.raw) {
      return _buildRawView(context, l10n, parsed, visibleEntries);
    }
    return _buildStructuredView(context, l10n, parsed, visibleEntries);
  }

  Widget _buildRecordingSection(BuildContext context, AppLocalizations l10n) {
    if (_recordingEnabled == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HyperosListGroup(
          children: [
            HyperosSwitchTile(
              title: l10n.aboutRecordDiagnosticsTitle,
              subtitle: l10n.aboutRecordDiagnosticsSubtitle,
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
        if (!_recordingEnabled! && _parsed.entries.isNotEmpty)
          HyperosSectionDescription(text: l10n.appLogsRecordingPausedHint),
      ],
    );
  }

  Widget _buildControlsSection(
    BuildContext context,
    AppLocalizations l10n,
    _DiagnosticsParsedLog parsed,
  ) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRecordingSection(context, l10n),
        if (_recordingEnabled != null) const HyperosSectionGap(),
        HyperosListGroup(
          children: [
            HyperosPressableRow(
              onTap: _toggleDisplayOptionsExpanded,
              backgroundColor: cardColor,
              highlightColor: highlightColor,
              child: Padding(
                padding: HyperosTokens.rowPadding(),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.diagnosticsDisplayOptionsTitle,
                            style: HyperosTypography.listTitle(context),
                          ),
                          if (!_displayOptionsExpanded) ...[
                            const SizedBox(height: 2),
                            Text(
                              _displayOptionsSummary(l10n),
                              style: HyperosTypography.listDetail(context)
                                  .copyWith(
                                    color: HyperosColors.secondaryText(
                                      context,
                                    ),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const HyperosUpDownChevron(),
                  ],
                ),
              ),
            ),
            if (_displayOptionsExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.diagnosticsLogIntro,
                      style: HyperosTypography.sectionDescription(context),
                    ),
                    const SizedBox(height: 10),
                    HyperosSegmentedControl(
                      tabs: [
                        l10n.diagnosticsStructuredTab,
                        l10n.diagnosticsRawTab,
                      ],
                      selectedIndex:
                          _viewMode == DiagnosticsLogViewMode.structured
                          ? 0
                          : 1,
                      onChanged: (index) {
                        setState(() {
                          _viewMode = index == 0
                              ? DiagnosticsLogViewMode.structured
                              : DiagnosticsLogViewMode.raw;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    HyperosSegmentedControl(
                      tabs: [
                        l10n.diagnosticsTimeSortAscending,
                        l10n.diagnosticsTimeSortDescending,
                      ],
                      selectedIndex:
                          _timeSort == DiagnosticsLogTimeSort.ascending
                          ? 0
                          : 1,
                      onChanged: (index) {
                        _setTimeSort(
                          index == 0
                              ? DiagnosticsLogTimeSort.ascending
                              : DiagnosticsLogTimeSort.descending,
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.diagnosticsLevelLabel),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (var i = 0; i < DiagnosticsLogLevel.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _LevelFilterChip(
                  label:
                      '${_levelLabel(l10n, DiagnosticsLogLevel.values[i])} ${_levelCount(parsed.entries, DiagnosticsLogLevel.values[i])}',
                  selected:
                      _selectedLevel == DiagnosticsLogLevel.values[i],
                  onPress: () {
                    setState(() {
                      _selectedLevel = DiagnosticsLogLevel.values[i];
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
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

  List<_DiagnosticsLogEntry> _sortEntries(
    List<_DiagnosticsLogEntry> entries,
  ) {
    final sorted = entries.toList(growable: true);
    sorted.sort((a, b) {
      final cmp = a.timeMillis.compareTo(b.timeMillis);
      return _timeSort == DiagnosticsLogTimeSort.ascending ? cmp : -cmp;
    });
    return sorted;
  }

  List<_DiagnosticsLogEntry> _visibleEntries(
    List<_DiagnosticsLogEntry> entries,
  ) {
    return _sortEntries(_filterEntries(entries, _selectedLevel));
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: HyperosColors.secondaryText(context),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsEmptyTitle,
              style: HyperosTypography.listTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.diagnosticsEmptySubtitle,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.secondaryText(context),
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
      return _buildNoMatchingState(context, l10n);
    }

    final listChildren = <Widget>[
      if (parsed.headerEntries.isNotEmpty)
        _DiagnosticsHeaderRow(parsed: parsed, l10n: l10n),
      for (final entry in filteredEntries)
        _DiagnosticsLogEntryTile(entry: entry, l10n: l10n),
    ];

    return ListView(
      controller: _structuredScrollController,
      physics: const HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        HyperosTokens.listPadding.left,
        HyperosTokens.sectionGap,
        HyperosTokens.listPadding.right,
        HyperosTokens.listPadding.bottom,
      ),
      children: [
        HyperosListGroup(children: listChildren),
      ],
    );
  }

  Widget _buildNoMatchingState(BuildContext context, AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: HyperosColors.secondaryText(context),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.diagnosticsNoMatchingTitle,
              style: HyperosTypography.listTitle(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              l10n.diagnosticsNoMatchingSubtitle,
              textAlign: TextAlign.center,
              style: HyperosTypography.listDetail(context).copyWith(
                color: HyperosColors.secondaryText(context),
              ),
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

    final rawText = _buildFilteredRawText(parsed, filteredEntries);
    return SingleChildScrollView(
      controller: _rawScrollController,
      physics: const HyperosOverscrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        HyperosTokens.listPadding.left,
        HyperosTokens.sectionGap,
        HyperosTokens.listPadding.right,
        HyperosTokens.listPadding.bottom,
      ),
      child: HyperosControlCard(
        child: Text(
          rawText,
          style: HyperosTypography.listDetail(
            context,
          ).copyWith(fontFamily: 'monospace', height: 1.45),
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
    showAppToast(
      context,
      message: l10n.appLogsCopied,
      kind: AppToastKind.success,
    );
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
    if (cleared) {
      if (widget.watchRawLog != null) {
        setState(() {
          _rawLog = '';
          _refreshParsedCache();
        });
      } else if (widget.loadRawLog != null) {
        await _loadLogs();
      } else {
        setState(() {
          _rawLog = '';
          _refreshParsedCache();
        });
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _clearing = false;
    });
    showAppToast(
      context,
      message: cleared ? l10n.appLogsCleared : l10n.appLogsClearFailed,
      kind: cleared ? AppToastKind.success : AppToastKind.error,
    );
  }
}

class _LevelFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPress;

  const _LevelFilterChip({
    required this.label,
    required this.selected,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = selected
        ? HyperosTokens.accent.withValues(alpha: isDark ? 0.22 : 0.12)
        : (isDark
              ? HyperosMiuixDarkColors.surface
              : HyperosMiuixLightColors.surface);
    final textColor = selected
        ? HyperosTokens.accent
        : HyperosColors.secondaryText(context);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(
        HyperosMiuixTabRow.contourCornerRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: HyperosTypography.listDetail(context).copyWith(
              color: textColor,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsHeaderRow extends StatefulWidget {
  final _DiagnosticsParsedLog parsed;
  final AppLocalizations l10n;

  const _DiagnosticsHeaderRow({required this.parsed, required this.l10n});

  @override
  State<_DiagnosticsHeaderRow> createState() => _DiagnosticsHeaderRowState();
}

class _DiagnosticsHeaderRowState extends State<_DiagnosticsHeaderRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final padding = _diagnosticsListRowPadding(context);

    return HyperosPressableRow(
      onTap: () => setState(() => _expanded = !_expanded),
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.l10n.diagnosticsDeviceInfoTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
                const HyperosUpDownChevron(),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.parsed.headerEntries.entries
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: HyperosColors.rowHighlight(context),
                          borderRadius: BorderRadius.circular(
                            HyperosMiuixTabRow.contourCornerRadius,
                          ),
                        ),
                        child: Text(
                          '${_prettyKey(item.key, widget.l10n)}: ${_inlineValue(item.value)}',
                          style: HyperosTypography.listDetail(context).copyWith(
                            fontSize: HyperosMiuixTypography.footnote2,
                            height: 1.3,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DiagnosticsLogEntryTile extends StatefulWidget {
  final _DiagnosticsLogEntry entry;
  final AppLocalizations l10n;

  const _DiagnosticsLogEntryTile({required this.entry, required this.l10n});

  @override
  State<_DiagnosticsLogEntryTile> createState() =>
      _DiagnosticsLogEntryTileState();
}

class _DiagnosticsLogEntryTileState extends State<_DiagnosticsLogEntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final localizedMessage = AppLogMessageLocalizer.localizeMessage(
      widget.l10n,
      widget.entry.message,
    );
    final details = widget.entry.detailEntries.toList(growable: false);
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final padding = _diagnosticsListRowPadding(context);

    return HyperosPressableRow(
      onTap: () => setState(() => _expanded = !_expanded),
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: padding,
        child: _expanded
            ? _buildExpanded(context, localizedMessage, details)
            : _buildCollapsed(context, localizedMessage),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context, String localizedMessage) {
    final levelColor = _levelColor(context, widget.entry.level);
    final time = widget.entry.formattedTime;
    final prefix = time == null ? '' : '$time ';
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: levelColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: HyperosTokens.rowContentGap),
        Expanded(
          child: Text(
            '$prefix$localizedMessage',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyperosTypography.listDetail(context).copyWith(height: 1.25),
          ),
        ),
        SizedBox(width: HyperosTokens.titleChevronGap),
        const HyperosChevron(),
      ],
    );
  }

  Widget _buildExpanded(
    BuildContext context,
    String localizedMessage,
    List<MapEntry<String, String>> details,
  ) {
    final levelColor = _levelColor(context, widget.entry.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: levelColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  HyperosMiuixTabRow.contourCornerRadius,
                ),
              ),
              child: Icon(
                _levelIcon(widget.entry.level),
                color: levelColor,
                size: 14,
              ),
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  HyperosTag(label: _levelLabel(widget.l10n, widget.entry.level)),
                  HyperosTag(
                    label: _sourceLabel(widget.l10n, widget.entry),
                    outlined: true,
                  ),
                  if (widget.entry.isLevelInferred)
                    HyperosTag(
                      label: widget.l10n.diagnosticsLevelInferred,
                      outlined: true,
                    ),
                  if (widget.entry.category.isNotEmpty)
                    Text(
                      AppLogMessageLocalizer.localizeCategory(
                        widget.l10n,
                        widget.entry.category,
                      ),
                      style: HyperosTypography.listDetail(context).copyWith(
                        color: HyperosColors.secondaryText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const HyperosUpDownChevron(),
          ],
        ),
        if (widget.entry.formattedTime != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.entry.formattedTime!,
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
            ),
          ),
        ],
        if (localizedMessage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            localizedMessage,
            style: HyperosTypography.listTitle(context).copyWith(
              fontSize: HyperosMiuixTypography.body2,
              height: 1.35,
            ),
          ),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (var i = 0; i < details.length; i++) ...[
            _DiagnosticsDetailRow(
              label: _prettyKey(details[i].key, widget.l10n),
              value: _inlineValue(details[i].value),
              compact: true,
            ),
            if (i != details.length - 1) const SizedBox(height: 6),
          ],
        ],
      ],
    );
  }
}

class _DiagnosticsDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;

  const _DiagnosticsDetailRow({
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 12),
      decoration: BoxDecoration(
        color: HyperosColors.rowHighlight(context),
        borderRadius: BorderRadius.circular(
          HyperosMiuixTabRow.contourCornerRadius,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: HyperosTypography.listDetail(context).copyWith(
              color: HyperosColors.secondaryText(context),
              fontWeight: FontWeight.w600,
              fontSize: compact ? HyperosMiuixTypography.footnote2 : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: HyperosTypography.listDetail(context).copyWith(
              fontFamily: value.contains('\n') ? 'monospace' : null,
              height: 1.35,
              fontSize: compact ? HyperosMiuixTypography.footnote2 : null,
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

  String? get formattedTime => _formatMillis(fields['time']);

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

String _sourceLabel(AppLocalizations l10n, _DiagnosticsLogEntry entry) {
  return entry.isNativeSource ? l10n.appLogsSourceNative : l10n.appLogsSourceApp;
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
  return switch (level) {
    DiagnosticsLogLevel.all => HyperosTokens.accent,
    DiagnosticsLogLevel.error => HyperosTokens.error,
    DiagnosticsLogLevel.warn => const Color(0xFFFF9F0A),
    DiagnosticsLogLevel.info => HyperosTokens.accent,
    DiagnosticsLogLevel.debug => HyperosColors.actionIcon(context),
    DiagnosticsLogLevel.verbose => HyperosColors.secondaryText(context),
  };
}

EdgeInsets _diagnosticsListRowPadding(BuildContext context) {
  final scope = HyperosListTileScope.maybeOf(context);
  return HyperosTokens.rowPadding(
    isFirst: scope?.isFirst ?? true,
    isLast: scope?.isLast ?? true,
  );
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
    default:
      return AppLogMessageLocalizer.localizeField(l10n, key);
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
