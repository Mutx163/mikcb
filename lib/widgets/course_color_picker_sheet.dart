import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../utils/hex_color.dart';

String colorToHex(Color color) {
  final red = (color.r * 255).round().clamp(0, 255);
  final green = (color.g * 255).round().clamp(0, 255);
  final blue = (color.b * 255).round().clamp(0, 255);
  return '#${red.toRadixString(16).padLeft(2, '0')}'
          '${green.toRadixString(16).padLeft(2, '0')}'
          '${blue.toRadixString(16).padLeft(2, '0')}'
      .toUpperCase();
}

/// Bottom sheet for picking a custom course color via Miuix HSV slider picker.
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

    return HyperosSheet(
      title: l10n.colorPaletteTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 当前颜色预览条
          Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: _pickerColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Miuix HSV 滑块取色器
          MiuixColorPicker(
            color: _pickerColor,
            onColorChanged: (color) => setState(() => _pickerColor = color),
            showPreview: false,
            hapticEffect: MiuixSliderHapticEffect.step,
          ),
          const SizedBox(height: 24),
          // 底部操作按钮
          Row(
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
        ],
      ),
    );
  }
}
