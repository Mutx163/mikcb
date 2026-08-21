#!/usr/bin/env python3
"""Build static, crawlable website pages and sitemap from docs data files.

The homepage keeps its existing interactive experience, while this generator
creates durable HTML entry points for search crawlers. It deliberately creates
one useful school hub and one page per release summary instead of thin pages
for every school.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import defaultdict
from datetime import datetime
from html import escape
from pathlib import Path
from typing import Any
ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
BASE_URL = "https://mutx.ccwu.cc"
TOPIC_LASTMOD = "2026-08-19"
RELEASE_TYPES = ("新增", "优化", "修复", "调整", "测试", "移除", "更新")

TOPIC_PAGES = (
    {
        "filename": "android-timetable.html",
        "slug": "android-timetable",
        "title": "Android 课表 App - 轻屿课表免费开源课程表",
        "description": "轻屿课表是一款免费开源的 Android 课表 App，支持教务导入、ICS、AI 识图、课程提醒、桌面小组件、情侣课表和本地数据管理。",
        "label": "Android 课表 / ANDROID TIMETABLE",
        "heading": "一款把课程信息装进 Android 的课表 App",
        "lead": "轻屿课表面向大学生设计：把每周课程、上课提醒、考试安排和桌面查看集中在一个免费、无广告、无需注册的 Android 应用里。课程数据默认保存在本地，并提供备份与同步能力。",
        "sections": (
            ("从导入到提醒，覆盖完整的上课流程", "导入课表后，可以按周查看课程、设置单双周和自定义周次，配置地点与时间模板，并在课前、课中和下课前收到分阶段提醒。桌面小组件和 HyperOS 系统联动让下一节课无需打开应用也能看到。", ("周视图、日视图和多课表管理", "课程地点、教师、备注和作业标记", "考试安排与系统级提醒", "桌面小组件、超级岛和局域网编辑")),
            ("免费开源，数据由你掌握", "应用不要求注册账号，也没有广告。课表数据优先本地存储，支持完整备份导出与恢复；需要多设备使用时，可以配置 WebDAV 云同步并查看历史快照。源码公开在 GitHub，欢迎审阅、反馈和贡献。", ("GPL-3.0 开源", "无需注册，不以账号锁定数据", "支持备份文件迁移和 WebDAV 同步", "Android 8.0+，重点适配 HyperOS")),
            ("适合哪些学生使用？", "如果你希望减少手动录入、快速知道下一节课、在桌面直接查看课程，或需要在手机与电脑之间编辑课表，轻屿课表提供了从教务系统导入到日常提醒的一整套工具。没有学校适配时，也可以使用 ICS、AI 识图或表格模板导入。", ("新学期快速建立课表", "需要课程提醒和桌面小组件", "情侣或同学之间叠加查看课表", "需要本地备份或跨设备同步")),
        ),
    },
    {
        "filename": "hyperos-timetable.html",
        "slug": "hyperos-timetable",
        "title": "HyperOS 超级岛课表 - 轻屿课表课程提醒",
        "description": "轻屿课表 HyperOS 超级岛课表功能介绍：课前、课中、下课状态联动，支持下一节课、地点、倒计时和快捷操作。",
        "label": "HyperOS 超级岛 / HYPEROS ISLAND",
        "heading": "让下一节课出现在 HyperOS 超级岛",
        "lead": "轻屿课表把课表状态与 HyperOS 系统体验连接起来：课前看到课程和地点，课中保持状态，临近下课继续承接下一节课。你不必反复打开课表 App，也能知道接下来要去哪里。",
        "sections": (
            ("课前、课中、下课连续显示", "超级岛不是一条孤立通知，而是围绕一节课持续变化的状态。它可以展示课程名称、上课地点、开始时间和剩余进度，并在课程结束后切换到下一节安排。", ("课前倒计时与课程地点", "课中状态和进度提示", "下课后承接下一节课", "支持情侣课表的共同空闲场景")),
            ("系统快捷操作自动恢复", "在支持的 HyperOS 设备上，课前可以使用静音或免打扰等快捷操作；课程结束后，应用会按设置恢复原来的状态，减少忘记关闭系统模式的情况。", ("快捷操作与课程时间绑定", "下课后自动恢复", "重启手机后恢复相关状态", "可在应用设置中管理系统联动")),
            ("使用条件与兼容性", "超级岛功能需要兼容的 Xiaomi / Redmi 设备和 HyperOS 3.0.300 及以上版本。其他 Android 设备仍然可以使用课表、教务导入、提醒、桌面小组件和 WebDAV 等核心功能。", ("Android 8.0+ 可使用基础功能", "HyperOS 版本和设备能力决定超级岛可用性", "不支持的设备不会影响普通课表使用", "下载前请查看应用内说明和版本要求")),
        ),
    },
    {
        "filename": "course-import.html",
        "slug": "course-import",
        "title": "大学课表导入 - 轻屿课表教务系统、ICS 与 AI 识图",
        "description": "轻屿课表支持大学教务系统网页登录导入、ICS 文件、AI 识图和表格模板导入，快速建立 Android 课程表。",
        "label": "课表导入 / COURSE IMPORT",
        "heading": "大学课表怎么导入？轻屿课表提供四种方式",
        "lead": "新学期不想手动录入每一节课，可以根据学校和手上的课表资料选择导入方式。已适配学校优先使用教务网页登录，暂未适配的学校也可以使用 ICS、AI 识图或表格模板。",
        "sections": (
            ("方式一：教务系统网页登录导入", "在 App 内打开「导入课程表 → 教务系统导入」，选择学校后按页面提示登录教务系统。适配脚本会读取课程安排并转换为应用内课表，具体登录步骤和验证码要求取决于学校教务系统。", ("先在适配学校列表确认学校", "按学校页面提示完成登录或验证码", "导入后检查学期、周次、节次和地点", "不要把教务密码分享给任何第三方")),
            ("方式二：ICS 文件导入", "如果学校或其他课表工具可以导出 iCalendar（.ics）文件，可以在应用中选择文件导入。ICS 适合在不同课表软件之间迁移课程，但导出文件的周次和重复规则需要在导入后核对。", ("支持 .ics 文件", "适合跨应用迁移", "导入后检查单双周和课程时间", "保留原始文件作为备份")),
            ("方式三：AI 识图与表格模板", "手上只有课表截图时，可以尝试 AI 识图导入；也可以使用表格模板批量整理课程。识图结果和表格内容都建议逐项核对，尤其是教室、单双周、起止日期和周次范围。", ("适合没有网页适配的学校", "截图清晰、表头完整时识别更可靠", "复杂排课请优先人工复核", "导入前后都可以使用备份功能")),
            ("找不到学校怎么办？", "先选择 ICS、AI 识图或表格模板完成课表建立，再到 qingyu_warehouse 提交学校教务适配需求。学校名单会自动同步，适配情况以官网学校列表和应用内列表为准。", ("查看已适配学校列表", "反馈学校名称和教务系统入口", "不要在公开 Issue 中提交账号密码", "等待适配期间仍可使用通用导入方式")),
        ),
    },
    {
        "filename": "webdav-timetable-sync.html",
        "slug": "webdav-timetable-sync",
        "title": "WebDAV 课表同步与备份 - 轻屿课表多设备同步",
        "description": "轻屿课表 WebDAV 课表同步支持坚果云或自建 WebDAV 服务，在手机、平板之间同步课表、设置和历史快照。",
        "label": "WebDAV 同步 / WEBDAV SYNC",
        "heading": "用 WebDAV 同步课表，也保留自己的数据",
        "lead": "轻屿课表支持将课表与设置同步到坚果云或自建 WebDAV 服务。你可以在手机、平板之间保持课表一致，也可以查看历史快照，在误修改后按条恢复或删除。",
        "sections": (
            ("适合手机、平板与换机迁移", "配置 WebDAV 后，应用可以在设备之间同步课表数据。新设备可以通过同步或完整备份恢复课程，不必重新登录学校教务系统逐条导入。", ("支持坚果云等 WebDAV 服务", "也可连接自建 WebDAV", "适合多设备和换机迁移", "同步前后可以查看本地与远程状态")),
            ("历史快照与冲突保护", "同步不是简单覆盖。应用会校验远程基线和快照内容，在本地与远程同时变化时提示处理，减少误覆盖。历史快照可以查看、按条恢复或删除，重要修改前建议先手动备份。", ("远程快照保留历史版本", "远程变化时提示冲突", "支持恢复或删除历史快照", "避免用空数据覆盖已有内容")),
            ("情侣课表与数据安全建议", "情侣课表可以通过 WebDAV 交换课表，但双方应使用不同的槽位，避免把自己的课表误当成对方课表。WebDAV 地址、账号和密码由用户自行配置，请使用可信服务并定期检查访问权限。", ("情侣课表使用不同槽位", "不要公开分享 WebDAV 凭据", "优先使用 HTTPS 服务地址", "定期保留离线备份")),
        ),
    },
)


def read_json(path: Path) -> Any:
    if not path.exists():
        raise SystemExit(f"Required SEO input is missing: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Required SEO input is invalid: {path}: {error}") from error


def validate_schools_payload(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise SystemExit("schools.json must contain a JSON object")
    schools = payload.get("schools")
    counts = payload.get("counts")
    if not isinstance(schools, list) or not isinstance(counts, dict):
        raise SystemExit("schools.json must contain schools and counts")
    actual_total = len(schools)
    actual_school_count = sum(
        1 for item in schools if isinstance(item, dict) and item.get("category") == "school"
    )
    actual_generic_count = sum(
        1 for item in schools if isinstance(item, dict) and item.get("category") == "generic"
    )
    expected = {
        "total": actual_total,
        "schools": actual_school_count,
        "generic": actual_generic_count,
    }
    for key, actual in expected.items():
        declared = counts.get(key)
        if not isinstance(declared, int) or declared != actual:
            raise SystemExit(
                f"schools.json counts.{key}={declared!r} does not match {actual}"
            )
    seen_ids: set[str] = set()
    for item in schools:
        if not isinstance(item, dict) or not text(item.get("id")):
            raise SystemExit("schools.json contains an entry without a valid id")
        school_id = text(item["id"])
        if school_id in seen_ids:
            raise SystemExit(f"schools.json contains duplicate id: {school_id}")
        seen_ids.add(school_id)
    return payload


def validate_feed_payload(payload: Any) -> dict[str, Any]:
    if not isinstance(payload, dict):
        raise SystemExit("feed.json must contain a JSON object")
    releases = payload.get("releases")
    if not isinstance(releases, list):
        raise SystemExit("feed.json releases must be a list")
    declared_count = payload.get("releaseCount")
    if not isinstance(declared_count, int):
        raise SystemExit("feed.json releaseCount must be an integer")
    # The feed keeps only the latest eight cards, while releaseCount records
    # the total number of published releases returned by GitHub.
    if declared_count < len(releases):
        raise SystemExit(
            f"feed.json releaseCount={declared_count} is smaller than serialized releases {len(releases)}"
        )
    if len(releases) > 8:
        raise SystemExit("feed.json may serialize at most eight release cards")
    seen_slugs: set[str] = set()
    for item in releases:
        if not isinstance(item, dict) or not text(item.get("version")):
            raise SystemExit("feed.json contains a release without a version")
        slug = slug_version(item["version"])
        if slug in seen_slugs:
            raise SystemExit(f"feed.json contains duplicate version slug: {slug}")
        seen_slugs.add(slug)
    return payload


def text(value: Any, fallback: str = "") -> str:
    value = str(value or "").strip()
    return value or fallback


def date_only(value: Any) -> str:
    raw = text(value)
    if not raw:
        return ""
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).date().isoformat()
    except ValueError:
        match = re.match(r"^(\d{4}-\d{2}-\d{2})", raw)
        return match.group(1) if match else ""


def slug_version(version: Any) -> str:
    safe = re.sub(r"[^0-9A-Za-z._-]+", "-", text(version, "release"))
    return safe.strip(".-") or "release"


def attr(value: Any) -> str:
    return escape(text(value), quote=True)


def body(value: Any) -> str:
    return escape(text(value))


def json_ld(value: dict[str, Any]) -> str:
    # Keep untrusted release text from terminating the JSON-LD script element.
    serialized = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return (
        serialized.replace("<", "\\u003c")
        .replace(">", "\\u003e")
        .replace("&", "\\u0026")
        .replace("\u2028", "\\u2028")
        .replace("\u2029", "\\u2029")
    )


MANAGED_RELEASE_FILENAME = re.compile(r"^v[0-9A-Za-z._-]+\.html$")


def remove_stale_release_pages(releases_dir: Path, generated: set[str]) -> int:
    removed = 0
    for path in releases_dir.iterdir():
        if path.is_file() and MANAGED_RELEASE_FILENAME.fullmatch(path.name) and path.name not in generated:
            path.unlink()
            removed += 1
    return removed


def site_header(prefix: str) -> str:
    home = prefix or "./"
    return f"""\
