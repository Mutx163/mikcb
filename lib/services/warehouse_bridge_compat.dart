/// 教务适配脚本桥接兼容垫片（注入 WebView 用）。
///
/// 上游 shiguang_warehouse 已于 2026-08-23 将适配协议从 v1 升级至 v2：
/// 桥接对象由 `AndroidBridge` / `AndroidBridgePromise` 统一更名为
/// `window.shiguangBridge` / `window.shiguangBridgePromise`，
/// 方法集合与数据结构完全不变。
///
/// 宿主先完成 v1 桥实现（QingyuBridge -> AndroidBridge*），再追加本垫片，
/// 使同一份注入环境同时兼容 v1 与 v2 两种协议的适配脚本：
/// - 正向别名：让上游 v2 新脚本能找到桥；
/// - 反向幂等别名：防御性保证 v1 老脚本在任何时序下仍能找到桥。
///
/// 详见 docs/plans/2026-08-23-upstream-v2-bridge-compat-plan.md（A 层）。
const String kWarehouseBridgeCompatShim = r'''
// qingyu bridge compat: v1 <-> v2 aliases (upstream protocol v2, 2026-08)
window.shiguangBridge = window.AndroidBridge;
window.shiguangBridgePromise = window.AndroidBridgePromise;
if (!window.AndroidBridge && window.shiguangBridge) {
  window.AndroidBridge = window.shiguangBridge;
}
if (!window.AndroidBridgePromise && window.shiguangBridgePromise) {
  window.AndroidBridgePromise = window.shiguangBridgePromise;
}
''';
