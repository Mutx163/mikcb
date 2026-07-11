import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lan edit web assets are bundled', () async {
    final index = await rootBundle.loadString('assets/lan_edit/index.html');
    final script = await rootBundle.loadString('assets/lan_edit/app.js');
    final i18n = await rootBundle.loadString('assets/lan_edit/i18n.js');
    final style = await rootBundle.loadString(
      'assets/lan_edit/lan-timetable.css',
    );

    expect(index, contains('轻屿课表'));
    expect(index, contains('/assets/lan-timetable.css'));
    expect(index, isNot(contains('tabler.min.css')));
    expect(index, isNot(contains('tabler.min.js')));
    expect(index, contains('/assets/i18n.js'));
    expect(index, contains('/assets/logo.png'));
    expect(index, contains('login-page'));
    expect(index, contains('app-shell'));
    expect(index, contains('dialog-overlay'));
    expect(index, contains('id="profile-switcher"'));
    expect(index, contains('id="loading-text"'));
    expect(index, contains('id="close-modal-x"'));
    expect(script, contains('/api/v1/auth/verify'));
    expect(script, contains('/api/v1/profiles/switch'));
    expect(script, contains("params.get('pin')"));
    expect(script, contains('verifyPinAndEnter'));
    expect(script, contains('stripPinFromUrl'));
    expect(script, contains('autoPinLogin'));
    expect(script, contains('showCourseModal'));
    expect(script, contains('fillProfileSwitcher'));
    expect(script, isNot(contains('bootstrap.Modal')));
    expect(i18n, contains('autoPinLogin'));
    expect(style, contains('#timetable-grid'));
    expect(style, contains('.login-logo'));
    expect(style, contains('--primary:'));
    expect(style, contains('.dialog-overlay'));
    expect(style, contains('.app-shell'));
  });
}
