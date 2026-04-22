import 'package:flutter/material.dart';

Color? tryParseHexColor(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final hex = normalized.startsWith('#') ? normalized.substring(1) : normalized;
  if (hex.length != 6) {
    return null;
  }
  final colorValue = int.tryParse('FF$hex', radix: 16);
  if (colorValue == null) {
    return null;
  }
  return Color(colorValue);
}

Color parseHexColorOrFallback(String? value, {required Color fallback}) {
  return tryParseHexColor(value) ?? fallback;
}
