import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/data_transfer_service.dart';
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
          HyperosControlCard(
            title: l10n.fullExportTitle,
            subtitle: l10n.fullExportSubtitle,
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
          HyperosControlCard(
            title: l10n.fullImportTitle,
            subtitle: l10n.fullImportSubtitle,
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
          HyperosControlCard(
            title: l10n.transferOverviewTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBullet(
                  context,
                  l10n.courseCountBullet(provider.courses.length),
                ),
                _buildBullet(
                  context,
                  l10n.currentTimetableBullet(activeProfileName),
                ),
                _buildBullet(
                  context,
                  l10n.allTimetablesBullet(provider.profiles.length),
                ),
                _buildBullet(
                  context,
                  l10n.timeSchemeCountBullet(provider.timeSchemes.length),
                ),
                _buildBullet(
                  context,
                  l10n.currentWeekBullet(provider.currentWeek),
                ),
                _buildBullet(
                  context,
                  provider.settings.semesterStartDate == null
                      ? l10n.semesterStartUnsetBullet
                      : l10n.semesterStartBullet(
                          _formatDate(provider.settings.semesterStartDate!),
                        ),
                ),
                _buildBullet(
                  context,
                  l10n.fileExtensionBullet(DataTransferService.fileExtension),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(BuildContext context, String text) {
    final typo = context.theme.typography.body;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.circle,
              size: 6,
              color: context.theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: typo.sm)),
        ],
      ),
    );
  }

  Future<void> _exportCurrentProfile() async {
    final provider = context.read<TimetableProvider>();
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
    setState(() {
      _isExporting = true;
    });
    try {
      await provider.dataTransferService.exportFullBackupAndShare(
        profiles: provider.profiles,
        activeProfileId: provider.activeProfileId,
        timeSchemes: provider.timeSchemes,
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
      final result = await FilePicker.platform.pickFiles(
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
        message:
            message ??
            (importMode == _BackupImportMode.importAsNew
                ? l10n.createdNewTimetableAfterImport
                : l10n.backupRestoredSuccess),
        kind: AppToastKind.success,
      );
    } on FormatException catch (e) {
      if (!mounted) {
        return;
      }
      showAppToast(context, message: e.message, kind: AppToastKind.error);
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

enum _BackupImportMode { replaceCurrent, importAsNew }
