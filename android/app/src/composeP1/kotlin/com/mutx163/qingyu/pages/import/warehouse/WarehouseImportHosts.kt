package com.mutx163.qingyu.pages.import.warehouse

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.util.Log
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.pages.settings.SettingsStrings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 教务适配族三个列表页的**真宿主**（F08 8b）。
 *
 * ## 壳里原来是什么（§二 根因）
 *
 * | 路由 | 原挂法 | 用户看到 |
 * |---|---|---|
 * | `g2.warehouseImport` | `WarehouseCourseImportPage(onBack)` | 学校清单恒空 |
 * | `g2.schoolAdapters` | `SHELL_DEMO_SCHOOL` + `adapters = emptyList()` | 「示例学校」+ 空列表 |
 * | `g2.adapterDetail` | `SHELL_DEMO_SCHOOL` / `SHELL_DEMO_ADAPTER` | 两个演示对象 |
 *
 * ## 现在每个交互的落点
 *
 * | 控件 | 真落点 |
 * |---|---|
 * | 学校卡片 | 记住所选学校（[WarehouseShellState]）+ 写「最近使用」（[WarehouseImportPrefs]）+ 进适配器列表 |
 * | 刷新 / 失败重试 | 重新走一遍候选链（[WarehouseRepositoryService]） |
 * | 适配器「网页登录导入」 | 进 `g2.webLogin`，地址取该适配器的 `import_url`（不再是 `example.com` 占位） |
 * | 适配器「查看详情」 | 进 `g2.adapterDetail`（真数据：分类/维护者/描述/脚本路径） |
 * | 详情页「复制登录地址 / 复制脚本地址」 | 系统剪贴板 + Toast（文案取 ARB 原文） |
 * | 详情页自定义登录地址 | [WarehouseImportPrefs] 落盘（键名与 Dart 逐字一致），重进这一页看得见 |
 * | 详情页「网页登录」 | 进 `g2.webLogin`（同上，真地址） |
 * | 「录制导入 / 快捷导入」 | **给一句实话**：宏引擎（`warehouse_macro_service`）还没移植 |
 * | 「意见反馈 / 自定义调试」 | 壳的 `onOpenPage`（`k.feedback` / `g2.customDebug`） |
 *
 * ## 诚实边界（重要，别把这段删掉）
 *
 * 1. **登录之后的「抓课表」没有接**：Dart 侧靠 WebView 里注入适配脚本（`asset_js_path`）跑出课表，
 *    再走导入确认；Kotlin 侧脚本引擎没移植（属 8c）。所以「网页登录导入」现在能到**登录页**、
 *    地址是真的，但登录完**不会**自己抓课表。这一点写在 F08 认领文件的诚实清单里。
 * 2. **宏录制 / 快捷导入**给的是「不可用」提示，不是空回调；等宏引擎移植后再接。
 * 3. **没有缓存**：每次进页面都真拉一次（Dart 会落 SharedPreferences 并标缓存时间），
 *    断网时看到的是失败态 + 重试，而不是上次的旧名单冒充新数据。
 * 4. 真机没对照：本刀只证明「编译通过 + JVM 单测通过」。仓库文件能不能拉到、学校名对不对，
 *    要用户真机验收。
 */

private const val LOG_TAG = "WarehouseHost"

/** 壳里的路由 id（与 `ShellPageCatalog` 的 `page("P3-G2", …)` 一一对应）。 */
internal object WarehouseRoutes {
    const val IMPORT_PICKER = "g2.warehouseImport"
    const val ADAPTERS = "g2.schoolAdapters"
    const val DETAIL = "g2.adapterDetail"
    const val WEB_LOGIN = "g2.webLogin"
    const val CUSTOM_DEBUG = "g2.customDebug"
    const val FEEDBACK = "k.feedback"
}

/**
 * 三个仓库页之间的暂存：壳里 `remember { WarehouseShellState() }`，挂在 `when (pageId)` 之上。
 *
 * 与 `ImportShellBridge` 同一个做法（壳的导航只有 `onOpenPage(pageId)`，**不带参数**）：
 * 选中哪所学校、哪个适配器放在这里，下一页从这取。切页不丢，退出壳就丢——与 Dart 的
 * 「页面间传对象」体验一致，也不落盘（这两项本来就不该进存档）。
 */
class WarehouseShellState {
    var school by mutableStateOf<WarehouseSchoolEntry?>(null)
    var adapter by mutableStateOf<WarehouseAdapterEntry?>(null)
}

