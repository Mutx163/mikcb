import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../logging/app_log_message_localizer.dart';
import '../logging/diagnostics_log_parser.dart';
import '../services/diagnostics_log_viewer_preferences.dart';
import '../utils/app_toast.dart';

export '../logging/diagnostics_log_parser.dart' show DiagnosticsLogLevel;

enum DiagnosticsLogViewMode { structured, raw }

enum DiagnosticsLogTimeSort { ascending, descending }

class LiveDiagnosticsLogViewerScreen extends StatefulWidget {
  final String title;
  final String rawLog;
  final Future<String> Function()? loadRawLog;
  final Stream<String> Function()? watchRawLog;
  final VoidCallback? onLoadEmpty;

  /// 只读的记录状态，仅用于在列表顶部提示「记录已关闭」；开关本体在
  /// 「设置 → 诊断与日志」，本页保持纯查看。
  final bool? isRecordingEnabled;
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
  String _lastBody = '';
  bool _initializing = false;
  bool _parsing = false;
  String? _loadError;
  bool _clearing = false;
  bool _exporting = false;
  DiagnosticsLogSnapshot _parsed = DiagnosticsLogSnapshot.empty;
  Map<DiagnosticsLogLevel, int> _levelCounts = const {};
  List<DiagnosticsLogEntry> _visibleEntries = const [];
  StreamSubscription<String>? _logSubscription;
  final ScrollController _structuredScrollController = ScrollController();
  final ScrollController _rawScrollController = ScrollController();
  bool _stickToLatest = true;
  bool _isStreaming = false;
  bool _autoScrollPending = false;
  final Map<String, bool> _expandedEntryIds = <String, bool>{};
  bool _deviceInfoExpanded = false;
  Timer? _uiRefreshTimer;
  int _parseGeneration = 0;
  static const int _isolateParseThresholdBytes = 128 * 1024;

  @override
  void initState() {
    super.initState();
    _rawLog = widget.rawLog;
    _structuredScrollController.addListener(_onStructuredScroll);
    _rawScrollController.addListener(_onRawScroll);
    unawaited(_loadViewerPreferences());
    if (widget.watchRawLog != null) {
      _isStreaming = true;
      _startWatching();
    } else if (widget.loadRawLog != null) {
      _initializing = true;
      unawaited(_loadLogs());
    } else if (_rawLog.trim().isNotEmpty) {
      if (_rawLog.length <= _isolateParseThresholdBytes) {
        _parsed = parseDiagnosticsLog(_rawLog, fallbackTitle: widget.title);
        _lastBody = extractDiagnosticsLogBody(_rawLog);
        _rebuildVisibleEntries();
      } else {
        unawaited(_applyFullLogText(_rawLog, isFirstEmission: true));
      }
    }
  }

  Future<void> _loadViewerPreferences() async {
    final sort = await DiagnosticsLogViewerPreferences.loadTimeSort();
    if (!mounted) {
      return;
    }
    setState(() {
      _timeSort = sort == DiagnosticsLogViewerPreferences.descending
          ? DiagnosticsLogTimeSort.descending
          : DiagnosticsLogTimeSort.ascending;
    });
    _rebuildVisibleEntries();
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
    _rebuildVisibleEntries();
    if (_stickToLatest) {
      _scheduleAutoScroll();
    }
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _uiRefreshTimer?.cancel();
    _structuredScrollController
      ..removeListener(_onStructuredScroll)
      ..dispose();
    _rawScrollController
      ..removeListener(_onRawScroll)
      ..dispose();
    super.dispose();
  }

