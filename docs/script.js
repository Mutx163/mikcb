/** 官网文案：优先 I18n，回退中文默认值（无 i18n 脚本时仍可用）。 */
function t(key, fallback, vars) {
  if (window.I18n && typeof window.I18n.t === "function") {
    const translated = window.I18n.t(key, vars);
    if (translated && translated !== key) {
      return translated;
    }
  }
  if (vars && typeof fallback === "string") {
    return Object.keys(vars).reduce(
      (text, name) => text.replaceAll(`{${name}}`, String(vars[name])),
      fallback
    );
  }
  return fallback ?? key;
}

function currentUiLocale() {
  return window.I18n?.getLocale?.() || document.documentElement.lang || "zh-CN";
}

if ("IntersectionObserver" in window) {
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
} else {
  document.querySelectorAll(".reveal").forEach((node) => {
    node.classList.add("is-visible");
  });
}

const scrollRestoreStorageKey = "mikcb-docs-scroll-restore";

function getCurrentPageKey() {
  return `${window.location.pathname}${window.location.search}${window.location.hash}`;
}

function saveScrollPosition() {
  try {
    window.sessionStorage?.setItem(
      scrollRestoreStorageKey,
      JSON.stringify({
        page: getCurrentPageKey(),
        scrollY: Math.max(window.scrollY, 0),
      })
    );
  } catch (error) {
    // Ignore sessionStorage failures.
  }
}

function restoreScrollPositionOnReload() {
  const navigationEntry = performance.getEntriesByType?.("navigation")?.[0];
  if (navigationEntry?.type !== "reload") {
    return;
  }

  try {
    const raw = window.sessionStorage?.getItem(scrollRestoreStorageKey);
    if (!raw) {
      return;
    }

    const saved = JSON.parse(raw);
    if (
      !saved ||
      saved.page !== getCurrentPageKey() ||
      typeof saved.scrollY !== "number"
    ) {
      return;
    }

    document.documentElement.setAttribute("data-scroll-restoring", "true");
    const restore = () => {
      window.scrollTo(0, saved.scrollY);
    };

    restore();
    window.requestAnimationFrame(() => {
      restore();
      window.setTimeout(() => {
        restore();
        document.documentElement.removeAttribute("data-scroll-restoring");
      }, 80);
    });
  } catch (error) {
    document.documentElement.removeAttribute("data-scroll-restoring");
  }
}

if ("scrollRestoration" in window.history) {
  window.history.scrollRestoration = "manual";
}

restoreScrollPositionOnReload();
window.addEventListener("pagehide", saveScrollPosition);
window.addEventListener("beforeunload", saveScrollPosition);

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

function buildDownloadAnalyticsPayload(source, url, channel = "stable") {
  const releaseData = getReleaseDataByChannel(channel);
  return {
    download_source: source,
    release_channel: channel,
    release_version: releaseData?.version || "",
    file_name: getDownloadFileName(url),
    link_url: sanitizeUrlForAnalytics(url),
    download_resolved: url && url !== fallbackReleasePage ? 1 : 0,
  };
}

void ensureGoogleAnalytics();

const analyticsSiteVariant = "docs";
const analyticsSessionStorageKey = "mikcb-docs-analytics-session";
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

function bindGeneralAnalytics() {
  navSectionLinks.forEach((link) => {
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
      release_channel: activeReleaseChannel,
      release_channel_label:
        getReleaseDataByChannel(activeReleaseChannel)?.channelLabel ||
        activeReleaseChannel,
      ui_surface_label: "下载弹窗",
      ui_label: getElementLabel(releasePageLink),
      link_url: sanitizeUrlForAnalytics(targetUrl),
    });
  });

  bindSectionViewTracking();
}

const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = String(new Date().getFullYear());
}
const footerCopyEl = document.getElementById("footer-copy");
if (footerCopyEl && !footerCopyEl.getAttribute("data-i18n")) {
  footerCopyEl.textContent = t(
    "footer.copy",
    `Copyright © ${new Date().getFullYear()} 轻屿课表`,
    { year: new Date().getFullYear() }
  );
}

const navToggle = document.querySelector(".nav-toggle");
const navMenu = document.getElementById("nav-menu");
const navSectionLinks = Array.from(
  document.querySelectorAll('.nav-links a[href^="#"]')
);

if (navToggle && navMenu) {
  const closeNavMenu = () => {
    navToggle.setAttribute("aria-expanded", "false");
    navMenu.classList.remove("is-open");
  };

  navToggle.addEventListener("click", () => {
    const expanded = navToggle.getAttribute("aria-expanded") === "true";
    navToggle.setAttribute("aria-expanded", String(!expanded));
    navMenu.classList.toggle("is-open", !expanded);
  });

  navMenu.querySelectorAll("a").forEach((link) => {
    link.addEventListener("click", () => {
      closeNavMenu();
    });
  });

  document.addEventListener("click", (event) => {
    if (!navMenu.classList.contains("is-open")) {
      return;
    }

    if (navMenu.contains(event.target) || navToggle.contains(event.target)) {
      return;
    }

    closeNavMenu();
  });

  window.addEventListener("resize", () => {
    if (window.innerWidth > 780) {
      closeNavMenu();
    }
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      closeNavMenu();
    }
  });
}

