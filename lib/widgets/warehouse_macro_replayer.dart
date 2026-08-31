import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:university_timetable/l10n/app_localizations.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:university_timetable/l10n/service_message_localizer.dart';

import '../models/warehouse_macro_models.dart';
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
  bool _isCancelled = false;
  Timer? _timeoutTimer;

  WarehouseMacroReplayer({
    required this._controller,
    required this._callbacks,
    required this._l10n,
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

      try {
        await _executeStep(step);
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

    final completer = Completer<void>();
    final timeout = step.waitMs > 0 ? step.waitMs : 15000;

    late final NavigationDelegate delegate;
    delegate = NavigationDelegate(
      onPageFinished: (url) {
        _controller.setNavigationDelegate(delegate); // no-op, just to keep ref
        if (!completer.isCompleted) completer.complete();
      },
    );

    // 替换导航代理来监听完成
    // 但由于无法直接替换，改用轮询方式
    _controller.loadRequest(uri);

    // 轮询等待页面加载
    await _pollCondition(
      check: () async {
        try {
          final currentUrl = await _controller.currentUrl();
          return currentUrl != null && currentUrl.isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      timeout: Duration(milliseconds: timeout),
      stepLabel: _l10n.macroReplayNavigateTo(url),
    );

    // 额外等待确保页面完全渲染
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _executeFillField(MacroStep step) async {
    final selector = step.selector ?? '';
    final value = step.value ?? '';
    if (selector.isEmpty) throw Exception('macro_fill_selector_empty');

    // 先等待一下确保元素存在
    await Future.delayed(const Duration(milliseconds: 300));

    final escapedValue = jsonEncode(value);
    final js =
        '''
(() => {
  var el = document.querySelector(${jsonEncode(selector)});
  if (!el) {
    // 尝试用 name 属性查找
    el = document.querySelector('input[name="${selector.split('"').join('\\"')}"]');
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
''';

    final result = await _controller.runJavaScriptReturningResult(js);
    final normalized = _normalizeJsResult(result);
    ensureMacroElementFound(
      normalized,
      encodeServiceMessage('macro_element_not_found', {'selector': selector}),
    );
    // 填充后等待页面响应
    await _waitForPageReady(timeout: 15000);
  }

  Future<void> _executeClick(MacroStep step) async {
    final selector = step.selector ?? '';
    if (selector.isEmpty) throw Exception('macro_click_selector_empty');

    await Future.delayed(const Duration(milliseconds: 200));

    final js =
        '''
(() => {
  var el = document.querySelector(${jsonEncode(selector)});
  if (!el) return JSON.stringify({found: false, selector: ${jsonEncode(selector)}});
  if (typeof el.click === 'function') {
    el.click();
  } else {
    var evt = new MouseEvent('click', { bubbles: true, cancelable: true, view: window });
    el.dispatchEvent(evt);
  }
  return JSON.stringify({found: true, tag: el.tagName});
})();
''';

    final result = await _controller.runJavaScriptReturningResult(js);
    final normalized = _normalizeJsResult(result);
    ensureMacroElementFound(
      normalized,
      encodeServiceMessage('macro_element_not_found', {'selector': selector}),
    );

    // 点击后等待页面加载（可能触发导航到新页）
    await _waitForPageReady(timeout: 15000);
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

@visibleForTesting
void ensureMacroElementFound(String normalizedResult, String errorMessage) {
  try {
    final decoded = jsonDecode(normalizedResult);
    if (decoded is Map && decoded['found'] == false) {
      throw Exception(errorMessage);
    }
  } on FormatException {
    return;
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

/// 标准化 JS 返回值
String _normalizeJsResult(Object? raw) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  // webview_flutter 有时会用引号包裹返回值
  if (s.length >= 2 &&
      ((s.startsWith('"') && s.endsWith('"')) ||
          (s.startsWith("'") && s.endsWith("'")))) {
    return s.substring(1, s.length - 1);
  }
  return s;
}
