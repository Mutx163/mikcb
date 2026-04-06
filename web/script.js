const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  },
  {
    threshold: 0.14,
  }
);

document.querySelectorAll(".reveal").forEach((node) => {
  observer.observe(node);
});

const googleAnalyticsMeasurementId =
  document
    .querySelector('meta[name="google-analytics-measurement-id"]')
    ?.getAttribute("content")
    ?.trim() || "";
const isGoogleAnalyticsEnabled = /^G-[A-Z0-9]+$/i.test(
  googleAnalyticsMeasurementId
);
const isDoNotTrackEnabled =
  navigator.doNotTrack === "1" ||
  window.doNotTrack === "1" ||
  navigator.msDoNotTrack === "1";
const canSendAnalytics = isGoogleAnalyticsEnabled && !isDoNotTrackEnabled;
let googleAnalyticsSetupPromise = null;

function ensureGoogleAnalytics() {
  if (!canSendAnalytics) {
    return Promise.resolve(false);
  }

  if (googleAnalyticsSetupPromise) {
    return googleAnalyticsSetupPromise;
  }

  googleAnalyticsSetupPromise = new Promise((resolve, reject) => {
    window.dataLayer = window.dataLayer || [];
    if (typeof window.gtag !== "function") {
      window.gtag = function gtag() {
        window.dataLayer.push(arguments);
      };
    }

    const finishSetup = () => {
      window.gtag("js", new Date());
      window.gtag("config", googleAnalyticsMeasurementId);
      resolve(true);
    };

    const existingScript = document.querySelector(
      'script[data-google-analytics-loader="true"]'
    );
    if (existingScript) {
      if (existingScript.dataset.failed === "true") {
        existingScript.remove();
      } else if (existingScript.dataset.loaded === "true") {
        finishSetup();
        return;
      } else {
        existingScript.addEventListener("load", finishSetup, { once: true });
        existingScript.addEventListener(
          "error",
          () => reject(new Error("Google Analytics 加载失败")),
          { once: true }
        );
        return;
      }
    }

    const script = document.createElement("script");
    script.async = true;
    script.src = `https://www.googletagmanager.com/gtag/js?id=${encodeURIComponent(
      googleAnalyticsMeasurementId
    )}`;
    script.dataset.googleAnalyticsLoader = "true";
    script.addEventListener(
      "load",
      () => {
        script.dataset.loaded = "true";
        finishSetup();
      },
      { once: true }
    );
    script.addEventListener(
      "error",
      () => {
        script.dataset.failed = "true";
        script.remove();
        reject(new Error("Google Analytics 加载失败"));
      },
      { once: true }
    );
    document.head.appendChild(script);
  }).catch((error) => {
    googleAnalyticsSetupPromise = null;
    return Promise.reject(error);
  });

  return googleAnalyticsSetupPromise;
}

function getDownloadFileName(url) {
  try {
    const pathname = new URL(url, window.location.href).pathname;
    return decodeURIComponent(pathname.split("/").pop() || "");
  } catch (error) {
    return "";
  }
}

function sanitizeUrlForAnalytics(url) {
  try {
    const parsed = new URL(url, window.location.href);
    return `${parsed.origin}${parsed.pathname}`;
  } catch (error) {
    return "";
  }
}

function getSafePageLocation() {
  return sanitizeUrlForAnalytics(window.location.href);
}

function isSafeExternalUrl(url) {
  try {
    const parsed = new URL(url, window.location.href);
    return parsed.protocol === "https:" || parsed.protocol === "http:";
  } catch (error) {
    return false;
  }
}

function trackGoogleAnalyticsEvent(eventName, params = {}, onComplete) {
  if (!canSendAnalytics) {
    onComplete?.();
    return;
  }

  ensureGoogleAnalytics()
    .then(() => {
      const payload = {
        page_location: getSafePageLocation(),
        page_title: document.title,
        ...params,
      };

      if (typeof onComplete === "function") {
        let completed = false;
        const finish = () => {
          if (completed) {
            return;
          }
          completed = true;
          onComplete();
        };
        payload.event_callback = finish;
        payload.event_timeout = 1200;
        window.setTimeout(finish, 1200);
      }

      window.gtag("event", eventName, payload);
    })
    .catch(() => {
      onComplete?.();
    });
}

function buildDownloadAnalyticsPayload(source, url) {
  return {
    download_source: source,
    release_version: normalizeVersion(releaseVersion?.textContent || ""),
    file_name: getDownloadFileName(url),
    link_url: sanitizeUrlForAnalytics(url),
    download_resolved: url && url !== fallbackReleasePage ? 1 : 0,
  };
}

void ensureGoogleAnalytics();

