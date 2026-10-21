import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:university_timetable/l10n/service_message_localizer.dart';

import '../domain/warehouse_macro_replay_logic.dart';
import '../models/warehouse_macro_models.dart';
import '../services/warehouse_import_session_log.dart';
import 'warehouse_macro_recorder.dart';

/// 回放步骤的当前状态
enum ReplayStepStatus { pending, running, succeeded, failed, pausedForInput }

/// 回放进度信息（回放引擎通过回调传递给 UI）
class ReplayProgress {
  final int currentStepIndex;
  final int totalSteps;
  final MacroStep currentStep;
  final ReplayStepStatus status;
  final String? errorMessage;
  final String? pauseReason;

  const ReplayProgress({
    required this.currentStepIndex,
    required this.totalSteps,
    required this.currentStep,
    required this.status,
    this.errorMessage,
    this.pauseReason,
  });

  double get progress =>
      totalSteps > 0 ? (currentStepIndex + 1) / totalSteps : 0.0;

  String statusLabel(AppLocalizations l10n) {
    switch (status) {
      case ReplayStepStatus.running:
        return _stepTypeLabel(l10n, currentStep.type);
      case ReplayStepStatus.failed:
        return l10n.macroReplayStatusFailed(
          errorMessage != null
              ? localizeServiceMessage(l10n, errorMessage!)
              : '',
        );
      case ReplayStepStatus.pausedForInput:
        return l10n.macroReplayStatusPaused(
          pauseReason != null ? localizeServiceMessage(l10n, pauseReason!) : '',
        );
      case ReplayStepStatus.pending:
      case ReplayStepStatus.succeeded:
        return '';
    }
  }

  static String _stepTypeLabel(AppLocalizations l10n, MacroStepType type) {
    switch (type) {
      case MacroStepType.navigate:
        return l10n.macroReplayStepNavigating;
      case MacroStepType.fillField:
        return l10n.macroReplayStepFilling;
      case MacroStepType.click:
        return l10n.macroReplayStepClicking;
      case MacroStepType.waitForUrl:
        return l10n.macroReplayStepWaitUrl;
      case MacroStepType.waitForSelector:
        return l10n.macroReplayStepWaitSelector;
      case MacroStepType.waitForManualInput:
        return l10n.macroReplayStepWaitManual;
      case MacroStepType.executeScript:
        return l10n.macroReplayStepExecuteScript;
      case MacroStepType.delay:
        return l10n.macroReplayStepDelay;
    }
  }
}

/// 回放引擎回调接口
class ReplayCallbacks {
  /// 进度更新
  final void Function(ReplayProgress progress) onProgress;

  /// 需要用户手动操作时调用（如验证码）。返回 true = 继续，false = 取消
  final Future<bool> Function(MacroStep step, String reason)
  onPauseForManualInput;

  /// 回放过程中需要显示消息提示
  final void Function(String message) onShowTip;

  /// 回放完成回调
  final void Function(bool success, String? errorMessage) onComplete;

  const ReplayCallbacks({
    required this.onProgress,
    required this.onPauseForManualInput,
    required this.onShowTip,
    required this.onComplete,
  });
}

/// 宏回放引擎
class WarehouseMacroReplayer {
  final WebViewController _controller;
  final ReplayCallbacks _callbacks;
  final AppLocalizations _l10n;

  /// 步骤自己没声明等待时长时，等元素的默认预算。
  ///
  /// 只有测试会改它：真机上一个「等 10 秒」的用例要跑 10 秒，把整条失败路径
  /// 变成跑不动的测试，等于没测。生产路径一律用 [defaultMacroElementWaitMs]。
  final int defaultElementWaitMs;

  /// 开始回放前等入口页成为完整文档的上限；同样只为测试可调。
  final Duration entryReadyTimeout;

  bool _isCancelled = false;
  Timer? _timeoutTimer;

  WarehouseMacroReplayer({
    required this._controller,
    required this._callbacks,
    required this._l10n,
    this.defaultElementWaitMs = defaultMacroElementWaitMs,
    this.entryReadyTimeout = const Duration(seconds: 15),
  });