  void _startWatching() {
    _loadError = null;
    _logSubscription = widget.watchRawLog!().listen(
      (loaded) {
        if (!mounted) {
          return;
        }
        unawaited(_applyLoadedLog(loaded));
      },
      onError: (Object error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _initializing = false;
          _parsing = false;
          _loadError = error.toString();
        });
      },
    );
  }

  Future<void> _applyLoadedLog(String loaded) async {
    final body = extractDiagnosticsLogBody(loaded);
    if (body.trim().isEmpty &&
        _parsed.entries.isEmpty &&
        widget.onLoadEmpty != null) {
      widget.onLoadEmpty!();
      return;
    }
    if (body == _lastBody) {
      if (_initializing || _parsing) {
        setState(() {
          _initializing = false;
          _parsing = false;
          _loadError = null;
        });
      }
      return;
    }

    final previousCount = _parsed.entries.length;
    final previousBody = _lastBody;
    final isAppend =
        previousBody.isNotEmpty &&
        body.startsWith(previousBody) &&
        body.length > previousBody.length;
    _rawLog = loaded;
    _lastBody = body;
    _loadError = null;

    if (isAppend) {
      final appendedBody = body.substring(previousBody.length);
      _parsed = appendDiagnosticsLogBody(
        _parsed,
        appendedBody,
        mergedFullText: loaded,
      );
      _rebuildVisibleEntries();
      _scheduleUiRefresh();
      if (_initializing || _parsing) {
        setState(() {
          _initializing = false;
          _parsing = false;
        });
      }
    } else {
      if (!_parsing && !_initializing) {
        _parsing = true;
        _scheduleUiRefresh();
      }
      await _parseFullLogText(
        loaded,
        previousCount: previousCount,
        isFirstEmission: previousCount == 0,
      );
    }
  }

  Future<void> _applyFullLogText(
    String loaded, {
    required bool isFirstEmission,
  }) async {
    final body = extractDiagnosticsLogBody(loaded);
    if (body.trim().isEmpty && isFirstEmission && widget.onLoadEmpty != null) {
      widget.onLoadEmpty!();
      return;
    }
    _rawLog = loaded;
    _lastBody = body;
    _loadError = null;
    _parsing = true;
    _scheduleUiRefresh();
    await _parseFullLogText(
      loaded,
      previousCount: 0,
      isFirstEmission: isFirstEmission,
    );
  }

  Future<DiagnosticsLogSnapshot> _parseLogSnapshot(String loaded) async {
    if (kIsWeb || loaded.length <= _isolateParseThresholdBytes) {
      return parseDiagnosticsLog(loaded, fallbackTitle: widget.title);
    }
    return compute(parseDiagnosticsLogIsolate, loaded);
  }

  Future<void> _parseFullLogText(
    String loaded, {
    required int previousCount,
    required bool isFirstEmission,
  }) async {
    final generation = ++_parseGeneration;
    final parsed = await _parseLogSnapshot(loaded);
    if (!mounted || generation != _parseGeneration) {
      return;
    }
    setState(() {
      _parsed = parsed.title.isEmpty
          ? parsed.copyWith(title: widget.title)
          : parsed;
      _initializing = false;
      _parsing = false;
      _rebuildVisibleEntries();
    });
    final shouldFollowLatest =
        _stickToLatest &&
        (isFirstEmission ||
            (_isStreaming && _parsed.entries.length > previousCount));
    if (shouldFollowLatest) {
      _scheduleAutoScroll();
    }
  }

  void _rebuildVisibleEntries() {
    _levelCounts = countDiagnosticsLevels(_parsed.entries);
    _visibleEntries = sortDiagnosticsEntries(
      filterDiagnosticsEntries(_parsed.entries, _selectedLevel),
      ascending: _timeSort == DiagnosticsLogTimeSort.ascending,
    );
  }

  void _scheduleUiRefresh() {
    if (_uiRefreshTimer?.isActive ?? false) {
      return;
    }
    final delay = _isStreaming
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 16);
    _uiRefreshTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _rebuildVisibleEntries();
      });
      if (_stickToLatest) {
        _scheduleAutoScroll();
      }
    });
  }

  bool get _latestAtBottom => _timeSort == DiagnosticsLogTimeSort.ascending;

  void _onStructuredScroll() {
    if (!_structuredScrollController.hasClients) {
      return;
    }
    final position = _structuredScrollController.position;
    if (_latestAtBottom) {
      _stickToLatest = position.pixels >= position.maxScrollExtent - 48;
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
      _stickToLatest = position.pixels >= position.maxScrollExtent - 48;
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
    if (!_stickToLatest || attempt > 2) {
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
      _initializing = true;
      _loadError = null;
    });
    try {
      final loaded = await widget.loadRawLog!();
      if (!mounted) {
        return;
      }
      await _applyFullLogText(loaded, isFirstEmission: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _parsing = false;
        _loadError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showControls = _loadError == null;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.title),
      suffixes: _buildHeaderActions(l10n),
      headerExtension: showControls
          ? HyperosBlurredHeaderExtension(
              // 头部扩展区只放固定高度的等级筛选条：曾经这里住着记录开关和
              // 可折叠的「查看与排序」卡，高度一变，body 顶部的测量缓存
              // inset 跟不上就留出一大片空白；现在扩展区高度恒定，页面
              // 主体整页让给日志列表。
              child: _buildLevelFilterBar(context, l10n),
            )
          : null,
      child: HyperosBlurredBodyInset(
        child: _loadError != null
            ? _buildLoadError(context, l10n)
            : _buildLogBody(context, l10n),
      ),
    );
  }

  List<FHeaderAction> _buildHeaderActions(AppLocalizations l10n) {
    if (_loadError != null) {
      return const [];
    }

    final filteredRawText = buildFilteredDiagnosticsRawText(
      _parsed,
      _visibleEntries,
    );

    return [
      FHeaderAction(
        icon: const Icon(Icons.tune_rounded),
        semanticsLabel: l10n.diagnosticsDisplayOptionsTitle,
        onPress: () => _showDisplayOptionsSheet(context),
      ),
      FHeaderAction(
        icon: const Icon(Icons.copy_all_rounded),
        semanticsLabel: l10n.appLogsCopyAction,
        onPress: _parsed.entries.isEmpty
            ? null
            : () => _copyLogs(filteredRawText),
      ),
      FHeaderAction(
        icon: _exporting
            ? const HyperosCircularProgress(size: 18, strokeWidth: 2)
            : const Icon(Icons.ios_share_rounded),
        semanticsLabel: l10n.appLogsExportAction,
        onPress:
            widget.onExport == null || _exporting || _parsed.entries.isEmpty
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
              color: HyperosColors.error(context),
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
    if (_initializing && _parsed.entries.isEmpty) {
      return const Center(child: HyperosCircularProgress());
    }
    if (_parsed.entries.isEmpty && !_parsing) {
      return _buildEmptyState(context, l10n);
    }
    if (_viewMode == DiagnosticsLogViewMode.raw) {
      return _buildRawView(context, l10n);
    }
    return _buildStructuredView(context, l10n);
  }

  Widget _buildLevelFilterBar(BuildContext context, AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                for (var i = 0; i < DiagnosticsLogLevel.values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _LevelFilterChip(
                    label:
                        '${_levelLabel(l10n, DiagnosticsLogLevel.values[i])} ${_levelCounts[DiagnosticsLogLevel.values[i]] ?? 0}',
                    selected: _selectedLevel == DiagnosticsLogLevel.values[i],
                    onPress: () {
                      setState(() {
                        _selectedLevel = DiagnosticsLogLevel.values[i];
                        _rebuildVisibleEntries();
                      });
                      if (_stickToLatest) {
                        _scheduleAutoScroll();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_parsing) ...[
          const SizedBox(width: 8),
          const HyperosCircularProgress(size: 14, strokeWidth: 2),
        ],
      ],
    );
  }

  Future<void> _showDisplayOptionsSheet(BuildContext context) async {
    await showHyperosSheet<void>(
      context: context,
      enableDrag: false,
      builder: (sheetContext) => _DisplayOptionsSheet(
        viewMode: _viewMode,
        timeSort: _timeSort,
        onViewModeChanged: (mode) {
          if (mode == _viewMode) {
            return;
          }
          setState(() {
            _viewMode = mode;
          });
          if (_stickToLatest) {
            _scheduleAutoScroll();
          }
        },
        onTimeSortChanged: _setTimeSort,
      ),
    );
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
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.secondaryText(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStructuredView(BuildContext context, AppLocalizations l10n) {
    if (_visibleEntries.isEmpty && _parsed.entries.isNotEmpty) {
      return _buildNoMatchingState(context, l10n);
    }

    final hasHeader = _parsed.headerEntries.isNotEmpty;
    final showPausedHint =
        widget.isRecordingEnabled == false && _parsed.entries.isNotEmpty;
    final itemCount =
        _visibleEntries.length + (hasHeader ? 1 : 0) + (showPausedHint ? 1 : 0);

    return ListView.builder(
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
      scrollCacheExtent: const ScrollCacheExtent.pixels(640),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showPausedHint && index == 0) {
          return Padding(
            padding: EdgeInsets.only(
              left: HyperosTokens.listPadding.left,
              right: HyperosTokens.listPadding.right,
              bottom: 8,
            ),
            child: Text(
              l10n.appLogsRecordingPausedHint,
              style: HyperosTypography.sectionDescription(context),
            ),
          );
        }
        final adjustedIndex = index - (showPausedHint ? 1 : 0);
        if (hasHeader && adjustedIndex == 0) {
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HyperosListGroup(
                children: [
                  _DiagnosticsHeaderRow(
                    parsed: _parsed,
                    l10n: l10n,
                    expanded: _deviceInfoExpanded,
                    onToggle: () {
                      setState(() {
                        _deviceInfoExpanded = !_deviceInfoExpanded;
                      });
                    },
                  ),
                ],
              ),
            ),
          );
        }

        final entryIndex = adjustedIndex - (hasHeader ? 1 : 0);
        final entry = _visibleEntries[entryIndex];
        return RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: entryIndex == _visibleEntries.length - 1 ? 0 : 8,
            ),
            child: HyperosListGroup(
              children: [
                _DiagnosticsLogEntryTile(
                  key: ValueKey(entry.stableId),
                  entry: entry,
                  l10n: l10n,
                  expanded: _expandedEntryIds[entry.stableId] ?? false,
                  onToggle: () {
                    setState(() {
                      _expandedEntryIds[entry.stableId] =
                          !(_expandedEntryIds[entry.stableId] ?? false);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
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
              style: HyperosTypography.listDetail(
                context,
              ).copyWith(color: HyperosColors.secondaryText(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRawView(BuildContext context, AppLocalizations l10n) {
    if (_visibleEntries.isEmpty && _parsed.entries.isNotEmpty) {
      return _buildNoMatchingState(context, l10n);
    }

    return ListView.builder(
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
      scrollCacheExtent: const ScrollCacheExtent.pixels(480),
      itemCount: _visibleEntries.length,
      itemBuilder: (context, index) {
        final entry = _visibleEntries[index];
        return RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: index == _visibleEntries.length - 1 ? 0 : 8,
            ),
            child: HyperosControlCard(
              child: Text(
                entry.rawBlock.trim(),
                style: HyperosTypography.listDetail(
                  context,
                ).copyWith(fontFamily: 'monospace', height: 1.45),
              ),
            ),
          ),
        );
      },
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
      _parseGeneration++;
      _lastBody = '';
      _expandedEntryIds.clear();
      setState(() {
        _rawLog = '';
        _parsed = DiagnosticsLogSnapshot.empty;
        _rebuildVisibleEntries();
      });
      if (widget.loadRawLog != null) {
        await _loadLogs();
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

/// 「查看与排序」弹层：结构化/原文 + 时间排序。
///
/// 弹层自持一份选中态用于即时高亮，变更经回调同步给页面（页面负责
/// 持久化与重排）；不直接复用页面状态，避免弹层内每次点击都整页重建。
class _DisplayOptionsSheet extends StatefulWidget {
  const _DisplayOptionsSheet({
    required this.viewMode,
    required this.timeSort,
    required this.onViewModeChanged,
    required this.onTimeSortChanged,
  });

  final DiagnosticsLogViewMode viewMode;
  final DiagnosticsLogTimeSort timeSort;
  final ValueChanged<DiagnosticsLogViewMode> onViewModeChanged;
  final ValueChanged<DiagnosticsLogTimeSort> onTimeSortChanged;

  @override
  State<_DisplayOptionsSheet> createState() => _DisplayOptionsSheetState();
}

class _DisplayOptionsSheetState extends State<_DisplayOptionsSheet> {
  late DiagnosticsLogViewMode _viewMode = widget.viewMode;
  late DiagnosticsLogTimeSort _timeSort = widget.timeSort;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSheet(
      title: l10n.diagnosticsDisplayOptionsTitle,
      description: l10n.diagnosticsLogIntro,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosSegmentedControl(
                tabs: [
                  l10n.diagnosticsStructuredTab,
                  l10n.diagnosticsRawTab,
                ],
                selectedIndex:
                    _viewMode == DiagnosticsLogViewMode.structured ? 0 : 1,
                onChanged: (index) {
                  final mode = index == 0
                      ? DiagnosticsLogViewMode.structured
                      : DiagnosticsLogViewMode.raw;
                  if (mode == _viewMode) {
                    return;
                  }
                  setState(() {
                    _viewMode = mode;
                  });
                  widget.onViewModeChanged(mode);
                },
              ),
              const SizedBox(height: 12),
              HyperosSegmentedControl(
                tabs: [
                  l10n.diagnosticsTimeSortAscending,
                  l10n.diagnosticsTimeSortDescending,
                ],
                selectedIndex:
                    _timeSort == DiagnosticsLogTimeSort.ascending ? 0 : 1,
                onChanged: (index) {
                  final sort = index == 0
                      ? DiagnosticsLogTimeSort.ascending
                      : DiagnosticsLogTimeSort.descending;
                  if (sort == _timeSort) {
                    return;
                  }
                  setState(() {
                    _timeSort = sort;
                  });
                  widget.onTimeSortChanged(sort);
                },
              ),
            ],
          ),
        ),
      ),
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
        ? HyperosColors.primary(context).withValues(alpha: isDark ? 0.22 : 0.12)
        : HyperosColors.surface(context);
    final textColor = selected
        ? HyperosColors.primary(context)
        : HyperosColors.secondaryText(context);

    return MiuixPressable(
      onPressed: onPress,
      borderRadius: BorderRadius.circular(
        HyperosMiuixTabRow.contourCornerRadius,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(
            HyperosMiuixTabRow.contourCornerRadius,
          ),
        ),
        child: Text(
          label,
          style: HyperosTypography.listDetail(context).copyWith(
            color: textColor,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsHeaderRow extends StatelessWidget {
  final DiagnosticsLogSnapshot parsed;
  final AppLocalizations l10n;
  final bool expanded;
  final VoidCallback onToggle;

  const _DiagnosticsHeaderRow({
    required this.parsed,
    required this.l10n,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final padding = _diagnosticsListRowPadding(context);

    return HyperosPressableRow(
      onTap: onToggle,
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
                    l10n.diagnosticsDeviceInfoTitle,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
                const HyperosUpDownChevron(),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: parsed.headerEntries.entries
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
                          '${_prettyKey(item.key, l10n)}: ${_inlineValue(item.value)}',
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

class _DiagnosticsLogEntryTile extends StatelessWidget {
  final DiagnosticsLogEntry entry;
  final AppLocalizations l10n;
  final bool expanded;
  final VoidCallback onToggle;

  const _DiagnosticsLogEntryTile({
    super.key,
    required this.entry,
    required this.l10n,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final localizedMessage = AppLogMessageLocalizer.localizeMessage(
      l10n,
      entry.message,
    );
    final details = entry.detailEntries.toList(growable: false);
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final padding = _diagnosticsListRowPadding(context);

    return HyperosPressableRow(
      onTap: onToggle,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: padding,
        child: expanded
            ? _buildExpanded(context, localizedMessage, details)
            : _buildCollapsed(context, localizedMessage),
      ),
    );
  }

  Widget _buildCollapsed(BuildContext context, String localizedMessage) {
    final levelColor = _levelColor(context, entry.level);
    final time = entry.formattedTime;
    final prefix = time == null ? '' : '$time ';
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: levelColor, shape: BoxShape.circle),
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
    final levelColor = _levelColor(context, entry.level);
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
              child: Icon(_levelIcon(entry.level), color: levelColor, size: 14),
            ),
            const SizedBox(width: HyperosTokens.rowContentGap),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  HyperosTag(label: _levelLabel(l10n, entry.level)),
                  HyperosTag(label: _sourceLabel(l10n, entry), outlined: true),
                  if (entry.isLevelInferred)
                    HyperosTag(
                      label: l10n.diagnosticsLevelInferred,
                      outlined: true,
                    ),
                  if (entry.category.isNotEmpty)
                    Text(
                      AppLogMessageLocalizer.localizeCategory(
                        l10n,
                        entry.category,
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
        if (entry.formattedTime != null) ...[
          const SizedBox(height: 4),
          Text(
            entry.formattedTime!,
            style: HyperosTypography.listDetail(
              context,
            ).copyWith(color: HyperosColors.secondaryText(context)),
          ),
        ],
        if (localizedMessage.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            localizedMessage,
            style: HyperosTypography.listTitle(
              context,
            ).copyWith(fontSize: HyperosMiuixTypography.body2, height: 1.35),
          ),
        ],
        if (details.isNotEmpty) ...[
          const SizedBox(height: 6),
          for (var i = 0; i < details.length; i++) ...[
            _DiagnosticsDetailRow(
              label: _prettyKey(details[i].key, l10n),
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

String _sourceLabel(AppLocalizations l10n, DiagnosticsLogEntry entry) {
  return entry.isNativeSource
      ? l10n.appLogsSourceNative
      : l10n.appLogsSourceApp;
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
    DiagnosticsLogLevel.all => HyperosColors.primary(context),
    DiagnosticsLogLevel.error => HyperosColors.error(context),
    DiagnosticsLogLevel.warn => const Color(0xFFFF9F0A),
    DiagnosticsLogLevel.info => HyperosColors.primary(context),
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
  final formattedTime = formatDiagnosticsMillis(value);
  return formattedTime ?? value;
}
