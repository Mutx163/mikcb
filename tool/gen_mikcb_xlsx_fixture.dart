import 'dart:io';
import 'dart:isolate';

import 'package:table_parser/table_parser.dart';

Future<void> main() async {
  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:table_parser/table_parser.dart'),
  );
  if (packageUri == null) {
    stderr.writeln('table_parser package not resolved');
    exit(1);
  }
  final templateXlsx = File.fromUri(
    packageUri.resolve('../test/files/default.xlsx'),
  );

  final csv = File('assets/templates/mikcb_course_import_template.csv')
      .readAsStringSync();
  final csvDecoder = TableParser.decodeCsv(csv);
  final csvSheet = csvDecoder.tables.values.first;

  final bytes = templateXlsx.readAsBytesSync();
  final decoder = TableParser.decodeBytes(bytes, update: true);
  final sheetName = decoder.tables.keys.first;
  final table = decoder.tables[sheetName]!;

  while (table.maxRows < csvSheet.maxRows) {
    decoder.insertRow(sheetName, table.maxRows);
  }
  while (table.maxCols < csvSheet.maxCols) {
    decoder.insertColumn(sheetName, table.maxCols);
  }

  for (var rowIndex = 0; rowIndex < csvSheet.maxRows; rowIndex++) {
    final row = csvSheet.rows[rowIndex];
    for (var colIndex = 0; colIndex < row.length; colIndex++) {
      decoder.updateCell(sheetName, colIndex, rowIndex, row[colIndex]);
    }
  }

  final outDir = Directory('test/fixtures');
  outDir.createSync(recursive: true);
  File('test/fixtures/mikcb_course_import_template.xlsx')
      .writeAsBytesSync(decoder.encode());
}