  /// 取消回放
  void cancel() {
    _isCancelled = true;
    _timeoutTimer?.cancel();
  }

  /// 执行整个宏录制
  Future<void> execute(WarehouseMacroRecord macro) async {
    _isCancelled = false;
    // 旧宏可能含逐字 fillField；加载时压缩，避免「已填满又重输」。
    final fullSteps = compactMacroFillSteps(macro.steps);
    if (fullSteps.isEmpty) {
      _callbacks.onComplete(false, 'macro_no_steps');
      return;
    }

    // 先把进度条摆到「第 1 / N 步」，再去等页面。
    //
    // 宿主给回放覆盖层的初始进度是 totalSteps=0，等页面这段时间会显示成
    // 「第 1 / 0 步」。同步一次真实步数，等待期间读数才是对的。
    _callbacks.onProgress(
      ReplayProgress(
        currentStepIndex: 0,
        totalSteps: fullSteps.length,
        currentStep: fullSteps.first,
        status: ReplayStepStatus.pending,
      ),
    );

    // 等入口页真的成了一个完整文档。
    //
    // 宿主是在页面第一帧就调用这里的（见屏幕侧 _startPlayback），那一刻 WebView
    // 里通常还是空白页：实测日志里「打开网页」到「回放开始」只隔 2ms，460ms 后
    // 第一步填账号就报「找不到 #userAccount」。旧实现没有这道门，等于把所有宏都
    // 建在「页面已经加载好」这个从未被保证的前提上。
    await _waitForEntryDocumentReady(macro.importUrl);
    if (_isCancelled) {
      _callbacks.onComplete(false, 'macro_user_cancelled');
      return;
    }

    final acceleratedSteps = buildAcceleratedMacroSteps(
      fullSteps,
      scriptPageUrl: macro.scriptPageUrl,
      importUrl: macro.importUrl,
    );
    final useAcceleratedPath = acceleratedSteps.length < fullSteps.length;
    debugPrint(
      'WarehouseMacroReplayer: full=${fullSteps.length} '
      'accelerated=${acceleratedSteps.length} '
      'useAccelerated=$useAcceleratedPath '
      'scriptPageUrl=${macro.scriptPageUrl} '
      'importUrl=${macro.importUrl}',
    );

    if (useAcceleratedPath) {
      final acceleratedSucceeded = await _runSteps(
        acceleratedSteps,
        // Do not notify host failure yet — full path may still succeed.
        reportFailureToHost: false,
      );
      if (acceleratedSucceeded || _isCancelled) {
        return;
      }
      // Navigate/DOM shortcut failed — fall back to the full click path.
      _callbacks.onShowTip(_l10n.macroReplayAcceleratedFallbackTip);
      // Reload the entry URL so the full click path starts from a clean page.
      final entryUrl = sanitizeWarehouseScriptPageUrl(macro.importUrl);
      if (entryUrl != null) {
        try {
          await _executeNavigate(MacroStep.navigate(entryUrl));
        } catch (_) {
          // Full path will report its own failures if reload also fails.
        }
      }
    }

    await _runSteps(fullSteps, reportFailureToHost: true);
  }

