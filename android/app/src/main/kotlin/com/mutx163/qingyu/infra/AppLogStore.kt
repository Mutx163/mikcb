package com.mutx163.qingyu.infra

import java.io.File

/**
 * 应用日志存储（Android 薄壳，源：`lib/services/app_log_service.dart`）。
 *
 * 所有格式/截断/合并口径都在 [AppLogFile]（纯 JVM 单测覆盖）；本对象只负责
 * 「持有 `filesDir`、串行写、吞掉异常、给轮询一个指纹」。
 *
 * ## 为什么这里没有 `import android.content.Context`
 *
 * 见 [AppLogFile] 顶部说明：`infra/` 是全队 L0 共用的纯 Kotlin 目录，只要出现
 * 一个 `android.*` 导入，`scripts/test-kotlin-module.ps1` 就会跳过整个目录，
 * 24 个模块的 L0 一起 `Unresolved reference`。所以 Android 入口长这样：
 *
 * ```kotlin
 * // UmengApplication.onCreate（Lead 接线）——两种写法都行：
 * AppLogStore.initialize(this)          // 反射取 filesDir + versionName
 * AppLogStore.initialize(filesDir)      // 只给目录（无 version 行）
 * AppLogStore.initialize(filesDir, "1.2.3+456")  // 目录 + 版本
 * ```
 *
 * 反射只碰 `Context.getFilesDir()` / `PackageManager.getPackageInfo(...)` 这两个
 * **framework 公共 API**（R8 不改名 framework 类），失败时静默降级为「未初始化」：
 * [append] 返回 false、[readText] 只回头部，不会崩。
 *
 * ## 纪律
 *
 * - 写失败**不抛**（日志不能破坏业务流），连续失败只是返回 false 给调用方；
 * - 写与截断在同一把锁里（Dart 的 `_writeQueue` 串行化等价物），避免截断和追加交错；
 * - 读不加锁（Dart 也不加），文件半写时最多读到半条，解析侧按段落容错。
 */
object AppLogStore {

    @Volatile
    private var logFile: File? = null

    @Volatile
    private var nativeLogFile: File? = null

    @Volatile
    private var appVersion: String? = null

    /** 写串行化（替代 Dart `_writeQueue`）。 */
    private val writeLock = Any()

    // ---------- 初始化 ----------

    /** 纯目录入口（JVM 单测用这个；Android 侧也可在 `Application` 里传 `filesDir`）。 */
    fun initialize(filesDir: File) {
        initialize(filesDir, null)
    }

    /**
     * 目录 + 版本号入口。[version] 形如 `1.2.3+456`（Dart `'${version}+${buildNumber}'`），
     * 为空时头部不写 `version=` 行。
     */
    fun initialize(filesDir: File, version: String?) {
        val dir = File(filesDir, APP_LOG_DIR_NAME)
        logFile = File(dir, APP_LOG_FILE_NAME)
        nativeLogFile = File(dir, NATIVE_DIAGNOSTICS_FILE_NAME)
        appVersion = version?.takeIf { it.isNotEmpty() }
        runCatching { dir.mkdirs() }
    }

    /**
     * Android `Context` 入口（Lead 在 `UmengApplication.onCreate` 里 `AppLogStore.initialize(this)`）。
     *
     * 参数类型刻意写成 [Any]：这样本文件不需要 `import android.content.Context`，
     * 全队 L0 的 classpath 保持纯净（理由见类注释）。取不到 `filesDir` 时保持
     * 未初始化状态，后续 [append] 一律返回 false（可见、不崩）。
     */
    fun initialize(context: Any) {
        val filesDir = runCatching {
            context.javaClass.getMethod("getFilesDir").invoke(context) as? File
        }.getOrNull() ?: return
        initialize(filesDir, contextVersion(context))
    }

    /** 文件是否已就位（Android 反射失败时会是 false）。 */
    fun isInitialized(): Boolean = logFile != null

    /** 应用日志文件（未初始化 / 测试探查用）。 */
    fun appLogFile(): File? = logFile

    /** 原生超级岛诊断日志文件（只读 + 清空，写入方是 `UmengDiagnosticReporter`）。 */
    fun nativeDiagnosticsFile(): File? = nativeLogFile

    // ---------- 写 ----------

    /**
     * 追加一条日志（Dart `log()` 的落盘段 :214-247）：先截断再追加，写失败返回 false。
     *
     * 返回 true 只代表「这次写没抛」，调用方不需要也不应该因此做业务分支。
     */
    fun append(
        level: String,
        category: String,
        message: String,
        extras: Map<String, Any?> = emptyMap(),
    ): Boolean {
        val file = logFile ?: return false
        return try {
            synchronized(writeLock) {
                file.parentFile?.mkdirs()
                trimAppLogIfNeeded(file)
                file.appendText(
                    buildAppLogEntryPayload(
                        level = level,
                        category = category,
                        message = message,
                        extras = extras,
                        nowMillis = System.currentTimeMillis(),
                    ),
                )
            }
            true
        } catch (t: Throwable) {
            // 日志写失败绝不能反向打断业务流；连续失败由调用方的取模节流负责可见性。
            false
        }
    }

