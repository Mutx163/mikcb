import 'package:flutter_test/flutter_test.dart';
import 'package:university_timetable/services/warehouse_bridge_compat.dart';

void main() {
  group('kWarehouseBridgeCompatShim', () {
    const shim = kWarehouseBridgeCompatShim;

    test('为上游 v2 协议暴露正向别名（新脚本可用）', () {
      expect(shim, contains('window.shiguangBridge = window.AndroidBridge;'));
      expect(
        shim,
        contains(
          'window.shiguangBridgePromise = window.AndroidBridgePromise;',
        ),
      );
    });

    test('保留反向幂等别名（v1 老脚本始终可用）', () {
      expect(
        shim,
        contains('if (!window.AndroidBridge && window.shiguangBridge)'),
      );
      expect(
        shim,
        contains(
          'if (!window.AndroidBridgePromise && window.shiguangBridgePromise)',
        ),
      );
    });

    test('不包含宿主注入占位符，避免意外 Dart 插值', () {
      // 垫片会被嵌入 wrappedScript 三引号字符串，$ 会触发 Dart 插值。
      expect(shim.contains(r'$'), isFalse);
    });
  });
}
