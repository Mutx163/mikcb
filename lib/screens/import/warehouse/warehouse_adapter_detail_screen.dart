// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 适配器详情页
// 单个适配器的说明、宏录制、升级等操作。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import '../../../l10n/service_message_localizer.dart';
import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../../services/warehouse_import_preferences_service.dart';
import '../../../services/warehouse_macro_service.dart';
import '../../../services/warehouse_repository_service.dart';
import '../import_shared.dart';
import 'warehouse_shared.dart';
import 'warehouse_import_policy.dart';
import 'warehouse_adapter_web_login_screen.dart';

class WarehouseAdapterDetailScreen extends StatefulWidget {
  final WarehouseRepositorySource source;
  final WarehouseSchoolEntry school;
  final WarehouseAdapterEntry adapter;
  final WarehouseFetchOptions fetchOptions;

  const WarehouseAdapterDetailScreen({
    super.key,
    required this.source,
    required this.school,
    required this.adapter,
    required this.fetchOptions,
  });

  @override
  State<WarehouseAdapterDetailScreen> createState() =>
      _WarehouseAdapterDetailScreenState();
}

class _WarehouseAdapterDetailScreenState
    extends State<WarehouseAdapterDetailScreen> {
  final WarehouseRepositoryService _repositoryService =
      WarehouseRepositoryService();
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  final WarehouseMacroService _macroService = WarehouseMacroService();
  late Future<String> _scriptFuture;
  String? _customImportUrl;

  @override
  void initState() {
    super.initState();
    _scriptFuture = _repositoryService.fetchAdapterScript(
      widget.source,
      school: widget.school,
      adapter: widget.adapter,
      options: widget.fetchOptions,
    );
    _loadCustomImportUrl();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final adapter = widget.adapter;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(adapter.adapterName),
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: HyperosListView(
            children: [
              WarehouseIntroCard(
                title: adapter.adapterName,
                subtitle: adapter.description.isEmpty
                    ? l10n.adapterIntroSubtitle
                    : '',
                chips: [
                  '${l10n.schoolLabel}：${widget.school.name}',
                  '${l10n.categoryLabel}：${adapter.category}',
                  '${l10n.maintainerLabel}：${adapter.maintainer}',
                ],
                markdown: adapter.description.isEmpty
                    ? null
                    : adapter.description,
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.adapterInfoTitle),
              HyperosControlCard(
                child: HyperosControlCardInset(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImportDetailLine(
                        label: 'adapter_id',
                        value: adapter.adapterId,
                      ),
                      ImportDetailLine(
                        label: l10n.scriptPathLabel,
                        value: adapter.assetJsPath,
                      ),
                      ImportDetailLine(
                        label: l10n.loginEntryLabel,
                        value: _effectiveImportUrl.isEmpty
                            ? l10n.unsetConfigLabel
                            : _effectiveImportUrl,
                      ),
                      if ((_customImportUrl ?? '').isNotEmpty)
                        ImportDetailLine(
                          label: l10n.homeWidgetDescriptionTitle,
                          value: l10n.adapterOverrideImportUrlHint,
                        ),
                      ImportDetailLine(
                        label: l10n.repositoryLabel,
                        value: widget.source.repositoryUrl,
                      ),
                    ],
                  ),
                ),
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.scriptStatusTitle),
              FutureBuilder<String>(
                future: _scriptFuture,
                builder: (context, snapshot) {
                  final readable =
                      snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError &&
                      (snapshot.data?.trim().isNotEmpty ?? false);
                  return HyperosControlCard(
                    child: HyperosControlCardInset(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (snapshot.connectionState ==
                              ConnectionState.waiting)
                            const HyperosLinearProgress(minHeight: 3)
                          else if (readable)
                            importListDetail(
                              context,
                              l10n.scriptLoadedLength(snapshot.data!.length),
                            )
                          else
                            Text(
                              snapshot.hasError
                                  ? localizeServiceError(l10n, snapshot.error!)
                                  : l10n.scriptEmpty,
                              style: HyperosTypography.listDetail(
                                context,
                              ).copyWith(color: colorScheme.error),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              HyperosButton(
                label: _effectiveImportUrl.isEmpty
                    ? l10n.fillUrlThenImport
                    : l10n.openLoginInAppAction,
                expand: true,
                onPressed: _openInAppLogin,
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.moreActionsTooltip),
              HyperosListGroup(
                children: [
                  HyperosNavTile(
                    title: l10n.openInSystemBrowserAction,
                    enabled: _effectiveImportUrl.isNotEmpty,
                    onTap: _effectiveImportUrl.isEmpty
                        ? null
                        : () => _openImportUrl(_effectiveImportUrl),
                  ),
                  HyperosNavTile(
                    title: l10n.copyLoginAddressAction,
                    enabled: _effectiveImportUrl.isNotEmpty,
                    onTap: _effectiveImportUrl.isEmpty
                        ? null
                        : () => _copyText(
                            _effectiveImportUrl,
                            successMessage: l10n.copiedImportLoginUrl,
                          ),
                  ),
                  HyperosNavTile(
                    title: l10n.copyScriptAddressAction,
                    onTap: () => _copyText(
                      widget.source
                          .buildRawFileUri(
                            'resources/${widget.school.resourceFolder}/${adapter.assetJsPath}',
                          )
                          .toString(),
                      successMessage: l10n.copiedScriptRawUrl,
                    ),
                  ),
                  HyperosNavTile(
                    title: (_customImportUrl ?? '').isEmpty
                        ? l10n.customLoginAddressAction
                        : l10n.editCustomLoginAddressAction,
                    onTap: _editCustomImportUrl,
                  ),
                  if ((_customImportUrl ?? '').isNotEmpty)
                    HyperosNavTile(
                      title: adapter.importUrl.isEmpty
                          ? l10n.clearCustomLoginAddressAction
                          : l10n.restoreRepositoryAddressAction,
                      onTap: _clearCustomImportUrl,
                    ),
                ],
              ),
            ],
          ),
    );
  }

  String get _effectiveImportUrl => (_customImportUrl ?? '').trim().isNotEmpty
      ? _customImportUrl!.trim()
      : widget.adapter.importUrl;

  Future<void> _loadCustomImportUrl() async {
    final custom = await _preferencesService.getCustomImportUrl(
      widget.adapter.adapterId,
    );
    if (!mounted) return;
    setState(() {
      _customImportUrl = custom;
    });
  }

  Future<void> _openImportUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      showImportLightTip(
        context,
        AppLocalizations.of(context)!.invalidLoginEntryUrl,
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openInAppLogin() async {
    var targetUrl = _effectiveImportUrl.trim();
    if (targetUrl.isEmpty) {
      final manualUrl = await promptImportWarehouseUrl(
        context,
        schoolName: widget.school.name,
        adapterName: widget.adapter.adapterName,
      );
      if (manualUrl == null) {
        return;
      }
      await _preferencesService.setCustomImportUrl(
        widget.adapter.adapterId,
        manualUrl,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _customImportUrl = manualUrl;
      });
      showImportLightTip(context, AppLocalizations.of(context)!.savedImportUrlHint);
      targetUrl = manualUrl;
    }
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }
      showImportLightTip(
        context,
        AppLocalizations.of(context)!.invalidLoginEntryUrl,
      );
      return;
    }
    final hasExistingMacro = await _macroService.hasMacro(
      widget.school.id,
      widget.adapter.adapterId,
    );
    if (!mounted) {
      return;
    }
    final shouldRecord = shouldAutoRecordWarehouseImport(
      forceRecord: false,
      hasExistingMacro: hasExistingMacro,
    );
    await Navigator.of(context)
        .push(
          HyperosPageRoute(
            settings: const RouteSettings(
              name: '/courses/import/warehouse/login',
            ),
            builder: (_) => WarehouseAdapterWebLoginScreen(
              title: widget.adapter.adapterName,
              initialUrl: targetUrl,
              source: widget.source,
              school: widget.school,
              adapter: widget.adapter,
              fetchOptions: widget.fetchOptions,
              autoRecord: shouldRecord,
            ),
          ),
        )
        .then((imported) {
          if (imported == true && mounted) {
            Navigator.of(context).pop(true);
          }
        });
  }

  Future<void> _editCustomImportUrl() async {
    final result = await promptImportWarehouseUrl(
      context,
      schoolName: widget.school.name,
      adapterName: widget.adapter.adapterName,
      initialValue: _effectiveImportUrl,
    );
    if (result == null) return;
    await _preferencesService.setCustomImportUrl(
      widget.adapter.adapterId,
      result,
    );
    if (!mounted) return;
    setState(() {
      _customImportUrl = result;
    });
    showImportLightTip(
      context,
      AppLocalizations.of(context)!.savedCustomLoginAddress,
    );
  }

  Future<void> _clearCustomImportUrl() async {
    await _preferencesService.clearCustomImportUrl(widget.adapter.adapterId);
    if (!mounted) return;
    setState(() {
      _customImportUrl = null;
    });
    showImportLightTip(
      context,
      widget.adapter.importUrl.isEmpty
          ? AppLocalizations.of(context)!.clearedCustomLoginAddress
          : AppLocalizations.of(context)!.restoredRepositoryImportUrl,
    );
  }

  Future<void> _copyText(String value, {required String successMessage}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) {
      return;
    }
    showImportLightTip(context, successMessage);
  }
}

