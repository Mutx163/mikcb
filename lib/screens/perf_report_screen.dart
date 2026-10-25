// Per-page performance report (diagnostics builds only).
//
// Why every string here is English while the rest of the app is localized:
// the repo keeps a ratchet over hardcoded CJK lines
// (`tool/cjk_hardcode_baseline.txt`, "only decreases allowed"), and that
// baseline is a to-do list, not an exemption register — new Chinese strings in
// a new file raise the total and turn the CI gate red. Diagnostic output
// already follows the same convention for the same reason (`[frame-perf]`,
// `[first-frame]`). This page is only reachable from a diagnostics build, so
// it does not need translating.
//
// It is deliberately NOT registered in the home-menu catalog: the catalog
// reconciliation test requires every catalog page destination to also appear on
// the "all features" page, which would mean editing six ARB files that another
// session is rewriting. Entry is instead the memory-stats diagnostics page
// (already gated to `.debug` / `.profile`) plus a debug deep link.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';
import '../utils/perf_probe.dart';

class PerfReportScreen extends StatefulWidget {
  const PerfReportScreen({super.key});

  @override
  State<PerfReportScreen> createState() => _PerfReportScreenState();
}

class _PerfReportScreenState extends State<PerfReportScreen> {
  /// Refresh cadence. The probe itself only writes every 5s **when new frames
  /// arrived**, so re-reading faster than that would be pure waste — and a
  /// diagnostics page that burns frames is exactly the thing we are hunting.
  static const Duration _refreshInterval = Duration(seconds: 5);

