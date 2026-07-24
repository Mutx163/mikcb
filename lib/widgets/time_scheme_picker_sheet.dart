import 'package:flutter/material.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
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

  /// When the entry is in auto mode, describes which scheme is currently used.
  String? autoResolvedSubtitle,
}) {
  return showHyperosSheet<void>(
    context: context,
    builder: (sheetContext) => _TimeSchemePickerSheetBody(
      hostContext: context,
      currentValue: currentValue,
      autoResolvedSubtitle: autoResolvedSubtitle,
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
    this.autoResolvedSubtitle,
  });

  final BuildContext hostContext;
  final String? currentValue;
  final ValueChanged<String?> onSelected;
  final String? autoResolvedSubtitle;

  @override
  State<_TimeSchemePickerSheetBody> createState() =>
      _TimeSchemePickerSheetBodyState();
}

class _TimeSchemePickerSheetBodyState
    extends State<_TimeSchemePickerSheetBody> {
  Future<void> _openManagement({String? initialEditSchemeId}) async {
    await Navigator.push<void>(
      widget.hostContext,
      HyperosPageRoute<void>(
        settings: const RouteSettings(name: '/settings/time-schemes'),
        builder: (_) => TimeSchemeManagementScreen(
          initialEditSchemeId: initialEditSchemeId,
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
                    title: l10n.followLocationAutoTimeScheme,
                    subtitle: Text(
                      widget.autoResolvedSubtitle?.trim().isNotEmpty == true
                          ? widget.autoResolvedSubtitle!
                          : l10n.followLocationAutoTimeSchemeDescription,
                    ),
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
        ],
      ),
    );
  }
}
