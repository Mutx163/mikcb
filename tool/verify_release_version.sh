#!/usr/bin/env bash
# 发版版本号守卫（去 Flutter 化 P4 起）：校验 `android/version.properties`。
#
# 为什么替换掉 `verify_release_pubspec.sh`：pubspec 随 Dart 层一起删除，
# 版本号的唯一事实源变成 `android/version.properties`。语义与 pubspec 的
# `version: <name>+<code>` 一一对应（versionName / versionCodeBase）。
#
# 用法：
#   bash tool/verify_release_version.sh                       # 只校验文件本身
#   bash tool/verify_release_version.sh prerelease            # 要求版本号含 '-'
#   bash tool/verify_release_version.sh release               # 要求不含 '-'
set -euo pipefail

FILE="${1:-android/version.properties}"
MODE="${2:-}"
if [[ "${FILE}" == "prerelease" || "${FILE}" == "release" ]]; then
  MODE="${FILE}"
  FILE="android/version.properties"
fi

if [[ ! -f "${FILE}" ]]; then
  echo "ERROR: ${FILE} not found" >&2
  exit 1
fi

# CRLF 归一化（git core.autocrlf=true 时该文件是 CRLF，`$` 会撞上 \r）。
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT
tr -d '\r' < "${FILE}" > "${TMP}"

VERSION_NAME="$(sed -n 's/^versionName=//p' "${TMP}" | head -1)"
VERSION_CODE="$(sed -n 's/^versionCodeBase=//p' "${TMP}" | head -1)"

if [[ -z "${VERSION_NAME}" ]]; then
  echo "ERROR: ${FILE} 缺少 versionName= 行" >&2
  exit 1
fi
if [[ ! "${VERSION_CODE}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: ${FILE} 的 versionCodeBase 必须是非负整数（当前：${VERSION_CODE}）" >&2
  exit 1
fi

HAS_DASH=0
[[ "${VERSION_NAME}" == *-* ]] && HAS_DASH=1

case "${MODE}" in
  prerelease)
    if [[ "${HAS_DASH}" -ne 1 ]]; then
      echo "ERROR: 预发布要求 versionName 含 '-'（当前：${VERSION_NAME}）" >&2
      exit 1
    fi
    ;;
  release)
    if [[ "${HAS_DASH}" -ne 0 ]]; then
      echo "ERROR: 正式版要求 versionName 不含 '-'（当前：${VERSION_NAME}）" >&2
      exit 1
    fi
    ;;
  "")
    ;;
  *)
    echo "ERROR: 未知模式 '${MODE}'（只接受 prerelease / release）" >&2
    exit 1
    ;;
esac

echo "OK: versionName=${VERSION_NAME} versionCodeBase=${VERSION_CODE}（+100000 偏移在 build.gradle）"
