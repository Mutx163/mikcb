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

  /* ---------- 界面实拍：横向拖动与进度拉杆 ----------
     胶片带是原生横向滚动（scroll-snap），但滚动条已隐藏、鼠标没有直接
     抓握的手势，所以补两件事：
     1) 按住胶片带直接左右拖（pointer capture，拖动时关掉 snap 防抖动）；
     2) 底部一根等比进度拉杆，可点、可拖，与滚动位置双向同步。
     拉杆不消耗键盘焦点（aria-hidden，纯指针增强），键盘用户走 Tab
     进各张截图按钮，路径不变。

     与 scroll-snap 的两处冲突（Chromium 实测）：
     a) 同步块里 add class → 赋值 scrollLeft，样式未重算，首次赋值仍被吸附；
        必须在赋值前强制 reflow 让 snap:none 生效。
     b) pointerup 立刻恢复 snap，松手会被视作「滚动手势结束」吸附到最近卡点；
        必须延迟恢复（恢复动作本身不触发滚动，之后不会再吸附）。 */
  const shotsBand = document.querySelector("[data-shots-band]");
  const shotsScrollbar = document.querySelector("[data-shots-scrollbar]");
  const shotsThumb = document.querySelector("[data-shots-thumb]");

  if (shotsBand && shotsScrollbar && shotsThumb) {
    let dragPointerId = null;
    let dragStartX = 0;
    let dragStartScroll = 0;
    let scrollbarDrag = false;
    let snapRestoreTimer = null;
    let suppressNextClick = false;

    const clampScroll = (value) => {
      const max = shotsBand.scrollWidth - shotsBand.clientWidth;
      return Math.min(Math.max(value, 0), Math.max(max, 0));
    };

    /** 关掉 snap（供程序赋值 scrollLeft 用）；restoreSnap() 延迟恢复。 */
    const suppressSnap = () => {
      if (snapRestoreTimer !== null) {
        window.clearTimeout(snapRestoreTimer);
        snapRestoreTimer = null;
      }
      shotsBand.classList.add("is-dragging");
      void shotsBand.offsetHeight; // 强制重算：让 snap:none 立即生效
    };

    const restoreSnap = () => {
      if (snapRestoreTimer !== null) {
        window.clearTimeout(snapRestoreTimer);
      }
      snapRestoreTimer = window.setTimeout(() => {
        snapRestoreTimer = null;
        shotsBand.classList.remove("is-dragging");
      }, 300);
    };

    const updateThumb = () => {
      const max = shotsBand.scrollWidth - shotsBand.clientWidth;
      if (max <= 0) {
        shotsScrollbar.hidden = true; // 单屏放得下就不需要拉杆
        return;
      }
      shotsScrollbar.hidden = false;
      const ratio = shotsBand.clientWidth / shotsBand.scrollWidth;
      const thumbWidth = Math.max(ratio * 100, 8); // 最小 8%，避免太细抓不到
      const progress = shotsBand.scrollLeft / max;
      const travel = 100 - thumbWidth;
      shotsThumb.style.width = `${thumbWidth}%`;
      shotsThumb.style.left = `${progress * travel}%`;
    };

    shotsBand.addEventListener("scroll", updateThumb, { passive: true });
    window.addEventListener("resize", updateThumb);
    updateThumb();

    /* --- 胶片带按住拖动 --- */
    shotsBand.addEventListener("pointerdown", (event) => {
      // 右键/多点触控不接管；滚轮与触摸的原生滚动保持不动
      if (event.button !== 0 || dragPointerId !== null) {
        return;
      }
      dragPointerId = event.pointerId;
      dragStartX = event.clientX;
      dragStartScroll = shotsBand.scrollLeft;
      suppressSnap();
      try {
        shotsBand.setPointerCapture(event.pointerId);
      } catch {
        // 指针失效：退化为「移出元素才停止」的普通拖动，不致命
      }
    });

    shotsBand.addEventListener("pointermove", (event) => {
      if (event.pointerId !== dragPointerId) {
        return;
      }
      shotsBand.scrollLeft = clampScroll(dragStartScroll - (event.clientX - dragStartX));
    });

    const endBandDrag = (event) => {
      if (event.pointerId !== dragPointerId) {
        return;
      }
      dragPointerId = null;
      restoreSnap();
      if (shotsBand.hasPointerCapture(event.pointerId)) {
        shotsBand.releasePointerCapture(event.pointerId);
      }
      // 位移超过阈值的这次按压是「拖动」不是「点选」：拦掉紧随的 click，
      // 避免松手时误开灯箱。纯点击（<6px）不拦截。
      suppressNextClick = Math.abs(event.clientX - dragStartX) > 6;
    };
    shotsBand.addEventListener("pointerup", endBandDrag);
    shotsBand.addEventListener("pointercancel", endBandDrag);

    // 拖动结束后的那次 click 在捕获阶段拦掉（灯箱的 click 监听在冒泡阶段）
    shotsBand.addEventListener("click", (event) => {
      if (suppressNextClick) {
        event.stopPropagation();
        event.preventDefault();
        suppressNextClick = false;
      }
    }, true);

    /* --- 拉杆：点击定位 + 按住拖动 ---
       seek 放在 setPointerCapture 之前：capture 对合成/已失效指针会抛
       NotFoundError，放在后面会让点击定位被异常跳过（2026-10-15 实测）。 */
    const seekFromEvent = (event) => {
      const track = shotsScrollbar.getBoundingClientRect();
      const ratio = Math.min(Math.max((event.clientX - track.left) / track.width, 0), 1);
      const max = shotsBand.scrollWidth - shotsBand.clientWidth;
      shotsBand.scrollLeft = ratio * max;
    };

    shotsScrollbar.addEventListener("pointerdown", (event) => {
      if (event.button !== 0) {
        return;
      }
      suppressSnap();
      seekFromEvent(event);
      scrollbarDrag = true;
      shotsScrollbar.classList.add("is-dragging");
      try {
        shotsScrollbar.setPointerCapture(event.pointerId);
      } catch {
        // 指针已失效（罕见）：拖动跟随会在指针移出拉杆后停止，点击定位不受影响
      }
    });

    shotsScrollbar.addEventListener("pointermove", (event) => {
      if (scrollbarDrag) {
        seekFromEvent(event);
      }
    });

    const endScrollbarDrag = (event) => {
      if (!scrollbarDrag) {
        return;
      }
      scrollbarDrag = false;
      shotsScrollbar.classList.remove("is-dragging");
      restoreSnap();
      if (shotsScrollbar.hasPointerCapture(event.pointerId)) {
        shotsScrollbar.releasePointerCapture(event.pointerId);
      }
    };
    shotsScrollbar.addEventListener("pointerup", endScrollbarDrag);
    shotsScrollbar.addEventListener("pointercancel", endScrollbarDrag);
  }

  /* ---------- 界面实拍：灯箱 ----------
     开图 / 前后翻页 / Esc 与背景点击关闭 / 简单焦点管理。
     图源与文案全部读 DOM（.shot 的 picture 与 caption），不在 JS 里再存一份数据——
     六语言标注由 i18n 写进 caption，灯箱直接引用，天然跟随语言切换。
     注意：胶片带的「拖动拦截 click」在捕获阶段监听，会先于这里冒泡的 click 执行。 */
  const lightbox = document.getElementById("shots-lightbox");
  const lightboxImg = document.getElementById("shots-lightbox-img");
  const lightboxWebp = document.getElementById("shots-lightbox-webp");
  const lightboxTitle = document.getElementById("shots-lightbox-title");
  const lightboxCounter = document.getElementById("shots-lightbox-counter");
  const lightboxPrev = document.getElementById("shots-lightbox-prev");
  const lightboxNext = document.getElementById("shots-lightbox-next");
  const lightboxClose = document.getElementById("shots-lightbox-close");

  let shotsList = [];
  let shotsIndex = 0;
  let shotsLastFocused = null;

  function collectShots() {
    shotsList = Array.from(document.querySelectorAll(".shot")).map((node) => {
      const img = node.querySelector(".shot-frame img");
      const source = node.querySelector(".shot-frame source");
      return {
        // caption 可能被 i18n 重写，所以每次打开时现取文本
        node,
        png: img ? img.getAttribute("src") || "" : "",
        webp: source ? source.getAttribute("srcset") || "" : "",
      };
    });
  }

  function readShotTitle(index) {
    const node = shotsList[index] && shotsList[index].node;
    const caption = node ? node.querySelector(".shot-caption") : null;
    return caption ? caption.textContent.trim() : "";
  }

  function showShot(index) {
    if (!shotsList.length) {
      return;
    }
    // 循环翻页：最后一张的下一张是第一张
    shotsIndex = (index + shotsList.length) % shotsList.length;
    const shot = shotsList[shotsIndex];
    if (lightboxWebp) {
      lightboxWebp.setAttribute("srcset", shot.webp);
    }
    if (lightboxImg) {
      lightboxImg.setAttribute("src", shot.png);
      lightboxImg.setAttribute(
        "alt",
        readShotTitle(shotsIndex) || shot.png
      );
    }
    if (lightboxTitle) {
      lightboxTitle.textContent = readShotTitle(shotsIndex);
    }
    if (lightboxCounter) {
      lightboxCounter.textContent = `${shotsIndex + 1} / ${shotsList.length}`;
    }
  }

  function openShotsLightbox(index) {
    if (!lightbox) {
      return;
    }
    collectShots();
    if (!shotsList.length) {
      return;
    }
    shotsLastFocused = document.activeElement;
    showShot(index);
    lightbox.classList.add("is-open");
    lightbox.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
    // 等两帧（is-open 的 visibility 过渡生效、元素进入渲染树）再聚焦关闭按钮，
    // 否则 focus 落在仍 visibility:hidden 的元素上是 no-op。
    // 下载弹窗用 setTimeout(0) 够用是因为它的过渡不含 visibility 延迟；这里 rAF 双帧为主、
    // 60ms 定时器兜底（后台窗口/省电模式下 rAF 可能被冻结，届时兜底补上焦点）。
    const focusCloseButton = () => {
      if (lightboxClose) {
        lightboxClose.focus();
      }
    };
    requestAnimationFrame(() => {
      requestAnimationFrame(focusCloseButton);
    });
    window.setTimeout(focusCloseButton, 60);
  }

  function closeShotsLightbox() {
    if (!lightbox || !lightbox.classList.contains("is-open")) {
      return;
    }
    lightbox.classList.remove("is-open");
    lightbox.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
    if (shotsLastFocused instanceof HTMLElement) {
      shotsLastFocused.focus();
      shotsLastFocused = null;
    }
  }

  const shotsBandForLightbox = shotsBand;
  if (lightbox && shotsBandForLightbox) {
    shotsBandForLightbox.addEventListener("click", (event) => {
      const shot = event.target instanceof Element ? event.target.closest(".shot") : null;
      if (!shot) {
        return;
      }
      const index = Number(shot.getAttribute("data-shot-index"));
      openShotsLightbox(Number.isFinite(index) ? index : 0);
    });

    lightboxPrev &&
      lightboxPrev.addEventListener("click", () => showShot(shotsIndex - 1));
    lightboxNext &&
      lightboxNext.addEventListener("click", () => showShot(shotsIndex + 1));
    lightboxClose &&
      lightboxClose.addEventListener("click", closeShotsLightbox);

    lightbox.addEventListener("click", (event) => {
      if (event.target instanceof Element && event.target.closest("[data-close-shots-lightbox]")) {
        closeShotsLightbox();
      }
    });

    document.addEventListener("keydown", (event) => {
      if (!lightbox.classList.contains("is-open")) {
        return;
      }
      if (event.key === "Escape") {
        event.preventDefault();
        closeShotsLightbox();
      } else if (event.key === "ArrowLeft") {
        event.preventDefault();
        showShot(shotsIndex - 1);
      } else if (event.key === "ArrowRight") {
        event.preventDefault();
        showShot(shotsIndex + 1);
      }
    });
  }
})();
