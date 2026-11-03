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
import com.mutx163.qingyu.platform.PrefsKeyValueStore
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
 * | 适配器「录制导入」 | 进 `g2.webLogin` 并自动开录（Dart `autoRecord`，I2-4 已接） |
 * | 「快捷导入」（学校页 / 适配器页） | 读已存宏（多个时先选一条）→ 合成临时学校/适配器 → 进 `g2.webLogin` 自动回放（I2-5） |
 * | 「意见反馈 / 自定义调试」 | 壳的 `onOpenPage`（`k.feedback` / `g2.customDebug`） |
 *
 * ## 诚实边界（重要，别把这段删掉）
 *
 * 1. **登录之后的「抓课表」已接**（F32 + I2）：脚本注入、`courses` 写回、原生对话框、
 *    `saveCourseConfig` 落盘、替换/合并弹窗都已落地（见 `WarehouseWebLoginHost`）。
 * 2. **快捷导入（宏回放）已接**：入口读真宏存档，多条时先弹选择，进登录页后由
 *    [`WarehouseMacroReplayer`] 自动跑完再执行导入脚本。
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

    /** 「录制导入」一录到底：进 `g2.webLogin` 后自动开录（Dart `widget.autoRecord`）。 */
    var autoRecord by mutableStateOf(false)

    /** 「快捷导入」选定的宏：进 `g2.webLogin` 后由回放引擎自动跑完并执行导入脚本。 */
    var quickMacro by mutableStateOf<WarehouseMacroRecord?>(null)

    /** 快捷导入的页标题主体：全局入口用学校名、适配器入口用适配器名（Dart `quickImportTitle`）。 */
    var quickImportTitleName by mutableStateOf<String?>(null)


    /** 宏存档版本号：录制保存成功 +1，列表页据此重拉 macroMap/计数（导航回退不触发 LaunchedEffect 重跑）。 */
    var macrosVersion by mutableStateOf(0)
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
    // 宏引擎的录制侧已移植（I2-4）：列表卡片显示真计数；回放（快捷导入）仍未移植。
    val macroStore = remember(context) { WarehouseMacroStore(PrefsKeyValueStore(context)) }

    var phase by remember { mutableStateOf(WarehouseListPhase.Loading) }
    var schools by remember { mutableStateOf<List<WarehouseSchoolEntry>>(emptyList()) }
    var recentSchoolIds by remember { mutableStateOf<List<String>>(emptyList()) }
    var macroCount by remember { mutableStateOf(0) }
    var reloadToken by remember { mutableStateOf(0) }

    LaunchedEffect(reloadToken, state.macrosVersion) {
        phase = WarehouseListPhase.Loading
        val loaded = withContext(Dispatchers.IO) { service.loadRootIndex() }
        recentSchoolIds = withContext(Dispatchers.IO) { prefs.recentSchoolIds() }
        macroCount = withContext(Dispatchers.IO) {
            runCatching { macroStore.count() }.getOrDefault(0)
        }
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

    // ---- 快捷导入：多条宏先让用户选（Dart `_handleQuickImport`） ----
    var quickImportRecords by remember { mutableStateOf<List<WarehouseMacroRecord>?>(null) }

    /** 全局快捷导入：合成临时学校/适配器 → 进登录页自动回放（Dart `_startQuickImport`）。 */
    fun launchQuickImport(record: WarehouseMacroRecord, titleName: String) {
        val synthesizedSchool = WarehouseSchoolEntry(
            id = record.schoolId,
            name = record.schoolName,
            initial = record.schoolName.firstOrNull()?.toString() ?: "#",
            resourceFolder = record.schoolResourceFolder.ifBlank { record.schoolId },
        )
        val synthesizedAdapter = WarehouseAdapterEntry(
            id = record.adapterId,
            name = record.adapterName,
            script = record.adapterAssetJsPath.ifBlank { "macro/${record.adapterId}.js" },
            category = "macro",
            maintainer = "macro",
            importUrl = record.importUrl,
        )
        if (resolveWarehouseWebLoginTarget(synthesizedAdapter, prefs.customImportUrl(record.adapterId)) == null) {
            // 与 Dart 同一个拦截口径：没有可用登录地址就别进页面。
            Toast.makeText(context, WarehouseStrings.noValidWarehouseLoginUrl.zh, Toast.LENGTH_SHORT).show()
            return
        }
        state.school = synthesizedSchool
        state.adapter = synthesizedAdapter
        state.autoRecord = false
        state.quickMacro = record
        state.quickImportTitleName = titleName
        onOpenPage(WarehouseRoutes.WEB_LOGIN)
    }

    fun pickQuickImport() {
        scope.launch {
            val records = withContext(Dispatchers.IO) {
                runCatching {
                    macroStore.listEntries().mapNotNull { entry ->
                        macroStore.getMacro(entry.schoolId, entry.adapterId)
                    }
                }.getOrDefault(emptyList())
            }
            if (records.isEmpty()) {
                Toast.makeText(context, WarehouseStrings.noSavedQuickImportRecords.zh, Toast.LENGTH_SHORT).show()
                return@launch
            }
            if (records.size == 1) {
                launchQuickImport(records.first(), records.first().schoolName)
            } else {
                quickImportRecords = records
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
        // 宏录制（I2-4）+ 回放（I2-5）都已落地：计数与点击都走真实宏存档。
        hasQuickImportMacro = macroCount > 0,
        quickImportMacroCount = macroCount,
        onRetry = { reloadToken += 1 },
        onSelectSchool = { school ->
            // 普通选校入口必须把快捷导入的残留清掉，否则再次进登录页会被当成回放。
            state.quickMacro = null
            state.quickImportTitleName = null
            state.school = school
            state.autoRecord = false
            onOpenPage(WarehouseRoutes.ADAPTERS)
            scope.launch {
                withContext(Dispatchers.IO) { prefs.recordRecentSchool(school.id) }
                recentSchoolIds = withContext(Dispatchers.IO) { prefs.recentSchoolIds() }
            }
        },
        onQuickImportClick = { pickQuickImport() },
        onFeedbackClick = { onOpenPage(WarehouseRoutes.FEEDBACK) },
        onCustomDebugClick = { onOpenPage(WarehouseRoutes.CUSTOM_DEBUG) },
        onExecutionLogClick = { toastUnavailable(context, "execution log: import pipeline not ported (F08-8c)") },
    )

    // 弹层常驻组合 + show 驱动：选完/取消后靠内部记住的最后一份列表撑完退场动画。
    WarehouseQuickImportPickerDialog(
        show = quickImportRecords != null,
        records = quickImportRecords,
        onResult = { record ->
            quickImportRecords = null
            if (record != null) launchQuickImport(record, record.schoolName)
        },
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
    // 宏录制（I2-4）与回放（I2-5）：哪些适配器存过录制读真值，快捷导入据此取宏。
    val macroStore = remember(context) { WarehouseMacroStore(PrefsKeyValueStore(context)) }
    val scope = rememberCoroutineScope()
    val prefs = remember(context) { WarehouseImportPrefs(PrefsKeyValueStore(context)) }
    var phase by remember(school.id) { mutableStateOf(WarehouseListPhase.Loading) }
    var adapters by remember(school.id) { mutableStateOf<List<WarehouseAdapterEntry>>(emptyList()) }
    var macroMap by remember(school.id) { mutableStateOf<Map<String, Boolean>>(emptyMap()) }
    var reloadToken by remember(school.id) { mutableStateOf(0) }

    LaunchedEffect(school.id, reloadToken, state.macrosVersion) {
        phase = WarehouseListPhase.Loading
        val loaded = withContext(Dispatchers.IO) { service.loadAdaptersIndex(school) }
        when (loaded) {
            is WarehouseLoad.Ok -> {
                adapters = loaded.value.adapters
                macroMap = withContext(Dispatchers.IO) {
                    loaded.value.adapters.associate { entry ->
                        entry.id to runCatching { macroStore.hasMacro(school.id, entry.id) }.getOrDefault(false)
                    }
                }
                phase = WarehouseListPhase.Idle
            }

            is WarehouseLoad.Failed -> {
                adapters = emptyList()
                macroMap = emptyMap()
                phase = WarehouseListPhase.Failed
                Log.w(
                    LOG_TAG,
                    "adapters load failed school=${school.id} code=${loaded.code} attempts=${loaded.attempts}",
                )
            }
        }
    }

    // 适配器页快捷导入：沿用真学校 + 真适配器，只多带一份宏（Dart `_openQuickImport`）。
    fun launchAdapterQuickImport(adapter: WarehouseAdapterEntry) {
        val currentSchool = school
        scope.launch {
            val macro = withContext(Dispatchers.IO) {
                runCatching { macroStore.getMacro(currentSchool.id, adapter.id) }.getOrNull()
            }
            if (macro == null) {
                Toast.makeText(context, WarehouseStrings.noMacroRecordFound.zh, Toast.LENGTH_SHORT).show()
                return@launch
            }
            if (resolveWarehouseWebLoginTarget(adapter, prefs.customImportUrl(adapter.id)) == null) {
                Toast.makeText(context, WarehouseStrings.noValidWarehouseLoginUrl.zh, Toast.LENGTH_SHORT).show()
                return@launch
            }
            state.school = currentSchool
            state.adapter = adapter
            state.autoRecord = false
            state.quickMacro = macro
            state.quickImportTitleName = adapter.adapterName
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        }
    }

    WarehouseSchoolAdaptersPage(
        school = school,
        adapters = adapters,
        // 宏映射：录制侧已移植（I2-4），真值来自 WarehouseMacroStore（与 Dart 同一份存档）。
        macroMap = macroMap,
        phase = phase,
        onBack = onBack,
        onRefresh = { reloadToken += 1 },
        onRetry = { reloadToken += 1 },
        onImportAdapter = { adapter ->
            // 「网页登录导入」= 去登录页（Dart 同名按钮的语义）；普通入口清掉快捷导入残留。
            state.quickMacro = null
            state.quickImportTitleName = null
            state.adapter = adapter
            state.autoRecord = false
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        },
        onViewAdapterDetail = { adapter ->
            state.quickMacro = null
            state.quickImportTitleName = null
            state.adapter = adapter
            onOpenPage(WarehouseRoutes.DETAIL)
        },
        onRecordAdapter = { adapter ->
            // 一录到底（Dart `autoRecord: true`）：进登录页后自动开录。
            state.quickMacro = null
            state.quickImportTitleName = null
            state.adapter = adapter
            state.autoRecord = true
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        },
        onQuickImportAdapter = { adapter -> launchAdapterQuickImport(adapter) },
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
            state.quickMacro = null
            state.quickImportTitleName = null
            state.adapter = adapter
            state.autoRecord = false
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
