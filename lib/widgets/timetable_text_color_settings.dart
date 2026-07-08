import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/hex_color.dart';

class TimetableTextColorSettings extends StatelessWidget {
  const TimetableTextColorSettings({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  final TimetableSettings settings;
  final ValueChanged<TimetableSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return HyperosControlCard(
      title: l10n.appearanceTextColorsSectionTitle,
      subtitle: l10n.appearanceTextColorsSectionSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HyperosSwitchTile(
            title: l10n.textColorIndependentDetail,
            value: !settings.linkCourseCardColors,
            onChanged: (value) {
              if (!value) {
                onChanged(
                  settings.copyWith(
                    linkCourseCardColors: true,
                    courseCardDetailColorLight:
                        settings.courseCardTitleColorLight,
                    courseCardDetailColorDark:
                        settings.courseCardTitleColorDark,
                  ),
                );
              } else {
                onChanged(settings.copyWith(linkCourseCardColors: false));
              }
            },
          ),
          const SizedBox(height: 12),
          _ModeColorSettings(
            settings: settings,
            onChanged: onChanged,
            modeLabel: l10n.themeModeLight,
            containerColor: Theme.of(context).colorScheme.surfaceContainerLow,
            titleColor: settings.courseCardTitleColorLight,
            detailColor: settings.courseCardDetailColorLight,
            weekdayColor: settings.weekdayBarFontColorLight,
            timeAxisColor: settings.timeAxisFontColorLight,
            accentColor: settings.weekdayBarAccentColorLight,
            onTitleColorChanged: (color) {
              if (settings.linkCourseCardColors) {
                onChanged(
                  settings.copyWith(
                    courseCardTitleColorLight: color,
                    courseCardDetailColorLight: color,
                  ),
                );
              } else {
                onChanged(settings.copyWith(courseCardTitleColorLight: color));
              }
            },
            onDetailColorChanged: (color) => onChanged(
              settings.copyWith(courseCardDetailColorLight: color),
            ),
            onWeekdayColorChanged: (color) =>
                onChanged(settings.copyWith(weekdayBarFontColorLight: color)),
            onTimeAxisColorChanged: (color) =>
                onChanged(settings.copyWith(timeAxisFontColorLight: color)),
            onAccentColorChanged: (color) =>
                onChanged(settings.copyWith(weekdayBarAccentColorLight: color)),
            defaultTitleColor: TimetableSettings.defaultCourseCardTitleColor,
            defaultDetailColor: TimetableSettings.defaultCourseCardDetailColor,
            defaultWeekdayColor:
                TimetableSettings.defaultWeekdayBarFontColorLight,
            defaultTimeAxisColor:
                TimetableSettings.defaultTimeAxisFontColorLight,
            defaultAccentColor:
                TimetableSettings.defaultWeekdayBarAccentColorLight,
          ),
          const SizedBox(height: 12),
          _ModeColorSettings(
            settings: settings,
            onChanged: onChanged,
            modeLabel: l10n.themeModeDark,
            containerColor: Theme.of(context).colorScheme.surfaceContainerHigh,
            titleColor: settings.courseCardTitleColorDark,
            detailColor: settings.courseCardDetailColorDark,
            weekdayColor: settings.weekdayBarFontColorDark,
            timeAxisColor: settings.timeAxisFontColorDark,
            accentColor: settings.weekdayBarAccentColorDark,
            onTitleColorChanged: (color) {
              if (settings.linkCourseCardColors) {
                onChanged(
                  settings.copyWith(
                    courseCardTitleColorDark: color,
                    courseCardDetailColorDark: color,
                  ),
                );
              } else {
                onChanged(settings.copyWith(courseCardTitleColorDark: color));
              }
            },
            onDetailColorChanged: (color) => onChanged(
              settings.copyWith(courseCardDetailColorDark: color),
            ),
            onWeekdayColorChanged: (color) =>
                onChanged(settings.copyWith(weekdayBarFontColorDark: color)),
            onTimeAxisColorChanged: (color) =>
                onChanged(settings.copyWith(timeAxisFontColorDark: color)),
            onAccentColorChanged: (color) =>
                onChanged(settings.copyWith(weekdayBarAccentColorDark: color)),
            defaultTitleColor: TimetableSettings.defaultCourseCardTitleColor,
            defaultDetailColor: TimetableSettings.defaultCourseCardDetailColor,
            defaultWeekdayColor:
                TimetableSettings.defaultWeekdayBarFontColorDark,
            defaultTimeAxisColor: TimetableSettings.defaultTimeAxisFontColorDark,
            defaultAccentColor: TimetableSettings.defaultWeekdayBarAccentColorDark,
          ),
        ],
      ),
    );
  }
}

class _ModeColorSettings extends StatelessWidget {
  const _ModeColorSettings({
    required this.settings,
    required this.onChanged,
    required this.modeLabel,
    required this.containerColor,
    required this.titleColor,
    required this.detailColor,
    required this.weekdayColor,
    required this.timeAxisColor,
    required this.accentColor,
    required this.onTitleColorChanged,
    required this.onDetailColorChanged,
    required this.onWeekdayColorChanged,
    required this.onTimeAxisColorChanged,
    required this.onAccentColorChanged,
    required this.defaultTitleColor,
    required this.defaultDetailColor,
    required this.defaultWeekdayColor,
    required this.defaultTimeAxisColor,
    required this.defaultAccentColor,
  });

