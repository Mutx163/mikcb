#!/usr/bin/env python3
"""重排页面索引，并同时刷出两份（仓库 docs/ 与 android/docs/）。

新增/删除页面后跑这一条即可：
    python tool/page_index.py

输出**只有页面按钮**的表格（点名字跳源码），其余字段藏在文末注释块里，
表格保持极窄。数据源优先读那个注释块；没有时退回归解析旧表格。
"""
import json
import os
import re

SRC = "docs/reference/page-index.md"
DATA_JSON = "tool/page_index_data.json"
PAGES_REL = "composeP1/kotlin/com/mutx163/qingyu/pages"
SRC_ROOT = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages"
LINE_W = 120  # 一行大约多宽（汉字记 2、ASCII 记 1），超了就换行


def width_of(s):
    return sum(2 if ord(ch) > 0x2E80 else 1 for ch in s)

# 这些页面在代码里没有固定中文标题（标题由 spec / 日期 / 登录状态在运行期决定），
# 按功能给一个人工确认过的中文名，避免表里混着英文入口名。
ALIAS = {
    "DayViewPage": "日视图",
    "MonthViewPage": "月视图",
    "TimetableWeekPage": "周视图",
    "SettingsPageScreen": "设置（通用）",
    "AppearanceEditorScreen": "外观编辑",
    "GlassDockIconPickerScreen": "坞站图标选择",
    "StatisticsAnalysisPage": "统计分析",
    "AboutUpdatePage": "版本更新",
    "OpenSourceLicenseDetailPage": "开源许可详情",
    "WarehouseNoTargetPage": "教务导入中转",
    "WarehouseWebLoginPage": "教务网页登录",
    "CourseStatisticsPage": "课程统计",
    "LocationTimeMatchPage": "地点作息匹配",
    "TimeSchemeManagementPage": "时间模板管理",
}

# 源码里标题重名、但实际是两个不同页面，强制区分
FORCE = {
    "LocationTimeGroupEditorPage": "地点时间组编辑",
}

# ── 人工登记段：源码扫描认不出来，必须显式列 ────────────────────────────────
#
# 设置族 20 页走共享渲染器 `SettingsPageScreen(spec)`：源码里没有 `fun XxxPage(`，
# 标题在运行期由 ARB 决定、路由在各宿主常量里 —— 扫描既扫不全也扫不准。
# 超级岛两个子屏同理：同一渲染层靠宿主入参区分，没有独立入口函数。
#
# 所以用显式清单，并在 main() 里做**存在性断言**（文件在 + 标记串在）：
# 少一样直接非零退出。清单漂了要当场红，不许静默少页。
#
# 元组：（标题, 相对 android/app/src/ 的路径, 必须命中的源码串, entry 名）
_SETTINGS = "main/kotlin/com/mutx163/qingyu/pages/settings/"
_LIVE = "composeP1/kotlin/com/mutx163/qingyu/pages/live/"

