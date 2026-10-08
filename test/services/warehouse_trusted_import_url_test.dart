import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_import_preferences_service.dart';

/// 2026-10-08 审核实测：教务密码的**自动填充白名单**可以被云端数据换成
/// 攻击者的主机名。
///
/// 完整链路（已逐行读过）：
/// 1. `WarehouseSyncBundle.customImportUrls` 随 `AppSyncSnapshot.warehouse`
///    上行/下行（`app_sync_snapshot_service.dart` 的 `exportSyncBundle`）；
/// 2. 还原时 `setCustomImportUrl` **只 `trim()` 就落盘**，零校验；
/// 3. `warehouse_adapter_web_login_screen.dart` 的 `_warehouseAutofillTrustedHosts`
///    把这个地址的 host **无条件**加进自动填充白名单；
/// ⇒ 一份构造过的云端快照就能让已保存的教务账号密码自动填到钓鱼页上。
///
/// 修法两道闸：还原时要求 https；进白名单时额外要求与该适配器登记的
/// 登录地址**同域**（本身或其子域）。
void main() {
  group('自定义导入地址进自动填充白名单的判据', () {
    test('与登记地址完全相同 → 放行', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://example.edu.cn/jwxt/login',
          registeredHost: 'example.edu.cn',
        ),
        isTrue,
      );
    });

    test('登记地址的子域 → 放行（学校常把教务挂在 jwxt. 子域上）', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://jwxt.example.edu.cn/login',
          registeredHost: 'example.edu.cn',
        ),
        isTrue,
      );
    });

    test('后缀伪装（example.edu.cn.evil.com）→ 拒绝', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://example.edu.cn.evil.com/login',
          registeredHost: 'example.edu.cn',
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
        ),
        isFalse,
      );
    });

    test('明文 http → 拒绝（要提交账号密码，绝不走明文）', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'http://example.edu.cn/jwxt',
          registeredHost: 'example.edu.cn',
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
          isTrustedCustomImportUrl(url: bad, registeredHost: 'example.edu.cn'),
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
        ),
        isTrue,
      );
    });

    test('空串 / 纯空白 → 拒绝', () {
      expect(
        isTrustedCustomImportUrl(url: '', registeredHost: 'example.edu.cn'),
        isFalse,
      );
      expect(
        isTrustedCustomImportUrl(url: '   ', registeredHost: 'example.edu.cn'),
        isFalse,
      );
    });

    test('没有登记地址可对时只放行 https（由调用方决定要不要进白名单）', () {
      expect(
        isTrustedCustomImportUrl(
          url: 'https://anything.example.org/login',
          registeredHost: null,
        ),
        isTrue,
      );
      expect(
        isTrustedCustomImportUrl(
          url: 'http://anything.example.org/login',
          registeredHost: null,
        ),
        isFalse,
      );
    });
  });
}