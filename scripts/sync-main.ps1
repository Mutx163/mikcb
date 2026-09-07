#Requires -Version 5.1
<#
.SYNOPSIS
    mikcb main 双远端推送流程：先拉取，后推送。

.DESCRIPTION
    背景：origin 同时挂着 GitHub 与 cnb 两个 push URL。单次 `git push origin main`
    遇到「GitHub 拒绝、cnb 成功」时，git 会把 origin/main 跟踪引用更新成 cnb 的
    结果；之后再执行 `git pull --rebase`，回放范围按被污染的跟踪引用计算会变成
    空集，HEAD 直接快进到远端，本地提交被静默丢弃（2026-09-07 实录，靠
    cherry-pick 才找回）。cnb 自带独立 remote（cnb），origin 上的第二个 push
    URL 纯属历史遗留的镜像手段。

    本流程三条铁律：
      1. 先拉取：push 前必 `git fetch origin main`（fetch URL 只指向 GitHub，
         结果可信），落后就 rebase 到 origin/main，把分叉消灭在推送之前；
      2. 不经 origin 别名推送：显式 URL 分别推 GitHub 与 cnb，推送结果不再
         污染 origin/main 跟踪引用；
      3. cnb 只作镜像：用 --force-with-lease 钉住其当前 tip 对齐，即使 cnb 上
         存在本地已不可达的旧提交，也不可能覆盖远端新数据。

.EXAMPLE
    pwsh scripts/sync-main.ps1
#>

$ErrorActionPreference = 'Stop'
Set-Location -Path (Join-Path $PSScriptRoot '..')

function Fail($msg) {
    Write-Host ("X " + $msg) -ForegroundColor Red
    exit 1
}

# ---- [0/4] 前置检查 -------------------------------------------------------
$branch = (git branch --show-current).Trim()
if ($branch -ne 'main') {
    Fail ("当前分支 " + $branch + "，本流程只处理 main")
}
$head = (git rev-parse HEAD).Trim()
$dirty = @(git status --porcelain).Count

# ---- [1/4] 先拉取：以 GitHub 为唯一真源 ------------------------------------
Write-Host '==> [1/4] 先拉取：git fetch origin main' -ForegroundColor Cyan
git fetch origin main
if ($LASTEXITCODE -ne 0) { Fail 'git fetch origin main 失败，请检查网络' }
$behind = [int](git rev-list --count main..origin/main)
$ahead  = [int](git rev-list --count origin/main..main)

if ($behind -gt 0) {
    Write-Host ("本地落后 {0} 个提交（领先 {1} 个），rebase 到 origin/main" -f $behind, $ahead) -ForegroundColor Yellow
    if ($dirty -gt 0) {
        Fail '工作区有未提交改动，无法 rebase；请先提交或 git stash'
    }
    git rebase origin/main
    if ($LASTEXITCODE -ne 0) {
        git rebase --abort 2> $null
        Fail 'rebase 冲突，已中止恢复原状；请手工解决后重跑本流程'
    }
    $head = (git rev-parse HEAD).Trim()
    Write-Host 'rebase 完成' -ForegroundColor Green
}
elseif ($ahead -gt 0) {
    Write-Host ("本地领先 {0} 个提交，无需拉取，直接进入推送" -f $ahead) -ForegroundColor Yellow
}
else {
    Write-Host '本地与 GitHub main 一致' -ForegroundColor Green
}

# ---- [2/4] 推 GitHub（显式 URL，不碰 origin/main 跟踪引用）-------------------
Write-Host '==> [2/4] 推送 GitHub' -ForegroundColor Cyan
git push https://github.com/Mutx163/mikcb.git main
if ($LASTEXITCODE -ne 0) {
    Fail 'GitHub 推送被拒（远端又有新提交？）；直接重跑本流程即可先拉取再推'
}

# ---- [3/4] 推 cnb 镜像（force-with-lease 钉住其当前 tip）--------------------
Write-Host '==> [3/4] 推送 cnb 镜像' -ForegroundColor Cyan
$cnbTip = (git ls-remote https://cnb.cool/Mutx163/qingyukb.git refs/heads/main)
if (-not $cnbTip) { Fail '无法读取 cnb main 当前 tip' }
$cnbTip = ($cnbTip -split "\s+")[0]
# 注意：lease 参数必须先拼成单个变量再传，pwsh 会把
# --force-with-lease=("..." + $var) 拆成两个 token，导致 git 把 URL 当 refspec。
$leaseArg = '--force-with-lease=refs/heads/main:' + $cnbTip
git push $leaseArg 'https://cnb.cool/Mutx163/qingyukb.git' main
if ($LASTEXITCODE -ne 0) {
    Fail ("cnb 推送失败（其 main 已被移到 " + $cnbTip + " 之外？）；确认后手工处理")
}

# ---- [4/4] 校验三端一致 -----------------------------------------------------
Write-Host '==> [4/4] 校验三端一致' -ForegroundColor Cyan
$githubTip = ((git ls-remote https://github.com/Mutx163/mikcb.git refs/heads/main) -split "\s+")[0]
$cnbTip2   = ((git ls-remote https://cnb.cool/Mutx163/qingyukb.git refs/heads/main) -split "\s+")[0]
Write-Host ("local  : " + $head)
Write-Host ("github : " + $githubTip)
Write-Host ("cnb    : " + $cnbTip2)
if ($githubTip -eq $head -and $cnbTip2 -eq $head) {
    Write-Host 'OK 三端一致，流程完成' -ForegroundColor Green
}
else {
    Fail '三端不一致，请检查上方输出'
}
