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
      // loginState/loginAttempt/sessionProbe 是宿主自注入脚本协议，且已有
      // W7 同源门禁。这里只保证本函数不误伤它们。
      for (final type in const [
        'saveCourseConfig',
        'savePresetTimeSlots',
        'courses',
        'loginState',
        'loginAttempt',
        'sessionProbe',
        'macro:event',
        '',
        'unknown-type',
      ]) {
        expect(
          shouldProcessWarehouseBridgeMessage(
            type: type,
            importExecutionActive: false,
          ),
          isTrue,
          reason: 'type=$type 不属于 UI 类门禁名单',
        );
      }
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
