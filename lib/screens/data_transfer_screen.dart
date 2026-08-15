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
                    ).copyWith(color: Colors.orangeAccent),
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

  Future<void> _exportCurrentProfile() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isExporting = true;
    });
    try {
      final package = _transferService.buildCurrentPackage(
        provider: provider,
        channel: TransferChannel.file,
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
        channel: TransferChannel.file,
      );
      await _shareTransferPackage(
        package,
        shareText: l10n.dataTransferFullBackupShareText,
        shareSubject: l10n.dataTransferFullBackupShareSubject,
      );
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
  }

  Future<void> _qrSendAll() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final content = _transferService
        .buildFullPackage(provider: provider, channel: TransferChannel.qr)
        .encode();
    await _openQrSender(
      Uint8List.fromList(utf8.encode(content)),
      l10n.qrTransferSendAll,
    );
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
      mode: TransferApplyMode.merge,
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
    final success = await _transferService.undoToken(provider, token.id);
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: success ? 'Transfer undone' : 'Undo failed',
      kind: success ? AppToastKind.success : AppToastKind.error,
    );
  }

  Future<TransferScope?> _chooseQrScope() {
    final l10n = AppLocalizations.of(context)!;
    return showHyperosDialog<TransferScope>(
      context: context,
      title: l10n.qrTransferSendCurrent,
      message: l10n.qrTransferSectionSubtitle,
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: 'Share this week',
          onPressed: () => Navigator.pop(context, TransferScope.weekTimetable),
        ),
        HyperosDialogAction(
          label: 'Share selected courses',
          onPressed: () =>
              Navigator.pop(context, TransferScope.selectedCourses),
        ),
        HyperosDialogAction(
          label: 'Share time template',
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

  Future<Set<String>?> _chooseCoursesForQr(TimetableProvider provider) {
    final selected = <String>{};
    return showHyperosSheet<Set<String>>(
      context: context,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.75,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        children: [
                          for (final course in provider.courses)
                            CheckboxListTile(
                              value: selected.contains(course.id),
                              title: Text(course.name),
                              subtitle: Text(course.location),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == true) {
                                    selected.add(course.id);
                                  } else {
                                    selected.remove(course.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: HyperosButton(
                        label: 'Done',
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          Set<String>.from(selected),
                        ),
                      ),
                    ),
                  ],
                ),
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
