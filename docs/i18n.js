/**
 * 官网多语言：与 App 对齐（简体中文 / 繁體香港 / 繁體台灣 / English / 日本語 / 한국어）
 * - 默认：localStorage 记忆 > 浏览器语言匹配 > 简体中文
 * - 右上角语言切换器由本脚本注入 .nav-actions 或 body
 */
(function initSiteI18n() {
  const STORAGE_KEY = "mikcb-site-locale";
  const DEFAULT_LOCALE = "zh-CN";
  const SUPPORTED = [
    { id: "zh-CN", htmlLang: "zh-CN", ogLocale: "zh_CN", nativeName: "简体中文" },
    { id: "zh-HK", htmlLang: "zh-HK", ogLocale: "zh_HK", nativeName: "繁體中文（香港）" },
    { id: "zh-TW", htmlLang: "zh-TW", ogLocale: "zh_TW", nativeName: "繁體中文（台灣）" },
    { id: "en", htmlLang: "en", ogLocale: "en_US", nativeName: "English" },
    { id: "ja", htmlLang: "ja", ogLocale: "ja_JP", nativeName: "日本語" },
    { id: "ko", htmlLang: "ko", ogLocale: "ko_KR", nativeName: "한국어" },
  ];
  const SUPPORTED_IDS = SUPPORTED.map((item) => item.id);

  /** @type {Record<string, Record<string, string>>} */
  let catalogs = {};
  /** @type {string} */
  let currentLocale = DEFAULT_LOCALE;
  /** @type {Set<(locale: string) => void>} */
  const changeListeners = new Set();
  let remainingCatalogsPrefetched = false;

  function getLocaleMeta(localeId) {
    return SUPPORTED.find((item) => item.id === localeId) || SUPPORTED[0];
  }

  function normalizeBrowserTag(tag) {
    return String(tag || "")
      .trim()
      .replace(/_/g, "-");
  }

  function matchSupportedLocale(rawTag) {
    const tag = normalizeBrowserTag(rawTag);
    if (!tag) {
      return null;
    }
    const lower = tag.toLowerCase();

    if (SUPPORTED_IDS.includes(tag)) {
      return tag;
    }
    if (SUPPORTED_IDS.includes(lower)) {
      return lower;
    }

    // zh-Hans / zh-CN / zh → 简体
    if (/^zh(-hans)?(-cn)?$/i.test(lower) || lower === "zh-sg" || lower === "zh-my") {
      return "zh-CN";
    }
    // 香港
    if (/^zh(-hant)?-hk$/i.test(lower) || lower === "zh-hk") {
      return "zh-HK";
    }
    // 台湾 / 澳门等繁体
    if (
      /^zh(-hant)?(-tw)?$/i.test(lower) ||
      lower === "zh-tw" ||
      lower === "zh-mo" ||
      lower === "zh-hant"
    ) {
      return "zh-TW";
    }
    if (lower.startsWith("en")) {
      return "en";
    }
    if (lower.startsWith("ja")) {
      return "ja";
    }
    if (lower.startsWith("ko")) {
      return "ko";
    }
    return null;
  }

  function detectLocale() {
    try {
      const stored = window.localStorage?.getItem(STORAGE_KEY);
      const fromStore = matchSupportedLocale(stored);
      if (fromStore) {
        return fromStore;
      }
    } catch {
      /* ignore */
    }

    const candidates = [];
    if (Array.isArray(navigator.languages)) {
      candidates.push(...navigator.languages);
    }
    if (navigator.language) {
      candidates.push(navigator.language);
    }
    for (const candidate of candidates) {
      const matched = matchSupportedLocale(candidate);
      if (matched) {
        return matched;
      }
    }
    return DEFAULT_LOCALE;
  }

  function t(key, vars) {
    const dict = catalogs[currentLocale] || catalogs[DEFAULT_LOCALE] || {};
    const fallback = catalogs[DEFAULT_LOCALE] || {};
    let text = dict[key] ?? fallback[key] ?? key;
    if (vars && typeof vars === "object") {
      Object.keys(vars).forEach((name) => {
        text = text.replaceAll(`{${name}}`, String(vars[name]));
      });
    }
    return text;
  }

  function applyAttributes(element) {
    const attrSpec = element.getAttribute("data-i18n-attr");
    if (!attrSpec) {
      return;
    }
    attrSpec.split(";").forEach((pair) => {
      const trimmed = pair.trim();
      if (!trimmed) {
        return;
      }
      const colonIndex = trimmed.indexOf(":");
      if (colonIndex <= 0) {
        return;
      }
      const attrName = trimmed.slice(0, colonIndex).trim();
      const messageKey = trimmed.slice(colonIndex + 1).trim();
      if (attrName && messageKey) {
        element.setAttribute(attrName, t(messageKey));
      }
    });
  }

  function applyElement(element) {
    const htmlKey = element.getAttribute("data-i18n-html");
    if (htmlKey) {
      element.innerHTML = t(htmlKey);
    }
    const textKey = element.getAttribute("data-i18n");
    if (textKey) {
      element.textContent = t(textKey);
    }
    const placeholderKey = element.getAttribute("data-i18n-placeholder");
    if (placeholderKey && "placeholder" in element) {
      element.placeholder = t(placeholderKey);
    }
    applyAttributes(element);
  }

  function applyDocument() {
    document.documentElement.lang = getLocaleMeta(currentLocale).htmlLang;

    const titleEl = document.querySelector("title[data-i18n]");
    if (titleEl) {
      document.title = t(titleEl.getAttribute("data-i18n"));
    }

    document
      .querySelectorAll(
        "[data-i18n], [data-i18n-html], [data-i18n-attr], [data-i18n-placeholder]"
      )
      .forEach((element) => {
        applyElement(element);
      });

    // footer.copy uses {year}
    const footerCopy = document.querySelector(
      '.footer-copy[data-i18n="footer.copy"], #footer-copy'
    );
    if (footerCopy) {
      footerCopy.textContent = t("footer.copy", {
        year: new Date().getFullYear(),
      });
    }

    const ogLocale = document.querySelector('meta[property="og:locale"]');
    if (ogLocale) {
      ogLocale.setAttribute("content", getLocaleMeta(currentLocale).ogLocale);
    }

    updateSwitcherUi();
  }

  async function setLocale(localeId, { persist = true } = {}) {
    const matched = matchSupportedLocale(localeId) || DEFAULT_LOCALE;
    try {
      await loadCatalog(matched);
      currentLocale = matched;
    } catch {
      if (!catalogs[DEFAULT_LOCALE]) {
        try {
          await loadCatalog(DEFAULT_LOCALE);
        } catch {
          return;
        }
      }
      currentLocale = DEFAULT_LOCALE;
    }
    if (persist) {
      try {
        window.localStorage?.setItem(STORAGE_KEY, currentLocale);
      } catch {
        /* ignore */
      }
    }
    applyDocument();
    changeListeners.forEach((listener) => {
      try {
        listener(currentLocale);
      } catch {
        /* ignore */
      }
    });
  }

  function onChange(listener) {
    if (typeof listener === "function") {
      changeListeners.add(listener);
    }
    return () => changeListeners.delete(listener);
  }

  function closeAllMenus() {
    document.querySelectorAll(".lang-switcher.is-open").forEach((root) => {
      root.classList.remove("is-open");
      const button = root.querySelector(".lang-switcher-btn");
      if (button) {
        button.setAttribute("aria-expanded", "false");
      }
    });
  }

  function updateSwitcherUi() {
    document.querySelectorAll(".lang-switcher").forEach((root) => {
      const label = root.querySelector(".lang-switcher-label");
      if (label) {
        label.textContent = getLocaleMeta(currentLocale).nativeName;
      }
      root.querySelectorAll("[data-locale-option]").forEach((option) => {
        const optionId = option.getAttribute("data-locale-option");
        const isActive = optionId === currentLocale;
        option.classList.toggle("is-active", isActive);
        option.setAttribute("aria-selected", isActive ? "true" : "false");
      });
    });
  }

  function buildSwitcherElement() {
    const root = document.createElement("div");
    root.className = "lang-switcher";

    const button = document.createElement("button");
    button.type = "button";
    button.className = "lang-switcher-btn";
    button.setAttribute("aria-haspopup", "listbox");
    button.setAttribute("aria-expanded", "false");
    button.setAttribute("aria-label", t("lang.switchAria"));

    button.innerHTML =
      '<svg class="lang-switcher-icon" viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      '<circle cx="12" cy="12" r="9"/>' +
      '<path d="M3 12h18"/>' +
      '<path d="M12 3a14 14 0 0 1 0 18"/>' +
      '<path d="M12 3a14 14 0 0 0 0 18"/>' +
      "</svg>" +
      '<span class="lang-switcher-label"></span>' +
      '<svg class="lang-switcher-caret" viewBox="0 0 12 12" width="10" height="10" fill="none" stroke="currentColor" stroke-width="1.6" aria-hidden="true"><path d="M2.5 4.5 6 8l3.5-3.5"/></svg>';

    const menu = document.createElement("ul");
    menu.className = "lang-switcher-menu";
    menu.setAttribute("role", "listbox");
    menu.setAttribute("aria-label", t("lang.menuAria"));

    SUPPORTED.forEach((locale) => {
      const item = document.createElement("li");
      item.setAttribute("role", "option");
      item.setAttribute("data-locale-option", locale.id);
      item.tabIndex = -1;
      item.textContent = locale.nativeName;
      item.addEventListener("click", (event) => {
        event.preventDefault();
        setLocale(locale.id);
        closeAllMenus();
      });
      menu.appendChild(item);
    });

    button.addEventListener("click", (event) => {
      event.stopPropagation();
      const willOpen = !root.classList.contains("is-open");
      closeAllMenus();
      if (willOpen) {
        root.classList.add("is-open");
        button.setAttribute("aria-expanded", "true");
        prefetchRemainingCatalogs();
      }
    });

    root.appendChild(button);
    root.appendChild(menu);
    return root;
  }

  function mountSwitcher() {
    if (document.querySelector(".lang-switcher")) {
      updateSwitcherUi();
      return;
    }

    const switcher = buildSwitcherElement();
    const navActions = document.querySelector(".nav-actions");
    if (navActions) {
      const github = navActions.querySelector(".nav-github");
      if (github) {
        navActions.insertBefore(switcher, github);
      } else {
        navActions.insertBefore(switcher, navActions.firstChild);
      }
    } else {
      switcher.classList.add("lang-switcher-floating");
      document.body.appendChild(switcher);
    }
    updateSwitcherUi();
  }

  document.addEventListener("click", () => {
    closeAllMenus();
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeAllMenus();
    }
  });

  async function loadCatalog(localeId) {
    if (catalogs[localeId]) {
      return catalogs[localeId];
    }
    const response = await fetch(`./i18n/${localeId}.json`, { cache: "force-cache" });
    if (!response.ok) {
      throw new Error(`i18n load failed: ${localeId} HTTP ${response.status}`);
    }
    const data = await response.json();
    catalogs[localeId] = data;
    return data;
  }

  function prefetchRemainingCatalogs() {
    if (remainingCatalogsPrefetched) {
      return;
    }
    remainingCatalogsPrefetched = true;
    SUPPORTED_IDS.forEach((localeId) => {
      if (!catalogs[localeId]) {
        void loadCatalog(localeId).catch(() => {});
      }
    });
  }

  async function bootstrap() {
    currentLocale = detectLocale();
    try {
      await loadCatalog(DEFAULT_LOCALE);
      if (currentLocale !== DEFAULT_LOCALE) {
        try {
          await loadCatalog(currentLocale);
        } catch {
          currentLocale = DEFAULT_LOCALE;
        }
      }
    } catch (error) {
      console.warn("[i18n] failed to load catalogs", error);
      return;
    }

    mountSwitcher();
    applyDocument();

  }

  window.I18n = {
    t,
    setLocale,
    getLocale: () => currentLocale,
    getLocales: () => SUPPORTED.slice(),
    onChange,
    apply: applyDocument,
    ready: bootstrap(),
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      void window.I18n.ready;
    });
  }
})();
