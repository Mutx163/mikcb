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
    expect(script, contains('/api/v1/import/preview'));
    expect(script, contains('/api/v1/import/apply'));
    expect(index, contains('id="transfer-preview-card"'));
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

  // The page used to pull Tabler icons from cdn.jsdelivr.net at a floating
  // `@latest` tag with no integrity check, while a complete local subset sat
  // unused in this same directory. The main stylesheet defines no icon rules, so
  // any offline phone or guest device rendered the page with no icons at all.
  test('lan edit icons are served locally with no third-party CDN', () async {
    final index = await rootBundle.loadString('assets/lan_edit/index.html');
    final icons = await rootBundle.loadString(
      'assets/lan_edit/tabler-icons-subset.css',
    );
    final script = await rootBundle.loadString('assets/lan_edit/app.js');
    final i18n = await rootBundle.loadString('assets/lan_edit/i18n.js');

    // No remote stylesheet, script, or font may come back.
    for (final source in {index: 'index.html', script: 'app.js', i18n: 'i18n.js'}.entries) {
      expect(
        source.value,
        isNot(contains('cdn.jsdelivr.net')),
        reason: '${source.key} must not load from a CDN',
      );
      expect(
        source.value,
        isNot(contains('cdnjs.cloudflare.com')),
        reason: '${source.key} must not load from a CDN',
      );
    }
    expect(index, contains('/assets/tabler-icons-subset.css'));
    // Icons are inline data: URIs, so no @font-face and no network font.
    expect(icons, isNot(contains('@font-face')));
    expect(icons, contains('--ti-svg: url("data:image/svg+xml'));
    // The mask rule is what actually paints them; without it every icon is blank.
    expect(icons, matches(RegExp(r'\.ti\s*\{[^}]*mask\s*:')));

    // Every icon the page references must exist locally. This caught ti-eye and
    // ti-lock, which the subset shipped without while index.html used them in
    // four places.
    final defined = RegExp(r'^\.(ti-[a-z0-9-]+)\s*\{', multiLine: true)
        .allMatches(icons)
        .map((m) => m.group(1)!)
        .toSet();
    final used = RegExp(r'\bti-[a-z0-9-]+')
        .allMatches('$index\n$script')
        .map((m) => m.group(0)!)
        .toSet();
    expect(used, isNotEmpty);
    final missing = used.where((name) => !defined.contains(name)).toList()..sort();
    expect(missing, isEmpty, reason: 'icons used but not bundled: $missing');
  });
}
