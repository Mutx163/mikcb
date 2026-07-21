import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/location_time_group.dart';
import '../providers/timetable/location_building_cluster_logic.dart';
import '../providers/timetable_provider.dart';
import '../utils/app_toast.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/course_field_picker_sheet.dart';

/// Settings screen for location-keyword → time-scheme routing.
class LocationTimeMatchScreen extends StatefulWidget {
  const LocationTimeMatchScreen({super.key});

  @override
  State<LocationTimeMatchScreen> createState() =>
      _LocationTimeMatchScreenState();
}

class _LocationTimeMatchScreenState extends State<LocationTimeMatchScreen> {
  final TextEditingController _previewController = TextEditingController();

  @override
  void dispose() {
    _previewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;

    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final groups = provider.locationTimeGroups;
        final previewMatch = provider.matchLocationTime(
          _previewController.text,
        );
        final previewSchemeName = previewMatch == null
            ? null
            : provider.timeSchemes
                      .where((scheme) => scheme.id == previewMatch.timeSchemeId)
                      .map((scheme) => scheme.name)
                      .firstOrNull ??
                  l10n.locationTimeMatchUnknownScheme;

        return HyperosSubpage(
          onBack: () => Navigator.pop(context),
          title: Text(l10n.locationTimeMatchTitle),
          suffixes: [
            FHeaderAction(
              icon: const Icon(Icons.add_rounded),
              semanticsLabel: l10n.locationTimeMatchCreateGroup,
              onPress: () => _openEditor(context, provider),
            ),
          ],
          child: HyperosBlurredBodyInset(
            child: ListView(
              padding: HyperosTokens.listPadding,
              children: [
                Text(
                  l10n.locationTimeMatchSubtitle,
                  style: theme.typography.body.sm.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.locationTimeMatchWeekAxisNote,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                const SizedBox(height: 16),
                HyperosListGroup(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HyperosTextField(
                            controller: _previewController,
                            label: l10n.locationTimeMatchPreviewLabel,
                            hint: l10n.locationTimeMatchPreviewHint,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () async {
                                final controller = TextEditingController(
                                  text: _previewController.text,
                                );
                                await showCourseFieldPickerSheet(
                                  context,
                                  title: l10n.selectLocationTitle,
                                  suggestions: provider.uniqueLocations,
                                  controller: controller,
                                  onConfirmed: () {
                                    _previewController.text = controller.text;
                                    setState(() {});
                                  },
                                );
                                controller.dispose();
                              },
                              icon: const Icon(Icons.history_rounded, size: 18),
                              label: Text(
                                l10n.locationTimeMatchPickFromLocations,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            previewMatch == null
                                ? l10n.locationTimeMatchPreviewNoMatch
                                : l10n.locationTimeMatchPreviewResult(
                                    previewMatch.groupName,
                                    previewSchemeName ?? '',
                                    previewMatch.matchedKeyword.pattern,
                                  ),
                            style: theme.typography.body.sm.copyWith(
                              color: previewMatch == null
                                  ? theme.colors.mutedForeground
                                  : theme.colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                HyperosButton(
                  label: l10n.locationTimeMatchApplyActive,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _applyToActive(context, provider),
                ),
                const SizedBox(height: 16),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        l10n.locationTimeMatchEmpty,
                        style: theme.typography.body.sm.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                  )
                else
                  ...groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildGroupCard(context, provider, group),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    TimetableProvider provider,
    LocationTimeGroup group,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final schemeName =
        provider.timeSchemes
            .where((scheme) => scheme.id == group.timeSchemeId)
            .map((scheme) => scheme.name)
            .firstOrNull ??
        l10n.locationTimeMatchUnknownScheme;
    final keywordText = group.keywordSummary.isEmpty
        ? l10n.locationTimeMatchNoKeywords
        : group.keywordSummary;

    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(context, provider, existing: group),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: group.enabled,
                    onChanged: (value) async {
                      await provider.updateLocationTimeGroup(
                        group.copyWith(enabled: value),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.locationTimeMatchBoundScheme(schemeName),
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.locationTimeMatchKeywordsLine(keywordText),
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: HyperosButton(
                      label: l10n.editAction,
                      variant: HyperosButtonVariant.secondary,
                      expand: true,
                      onPressed: () =>
                          _openEditor(context, provider, existing: group),
                    ),
                  ),
                  const SizedBox(width: 8),
                  HyperosButton(
                    label: l10n.deleteAction,
                    variant: HyperosButtonVariant.secondary,
                    onPressed: () => _deleteGroup(context, provider, group),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _applyToActive(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final stats = await provider.applyLocationTimeRulesToActiveProfile();
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.locationTimeMatchApplyResult(
        stats.matchedCount,
        stats.updatedCount,
        stats.unlockedCount,
      ),
      kind: AppToastKind.success,
    );
  }

  Future<void> _deleteGroup(
    BuildContext context,
    TimetableProvider provider,
    LocationTimeGroup group,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.locationTimeMatchDeleteTitle,
      message: l10n.locationTimeMatchDeleteMessage(group.name),
      confirmLabel: l10n.deleteAction,
      destructiveConfirm: true,
    );
    if (confirmed != true) {
      return;
    }
    await provider.deleteLocationTimeGroup(group.id);
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: l10n.locationTimeMatchDeleted,
      kind: AppToastKind.success,
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    TimetableProvider provider, {
    LocationTimeGroup? existing,
  }) async {
    await Navigator.push<void>(
      context,
      HyperosPageRoute(
        builder: (_) => _LocationTimeGroupEditorScreen(existing: existing),
      ),
    );
  }
}

class _LocationTimeGroupEditorScreen extends StatefulWidget {
  final LocationTimeGroup? existing;

  const _LocationTimeGroupEditorScreen({this.existing});

  @override
  State<_LocationTimeGroupEditorScreen> createState() =>
      _LocationTimeGroupEditorScreenState();
}

class _KeywordDraft {
  final TextEditingController patternController;
  LocationKeywordMatchMode mode;

  _KeywordDraft({
    required String pattern,
    this.mode = LocationKeywordMatchMode.prefix,
  }) : patternController = TextEditingController(text: pattern);

  void dispose() {
    patternController.dispose();
  }
}

class _LocationTimeGroupEditorScreenState
    extends State<_LocationTimeGroupEditorScreen> {
  late final TextEditingController _nameController;
  late String _timeSchemeId;
  late bool _enabled;
  late final List<_KeywordDraft> _keywords;
  final TextEditingController _locationPickController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _timeSchemeId = existing?.timeSchemeId ?? '';
    _enabled = existing?.enabled ?? true;
    _keywords = (existing?.keywords ?? const <LocationKeyword>[])
        .map(
          (keyword) =>
              _KeywordDraft(pattern: keyword.pattern, mode: keyword.mode),
        )
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationPickController.dispose();
    for (final draft in _keywords) {
      draft.dispose();
    }
    super.dispose();
  }

  List<LocationKeyword> get _currentKeywords {
    return _keywords
        .map(
          (draft) => LocationKeyword(
            pattern: draft.patternController.text.trim(),
            mode: draft.mode,
          ),
        )
        .where((keyword) => keyword.pattern.isNotEmpty)
        .toList();
  }

  bool _hasKeyword(String pattern) {
    final normalized = pattern.trim().toLowerCase();
    return _keywords.any(
      (draft) =>
          draft.patternController.text.trim().toLowerCase() == normalized,
    );
  }

  void _addKeyword(LocationKeyword keyword, {bool showToast = true}) {
    final pattern = keyword.pattern.trim();
    if (pattern.isEmpty) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    if (_hasKeyword(pattern)) {
      if (showToast) {
        showAppToast(
          context,
          message: l10n.locationTimeMatchKeywordAlreadyExists,
          kind: AppToastKind.info,
        );
      }
      return;
    }
    setState(() {
      _keywords.add(_KeywordDraft(pattern: pattern, mode: keyword.mode));
    });
    if (showToast) {
      showAppToast(
        context,
        message: l10n.locationTimeMatchKeywordExtracted(pattern),
        kind: AppToastKind.success,
      );
    }
  }

  void _removeKeywordAt(int index) {
    setState(() {
      _keywords.removeAt(index).dispose();
    });
  }

  Future<void> _pickLocationAsKeyword(
    BuildContext context,
    TimetableProvider provider,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    _locationPickController.clear();
    await showCourseFieldPickerSheet(
      context,
      title: l10n.selectLocationTitle,
      suggestions: provider.uniqueLocations,
      controller: _locationPickController,
      onConfirmed: () {
        final raw = _locationPickController.text.trim();
        if (raw.isEmpty) {
          return;
        }
        final suggested =
            LocationBuildingClusterLogic.suggestKeywordFromLocation(raw) ??
            LocationKeyword(
              pattern: raw,
              mode: LocationKeywordMatchMode.prefix,
            );
        _addKeyword(suggested);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final schemes = provider.timeSchemes;
    if (_timeSchemeId.isEmpty && schemes.isNotEmpty) {
      _timeSchemeId = schemes.first.id;
    }

    final currentKeywords = _currentKeywords;
    final uncovered = LocationBuildingClusterLogic.uncoveredClusters(
      locations: provider.uniqueLocations,
      existingKeywords: currentKeywords,
    );

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      title: Text(
        widget.existing == null
            ? l10n.locationTimeMatchCreateGroup
            : l10n.locationTimeMatchEditGroup,
      ),
      suffixes: [
        FHeaderAction(
          icon: const Icon(Icons.check_rounded),
          semanticsLabel: l10n.saveAction,
          onPress: () => _save(context, provider),
        ),
      ],
      child: HyperosBlurredBodyInset(
        child: ListView(
          padding: HyperosTokens.listPadding,
          children: [
            HyperosTextField(
              controller: _nameController,
              label: l10n.locationTimeMatchGroupNameLabel,
              hint: l10n.locationTimeMatchGroupNameHint,
            ),
            const SizedBox(height: 12),
            Text(l10n.locationTimeMatchBoundSchemeLabel),
            const SizedBox(height: 8),
            if (schemes.isEmpty)
              Text(l10n.locationTimeMatchNeedTimeScheme)
            else
              DropdownButton<String>(
                isExpanded: true,
                value: schemes.any((scheme) => scheme.id == _timeSchemeId)
                    ? _timeSchemeId
                    : schemes.first.id,
                items: [
                  for (final scheme in schemes)
                    DropdownMenuItem(
                      value: scheme.id,
                      child: Text(scheme.name),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _timeSchemeId = value);
                },
              ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.locationTimeMatchEnabledLabel),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.locationTimeMatchKeywordsSection,
              style: context.theme.typography.body.md.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.locationTimeMatchKeywordsHelp,
              style: context.theme.typography.body.xs.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.locationTimeMatchSelectedKeywords),
            const SizedBox(height: 8),
            if (_keywords.isEmpty)
              Text(
                l10n.locationTimeMatchNoSelectedKeywords,
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < _keywords.length; index++)
                    InputChip(
                      label: Text(
                        '${_keywords[index].patternController.text} · ${_modeLabel(l10n, _keywords[index].mode)}',
                      ),
                      onDeleted: () => _removeKeywordAt(index),
                      onPressed: () => _editKeywordDialog(context, l10n, index),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            HyperosButton(
              label: l10n.locationTimeMatchPickFromLocations,
              variant: HyperosButtonVariant.secondary,
              expand: true,
              onPressed: () => _pickLocationAsKeyword(context, provider),
            ),
            const SizedBox(height: 16),
            Text(l10n.locationTimeMatchBuildingSuggestions),
            const SizedBox(height: 8),
            if (uncovered.isEmpty)
              Text(
                l10n.locationTimeMatchNoBuildingSuggestions,
                style: context.theme.typography.body.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              )
            else ...[
              for (final cluster in uncovered)
                _buildBuildingClusterCard(context, l10n, cluster),
              const SizedBox(height: 8),
              HyperosButton(
                label: l10n.locationTimeMatchAddAllBuildings,
                variant: HyperosButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  for (final cluster in uncovered) {
                    _addKeyword(cluster.suggestedKeyword, showToast: false);
                  }
                  if (uncovered.isNotEmpty) {
                    showAppToast(
                      context,
                      message: l10n.locationTimeMatchKeywordExtracted(
                        uncovered
                            .map((cluster) => cluster.buildingKey)
                            .join(', '),
                      ),
                      kind: AppToastKind.success,
                    );
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            HyperosButton(
              label: l10n.locationTimeMatchAddKeyword,
              variant: HyperosButtonVariant.secondary,
              expand: true,
              onPressed: () => _addManualKeywordDialog(context, l10n),
            ),
            const SizedBox(height: 16),
            HyperosButton(
              label: l10n.saveAction,
              expand: true,
              onPressed: () => _save(context, provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuildingClusterCard(
    BuildContext context,
    AppLocalizations l10n,
    BuildingCluster cluster,
  ) {
    final theme = context.theme;
    final samplesPreview = cluster.sampleLocations.take(3).join('、');
    final gateText = cluster.gateTags.isEmpty
        ? null
        : l10n.locationTimeMatchBuildingGateTags(cluster.gateTags.join('、'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HyperosColors.card(context),
        shape: HyperosTheme.cardShape(),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cluster.buildingKey} · ${cluster.displayName}',
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.locationTimeMatchBuildingRoomCount(
                        cluster.locationCount,
                      ),
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    if (samplesPreview.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        samplesPreview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                    if (gateText != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        gateText,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              HyperosButton(
                label: l10n.locationTimeMatchAddBuilding,
                variant: HyperosButtonVariant.secondary,
                onPressed: () => _addKeyword(cluster.suggestedKeyword),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addManualKeywordDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    var mode = LocationKeywordMatchMode.prefix;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.locationTimeMatchAddKeyword),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HyperosTextField(
                    controller: controller,
                    label: l10n.locationTimeMatchKeywordLabel,
                    hint: l10n.locationTimeMatchKeywordHint,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<LocationKeywordMatchMode>(
                    isExpanded: true,
                    value: mode,
                    items: [
                      for (final item in LocationKeywordMatchMode.values)
                        DropdownMenuItem(
                          value: item,
                          child: Text(_modeLabel(l10n, item)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => mode = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancelAction),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.saveAction),
                ),
              ],
            );
          },
        );
      },
    );
    final pattern = controller.text.trim();
    controller.dispose();
    if (confirmed == true && pattern.isNotEmpty && context.mounted) {
      _addKeyword(LocationKeyword(pattern: pattern, mode: mode));
    }
  }

  Future<void> _editKeywordDialog(
    BuildContext context,
    AppLocalizations l10n,
    int index,
  ) async {
    final draft = _keywords[index];
    final controller = TextEditingController(
      text: draft.patternController.text,
    );
    var mode = draft.mode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.locationTimeMatchKeywordLabel),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HyperosTextField(
                    controller: controller,
                    label: l10n.locationTimeMatchKeywordLabel,
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<LocationKeywordMatchMode>(
                    isExpanded: true,
                    value: mode,
                    items: [
                      for (final item in LocationKeywordMatchMode.values)
                        DropdownMenuItem(
                          value: item,
                          child: Text(_modeLabel(l10n, item)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() => mode = value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancelAction),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.saveAction),
                ),
              ],
            );
          },
        );
      },
    );
    final pattern = controller.text.trim();
    controller.dispose();
    if (confirmed == true && pattern.isNotEmpty && mounted) {
      setState(() {
        draft.patternController.text = pattern;
        draft.mode = mode;
      });
    }
  }

  String _modeLabel(AppLocalizations l10n, LocationKeywordMatchMode mode) {
    return switch (mode) {
      LocationKeywordMatchMode.prefix => l10n.locationTimeMatchModePrefix,
      LocationKeywordMatchMode.contains => l10n.locationTimeMatchModeContains,
      LocationKeywordMatchMode.exact => l10n.locationTimeMatchModeExact,
    };
  }

  Future<void> _save(BuildContext context, TimetableProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      showAppToast(
        context,
        message: l10n.locationTimeMatchNameRequired,
        kind: AppToastKind.error,
      );
      return;
    }
    if (_timeSchemeId.isEmpty) {
      showAppToast(
        context,
        message: l10n.locationTimeMatchNeedTimeScheme,
        kind: AppToastKind.error,
      );
      return;
    }

    final keywords = _currentKeywords;
    if (keywords.isEmpty) {
      showAppToast(
        context,
        message: l10n.locationTimeMatchKeywordRequired,
        kind: AppToastKind.error,
      );
      return;
    }

    try {
      final existing = widget.existing;
      if (existing == null) {
        await provider.createLocationTimeGroup(
          name: name,
          timeSchemeId: _timeSchemeId,
          keywords: keywords,
          enabled: _enabled,
        );
      } else {
        await provider.updateLocationTimeGroup(
          existing.copyWith(
            name: name,
            timeSchemeId: _timeSchemeId,
            keywords: keywords,
            enabled: _enabled,
          ),
        );
      }
      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);
      showAppToast(
        context,
        message: l10n.locationTimeMatchSaved,
        kind: AppToastKind.success,
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) {
        return;
      }
      showAppToast(
        context,
        message: error.message?.toString() ?? l10n.locationTimeMatchSaveFailed,
        kind: AppToastKind.error,
      );
    }
  }
}
