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

  /* ---------- 界面展示交互逻辑 (旗舰大片级展台) ---------- */
  const SHOWCASE_DATA = {
    "zh-CN": [
      {
        num: "01",
        badge: "核心全景",
        headline: "把整周节奏，化作桌面风景",
        subline: "全景壁纸 · 毛玻璃课卡 · 液态玻璃底栏",
        desc: "全景俯瞰一周日程分布，课卡层次清晰分明。单双周智能过滤，空余时段一目了然；壁纸支持拖拽与平滑手势缩放，让课表成为真正赏心悦目的日常工具。",
        tiles: [
          { tag: "自研 Shader", text: "液态玻璃底部导航坞" },
          { tag: "智能排布", text: "单双周过滤与空课高亮" },
          { tag: "手势调配", text: "壁纸位置独立自由拖拽" }
        ],
        glow: "rgba(41, 121, 255, 0.45)",
        webp: "./screenshots/01-week-timetable.webp",
        png: "./screenshots/01-week-timetable.png",
        name: "周课表"
      },
      {
        num: "02",
        badge: "当日流转",
        headline: "聚焦当下，从容掌控每节作息",
        subline: "分阶段卡片 · 精准节次 · 毫秒级倒计时",
        desc: "自动收拢非今日日程，专注此时此刻的教学节奏。下一节课去哪个校区教室、还有多久打铃、课后去向何处，悬浮卡片自然连续衔接。",
        tiles: [
          { tag: "动态流转", text: "上课倒计时毫秒级追踪" },
          { tag: "精准节次", text: "教学楼与作息无缝对齐" },
          { tag: "无感承接", text: "课前课中下课状态流转" }
        ],
        glow: "rgba(20, 184, 166, 0.42)",
        webp: "./screenshots/02-day-agenda.webp",
        png: "./screenshots/02-day-agenda.png",
        name: "今日日程"
      },
      {
        num: "03",
        badge: "系统级协同",
        headline: "状态栏灵动流转，抬眼即知",
        subline: "深度接入小米 HyperOS 焦点通知架构",
        desc: "与状态栏镜头挖孔浑然一体。灵动胶囊毫秒级倒计时，下拉大卡片清晰展现课程详情与授课教师。上课无需反复解锁点开 App，信息自然生长在系统里。",
        tiles: [
          { tag: "灵动胶囊", text: "镜头挖孔毫秒级调度" },
          { tag: "卡片展开", text: "支持自定义字段与排序" },
          { tag: "免打扰联动", text: "课前自动静音课后恢复" }
        ],
        glow: "rgba(0, 122, 255, 0.52)",
        webp: "./screenshots/03-super-island.webp",
        png: "./screenshots/03-super-island.png",
        name: "超级岛"
      },
      {
        num: "04",
        badge: "桌面组件生态",
        headline: "全尺寸矩阵，自由编排主屏",
        subline: "2×2 主卡 · 迷你日程 · 课程概览 · 倒计时条",
        desc: "全套小组件覆盖各种屏幕排版需求。采用原生数据快照高效秒级渲染，极低电量消耗；还支持情侣课表双人日程透出，抬眼即见彼此安排。",
        tiles: [
          { tag: "全套规格", text: "2×2 / 概览 / 倒计时混搭" },
          { tag: "原生快照", text: "极低能耗后台秒级响应" },
          { tag: "情侣协同", text: "双人课表同屏即时透出" }
        ],
        glow: "rgba(139, 92, 246, 0.45)",
        webp: "./screenshots/04-home-widgets.webp",
        png: "./screenshots/04-home-widgets.png",
        name: "桌面组件"
      },
      {
        num: "05",
        badge: "场景感知",
        headline: "知晓晴雨温差，从容出门上课",
        subline: "实时气温 · 降水预报 · 出行贴心建议",
        desc: "课程卡片内嵌实时气象信息。清晨出门前智能提示是否携带雨具与温差变化，将气象感知与日程结合，让工具具备生活温度。",
        tiles: [
          { tag: "精准气象", text: "基于地理位置实时气温" },
          { tag: "出行建议", text: "降雨概率与雨具携带提示" },
          { tag: "轻量轮询", text: "不增加额外功耗与负担" }
        ],
        glow: "rgba(56, 189, 248, 0.45)",
        webp: "./screenshots/05-weather-integration.webp",
        png: "./screenshots/05-weather-integration.png",
        name: "天气联动"
      },
      {
        num: "06",
        badge: "视觉美学",
        headline: "质感定制，触手可及的液态美",
        subline: "实体卡片 · 高斯磨砂 · 自研 Shader",
        desc: "内置多种视觉材质风格：实体卡片、高斯磨砂柔光以及基于 Impeller Fragment Shader 自研的液态玻璃材质，圆角、字重、透明度随心微调。",
        tiles: [
          { tag: "自研 Shader", text: "Impeller 液态玻璃材质" },
          { tag: "细节微调", text: "卡片圆角、透明度与字重" },
          { tag: "色彩适配", text: "深浅模式高对比度校准" }
        ],
        glow: "rgba(236, 72, 153, 0.45)",
        webp: "./screenshots/06-appearance-customization.webp",
        png: "./screenshots/06-appearance-customization.png",
        name: "液态外观"
      },
      {
        num: "07",
        badge: "教务配置中心",
        headline: "化繁为简，轻松驾驭复杂学制",
        subline: "学期周历 · 作息模板 · 法定节假日排课",
        desc: "支持多套节次作息时间模板切换、开学周次智能推算、单双周连续排课以及法定节假日调休自动避让，全面兼容各大高校的特殊排课规则。",
        tiles: [
          { tag: "作息模板", text: "多套时间作息灵活切换" },
          { tag: "调休排课", text: "法定假期与补课自动适配" },
          { tag: "多课表隔离", text: "沙箱数据毫秒级无感切换" }
        ],
        glow: "rgba(245, 158, 11, 0.45)",
        webp: "./screenshots/07-timetable-settings.webp",
        png: "./screenshots/07-timetable-settings.png",
        name: "课表设置"
      },
      {
        num: "08",
        badge: "产品理念",
        headline: "零广告、无注册，回归工具纯粹",
        subline: "GPL-3.0 协议 · 本地优先 · 隐私完全掌控",
        desc: "代码完全开源透明，杜绝流氓常驻与隐私获取。数据完全由你掌控，支持本地全量加密备份与 WebDAV 云同步，纯粹无负担，做最可靠的大学伴侣。",
        tiles: [
          { tag: "开源透明", text: "GPL-3.0 协议可独立审计" },
          { tag: "零骚扰", text: "无开屏广告、无需注册账号" },
          { tag: "本地掌控", text: "WebDAV 与全量数据加密" }
        ],
        glow: "rgba(34, 197, 94, 0.45)",
        webp: "./screenshots/08-about-app.webp",
        png: "./screenshots/08-about-app.png",
        name: "纯粹开源"
      }
    ],
    "zh-HK": [
      {
        num: "01",
        badge: "核心全景",
        headline: "把整週節奏，化作桌面風景",
        subline: "全景桌布 · 毛玻璃課卡 · 液態玻璃底欄",
        desc: "全景俯瞰一週日程分佈，課卡層次清晰分明。單雙週智慧過濾，空堂時段一目了然；桌布支援拖曳與平滑手勢縮放，讓課表成為真正賞心悅目的日常工具。",
        tiles: [
          { tag: "自研 Shader", text: "液態玻璃底部導航塢" },
          { tag: "智慧排布", text: "單雙週過濾與空堂高亮" },
          { tag: "手勢調配", text: "桌布位置獨立自由拖曳" }
        ],
        glow: "rgba(41, 121, 255, 0.45)",
        webp: "./screenshots/01-week-timetable.webp",
        png: "./screenshots/01-week-timetable.png",
        name: "週課表"
      },
      {
        num: "02",
        badge: "當日流轉",
        headline: "聚焦當下，從容掌控每節作息",
        subline: "分階段卡片 · 精準節次 · 毫秒級倒數",
        desc: "自動收攏非今日日程，專注此時此刻的教學節奏。下一節課去哪個校區教室、還有多久打鈴、課後去向何處，懸浮卡片自然連續銜接。",
        tiles: [
          { tag: "動態流轉", text: "上課倒數毫秒級追蹤" },
          { tag: "精準節次", text: "教學樓與作息無縫對齊" },
          { tag: "無感承接", text: "課前課中下課狀態流轉" }
        ],
        glow: "rgba(20, 184, 166, 0.42)",
        webp: "./screenshots/02-day-agenda.webp",
        png: "./screenshots/02-day-agenda.png",
        name: "今日日程"
      },
      {
        num: "03",
        badge: "系統級協同",
        headline: "狀態欄靈動流轉，抬眼即知",
        subline: "深度接入小米 HyperOS 焦點通知架構",
        desc: "與狀態欄鏡頭挖孔渾然一體。靈動膠囊毫秒級倒數，下拉大卡片清晰展現課程詳情與授課教師。上課無需反覆解鎖點開 App，資訊自然生長在系統裏。",
        tiles: [
          { tag: "靈動膠囊", text: "鏡頭挖孔毫秒級調度" },
          { tag: "卡片展開", text: "支援自訂欄位與排序" },
          { tag: "勿擾聯動", text: "課前自動靜音課後恢復" }
        ],
        glow: "rgba(0, 122, 255, 0.52)",
        webp: "./screenshots/03-super-island.webp",
        png: "./screenshots/03-super-island.png",
        name: "超級島"
      },
      {
        num: "04",
        badge: "桌面組件生態",
        headline: "全尺寸矩陣，自由編排主屏",
        subline: "2×2 主卡 · 迷你日程 · 課程概覽 · 倒數條",
        desc: "全套小組件覆蓋各種螢幕排版需求。採用原生數據快照高效秒級渲染，極低電量消耗；還支援情侶課表雙人日程透出，抬眼即見彼此安排。",
        tiles: [
          { tag: "全套規格", text: "2×2 / 概覽 / 倒數混搭" },
          { tag: "原生快照", text: "極低能耗背景秒級回應" },
          { tag: "情侶協同", text: "雙人課表同屏即時透出" }
        ],
        glow: "rgba(139, 92, 246, 0.45)",
        webp: "./screenshots/04-home-widgets.webp",
        png: "./screenshots/04-home-widgets.png",
        name: "桌面組件"
      },
      {
        num: "05",
        badge: "場景感知",
        headline: "知曉晴雨溫差，從容出門上課",
        subline: "即時氣溫 · 降水預報 · 出行貼心建議",
        desc: "課程卡片內嵌即時氣象資訊。清晨出門前智慧提示是否攜帶雨具與溫差變化，將氣象感知與日程結合，讓工具具備生活溫度。",
        tiles: [
          { tag: "精準氣象", text: "基於地理位置即時氣溫" },
          { tag: "出行建議", text: "降雨機率與雨具攜帶提示" },
          { tag: "輕量輪詢", text: "不增加額外功耗與負擔" }
        ],
        glow: "rgba(56, 189, 248, 0.45)",
        webp: "./screenshots/05-weather-integration.webp",
        png: "./screenshots/05-weather-integration.png",
        name: "天氣聯動"
      },
      {
        num: "06",
        badge: "視覺美學",
        headline: "質感訂製，觸手可及的液態美",
        subline: "實體卡片 · 高斯磨砂 · 自研 Shader",
        desc: "內建多種視覺材質風格：實體卡片、高斯磨砂柔光以及基於 Impeller Fragment Shader 自研的液態玻璃材質，圓角、字重、透明度隨心微調。",
        tiles: [
          { tag: "自研 Shader", text: "Impeller 液態玻璃材質" },
          { tag: "細節微調", text: "卡片圓角、透明度與字重" },
          { tag: "色彩適配", text: "深淺模式高對比度校準" }
        ],
        glow: "rgba(236, 72, 153, 0.45)",
        webp: "./screenshots/06-appearance-customization.webp",
        png: "./screenshots/06-appearance-customization.png",
        name: "液態外觀"
      },
      {
        num: "07",
        badge: "教務配置中心",
        headline: "化繁為簡，輕鬆駕馭複雜學制",
        subline: "學期週歷 · 作息範本 · 法定節假日排課",
        desc: "支援多套節次作息時間範本切換、開學週次智慧推算、單雙週連續排課以及法定節假日調休自動避讓，全面相容各大高校的特殊排課規則。",
        tiles: [
          { tag: "作息範本", text: "多套時間作息靈活切換" },
          { tag: "調休排課", text: "法定假期與補課自動適配" },
          { tag: "多課表隔離", text: "沙箱數據毫秒級無感切換" }
        ],
        glow: "rgba(245, 158, 11, 0.45)",
        webp: "./screenshots/07-timetable-settings.webp",
        png: "./screenshots/07-timetable-settings.png",
        name: "課表設定"
      },
      {
        num: "08",
        badge: "產品理念",
        headline: "零廣告、無註冊，回歸工具純粹",
        subline: "GPL-3.0 協議 · 本地優先 · 隱私完全掌控",
        desc: "代碼完全開源透明，杜絕流氓常駐與隱私獲取。數據完全由你掌控，支援本地全量加密備份與 WebDAV 雲同步，純粹無負擔，做最可靠的大學伴侶。",
        tiles: [
          { tag: "開源透明", text: "GPL-3.0 協議可獨立審計" },
          { tag: "零騷擾", text: "無開屏廣告、無需註冊帳號" },
          { tag: "本地掌控", text: "WebDAV 與全量數據加密" }
        ],
        glow: "rgba(34, 197, 94, 0.45)",
        webp: "./screenshots/08-about-app.webp",
        png: "./screenshots/08-about-app.png",
        name: "純粹開源"
      }
    ],
    "en": [
      {
        num: "01",
        badge: "Core View",
        headline: "Turn your weekly rhythm into a living view",
        subline: "Panoramic wallpaper · Frosted cards · Liquid glass dock",
        desc: "Get an aerial perspective of your weekly course distribution with tactile glass layers. Smart odd/even week filtering and free time detection. Smooth gesture zoom and wallpaper panning.",
        tiles: [
          { tag: "Custom Shader", text: "Impeller liquid glass dock" },
          { tag: "Smart Layout", text: "Odd/even & free time highlights" },
          { tag: "Gesture Control", text: "Independent wallpaper drag & zoom" }
        ],
        glow: "rgba(41, 121, 255, 0.45)",
        webp: "./screenshots/01-week-timetable.webp",
        png: "./screenshots/01-week-timetable.png",
        name: "Week View"
      },
      {
        num: "02",
        badge: "Daily Flow",
        headline: "Focus on today, in sync with every bell",
        subline: "Staged cards · Precision periods · Millisecond countdown",
        desc: "Seamlessly collapses non-today courses to focus on your immediate class progression. Exact campus, classroom, time left, and post-class schedule flow naturally.",
        tiles: [
          { tag: "Dynamic Flow", text: "Millisecond countdown tracking" },
          { tag: "Precision Bell", text: "Classroom and period alignment" },
          { tag: "Smooth Handoff", text: "Pre-class, in-class, and dismissal" }
        ],
        glow: "rgba(20, 184, 166, 0.42)",
        webp: "./screenshots/02-day-agenda.webp",
        png: "./screenshots/02-day-agenda.png",
        name: "Daily Flow"
      },
      {
        num: "03",
        badge: "System Focus",
        headline: "Dynamic island flow right in your status bar",
        subline: "Deep Xiaomi HyperOS Focus Notification integration",
        desc: "Seamlessly wraps around the front camera punch-hole. Millisecond status bar countdown capsule and expandable focus cards—glance at your class without unlocking your phone.",
        tiles: [
          { tag: "Live Capsule", text: "Punch-hole camera scheduling" },
          { tag: "Card Expand", text: "Customizable fields & ordering" },
          { tag: "Auto DND", text: "Pre-class mute & post-class restore" }
        ],
        glow: "rgba(0, 122, 255, 0.52)",
        webp: "./screenshots/03-super-island.webp",
        png: "./screenshots/03-super-island.png",
        name: "Super Island"
      },
      {
        num: "04",
        badge: "Widget Suite",
        headline: "Full widget matrix, tailor your home screen",
        subline: "2×2 Hero · Mini Agenda · Week Overview · Countdown Strip",
        desc: "Every standard widget size for creative home screen setups. Powered by native OS snapshot rendering for instant zero-lag updates and remarkable battery efficiency.",
        tiles: [
          { tag: "Full Sizes", text: "2×2 / Overview / Countdown mix" },
          { tag: "Native Snapshot", text: "Ultra-low battery background sync" },
          { tag: "Couples Mode", text: "Dual schedule side-by-side" }
        ],
        glow: "rgba(139, 92, 246, 0.45)",
        webp: "./screenshots/04-home-widgets.webp",
        png: "./screenshots/04-home-widgets.png",
        name: "Widgets"
      },
      {
        num: "05",
        badge: "Context Aware",
        headline: "Weather forecasts tailored to your class walks",
        subline: "Real-time temp · Rain probability · Departure tips",
        desc: "Embedded live weather radar on course cards. Know whether to pack an umbrella or an extra jacket before stepping out to morning lectures.",
        tiles: [
          { tag: "Live Weather", text: "Location-based precision climate" },
          { tag: "Travel Advice", text: "Precipitation & umbrella alerts" },
          { tag: "Lightweight", text: "Zero impact on system performance" }
        ],
        glow: "rgba(56, 189, 248, 0.45)",
        webp: "./screenshots/05-weather-integration.webp",
        png: "./screenshots/05-weather-integration.png",
        name: "Weather"
      },
      {
        num: "06",
        badge: "Aesthetics",
        headline: "Custom liquid textures at your fingertips",
        subline: "Solid cards · Gaussian blur · Custom Fragment Shader",
        desc: "Multiple visual design philosophies: from minimalist solid cards to soft frosted glass and custom Impeller Fragment Shader liquid glass dock.",
        tiles: [
          { tag: "Custom Shader", text: "Impeller liquid glass dock" },
          { tag: "Precision Tuning", text: "Corner radius, opacity & weights" },
          { tag: "High Contrast", text: "Calibrated dark and light modes" }
        ],
        glow: "rgba(236, 72, 153, 0.45)",
        webp: "./screenshots/06-appearance-customization.webp",
        png: "./screenshots/06-appearance-customization.png",
        name: "Appearance"
      },
      {
        num: "07",
        badge: "Setup Hub",
        headline: "Tame complex semester schedules with ease",
        subline: "Semester calendar · Period templates · Holiday shifts",
        desc: "Multi-period timetable templates, automatic start date calculation, odd/even week patterns, and statutory holiday shift compensation.",
        tiles: [
          { tag: "Period Templates", text: "Quickly swap custom bell schedules" },
          { tag: "Holiday Shift", text: "Statutory make-up day support" },
          { tag: "Multi Schedule", text: "Sandboxed instant profile switching" }
        ],
        glow: "rgba(245, 158, 11, 0.45)",
        webp: "./screenshots/07-timetable-settings.webp",
        png: "./screenshots/07-timetable-settings.png",
        name: "Settings"
      },
      {
        num: "08",
        badge: "Philosophy",
        headline: "Zero ads, no accounts, pure utility",
        subline: "GPL-3.0 License · Local-first · Total privacy control",
        desc: "100% open source and auditable. No tracking, no startup popups. All data stays securely on your device, with optional WebDAV cloud sync and encrypted backups.",
        tiles: [
          { tag: "Open Source", text: "GPL-3.0 auditable codebase" },
          { tag: "Zero Clutter", text: "No ads, no accounts required" },
          { tag: "Local Control", text: "Encrypted backups & WebDAV sync" }
        ],
        glow: "rgba(34, 197, 94, 0.45)",
        webp: "./screenshots/08-about-app.webp",
        png: "./screenshots/08-about-app.png",
        name: "Open Source"
      }
    ]
  };
  SHOWCASE_DATA["zh-TW"] = SHOWCASE_DATA["zh-HK"];

  function initShowcase() {
    const stage = document.querySelector(".section-showcase");
    if (!stage) return;

    let currentIndex = 0;
    const pills = Array.from(document.querySelectorAll(".showcase-nav-pill"));
    const deviceMockup = document.getElementById("sc-device-mockup");
    const ambientGlow = document.getElementById("sc-ambient-glow");
    const watermark = document.getElementById("sc-watermark");
    const badgeText = document.getElementById("sc-badge-text");
    const headline = document.getElementById("sc-headline");
    const subline = document.getElementById("sc-subline");
    const narrative = document.getElementById("sc-narrative");
    const tilesWrap = document.getElementById("sc-tiles");
    const prevBtn = document.getElementById("sc-prev");
    const nextBtn = document.getElementById("sc-next");
    const progressBar = document.getElementById("sc-progress");
    const counterEl = document.getElementById("sc-counter");
    const filmstrip = document.getElementById("sc-filmstrip");
    const zoomBtn = document.getElementById("sc-open-zoom");
    const mainWebp = document.getElementById("sc-main-webp");
    const mainImg = document.getElementById("sc-main-img");

    // Lightbox elements
    const lightbox = document.getElementById("sc-lightbox");
    const lightboxImg = document.getElementById("sc-lightbox-img");
    const lightboxCaption = document.getElementById("sc-lightbox-caption");
    const lightboxClose = document.getElementById("sc-lightbox-close");
    const lightboxBackdrop = document.getElementById("sc-lightbox-backdrop");

    function getItems() {
      const locale = window.I18n?.getLocale?.() || "zh-CN";
      return SHOWCASE_DATA[locale] || SHOWCASE_DATA["zh-CN"] || SHOWCASE_DATA["en"];
    }

    // Build Progress Segments & Filmstrip Cards dynamically
    function setupFilmstripAndProgress() {
      const items = getItems();
      if (!items) return;

      if (progressBar) {
        progressBar.innerHTML = "";
        items.forEach((_, idx) => {
          const seg = document.createElement("button");
          seg.type = "button";
          seg.className = `sc-prog-seg ${idx === currentIndex ? "is-active" : ""}`;
          seg.setAttribute("aria-label", `界面 ${idx + 1}`);
          seg.addEventListener("click", () => renderItem(idx));
          progressBar.appendChild(seg);
        });
      }

      if (filmstrip) {
        filmstrip.innerHTML = "";
        items.forEach((item, idx) => {
          const card = document.createElement("button");
          card.type = "button";
          card.className = `showcase-filmstrip-card ${idx === currentIndex ? "is-active" : ""}`;
          card.setAttribute("data-index", String(idx));
          card.innerHTML = `
            <div class="showcase-filmstrip-thumb">
              <img src="${item.webp}" alt="${item.name}" loading="lazy" />
            </div>
            <div class="showcase-filmstrip-meta">
              <span class="showcase-filmstrip-num">${item.num}</span>
              <span class="showcase-filmstrip-name">${item.name}</span>
            </div>
          `;
          card.addEventListener("click", () => renderItem(idx));
          filmstrip.appendChild(card);
        });
      }
    }

    function renderItem(index) {
      const items = getItems();
      if (!items || !items[index]) return;
      currentIndex = index;
      const item = items[index];

      // Update Top Nav Pills
      pills.forEach((pill, i) => {
        const active = i === index;
        pill.classList.toggle("is-active", active);
        pill.setAttribute("aria-selected", active ? "true" : "false");
      });

      // Update Filmstrip cards
      const filmCards = document.querySelectorAll(".showcase-filmstrip-card");
      filmCards.forEach((card, i) => {
        card.classList.toggle("is-active", i === index);
      });

      // Update Progress segments
      const segs = document.querySelectorAll(".sc-prog-seg");
      segs.forEach((seg, i) => {
        seg.classList.toggle("is-active", i === index);
      });

      // Update Counter
      if (counterEl) {
        counterEl.textContent = `${item.num} / 0${items.length}`;
      }

      // Update Ambient Glow color
      if (ambientGlow) {
        ambientGlow.style.background = `radial-gradient(circle, ${item.glow} 0%, rgba(20, 184, 166, 0.12) 50%, transparent 72%)`;
      }
      if (deviceMockup) {
        deviceMockup.style.setProperty("--sc-glow", item.glow);
      }

      // Update Editorial Text
      if (watermark) watermark.textContent = item.num;
      if (badgeText) badgeText.textContent = item.badge;
      if (headline) headline.textContent = item.headline;
      if (subline) subline.textContent = item.subline;
      if (narrative) narrative.textContent = item.desc;

      // Update Feature Tiles
      if (tilesWrap && Array.isArray(item.tiles)) {
        tilesWrap.innerHTML = item.tiles
          .map(
            (t) => `
              <div class="showcase-tile">
                <div class="showcase-tile-tag">${t.tag}</div>
                <div class="showcase-tile-text">${t.text}</div>
              </div>`
          )
          .join("");
      }

      // Smooth Device Screen Crossfade
      if (mainImg) {
        mainImg.classList.add("is-changing");
        if (mainWebp) mainWebp.srcset = item.webp;
        mainImg.src = item.png;
        mainImg.alt = `${item.headline} - ${item.name}`;

        const handleLoad = () => {
          mainImg.classList.remove("is-changing");
          mainImg.removeEventListener("load", handleLoad);
        };
        mainImg.addEventListener("load", handleLoad);
        window.setTimeout(() => mainImg.classList.remove("is-changing"), 220);
      }

      // Scroll active filmstrip card into view smoothly
      if (filmCards[index]) {
        filmCards[index].scrollIntoView({
          behavior: "smooth",
          block: "nearest",
          inline: "center"
        });
      }
    }

    // Lightbox Controls
    function openLightbox() {
      const items = getItems();
      const item = items[currentIndex];
      if (!item || !lightbox || !lightboxImg) return;

      lightboxImg.src = item.png;
      lightboxImg.alt = item.headline;
      if (lightboxCaption) {
        lightboxCaption.textContent = `${item.num} · ${item.headline} (${item.subline})`;
      }
      lightbox.hidden = false;
      document.body.style.overflow = "hidden";
    }

    function closeLightbox() {
      if (!lightbox) return;
      lightbox.hidden = true;
      document.body.style.overflow = "";
    }

    if (deviceMockup) {
      deviceMockup.addEventListener("click", openLightbox);
      deviceMockup.addEventListener("keydown", (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          openLightbox();
        }
      });
    }

    if (zoomBtn) {
      zoomBtn.addEventListener("click", openLightbox);
    }

    if (lightboxClose) {
      lightboxClose.addEventListener("click", closeLightbox);
    }
    if (lightboxBackdrop) {
      lightboxBackdrop.addEventListener("click", closeLightbox);
    }
    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape" && lightbox && !lightbox.hidden) {
        closeLightbox();
      }
    });

    // Bind Top Nav Pills
    pills.forEach((pill, i) => {
      pill.addEventListener("click", () => renderItem(i));
    });

    // Bind Prev / Next
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

    // Keyboard Arrow Controls
    stage.addEventListener("keydown", (e) => {
      if (lightbox && !lightbox.hidden) return;
      if (e.key === "ArrowLeft") {
        const items = getItems();
        renderItem((currentIndex - 1 + items.length) % items.length);
      } else if (e.key === "ArrowRight") {
        const items = getItems();
        renderItem((currentIndex + 1) % items.length);
      }
    });

    // Initial setup
    setupFilmstripAndProgress();
    renderItem(0);

    // Re-render when i18n locale changes
    if (window.I18n && typeof window.I18n.onChange === "function") {
      window.I18n.onChange(() => {
        setupFilmstripAndProgress();
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
