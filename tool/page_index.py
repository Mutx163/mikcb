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
COLS = 3  # 一行放几个页面按钮

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


def render(rows, prefix):
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
    out.append("排列顺序：课表 → 课程 → 日程与任务 → 时间与考试 → 统计 → 导入 → 迁移与导出 → "
               "同步与备份 → 实时显示 → 设置 → 帮助与展示 → 诊断 → 关于。\n")
    out.append("> 这个文件由 `python tool/page_index.py` 生成，别手改；"
               "新增/删除页面后重跑一次并随代码提交。\n")

    defs = []
    cells = []
    for i, r in enumerate(rows, start=1):
        ref = "p%d" % i
        defs.append((ref, prefix + r["file"]))
        cells.append("[%s][%s]" % (r["title"], ref))

    out.append("| 页面 | 页面 | 页面 |")
    out.append("|---|---|---|")
    for i in range(0, len(cells), COLS):
        chunk = cells[i:i + COLS]
        while len(chunk) < COLS:
            chunk.append(" ")
        out.append("| " + " | ".join(chunk) + " |")
    out.append("")

    # 数据写在独立 JSON，md 里不再放注释块（Studio 的 markdown 预览会把注释块当正文显示）
    out.append("<!-- 链接定义 -->")
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
    refresh_previews(rows)
    targets = [
        ("docs/reference/page-index.md", "../../android/app/src/" + PAGES_REL + "/"),
        ("android/docs/reference/page-index.md", "../../app/src/" + PAGES_REL + "/"),
    ]
    for path, prefix in targets:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        text = render(rows, prefix)
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        print("写入 %s（%d 行）" % (path, text.count("\n")))

    with open(DATA_JSON, "w", encoding="utf-8", newline="\n") as f:
        json.dump(rows, f, ensure_ascii=False, indent=1)
    print("写入 %s（%d 条）" % (DATA_JSON, len(rows)))


if __name__ == "__main__":
    main()