  /// Runs [steps] sequentially. Returns true when every step succeeded.
  Future<bool> _runSteps(
    List<MacroStep> steps, {
    required bool reportFailureToHost,
  }) async {
    // 上一步点击有没有把文档带走。旧宏把「点登录」记成了两次点击（按钮 + 表单），
    // 第二下要点的表单在新页面上并不存在；只有「刚翻过页」才把这种找不到当成
    // 作废步骤跳过，否则照旧如实失败（见 shouldSkipStaleClickStep）。
    var previousClickNavigated = false;
    for (var i = 0; i < steps.length; i++) {
      if (_isCancelled) {
        _callbacks.onComplete(false, 'macro_user_cancelled');
        return false;
      }

      final step = steps[i];
      _callbacks.onProgress(
        ReplayProgress(
          currentStepIndex: i,
          totalSteps: steps.length,
          currentStep: step,
          status: ReplayStepStatus.running,
        ),
      );

      final hrefBeforeStep = step.type == MacroStepType.click
          ? await _currentDocumentHref()
          : null;
      try {
        await _executeStep(step);
        if (hrefBeforeStep != null) {
          previousClickNavigated = macroDocumentChanged(
            hrefBeforeStep,
            await _currentDocumentHref(),
          );
        }
        _callbacks.onProgress(
          ReplayProgress(
            currentStepIndex: i,
            totalSteps: steps.length,
            currentStep: step,
            status: ReplayStepStatus.succeeded,
          ),
        );
      } catch (e) {
        final detail = _exceptionPayload(e);
        if (shouldSkipStaleClickStep(
          stepIsClick: step.type == MacroStepType.click,
          elementNotFound: detail.contains('macro_element_not_found'),
          previousClickNavigated: previousClickNavigated,
        )) {
          // 这一步要点的元素属于「已经翻过去的那一页」：跳过并继续。
          //
          // 必须留痕到用户可导出的导入日志里：跳过就意味着少做了一步，将来若
          // 「导入成功但数据不对」，日志要能解释是这里放过的，而不是查无实据。
          WarehouseImportSessionLog.instance.append(
            message:
                'playback skipped stale click step=${i + 1}/${steps.length} '
                'selector=${step.selector} '
                'reason=element_not_found_after_navigation',
            level: 'warn',
          );
          debugPrint(
            'WarehouseMacroReplayer: skip stale click step=${i + 1} '
            'selector=${step.selector}',
          );
          previousClickNavigated = false;
          continue;
        }
        _callbacks.onProgress(
          ReplayProgress(
            currentStepIndex: i,
            totalSteps: steps.length,
            currentStep: step,
            status: ReplayStepStatus.failed,
            errorMessage: detail,
          ),
        );
        if (reportFailureToHost) {
          _callbacks.onComplete(
            false,
            encodeServiceMessage('macro_step_failed', {
              'stepIndex': i + 1,
              'totalSteps': steps.length,
              'detail': detail,
            }),
          );
        }
        return false;
      }
    }

    if (!_isCancelled) {
      _callbacks.onComplete(true, null);
      return true;
    }
    return false;
  }

  /// 执行单步操作
  Future<void> _executeStep(MacroStep step) async {
    switch (step.type) {
      case MacroStepType.navigate:
        await _executeNavigate(step);
        break;
      case MacroStepType.fillField:
        await _executeFillField(step);
        break;
      case MacroStepType.click:
        await _executeClick(step);
        break;
      case MacroStepType.waitForUrl:
        await _executeWaitForUrl(step);
        break;
      case MacroStepType.waitForSelector:
        await _executeWaitForSelector(step);
        break;
      case MacroStepType.waitForManualInput:
        await _executeWaitForManualInput(step);
        break;
      case MacroStepType.executeScript:
        // 脚本执行由外部处理，回放引擎只标记完成
        // 实际执行由宿主屏幕处理
        break;
      case MacroStepType.delay:
        await _executeDelay(step);
        break;
    }
  }

  Future<void> _executeNavigate(MacroStep step) async {
    final url = step.value ?? '';
    if (url.isEmpty) throw Exception('macro_navigate_url_empty');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw Exception(
        encodeServiceMessage('macro_navigate_url_invalid', {'url': url}),
      );
    }

    final timeout = step.waitMs > 0 ? step.waitMs : 15000;

    // 导航前先读一次当前文档地址：判据要比的是「文档换没换」，不是「有没有读到
    // URL」。旧实现把这两件事混了：轮询条件是 currentUrl 非空，而导航前旧页面的
    // URL 本来就非空 —— 第一拍就通过，15 秒超时形同虚设，只有末尾固定 500ms 在等。
    // 更糟的是它顺手 new 了一个 NavigationDelegate，却只在它自己的 onPageFinished
    // 里 setNavigationDelegate，等于从未注册，那个 completer 也就永远完不成（而且
    // 根本没人 await 它）。这里不能提前替换代理：宿主屏幕的导航代理在驱动导入状态机。
    final beforeHref = await _currentDocumentHref();

    _controller.loadRequest(uri);

