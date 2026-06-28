import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/week_expression_parser.dart';

void main() {
  group('WeekExpressionParser', () {
    test('parses simple range', () {
      expect(
        WeekExpressionParser.parse('1-16', itemName: '周数'),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16],
      );
    });

    test('parses disjoint weeks', () {
      expect(
        WeekExpressionParser.parse('1-8、10-16', itemName: '周数'),
        [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15, 16],
      );
    });

    test('parses WakeUp odd-week suffix on range', () {
      expect(
        WeekExpressionParser.parse('7-11单', itemName: '周数'),
        [7, 9, 11],
      );
    });

    test('parses WakeUp even-week suffix on range', () {
      expect(
        WeekExpressionParser.parse('1-5双', itemName: '周数'),
        [2, 4],
      );
    });

    test('parses combined WakeUp expression', () {
      expect(
        WeekExpressionParser.parse('1-5、7-11单', itemName: '周数'),
        [1, 2, 3, 4, 5, 7, 9, 11],
      );
    });

    test('parses parenthetical parity mode', () {
      expect(
        WeekExpressionParser.parse('14-15(全部)[01-02-03-04节]', itemName: '周数'),
        [14, 15],
      );
      expect(
        WeekExpressionParser.parse('1-4(单)', itemName: '周数'),
        [1, 3],
      );
      expect(
        WeekExpressionParser.parse('1-4(双)', itemName: '周数'),
        [2, 4],
      );
    });

    test('rejects invalid range', () {
      expect(
        () => WeekExpressionParser.parse('5-3', itemName: '周数'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
