import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';
import 'hyperos_widgets.dart';

/// HyperOS-style checkbox — delegates to [MiuixCheckbox].
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
    return MiuixCheckbox(
      value: value,
      onChanged: onChanged != null ? (v) => onChanged!(v ?? false) : null,
      enabled: onChanged != null,
    );
  }
}

/// HyperOS-style radio button — delegates to [MiuixRadioButton].
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
    return MiuixRadioButton(
      selected: _selected,
      onChanged: onChanged != null ? (_) => onChanged!(value) : null,
      enabled: onChanged != null,
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
    onChanged?.call(!value);
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: HyperosTokens.titleCaptionGap),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: HyperosMiuixBasicComponent.startEndSpacer),
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null) ...[
                    const SizedBox(height: HyperosTokens.titleCaptionGap),
                    Text(subtitle!, style: subtitleStyle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: HyperosMiuixBasicComponent.startEndSpacer),
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