/** `g2.warehouseImport`：学校选择页（数据源 = `index/root_index.yaml`）。 */
@Composable
fun WarehouseImportPickerHost(
    state: WarehouseShellState,
    prefs: WarehouseImportPrefs,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    fetch: WarehouseFetch = remember { WarehouseJdkFetch() },
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val service = remember(fetch) { WarehouseRepositoryService(fetch) }

    var phase by remember { mutableStateOf(WarehouseListPhase.Loading) }
    var schools by remember { mutableStateOf<List<WarehouseSchoolEntry>>(emptyList()) }
    var recentSchoolIds by remember { mutableStateOf<List<String>>(emptyList()) }
    var reloadToken by remember { mutableStateOf(0) }

    LaunchedEffect(reloadToken) {
        phase = WarehouseListPhase.Loading
        val loaded = withContext(Dispatchers.IO) { service.loadRootIndex() }
        recentSchoolIds = withContext(Dispatchers.IO) { prefs.recentSchoolIds() }
        when (loaded) {
            is WarehouseLoad.Ok -> {
                schools = loaded.value.schools
                phase = WarehouseListPhase.Idle
            }

            is WarehouseLoad.Failed -> {
                schools = emptyList()
                phase = WarehouseListPhase.Failed
                // 日志用英文：composeP1 有中文字面量棘轮门禁（CjkLiteralGateTest），代码里的字符串不许硬写中文。
                Log.w(LOG_TAG, "root_index load failed code=${loaded.code} attempts=${loaded.attempts}")
            }
        }
    }

    WarehouseCourseImportPage(
        allSchools = schools,
        recentSchoolIds = recentSchoolIds,
        // 适配器名搜索索引（`index/search_index.yaml`）这一刀没移植：搜索框仍按学校名/首字母/
        // 代码匹配，按适配器名搜不到。属 8c 的补口，别当成已经能搜。
        adapterMatches = emptyMap(),
        phase = phase,
        onBack = onBack,
        // 宏（快捷导入）引擎未移植 ⇒ 卡片不显示，数量恒 0，不是「测出来没有」。
        hasQuickImportMacro = false,
        quickImportMacroCount = 0,
        onRetry = { reloadToken += 1 },
        onSelectSchool = { school ->
            state.school = school
            onOpenPage(WarehouseRoutes.ADAPTERS)
            scope.launch {
                withContext(Dispatchers.IO) { prefs.recordRecentSchool(school.id) }
                recentSchoolIds = withContext(Dispatchers.IO) { prefs.recentSchoolIds() }
            }
        },
        onQuickImportClick = { toastUnavailable(context, "quick import: macro engine not ported (F08-8c)") },
        onFeedbackClick = { onOpenPage(WarehouseRoutes.FEEDBACK) },
        onCustomDebugClick = { onOpenPage(WarehouseRoutes.CUSTOM_DEBUG) },
        onExecutionLogClick = { toastUnavailable(context, "execution log: import pipeline not ported (F08-8c)") },
    )
}

/** `g2.schoolAdapters`：某所学校的适配器列表（数据源 = `resources/<学校>/adapters.yaml`）。 */
@Composable
fun WarehouseSchoolAdaptersHost(
    state: WarehouseShellState,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
    fetch: WarehouseFetch = remember { WarehouseJdkFetch() },
) {
    val context = LocalContext.current
    val school = state.school
    if (school == null) {
        // 直接进这一页（壳的页面清单里点进来）时没有选中学校：退回选择页，而不是拿演示学校凑合。
        LaunchedEffect(Unit) { onOpenPage(WarehouseRoutes.IMPORT_PICKER) }
        return
    }

    val service = remember(fetch) { WarehouseRepositoryService(fetch) }
    var phase by remember(school.id) { mutableStateOf(WarehouseListPhase.Loading) }
    var adapters by remember(school.id) { mutableStateOf<List<WarehouseAdapterEntry>>(emptyList()) }
    var reloadToken by remember(school.id) { mutableStateOf(0) }

    LaunchedEffect(school.id, reloadToken) {
        phase = WarehouseListPhase.Loading
        val loaded = withContext(Dispatchers.IO) { service.loadAdaptersIndex(school) }
        when (loaded) {
            is WarehouseLoad.Ok -> {
                adapters = loaded.value.adapters
                phase = WarehouseListPhase.Idle
            }

            is WarehouseLoad.Failed -> {
                adapters = emptyList()
                phase = WarehouseListPhase.Failed
                Log.w(
                    LOG_TAG,
                    "adapters load failed school=${school.id} code=${loaded.code} attempts=${loaded.attempts}",
                )
            }
        }
    }

    WarehouseSchoolAdaptersPage(
        school = school,
        adapters = adapters,
        // 宏映射（哪些适配器存过录制）依赖宏服务，未移植 ⇒ 一律没有「快捷导入」入口。
        macroMap = emptyMap(),
        phase = phase,
        onBack = onBack,
        onRefresh = { reloadToken += 1 },
        onRetry = { reloadToken += 1 },
        onImportAdapter = { adapter ->
            // 「网页登录导入」= 去登录页（Dart 同名按钮的语义）。地址是真的（`import_url`）；
            // 登录之后的脚本抓课表未接，见本文件 KDoc 诚实边界第 1 条。
            state.adapter = adapter
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        },
        onViewAdapterDetail = { adapter ->
            state.adapter = adapter
            onOpenPage(WarehouseRoutes.DETAIL)
        },
        onRecordAdapter = { toastUnavailable(context, "macro recording: engine not ported (F08-8c)") },
        onQuickImportAdapter = { toastUnavailable(context, "quick import: macro engine not ported (F08-8c)") },
    )
}

