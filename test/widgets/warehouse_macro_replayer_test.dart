import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/widgets/warehouse_macro_replayer.dart';

void main() {
  group('ensureMacroElementFound', () {
    test('throws when JavaScript reports missing element', () {
      expect(
        () => ensureMacroElementFound(
          '{"found":false,"selector":"#missing"}',
          '未找到点击元素: #missing',
        ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('未找到点击元素: #missing'),
          ),
        ),
      );
    });

    test('does not throw for found element or non-json result', () {
      expect(
        () => ensureMacroElementFound(
          '{"found":true,"selector":"#login"}',
          '未找到点击元素: #login',
        ),
        returnsNormally,
      );
      expect(
        () => ensureMacroElementFound('true', '未找到点击元素: #login'),
        returnsNormally,
      );
    });
  });
}
