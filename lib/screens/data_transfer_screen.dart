import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/l10n/service_message_localizer.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/data_transfer_service.dart';
import 'qr_transfer_send_screen.dart';
import 'qr_transfer_scan_screen.dart';
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
      await provider.dataTransferService.exportAndShare(
        profileName: provider.activeProfile?.name,
        courses: provider.courses,
        exams: provider.exams,
        settings: provider.settings,
        currentWeek: provider.currentWeek,
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

  Future<void> _exportFullData() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isExporting = true;
    });
    try {
      await provider.dataTransferService.exportFullBackupAndShare(
        profiles: provider.profiles,
        activeProfileId: provider.activeProfileId,
        timeSchemes: provider.timeSchemes,
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
    final importMode = await showHyperosDialog<_BackupImportMode>(
      context: context,
      title: l10n.selectImportModeTitle,
      message: l10n.selectImportModeMessage,
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.replaceCurrentTimetable,
          isPrimary: true,
          onPressed: () =>
              Navigator.pop(context, _BackupImportMode.replaceCurrent),
        ),
        HyperosDialogAction(
          label: l10n.importAsNewTimetable,
          onPressed: () =>
              Navigator.pop(context, _BackupImportMode.importAsNew),
        ),
      ],
    );

    if (importMode == null || !mounted) {
      return;
    }

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
      if (!mounted) {
        return;
      }

      final provider = context.read<TimetableProvider>();
      final message = switch (importMode) {
        _BackupImportMode.replaceCurrent => await provider.importAppDataBackup(
          content,
        ),
        _BackupImportMode.importAsNew =>
          await provider.importAppDataBackupAsNewProfile(content),
      };
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: message != null
            ? localizeServiceMessage(l10n, message)
            : (importMode == _BackupImportMode.importAsNew
                  ? l10n.createdNewTimetableAfterImport
                  : l10n.backupRestoredSuccess),
        kind: message != null ? AppToastKind.error : AppToastKind.success,
      );
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
    final content = provider.dataTransferService.buildBackupJson(
      profileName: provider.activeProfile?.name,
      courses: provider.courses,
      exams: provider.exams,
      settings: provider.settings,
      currentWeek: provider.currentWeek,
    );
    if (!mounted) {
      return;
    }
    await HyperosNavigation.pushWidget<void>(
      context,
      QrTransferSendScreen(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        title: l10n.qrTransferSendCurrent,
      ),
    );
  }

  Future<void> _qrSendAll() async {
    final provider = context.read<TimetableProvider>();
    final l10n = AppLocalizations.of(context)!;
    final content = provider.dataTransferService.buildFullBackupJson(
      profiles: provider.profiles,
      activeProfileId: provider.activeProfileId,
      timeSchemes: provider.timeSchemes,
    );
    if (!mounted) {
      return;
    }
    await HyperosNavigation.pushWidget<void>(
      context,
      QrTransferSendScreen(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        title: l10n.qrTransferSendAll,
      ),
    );
  }

  void _qrReceive() {
    HyperosNavigation.pushWidget<void>(
      context,
      QrTransferScanScreen(onComplete: _handleQrReceivedBytes),
    );
  }

  Future<void> _handleQrReceivedBytes(Uint8List bytes) async {
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    final content = utf8.decode(bytes);
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<TimetableProvider>();

    if (provider.dataTransferService.isFullBackupJson(content)) {
      final message = await provider.importFullAppDataBackup(content);
      if (!mounted) {
        return;
      }
      showAppToast(
        context,
        message: message != null
            ? localizeServiceMessage(l10n, message)
            : l10n.backupRestoredSuccess,
        kind: message != null ? AppToastKind.error : AppToastKind.success,
      );
      return;
    }

    final importMode = await showHyperosDialog<_BackupImportMode>(
      context: context,
      title: l10n.selectImportModeTitle,
      message: l10n.selectImportModeMessage,
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.replaceCurrentTimetable,
          isPrimary: true,
          onPressed: () =>
              Navigator.pop(context, _BackupImportMode.replaceCurrent),
        ),
        HyperosDialogAction(
          label: l10n.importAsNewTimetable,
          onPressed: () =>
              Navigator.pop(context, _BackupImportMode.importAsNew),
        ),
      ],
    );
    if (importMode == null || !mounted) {
      return;
    }

    final message = switch (importMode) {
      _BackupImportMode.replaceCurrent => await provider.importAppDataBackup(
        content,
      ),
      _BackupImportMode.importAsNew =>
        await provider.importAppDataBackupAsNewProfile(content),
    };
    if (!mounted) {
      return;
    }
    showAppToast(
      context,
      message: message != null
          ? localizeServiceMessage(l10n, message)
          : (importMode == _BackupImportMode.importAsNew
                ? l10n.createdNewTimetableAfterImport
                : l10n.backupRestoredSuccess),
      kind: message != null ? AppToastKind.error : AppToastKind.success,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

enum _BackupImportMode { replaceCurrent, importAsNew }
