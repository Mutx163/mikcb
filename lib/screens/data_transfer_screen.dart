import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/timetable_provider.dart';
import '../services/data_transfer_service.dart';

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
    final theme = Theme.of(context);
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fullExportTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.fullExportSubtitle,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              _isExporting ? null : _exportCurrentProfile,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.ios_share_rounded),
                          label: Text(_isExporting
                              ? '${l10n.fullExportTitle}...'
                              : l10n.exportCurrentTimetable),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _isExporting ? null : _exportFullData,
                          icon: const Icon(Icons.storage_rounded),
                          label: Text(l10n.exportAllData),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fullImportTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.fullImportSubtitle),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _isImporting ? null : _confirmAndImport,
                      icon: _isImporting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_isImporting
                          ? '${l10n.fullImportTitle}...'
                          : l10n.chooseFileAndImport),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.transferOverviewTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildBullet(l10n.courseCountBullet(provider.courses.length)),
                  _buildBullet(l10n.currentTimetableBullet(activeProfileName)),
                  _buildBullet(
                      l10n.allTimetablesBullet(provider.profiles.length)),
                  _buildBullet(
                      l10n.timeSchemeCountBullet(provider.timeSchemes.length)),
                  _buildBullet(l10n.currentWeekBullet(provider.currentWeek)),
                  _buildBullet(
                    provider.settings.semesterStartDate == null
                        ? l10n.semesterStartUnsetBullet
                        : l10n.semesterStartBullet(
                            _formatDate(provider.settings.semesterStartDate!),
                          ),
                  ),
                  _buildBullet(l10n
                      .fileExtensionBullet(DataTransferService.fileExtension)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
    final importMode = await showDialog<_BackupImportMode>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.selectImportModeTitle),
          content: Text(AppLocalizations.of(context)!.selectImportModeMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.cancelAction),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _BackupImportMode.replaceCurrent),
              child:
                  Text(AppLocalizations.of(context)!.replaceCurrentTimetable),
            ),
            FilledButton.tonal(
              onPressed: () =>
                  Navigator.pop(context, _BackupImportMode.importAsNew),
              child: Text(AppLocalizations.of(context)!.importAsNewTimetable),
            ),
          ],
        );
      },
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
        throw FormatException(AppLocalizations.of(context)!.importFileReadFailed);
      }
      if (!mounted) {
        return;
      }

      final provider = context.read<TimetableProvider>();
      final message = switch (importMode) {
        _BackupImportMode.replaceCurrent =>
          await provider.importAppDataBackup(content),
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
                    ? AppLocalizations.of(context)!
                        .createdNewTimetableAfterImport
                    : AppLocalizations.of(context)!.backupRestoredSuccess),
          ),
        ),
      );
    } on FormatException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.importFailedInvalidFile)),
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

enum _BackupImportMode {
  replaceCurrent,
  importAsNew,
}