<header class="global-nav">
  <div class="nav-inner">
    <a class="nav-brand" href="{home}#top" aria-label="轻屿课表首页">
      <span class="nav-brand-mark">
        <img src="{prefix}app-icon.png" alt="轻屿课表图标" width="32" height="32" decoding="async" />
      </span>
      <span class="nav-brand-text">轻屿课表</span>
    </a>
    <nav id="seo-nav-menu" class="nav-links" aria-label="站点导航">
      <a href="{home}#features">功能</a>
      <a href="{prefix}schools.html">适配学校</a>
      <a href="{prefix}releases/">更新</a>
      <a href="{home}#faq">常见问题</a>
      <a href="{home}#download">下载</a>
    </nav>
    <div class="nav-actions">
      <a
        class="nav-github"
        href="https://github.com/Mutx163/mikcb"
        target="_blank"
        rel="noreferrer"
        aria-label="GitHub 仓库"
      >
        <svg viewBox="0 0 16 16" width="18" height="18" fill="currentColor" aria-hidden="true">
          <path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27s1.36.09 2 .27c1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07.01 1.93-.01 2.2 0 .21.15.46.55.38A8.01 8.01 0 0 0 16 8c0-4.42-3.58-8-8-8Z" />
        </svg>
      </a>
      <a class="seo-nav-cta primary-cta" href="{home}#download">立即下载</a>
      <button
        class="nav-toggle"
        type="button"
        aria-expanded="false"
        aria-controls="seo-nav-menu"
        aria-label="切换导航"
      >
        <span></span>
        <span></span>
      </button>
    </div>
  </div>
