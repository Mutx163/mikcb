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

const yearEl = document.getElementById("year");
if (yearEl) {
  yearEl.textContent = String(new Date().getFullYear());
}

const navToggle = document.querySelector(".nav-toggle");
const navMenu = document.getElementById("nav-menu");

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
    return;
  }

  setReleaseLoadingState();

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
  } catch (error) {
    setReleaseErrorState();
  }
}

function openReleaseModal() {
  if (!releaseModal) {
    return;
  }
  releaseModal.classList.add("is-open");
  releaseModal.setAttribute("aria-hidden", "false");
  document.body.style.overflow = "hidden";
  loadLatestRelease();
}

function closeReleaseModal() {
  if (!releaseModal) {
    return;
  }
  releaseModal.classList.remove("is-open");
  releaseModal.setAttribute("aria-hidden", "true");
  document.body.style.overflow = "";
}

releaseOpenButtons.forEach((button) => {
  button.addEventListener("click", openReleaseModal);
});

releaseCloseButtons.forEach((button) => {
  button.addEventListener("click", closeReleaseModal);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    closeReleaseModal();
  }
});
