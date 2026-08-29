import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../models/location_time_group.dart';
import '../models/time_scheme.dart';
import '../domain/location_building_cluster_logic.dart';
import '../providers/timetable_provider.dart';
import '../logging/app_debug_log.dart';
import '../services/app_log_service.dart';
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
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer<TimetableProvider>(
      builder: (context, provider, child) {
        final groups = provider.locationTimeGroups;
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
              HyperosSectionLabel(text: l10n.locationTimeMatchEntryTitle),
              if (groups.isEmpty)
                HyperosListGroup(
                  children: [
                    HyperosActionTile(
                      icon: Icons.add_rounded,
                      title: l10n.locationTimeMatchCreateGroup,
                      onTap: () => _openEditor(context, provider),
                    ),
                  ],
                )
              else ...[
                for (var index = 0; index < groups.length; index++) ...[
                  if (index > 0) const HyperosSectionGap(),
                  _buildGroupCard(context, provider, groups[index]),
                ],
              ],
              HyperosSectionDescription(text: l10n.locationTimeMatchSubtitle),
              if (groups.isNotEmpty) ...[
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
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top edge of card (no header): round top press; bottom is button row.
          HyperosControlCardRowScope(
            isFirst: true,
            isLast: false,
            child: HyperosSwitchTile(
              icon: Icons.place_outlined,
              iconAccent: HyperosIconColors.orange,
              title: group.name,
              subtitle:
                  '${l10n.locationTimeMatchBoundScheme(schemeName)} · '
                  '${l10n.locationTimeMatchKeywordsLine(keywordText)}',
              value: group.enabled,
              onChanged: (value) async {
                await provider.updateLocationTimeGroup(
                  group.copyWith(enabled: value),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
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
    final candidateCount = provider.courses
        .where((course) => provider.matchLocationTime(course.location) != null)
        .length;
    if (candidateCount == 0) {
      showAppToast(
        context,
        message: l10n.locationTimeMatchApplyNoneMatched,
        kind: AppToastKind.info,
      );
      return;
    }
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.locationTimeMatchApplyTitle,
      message: l10n.locationTimeMatchApplyMessage(candidateCount),
      confirmLabel: l10n.locationTimeMatchApplyConfirm,
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final overridesBefore = provider.courses
        .where((course) => course.timeSchemeIdOverride != null)
        .length;
    appDebugLog(
      'LocationTimeApplyUI',
      '用户点击「重新匹配当前课表」 courses=${provider.courses.length} '
          'groups=${provider.locationTimeGroups.length} '
          'overridesBefore=$overridesBefore',
    );
    unawaited(
      AppLogService.instance.info(
        'location_time_apply_ui',
        '用户点击「重新匹配当前课表」',
        extras: {
          'courses': provider.courses.length,
          'groups': provider.locationTimeGroups.length,
          'overridesBefore': overridesBefore,
        },
      ),
    );
    final stats = await provider.applyLocationTimeRulesToActiveProfile();
    if (!context.mounted) {
      return;
    }
    final overridesAfter = provider.courses
        .where((course) => course.timeSchemeIdOverride != null)
        .length;
    final sampleOverrides = provider.courses
        .take(12)
        .map(
          (course) =>
              '${course.name}|${course.id}|override=${course.timeSchemeIdOverride ?? "null"}|${course.startTime}-${course.endTime}|loc=${course.location}',
        )
        .join(' || ');
    appDebugLog(
      'LocationTimeApplyUI',
      '应用结果 toast: matched=${stats.matchedCount} updated=${stats.updatedCount} '
          'unlocked=${stats.unlockedCount} sameClock=${stats.alreadySameClockCount} '
          'overflow=${stats.sectionOverflowCount} '
          'overflowNames=${stats.sectionOverflowCourseNames.join(",")} '
          'overridesAfter=$overridesAfter samples=$sampleOverrides',
    );
    unawaited(
      AppLogService.instance.info(
        'location_time_apply_ui',
        '应用结果: matched=${stats.matchedCount} updated=${stats.updatedCount} '
            'overridesAfter=$overridesAfter',
        extras: {
          'matched': stats.matchedCount,
          'updated': stats.updatedCount,
          'unlocked': stats.unlockedCount,
          'sameClock': stats.alreadySameClockCount,
          'overflow': stats.sectionOverflowCount,
          'overflowNames': stats.sectionOverflowCourseNames,
          'overridesAfter': overridesAfter,
          'samples': sampleOverrides,
        },
      ),
    );
    // Scenario-based copy: "matched but updated 0" is usually success
    // (clocks already aligned), not a failure — never show as "更新 0".
    final String message;
    final String? description;
    final AppToastKind toastKind;
    if (stats.updatedCount > 0 && stats.sectionOverflowCount > 0) {
      // Partial success: some fully mapped, some rejected for overflow.
      message =
          '${l10n.locationTimeMatchApplyUpdated(stats.matchedCount, stats.updatedCount)}；'
          '${l10n.locationTimeMatchApplyOverflowResult(stats.matchedCount, stats.sectionOverflowCount)}';
      description = stats.sectionOverflowCourseNames.isEmpty
          ? null
          : l10n.locationTimeMatchApplyOverflowHint(
              stats.sectionOverflowCourseNames.join('、'),
            );
      toastKind = AppToastKind.warning;
    } else if (stats.updatedCount > 0) {
      message = l10n.locationTimeMatchApplyUpdated(
        stats.matchedCount,
        stats.updatedCount,
      );
      description = null;
      toastKind = AppToastKind.success;
    } else if (stats.sectionOverflowCount > 0 && stats.matchedCount > 0) {
      message = l10n.locationTimeMatchApplyOverflowResult(
        stats.matchedCount,
        stats.sectionOverflowCount,
      );
      description = stats.sectionOverflowCourseNames.isEmpty
          ? null
          : l10n.locationTimeMatchApplyOverflowHint(
              stats.sectionOverflowCourseNames.join('、'),
            );
      toastKind = AppToastKind.warning;
    } else if (stats.matchedCount > 0) {
      message = l10n.locationTimeMatchApplyAlreadyAligned(stats.matchedCount);
      description = null;
      toastKind = AppToastKind.success;
    } else {
      message = l10n.locationTimeMatchApplyNoneMatched;
      description = null;
      toastKind = AppToastKind.info;
    }
    // Show immediately: this is a full page (not a modal sheet). Deferring to
    // postFrameCallback races Provider rebuild + Overlay insert and can drop
    // the first toast (user has to tap again).
    if (!context.mounted) {
      return;
    }
    showAppToast(
      context,
      message: message,
      description: description,
      kind: toastKind,
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

class _LocationKeywordDialogField extends StatefulWidget {
  const _LocationKeywordDialogField({
    required this.initialValue,
    required this.label,
    required this.onChanged,
    this.hint,
    this.autofocus = false,
  });

  final String initialValue;
  final String label;
  final String? hint;
  final bool autofocus;
  final ValueChanged<String> onChanged;

  @override
  State<_LocationKeywordDialogField> createState() =>
      _LocationKeywordDialogFieldState();
}

class _LocationKeywordDialogFieldState
    extends State<_LocationKeywordDialogField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HyperosTextField(
      controller: _controller,
      label: widget.label,
      hint: widget.hint,
      autofocus: widget.autofocus,
      onChanged: widget.onChanged,
    );
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

  /// Editing an existing group must not treat its own keywords as conflicts.
  String? get _editingGroupId => widget.existing?.id;

  bool _hasKeyword(String pattern) {
    final normalized = pattern.trim().toLowerCase();
    return _keywords.any(
      (draft) =>
          draft.patternController.text.trim().toLowerCase() == normalized,
    );
  }

  /// Returns owner group name when [pattern] is claimed elsewhere, else null.
  String? _otherGroupOwningPattern(TimetableProvider provider, String pattern) {
    return LocationTimeMatchLogic.groupNameOwningPattern(
      provider.locationTimeGroups,
      pattern,
      excludingGroupId: _editingGroupId,
    );
  }

  /// Classrooms free for this editor (not already matched by another group).
  List<String> _availableLocations(TimetableProvider provider) {
    return provider.uniqueLocations
        .where(
          (location) => !LocationTimeMatchLogic.isLocationClaimedByOtherGroups(
            location,
            provider.locationTimeGroups,
            excludingGroupId: _editingGroupId,
          ),
        )
        .toList();
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
    final provider = context.read<TimetableProvider>();
    final ownerName = _otherGroupOwningPattern(provider, pattern);
    if (ownerName != null) {
      if (showToast) {
        showAppToast(
          context,
          message: l10n.locationTimeMatchKeywordUsedByGroup(ownerName),
          kind: AppToastKind.warning,
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

    final provider = context.read<TimetableProvider>();
    final addedPatterns = <String>[];
    setState(() {
      for (final cluster in uncovered) {
        final pattern = cluster.suggestedKeyword.pattern.trim();
        if (pattern.isEmpty ||
            _hasKeyword(pattern) ||
            _otherGroupOwningPattern(provider, pattern) != null) {
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
      suggestions: _availableLocations(provider),
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
      existingKeywords: [
        ...currentKeywords,
        ...LocationTimeMatchLogic.keywordsFromOtherGroups(
          provider.locationTimeGroups,
          excludingGroupId: _editingGroupId,
        ),
      ],
    );
    final schemeItems = <String, String>{
      // Unique labels so duplicate scheme names never collapse Map keys.
      for (final scheme in schemes)
        _timeSchemeSelectLabel(schemes, scheme): scheme.id,
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
            HyperosListGroup(
              children: [
                HyperosNavTile(
                  title: l10n.locationTimeMatchNeedTimeScheme,
                  enabled: false,
                  showChevron: false,
                ),
              ],
            )
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
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MiuixPressable(
                              onPressed: () =>
                                  _editKeywordDialog(context, l10n, index),
                              borderRadius: BorderRadius.circular(6),
                              child: HyperosTag(
                                label:
                                    '${_keywords[index].patternController.text} · ${_modeLabel(l10n, _keywords[index].mode)}',
                                outlined: true,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Tooltip(
                              message: l10n.deleteAction,
                              child: MiuixIconButton(
                                onPressed: () => _removeKeywordAt(index),
                                minWidth: 24,
                                minHeight: 24,
                                cornerRadius: 12,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: HyperosColors.secondaryText(context),
                                ),
                              ),
                            ),
                          ],
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
          HyperosSectionDescription(text: l10n.locationTimeMatchKeywordsHelp),
          const HyperosSectionGap(),
          HyperosSectionLabel(text: l10n.locationTimeMatchBuildingSuggestions),
          if (uncovered.isEmpty)
            HyperosListGroup(
              children: [
                HyperosNavTile(
                  title: l10n.locationTimeMatchNoBuildingSuggestions,
                  enabled: false,
                  showChevron: false,
                ),
              ],
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
      ?gateText,
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
    var patternDraft = '';
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
              _LocationKeywordDialogField(
                initialValue: patternDraft,
                label: l10n.locationTimeMatchKeywordLabel,
                hint: l10n.locationTimeMatchKeywordHint,
                autofocus: true,
                onChanged: (value) => patternDraft = value,
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
    final pattern = patternDraft.trim();
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
    var patternDraft = draft.patternController.text;
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
              _LocationKeywordDialogField(
                initialValue: patternDraft,
                label: l10n.locationTimeMatchKeywordLabel,
                autofocus: true,
                onChanged: (value) => patternDraft = value,
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
    final pattern = patternDraft.trim();
    if (confirmed == true && pattern.isNotEmpty && context.mounted) {
      if (_hasKeyword(pattern) &&
          pattern.toLowerCase() !=
              draft.patternController.text.trim().toLowerCase()) {
        showAppToast(
          context,
          message: l10n.locationTimeMatchKeywordAlreadyExists,
          kind: AppToastKind.info,
        );
        return;
      }
      final provider = context.read<TimetableProvider>();
      final ownerName = _otherGroupOwningPattern(provider, pattern);
      if (ownerName != null) {
        showAppToast(
          context,
          message: l10n.locationTimeMatchKeywordUsedByGroup(ownerName),
          kind: AppToastKind.warning,
        );
        return;
      }
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

    for (final keyword in keywords) {
      final ownerName = _otherGroupOwningPattern(provider, keyword.pattern);
      if (ownerName != null) {
        showAppToast(
          context,
          message: l10n.locationTimeMatchKeywordUsedByGroup(ownerName),
          kind: AppToastKind.error,
        );
        return;
      }
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

/// Builds a unique select label for [scheme] so duplicate names never collapse
/// [Map] keys in [HyperosSelectTile] items.
String _timeSchemeSelectLabel(List<TimeScheme> schemes, TimeScheme scheme) {
  final duplicateCount = schemes
      .where((candidate) => candidate.name == scheme.name)
      .length;
  if (duplicateCount <= 1) {
    return scheme.name;
  }
  final shortId = scheme.id.length <= 8 ? scheme.id : scheme.id.substring(0, 8);
  return '${scheme.name} · $shortId';
}