</header>"""


def site_footer(prefix: str) -> str:
    home = prefix or "./"
    return f"""\
<footer class="site-footer">
  <div class="footer-inner">
    <div class="footer-brand">
      <img src="{prefix}app-icon.png" alt="轻屿课表图标" width="32" height="32" />
      <div><strong>轻屿课表</strong><small>把课程信息做成系统体验</small></div>
    </div>
    <nav class="footer-cols" aria-label="页脚导航">
      <div class="footer-col"><small>产品</small><a href="{home}">首页</a><a href="{prefix}android-timetable.html">Android 课表</a><a href="{prefix}hyperos-timetable.html">HyperOS 超级岛</a></div>
      <div class="footer-col"><small>指南</small><a href="{prefix}schools.html">适配学校</a><a href="{prefix}course-import.html">教务导入</a><a href="{prefix}webdav-timetable-sync.html">WebDAV 同步</a></div>
      <div class="footer-col"><small>开源</small><a href="https://github.com/Mutx163/mikcb" target="_blank" rel="noreferrer">GitHub</a><a href="https://github.com/Mutx163/mikcb/releases" target="_blank" rel="noreferrer">Releases</a><a href="{prefix}contributing.html">贡献指南</a></div>
    </nav>
  </div>
  <p class="footer-copy">Copyright © 轻屿课表 · GPL-3.0</p>
