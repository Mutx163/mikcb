import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/hex_color.dart';

void main() {
  test('parseHexColorOrFallback parses valid hex colors', () {
    expect(
      parseHexColorOrFallback('#2563EB', fallback: Colors.black),
      const Color(0xFF2563EB),
    );
    expect(
      parseHexColorOrFallback('2196F3', fallback: Colors.black),
      const Color(0xFF2196F3),
    );
  });

  test('parseHexColorOrFallback falls back for invalid values', () {
    expect(
      parseHexColorOrFallback('ZZZZZZ', fallback: Colors.black),
      Colors.black,
    );
    expect(parseHexColorOrFallback('', fallback: Colors.red), Colors.red);
    expect(
      parseHexColorOrFallback('#12345', fallback: Colors.blue),
      Colors.blue,
    );
  });
}