/** `g2.adapterDetail`：适配器详情（真数据 + 真剪贴板 + 自定义地址落盘）。 */
@Composable
fun WarehouseAdapterDetailHost(
    state: WarehouseShellState,
    prefs: WarehouseImportPrefs,
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val context = LocalContext.current
    val school = state.school
    val adapter = state.adapter
    if (school == null || adapter == null) {
        LaunchedEffect(Unit) { onOpenPage(WarehouseRoutes.IMPORT_PICKER) }
        return
    }

    var customImportUrl by remember(adapter.id) { mutableStateOf(prefs.customImportUrl(adapter.id)) }

    WarehouseAdapterDetailPage(
        school = school,
        adapter = adapter,
        customImportUrl = customImportUrl,
        onBack = onBack,
        onSaveCustomUrl = { url ->
            prefs.putCustomImportUrl(adapter.id, url)
            // 落盘后立刻读回：页面的 `remember(customImportUrl)` 靠这个值刷新「已自定义」状态。
            customImportUrl = prefs.customImportUrl(adapter.id)
        },
        onClearCustomUrl = {
            prefs.clearCustomImportUrl(adapter.id)
            customImportUrl = null
        },
        onCopyLoginUrl = {
            val text = customImportUrl ?: adapter.importUrl
            if (text.isBlank()) {
                // 仓库条目本身没有 import_url 时不许「复制成功」骗用户。
                Toast.makeText(context, SettingsStrings.aboutUnavailable.zh, Toast.LENGTH_SHORT).show()
            } else {
                copyTextToClipboard(context, "warehouse-login-url", text)
                Toast.makeText(context, WarehouseStrings.copiedImportLoginUrl.zh, Toast.LENGTH_SHORT).show()
            }
        },
        onCopyScriptUrl = {
            if (adapter.script.isBlank()) {
                Toast.makeText(context, SettingsStrings.aboutUnavailable.zh, Toast.LENGTH_SHORT).show()
            } else {
                val rawUrl = WarehouseRepositoryUrls.rawGitHubUrl(
                    WarehouseRepositorySource.DEFAULT,
                    adapter.script,
                )
                copyTextToClipboard(context, "warehouse-script-url", rawUrl)
                Toast.makeText(context, WarehouseStrings.copiedScriptRawUrl.zh, Toast.LENGTH_SHORT).show()
            }
        },
        onOpenWebLogin = {
            state.adapter = adapter
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        },
    )
}

/**
 * 「这个能力还没到位」的统一说法。
 *
 * 为什么用 `SettingsStrings.aboutUnavailable`（"不可用"）而不是新加一条 ARB：
 * 新键在 Dart 侧没人用 ⇒ 会被死键扫描记成新增死键（为了一个提示去动六份 ARB + 重新 gen-l10n，
 * 还要过死键基线，代价与收益不成比例）。**先例**：`SettingsHost` 对未移植的弹层
 * 就是这么说的（"点下去给一句实话"）。真实原因进 `Log.w`，不往用户脸上堆行话。
 */
internal fun toastUnavailable(context: Context, reason: String) {
    Log.w(LOG_TAG, reason)
    Toast.makeText(context, SettingsStrings.aboutUnavailable.zh, Toast.LENGTH_SHORT).show()
}

internal fun copyTextToClipboard(context: Context, label: String, text: String) {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
    clipboard.setPrimaryClip(ClipData.newPlainText(label, text))
}
