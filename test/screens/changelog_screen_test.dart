import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/changelog_screen.dart';

void main() {
  group('compareReleaseVersionsDesc', () {
    test('sorts newest version first', () {
      final versions = [
        'v2.0.5.6',
        'v2.1.1',
        'v2.1.0',
        'v2.1.1.4',
        'v2.1.1.1',
        'v1.3',
        'v1.3.2',
      ];
      versions.sort(compareReleaseVersionsDesc);
      expect(versions, [
        'v2.1.1.4',
        'v2.1.1.1',
        'v2.1.1',
        'v2.1.0',
        'v2.0.5.6',
        'v1.3.2',
        'v1.3',
      ]);
    });

    test('handles patch-level and suffix versions', () {
      final versions = ['v1.1.5-a', 'v1.1.6', 'v1.1.10', 'v1.2.0.30'];
      versions.sort(compareReleaseVersionsDesc);
      expect(versions, ['v1.2.0.30', 'v1.1.10', 'v1.1.6', 'v1.1.5-a']);
    });

    test('treats missing segments as zero', () {
      final versions = ['v1.2', 'v1.2.0.1'];
      versions.sort(compareReleaseVersionsDesc);
      expect(versions, ['v1.2.0.1', 'v1.2']);
    });
  });

  group('parseReleaseVersion', () {
    test('parses numeric segments', () {
      expect(parseReleaseVersion('v2.1.1.4'), [2, 1, 1, 4]);
      expect(parseReleaseVersion('v1.3'), [1, 3]);
    });

    test('falls back for non-numeric version', () {
      expect(parseReleaseVersion('abc'), [0]);
    });
  });
}
