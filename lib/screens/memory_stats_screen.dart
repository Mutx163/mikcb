import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/memory_stats_service.dart';
import '../ui/hyperos/hyperos.dart';

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
    final heapUsage = MemoryStatsService.asDouble(javaHeap['usageRatio']);
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

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: const Text('内存统计'),
      child: HyperosListView(
        itemCount: 1,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosControlCard(
                title: '公平运行内存 · 全应用监控',
                subtitle: '统计主进程 + 同包其它进程（含超级岛服务）。仅调试版/性能版可见。',
                child: HyperosControlCardInset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MemoryChip(
                            label: '压力 $pressureLabel',
                            color: _pressureColor(context, pressureLevel),
                          ),
                          _MemoryChip(
                            label: '状态 $appStateLabel',
                            color: appInForeground
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.tertiary,
                          ),
                          _MemoryChip(
                            label: '总 PSS $totalPssText',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          _MemoryChip(
                            label: '峰值 $peakPssText',
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_errorText != null) ...[
                        Text(
                          _errorText!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          HyperosButton(
                            label: _loading ? '刷新中…' : '立即刷新',
                            variant: HyperosButtonVariant.secondary,
                            loading: _loading,
                            onPressed: _loading
                                ? null
                                : () => _refresh(showLoading: true),
                          ),
                          HyperosButton(
                            label: '复制 JSON',
                            variant: HyperosButtonVariant.secondary,
                            onPressed: snapshot == null
                                ? null
                                : () async {
                                    final text = const JsonEncoder.withIndent(
                                      '  ',
                                    ).convert(snapshot);
                                    await Clipboard.setData(
                                      ClipboardData(text: text),
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已复制内存快照 JSON'),
                                      ),
                                    );
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      HyperosSwitchTile(
                        value: _autoRefreshEnabled,
                        onChanged: (value) {
                          setState(() {
                            _autoRefreshEnabled = value;
                          });
                        },
                        title: '自动刷新',
                        subtitle: _autoRefreshEnabled
                            ? '每 ${_autoRefreshInterval.inSeconds} 秒采样一次'
                            : '已关闭自动刷新',
                      ),
                      Text(
                        '最近刷新：$refreshedText',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const HyperosSectionGap(),
              _KvCard(
                title: '总览',
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
                    '前台/后台采样次数',
                    '${app['foregroundSampleCount'] ?? 0} / ${app['backgroundSampleCount'] ?? 0}',
                  ),
                  _Kv(
                    '系统 onLowMemory 次数',
                    '${app['lowMemoryEventCount'] ?? 0}',
                  ),
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
              ),
              const HyperosSectionGap(),
              _KvCard(
                title: '后台内存统计',
                rows: [
                  _Kv(
                    '当前是否后台',
                    backgroundStats['currentlyBackground'] == true ? '是' : '否',
                  ),
                  _Kv(
                    '采样间隔 前台/后台',
                    '${backgroundStats['foregroundSampleIntervalSec'] ?? 15}s / '
                        '${backgroundStats['backgroundSampleIntervalSec'] ?? 30}s',
                  ),
                  _Kv(
                    '是否已有后台采样',
                    backgroundStats['hasBackgroundSamples'] == true
                        ? '是（${backgroundStats['backgroundPointCount'] ?? 0} 点）'
                        : '否（回桌面待一会儿再回来）',
                  ),
                  _Kv(
                    '最近前台 PSS',
                    MemoryStatsService.formatKb(
                      MemoryStatsService.asInt(
                        backgroundStats['lastForegroundPssKb'],
                      ),
                    ),
                  ),
                  _Kv(
                    '最近后台 PSS',
                    MemoryStatsService.formatKb(
                      MemoryStatsService.asInt(
                        backgroundStats['lastBackgroundPssKb'],
                      ),
                    ),
                  ),
                  _Kv(
                    '后台 − 前台（最近）',
                    MemoryStatsService.formatKb(
                      MemoryStatsService.asInt(
                        backgroundStats['backgroundMinusLastForegroundKb'],
                      ),
                    ),
                  ),
                  _Kv(
                    '前台峰值 / 均值',
                    '${MemoryStatsService.formatKb(MemoryStatsService.asInt(backgroundStats['peakForegroundPssKb']))} / '
                        '${MemoryStatsService.formatKb(MemoryStatsService.asInt(backgroundStats['avgForegroundPssKb']))}',
                  ),
                  _Kv(
                    '后台峰值 / 均值',
                    '${MemoryStatsService.formatKb(MemoryStatsService.asInt(backgroundStats['peakBackgroundPssKb']))} / '
                        '${MemoryStatsService.formatKb(MemoryStatsService.asInt(backgroundStats['avgBackgroundPssKb']))}',
                  ),
                  _Kv(
                    '上次进前台',
                    _formatEpochMillis(
                      MemoryStatsService.asInt(
                        backgroundStats['lastForegroundAtMillis'],
                      ),
                    ),
                  ),
                  _Kv(
                    '上次进后台',
                    _formatEpochMillis(
                      MemoryStatsService.asInt(
                        backgroundStats['lastBackgroundAtMillis'],
                      ),
                    ),
                  ),
                  _Kv(
                    '说明',
                    backgroundStats['note']?.toString() ?? '进程被杀后无法继续后台采样',
                  ),
                ],
              ),
              const HyperosSectionGap(),
              HyperosControlCard(
                title: analysis['headline']?.toString() ?? '自动分析',
                subtitle:
                    '严重度：${analysis['severityLabel'] ?? '—'} · 基于当前 PSS 拆解与包类型',
                child: HyperosControlCardInset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '可节约粗估：易清 ${cleanable['easyMb'] ?? 0} MB · '
                        '中等 ${cleanable['mediumMb'] ?? 0} MB · '
                        '难清 ${cleanable['hardMb'] ?? 0} MB',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (cleanable['note'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          cleanable['note'].toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (analysisBullets.isEmpty)
                        Text(
                          '暂无分析结论，请刷新。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else
                        ...analysisBullets.map(
                          (bullet) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '· ',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                Expanded(
                                  child: Text(
                                    bullet,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
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
              const HyperosSectionGap(),
              HyperosControlCard(
                title: 'PSS 分类详解（可清性）',
                subtitle: '占比相对总 PSS；易清/中等/难清是应用层能否主动释放的判断。',
                child: HyperosControlCardInset(
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < orderedKeys.length;
                        index++
                      ) ...[
                        if (index > 0) const Divider(height: 18),
                        _BreakdownRow(
                          data: MemoryStatsService.asStringKeyMap(
                            breakdown[orderedKeys[index]],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const HyperosSectionGap(),
              _KvCard(
                title: 'Java 堆（接近 OOM 监控）',
                rows: [
                  _Kv(
                    '已用 / 上限',
                    '${MemoryStatsService.formatBytes(MemoryStatsService.asInt(javaHeap['allocBytes']))} / ${MemoryStatsService.formatBytes(MemoryStatsService.asInt(javaHeap['maxBytes']))}',
                  ),
                  _Kv('使用率', MemoryStatsService.formatPercent(heapUsage)),
                  _Kv('接近 OOM (≥85%)', javaHeap['nearOom'] == true ? '是' : '否'),
                  _Kv(
                    '会话峰值堆占用',
                    MemoryStatsService.formatKb(
                      MemoryStatsService.asInt(app['peakJavaHeapAllocKb']),
                    ),
                  ),
                ],
              ),
              const HyperosSectionGap(),
              _KvCard(
                title: 'PSS 拆解（当前进程 Debug.MemoryInfo）',
                rows: [
                  _Kv(
                    'Java/Dalvik',
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
              const HyperosSectionGap(),
              HyperosControlCard(
                title: '系统 memoryStats 原始字段',
                subtitle:
                    'Android Debug.MemoryInfo.getMemoryStats() 全量键值，便于对照 dumpsys。',
                child: HyperosControlCardInset(
                  child: memoryStats.isEmpty
                      ? Text(
                          '当前系统未提供 memoryStats（或 API 过低）。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final entry in memoryStats.entries)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '${entry.key} = ${entry.value}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontFamily: 'monospace'),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const HyperosSectionGap(),
              _KvCard(
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
                      MemoryStatsService.asInt(imageCache['currentSizeBytes']),
                    ),
                  ),
                  _Kv(
                    '图片缓存上限',
                    MemoryStatsService.formatBytes(
                      MemoryStatsService.asInt(imageCache['maximumSizeBytes']),
                    ),
                  ),
                  _Kv(
                    '图片条目 live / pending',
                    '${imageCache['liveImageCount'] ?? 0} / ${imageCache['pendingImageCount'] ?? 0}',
                  ),
                ],
              ),
              const HyperosSectionGap(),
              _KvCard(
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
              const HyperosSectionGap(),
              _KvCard(
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
              const HyperosSectionGap(),
              _KvCard(
                title: '公平运行内存事件（本地标记）',
                rows: [
                  _Kv(
                    '最近 KILL 时间',
                    _formatEpochMillis(
                      MemoryStatsService.asInt(fairMemory['lastKillAtMillis']),
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
              const HyperosSectionGap(),
              HyperosControlCard(
                title: '进程列表（整包）',
                subtitle: '同 applicationId 下各进程 PSS；超级岛一般在主进程或同 UID 服务内。',
                child: HyperosControlCardInset(
                  child: processes.isEmpty
                      ? Text(
                          '暂无进程数据',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          children: [
                            for (
                              var index = 0;
                              index < processes.length;
                              index++
                            ) ...[
                              if (index > 0) const Divider(height: 16),
                              _ProcessRow(process: processes[index]),
                            ],
                          ],
                        ),
                ),
              ),
              const HyperosSectionGap(),
              HyperosControlCard(
                title: '会话采样历史',
                subtitle:
                    '前台约 15s、后台约 30s 采一次；进出前后台会立即补采。最多 240 点。进程被杀后无法再记后台点。',
                child: HyperosControlCardInset(
                  child: history.isEmpty
                      ? Text(
                          '采样尚未积累。可先回桌面 1～2 分钟再回来，查看后台 PSS。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '共 ${history.length} 点 · 最早→最晚',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            ...history.reversed.take(20).map((sample) {
                              final at = MemoryStatsService.asInt(
                                sample['atMillis'],
                              );
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
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  '${_formatEpochMillis(at)}  [$state]  PSS $pss  堆 $ratio  $live  压力 ${sample['pressureLevel'] ?? '—'}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontFamily: 'monospace'),
                                ),
                              );
                            }),
                            if (history.length > 20)
                              Text(
                                '仅显示最近 20 条；完整数据请复制 JSON。',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                ),
              ),
              const HyperosSectionGap(),
              HyperosControlCard(
                title: '原始 JSON',
                subtitle: '便于粘贴到 issue / 对照公平内存 TRIM·KILL。',
                child: HyperosControlCardInset(
                  child: HyperosAccordion(
                    items: [
                      HyperosAccordionItem(
                        title: const Text('展开完整快照'),
                        child: SelectableText(
                          snapshot == null
                              ? '—'
                              : const JsonEncoder.withIndent(
                                  '  ',
                                ).convert(snapshot),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(height: 1.35, fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Color _pressureColor(BuildContext context, String level) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      'critical' => scheme.error,
      'high' => Colors.orange,
      'elevated' => Colors.amber.shade800,
      _ => Colors.green,
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

class _KvCard extends StatelessWidget {
  const _KvCard({required this.title, required this.rows});

  final String title;
  final List<_Kv> rows;

  @override
  Widget build(BuildContext context) {
    return HyperosControlCard(
      title: title,
      child: HyperosControlCardInset(
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 128,
                    child: Text(
                      rows[index].label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[index].value,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
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
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
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

class _MemoryChip extends StatelessWidget {
  const _MemoryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
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
      'partial' => Colors.orange,
      'no' => Theme.of(context).colorScheme.outline,
      _ => Theme.of(context).colorScheme.error,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              '$pssText · $ratioText',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: cleanableColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            cleanableLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: cleanableColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (meaning.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(meaning, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
