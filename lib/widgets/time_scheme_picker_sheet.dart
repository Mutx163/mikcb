import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:provider/provider.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/time_scheme.dart';
import '../providers/timetable_provider.dart';
import '../screens/time_scheme_management_screen.dart';

/// Bottom sheet for picking a per-entry time scheme override.
Future<void> showTimeSchemePickerSheet(
  BuildContext context, {
  required String? currentValue,
  required ValueChanged<String?> onSelected,
}) {
  return showFSheet<void>(
    context: context,
    side: FLayout.btt,
    useSafeArea: true,
    draggable: true,
    mainAxisMaxRatio: null,
    builder: (sheetContext) => _TimeSchemePickerSheetBody(
      hostContext: context,
      currentValue: currentValue,
      onSelected: (value) {
        onSelected(value);
        Navigator.of(sheetContext).pop();
      },
    ),
  );
}

class _TimeSchemePickerSheetBody extends StatefulWidget {
  const _TimeSchemePickerSheetBody({
    required this.hostContext,
    required this.currentValue,
    required this.onSelected,
  });

  final BuildContext hostContext;
  final String? currentValue;
  final ValueChanged<String?> onSelected;

  @override
  State<_TimeSchemePickerSheetBody> createState() =>
      _TimeSchemePickerSheetBodyState();
}

class _TimeSchemePickerSheetBodyState
    extends State<_TimeSchemePickerSheetBody> {
  Future<void> _openManagement({
    String? initialEditSchemeId,
    bool openCreateOnOpen = false,
    bool popSheetFirst = false,
  }) async {
    if (popSheetFirst && mounted) {
      Navigator.of(context).pop();
    }

    await Navigator.push<void>(
      widget.hostContext,
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/settings/time-schemes'),
        builder: (_) => TimeSchemeManagementScreen(
          initialEditSchemeId: initialEditSchemeId,
          openCreateOnOpen: openCreateOnOpen,
        ),
      ),
    );

    if (mounted) setState(() {});
  }

  String? _schemeMeta(TimeScheme scheme) {
    if (scheme.sections.isEmpty) return null;
    return '${scheme.sections.first.startTime}–${scheme.sections.last.endTime} · ${scheme.sectionCount}';
  }

  Widget? _selectionSuffix({
    required bool isSelected,
    VoidCallback? onEdit,
    required AppLocalizations l10n,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    if (onEdit != null) {
      widgets.add(
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: l10n.editTimeSchemeTitle,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onEdit,
        ),
      );
    }

    if (isSelected) {
      widgets.add(
        Icon(Icons.check_rounded, color: colorScheme.primary, size: 20),
      );
    }

    if (widgets.isEmpty) return null;

    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  Widget _schemeTitle({
    required String name,
    String? meta,
    required TextStyle baseStyle,
    required Color mutedColor,
  }) {
    if (meta == null) {
      return Text(name, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: name),
          TextSpan(
            text: ' · $meta',
            style: TextStyle(color: mutedColor),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final schemes = provider.timeSchemes;
    final followLabel =
        provider.activeTimeScheme?.name ?? l10n.timetableAppName;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;
    final titleStyle = typo.sm.copyWith(fontWeight: FontWeight.w600);
    final tileTitleStyle = typo.sm;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.38;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.selectTimeSchemeTitle, style: titleStyle),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxListHeight),
                child: SingleChildScrollView(
                  child: FTileGroup(
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      FTile(
                        title: Text(
                          l10n.followCurrentTimetableWithName(followLabel),
                          style: tileTitleStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        suffix: _selectionSuffix(
                          isSelected: widget.currentValue == null,
                          l10n: l10n,
                        ),
                        onPress: () => widget.onSelected(null),
                      ),
                      for (final scheme in schemes)
                        FTile(
                          title: _schemeTitle(
                            name: scheme.name,
                            meta: _schemeMeta(scheme),
                            baseStyle: tileTitleStyle,
                            mutedColor: colors.mutedForeground,
                          ),
                          suffix: _selectionSuffix(
                            isSelected: widget.currentValue == scheme.id,
                            onEdit: () =>
                                _openManagement(initialEditSchemeId: scheme.id),
                            l10n: l10n,
                          ),
                          onPress: () => widget.onSelected(scheme.id),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.secondary,
                      onPress: () => _openManagement(popSheetFirst: true),
                      prefix: const Icon(Icons.settings_rounded, size: 18),
                      child: Text(l10n.manageTimeSchemesAction),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FButton(
                      variant: FButtonVariant.secondary,
                      onPress: () => _openManagement(
                        popSheetFirst: true,
                        openCreateOnOpen: true,
                      ),
                      prefix: const Icon(Icons.add_rounded, size: 18),
                      child: Text(l10n.createTimeSchemeTitle),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
