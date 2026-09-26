import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/import_file_reader.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('import_file_reader_test');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  File write(String name, int bytes) {
    final file = File('${dir.path}${Platform.pathSeparator}$name')
      ..writeAsBytesSync(List<int>.filled(bytes, 0x41));
    return file;
  }

  group('readImportFileBytes', () {
    // The point of the two-step design: the limit has to be applied before the
    // read, because `FilePicker` with `withData: true` would otherwise already
    // hold the whole file, and Android kills the process on OOM rather than
    // raising something catchable.
    test('reads a file that is within the budget', () async {
      final file = write('ok.json', 4096);

      final bytes = await readImportFileBytes(file.path, maxBytes: 8192);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, 4096);
    });

    test('accepts a file exactly at the limit', () async {
      final file = write('exact.json', 8192);

      final bytes = await readImportFileBytes(file.path, maxBytes: 8192);

      expect(bytes.length, 8192);
    });

    test('refuses a file one byte over the limit, and does not read it', () async {
      final file = write('big.json', 8193);

      await expectLater(
        readImportFileBytes(file.path, maxBytes: 8192),
        throwsA(
          isA<ImportFileTooLarge>()
              .having((e) => e.actualBytes, 'actualBytes', 8193)
              .having((e) => e.maxBytes, 'maxBytes', 8192),
        ),
      );
    });

    test('a refused file is left untouched on disk', () async {
      final file = write('big.json', 8193);

      await expectLater(
        readImportFileBytes(file.path, maxBytes: 8192),
        throwsA(isA<ImportFileTooLarge>()),
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), 8193);
    });
  });

  group('formatByteBudget', () {
    test('renders the budgets this codebase uses', () {
      expect(formatByteBudget(20 * 1024 * 1024), '20 MB');
      expect(formatByteBudget(512 * 1024), '512 KB');
      expect(formatByteBudget(900), '900 B');
    });
  });
}