</footer>"""


def document(
    *,
    title: str,
    description: str,
    canonical: str,
    prefix: str,
    content: str,
    structured_data: dict[str, Any],
    og_type: str = "article",
) -> str:
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
  <!-- Generated by tool/build_docs_seo.py; edit the source data or template instead. -->
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover" />
    <title>{body(title)}</title>
    <meta name="description" content="{attr(description)}" />
    <meta name="robots" content="index,follow,max-image-preview:large,max-snippet:-1,max-video-preview:-1" />
    <meta property="og:type" content="{attr(og_type)}" />
    <meta property="og:site_name" content="轻屿课表" />
    <meta property="og:locale" content="zh_CN" />
    <meta property="og:title" content="{attr(title)}" />
    <meta property="og:description" content="{attr(description)}" />
    <meta property="og:url" content="{attr(canonical)}" />
    <meta property="og:image" content="{BASE_URL}/app-icon.png" />
    <meta name="twitter:card" content="summary" />
    <meta name="twitter:title" content="{attr(title)}" />
    <meta name="twitter:description" content="{attr(description)}" />
    <link rel="canonical" href="{attr(canonical)}" />
    <link rel="icon" href="{prefix}app-icon.png" type="image/png" />
    <link rel="stylesheet" href="{prefix}styles.css" />
    <script type="application/ld+json">{json_ld(structured_data)}</script>
    <script>
      document.addEventListener("DOMContentLoaded", function () {{
        var toggle = document.querySelector(".seo-page .nav-toggle");
        var menu = document.getElementById("seo-nav-menu");
        if (!toggle || !menu) return;
        toggle.addEventListener("click", function () {{
          var expanded = toggle.getAttribute("aria-expanded") === "true";
          toggle.setAttribute("aria-expanded", String(!expanded));
          menu.classList.toggle("is-open", !expanded);
        }});
        menu.addEventListener("click", function (event) {{
          if (event.target.closest("a")) {{
            toggle.setAttribute("aria-expanded", "false");
            menu.classList.remove("is-open");
          }}
        }});
        document.addEventListener("click", function (event) {{
          if (!menu.classList.contains("is-open")) return;
          if (menu.contains(event.target) || toggle.contains(event.target)) return;
          toggle.setAttribute("aria-expanded", "false");
          menu.classList.remove("is-open");
        }});
        window.addEventListener("resize", function () {{
          if (window.innerWidth > 780) {{
            toggle.setAttribute("aria-expanded", "false");
            menu.classList.remove("is-open");
          }}
        }});
      }});
    </script>
  </head>
  <body class="seo-page">
    {site_header(prefix)}
    <main class="detail-page">{content}</main>
    {site_footer(prefix)}
  </body>
</html>
"""


