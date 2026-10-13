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

  /* ---------- 界面展示交互逻辑 ---------- */
  const SHOWCASE_DATA = {
    "zh-CN": [
      {
        badge: "核心视图",
        title: "全景周课表",
        desc: "全景俯瞰一周日程，课卡呼吸层次分明。支持自定义壁纸与拖拽微调，液态玻璃底部导航沉浸交互。",
        points: [
          "单双周智能过滤与空课时段高亮",
          "毛玻璃卡片与自研液态玻璃底栏",
          "壁纸位置独立微调与平滑手势缩放"
        ],
        webp: "./screenshots/01-week-timetable.webp",
        png: "./screenshots/01-week-timetable.png",
        alt: "轻屿课表全景周课表界面"
      },
      {
        badge: "日视图",
        title: "今日日程流转",
        desc: "专注当天日程节奏，分阶段悬浮卡片展示。距离下一节课剩余时间、教学场地一目了然。",
        points: [
          "上课倒计时毫秒级动态追踪",
          "课程时间段与作息节次精准对齐",
          "下课与转场状态无缝衔接"
        ],
        webp: "./screenshots/02-day-agenda.webp",
        png: "./screenshots/02-day-agenda.png",
        alt: "轻屿课表今日日程流转界面"
      },
      {
        badge: "系统协同",
        title: "HyperOS 超级岛联动",
        desc: "深度接入小米 HyperOS 焦点通知架构。状态栏灵动胶囊与大卡片展开，课前课中无需频繁解锁查看。",
        points: [
          "灵动胶囊镜头挖孔毫秒级调度",
          "大卡片展开自定义字段与顺序",
          "课前自动静音与免打扰联动"
        ],
        webp: "./screenshots/03-super-island.webp",
        png: "./screenshots/03-super-island.png",
        alt: "HyperOS 超级岛灵动胶囊与焦点卡片"
      },
      {
        badge: "原生组件",
        title: "桌面小组件矩阵",
        desc: "覆盖 2×2 主卡、迷你日程、整周概览、倒计时横条等全套规格。秒级快照更新，免开 App 即知日程。",
        points: [
          "丰富尺寸自由混搭排版",
          "原生数据快照高效省电渲染",
          "支持情侣课表双人日程透出"
        ],
        webp: "./screenshots/04-home-widgets.webp",
        png: "./screenshots/04-home-widgets.png",
        alt: "桌面小组件矩阵多尺寸展示"
      },
      {
        badge: "智能场景",
        title: "天气与日程感知",
        desc: "课卡深度整合实时气温与降雨概率预报。出门前智能提示携带雨具与温差变化，日程更具温度。",
        points: [
          "基于地理位置的精准实时天气",
          "降雨概率与出行建议直观透出",
          "不增加系统功耗的轻量轮询"
        ],
        webp: "./screenshots/05-weather-integration.webp",
        png: "./screenshots/05-weather-integration.png",
        alt: "天气与日程深度联动界面"
      },
      {
        badge: "视觉个性",
        title: "外观与液态材质",
        desc: "实体卡片、高斯磨砂、柔光玻璃及基于 Impeller Fragment Shader 自研的液态玻璃材质随心切换。",
        points: [
          "多层次毛玻璃与自研 Shader",
          "卡片圆角、透明度与字重微调",
          "暗色与亮色模式高对比度适配"
        ],
        webp: "./screenshots/06-appearance-customization.webp",
        png: "./screenshots/06-appearance-customization.png",
        alt: "外观定制与液态材质调节界面"
      },
      {
        badge: "教务配置",
        title: "课表设置中心",
        desc: "支持学期周次设置、开学日期推算、节次作息时间模板与法定节假日调休排课，适配各类复杂学制。",
        points: [
          "多套时间模板灵活切换",
          "支持单双周跨周连续排课",
          "法定假期与补课日自动适配"
        ],
        webp: "./screenshots/07-timetable-settings.webp",
        png: "./screenshots/07-timetable-settings.png",
        alt: "课表设置中心与学期配置界面"
      },
      {
        badge: "产品理念",
        title: "纯粹克制与开源",
        desc: "基于 GPL-3.0 协议开源。坚持零广告、无需注册账号、无冗余后台驻留，还课表以工具纯粹本质。",
        points: [
          "数据完全本地加密或 WebDAV 掌控",
          "代码透明可审计，社区协同进化",
          "尊重系统规范，杜绝流氓常驻"
        ],
        webp: "./screenshots/08-about-app.webp",
        png: "./screenshots/08-about-app.png",
        alt: "关于轻屿课表与开源协议界面"
      }
    ],
    "zh-HK": [
      {
        badge: "核心視圖",
        title: "全景周課表",
        desc: "全景俯瞰一週日程，課卡呼吸層次分明。支援自訂桌布與拖曳微調，液態玻璃底部導航沉浸互動。",
        points: [
          "單雙週智慧過濾與空堂時段突顯",
          "毛玻璃卡片與自研液態玻璃底欄",
          "桌布位置獨立微調與平滑手勢縮放"
        ],
        webp: "./screenshots/01-week-timetable.webp",
        png: "./screenshots/01-week-timetable.png",
        alt: "輕嶼課表全景周課表介面"
      },
      {
        badge: "日視圖",
        title: "今日日程流轉",
        desc: "專注當天日程節奏，分階段懸浮卡片展示。距離下一節課剩餘時間、教學場地一目了然。",
        points: [
          "上課倒數毫秒級動態追蹤",
          "課程時間段與作息節次精準對齊",
          "下課與轉場狀態無縫銜接"
        ],
        webp: "./screenshots/02-day-agenda.webp",
        png: "./screenshots/02-day-agenda.png",
        alt: "輕嶼課表今日日程流轉介面"
      },
      {
        badge: "系統協同",
        title: "HyperOS 超級島聯動",
        desc: "深度接入小米 HyperOS 焦點通知架構。狀態欄靈動膠囊與大卡片展開，課前課中無需頻繁解鎖查看。",
        points: [
          "靈動膠囊鏡頭挖孔毫秒級調度",
          "大卡片展開自訂欄位與順序",
          "課前自動靜音與勿擾聯動"
        ],
        webp: "./screenshots/03-super-island.webp",
        png: "./screenshots/03-super-island.png",
        alt: "HyperOS 超級島靈動膠囊與焦點卡片"
      },
      {
        badge: "原生組件",
        title: "桌面小組件矩陣",
        desc: "涵蓋 2×2 主卡、迷你日程、整週概覽、倒數橫條等全套規格。秒級快照更新，免開 App 即知日程。",
        points: [
          "豐富尺寸自由混搭排版",
          "原生數據快照高效省電渲染",
          "支援情侶課表雙人日程透出"
        ],
        webp: "./screenshots/04-home-widgets.webp",
        png: "./screenshots/04-home-widgets.png",
        alt: "桌面小組件矩陣多尺寸展示"
      },
      {
        badge: "智慧場景",
        title: "天氣與日程感知",
        desc: "課卡深度整合即時氣溫與降雨機率預報。出門前智慧提示攜帶雨具與溫差變化，日程更具溫度。",
        points: [
          "基於地理位置的精準即時天氣",
          "降雨機率與出行建議直觀呈現",
          "不增加系統功耗的輕量輪詢"
        ],
        webp: "./screenshots/05-weather-integration.webp",
        png: "./screenshots/05-weather-integration.png",
        alt: "天氣與日程深度聯動介面"
      },
      {
        badge: "視覺個性",
        title: "外觀與液態材質",
        desc: "實體卡片、高斯磨砂、柔光玻璃及基於 Impeller Fragment Shader 自研的液態玻璃材質隨心切換。",
        points: [
          "多層次毛玻璃與自研 Shader",
          "卡片圓角、透明度與字重微調",
          "深色與淺色模式高對比度適配"
        ],
        webp: "./screenshots/06-appearance-customization.webp",
        png: "./screenshots/06-appearance-customization.png",
        alt: "外觀訂製與液態材質調節介面"
      },
      {
        badge: "教務配置",
        title: "課表設定中心",
        desc: "支援學期週次設定、開學日期推算、節次作息時間範本與法定節假日調休排課，適配各類複雜學制。",
        points: [
          "多套時間範本靈活切換",
          "支援單雙週跨週連續排課",
          "法定假期與補課日自動適配"
        ],
        webp: "./screenshots/07-timetable-settings.webp",
        png: "./screenshots/07-timetable-settings.png",
        alt: "課表設定中心與學期配置介面"
      },
      {
        badge: "產品理念",
        title: "純粹克制與開源",
        desc: "基於 GPL-3.0 協議開源。堅持零廣告、無需註冊帳號、無冗餘背景駐留，還課表以工具純粹本質。",
        points: [
          "數據完全本地加密或 WebDAV 掌控",
          "代碼透明可審計，社群協同進化",
          "尊重系統規範，杜絕流氓常駐"
        ],
        webp: "./screenshots/08-about-app.webp",
        png: "./screenshots/08-about-app.png",
        alt: "關於輕嶼課表與開源協議介面"
      }
    ],
    "en": [
      {
        badge: "Core View",
        title: "Panoramic Week Timetable",
        desc: "Overview of your full week schedule with distinct frosted glass card layers. Custom wallpaper repositioning and liquid glass bottom navigation.",
        points: [
          "Odd/even week filter and free time highlights",
          "Frosted glass cards with custom shader liquid dock",
          "Wallpaper position fine-tuning with smooth gestures"
        ],
        webp: "./screenshots/01-week-timetable.webp",
        png: "./screenshots/01-week-timetable.png",
        alt: "Qingyu Timetable panoramic week view"
      },
      {
        badge: "Day Agenda",
        title: "Daily Schedule Flow",
        desc: "Focus on today's rhythm with floating staged cards. Class countdowns and exact classroom locations at a glance.",
        points: [
          "Millisecond-level class countdown tracking",
          "Precision period timetable alignment",
          "Seamless handoff between periods"
        ],
        webp: "./screenshots/02-day-agenda.webp",
        png: "./screenshots/02-day-agenda.png",
        alt: "Daily schedule flow view"
      },
      {
        badge: "System Integration",
        title: "HyperOS Super Island",
        desc: "Deep integration with Xiaomi HyperOS Focus Notifications. Dynamic capsules around camera cutout and expandable cards without unlocking.",
        points: [
          "Millisecond scheduling around camera punch-hole",
          "Customizable expanded card rows and order",
          "Automatic pre-class mute and DND automation"
        ],
        webp: "./screenshots/03-super-island.webp",
        png: "./screenshots/03-super-island.png",
        alt: "HyperOS Super Island dynamic capsule"
      },
      {
        badge: "Home Widgets",
        title: "Widget Ecosystem",
        desc: "Full matrix covering 2x2 cards, mini agendas, weekly overviews, and countdown strips with instant snapshot updates.",
        points: [
          "Flexible grid arrangement for any home screen",
          "Battery-efficient native snapshot rendering",
          "Couple timetable dual schedule support"
        ],
        webp: "./screenshots/04-home-widgets.webp",
        png: "./screenshots/04-home-widgets.png",
        alt: "Android home widget matrix"
      },
      {
        badge: "Smart Context",
        title: "Weather & Schedule",
        desc: "Integrated real-time temperature and precipitation forecasts directly on course cards for timely departure advice.",
        points: [
          "Location-based accurate live weather updates",
          "Precipitation probability & travel recommendations",
          "Battery-conscious lightweight scheduling"
        ],
        webp: "./screenshots/05-weather-integration.webp",
        png: "./screenshots/05-weather-integration.png",
        alt: "Weather and course integration"
      },
      {
        badge: "Visual Craft",
        title: "Liquid Glass & Themes",
        desc: "Solid cards, gaussian blur, soft frosted glass, and proprietary Impeller Fragment Shader liquid glass materials.",
        points: [
          "Multi-layer frosted glass and custom shaders",
          "Adjustable corner radius, opacity, and font weights",
          "High contrast dark & light mode adaptation"
        ],
        webp: "./screenshots/06-appearance-customization.webp",
        png: "./screenshots/06-appearance-customization.png",
        alt: "Appearance customization and liquid glass"
      },
      {
        badge: "Academic Setup",
        title: "Timetable Settings",
        desc: "Semester week management, start date calculation, period templates, and holiday shift compensation.",
        points: [
          "Multiple flexible period templates",
          "Odd/even and continuous session rules",
          "Statutory holiday and makeup day handling"
        ],
        webp: "./screenshots/07-timetable-settings.webp",
        png: "./screenshots/07-timetable-settings.png",
        alt: "Timetable settings and semester configuration"
      },
      {
        badge: "Philosophy",
        title: "Clean, Focused & Open Source",
        desc: "Open source under GPL-3.0. Zero ads, zero accounts required, and zero background clutter—pure utility at its best.",
        points: [
          "Locally encrypted data or WebDAV cloud control",
          "Auditable code built with open community",
          "Respects system lifecycle without intrusive services"
        ],
        webp: "./screenshots/08-about-app.webp",
        png: "./screenshots/08-about-app.png",
        alt: "About app and open source license"
      }
    ]
  };
  SHOWCASE_DATA["zh-TW"] = SHOWCASE_DATA["zh-HK"];

  function initShowcase() {
    const stage = document.querySelector(".showcase-container");
    if (!stage) return;

    let currentIndex = 0;
    const tabs = Array.from(document.querySelectorAll(".showcase-tab"));
    const thumbs = Array.from(document.querySelectorAll(".showcase-thumb-btn"));
    const prevBtn = document.getElementById("sc-prev");
    const nextBtn = document.getElementById("sc-next");
    const badgeEl = document.getElementById("sc-badge");
    const titleEl = document.getElementById("sc-title");
    const descEl = document.getElementById("sc-desc");
    const pointsEl = document.getElementById("sc-points");
    const counterEl = document.getElementById("sc-counter");
    const mainWebp = document.getElementById("sc-main-webp");
    const mainImg = document.getElementById("sc-main-img");

    function getItems() {
      const locale = window.I18n?.getLocale?.() || "zh-CN";
      return SHOWCASE_DATA[locale] || SHOWCASE_DATA["zh-CN"] || SHOWCASE_DATA["en"];
    }

    function renderItem(index) {
      const items = getItems();
      if (!items || !items[index]) return;
      currentIndex = index;
      const item = items[index];

      // Update tabs
      tabs.forEach((tab, i) => {
        const active = i === index;
        tab.classList.toggle("is-active", active);
        tab.setAttribute("aria-selected", active ? "true" : "false");
      });

      // Update thumbs
      thumbs.forEach((thumb, i) => {
        thumb.classList.toggle("is-active", i === index);
      });

      // Update text
      if (badgeEl) badgeEl.textContent = item.badge;
      if (titleEl) titleEl.textContent = item.title;
      if (descEl) descEl.textContent = item.desc;
      if (counterEl) counterEl.textContent = `${index + 1} / ${items.length}`;

      if (pointsEl && Array.isArray(item.points)) {
        pointsEl.innerHTML = item.points
          .map((p) => `<li><span class="sc-bullet"></span><span>${p}</span></li>`)
          .join("");
      }

      // Smooth image transition
      if (mainImg) {
        mainImg.classList.add("is-changing");
        if (mainWebp) mainWebp.srcset = item.webp;
        mainImg.src = item.png;
        mainImg.alt = item.alt;

        const handleLoad = () => {
          mainImg.classList.remove("is-changing");
          mainImg.removeEventListener("load", handleLoad);
        };
        mainImg.addEventListener("load", handleLoad);
        window.setTimeout(() => mainImg.classList.remove("is-changing"), 220);
      }
    }

    // Bind tabs
    tabs.forEach((tab, i) => {
      tab.addEventListener("click", () => renderItem(i));
    });

    // Bind thumbs
    thumbs.forEach((thumb, i) => {
      thumb.addEventListener("click", () => renderItem(i));
    });

    // Bind prev / next
    if (prevBtn) {
      prevBtn.addEventListener("click", () => {
        const items = getItems();
        const nextIdx = (currentIndex - 1 + items.length) % items.length;
        renderItem(nextIdx);
      });
    }

    if (nextBtn) {
      nextBtn.addEventListener("click", () => {
        const items = getItems();
        const nextIdx = (currentIndex + 1) % items.length;
        renderItem(nextIdx);
      });
    }

    // Keyboard navigation within showcase
    stage.addEventListener("keydown", (e) => {
      if (e.key === "ArrowLeft") {
        const items = getItems();
        renderItem((currentIndex - 1 + items.length) % items.length);
      } else if (e.key === "ArrowRight") {
        const items = getItems();
        renderItem((currentIndex + 1) % items.length);
      }
    });

    // Re-render when i18n locale changes
    if (window.I18n && typeof window.I18n.onChange === "function") {
      window.I18n.onChange(() => {
        renderItem(currentIndex);
      });
    }
  }

  initShowcase();

  /* ---------- 页面加载后预取版本信息 ----------
     script.js 原逻辑只在打开下载弹窗时读取 latest.json；
     这里提前触发一次，让下载区「最新正式版更新」与版本数不用等弹窗。 */
  window.addEventListener("load", () => {
    if (typeof loadLatestRelease === "function") {
      void loadLatestRelease();
    }
  });
})();
