import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';
import 'hyperos_tokens.dart';

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
    this.fontSize = HyperosMiuixTextField.labelFontSizeNormal,
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
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    final onSurface = HyperosColors.onSurface(context);
    final summary = HyperosColors.onSurfaceVariantSummary(context);
    final fill = HyperosColors.secondaryVariant(context);
    final disabled = HyperosColors.disabledOnSurface(context);
    final outline = HyperosColors.outline(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: TextStyle(
              fontSize: fontSize,
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
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              color: enabled ? onSurface : disabled,
            ),
            decoration: InputDecoration(
              hintText: hint,
              // Fully specify size/weight so hint does not inherit a larger or
              // bolder theme body style (mixed Chinese glyphs otherwise look uneven).
              hintStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
                color: summary,
                height: 1.25,
              ),
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
            style: HyperosTypography.sectionDescription(
              context,
            ).copyWith(color: summary),
          ),
        ],
      ],
    );
  }
}

/// Tappable value field with the same chrome as [HyperosTextField].
///
/// Use on frosted sheets / forms instead of a bare [HyperosListTile] or white
/// [HyperosListGroup] (those read as opaque square cards and break glass UI).
class HyperosPickerField extends StatelessWidget {
  const HyperosPickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.isPlaceholder = false,
    this.fontSize = HyperosMiuixTextField.labelFontSizeNormal,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool enabled;
  final bool isPlaceholder;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final primary = HyperosColors.primary(context);
    final onSurface = HyperosColors.onSurface(context);
    final summary = HyperosColors.onSurfaceVariantSummary(context);
    final fill = HyperosColors.secondaryVariant(context);
    final disabled = HyperosColors.disabledOnSurface(context);
    final outline = HyperosColors.outline(context);
    final canTap = enabled && onTap != null;
    final radius = BorderRadius.circular(HyperosMiuixTextField.cornerRadius);
    final valueColor = !canTap
        ? disabled
        : (isPlaceholder || value.isEmpty ? summary : onSurface);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            color: canTap ? onSurface : disabled,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: canTap ? fill : fill.withValues(alpha: 0.5),
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: canTap ? onTap : null,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: outline, width: 1),
              ),
              child: Padding(
                padding: HyperosMiuixTextField.insideMargin,
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: canTap ? primary : disabled),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        value.isEmpty ? '—' : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: fontSize, color: valueColor),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: canTap ? summary : disabled,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
                const SizedBox(height: HyperosTokens.titleCaptionGap),
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
