import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lan edit web assets are bundled', () async {
    final index = await rootBundle.loadString('assets/lan_edit/index.html');
    final script = await rootBundle.loadString('assets/lan_edit/app.js');
    final style = await rootBundle.loadString(
      'assets/lan_edit/lan-timetable.css',
    );
    final tabler = await rootBundle.loadString(
      'assets/lan_edit/vendor/tabler.min.css',
    );

    expect(index, contains('轻屿课表'));
    expect(index, contains('tabler.min.css'));
    expect(script, contains('/api/v1/auth/verify'));
    expect(script, contains("params.get('pin')"));
    expect(script, contains('verifyPinAndEnter'));
    expect(script, contains('stripPinFromUrl'));
    expect(style, contains('#timetable-grid'));
    expect(tabler.length, greaterThan(10000));
  });
}
