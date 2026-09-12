#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# mikcb main 双远端推送流程（bash 版，WSL 侧对等脚本）
#
# 与 scripts/sync-main.ps1 同逻辑、同铁律，供**没有 pwsh 的 WSL 侧 Agent/终端**使用
# （Windows 侧仍用 sync-main.ps1，两者行为一致；改动其一时请同步另一个）。
#
# 背景同 PS1：origin 同时挂着 GitHub 与 cnb 两个 push URL。单次 `git push origin main`
# 遇「GitHub 拒绝、cnb 成功」时，git 会把 origin/main 跟踪引用更新成 cnb 的结果；
# 之后再 `git pull --rebase`，回放范围按被污染的引用计算会变成空集，HEAD 直接快进到
# 远端，本地提交被静默丢弃（2026-09-07 实录，靠 cherry-pick 才找回）。
#
# 三条铁律：
#   1. 先拉取：push 前必 `git fetch origin main`（fetch URL 只指向 GitHub，结果可信），
#      落后就 rebase 到 origin/main，把分叉消灭在推送之前；
#   2. 不经 origin 别名推送：显式 URL 分别推 GitHub 与 cnb，推送结果不再污染跟踪引用；
#   3. cnb 只作镜像：用 --force-with-lease 钉住其当前 tip 对齐，即使 cnb 上有本地已不可达
#      的旧提交，也不可能覆盖远端新数据。
#
# 用法：
#   bash scripts/sync-main.sh            # 完整四步
#   bash scripts/sync-main.sh --dry-run  # 只做 [0][1] 检查与彩排，不推送
# ---------------------------------------------------------------------------
set -uo pipefail

GITHUB_URL="https://github.com/Mutx163/mikcb.git"
CNB_URL="https://cnb.cool/Mutx163/qingyukb.git"
DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

cd "$(dirname "$0")/.." || exit 1

if [ -t 1 ]; then C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'; C_CYN=$'\033[36m'; C_OFF=$'\033[0m'; else C_RED=""; C_GRN=""; C_YEL=""; C_CYN=""; C_OFF=""; fi
fail() { printf '%sX %s%s\n' "$C_RED" "$1" "$C_OFF"; exit 1; }
info() { printf '%s==> %s%s\n' "$C_CYN" "$1" "$C_OFF"; }

# ---- [0/4] 前置检查 -------------------------------------------------------
branch="$(git branch --show-current)"
[ "$branch" = "main" ] || fail "当前分支 ${branch}，本流程只处理 main"
head_sha="$(git rev-parse HEAD)"
dirty="$(git status --porcelain | wc -l | tr -d ' ')"

# ---- [1/4] 先拉取：以 GitHub 为唯一真源 ------------------------------------
info "[1/4] 先拉取：git fetch origin main"
git fetch origin main || fail "git fetch origin main 失败，请检查网络（WSL 侧代理见 scripts/wsl-env.sh）"
behind="$(git rev-list --count main..origin/main)"
ahead="$(git rev-list --count origin/main..main)"

if [ "$behind" -gt 0 ]; then
  printf '%s本地落后 %s 个提交（领先 %s 个），rebase 到 origin/main%s\n' "$C_YEL" "$behind" "$ahead" "$C_OFF"
  if [ "$dirty" -gt 0 ]; then
    fail "工作区有 ${dirty} 处未提交改动，无法 rebase；请先提交或 git stash（禁止 reset/clean）"
  fi
  if ! git rebase origin/main; then
    git rebase --abort 2>/dev/null
    fail "rebase 冲突，已中止恢复原状；请手工解决后重跑本流程"
  fi
  head_sha="$(git rev-parse HEAD)"
  printf '%srebase 完成%s\n' "$C_GRN" "$C_OFF"
elif [ "$ahead" -gt 0 ]; then
  printf '%s本地领先 %s 个提交，无需拉取，直接进入推送%s\n' "$C_YEL" "$ahead" "$C_OFF"
else
  printf '%s本地与 GitHub main 一致%s\n' "$C_GRN" "$C_OFF"
fi

if [ "$DRY_RUN" = "1" ]; then
  info "--dry-run：跳过 [2][3][4] 推送与校验"
  printf 'local  : %s\n' "$head_sha"
  exit 0
fi

# ---- [2/4] 推 GitHub（显式 URL，不碰 origin/main 跟踪引用）-------------------
info "[2/4] 推送 GitHub"
git push "$GITHUB_URL" main || fail "GitHub 推送被拒（远端又有新提交？）；直接重跑本流程即可先拉取再推"

# ---- [3/4] 推 cnb 镜像（force-with-lease 钉住其当前 tip）--------------------
info "[3/4] 推送 cnb 镜像"
cnb_tip="$(git ls-remote "$CNB_URL" refs/heads/main | cut -f1)"
[ -n "$cnb_tip" ] || fail "无法读取 cnb main 当前 tip"
git push "--force-with-lease=refs/heads/main:${cnb_tip}" "$CNB_URL" main \
  || fail "cnb 推送失败（其 main 已被移到 ${cnb_tip} 之外？）；确认后手工处理"

# ---- [4/4] 校验三端一致 -----------------------------------------------------
info "[4/4] 校验三端一致"
gh_tip="$(git ls-remote "$GITHUB_URL" refs/heads/main | cut -f1)"
cnb_tip2="$(git ls-remote "$CNB_URL" refs/heads/main | cut -f1)"
printf 'local  : %s\ngithub : %s\ncnb    : %s\n' "$head_sha" "$gh_tip" "$cnb_tip2"
if [ "$gh_tip" = "$head_sha" ] && [ "$cnb_tip2" = "$head_sha" ]; then
  printf '%sOK 三端一致，流程完成%s\n' "$C_GRN" "$C_OFF"
else
  fail "三端不一致，请检查上方输出"
fi
