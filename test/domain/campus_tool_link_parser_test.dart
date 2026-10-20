import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/campus_tool_link_parser.dart';

/// 链接编辑框的解析规则：这些字符串是**用户手输**的，解析器是唯一一道
/// 把「用户写的东西」变成可执行 intent 的闸门，所以逐条钉死。
void main() {
  group('parseCampusToolLinks', () {
    test('空文本得到空表（不算错误）', () {
      final result = parseCampusToolLinks('  \n \n');
      expect(result.ok, isTrue);
      expect(result.links, isEmpty);
    });

    test('纯链接行不限定包名', () {
      final result = parseCampusToolLinks('https://example.com/a');
      expect(result.ok, isTrue);
      expect(result.links.single.uri, 'https://example.com/a');
      expect(result.links.single.package, isNull);
    });

    test('包名|链接 拆成限定目标应用', () {
      final result = parseCampusToolLinks(
        'com.taobao.taobao|taobao://m.taobao.com/x\n'
        '  cainiao://desktop/station_code  ',
      );
      expect(result.ok, isTrue);
      expect(result.links.length, 2);
      expect(result.links.first.package, 'com.taobao.taobao');
      expect(result.links.first.uri, 'taobao://m.taobao.com/x');
      expect(result.links.last.package, isNull);
      expect(result.links.last.uri, 'cainiao://desktop/station_code');
    });

    test('左侧不像包名时整行按 URI 解析（查询串里的 | 不能误伤）', () {
      final result = parseCampusToolLinks(
        'https://example.com/search?q=a|b&lang=zh',
      );
      expect(result.ok, isTrue);
      expect(result.links.single.uri, 'https://example.com/search?q=a|b&lang=zh');
      expect(result.links.single.package, isNull);
    });

    test('缺少 scheme 的行报错并给出 1 基行号（空行不占号）', () {
      final result = parseCampusToolLinks(
        'taobao://ok\n'
        '\n'
        'https://ok\n'
        'not-a-uri',
      );
      expect(result.ok, isFalse);
      expect(result.error, CampusToolLinkParseError.uri);
      expect(result.lineNumber, 4);
    });

    test('危险 scheme 被拒绝（file / javascript / intent）', () {
      for (final uri in <String>[
        'file:///sdcard/a.apk',
        'javascript:alert(1)',
        'intent://scan#Intent;scheme=zxing;end',
        'content://media/external/images/1',
      ]) {
        final result = parseCampusToolLinks(uri);
        expect(result.ok, isFalse, reason: '应当拒绝 $uri');
        expect(result.error, CampusToolLinkParseError.uri);
      }
    });

    test('`包名|坏链接` 报 URI 错，而不是把它当成无包名链接', () {
      final result = parseCampusToolLinks('com.taobao.taobao|oops');
      expect(result.ok, isFalse);
      expect(result.error, CampusToolLinkParseError.uri);
    });
  });

  group('parseCampusToolPackages', () {
    test('空行跳过、重复去重', () {
      final result = parseCampusToolPackages(
        'com.taobao.taobao\n\ncom.taobao.taobao\ncom.xunmeng.pinduoduo',
      );
      expect(result.ok, isTrue);
      expect(result.packages, <String>[
        'com.taobao.taobao',
        'com.xunmeng.pinduoduo',
      ]);
    });

    test('坏包名给出 1 基行号', () {
      final result = parseCampusToolPackages('com.ok.app\nbad-package');
      expect(result.ok, isFalse);
      expect(result.badLineNumber, 2);
    });
  });

  group('isValidCampusToolWebUri', () {
    test('只接受 http(s) 且有主机部分', () {
      expect(isValidCampusToolWebUri('https://a.cn/x'), isTrue);
      expect(isValidCampusToolWebUri('HTTP://a.cn'), isTrue);
      expect(isValidCampusToolWebUri('https://'), isFalse);
      expect(isValidCampusToolWebUri('taobao://a.cn'), isFalse);
      expect(isValidCampusToolWebUri('a.cn'), isFalse);
    });
  });

  group('isValidCampusToolUri', () {
    test('上限长度与 scheme 形状', () {
      expect(isValidCampusToolUri('a://b'), isTrue);
      expect(isValidCampusToolUri('a+b-c.d://x'), isTrue);
      expect(isValidCampusToolUri('1a://x'), isFalse);
      expect(isValidCampusToolUri('://x'), isFalse);
      final long = 'https://a.cn/${'x' * kCampusToolMaxUriLength}';
      expect(isValidCampusToolUri(long), isFalse);
    });
  });
}
