import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/logging/diagnostics_log_parser.dart';

void main() {
  const sampleLog = '''
Diagnostics Export
exportedAt=1000
----
time=1000
level=error
source=app
category=Sync
message=upload failed
extras=
  code=500

time=2000
level=warn
source=native
category=live_update
message=delayed

time=3000
category=InfoCat
message=plain info without level
''';

  group('parseDiagnosticsLog', () {
    test('returns empty snapshot for blank input', () {
      final parsed = parseDiagnosticsLog('   ', fallbackTitle: 'Fallback');
      expect(parsed.title, 'Fallback');
      expect(parsed.entries, isEmpty);
      expect(parsed.fullText, isEmpty);
    });

    test('parses header body and entries', () {
      final parsed = parseDiagnosticsLog(sampleLog);

      expect(parsed.title, 'Diagnostics Export');
      expect(parsed.headerEntries['exportedAt'], '1000');
      expect(parsed.entries, hasLength(3));

      final first = parsed.entries[0];
      expect(first.level, DiagnosticsLogLevel.error);
      expect(first.isLevelInferred, isFalse);
      expect(first.category, 'Sync');
      expect(first.message, 'upload failed');
      expect(first.sourceKey, 'app');
      expect(first.isNativeSource, isFalse);
      expect(first.timeMillis, 1000);
      expect(first.formattedTime, isNotNull);

      final second = parsed.entries[1];
      expect(second.level, DiagnosticsLogLevel.warn);
      expect(second.sourceKey, 'native');
      expect(second.isNativeSource, isTrue);

      final third = parsed.entries[2];
      expect(third.level, DiagnosticsLogLevel.info);
      expect(third.isLevelInferred, isTrue);
    });

    test(
      'infers native source from live_update category without source field',
      () {
        final parsed = parseDiagnosticsLog('''
title
----
time=1
category=live_update_push
message=hello
''');
        expect(parsed.entries.single.sourceKey, 'native');
      },
    );

    test('infers error level from message keywords', () {
      final parsed = parseDiagnosticsLog('''
title
----
time=1
category=Demo
message=something failed badly
''');
      expect(parsed.entries.single.level, DiagnosticsLogLevel.error);
      expect(parsed.entries.single.isLevelInferred, isTrue);
    });
  });

  group('diagnostics helpers', () {
    test('extractDiagnosticsLogBody strips header', () {
      final body = extractDiagnosticsLogBody(sampleLog);
      expect(body, isNot(contains('Diagnostics Export')));
      expect(body, contains('upload failed'));
    });

    test('filter sort and count entries', () {
      final parsed = parseDiagnosticsLog(sampleLog);
      final errors = filterDiagnosticsEntries(
        parsed.entries,
        DiagnosticsLogLevel.error,
      );
      expect(errors, hasLength(1));
      expect(errors.single.level, DiagnosticsLogLevel.error);

      final descending = sortDiagnosticsEntries(
        parsed.entries,
        ascending: false,
      );
      expect(descending.first.timeMillis, 3000);
      expect(descending.last.timeMillis, 1000);

      final counts = countDiagnosticsLevels(parsed.entries);
      expect(counts[DiagnosticsLogLevel.all], 3);
      expect(counts[DiagnosticsLogLevel.error], 1);
      expect(counts[DiagnosticsLogLevel.warn], 1);
      expect(counts[DiagnosticsLogLevel.info], 1);
    });

    test('buildFilteredDiagnosticsRawText keeps header', () {
      final parsed = parseDiagnosticsLog(sampleLog);
      final filtered = filterDiagnosticsEntries(
        parsed.entries,
        DiagnosticsLogLevel.error,
      );
      final raw = buildFilteredDiagnosticsRawText(parsed, filtered);
      expect(raw, contains('Diagnostics Export'));
      expect(raw, contains('----'));
      expect(raw, contains('upload failed'));
      expect(raw, isNot(contains('plain info without level')));
    });

    test('appendDiagnosticsLogBody merges new entries', () {
      final current = parseDiagnosticsLog(sampleLog);
      final appended = '''
time=4000
level=debug
category=Demo
message=extra
''';
      final merged = appendDiagnosticsLogBody(
        current,
        appended,
        mergedFullText: '${current.fullText}\n\n$appended',
      );
      expect(merged.entries, hasLength(4));
      expect(merged.entries.last.level, DiagnosticsLogLevel.debug);
      expect(merged.entries.last.message, 'extra');
    });

    test('formatDiagnosticsMillis returns null for invalid input', () {
      expect(formatDiagnosticsMillis(null), isNull);
      expect(formatDiagnosticsMillis('abc'), isNull);
      expect(formatDiagnosticsMillis('1000'), isNotNull);
    });

    test('snapshot copyWith replaces selected fields', () {
      final parsed = parseDiagnosticsLog(sampleLog);
      final copied = parsed.copyWith(title: 'New title', entries: const []);
      expect(copied.title, 'New title');
      expect(copied.entries, isEmpty);
      expect(copied.fullText, parsed.fullText);
    });
  });
}
