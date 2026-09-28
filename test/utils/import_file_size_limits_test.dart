import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/import_file_reader.dart';

/// The size ceiling must reject *before* reading, not after.
///
/// The 20 MB figure is a product decision; "there is a ceiling at all" is not.
/// On Android an out-of-memory condition kills the process outright instead of
/// raising something catchable, so an unguarded picker is a crash rather than
/// an error message.
///
/// This lives in its own file with no service imports on purpose: it is the
/// half that must stay runnable no matter what else in the app is mid-refactor.
/// The companion `import_file_budget_consistency_test.dart` pins that every
/// entry point agrees on the number.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('import_size_limit');
  });

  tearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  File write(String name, int bytes) => File(
        '${dir.path}${Platform.pathSeparator}$name',
      )..writeAsBytesSync(List<int>.filled(bytes, 0x41));

  test('大于上限时抛 ImportFileTooLarge，且不返回任何字节', () async {
    final file = write('big.json', 2048);
    await expectLater(
      readImportFileBytes(file.path, maxBytes: 1024),
      throwsA(isA<ImportFileTooLarge>()),
    );
  });

  test('恰好等于上限时放行（边界不能差一）', () async {
    final file = write('exact.json', 1024);
    final bytes = await readImportFileBytes(file.path, maxBytes: 1024);
    expect(bytes.length, 1024);
  });

  test('小于上限时原样返回内容', () async {
    final file = write('small.json', 16);
    final bytes = await readImportFileBytes(file.path, maxBytes: 1024);
    expect(bytes.length, 16);
  });

  test('超限时异常带上真实体积与上限，便于界面提示', () async {
    final file = write('big2.json', 2048);
    try {
      await readImportFileBytes(file.path, maxBytes: 1024);
      fail('应当抛出 ImportFileTooLarge');
    } on ImportFileTooLarge catch (error) {
      expect(error.actualBytes, 2048);
      expect(error.maxBytes, 1024);
    }
  });
}
