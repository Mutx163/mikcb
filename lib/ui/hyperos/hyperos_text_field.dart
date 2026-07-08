import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// HyperOS / Miuix-styled text field (16dp corner, 2dp focus border).
class HyperosTextField extends StatelessWidget {
  const HyperosTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.helper,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? helper;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? minLines;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? HyperosMiuixDarkColors.primary
        : HyperosMiuixLightColors.primary;
    final onSurface = isDark
        ? HyperosMiuixDarkColors.onSurface
        : HyperosMiuixLightColors.onSurface;
    final summary = isDark
        ? HyperosMiuixDarkColors.onSurfaceVariantSummary
        : HyperosMiuixLightColors.onSurfaceVariantSummary;
    final fill = isDark
        ? HyperosMiuixDarkColors.secondaryVariant
        : HyperosMiuixLightColors.secondaryVariant;
    final disabled = isDark
        ? HyperosMiuixDarkColors.disabledOnSurface
        : HyperosMiuixLightColors.disabledOnSurface;
    final outline = isDark
        ? HyperosMiuixDarkColors.outline
        : HyperosMiuixLightColors.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: HyperosMiuixTextField.labelFontSizeNormal,
              color: enabled ? onSurface : disabled,
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            obscureText: obscureText,
            maxLines: maxLines,
            minLines: minLines,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            scrollPadding: EdgeInsets.zero,
            style: TextStyle(
              fontSize: HyperosMiuixTextField.labelFontSizeNormal,
              color: enabled ? onSurface : disabled,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: summary),
              filled: true,
              fillColor: enabled ? fill : fill.withValues(alpha: 0.5),
              contentPadding: HyperosMiuixTextField.insideMargin,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  HyperosMiuixTextField.cornerRadius,
                ),
                borderSide: BorderSide(color: outline, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  HyperosMiuixTextField.cornerRadius,
                ),
                borderSide: BorderSide(color: outline, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  HyperosMiuixTextField.cornerRadius,
                ),
                borderSide: BorderSide(
                  color: primary,
                  width: HyperosMiuixTextField.borderWidth,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  HyperosMiuixTextField.cornerRadius,
                ),
                borderSide: BorderSide(color: outline.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(
            helper!,
            style: TextStyle(
              fontSize: HyperosMiuixTypography.footnote1,
              color: summary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Text field inside a white HyperOS control card.
class HyperosTextFieldTile extends StatelessWidget {
  const HyperosTextFieldTile({
    super.key,
    this.cardTitle,
    this.cardSubtitle,
    required this.field,
  });

  final String? cardTitle;
  final String? cardSubtitle;
  final HyperosTextField field;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HyperosColors.card(context),
      shape: HyperosTheme.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cardTitle != null) ...[
              Text(cardTitle!, style: HyperosTypography.title(context)),
              if (cardSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  cardSubtitle!,
                  style: HyperosTypography.sectionDescription(context),
                ),
              ],
              const SizedBox(height: 12),
            ],
            field,
          ],
        ),
      ),
    );
  }
}
