import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../utils/hex_color.dart';
import 'course_field_picker_sheet.dart';

String colorToHex(Color color) {
  final red = (color.r * 255).round().clamp(0, 255);
  final green = (color.g * 255).round().clamp(0, 255);
  final blue = (color.b * 255).round().clamp(0, 255);
  return '#${red.toRadixString(16).padLeft(2, '0')}'
          '${green.toRadixString(16).padLeft(2, '0')}'
          '${blue.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Bottom sheet for picking a custom course color via palette / wheel.
Future<String?> showCourseColorPickerSheet(
  BuildContext context, {
  required String initialColorHex,
}) {
  return showHyperosSheet<String>(
    context: context,
    builder: (_) =>
        _CourseColorPickerSheetBody(initialColorHex: initialColorHex),
  );
}

class _CourseColorPickerSheetBody extends StatefulWidget {
  const _CourseColorPickerSheetBody({required this.initialColorHex});

  final String initialColorHex;

  @override
  State<_CourseColorPickerSheetBody> createState() =>
      _CourseColorPickerSheetBodyState();
}

class _CourseColorPickerSheetBodyState
    extends State<_CourseColorPickerSheetBody> {
  late Color _pickerColor;

  @override
  void initState() {
    super.initState();
    _pickerColor = parseHexColorOrFallback(
      widget.initialColorHex,
      fallback: const Color(0xFF2196F3),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.theme.colors;
    final typo = context.theme.typography.body;

    return PickerSheetScaffold(
      actions: Row(
        children: [
          Expanded(
            child: HyperosButton(
              label: l10n.cancelAction,
              variant: HyperosButtonVariant.secondary,
              expand: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: HyperosButton(
              label: l10n.useThisColor,
              expand: true,
              onPressed: () =>
                  Navigator.of(context).pop(colorToHex(_pickerColor)),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.colorPaletteTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _pickerColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
          ),
          const SizedBox(height: 12),
          ColorPicker(
            color: _pickerColor,
            onColorChanged: (color) => setState(() => _pickerColor = color),
            width: 36,
            height: 36,
            borderRadius: 8,
            spacing: 6,
            runSpacing: 6,
            wheelDiameter: 220,
            wheelWidth: 22,
            enableOpacity: false,
            showColorCode: true,
            showColorName: false,
            showMaterialName: false,
            copyPasteBehavior: const ColorPickerCopyPasteBehavior(
              copyButton: true,
              pasteButton: true,
              longPressMenu: true,
            ),
            colorCodeTextStyle: typo.sm,
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: false,
              ColorPickerType.bw: true,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
            },
          ),
        ],
      ),
    );
  }
}
