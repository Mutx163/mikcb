import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';

/// HyperOS-style switch — delegates to [MiuixSwitch].
class HyperosSwitch extends StatelessWidget {
  const HyperosSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MiuixSwitch(
      value: value,
      onChanged: onChanged,
      enabled: onChanged != null,
    );
  }
}
