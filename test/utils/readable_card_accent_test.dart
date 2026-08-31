import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/home_page_background.dart';

/// WCAG 相对对比度。
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 绿色相保留：绿通道仍是绝对主导。
bool _greenDominant(Color c) => c.g > c.r && c.g > c.b;

void main() {
  // 情侣课表「共同空闲」强调色（CoupleTimetableLogic.freeSlotColorHex）。
  const freeGreen = Color(0xFF4CAF50);

  group('readableAccentOnCardInk', () {
    test('浅色卡面：中明度绿压暗到可读，且保持绿色相', () {
      final readable = readableAccentOnCardInk(freeGreen, Colors.black);

      expect(readable.computeLuminance(), lessThanOrEqualTo(0.12));
      expect(_contrastRatio(readable, Colors.white), greaterThanOrEqualTo(4.5));
      // 修复前：原色对白底只有 ~2.8:1，细字号不可读。
      expect(
        _contrastRatio(readable, Colors.white),
        greaterThan(_contrastRatio(freeGreen, Colors.white)),
      );
      // 只调明度不换色相：绿通道仍是绝对主导。
      expect(_greenDominant(readable), isTrue);
    });

    test('深色卡面：同一绿色提亮到可读', () {
      final readable = readableAccentOnCardInk(freeGreen, Colors.white);

      expect(readable.computeLuminance(), greaterThanOrEqualTo(0.50));
      expect(
        _contrastRatio(readable, const Color(0xFF141414)),
        greaterThanOrEqualTo(3.0),
      );
      expect(_greenDominant(readable), isTrue);
    });

    test('本就可读的强调色原样返回，不再加深或减淡', () {
      const deepGreen = Color(0xFF1B5E20);
      const paleGreen = Color(0xFFA5D6A7);

      expect(readableAccentOnCardInk(deepGreen, Colors.black), deepGreen);
      expect(readableAccentOnCardInk(paleGreen, Colors.white), paleGreen);
    });
  });
}