if ("IntersectionObserver" in window && navSectionLinks.length) {
  const sections = navSectionLinks
    .map((link) => ({
      link,
      section: document.querySelector(link.getAttribute("href")),
    }))
    .filter((item) => item.section);

  const setActiveNavLink = (targetId) => {
    navSectionLinks.forEach((link) => {
      const isActive = link.getAttribute("href") === `#${targetId}`;
      link.classList.toggle("is-active", isActive);
      if (isActive) {
        link.setAttribute("aria-current", "location");
      } else {
        link.removeAttribute("aria-current");
      }
    });
  };

  const sectionObserver = new IntersectionObserver(
    (entries) => {
      const visibleEntry = entries
        .filter((entry) => entry.isIntersecting)
        .sort((left, right) => right.intersectionRatio - left.intersectionRatio)[0];
      if (visibleEntry?.target?.id) {
        setActiveNavLink(visibleEntry.target.id);
      }
    },
    {
      rootMargin: "-35% 0px -45% 0px",
      threshold: [0.2, 0.45, 0.7],
    }
  );

  sections.forEach((item) => {
    sectionObserver.observe(item.section);
  });

  const initialHash = window.location.hash.replace(/^#/, "");
  if (initialHash) {
    setActiveNavLink(initialHash);
  } else if (sections[0]?.section?.id) {
    setActiveNavLink(sections[0].section.id);
  }
}

const repoApiUrl = "https://api.github.com/repos/Mutx163/mikcb";
const releasesApiUrl = "./releases/latest.json";
const releaseFeedApiUrl = "./releases/feed.json";
const fallbackReleasePage = "https://github.com/Mutx163/mikcb/releases";
const defaultMirrorPrefix = "https://ghfast.top/";
const globalMirrorProbeKey = "mikcb-docs-fastest-mirror:__global__";
function getMirrorCandidates() {
  return [
    {
      key: "ghfast",
      label: t("js.defaultMirror", "默认镜像"),
      prefix: "https://ghfast.top/",
    },
    {
      key: "ghproxy_cn",
      label: t("js.backupMirror1", "备用镜像 1"),
      prefix: "https://ghproxy.cn/",
    },
    {
      key: "gh_llkk",
      label: t("js.backupMirror2", "备用镜像 2"),
      prefix: "https://gh.llkk.cc/",
    },
  ];
}
const mirrorCandidates = getMirrorCandidates();

const releaseModal = document.getElementById("release-modal");
const releaseOpenButtons = document.querySelectorAll(".release-open-button");
const releaseCloseButtons = document.querySelectorAll("[data-close-release-modal]");
const releaseVersion = document.getElementById("release-version");
const releasePublishedAt = document.getElementById("release-published-at");
const releaseChannel = document.getElementById("release-channel");
const releaseDescription = document.getElementById("release-description");
const releaseGithubDownload = document.getElementById("release-github-download");
const releaseMirrorDownload = document.getElementById("release-mirror-download");
const releasePageLink = document.getElementById("release-page-link");
const releaseDialogTitle = document.getElementById("release-dialog-title");
const releaseCloseButton = document.querySelector(".release-close");
const releaseDialog = document.querySelector(".release-dialog");
const releaseDownloadNote = document.querySelector(".release-download-note");
const releaseChannelSwitch = document.getElementById("release-channel-switch");
const releaseChannelLabel = document.getElementById("release-channel-label");
const releaseChannelTabs = Array.from(
  document.querySelectorAll(".release-channel-tab")
);
const heroStars = document.getElementById("hero-stars");
const trustStars = document.getElementById("trust-stars");
const trustReleases = document.getElementById("trust-releases");
const latestStableHighlights = document.getElementById("latest-stable-highlights");
const releaseTimeline = document.getElementById("release-timeline");

let releaseLoaded = false;
let releaseLoadedAt = 0;
let releaseLoadPromise = null;
let lastFocusedElement = null;
let stableReleaseData = null;
let prereleaseReleaseData = null;
let activeReleaseChannel = "stable";
let trustSignalsLoaded = false;
let trustSignalsPromise = null;
const mirrorProbeCache = new Map();
const mirrorProbePromises = new Map();

function normalizeVersion(raw) {
  return (
    String(raw || "")
      .trim()
      .replace(/^[vV]/, "") || t("js.unknownVersion", "未知版本")
  );
}

function formatDateTime(raw) {
  if (!raw) {
    return t("js.unknown", "未知");
  }

  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    return t("js.unknown", "未知");
  }

  return new Intl.DateTimeFormat(currentUiLocale(), {
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

function buildMirrorUrl(originalUrl, prefix = defaultMirrorPrefix) {
  if (!originalUrl) {
    return fallbackReleasePage;
  }
  return `${prefix}${originalUrl}`;
}

function cleanReleaseLine(line) {
  return String(line || "")
    .replace(/^[-*+]\s+/, "")
    .replace(/^#{1,6}\s+/, "")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/__([^_]+)__/g, "$1")
    .trim();
}

// 累计式 Release 说明会包含多个「## vX.Y」分段，这里只取最后一个版本的段落。
function extractLatestVersionSection(rawBody) {
  const body = String(rawBody || "");
  const versionSections = body.split(/^#{2,}\s*v[\d.]+.*$/im);
  if (versionSections.length > 1) {
    const lastSection = versionSections[versionSections.length - 1].trim();
    if (lastSection) {
      return lastSection;
    }
  }
  return body;
}

function buildReleaseDescription(rawBody, releaseHints = []) {
  const normalizedHints = releaseHints
    .map((item) => cleanReleaseLine(item).toLowerCase())
    .filter(Boolean);
  const lines = extractLatestVersionSection(rawBody)
    .split(/\r?\n/)
    .map(cleanReleaseLine)
    .filter((line) => {
      if (!line) {
        return false;
      }

      const normalizedLine = line.toLowerCase();
      return !normalizedHints.some(
        (hint) =>
          normalizedLine === hint ||
          normalizedLine === `v${hint}` ||
          (/^(版本|版本号|version|release)\s*[:：-]\s*/i.test(normalizedLine) &&
            normalizedLine.replace(/^(版本|版本号|version|release)\s*[:：-]\s*/i, "") ===
              hint) ||
          normalizedLine.startsWith(`${hint} ·`) ||
          normalizedLine.startsWith(`${hint} -`)
      );
    });

  if (!lines.length) {
    return t("js.releaseBodyFallback", "当前弹窗提供 GitHub 原版与镜像下载入口，方便直接下载安装。");
  }

  const preview = lines.slice(0, 3).join(" · ");
  return preview.length > 160 ? `${preview.slice(0, 160).trim()}…` : preview;
}

function getFocusableElements(container) {
  if (!container) {
    return [];
  }

  return Array.from(
    container.querySelectorAll(
      'a[href], button:not([disabled]), [tabindex]:not([tabindex="-1"])'
    )
  ).filter((node) => !node.hasAttribute("hidden"));
}

function hasUsableReleaseDownloadUrl(release) {
  return Boolean(pickDownloadUrl(release?.assets));
}

function pickReleaseGroup(releases) {
  const normalizedReleases = Array.isArray(releases) ? releases : [];
  const published = normalizedReleases.filter(
    (item) => !item?.draft && hasUsableReleaseDownloadUrl(item)
  );
  const stable = published.find((item) => item?.prerelease !== true) || null;
  const prerelease = published.find((item) => item?.prerelease === true) || null;
  return {
    stable: stable || published[0] || null,
    prerelease,
  };
}

function normalizeReleaseRecord(release, channelLabel) {
  if (!release) {
    return null;
  }

  const releaseUrl = release.html_url || fallbackReleasePage;
  const downloadUrl = pickDownloadUrl(release.assets) || releaseUrl;
  const version = normalizeVersion(release.tag_name || release.name);
  const title = release.name || release.tag_name || "最新版本";
  const primaryAsset = Array.isArray(release.assets)
    ? release.assets.find((asset) =>
        String(asset?.name || "").toLowerCase().endsWith(".apk")
      ) || release.assets[0]
    : null;
  return {
    channelLabel: release.prerelease ? t("js.channelPrerelease", "预发布") : channelLabel,
    version,
    title,
    publishedAt: formatDateTime(release.published_at || release.updated_at),
    rawBody: release.body || "",
    description: buildReleaseDescription(release.body || "", [
      title,
      version,
      `v${version}`,
    ]),
    releaseUrl,
    downloadUrl,
    assetName: String(primaryAsset?.name || ""),
    assetCount: Array.isArray(release.assets) ? release.assets.length : 0,
    assetDownloadCount:
      Number(primaryAsset?.download_count || 0) ||
      (Array.isArray(release.assets)
        ? release.assets.reduce(
            (sum, asset) => sum + (Number(asset?.download_count || 0) || 0),
            0
          )
        : 0),
  };
}

function normalizeCompactReleaseRecord(release, channelLabel) {
  if (!release) {
    return null;
  }

  const rawBody = String(release.body || release.rawBody || "");
  const version = normalizeVersion(
    release.version || release.tagName || release.tag_name || release.title || release.name
  );
  const title =
    String(release.title || release.name || release.tagName || release.tag_name || "").trim() ||
    (version ? `v${version}` : "最新版本");
  const releaseUrl = release.releaseUrl || release.html_url || fallbackReleasePage;
  const downloadUrl = release.downloadUrl || release.browser_download_url || releaseUrl;

  return {
    channelLabel: String(release.channelLabel || channelLabel),
    version,
    title,
    publishedAt: formatDateTime(
      release.publishedAt || release.published_at || release.updatedAt || release.updated_at
    ),
    rawBody,
    description: buildReleaseDescription(rawBody, [title, version, `v${version}`]),
    releaseUrl,
    downloadUrl,
    assetName: String(release.assetName || ""),
    assetCount: Number(release.assetCount || 0) || 0,
    assetDownloadCount: Number(release.assetDownloadCount || 0) || 0,
  };
}

function normalizeStoredReleasePayload(payload) {
  if (Array.isArray(payload)) {
    const grouped = pickReleaseGroup(payload);
    return {
      stable: normalizeReleaseRecord(grouped.stable, t("js.channelStable", "正式版")),
      prerelease: normalizeReleaseRecord(grouped.prerelease, t("js.channelPrerelease", "预发布")),
      releaseCount: payload.length,
    };
  }

  if (!payload || typeof payload !== "object") {
    return null;
  }

  return {
    stable: normalizeCompactReleaseRecord(payload.stable, t("js.channelStable", "正式版")),
    prerelease: normalizeCompactReleaseRecord(payload.prerelease, t("js.channelPrerelease", "预发布")),
    releaseCount: Number(payload.releaseCount || 0) || 0,
  };
}

function formatCompactCount(value) {
  const number = Number(value) || 0;
  try {
    return new Intl.NumberFormat(currentUiLocale(), {
      notation: "compact",
      maximumFractionDigits: 1,
    }).format(number);
  } catch {
    if (number >= 10000) {
      return `${(number / 10000).toFixed(number >= 100000 ? 0 : 1)} 万`;
    }
    if (number >= 1000) {
      return `${(number / 1000).toFixed(number >= 10000 ? 0 : 1)}k`;
    }
    return String(number);
  }
}

function extractReleaseHighlights(rawBody, fallbackDescription) {
  const lines = extractLatestVersionSection(rawBody)
    .split(/\r?\n/)
    .map((line) => line.replace(/^[-*]\s*/, "").trim())
    .filter(Boolean)
    .filter(
      (line) => !/^#/.test(line) && !/^v\d/i.test(line) && line !== "---"
    );
  if (lines.length) {
    return lines.slice(0, 3);
  }
  return [fallbackDescription || t("js.highlightFallback", "最近版本更新内容会显示在这里。")];
}

function renderLatestStableHighlights(releaseData) {
  if (!latestStableHighlights || !releaseData) {
    return;
  }
  const highlights = extractReleaseHighlights(
    releaseData.rawBody,
    releaseData.description
  );
  latestStableHighlights.innerHTML = "";
  highlights.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = item;
    latestStableHighlights.appendChild(li);
  });
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function formatReleaseDate(raw) {
  if (!raw) {
    return "";
  }
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  return date.toISOString().slice(0, 10);
}

function normalizeChangeType(type) {
  const label = String(type || "").trim();
  if (/新增|feature|new/i.test(label)) {
    return { label: t("js.chipNew", "新增"), className: "chip-new" };
  }
  if (/修复|fix/i.test(label)) {
    return { label: t("js.chipFix", "修复"), className: "chip-fix" };
  }
  if (/测试|test/i.test(label)) {
    return { label: t("js.chipTest", "测试"), className: "chip-test" };
  }
  if (/移除|删除|remove/i.test(label)) {
    return { label: t("js.chipRemove", "移除"), className: "chip-remove" };
  }
  if (/调整|change|adjust/i.test(label)) {
    return { label: t("js.chipChange", "调整"), className: "chip-change" };
  }
  return { label: t("js.chipOpt", "优化"), className: "chip-opt" };
}

function stripRepeatedChangePrefix(text, typeLabel) {
  const normalizedText = String(text || "").trim();
  const normalizedType = String(typeLabel || "").trim();
  if (!normalizedText || !normalizedType) {
    return normalizedText;
  }

  const escapedType = normalizedType.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return normalizedText.replace(
    new RegExp(`^${escapedType}\\s*[：:]?\\s*`),
    ""
  );
}

function renderReleaseTimeline(feed) {
  if (!releaseTimeline) {
    return;
  }

  const releases = Array.isArray(feed?.releases) ? feed.releases : [];
  const visibleReleases = releases.filter(Boolean).slice(0, 6);
  if (!visibleReleases.length) {
    releaseTimeline.innerHTML =
      '<article class="tl-item reveal is-visible" data-spotlight>' +
      '<div class="tl-node"><span class="tl-dot tl-dot-live"></span></div>' +
      '<div class="tl-card"><header class="tl-head"><h3>' +
      escapeHtml(t("js.timelineEmptyTitle", "暂时无法读取更新日志")) +
      '</h3>' +
      '<span class="tl-badge">' +
      escapeHtml(t("js.timelineEmptyBadge", "稍后重试")) +
      '</span></header>' +
      '<p class="tl-status">' +
      escapeHtml(t("js.timelineEmptyStatus", "可以先打开 GitHub Releases 查看完整更新内容。")) +
      '</p></div></article>';
    return;
  }

  releaseTimeline.innerHTML = visibleReleases
    .map((release, index) => {
      const version = normalizeVersion(release.version || release.tagName || release.title);
      const dateLabel = formatReleaseDate(release.publishedAt);
      const changes = Array.isArray(release.highlights) ? release.highlights.slice(0, 5) : [];
      const isLatest = index === 0;
      const isMajor = /^2\.0$/.test(version);
      const channelLabel = release.prerelease ? t("js.channelPrerelease", "预发布") : t("js.channelStable", "正式版");
      const badgeClass = isLatest
        ? "tl-badge-new"
        : release.prerelease
          ? "tl-badge-feature"
          : isMajor
            ? "tl-badge-major"
            : "";
      const dotClass = isLatest ? "tl-dot-live" : isMajor ? "tl-dot-major" : "";
      const cardClass = isMajor ? " tl-card-major" : "";
      const badgeText = isLatest ? t("js.timelineLatest", "最新 · {channel}", { channel: channelLabel }) : channelLabel;
      const listHtml = changes.length
        ? changes
            .map((item) => {
              const type = normalizeChangeType(item.type);
              return `<li><i class="chip ${type.className}">${type.label}</i>${escapeHtml(
                stripRepeatedChangePrefix(item.text, type.label)
              )}</li>`;
            })
            .join("")
        : `<li><i class="chip chip-opt">${escapeHtml(t("js.chipUpdate", "更新"))}</i>${escapeHtml(
            release.description || t("js.timelineMore", "查看 Release 页面了解更多")
          )}</li>`;

      return (
        '<article class="tl-item reveal is-visible" data-spotlight>' +
        `<div class="tl-node"><span class="tl-dot ${dotClass}"></span></div>` +
        `<div class="tl-card${cardClass}">` +
        '<header class="tl-head">' +
        `<h3>v${escapeHtml(version)}</h3>` +
        `<span class="tl-badge ${badgeClass}">${escapeHtml(badgeText)}</span>` +
        (dateLabel ? `<time>${escapeHtml(dateLabel)}</time>` : "") +
        "</header>" +
        `<ul class="tl-list">${listHtml}</ul>` +
        "</div></article>"
      );
    })
    .join("");
}

async function loadReleaseTimeline() {
  if (!releaseTimeline) {
    return;
  }
  try {
    const response = await fetch(releaseFeedApiUrl, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    renderReleaseTimeline(await response.json());
  } catch (error) {
    renderReleaseTimeline({ releases: [] });
  }
}

function renderTrustSignals({
  stars = 0,
  releaseCount = 0,
  showStars = true,
} = {}) {
  if (heroStars) {
    heroStars.textContent = showStars
      ? `GitHub Star ${formatCompactCount(stars)}`
      : "GitHub Star";
  }
  if (trustStars) {
    trustStars.textContent = showStars ? formatCompactCount(stars) : "—";
  }
  if (trustReleases && Number(releaseCount) > 0) {
    trustReleases.textContent = formatCompactCount(releaseCount);
  }
}

async function loadTrustSignals(releases = 0) {
  if (trustSignalsLoaded) {
    return;
  }
  if (trustSignalsPromise) {
    return trustSignalsPromise;
  }

  const releaseCount = Array.isArray(releases)
    ? releases.length
    : Number(releases || 0) || 0;

  trustSignalsPromise = (async () => {
    let stars = 0;
    let showStars = false;

    try {
      const response = await fetch(repoApiUrl, {
        cache: "no-store",
        headers: {
          Accept: "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
        },
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const repo = await response.json();
      stars = Number(repo?.stargazers_count || 0);
      showStars = true;
    } catch (error) {
      try {
        const badgeResponse = await fetch(
          "https://img.shields.io/github/stars/Mutx163/mikcb.json",
          { cache: "no-store" }
        );
        if (badgeResponse.ok) {
          const badge = await badgeResponse.json();
          const raw = badge?.message || badge?.value;
          if (raw) {
            const parsed = Number(String(raw).replace(/,/g, ""));
            if (!Number.isNaN(parsed)) {
              stars = parsed;
              showStars = true;
            }
          }
        }
      } catch {
        // ignore
      }
    }

    renderTrustSignals({ stars, releaseCount, showStars });
    trustSignalsLoaded = true;
    trustSignalsPromise = null;
  })();

  return trustSignalsPromise;
}

function compareVersionStrings(left, right) {
  const leftParts = String(left || "")
    .split('.')
    .map((part) => Number.parseInt(part, 10) || 0);
  const rightParts = String(right || "")
    .split('.')
    .map((part) => Number.parseInt(part, 10) || 0);
  const maxLength = Math.max(leftParts.length, rightParts.length);

  for (let index = 0; index < maxLength; index += 1) {
    const leftValue = leftParts[index] || 0;
    const rightValue = rightParts[index] || 0;
    if (leftValue > rightValue) {
      return 1;
    }
    if (leftValue < rightValue) {
      return -1;
    }
  }

  return 0;
}

function hasUsablePrerelease() {
  if (!prereleaseReleaseData) {
    return false;
  }

  if (!stableReleaseData) {
    return true;
  }

  return compareVersionStrings(
    prereleaseReleaseData.version,
    stableReleaseData.version
  ) > 0;
}

function setMirrorButtonLoading(button, isLoading) {
  if (!button) {
    return;
  }

  if (!button.dataset.originalLabel) {
    button.dataset.originalLabel = button.textContent.trim();
  }

  button.textContent = isLoading ? t("js.preparing", "准备中...") : button.dataset.originalLabel;
  button.setAttribute("aria-busy", isLoading ? "true" : "false");
  button.style.pointerEvents = isLoading ? "none" : "";
  button.style.opacity = isLoading ? "0.72" : "";
}

function getReleaseDataByChannel(channel = activeReleaseChannel) {
  return channel === "prerelease" ? prereleaseReleaseData : stableReleaseData;
}

function updateReleaseChannelTabs() {
  const hasPrerelease = hasUsablePrerelease();

  if (releaseChannelSwitch) {
    releaseChannelSwitch.hidden = !hasPrerelease;
  }

  if (releaseChannelLabel) {
    releaseChannelLabel.style.display = hasPrerelease ? "none" : "block";
  }

  releaseChannelTabs.forEach((tab) => {
    const isPrereleaseTab = tab.dataset.releaseChannel === "prerelease";
    const isDisabled = isPrereleaseTab && !hasPrerelease;
    const isActive = tab.dataset.releaseChannel === activeReleaseChannel;
    tab.disabled = isDisabled;
    tab.hidden = isPrereleaseTab && !hasPrerelease;
    tab.classList.toggle("is-active", isActive && !isDisabled);
    tab.setAttribute("aria-pressed", isActive && !isDisabled ? "true" : "false");
  });
}

function renderReleaseData(channel = activeReleaseChannel) {
  const releaseData = getReleaseDataByChannel(channel);
  if (!releaseData) {
    return;
  }

  activeReleaseChannel = channel;
  releaseDialogTitle.textContent = t("js.downloadTitle", "下载轻屿课表");
  if (releaseDialog) {
    releaseDialog.dataset.releaseChannel = channel;
  }
  releaseDescription.textContent = releaseData.description;
  releaseChannel.textContent = releaseData.channelLabel;
  releaseVersion.textContent = releaseData.version;
  releasePublishedAt.textContent = releaseData.publishedAt;
  releaseGithubDownload.href = releaseData.downloadUrl;
  releaseMirrorDownload.href = buildMirrorUrl(releaseData.downloadUrl);
  releasePageLink.href = releaseData.releaseUrl;
  updateReleaseChannelTabs();
}

function getMirrorCandidateByPrefix(prefix) {
  return (
    mirrorCandidates.find((candidate) => candidate.prefix === prefix) || {
      key: "unknown",
      label: t("js.unknownMirror", "未知镜像"),
      prefix,
    }
  );
}

async function probeMirrorCandidate(candidate, probeTarget) {
  const probeUrl = buildMirrorUrl(probeTarget, candidate.prefix);
  const startedAt = performance.now();

  const probePromise = fetch(probeUrl, {
    mode: "no-cors",
    cache: "no-store",
  })
    .then(() => ({ ok: true }))
    .catch(() => ({ ok: false }));

  const timeoutPromise = new Promise((resolve) => {
    window.setTimeout(() => resolve({ ok: false }), 1800);
  });

  const result = await Promise.race([probePromise, timeoutPromise]);
  if (!result.ok) {
    return null;
  }

  return {
    ...candidate,
    duration: performance.now() - startedAt,
  };
}

function getCachedMirrorPrefix(cacheKey) {
  if (mirrorProbeCache.has(cacheKey)) {
    return mirrorProbeCache.get(cacheKey);
  }

  const cachedPrefix = window.sessionStorage?.getItem(cacheKey);
  if (cachedPrefix) {
    mirrorProbeCache.set(cacheKey, cachedPrefix);
    return cachedPrefix;
  }

  return null;
}

function setCachedMirrorPrefix(cacheKey, prefix) {
  mirrorProbeCache.set(cacheKey, prefix);
  window.sessionStorage?.setItem(cacheKey, prefix);
}

function resolveMirrorPrefix(cacheKey, probeTarget) {
  const cachedPrefix = getCachedMirrorPrefix(cacheKey);
  if (cachedPrefix) {
    return Promise.resolve(cachedPrefix);
  }

  if (mirrorProbePromises.has(cacheKey)) {
    return mirrorProbePromises.get(cacheKey);
  }

  const probePromise = Promise.all(
    mirrorCandidates.map((candidate) =>
      probeMirrorCandidate(candidate, probeTarget)
    )
  )
    .then((results) => {
      const best = results
        .filter(Boolean)
        .sort((left, right) => left.duration - right.duration)[0];
      const resolvedPrefix = best?.prefix || defaultMirrorPrefix;
      setCachedMirrorPrefix(cacheKey, resolvedPrefix);
      return resolvedPrefix;
    })
    .finally(() => {
      mirrorProbePromises.delete(cacheKey);
    });

  mirrorProbePromises.set(cacheKey, probePromise);
  return probePromise;
}

function prewarmGlobalMirror() {
  return resolveMirrorPrefix(globalMirrorProbeKey, fallbackReleasePage);
}

async function resolveBestMirrorPrefix(downloadUrl) {
  const normalizedDownloadUrl = downloadUrl || `${fallbackReleasePage}/latest`;
  const cacheKey = `mikcb-docs-fastest-mirror:${normalizedDownloadUrl}`;
  const cachedPrefix = getCachedMirrorPrefix(cacheKey);
  if (cachedPrefix) {
    return cachedPrefix;
  }

  const cachedGlobalPrefix = getCachedMirrorPrefix(globalMirrorProbeKey);
  if (cachedGlobalPrefix) {
    void resolveMirrorPrefix(cacheKey, normalizedDownloadUrl).catch(() => {});
    return cachedGlobalPrefix;
  }

  const globalProbePromise = mirrorProbePromises.get(globalMirrorProbeKey);
  if (globalProbePromise) {
    const resolvedGlobalPrefix = await globalProbePromise.catch(() => null);
    if (resolvedGlobalPrefix) {
      void resolveMirrorPrefix(cacheKey, normalizedDownloadUrl).catch(() => {});
      return resolvedGlobalPrefix;
    }
  }

  return resolveMirrorPrefix(cacheKey, normalizedDownloadUrl);
}

function triggerDownload(url) {
  if (!isSafeExternalUrl(url)) {
    return;
  }
  if (!url || url === fallbackReleasePage) {
    window.location.assign(fallbackReleasePage);
    return;
  }

  let transportFrame = document.getElementById("download-transport-frame");
  if (!(transportFrame instanceof HTMLIFrameElement)) {
    transportFrame = document.createElement("iframe");
    transportFrame.id = "download-transport-frame";
    transportFrame.hidden = true;
    transportFrame.setAttribute("aria-hidden", "true");
    document.body.appendChild(transportFrame);
  }

  transportFrame.src = "";
  window.setTimeout(() => {
    transportFrame.src = url;
  }, 0);
}

async function ensureReleaseDownloadUrl(channel = "stable") {
  const currentData =
    channel === "prerelease" ? prereleaseReleaseData : stableReleaseData;
  if (currentData?.downloadUrl) {
    return currentData.downloadUrl;
  }

  const releaseGroup = await loadLatestRelease();
  return channel === "prerelease"
    ? releaseGroup?.prerelease?.downloadUrl || null
    : releaseGroup?.stable?.downloadUrl || null;
}

async function startMirrorDownload(button, channel = "stable") {
  setMirrorButtonLoading(button, true);
  let targetUrl = fallbackReleasePage;
  const releaseData = getReleaseDataByChannel(channel);
  trackStructuredEvent("app_download_intent", {
    download_source: "mirror",
    release_channel: channel,
    release_channel_label: releaseData?.channelLabel || channel,
    release_version: releaseData?.version || "",
    ui_surface_label: "下载弹窗",
    ui_label: getElementLabel(button),
  });
  try {
    updateMirrorPrewarmState(t("js.preparingDownload", "正在准备下载..."));
    targetUrl = (await ensureReleaseDownloadUrl(channel)) || fallbackReleasePage;
    updateMirrorPrewarmState(t("js.connectingRoute", "正在连接下载线路..."));
    const bestPrefix = await resolveBestMirrorPrefix(targetUrl);
    const finalUrl = buildMirrorUrl(targetUrl, bestPrefix);
    const mirrorCandidate = getMirrorCandidateByPrefix(bestPrefix);
    trackStructuredEvent("mirror_resolution", {
      resolution_state: "resolved",
      release_channel: channel,
      release_channel_label: releaseData?.channelLabel || channel,
      release_version: releaseData?.version || "",
      mirror_provider: mirrorCandidate.key,
      mirror_provider_label: mirrorCandidate.label,
      link_url: finalUrl,
    });
    trackStructuredEvent(
      "app_download",
      {
        ...buildDownloadAnalyticsPayload("mirror", finalUrl, channel),
        release_channel_label: releaseData?.channelLabel || channel,
        release_title: releaseData?.title || "",
        release_asset_name: releaseData?.assetName || "",
        release_asset_count: releaseData?.assetCount || 0,
        mirror_provider: mirrorCandidate.key,
        mirror_provider_label: mirrorCandidate.label,
        download_fallback: 0,
      }
    );
    triggerDownload(finalUrl);
    updateMirrorPrewarmState(t("js.downloadStarted", "已开始下载，可切换 GitHub 原版。"));
  } catch (error) {
    const fallbackUrl = buildMirrorUrl(targetUrl, defaultMirrorPrefix);
    const mirrorCandidate = getMirrorCandidateByPrefix(defaultMirrorPrefix);
    trackStructuredEvent("mirror_resolution", {
      resolution_state: "fallback",
      release_channel: channel,
      release_channel_label: releaseData?.channelLabel || channel,
      release_version: releaseData?.version || "",
      mirror_provider: mirrorCandidate.key,
      mirror_provider_label: mirrorCandidate.label,
      link_url: fallbackUrl,
    });
    trackStructuredEvent(
      "app_download",
      {
        ...buildDownloadAnalyticsPayload("mirror", fallbackUrl, channel),
        release_channel_label: releaseData?.channelLabel || channel,
        release_title: releaseData?.title || "",
        release_asset_name: releaseData?.assetName || "",
        release_asset_count: releaseData?.assetCount || 0,
        mirror_provider: mirrorCandidate.key,
        mirror_provider_label: mirrorCandidate.label,
        download_fallback: 1,
      }
    );
    triggerDownload(fallbackUrl);
    updateMirrorPrewarmState(t("js.fallbackRoute", "已切到默认线路，可改用 GitHub 原版。"));
  } finally {
    window.setTimeout(() => {
      setMirrorButtonLoading(button, false);
    }, 800);
  }
}

function updateMirrorPrewarmState(message) {
  if (releaseDownloadNote) {
    releaseDownloadNote.textContent = message;
  }
}

async function prewarmMirrorForRelease(releaseData) {
  if (!releaseData?.downloadUrl) {
    return defaultMirrorPrefix;
  }
  return resolveBestMirrorPrefix(releaseData.downloadUrl);
}

async function prewarmReleaseDownloads() {
  const warmTargets = [stableReleaseData, prereleaseReleaseData].filter(Boolean);
  if (!warmTargets.length) {
    return;
  }

  updateMirrorPrewarmState(t("js.probingRoutes", "正在测速国内下载线路，稍后点下载会更快响应。"));
  try {
    await Promise.all(warmTargets.map((item) => prewarmMirrorForRelease(item)));
    updateMirrorPrewarmState(t("js.routesReady", "下载线路已就绪。"));
  } catch (error) {
    updateMirrorPrewarmState(t("js.routesFallback", "国内下载会自动回退可用线路。"));
  }
}

function setReleaseLoadingState() {
  releaseDialogTitle.textContent = t("js.downloadTitle", "下载轻屿课表");
  if (releaseDialog) {
    releaseDialog.dataset.releaseChannel = "stable";
  }
  releaseDescription.textContent = t("js.loadingVersion", "正在读取版本信息...");
  activeReleaseChannel = "stable";
  releaseChannel.textContent = t("js.channelStable", "正式版");
  releaseVersion.textContent = t("modal.reading", "读取中");
  releasePublishedAt.textContent = t("modal.reading", "读取中");
  releaseGithubDownload.href = fallbackReleasePage;
  releaseMirrorDownload.href = fallbackReleasePage;
  releasePageLink.href = fallbackReleasePage;
  updateReleaseChannelTabs();
  updateMirrorPrewarmState(t("js.preparingRoutes", "正在准备下载线路..."));
}

function setReleaseErrorState() {
  releaseDialogTitle.textContent = t("js.errorTitle", "暂时无法读取最新版本");
  if (releaseDialog) {
    releaseDialog.dataset.releaseChannel = "stable";
  }
  releaseDescription.textContent = t(
    "js.errorDesc",
    "你仍然可以直接打开 GitHub Releases 页面，或者使用镜像入口进行下载。"
  );
  releaseChannel.textContent = t("js.channelStable", "正式版");
  releaseVersion.textContent = t("js.unknown", "未知");
  releasePublishedAt.textContent = t("js.unknown", "未知");
  releaseGithubDownload.href = fallbackReleasePage;
  releaseMirrorDownload.href = buildMirrorUrl(fallbackReleasePage);
  releasePageLink.href = fallbackReleasePage;
  prereleaseReleaseData = null;
  activeReleaseChannel = "stable";
  updateReleaseChannelTabs();
  updateMirrorPrewarmState(t("js.errorNote", "当前会直接尝试可用下载线路。"));
}

const releaseCacheTtlMs = 15 * 1000;

function applyLoadedReleaseGroup({
  stable,
  prerelease,
  releaseCount = 0,
  loadSource,
  successMessage,
}) {
  stableReleaseData = stable;
  prereleaseReleaseData = prerelease;

  if (!stableReleaseData) {
    throw new Error("No release data");
  }

  renderLatestStableHighlights(stableReleaseData);
  void loadTrustSignals(releaseCount);

  if (hasUsablePrerelease()) {
    activeReleaseChannel =
      activeReleaseChannel === "prerelease" ? "prerelease" : "stable";
  } else {
    activeReleaseChannel = "stable";
  }

  renderReleaseData(activeReleaseChannel);
  releaseLoaded = true;
  releaseLoadedAt = Date.now();
  trackStructuredEvent("release_data_load", {
    load_state: "success",
    load_source: loadSource,
    stable_version: stableReleaseData?.version || "",
    prerelease_version: prereleaseReleaseData?.version || "",
    has_prerelease: hasUsablePrerelease() ? 1 : 0,
  });
  updateMirrorPrewarmState(successMessage);
  return {
    stable: stableReleaseData,
    prerelease: prereleaseReleaseData,
  };
}

async function loadLatestRelease() {
  if (releaseLoaded && Date.now() - releaseLoadedAt < releaseCacheTtlMs) {
    trackStructuredEvent("release_data_load", {
      load_state: "cache_hit",
      release_channel: activeReleaseChannel,
      release_channel_label:
        getReleaseDataByChannel(activeReleaseChannel)?.channelLabel ||
        activeReleaseChannel,
      release_version: getReleaseDataByChannel(activeReleaseChannel)?.version || "",
    });
    return {
      stable: stableReleaseData,
      prerelease: prereleaseReleaseData,
    };
  }

  if (releaseLoadPromise) {
    return releaseLoadPromise;
  }

  setReleaseLoadingState();
  trackStructuredEvent("release_data_load", {
    load_state: "start",
    load_source: "network",
  });

  releaseLoadPromise = (async () => {
    try {
      const response = await fetch(releasesApiUrl, {
        cache: "no-store",
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const releases = await response.json();
      const normalizedPayload = normalizeStoredReleasePayload(releases);
      if (!normalizedPayload) {
        throw new Error("Invalid release payload");
      }

      return applyLoadedReleaseGroup({
        stable: normalizedPayload.stable,
        prerelease: normalizedPayload.prerelease,
        releaseCount: normalizedPayload.releaseCount,
        loadSource: "network",
        successMessage: "已读取最新版本信息。",
      });
    } catch (error) {
      trackStructuredEvent("release_data_load", {
        load_state: "error",
        load_source: "network",
        error_name: normalizeAnalyticsValue(error?.message || "unknown", 80),
      });
      setReleaseErrorState();
      renderLatestStableHighlights({
        rawBody: "",
        description: "暂时无法读取最近更新，仍可直接打开 Releases 查看详情。",
      });
      void loadTrustSignals(0);
      return null;
    } finally {
      releaseLoadPromise = null;
    }
  })();

  return releaseLoadPromise;
}

void loadTrustSignals([]);
void loadReleaseTimeline();

function openReleaseModal(triggerContext = {}) {
  if (!releaseModal || !releaseDialog) {
    return;
  }
  lastFocusedElement = document.activeElement;
  releaseModal.classList.add("is-open");
  releaseModal.setAttribute("aria-hidden", "false");
  document.body.style.overflow = "hidden";
  window.setTimeout(() => {
    (releaseCloseButton || releaseDialog).focus();
  }, 0);
  trackStructuredEvent("release_modal_open", {
    trigger_label: normalizeAnalyticsValue(triggerContext.label || ""),
    trigger_surface_label: normalizeAnalyticsValue(
      triggerContext.surface || "未知区域"
    ),
  });
  void loadLatestRelease();
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
    release_channel: activeReleaseChannel,
    release_channel_label:
      getReleaseDataByChannel(activeReleaseChannel)?.channelLabel ||
      activeReleaseChannel,
  });
  if (lastFocusedElement instanceof HTMLElement) {
    lastFocusedElement.focus();
  }
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

releaseChannelTabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    const channel = tab.dataset.releaseChannel;
    if (!channel || channel === activeReleaseChannel) {
      return;
    }
    if (channel === "prerelease" && !prereleaseReleaseData) {
      return;
    }
    trackStructuredEvent("release_channel_switch", {
      previous_channel: activeReleaseChannel,
      next_channel: channel,
      next_channel_label:
        getReleaseDataByChannel(channel)?.channelLabel || channel,
      ui_surface_label: "下载弹窗",
      ui_label: getElementLabel(tab),
    });
    renderReleaseData(channel);
  });
});

releaseMirrorDownload?.addEventListener("click", async (event) => {
  event.preventDefault();
  await startMirrorDownload(releaseMirrorDownload, activeReleaseChannel);
});

releaseGithubDownload?.addEventListener("click", (event) => {
  const targetUrl = releaseGithubDownload.href || fallbackReleasePage;
  const releaseData = getReleaseDataByChannel(activeReleaseChannel);
  trackStructuredEvent("app_download_intent", {
    download_source: "github",
    release_channel: activeReleaseChannel,
    release_channel_label: releaseData?.channelLabel || activeReleaseChannel,
    release_version: releaseData?.version || "",
    ui_surface_label: "下载弹窗",
    ui_label: getElementLabel(releaseGithubDownload),
  });
  trackStructuredEvent(
    "app_download",
    {
      ...buildDownloadAnalyticsPayload(
        "github",
        targetUrl,
        activeReleaseChannel
      ),
      release_channel_label: releaseData?.channelLabel || activeReleaseChannel,
      release_title: releaseData?.title || "",
      release_asset_name: releaseData?.assetName || "",
      release_asset_count: releaseData?.assetCount || 0,
      download_fallback: 0,
    }
  );
  closeReleaseModal("download");
});

bindGeneralAnalytics();

async function initHeroSchoolCount() {
  const countEl = document.getElementById("hero-school-count");
  if (!countEl) {
    return;
  }

  try {
    const response = await fetch("./schools.json", { cache: "no-store" });
    if (!response.ok) {
      throw new Error("HTTP " + response.status);
    }
    const payload = await response.json();
    const schoolCount = Number(payload?.counts?.schools);
    if (Number.isFinite(schoolCount) && schoolCount > 0) {
      countEl.textContent = String(schoolCount);
    }
  } catch (error) {
    // Keep the fallback label in HTML.
  }
}

initHeroSchoolCount();

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeReleaseModal("escape");
  }

  if (event.key !== "Tab" || !releaseModal?.classList.contains("is-open")) {
    return;
  }

  const focusableElements = getFocusableElements(releaseDialog);
  if (!focusableElements.length) {
    return;
  }

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];
  const activeElement = document.activeElement;

  if (event.shiftKey && activeElement === firstElement) {
    event.preventDefault();
    lastElement.focus();
  } else if (!event.shiftKey && activeElement === lastElement) {
    event.preventDefault();
    firstElement.focus();
  }
});

