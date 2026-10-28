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

/** `NOTICES` 在 APK 里的落点（Flutter 把 LICENSE 汇总压成 gzip；已用构建产物核对）。 */
private const val noticesAssetPath = "flutter_assets/NOTICES.Z"

/**
 * 读 APK 里的 `NOTICES.Z`（gzip）→ 解压 → 解析 → 聚合成可渲染的包许可证列表。
 *
 * 与 Flutter `loadOpenSourcePackageLicenses()` 的结果同源（Flutter 的 `LicenseRegistry` 读的也是这份
 * `NOTICES`）。任何一步失败都抛出，由 [OpenSourceLicensesHost] 落到「加载失败」态，不静默吞。
 */
private fun loadOpenSourcePackageLicenses(context: Context): List<OpenSourcePackageLicense> {
    val text = context.assets.open(noticesAssetPath).use { stream ->
        GZIPInputStream(stream).bufferedReader(Charsets.UTF_8).use { it.readText() }
    }
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