const analyticsSiteVariant = "web";
const analyticsSessionStorageKey = "mikcb-web-analytics-session";
const analyticsSeenSections = new Set();
const sectionLabelMap = {
  top: "顶部",
  overview: "概览",
  experience: "体验",
  features: "能力",
  "time-template": "时间模板",
  platform: "平台",
  download: "下载",
};

function getAnalyticsSessionId() {
  try {
    const existing = window.sessionStorage?.getItem(analyticsSessionStorageKey);
    if (existing) {
      return existing;
    }
    const generated = `s_${Date.now().toString(36)}_${Math.random()
      .toString(36)
      .slice(2, 10)}`;
    window.sessionStorage?.setItem(analyticsSessionStorageKey, generated);
    return generated;
  } catch (error) {
    return `s_${Date.now().toString(36)}`;
  }
}

const analyticsSessionId = getAnalyticsSessionId();

function normalizeAnalyticsValue(value, maxLength = 120) {
  const text = String(value || "").replace(/\s+/g, " ").trim();
  if (!text) {
    return "";
  }
  return text.length > maxLength ? `${text.slice(0, maxLength - 1)}…` : text;
}

function getSectionLabel(sectionId) {
  return sectionLabelMap[sectionId] || normalizeAnalyticsValue(sectionId) || "未命名区块";
}

function inferElementSurfaceLabel(element) {
  const node = element instanceof Element ? element : null;
  if (!node) {
    return "未知区域";
  }
  if (node.closest(".release-dialog") || node.closest("#release-modal")) {
    return "下载弹窗";
  }
  if (node.closest(".global-nav")) {
    return "顶部导航";
  }
  if (node.closest(".hero-section")) {
    return "首屏";
  }
  if (node.closest("#download")) {
    return "下载区";
  }
  if (node.closest("footer")) {
    return "页脚";
  }
  const section = node.closest("section[id]");
  if (section?.id) {
    return getSectionLabel(section.id);
  }
  return "页面主体";
}

function getElementLabel(element) {
  if (!(element instanceof Element)) {
    return "";
  }
  return normalizeAnalyticsValue(
    element.getAttribute("aria-label") ||
      element.getAttribute("title") ||
      element.textContent
  );
}

function buildAnalyticsParams(params = {}) {
  return {
    site_variant: analyticsSiteVariant,
    session_id: analyticsSessionId,
    page_path: window.location.pathname || "/",
    page_language: document.documentElement.lang || "zh-CN",
    ...params,
  };
}

function trackStructuredEvent(eventName, params = {}, onComplete) {
  trackGoogleAnalyticsEvent(
    eventName,
    buildAnalyticsParams(params),
    onComplete
  );
}

function trackSectionView(sectionId) {
  if (!sectionId || analyticsSeenSections.has(sectionId)) {
    return;
  }
  analyticsSeenSections.add(sectionId);
  trackStructuredEvent("section_view", {
    section_id: sectionId,
    section_label: getSectionLabel(sectionId),
  });
}

function openTrackedUrl(url, { newTab = true } = {}) {
  if (!url || !isSafeExternalUrl(url)) {
    return;
  }
  if (newTab) {
    window.open(url, "_blank", "noopener,noreferrer");
    return;
  }
  window.location.assign(url);
}

function bindSectionViewTracking() {
  const trackables = [
    { id: "top", element: document.querySelector(".hero-section") },
    ...Array.from(document.querySelectorAll("main section[id]")).map((element) => ({
      id: element.id,
      element,
    })),
  ].filter((item) => item.id && item.element);

  if (!trackables.length) {
    return;
  }

  if ("IntersectionObserver" in window) {
    const tracker = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && entry.target instanceof HTMLElement) {
            trackSectionView(entry.target.dataset.analyticsSectionId || "");
          }
        });
      },
      {
        threshold: 0.45,
      }
    );

    trackables.forEach((item) => {
      item.element.dataset.analyticsSectionId = item.id;
      tracker.observe(item.element);
    });
    return;
  }

  trackables.forEach((item) => {
    trackSectionView(item.id);
  });
}

const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = String(new Date().getFullYear());
}

const navToggle = document.querySelector(".nav-toggle");
const navMenu = document.getElementById("nav-menu");

