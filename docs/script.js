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

const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = String(new Date().getFullYear());
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

const releasesApiUrl =
  "https://api.github.com/repos/Mutx163/mikcb/releases?per_page=8";
const fallbackReleasePage = "https://github.com/Mutx163/mikcb/releases";
const defaultMirrorPrefix = "https://ghfast.top/";
const globalMirrorProbeKey = "mikcb-docs-fastest-mirror:__global__";
const mirrorCandidates = [
  {
    key: "ghfast",
    label: "默认镜像",
    prefix: "https://ghfast.top/",
  },
  {
    key: "ghproxy_cn",
    label: "备用镜像 1",
    prefix: "https://ghproxy.cn/",
  },
  {
    key: "gh_llkk",
    label: "备用镜像 2",
    prefix: "https://gh.llkk.cc/",
  },
];

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
const releaseChannelTabs = Array.from(
  document.querySelectorAll(".release-channel-tab")
);

let releaseLoaded = false;
let releaseLoadedAt = 0;
let releaseLoadPromise = null;
let lastFocusedElement = null;
let stableReleaseData = null;
let prereleaseReleaseData = null;
let activeReleaseChannel = "stable";
const mirrorProbeCache = new Map();
const mirrorProbePromises = new Map();

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

function buildReleaseDescription(rawBody, releaseHints = []) {
  const normalizedHints = releaseHints
    .map((item) => cleanReleaseLine(item).toLowerCase())
    .filter(Boolean);
  const lines = String(rawBody || "")
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
    return "当前弹窗提供 GitHub 原版与镜像下载入口，方便直接下载安装。";
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

function pickReleaseGroup(releases) {
  const normalizedReleases = Array.isArray(releases) ? releases : [];
  const published = normalizedReleases.filter((item) => !item?.draft);
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
  return {
    channelLabel: release.prerelease ? "预发布" : channelLabel,
    version,
    title,
    publishedAt: formatDateTime(release.published_at || release.updated_at),
    description: buildReleaseDescription(release.body || "", [
      title,
      version,
      `v${version}`,
    ]),
    releaseUrl,
    downloadUrl,
  };
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

  button.textContent = isLoading ? "准备中..." : button.dataset.originalLabel;
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
  releaseDialogTitle.textContent = "下载轻屿课表";
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

async function probeMirrorCandidate(candidate, probeTarget) {
  const probeUrl = buildMirrorUrl(probeTarget, candidate.prefix);
  const controller = new AbortController();
  const startedAt = performance.now();
  const timeoutId = window.setTimeout(() => controller.abort(), 1800);

  try {
    await fetch(probeUrl, {
      mode: "no-cors",
      cache: "no-store",
      signal: controller.signal,
    });
    return {
      ...candidate,
      duration: performance.now() - startedAt,
    };
  } catch (error) {
    return null;
  } finally {
    window.clearTimeout(timeoutId);
  }
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
  try {
    updateMirrorPrewarmState("正在准备下载...");
    targetUrl = (await ensureReleaseDownloadUrl(channel)) || fallbackReleasePage;
    updateMirrorPrewarmState("正在连接下载线路...");
    const bestPrefix = await resolveBestMirrorPrefix(targetUrl);
    const finalUrl = buildMirrorUrl(targetUrl, bestPrefix);
    triggerDownload(finalUrl);
    updateMirrorPrewarmState("已开始下载，可切换 GitHub 原版。");
  } catch (error) {
    const fallbackUrl = buildMirrorUrl(targetUrl, defaultMirrorPrefix);
    triggerDownload(fallbackUrl);
    updateMirrorPrewarmState("已切到默认线路，可改用 GitHub 原版。");
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

  updateMirrorPrewarmState("正在测速国内下载线路，稍后点下载会更快响应。");
  try {
    await Promise.all(warmTargets.map((item) => prewarmMirrorForRelease(item)));
    updateMirrorPrewarmState("下载线路已就绪。");
  } catch (error) {
    updateMirrorPrewarmState("国内下载会自动回退可用线路。");
  }
}

function setReleaseLoadingState() {
  releaseDialogTitle.textContent = "下载轻屿课表";
  if (releaseDialog) {
    releaseDialog.dataset.releaseChannel = "stable";
  }
  releaseDescription.textContent = "正在读取版本信息...";
  activeReleaseChannel = "stable";
  releaseChannel.textContent = "正式版";
  releaseVersion.textContent = "读取中";
  releasePublishedAt.textContent = "读取中";
  releaseGithubDownload.href = fallbackReleasePage;
  releaseMirrorDownload.href = fallbackReleasePage;
  releasePageLink.href = fallbackReleasePage;
  updateReleaseChannelTabs();
  updateMirrorPrewarmState("正在准备下载线路...");
}

function setReleaseErrorState() {
  releaseDialogTitle.textContent = "暂时无法读取最新版本";
  if (releaseDialog) {
    releaseDialog.dataset.releaseChannel = "stable";
  }
  releaseDescription.textContent =
    "你仍然可以直接打开 GitHub Releases 页面，或者使用镜像入口进行下载。";
  releaseChannel.textContent = "正式版";
  releaseVersion.textContent = "未知";
  releasePublishedAt.textContent = "未知";
  releaseGithubDownload.href = fallbackReleasePage;
  releaseMirrorDownload.href = buildMirrorUrl(fallbackReleasePage);
  releasePageLink.href = fallbackReleasePage;
  prereleaseReleaseData = null;
  activeReleaseChannel = "stable";
  updateReleaseChannelTabs();
  updateMirrorPrewarmState("当前会直接尝试可用下载线路。");
}

const releaseCacheTtlMs = 15 * 1000;

async function loadLatestRelease() {
  if (releaseLoaded && Date.now() - releaseLoadedAt < releaseCacheTtlMs) {
    return {
      stable: stableReleaseData,
      prerelease: prereleaseReleaseData,
    };
  }

  if (releaseLoadPromise) {
    return releaseLoadPromise;
  }

  setReleaseLoadingState();

  releaseLoadPromise = (async () => {
    try {
      const response = await fetch(releasesApiUrl, {
        cache: "no-store",
        headers: {
          Accept: "application/vnd.github+json",
          "X-GitHub-Api-Version": "2022-11-28",
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const releases = await response.json();
      const grouped = pickReleaseGroup(releases);
      stableReleaseData = normalizeReleaseRecord(grouped.stable, "正式版");
      prereleaseReleaseData = normalizeReleaseRecord(
        grouped.prerelease,
        "预发布"
      );

      if (!stableReleaseData) {
        throw new Error("No release data");
      }

      if (hasUsablePrerelease()) {
        activeReleaseChannel =
          activeReleaseChannel === "prerelease" ? "prerelease" : "stable";
      } else {
        activeReleaseChannel = "stable";
      }

      renderReleaseData(activeReleaseChannel);
      releaseLoaded = true;
      releaseLoadedAt = Date.now();
      updateMirrorPrewarmState("已从 GitHub 读取版本信息。");
      void prewarmReleaseDownloads();
      return {
        stable: stableReleaseData,
        prerelease: prereleaseReleaseData,
      };
    } catch (error) {
      setReleaseErrorState();
      return null;
    } finally {
      releaseLoadPromise = null;
    }
  })();

  return releaseLoadPromise;
}

function openReleaseModal() {
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
  void prewarmGlobalMirror();
  void loadLatestRelease();
}

function closeReleaseModal() {
  if (!releaseModal) {
    return;
  }
  releaseModal.classList.remove("is-open");
  releaseModal.setAttribute("aria-hidden", "true");
  document.body.style.overflow = "";
  if (lastFocusedElement instanceof HTMLElement) {
    lastFocusedElement.focus();
  }
}

releaseOpenButtons.forEach((button) => {
  button.addEventListener("click", (event) => {
    event.preventDefault();
    openReleaseModal();
  });
});

releaseCloseButtons.forEach((button) => {
  button.addEventListener("click", closeReleaseModal);
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
    renderReleaseData(channel);
  });
});

releaseMirrorDownload?.addEventListener("click", async (event) => {
  event.preventDefault();
  await startMirrorDownload(releaseMirrorDownload, activeReleaseChannel);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeReleaseModal();
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
