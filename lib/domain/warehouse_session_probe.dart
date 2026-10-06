import 'dart:convert';

/// 教务会话探针。
///
/// ## 它要解决什么
///
/// 强智一类教务系统（`jsxsd`）的**登录页是一张写死的静态页**：服务器对入口地址
/// 根本不做会话判断，无论你登录没登录都原样返回那张登录框。会话判断只发生在
/// 「内页」（如课表页）——未登录时它同样不跳转，而是把登录框再吐一遍，只是在
/// 上面多一行红字。后果是：登录态明明还在，用户看到的却是一张登录框，App 只能
/// 照着「看见密码框」这个假象去问用户要不要重新登录。
///
/// 而适配脚本抓课表时是 `fetch(课表页, {credentials: 'include'})`，**带会话
/// Cookie 的请求照样通过**——所以「其实还登录着」这件事在导入那一步本来就是
/// 已知的，只是从来没人提前告诉用户。
///
/// ## 怎么探
///
/// 请求一个**必须登录才能看**的地址，看服务器给的是什么：
///
/// - 给登录框（有 `input[type=password]`）→ 会话没了（[WarehouseSessionProbeVerdict.loggedOut]）
/// - 给别的东西 → 会话还在（[WarehouseSessionProbeVerdict.loggedIn]）
///
/// 判据就这么一条，因为它复用了服务器自己的行为，不猜、不猜学校实现。
///
/// ## 为什么探测目标要学校自己声明
///
/// 判据通用，**目标地址不通用**：App 只知道登记的入口地址，而入口地址对多数学校
/// 就是那张登录页本身（少数学校登记的是课表页）。从登录页看不出会话状态——那正是
/// 本文件要解决的病。所以目标地址由学校在
/// `qingyu_only/<学校ID>/session_probe.json` 里声明一行，见
/// [parseWarehouseSessionProbeConfig]。
///
/// 没有这个文件 = 不探针 = 保持现状（200+ 所学校零行为变化）。这是刻意的：
/// 探针是锦上添花，判不出来时必须安静退让，不能把用户从登录页踹到别处。

/// 一所学校的探针配置。留空 / 解析失败一律当作「没有配置」。
class WarehouseSessionProbeConfig {
  /// 必须登录才能看到的地址。相对路径按入口地址的 origin 解析。
  final String probeUrl;

  const WarehouseSessionProbeConfig({required this.probeUrl});
}

/// 解析 `qingyu_only/<学校ID>/session_probe.json`。
///
/// ```json
/// { "probe_url": "/cqdxcskjxy_jsxsd/xskb/xskb_list.do" }
/// ```
///
/// 任何异常（不是 JSON、不是对象、缺键、键不是非空字符串）都返回 `null` 而不是
/// 抛错：这份数据来自网络，坏了就等于「没配置」，绝不能因此让导入流程失败。
WarehouseSessionProbeConfig? parseWarehouseSessionProbeConfig(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  final probeUrl = decoded['probe_url'];
  if (probeUrl is! String || probeUrl.trim().isEmpty) {
    return null;
  }
  return WarehouseSessionProbeConfig(probeUrl: probeUrl.trim());
}

/// 探针结论。
enum WarehouseSessionProbeVerdict {
  /// 还没探过，或探了但没结论。
  unknown,

  /// 会话还在：服务器给了正经页面，没给登录框。
  loggedIn,

  /// 会话没了：服务器把登录框吐回来了。
  loggedOut,

  /// 探不动（网络失败 / 被跨源重定向 / 响应不像页面）。**不等于没登录**。
  unavailable,
}

/// 页面里跑完 fetch 后回传的原始信号。字段与注入的 JS 一一对应。
class WarehouseSessionProbeSignal {
  /// fetch 本身有没有跑通（false = 网络层就废了）。
  final bool ok;

  /// HTTP 状态码。
  final int status;

  /// 跟随重定向之后的最终地址。
  final String finalUrl;

  /// 响应 HTML 里有没有密码输入框。
  final bool hasPasswordField;

  /// 响应体长度。用来挡掉 WAF 拦截页 / 错误页这类「不是页面」的响应。
  final int bodyLength;

  const WarehouseSessionProbeSignal({
    required this.ok,
    required this.status,
    required this.finalUrl,
    required this.hasPasswordField,
    required this.bodyLength,
  });

  /// 低于这个长度就当「不是页面」。真实内页（课表页）动辄几十 KB，登录框也有
  /// 几 KB；几百字节的响应只可能是拦截页、空壳或错误页，拿它判会话一定是瞎猜。
  static const int minBodyLength = 400;
}

