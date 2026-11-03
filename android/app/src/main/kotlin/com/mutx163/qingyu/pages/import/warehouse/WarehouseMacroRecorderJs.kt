package com.mutx163.qingyu.pages.import.warehouse

/**
 * 宏录制 JS（I2-4）——逐字移植 Dart `lib/widgets/warehouse_macro_recorder.dart` 的
 * `MacroRecorderJs.injectScript` / `dumpScript`。
 *
 * - [INJECT_SCRIPT]：录制期注入 WebView（每次页面加载完成后都要重注，JS 上下文随导航重建），
 *   监听 input / change / click / submit，事件经 `QingyuBridge` 发 `macro:event` 回原生，
 *   同时留在 `window.__qingyuMacroRecordedSteps` 缓冲里（桥不可用时停止录制的 dump 能补收）。
 * - [DUMP_SCRIPT]：停止录制时把缓冲里剩余事件整体取回。
 *
 * ⚠️ 敏感字段（password / captcha）的 `value` 在 JS 侧就发空串——**密码不进事件流**，
 * 这是脱敏的第一道（第二道在模型层 `WarehouseMacroStep.toJson`）。改这里要两边对齐。
 */
object WarehouseMacroRecorderJs {

    /** 注入脚本：幂等（`__qingyuMacroRecorderInstalled` 守卫），可重复注入。 */
    const val INJECT_SCRIPT: String = """
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
    // 教务站常见的规避手法是把 type 改成 text、name 换成混淆串（kmbm 一类）。
    // autocomplete 是标准属性，current-password / new-password 出现即口令框，
    // 把它并进来不会误伤普通字段（这些 token 只由页面自己声明用途）。
    var autocomplete = (input.getAttribute('autocomplete') || '').toLowerCase();
    var combined = name + ' ' + id + ' ' + placeholder + ' ' + ariaLabel + ' ' + autocomplete;
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

  /// 元素所属表单的选择器；不在表单里（或页面用 div 假扮表单）时返回 ''。
  function _macroFormSelector(el) {
    try {
      var form = el && el.form ? el.form : (el ? el.closest('form') : null);
      return form ? _macroMakeSelector(form) : '';
    } catch (e) {
      return '';
    }
  }

  function _macroEmit(entry) {
    window.__qingyuMacroRecordedSteps.push(entry);
    try {
      QingyuBridge.postMessage(JSON.stringify({
        type: 'macro:event',
        payload: JSON.stringify(entry)
      }));
    } catch(e) {
      // bridge 不可用时事件仍留在 window 缓冲，停止录制时的 dumpScript
      // 会补收；console.warn 留痕便于排查「录完是空的」类反馈。
      console.warn('[qingyu-macro] bridge postMessage failed:', e);
    }
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
          // 点提交按钮会连带触发所属表单的 submit 事件；把表单选择器带上，
          // 转换时才知道「后面那条 submit 是同一次动作的重复」（见 convert()）。
          formSelector: _macroFormSelector(el),
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
"""

    /** 取回 `window.__qingyuMacroRecordedSteps` 缓冲里剩余的全部事件（JSON 数组文本）。 */
    const val DUMP_SCRIPT: String = """
(() => {
  try {
    return JSON.stringify(window.__qingyuMacroRecordedSteps || []);
  } catch(e) {
    return '[]';
  }
})();
"""
}
