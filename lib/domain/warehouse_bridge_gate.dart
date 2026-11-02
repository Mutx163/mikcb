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
///
/// 2. **macro:event / loginAttempt**（2026-11-02 第二轮安全审计 #2）原先
///    「随时处理」：宏事件只在处理器内部做录制态自检，登录尝试则完全无门禁。
///    伪造 loginAttempt 可触发「保存密码」弹窗把攻击者构造的值存进受信凭据
///    槽位（该槽位每个适配器只有一份，存盘即覆盖真凭据）。两者的放行条件
///    见 [shouldProcessWarehouseBridgeMessage]；loginState / sessionProbe
///    仍属宿主自己注入的探活脚本协议，且已有 W7 同源门禁
///    （rememberedLoginAllowsUrl）与同源探测判定，不在此列。
///
/// 3. **主框架导航**：NavigationDelegate 此前没有 onNavigationRequest，对
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

/// 非 UI 类消息一律照常处理；UI 类只在导入执行期放行；
/// macro:event / loginAttempt 有各自的放行条件（见函数内注释）。
bool shouldProcessWarehouseBridgeMessage({
  required String type,
  required bool importExecutionActive,
  bool macroRecordingActive = false,
  bool foregroundReplayActive = false,
  bool trustedPageOrigin = false,
}) {
  switch (type) {
    case 'macro:event':
      // 唯一合法生产者是宿主在**录制态**注入的录制脚本（录制开始时注入当前页、
      // 录制中每次导航后重注入）。非录制态没有合法生产者，一律丢弃——原先这个
      // 判据写在事件处理器内部，现在与其它消息一样收进门禁统一判。
      // 已知残留（审计接受）：录制中把 WebView 导航到第三方页时，该页伪造的
      // 宏事件仍会通过录制态判定；录制脚本的注入范围与导航白名单的关系需要
      // 产品层面再定，见交付报告。
      return macroRecordingActive;
    case 'loginAttempt':
      // 伪造 loginAttempt 的落点是「保存密码」弹窗（钓鱼面 + 覆盖真凭据）。
      // 放行条件取并集：
      // - 执行期 / 录制态：宿主主导的会话，与 UI 类门禁同权；
      // - 前台回放的导航阶段（登录步骤在 executingImport 之前）：回放允许
      //   补录提示（见 _handleLoginAttempt 的注释），后台回放本来就会被
      //   runInBackground 抑制；
      // - 当前页在受信 host 上：**普通手动登录不在执行期/录制态**（登录监听
      //   脚本每次 onPageFinished 都注入），主路径靠这条放行——锚点与 W7
      //   自动填充门禁同一套（登记地址 + 受信自定义地址），钓鱼页/第三方页
      //   上的伪造登录尝试在这里被挡下。
      return importExecutionActive ||
          macroRecordingActive ||
          foregroundReplayActive ||
          trustedPageOrigin;
    default:
      if (!kWarehouseImportOnlyBridgeMessageTypes.contains(type)) {
        return true;
      }
      return importExecutionActive;
  }
}

/// 当前页 URL 是否落在受信 host 集合内（精确或子域）——loginAttempt 门禁的
/// 「同源放行」锚点。
///
/// 受信 host 由宿主提供：适配器登记的登录地址 + 受信的自定义导入地址，与 W7
/// 自动填充门禁（`rememberedLoginAllowsUrl` 内部的 `_hostMatches`）同一套
/// 语义。这里为可单测另写一份纯函数（domain 层不 import services）；两处
/// 测试都必须覆盖 `a.trusted.cn` 匹配 `trusted.cn`、而 `trusted.cn.evil.com`
/// 的后缀伪装被拒绝。
///
/// 解析不出 host 的输入（空串、相对地址、非 http 形态）按拒绝处理：门禁
/// 因此只会更严，不会更松。
bool warehouseUrlOnTrustedHosts(String? url, Iterable<String> trustedHosts) {
  final uri = Uri.tryParse((url ?? '').trim());
  final host = uri?.host.trim().toLowerCase() ?? '';
  if (host.isEmpty) {
    return false;
  }
  for (final trusted in trustedHosts) {
    final t = trusted.trim().toLowerCase();
    if (t.isEmpty) {
      continue;
    }
    if (host == t || host.endsWith('.$t')) {
      return true;
    }
  }
  return false;
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
