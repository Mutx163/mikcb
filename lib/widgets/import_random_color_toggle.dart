import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../services/import_random_color_preferences.dart';
import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import 'course_recolor_sheet.dart';

/// Master switch + color-group picker for random course colors on the
/// course import hub page.
class ImportRandomColorToggle extends StatefulWidget {
  const ImportRandomColorToggle({super.key});

  @override
  State<ImportRandomColorToggle> createState() =>
      _ImportRandomColorToggleState();
}

class _ImportRandomColorToggleState extends State<ImportRandomColorToggle> {
  bool _enabled = ImportRandomColorPreferences.defaultEnabled;
  String _groupId = ImportRandomColorPreferences.defaultGroupId;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final enabled = await ImportRandomColorPreferences.isEnabled();
    final groupId = await ImportRandomColorPreferences.getGroupId();
    if (!mounted) {
      return;
    }
    setState(() {
      _enabled = enabled;
      _groupId = groupId;
      _loaded = true;
    });
  }

  Future<void> _onChanged(bool value) async {
    setState(() {
      _enabled = value;
    });
    await ImportRandomColorPreferences.setEnabled(value);
  }

  Future<void> _pickGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showHyperosSheet<String>(
      context: context,
      enableDrag: false,
      builder: (sheetContext) => HyperosSheet(
        title: l10n.importRandomColorGroupTitle,
        child: HyperosChoiceGroup(
          children: [
            _buildGroupOption(
              sheetContext,
              groupId: kCourseColorGroupAllId,
              label: l10n.colorGroupAll,
              previewHexes: kCourseColorQuickPickHexes,
            ),
            for (var index = 0; index < kCourseColorGroups.length; index++)
              _buildGroupOption(
                sheetContext,
                groupId: kCourseColorGroups[index].id,
                label: _groupLabel(kCourseColorGroups[index].id, l10n),
                previewHexes: kCourseColorGroups[index].hexes,
                showDivider: true,
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _groupId) {
      return;
    }
    setState(() {
      _groupId = selected;
    });
    await ImportRandomColorPreferences.setGroupId(selected);
  }

  Widget _buildGroupOption(
    BuildContext sheetContext, {
    required String groupId,
    required String label,
    required List<String> previewHexes,
    bool showDivider = false,
  }) {
    return HyperosChoiceTile(
      title: label,
      selected: _groupId == groupId,
      variant: HyperosChoiceVariant.dialog,
      showDivider: showDivider,
      onTap: () => Navigator.pop(sheetContext, groupId),
      subtitle: _ColorDotsPreview(hexes: previewHexes),
    );
  }

  String _groupLabel(String groupId, AppLocalizations l10n) {
    return colorGroupDisplayName(groupId, l10n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosListGroup(
      children: [
        HyperosSwitchTile(
          icon: Icons.palette_outlined,
          iconAccent: HyperosIconColors.purple,
          title: l10n.importRandomCourseColorTitle,
          subtitle: l10n.importRandomCourseColorSubtitle,
          value: _enabled,
          onChanged: _loaded ? _onChanged : null,
        ),
        HyperosListTile(
          title: l10n.importRandomColorGroupTitle,
          details: _groupLabel(_groupId, l10n),
          onTap: _loaded && _enabled ? _pickGroup : null,
        ),
      ],
    );
  }
}

/// 选组行的色点预览：色板过长时按步长抽样，最多 10 个点。
class _ColorDotsPreview extends StatelessWidget {
  const _ColorDotsPreview({required this.hexes});

  final List<String> hexes;

  @override
  Widget build(BuildContext context) {
    final stride = hexes.length > 10 ? (hexes.length / 10).ceil() : 1;
    final samples = <String>[
      for (var index = 0; index < hexes.length; index += stride)
        hexes[index],
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          for (final hex in samples.take(10)) ...[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: parseHexColorOrFallback(
                  hex,
                  fallback: const Color(0xFF2196F3),
                ),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}