function bindGeneralAnalytics() {
  document.querySelectorAll('.nav-links a[href^="#"]').forEach((link) => {
    link.addEventListener("click", () => {
      const targetId = (link.getAttribute("href") || "").replace(/^#/, "");
      trackStructuredEvent("nav_link_click", {
        target_section_id: targetId,
        target_section_label: getSectionLabel(targetId),
        ui_label: getElementLabel(link),
        ui_surface_label: inferElementSurfaceLabel(link),
      });
    });
  });

  navToggle?.addEventListener("click", () => {
    const expanded = navToggle.getAttribute("aria-expanded") === "true";
    trackStructuredEvent("nav_menu_toggle", {
      menu_state: expanded ? "opened" : "closed",
      ui_surface_label: "顶部导航",
      ui_label: "导航菜单",
    });
  });

  document
    .querySelectorAll(
      'a[href="https://github.com/Mutx163/mikcb"], a[href="https://github.com/Mutx163/mikcb/releases"]'
    )
    .forEach((link) => {
      if (
        link === releaseGithubDownload ||
        link === releaseMirrorDownload ||
        link === releasePageLink
      ) {
        return;
      }
      link.addEventListener("click", (event) => {
        const targetUrl = link.href || fallbackReleasePage;
        trackStructuredEvent("outbound_repo_click", {
          destination_host: "github.com",
          destination_path: normalizeAnalyticsValue(
            new URL(targetUrl).pathname,
            160
          ),
          ui_label: getElementLabel(link),
          ui_surface_label: inferElementSurfaceLabel(link),
          link_url: sanitizeUrlForAnalytics(targetUrl),
        });
      });
    });

  releasePageLink?.addEventListener("click", (event) => {
    const targetUrl = releasePageLink.href || fallbackReleasePage;
    trackStructuredEvent("release_page_click", {
      ui_surface_label: "下载弹窗",
      ui_label: getElementLabel(releasePageLink),
      link_url: sanitizeUrlForAnalytics(targetUrl),
      release_version: normalizeVersion(releaseVersion?.textContent || ""),
    });
  });

  bindSectionViewTracking();
}

if (navToggle && navMenu) {
  navToggle.addEventListener("click", () => {
    const expanded = navToggle.getAttribute("aria-expanded") === "true";
    navToggle.setAttribute("aria-expanded", String(!expanded));
    navMenu.classList.toggle("is-open", !expanded);
  });

  navMenu.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      navToggle.setAttribute("aria-expanded", "false");
      navMenu.classList.remove("is-open");
    });
  });
}

const latestReleaseApiUrl =
  "https://api.github.com/repos/Mutx163/mikcb/releases/latest";
const mirrorPrefix = "https://ghfast.top/";
const fallbackReleasePage = "https://github.com/Mutx163/mikcb/releases";

const releaseModal = document.getElementById("release-modal");
const releaseOpenButtons = document.querySelectorAll(".release-open-button");
const releaseCloseButtons = document.querySelectorAll("[data-close-release-modal]");
const releaseVersion = document.getElementById("release-version");
const releasePublishedAt = document.getElementById("release-published-at");
const releaseDescription = document.getElementById("release-description");
const releaseGithubDownload = document.getElementById("release-github-download");
const releaseMirrorDownload = document.getElementById("release-mirror-download");
const releasePageLink = document.getElementById("release-page-link");
const releaseDialogTitle = document.getElementById("release-dialog-title");

let releaseLoaded = false;

function normalizeVersion(raw) {
  return String(raw || "").trim().replace(/^[vV]/, "") || "未知版本";
}

function formatDateTime(raw) {
  if (!raw) {
    return "未知";
  }

  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    return "未知";
  }

  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function pickDownloadUrl(assets) {
  const normalizedAssets = Array.isArray(assets) ? assets : [];

  for (const asset of normalizedAssets) {
    const name = String(asset?.name || "").toLowerCase();
    if (name.endsWith(".apk") && !name.includes("debug")) {
      return asset.browser_download_url || null;
    }
  }

  for (const asset of normalizedAssets) {
    const name = String(asset?.name || "").toLowerCase();
    if (name.endsWith(".apk")) {
      return asset.browser_download_url || null;
    }
  }

  return normalizedAssets[0]?.browser_download_url || null;
}

function buildMirrorUrl(originalUrl) {
  if (!originalUrl) {
    return fallbackReleasePage;
  }
  return `${mirrorPrefix}${originalUrl}`;
}

function setReleaseLoadingState() {
  releaseDialogTitle.textContent = "最新版本";
  releaseDescription.textContent = "正在读取最新发行版信息...";
  releaseVersion.textContent = "读取中";
  releasePublishedAt.textContent = "读取中";
  releaseGithubDownload.href = fallbackReleasePage;
  releaseMirrorDownload.href = fallbackReleasePage;
  releasePageLink.href = fallbackReleasePage;
}

function setReleaseErrorState() {
  releaseDialogTitle.textContent = "暂时无法读取最新版本";
  releaseDescription.textContent =
    "你仍然可以直接打开 GitHub Releases 页面，或者使用镜像入口进行下载。";
  releaseVersion.textContent = "未知";
  releasePublishedAt.textContent = "未知";
  releaseGithubDownload.href = fallbackReleasePage;
  releaseMirrorDownload.href = buildMirrorUrl(fallbackReleasePage);
  releasePageLink.href = fallbackReleasePage;
}

