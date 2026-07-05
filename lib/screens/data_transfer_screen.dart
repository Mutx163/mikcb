import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/data_transfer_service.dart';
import '../widgets/settings_section_widgets.dart';

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

    return FScaffold(
      header: FHeader.nested(
        prefixes: [FHeaderAction.back(onPress: () => Navigator.pop(context))],
        title: Text(l10n.dataTransferTitle),
      ),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SettingsSectionCard(
              title: l10n.fullExportTitle,
              subtitle: l10n.fullExportSubtitle,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FButton(
                    variant: FButtonVariant.primary,
                    onPress: _isExporting ? null : _exportCurrentProfile,
                    prefix: _isExporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    child: Text(
                      _isExporting
                          ? '${l10n.fullExportTitle}...'
                          : l10n.exportCurrentTimetable,
                    ),
                  ),
                  FButton(
                    variant: FButtonVariant.secondary,
                    onPress: _isExporting ? null : _exportFullData,
                    prefix: const Icon(Icons.storage_rounded),
                    child: Text(l10n.exportAllData),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
              title: l10n.fullImportTitle,
              subtitle: l10n.fullImportSubtitle,
              child: FButton(
                variant: FButtonVariant.secondary,
                onPress: _isImporting ? null : _confirmAndImport,
                prefix: _isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_rounded),
                child: Text(
                  _isImporting
                      ? '${l10n.fullImportTitle}...'
                      : l10n.chooseFileAndImport,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SettingsSectionCard(
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
    final importMode = await showFDialog<_BackupImportMode>(
      context: context,
      builder: (ctx, style, animation) => FDialog(
        title: Text(l10n.selectImportModeTitle),
        body: Text(l10n.selectImportModeMessage),
        actions: [
          FButton(
            variant: FButtonVariant.ghost,
            onPress: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          FButton(
            variant: FButtonVariant.primary,
            onPress: () => Navigator.pop(ctx, _BackupImportMode.replaceCurrent),
            child: Text(l10n.replaceCurrentTimetable),
          ),
          FButton(
            variant: FButtonVariant.secondary,
            onPress: () => Navigator.pop(ctx, _BackupImportMode.importAsNew),
            child: Text(l10n.importAsNewTimetable),
          ),
        ],
      ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message ??
                (importMode == _BackupImportMode.importAsNew
                    ? l10n.createdNewTimetableAfterImport
                    : l10n.backupRestoredSuccess),
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.importFailedInvalidFile)));
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