SETTINGS_SPEC_PAGES = [
    ("设置首页（课表设置）", _SETTINGS + "SettingsTimetablePage.kt",
     "object SettingsTimetablePage {", "SettingsTimetableHubPage"),
    ("设置 · 学期", _SETTINGS + "SettingsTimetablePage.kt",
     "SEMESTER_ID", "SettingsTimetableSemesterPage"),
    ("设置 · 外观", _SETTINGS + "SettingsAppearancePage.kt",
     "object SettingsAppearancePage {", "SettingsAppearanceSpecPage"),
    ("设置 · 主题管理", _SETTINGS + "SettingsAppearancePage.kt",
     "object SettingsThemeManagePage {", "SettingsThemeManagePage"),
    ("外观 · 材质（通用页签）", _SETTINGS + "SettingsMaterialPanels.kt",
     "object SettingsMaterialGeneralPage {", "SettingsMaterialGeneralPage"),
    ("外观 · 材质（课程卡页签）", _SETTINGS + "SettingsMaterialPanels.kt",
     "object SettingsMaterialCourseCardPage {", "SettingsMaterialCourseCardPage"),
    ("外观 · 首页背景（壁纸面板）", _SETTINGS + "SettingsBackdropFlowPage.kt",
     "object SettingsBackdropFlowPage {", "SettingsBackdropFlowPage"),
    ("Bing 壁纸画廊", _SETTINGS + "SettingsBingWallpaperGalleryPage.kt",
     "object SettingsBingWallpaperGalleryPage {", "SettingsBingWallpaperGalleryPage"),
    ("壁纸取景", _SETTINGS + "SettingsWallpaperPositionPage.kt",
     "object SettingsWallpaperPositionPage {", "SettingsWallpaperPositionPage"),
    ("首页小组件", _SETTINGS + "SettingsHomeWidgetPage.kt",
     "object SettingsHomeWidgetPage {", "SettingsHomeWidgetPage"),
    ("首页与导航", _SETTINGS + "SettingsHomeNavigationPage.kt",
     "object SettingsHomeNavigationPage {", "SettingsHomeNavigationPage"),
    ("课表页面设置", _SETTINGS + "SettingsTimetablePageSettingsPage.kt",
     "object SettingsTimetablePageSettingsPage {", "SettingsTimetablePageSettingsPage"),
    ("课程卡片设置", _SETTINGS + "SettingsCourseCardPage.kt",
     "object SettingsCourseCardPage {", "SettingsCourseCardPage"),
    ("设置 · 实时活动", _SETTINGS + "SettingsLivePage.kt",
     "object SettingsLivePage {", "SettingsLivePage"),
    ("实时活动自检", _SETTINGS + "SettingsLiveSelfCheckPage.kt",
     "object SettingsLiveSelfCheckPage {", "SettingsLiveSelfCheckPage"),
    ("设置 · 节假日", _SETTINGS + "SettingsHolidayPage.kt",
     "object SettingsHolidayPage {", "SettingsHolidayPage"),
    ("设置 · 节假日（高级）", _SETTINGS + "SettingsHolidayAdvancedPage.kt",
     "object SettingsHolidayAdvancedPage {", "SettingsHolidayAdvancedPage"),
    ("设置 · 天气", _SETTINGS + "SettingsWeatherPage.kt",
     "object SettingsWeatherPage {", "SettingsWeatherPage"),
    ("设置 · 诊断", _SETTINGS + "SettingsDiagnosticsPage.kt",
     "object SettingsDiagnosticsPage {", "SettingsDiagnosticsPage"),
    ("设置 · 重置", _SETTINGS + "SettingsResetPage.kt",
     "object SettingsResetPage {", "SettingsResetPage"),
]

LIVE_SUBPAGES = [
    ("上课前显示子屏", _LIVE + "DisplaySettingsPage.kt",
     "fun DisplaySettingsPage(", "DisplaySettingsBeforeSubpage"),
    ("下课前显示子屏", _LIVE + "DisplaySettingsPage.kt",
     "fun DisplaySettingsPage(", "DisplaySettingsDuringSubpage"),
]


def _assert_marker(rel, marker, entry):
    path = os.path.join("android", "app", "src", rel)
    if not os.path.exists(path):
        raise SystemExit("人工段条目 %s 的文件不存在：%s" % (entry, path))
    with open(path, encoding="utf-8", errors="replace") as f:
        src = f.read()
    if marker not in src:
        raise SystemExit("人工段条目 %s 的标记串未命中：%s → %r" % (entry, path, marker))


def manual_rows():
    """人工段的行。

    `file` 存相对 `android/app/src/` 的路径（扫描段存的是相对 pages/ 的），
    两者基准不同，靠 `href` 键在 render() 里区分链接拼法。
    """
    out = []
    for title, rel, marker, entry in SETTINGS_SPEC_PAGES:
        _assert_marker(rel, marker, entry)
        out.append({"domain": "settings_spec", "title": title, "entry": entry,
                    "file": rel, "href": rel, "previews": 0})
    for title, rel, marker, entry in LIVE_SUBPAGES:
        _assert_marker(rel, marker, entry)
        out.append({"domain": "live_sub", "title": title, "entry": entry,
                    "file": rel, "href": rel, "previews": 0})
    return out


GROUPS = [
    ("课表", "c", ["timetable"]),
    ("课程", "d1", ["course", "conflict"]),
    ("日程与任务", "d2", ["schedule", "task"]),
    ("时间与考试", "d3", ["time_scheme", "exam"]),
    ("统计", "e", ["statistics"]),
    ("导入", "g1 / g2", ["import"]),
    ("迁移与导出", "g3", ["transfer", "export"]),
    ("同步与备份", "f", ["sync"]),
    ("实时显示", "j", ["live"]),
    ("设置", "b", ["settings", "weather"]),
    ("帮助与展示", "i", ["guide", "showcase"]),
    ("诊断", "h", ["diagnostics"]),
    ("关于", "a", ["about", "feedback"]),
    # 追加在末尾：人工段从 p69 起排，旧的 p1–p68 编号一个不动
    # （校验脚本、文档、群里的引用都还认旧号）。
    ("设置二级页", "b1", ["settings_spec"]),
    ("实时显示子屏", "j1", ["live_sub"]),
]

