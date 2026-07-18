import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../../models/statistics_export_options.dart';
import '../../utils/app_toast.dart';

/// Opens the statistics export options sheet.
///
/// Returns selected [StatisticsExportOptions], or `null` if dismissed.
/// Export is always a long PNG image (no PDF / format picker).
Future<StatisticsExportOptions?> showStatisticsExportSheet({
  required BuildContext context,
  bool hasStories = true,
  bool hasAchievements = true,
}) {
  return showHyperosSheet<StatisticsExportOptions>(
    context: context,
    builder: (sheetContext) {
      return _StatisticsExportSheet(
        hasStories: hasStories,
        hasAchievements: hasAchievements,
      );
    },
  );
}

class _StatisticsExportSheet extends StatefulWidget {
  const _StatisticsExportSheet({
    required this.hasStories,
    required this.hasAchievements,
  });

  final bool hasStories;
  final bool hasAchievements;

  @override
  State<_StatisticsExportSheet> createState() => _StatisticsExportSheetState();
}

class _StatisticsExportSheetState extends State<_StatisticsExportSheet> {
  late final Set<StatisticsExportModule> _selectedModules =
      Set<StatisticsExportModule>.from(StatisticsExportOptions.defaultModules);

  @override
  void initState() {
    super.initState();
    if (!widget.hasAchievements) {
      _selectedModules.remove(StatisticsExportModule.achievements);
    }
    if (!widget.hasStories) {
      _selectedModules.remove(StatisticsExportModule.stories);
    }
  }

  void _toggleModule(StatisticsExportModule module, bool enabled) {
    setState(() {
      if (enabled) {
        _selectedModules.add(module);
      } else {
        _selectedModules.remove(module);
      }
    });
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedModules.isEmpty) {
      showAppToast(
        context,
        message: l10n.statisticsExportSelectModuleHint,
        kind: AppToastKind.warning,
      );
      return;
    }
    Navigator.pop(
      context,
      StatisticsExportOptions(
        modules: Set<StatisticsExportModule>.unmodifiable(_selectedModules),
      ),
    );
  }

  String _moduleTitle(AppLocalizations l10n, StatisticsExportModule module) {
    return switch (module) {
      StatisticsExportModule.overview => l10n.statisticsExportModuleOverview,
      StatisticsExportModule.achievements => l10n.statisticsAchievementsTitle,
      StatisticsExportModule.stories => l10n.statisticsStoriesTitle,
      StatisticsExportModule.dailyDistribution =>
        l10n.statisticsDailyDistribution,
      StatisticsExportModule.natureRatio => l10n.statisticsNatureRatio,
      StatisticsExportModule.ranking => l10n.statisticsRankingTitle,
    };
  }

  List<StatisticsExportModule> get _availableModules {
    return [
      StatisticsExportModule.overview,
      if (widget.hasAchievements) StatisticsExportModule.achievements,
      if (widget.hasStories) StatisticsExportModule.stories,
      StatisticsExportModule.dailyDistribution,
      StatisticsExportModule.natureRatio,
      StatisticsExportModule.ranking,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final modules = _availableModules;

    return HyperosSheet(
      title: l10n.statisticsExportTitle,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.statisticsExportModulesSection,
              style: HyperosTypography.sectionLabel(context),
            ),
            const SizedBox(height: 8),
            HyperosControlCard(
              edgeToEdge: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < modules.length; index++) ...[
                    if (index > 0)
                      HyperosInsetDivider(
                        indent: HyperosTokens.listTileDividerIndent,
                      ),
                    HyperosCheckboxTile(
                      title: _moduleTitle(l10n, modules[index]),
                      value: _selectedModules.contains(modules[index]),
                      onChanged: (enabled) =>
                          _toggleModule(modules[index], enabled),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            HyperosButton(
              label: l10n.statisticsExportAction,
              expand: true,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
