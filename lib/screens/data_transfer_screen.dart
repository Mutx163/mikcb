import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/data_transfer_service.dart';
import '../services/transfer_package.dart';
import '../services/transfer_undo_service.dart';
import '../services/unified_transfer_service.dart';
import 'ics_export_screen.dart';
import '../services/qr_transfer/qr_transfer_codec.dart';
import '../services/qr_transfer/qr_transfer_session.dart';
import 'qr_transfer_send_screen.dart';
import 'qr_transfer_scan_screen.dart';
import 'transfer_preview_dialog.dart';
import '../utils/app_toast.dart';
import '../ui/hyperos/hyperos.dart';

class DataTransferScreen extends StatefulWidget {
  const DataTransferScreen({super.key});

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _qrImportInFlight = false;
  final UnifiedTransferService _transferService = UnifiedTransferService();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final activeProfileName =
        provider.activeProfile?.name ?? l10n.timetableAppName;

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(l10n.dataTransferTitle),
      child: HyperosListView(
        children: [
          HyperosSectionLabel(text: l10n.fullExportTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  HyperosButton(
                    label: _isExporting
                        ? '${l10n.fullExportTitle}...'
                        : l10n.exportCurrentTimetable,
                    loading: _isExporting,
                    onPressed: _isExporting ? null : _exportCurrentProfile,
                  ),
                  HyperosButton(
                    label: l10n.exportAllData,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: _isExporting ? null : _exportFullData,
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.icsExportSectionTitle),
          HyperosListGroup(
            children: [
              HyperosNavTile(
                title: l10n.icsExportSectionTitle,
                subtitle: l10n.icsExportSectionSubtitle,
                onTap: _openIcsExport,
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.fullImportTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: HyperosButton(
                label: _isImporting
                    ? '${l10n.fullImportTitle}...'
                    : l10n.chooseFileAndImport,
                variant: HyperosButtonVariant.secondary,
                loading: _isImporting,
                onPressed: _isImporting ? null : _confirmAndImport,
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.qrTransferSectionTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.qrTransferSectionSubtitle,
                    style: HyperosTypography.listDetail(context),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.qrTransferPlaintextWarning,
                    style: HyperosTypography.listDetail(
                      context,
                    ).copyWith(color: HyperosColors.error(context)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      HyperosButton(
                        label: l10n.qrTransferSendCurrent,
                        onPressed: _isExporting ? null : _qrSendCurrent,
                      ),
                      HyperosButton(
                        label: l10n.qrTransferSendAll,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _isExporting ? null : _qrSendAll,
                      ),
                      HyperosButton(
                        label: l10n.qrTransferScanReceive,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: _isImporting ? null : _qrReceive,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.transferOverviewTitle),
          HyperosControlCard(
            child: HyperosControlCardInset(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewRow(
                    context,
                    l10n.courseCountBullet(provider.courses.length),
                  ),
                  _buildOverviewRow(
                    context,
                    l10n.currentTimetableBullet(activeProfileName),
                  ),
                  _buildOverviewRow(
                    context,
                    l10n.allTimetablesBullet(provider.profiles.length),
                  ),
                  _buildOverviewRow(
                    context,
                    l10n.timeSchemeCountBullet(provider.timeSchemes.length),
                  ),
                  _buildOverviewRow(
                    context,
                    l10n.currentWeekBullet(provider.currentWeek),
                  ),
                  _buildOverviewRow(
                    context,
                    provider.settings.semesterStartDate == null
                        ? l10n.semesterStartUnsetBullet
                        : l10n.semesterStartBullet(
                            _formatDate(provider.settings.semesterStartDate!),
                          ),
                  ),
                  _buildOverviewRow(
                    context,
                    l10n.fileExtensionBullet(DataTransferService.fileExtension),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, String) _splitOverviewLabelValue(String text) {
    final fullWidthColon = text.indexOf('：');
    if (fullWidthColon != -1) {
      return (
        text.substring(0, fullWidthColon),
        text.substring(fullWidthColon + 1).trim(),
      );
    }

    final halfWidthColon = text.indexOf(': ');
    if (halfWidthColon != -1) {
      return (
        text.substring(0, halfWidthColon),
        text.substring(halfWidthColon + 2).trim(),
      );
    }

    return ('', text);
  }

  Widget _buildOverviewRow(
    BuildContext context,
    String text, {
    bool isLast = false,
  }) {
    final (label, value) = _splitOverviewLabelValue(text);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: HyperosTypography.listDetail(context)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: HyperosTypography.listDetail(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 发送/导出链路兜底报错：打包与编码在 UI 线程同步执行，任何异常
  /// 若不接住都会变成「点了没反应」（异步异常只进日志，无 UI 提示）。
  void _showTransferSendError(AppLocalizations l10n, Object error) {
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.sendFailedWithError(localizeServiceError(l10n, error)),
      kind: AppToastKind.error,
    );
  }

  Future<void> _exportCurrentProfile() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isExporting = true;
    });
    try {
      final package = _transferService.buildCurrentPackage(
        provider: provider,
      );
      await _shareTransferPackage(
        package,
        shareText: l10n.dataTransferProfileShareText,
        shareSubject: provider.activeProfile?.name == null
            ? l10n.dataTransferProfileShareSubject
            : l10n.dataTransferProfileShareSubjectNamed(
                provider.activeProfile!.name,
              ),
      );
    } catch (error) {
      _showTransferSendError(l10n, error);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _shareTransferPackage(
    TransferPackage package, {
    required String shareText,
    required String shareSubject,
  }) async {
    final now = DateTime.now();
    final prefix = package.isFullBackup ? 'mikcb-full-backup' : 'mikcb-backup';
    final filename =
        '$prefix-${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}.${DataTransferService.fileExtension}';
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            package.encodeBytes(),
            mimeType: 'application/json',
            name: filename,
          ),
        ],
        text: shareText,
        subject: shareSubject,
      ),
    );
  }

  void _openIcsExport() {
    HyperosNavigation.pushWidget<void>(context, const IcsExportScreen());
  }

  Future<void> _exportFullData() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isExporting = true;
    });
    try {
      final package = _transferService.buildFullPackage(
        provider: provider,
      );
      await _shareTransferPackage(
        package,
        shareText: l10n.dataTransferFullBackupShareText,
        shareSubject: l10n.dataTransferFullBackupShareSubject,
      );
    } catch (error) {
      _showTransferSendError(l10n, error);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _confirmAndImport() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isImporting = true;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        withData: true,
        allowedExtensions: const ['json', 'mikcb'],
      );
      final file = result?.files.single;
      if (file == null) {
        return;
      }

      final bytes = file.bytes;
      final content = bytes == null ? '' : utf8.decode(bytes);
      if (!mounted) {
        return;
      }
      if (content.isEmpty) {
        throw FormatException(l10n.importFileReadFailed);
      }
      await _previewAndApply(content, TransferChannel.file);
    } on FormatException catch (e) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: localizeServiceMessage(l10n, e.message),
        kind: AppToastKind.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.importFailedInvalidFile,
        kind: AppToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _qrSendCurrent() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final scope = await _chooseQrScope();
    if (scope == null || !mounted) {
      return;
    }
    Set<String> selectedCourseIds = const {};
    if (scope == TransferScope.selectedCourses ||
        scope == TransferScope.selectedCourse) {
      final selected = await _chooseCoursesForQr(provider);
      if (selected == null || selected.isEmpty || !mounted) {
        return;
      }
      selectedCourseIds = selected;
    }
    try {
      final package = _transferService.buildCurrentPackage(
        provider: provider,
        channel: TransferChannel.qr,
        scope: scope,
        selectedCourseIds: selectedCourseIds,
      );
      final content = package.encode();
      await _openQrSender(
        Uint8List.fromList(utf8.encode(content)),
        l10n.qrTransferSendCurrent,
      );
    } catch (error) {
      _showTransferSendError(l10n, error);
    }
  }

  Future<void> _qrSendAll() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    try {
      final content = _transferService
          .buildFullPackage(provider: provider, channel: TransferChannel.qr)
          .encode();
      await _openQrSender(
        Uint8List.fromList(utf8.encode(content)),
        l10n.qrTransferSendAll,
      );
    } catch (error) {
      _showTransferSendError(l10n, error);
    }
  }

  Future<void> _openQrSender(Uint8List payloadBytes, String title) async {
    try {
      QrTransferEncoder.preflight(payloadBytes);
    } on QrTransferLimitException {
      if (mounted) {
        showAppToast(
          context,
          message: AppLocalizations.of(context)!.qrTransferResourceLimit,
          kind: AppToastKind.error,
        );
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await HyperosNavigation.pushWidget<void>(
      context,
      QrTransferSendScreen(payloadBytes: payloadBytes, title: title),
    );
  }

  void _qrReceive() {
    if (_isImporting || _qrImportInFlight) {
      return;
    }
    HyperosNavigation.pushWidget<void>(
      context,
      QrTransferScanScreen(onComplete: _handleQrReceivedBytes),
    );
  }

  Future<void> _handleQrReceivedBytes(Uint8List bytes) async {
    if (!mounted || _qrImportInFlight) {
      return;
    }
    _qrImportInFlight = true;
    setState(() {
      _isImporting = true;
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      late final String content;
      try {
        final decoded = StringBuffer();
        final sink = utf8.decoder.startChunkedConversion(
          StringConversionSink.withCallback(decoded.write),
        );
        sink.add(bytes);
        sink.close();
        content = decoded.toString();
      } on FormatException {
        throw const FormatException('qr_transfer_invalid_utf8');
      }
      await _previewAndApply(content, TransferChannel.qr);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: error.message == 'qr_transfer_invalid_utf8'
            ? l10n.importFailedInvalidFile
            : localizeServiceMessage(l10n, error.message),
        kind: AppToastKind.error,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: l10n.importFailedInvalidFile,
        kind: AppToastKind.error,
      );
    } finally {
      _qrImportInFlight = false;
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  Future<void> _previewAndApply(String content, TransferChannel channel) async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();
    final incoming = _transferService.parseCompatible(
      content,
      channel: channel,
    );
    final current = _transferService.buildCurrentPackage(
      provider: provider,
      channel: channel,
    );
    final mergePreview = _transferService.preview(
      current: current,
      incoming: incoming,
    );
    final overwritePreview = _transferService.preview(
      current: current,
      incoming: incoming,
      mode: TransferApplyMode.overwrite,
    );
    final choice = await showTransferPreviewDialog(
      context: context,
      preview: overwritePreview,
      alternatePreview: mergePreview,
      incoming: incoming,
    );
    if (choice == null || !mounted) {
      return;
    }
    final mode = choice;
    final result = await _transferService.applyToProvider(
      provider: provider,
      incoming: incoming,
      mode: mode,
      current: current,
    );
    if (!mounted) {
      return;
    }
    if (!result.applied) {
      showAppToast(
        context,
        message: result.error == null
            ? l10n.importFailedInvalidFile
            : localizeServiceMessage(l10n, result.error!),
        kind: AppToastKind.error,
      );
      return;
    }
    final token = result.undoToken;
    if (token == null) {
      showAppToast(
        context,
        message: l10n.backupRestoredSuccess,
        kind: AppToastKind.success,
      );
      return;
    }
    showAppToastWithAction(
      context,
      message: l10n.backupRestoredSuccess,
      actionLabel: l10n.themeUndo,
      kind: AppToastKind.success,
      onAction: () => unawaited(_undoTransfer(token)),
    );
  }

  Future<void> _undoTransfer(TransferUndoToken token) async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final success = await _transferService.undoToken(provider, token.id);
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: success
          ? l10n.dataTransferUndoSuccess
          : l10n.dataTransferUndoFailed,
      kind: success ? AppToastKind.success : AppToastKind.error,
    );
  }

  Future<TransferScope?> _chooseQrScope() {
    final l10n = AppLocalizations.of(context)!;
    return showHyperosDialog<TransferScope>(
      context: context,
      title: l10n.qrTransferSendCurrent,
      // 说明文字用主文本墨色：默认 message 样式是次级灰，液态玻璃弹窗
      // 通透材质上几乎不可见（用户反馈）。
      body: Text(
        l10n.qrTransferSectionSubtitle,
        textAlign: TextAlign.center,
        style: HyperosTypography.listDetail(context).copyWith(
          color: HyperosColors.primaryText(context),
        ),
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.qrTransferShareWeek,
          onPressed: () => Navigator.pop(context, TransferScope.weekTimetable),
        ),
        HyperosDialogAction(
          label: l10n.qrTransferShareSelectedCourses,
          onPressed: () =>
              Navigator.pop(context, TransferScope.selectedCourses),
        ),
        HyperosDialogAction(
          label: l10n.qrTransferShareTimeTemplate,
          onPressed: () => Navigator.pop(context, TransferScope.timeTemplate),
        ),
        HyperosDialogAction(
          label: l10n.qrTransferSendCurrent,
          isPrimary: true,
          onPressed: () =>
              Navigator.pop(context, TransferScope.currentTimetable),
        ),
      ],
    );
  }

  /// 多选课程弹窗。内容必须包在 [HyperosSheetFrame] 里：showHyperosSheet
  /// 只提供压暗层与浮层定位，面板背景（磨砂/液态玻璃）由 Frame 绘制，
  /// 裸列表会渲染成全透明浮层（无 Material、无背景）。课程按
  /// courseGroups（科目）聚合勾选，避免同一科目多次出现逐条列出。
  Future<Set<String>?> _chooseCoursesForQr(TimetableProvider provider) {
    final selected = <String>{};
    final l10n = AppLocalizations.of(context)!;
    final courseGroups = provider.courseGroups;
    return showHyperosSheet<Set<String>>(
      context: context,
      // 列表可滚动时禁用下拉关闭，避免拖拽关闭手势与列表滚动竞争。
      enableDrag: false,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxListHeight = MediaQuery.sizeOf(context).height * 0.52;
            return HyperosSheetFrame(
              chrome: HyperosSheetChrome.floating,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.qrTransferShareSelectedCourses,
                    textAlign: TextAlign.center,
                    style: HyperosTypography.sheetTitle(context),
                  ),
                  const SizedBox(height: 12),
                  if (courseGroups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(
                        l10n.noCoursesInCurrentProfile,
                        textAlign: TextAlign.center,
                        style: HyperosTypography.sectionDescription(context),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: maxListHeight),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final group in courseGroups)
                              HyperosChoiceTile(
                                variant: HyperosChoiceVariant.dialog,
                                title: group.name,
                                subtitle: group.teacher.isNotEmpty
                                    ? Text(
                                        group.teacher,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                selected: group.courses.any(
                                  (course) => selected.contains(course.id),
                                ),
                                highlightSelectedText: true,
                                onTap: () {
                                  setModalState(() {
                                    final groupIds = group.courses
                                        .map((course) => course.id)
                                        .toSet();
                                    final allSelected = groupIds.every(
                                      selected.contains,
                                    );
                                    if (allSelected) {
                                      selected.removeAll(groupIds);
                                    } else {
                                      selected.addAll(groupIds);
                                    }
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  HyperosButton(
                    label: l10n.qrTransferSelectCoursesDone,
                    expand: true,
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      Set<String>.from(selected),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
