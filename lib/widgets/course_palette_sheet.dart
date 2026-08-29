import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import 'course_color_picker_sheet.dart';

/// Bottom sheet presenting the full preset course palette as a chip grid.
///
/// Tapping a chip pops with its hex directly; the trailing palette chip
/// chains into the HSV custom picker and pops with its result instead.
Future<String?> showCoursePaletteSheet(
  BuildContext context, {
  required String initialColorHex,
}) {
  return showHyperosSheet<String>(
    context: context,
    enableDrag: false,
    builder: (sheetContext) => _CoursePaletteSheetBody(
      initialColorHex: initialColorHex.toUpperCase(),
    ),
  );
}

class _CoursePaletteSheetBody extends StatelessWidget {
  const _CoursePaletteSheetBody({required this.initialColorHex});

  final String initialColorHex;

  Future<void> _openCustomPicker(BuildContext context) async {
    final custom = await showCourseColorPickerSheet(
      context,
      initialColorHex: initialColorHex,
    );
    if (custom == null || !context.mounted) {
      return;
    }
    Navigator.of(context).pop(custom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;

    return HyperosSheet(
      title: l10n.colorPaletteTitle,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.64,
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final colorHex in kPresetCourseColorHexes)
                _PaletteChip(
                  colorHex: colorHex,
                  isSelected: initialColorHex == colorHex.toUpperCase(),
                  selectionBorder: theme.colors.foreground,
                  borderColor: theme.colors.border,
                  onTap: () => Navigator.of(context).pop(colorHex),
                ),
              _PaletteChip(
                colorHex: kPresetCourseColorHexes.contains(initialColorHex)
                    ? null
                    : initialColorHex,
                selectionBorder: theme.colors.foreground,
                borderColor: theme.colors.border,
                onTap: () => _openCustomPicker(context),
                icon: Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: theme.colors.mutedForeground,
                ),
                tooltip: l10n.customPaletteAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.selectionBorder,
    required this.borderColor,
    required this.onTap,
    this.colorHex,
    this.isSelected = false,
    this.icon,
    this.tooltip,
  });

  final String? colorHex;
  final bool isSelected;
  final Color selectionBorder;
  final Color borderColor;
  final VoidCallback onTap;
  final Widget? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    const size = 36.0;
    final parsed =
        tryParseHexColor(colorHex) ?? context.theme.colors.secondary;
    // 浅色阶上白色对勾不可见，按亮度切换勾色（与卡片墨色守卫同思路）。
    final checkColor = parsed.computeLuminance() > 0.5
        ? const Color(0xFF1A1A1A)
        : Colors.white;
    final chip = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: parsed,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? selectionBorder : borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: icon == null && isSelected
            ? Icon(Icons.check, size: 18, color: checkColor)
            : Center(child: icon),
      ),
    );
    if (tooltip == null) {
      return chip;
    }
    return Tooltip(message: tooltip!, child: chip);
  }
}