def breadcrumb(prefix: str, label: str) -> str:
    return f'<p class="seo-breadcrumb"><a href="{prefix}">轻屿课表</a><span aria-hidden="true">/</span>{body(label)}</p>'


def render_topic_page(page: dict[str, Any]) -> str:
    sections = []
    for heading, paragraph, bullets in page["sections"]:
        items = "".join(f"<li>{body(item)}</li>" for item in bullets)
        sections.append(
            f'<section class="seo-topic-section"><div><h2>{body(heading)}</h2><p>{body(paragraph)}</p></div><ul class="seo-check-list">{items}</ul></section>'
        )
    description = text(page["description"])
    content = f"""
<section class="section-shell seo-article">
  {breadcrumb("./", page["label"])}
  <p class="section-label">{body(page["label"])}</p>
  <h1>{body(page["heading"])}</h1>
  <p class="seo-lead">{body(page["lead"])}</p>
  {"".join(sections)}
  <div class="seo-related-links"><a class="primary-cta" href="./#download">下载最新版本</a><a class="secondary-cta" href="./course-import.html">查看课表导入方式</a><a class="secondary-cta" href="./">返回官网首页</a></div>
</section>"""
    structured = {
        "@context": "https://schema.org",
        "@type": "Article",
        "headline": page["heading"],
        "description": description,
        "url": f"{BASE_URL}/{page['filename']}",
        "author": {"@type": "Person", "name": "Mutx163"},
        "publisher": {"@type": "Organization", "name": "轻屿课表", "url": f"{BASE_URL}/"},
        "mainEntityOfPage": f"{BASE_URL}/{page['filename']}",
    }
    return document(
        title=page["title"],
        description=description,
        canonical=f"{BASE_URL}/{page['filename']}",
        prefix="./",
        content=content,
        structured_data=structured,
    )


