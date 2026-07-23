import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/memory_stats_service.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/app_toast.dart';

/// 公平运行内存 / 全应用内存监控页（仅调试版、性能版入口）。
///
/// 统计整包 UID 下进程（含超级岛服务所在进程），不修改业务数据。
class MemoryStatsScreen extends StatefulWidget {
  const MemoryStatsScreen({super.key});

  @override
  State<MemoryStatsScreen> createState() => _MemoryStatsScreenState();
}

class _MemoryStatsScreenState extends State<MemoryStatsScreen>
    with WidgetsBindingObserver {
  static const Duration _autoRefreshInterval = Duration(seconds: 3);

  Map<String, dynamic>? _snapshot;
  bool _loading = true;
  bool _refreshInFlight = false;
  bool _autoRefreshEnabled = true;
  bool _isAppResumed = true;
  String? _errorText;
  DateTime? _lastRefreshedAt;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh(showLoading: true));
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (!mounted || !_isAppResumed || !_autoRefreshEnabled) {
        return;
      }
      unawaited(_refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh({bool showLoading = false}) async {
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _errorText = null;
      });
    }
    try {
      final snapshot = await MemoryStatsService.instance.fetchSnapshot();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _lastRefreshedAt = DateTime.now();
        _errorText = snapshot['error']?.toString();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _errorText = error.toString();
      });
    } finally {
      _refreshInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final app = MemoryStatsService.asStringKeyMap(snapshot?['app']);
    final javaHeap = MemoryStatsService.asStringKeyMap(snapshot?['javaHeap']);
    final debugMemory = MemoryStatsService.asStringKeyMap(
      snapshot?['debugMemoryInfo'],
    );
    final system = MemoryStatsService.asStringKeyMap(snapshot?['system']);
    final liveIsland = MemoryStatsService.asStringKeyMap(
      snapshot?['liveIsland'],
    );
    final fairMemory = MemoryStatsService.asStringKeyMap(
      snapshot?['fairMemory'],
    );
    final dartVm = MemoryStatsService.asStringKeyMap(snapshot?['dartVm']);
    final imageCache = MemoryStatsService.asStringKeyMap(
      snapshot?['flutterImageCache'],
    );
    final processes = MemoryStatsService.asMapList(snapshot?['processes']);
    final history = MemoryStatsService.asMapList(snapshot?['history']);
    final backgroundStats = MemoryStatsService.asStringKeyMap(
      snapshot?['backgroundStats'],
    );
    final appInForeground = snapshot?['appInForeground'] == true;
    final appStateLabel = appInForeground ? '前台' : '后台';

    final pressureLevel = snapshot?['pressureLevel']?.toString() ?? 'normal';
    final pressureLabel = snapshot?['pressureLabel']?.toString() ?? '—';
    final totalPssText = MemoryStatsService.formatKb(
      MemoryStatsService.asInt(app['totalPssKb']),
    );
    final peakPssText = MemoryStatsService.formatKb(
      MemoryStatsService.asInt(app['peakTotalPssKb']),
    );
    final heapUsage =
        MemoryStatsService.asDouble(javaHeap['usageRatio']) ?? 0.0;
    final refreshedText = _lastRefreshedAt == null
        ? '尚未刷新'
        : _formatClock(_lastRefreshedAt!);

    final analysis = MemoryStatsService.asStringKeyMap(snapshot?['analysis']);
    final cleanable = MemoryStatsService.asStringKeyMap(
      analysis['cleanableEstimate'],
    );
    final analysisBullets = analysis['bullets'] is List
        ? (analysis['bullets'] as List)
              .map((item) => item.toString())
              .toList(growable: false)
        : const <String>[];
    final breakdown = MemoryStatsService.asStringKeyMap(
      snapshot?['pssBreakdown'],
    );
    final orderedKeys = breakdown['ordered'] is List
        ? (breakdown['ordered'] as List).map((item) => item.toString()).toList()
        : const <String>[
            'privateOther',
            'system',
            'graphics',
            'nativeHeap',
            'javaHeap',
            'code',
            'stack',
          ];
    final memoryStats = MemoryStatsService.asStringKeyMap(
      snapshot?['memoryStats'],
    );

    final copyJson = snapshot == null
        ? null
        : () async {
            final text = const JsonEncoder.withIndent('  ').convert(snapshot);
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              showAppToast(
                context,
                message: '已复制内存快照 JSON',
                kind: AppToastKind.success,
              );
            }
          };

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: const Text('内存统计'),
      suffixes: [
        HyperosIconButton(
          icon: _loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
          tooltip: '立即刷新',
          onPressed: _loading ? null : () => _refresh(showLoading: true),
        ),
        HyperosIconButton(
          icon: Icons.content_copy_outlined,
          tooltip: '复制 JSON',
          onPressed: copyJson,
        ),
      ],
      child: HyperosListView(
        children: [
          const HyperosSectionLabel(text: '运行概览'),
          HyperosSummaryCard(
            leading: HyperosIconBadge(
              icon: Icons.memory_rounded,
              accent: _pressureColor(pressureLevel),
            ),
            summary: totalPssText,
            title: '整包总 PSS',
            subtitle: '压力 $pressureLabel · $appStateLabel · 峰值 $peakPssText',
            onTap: () =>
                _showOverviewSheet(context, snapshot: snapshot, app: app),
          ),
          HyperosSectionDescription(
            text:
                '统计主进程与同 UID 的其它进程（含超级岛服务）。数据每 ${_autoRefreshInterval.inSeconds} 秒更新一次，可在下方关闭自动采样。最近刷新：$refreshedText',
          ),
          const HyperosSectionGap(),
          if (_loading && snapshot == null) ...[
            HyperosHintBanner(
              icon: const HyperosCircularProgress(size: 18, strokeWidth: 2),
              title: const Text('正在读取当前内存快照…'),
            ),
            const HyperosSectionGap(),
          ],
          if (_errorText != null) ...[
            HyperosHintBanner(
              icon: Icon(
                Icons.error_outline_rounded,
                color: HyperosIconColors.red,
              ),
              title: Text(_errorText!),
            ),
            const HyperosSectionGap(),
          ],
          const HyperosSectionLabel(text: '采样控制'),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                icon: Icons.autorenew_rounded,
                iconAccent: HyperosIconColors.blue,
                value: _autoRefreshEnabled,
                onChanged: (value) =>
                    setState(() => _autoRefreshEnabled = value),
                title: '自动刷新',
                subtitle: _autoRefreshEnabled
                    ? '每 ${_autoRefreshInterval.inSeconds} 秒采样一次'
                    : '已关闭自动刷新，使用右上角按钮手动更新',
              ),
            ],
          ),
          const HyperosSectionGap(),
          const HyperosSectionLabel(text: '内存构成'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.data_usage_rounded,
                iconAccent: heapUsage >= 0.85
                    ? HyperosIconColors.red
                    : HyperosIconColors.blue,
                title: 'Java 堆',
                details: MemoryStatsService.formatPercent(heapUsage),
                onTap: () => _showKvSheet(
                  context,
                  title: 'Java 堆',
                  description: '用于观察接近 OOM 的风险，不代表整包 PSS。',
                  rows: [
                    _Kv(
                      '已用 / 上限',
                      '${MemoryStatsService.formatBytes(MemoryStatsService.asInt(javaHeap['allocBytes']))} / ${MemoryStatsService.formatBytes(MemoryStatsService.asInt(javaHeap['maxBytes']))}',
                    ),
                    _Kv('使用率', MemoryStatsService.formatPercent(heapUsage)),
                    _Kv(
                      '接近 OOM（≥85%）',
                      javaHeap['nearOom'] == true ? '是' : '否',
                    ),
                    _Kv(
                      '会话峰值堆占用',
                      MemoryStatsService.formatKb(
                        MemoryStatsService.asInt(app['peakJavaHeapAllocKb']),
                      ),
                    ),
                  ],
                ),
              ),
              HyperosListTile(
                icon: Icons.pie_chart_outline_rounded,
                iconAccent: HyperosIconColors.indigo,
                title: 'PSS 分类与可清性',
                details: totalPssText,
                onTap: () =>
                    _showBreakdownSheet(context, breakdown, orderedKeys),
              ),
              HyperosListTile(
                icon: Icons.tune_rounded,
                iconAccent: HyperosIconColors.cyan,
                title: '当前进程 Debug.MemoryInfo',
                details: MemoryStatsService.formatKb(
                  MemoryStatsService.asInt(debugMemory['totalPssKb']),
                ),
                onTap: () => _showKvSheet(
                  context,
                  title: '当前进程 Debug.MemoryInfo',
                  description: 'Android 当前进程的 PSS 分类，不包含同 UID 的其它进程。',
                  rows: [
                    _Kv(
                      'Java / Dalvik',
                      MemoryStatsService.formatKb(
                        MemoryStatsService.asInt(debugMemory['dalvikPssKb']),
                      ),
                    ),
                    _Kv(
                      'Native',
                      MemoryStatsService.formatKb(
                        MemoryStatsService.asInt(debugMemory['nativePssKb']),
                      ),
                    ),
                    _Kv(
                      'Graphics',
                      MemoryStatsService.formatKb(
                        MemoryStatsService.asInt(debugMemory['graphicsPssKb']),
                      ),
                    ),
                    _Kv(
                      'Code',
                      MemoryStatsService.formatKb(
                        MemoryStatsService.asInt(debugMemory['codePssKb']),
                      ),
                    ),
                    _Kv(
                      'Stack',
                      MemoryStatsService.formatKb(
                        MemoryStatsService.asInt(debugMemory['stackPssKb']),
                      ),
                    ),
                    _Kv(
                      'Other / System',
                      '${MemoryStatsService.formatKb(MemoryStatsService.asInt(debugMemory['otherPssKb']))} / ${MemoryStatsService.formatKb(MemoryStatsService.asInt(debugMemory['systemPssKb']))}',
                    ),
                  ],
                ),
              ),
              HyperosListTile(
                icon: Icons.code_rounded,
                iconAccent: HyperosIconColors.purple,
                title: 'Dart / Flutter 图片缓存',
                details: MemoryStatsService.formatBytes(
                  MemoryStatsService.asInt(imageCache['currentSizeBytes']),
                ),
                onTap: () => _showKvSheet(
                  context,
                  title: 'Dart / Flutter 图片缓存',
                  rows: [
                    _Kv(
                      'Dart RSS',
                      MemoryStatsService.formatBytes(
                        MemoryStatsService.asInt(dartVm['currentRssBytes']),
                      ),
                    ),
                    _Kv(
                      'Dart max RSS',
                      MemoryStatsService.formatBytes(
                        MemoryStatsService.asInt(dartVm['maxRssBytes']),
                      ),
                    ),
                    _Kv(
                      '图片缓存占用',
                      MemoryStatsService.formatBytes(
                        MemoryStatsService.asInt(
                          imageCache['currentSizeBytes'],
                        ),
                      ),
                    ),
                    _Kv(
                      '图片缓存上限',
                      MemoryStatsService.formatBytes(
                        MemoryStatsService.asInt(
                          imageCache['maximumSizeBytes'],
                        ),
                      ),
                    ),
                    _Kv(
                      '图片条目 live / pending',
                      '${imageCache['liveImageCount'] ?? 0} / ${imageCache['pendingImageCount'] ?? 0}',
                    ),
                  ],
                ),
              ),
              HyperosListTile(
                icon: Icons.phone_android_rounded,
                iconAccent: HyperosIconColors.teal,
                title: '系统内存',
                details: system['isLowMemory'] == true ? '低内存' : '正常',
                onTap: () => _showKvSheet(
                  context,
                  title: '系统内存',
                  rows: [
                    _Kv(
                      '设备可用 / 总量',
                      '${MemoryStatsService.formatBytes(MemoryStatsService.asInt(system['availMemBytes']))} / ${MemoryStatsService.formatBytes(MemoryStatsService.asInt(system['totalMemBytes']))}',
                    ),
                    _Kv(
                      '低内存阈值',
                      MemoryStatsService.formatBytes(
                        MemoryStatsService.asInt(system['thresholdBytes']),
                      ),
                    ),
                    _Kv(
                      '系统 isLowMemory',
                      system['isLowMemory'] == true ? '是' : '否',
                    ),
                    _Kv(
                      'memoryClass / large',
                      '${system['memoryClassMb'] ?? '—'} / ${system['largeMemoryClassMb'] ?? '—'} MB',
                    ),
                  ],
                ),
              ),
            ],
          ),
          HyperosSectionDescription(text: 'PSS 详情按需展开，避免常驻技术字段干扰当前状态。'),
          const HyperosSectionGap(),
          const HyperosSectionLabel(text: '运行环境'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.dashboard_outlined,
                iconAccent: HyperosIconColors.blue,
                title: '应用总览',
                details: '${app['processCount'] ?? '—'} 个进程',
                onTap: () =>
                    _showOverviewSheet(context, snapshot: snapshot, app: app),
              ),
              HyperosListTile(
                icon: Icons.swap_vert_rounded,
                iconAccent: HyperosIconColors.orange,
                title: '前台 / 后台采样',
                details: backgroundStats['currentlyBackground'] == true
                    ? '后台'
                    : '前台',
                onTap: () => _showBackgroundSheet(context, backgroundStats),
              ),
              HyperosListTile(
                icon: Icons.bolt_outlined,
                iconAccent: liveIsland['serviceRunning'] == true
                    ? HyperosIconColors.green
                    : HyperosIconColors.indigo,
                title: '超级岛服务',
                details: liveIsland['serviceRunning'] == true ? '运行中' : '未运行',
                onTap: () => _showKvSheet(
                  context,
                  title: '超级岛（LiveUpdateService）',
                  rows: [
                    _Kv(
                      '服务是否在跑',
                      liveIsland['serviceRunning'] == true ? '是' : '否',
                    ),
                    _Kv('服务类名', liveIsland['serviceClass']?.toString() ?? '—'),
                    _Kv(
                      '说明',
                      liveIsland['note']?.toString() ?? '与主进程同 UID，计入总 PSS',
                    ),
                  ],
                ),
              ),
              HyperosListTile(
                icon: Icons.account_tree_outlined,
                iconAccent: HyperosIconColors.cyan,
                title: '整包进程列表',
                details: '${processes.length} 个',
                onTap: () => _showProcessesSheet(context, processes),
              ),
            ],
          ),
          const HyperosSectionGap(),
          const HyperosSectionLabel(text: '诊断工具'),
          HyperosListGroup(
            children: [
              HyperosListTile(
                icon: Icons.analytics_outlined,
                iconAccent: _pressureColor(pressureLevel),
                title: analysis['headline']?.toString() ?? '自动分析',
                details: analysis['severityLabel']?.toString() ?? '暂无结论',
                onTap: () => _showAnalysisSheet(
                  context,
                  analysis,
                  cleanable,
                  analysisBullets,
                ),
              ),
              HyperosListTile(
                icon: Icons.timeline_rounded,
                iconAccent: HyperosIconColors.purple,
                title: '会话采样历史',
                details: '${history.length} 条',
                onTap: () => _showHistorySheet(context, history),
              ),
              HyperosListTile(
                icon: Icons.memory_outlined,
                iconAccent: HyperosIconColors.teal,
                title: '系统 memoryStats 原始字段',
                details: '${memoryStats.length} 项',
                onTap: () => _showMemoryStatsSheet(context, memoryStats),
              ),
              HyperosListTile(
                icon: Icons.data_object_rounded,
                iconAccent: HyperosIconColors.orange,
                title: '复制 / 查看原始 JSON',
                details: snapshot == null ? '暂无快照' : '完整快照',
                onTap: snapshot == null
                    ? null
                    : () => _showJsonSheet(context, snapshot),
                onLongPress: copyJson,
              ),
              HyperosListTile(
                icon: Icons.notifications_none_rounded,
                iconAccent: HyperosIconColors.red,
                title: '公平运行内存事件',
                details: _formatEpochMillis(
                  MemoryStatsService.asInt(fairMemory['lastKillAtMillis']),
                ),
                onTap: () => _showKvSheet(
                  context,
                  title: '公平运行内存事件',
                  rows: [
                    _Kv(
                      '最近 KILL 时间',
                      _formatEpochMillis(
                        MemoryStatsService.asInt(
                          fairMemory['lastKillAtMillis'],
                        ),
                      ),
                    ),
                    _Kv(
                      'notifyType / notifyId',
                      '${fairMemory['lastKillNotifyType'] ?? 0} / ${fairMemory['lastKillNotifyId'] ?? 0}',
                    ),
                    _Kv(
                      'reason',
                      (fairMemory['lastKillReason']?.toString().isNotEmpty ==
                              true)
                          ? fairMemory['lastKillReason'].toString()
                          : '—',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _showOverviewSheet(
    BuildContext context, {
    required Map<String, dynamic>? snapshot,
    required Map<String, dynamic> app,
  }) {
    return _showKvSheet(
      context,
      title: '应用总览',
      description: '公平运行内存页统计的是同 UID 进程总量。',
      rows: [
        _Kv(
          '运行时长',
          MemoryStatsService.formatDuration(
            MemoryStatsService.asInt(snapshot?['uptimeMillis']),
          ),
        ),
        _Kv('包名', snapshot?['packageName']?.toString() ?? '—'),
        _Kv('进程数', '${app['processCount'] ?? '—'}'),
        _Kv('会话采样次数', '${app['sampleCount'] ?? 0}'),
        _Kv(
          '前台 / 后台采样次数',
          '${app['foregroundSampleCount'] ?? 0} / ${app['backgroundSampleCount'] ?? 0}',
        ),
        _Kv('系统 onLowMemory 次数', '${app['lowMemoryEventCount'] ?? 0}'),
        _Kv(
          '当前进程 PSS',
          MemoryStatsService.formatKb(
            MemoryStatsService.asInt(app['selfPssKb']),
          ),
        ),
        _Kv(
          '进程接口合计 PSS',
          MemoryStatsService.formatKb(
            MemoryStatsService.asInt(app['processSumPssKb']),
          ),
        ),
        _Kv(
          'Private Dirty 合计',
          MemoryStatsService.formatKb(
            MemoryStatsService.asInt(app['totalPrivateDirtyKb']),
          ),
        ),
      ],
    );
  }

  Future<void> _showBackgroundSheet(
    BuildContext context,
    Map<String, dynamic> stats,
  ) {
    return _showKvSheet(
      context,
      title: '前台 / 后台采样',
      description: '前台约 15 秒、后台约 30 秒采样；进出前后台会立即补采。',
      rows: [
        _Kv('当前是否后台', stats['currentlyBackground'] == true ? '是' : '否'),
        _Kv(
          '采样间隔 前台 / 后台',
          '${stats['foregroundSampleIntervalSec'] ?? 15}s / ${stats['backgroundSampleIntervalSec'] ?? 30}s',
        ),
        _Kv(
          '是否已有后台采样',
          stats['hasBackgroundSamples'] == true
              ? '是（${stats['backgroundPointCount'] ?? 0} 点）'
              : '否（回桌面待一会儿再回来）',
        ),
        _Kv(
          '最近前台 PSS',
          MemoryStatsService.formatKb(
            MemoryStatsService.asInt(stats['lastForegroundPssKb']),
          ),
        ),
        _Kv(
          '最近后台 PSS',
          MemoryStatsService.formatKb(
            MemoryStatsService.asInt(stats['lastBackgroundPssKb']),
          ),
        ),
        _Kv(
          '后台 − 前台（最近）',
          MemoryStatsService.formatKb(
            MemoryStatsService.asInt(stats['backgroundMinusLastForegroundKb']),
          ),
        ),
        _Kv(
          '前台峰值 / 均值',
          '${MemoryStatsService.formatKb(MemoryStatsService.asInt(stats['peakForegroundPssKb']))} / ${MemoryStatsService.formatKb(MemoryStatsService.asInt(stats['avgForegroundPssKb']))}',
        ),
        _Kv(
          '后台峰值 / 均值',
          '${MemoryStatsService.formatKb(MemoryStatsService.asInt(stats['peakBackgroundPssKb']))} / ${MemoryStatsService.formatKb(MemoryStatsService.asInt(stats['avgBackgroundPssKb']))}',
        ),
        _Kv(
          '上次进前台',
          _formatEpochMillis(
            MemoryStatsService.asInt(stats['lastForegroundAtMillis']),
          ),
        ),
        _Kv(
          '上次进后台',
          _formatEpochMillis(
            MemoryStatsService.asInt(stats['lastBackgroundAtMillis']),
          ),
        ),
        _Kv('说明', stats['note']?.toString() ?? '进程被杀后无法继续后台采样'),
      ],
    );
  }

  Future<void> _showKvSheet(
    BuildContext context, {
    required String title,
    required List<_Kv> rows,
    String? description,
  }) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: title,
        description: description,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.62,
          ),
          child: SingleChildScrollView(child: _KvTable(rows: rows)),
        ),
      ),
    );
  }

  Future<void> _showAnalysisSheet(
    BuildContext context,
    Map<String, dynamic> analysis,
    Map<String, dynamic> cleanable,
    List<String> bullets,
  ) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: analysis['headline']?.toString() ?? '自动分析',
        description:
            '严重度：${analysis['severityLabel'] ?? '—'} · 基于当前 PSS 拆解与包类型',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.62,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '可节约粗估：易清 ${cleanable['easyMb'] ?? 0} MB · 中等 ${cleanable['mediumMb'] ?? 0} MB · 难清 ${cleanable['hardMb'] ?? 0} MB',
                  style: HyperosTypography.listTitle(sheetContext),
                ),
                if (cleanable['note'] != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    cleanable['note'].toString(),
                    style: HyperosTypography.listDetail(sheetContext),
                  ),
                ],
                const SizedBox(height: 12),
                if (bullets.isEmpty)
                  Text(
                    '暂无分析结论，请刷新。',
                    style: HyperosTypography.listDetail(sheetContext),
                  )
                else
                  ...bullets.map(
                    (bullet) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('· '),
                          Expanded(
                            child: Text(
                              bullet,
                              style: HyperosTypography.listDetail(sheetContext),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBreakdownSheet(
    BuildContext context,
    Map<String, dynamic> breakdown,
    List<String> orderedKeys,
  ) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: 'PSS 分类与可清性',
        description: '占比相对总 PSS；可清性是应用层能否主动释放的判断。',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.68,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var index = 0; index < orderedKeys.length; index++) ...[
                  if (index > 0) const HyperosInsetDivider(indent: 0),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: _BreakdownRow(
                      data: MemoryStatsService.asStringKeyMap(
                        breakdown[orderedKeys[index]],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMemoryStatsSheet(
    BuildContext context,
    Map<String, dynamic> memoryStats,
  ) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: '系统 memoryStats 原始字段',
        description:
            'Android Debug.MemoryInfo.getMemoryStats() 全量键值，便于对照 dumpsys。',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.68,
          ),
          child: SingleChildScrollView(
            child: memoryStats.isEmpty
                ? Text(
                    '当前系统未提供 memoryStats（或 API 过低）。',
                    style: HyperosTypography.listDetail(sheetContext),
                  )
                : Text(
                    memoryStats.entries
                        .map((entry) => '${entry.key} = ${entry.value}')
                        .join('\n'),
                    style: HyperosTypography.listDetail(
                      sheetContext,
                    ).copyWith(fontFamily: 'monospace', height: 1.4),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showProcessesSheet(
    BuildContext context,
    List<Map<String, dynamic>> processes,
  ) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: '整包进程列表',
        description: '同 applicationId 下各进程 PSS；超级岛一般在主进程或同 UID 服务内。',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.68,
          ),
          child: SingleChildScrollView(
            child: processes.isEmpty
                ? Text(
                    '暂无进程数据',
                    style: HyperosTypography.listDetail(sheetContext),
                  )
                : Column(
                    children: [
                      for (
                        var index = 0;
                        index < processes.length;
                        index++
                      ) ...[
                        if (index > 0) const HyperosInsetDivider(indent: 0),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: _ProcessRow(process: processes[index]),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showHistorySheet(
    BuildContext context,
    List<Map<String, dynamic>> history,
  ) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: '会话采样历史',
        description: '最多保留 240 点；这里展示最近 20 条，完整数据请复制 JSON。',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.68,
          ),
          child: SingleChildScrollView(
            child: history.isEmpty
                ? Text(
                    '采样尚未积累。可先回桌面 1～2 分钟再回来，查看后台 PSS。',
                    style: HyperosTypography.listDetail(sheetContext),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '共 ${history.length} 点 · 最早→最晚',
                        style: HyperosTypography.listDetail(sheetContext),
                      ),
                      const SizedBox(height: 10),
                      ...history.reversed.take(20).map((sample) {
                        final at = MemoryStatsService.asInt(sample['atMillis']);
                        final pss = MemoryStatsService.formatKb(
                          MemoryStatsService.asInt(sample['totalPssKb']),
                        );
                        final ratio = MemoryStatsService.formatPercent(
                          MemoryStatsService.asDouble(
                            sample['javaHeapUsageRatio'],
                          ),
                        );
                        final live = sample['liveServiceRunning'] == true
                            ? '岛开'
                            : '岛关';
                        final state = sample['appInForeground'] == false
                            ? '后台'
                            : '前台';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${_formatEpochMillis(at)}  [$state]  PSS $pss  堆 $ratio  $live  压力 ${sample['pressureLevel'] ?? '—'}',
                            style: HyperosTypography.listDetail(
                              sheetContext,
                            ).copyWith(fontFamily: 'monospace'),
                          ),
                        );
                      }),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _showJsonSheet(
    BuildContext context,
    Map<String, dynamic>? snapshot,
  ) {
    return showHyperosSheet<void>(
      context: context,
      builder: (sheetContext) => HyperosSheet(
        title: '原始 JSON',
        description: '便于粘贴到 issue / 对照公平内存 TRIM·KILL。长按列表行也可直接复制。',
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Text(
              snapshot == null
                  ? '—'
                  : const JsonEncoder.withIndent('  ').convert(snapshot),
              style: HyperosTypography.listDetail(
                sheetContext,
              ).copyWith(fontFamily: 'monospace', height: 1.35),
            ),
          ),
        ),
      ),
    );
  }

  Color _pressureColor(String level) {
    return switch (level) {
      'critical' => HyperosIconColors.red,
      'high' => HyperosIconColors.orange,
      'elevated' => HyperosIconColors.yellow,
      _ => HyperosIconColors.green,
    };
  }

  String _formatClock(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  String _formatEpochMillis(int? millis) {
    if (millis == null || millis <= 0) {
      return '—';
    }
    final value = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }
}

class _Kv {
  const _Kv(this.label, this.value);

  final String label;
  final String value;
}

class _KvTable extends StatelessWidget {
  const _KvTable({required this.rows});

  final List<_Kv> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const HyperosInsetDivider(indent: 0),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 128,
                  child: Text(
                    rows[index].label,
                    style: HyperosTypography.listDetail(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rows[index].value,
                    style: HyperosTypography.listTitle(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProcessRow extends StatelessWidget {
  const _ProcessRow({required this.process});

  final Map<String, dynamic> process;

  @override
  Widget build(BuildContext context) {
    final name = process['processName']?.toString() ?? '—';
    final pid = process['pid'];
    final pss = MemoryStatsService.formatKb(
      MemoryStatsService.asInt(process['pssKb']),
    );
    final privateDirty = MemoryStatsService.formatKb(
      MemoryStatsService.asInt(process['privateDirtyKb']),
    );
    final isMain = process['isMainProcess'] == true;
    final likelyLive = process['likelyLiveIsland'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: HyperosTypography.listTitle(context)),
        const SizedBox(height: 4),
        Text(
          'pid=$pid  PSS=$pss  privateDirty=$privateDirty'
          '${isMain ? '  ·主进程' : ''}'
          '${likelyLive ? '  ·疑似超级岛相关' : ''}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final label = data['label']?.toString() ?? data['key']?.toString() ?? '—';
    final pssText = MemoryStatsService.formatKb(
      MemoryStatsService.asInt(data['pssKb']),
    );
    final ratioText = MemoryStatsService.formatPercent(
      MemoryStatsService.asDouble(data['ratio']),
    );
    final cleanable = data['cleanable']?.toString() ?? 'hard';
    final meaning = data['meaning']?.toString() ?? '';
    final cleanableLabel = switch (cleanable) {
      'partial' => '部分可清',
      'no' => '基本不可清',
      _ => '难清',
    };
    final cleanableColor = switch (cleanable) {
      'partial' => HyperosIconColors.orange,
      'no' => HyperosColors.secondaryText(context),
      _ => HyperosColors.error(context),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: HyperosTypography.listTitle(context)),
            ),
            Text(
              '$pssText · $ratioText',
              style: HyperosTypography.listTitle(context),
            ),
          ],
        ),
        const SizedBox(height: 4),
        HyperosTag(
          label: cleanableLabel,
          backgroundColor: cleanableColor.withValues(alpha: 0.12),
          textStyle: HyperosTypography.listDetail(
            context,
          ).copyWith(color: cleanableColor),
        ),
        if (meaning.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meaning, style: HyperosTypography.listDetail(context)),
        ],
      ],
    );
  }
}
