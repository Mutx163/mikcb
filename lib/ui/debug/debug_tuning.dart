import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

/// One numeric field exposed as a slider in [DebugTuningPanel].
class DebugTuningFieldSpec {
  const DebugTuningFieldSpec({
    required this.label,
    required this.min,
    required this.max,
    required this.read,
    required this.write,
    this.divisions,
  });

  final String label;
  final double min;
  final double max;
  final int? divisions;
  final double Function() read;
  final void Function(double value) write;
}

/// A group of debug sliders (e.g. HyperOS list, future MIUI widgets).
class DebugTuningSuite {
  const DebugTuningSuite({
    required this.id,
    required this.title,
    required this.notifier,
    required this.fields,
    this.onReset,
    this.exportJson,
  });

  final String id;
  final String title;
  final Listenable notifier;
  final List<DebugTuningFieldSpec> fields;
  final VoidCallback? onReset;
  final Map<String, num> Function()? exportJson;
}

/// Global registry for debug tuning suites.
class DebugTuningRegistry {
  DebugTuningRegistry._();

  static final DebugTuningRegistry instance = DebugTuningRegistry._();

  final List<DebugTuningSuite> suites = [];

  void register(DebugTuningSuite suite) {
    assert(
      !suites.any((s) => s.id == suite.id),
      'Duplicate debug tuning suite id: ${suite.id}',
    );
    suites.add(suite);
  }
}

/// Wraps the app body and shows the floating HyperOS tuning panel in
/// non-release builds.
class DebugTuningOverlayHost extends StatelessWidget {
  const DebugTuningOverlayHost({super.key, required this.child, this.enabled});

  final Widget child;

  /// Defaults to [!kReleaseMode] (debug + profile builds).
  final bool? enabled;

  bool get _enabled => enabled ?? !kReleaseMode;

  @override
  Widget build(BuildContext context) {
    if (!_enabled || DebugTuningRegistry.instance.suites.isEmpty) {
      return child;
    }
    // Host the panel in a local [Overlay]. This widget tree sits in
    // MaterialApp.builder *outside* the route Navigator, but [Slider] and
    // [Tooltip] need an [Overlay] ancestor for [OverlayPortal].
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Overlay(
          initialEntries: [
            OverlayEntry(builder: (context) => const DebugTuningPanel()),
          ],
        ),
      ],
    );
  }
}

/// Compact draggable slider panel for live UI tuning.
class DebugTuningPanel extends StatefulWidget {
  const DebugTuningPanel({super.key});

  @override
  State<DebugTuningPanel> createState() => _DebugTuningPanelState();
}

class _DebugTuningPanelState extends State<DebugTuningPanel> {
  static const _panelWidth = 208.0;
  static const _edgeMargin = 8.0;

  final GlobalKey _shellKey = GlobalKey();

  late int _suiteIndex;
  late List<double> _draftValues;
  bool _collapsed = false;

  /// Custom top-left position; null keeps the default top-right anchor.
  Offset? _position;

  DebugTuningSuite get _suite =>
      DebugTuningRegistry.instance.suites[_suiteIndex];

  @override
  void initState() {
    super.initState();
    _suiteIndex = 0;
    _draftValues = _readDraft();
    _suite.notifier.addListener(_syncDraftFromNotifier);
  }

  @override
  void dispose() {
    _suite.notifier.removeListener(_syncDraftFromNotifier);
    super.dispose();
  }

  void _syncDraftFromNotifier() {
    if (!mounted) return;
    setState(() => _draftValues = _readDraft());
  }

  List<double> _readDraft() {
    return _suite.fields.map((f) => f.read()).toList(growable: false);
  }

  void _onSuiteChanged(int? index) {
    if (index == null || index == _suiteIndex) return;
    _suite.notifier.removeListener(_syncDraftFromNotifier);
    setState(() {
      _suiteIndex = index;
      _draftValues = _readDraft();
    });
    _suite.notifier.addListener(_syncDraftFromNotifier);
  }

  void _applyField(int index, double value) {
    _suite.fields[index].write(value);
  }