def render_school_page(payload: dict[str, Any]) -> str:
    counts = payload.get("counts") or {}
    schools = [item for item in payload.get("schools", []) if isinstance(item, dict)]
    schools = sorted(schools, key=lambda item: (text(item.get("initial")), text(item.get("name"))))
    normal = [item for item in schools if text(item.get("category")) != "generic"]
    generic = [item for item in schools if text(item.get("category")) == "generic"]
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for item in normal:
        grouped[text(item.get("initial"), "#")].append(item)

    groups_html = []
    item_list = []
    position = 1
    for initial in sorted(grouped):
        rows = []
        for item in grouped[initial]:
            name = text(item.get("name"))
            rows.append(f'<li><span class="seo-school-name">{body(name)}</span><span class="seo-school-type">网页登录导入</span></li>')
            item_list.append({"@type": "ListItem", "position": position, "name": name})
            position += 1
        groups_html.append(
            f'<section class="seo-school-group" id="schools-{attr(initial.lower())}"><h2>{body(initial)} <span>{len(rows)} 所</span></h2><ul class="seo-school-list">{"".join(rows)}</ul></section>'
        )

    generic_rows = "".join(
        f'<li><span class="seo-school-name">{body(text(item.get("name")))}</span><span class="seo-school-type">通用适配</span></li>'
        for item in generic
    )
    updated = date_only(payload.get("updatedAt")) or "持续同步"
    total = int(counts.get("total") or len(schools))
    school_count = int(counts.get("schools") or len(normal))
    generic_count = int(counts.get("generic") or len(generic))
    description = f"轻屿课表已适配 {school_count} 所高校和 {generic_count} 套通用教务入口，支持 Android 课表教务系统网页登录导入，也支持 ICS、AI 识图和表格模板导入。"
    content = f"""
<section class="section-shell seo-article">
  {breadcrumb("./", "已适配学校")}
  <p class="section-label">教务导入 / SCHOOL IMPORT</p>
  <h1>轻屿课表已适配学校与教务导入</h1>
  <p class="seo-lead">轻屿课表支持在 Android App 内选择「导入课程表 → 教务系统导入」，登录学校教务系统后直接同步课程。当前共有 <strong>{school_count} 所高校</strong>、<strong>{generic_count} 套通用教务适配</strong>，共 {total} 条导入入口。</p>
  <div class="seo-stat-grid"><div><strong>{school_count}</strong><span>所高校</span></div><div><strong>{generic_count}</strong><span>套通用适配</span></div><div><strong>{total}</strong><span>条入口</span></div></div>
  <div class="seo-callout"><strong>找不到你的学校？</strong><p>可以先使用 .ics 文件、AI 识图或表格模板导入；也可以在 <a href="https://github.com/Mutx163/qingyu_warehouse/issues" target="_blank" rel="noreferrer">qingyu_warehouse 提交适配需求</a>。</p></div>
  <h2>支持网页登录导入的高校</h2>
  <p class="seo-muted">以下学校名单由 <a href="https://github.com/Mutx163/qingyu_warehouse" target="_blank" rel="noreferrer">qingyu_warehouse</a> 自动同步，最近同步时间：{body(updated)}。</p>
  {"".join(groups_html)}
  <section class="seo-school-group"><h2>通用教务适配 <span>{generic_count} 套</span></h2><ul class="seo-school-list">{generic_rows}</ul></section>
  <div class="seo-related-links"><a class="primary-cta" href="./course-import.html">查看完整导入方式</a><a class="secondary-cta" href="./">返回官网首页</a></div>
</section>"""
    structured = {
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": "轻屿课表已适配学校与教务导入",
        "description": description,
        "url": f"{BASE_URL}/schools.html",
        "isPartOf": {"@type": "WebSite", "name": "轻屿课表", "url": f"{BASE_URL}/"},
        "mainEntity": {"@type": "ItemList", "numberOfItems": len(item_list), "itemListElement": item_list},
    }
    return document(
        title="轻屿课表已适配学校 - 高校教务导入列表",
        description=description,
        canonical=f"{BASE_URL}/schools.html",
        prefix="./",
        content=content,
        structured_data=structured,
        og_type="website",
    )


