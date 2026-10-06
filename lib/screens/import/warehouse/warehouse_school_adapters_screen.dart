// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 学校适配器列表页
// 按省 / 学校分组浏览仓库里的教务适配器。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../../domain/warehouse_adapter_upgrade.dart';
import '../../../services/warehouse_import_preferences_service.dart';
import '../../../services/warehouse_macro_service.dart';
import '../../../services/warehouse_repository_service.dart';
import '../import_shared.dart';
import 'warehouse_shared.dart';
import 'warehouse_import_policy.dart';
import 'warehouse_adapter_detail_screen.dart';
import 'warehouse_adapter_web_login_screen.dart';

class WarehouseSchoolAdaptersScreen extends StatefulWidget {
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseSchoolAdaptersScreen({
    super.key,
    required this.source,
    required this.school,
    required this.fetchOptions,
    this.repositoryServiceOverride,
  });

  /// 测试用的注入口。生产路径不传。
  ///
  /// 存在的理由是下面那条回归测试要能造出「探测永远不返回」的假服务——这类 bug
  /// （把可选探测挂在渲染关键路径上）靠读代码看不出来，只能造出来看。
  final WarehouseRepositoryService? repositoryServiceOverride;

  @override
  State<WarehouseSchoolAdaptersScreen> createState() =>
      _WarehouseSchoolAdaptersScreenState();
}

