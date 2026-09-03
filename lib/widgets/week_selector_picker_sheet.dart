import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:university_timetable/ui/hyperos/hyperos.dart';

/// Bottom sheet for picking the visible timetable week using HyperOS styling.
Future<int?> showWeekSelectorPickerSheet(
  BuildContext context, {
  required List<int> availableWeeks,
  required int visibleWeek,
  required int? currentSemesterWeek,
}) {
  return showHomeHyperosSheet<int>(
    context: context,
    builder: (sheetContext) => _WeekSelectorPickerSheetBody(
      availableWeeks: availableWeeks,
      visibleWeek: visibleWeek,
      currentSemesterWeek: currentSemesterWeek,
    ),
  );
}

class _WeekSelectorPickerSheetBody extends StatelessWidget {
  const _WeekSelectorPickerSheetBody({
    required this.availableWeeks,
    required this.visibleWeek,
    required this.currentSemesterWeek,
  });

  final List<int> availableWeeks;
  final int visibleWeek;
  final int? currentSemesterWeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final maxListHeight = MediaQuery.sizeOf(context).height * 0.42;
    final showBackToCurrentWeek =
        currentSemesterWeek != null && visibleWeek != currentSemesterWeek;
    // 材质判定须与 HyperosSheetFrame._buildFrostedBackground 的液态玻璃分支
    // 一致（同一 appearance 字段 + 同一降级策略），保证格子样式跟实际面板
    // 材质同步切换。
    final appearance = FrostedAppearanceScope.of(context);
    final onLiquidGlassPanel =
        appearance.glassMode == FrostedGlassMode.liquidGlass &&
        appearance.liquidGlassSheetDialogEnabled &&
        !LiquidGlassDegradation.shouldDegrade(context);
    final weekCountText = l10n.availableWeeksCount(availableWeeks.length);

    return HyperosSheetFrame(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.selectWeekTitle,
            style: HyperosTypography.sheetTitle(context),
          ),
          const SizedBox(height: 8),
          if (onLiquidGlassPanel)
            // 通透玻璃上 99 灰说明字几乎不可见，跟标题同用主墨色。
            Padding(
              padding: const EdgeInsets.only(
                left: HyperosTokens.sectionLabelInset,
                right: HyperosTokens.sectionLabelInset,
                top: 8,
              ),
              child: Text(
                weekCountText,
                style: HyperosTypography.sectionDescription(context).copyWith(
                  color: HyperosColors.primaryText(context),
                ),
                softWrap: true,
              ),
            )
          else
            HyperosSectionDescription(text: weekCountText),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxListHeight),
            child: SingleChildScrollView(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                // 显式清零：ScrollView 会自动消费 MediaQuery.padding，而弹窗
                // 路由挂在根 Navigator 上能看到未消费的状态栏 inset，曾变成
                // 格子顶上 ~50dp 的透明内边距（「共N周」与格子间大空隙）。
                padding: EdgeInsets.zero,
                itemCount: availableWeeks.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                ),
                itemBuilder: (context, index) {
                  final week = availableWeeks[index];
                  return _WeekSelectorCell(
                    label: l10n.goToWeekLabel(week),
                    style: week == visibleWeek
                        ? _WeekCellStyle.selected
                        : week == currentSemesterWeek
                        ? _WeekCellStyle.current
                        : _WeekCellStyle.normal,
                    onLiquidGlass: onLiquidGlassPanel,
                    onPressed: () => Navigator.of(context).pop(week),
                  );
                },
              ),
            ),
          ),
          if (showBackToCurrentWeek) ...[
            const SizedBox(height: 14),
            HyperosFrostedSheetButton(
              label: l10n.backToCurrentWeekAction,
              bordered: true,
              expand: true,
              onPressed: () => Navigator.of(context).pop(currentSemesterWeek),
            ),
          ],
        ],
      ),
    );
  }
}

/// 格子状态：selected=当前正在查看的周（实底主题色，最强）；
/// current=学期实际所在周（主题色浅井，弱一档）；normal=其余。
enum _WeekCellStyle { normal, selected, current }

/// Compact week tile: single-line label, smaller than sheet title, fills the grid cell.
class _WeekSelectorCell extends StatelessWidget {
  const _WeekSelectorCell({
    required this.label,
    required this.style,
    required this.onLiquidGlass,
    required this.onPressed,
  });

  final String label;
  final _WeekCellStyle style;

  /// 面板为通透液态玻璃时切换玻璃专用墨色/描边（磨砂、实底维持 Miuix 平涂）。
  final bool onLiquidGlass;
  final VoidCallback onPressed;

  /// Below [HyperosTypography.sheetTitle] (~preference title), above dense footnote.
  static const double _labelFontSize = HyperosMiuixTypography.body2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const minHeight = 40.0;
    final cornerRadius = HyperosRadius.clampCornerRadius(
      HyperosMiuixButton.cornerRadius,
      minHeight,
    );
    final borderRadius = BorderRadius.circular(cornerRadius);

    // 平涂 #E8E8E8 在通透玻璃上与底同亮度、无边框感（与 HyperosButton
    // secondary 在磨砂玻璃上修过的同类失效）；改半透明白井 + 细描边，
    // 墨色用 onSurface 纯黑保证任意壁纸折射下可读。
    final isSelected = style == _WeekCellStyle.selected;
    final isCurrent = style == _WeekCellStyle.current;
    final backgroundColor = isSelected
        ? HyperosColors.primary(context)
        : isCurrent
        ? HyperosColors.primary(context).withValues(alpha: 0.12)
        : onLiquidGlass
        ? Colors.white.withValues(alpha: isDark ? 0.14 : 0.55)
        : (isDark
              ? Colors.white.withValues(alpha: 0.14)
              : const Color(0xFFE8E8E8));
    final foregroundColor = isSelected
        ? HyperosColors.onPrimary(context)
        : isCurrent
        ? HyperosColors.primary(context)
        : onLiquidGlass
        ? HyperosColors.onSurface(context)
        : HyperosColors.onSecondaryVariant(context);
    final edgeColor = isSelected
        ? null
        : isCurrent
        // 当前周浅色井在通透玻璃上会融底，加主题色细描边保持轮廓。
        ? HyperosColors.primary(context).withValues(alpha: isDark ? 0.55 : 0.38)
        : onLiquidGlass
        ? (isDark
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.12))
        : null;

    final labelWidget = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: _labelFontSize,
          color: foregroundColor,
          fontWeight: FontWeight.w400,
          height: 1.1,
        ),
      ),
    );

    return Material(
      color: backgroundColor,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: borderRadius,
        child: Ink(
          decoration: edgeColor == null
              ? null
              : BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(color: edgeColor),
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Center(child: labelWidget),
          ),
        ),
      ),
    );
  }
}
