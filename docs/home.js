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

  /* ---------- Hero 手机 3D 跟随 ---------- */
  const phone = document.getElementById("hero-phone");
  const heroVisual = phone?.closest(".hero-visual");
  if (phone && heroVisual && !prefersReducedMotion) {
    const maxTilt = 10;

    heroVisual.addEventListener("pointermove", (event) => {
      const rect = heroVisual.getBoundingClientRect();
      const ratioX = (event.clientX - rect.left) / rect.width - 0.5;
      const ratioY = (event.clientY - rect.top) / rect.height - 0.5;
      phone.style.transform = `rotateY(${ratioX * maxTilt}deg) rotateX(${
        -ratioY * maxTilt
      }deg)`;
    });

    heroVisual.addEventListener("pointerleave", () => {
      phone.style.transform = "";
    });
  }

  /* ---------- 页面加载后预取版本信息 ----------
     script.js 原逻辑只在打开下载弹窗时读取 latest.json；
     这里提前触发一次，让下载区「最新正式版更新」与版本数不用等弹窗。 */
  window.addEventListener("load", () => {
    if (typeof loadLatestRelease === "function") {
      void loadLatestRelease();
    }
  });
})();