    await _pollCondition(
      check: () async {
        final document = await _currentDocumentState();
        return isTargetDocumentLoaded(
          beforeHref: beforeHref,
          currentHref: document?.$1,
          readyState: document?.$2,
          targetHref: url,
        );
      },
      timeout: Duration(milliseconds: timeout),
      stepLabel: _l10n.macroReplayNavigateTo(url),
    );

    // 额外等待确保页面完全渲染
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// 当前文档的 `location.href` 与 `document.readyState`。
  ///
  /// 导航提交的那一瞬间 JS 上下文可能不可用，或者返回的是旧文档 —— 一律回 null，
  /// 由 [_pollCondition] 下一拍重试，绝不当成「加载好了」。
  Future<(String? href, String? readyState)?> _currentDocumentState() async {
    try {
      final hrefResult = await _controller.runJavaScriptReturningResult(
        'location.href',
      );
      final readyResult = await _controller.runJavaScriptReturningResult(
        'document.readyState',
      );
      final href = _normalizeJsResult(hrefResult);
      if (href.isEmpty) return null;
      return (href, _normalizeJsResult(readyResult));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _currentDocumentHref() async {
    final state = await _currentDocumentState();
    return state?.$1;
  }

  /// 等入口网页成为完整文档；超时或被取消都不报失败。
  ///
  /// 不在这里直接判失败，是因为「入口页慢」和「这个站就是永远不 complete」
  /// 在用户眼里是两回事：后者强行报「回放失败」会让人以为宏坏了。放行之后，
  /// 每一步的等元素轮询还有自己的 10 秒预算，慢站仍然能成功。
  ///
  /// 也绝不往外抛：宿主是 `await replayer.execute(...)` 且没有 try/catch，
  /// 这里抛出去会变成一条没人处理的异步异常（界面停在转圈）。
  Future<void> _waitForEntryDocumentReady(String importUrl) async {
    if (importUrl.trim().isEmpty || _isCancelled) return;
    try {
      await _pollCondition(
        check: () async {
          final document = await _currentDocumentState();
          return isEntryDocumentReady(
            href: document?.$1,
            readyState: document?.$2,
          );
        },
        timeout: entryReadyTimeout,
        stepLabel: _l10n.macroReplayWaitPageLoad,
      );
    } catch (_) {
      // 15 秒还没 complete，或被取消：交给后续步骤 / 调用方的取消处理。
    }
  }

  Future<void> _executeFillField(MacroStep step) async {
    final selector = step.selector ?? '';
    final value = step.value ?? '';
    if (selector.isEmpty) throw Exception('macro_fill_selector_empty');

    final escapedValue = jsonEncode(value);
    await _runElementStep(
      selector: selector,
      waitMs: step.waitMs,
      spec: (candidatesJson) =>
          '''
(() => {
  const sels = $candidatesJson;
  var el = null;
  for (var i = 0; i < sels.length; i++) {
    el = document.querySelector(sels[i]);
    if (el) break;
  }
  if (!el) return JSON.stringify({found: false, selector: ${jsonEncode(selector)}});
  // 已有正确值则跳过改写，避免覆盖浏览器/记住登录的自动填充后再逐字重输。
  if (String(el.value || '') === $escapedValue) {
    return JSON.stringify({
      found: true,
      skipped: true,
      tag: el.tagName,
      type: el.type || ''
    });
  }
  el.focus();
  el.value = $escapedValue;
  el.dispatchEvent(new Event('input', { bubbles: true }));
  el.dispatchEvent(new Event('change', { bubbles: true }));
  el.dispatchEvent(new Event('blur', { bubbles: true }));
  return JSON.stringify({found: true, tag: el.tagName, type: el.type || ''});
})();
''',
    );
    // 填充后等待页面响应
    await _waitForPageReady(timeout: 15000);
  }

  Future<void> _executeClick(MacroStep step) async {
    final selector = step.selector ?? '';
    if (selector.isEmpty) throw Exception('macro_click_selector_empty');

    await _runElementStep(
      selector: selector,
      waitMs: step.waitMs,
      spec: (candidatesJson) =>
          '''
(() => {
  const sels = $candidatesJson;
  var el = null;
  for (var i = 0; i < sels.length; i++) {
    el = document.querySelector(sels[i]);
    if (el) break;
  }
  if (!el) return JSON.stringify({found: false, selector: ${jsonEncode(selector)}});
  if (typeof el.click === 'function') {
    el.click();
  } else {
    var evt = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
    el.dispatchEvent(evt);
  }
  return JSON.stringify({found: true, tag: el.tagName});
})();
''',
    );

    // 点击后等待页面加载（可能触发导航到新页）
    await _waitForPageReady(timeout: 15000);
  }

  /// 反复尝试直到脚本明确回报「找到了」，超时才报元素不存在。
  ///
  /// 旧实现是「固定等 300ms → 查一次 → 查不到就整条回放失败」：教务站首页把
  /// 表单铺出来往往要几百毫秒到几秒，慢网下这一拍必然落空，用户看到的就是
  /// 「一开场就弹失败」。现在按 [defaultMacroElementWaitMs] 的预算轮询，慢站也能过；
  /// 只有整个预算用完还查不到，才算真的没有这个元素。
  ///
  /// [spec] 接收候选选择器的 JSON 数组文本（见 [macroSelectorCandidates]），
  /// 返回要执行的脚本；脚本必须回 `{found: true|false}` 形态的 JSON。
  Future<void> _runElementStep({
    required String selector,
    required int waitMs,
    required String Function(String candidatesJson) spec,
  }) async {
    final candidatesJson = jsonEncode(macroSelectorCandidates(selector));
    final js = spec(candidatesJson);
    final budget = Duration(
      milliseconds: waitMs > 0 ? waitMs : defaultElementWaitMs,
    );
    final deadline = DateTime.now().add(budget);

    while (DateTime.now().isBefore(deadline)) {
      if (_isCancelled) throw Exception('macro_user_cancelled');
      try {
        final normalized = _normalizeJsResult(
          await _controller.runJavaScriptReturningResult(js),
        );
        if (macroElementFound(normalized)) return;
      } catch (_) {
        // 导航进行中 JS 上下文会被销毁，这一拍读不到属正常，继续轮询。
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }

    throw Exception(
      encodeServiceMessage('macro_element_not_found', {'selector': selector}),
    );
  }

  Future<void> _executeWaitForUrl(MacroStep step) async {
    final pattern = step.value ?? '';
    if (pattern.isEmpty) throw Exception('macro_url_pattern_empty');

    await _pollCondition(
      check: () async {
        try {
          final currentUrl = await _controller.currentUrl();
          if (currentUrl == null || currentUrl.isEmpty) return false;
          // 支持子串匹配
          return currentUrl.contains(pattern);
        } catch (_) {
          return false;
        }
      },
      timeout: Duration(milliseconds: step.waitMs > 0 ? step.waitMs : 15000),
      stepLabel: _l10n.macroReplayWaitUrlPattern(pattern),
    );
  }

  Future<void> _executeWaitForSelector(MacroStep step) async {
    final selector = step.selector ?? '';
    if (selector.isEmpty) throw Exception('macro_wait_selector_empty');

    await _pollCondition(
      check: () async {
        try {
          final result = await _controller.runJavaScriptReturningResult('''
document.querySelector(${jsonEncode(selector)}) !== null
''');
          return _normalizeJsResult(result) == 'true';
        } catch (_) {
          return false;
        }
      },
      timeout: Duration(milliseconds: step.waitMs > 0 ? step.waitMs : 15000),
      stepLabel: _l10n.macroReplayWaitSelector(selector),
    );

    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _executeWaitForManualInput(MacroStep step) async {
    final reason = step.value ?? 'macro_manual_input_default';
    final shouldContinue = await _callbacks.onPauseForManualInput(step, reason);
    if (!shouldContinue) {
      throw Exception('macro_user_cancelled');
    }
  }

  Future<void> _executeDelay(MacroStep step) async {
    final ms = step.waitMs > 0 ? step.waitMs : 1000;
    await Future.delayed(Duration(milliseconds: ms));
  }

  /// 等待页面完全加载（URL 非空 + 加载完成 + 额外渲染时间）
  Future<void> _waitForPageReady({int timeout = 20000}) async {
    // 等待页面 URL 出现
    await _pollCondition(
      check: () async {
        try {
          final url = await _controller.currentUrl();
          return url != null && url.isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      timeout: Duration(milliseconds: timeout),
      stepLabel: _l10n.macroReplayWaitPageLoad,
    );

    // 等待页面 DOM 完全就绪（document.readyState === 'complete'）
    try {
      await _pollCondition(
        check: () async {
          final result = await _controller.runJavaScriptReturningResult(
            'document.readyState',
          );
          final state = _normalizeJsResult(result);
          return state == 'complete';
        },
        timeout: const Duration(milliseconds: 15000),
        stepLabel: _l10n.macroReplayWaitDomReady,
      );
    } catch (_) {
      // 超时了也继续，DOM readyState 可能受 iframe 影响
    }

    // 额外等待确保 DOM 完全渲染
    await Future.delayed(const Duration(milliseconds: 800));
  }

  /// 轮询直到条件满足或超时
  Future<void> _pollCondition({
    required Future<bool> Function() check,
    required Duration timeout,
    required String stepLabel,
  }) async {
    final deadline = DateTime.now().add(timeout);
    var lastError = '';

    while (DateTime.now().isBefore(deadline)) {
      if (_isCancelled) throw Exception('macro_user_cancelled');

      try {
        final satisfied = await check();
        if (satisfied) return;
        lastError = '';
      } catch (e) {
        lastError = '$e';
      }

      await Future.delayed(const Duration(milliseconds: 300));
    }

    throw Exception(
      encodeServiceMessage('macro_poll_timeout', {
        'stepLabel': stepLabel,
        'timeoutSeconds': timeout.inSeconds,
        'lastError': lastError.isNotEmpty ? ': $lastError' : '',
      }),
    );
  }
}

String _exceptionPayload(Object error) {
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return error.toString();
}

/// 回放 UI 状态
enum PlaybackUiState {
  hidden,
  playing,
  pausedForInput,
  executingImport,
  finished,
  error,
}

/// 脚本明确回报「没找到」时抛出 [errorMessage]；读不懂的返回值一律放过。
///
/// 口径与轮询路径分开：这里读不懂 ≠ 没找到（不能凭空报错），轮询里读不懂 ≠ 找到
/// （必须继续等）。两份判据都在 `domain/warehouse_macro_replay_logic.dart` 里。
@visibleForTesting
void ensureMacroElementFound(String normalizedResult, String errorMessage) {
  if (macroElementExplicitlyMissing(normalizedResult)) {
    throw Exception(errorMessage);
  }
}

bool shouldUseRememberedPasswordForManualStep(
  MacroStep step,
  String reason,
  AppLocalizations l10n,
) {
  final lowerReason = reason.toLowerCase();
  final looksLikeCaptcha =
      step.fieldType == 'captcha' ||
      reason.contains('验证码') ||
      reason.contains('校验码') ||
      lowerReason.contains('captcha') ||
      lowerReason.contains('verification');
  if (looksLikeCaptcha) {
    return false;
  }
  return step.fieldType == 'password' ||
      (step.fieldType == null || step.fieldType!.isEmpty) &&
          (reason.contains('密码') ||
              lowerReason.contains('password') ||
              lowerReason.contains('pwd') ||
              reason == l10n.macroReplayManualActionRequired);
}

/// 标准化 JS 返回值。
///
/// 口径与屏幕侧统一到一个实现里（`normalizeWebScriptResult`）：平台把字符串型
/// 返回值按 JSON 编码送回，必须整体解码才能还原 `\"`。旧实现只切首尾引号，
/// 留下 `{\\"found\\":false}` 这种半截转义，`ensureMacroElementFound` 里的
/// `jsonDecode` 必然抛 → 被 `on FormatException` 当成「非 JSON，忽略」→
/// 填充/点击没找到元素却被判成功，宏继续往下跑。
String _normalizeJsResult(Object? raw) => normalizeWebScriptResult(raw);
