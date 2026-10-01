import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/app_update_service.dart';

/// 回归钉（CODE_REVIEW 2026-10-01 A2）：
///
/// `isTrustedApkDownloadUrl` 只判定主机，且 `github.com` / `githubusercontent.com`
/// / `gitcode.com` 是**全域**可信，再加四个硬编码的第三方加速镜像与用户自填前缀。
/// 镜像是 TLS 终止点，对响应内容有完全控制权，所以「digest 与 browser_download_url
/// 出自同一份响应」证明不了来源：攻击者只要返回
/// `https://github.com/<别人的仓库>/x.apk` 再配一份自洽摘要，主机白名单与常量时间
/// 摘要比对两处会同时通过。旧审计 `docs/CODE_AUDIT_2026-09-26.md` §4 把这套校验评为
/// 「即使 GitHub 和所有镜像全被攻陷，攻击者也装不进恶意包」，漏的正是这里。
///
/// 另外 Dart HttpClient 默认自动跟随最多 5 次重定向，而入口校验看的是初始 URL，
/// 受信任主机一条 302 就能把流量送到攻击者域名。
void main() {
  const official =
      'https://github.com/Mutx163/mikcb/releases/download/'
      'v2.1.3.1/mikcb-2.1.3.1-arm64-v8a.apk';
  const gitcode =
      'https://gitcode.com/mutx/qingyu/releases/download/'
      'v2.1.3.1/mikcb-2.1.3.1-arm64-v8a.apk';
  // release 资产的真实跳转形态：签名短链，路径里不含仓库名。
  const cdn =
      'https://objects.githubusercontent.com/github-production-release-asset/'
      '123?token=***&Expires=***';

  group('isOfficialApkAssetUrl', () {
    test('接受官方仓库、GitCode，以及镜像外壳包着的官方仓库', () {
      expect(AppUpdateService.isOfficialApkAssetUrl(official), isTrue);
      expect(AppUpdateService.isOfficialApkAssetUrl(gitcode), isTrue);
      // 镜像把原 URL 整段拼在路径里（buildMirrorCandidateUrls 的构造方式），
      // 收紧到仓库粒度不能顺手掐掉加速通道。
      expect(
        AppUpdateService.isOfficialApkAssetUrl('https://ghfast.top/$official'),
        isTrue,
      );
      expect(
        AppUpdateService.isOfficialApkAssetUrl('https://gh-proxy.com/$gitcode'),
        isTrue,
      );
      // 部分镜像会把双斜杠塌成单斜杠。
      expect(
        AppUpdateService.isOfficialApkAssetUrl(
          'https://ghfast.top/https:/github.com/Mutx163/mikcb/releases/'
          'download/v2.1.3.1/a.apk',
        ),
        isTrue,
      );
    });

    test('拒绝同一主机上别人的仓库，以及镜像外壳里的别人仓库', () {
      expect(
        AppUpdateService.isOfficialApkAssetUrl(
          'https://github.com/attacker/mikcb/releases/download/v9/a.apk',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isOfficialApkAssetUrl(
          'https://github.com/Mutx163/other/releases/download/v9/a.apk',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isOfficialApkAssetUrl(
          'https://ghfast.top/https://github.com/attacker/x/releases/'
          'download/v9/a.apk',
        ),
        isFalse,
      );
      // 官方路径被塞进查询串不构成资产直链。
      expect(
        AppUpdateService.isOfficialApkAssetUrl(
          'https://github.com/Mutx163/mikcb/releases/latest'
          '?x=/Mutx163/mikcb/releases/download/v9/a.apk',
        ),
        isFalse,
      );
      // 路径之外的官方仓库地址（tag 页、latest 重定向页）都不算资产直链。
      expect(
        AppUpdateService.isOfficialApkAssetUrl(
          'https://github.com/Mutx163/mikcb/releases/tag/v2.1.3.1',
        ),
        isFalse,
      );
    });
  });

  group('isRedirectTargetAllowed', () {
    test('放行 GitHub 资产 CDN 与仍是官方资产的跳点', () {
      expect(AppUpdateService.isRedirectTargetAllowed(cdn), isTrue);
      expect(AppUpdateService.isRedirectTargetAllowed(official), isTrue);
    });

    test('拒绝把流量送到攻击者域名、别人的仓库或明文跳点', () {
      expect(
        AppUpdateService.isRedirectTargetAllowed(
          'https://evil.example.com/a.apk',
        ),
        isFalse,
      );
      expect(
        AppUpdateService.isRedirectTargetAllowed(
          'https://github.com/attacker/repo/releases/download/v9/a.apk',
        ),
        isFalse,
      );
      // 仿冒域名必须过不了 .githubusercontent.com 的边界。
      expect(
        AppUpdateService.isRedirectTargetAllowed(
          'https://evil-githubusercontent.com/x',
        ),
        isFalse,
      );
      // 重定向降级成 http 一律拒绝（主机层校验要求 https）。
      expect(
        AppUpdateService.isRedirectTargetAllowed(
          'http://github.com/Mutx163/mikcb/releases/download/v9/a.apk',
        ),
        isFalse,
      );
    });
  });
}