async function loadLatestRelease() {
  if (releaseLoaded) {
    trackStructuredEvent("release_data_load", {
      load_state: "cache_hit",
      release_version: normalizeVersion(releaseVersion?.textContent || ""),
    });
    return;
  }

  setReleaseLoadingState();
  trackStructuredEvent("release_data_load", {
    load_state: "start",
    load_source: "network",
  });

  try {
    const response = await fetch(latestReleaseApiUrl, {
      headers: {
        Accept: "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const release = await response.json();
    const version = normalizeVersion(release.tag_name || release.name);
    const publishedAt = formatDateTime(release.published_at || release.updated_at);
    const releaseUrl = release.html_url || fallbackReleasePage;
    const downloadUrl = pickDownloadUrl(release.assets);
    const body = String(release.body || "").trim();

    releaseDialogTitle.textContent = release.name || `v${version}`;
    releaseDescription.textContent =
      body.length > 120
        ? `${body.slice(0, 120).trim()}...`
        : body || "当前弹窗提供 GitHub 原版与镜像下载入口，方便直接下载安装。";
    releaseVersion.textContent = version;
    releasePublishedAt.textContent = publishedAt;
    releaseGithubDownload.href = downloadUrl || releaseUrl;
    releaseMirrorDownload.href = buildMirrorUrl(downloadUrl || releaseUrl);
    releasePageLink.href = releaseUrl;
    releaseLoaded = true;
    trackStructuredEvent("release_data_load", {
      load_state: "success",
      load_source: "network",
      release_version: version,
      release_asset_name: getDownloadFileName(downloadUrl || releaseUrl),
      has_direct_download: downloadUrl ? 1 : 0,
    });
  } catch (error) {
    trackStructuredEvent("release_data_load", {
      load_state: "error",
      load_source: "network",
      error_name: normalizeAnalyticsValue(error?.message || "unknown", 80),
    });
    setReleaseErrorState();
  }
}

function openReleaseModal(triggerContext = {}) {
  if (!releaseModal) {
    return;
  }
  releaseModal.classList.add("is-open");
  releaseModal.setAttribute("aria-hidden", "false");
  document.body.style.overflow = "hidden";
  trackStructuredEvent("release_modal_open", {
    trigger_label: normalizeAnalyticsValue(triggerContext.label || ""),
    trigger_surface_label: normalizeAnalyticsValue(
      triggerContext.surface || "未知区域"
    ),
  });
  loadLatestRelease();
}

function closeReleaseModal(reason = "button") {
  if (!releaseModal || !releaseModal.classList.contains("is-open")) {
    return;
  }
  releaseModal.classList.remove("is-open");
  releaseModal.setAttribute("aria-hidden", "true");
  document.body.style.overflow = "";
  trackStructuredEvent("release_modal_close", {
    close_reason: reason,
    release_version: normalizeVersion(releaseVersion?.textContent || ""),
  });
}

releaseOpenButtons.forEach((button) => {
  button.addEventListener("click", (event) => {
    event.preventDefault();
    openReleaseModal({
      label: getElementLabel(button),
      surface: inferElementSurfaceLabel(button),
    });
  });
});

releaseCloseButtons.forEach((button) => {
  button.addEventListener("click", () => closeReleaseModal("button"));
});

releaseGithubDownload?.addEventListener("click", (event) => {
  const targetUrl = releaseGithubDownload.href || fallbackReleasePage;
  trackStructuredEvent("app_download_intent", {
    download_source: "github",
    ui_surface_label: "下载弹窗",
    ui_label: getElementLabel(releaseGithubDownload),
    release_version: normalizeVersion(releaseVersion?.textContent || ""),
  });
  trackStructuredEvent(
    "app_download",
    {
      ...buildDownloadAnalyticsPayload("github", targetUrl),
      ui_surface_label: "下载弹窗",
      ui_label: getElementLabel(releaseGithubDownload),
      download_fallback: 0,
    }
  );
  closeReleaseModal("download");
});

releaseMirrorDownload?.addEventListener("click", (event) => {
  const targetUrl = releaseMirrorDownload.href || fallbackReleasePage;
  trackStructuredEvent("app_download_intent", {
    download_source: "mirror",
    ui_surface_label: "下载弹窗",
    ui_label: getElementLabel(releaseMirrorDownload),
    release_version: normalizeVersion(releaseVersion?.textContent || ""),
  });
  trackStructuredEvent(
    "app_download",
    {
      ...buildDownloadAnalyticsPayload("mirror", targetUrl),
      ui_surface_label: "下载弹窗",
      ui_label: getElementLabel(releaseMirrorDownload),
      download_fallback: 0,
    }
  );
  closeReleaseModal("download");
});

bindGeneralAnalytics();

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeReleaseModal("escape");
  }
});
