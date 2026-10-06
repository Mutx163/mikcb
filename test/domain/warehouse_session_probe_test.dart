import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_session_probe.dart';

void main() {
  group('parseWarehouseSessionProbeConfig', () {
    test('reads probe_url', () {
      final config = parseWarehouseSessionProbeConfig(
        '{"probe_url": "/cqdxcskjxy_jsxsd/xskb/xskb_list.do"}',
      );

      expect(config, isNotNull);
      expect(config!.probeUrl, '/cqdxcskjxy_jsxsd/xskb/xskb_list.do');
    });

    test('trims the value', () {
      final config = parseWarehouseSessionProbeConfig(
        '{"probe_url": "  /xskb/xskb_list.do  "}',
      );

      expect(config?.probeUrl, '/xskb/xskb_list.do');
    });

    // 这份数据来自网络。坏了必须等于「没配置」，绝不能让导入流程炸掉。
    test('treats every malformed shape as "not configured"', () {
      expect(parseWarehouseSessionProbeConfig(null), isNull);
      expect(parseWarehouseSessionProbeConfig(''), isNull);
      expect(parseWarehouseSessionProbeConfig('   '), isNull);
      expect(parseWarehouseSessionProbeConfig('not json'), isNull);
      expect(parseWarehouseSessionProbeConfig('[]'), isNull);
      expect(parseWarehouseSessionProbeConfig('"a string"'), isNull);
      expect(parseWarehouseSessionProbeConfig('{}'), isNull);
      expect(parseWarehouseSessionProbeConfig('{"probe_url": ""}'), isNull);
      expect(parseWarehouseSessionProbeConfig('{"probe_url": 42}'), isNull);
      expect(parseWarehouseSessionProbeConfig('{"other": "/x"}'), isNull);
    });
  });

  group('resolveWarehouseSessionProbeTarget', () {
    const entry = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/';

    test('resolves a relative path against the entry url', () {
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: entry,
          probeUrl: '/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
        ),
        'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
      );
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: entry,
          probeUrl: 'xskb/xskb_list.do',
        ),
        'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
      );
    });

    test('accepts an absolute same-origin url', () {
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: entry,
          probeUrl: 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
        ),
        'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
      );
    });

    // 探针是**自动发起**的请求：用户没在看的站，它不许自己跑过去。
    test('rejects anything that is not same-origin with the current page', () {
      String? resolve(String pageUrl, String probeUrl) =>
          resolveWarehouseSessionProbeTarget(
            entryUrl: entry,
            pageUrl: pageUrl,
            probeUrl: probeUrl,
          );

      expect(resolve(entry, 'http://evil.example.com/x'), isNull);
      expect(resolve(entry, 'https://jw.cqcst.edu.cn/x'), isNull);
      expect(resolve(entry, 'http://jw.cqcst.edu.cn:8080/x'), isNull);
      expect(resolve('https://other.example.com/', '/x'), isNull);
    });

    test('rejects non-http schemes and protocol-relative urls', () {
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: entry,
          probeUrl: 'javascript:alert(1)',
        ),
        isNull,
      );
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: entry,
          probeUrl: 'data:text/html,<input type="password">',
        ),
        isNull,
      );
      // 协议相对地址的 scheme 得靠页面猜，不接受这种写法。
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: entry,
          probeUrl: '//jw.cqcst.edu.cn/x',
        ),
        isNull,
      );
    });

    test('rejects unusable urls', () {
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: '',
          pageUrl: entry,
          probeUrl: '/x',
        ),
        isNull,
      );
      expect(
        resolveWarehouseSessionProbeTarget(
          entryUrl: entry,
          pageUrl: 'not a url at all',
          probeUrl: '/x',
        ),
        isNull,
      );
    });
  });

  group('parseWarehouseSessionProbeSignal', () {
    test('reads the injected js payload', () {
      final signal = parseWarehouseSessionProbeSignal(
        '{"ok":true,"status":200,"finalUrl":"http://a/b.do",'
        '"hasPasswordField":false,"bodyLength":51234}',
      );

      expect(signal, isNotNull);
      expect(signal!.ok, isTrue);
      expect(signal.status, 200);
      expect(signal.finalUrl, 'http://a/b.do');
      expect(signal.hasPasswordField, isFalse);
      expect(signal.bodyLength, 51234);
    });

    test('tolerates stringified numbers and missing fields', () {
      final signal = parseWarehouseSessionProbeSignal(
        '{"ok":true,"status":"200","bodyLength":"900"}',
      );

      expect(signal!.status, 200);
      expect(signal.bodyLength, 900);
      expect(signal.finalUrl, '');
      expect(signal.hasPasswordField, isFalse);
    });

    test('returns null for junk', () {
      expect(parseWarehouseSessionProbeSignal(null), isNull);
      expect(parseWarehouseSessionProbeSignal(''), isNull);
      expect(parseWarehouseSessionProbeSignal('}{'), isNull);
      expect(parseWarehouseSessionProbeSignal('[]'), isNull);
    });
  });

  group('classifyWarehouseSessionProbe', () {
    const page = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/';

    WarehouseSessionProbeSignal signal({
      bool ok = true,
      int status = 200,
      String finalUrl = 'http://jw.cqcst.edu.cn/cqdxcskjxy_jsxsd/xskb/xskb_list.do',
      bool hasPasswordField = false,
      int bodyLength = 20000,
    }) => WarehouseSessionProbeSignal(
      ok: ok,
      status: status,
      finalUrl: finalUrl,
      hasPasswordField: hasPasswordField,
      bodyLength: bodyLength,
    );

    test('server gave a real page -> session alive', () {
      expect(
        classifyWarehouseSessionProbe(signal: signal(), pageUrl: page),
        WarehouseSessionProbeVerdict.loggedIn,
      );
    });

    // 强智未登录时不跳转，而是把登录框原样吐回来 —— 见到密码框就是没登录。
    test('server handed back a login form -> session gone', () {
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(hasPasswordField: true),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.loggedOut,
      );
    });

    // 下面每一条都必须倒向 unavailable，绝不允许给出强结论。
    test('every uncertain case stays unavailable, never a strong verdict', () {
      expect(
        classifyWarehouseSessionProbe(signal: null, pageUrl: page),
        WarehouseSessionProbeVerdict.unavailable,
      );
      // 网络层就废了（WAF、离线、证书……）。
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(ok: false, bodyLength: 0),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.unavailable,
      );
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(status: 500),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.unavailable,
      );
      // 拦截页 / 空壳：不是页面，不能拿来判会话。
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(bodyLength: 12),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.unavailable,
      );
      // 被甩到别的站（SSO 域名不同、统一认证网关……），那条响应与本会话无关。
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(finalUrl: 'https://sso.other.edu.cn/login'),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.unavailable,
      );
      // 跨源且同时带密码框：这时最容易被误判成"没登录"，必须挡住。
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(
            finalUrl: 'https://sso.other.edu.cn/login',
            hasPasswordField: true,
          ),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.unavailable,
      );
    });

    test('an empty finalUrl means "not redirected"', () {
      expect(
        classifyWarehouseSessionProbe(
          signal: signal(finalUrl: ''),
          pageUrl: page,
        ),
        WarehouseSessionProbeVerdict.loggedIn,
      );
    });
  });

  group('warehouseSessionProbeOrigin', () {
    test('normalizes default ports so the same site keeps one origin', () {
      expect(
        warehouseSessionProbeOrigin('http://a.example.com/x'),
        warehouseSessionProbeOrigin('http://a.example.com:80/y'),
      );
    });

    test('separates different hosts, schemes and ports', () {
      final base = warehouseSessionProbeOrigin('http://a.example.com/x');

      expect(warehouseSessionProbeOrigin('http://b.example.com/x'), isNot(base));
      expect(warehouseSessionProbeOrigin('https://a.example.com/x'), isNot(base));
      expect(
        warehouseSessionProbeOrigin('http://a.example.com:8080/x'),
        isNot(base),
      );
    });

    test('returns null for unusable urls', () {
      expect(warehouseSessionProbeOrigin(null), isNull);
      expect(warehouseSessionProbeOrigin(''), isNull);
      expect(warehouseSessionProbeOrigin('   '), isNull);
      expect(warehouseSessionProbeOrigin('relative/path'), isNull);
    });
  });
}
