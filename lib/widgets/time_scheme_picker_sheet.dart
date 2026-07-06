import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:provider/provider.dart';import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/time_scheme.dart';
import '../providers/timetable_provider.dart';
import '../screens/time_scheme_management_screen.dart';

/// Bottom sheet for picking a per-entry time scheme override.
Future<void> showTimeSchemePickerSheet(
  BuildContext context, {
  required String? currentValue,
  required ValueChanged<String?> onSelected,
}) {
  return showHyperosSheet<void>(
    context: context,
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
      HyperosPageRoute<void>(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TimetableProvider>();
    final schemes = provider.timeSchemes;
    final followLabel =
        provider.activeTimeScheme?.name ?? l10n.timetableAppName;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.38;

    return HyperosSheet(
      title: l10n.selectTimeSchemeTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: HyperosChoiceGroup(
                children: [
                  HyperosChoiceTile(
                    title: l10n.followCurrentTimetableWithName(followLabel),
                    selected: widget.currentValue == null,
                    highlightSelectedText: true,
                    onTap: () => widget.onSelected(null),
                  ),
                  for (final scheme in schemes)
                    HyperosChoiceTile(
                      title: scheme.name,
                      subtitle: _schemeMeta(scheme) == null
                          ? null
                          : Text(_schemeMeta(scheme)!),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: l10n.editTimeSchemeTitle,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: () =>
                            _openManagement(initialEditSchemeId: scheme.id),
                      ),
                      selected: widget.currentValue == scheme.id,
                      highlightSelectedText: true,
                      onTap: () => widget.onSelected(scheme.id),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: HyperosButton(
                  label: l10n.manageTimeSchemesAction,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _openManagement(popSheetFirst: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: HyperosButton(
                  label: l10n.createTimeSchemeTitle,
                  variant: HyperosButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _openManagement(
                    popSheetFirst: true,
                    openCreateOnOpen: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