  Future<void> _copyJson() async {
    final export = _suite.exportJson;
    if (export == null) return;
    await Clipboard.setData(ClipboardData(text: export().toString()));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(l10n.debugCopiedJson),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Size _estimatedPanelSize(MediaQueryData mq) {
    if (_collapsed) {
      return const Size(52, 30);
    }
    return Size(_panelWidth, mq.size.height * 0.55 + 72);
  }

  Size _measuredPanelSize(MediaQueryData mq) {
    final box = _shellKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size ?? _estimatedPanelSize(mq);
  }

  Offset _defaultPosition(MediaQueryData mq, Size panelSize) {
    return Offset(
      mq.size.width - panelSize.width - _edgeMargin,
      mq.padding.top + _edgeMargin,
    );
  }

  Offset _clampPosition(Offset position, MediaQueryData mq, Size panelSize) {
    final minX = mq.padding.left + _edgeMargin;
    final minY = mq.padding.top + _edgeMargin;
    final maxX =
        mq.size.width - panelSize.width - mq.padding.right - _edgeMargin;
    final maxY =
        mq.size.height - panelSize.height - mq.padding.bottom - _edgeMargin;
    return Offset(position.dx.clamp(minX, maxX), position.dy.clamp(minY, maxY));
  }

  Offset _resolvedPosition(MediaQueryData mq) {
    final panelSize = _measuredPanelSize(mq);
    final anchor = _position ?? _defaultPosition(mq, panelSize);
    return _clampPosition(anchor, mq, panelSize);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final mq = MediaQuery.of(context);
    final panelSize = _measuredPanelSize(mq);
    setState(() {
      final base = _position ?? _defaultPosition(mq, panelSize);
      _position = _clampPosition(base + details.delta, mq, panelSize);
    });
  }

  Widget _dragHandle({required Widget child}) {
    return GestureDetector(
      onPanUpdate: _onDragUpdate,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final suites = DebugTuningRegistry.instance.suites;
    final offset = _resolvedPosition(mq);

    Widget shell;
    if (_collapsed) {
      shell = Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.72),
        child: _dragHandle(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _collapsed = false),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.drag_indicator, size: 14, color: Colors.white54),
                  SizedBox(width: 4),
                  Text(
                    '调试',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      shell = Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: Colors.black.withValues(alpha: 0.78),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dragHandle(child: _buildHeader(suites)),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: mq.size.height * 0.55),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                child: Column(
                  children: [
                    for (var i = 0; i < _suite.fields.length; i++)
                      _buildSlider(i, _suite.fields[i]),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      );
    }

    return Positioned(
      key: _shellKey,
      left: offset.dx,
      top: offset.dy,
      width: _collapsed ? null : _panelWidth,
      child: shell,
    );
  }

  Widget _buildHeader(List<DebugTuningSuite> suites) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.drag_indicator, size: 16, color: Colors.white54),
          ),
          Expanded(
            child: suites.length <= 1
                ? Text(
                    _suite.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isDense: true,
                      isExpanded: true,
                      value: _suiteIndex,
                      dropdownColor: Colors.grey.shade900,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      items: [
                        for (var i = 0; i < suites.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(suites[i].title),
                          ),
                      ],
                      onChanged: _onSuiteChanged,
                    ),
                  ),
          ),
          InkWell(
            onTap: () => setState(() => _collapsed = true),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.remove, size: 16, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_suite.exportJson != null)
            _footerButton(Icons.copy, '复制', _copyJson),
          if (_suite.onReset != null)
            _footerButton(Icons.restart_alt, '重置', () {
              _suite.onReset?.call();
              setState(() => _draftValues = _readDraft());
            }),
        ],
      ),
    );
  }

  Widget _footerButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildSlider(int index, DebugTuningFieldSpec field) {
    final value = _draftValues[index].clamp(field.min, field.max);
    final label = field.label;
    final display = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                display,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: SliderComponentShape.noOverlay,
              activeTrackColor: const Color(0xFF3482FF),
              inactiveTrackColor: Colors.white24,
              thumbColor: Colors.white,
            ),
            child: Slider(
              min: field.min,
              max: field.max,
              divisions: field.divisions,
              value: value,
              onChanged: (v) => setState(() => _draftValues[index] = v),
              onChangeEnd: (v) => _applyField(index, v),
            ),
          ),
        ],
      ),
    );
  }
}
