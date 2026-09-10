import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/header_blur_style.dart';
import 'package:university_timetable/models/timetable_settings.dart';
import 'package:university_timetable/ui/hyperos/frosted/frosted_appearance.dart';

void main() {
  group('顶栏模糊风格：模型层', () {
    test('默认值为渐进模糊档', () {
      expect(TimetableSettings.defaults().headerBlurStyle,
          HeaderBlurStyle.inspire);
      expect(FrostedAppearance.defaults.headerBlurStyle,
          HeaderBlurStyle.inspire);
    });

    test('缺键 / 未知值回退渐进模糊', () {
      expect(HeaderBlurStyleX.fromValue(null), HeaderBlurStyle.inspire);
      expect(HeaderBlurStyleX.fromValue('nope'), HeaderBlurStyle.inspire);
      expect(HeaderBlurStyleX.fromValue('gaussian'), HeaderBlurStyle.gaussian);
      expect(HeaderBlurStyleX.fromValue('inspire'), HeaderBlurStyle.inspire);
      final legacy = TimetableSettings.fromJson(const {'sections': []});
      expect(legacy.headerBlurStyle, HeaderBlurStyle.inspire);
    });

    test('JSON 往返保留档位', () {
      final custom = TimetableSettings.defaults().copyWith(
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      final restored = TimetableSettings.fromJson(custom.toJson());
      expect(restored.headerBlurStyle, HeaderBlurStyle.gaussian);
    });

    test('frostedAppearance 映射顶栏模糊风格', () {
      final settings = TimetableSettings.defaults().copyWith(
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(
        settings.frostedAppearance.headerBlurStyle,
        HeaderBlurStyle.gaussian,
      );
    });

    test('FrostedAppearance 相等性包含顶栏模糊风格', () {
      final a = FrostedAppearance.defaults;
      final b = FrostedAppearance(
        sheetBlurSigma: a.sheetBlurSigma,
        sheetTintAlpha: a.sheetTintAlpha,
        sheetBarrierAlpha: a.sheetBarrierAlpha,
        headerBlurStyle: HeaderBlurStyle.gaussian,
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });
  });
}