CELL = r"`([^`]+?\.kt)`"
ROW_FULL = re.compile(r"^\| ([^|]+?) \| \[(.+?)\]\[[^\]]+\] \| `(\w+)` \| " + CELL + r" \| (\d+) \|$")
ROW_FULL_INLINE = re.compile(r"^\| ([a-z_]+) \| \[(.+?)\]\((.+?)\) \| `(\w+)` \| " + CELL + r" \| (\d+) \|$")
DEF = re.compile(r"^\[(\w+)\]: (\S+)$")
DATA_START = "<!-- DATA"
DATA_END = "-->"


def read_data_block(lines):
    try:
        start = lines.index(next(l for l in lines if l.startswith(DATA_START)))
    except StopIteration:
        return None
    rows = []
    for line in lines[start + 1:]:
        if line.strip() == DATA_END:
            break
        parts = line.split("|")
        if len(parts) == 5:
            rows.append({
                "domain": parts[0],
                "title": parts[1],
                "entry": parts[2],
                "file": parts[3],
                "previews": int(parts[4] or 0),
            })
    return rows or None


def load_rows():
    # 1) 优先读独立的 JSON（md 里不再存数据）
    if os.path.exists(DATA_JSON):
        with open(DATA_JSON, encoding="utf-8") as f:
            return json.load(f)

    # 2) 旧版：md 里的 DATA 注释块
    lines = [l.rstrip("\n") for l in open(SRC, encoding="utf-8")]
    rows = read_data_block(lines)
    if rows:
        return rows

    # 3) 更旧版：表格里带入口/文件
    rows = []
    for line in lines:
        line = line.strip()
        if DEF.match(line):
            continue
        m = ROW_FULL.match(line)
        if m:
            _first, title, entry, file, prev = m.groups()
            domain = file.split("/")[0]
        else:
            m = ROW_FULL_INLINE.match(line)
            if not m:
                continue
            domain, title, _url, entry, file, prev = m.groups()
        rows.append({
            "domain": domain,
            "title": title,
            "entry": entry,
            "file": file.replace("pages/", "", 1),
            "previews": int(prev),
        })
    return rows


def render(rows, prefix, base):
    order = {}
    for i, (title, _tag, domains) in enumerate(GROUPS):
        for d in domains:
            order[d] = i

    def rank(r):
        return (order.get(r["domain"], 99), r["entry"])

    rows = sorted(rows, key=rank)
    total = len(rows)

    out = []
    out.append("# 页面索引\n")
    out.append("**共 %d 个页面，`Ctrl+F` 搜中文，按住 `Ctrl` 点名字直接打开源码。**\n" % total)
    out.append("按功能分区成块排列：课表 → 课程 → 日程与任务 → 时间与考试 → 统计 → 导入 → "
               "迁移与导出 → 同步与备份 → 实时显示 → 设置 → 帮助与展示 → 诊断 → 关于 → "
               "设置二级页 → 实时显示子屏。\n")
    out.append("> 这个文件由 `python tool/page_index.py` 生成，别手改；"
               "新增/删除页面后重跑一次并随代码提交。\n")

    by_domain = {}
    for r in rows:
        by_domain.setdefault(r["domain"], []).append(r)

    defs = []
    n = 0
    placed = set()

    def emit(title, group):
        nonlocal n
        group.sort(key=lambda r: (r["domain"], r["entry"]))
        cells = []
        for r in group:
            n += 1
            ref = "p%d" % n
            # 扫描段的 file 相对 pages/（拼 prefix）；人工段的 href 相对 android/app/src/（拼 base）。
            defs.append((ref, (base + r["href"]) if r.get("href") else (prefix + r["file"])))
            cells.append((r["title"], "[%s][%s]" % (r["title"], ref)))
        out.append("### %s\n" % title)
        line, width = [], 0
        for name, cell in cells:
            w = width_of(name) + 6
            if line and width + w > LINE_W:
                out.append(" · ".join(line) + "\n")
                line, width = [], 0
            line.append(cell)
            width += w
        if line:
            out.append(" · ".join(line) + "\n")

    for title, _tag, domains in GROUPS:
        group = []
        for d in domains:
            group.extend(by_domain.get(d, []))
            placed.add(d)
        if not group:
            continue
        emit(title, group)

    rest = [r for r in rows if r["domain"] not in placed]
    if rest:
        emit("未归类", rest)
    out.append("")

    for ref, path in defs:
        out.append("[%s]: %s" % (ref, path))
    return "\n".join(out) + "\n"