function initSchoolsPage() {
  const listEl = document.getElementById("schools-list");
  if (!listEl) {
    return;
  }

  const emptyEl = document.getElementById("schools-empty");
  const updatedEl = document.getElementById("schools-updated");
  const indexBarEl = document.getElementById("schools-index-bar");
  const searchEl = document.getElementById("schools-search");
  const genericToggleEl = document.getElementById("schools-show-generic");
  const statCountEl = document.getElementById("schools-stat-count");
  const statGenericEl = document.getElementById("schools-stat-generic");
  const statTotalEl = document.getElementById("schools-stat-total");

  let allSchools = [];

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
  }

  function formatUpdatedAt(value) {
    if (!value) {
      return "";
    }
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
      return "";
    }
    return date.toLocaleString(currentUiLocale(), {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      timeZoneName: "short",
    });
  }

  function filterSchools() {
    const keyword = searchEl.value.trim().toLowerCase();
    const showGeneric = genericToggleEl.checked;

    return allSchools.filter((school) => {
      if (!showGeneric && school.category === "generic") {
        return false;
      }
      if (!keyword) {
        return true;
      }
      return (
        school.name.toLowerCase().includes(keyword) ||
        school.id.toLowerCase().includes(keyword) ||
        String(school.initial || "").toLowerCase() === keyword
      );
    });
  }

  function renderSchoolRow(school) {
    const initial = escapeHtml(school.initial || "?");
    const name = escapeHtml(school.name);
    const subtitle =
      school.category === "generic"
        ? t("schools.rowGeneric", "通用教务适配")
        : t("schools.rowSchool", "网页登录导入");

    return (
      '<article class="feature-item compact">' +
      "<small>" +
      initial +
      "</small>" +
      "<strong>" +
      name +
      "</strong>" +
      "<p>" +
      subtitle +
      "</p>" +
      "</article>"
    );
  }

  function renderGroup(title, schools, anchorId) {
    if (!schools.length) {
      return "";
    }
    const idAttr = anchorId
      ? ' id="schools-group-' + escapeHtml(anchorId) + '"'
      : "";
    return (
      '<section class="schools-group"' +
      idAttr +
      ">" +
      '<p class="section-label">' +
      escapeHtml(title) +
      "</p>" +
      '<div class="feature-stack">' +
      schools.map(renderSchoolRow).join("") +
      "</div>" +
      "</section>"
    );
  }

  function renderList() {
    const filtered = filterSchools();
    const isSearching = searchEl.value.trim().length > 0;
    const generic = filtered.filter((item) => item.category === "generic");
    const schools = filtered.filter((item) => item.category !== "generic");

    if (!filtered.length) {
      listEl.innerHTML = "";
      emptyEl.hidden = false;
      indexBarEl.hidden = true;
      indexBarEl.innerHTML = "";
      return;
    }

    emptyEl.hidden = true;

    const groups = new Map();
    schools.forEach((school) => {
      const tag = school.initial || "#";
      if (!groups.has(tag)) {
        groups.set(tag, []);
      }
      groups.get(tag).push(school);
    });

    const sections = [];
    if (generic.length) {
      sections.push(renderGroup(t("schools.genericGroup", "通用教务"), generic, "generic"));
    }

    [...groups.keys()]
      .sort((left, right) => left.localeCompare(right, currentUiLocale()))
      .forEach((tag) => {
        sections.push(renderGroup(tag, groups.get(tag), tag));
      });

    listEl.innerHTML = sections.join("");

    if (isSearching || groups.size === 0) {
      indexBarEl.hidden = true;
      indexBarEl.innerHTML = "";
      return;
    }

    const tags = [...groups.keys()].sort((left, right) =>
      left.localeCompare(right, currentUiLocale())
    );
    indexBarEl.hidden = false;
    indexBarEl.innerHTML = tags
      .map(
        (tag) =>
          '<a href="#schools-group-' +
          encodeURIComponent(tag) +
          '">' +
          escapeHtml(tag) +
          "</a>"
      )
      .join("");
  }

  function updateStats(counts) {
    statCountEl.textContent = String(counts?.schools ?? "—");
    statGenericEl.textContent = String(counts?.generic ?? "—");
    statTotalEl.textContent = String(counts?.total ?? "—");
  }

  async function loadSchools() {
    try {
      const response = await fetch("./schools.json", { cache: "no-store" });
      if (!response.ok) {
        throw new Error("HTTP " + response.status);
      }
      const payload = await response.json();
      allSchools = Array.isArray(payload?.schools) ? payload.schools : [];
      updateStats(payload?.counts);

      const updatedLabel = formatUpdatedAt(payload?.updatedAt);
      updatedEl.textContent = updatedLabel
          ? t("schools.updatedAt", "列表更新于 {time}", { time: updatedLabel })
          : "";

      renderList();
    } catch (error) {
      listEl.innerHTML =
        '<p class="schools-status">' +
        t("schools.loadError", "无法加载学校列表，请稍后刷新页面。") +
        "</p>";
      updatedEl.textContent = "";
    }
  }

  searchEl.addEventListener("input", renderList);
  genericToggleEl.addEventListener("change", renderList);
  window.__mikcbRerenderSchools = renderList;
  loadSchools();
}

