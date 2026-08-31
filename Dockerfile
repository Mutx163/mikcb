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
