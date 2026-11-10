-dontwarn com.umeng.**
-keep class com.umeng.** { *; }
-keepclassmembers class * {
    public <init>(org.json.JSONObject);
}

# Room 生成的 *_Impl 由 Room 反射调用无参构造创建。
#
# Room 2.6.1 自带的 consumer rule 只有
#   -keep class * extends androidx.room.RoomDatabase
# 在 AGP 9.4.1 / R8 下它只保住了类名，没保住 <init>()：
# build/app/outputs/mapping/<变体>/usage.txt 里能看到
#   androidx.work.impl.WorkDatabase_Impl:
#       public void <init>()
# 被 removed（2026-11-02 实测，perfBench 2.1.4-1-profile-bench）。
#
# 后果不是「某个功能不可用」，而是**进程启动即崩**：
# androidx.startup.InitializationProvider 在 Application.onCreate 之前初始化
# WorkManager，反射 new WorkDatabase_Impl() 抛
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# 所有走 R8 的包（release / bench）都会中，debug 不跑 R8 所以看不出来。
#
# -keep 带上成员块才会保构造函数；只写类名不够。
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# ── 平台 WebView 的 JS 桥（双保险，不是补缺口）────────────────────────────────
#
# 教务导入的 WebView 用 `addJavascriptInterface(bridgeProxy, "QingyuBridge")` 把
# `WarehouseBridgeProxy.postMessage(String)` 暴露给页面里的脚本
# （WarehouseWebViewHost.kt:320 声明、:465 注册）。JavaBridge 是**按方法名**从 JS
# 侧反射调用的：R8 一旦把 `postMessage` 改名，页面里的 `QingyuBridge.postMessage(...)`
# 会静默变成 undefined，脚本全卡在「等页面回传」且不抛异常——坏起来很难查。
#
# ⚠️ 这条规则**默认规则集里本来就有**：AGP 的 `proguard-android-optimize.txt` 自带
# 「Preserve annotated Javascript interface methods」（2026-11-02 prodBench 的 R8
# configuration.txt:56-58 可见原文）。项目里再写一遍是**双保险**，防的是将来默认
# 规则集调整时这里悄无声息地失守；不是缺了它会坏。
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# AndroidX 通过清单注入的 ComponentFactory（合并清单里的
# `android:appComponentFactory="androidx.core.app.CoreComponentFactory"`）。
# ⚠️ AGP 也会保它：从合并清单生成的 `aapt_rules.txt:2` 就是
# `-keep class androidx.core.app.CoreComponentFactory { <init>(); }`（release/bench
# 各变体产物实测都有这一行）。这里显式再保是**双保险**，不是缺了它会崩。
-keep class androidx.core.app.CoreComponentFactory { *; }

# ── 依赖自带的规则（2026-11-09 逐个拆 AAR/JAR 核过，勿重复抄）──────────────────
#
# 下列依赖已内置 consumer proguard 规则（AGP 自动合并），重开 R8 时不需要在项目里
# 再抄一遍；重复 keep 只会无谓地卡住裁剪：
#   · androidx.work:work-runtime 2.10.1 —— proguard.txt 有
#     `-keepnames class * extends androidx.work.ListenableWorker` + 保构造，
#     LiveUpdateRefreshWorker / WidgetRefreshWorker 这类按类名被 WorkManager
#     从库里反实例化的 Worker 已覆盖（类名写进 WorkManager 的库，改名会断）。
#   · androidx.room:room-runtime 2.6.1 —— proguard.txt；上面那条 RoomDatabase
#     构造 keep 是补它在 AGP 9.4.1 下「只保类名不保 <init>()」的实测缺口。
#   · com.google.mlkit:barcode-scanning 17.3.0、androidx.camera:* 1.6.1 —— 均带
#     proguard.txt（扫码/相机链不需要额外 keep）。
#   · com.squareup.okhttp3:okhttp 4.12.0 —— jar 内 META-INF/proguard/okhttp3.pro。
#   · com.umeng.umsdk:apm 2.1.0 / uyumao 1.1.2 —— 带 proguard.txt；common / asms
#     没有规则，由上面 `-keep class com.umeng.** { *; }` 兜住。
#   · miuix 0.9.4（含本地 fork）：纯 Compose 直调，fork 源码里 0 处
#     Class.forName/getMethod/JavascriptInterface，不需要 keep。
#   · androidx.core:core、androidx.startup:startup-runtime —— 均带 proguard.txt。
