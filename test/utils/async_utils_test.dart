import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/utils/async_utils.dart';

void main() {
  group('isTrustedApkDownloadUrl', () {
    test('allows github release assets', () {
      expect(
        isTrustedApkDownloadUrl(
          'https://github.com/Mutx163/mikcb/releases/download/v2.0.0/app.apk',
        ),
        isTrue,
      );
      expect(
        isTrustedApkDownloadUrl(
          'https://objects.githubusercontent.com/github-production-release-asset/1.apk',
        ),
        isTrue,
      );
    });

    test('allows builtin mirror hosts', () {
      expect(
        isTrustedApkDownloadUrl(
          'https://ghfast.top/github.com/Mutx163/mikcb/releases/download/v2/app.apk',
        ),
        isTrue,
      );
    });

    test('rejects untrusted hosts and non-https urls', () {
      expect(
        isTrustedApkDownloadUrl('http://github.com/Mutx163/mikcb/app.apk'),
        isFalse,
      );
      expect(
        isTrustedApkDownloadUrl('https://evil.example.com/app.apk'),
        isFalse,
      );
      expect(isTrustedApkDownloadUrl('not-a-url'), isFalse);
    });

    test('allows loopback urls only under flutter test', () {
      expect(
        isTrustedApkDownloadUrl('http://127.0.0.1:1234/app.apk'),
        isTrue,
      );
    });

    test('allows user-selected mirror prefix host', () {
      expect(
        isTrustedApkDownloadUrl(
          'https://mirror.example.com/Mutx163/mikcb/app.apk',
          mirrorUrlPrefix: 'https://mirror.example.com/',
        ),
        isTrue,
      );
    });
  });

  // 2026-10-19 信任根收紧：清单（发行版 JSON / Release 页面 HTML）只允许
  // 官方直连主机。第三方反代镜像与用户自填前缀对响应有完全控制权，可同时
  // 伪造清单与其声明的摘要（自洽投毒），因此清单信任判定必须与 APK 下载
  // 主机白名单分开 —— 前者永不接受镜像。
  group('isTrustedManifestUrl', () {
    test('allows official direct hosts and their subdomains', () {
      expect(
        isTrustedManifestUrl(
          'https://api.github.com/repos/Mutx163/mikcb/releases',
        ),
        isTrue,
      );
      expect(
        isTrustedManifestUrl('https://github.com/Mutx163/mikcb/releases'),
        isTrue,
      );
      expect(
        isTrustedManifestUrl(
          'https://objects.githubusercontent.com/github-production-release-asset/1',
        ),
        isTrue,
      );
      expect(
        isTrustedManifestUrl(
          'https://api.gitcode.com/api/v5/repos/mutx/qingyu/releases',
        ),
        isTrue,
      );
    });

    test('rejects builtin mirror hosts even when the path embeds the original url', () {
      // 镜像外壳里恰好整段包含原始 URL（buildMirrorCandidateUrls 的拼接形态），
      // 判定必须看外壳 host，而不是路径里出现过的官方域。
      for (final prefix in allBuiltinMirrorUrlPrefixes) {
        expect(
          isTrustedManifestUrl(
            '$prefix${'https://api.github.com/repos/Mutx163/mikcb/releases'}',
          ),
          isFalse,
          reason: '镜像前缀 $prefix 不允许作为清单来源',
        );
      }
    });

    test('rejects user-selected mirror prefix hosts', () {
      expect(
        isTrustedManifestUrl(
          'https://mirror.example.com/https://api.github.com/repos/Mutx163/mikcb/releases',
        ),
        isFalse,
      );
    });

    test('rejects non-https and garbage urls', () {
      expect(
        isTrustedManifestUrl('http://api.github.com/repos/Mutx163/mikcb/releases'),
        isFalse,
      );
      expect(isTrustedManifestUrl('https://evil.example.com/manifest.json'), isFalse);
      expect(isTrustedManifestUrl('not-a-url'), isFalse);
    });

    test('allows loopback urls only under flutter test', () {
      expect(
        isTrustedManifestUrl('http://127.0.0.1:1234/manifest.json'),
        isTrue,
      );
    });

    test('official host suffix cannot be spoofed by trailing suffix games', () {
      // endsWith('.github.com') 形态的匹配对 `evil.github.com.evil.com` 天然免疫：
      // host 必须恰好等于或以 `.官方域` 结尾。
      expect(
        isTrustedManifestUrl('https://api.github.com.evil.com/releases'),
        isFalse,
      );
      expect(
        isTrustedManifestUrl('https://github.com.evil.com/releases'),
        isFalse,
      );
    });
  });
}
