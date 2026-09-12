#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# mikcb WSL 侧环境固化脚本（2026-09-12 新增）
#
# 背景：DSH / 无头 Agent 起的 bash 是非交互 shell，**不会加载 ~/.profile**，
#       于是 http_proxy、PUB_CACHE、ANDROID_HOME 全为空，PATH 又解析到
#       /mnt/d/Flutter/flutter/bin（Windows 侧 wrapper，CRLF shebang，在 WSL
#       下必然崩：/usr/bin/env: 'bash\r'）。本脚本把 WSL 原生工具链与环境补齐。
#
# 用法：
#   source scripts/wsl-env.sh              # 修好当前 shell（PATH/PUB_CACHE/代理）
#   bash   scripts/wsl-env.sh --doctor     # 只报告环境与 package_config 健康度
#   bash   scripts/wsl-env.sh -- <命令>    # 带修好的环境执行一条命令
#   WSL_ENV_SKIP_PROXY=1 source scripts/wsl-env.sh   # 不改代理（跑 flutter test 时用）
#
# ⚠️ 代理与 flutter test：flutter_tester 走本机 WebSocket，设置 http_proxy 会让它
#    报 "Unable to connect to flutter_tester process: Invalid WebSocket upgrade
#    request"。跑测试前先 WSL_ENV_SKIP_PROXY=1 source，或 unset 掉 *_proxy。
# ---------------------------------------------------------------------------

WSL_FLUTTER_BIN="${WSL_FLUTTER_BIN:-/opt/flutter/bin}"
WSL_ANDROID_SDK="${WSL_ANDROID_SDK:-/opt/android-sdk}"
WSL_PUB_CACHE="${WSL_PUB_CACHE:-$HOME/.pub-cache}"

wsl_env_apply() {
  export ANDROID_HOME="$WSL_ANDROID_SDK"
  export ANDROID_SDK_ROOT="$WSL_ANDROID_SDK"
  export PUB_CACHE="$WSL_PUB_CACHE"

  # 原生工具链置于 PATH 最前，压过 /mnt/d 的 Windows wrapper
  for _d in "$WSL_FLUTTER_BIN" "$WSL_ANDROID_SDK/platform-tools"; do
    case ":$PATH:" in
      *":$_d:"*) ;;
      *) PATH="$_d:$PATH" ;;
    esac
  done
  export PATH
  unset _d

  # 代理：从默认网关探测 Windows 主机 IP（NAT 下 127.0.0.1 指向 WSL 自己）
  if [ "${WSL_ENV_SKIP_PROXY:-0}" != "1" ]; then
    _win_ip="$(ip route show default 2>/dev/null | awk '/default/ {print $3; exit}')"
    if [ -n "$_win_ip" ]; then
      export http_proxy="http://${_win_ip}:7897"
      export https_proxy="$http_proxy"
      export all_proxy="socks5://${_win_ip}:7897"
      export HTTP_PROXY="$http_proxy"
      export HTTPS_PROXY="$http_proxy"
      export ALL_PROXY="$all_proxy"
      export no_proxy="localhost,127.0.0.1,::1,${_win_ip}"
      export NO_PROXY="$no_proxy"
    fi
    unset _win_ip
  fi
}

wsl_env_doctor() {
  _repo="${1:-$PWD}"
  echo "=== WSL 环境诊断 ($(date '+%F %T')) ==="
  echo "-- 发行版 / 用户 --"
  echo "distro=${WSL_DISTRO_NAME:-?} user=$(id -un) cwd=$PWD"
  echo "-- 工具链解析（务必指向 /opt，不能是 /mnt/d）--"
  _fl="$(command -v flutter 2>/dev/null || true)"
  _ad="$(command -v adb 2>/dev/null || true)"
  echo "flutter -> ${_fl:-<未找到>}"
  echo "adb     -> ${_ad:-<未找到>}"
  case "$_fl" in
    /mnt/*) echo "  ⛔ flutter 解析到 Windows 侧 wrapper，在 WSL 下必崩；先 source 本脚本" ;;
    /opt/*) echo "  ✅ flutter 为 WSL 原生" ;;
  esac
  echo "版本："
  "$WSL_FLUTTER_BIN/flutter" --version 2>&1 | head -2 | sed 's/^/  /'
  "$WSL_ANDROID_SDK/platform-tools/adb" version 2>&1 | head -1 | sed 's/^/  /'
  echo "-- .fvmrc 期望版本 --"
  [ -f "$_repo/.fvmrc" ] && sed 's/^/  /' "$_repo/.fvmrc" || echo "  (无 .fvmrc)"
  echo "-- package_config.json 健康度（跨文件系统共用文件，最易踩坏）--"
  _pc="$_repo/.dart_tool/package_config.json"
  if [ -f "$_pc" ]; then
    # 注意：grep -c 无匹配时既输出 0 又返回 1，不能接 `|| echo 0`，否则变量会变成两行
    _win=$(grep -c 'file:///[A-Za-z]:/' "$_pc" 2>/dev/null || true)
    _nix=$(grep -c 'file:///opt/flutter\|file:///home/mutx/.pub-cache' "$_pc" 2>/dev/null || true)
    _win=${_win:-0}
    _nix=${_nix:-0}
    echo "  Windows 侧路径 $_win 条；WSL 侧路径 $_nix 条"
    if [ "$_nix" -gt 0 ]; then
      echo "  ⛔ 已被 WSL 侧改写 —— Windows 侧 Cursor 会全项目 import 报错"
      echo "     修法（Windows 侧）：flutter pub get"
    else
      echo "  ✅ 指向 Windows 侧缓存，Windows 侧可用"
      echo "     ⚠️ WSL 侧 analyze 必须带 --no-pub，否则本文件会被改写"
    fi
  else
    echo "  (无 $_pc)"
  fi
  echo "-- 代理 --"
  echo "http_proxy=${http_proxy:-<空>}"
  echo "  跑 flutter test 前记得 WSL_ENV_SKIP_PROXY=1，否则 flutter_tester 会被代理拦"
  echo "-- adb 设备（WSL 侧默认不接物理设备）--"
  "$WSL_ANDROID_SDK/platform-tools/adb" devices 2>&1 | sed 's/^/  /'
  echo "=== 诊断结束 ==="
}

case "${1:-}" in
  --doctor|-d) shift; wsl_env_apply; wsl_env_doctor "$@"; ;;
  --help|-h)   sed -n '2,20p' "$0"; ;;
  --)          shift; wsl_env_apply; "$@"; ;;
  *)           wsl_env_apply; ;;
esac
