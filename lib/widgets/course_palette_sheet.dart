import 'package:flutter/material.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

import '../utils/course_color_palette.dart';
import '../utils/hex_color.dart';
import 'course_color_picker_sheet.dart';

/// 课程颜色配置弹窗：实时预览卡 + 快捷色 + 全量色板 + 自定义（HSV）入口。
///
/// 点色块先更新预览（弹窗保持打开），底部「使用这个颜色」确认后才带回
/// 结果；自定义入口串联 HSV 取色 sheet，其结果同样先进入预览待确认。
Future<String?> showCoursePaletteSheet(
  BuildContext context, {
  required String initialColorHex,
  String? previewText,
  String? title,
}) {
  return showHyperosSheet<String>(
    context: context,
    enableDrag: false,
    builder: (sheetContext) => _CoursePaletteSheetBody(
      initialColorHex: initialColorHex.toUpperCase(),
      previewText: previewText,
      title: title,
    ),
  );
}

class _CoursePaletteSheetBody extends StatefulWidget {
  const _CoursePaletteSheetBody({
    required this.initialColorHex,
    this.previewText,
    this.title,
  });

  final String initialColorHex;
  final String? previewText;
  final String? title;

  @override
  State<_CoursePaletteSheetBody> createState() =>
      _CoursePaletteSheetBodyState();
}

class _CoursePaletteSheetBodyState extends State<_CoursePaletteSheetBody> {
  late String _selectedHex;

  @override
  void initState() {
    super.initState();
    _selectedHex = widget.initialColorHex;
  }

  Future<void> _openCustomPicker() async {
    final custom = await showCourseColorPickerSheet(
      context,
      initialColorHex: _selectedHex,
    );
    if (custom == null || !mounted) {
      return;
    }
    setState(() {
      _selectedHex = custom.toUpperCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;

    return HyperosSheet(
      title: widget.title ?? l10n.colorPaletteTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ColorPreviewCard(
            colorHex: _selectedHex,
            label: widget.previewText?.trim().isNotEmpty == true
                ? widget.previewText!.trim()
                : l10n.weekdayMon,
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(text: l10n.courseColorQuickSection),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final colorHex in kCourseColorQuickPickHexes)
                        _PaletteChip(
                          colorHex: colorHex,
                          isSelected: _selectedHex == colorHex,
                          selectionBorder: theme.colors.foreground,
                          borderColor: theme.colors.border,
                          onTap: () =>
                              setState(() => _selectedHex = colorHex),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionLabel(text: l10n.colorGroupAll),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final colorHex in kPresetCourseColorHexes)
                        _PaletteChip(
                          colorHex: colorHex,
                          isSelected: _selectedHex == colorHex,
                          selectionBorder: theme.colors.foreground,
                          borderColor: theme.colors.border,
                          onTap: () =>
                              setState(() => _selectedHex = colorHex),
                        ),
                      _PaletteChip(
                        colorHex: kPresetCourseColorHexes
                                .contains(_selectedHex)
                            ? null
                            : _selectedHex,
                        isSelected: !kPresetCourseColorHexes
                            .contains(_selectedHex),
                        selectionBorder: theme.colors.foreground,
                        borderColor: theme.colors.border,
                        onTap: _openCustomPicker,
                        icon: Icon(
                          Icons.palette_outlined,
                          size: 18,
                          color: theme.colors.mutedForeground,
                        ),
                        tooltip: l10n.customPaletteAction,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                      Navigator.of(context).pop(_selectedHex),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 顶部实时预览：所选颜色铺底 + 自动最优墨色（与实心卡隐身线回落同款）。
class _ColorPreviewCard extends StatelessWidget {
  const _ColorPreviewCard({required this.colorHex, required this.label});

  final String colorHex;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color =
        tryParseHexColor(colorHex) ?? HyperosColors.secondaryVariant(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colors.border),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: HyperosTypography.listTitle(context).copyWith(
          color: bestContrastCourseCardInk(color),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.typography.body.xs2
            .copyWith(color: theme.colors.mutedForeground),
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
    // 占位井用浅灰 secondaryVariant；colors.secondary 是兼容垫片上的
    // 深色 M3 强调色，浅色弹窗里会像一颗黑块。
    final parsed = tryParseHexColor(colorHex) ??
        HyperosColors.secondaryVariant(context);
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
