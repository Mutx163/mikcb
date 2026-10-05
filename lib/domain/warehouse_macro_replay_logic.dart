/// 宏录制/回放里「与真实页面打交道」的几处判定，抽成纯函数以便测试钉住不变量：
/// - WebView 返回值的归一化（平台按 JSON 编码送回字符串）；
/// - 脚本单选项的解析，以及把录制的标签映射回脚本契约要求的下标；
/// - 回放 `navigate` 时，目标文档到底加载好了没有。
///
/// 这些逻辑原先内联在 `course_import_screen.dart` / `warehouse_macro_replayer.dart`
/// 里，靠不了真 WebView 就没法测，也容易出现「录制口径」和「回放口径」各写一份。
library;

import 'dart:convert';

/// 解析一条 QingyuBridge 消息：只有 JSON 对象才算合法，其它一律返回 null。
///
/// 旧写法是 `jsonDecode(raw) as Map<String, dynamic>`，对 `[1,2]`、`"x"`、`42`
/// 这些**合法 JSON** 会抛 TypeError，再被外层 `catch (_) { return; }` 静默吞掉 ——
/// 消息凭空消失且连一条日志都不留，脚本侧的失败因此无从追溯。
Map<String, dynamic>? decodeBridgeMessage(String rawMessage) {
  try {
    final decoded = jsonDecode(rawMessage);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // 非法 JSON，按「不是合法桥消息」丢弃，交调用方记一笔。
  }
  return null;
}

/// 归一化 `runJavaScriptReturningResult` / `evaluateJavascript` 的返回值。
///
/// 平台对**字符串型**表达式的返回值是按 JSON 编码送回来的，例如 JS 里
/// `JSON.stringify({found:false})` 到手是
/// `"{\\"found\\":false,\\"selector\\":\\"#user\\"}"` —— 带外层引号、内层反斜杠转义。
/// 必须整体 `jsonDecode` 才能把 `\\"` 还原成 `"`；只切掉首尾引号会留下
/// `{\\"found\\":false,...}`，下游 `jsonDecode` 必然抛 FormatException。
///
/// 回放引擎里那份旧实现正是只切首尾引号，于是「元素没找到」的判定被
/// `on FormatException` 吞掉、当成成功继续往下跑。裸文本（对象 JSON、`true`、
/// `complete`）解不出字符串，原样返回。
String normalizeWebScriptResult(Object? raw) {
  if (raw == null) return '';
  final text = raw.toString();
  try {
    final decoded = jsonDecode(text);
    if (decoded is String) return decoded;
  } catch (_) {
    // 本来就是裸文本，属预期分支，不是错误。
  }
  return text;
}

/// 桥消息里的可选字符串：只有真的是 [String] 才取值。
///
/// 屏幕侧原先到处写 `message['x'] as String?`，脚本发来一个对象/数组/数字时
/// 会抛 TypeError；而 `_handleBridgeMessage` 的 Future 是被丢掉的（没有
/// await、没有 catch），于是这一抛就把整条回调打断：该做的收尾（取消超时、
/// 复位 `_isExecutingImport`）全部没执行，用户只看到几十秒后一句假的 timeout。
String? bridgeOptionalString(Object? value) => value is String ? value : null;

/// 解析脚本下发的候选项。
///
/// [optionsJson] 既可能是脚本 `JSON.stringify` 出来的字符串，也可能因为脚本
/// 直接塞了个数组而已经是 [List]。两种都接；坏 JSON、其它类型、null 一律按
/// 「没有选项」处理，让调用方自己决定回落，而不是在这里抛。
/// 元素统一 `toString()`，口径与屏幕侧原先的实现逐字一致。
List<String> parseScriptOptionLabels(Object? optionsJson) {
  if (optionsJson is List) {
    return optionsJson.map((item) => item.toString()).toList(growable: false);
  }
  final raw = optionsJson is String ? optionsJson : null;
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((item) => item.toString()).toList(growable: false);
    }
  } catch (_) {
    // 脚本侧数据异常，按空选项兜底。
  }
  return const [];
}

/// 把录制到的「选项」换算成下标；换算不出来返回 null（绝不返回越界下标）。
///
/// 录制存的是**标签**（`options[result]`），而脚本拿到的必须是**下标**
/// （真人操作时 `_resolveJavaScriptRequest(requestId, result)` 传的就是
/// `showAppSingleChoiceDialog` 的 `int?` 返回值）。回放若把标签原样 resolve
/// 回去，脚本里 `options[i]` 会变成 `options["周三"]` → undefined，于是静默
/// 选错校区/学期并把错的数据导进来。
///
/// 同名标签重复时取第一个（与 `List.indexOf` 同语义）。旧录制里如果存的是
/// 数字，也在范围内时按下标接受，越界仍然返回 null。
int? matchRecordedOptionIndex(List<String> options, Object? recorded) {
  if (options.isEmpty || recorded == null) return null;
  if (recorded is int) {
    return recorded >= 0 && recorded < options.length ? recorded : null;
  }
  if (recorded is num) {
    final asInt = recorded.toInt();
    return asInt >= 0 && asInt < options.length ? asInt : null;
  }
  final label = recorded.toString();
  final index = options.indexOf(label);
  return index >= 0 ? index : null;
}

/// 回放 `navigate` 的等待判据：当前文档是不是「已经落到目标页并且加载完成」。
///
/// 判据是 `location.href` 相对导航前**发生了变化**且 `document.readyState`
/// 为 `complete`。只看「URL 非空」是不够的 —— 导航前的旧页面本来就非空，
/// 那样的轮询第一拍就会通过，等于没等。
///
/// [targetHref] 只在「目标就是当前页（重载）」这一种情况下参与判断：那时
/// `href` 不会变化，继续要求变化必定等超时，所以退化成只要 `complete` 就算好。
bool isTargetDocumentLoaded({
  required String? beforeHref,
  required String? currentHref,
  required String? readyState,
  required String targetHref,
}) {
  if (currentHref == null || currentHref.isEmpty) return false;
  if (readyState != 'complete') return false;
  final before = _normalizeHref(beforeHref);
  final current = _normalizeHref(currentHref);
  final target = _normalizeHref(targetHref);
  if (before == null) return true;
  if (target != null && current == target) return true;
  return before != current;
}

/// 去掉 fragment 再比对；导航到 `#xxx` 只是换锚点，不该被当成两个页面。
String? _normalizeHref(String? href) {
  final value = href?.trim();
  if (value == null || value.isEmpty) return null;
  final fragmentIndex = value.indexOf('#');
  return fragmentIndex < 0 ? value : value.substring(0, fragmentIndex);
}
