import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hyperos_miuix_spec.dart';

/// HyperOS / Miuix-style switch (49×28 track, 20 thumb).
///
/// Dimensions and colors from [HyperosMiuixSpec] / Miuix `Switch.kt`.
class HyperosSwitch extends StatelessWidget {
  const HyperosSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _animationDuration = Duration(milliseconds: 200);
  static const _animationCurve = Curves.easeOutCubic;

  static double get _thumbTop =>
      (HyperosMiuixSwitch.height - HyperosMiuixSwitch.thumbSize) / 2;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = value
        ? (enabled
              ? (isDark
                    ? HyperosMiuixDarkColors.primary
                    : HyperosMiuixLightColors.primary)
              : (isDark
                    ? HyperosMiuixDarkColors.disabledPrimary
                    : HyperosMiuixLightColors.disabledPrimary))
        : (enabled
              ? (isDark
                    ? HyperosMiuixDarkColors.secondary
                    : HyperosMiuixLightColors.secondary)
              : (isDark
                    ? HyperosMiuixDarkColors.disabledSecondary
                    : HyperosMiuixLightColors.disabledSecondary));
    final thumbColor = value
        ? (enabled
              ? (isDark
                    ? HyperosMiuixDarkColors.onPrimary
                    : HyperosMiuixLightColors.onPrimary)
              : (isDark
                    ? HyperosMiuixDarkColors.disabledOnPrimary
                    : HyperosMiuixLightColors.disabledOnPrimary))
        : (enabled
              ? (isDark
                    ? HyperosMiuixDarkColors.onSecondary
                    : HyperosMiuixLightColors.onSecondary)
              : (isDark
                    ? HyperosMiuixDarkColors.disabledOnSecondary
                    : HyperosMiuixLightColors.disabledOnSecondary));
    final thumbLeft = value
        ? HyperosMiuixSwitch.thumbOnInset
        : HyperosMiuixSwitch.thumbOffInset;

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: value,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                onChanged!(!value);
              }
            : null,
        child: AnimatedContainer(
          duration: _animationDuration,
          curve: _animationCurve,
          width: HyperosMiuixSwitch.width,
          height: HyperosMiuixSwitch.height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(HyperosMiuixSwitch.height / 2),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: _animationDuration,
                curve: _animationCurve,
                left: thumbLeft,
                top: _thumbTop,
                width: HyperosMiuixSwitch.thumbSize,
                height: HyperosMiuixSwitch.thumbSize,
                child: AnimatedContainer(
                  duration: _animationDuration,
                  curve: _animationCurve,
                  decoration: BoxDecoration(
                    color: thumbColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
