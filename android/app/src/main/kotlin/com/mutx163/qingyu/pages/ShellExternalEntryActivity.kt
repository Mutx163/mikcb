package com.mutx163.qingyu.pages

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import androidx.activity.ComponentActivity
import com.mutx163.qingyu.pages.shell.ShellExternalEntry
import com.mutx163.qingyu.platform.AndroidImportDocumentReader

/**
 * 外部入口跳板（R1 切壳补口，2026-11-02）：透明、一次性的轻量 Activity，
 * 接住原本挂在 `.MainActivity` 上的三条外部入口，解析后转交 Compose 壳
 * [PagesShellActivity]——**全程不碰 Flutter**。删掉 Flutter 后本类就是
 * 这三条路径的唯一落点。
 *
 * | 入口 | 判定 | 落点 |
 * |---|---|---|
 * | `VIEW` / `SEND` 文件导入 | [ShellExternalEntry.isExternalImportAction] | 后台限长读 → payload 进 [ShellExternalEntryHub] → 壳推到对应导入页（自动进预览） |
 * | `mikcb-debug://` 深链 | scheme + 包名后缀门控（`*.debug` / `*.profile`） | path 规范化 → `ShellWiring.shellPageIdForRoute` → 壳推页；映射不到落首页 |
 * | `um.<key>://` 友盟 scheme | 其余 filter 命中的都归这类 | 只把壳带到前台（友盟推送点击的目标就是「打开 App」） |
 *
 * 判定逻辑全部在纯 Kotlin 的 [ShellExternalEntry]（pages/shell 域，L0 单测钉住）；
 * 本文件只做 Android 胶水（intent 拆装、跨进程读文件、任务栈修复）。
 *
 * ## 为什么是「跳板」而不是把 filter 直接挂壳上
 *
 * 壳是 Lead 专属写作用域；跳板把「读文件（跨进程 IO、可能秒级）」与
 * 「解析深链」都留在自己生命周期里，壳只消费一份现成的 hub 状态（一行钩子）。
 * 透明主题 + `noHistory` + `excludeFromRecents`，用户感知不到这一跳。
 */
