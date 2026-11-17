/* Microsoft Clarity 同意门（生成页 / 404 专用最小脚本）：
   与 Google Analytics 共用 localStorage["mikcb_analytics_consent"] 与 DNT 判断，
   同意后才注入 Clarity；不引入 script.js 的整份交互逻辑。 */
(function () {
  try {
    var consent = localStorage.getItem("mikcb_analytics_consent");
    var dnt =
      navigator.doNotTrack === "1" ||
      window.doNotTrack === "1" ||
      navigator.msDoNotTrack === "1";
    if (consent !== "granted" || dnt) return;
    if (document.querySelector('script[data-microsoft-clarity-loader="true"]')) return;
    window.clarity =
      window.clarity ||
      function clarityQueue() {
        (window.clarity.q = window.clarity.q || []).push(arguments);
      };
    var s = document.createElement("script");
    s.async = true;
    s.src = "https://www.clarity.ms/tag/zewwj6durg";
    s.dataset.microsoftClarityLoader = "true";
    document.head.appendChild(s);
  } catch (error) {
    /* 存储不可用时静默跳过，与官网同一口径 */
  }
})();
