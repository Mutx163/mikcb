import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../utils/app_toast.dart';
import '../services/app_migration_service.dart';

enum MigrationFlowAction { restoreBackup, skip }

class PackageMigrationGuideScreen extends StatefulWidget {
  final String legacyPackageName;

  const PackageMigrationGuideScreen({
    super.key,
    required this.legacyPackageName,
  });

  @override
  State<PackageMigrationGuideScreen> createState() =>
      _PackageMigrationGuideScreenState();
}

class _PackageMigrationGuideScreenState
    extends State<PackageMigrationGuideScreen> {
  final AppMigrationService _migrationService = AppMigrationService();
  bool _isOpeningOldApp = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return HyperosSubpage(
      prefixes: const [],
      title: Text(l10n.migrationTitle),
      childPad: false,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.migrationSafeTitle,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.migrationSafeSubtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _MigrationStep(
                        index: 1,
                        title: l10n.migrationStep1Title,
                        subtitle: l10n.migrationStep1Subtitle,
                      ),
                      const SizedBox(height: 10),
                      _MigrationStep(
                        index: 2,
                        title: l10n.migrationStep2Title,
                        subtitle: l10n.migrationStep2Subtitle,
                      ),
                      const SizedBox(height: 10),
                      _MigrationStep(
                        index: 3,
                        title: l10n.migrationStep3Title,
                        subtitle: l10n.migrationStep3Subtitle,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tips_and_updates_rounded,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.migrationNoSaveToFilesTitle,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.migrationNoSaveToFilesSubtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: HyperosButton(
                        label: _isOpeningOldApp
                            ? l10n.openingOldApp
                            : l10n.openOldAppForBackup,
                        expand: true,
                        loading: _isOpeningOldApp,
                        onPressed: _isOpeningOldApp ? null : _openLegacyApp,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: HyperosButton(
                        label: l10n.backupDoneGoImport,
                        variant: HyperosButtonVariant.secondary,
                        expand: true,
                        onPressed: () => Navigator.pop(
                          context,
                          MigrationFlowAction.restoreBackup,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.center,
                      child: HyperosButton(
                        label: l10n.startFreshWithoutMigration,
                        variant: HyperosButtonVariant.secondary,
                        onPressed: () =>
                            Navigator.pop(context, MigrationFlowAction.skip),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLegacyApp() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isOpeningOldApp = true;
    });
    final opened = await _migrationService.openPackage(
      widget.legacyPackageName,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _isOpeningOldApp = false;
    });
    if (!opened) {
      showAppToast(
        context,
        message: l10n.openOldAppFailed,
        kind: AppToastKind.error,
      );
    }
  }
}

class _MigrationStep extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;

  const _MigrationStep({
    required this.index,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
