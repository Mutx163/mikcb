import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/third_party_disclaimer_card.dart';

void main() {
  group('thirdPartyDisclaimerBody', () {
    test('strips Chinese full-width colon prefix', () {
      const text = '特此声明：本应用由第三方开发者独立开发。';
      expect(thirdPartyDisclaimerBody(text), '本应用由第三方开发者独立开发。');
    });

    test('strips English colon prefix', () {
      const text = 'Disclaimer: This app is independently developed.';
      expect(
        thirdPartyDisclaimerBody(text),
        'This app is independently developed.',
      );
    });

    test('returns full text when no delimiter', () {
      const text = 'No delimiter here.';
      expect(thirdPartyDisclaimerBody(text), 'No delimiter here.');
    });
  });
}
