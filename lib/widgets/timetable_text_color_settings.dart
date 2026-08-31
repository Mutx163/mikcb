import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:university_timetable/l10n/app_localizations.dart';

import '../models/timetable_settings.dart';
import '../ui/hyperos/hyperos.dart';
import '../utils/hex_color.dart';

/// Scope identifier for text color settings.
///
/// The scope decides which color rows render on which settings page:
/// course-card rows (title / detail + the independent-detail switch) go to the
/// course-card page; page rows (weekday bar / accent / time axis) go to the
/// timetable-page page. Ownership mirrors the reset scopes in
/// settings_reset.dart — a color field is editable on exactly one page.
class TextColorScope {
  const TextColorScope._(this.name);

  /// The name of this scope, for identification purposes.
  final String name;

  /// Text colors for course cards (title, detail).
  static const courseCard = TextColorScope._('courseCard');

  /// Text colors for the timetable page (weekday bar, time axis).
  static const page = TextColorScope._('page');
}

/// 文字颜色设置区块，按 scope 决定渲染哪些颜色行。
///
/// 「课程卡片」页渲染课卡标题/详情与「详情字色独立」开关；「课表页面」页
/// 渲染星期栏/强调/时间轴。同一字段只在一页出现，与 settings_reset.dart
/// 的重置作用域字段划分一一对应。
class TimetableTextColorSettings extends StatelessWidget {
  const TimetableTextColorSettings({
    super.key,
    required this.settings,
    required this.onChanged,
    required this.scope,
  });

  final TimetableSettings settings;
  final ValueChanged<TimetableSettings> onChanged;
  final TextColorScope scope;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showCourseCardRows = scope == TextColorScope.courseCard;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.appearanceTextColorsSectionTitle),

        // 卡片 1：链接课程卡片颜色（开关）——课卡专属，只在课程卡片页出现。
        if (showCourseCardRows) ...[
          HyperosControlCard(
            edgeToEdge: true,
            child: HyperosControlCardRowScope(
              isFirst: true,
              isLast: true,
              child: HyperosSwitchTile(
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
            ),
          ),

          const SizedBox(height: 12),
        ],

        // 卡片 2：浅色模式颜色设置
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.themeModeLight),
        _ModeColorSettings(
          scope: scope,
          settings: settings,
          onChanged: onChanged,
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
          onDetailColorChanged: (color) =>
              onChanged(settings.copyWith(courseCardDetailColorLight: color)),
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
          defaultTimeAxisColor: TimetableSettings.defaultTimeAxisFontColorLight,
          defaultAccentColor:
              TimetableSettings.defaultWeekdayBarAccentColorLight,
        ),

        const SizedBox(height: 12),

        // 卡片 3：深色模式颜色设置
        const HyperosSectionGap(),
        HyperosSectionLabel(text: l10n.themeModeDark),
        _ModeColorSettings(
          scope: scope,
          settings: settings,
          onChanged: onChanged,
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
          onDetailColorChanged: (color) =>
              onChanged(settings.copyWith(courseCardDetailColorDark: color)),
          onWeekdayColorChanged: (color) =>
              onChanged(settings.copyWith(weekdayBarFontColorDark: color)),
          onTimeAxisColorChanged: (color) =>
              onChanged(settings.copyWith(timeAxisFontColorDark: color)),
          onAccentColorChanged: (color) =>
              onChanged(settings.copyWith(weekdayBarAccentColorDark: color)),
          defaultTitleColor: TimetableSettings.defaultCourseCardTitleColor,
          defaultDetailColor: TimetableSettings.defaultCourseCardDetailColor,
          defaultWeekdayColor: TimetableSettings.defaultWeekdayBarFontColorDark,
          defaultTimeAxisColor: TimetableSettings.defaultTimeAxisFontColorDark,
          defaultAccentColor:
              TimetableSettings.defaultWeekdayBarAccentColorDark,
        ),
      ],
    );
  }
}

class _ModeColorSettings extends StatelessWidget {
  const _ModeColorSettings({
    required this.scope,
    required this.settings,
    required this.onChanged,
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

  final TextColorScope scope;
  final TimetableSettings settings;
  final ValueChanged<TimetableSettings> onChanged;
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
    final showCourseCardRows = scope == TextColorScope.courseCard;
    final rows = <Widget>[
      // 课卡标题/详情与页面字色分属两页，同一字段只在一页可编辑。
      if (showCourseCardRows) ...[
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
      ] else ...[
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
    ];
    return HyperosControlCard(
      edgeToEdge: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
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
      body: MiuixColorPicker(
        color: pickerColor,
        onColorChanged: (Color c) {
          pickerColor = c;
        },
        hapticEffect: MiuixSliderHapticEffect.step,
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
