# ─────────────────────────────────────────────────────────────
# 轻屿课表 · CNB 构建镜像
# 基于 cirruslabs/flutter 官方镜像（含 Android SDK + JDK 21），
# 将 Flutter SDK 替换为项目 .fvmrc 指定的稳定版 3.44.8，
# 以匹配 pubspec.yaml 对 Dart SDK >=3.12.2 的要求。
# ─────────────────────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:3.44.0

USER root

ENV FLUTTER_VERSION=3.44.8 \
    FLUTTER_HOME=/sdks/flutter \
    FLUTTER_ROOT=/sdks/flutter

# 替换 Flutter SDK：官方发行 tarball 稳定可复现，避免 git clone 漂移。
# 优先使用国内镜像加速，失败时回退到 Google 官方源。
RUN set -eux; \
    rm -rf "${FLUTTER_HOME}" /tmp/flutter-sdk; \
    mkdir -p /tmp/flutter-sdk; \
    curl -fsSL --retry 3 \
      "https://storage.flutter-io.cn/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter-sdk/flutter.tar.xz \
    || curl -fsSL --retry 3 \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
      -o /tmp/flutter-sdk/flutter.tar.xz; \
    tar -xJf /tmp/flutter-sdk/flutter.tar.xz -C /; \
    mv /flutter "${FLUTTER_HOME}"; \
    rm -rf /tmp/flutter-sdk; \
    # tarball 解压出的 SDK 文件属主非 root，需将 FLUTTER_HOME 加入
    # git safe.directory，否则 flutter 内置 git 操作会报 dubious ownership
    git config --global --add safe.directory "${FLUTTER_HOME}"; \
    flutter --version; \
    dart --version; \
    flutter precache --android

ENV PATH="${PATH}:${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin"

# ── HyperOS 审计依赖 ─────────────────────────────────────────
# 基础镜像未预装 PyYAML。Ubuntu noble 启用 PEP 668（externally-managed-environment），
# pip 直接装包会失败，故改用 apt 安装发行版自带的 python3-yaml（提供 import yaml）。
# 直接预装进构建镜像，避免每次构建都执行安装（GitHub Actions 每次跑，
# CNB 流水线在镜像层固化，更快更稳）。
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3-yaml; \
    rm -rf /var/lib/apt/lists/*; \
    python3 -c "import yaml; print('PyYAML via python3-yaml OK')"

# ── crossguard 依赖：PowerShell 7（钉版本，2026-11-12）──────────────
# 为什么镜像必须有 pwsh：JVM 单测里的 CrossDomainGateGuardTest 会**真的**以子进程调用
# `scripts/compose-style-lint.ps1`（样式门禁）。缺 pwsh ⇒ 这条门禁在 CNB 上必然
# fail-closed 红，而且会被误读成「代码有问题」。python3 由上面那层 apt 一并提供。
# 钉 7.4.6：可复现；升级要显式改 ARG，别让镜像漂。
ARG PWSH_VERSION=7.4.6
RUN set -eux; \
    curl -fsSL --retry 3 \
      "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz" \
      -o /tmp/pwsh.tar.gz; \
    mkdir -p /opt/microsoft/powershell/7; \
    tar -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7; \
    chmod +x /opt/microsoft/powershell/7/pwsh; \
    ln -sf /opt/microsoft/powershell/7/pwsh /usr/bin/pwsh; \
    rm -f /tmp/pwsh.tar.gz; \
    pwsh -v; \
    python3 -V
