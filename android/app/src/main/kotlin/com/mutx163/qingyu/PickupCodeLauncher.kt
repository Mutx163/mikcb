package com.mutx163.qingyu

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import android.util.Log

/**
 * 「取件码」页的外部跳转实现：ACTION_VIEW + 可选 setPackage。
 *
 * 口径与 QuickJump（github.com/chuhe0719/QuickJump）一致：这些取件身份码
 * 页面没有公开 API，只能靠各 App 自己的 deeplink。**不用 URL scheme 之外的
 * 任何手段**（不读别的 App 数据、不申请权限、不反射内部 Activity）。
 *
 * 安全边界：
 * - 只接受 `scheme://...`，file/content/javascript/data/intent 等一律拒绝
 *   （用户手滑粘贴的本地文件路径或脚本链接不该被执行）；
 * - 包名必须匹配 `a.b.c` 形状，避免把任意字符串塞进 setPackage；
 * - URI 长度上限 4096，与 Dart 侧同一口径。
 *
 * 返回给 Flutter 的统一是 `{ok: Boolean, reason: String?}`：失败原因码由界面
 * 翻译成人话（`no_activity` / `app_not_found` / `invalid_uri` / ...）。
 *
 * **通道名必须与 Dart 侧 `PickupCodeNativeChannel.channelName`
 * （`lib/services/pickup_code_launcher.dart`）逐字一致。** 两侧不一致时
 * Dart 的每次调用都会抛 MissingPluginException，被 launcher 归成
 * `unsupported`，整页 7 条入口全部提示「当前平台不支持跳到其它应用」——
 * 2026-10-20 改名时只改了 Dart 侧、漏了这里，就是这样坏的。
 * `test/services/pickup_codes_wiring_test.dart` 会钉住这两侧的名字。
 */
object PickupCodeLauncher {
    const val CHANNEL = "com.mutx163.qingyu/pickup_code"

    private const val TAG = "PickupCodeLauncher"
    private const val MAX_URI_LENGTH = 4096

    private val BLOCKED_SCHEMES = setOf(
        "file",
        "content",
        "javascript",
        "data",
        "intent",
        "blob",
        "vbscript",
        "about",
        "chrome",
        "android-app",
    )

    private val SCHEME_PATTERN = Regex("^[a-z][a-z0-9+.\\-]*$")
    private val PACKAGE_PATTERN = Regex("^[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z0-9_]+)+$")