  Map<String, Object?>? _snapshot;
  Timer? _timer;
  bool _showRaw = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _timer = Timer.periodic(_refreshInterval, (_) => _reload());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reload() {
    if (!mounted) {
      return;
    }
    setState(() {
      _snapshot = PerfProbe.isInstalled ? PerfProbe.snapshotJson() : null;
    });
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showAppToast(context, message: 'copied', kind: AppToastKind.success);
    }
  }

  Future<void> _exportFiles() async {
    final path = await PerfProbe.exportSnapshot();
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: path == null ? 'export failed (see console)' : 'exported',
      description: path,
      kind: path == null ? AppToastKind.error : AppToastKind.success,
    );
  }

  void _clearLedger() {
    PerfProbe.reset();
    _reload();
    if (mounted) {
      showAppToast(context, message: 'ledger cleared');
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final pages = _mapList(snapshot?['pages']);
    final startup = _mapList(snapshot?['startup']);
    final totals = _map(snapshot?['totals']);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: const Text('Perf Report'),
      suffixes: [
        HyperosIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Refresh now',
          onPressed: _reload,
        ),
        HyperosIconButton(
          icon: Icons.save_alt_rounded,
          tooltip: 'Export timestamped files',
          onPressed: snapshot == null ? null : _exportFiles,
        ),
      ],
      child: HyperosListView(
        children: [
          if (snapshot == null)
            const HyperosSectionDescription(
              text: 'Probe is not installed in this build. Rebuild with '
                  '--dart-define=PERF_PROBE=true, or use a .debug / .profile '
                  'package.',
            )
          else ...[
            const HyperosSectionLabel(text: 'Totals'),
            HyperosSummaryCard(
              // accent 省略即用默认的 blue：显式传一遍是冗余实参。
              leading: const HyperosIconBadge(icon: Icons.speed_rounded),
              summary: '${totals['janky'] ?? 0} / ${totals['frames'] ?? 0}',
              title: 'janky / total frames',
              // 判据三栏取自快照的 probe 块（不是排行首行的副本）。
              // budget 是实际生效的阈值、nominal 是显示上报值、observed 是实测
              // vsync —— 三个一起看才能判断「这次收紧对不对」：首轮探针只报生效
              // 值，把 120Hz 面板上的卡顿读成全绿就是栽在这上面。
              subtitle: 'pages ${totals['pages'] ?? 0}  '
                  'janky ${totals['jankyPct'] ?? '0.0'}%  '
                  'budget ${_probeOf(snapshot)['budgetMs']}ms '
                  '(nominal ${_probeOf(snapshot)['nominalMs']}ms, '
                  'vsync ${_probeOf(snapshot)['observedVsyncMs']}ms)  '
                  'rate ${_fmtNum(snapshot['refreshRateHz'])}Hz',
            ),
            const HyperosSectionGap(),

            const HyperosSectionLabel(text: 'Startup phases'),
            if (startup.isEmpty)
              const HyperosSectionDescription(
                text: 'No startup phase recorded in this session.',
              )
            else
              HyperosListGroup(
                children: [
                  for (final row in startup)
                    HyperosListTile(
                      icon: Icons.timeline_rounded,
                      iconAccent: HyperosIconColors.teal,
                      title: '${row['phase']}',
                      details: '${row['stepMs']} ms',
                      subtitle: 'since start ${row['totalMs']} ms',
                    ),
                ],
              ),
            const HyperosSectionGap(),

            const HyperosSectionLabel(text: 'Per-page ranking'),
            if (pages.isEmpty)
              const HyperosSectionDescription(
                text: 'No page has rendered a frame yet.',
              )
            else
              HyperosListGroup(
                children: [
                  for (final row in pages) _pageTile(row),
                ],
              ),
            const HyperosSectionGap(),

            const HyperosSectionLabel(text: 'Round control'),
            HyperosListGroup(
              children: [
                HyperosListTile(
                  icon: Icons.delete_sweep_rounded,
                  iconAccent: HyperosIconColors.orange,
                  title: 'Clear ledger',
                  details: '${PerfProbe.observedFrames} frames',
                  subtitle: 'start a fresh sweep round',
                  onTap: _clearLedger,
                ),
                HyperosListTile(
                  icon: Icons.description_outlined,
                  iconAccent: HyperosIconColors.indigo,
                  title: _showRaw ? 'Hide raw report' : 'Show raw report',
                  onTap: () => setState(() => _showRaw = !_showRaw),
                ),
                if (_showRaw)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SelectableText(
                          PerfProbe.reportText(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 8),
                        HyperosListTile(
                          icon: Icons.content_copy_outlined,
                          iconAccent: HyperosIconColors.blue,
                          title: 'Copy text report',
                          onTap: () => _copyText(PerfProbe.reportText()),
                        ),
                        HyperosListTile(
                          icon: Icons.data_object_outlined,
                          iconAccent: HyperosIconColors.purple,
                          title: 'Copy JSON snapshot',
                          onTap: () => _copyText(
                            const JsonEncoder.withIndent('  ').convert(snapshot),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const HyperosSectionGap(),
            const HyperosSectionDescription(
              text: 'Energy columns are proxies, not power draw. cpuMs is a '
                  'page\'s share of process CPU time; rssDeltaKb is its '
                  'resident-memory growth. This device exposes no readable '
                  'battery current or GPU frequency without root, so nothing '
                  'here is watts or mAh — compare two builds, do not read '
                  'absolute power out of it. budgetMs is the per-frame '
                  'allowance, tightened to the measured vsync gap; verdict '
                  'names the thread that blew it (ui = build/layout/paint, '
                  'raster = GPU/offscreen layers/blur).',
            ),
          ],
        ],
      ),
    );
  }

  Widget _pageTile(Map<String, Object?> row) {
    final frames = _asInt(row['frames']);
    final janky = _asInt(row['janky']);
    final ratio = frames == 0 ? 0.0 : janky / frames;
    return HyperosListTile(
      icon: _iconForVerdict('${row['verdict']}'),
      iconAccent: ratio >= 0.25
          ? HyperosIconColors.red
          : ratio >= 0.05
          ? HyperosIconColors.yellow
          : HyperosIconColors.green,
      title: '${row['page']}',
      details: '${row['fps'] ?? '?'} fps   $janky/$frames',
      subtitle: 'build worst ${row['worstBuildMs']}/${row['avgBuildMs']} ms  '
          'raster ${row['worstRasterMs']}/${row['avgRasterMs']} ms  '
          'first ${row['firstFrameMs'] ?? '?'} ms  '
          'cpu ${row['cpuMs'] ?? '?'} ms  rss ${row['rssDeltaKb'] ?? '?'} KB',
    );
  }

  static IconData _iconForVerdict(String verdict) => switch (verdict) {
    'ui-bound' => Icons.build_circle_outlined,
    'raster-bound' => Icons.memory_outlined,
    'both' => Icons.compare_arrows_rounded,
    _ => Icons.help_outline_rounded,
  };

  static int _asInt(Object? value) => value is int ? value : 0;

  /// 快照的判据块。缺块时三栏都给 '?'：宁可显示「没量到」，
  /// 也不要拿 0 去填一个「阈值是 0 毫秒」的假判据。
  static Map<String, Object?> _probeOf(Map<String, Object?> snapshot) {
    final probe = snapshot['probe'];
    if (probe is! Map) {
      return const <String, Object?>{
        'budgetMs': '?',
        'nominalMs': '?',
        'observedVsyncMs': '?',
      };
    }
    return Map<String, Object?>.from(probe);
  }

  static String _fmtNum(Object? value) =>
      value is num ? value.toStringAsFixed(0) : '$value';

  static Map<String, Object?> _map(Object? value) => value is Map
      ? Map<String, Object?>.from(value)
      : const <String, Object?>{};

  static List<Map<String, Object?>> _mapList(Object? value) {
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return [
      for (final entry in value)
        if (entry is Map) Map<String, Object?>.from(entry),
    ];
  }
}
