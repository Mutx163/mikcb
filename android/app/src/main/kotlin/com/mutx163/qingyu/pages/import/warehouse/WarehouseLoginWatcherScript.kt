package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.MiniJson

/**
 * 登录页的**页面内观察脚本**：采集「用户正在敲的账号密码」与「是否点了登录」，
 * 并提供原生侧把记住的凭据填回去的入口。
 *
 * ## 为什么需要它
 *
 * 「记住账号 / 密码」这条链路在 Compose 侧以前整段没接：没有采集就没有候选账号
 * （`candidateAccount` 恒空 ⇒ `shouldPromptSave` 恒假 ⇒「记住密码」卡片永远不出现），
 * 也没有办法把已存的凭据填进网页。Dart 用宿主注入的观察脚本做这件事
 * （`warehouse_adapter_web_login_screen.dart` 的 `_installLoginWatcher`），这里对齐它的口径：
 *
 * | 事件 | 回传 |
 * |---|---|
 * | `input` / `change` / DOM 变化 / 定时补采 | `loginState`（账号、口令、有无密码框） |
 * | 点「登录 / 提交」类按钮、表单提交 | `loginAttempt`（只在真的尝试登录后问「记住密码」） |
 *
 * 采集值只在**内存**里用（判断要不要提示），既不落盘也不进日志：口令从源头就不该多留一份。
 *
 * ## 安全取舍
 *
 * - 桥对象名与 Dart 逐字一致（[BRIDGE_OBJECT]），否则页面里的 `postMessage` 会静默失效；
 * - 回传走的是页面已注册的原生通道，宿主侧仍有 §6.2 门禁（`loginAttempt` 只认受信 host /
 *   执行期 / 录制态），本脚本不是信任锚点；
 * - 脚本自身**幂等**：用 `window.__qingyuLoginWatcherInstalled` 哨兵，每个页面重复注入只装一次。
 */
object WarehouseLoginWatcherJs {

    /** 页面里可用的桥对象名（`addJavascriptInterface` 注册的那个，与 Dart 通道名一致）。 */
    const val BRIDGE_OBJECT = "QingyuBridge"

    /**
     * 安装观察脚本 + 暴露填充入口；**可重复注入**（哨兵挡住重复安装）。
     *
     * 只碰 `input` 元素，不读取页面其它内容；所有异常在脚本内吞掉，
     * 不让观察脚本把学校自己的登录页搞挂。
     */
    val INSTALL_SCRIPT: String = """
(() => {
  const bridge = window.$BRIDGE_OBJECT;
  if (!bridge || typeof bridge.postMessage !== 'function') return;
  const post = (payload) => {
    try { bridge.postMessage(JSON.stringify(payload)); } catch (e) {}
  };
  const textInput = () => Array.from(document.querySelectorAll('input')).filter((i) => {
    const t = (i.type || 'text').toLowerCase();
    return ['text', 'email', 'tel', 'number'].indexOf(t) !== -1 && !i.disabled;
  })[0];
  const passwordInput = () => Array.from(document.querySelectorAll('input[type="password"]')).filter((i) => !i.disabled)[0];
  const setValue = (el, value) => {
    if (!el) return false;
    try {
      const proto = el.tagName === 'TEXTAREA' ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
      const descriptor = Object.getOwnPropertyDescriptor(proto, 'value');
      if (descriptor && descriptor.set) {
        descriptor.set.call(el, value);
      } else {
        el.value = value;
      }
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
      return true;
    } catch (e) {
      return false;
    }
  };
  const collect = () => {
    const account = textInput();
    const password = passwordInput();
    post({
      type: 'loginState',
      username: account ? String(account.value || '') : '',
      password: password ? String(password.value || '') : '',
      hasPasswordField: !!password
    });
  };
  window.__qingyuCollectLoginState = collect;
  window.__qingyuAutofillLogin = (username, password) => {
    let filled = false;
    if (username) { filled = setValue(textInput(), String(username)) || filled; }
    if (password) { filled = setValue(passwordInput(), String(password)) || filled; }
    return filled;
  };
  if (!window.__qingyuLoginWatcherInstalled) {
    window.__qingyuLoginWatcherInstalled = true;
    document.addEventListener('input', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('change', (event) => {
      if (event.target && event.target.tagName === 'INPUT') collect();
    }, true);
    document.addEventListener('click', (event) => {
      const target = event.target;
      if (!(target instanceof HTMLElement)) return;
      const text = (target.innerText || target.textContent || target.value || '').trim().toLowerCase();
      if (/登录|login|sign in|signin|进入教务|提交/.test(text)) {
        collect();
        post({ type: 'loginAttempt' });
      }
    }, true);
    document.addEventListener('submit', () => {
      collect();
      post({ type: 'loginAttempt' });
    }, true);
    let timer = null;
    const schedule = () => {
      window.clearTimeout(timer);
      timer = window.setTimeout(collect, 120);
    };
    try {
      new MutationObserver(schedule).observe(document.documentElement || document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['type', 'disabled', 'style', 'class']
      });
    } catch (e) {}
  }
  collect();
  window.setTimeout(collect, 0);
  window.setTimeout(collect, 300);
})();
""".trimIndent()

    /** 主动补采一次（进入页面 / 页面跳转完成后调）。 */
    const val COLLECT_SCRIPT: String =
        "window.__qingyuCollectLoginState && window.__qingyuCollectLoginState();"
}

/**
 * 把记住的账号密码填进当前页面的 JS。
 *
 * 口令是**不可信拼串风险最高**的那类输入（用户可能设了带引号/反斜杠的密码），
 * 所以一律经 [MiniJson.encode] 转成 JSON 字面量再拼，绝不直接字符串插值——
 * 否则一个含 `"` 的密码就能把注入脚本截断成任意 JS。
 */
fun warehouseAutofillLoginScript(login: WarehouseRememberedLogin): String =
    "window.__qingyuAutofillLogin && window.__qingyuAutofillLogin(" +
        MiniJson.encode(login.username) + ", " + MiniJson.encode(login.password) + ");"
