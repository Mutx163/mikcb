import '../models/warehouse_macro_models.dart';

/// 录制 JS —— 注入到 WebView 中捕获用户交互
class MacroRecorderJs {
  /// 生成用于注入的录制脚本。
  /// 该脚本会在每个页面加载后注入，监听用户操作并通过 QingyuBridge 发送回 Flutter。
  static String get injectScript => '''
(() => {
  if (window.__qingyuMacroRecorderInstalled) return;
  window.__qingyuMacroRecorderInstalled = true;
  window.__qingyuMacroRecordedSteps = [];

  function _macroMakeSelector(el) {
    if (!el || el === document.body) return 'body';
    if (el.id) return '#' + CSS.escape(el.id);
    var tag = el.tagName.toLowerCase();
    if (el.name) return tag + '[name="' + CSS.escape(el.name) + '"]';
    var parent = el.parentElement;
    if (parent) {
      var siblings = Array.from(parent.children).filter(function(c) { return c.tagName === el.tagName; });
      if (siblings.length > 1) {
        var idx = siblings.indexOf(el) + 1;
        return _macroMakeSelector(parent) + ' > ' + tag + ':nth-of-type(' + idx + ')';
      }
      return _macroMakeSelector(parent) + ' > ' + tag;
    }
    return tag;
  }

  function _macroGetFieldType(input) {
    var type = (input.type || 'text').toLowerCase();
    if (type === 'password') return 'password';
    var name = (input.name || '').toLowerCase();
    var id = (input.id || '').toLowerCase();
    var placeholder = (input.placeholder || '').toLowerCase();
    var ariaLabel = (input.getAttribute('aria-label') || '').toLowerCase();
    var combined = name + ' ' + id + ' ' + placeholder + ' ' + ariaLabel;
    var looksLikeVerificationCode = combined.indexOf('code') !== -1 &&
      (combined.indexOf('verify') !== -1 || combined.indexOf('verification') !== -1 ||
       combined.indexOf('captcha') !== -1 || combined.indexOf('auth') !== -1 ||
       combined.indexOf('sms') !== -1 || combined.indexOf('login') !== -1);
    if (combined.indexOf('验证码') !== -1 || combined.indexOf('校验码') !== -1 || combined.indexOf('captcha') !== -1 || combined.indexOf('verification') !== -1 || looksLikeVerificationCode) return 'captcha';
    if (combined.indexOf('user') !== -1 || combined.indexOf('学号') !== -1 || combined.indexOf('账号') !== -1 || combined.indexOf('account') !== -1 || combined.indexOf('username') !== -1) return 'username';
    if (combined.indexOf('pwd') !== -1 || combined.indexOf('密码') !== -1 || combined.indexOf('password') !== -1) return 'password';
    return 'other';
  }

  function _macroIsSensitiveFieldType(fieldType) {
    return fieldType === 'password' || fieldType === 'captcha';
  }

  function _macroEmit(entry) {
    window.__qingyuMacroRecordedSteps.push(entry);
    try {
      QingyuBridge.postMessage(JSON.stringify({
        type: 'macro:event',
        payload: JSON.stringify(entry)
      }));
    } catch(e) {}
  }

  document.addEventListener('input', function(e) {
    var el = e.target;
    if (!el || !el.tagName || el.tagName !== 'INPUT') return;
    if (el.disabled || el.readOnly) return;
    var selector = _macroMakeSelector(el);
    var fieldType = _macroGetFieldType(el);
    _macroEmit({
      eventType: 'input',
      selector: selector,
      value: _macroIsSensitiveFieldType(fieldType) ? '' : el.value,
      fieldType: fieldType,
      timestamp: Date.now()
    });
  }, true);

  document.addEventListener('change', function(e) {
    var el = e.target;
    if (!el || !el.tagName || el.tagName !== 'INPUT') return;
    if (el.disabled || el.readOnly) return;
    if (el.type === 'file') return;
    var selector = _macroMakeSelector(el);
    var fieldType = _macroGetFieldType(el);
    _macroEmit({
      eventType: 'change',
      selector: selector,
      value: _macroIsSensitiveFieldType(fieldType) ? '' : el.value,
      fieldType: fieldType,
      timestamp: Date.now()
    });
  }, true);

  document.addEventListener('click', function(e) {
    var el = e.target;
    if (!el) return;
    var tag = (el.tagName || '').toLowerCase();
    if (tag === 'input') {
      var inputType = (el.type || '').toLowerCase();
      if (inputType === 'submit' || inputType === 'button') {
        var selector = _macroMakeSelector(el);
        var text = el.value || '';
        _macroEmit({
          eventType: 'click',
          selector: selector,
          value: text,
          fieldType: 'button',
          timestamp: Date.now()
        });
      }
      return;
    }
    var triggerTags = ['a', 'button', 'select'];
    if (triggerTags.indexOf(tag) === -1) {
      var parent = el.closest('a, button, [role="button"], [onclick]');
      if (!parent) return;
      el = parent;
    }
    var selector = _macroMakeSelector(el);
    var text = (el.innerText || el.textContent || el.getAttribute('aria-label') || '').trim().substring(0, 50);
    _macroEmit({
      eventType: 'click',
      selector: selector,
      value: text,
      fieldType: 'link',
      timestamp: Date.now()
    });
  }, true);

  document.addEventListener('submit', function(e) {
    var form = e.target;
    if (!form || !form.tagName || form.tagName !== 'FORM') return;
    var selector = _macroMakeSelector(form);
    _macroEmit({
      eventType: 'submit',
      selector: selector,
      fieldType: 'form',
      timestamp: Date.now()
    });
  }, true);
})();
''';

