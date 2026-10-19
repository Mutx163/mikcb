/// WebView 桥接与主框架导航的安全门禁（纯函数，无 Flutter 依赖，可单测）。
///
/// 登录 WebView 对**任意**页面开放 `QingyuBridge` JS 通道：适配脚本只在导入
/// 执行期由宿主注入运行，但页面本身（登录跳转的中间页、被劫持的重定向、
/// 诱导用户访问的钓鱼页）随时可以 postMessage。两类面由此收紧：
///
/// 1. **UI 类桥接消息**（toast / confirm / prompt / singleSelection / error）
///    的唯一合法生产者是导入执行期正在运行的适配脚本（宿主侧判据
///    `_isPrivilegedBridgeContextActive`）。数据类消息（saveCourseConfig /
///    savePresetTimeSlots / courses）此前已有同款门禁；UI 类此前没有，任意
///    网页都能在原生层弹任意标题/任意内容的对话框——典型钓鱼面（伪造
///    「请输入身份证号」类输入框骗后续操作）。现在统一在消息入口丢弃。
///    宏事件（macro:event）有录制态自检；loginState / loginAttempt /
///    sessionProbe 属宿主自己注入的探活脚本协议，且已有 W7 同源门禁
///    （rememberedLoginAllowsUrl）与同源探测判定，不在此列。
///
/// 2. **主框架导航**：NavigationDelegate 此前没有 onNavigationRequest，对
///    intent: / file: / javascript: / data: 等 scheme 完全不设防。白名单
///    放行 http/https（教务站大量明文 http，NSC 已全量放行）与 about:；
///    其余一律拒绝。子框架导航本就不经过该回调，不受影响。
library;

/// 只在导入执行期处理的桥接消息类型（UI 类，见库注释第 1 点）。
const Set<String> kWarehouseImportOnlyBridgeMessageTypes = <String>{
  'toast',
  'confirm',
  'prompt',
  'singleSelection',
  'error',
};

/// 非 UI 类消息一律照常处理；UI 类只在导入执行期放行。
bool shouldProcessWarehouseBridgeMessage({
  required String type,
  required bool importExecutionActive,
}) {
  if (!kWarehouseImportOnlyBridgeMessageTypes.contains(type)) {
    return true;
  }
  return importExecutionActive;
}

/// 主框架导航的 scheme 白名单。
bool warehouseAllowsMainFrameNavigation(String url) {
  final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
  return scheme == 'http' || scheme == 'https' || scheme == 'about';
}

/// Adapter scripts often toast "成功导入 N 条课程" right before the host shows
/// the quick-import completion sheet. Match common success phrasings so we
/// can suppress the redundant light tip during macro replay.
bool isScriptImportSuccessToast(String message) {
  final text = message.trim();
  if (text.isEmpty) {
    return false;
  }
  final lower = text.toLowerCase();
  return text.contains('成功导入') ||
      text.contains('导入成功') ||
      text.contains('导入完成') ||
      (text.contains('导入') && text.contains('条课程')) ||
      lower.contains('import success') ||
      lower.contains('imported') && lower.contains('course');
}

/// Progress toasts from adapter scripts ("正在获取课表…") are redundant with
/// the quick-import playback overlay / completion sheet.
bool isScriptImportProgressToast(String message) {
  final text = message.trim();
  if (text.isEmpty) {
    return false;
  }
  return text.contains('正在通过接口') ||
      text.contains('正在获取') ||
      text.contains('正在导入') ||
      text.contains('请稍候') ||
      text.contains('请稍等');
}
