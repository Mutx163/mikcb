import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

/// 教务密码的**自动填充白名单**判定。
///
/// 2026-10-08 修的是真问题：`WarehouseSyncBundle.customImportUrls` 随
/// `AppSyncSnapshot.warehouse` 上下行，而 `setCustomImportUrl` 原本只 `trim()`
/// 就落盘，于是 `_warehouseAutofillTrustedHosts` 会无条件把它的 host 加进
/// 白名单 ⇒ 一份构造过的云端快照就能让已保存的教务密码自动填到钓鱼页上。
///
/// 2026-10-10 换了判据维度：原先按「是不是 https」判，结果**只支持明文 http
/// 的教务学校一律拿不到自动填充**——协议不是攻击面的来源。现在按**地址是谁
/// 填的**判：本机亲手填的（用户看得见落地页）http 也放行；云快照下发的
/// （用户没见过那个页面）才要求 https + 同域。
void main() {
  group('本机亲手填的自定义地址', () {
    const source = CustomImportUrlSource.userEntered;

    test('https 与登记地址完全相同 → 放行', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://example.edu.cn/jwxt/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('登记地址的子域 → 放行（学校常把教务挂在 jwxt. 子域上）', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://jwxt.example.edu.cn/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('明文 http → 放行（落地页就在用户眼前，http 的教务学校不该被区别对待）', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'http://jwxt.example.edu.cn/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
        reason: '只支持明文 http 的教务站很多，这一条是 2026-10-10 修复的核心',
      );
    });

    test('与登记地址完全不同的主机 → 仍然放行', () {
      // 用户自己填的地址就是有权覆盖登记地址的：`_effectiveImportUrl` 也用它，
      // 两边必须同源，否则会出现「App 把 WebView 带去 A，白名单只认 B」。
      expect(
        isTrustedCustomImportUrl(
          url: 'http://192.168.1.10:8080/xk',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
        reason: '教务常挂在局域网 IP 或与登记域不同的内网主机上',
      );
    });

    test('后缀伪装在「本机填写」这一侧不予理会', () {
      // 这个地址是用户亲手填的，他看见的就是 example.edu.cn.evil.com，
      // 没有「冒充登记域」的余地。后缀伪装判定是云端来源那道闸的事。
      expect(
        isTrustedCustomImportUrl(
          url: 'https://example.edu.cn.evil.com/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('大小写差异不影响判定', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://JWXT.Example.EDU.CN/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('ftp:// 这类 WebView 打不开的协议 → 拒绝', () {
      // 有主机名、但不是网页。手工填错时不该拿到「可以自动填密码」的信任。
      expect(
        isTrustedCustomImportUrl(
          url: 'ftp://files.example.edu.cn/x',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isFalse,
      );
      expect(
        isTrustedCustomImportUrl(
          url: 'http://jw.example.edu.cn/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
        reason: '同一所学校换成 http 就放行——协议本身不是判据',
      );
    });

    test('没有登记地址可对时（适配器本身没配 importUrl）→ 放行', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'http://jw.some-college.edu.cn/login',
          registeredHost: null,
          source: source,
        ),
        isTrue,
        reason: '这类学校用户必须自己填地址，否则永远没有自动填充',
      );
    });

    test('空串 / 纯空白 → 拒绝', () {
      expect(
        isTrustedCustomImportUrl(url: '', registeredHost: 'example.edu.cn', source: source),
        isFalse,
      );
      expect(
        isTrustedCustomImportUrl(
          url: '   ',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isFalse,
      );
    });

    test('解析不出地址 → 拒绝', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'not a url',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isFalse,
      );
    });
  });

  group('云端快照下发的自定义地址', () {
    const source = CustomImportUrlSource.cloud;

    test('https 与登记地址完全相同 → 放行', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://example.edu.cn/jwxt/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('登记地址的子域 → 放行', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://jwxt.example.edu.cn/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('明文 http → 拒绝（用户没见过这个页面）', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'http://example.edu.cn/jwxt',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isFalse,
      );
    });

    test('后缀伪装（example.edu.cn.evil.com）→ 拒绝', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://example.edu.cn.evil.com/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isFalse,
        reason: 'endsWith 必须是 ".base" 形态，"base.evil.com" 不是子域',
      );
    });

    test('完全不同的主机 → 拒绝', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://evil.com/harvest',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isFalse,
      );
    });

    test('javascript: / file: / data: → 拒绝', () {
      for (final bad in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'data:text/html,<script>alert(1)</script>',
      ]) {
        expect(
          isTrustedCustomImportUrl(
            url: bad,
            registeredHost: 'example.edu.cn',
            source: source,
          ),
          isFalse,
          reason: '$bad 不是可用的登录地址',
        );
      }
    });

    test('大小写差异不影响判定', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://JWXT.Example.EDU.CN/login',
          registeredHost: 'example.edu.cn',
          source: source,
        ),
        isTrue,
      );
    });

    test('没有登记地址可对时只放行 https', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://anything.example.org/login',
          registeredHost: null,
          source: source,
        ),
        isTrue,
      );
      expect(
        isTrustedCustomImportUrl(
          url: 'http://anything.example.org/login',
          registeredHost: null,
          source: source,
        ),
        isFalse,
      );
    });

    test('空串 → 拒绝', () {
      expect(
        isTrustedCustomImportUrl(url: '', registeredHost: 'example.edu.cn', source: source),
        isFalse,
      );
    });
  });
}