/// 解析页面回传的信号 JSON。解析不了返回 `null`（= `unknown`）。
WarehouseSessionProbeSignal? parseWarehouseSessionProbeSignal(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return null;
  }
  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) {
    return null;
  }
  return WarehouseSessionProbeSignal(
    ok: decoded['ok'] == true,
    status: _asInt(decoded['status']),
    finalUrl: decoded['finalUrl'] is String
        ? decoded['finalUrl'] as String
        : '',
    hasPasswordField: decoded['hasPasswordField'] == true,
    bodyLength: _asInt(decoded['bodyLength']),
  );
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

/// 把探针信号判成结论。
///
/// 每一条不确定的分支都倒向 [WarehouseSessionProbeVerdict.unavailable]，因为
/// 探针的**唯一**用途是改善提示与抑制无谓的自动填充弹窗：
///
/// - 误判「已登录」→ 用户看到一句多余的话，仍可正常手动登录；
/// - 误判「未登录」→ 多弹一次自动填充，用户点「暂不」即可。
///
/// 两个误判都可恢复、无破坏性；反过来若允许在不确定时给出强结论，就会出现
/// 「明明会话已失效，App 却信誓旦旦说已登录」这种更糟的误导。
WarehouseSessionProbeVerdict classifyWarehouseSessionProbe({
  required WarehouseSessionProbeSignal? signal,
  required String pageUrl,
}) {
  if (signal == null || !signal.ok) {
    return WarehouseSessionProbeVerdict.unavailable;
  }
  if (signal.status < 200 || signal.status >= 400) {
    return WarehouseSessionProbeVerdict.unavailable;
  }
  if (signal.bodyLength < WarehouseSessionProbeSignal.minBodyLength) {
    return WarehouseSessionProbeVerdict.unavailable;
  }
  // 服务器把我们甩到了别的站（SSO 域名不同、统一认证网关……）。那条响应说的
  // 是另一个站的事，跟当前教务会话无关，不许据此下结论。finalUrl 为空时
  // 视为「没被重定向」，不作跨源判断。
  final landed = signal.finalUrl.trim();
  if (landed.isNotEmpty) {
    final page = Uri.tryParse(pageUrl.trim());
    final target = Uri.tryParse(landed);
    if (page == null || target == null || !_sameOrigin(target, page)) {
      return WarehouseSessionProbeVerdict.unavailable;
    }
  }
  return signal.hasPasswordField
      ? WarehouseSessionProbeVerdict.loggedOut
      : WarehouseSessionProbeVerdict.loggedIn;
}

/// 算出这次真正要请求的地址；不该探就返回 `null`。
///
/// 规则：
///
/// 1. 只允许 http / https。`javascript:`、`data:` 之类一律拒绝——配置虽然来自
///    我们自己的仓库，但它是**要被 fetch 的 URL**，没必要给它任何执行语义。
/// 2. 相对路径按**入口地址**解析，学校数据里写 `/xskb/xskb_list.do` 就够了，
///    不用每所学校重复写一遍域名。
/// 3. 最终地址必须与**当前页面同源**（scheme + host + 端口都算）。跨源就返回
///    `null` —— 探针是自动发起的请求，不能让它悄悄跑到用户没在看的站上去；
///    用户自己在地址栏输别的站时同理。
String? resolveWarehouseSessionProbeTarget({
  required String entryUrl,
  required String pageUrl,
  required String probeUrl,
}) {
  final probe = Uri.tryParse(probeUrl.trim());
  if (probe == null) {
    return null;
  }
  // 协议相对地址（`//host/path`）的 scheme 得看页面，相对入口地址解析等于让
  // 数据作者赌一个协议，不接受这种写法。
  if (!probe.hasScheme && probeUrl.trim().startsWith('//')) {
    return null;
  }
  final entry = Uri.tryParse(entryUrl.trim());
  final page = Uri.tryParse(pageUrl.trim());
  if (entry == null || page == null || !entry.hasScheme || !page.hasScheme) {
    return null;
  }
  final Uri target;
  if (probe.hasScheme) {
    if (probe.scheme != 'http' && probe.scheme != 'https') {
      return null;
    }
    target = probe;
  } else {
    target = entry.resolveUri(probe);
  }
  if (target.scheme != 'http' && target.scheme != 'https') {
    return null;
  }
  if (target.host.isEmpty || !_sameOrigin(target, page)) {
    return null;
  }
  return target.toString();
}

/// origin = scheme + host + 有效端口（`http` 默认 80、`https` 默认 443）。
/// `Uri.port` 已经把默认端口归一化，直接比即可。
bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme && a.host == b.host && a.port == b.port;

/// 页面来源是否变了。变了就说明换站了，之前那份会话结论不再作数。
String? warehouseSessionProbeOrigin(String? url) {
  final uri = Uri.tryParse((url ?? '').trim());
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  return '${uri.scheme}://${uri.host}:${uri.port}';
}
