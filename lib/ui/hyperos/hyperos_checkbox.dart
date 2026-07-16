import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

/// HyperOS / Miuix checkbox (26dp, primary fill when checked).
class HyperosCheckbox extends StatelessWidget {
  const HyperosCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final primary = HyperosColors.primary(context);
    final border = HyperosColors.outline(context);
    final disabled = HyperosColors.disabledOnSurface(context);

    final size = HyperosMiuixCheckbox.size;
    final radius = size * 0.22;

    return Semantics(
      checked: value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(!value);
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: HyperosMiuixCheckbox.colorAnimMs,
          ),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: value ? (enabled ? primary : disabled) : Colors.transparent,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: value
                  ? (enabled ? primary : disabled)
                  : (enabled ? border : disabled),
              width: value ? 0 : 1.5,
            ),
          ),
          child: value
              ? Icon(
                  Icons.check_rounded,
                  size: size * 0.72,
                  color: HyperosColors.onPrimary(context),
                )
              : null,
        ),
      ),
    );
  }
}

/// HyperOS / Miuix radio button (26dp outer ring).
class HyperosRadio<T> extends StatelessWidget {
  const HyperosRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  bool get _selected => value == groupValue;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final primary = HyperosColors.primary(context);
    final border = HyperosColors.outline(context);
    final disabled = HyperosColors.disabledOnSurface(context);

    const size = HyperosMiuixCheckbox.size;
    const inner = 10.0;

    return Semantics(
      checked: _selected,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onChanged!(value);
              }
            : null,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: HyperosMiuixCheckbox.colorAnimMs,
              ),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selected
                      ? (enabled ? primary : disabled)
                      : (enabled ? border : disabled),
                  width: 2,
                ),
              ),
              child: _selected
                  ? Center(
                      child: Container(
                        width: inner,
                        height: inner,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled ? primary : disabled,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkbox preference row — title (+ optional subtitle) + trailing [HyperosCheckbox].
class HyperosCheckboxTile extends StatelessWidget {
  const HyperosCheckboxTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  void _toggle() {
    if (onChanged != null) onChanged!(!value);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final enabled = onChanged != null;
    final primaryText = HyperosColors.primaryText(context);
    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: enabled ? primaryText : primaryText.withValues(alpha: 0.45),
    );
    final secondaryText = HyperosColors.secondaryText(context);
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled ? secondaryText : secondaryText.withValues(alpha: 0.45),
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPaddingUniform,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            SizedBox(width: HyperosMiuixBasicComponent.startEndSpacer),
            HyperosCheckbox(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: enabled ? _toggle : null,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}

/// Radio preference row — title (+ optional subtitle) + trailing [HyperosRadio].
class HyperosRadioTile<T> extends StatelessWidget {
  const HyperosRadioTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String? subtitle;
  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final cardColor = HyperosColors.card(context);
    final highlightColor = HyperosColors.rowHighlight(context);
    final enabled = onChanged != null;
    final primaryText = HyperosColors.primaryText(context);
    final titleStyle = HyperosTypography.listTitle(context).copyWith(
      color: enabled ? primaryText : primaryText.withValues(alpha: 0.45),
    );
    final secondaryText = HyperosColors.secondaryText(context);
    final subtitleStyle = HyperosTypography.listDetail(context).copyWith(
      color: enabled ? secondaryText : secondaryText.withValues(alpha: 0.45),
    );

    final row = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: HyperosTokens.listRowMinHeight,
      ),
      child: Padding(
        padding: HyperosTokens.rowPaddingUniform,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            SizedBox(width: HyperosMiuixBasicComponent.startEndSpacer),
            HyperosRadio<T>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );

    return HyperosPressableRow(
      onTap: enabled ? () => onChanged!(value) : null,
      backgroundColor: cardColor,
      highlightColor: highlightColor,
      child: row,
    );
  }
}
