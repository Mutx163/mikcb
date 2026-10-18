#!/usr/bin/env bash
# 发版前置体检（2026-10-18）：一条命令回答「现在能不能安全打 tag」。
#
# 只读，约 2～5 秒；联网项可关。输出 PASS / WARN / FAIL：
#   FAIL → 别打 tag；WARN → 允许继续，但要先看一眼它说的那件事。
#
# 用法：
#   bash tool/release_preflight.sh                     # 目标版本从 pubspec 推导
#   bash tool/release_preflight.sh --mode prerelease   # 显式声明渠道（默认自动推导）
#   bash tool/release_preflight.sh --target v2.1.3.4   # 显式指定目标 tag
#   bash tool/release_preflight.sh --offline           # 跳过联网检查（tag 查重 / CI 状态）
#   bash tool/release_preflight.sh --retag             # 重打 tag（仅 Tag recovery 用）
#
# 退出码：0 = 没有 FAIL；1 = 有 FAIL。
set -uo pipefail

# ---------------------------------------------------------------- 工具函数
version_gt() {
  # $1 > $2？按数字段比较，缺位补 0。
  local IFS='.'
  local -a a=($1)
  local -a b=($2)
  local n=${#a[@]}
  (( ${#b[@]} > n )) && n=${#b[@]}
  local i x y
  for ((i = 0; i < n; i++)); do
    x="${a[i]:-0}"
    y="${b[i]:-0}"
    [[ "${x}" =~ ^[0-9]+$ ]] || x=0
    [[ "${y}" =~ ^[0-9]+$ ]] || y=0
    ((10#${x} > 10#${y})) && return 0
    ((10#${x} < 10#${y})) && return 1
  done
  return 1
}

# ---------------------------------------------------------------- 参数
TARGET=""
MODE=""
OFFLINE=0
RETAG=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2 ;;
    --mode) MODE="${2:-}"; shift 2 ;;
    --offline) OFFLINE=1; shift ;;
    --retag) RETAG=1; shift ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

FAILS=0
WARNS=0
pass() { printf 'PASS  %s\n' "$*"; }
warn() { WARNS=$((WARNS + 1)); printf 'WARN  %s\n' "$*"; }
fail() { FAILS=$((FAILS + 1)); printf 'FAIL  %s\n' "$*"; }
info() { printf 'INFO  %s\n' "$*"; }

if [[ ! -f pubspec.yaml || ! -d docs/releases ]]; then
  echo "ERROR: 请在仓库根目录运行（找不到 pubspec.yaml / docs/releases）" >&2
  exit 2
fi
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: 找不到 git" >&2
  exit 2
fi

TMP_PUBSPEC="$(mktemp)"
TMP_NOTES="$(mktemp)"
trap 'rm -f "${TMP_PUBSPEC}" "${TMP_NOTES}"' EXIT
tr -d '\r' < pubspec.yaml > "${TMP_PUBSPEC}"

# gh 决定能不能查「同名 Release」与「CI 状态」。WSL 里通常没装 gh，
# 这里必须**说一声**，否则跳过两项检查后仍然显示 0 FAIL，会让人误以为查过了。
HAS_GH=0
if ((OFFLINE == 0)); then
  if command -v gh >/dev/null 2>&1; then
    HAS_GH=1
  else
    warn "找不到 gh：跳过「同名 Release」与「CI 状态」两项（在 Git Bash 里跑，或安装 gh）"
  fi
fi

# ---------------------------------------------------------------- 1. 版本形态与渠道
VERSION="$(awk '/^version:/{print $2; exit}' "${TMP_PUBSPEC}")"
BASE=""
PRE_NUM=""
BUILD=""
if [[ "${VERSION}" =~ ^([0-9]+(\.[0-9]+)*)(-([0-9]+))?\+([0-9]+)$ ]]; then
  BASE="${BASH_REMATCH[1]}"
  PRE_NUM="${BASH_REMATCH[4]:-}"
  BUILD="${BASH_REMATCH[5]}"
else
  fail "pubspec version 不可解析：'${VERSION}'（期望形如 2.1.3-3+138 或 2.1.4+139）"
fi

DERIVED_MODE="release"
[[ -n "${PRE_NUM}" ]] && DERIVED_MODE="prerelease"
if [[ -n "${MODE}" && "${MODE}" != "${DERIVED_MODE}" ]]; then
  fail "pubspec 渠道是 ${DERIVED_MODE}（'-' 段=${PRE_NUM:-无}），与声明的 ${MODE} 不一致"
else
  pass "渠道 ${DERIVED_MODE}（pubspec ${VERSION}）"
fi

DERIVED_TARGET=""
if [[ -n "${BASE}" ]]; then
  if [[ -n "${PRE_NUM}" && "${PRE_NUM}" != "0" ]]; then
    DERIVED_TARGET="v${BASE}.${PRE_NUM}"
  else
    DERIVED_TARGET="v${BASE}"
  fi
  if [[ -z "${TARGET}" ]]; then
    TARGET="${DERIVED_TARGET}"
  elif [[ "${TARGET}" != "${DERIVED_TARGET}" ]]; then
    fail "目标 tag ${TARGET} 与 pubspec ${VERSION} 推导出的 ${DERIVED_TARGET} 不一致"
  else
    pass "目标 tag ${TARGET}"
  fi
fi

# ---------------------------------------------------------------- 2. 与最后已发布版本的关系
LAST_TAG="$(git tag -l 'v*' --sort=-v:refname | head -n1)"
CONVERT=0
if [[ -z "${LAST_TAG}" ]]; then
  warn "仓库里没有任何 v* tag：无法确认 build number 是否递增"
else
  if [[ -n "${TARGET}" && "${TARGET}" == "${LAST_TAG}" && "${RETAG}" == "0" ]]; then
    CONVERT=1
    info "目标与最后发布同版本（${LAST_TAG}）：若是把预发布转正式，改 GitHub Release 的 Pre-release 勾选即可，不需要打 tag"
    info "若确需重打同名 tag（Tag recovery），先删远端 tag，再用 --retag 复查"
  fi
  LAST_VERSION="$(git show "${LAST_TAG}:pubspec.yaml" 2>/dev/null | tr -d '\r' | awk '/^version:/{print $2; exit}')"
  LAST_BUILD="$(printf '%s' "${LAST_VERSION}" | sed -E 's/^.*\+([0-9]+)$/\1/')"
  if ((CONVERT == 1)); then
    info "转换模式：pubspec 与 tag 都不改，build number 不递增是正常的"
  elif [[ "${LAST_BUILD}" =~ ^[0-9]+$ ]]; then
    if ((BUILD <= LAST_BUILD)); then
      fail "build number 没递增：pubspec +${BUILD}，而 ${LAST_TAG} 已经是 +${LAST_BUILD}"
    else
      pass "build number +${BUILD} > ${LAST_TAG} 的 +${LAST_BUILD}"
    fi
  else
    warn "读不到 ${LAST_TAG} 的 build number（'${LAST_VERSION}'）"
  fi
  if ((CONVERT == 0)) && [[ -n "${TARGET}" ]]; then
    LAST_PLAIN="${LAST_TAG#v}"
    if version_gt "${TARGET#v}" "${LAST_PLAIN}"; then
      pass "版本 ${TARGET} 高于最后发布 ${LAST_TAG}"
    else
      fail "版本 ${TARGET} 不高于最后发布 ${LAST_TAG}"
    fi
  fi
fi

# ---------------------------------------------------------------- 3. 发版说明
NOTES="docs/releases/${TARGET}.md"
if [[ -z "${TARGET}" ]]; then
  fail "拿不到目标版本，跳过发版说明检查"
elif [[ ! -f "${NOTES}" ]]; then
  fail "缺少发版说明 ${NOTES}"
else
  # 先落成 LF 临时文件再检查：`tr | grep -q` 在 pipefail 下会因 grep 提前退出、
  # tr 收到 SIGPIPE（141）而把「有匹配」误判成「没匹配」——今天就栽过这个。
  tr -d '\r' < "${NOTES}" > "${TMP_NOTES}"
  HEADING="$(awk 'NF{print; exit}' "${TMP_NOTES}")"
  if [[ "${HEADING}" == "# ${TARGET}" ]]; then
    pass "${NOTES} 首行标题正确"
  else
    warn "${NOTES} 首行是 '${HEADING}'，不是 '# ${TARGET}'"
  fi
  ITEM_COUNT="$(grep -c '^- ' "${TMP_NOTES}" || true)"
  if [[ "${ITEM_COUNT}" != "0" ]]; then
    # 两种版式都要数得对：新版按 `## 新增 · 12` 分组、条目不带前缀；
    # 旧版是扁平列表、每条以「新增 」开头。
    COUNTS="$(awk '
      /^#/ {
        kind = ""
        if ($0 ~ /新增/) kind = "a"
        else if ($0 ~ /优化/) kind = "o"
        else if ($0 ~ /修复/) kind = "f"
        else if ($0 ~ /移除/) kind = "r"
        else if ($0 ~ /(New|Added)/) kind = "a"
        else if ($0 ~ /(Improve|Enhance|Optim)/) kind = "o"
        else if ($0 ~ /Fix/) kind = "f"
        else if ($0 ~ /(Remove|Deprecat)/) kind = "r"
        next
      }
      /^- / {
        total++
        if ($0 ~ /^- 新增 /) added++
        else if ($0 ~ /^- 优化 /) improved++
        else if ($0 ~ /^- 修复 /) fixed++
        else if ($0 ~ /^- 移除 /) removed++
        else if (kind == "a") added++
        else if (kind == "o") improved++
        else if (kind == "f") fixed++
        else if (kind == "r") removed++
      }
      END { printf "新增 %d · 优化 %d · 修复 %d · 移除 %d · 合计 %d", added, improved, fixed, removed, total }' "${TMP_NOTES}")"
    pass "发版说明条目：${COUNTS}"
  else
    fail "${NOTES} 里没有任何 '- ' 条目"
  fi
  if grep -qE '^>.*本次重点' "${TMP_NOTES}"; then
    pass "已声明「本次重点」（更新弹窗照它显示前 3 条）"
  else
    warn "没有 '> 本次重点：…' 行：弹窗会退化成按「新增>优化>移除>修复」猜前 3 条"
  fi
fi

# ---------------------------------------------------------------- 4. 删除/回滚提交对账
if [[ -n "${LAST_TAG}" ]]; then
  REMOVALS="$(git log --oneline "${LAST_TAG}..HEAD" 2>/dev/null \
    | grep -Eic '(^| )(revert|还原|删\(|删除\(|移除)' || true)"
  if [[ "${REMOVALS}" != "0" ]]; then
    warn "自 ${LAST_TAG} 以来有 ${REMOVALS} 条删除/回滚提交：逐条确认日志里没有对应功能的「新增」"
  fi
fi

# ---------------------------------------------------------------- 5. tag / Release 查重
if ((CONVERT == 0)) && [[ -n "${TARGET}" ]]; then
  if git rev-parse -q --verify "refs/tags/${TARGET}" >/dev/null 2>&1; then
    fail "本地已存在 tag ${TARGET}"
  else
    pass "本地无同名 tag"
  fi
  if ((OFFLINE == 0)); then
    if REMOTE_TAG="$(git ls-remote --tags origin "refs/tags/${TARGET}" 2>/dev/null)"; then
      if [[ -n "${REMOTE_TAG}" ]]; then
        fail "远端已存在 tag ${TARGET}（历史删过同名 tag 也会走到这里：先确认要不要复用版本号）"
      else
        pass "远端无同名 tag"
      fi
    else
      warn "查不到远端 tag（网络或 remote 不可用）"
    fi
    if ((HAS_GH == 1)); then
      if GH_PROMPT_DISABLED=1 gh release view "${TARGET}" --json tagName >/dev/null 2>&1; then
        fail "GitHub 上已有同名 Release ${TARGET}（tag 可能被删过但 Release 还在）"
      fi
    fi
  fi
fi

# ---------------------------------------------------------------- 6. 工作区（未提交 = 不会进包）
TRACKED_DIRTY="$(git status --porcelain | grep -v '^??' || true)"
UNTRACKED_COUNT="$(git status --porcelain | grep -c '^??' || true)"
DIRTY_COUNT="$(git status --porcelain | wc -l | tr -d ' ')"
if [[ "${DIRTY_COUNT}" != "0" ]]; then
  warn "工作区有 ${DIRTY_COUNT} 个未提交/未跟踪条目，它们不会进本次包："
  if [[ -n "${TRACKED_DIRTY}" ]]; then
    printf '%s\n' "${TRACKED_DIRTY}" | head -n 6 | sed 's/^/        /'
  fi
  if [[ "${UNTRACKED_COUNT}" != "0" ]]; then
    info "        另有 ${UNTRACKED_COUNT} 个未跟踪文件/目录（本地工具或产物）"
  fi
else
  pass "工作区干净（本次包 = 当前 HEAD）"
fi

# ---------------------------------------------------------------- 7. 与 origin/main 的落差
if ((OFFLINE == 0)) && git rev-parse -q --verify origin/main >/dev/null 2>&1; then
  BEHIND="$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)"
  AHEAD="$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)"
  if [[ "${BEHIND}" != "0" ]]; then
    warn "落后 origin/main ${BEHIND} 个提交：先 git merge origin/main 再推，否则 push 会被拒"
  else
    pass "不落后 origin/main（本地领先 ${AHEAD} 个提交）"
  fi
fi

# ---------------------------------------------------------------- 8. 这个 commit 的 CI 是否已绿
if ((OFFLINE == 0)) && ((HAS_GH == 1)); then
  HEAD_SHA="$(git rev-parse HEAD)"
  CI_LINE="$(GH_PROMPT_DISABLED=1 gh run list --workflow=ci.yml --branch main --limit 1 \
    --json headSha,conclusion,status \
    --jq '.[0] | [.headSha, .conclusion, .status] | @tsv' 2>/dev/null || true)"
  if [[ -z "${CI_LINE}" ]]; then
    warn "查不到 main 上 CI 的状态（gh 未登录或网络不可用）"
  else
    CI_SHA="$(printf '%s' "${CI_LINE}" | awk '{print $1}')"
    CI_CONC="$(printf '%s' "${CI_LINE}" | awk '{print $2}')"
    CI_STATUS="$(printf '%s' "${CI_LINE}" | awk '{print $3}')"
    if [[ "${CI_SHA}" != "${HEAD_SHA}" ]]; then
      warn "main 上最近一次 CI 不是当前 HEAD（${HEAD_SHA:0:8}）：推 main 后等它绿再打 tag"
    elif [[ "${CI_STATUS}" != "completed" ]]; then
      warn "当前 HEAD 的 CI 还在跑（${CI_STATUS}）：等它绿再打 tag"
    elif [[ "${CI_CONC}" == "success" ]]; then
      pass "当前 HEAD 的 CI 已全绿：tag 会复用这次结果，省掉重复的 7～8 分钟"
    else
      fail "当前 HEAD 的 CI 是 ${CI_CONC}：先修红再发版（tag 的检查与 CI 同源，必挂）"
    fi
  fi
fi

# ---------------------------------------------------------------- 汇总
printf '\n—— %s 个 FAIL，%s 个 WARN ——\n' "${FAILS}" "${WARNS}"
if ((FAILS > 0)); then
  printf '结论：还不能打 tag。\n'
  exit 1
fi
if ((CONVERT == 1)); then
  printf '结论：同版本转正式 —— 去 GitHub Release 取消 Pre-release 勾选即可，不用打 tag。\n'
  exit 0
fi
printf '结论：可以打 tag。顺序（不要并行）：\n'
printf '  1) git push origin main\n'
printf '  2) 等这次 push 的 CI 变绿：gh run watch <run-id> --exit-status\n'
printf '  3) git tag -a %s -m "chore: cut %s %s"\n' "${TARGET}" "${TARGET}" "${DERIVED_MODE}"
printf '  4) git push origin %s\n' "${TARGET}"
exit 0
