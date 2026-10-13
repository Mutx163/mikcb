/* 首页专属交互增强：依赖 script.js 先加载（下载弹窗与统计逻辑仍在 script.js）。 */

(function initHomeEnhancements() {
  const prefersReducedMotion = window.matchMedia(
    "(prefers-reduced-motion: reduce)"
  ).matches;

  /* ---------- 卡片鼠标跟随光斑 ----------
     用事件委托而非逐元素绑定：更新日志时间线是 script.js 读取
     feed.json 后异步重建的，加载时的一次性绑定会漏掉这些卡片，
     导致只有初始静态卡片有跟随效果。 */
  document.addEventListener("pointermove", (event) => {
    const target = event.target;
    const card =
      target instanceof Element ? target.closest("[data-spotlight]") : null;
    if (!card) {
      return;
    }
    const rect = card.getBoundingClientRect();
    card.style.setProperty("--mx", `${event.clientX - rect.left}px`);
    card.style.setProperty("--my", `${event.clientY - rect.top}px`);
  });

  /* ---------- Hero 标题尾句轮换 ----------
     参考站头图是「固定前缀 + 尾词轮换」两段：前缀（不必想好，）完全静止，
     逐字结构只挂在尾词上，尾词每隔几秒换一句。这里照这个结构做：标题的最后
     一句在几套品牌卖点之间轮换，前面那句一动不动。

     三个绕不开的点：
     1) 逐字 span 必须在运行时生成，不能写死在 HTML——i18n 是用 textContent
        覆盖 [data-i18n] 元素的，写死的结构会被译文冲掉。所以放在 I18n.ready
        之后建，并在 onChange 里重建。
     2) 生成只改节点结构，h1 的 textContent 拼接结果不变，搜索引擎读到的仍是完整标题。
     3) 轮换会一直跑，所以「停稳后收掉常驻 filter」得每句各管各的（is-rest），
        不能像单次进场那样在标题上挂一个总开关。

     时序常量要和 home.css 那段注释对得上：进场 0.72s + 每字错开 30ms。 */
  const HERO_TAIL_INTRO_DELAY_MS = 260; // 让外层 .reveal（整块 0.7s 淡入）先起个头
  const HERO_TAIL_DWELL_MS = 3600; // 每句停留多久
  const HERO_TAIL_REST_MS = 1000; // 进场跑完 → 收掉常驻 filter
  const HERO_TAIL_CLEANUP_MS = 900; // 退场跑完 → 摘掉旧节点

  /** 把一句话拆成 .ht-char；有空格的语言多包一层 .ht-chunk（逐词 nowrap）。 */
  function buildTailWord(phrase, baseDelayMs) {
    const word = document.createElement("span");
    word.className = "ht-word";
    word.setAttribute("data-live", "false");
    // 进场前先对读屏软件藏起来，切成 live 时再放出来，免得标题被读两遍。
    word.setAttribute("aria-hidden", "true");
    if (baseDelayMs) {
      word.style.setProperty("--ht-base", `${baseDelayMs}ms`);
    }

    // 逐字 inline-block 会把长单词从中间拆断，所以拉丁、韩文这类有空格的语言
    // 先按词包一层 nowrap；中日文没有空格，直接按字排。
    const byWord = /\s/.test(phrase);
    const tokens = byWord ? phrase.split(/(\s+)/) : [phrase];
    let index = 0;

    tokens.forEach((token) => {
      if (!token) {
        return;
      }
      if (byWord && /^\s+$/.test(token)) {
        word.appendChild(document.createTextNode(token));
        return;
      }
      const host = byWord ? document.createElement("span") : word;
      if (byWord) {
        host.className = "ht-chunk";
      }
      Array.from(token).forEach((char) => {
        const span = document.createElement("span");
        span.className = "ht-char";
        span.style.setProperty("--i", String(index));
        span.textContent = char;
        host.appendChild(span);
        index += 1;
      });
      if (byWord) {
        word.appendChild(host);
      }
    });

    return word;
  }

  /** 标题尾句不留句末句号：标题带句号读起来像一句话，不是一个标题。
      统一在这里剥掉，而不是去改六份词条——这是排版决定，
      而且剥的是「句末标点」这一类，中英日韩的句号/点都能覆盖。
      （前缀那句里的「，」不动：用户只要求去掉句号。） */
  function stripFinalPeriod(text) {
    return String(text).replace(/[.。．]+$/, "");
  }

  /** 当前语言的尾句列表。缺键、或只有一句时退回 hero.titleGrad 那一句。 */
  function readTailPhrases() {
    const i18n = window.I18n;
    const fallback = stripFinalPeriod((i18n && i18n.t("hero.titleGrad")) || "");
    const raw = (i18n && i18n.t("hero.tails")) || "";
    const list = String(raw)
      .split("\n")
      .map((item) => stripFinalPeriod(item.trim()))
      .filter(Boolean);
    if (list.length >= 2) {
      return list;
    }
    // 目录没拉到（file:// 或 404）时返回空数组，调用方会原样留着 HTML 里的静态文案。
    return fallback ? [fallback] : [];
  }

  let heroTailTimer = null;

  function initHeroTail(title) {
    const lines = title.querySelectorAll("[data-i18n]");
    const line = lines[lines.length - 1];
    const phrases = readTailPhrases();

    // 切换语言会重建一次，先把上一轮的定时器拆掉，否则旧定时器继续空转。
    if (heroTailTimer !== null) {
      window.clearInterval(heroTailTimer);
      heroTailTimer = null;
    }

    if (!line || !phrases.length) {
      return;
    }

    const slot = document.createElement("span");
    slot.className = "ht-slot";
    line.textContent = "";
    line.appendChild(slot);

    let index = 0;
    let current = null;

    const show = (phrase, baseDelayMs) => {
      const word = buildTailWord(phrase, baseDelayMs);
      slot.appendChild(word);
      // 先让 data-live=false 的初始态（下方 + 模糊）落地一帧再切成 true。
      // 少了这次强制布局，浏览器会把两次样式计算合并，过渡直接跳到终态。
      requestAnimationFrame(() => {
        void word.offsetWidth;
        word.setAttribute("data-live", "true");
        word.removeAttribute("aria-hidden");
        window.setTimeout(() => {
          word.classList.add("is-rest");
        }, HERO_TAIL_REST_MS);
      });
      return word;
    };

    current = show(phrases[0], HERO_TAIL_INTRO_DELAY_MS);

    // 只有一句、或用户开了「减少动态效果」时不轮换，静态停在这句上。
    const reduceMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;
    if (reduceMotion || phrases.length < 2) {
      return;
    }

    heroTailTimer = window.setInterval(() => {
      if (document.hidden) {
        return;
      }
      index = (index + 1) % phrases.length;
      const outgoing = current;
      current = show(phrases[index], 0);
      if (!outgoing) {
        return;
      }
      // 顺序要紧：先摘 is-rest（否则它的 transition:none 会吃掉退场动画），
      // 再挂 data-exit，最后才撤 data-live。
      outgoing.classList.remove("is-rest");
      outgoing.setAttribute("data-exit", "true");
      outgoing.setAttribute("aria-hidden", "true");
      outgoing.removeAttribute("data-live");
      window.setTimeout(() => outgoing.remove(), HERO_TAIL_CLEANUP_MS);
    }, HERO_TAIL_DWELL_MS);
  }

  function initHeroTitle() {
    const title = document.querySelector(".hero-title");
    if (!title) {
      return;
    }

    const i18n = window.I18n;
    if (i18n && i18n.ready) {
      // 必须等 i18n 把文案写进 DOM 之后再建，否则刚建好就被译文覆盖。
      i18n.ready.then(
        () => initHeroTail(title),
        () => initHeroTail(title)
      );
    } else {
      initHeroTail(title);
    }

    if (i18n && typeof i18n.onChange === "function") {
      i18n.onChange(() => {
        // setLocale 的顺序是「先 applyDocument（textContent 覆盖）再通知监听者」，
        // 所以这里重建即可。
        initHeroTail(title);
      });
    }
  }

  initHeroTitle();

  /* ---------- 页面加载后预取版本信息 ----------
     script.js 原逻辑只在打开下载弹窗时读取 latest.json；
     这里提前触发一次，让下载区「最新正式版更新」与版本数不用等弹窗。 */
  window.addEventListener("load", () => {
    if (typeof loadLatestRelease === "function") {
      void loadLatestRelease();
    }
  });
})();