    /**
     * 追加一段**已格式化**的条目（崩溃落盘用：格式化与脱敏在纯函数
     * `formatCrashEntry`，见 `infra/CrashLog.kt`）。
     *
     * 与 [append] 共用同一把写锁与截断逻辑；未初始化或写失败返回 false，不抛。
     */
    fun appendRawPayload(payload: String): Boolean {
        val file = logFile ?: return false
        return try {
            synchronized(writeLock) {
                file.parentFile?.mkdirs()
                trimAppLogIfNeeded(file)
                file.appendText(payload)
            }
            true
        } catch (_: Throwable) {
            false
        }
    }

    // ---------- 读 ----------

    /** 应用日志全文（头部 + 正文，Dart `readAppLogsText` :250-264）。 */
    fun readText(forExport: Boolean = false): String {
        val header = buildAppLogHeader(appVersion, forExport, System.currentTimeMillis())
        val file = logFile ?: return header
        if (!file.isFile) {
            return header
        }
        val body = runCatching { file.readText().trim() }.getOrDefault("")
        return composeAppLogText(header, body)
    }

    /** 原生超级岛诊断日志正文（只读；文件不存在返回空串）。 */
    fun readNativeText(): String {
        val file = nativeLogFile ?: return ""
        if (!file.isFile) {
            return ""
        }
        return runCatching { file.readText() }.getOrDefault("")
    }

    /**
     * 合并源全文（Dart `readMergedLogsText` :266-290）：应用日志 + 原生诊断日志，
     * 各自打 `source=app` / `source=native`。日志查看器默认看的就是这一份。
     */
    fun readMergedText(forExport: Boolean = false): String {
        val header = buildAppLogHeader(appVersion, forExport, System.currentTimeMillis())
        val appBody = extractAppLogBody(readText(forExport = false))
        val nativeBody = extractAppLogBody(readNativeText())
        val merged = mergeAppLogText(appBody, nativeBody)
        return composeAppLogText(header, merged)
    }

    // ---------- 指纹（轮询去重） ----------

    /** 应用日志指纹 `"size:mtime"`（Dart `_logFileFingerprint`）；文件不存在为 null。 */
    fun fingerprint(): String? = appLogFingerprint(logFile)

    /** 原生诊断日志指纹；文件不存在为 null。 */
    fun nativeFingerprint(): String? = appLogFingerprint(nativeLogFile)

    // ---------- 清空 ----------

    /** 清空应用日志（Dart `clearAppLogs` :377-393）：删文件，失败返回 false。 */
    fun clear(): Boolean {
        val file = logFile ?: return false
        return try {
            synchronized(writeLock) {
                if (file.isFile) file.delete()
            }
            true
        } catch (t: Throwable) {
            false
        }
    }

    /**
     * 清空原生超级岛诊断日志（Dart `liveService.clearLiveDiagnostics()` 的等价动作）。
     *
     * 只删文件、不改写入方：`UmengDiagnosticReporter` 下一次写入会自己重建目录。
     */
    fun clearNative(): Boolean {
        val file = nativeLogFile ?: return false
        return try {
            synchronized(writeLock) {
                if (file.isFile) file.delete()
            }
            true
        } catch (t: Throwable) {
            false
        }
    }

    // ---------- 反射（仅 Android 入口用） ----------

    /**
     * 从 `Context` 反射出一个 `PackageInfo`，拼成 Dart 口径的 `version+buildNumber`。
     * 任何一步失败返回 null（头部就不写 `version=` 行）。**仅供 [initialize] 用。**
     */
    private fun contextVersion(context: Any): String? = runCatching {
        val packageManager = context.javaClass.getMethod("getPackageManager").invoke(context)
            ?: return@runCatching null
        val packageName = context.javaClass.getMethod("getPackageName").invoke(context) as? String
            ?: return@runCatching null
        val info = packageManager.javaClass
            .getMethod("getPackageInfo", String::class.java, Int::class.javaPrimitiveType)
            .invoke(packageManager, packageName, 0)
            ?: return@runCatching null
        val versionName = info.javaClass.getField("versionName").get(info) as? String
        // `versionCode` 在 API 28 起被 `longVersionCode` 取代；两个都试，取到哪个算哪个。
        val versionCode = runCatching {
            info.javaClass.getField("longVersionCode").getLong(info)
        }.recoverCatching {
            info.javaClass.getField("versionCode").getInt(info).toLong()
        }.getOrNull()
        if (versionName.isNullOrEmpty()) {
            null
        } else if (versionCode != null) {
            "$versionName+$versionCode"
        } else {
            versionName
        }
    }.getOrNull()
}
