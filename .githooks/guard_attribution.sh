#!/bin/sh
# 架构守卫红项归因（2026-10-20）—— pre-commit 的第一道门禁失败时调用。
#
# 背景：架构守卫（flutter test test/architecture/）读的是**整个工作区**，
# 并行会话的在途改动会顶爆别人的域，把无辜的提交拦下（2026-10-19 一晚
# 4 次 --no-verify 全是这个原因）。本脚本回答一个问题：
#
#   红项守卫读的文件，和本次提交的文件有没有关系？
#
# 判定（域映射见 .githooks/guard_domains.txt）：
#   1. 红项域 ∩ 本次提交文件 = ∅        → 外来红项，放行
#   2. 红项域 ∩ 提交 ≠ ∅，且域内混有
#      不属于本次提交的在途改动          → 无法切分，放行但打印警告
#      （守卫读工作区，无法把红项精确切给谁；CI 全量测试仍会兜底）
#   3. 红项域 ∩ 提交 ≠ ∅，域内无外来改动 → 疑似本次提交引入，拦下
#   4. 红项对不上任何已登记的棘轮/文件   → 按本次提交引入处理（保守）
#
# 用法: sh .githooks/guard_attribution.sh <flutter_test 输出文件>
# 退出码: 0 = 放行（理由已打印到 stderr）；1 = 拦下
set -u

out_file="$1"

cd "$(git rev-parse --show-toplevel)" || exit 1
exec 1>&2   # 本脚本全部输出走 stderr，与 pre-commit 的既有输出流一致

map_file=".githooks/guard_domains.txt"
staged_list=$(mktemp); dirty_list=$(mktemp); foreign_list=$(mktemp)
test_map=$(mktemp); file_map=$(mktemp)
trap 'rm -f "$staged_list" "$dirty_list" "$foreign_list" "$test_map" "$file_map"' EXIT

git diff --cached --name-only | tr -d '\r' | tr '\\' '/' | sort > "$staged_list"
git diff HEAD --name-only     | tr -d '\r' | tr '\\' '/' | sort > "$dirty_list"
comm -13 "$staged_list" "$dirty_list" > "$foreign_list"

if [ ! -f "$map_file" ]; then
  echo "pre-commit 归因: 找不到 $map_file，无法归因，按本次提交引入处理（保守）。"
  exit 1
fi
grep '^test=' "$map_file" | tr -d '\r' > "$test_map"
grep '^file=' "$map_file" | tr -d '\r' > "$file_map"

# paths_under <列表文件> <域根...> —— 打印列表里落在任一域根下的路径。
# 域根以 / 结尾按前缀匹配，否则要求整路径相等或作为目录前缀。
paths_under() {
  awk -v roots="$*" '
    BEGIN { n = split(roots, R, /[ \t]+/) }
    {
      for (i = 1; i <= n; i++) {
        r = R[i]; if (r == "") continue
        if (r ~ /\/$/) { if (index($0, r) == 1) { print; next } }
        else { if ($0 == r || index($0, r "/") == 1) { print; next } }
      }
    }' "$1"
}

# attribute <红项标签> <域路径...> —— 打印归因结论；返回 0 放行 / 1 拦下。
attribute() {
  label="$1"; domain="$2"
  staged_hit=$(paths_under "$staged_list" $domain)
  foreign_hit=$(paths_under "$foreign_list" $domain)
  if [ -z "$staged_hit" ]; then
    echo "pre-commit 归因: 【红项与本次提交无关】$label"
    echo "    域 = $domain —— 与本次提交的暂存文件无交集，红项来自在途改动："
    printf '      %s\n' $foreign_hit
    echo "    放行（CI 的全量测试仍会兜底）。"
    return 0
  fi
  if [ -n "$foreign_hit" ]; then
    echo "pre-commit 归因: 【红项混入在途改动，无法与本次提交切分】$label"
    echo "    域 = $domain"
    echo "    本次提交涉及该域："
    printf '      %s\n' $staged_hit
    echo "    域内混有不属于本次提交的在途改动："
    printf '      %s\n' $foreign_hit
    added=$(git diff HEAD --numstat -- $foreign_hit | awk '{s+=$1} END {print s+0}')
    echo "    在途改动合计 +$added 行。守卫读的是工作区，无法切分红项归属 → 放行。"
    over=$(sed -n 's/.*当前 \([0-9][0-9]*\) > 基线 \([0-9][0-9]*\).*/\1 \2/p' "$out_file" | head -1 |
      awk '{ if (NF == 2) printf "当前 %d / 基线 %d（差 +%d）", $1, $2, $1 - $2 }')
    [ -n "$over" ] && echo "    失败读数：$over。若差值明显大于在途 +$added 行，你的同域改动可能也有份，请自查。"
    echo "    同域自查：flutter test --plain-name \"<棘轮名>\"（CI 仍会兜底）。"
    return 0
  fi
  echo "pre-commit 归因: 【疑似本次提交引入】$label"
  echo "    域 = $domain —— 本次提交涉及该域，且域内没有外来在途改动。"
  echo "    棘轮只减不增：改动该拆就拆，别用抬基线的方式变绿（先问增长能不能下沉）。"
  return 1
}

verdict=0
saw_failure=0
matched_files=" "

# 第一轮：按失败证据片段（reason 文本只在失败时打印）认领各棘轮的红项。
while IFS='|' read -r tname tfrag tfile tdom; do
  [ -n "${tfrag:-}" ] || continue
  tname="${tname#test=}"
  hit=0
  rest="$tfrag"
  while [ -n "$rest" ]; do
    f="${rest%%~*}"
    rest="${rest#"$f"}"; rest="${rest#"~"}"   # "~" 必须加引号：裸 ~ 会被展开成主目录，剥不掉分隔符
    if grep -Fq -- "$f" "$out_file"; then hit=1; break; fi
  done
  if [ "$hit" = 1 ]; then
    saw_failure=1
    matched_files="$matched_files$tfile "
    attribute "棘轮「$tname」（$tfile）" "$tdom" || verdict=1
  fi
done < "$test_map"

# 第二轮：同文件里没被任何 test= 认领的失败，按整文件回退域归因。
while IFS='|' read -r fname fdom; do
  [ -n "${fdom:-}" ] || continue
  fname="${fname#file=}"
  case "$matched_files" in
    *" $fname "*) continue ;;
  esac
  if grep -F "architecture/$fname" "$out_file" | grep -Fq '[E]'; then
    saw_failure=1
    attribute "守卫文件 $fname（未能定位到具体棘轮）" "$fdom" || verdict=1
  fi
done < "$file_map"

# 第三轮：一条红项都对不上号 —— 保守处理为本次提交引入，并提示可能的盲区。
if [ "$saw_failure" = 0 ]; then
  echo "pre-commit 归因: 守卫失败，但没有任何红项对得上已登记的棘轮/文件（可能是新增守卫未登记、或守卫自身报错）。"
  untracked=$(git ls-files --others --exclude-standard -- test/architecture/ | head -5)
  if [ -n "$untracked" ]; then
    echo "    注意：test/architecture/ 下有未跟踪的新测试文件（可能是并行会话的半成品）："
    printf '      %s\n' $untracked
  fi
  echo "    按本次提交引入处理（保守）。确认是外来红项后，请同步登记 .githooks/guard_domains.txt。"
  exit 1
fi

exit "$verdict"
