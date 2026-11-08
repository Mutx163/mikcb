#!/usr/bin/env python3
"""重排页面索引，并同时刷出两份（仓库 docs/ 与 android/docs/）。

新增/删除页面后跑这一条即可：
    python tool/page_index.py

数据源是 docs/reference/page-index.md 的表格行；输出**一张表装全库**，
按软件分区（a..j，见 main/pages/ShellPageIndex.kt）排序，分区作为第一列。
链接用引用式（`[名字][pN]` + 文末 `[pN]: 路径`），避免长地址把表格撑宽。
"""
import os
import re

SRC = "docs/reference/page-index.md"
PAGES_REL = "composeP1/kotlin/com/mutx163/qingyu/pages"

# 分区顺序 = 打开 App 到设置的路径；tag 是官方路由前缀
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

CELL = r"`([^`]+?\.kt)`"
ROW_INLINE = re.compile(
    r"^\| ([a-z_]+) \| \[(.+?)\]\((.+?)\) \| `(\w+)` \| " + CELL + r" \| (\d+) \|$"
)
# 新格式多一列分区
ROW_REF = re.compile(
    r"^\| ([^|]+?) \| \[(.+?)\]\[[^\]]+\] \| `(\w+)` \| " + CELL + r" \| (\d+) \|$"
)
ROW_REF_OLD = re.compile(
    r"^\| ([a-z_]+) \| \[(.+?)\]\[[^\]]+\] \| `(\w+)` \| " + CELL + r" \| (\d+) \|$"
)
DEF = re.compile(r"^\[(\w+)\]: (\S+)$")


SRC_ROOT = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages"


def _stem(name: str) -> str:
    for s in ("Page", "Screen", "Body", "Content", "Sheet", "View"):
        if name.endswith(s) and len(name) > len(s):
            return name[: -len(s)]
    return name


def refresh_previews(rows) -> None:
    """预览数直接数源码里的 @Preview，避免索引写完就跟代码脱节。"""
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
        # 同文件多入口：按 @Preview 后调用的公共体名归到最像的入口
        counted = {g["entry"]: 0 for g in group}
        for m in re.finditer(r"@Preview\(", src):
            tail = src[m.end(): m.end() + 900]
            pm = re.search(r"\bPreview(\w+)\(", tail)
            if not pm:
                continue
            bstem, best, best_len = _stem(pm.group(1)), None, 0
            for g in group:
                common = 0
                for a, b in zip(bstem, _stem(g["entry"])):
                    if a != b:
                        break
                    common += 1
                if common > best_len:
                    best, best_len = g["entry"], common
            if best and best_len >= 4:
                counted[best] += 1
        for g in group:
            g["previews"] = counted.get(g["entry"], 0)


def load_rows():
    """同时认三种写法（旧 inline / 旧按域 / 新按分区），保证重跑幂等。"""
    rows = []
    for line in open(SRC, encoding="utf-8"):
        line = line.strip()
        if DEF.match(line):
            continue
        m = ROW_INLINE.match(line)
        if m:
            domain, title, _url, entry, file, prev = m.groups()
        else:
            m = ROW_REF_OLD.match(line) or ROW_REF.match(line)
            if not m:
                continue
            _first, title, entry, file, prev = m.groups()
            # 域从文件路径推断：pages/<域>/...
            domain = file.split("/")[0]
        rows.append({
            "domain": domain,
            "title": title,
            "entry": entry,
            "file": file.replace("pages/", "", 1),
            "previews": int(prev),
        })
    for r in rows:
        if r["title"] == r["entry"] and r["entry"] in ALIAS:
            r["title"] = ALIAS[r["entry"]]
    refresh_previews(rows)
    return rows


def render(rows, prefix):
    total = sum(r["previews"] for r in rows)
    order = {}
    for i, (title, _tag, domains) in enumerate(GROUPS):
        for d in domains:
            order[d] = (i, title)

    def rank(r):
        idx, _ = order.get(r["domain"], (99, "未归类"))
        return (idx, r["domain"], r["entry"])

    rows_sorted = sorted(rows, key=rank)

    out = []
    out.append("# 页面索引\n")
    out.append("**一张表装全库，`Ctrl+F` 搜中文就能定位，不用按分区往下翻。**\n")
    out.append("共 **%d** 个整页入口、**%d** 个预览。\n" % (len(rows), total))
    out.append("## 怎么用\n")
    out.append("1. `Ctrl+F` 搜你记得的中文页名，直接跳到那一行。")
    out.append("2. 按住 `Ctrl` 点名字（macOS 是 `Cmd`），打开对应源码文件。")
    out.append("3. 打开文件滚到底、右侧点 **Split / Preview**，就是这一页的全部档位。\n")
    out.append("> **这个文件是生成的，别手改。** 在 `pages/` 下新增、改名或删除整页入口后，")
    out.append("> 在仓库根跑 `python tool/page_index.py` 重新生成，并随代码一起提交。\n")
    out.append("## 口径\n")
    out.append("- 分区对应 App 的路由编号（`ShellPageIndex.kt` 里的 `a.*` … `j.*`），顺序按打开 App 到设置的路径。")
    out.append("- 入口 = 非 `private` 的 `fun XxxPage(` / `fun XxxScreen(`；`XxxHost` 是接线层，不收。")
    out.append("- 少数页面的标题由运行期决定（设置类的 `spec.title`、周/日/月视图、网页登录页），"
               "表里用的是按功能确定的中文名。")
    out.append("- 预览数按 `@Preview` 后调用的公共体归属，用来判断「这页铺没铺」，不是精确统计。\n")
    out.append("## 全部页面\n")
    out.append("| 分区 | 页面 | 入口 | 文件 | 预览 |")
    out.append("|---|---|---|---|---|")

    defs = []
    n = 0
    for r in rows_sorted:
        n += 1
        ref = "p%d" % n
        defs.append((ref, prefix + r["file"]))
        tag = order.get(r["domain"], (99, "未归类"))[1]
        out.append("| %s | [%s][%s] | `%s` | `%s` | %d |"
                   % (tag, r["title"], ref, r["entry"], r["file"], r["previews"]))
    out.append("")

    out.append("## 按分区统计\n")
    out.append("| 分区 | 入口数 |\n|---|---|")
    counts = {}
    for r in rows:
        counts[r["domain"]] = counts.get(r["domain"], 0) + 1
    for title, _tag, domains in GROUPS:
        c = sum(counts.get(d, 0) for d in domains)
        if c:
            out.append("| %s | %d |" % (title, c))
    out.append("")

    out.append("<!-- 链接定义：表格里的 [名字][pN] 指到这里 -->")
    for ref, path in defs:
        out.append("[%s]: %s" % (ref, path))
    return "\n".join(out) + "\n"


def main():
    rows = load_rows()
    if not rows:
        raise SystemExit("没读到表格行，检查 %s 是否存在" % SRC)
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


if __name__ == "__main__":
    main()