class _WarehouseSchoolAdaptersScreenState
    extends State<WarehouseSchoolAdaptersScreen> {
  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  WarehouseRepositoryService get _repository =>
      widget.repositoryServiceOverride ?? _repositoryService;
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final WarehouseMacroService _macroService = WarehouseMacroService();
  late Future<WarehouseAdaptersIndex> _adaptersFuture;
  final Map<String, bool> _macroCache = {};
  String? _macroCacheAdapterSignature;
  bool _macroCacheCheckInFlight = false;
  final Map<String, String?> _customImportUrlCache = {};
  String? _customImportUrlAdapterSignature;
  bool _customImportUrlCheckInFlight = false;

  /// `qingyu_only/` 探测的结果。**刻意不进 `_adaptersFuture`**：那个 Future 挂在
  /// 渲染路径上，探测对绝大多数学校是必然的 404，挂上去等于让整个学校页陪它等。
  List<WarehouseAdapterEntry> _qingyuOnlyAdapters = const [];
  Future<List<WarehouseAdapterEntry>>? _extrasFuture;

  /// 探测是否已有结论（含失败）。
  ///
  /// 导入入口要用它：探测还在飞的时候用户就点了导入，那一刻拿到的适配器还没有专属
  /// 字段，于是「自动应用专属内容」这次就落空了。入口等一下这个已在途的请求就行——
  /// 不新增任何网络往返（它本来就发过了），最多等它自己那个 6 秒超时。
  bool _extrasResolved = false;

  @override
  void initState() {
    super.initState();
    _adaptersFuture = _repository.fetchAdaptersIndex(
      widget.source,
      widget.school,
      options: widget.fetchOptions,
    );
    _startQingyuOnlyExtrasLoad();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(widget.school.name),
      // Standard scroll path so the large title collapses with scroll (see the
      // ICS import screen above); the loading state insets manually.
      child: FutureBuilder<WarehouseAdaptersIndex>(
            future: _adaptersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // Non-scroll centered view: inset below the bar manually.
                return HyperosBlurredBodyInset(
                  child: importLoadingCenter(),
                );
              }
              if (snapshot.hasError) {
                return HyperosListView(
                  children: [
                    HyperosSectionLabel(
                      text: l10n.warehouseAdaptersLoadFailedTitle,
                    ),
                    HyperosControlCard(
                      child: HyperosControlCardInset(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            importListDetail(
                              context,
                              localizeServiceError(l10n, snapshot.error!),
                            ),
                            const SizedBox(height: 12),
                            HyperosButton(
                              label: l10n.reloadAction,
                              variant: HyperosButtonVariant.secondary,
                              onPressed: _reloadAdapters,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final adapters = _mergeQingyuOnlyAdapters(
                snapshot.data?.adapters ?? const <WarehouseAdapterEntry>[],
              );
              // 检查每个适配器是否有宏录制
              _scheduleMacroCacheCheck(adapters);
              _scheduleCustomImportUrlCacheCheck(adapters);
              return HyperosListView(
                children: [
                  HyperosListGroup(
                    children: [
                      for (final adapter in adapters)
                        buildWarehouseAdapterListItem(
                          context: context,
                          adapter: adapter,
                          hasMacro: _macroCache[adapter.adapterId] ?? false,
                          importButtonLabel: _adapterHasImportUrl(adapter)
                              ? l10n.webLoginImport
                              : l10n.fillUrlThenImport,
                          recordButtonLabel: _adapterHasImportUrl(adapter)
                              ? l10n.recordImportAction
                              : l10n.fillUrlThenRecord,
                          onImport: () => _openAdapterImport(adapter),
                          onRecord: () =>
                              _openAdapterImport(adapter, autoRecord: true),
                          onInfo: () async {
                            final imported = await Navigator.of(context).push<bool>(
                              HyperosPageRoute(
                                settings: RouteSettings(
                                  name:
                                      '/courses/import/warehouse/${widget.school.id}/${adapter.adapterId}',
                                ),
                                builder: (_) => WarehouseAdapterDetailScreen(
                                  source: widget.source,
                                  school: widget.school,
                                  adapter: adapter,
                                  fetchOptions: widget.fetchOptions,
                                ),
                              ),
                            );
                            if (imported == true && context.mounted) {
                              Navigator.of(context).pop(true);
                            }
                            if (context.mounted) {
                              await _refreshCustomImportUrlCacheForAdapter(
                                adapter.adapterId,
                              );
                            }
                          },
                          onQuickImport: () => _openQuickImport(adapter),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
    );
  }

  /// 学校适配器列表分两段到。
  ///
  /// 第一段是**关键路径**：`resources/` 下的标准适配器，打开学校页就该看到它。
  /// 第二段是 `qingyu_only/` 下的轻屿专属条目，**刻意不挂在渲染路径上** ——
  /// 它对绝大多数学校是一次必然的 404，而上一版把两段塞进同一个 Future，页面
  /// 只能等探测结束才渲染：探测走「主地址 + 4 个镜像候选」共 5 个来回，加上
  /// `http.Client` 默认没有超时，一个半死的镜像就把整个学校页拖成一直转圈圈。
  ///
  /// 所以这里只负责发起；结果到了再 setState 追加。渲染耗时与加这一段之前
  /// 完全一致。
  void _startQingyuOnlyExtrasLoad() {
    _extrasFuture = _repository.fetchQingyuOnlyAdapters(
      widget.source,
      widget.school,
    );
    _extrasFuture!.then((list) {
      _extrasResolved = true;
      if (!mounted || list.isEmpty) {
        return;
      }
      setState(() => _qingyuOnlyAdapters = list);
    }, onError: (Object _) {
      // 降级本身对用户不可见（一所没有专属条目的学校看起来和以前一样），不必打扰。
      _extrasResolved = true;
    });
  }

  /// 专属条目不再单列，而是把专属字段并进同一份脚本的标准条目。
  ///
  /// 用户看到的是一条：同一所学校的「标准版 / 专属版」在用户眼里是同一件事，让 ta
  /// 做二选一等于先逼 ta 知道学校有没有做增强；挑了没增强的那条还会白丢「按教学楼
  /// 分流作息」。合并规则见 `mergeQingyuOnlyUpgrades`。
  ///
  /// 标准条目永远排在前面、也永远可用：它在任何仓库（含上游仓、他人 fork、镜像的旧
  /// 快照）里都存在，而专属条目只在我们的仓里有——探测失败时这一层原样不动。
  List<WarehouseAdapterEntry> _mergeQingyuOnlyAdapters(
    List<WarehouseAdapterEntry> standard,
  ) {
    return mergeQingyuOnlyUpgrades(
      standard: standard,
      extras: _qingyuOnlyAdapters,
    );
  }

  void _reloadAdapters() {
    setState(() {
      _adaptersFuture = _repository.fetchAdaptersIndex(
        widget.source,
        widget.school,
        options: widget.fetchOptions,
      );
      _startQingyuOnlyExtrasLoad();
    });
  }

  bool _adapterHasImportUrl(WarehouseAdapterEntry adapter) {
    return resolveWarehouseImportUrl(
          customImportUrl: _customImportUrlCache[adapter.adapterId],
          defaultUrl: adapter.importUrl,
        ) !=
        null;
  }

  /// 导入前把「专属增强」落到手上这条适配器上。
  ///
  /// 学校页渲染时专属探测是异步的（刻意不挂在渲染路径上），用户可能在它落地之前就
  /// 点了导入。此处在探测**还在途**时等它一下（复用同一个 Future，不新增网络往返），
  /// 拿到结论后按合并规则重算这条适配器；已经落地或已失败都直接返回，什么都不等。
  ///
  /// 等不到就返回原样：专属内容缺席只是「回到脚本下发的全局作息」，不是失败。
  Future<WarehouseAdapterEntry> _resolveAdapterWithExtras(
    WarehouseAdapterEntry adapter,
  ) async {
    if (_extrasResolved) {
      return adapter;
    }
    final pending = _extrasFuture;
    if (pending == null) {
      return adapter;
    }
    try {
      final extras = await pending;
      if (!mounted || extras.isEmpty) {
        return adapter;
      }
      final merged = mergeQingyuOnlyUpgrades(
        standard: [adapter],
        extras: extras,
      );
      return merged.first;
    } on Object {
      // 探测失败等价于「这所学校没有专属增强」，与拿到空列表同义。
      return adapter;
    }
  }

  Future<void> _openAdapterImport(
    WarehouseAdapterEntry adapter, {
    bool autoRecord = false,
  }) async {
    adapter = await _resolveAdapterWithExtras(adapter);
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (initialUrl == null || !mounted) {
      return;
    }
    // Explicit "record import" always records. Ordinary import auto-records
    // only when this school+adapter has no saved macro yet (first import).
    final hasExistingMacro = await _macroService.hasMacro(
      widget.school.id,
      adapter.adapterId,
    );
    if (!mounted) {
      return;
    }
    final shouldRecord = shouldAutoRecordWarehouseImport(
      forceRecord: autoRecord,
      hasExistingMacro: hasExistingMacro,
    );
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(name: '/courses/import/warehouse/login'),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: adapter.adapterName,
          initialUrl: initialUrl,
          source: widget.source,
          school: widget.school,
          adapter: adapter,
          fetchOptions: widget.fetchOptions,
          autoRecord: shouldRecord,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
    // 从导入/录制页面返回后刷新单适配器的宏缓存与自定义网址
    if (mounted) {
      await _refreshMacroCacheForAdapter(adapter.adapterId);
      await _refreshCustomImportUrlCacheForAdapter(adapter.adapterId);
    }
  }

  void _scheduleCustomImportUrlCacheCheck(
    List<WarehouseAdapterEntry> adapters,
  ) {
    final signature = _macroCacheSignatureForAdapters(adapters);
    final hasAllValues = adapters.every(
      (adapter) => _customImportUrlCache.containsKey(adapter.adapterId),
    );
    if (_customImportUrlCheckInFlight ||
        (_customImportUrlAdapterSignature == signature && hasAllValues)) {
      return;
    }
    _customImportUrlCheckInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _checkCustomImportUrlsForAdapters(adapters, signature);
    });
  }

  Future<void> _checkCustomImportUrlsForAdapters(
    List<WarehouseAdapterEntry> adapters,
    String signature,
  ) async {
    final nextCache = <String, String?>{};
    try {
      for (final adapter in adapters) {
        final custom = await _preferencesService.getCustomImportUrl(
          adapter.adapterId,
        );
        if (!mounted) return;
        nextCache[adapter.adapterId] = custom;
      }
    } catch (_) {
      if (mounted) {
        _customImportUrlCheckInFlight = false;
      }
      return;
    }
    if (!mounted) return;

    final changed =
        _customImportUrlAdapterSignature != signature ||
        _customImportUrlCache.length != nextCache.length ||
        nextCache.entries.any(
          (entry) => _customImportUrlCache[entry.key] != entry.value,
        );
    if (!changed) {
      _customImportUrlAdapterSignature = signature;
      _customImportUrlCheckInFlight = false;
      return;
    }

    setState(() {
      _customImportUrlCache
        ..clear()
        ..addAll(nextCache);
      _customImportUrlAdapterSignature = signature;
      _customImportUrlCheckInFlight = false;
    });
  }

  Future<void> _refreshCustomImportUrlCacheForAdapter(String adapterId) async {
    final custom = await _preferencesService.getCustomImportUrl(adapterId);
    if (!mounted) return;
    if (_customImportUrlCache[adapterId] != custom) {
      setState(() {
        _customImportUrlCache[adapterId] = custom;
      });
    }
  }

  Future<String?> _resolveAdapterImportUrl(
    WarehouseAdapterEntry adapter,
  ) async {
    final custom = await _preferencesService.getCustomImportUrl(
      adapter.adapterId,
    );
    final effectiveUrl = resolveWarehouseImportUrl(
      customImportUrl: custom,
      defaultUrl: adapter.importUrl,
    );
    if (effectiveUrl != null) {
      return effectiveUrl;
    }
    if (!mounted) {
      return null;
    }
    final manualUrl = await promptImportWarehouseUrl(
      context,
      schoolName: widget.school.name,
      adapterName: adapter.adapterName,
    );
    if (manualUrl == null) {
      return null;
    }
    await _preferencesService.setCustomImportUrl(adapter.adapterId, manualUrl);
    if (mounted) {
      showImportLightTip(context, AppLocalizations.of(context)!.savedImportUrlHint);
    }
    return manualUrl;
  }

  // ============ 宏录制快捷导入 ============

  void _scheduleMacroCacheCheck(List<WarehouseAdapterEntry> adapters) {
    final signature = _macroCacheSignatureForAdapters(adapters);
    final hasAllValues = adapters.every(
      (adapter) => _macroCache.containsKey(adapter.adapterId),
    );
    if (_macroCacheCheckInFlight ||
        (_macroCacheAdapterSignature == signature && hasAllValues)) {
      return;
    }
    _macroCacheCheckInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _checkMacrosForAdapters(adapters, signature);
    });
  }

  String _macroCacheSignatureForAdapters(List<WarehouseAdapterEntry> adapters) {
    return '${widget.school.id}|${adapters.map((a) => a.adapterId).join('|')}';
  }

  Future<void> _checkMacrosForAdapters(
    List<WarehouseAdapterEntry> adapters,
    String signature,
  ) async {
    final nextCache = <String, bool>{};
    try {
      for (final adapter in adapters) {
        final has = await _macroService.hasMacro(
          widget.school.id,
          adapter.adapterId,
        );
        if (!mounted) return;
        nextCache[adapter.adapterId] = has;
      }
    } catch (_) {
      if (mounted) {
        _macroCacheCheckInFlight = false;
      }
      return;
    }
    if (!mounted) return;

    final changed =
        _macroCacheAdapterSignature != signature ||
        _macroCache.length != nextCache.length ||
        nextCache.entries.any((entry) => _macroCache[entry.key] != entry.value);
    if (!changed) {
      _macroCacheAdapterSignature = signature;
      _macroCacheCheckInFlight = false;
      return;
    }

    setState(() {
      _macroCache
        ..clear()
        ..addAll(nextCache);
      _macroCacheAdapterSignature = signature;
      _macroCacheCheckInFlight = false;
    });
  }

  Future<void> _refreshMacroCacheForAdapter(String adapterId) async {
    final has = await _macroService.hasMacro(widget.school.id, adapterId);
    if (!mounted) return;
    if (_macroCache[adapterId] != has) {
      setState(() {
        _macroCache[adapterId] = has;
      });
    }
  }

  Future<void> _openQuickImport(WarehouseAdapterEntry adapter) async {
    final l10n = AppLocalizations.of(context)!;
    final initialUrl = await _resolveAdapterImportUrl(adapter);
    if (!mounted || initialUrl == null) return;

    final macro = await _macroService.getMacro(
      widget.school.id,
      adapter.adapterId,
    );
    if (!mounted) return;
    if (macro == null) {
      showImportLightTip(context, l10n.noMacroRecordFound);
      return;
    }

    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/quick-import',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: l10n.quickImportTitle(adapter.adapterName),
          initialUrl: initialUrl,
          source: widget.source,
          school: widget.school,
          adapter: adapter,
          fetchOptions: widget.fetchOptions,
          macroRecord: macro,
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
    if (mounted) {
      await _refreshMacroCacheForAdapter(adapter.adapterId);
    }
  }
}


