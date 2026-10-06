import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/screens/import/warehouse/warehouse_shared.dart';

void main() {
  group('warehouseDocumentKey', () {
    test('ignores query and fragment so hash routing stays same-document', () {
      const base = 'http://jw.example.edu.cn/jsxsd/xskb/xskb_list.do';
      expect(
        warehouseDocumentKey(base),
        warehouseDocumentKey('$base#tab2'),
      );
      expect(
        warehouseDocumentKey(base),
        warehouseDocumentKey('$base?zc=3&demo='),
      );
      expect(
        warehouseDocumentKey('$base?zc=3#tab2'),
        warehouseDocumentKey(base),
      );
    });

    test('is case-insensitive on scheme and host', () {
      expect(
        warehouseDocumentKey('HTTP://JW.Example.EDU.CN/jsxsd/xsMain.jsp'),
        warehouseDocumentKey('http://jw.example.edu.cn/jsxsd/xsMain.jsp'),
      );
    });

    test('treats a different path as a different document', () {
      // This is the 强智 case: script sits on the personal center and navigates
      // to the timetable page, which really does destroy the script context.
      expect(
        warehouseDocumentKey(
          'http://jw.example.edu.cn/jsxsd/framework/xsMain.jsp',
        ),
        isNot(
          warehouseDocumentKey(
            'http://jw.example.edu.cn/jsxsd/xskb/xskb_list.do',
          ),
        ),
      );
    });

    test('treats a different host or scheme as a different document', () {
      expect(
        warehouseDocumentKey('http://a.example.edu.cn/jsxsd/xsMain.jsp'),
        isNot(
          warehouseDocumentKey('https://a.example.edu.cn/jsxsd/xsMain.jsp'),
        ),
      );
      expect(
        warehouseDocumentKey('http://a.example.edu.cn/jsxsd/xsMain.jsp'),
        isNot(
          warehouseDocumentKey('http://b.example.edu.cn/jsxsd/xsMain.jsp'),
        ),
      );
    });

    test('path differences that are only trailing slash still differ', () {
      // /list and /list/ are different documents; do not silently merge them.
      expect(
        warehouseDocumentKey('http://a.example.cn/jsxsd/xskb_list.do'),
        isNot(warehouseDocumentKey('http://a.example.cn/jsxsd/xskb_list.do/')),
      );
    });

    test('degrades gracefully on empty or unparseable input', () {
      expect(warehouseDocumentKey(null), '');
      expect(warehouseDocumentKey('  '), '');
      expect(warehouseDocumentKey(''), '');
    });
  });
}