def release_item_url(version: Any) -> str:
    return f"{BASE_URL}/releases/v{slug_version(version)}.html"


def render_release_index(feed: dict[str, Any]) -> str:
    releases = [item for item in feed.get("releases", []) if isinstance(item, dict)]
    cards = []
    item_list = []
    for position, item in enumerate(releases, 1):
        version = text(item.get("version"), "未知版本")
        title = text(item.get("title"), f"v{version}")
        url = f"./v{slug_version(version)}.html"
        description = text(item.get("description"), "查看本次版本更新内容。")
        cards.append(
            f'<article class="seo-card"><p class="seo-card-kicker">{body(text(item.get("channelLabel"), "版本"))} · {body(date_only(item.get("publishedAt")))}</p><h2><a href="{url}">{body(title)}</a></h2><p>{body(description)}</p><a class="seo-inline-link" href="{url}">查看更新详情 →</a></article>'
        )
        item_list.append({"@type": "ListItem", "position": position, "url": f"{BASE_URL}/releases/v{slug_version(version)}.html", "name": title})
    description = "轻屿课表 Android 课表应用的版本更新日志，记录 HyperOS 超级岛、教务导入、WebDAV 云同步、提醒和小组件等功能变化。"
    content = f"""
<section class="section-shell seo-article">
  {breadcrumb("../", "更新日志")}
  <p class="section-label">更新日志 / CHANGELOG</p>
  <h1>轻屿课表版本更新日志</h1>
  <p class="seo-lead">这里汇总轻屿课表 Android App 的公开版本更新，包括 HyperOS 超级岛、课程提醒、教务导入、WebDAV 云同步、桌面小组件和课表管理优化。安装包和完整 Release 讨论仍以 <a href="https://github.com/Mutx163/mikcb/releases" target="_blank" rel="noreferrer">GitHub Releases</a> 为准。</p>
  <div class="seo-grid">{"".join(cards)}</div>
  <div class="seo-related-links"><a class="primary-cta" href="../#download">下载最新版本</a><a class="secondary-cta" href="../">返回官网首页</a></div>
</section>"""
    structured = {
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": "轻屿课表版本更新日志",
        "description": description,
        "url": f"{BASE_URL}/releases/",
        "mainEntity": {"@type": "ItemList", "itemListElement": item_list},
    }
    return document(
        title="轻屿课表更新日志 - Android 课表 App 版本记录",
        description=description,
        canonical=f"{BASE_URL}/releases/",
        prefix="../",
        content=content,
        structured_data=structured,
        og_type="website",
    )


