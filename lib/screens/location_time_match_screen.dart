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
          child: HyperosListView(
            children: [
              HyperosSectionLabel(text: l10n.locationTimeMatchTitle),
              HyperosSectionDescription(text: l10n.locationTimeMatchSubtitle),
              const SizedBox(height: 8),
              HyperosSectionDescription(
                text: l10n.locationTimeMatchWeekAxisNote,
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.locationTimeMatchPreviewLabel),
              HyperosControlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HyperosTextField(
                      controller: _previewController,
                      hint: l10n.locationTimeMatchPreviewHint,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    HyperosButton(
                      label: l10n.locationTimeMatchPickFromLocations,
                      variant: HyperosButtonVariant.secondary,
                      expand: true,
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
                    ),
                    const SizedBox(height: 12),
                    Text(
                      previewMatch == null
                          ? l10n.locationTimeMatchPreviewNoMatch
                          : l10n.locationTimeMatchPreviewResult(
                              previewMatch.groupName,
                              previewSchemeName ?? '',
                              previewMatch.matchedKeyword.pattern,
                            ),
                      style: HyperosTypography.listDetail(context).copyWith(
                        color: previewMatch == null
                            ? HyperosColors.secondaryText(context)
                            : HyperosColors.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const HyperosSectionGap(),
              HyperosListGroup(
                children: [
                  HyperosActionTile(
                    icon: Icons.playlist_add_check_rounded,
                    title: l10n.locationTimeMatchApplyActive,
                    onTap: () => _applyToActive(context, provider),
                  ),
                ],
              ),
              const HyperosSectionGap(),
              HyperosSectionLabel(text: l10n.locationTimeMatchEntryTitle),
              if (groups.isEmpty)
                HyperosSectionDescription(text: l10n.locationTimeMatchEmpty)
              else ...[
                for (var index = 0; index < groups.length; index++) ...[
                  if (index > 0) const HyperosSectionGap(),
                  _buildGroupCard(context, provider, groups[index]),
                ],
              ],
            ],
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
    final schemeName =
        provider.timeSchemes
            .where((scheme) => scheme.id == group.timeSchemeId)
            .map((scheme) => scheme.name)
            .firstOrNull ??
        l10n.locationTimeMatchUnknownScheme;
    final keywordText = group.keywordSummary.isEmpty
        ? l10n.locationTimeMatchNoKeywords
        : group.keywordSummary;

    return HyperosControlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HyperosSwitchTile(
            icon: Icons.place_outlined,
            iconAccent: HyperosIconColors.orange,
            title: group.name,
            subtitle: l10n.locationTimeMatchBoundScheme(schemeName),
            value: group.enabled,
            onChanged: (value) async {
              await provider.updateLocationTimeGroup(
                group.copyWith(enabled: value),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            l10n.locationTimeMatchKeywordsLine(keywordText),
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 12),
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

  /// Adds many building keywords in one rebuild, then scrolls back to the top.
  ///
  /// Without this, users often stand at the bottom of a long building list;
  /// after one-tap add the suggestion cards vanish and content height collapses,
  /// leaving a blank viewport while the real chips sit above the fold.
  void _addAllUncoveredBuildings(
    List<BuildingCluster> uncovered,
    AppLocalizations l10n,
  ) {
    if (uncovered.isEmpty) {
      return;
    }

    final addedPatterns = <String>[];
    setState(() {
      for (final cluster in uncovered) {
        final pattern = cluster.suggestedKeyword.pattern.trim();
        if (pattern.isEmpty || _hasKeyword(pattern)) {
          continue;
        }
        _keywords.add(
          _KeywordDraft(pattern: pattern, mode: cluster.suggestedKeyword.mode),
        );
        addedPatterns.add(pattern);
      }
    });

    if (addedPatterns.isEmpty) {
      showAppToast(
        context,
        message: l10n.locationTimeMatchKeywordAlreadyExists,
        kind: AppToastKind.info,
      );
      return;
    }

    showAppToast(
      context,
      message: l10n.locationTimeMatchKeywordExtracted(addedPatterns.join(', ')),
      kind: AppToastKind.success,
    );
    _scrollEditorToTop();
  }

  void _scrollEditorToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final primaryController = PrimaryScrollController.maybeOf(context);
      if (primaryController == null || !primaryController.hasClients) {
        return;
      }
      primaryController.jumpTo(0);
    });
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
    final schemeItems = <String, String>{
      for (final scheme in schemes) scheme.name: scheme.id,
    };
    final selectedSchemeId = schemes.any((scheme) => scheme.id == _timeSchemeId)
        ? _timeSchemeId
        : (schemes.isEmpty ? null : schemes.first.id);

    return HyperosSubpage(
      onBack: () => Navigator.pop(context),
      resizeToAvoidBottomInset: true,
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
      child: HyperosListView(
        pageStorageKey: const PageStorageKey<String>(
          'location-time-group-editor',
        ),
        children: [
          HyperosSectionLabel(text: l10n.locationTimeMatchGroupNameLabel),
          HyperosControlCard(
            child: HyperosTextField(
              controller: _nameController,
              hint: l10n.locationTimeMatchGroupNameHint,
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.locationTimeMatchBoundSchemeLabel),
          if (schemes.isEmpty)
            HyperosSectionDescription(text: l10n.locationTimeMatchNeedTimeScheme)
          else
            HyperosListGroup(
              children: [
                HyperosSelectTile<String>(
                  label: l10n.locationTimeMatchBoundSchemeLabel,
                  items: schemeItems,
                  value: selectedSchemeId,
                  useSheetForPopup: true,
                  onChanged: (value) {
                    setState(() => _timeSchemeId = value);
                  },
                ),
              ],
            ),
          const HyperosSectionGap(),
          HyperosListGroup(
            children: [
              HyperosSwitchTile(
                icon: Icons.toggle_on_outlined,
                iconAccent: HyperosIconColors.teal,
                title: l10n.locationTimeMatchEnabledLabel,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
            ],
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.locationTimeMatchKeywordsSection),
          HyperosSectionDescription(text: l10n.locationTimeMatchKeywordsHelp),
          const SizedBox(height: 8),
          HyperosControlCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.locationTimeMatchSelectedKeywords,
                  style: HyperosTypography.listTitle(context),
                ),
                const SizedBox(height: 8),
                if (_keywords.isEmpty)
                  Text(
                    l10n.locationTimeMatchNoSelectedKeywords,
                    style: HyperosTypography.listDetail(context),
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
                          onPressed: () =>
                              _editKeywordDialog(context, l10n, index),
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
                const SizedBox(height: 8),
                HyperosButton(
                  label: l10n.locationTimeMatchAddKeyword,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _addManualKeywordDialog(context, l10n),
                ),
              ],
            ),
          ),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.locationTimeMatchBuildingSuggestions),
          if (uncovered.isEmpty)
            HyperosSectionDescription(
              text: l10n.locationTimeMatchNoBuildingSuggestions,
            )
          else ...[
            for (final cluster in uncovered) ...[
              _buildBuildingClusterCard(context, l10n, cluster),
              const HyperosSectionGap(),
            ],
            HyperosListGroup(
              children: [
                HyperosActionTile(
                  icon: Icons.playlist_add_rounded,
                  title: l10n.locationTimeMatchAddAllBuildings,
                  onTap: () => _addAllUncoveredBuildings(uncovered, l10n),
                ),
              ],
            ),
          ],
          const HyperosSectionGap(),
          HyperosButton(
            label: l10n.saveAction,
            expand: true,
            onPressed: () => _save(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingClusterCard(
    BuildContext context,
    AppLocalizations l10n,
    BuildingCluster cluster,
  ) {
    final samplesPreview = cluster.sampleLocations.take(3).join('、');
    final gateText = cluster.gateTags.isEmpty
        ? null
        : l10n.locationTimeMatchBuildingGateTags(cluster.gateTags.join('、'));
    final detailParts = <String>[
      l10n.locationTimeMatchBuildingRoomCount(cluster.locationCount),
      if (samplesPreview.isNotEmpty) samplesPreview,
      if (gateText != null) gateText,
    ];

    return HyperosControlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${cluster.buildingKey} · ${cluster.displayName}',
            style: HyperosTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            detailParts.join(' · '),
            style: HyperosTypography.listDetail(context),
          ),
          const SizedBox(height: 12),
          HyperosButton(
            label: l10n.locationTimeMatchAddBuilding,
            variant: HyperosButtonVariant.secondary,
            expand: true,
            onPressed: () => _addKeyword(cluster.suggestedKeyword),
          ),
        ],
      ),
    );
  }

  Future<void> _addManualKeywordDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    var mode = LocationKeywordMatchMode.prefix;
    final confirmed = await showHyperosDialog<bool>(
      context: context,
      title: l10n.locationTimeMatchAddKeyword,
      body: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosTextField(
                controller: controller,
                label: l10n.locationTimeMatchKeywordLabel,
                hint: l10n.locationTimeMatchKeywordHint,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              HyperosSelectTile<LocationKeywordMatchMode>(
                label: l10n.locationTimeMatchModeLabel,
                items: {
                  for (final item in LocationKeywordMatchMode.values)
                    _modeLabel(l10n, item): item,
                },
                value: mode,
                useSheetForPopup: true,
                onChanged: (value) {
                  setDialogState(() => mode = value);
                },
              ),
            ],
          );
        },
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context, false),
        ),
        HyperosDialogAction(
          label: l10n.saveAction,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
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
    final confirmed = await showHyperosDialog<bool>(
      context: context,
      title: l10n.locationTimeMatchKeywordLabel,
      body: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HyperosTextField(
                controller: controller,
                label: l10n.locationTimeMatchKeywordLabel,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              HyperosSelectTile<LocationKeywordMatchMode>(
                label: l10n.locationTimeMatchModeLabel,
                items: {
                  for (final item in LocationKeywordMatchMode.values)
                    _modeLabel(l10n, item): item,
                },
                value: mode,
                useSheetForPopup: true,
                onChanged: (value) {
                  setDialogState(() => mode = value);
                },
              ),
            ],
          );
        },
      ),
      actions: [
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context, false),
        ),
        HyperosDialogAction(
          label: l10n.saveAction,
          isPrimary: true,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
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
