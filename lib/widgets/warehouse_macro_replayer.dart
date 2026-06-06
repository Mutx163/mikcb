import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/warehouse_macro_models.dart';

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

  String get statusLabel {
    switch (status) {
      case ReplayStepStatus.running:
        return _stepTypeLabel(currentStep.type);
      case ReplayStepStatus.failed:
        return '失败: $errorMessage';
      case ReplayStepStatus.pausedForInput:
        return '等待手动操作: ${pauseReason ?? ""}';
      case ReplayStepStatus.pending:
      case ReplayStepStatus.succeeded:
        return '';
    }
  }

  static String _stepTypeLabel(MacroStepType type) {
    switch (type) {
      case MacroStepType.navigate:
        return '正在导航...';
      case MacroStepType.fillField:
        return '正在填充表单...';
      case MacroStepType.click:
        return '正在点击...';
      case MacroStepType.waitForUrl:
        return '等待页面跳转...';
      case MacroStepType.waitForSelector:
        return '等待页面元素...';
      case MacroStepType.waitForManualInput:
        return '等待用户操作';
      case MacroStepType.executeScript:
        return '正在执行导入脚本...';
      case MacroStepType.delay:
        return '等待中...';
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
  bool _isCancelled = false;
  Timer? _timeoutTimer;

  WarehouseMacroReplayer({
    required WebViewController controller,
    required ReplayCallbacks callbacks,
  }) : _controller = controller,
       _callbacks = callbacks;

  /// 取消回放
  void cancel() {
    _isCancelled = true;
    _timeoutTimer?.cancel();
  }

  /// 执行整个宏录制
  Future<void> execute(WarehouseMacroRecord macro) async {
    _isCancelled = false;
    final steps = macro.steps;
    if (steps.isEmpty) {
      _callbacks.onComplete(false, '没有录制的步骤');
      return;
    }

    for (var i = 0; i < steps.length; i++) {
      if (_isCancelled) {
        _callbacks.onComplete(false, '用户取消');
        return;
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
        _callbacks.onProgress(
          ReplayProgress(
            currentStepIndex: i,
            totalSteps: steps.length,
            currentStep: step,
            status: ReplayStepStatus.failed,
            errorMessage: '$e',
          ),
        );
        _callbacks.onComplete(false, '第 ${i + 1}/${steps.length} 步失败: $e');
        return;
      }
    }

    if (!_isCancelled) {
      _callbacks.onComplete(true, null);
    }
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
    if (url.isEmpty) throw Exception('导航 URL 为空');
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('无效的 URL: $url');
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
      stepLabel: '导航到 $url',
    );

    // 额外等待确保页面完全渲染
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _executeFillField(MacroStep step) async {
    final selector = step.selector ?? '';
    final value = step.value ?? '';
    if (selector.isEmpty) throw Exception('填充字段的选择器为空');

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
    ensureMacroElementFound(normalized, '未找到表单字段: $selector');
    // 填充后等待页面响应
    await _waitForPageReady(timeout: 15000);
  }

  Future<void> _executeClick(MacroStep step) async {
    final selector = step.selector ?? '';
    if (selector.isEmpty) throw Exception('点击元素的选择器为空');

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
    ensureMacroElementFound(normalized, '未找到点击元素: $selector');

    // 点击后等待页面加载（可能触发导航到新页）
    await _waitForPageReady(timeout: 15000);
  }

  Future<void> _executeWaitForUrl(MacroStep step) async {
    final pattern = step.value ?? '';
    if (pattern.isEmpty) throw Exception('URL 模式为空');

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
      stepLabel: '等待 URL 匹配: $pattern',
    );
  }

  Future<void> _executeWaitForSelector(MacroStep step) async {
    final selector = step.selector ?? '';
    if (selector.isEmpty) throw Exception('等待元素的选择器为空');

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
      stepLabel: '等待元素: $selector',
    );

    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _executeWaitForManualInput(MacroStep step) async {
    final reason = step.value ?? '需要手动操作';
    final shouldContinue = await _callbacks.onPauseForManualInput(step, reason);
    if (!shouldContinue) {
      throw Exception('用户取消');
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
      stepLabel: '等待页面加载',
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
        stepLabel: '等待 DOM 就绪',
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
      if (_isCancelled) throw Exception('用户取消');

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
      '$stepLabel 超时（${timeout.inSeconds}秒）${lastError.isNotEmpty ? ": $lastError" : ""}',
    );
  }
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