class ShellExternalEntryActivity : ComponentActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 修「外部打开把我们拽进调用方的任务」（MainActivity :188-218 同一修法）：
        // 文件管理器 / QQ 的 VIEW intent 常不带 FLAG_ACTIVITY_NEW_TASK，跳板会起在
        // 对方任务里，最近任务里显示成对方的label。先转投自己任务再处理。
        // super.onCreate 必须在每条路径都跑（SuperNotCalledException），与
        // MainActivity 的修法一致：先 super、再 redirect、finish。
        val entry = intent
        if (!isTaskRoot && entry != null &&
            (entry.action == Intent.ACTION_SEND ||
                entry.action == Intent.ACTION_SEND_MULTIPLE ||
                entry.action == Intent.ACTION_VIEW)
        ) {
            val relaunch = Intent(this, ShellExternalEntryActivity::class.java).apply {
                action = entry.action
                type = entry.type
                entry.clipData?.let { clipData = it }
                putExtras(entry)
                entry.data?.let { data = it }
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP,
                )
            }
            startActivity(relaunch)
            finish()
            return
        }

        handleExternalEntry(entry)
    }

    private fun handleExternalEntry(entry: Intent?) {
        val action = entry?.action
        val data = entry?.data
        val dataScheme = data?.scheme

        // 1. 调试自动化深链：scheme 命中且包名是 *.debug / *.profile 才解析。
        //    显式组件名调起（tool/qa.ps1 的 am start -n）不走 filter，但同样会
        //    进到这里拿到 scheme，行为与隐式调起一致。
        if (action == Intent.ACTION_VIEW &&
            dataScheme == ShellExternalEntry.DEBUG_SCHEME &&
            ShellExternalEntry.isDebugAutomationPackageId(packageName)
        ) {
            val path = ShellExternalEntry.normalizeDebugDeepLinkPath(data?.host, data?.path)
            // query 缺口：壳的导航只认页面 id（见 ShellExternalEntryEffect 说明）。
            val pageId = ShellExternalEntry.debugRoutePageId(path, ::shellPageIdForRoute)
            if (pageId != null) {
                ShellExternalEntryHub.post(pageId, payload = null)
            }
            launchShellAndFinish()
            return
        }

        // 2. 外部文件导入：先把壳拉起来（不等跨进程 IO），读完再 post 落点。
        //    慢 provider（网盘）不会卡住壳的启动；payload 就绪后壳自动推导入页。
        if (ShellExternalEntry.isExternalImportAction(action, dataScheme)) {
            val uri = resolveImportUri(entry)
            if (uri != null && uri.scheme != ShellExternalEntry.DEBUG_SCHEME) {
                readImportInBackground(entry?.type, uri)
                finish()
                return
            }
        }

        // 3. 其余 filter 命中的入口（umeng scheme 等）：目标就是「打开 App」。
        launchShellAndFinish()
    }

    /** [MainActivity.resolveImportUri] 同口径：SEND 取 EXTRA_STREAM，VIEW 取 data。 */
    private fun resolveImportUri(entry: Intent?): Uri? {
        if (entry == null) return null
        return when (entry.action) {
            Intent.ACTION_SEND -> if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                entry.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                entry.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            else -> entry.data
        }
    }

    /**
     * 后台限长读 + 组 payload（`MainActivity.loadExternalImportFromUri` 的壳侧等价物）。
     * 文本类校验（VCALENDAR / "mikcb"）与 kind 识别在 [ShellExternalEntry]（有单测）；
     * 表格不再落盘缓存——壳的表格导入页直接吃字节。
     */
    private fun readImportInBackground(sharedType: String?, uri: Uri) {
        val appContext = applicationContext
        Thread {
            val payload = try {
                readPayload(appContext, sharedType, uri)
            } catch (e: Exception) {
                Log.w(TAG, "read external import failed: $uri", e)
                null
            }
            mainHandler.post {
                if (payload != null) {
                    ShellExternalEntryHub.post(ShellExternalEntry.importTargetPage(payload), payload)
                }
                launchShellAndFinish()
            }
        }.start()
    }

    private fun readPayload(
        context: android.content.Context,
        sharedType: String?,
        uri: Uri,
    ): ShellExternalEntry.ImportPayload? {
        val reader = AndroidImportDocumentReader(context)
        // 先用 provider 自报尺寸短路「文件过大」（读流之前），与 MainActivity 同口径：
        // 声明会撒谎，真正兜底是 readCapped 的流式计数，两者任一命中都算超限。
        val declared = try {
            context.contentResolver
                .query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                ?.use { cursor -> if (cursor.moveToFirst()) cursor.getLong(0) else null }
        } catch (_: Exception) {
            null
        }
        if (declared != null && ShellExternalEntry.declaredSizeExceedsCap(declared)) {
            return ShellExternalEntry.ImportPayload.TooLarge(
                fileName = reader.displayName(uri) ?: "import",
                maxBytes = ShellExternalEntry.MAX_IMPORT_BYTES,
            )
        }
        val read = reader.read(uri, ShellExternalEntry.MAX_IMPORT_BYTES)
        return when (read) {
            is AndroidImportDocumentReader.Result.TooLarge ->
                // TooLarge 不带名字（data object）：自己再查一次 DISPLAY_NAME。
                ShellExternalEntry.ImportPayload.TooLarge(
                    fileName = reader.displayName(uri) ?: "import",
                    maxBytes = ShellExternalEntry.MAX_IMPORT_BYTES,
                )
            is AndroidImportDocumentReader.Result.ReadFailed -> null
            is AndroidImportDocumentReader.Result.Bytes -> {
                val mimeType = sharedType?.takeIf { it.isNotBlank() }
                    ?: context.contentResolver.getType(uri)
                val fileName = read.fileName ?: uri.lastPathSegment?.substringAfterLast('/') ?: "import"
                val kind = ShellExternalEntry.detectImportKind(fileName, mimeType, read.bytes)
                    ?: return null
                ShellExternalEntry.buildImportPayload(kind, fileName, read.bytes)
            }
        }
    }

    /** 把壳带到前台（已在前台时被 CLEAR_TOP + SINGLE_TOP 复用，不重建）。 */
    private fun launchShellAndFinish() {
        val shell = Intent(this, PagesShellActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }
        runCatching { startActivity(shell) }
        finish()
    }

    private companion object {
        const val TAG = "ShellExternalEntry"
    }
}