  final TimetableSettings settings;
  final ValueChanged<TimetableSettings> onChanged;
  final String modeLabel;
  final Color containerColor;
  final String titleColor;
  final String detailColor;
  final String weekdayColor;
  final String timeAxisColor;
  final String accentColor;
  final ValueChanged<String> onTitleColorChanged;
  final ValueChanged<String> onDetailColorChanged;
  final ValueChanged<String> onWeekdayColorChanged;
  final ValueChanged<String> onTimeAxisColorChanged;
  final ValueChanged<String> onAccentColorChanged;
  final String defaultTitleColor;
  final String defaultDetailColor;
  final String defaultWeekdayColor;
  final String defaultTimeAxisColor;
  final String defaultAccentColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              modeLabel,
              style: HyperosTypography.sectionLabel(context).copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          _ColorSettingRow(
            label: l10n.textColorCourseCardTitle,
            currentColor: titleColor,
            defaultValue: defaultTitleColor,
            onColorSelected: onTitleColorChanged,
            bgColorForContrast: settings.timetableUseUnifiedCardColor
                ? settings.timetableUnifiedCardColor
                : settings.themeSeedColor,
          ),
          _ColorSettingRow(
            label: l10n.textColorCourseCardDetail,
            currentColor: detailColor,
            defaultValue: defaultDetailColor,
            enabled: !settings.linkCourseCardColors,
            onColorSelected: onDetailColorChanged,
            bgColorForContrast: settings.timetableUseUnifiedCardColor
                ? settings.timetableUnifiedCardColor
                : settings.themeSeedColor,
          ),
          _ColorSettingRow(
            label: l10n.textColorWeekdayBar,
            currentColor: weekdayColor,
            defaultValue: defaultWeekdayColor,
            onColorSelected: onWeekdayColorChanged,
            bgColorForContrast: settings.timetablePageBackgroundColor,
          ),
          _ColorSettingRow(
            label: l10n.textColorWeekdayBarAccent,
            currentColor: accentColor,
            defaultValue: defaultAccentColor,
            onColorSelected: onAccentColorChanged,
            bgColorForContrast: settings.timetablePageBackgroundColor,
          ),
          _ColorSettingRow(
            label: l10n.textColorTimeAxis,
            currentColor: timeAxisColor,
            defaultValue: defaultTimeAxisColor,
            onColorSelected: onTimeAxisColorChanged,
            bgColorForContrast: settings.timetablePageBackgroundColor,
          ),
        ],
      ),
    );
  }
}

class _ColorSettingRow extends StatelessWidget {
  const _ColorSettingRow({
    required this.label,
    required this.currentColor,
    required this.onColorSelected,
    this.defaultValue,
    this.enabled = true,
    this.bgColorForContrast,
  });

  final String label;
  final String currentColor;
  final ValueChanged<String> onColorSelected;
  final String? defaultValue;
  final bool enabled;
  final String? bgColorForContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: HyperosTypography.listTitle(context)),
            ),
            GestureDetector(
              onTap: enabled
                  ? () => _showColorPicker(
                      context,
                      currentColor: currentColor,
                      onColorSelected: onColorSelected,
                      defaultValue: defaultValue,
                    )
                  : null,
              child: Semantics(
                label: '${l10n.textColorCurrentColor}: $currentColor',
                button: true,
                child: Tooltip(
                  message: currentColor,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: parseHexColorOrFallback(
                        currentColor,
                        fallback: Theme.of(context).colorScheme.onSurface,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(
    BuildContext context, {
    required String currentColor,
    required ValueChanged<String> onColorSelected,
    String? defaultValue,
  }) {
    final l10n = AppLocalizations.of(context)!;
    Color pickerColor = parseHexColorOrFallback(
      currentColor,
      fallback: Theme.of(context).colorScheme.primary,
    );

    showHyperosDialog<void>(
      context: context,
      title: l10n.textColorSelectColor,
      body: SingleChildScrollView(
        child: ColorPicker(
          color: pickerColor,
          onColorChanged: (Color color) {
            pickerColor = color;
          },
          width: 40,
          height: 40,
          borderRadius: 4,
          spacing: 5,
          runSpacing: 5,
          wheelDiameter: 260,
          wheelWidth: 26,
          enableOpacity: false,
          showColorCode: true,
          showColorName: false,
          showMaterialName: false,
          copyPasteBehavior: const ColorPickerCopyPasteBehavior(
            copyButton: true,
            pasteButton: true,
            longPressMenu: true,
          ),
          colorCodeTextStyle: Theme.of(context).textTheme.bodyMedium,
          pickersEnabled: const <ColorPickerType, bool>{
            ColorPickerType.both: false,
            ColorPickerType.primary: true,
            ColorPickerType.accent: false,
            ColorPickerType.bw: true,
            ColorPickerType.custom: false,
            ColorPickerType.wheel: true,
          },
        ),
      ),
      actions: [
        if (defaultValue != null &&
            defaultValue.toLowerCase() != currentColor.toLowerCase())
          HyperosDialogAction(
            label: l10n.resetDefaultAction,
            onPressed: () {
              onColorSelected(defaultValue);
              Navigator.pop(context);
            },
          ),
        HyperosDialogAction(
          label: l10n.cancelAction,
          onPressed: () => Navigator.pop(context),
        ),
        HyperosDialogAction(
          label: l10n.confirmAction,
          isPrimary: true,
          onPressed: () {
            final r = ((pickerColor.r * 255.0).round() & 0xff)
                .toRadixString(16)
                .padLeft(2, '0');
            final g = ((pickerColor.g * 255.0).round() & 0xff)
                .toRadixString(16)
                .padLeft(2, '0');
            final b = ((pickerColor.b * 255.0).round() & 0xff)
                .toRadixString(16)
                .padLeft(2, '0');
            onColorSelected('#${(r + g + b).toUpperCase()}');
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
