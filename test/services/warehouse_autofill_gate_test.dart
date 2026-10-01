import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

/// 回归钉（CODE_REVIEW 2026-10-01 A1）：
///
/// `dc48ca3` 把凭据门禁改成「只认 App 会导航过去的站点」，方向正确，但它把安全
/// 判据建在了**远端可变数据**上 —— `trustedHosts` 由适配器登记地址推导
/// （course_import_screen `_warehouseAutofillTrustedHosts`），而这个地址
/// * 来自上游 qingyu_warehouse 的 adapters.yaml（分支钉在可变的 `main`，且
///   仓库自证 204 个 adapters.yaml 均无 sha256、哈希门禁 currently INERT）；
/// * 快捷导入路径里更是直接取宏记录的 `importUrl`，而宏可由云快照带回
///   （app_sync_snapshot_service.importAllMacros，反序列化对该 URL 零校验）。
///
/// 叠加回放模式原本「直接填充、不弹对话框」且那条 WebView 是 1×1 藏在 Offstage
/// 里（用户看不见落地页），结果：能写用户 WebDAV 目录、或能改上游仓库的人，就能让
/// App 在无声中把已存学号密码填进攻击者页面。
///
/// 修复是：无人值守的回放/快捷导入路径不再采信 trustedHosts（默认空集），只认凭据
/// 自身绑定的 host。本文件钉住两侧语义，防止将来被无意改回去。
void main() {
  const unboundLegacy = WarehouseRememberedLogin(username: 's', password: 'p');
  const bound = WarehouseRememberedLogin(
    username: 's',
    password: 'p',
    host: 'jw.example.edu.cn',
  );
  const remoteAnchoredUrl = 'https://jw.attacker.example/login';

  group('严格模式（回放/快捷导入，不传 trustedHosts）', () {
    test('存量空 host 凭据不再被远端推导的锚点放行', () {
      expect(
        rememberedLoginAllowsUrl(unboundLegacy, remoteAnchoredUrl),
        isFalse,
      );
    });

    test('绑定过 host 的凭据仍只在绑定域自动填充', () {
      expect(
        rememberedLoginAllowsUrl(bound, 'https://jw.example.edu.cn/t'),
        isTrue,
      );
      expect(rememberedLoginAllowsUrl(bound, remoteAnchoredUrl), isFalse);
    });
  });

  group('宽松模式（交互式导入页，WebView 全屏可见）', () {
    test('仍按名单放行 —— 本次修复没有改动交互式行为', () {
      expect(
        rememberedLoginAllowsUrl(
          unboundLegacy,
          remoteAnchoredUrl,
          trustedHosts: const ['jw.attacker.example'],
        ),
        isTrue,
      );
      expect(
        rememberedLoginAllowsUrl(
          unboundLegacy,
          'https://other.example/login',
          trustedHosts: const ['jw.attacker.example'],
        ),
        isFalse,
      );
    });
  });
}