def render_release_detail(item: dict[str, Any]) -> str:
    version = text(item.get("version"), "未知版本")
    title = text(item.get("title"), f"v{version}")
    published = date_only(item.get("publishedAt"))
    description = text(item.get("description"), "查看轻屿课表本次版本更新内容。")
    highlights = [entry for entry in item.get("highlights", []) if isinstance(entry, dict)]
    grouped: dict[str, list[str]] = defaultdict(list)
    for entry in highlights:
        grouped[text(entry.get("type"), "更新")].append(text(entry.get("text")))
    sections = []
    for change_type in RELEASE_TYPES:
        entries = grouped.get(change_type, [])
        if entries:
            sections.append(f'<section class="seo-release-section"><h2>{body(change_type)}</h2><ul class="detail-list">{"".join(f"<li>{body(value)}</li>" for value in entries)}</ul></section>')
    for change_type, entries in grouped.items():
        if change_type not in RELEASE_TYPES and entries:
            sections.append(f'<section class="seo-release-section"><h2>{body(change_type)}</h2><ul class="detail-list">{"".join(f"<li>{body(value)}</li>" for value in entries)}</ul></section>')
    if not sections:
        sections.append(f'<p>{body(description)}</p>')
    release_url = text(item.get("releaseUrl"), "https://github.com/Mutx163/mikcb/releases")
    download_url = text(item.get("downloadUrl"), release_url)
    content = f"""
<section class="section-shell seo-article">
  {breadcrumb("../", "更新日志")}
  <p class="section-label">{body(text(item.get("channelLabel"), "版本"))} / RELEASE</p>
  <h1>轻屿课表 {body(title)} 更新日志</h1>
  <p class="seo-release-meta">发布时间：{body(published or "未标注")} · Android 课表 App · HyperOS / 教务导入 / 课程提醒</p>
  <p class="seo-lead">{body(description)}</p>
  {"".join(sections)}
  <div class="seo-related-links"><a class="primary-cta" href="{attr(download_url)}" target="_blank" rel="noreferrer">下载此版本</a><a class="secondary-cta" href="{attr(release_url)}" target="_blank" rel="noreferrer">查看 GitHub Release</a><a class="secondary-cta" href="./">返回更新列表</a></div>
</section>"""
    structured = {
        "@context": "https://schema.org",
        "@type": "TechArticle",
        "headline": f"轻屿课表 {title} 更新日志",
        "description": description,
        "datePublished": text(item.get("publishedAt"), published),
        "dateModified": text(item.get("publishedAt"), published),
        "author": {"@type": "Person", "name": "Mutx163"},
        "publisher": {"@type": "Organization", "name": "轻屿课表", "url": f"{BASE_URL}/"},
        "mainEntityOfPage": release_item_url(version),
    }
    return document(
        title=f"轻屿课表 {title} 更新日志 - Android 课表 App",
        description=description,
        canonical=release_item_url(version),
        prefix="../",
        content=content,
        structured_data=structured,
    )


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def build_sitemap(feed: dict[str, Any], schools: dict[str, Any]) -> str:
    entries: list[tuple[str, str]] = [
        (f"{BASE_URL}/", TOPIC_LASTMOD),
        (f"{BASE_URL}/schools.html", date_only(schools.get("updatedAt"))),
        (f"{BASE_URL}/releases/", date_only(feed.get("generatedAt"))),
        (f"{BASE_URL}/hyperos-timetable.html", TOPIC_LASTMOD),
        (f"{BASE_URL}/course-import.html", TOPIC_LASTMOD),
        (f"{BASE_URL}/webdav-timetable-sync.html", TOPIC_LASTMOD),
        (f"{BASE_URL}/android-timetable.html", TOPIC_LASTMOD),
        (f"{BASE_URL}/privacy.html", TOPIC_LASTMOD),
        (f"{BASE_URL}/terms.html", TOPIC_LASTMOD),
        (f"{BASE_URL}/contributing.html", TOPIC_LASTMOD),
    ]
    for item in feed.get("releases", []):
        if isinstance(item, dict) and text(item.get("version")):
            entries.append((release_item_url(item["version"]), date_only(item.get("publishedAt"))))
    seen: set[str] = set()
    urls = []
    for loc, lastmod in entries:
        if loc in seen:
            continue
        seen.add(loc)
        lastmod_tag = f"\n    <lastmod>{body(lastmod)}</lastmod>" if lastmod else ""
        urls.append(f"  <url>\n    <loc>{body(loc)}</loc>{lastmod_tag}\n  </url>")
    return '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + "\n".join(urls) + "\n</urlset>\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default=BASE_URL)
    args = parser.parse_args()
    if args.base_url != BASE_URL:
        raise SystemExit("This generator currently supports the canonical mutx.ccwu.cc site only")

    schools = validate_schools_payload(read_json(DOCS / "schools.json"))
    feed = validate_feed_payload(read_json(DOCS / "releases" / "feed.json"))

    for page in TOPIC_PAGES:
        write_text(DOCS / page["filename"], render_topic_page(page))
    write_text(DOCS / "schools.html", render_school_page(schools))
    write_text(DOCS / "releases" / "index.html", render_release_index(feed))
    generated_releases = set()
    for item in feed.get("releases", []):
        if isinstance(item, dict) and text(item.get("version")):
            filename = f"v{slug_version(item['version'])}.html"
            write_text(DOCS / "releases" / filename, render_release_detail(item))
            generated_releases.add(filename)
    removed_releases = remove_stale_release_pages(DOCS / "releases", generated_releases)
    write_text(DOCS / "sitemap.xml", build_sitemap(feed, schools))
    print(f"Generated schools.html, releases/index.html, {len(generated_releases)} release pages, removed {removed_releases} stale release pages, and sitemap.xml")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