def refresh_previews(rows):
    """预览数直接数源码里的 @Preview，避免索引写完就跟代码脱节。"""
    def stem(name):
        for s in ("Page", "Screen", "Body", "Content", "Sheet", "View"):
            if name.endswith(s) and len(name) > len(s):
                return name[: -len(s)]
        return name

    by_file = {}
    for r in rows:
        by_file.setdefault(r["file"], []).append(r)
    for file, group in by_file.items():
        path = os.path.join(SRC_ROOT, file)
        if not os.path.exists(path):
            continue
        src = open(path, encoding="utf-8", errors="replace").read()
        total = src.count("@Preview(")
        if len(group) == 1:
            group[0]["previews"] = total
            continue
        counted = {g["entry"]: 0 for g in group}
        for m in re.finditer(r"@Preview\(", src):
            tail = src[m.end(): m.end() + 900]
            pm = re.search(r"\bPreview(\w+)\(", tail)
            if not pm:
                continue
            bstem, best, best_len = stem(pm.group(1)), None, 0
            for g in group:
                common = 0
                for a, b in zip(bstem, stem(g["entry"])):
                    if a != b:
                        break
                    common += 1
                if common > best_len:
                    best, best_len = g["entry"], common
            if best and best_len >= 4:
                counted[best] += 1
        for g in group:
            g["previews"] = counted.get(g["entry"], 0)


def scan_entries():
    """扫源码得到当前的整页入口集合，新加的页不会因为“表里没有”而被漏掉。"""
    found = set()
    for dirpath, _, files in os.walk(SRC_ROOT):
        for fn in files:
            if not fn.endswith(".kt"):
                continue
            p = os.path.join(dirpath, fn)
            src = open(p, encoding="utf-8", errors="replace").read()
            for m in re.finditer(r"fun\s+(\w+(?:Page|Screen))\s*\(", src):
                line_start = src.rfind("\n", 0, m.start()) + 1
                if "private" in src[line_start:m.start()]:
                    continue
                name = m.group(1)
                if "Host" in name:
                    continue
                rel = os.path.relpath(p, SRC_ROOT).replace(os.sep, "/")
                found.add((rel, name))
    return found


def merge_with_source(rows):
    """以源码为准：源里没有的丢弃，源里有而表里没有的补上（标题用别名或入口名）。"""
    known = {(r["file"], r["entry"]): r for r in rows}
    out = []
    for file, entry in sorted(scan_entries()):
        r = known.get((file, entry))
        if r:
            out.append(r)
        else:
            out.append({
                "domain": file.split("/")[0],
                "title": ALIAS.get(entry, entry),
                "entry": entry,
                "file": file,
                "previews": 0,
            })

    # 同名入口可能在包装文件里再声明一次：优先保留文件名与入口同名、预览更多的那个
    def score(x):
        return (os.path.basename(x["file"]) == x["entry"] + ".kt", x["previews"])

    best = {}
    for r in out:
        cur = best.get(r["entry"])
        if cur is None or score(r) > score(cur):
            best[r["entry"]] = r
    return list(best.values())


def main():
    rows = load_rows()
    if not rows:
        raise SystemExit("没读到数据，检查 %s" % SRC)
    rows = merge_with_source(rows)
    for r in rows:
        if r["entry"] in FORCE:
            r["title"] = FORCE[r["entry"]]
    # 人工段（设置 spec 页 20 + 超级岛子屏 2）追加在末尾：它们不参与源码扫描，
    # 因此不会被 merge_with_source 按「源码里没这个函数」丢掉。
    rows = rows + manual_rows()
    refresh_previews(rows)
    targets = [
        ("docs/reference/page-index.md",
         "../../android/app/src/" + PAGES_REL + "/", "../../android/app/src/"),
        ("android/docs/reference/page-index.md",
         "../../app/src/" + PAGES_REL + "/", "../../app/src/"),
    ]
    for path, prefix, base in targets:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        text = render(rows, prefix, base)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("写入 %s（%d 行）" % (path, text.count("\n")))

    with open(DATA_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)
    print("写入 %s（%d 条）" % (DATA_JSON, len(rows)))


if __name__ == "__main__":
    main()
