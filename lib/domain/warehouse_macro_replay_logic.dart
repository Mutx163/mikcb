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

/// 脚本发来 `complete` 时该怎么收尾。
enum ImportCompletionAction {
  /// 正常收尾：取消超时、复位执行中、状态写「导入流程已完成」。
  finalize,

  /// 宏回放还在等课程数据：只更新状态文字，不动执行中标记、不取消超时。
  showStatusOnly,

  /// 本轮导入已经定局（被取消/失败/超时/写完），不再由 complete 改写。
  ignore,
}

/// `complete` 的处置判定。
///
/// 关键点：`saveImportedCourses` 在 JS 侧是 fire-and-forget —— 它 postMessage
/// 之后就立刻 `return true`，课程数据到底解没解出来、用户选没选覆盖、写库成没
/// 成功，Dart 那边还在异步跑。所以脚本随后发的 `complete` 完全可能落在「本轮
/// 已经定局」之后：用户在「替换还是合并」里点了取消，屏幕已经把状态写成
/// 「导入已取消」并弹出错误提示，紧接着这条 `complete` 又把状态改成
/// 「导入流程已完成」—— 取消掉的导入在状态栏里显示成功。
///
/// 因此只要 `_isExecutingImport` 已经是 false（取消、失败、超时、写完四条路径
/// 都会先复位它），`complete` 就只能被忽略；判定顺序也排在宏回放之前，避免
/// 「已定局 + 仍在等课程」并存时反而写出成功文案。
ImportCompletionAction importCompletionAction({
  required bool isExecutingImport,
  required bool isMacroReplay,
  required bool playbackWaitingForCourses,
  required bool quickResultHandled,
}) {
  if (!isExecutingImport) return ImportCompletionAction.ignore;
  if (isMacroReplay && playbackWaitingForCourses) {
    return ImportCompletionAction.showStatusOnly;
  }
  if (isMacroReplay && quickResultHandled) {
    return ImportCompletionAction.ignore;
  }
  return ImportCompletionAction.finalize;
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

/// 回放开始前，入口网页是不是已经成了「有内容的完整文档」。
///
/// 宿主屏幕是在页面**第一帧**（`postFrameCallback`）就启动回放的，那时 WebView
/// 往往连第一个字节都还没拿到：document 还是 `about:blank`，或者只收到半截
/// HTML。旧回放没有这一步，于是宏的第一步（填账号）直接打在空白文档上——实测
/// 日志里页面打开到回放启动只隔 2ms，紧接着第一步就报元素不存在。
///
/// 判据刻意宽松：只要 href 不是空白页且 `readyState === 'complete'` 就放行。
/// 真正的「登录页长什么样」由各步骤自己等（见 [defaultMacroElementWaitMs]）。
bool isEntryDocumentReady({
  required String? href,
  required String? readyState,
}) {
  final value = href?.trim() ?? '';
  if (value.isEmpty) return false;
  // about:blank / about:srcdoc 是 WebView 的初始空文档，不是学校的页面。
  if (value.startsWith('about:')) return false;
  return readyState == 'complete';
}

/// 等某个 DOM 元素出现（填充 / 点击）的默认时长。
///
/// 教务站首页常常在回放已经开始之后才把表单铺出来，慢网下要好几秒。10 秒是
/// 实测能覆盖常见强智/正方登录页与菜单页的值，也是用户能忍受的上限。
const int defaultMacroElementWaitMs = 10000;

/// 等待元素的结果判定：只有明确回报 `found: true` 才算真的找到了。
///
/// 解析不出 JSON（脚本抛错、上下文已被导航销毁、平台返回空串）一律按「还没
/// 找到」处理，继续轮到超时——绝不像旧实现那样把「读不懂」当成「做成了」。
bool macroElementFound(String normalizedResult) {
  if (normalizedResult.isEmpty) return false;
  try {
    final decoded = jsonDecode(normalizedResult);
    if (decoded is Map) return decoded['found'] == true;
  } catch (_) {
    // 不是 JSON：交给调用方继续轮询 / 报失败。
  }
  return false;
}

/// 脚本明确回报「没找到」（`found: false`）。
///
/// 与 [macroElementFound] 的区别是「读不懂」怎么算：断言场景（[ensureMacroElementFound]）
/// 里读不懂不等于没找到，不能凭空报错；轮询场景里读不懂不等于找到了，必须继续等。
/// 两种口径各自显式写开，避免同一个 `if` 兼顾两件事。
bool macroElementExplicitlyMissing(String normalizedResult) {
  if (normalizedResult.isEmpty) return false;
  try {
    final decoded = jsonDecode(normalizedResult);
    if (decoded is Map) return decoded['found'] == false;
  } catch (_) {
    // 不是 JSON：不是「明确没找到」。
  }
  return false;
}

/// 两个 href 是不是「不同的文档」（忽略 query 与 fragment）。
///
/// 用于判断「上一步点击有没有把页面带走」：`?x=1` 与 `#/tab` 这种不算换页，
/// 只有 scheme+host+path 变了才说明旧页面的元素真的随之作废。
/// 任一 href 读不到时返回 false（判不准就别认定换了页）。
bool macroDocumentChanged(String? beforeHref, String? currentHref) {
  final before = _normalizeHref(beforeHref);
  final current = _normalizeHref(currentHref);
  if (before == null || current == null) return false;
  final beforeUri = Uri.tryParse(before);
  final currentUri = Uri.tryParse(current);
  if (beforeUri == null || currentUri == null) return before != current;
  if (!beforeUri.hasScheme || !currentUri.hasScheme) return before != current;
  final beforeKey = '${beforeUri.scheme}://${beforeUri.host}${beforeUri.path}';
  final currentKey =
      '${currentUri.scheme}://${currentUri.host}${currentUri.path}';
  return beforeKey.toLowerCase() != currentKey.toLowerCase();
}

/// 一条「找不到元素」的点击步骤，是不是记录时留下的、已经作废的步骤。
///
/// 用于**已经存在手机里的旧宏**（录制器已修，但旧宏不会自动重录）。旧录制把
/// 一次「点登录」记成了两次点击：先点 `#btnSubmit`，再点它所属的 `#Form1`。
/// 回放时第一下点击就完成跳转，第二下要点的登录表单在新页面上并不存在，于是把
/// 10 秒预算耗完、整条宏判失败——2026-10-21 城科实测：登录已经成功、URL 已经到
/// `xsMain.jsp`，却栽在 `#Form1` 上。
///
/// 判据要求三件事同时成立，才认定「这一步已经作废」：
/// 1. 这一步是**点击**（填充/等待找不到元素，说明页面根本没走到该到的地方）；
/// 2. 元素确实**没找到**（脚本明确回报 found:false）；
/// 3. **上一步点击刚刚把页面带走了**（`previousClickNavigated`）。
///
/// 第 3 条是关键的收紧项：只有「刚翻过页」才认定旧元素作废。若页面没动过还说
/// 找不到，那就是真的缺东西，必须如实失败。
bool shouldSkipStaleClickStep({
  required bool stepIsClick,
  required bool elementNotFound,
  required bool previousClickNavigated,
}) {
  return stepIsClick && elementNotFound && previousClickNavigated;
}

/// 录制事件里，「点提交按钮」后面那条 `submit` 是不是同一个动作的重复。
///
/// 浏览器点 `<input type="submit">` 走的是：先 `click`（落在按钮上），再
/// `submit`（落在它所属的 `<form>` 上）——**一次用户动作、两个事件**。录制器
/// 两个都收、且都转成 `MacroStep.click`，于是「点登录」变成两步：先点
/// `#btnSubmit`，再点 `#Form1`。
///
/// 回放时第一下点击就完成跳转，第二下打在新页面上（城科是 `xsMain.jsp`）——那里
/// 没有登录表单，于是第 6 步报 `macro_element_not_found|selector=#Form1`，
/// 十秒后整条宏失败。2026-10-21 城科实测日志正是这个形状：登录已成功、URL 已到
/// `xsMain.jsp`，却在一个不存在的表单上耗完预算。
///
/// 判据靠录制时一并记下的 [previousFormSelector]（点按钮时它所属表单的选择器，
/// 由注入脚本的 `formSelector` 字段带回）。只比字符串前缀是不够的：
/// `#btnSubmit` 与 `#Form1` 之间没有前缀关系，那种写法永远判不出来。
///
/// 丢的是**后面那条 submit**：前面的 click 已经足以触发提交，而 submit 那条的
/// 选择器是表单本身，跳转后的新页面上必然不存在。
bool isRedundantSubmitAfterClick({
  required String previousEventType,
  required String? previousFieldType,
  required String? previousFormSelector,
  required String currentSelector,
  required int gapMs,
}) {
  // 上一条必须是「点提交按钮」：只有 input[type=submit|button] 会带 formSelector。
  if (previousEventType != 'click') return false;
  if (previousFieldType != 'button') return false;
  final form = (previousFormSelector ?? '').trim();
  if (form.isEmpty) return false;
  // 同一次动作的两个事件紧挨着；窗口外说明是用户先做了别的、之后才提交。
  if (gapMs < 0 || gapMs > 2000) return false;
  return currentSelector.trim() == form;
}

/// 一个选择器之外还该试的等价选择器。
///
/// 旧回放里那段「找不到就按 name 再找一次」的兜底是坏的：它把选择器**整条**
/// 当 name 用，`#userAccount` 会拼成 `input[name="#userAccount"]`，永远匹配不上。
/// 真正的意图是「旧录制把 id 当选器存了，而页面只写了 name」，所以只在
/// 选择器是纯 id 形态（`#foo`）时才派生 `input[name="foo"]`。
List<String> macroSelectorCandidates(String selector) {
  final trimmed = selector.trim();
  if (trimmed.isEmpty) return const [];
  final candidates = <String>[trimmed];
  if (trimmed.startsWith('#') &&
      trimmed.length > 1 &&
      !trimmed.contains(' ') &&
      !trimmed.contains('>') &&
      !trimmed.contains('[') &&
      !trimmed.substring(1).contains('"')) {
    candidates.add('input[name="${trimmed.substring(1)}"]');
  }
  return candidates;
}

/// 去掉 fragment 再比对；导航到 `#xxx` 只是换锚点，不该被当成两个页面。
String? _normalizeHref(String? href) {
  final value = href?.trim();
  if (value == null || value.isEmpty) return null;
  final fragmentIndex = value.indexOf('#');
  return fragmentIndex < 0 ? value : value.substring(0, fragmentIndex);
}