initSchoolsPage();


function refreshDynamicI18n() {
  const nextCandidates = getMirrorCandidates();
  nextCandidates.forEach((candidate, index) => {
    if (mirrorCandidates[index]) {
      mirrorCandidates[index].label = candidate.label;
    }
  });

  // Reset download button cached labels so loading text uses the new locale.
  document.querySelectorAll(".release-action-link, #release-mirror-download").forEach((button) => {
    if (button.dataset.originalLabel) {
      delete button.dataset.originalLabel;
    }
  });

  if (stableReleaseData) {
    stableReleaseData.channelLabel = t("js.channelStable", "正式版");
    renderLatestStableHighlights(stableReleaseData);
  }
  if (prereleaseReleaseData) {
    prereleaseReleaseData.channelLabel = t("js.channelPrerelease", "预发布");
  }
  if (stableReleaseData) {
    renderReleaseData(activeReleaseChannel);
  }
  if (releaseTimeline) {
    void loadReleaseTimeline();
  }
  if (typeof window.__mikcbRerenderSchools === "function") {
    window.__mikcbRerenderSchools();
  }
}

function bindI18nRefresh() {
  if (!window.I18n || typeof window.I18n.onChange !== "function") {
    return;
  }
  window.I18n.onChange(() => {
    refreshDynamicI18n();
  });
}

if (window.I18n?.ready) {
  void window.I18n.ready.then(() => {
    bindI18nRefresh();
    refreshDynamicI18n();
  });
} else {
  bindI18nRefresh();
}