    /** 打开一条 deeplink；[clearTask] 时强制新开目标页（QuickJump 的修复项）。 */
    fun launch(
        activity: Activity,
        rawUri: String?,
        packageName: String?,
        clearTask: Boolean,
    ): Map<String, Any?> {
        val uri = parseUri(rawUri) ?: return failure("invalid_uri")
        if (!packageName.isNullOrBlank() && !PACKAGE_PATTERN.matches(packageName)) {
            return failure("invalid_package")
        }
        val targetPackage = packageName?.trim()?.takeIf { it.isNotEmpty() }
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            if (targetPackage != null) {
                setPackage(targetPackage)
            }
            addFlags(launchFlags(clearTask))
        }
        return try {
            activity.startActivity(intent)
            success()
        } catch (error: ActivityNotFoundException) {
            Log.w(TAG, "launch: no activity for scheme=${uri.scheme} pkg=$targetPackage", error)
            failure("no_activity")
        } catch (error: SecurityException) {
            Log.w(TAG, "launch: security exception for scheme=${uri.scheme}", error)
            failure("no_activity")
        } catch (error: IllegalArgumentException) {
            Log.w(TAG, "launch: malformed intent for scheme=${uri.scheme}", error)
            failure("invalid_uri")
        } catch (error: Exception) {
            Log.e(TAG, "launch: unexpected failure for scheme=${uri.scheme}", error)
            failure("unknown")
        }
    }

    /** 只拉起目标应用主界面：没有公开直达链接时的降级路径。 */
    fun launchApp(
        activity: Activity,
        packageName: String?,
        clearTask: Boolean,
    ): Map<String, Any?> {
        if (packageName.isNullOrBlank() || !PACKAGE_PATTERN.matches(packageName)) {
            return failure("invalid_package")
        }
        val launch = activity.packageManager.getLaunchIntentForPackage(packageName)
            ?: return failure("app_not_found")
        launch.addFlags(launchFlags(clearTask))
        if (clearTask) {
            launch.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK)
        }
        return try {
            activity.startActivity(launch)
            success()
        } catch (error: ActivityNotFoundException) {
            Log.w(TAG, "launchApp: no launcher for $packageName", error)
            failure("app_not_found")
        } catch (error: Exception) {
            Log.e(TAG, "launchApp: failed for $packageName", error)
            failure("unknown")
        }
    }

    /**
     * 这条链接现在有没有 App 能接。
     *
     * Android 11+ 受包可见性限制：调用方必须在 Manifest `<queries>` 里声明
     * 对应 scheme / 包名，否则这里永远返回 false（而不是「真的没人接」）。
     */
    fun canResolve(activity: Activity, rawUri: String?, packageName: String?): Boolean {
        val uri = parseUri(rawUri) ?: return false
        if (!packageName.isNullOrBlank() && !PACKAGE_PATTERN.matches(packageName)) {
            return false
        }
        val intent = Intent(Intent.ACTION_VIEW, uri).apply {
            if (!packageName.isNullOrBlank()) {
                setPackage(packageName)
            }
        }
        return try {
            resolveActivities(activity.packageManager, intent).isNotEmpty()
        } catch (error: Exception) {
            Log.w(TAG, "canResolve failed for scheme=${uri.scheme}", error)
            false
        }
    }

    /**
     * 两参版 `queryIntentActivities` 在 API 33 起被标注 deprecated（换成
     * `ResolveInfoFlags`），新签名在 minSdk 26 上要分支。包一层让调用点保持
     * 单行，`@Suppress` 也集中在一处。
     */
    @Suppress("DEPRECATION")
    private fun resolveActivities(
        packageManager: PackageManager,
        intent: Intent,
    ): List<ResolveInfo> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            packageManager.queryIntentActivities(intent, 0)
        }
    }

    /** 批量查包名是否已安装（同样受 `<queries>` 可见性约束）。 */
    fun installedPackages(activity: Activity, packages: List<String>): Map<String, Boolean> {
        val result = LinkedHashMap<String, Boolean>()
        for (packageName in packages) {
            if (!PACKAGE_PATTERN.matches(packageName)) {
                continue
            }
            result[packageName] = isInstalled(activity, packageName)
        }
        return result
    }

    private fun isInstalled(activity: Activity, packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.packageManager.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(0),
                )
            } else {
                @Suppress("DEPRECATION")
                activity.packageManager.getPackageInfo(packageName, 0)
            }
            true
        } catch (error: PackageManager.NameNotFoundException) {
            false
        } catch (error: Exception) {
            Log.w(TAG, "isInstalled failed for $packageName", error)
            false
        }
    }

    private fun parseUri(raw: String?): Uri? {
        val text = raw?.trim()
        if (text.isNullOrEmpty() || text.length > MAX_URI_LENGTH) {
            return null
        }
        val uri = try {
            Uri.parse(text)
        } catch (error: Exception) {
            return null
        }
        val scheme = uri.scheme?.lowercase()
        if (scheme.isNullOrEmpty() || scheme in BLOCKED_SCHEMES) {
            return null
        }
        if (!SCHEME_PATTERN.matches(scheme)) {
            return null
        }
        return uri
    }

    private fun launchFlags(clearTask: Boolean): Int {
        return if (clearTask) {
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        } else {
            Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
    }

    private fun success(): Map<String, Any?> = mapOf("ok" to true)

    private fun failure(reason: String): Map<String, Any?> =
        mapOf("ok" to false, "reason" to reason)
}
