import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/domain/warehouse_bridge_gate.dart';

void main() {
  group('shouldProcessWarehouseBridgeMessage（UI 类桥接消息的导入态门禁）', () {
    test('UI 类消息在导入执行期放行', () {
      for (final type in kWarehouseImportOnlyBridgeMessageTypes) {
        expect(
          shouldProcessWarehouseBridgeMessage(
            type: type,
            importExecutionActive: true,
          ),
          isTrue,
          reason: 'type=$type 应在导入执行期放行',
        );
      }
    });

    test('UI 类消息在非导入执行期一律丢弃（钓鱼弹窗面）', () {
      for (final type in kWarehouseImportOnlyBridgeMessageTypes) {
        expect(
          shouldProcessWarehouseBridgeMessage(
            type: type,
            importExecutionActive: false,
          ),
          isFalse,
          reason: 'type=$type 不该在导入执行期之外处理',
        );
      }
    });

    test('门禁名单恰好覆盖五种 UI 类消息，不多不少', () {
      // 名单变化必须是有意识的：新增一类 UI 消息就要同步进名单，
      // 否则它会绕过导入态门禁（2026-10-19 安全清单 #1）。
      expect(
        kWarehouseImportOnlyBridgeMessageTypes,
        {'toast', 'confirm', 'prompt', 'singleSelection', 'error'},
      );
    });

    test('数据类与宿主探活协议消息不受导入态门禁影响', () {
      // saveCourseConfig/savePresetTimeSlots/courses 在宿主侧另有同款门禁；
      // loginState/sessionProbe 是宿主自注入脚本协议，且已有 W7 同源门禁。
      // 这里只保证本函数不误伤它们。macro:event / loginAttempt 原先也在
      // 这份「不受影响」名单里，2026-11-02 第二轮安全审计收进门禁（见下）。
      for (final type in const [
        'saveCourseConfig',
        'savePresetTimeSlots',
        'courses',
        'loginState',
        'sessionProbe',
        '',
        'unknown-type',
      ]) {
        expect(
          shouldProcessWarehouseBridgeMessage(
            type: type,
            importExecutionActive: false,
          ),
          isTrue,
          reason: 'type=$type 不属于门禁名单',
        );
      }
    });
  });

  group('macro:event / loginAttempt 门禁（2026-11-02 第二轮安全审计 #2）', () {
    test('macro:event 非录制态一律拒绝，执行期也不例外', () {
      // 唯一合法生产者是录制脚本（只在录制态被注入）；执行期跑的是适配脚本，
      // 不发宏事件，执行期放行反而会开一个「脚本/页面伪造宏事件」的口子。
      expect(
        shouldProcessWarehouseBridgeMessage(
          type: 'macro:event',
          importExecutionActive: false,
        ),
        isFalse,
        reason: '非执行期、非录制态的 macro:event 必须被拒绝',
      );
      expect(
        shouldProcessWarehouseBridgeMessage(
          type: 'macro:event',
          importExecutionActive: true,
        ),
        isFalse,
        reason: '执行期也不该放行 macro:event（合法生产者只在录制态）',
      );
      expect(
        shouldProcessWarehouseBridgeMessage(
          type: 'macro:event',
          importExecutionActive: false,
          macroRecordingActive: true,
        ),
        isTrue,
        reason: '录制态放行',
      );
    });

    test('loginAttempt 非执行期且页面不受信：拒绝且无副作用', () {
      // 返回 false 即调用点在分发前整条丢弃：不触发「保存密码」弹窗、
      // 不写任何状态。四个放行条件全部缺省（= false，执行期/录制态/前台
      // 回放都不在、页面不受信）时必须拒绝。
      expect(
        shouldProcessWarehouseBridgeMessage(
          type: 'loginAttempt',
          importExecutionActive: false,
        ),
        isFalse,
        reason: '钓鱼页/第三方页上伪造的 loginAttempt 必须被拒绝',
      );
    });

    test('loginAttempt 四个放行条件任一成立即放行', () {
      bool allowed({
        required bool importExecutionActive,
        required bool macroRecordingActive,
        required bool foregroundReplayActive,
        required bool trustedPageOrigin,
      }) {
        return shouldProcessWarehouseBridgeMessage(
          type: 'loginAttempt',
          importExecutionActive: importExecutionActive,
          macroRecordingActive: macroRecordingActive,
          foregroundReplayActive: foregroundReplayActive,
          trustedPageOrigin: trustedPageOrigin,
        );
      }

      expect(
        allowed(
          importExecutionActive: true,
          macroRecordingActive: false,
          foregroundReplayActive: false,
          trustedPageOrigin: false,
        ),
        isTrue,
        reason: '导入执行期放行',
      );
      expect(
        allowed(
          importExecutionActive: false,
          macroRecordingActive: true,
          foregroundReplayActive: false,
          trustedPageOrigin: false,
        ),
        isTrue,
        reason: '宏录制中手动登录放行（首登保存密码的主路径）',
      );
      expect(
        allowed(
          importExecutionActive: false,
          macroRecordingActive: false,
          foregroundReplayActive: true,
          trustedPageOrigin: false,
        ),
        isTrue,
        reason: '前台回放导航阶段放行（登录步骤在执行期之前）',
      );
      expect(
        allowed(
          importExecutionActive: false,
          macroRecordingActive: false,
          foregroundReplayActive: false,
          trustedPageOrigin: true,
        ),
        isTrue,
        reason: '普通手动登录（学校页面上）放行，放行路径不变',
      );
    });
  });

  group('warehouseUrlOnTrustedHosts（loginAttempt 门禁的同源锚点）', () {
    test('精确与子域命中放行，大小写不敏感', () {
      expect(
        warehouseUrlOnTrustedHosts(
          'http://jw.example.cn/login',
          ['jw.example.cn'],
        ),
        isTrue,
      );
      expect(
        warehouseUrlOnTrustedHosts(
          'https://a.jw.example.cn/x',
          ['jw.example.cn'],
        ),
        isTrue,
        reason: '教务登录常在子域间跳，子域必须放行',
      );
      expect(
        warehouseUrlOnTrustedHosts('https://JW.EXAMPLE.CN/', ['jw.example.cn']),
        isTrue,
      );
    });

    test('后缀伪装与跨源页面拒绝', () {
      expect(
        warehouseUrlOnTrustedHosts(
          'https://jw.example.cn.evil.com/',
          ['jw.example.cn'],
        ),
        isFalse,
        reason: 'endsWith 必须带点边界，trusted.cn.evil.com 不算 trusted.cn',
      );
      expect(
        warehouseUrlOnTrustedHosts('https://evil.com/', ['jw.example.cn']),
        isFalse,
      );
      expect(
        warehouseUrlOnTrustedHosts(
          'https://notjw.example.cn/',
          ['jw.example.cn'],
        ),
        isFalse,
      );
    });

    test('解析不出 host 或受信集合为空一律拒绝（只会更严）', () {
      expect(warehouseUrlOnTrustedHosts(null, ['jw.example.cn']), isFalse);
      expect(warehouseUrlOnTrustedHosts('', ['jw.example.cn']), isFalse);
      expect(warehouseUrlOnTrustedHosts('not a url', ['jw.example.cn']),
          isFalse);
      expect(warehouseUrlOnTrustedHosts('https://jw.example.cn/', <String>[]),
          isFalse);
      expect(
        warehouseUrlOnTrustedHosts('https://jw.example.cn/', ['', '  ']),
        isFalse,
        reason: '空串锚点应被跳过而不是放行一切',
      );
    });
  });

  group('warehouseAllowsMainFrameNavigation（主框架导航 scheme 白名单）', () {
    test('http 与 https 放行（教务站大量明文 http，NSC 已全量放行）', () {
      expect(
        warehouseAllowsMainFrameNavigation('https://jw.example.edu.cn/login'),
        isTrue,
      );
      expect(
        warehouseAllowsMainFrameNavigation('http://jw.example.edu.cn/login'),
        isTrue,
      );
      expect(warehouseAllowsMainFrameNavigation('HTTPS://A.EXAMPLE.CN'), isTrue);
    });

    test('about: 放行（WebView 内部空白页）', () {
      expect(warehouseAllowsMainFrameNavigation('about:blank'), isTrue);
    });

    test('危险 scheme 一律拒绝', () {
      expect(
        warehouseAllowsMainFrameNavigation(
          'intent://x/#Intent;package=com.evil;end',
        ),
        isFalse,
      );
      expect(
        warehouseAllowsMainFrameNavigation('javascript:alert(1)'),
        isFalse,
      );
      expect(warehouseAllowsMainFrameNavigation('file:///data/1.html'), isFalse);
      expect(
        warehouseAllowsMainFrameNavigation('data:text/html,<h1>hi</h1>'),
        isFalse,
      );
      expect(warehouseAllowsMainFrameNavigation('ftp://files.example.cn'),
          isFalse);
      expect(warehouseAllowsMainFrameNavigation('chrome://flags'), isFalse);
    });

    test('解析不出 scheme 的输入按拒绝处理', () {
      expect(warehouseAllowsMainFrameNavigation(''), isFalse);
      expect(warehouseAllowsMainFrameNavigation('not a url'), isFalse);
    });
  });

  group('脚本 toast 分类器（自登录页 State 下沉为纯函数）', () {
    test('成功导入类文案识别', () {
      expect(isScriptImportSuccessToast('成功导入 5 条课程'), isTrue);
      expect(isScriptImportSuccessToast('导入成功'), isTrue);
      expect(isScriptImportSuccessToast('Import success!'), isTrue);
      expect(isScriptImportSuccessToast(''), isFalse);
      expect(isScriptImportSuccessToast('网络错误'), isFalse);
    });

    test('进度类文案识别', () {
      expect(isScriptImportProgressToast('正在获取课表…'), isTrue);
      expect(isScriptImportProgressToast('请稍候'), isTrue);
      expect(isScriptImportProgressToast('导入完成'), isFalse);
      expect(isScriptImportProgressToast('  '), isFalse);
    });
  });
}
