import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/models/warehouse_macro_models.dart';

void main() {
  group('sanitizeWarehouseScriptPageUrl 保留 hash 路由', () {
    test('纯路由 fragment 不再被顺手抹掉', () {
      // 教务站大量是 Vue/React SPA，目标页整个写在 fragment 里
      // （`#/schedule/semester`）。重建 Uri 时不带 fragment 会让保存的
      // scriptPageUrl、加速回放的入口都退化成站点外壳默认页，后面的选择器
      // 自然找不到 —— 表现为宏回放莫名其妙失败。
      expect(
        sanitizeWarehouseScriptPageUrl('https://jw.example.edu.cn/portal#/schedule'),
        'https://jw.example.edu.cn/portal#/schedule',
      );
      expect(
        sanitizeWarehouseScriptPageUrl(
          'https://jw.example.edu.cn/app#/course/semester/2025',
        ),
        'https://jw.example.edu.cn/app#/course/semester/2025',
      );
    });

    test('路由保留，会话参数照旧摘掉', () {
      final cleaned = sanitizeWarehouseScriptPageUrl(
        'https://jw.example.edu.cn/portal?JSESSIONID=ABC123&id=9#/schedule',
      )!;
      expect(cleaned, contains('#/schedule'));
      expect(cleaned, isNot(contains('ABC123')));
      expect(cleaned, contains('id=9'));
    });

    test('fragment 里夹回调凭据时整段丢掉', () {
      // OAuth 风格的 `#access_token=…` 属于一次性载荷，留着毫无意义且会跟着
      // 宏一起导出到云同步与日志里。
      expect(
        sanitizeWarehouseScriptPageUrl(
          'https://a.edu.cn/callback#access_token=SECRET&state=xyz',
        ),
        'https://a.edu.cn/callback',
      );
      final cleaned = sanitizeWarehouseScriptPageUrl(
        'https://a.edu.cn/p#/cb?token=SECRET',
      )!;
      expect(cleaned, isNot(contains('SECRET')));
    });

    test('口令类参数名一并纳入摘除口径（query 与 fragment 同一份判据）', () {
      final cleaned = sanitizeWarehouseScriptPageUrl(
        'https://a.edu.cn/p?userPassword=SECRET&year=2025#/r',
      )!;
      expect(cleaned, isNot(contains('SECRET')));
      expect(cleaned, contains('year=2025'));
      expect(cleaned, contains('#/r'));
      expect(isWarehouseVolatileUrlParamKey('PWD'), isTrue);
      expect(isWarehouseVolatileUrlParamKey('PHPSESSID'), isTrue);
      expect(isWarehouseVolatileUrlParamKey('year'), isFalse);
      expect(isWarehouseVolatileUrlParamKey('x'), isFalse);
    });

    test('没有 fragment 时不会凭空拼出一个 #', () {
      expect(
        sanitizeWarehouseScriptPageUrl('https://a.edu.cn/portal'),
        'https://a.edu.cn/portal',
      );
      expect(
        sanitizeWarehouseScriptPageUrl('https://a.edu.cn/portal?'),
        'https://a.edu.cn/portal',
      );
    });

    test('既有脱敏口径不退化：路径内与主机内的 ;jsessionid 依然清掉', () {
      expect(
        sanitizeWarehouseScriptPageUrl(
          'http://jw.example.edu.cn;jsessionid=ABC123DEF/x',
        ),
        'http://jw.example.edu.cn/x',
      );
      expect(
        sanitizeWarehouseScriptPageUrl('http://a.edu.cn/p;jsessionid=ABC/x'),
        'http://a.edu.cn/p/x',
      );
      expect(sanitizeWarehouseScriptPageUrl('not a url'), isNull);
      expect(sanitizeWarehouseScriptPageUrl('ftp://a.edu.cn/x'), isNull);
    });
  });
}