  /// 用于获取所有记录的步骤（供停止录制时导出）
  static String get dumpScript => '''
(() => {
  try {
    return JSON.stringify(window.__qingyuMacroRecordedSteps || []);
  } catch(e) {
    return '[]';
  }
})();
''';
}

/// 录制结果：从录制 JS 事件流转换为一组 MacroStep
class MacroRecordingConverter {
  /// 将原始录制事件列表转换为 MacroStep 列表。
  /// 同时根据事件时间戳自动插入合适的 delay 步。
  static List<MacroStep> convert(List<Map<String, dynamic>> rawEvents) {
    if (rawEvents.isEmpty) return [];

    final dedupedEvents = _dedupeRawEvents(rawEvents);
    if (dedupedEvents.isEmpty) return [];

    final steps = <MacroStep>[];
    final sensitiveSelectors = <String>{};
    final startTime = dedupedEvents.first['timestamp'] as num? ?? 0;
    var lastTimestamp = startTime;

    for (final event in dedupedEvents) {
      final eventType = event['eventType'] as String? ?? '';
      final selector = event['selector'] as String? ?? '';
      final value = event['value'] as String? ?? '';
      final fieldType = event['fieldType'] as String?;
      final timestamp = (event['timestamp'] as num?) ?? lastTimestamp;

      // 如果事件间隔超过 1.5 秒，插入一个 delay 步
      final gap = timestamp - lastTimestamp;
      if (gap > 1500 && gap < 60000) {
        // 如果间隔在 1.5~5 秒之间，精确记录
        if (gap <= 5000) {
          steps.add(MacroStep.delay(gap.toInt()));
        } else {
          // 超过 5 秒，记一个 3 秒标准等待
          steps.add(MacroStep.delay(3000));
        }
      }

      switch (eventType) {
        case 'input':
        case 'change':
          if (isSensitiveMacroFieldType(fieldType)) {
            final sensitiveKey = selector.isNotEmpty
                ? selector
                : fieldType ?? '';
            if (sensitiveKey.isNotEmpty &&
                sensitiveSelectors.add(sensitiveKey)) {
              steps.add(
                MacroStep.waitForManualInput(
                  manualInputReasonForFieldType(fieldType),
                  selector: selector,
                  fieldType: fieldType,
                ),
              );
            }
          } else if (selector.isNotEmpty) {
            steps.add(
              MacroStep.fillField(
                selector: selector,
                value: value,
                fieldType: fieldType,
              ),
            );
          }
          break;
        case 'click':
          if (selector.isNotEmpty) {
            steps.add(MacroStep.click(selector));
          }
          break;
        case 'submit':
          // 表单提交通常需要等待页面导航
          if (selector.isNotEmpty) {
            steps.add(MacroStep.click(selector));
          }
          steps.add(MacroStep.delay(2000));
          break;
      }

      lastTimestamp = timestamp;
    }

    return steps;
  }

  static List<Map<String, dynamic>> _dedupeRawEvents(
    List<Map<String, dynamic>> rawEvents,
  ) {
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final event in rawEvents) {
      final key = [
        event['timestamp'] ?? '',
        event['eventType'] ?? '',
        event['selector'] ?? '',
        event['fieldType'] ?? '',
        event['value'] ?? '',
      ].join('|');
      if (seen.add(key)) {
        deduped.add(event);
      }
    }
    return deduped;
  }

  /// 从录制事件列表中提取登录信息（用于后续回放时覆盖）
  static Map<String, String> extractLoginCredentials(
    List<Map<String, dynamic>> rawEvents,
  ) {
    String? username, password;
    for (final event in rawEvents) {
      final ft = event['fieldType'] as String?;
      final value = event['value'] as String? ?? '';
      if (ft == 'username' && value.isNotEmpty) {
        username = value;
      } else if (ft == 'password' && value.isNotEmpty) {
        password = value;
      }
    }
    return {
      if (username != null) 'username': username,
      if (password != null) 'password': password,
    };
  }
}
