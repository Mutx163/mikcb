// 本文件由 course_import_screen.dart 拆分而来（2026-10-06）。
// 仓库自定义脚本调试记录
// 导入脚本文本与调试记录的查看 / 编辑。
// 拆分只搬移代码、不改逻辑；符号可见性与 import 由拆分统一补齐。

import 'dart:async';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:uuid/uuid.dart';
import '../../../models/warehouse_repository_models.dart';
import '../../../services/unified_transfer_service.dart';
import '../../../services/warehouse_import_preferences_service.dart';
import '../../../services/warehouse_repository_service.dart';
import '../../../utils/app_toast.dart';
import '../../../utils/import_file_reader.dart';
import '../../../widgets/app_dialogs.dart';
import '../import_shared.dart';
import 'warehouse_adapter_web_login_screen.dart';

class WarehouseCustomDebugRecordsScreen extends StatefulWidget {
  const WarehouseCustomDebugRecordsScreen({super.key});

  @override
  State<WarehouseCustomDebugRecordsScreen> createState() =>
      _WarehouseCustomDebugRecordsScreenState();
}

class _WarehouseCustomDebugRecordsScreenState
    extends State<WarehouseCustomDebugRecordsScreen> {
  static const WarehouseRepositorySource _customSource =
      defaultQingyuWarehouseSource;

  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  List<WarehouseCustomDebugRecord> _records = const [];
  bool _isLoading = true;

  WarehouseFetchOptions _currentFetchOptions() {
    return currentWarehouseFetchOptions(context);
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final records = await _preferencesService.getCustomDebugRecords();
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _openEditor([WarehouseCustomDebugRecord? record]) async {
    final saved = await Navigator.of(context).push<WarehouseCustomDebugRecord>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/custom-debug/edit',
        ),
        builder: (_) => WarehouseCustomDebugEditScreen(initialRecord: record),
      ),
    );
    if (saved == null || !mounted) {
      return;
    }
    await _loadRecords();
  }

  Future<void> _deleteRecord(WarehouseCustomDebugRecord record) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.deleteDebugRecordTitle,
      message: l10n.deleteDebugRecordMessage(record.name),
      confirmLabel: l10n.deleteAction,
    );
    if (confirmed != true) {
      return;
    }
    await _preferencesService.deleteCustomDebugRecord(record.id);
    if (!mounted) {
      return;
    }
    await _loadRecords();
    if (!mounted) {
      return;
    }
    showImportLightTip(context, l10n.deletedDebugRecord(record.name));
  }

  Future<void> _openDebug(WarehouseCustomDebugRecord record) async {
    final imported = await Navigator.of(context).push<bool>(
      HyperosPageRoute(
        settings: const RouteSettings(
          name: '/courses/import/warehouse/custom-debug/run',
        ),
        builder: (_) => WarehouseAdapterWebLoginScreen(
          title: record.name,
          initialUrl: record.importUrl,
          source: _customSource,
          school: const WarehouseSchoolEntry(
            id: 'custom-debug',
            name: 'custom-debug',
            initial: '#',
            resourceFolder: 'custom-debug',
          ),
          adapter: WarehouseAdapterEntry(
            adapterId: 'custom-debug-${record.id}',
            adapterName: record.name,
            category: 'custom_debug',
            assetJsPath: 'custom/${record.id}.js',
            importUrl: record.importUrl,
            maintainer: 'custom-debug',
            description: '',
          ),
          fetchOptions: _currentFetchOptions(),
          debugScriptOverride: record.script,
          debugScriptName: '${record.name}.js',
        ),
      ),
    );
    if (imported == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.warehouseCustomDebugTitle),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.add_rounded),
          semanticsLabel: l10n.addDebugRecordTooltip,
          onPress: _openEditor,
        ),
      ],
      child: _isLoading
          // Non-scroll centered view: inset below the bar manually.
          ? HyperosBlurredBodyInset(child: importLoadingCenter())
          : HyperosListView(
                  children: [
                    HyperosControlCard(
                      title: l10n.customDebugIntroTitle,
                      subtitle: l10n.customDebugIntroSubtitle,
                      child: HyperosControlCardInset(
                        child: HyperosButton(
                          label: l10n.addDebugRecordAction,
                          onPressed: _openEditor,
                        ),
                      ),
                    ),
                    const HyperosSectionGap(),
                    if (_records.isEmpty)
                      ImportSectionCard(
                        padding: const EdgeInsets.all(20),
                        child: HyperosEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: l10n.noSavedDebugRecords,
                          subtitle: l10n.noSavedDebugRecordsHint,
                        ),
                      )
                    else
                      ..._records.map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ImportSectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: importListTitle(
                                        context,
                                        record.name,
                                      ),
                                    ),
                                    importListDetail(
                                      context,
                                      _formatDebugRecordDateTime(
                                        record.updatedAt,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  record.importUrl,
                                  style: HyperosTypography.listDetail(context)
                                      .copyWith(
                                        color: HyperosColors.primary(context),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                importListDetail(
                                  context,
                                  l10n.debugScriptLength(record.script.length),
                                ),
                                const SizedBox(height: 14),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    HyperosButton(
                                      label: l10n.startDebugAction,
                                      onPressed: () => _openDebug(record),
                                    ),
                                    HyperosButton(
                                      label: l10n.editAction,
                                      variant: HyperosButtonVariant.secondary,
                                      onPressed: () => _openEditor(record),
                                    ),
                                    HyperosButton(
                                      label: l10n.deleteAction,
                                      variant: HyperosButtonVariant.destructive,
                                      onPressed: () => _deleteRecord(record),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}


class WarehouseCustomDebugEditScreen extends StatefulWidget {
  final WarehouseCustomDebugRecord? initialRecord;

  const WarehouseCustomDebugEditScreen({super.key, this.initialRecord});

  @override
  State<WarehouseCustomDebugEditScreen> createState() =>
      _WarehouseCustomDebugEditScreenState();
}

class _WarehouseCustomDebugEditScreenState
    extends State<WarehouseCustomDebugEditScreen> {
  final WarehouseImportPreferencesService _preferencesService =
      WarehouseImportPreferencesService();
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  late final TextEditingController _scriptController;
  bool _isSaving = false;

  bool get _isEditing => widget.initialRecord != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialRecord?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.initialRecord?.importUrl ?? '',
    );
    _scriptController = TextEditingController(
      text: widget.initialRecord?.script ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _scriptController.dispose();
    super.dispose();
  }

  Future<void> _pickScriptFromFile() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['js', 'txt'],
        // Nothing is pre-loaded here (picker default), so measure before reading;
        // see the .ics picker above for why.
      );
      if (result == null || result.files.isEmpty || !mounted) {
        return;
      }
      final file = result.files.single;
      List<int>? bytes;
      if ((file.path ?? '').isNotEmpty) {
        try {
          bytes = await readImportFileBytes(
            file.path!,
            maxBytes: UnifiedTransferService.maxImportFileBytes,
          );
        } on ImportFileTooLarge {
          if (mounted) {
            showAppToast(
              context,
              message: l10n.importFileTooLarge(
                formatByteBudget(UnifiedTransferService.maxImportFileBytes),
              ),
              kind: AppToastKind.error,
            );
          }
          return;
        }
      }
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          showImportLightTip(context, l10n.scriptFileReadFailed);
        }
        return;
      }
      _scriptController.text = utf8.decode(bytes, allowMalformed: true).trim();
      if (!mounted) {
        return;
      }
      showImportLightTip(context, l10n.scriptFileImported(file.name));
    } catch (error) {
      if (!mounted) {
        return;
      }
      showImportLightTip(context, l10n.scriptFileImportFailed('$error'));
    }
  }

  Future<void> _saveRecord() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final importUrl = _urlController.text.trim();
    final script = _scriptController.text.trim();

    if (name.isEmpty) {
      showImportLightTip(context, l10n.debugRecordNameRequired);
      return;
    }
    final uri = Uri.tryParse(importUrl);
    if (importUrl.isEmpty || uri == null || uri.host.isEmpty) {
      showImportLightTip(context, l10n.invalidImportUrl);
      return;
    }
    if (script.isEmpty) {
      showImportLightTip(context, l10n.debugScriptRequired);
      return;
    }

    final now = DateTime.now();
    final record =
        (widget.initialRecord ??
                WarehouseCustomDebugRecord(
                  id: const Uuid().v4(),
                  name: name,
                  importUrl: importUrl,
                  script: script,
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(
              name: name,
              importUrl: importUrl,
              script: script,
              updatedAt: now,
            );

    setState(() {
      _isSaving = true;
    });
    await _preferencesService.saveCustomDebugRecord(record);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(record);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(
        _isEditing ? l10n.editDebugRecordTitle : l10n.addDebugRecordTitle,
      ),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: _isSaving ? null : _saveRecord,
        ),
      ],
      // Standard list path so the large title collapses with scroll (see the
      // ICS import screen above).
      child: HyperosListView(
            children: [
              HyperosSectionLabel(text: l10n.debugRecordFormula),
              const HyperosSectionGap(),
              HyperosTextField(
                controller: _nameController,
                label: l10n.debugRecordNameLabel,
                hint: l10n.debugRecordNameHint,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              HyperosTextField(
                controller: _urlController,
                label: l10n.importUrlLabel,
                hint: 'https://...',
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: importListTitle(context, l10n.debugScriptLabel),
                  ),
                  HyperosButton(
                    label: l10n.importFromFileAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _pickScriptFromFile,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              HyperosTextField(
                controller: _scriptController,
                hint: l10n.debugScriptHint,
                minLines: 14,
                maxLines: 24,
              ),
              const SizedBox(height: 16),
              HyperosButton(
                label: _isSaving
                    ? l10n.savingAction
                    : l10n.saveDebugRecordAction,
                loading: _isSaving,
                onPressed: _isSaving ? null : _saveRecord,
              ),
            ],
          ),
    );
  }
}


String _formatDebugRecordDateTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${importFormatDate(local)} $hour:$minute';
}


