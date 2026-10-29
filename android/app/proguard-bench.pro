# bench 构建类型专用 ProGuard/R8 规则（2026-10-29）
#
# 定位：`bench` = 与正式版**同一档**优化（R8 混淆 + 非 debuggable），只额外保留
# 「能让栈信息对回源码」的最小信息。它不是「为了好调试而关掉优化」——
# 优化档位一旦和正式版不同，量出来的帧率与启动时间就没有意义了。
#
# 只挂 bench（见 android/app/build.gradle 的 buildTypes.bench）。
# release 的规则一个字节都不动，避免为了调试把正式包也改胖。

# 行号 + 源文件名：崩溃栈、Perfetto/simpleperf 的采样栈能直接对回 .kt 行
# （配合 build/app/outputs/mapping/<变体>/mapping.txt 反混淆）。
-keepattributes SourceFile,LineNumberTable
