import 'dart:io';

import 'package:table_parser/table_parser.dart';

void main() {
  final b =
      File('test/fixtures/mikcb_course_import_template.xlsx').readAsBytesSync();
  stdout.writeln('magic: ${b.take(8).toList()}');
  try {
    stdout.writeln(TableParser.decodeBytes(b).tables.keys);
  } catch (e) {
    stdout.writeln('decodeBytes error: $e');
  }
}