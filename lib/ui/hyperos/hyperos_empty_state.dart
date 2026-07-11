import 'package:flutter/material.dart';

import 'hyperos_miuix_spec.dart';
import 'hyperos_theme.dart';

/// HyperOS list empty state (icon + title + optional action).
class HyperosEmptyState extends StatelessWidget {
  const HyperosEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final onSurface = HyperosColors.onSurface(context);
    final summary = HyperosColors.onSurfaceVariantSummary(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: summary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: HyperosTypography.title(context).copyWith(color: onSurface),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: HyperosMiuixTypography.body2,
                color: summary,
              ),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

/// Full-width divider matching Miuix [DividerDefaults.thickness].
class HyperosDivider extends StatelessWidget {
  const HyperosDivider({super.key, this.indent, this.endIndent});

  final double? indent;
  final double? endIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: HyperosMiuixDivider.thickness,
      thickness: HyperosMiuixDivider.thickness,
      indent: indent,
      endIndent: endIndent,
      color: HyperosColors.dividerLine(context),
    );
  }
}

/// HyperOS / Miuix search field for settings lists.
class HyperosSearchBar extends StatelessWidget {
  const HyperosSearchBar({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final activeController = controller;
    if (activeController == null || onClear == null) {
      return _buildField(context, showClear: false);
    }
    // Rebuild on text changes so the clear button appears/disappears without
    // relying on the parent widget rebuilding.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: activeController,
      builder: (context, value, _) {
        return _buildField(context, showClear: value.text.isNotEmpty);
      },
    );
  }

  Widget _buildField(BuildContext context, {required bool showClear}) {
    final fill = HyperosColors.secondaryVariant(context);
    final onSurface = HyperosColors.onSurface(context);
    final summary = HyperosColors.onSurfaceVariantSummary(context);
    final actions = HyperosColors.onSurfaceVariantActions(context);

    return SizedBox(
      height: HyperosMiuixSearchBar.inputFieldMinHeight,
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: TextStyle(
          fontSize: HyperosMiuixSearchBar.inputFieldFontSize,
          color: onSurface,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: summary),
          filled: true,
          fillColor: fill,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: HyperosMiuixSearchBar.leadingIconStartPadding,
              right: HyperosMiuixSearchBar.leadingIconEndPadding,
            ),
            child: Icon(Icons.search_rounded, color: actions, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          suffixIcon: showClear
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: actions, size: 20),
                  onPressed: onClear,
                  padding: const EdgeInsets.only(
                    right: HyperosMiuixSearchBar.trailingIconEndPadding,
                  ),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: HyperosMiuixSearchBar.insideMarginHorizontal,
            vertical: HyperosMiuixSearchBar.insideMarginVertical,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              HyperosMiuixSearchBar.inputFieldMinHeight / 2,
            ),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
