package com.mutx163.qingyu.pages.about

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.zip.GZIPInputStream

/**
 * 许可证全文在 APK 里的落点（2026-11-02 起换源为主 assets 的**自维护快照**）。
 *
 * 原数据源是 Flutter 工具链打进 `flutter_assets/NOTICES.Z` 的汇总文件——删 Flutter 后
 * 它**永不再生成**，所以把最近一次构建产物的字节原样拷进
 * `android/app/src/main/assets/licenses/NOTICES.gz`（SHA-256 一致，gzip 格式不变）。
 * 格式与解析器（[parseFlutterNotices]）零改动；代价是**新增依赖后要手动刷新快照**，
 * 自动化生成属构建脚本改动，方案见「需 Lead 执行」补丁（暂缺，见迁移说明文档）。
 *
 * ## 2026-11-04 修「开源许可页一直加载失败」——资源名不是 `.gz`
 *
 * AGP / aapt2 打包 assets 时会把 `NOTICES.gz` **自动解压**成纯文本
 * `assets/licenses/NOTICES`（构建产物实测：`build/app/intermediates/assets/<变体>/merge<变体>Assets/licenses/NOTICES`
 * 是 1.49 MB 的明文，`jar tf .../assets/licenses/NOTICES.jar` 里也是 `assets/licenses/NOTICES`）。
 * 所以运行时 `assets.open("licenses/NOTICES.gz")` 必然 `FileNotFoundException`，
 * 宿主 `onFailure` 把它落成「加载失败」。现在按「先明文、后 gz」两路试，并读魔数判断是否还需解压。
 */
private const val noticesAssetPath = "licenses/NOTICES.gz"

private val noticesAssetCandidates = listOf("licenses/NOTICES", noticesAssetPath)

/**
 * 从主 assets 读许可证快照，**兼容两种打包结果**：
 * - 资产被 aapt2 解压后的纯文本 `licenses/NOTICES`（当前实际形态）；
 * - 资产保持 gzip 的 `licenses/NOTICES.gz`（旧构建/其它打包器）。
 *
 * 以文件头魔数 `1f 8b` 判断是否 gzip，不靠扩展名猜。
 */
private fun readNoticesText(context: Context): String {
    var lastError: java.io.IOException? = null
    for (path in noticesAssetCandidates) {
        try {
            val bytes = context.assets.open(path).use { it.readBytes() }
            if (bytes.isEmpty()) continue
            val isGzip = bytes.size >= 2 &&
                bytes[0] == 0x1f.toByte() &&
                bytes[1] == 0x8b.toByte()
            return if (isGzip) {
                GZIPInputStream(bytes.inputStream())
                    .bufferedReader(Charsets.UTF_8)
                    .use { it.readText() }
            } else {
                String(bytes, Charsets.UTF_8)
            }
        } catch (e: java.io.IOException) {
            lastError = e
        }
    }
    throw lastError ?: java.io.FileNotFoundException("licenses/NOTICES missing in assets")
}

/**
 * 读主 assets 里的许可证快照（gzip 或已解压纯文本）→ 解析 → 聚合成可渲染的包许可证列表。
 *
 * 与 Flutter `loadOpenSourcePackageLicenses()` 的结果同源（Flutter 的 `LicenseRegistry` 读的也是这份
 * `NOTICES`）。任何一步失败都抛出，由 [OpenSourceLicensesHost] 落到「加载失败」态，不静默吞。
 */
private fun loadOpenSourcePackageLicenses(context: Context): List<OpenSourcePackageLicense> {
    val text = readNoticesText(context)
    return buildOpenSourcePackageLicenses(parseFlutterNotices(text))
}

/**
 * 开源许可页的**带数据宿主**（2026-10-28 补口）。
 *
 * 壳原先直接 `OpenSourceLicensesPage(packages = emptyList(), onOpenPackage = {})`，
 * 于是列表恒空、点包名也没反应。这里把三件事补齐：
 * 1. 从资产读真实许可证（[loadOpenSourcePackageLicenses]）；
 * 2. 详情页用 [OpenSourceLicenseDetailPage] 在页内推入（返回即回列表）；
 * 3. 加载/失败态交给纯渲染层 [OpenSourceLicensesPage] 画。
 *
 * 渲染层仍保持无数据副作用（它是纯展示），数据与导航只在这个宿主里做——与 ChangelogPage 同思路。
 */
@Composable
fun OpenSourceLicensesHost(onBack: () -> Unit) {
    val context = LocalContext.current
    var packages by remember { mutableStateOf<List<OpenSourcePackageLicense>?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var detail by remember { mutableStateOf<OpenSourcePackageLicense?>(null) }

    LaunchedEffect(Unit) {
        runCatching { withContext(Dispatchers.IO) { loadOpenSourcePackageLicenses(context) } }
            .onSuccess {
                packages = it
                error = null
            }
            .onFailure { error = it.message ?: "" }
    }

    val current = detail
    if (current != null) {
        OpenSourceLicenseDetailPage(pkg = current, onBack = { detail = null })
    } else {
        OpenSourceLicensesPage(
            packages = packages ?: emptyList(),
            onBack = onBack,
            onOpenPackage = { detail = it },
            isLoading = packages == null && error == null,
            loadError = error,
        )
    }
}
