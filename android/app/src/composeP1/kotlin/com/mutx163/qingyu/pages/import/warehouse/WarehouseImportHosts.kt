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
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.infra.AppUpdateDownloadChannel
import com.mutx163.qingyu.infra.AppUpdateDownloadSource
import com.mutx163.qingyu.pages.about.AppUpdateSettings
import com.mutx163.qingyu.pages.about.resolveMirrorUrlPrefix
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
 * | 「录制导入」 | **P1 起可用**：进 `g2.webLogin` 并自动开始录制，成功后询问保存 |
 * | 「快捷导入」 | 仍是实话（P2 回放引擎未接），但保存过宏的适配器与没有的显示一致（D7：不亮假入口） |
 * | 「意见反馈 / 自定义调试」 | 壳的 `onOpenPage`（`k.feedback` / `g2.customDebug`） |
 *
 * ## 诚实边界（重要，别把这段删掉）
 *
 * 1. **登录之后的「抓课表」没有接**：Dart 侧靠 WebView 里注入适配脚本（`asset_js_path`）跑出课表，
 *    再走导入确认；Kotlin 侧脚本引擎没移植（属 8c）。所以「网页登录导入」现在能到**登录页**、
 *    地址是真的，但登录完**不会**自己抓课表。这一点写在 F08 认领文件的诚实清单里。
 * 2. **宏录制**已接（P1：录制/保存/键名与 Dart 同键共读）；**快捷导入（回放）**未接（P2），
 *    保存过的宏在本期只落盘不回放。
 * 3. **缓存（2026-11-05 接上）**：索引落到 [WarehouseRepositoryCache]（原文 + 拉取时刻，TTL 6h）。
 *    进页面先出本地记录（最近使用 / 已存宏）→ 再出缓存名单 → 新鲜就不打网、过期则后台刷新。
 *    刷新失败时**保留缓存列表**并把原因写进 [WarehouseShellState.lastLoadIssue]，不把用户
 *    已经能看见的名单换成一张失败页。Dart 侧没有这一层，是本侧补强。
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
 * 三个仓库页之间的**页内**暂存（学校 / 适配器 / 待录制·待回放意图）。
 *
 * ⚠️ 它**不会自动跨页**：壳里是 `remember { WarehouseShellState() }`，而 `ShellPageContent`
 * 是**每个路由条目各组合一次**（miuix-nav 的条目彼此是独立组合作用域），所以推新页
 * 拿到的是全新实例。跨页要用的目标必须经 [WarehouseImportHandoff] 交接——
 * 2026-11-03 真机实报「点网页导入被打回学校列表」就是漏了这一步（详见该对象的注释）。
 *
 * 与 `ImportShellBridge` 同一个做法：壳的导航只有 `onOpenPage(pageId)`、**不带参数**，
 * 选中的对象不落盘（这两项本来就不该进存档）。
 */
class WarehouseShellState {
    var school by mutableStateOf<WarehouseSchoolEntry?>(null)
    var adapter by mutableStateOf<WarehouseAdapterEntry?>(null)

    /**
     * 进网页登录页时是否自动开始录制（Dart `_openAdapterImport` 的 `autoRecord` 参数）：
     * 「录制导入」按钮恒 true；普通导入按 [shouldAutoRecordWarehouseImport]
     * （无已存宏才自动录）。由列表宿主在导航前写好，登录页 `LaunchedEffect` 读一次。
     */
    var autoRecordMacro by mutableStateOf(false)

    /**
     * 快捷导入入口（P2）带来的待回放宏：列表页/课程导入页读出记录放这里，
     * 登录页 `LaunchedEffect` 消费一次即清（与 [autoRecordMacro] 同款跨页暂存）。
     */
    var playbackMacro by mutableStateOf<WarehouseMacroRecord?>(null)

    /**
     * 最近一次拉取的失败原因（四档，[WarehouseLoadIssue]）。
     *
     * 为什么放在跨页状态里而不是各页私有：两个列表页都会写它，而「失败原因出人话」的渲染
     * 在页面层——同一个页面实例可能先拿到缓存（成功）再拿到刷新失败，页面要能读到**最近一次**
     * 的结论，不必自己再解析 `WarehouseFeedCodes` 的串。
     * 成功时清成 `null`（页面据此收起失败提示）。
     */
    var lastLoadIssue by mutableStateOf<WarehouseLoadIssue?>(null)
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
    // 拉取偏好（更新下载渠道 → GitCode / 镜像前缀）。按设置的「渠道」选源，
    // 以前这里写死 GitHub raw 主地址，设置里切 GitCode 对适配仓毫无作用（见 WarehouseFetchOptions）。
    val fetchOptions = remember(context) {
        readWarehouseFetchOptions(PrefsKeyValueStore(context))
    }
    val service = remember(fetch, fetchOptions) {
        WarehouseRepositoryService(fetch, options = fetchOptions)
    }
    // 索引落盘缓存：与宏记录同一份 prefs。弱网/镜像半死时先用上次的名单秒开。
    val cache = remember(context) { WarehouseRepositoryCache(PrefsKeyValueStore(context)) }
    // 宏持久化（P2）：课程导入页的快捷导入入口要列「全部已存宏」（跨学校）。
    val macroStore = remember(context) { WarehouseMacroStore(PrefsKeyValueStore(context)) }

    var phase by remember { mutableStateOf(WarehouseListPhase.Loading) }
    var schools by remember { mutableStateOf<List<WarehouseSchoolEntry>>(emptyList()) }
    var recentSchoolIds by remember { mutableStateOf<List<String>>(emptyList()) }
    var reloadToken by remember { mutableStateOf(0) }
    // 已存宏的完整记录（条目 + 步骤数，选择器要用）；空 = 入口不亮（不是「测出来没有」）。
    var macroRecords by remember { mutableStateOf<List<WarehouseMacroRecord>>(emptyList()) }
    var showMacroPicker by remember { mutableStateOf(false) }

    LaunchedEffect(reloadToken) {
        // ① 本地记录先出：最近使用 + 已存宏都在盘上（读 prefs，几十毫秒），
        //    不等网络也不等缓存 —— 弱网首帧就已有 ★ 分组与快捷导入入口。
        val local = withContext(Dispatchers.IO) {
            WarehousePickerLocalRecords(
                recentSchoolIds = prefs.recentSchoolIds(),
                macroRecords = macroStore.getAllMacroEntries()
                    .mapNotNull { macroStore.getMacro(it.schoolId, it.adapterId) },
                cachedRootIndex = cache.readRootIndex(),
            )
        }
        recentSchoolIds = local.recentSchoolIds.also { ids ->
            // 显式记录：盘上的最近列表带重复（云恢复原样直写的历史数据）时，
            // 渲染层会按首次出现去重（schoolsToBeans）——这里留一条日志方便对账。
            if (ids.size != ids.distinct().size) {
                Log.w(LOG_TAG, "recent school ids contain duplicates; render dedupes by first occurrence")
            }
        }
        macroRecords = local.macroRecords

        // ② 缓存优先：有缓存就先渲染，stale 也先用（过期只代表「该刷新了」，不代表不能用）。
        val cached = local.cachedRootIndex
        if (cached != null) {
            schools = cached.value.schools
            phase = WarehouseListPhase.Idle
            state.lastLoadIssue = null
        } else {
            phase = WarehouseListPhase.Loading
        }

        // ③ 新鲜缓存直接收工：6h 内同一份名单，没必要再打网（省掉整条候选链）。
        if (cached != null && cache.isFresh(cached)) {
            Log.d(LOG_TAG, "root_index fresh cache hit fetchedAt=${cached.fetchedAtMillis}")
            return@LaunchedEffect
        }

        // ④ 打网（无缓存 = 首载，有缓存 = 后台刷新）；成功就把原文写回缓存。
        val loaded = withContext(Dispatchers.IO) {
            service.loadRootIndex().also { result ->
                if (result is WarehouseLoad.Ok) {
                    result.raw?.let { cache.writeRootIndex(it) }
                }
            }
        }
        when (loaded) {
            is WarehouseLoad.Ok -> {
                schools = loaded.value.schools
                phase = WarehouseListPhase.Idle
                state.lastLoadIssue = null
            }

            is WarehouseLoad.Failed -> {
                val issue = warehouseLoadIssueOf(loaded)
                state.lastLoadIssue = issue
                // 有缓存：**保留列表**（phase 已是 Idle），只在日志与 lastLoadIssue 里交代原因；
                // 没缓存才退到失败页（此时页面上本来就没内容可留）。
                if (cached == null) {
                    schools = emptyList()
                    phase = WarehouseListPhase.Failed
                }
                // 日志用英文：composeP1 有中文字面量棘轮门禁（CjkLiteralGateTest），代码里的字符串不许硬写中文。
                Log.w(
                    LOG_TAG,
                    "root_index load failed code=${loaded.code} attempts=${loaded.attempts} issue=$issue cached=${cached != null}",
                )
            }
        }
    }

    /** 把选中的宏接到跨页暂存并进登录页回放（学校/适配器对象由宏记录构造最小真数据）。 */
    fun startQuickImport(record: WarehouseMacroRecord) {
        val school = WarehouseSchoolEntry(
            id = record.schoolId,
            name = record.schoolName,
            resourceFolder = record.schoolResourceFolder,
        )
        val adapter = WarehouseAdapterEntry(
            id = record.adapterId,
            name = record.adapterName,
            script = record.adapterAssetJsPath,
            importUrl = record.importUrl,
        )
        state.school = school
        state.adapter = adapter
        state.autoRecordMacro = false
        state.playbackMacro = record
        // 跨页唯一通路：壳给每个路由条目独立的 WarehouseShellState（见 WarehouseImportHandoff）。
        WarehouseImportHandoff.publish(school, adapter, playbackMacro = record)
        onOpenPage(WarehouseRoutes.WEB_LOGIN)
    }

    WarehouseCourseImportPage(
        allSchools = schools,
        recentSchoolIds = recentSchoolIds,
        // 适配器名搜索索引（`index/search_index.yaml`）这一刀没移植：搜索框仍按学校名/首字母/
        // 代码匹配，按适配器名搜不到。属 8c 的补口，别当成已经能搜。
        adapterMatches = emptyMap(),
        phase = phase,
        onBack = onBack,
        // P2 起有真值：存过宏才亮快捷导入入口，数量 = 已存宏数。
        hasQuickImportMacro = macroRecords.isNotEmpty(),
        quickImportMacroCount = macroRecords.size,
        onRetry = { reloadToken += 1 },
        onSelectSchool = { school ->
            state.school = school
            // 跨条目必须带过去：壳给**每个路由条目独立**的 WarehouseShellState，只写本条目的话
            // 新条目读到的 school 是 null → 又渲染一遍选校页（用户得把同一所学校点两遍，
            // 「最近使用」还记两次）。这一跳 2026-11-03 修前两跳时漏了。
            WarehouseImportHandoff.publish(school)
            onOpenPage(WarehouseRoutes.ADAPTERS)
            scope.launch {
                withContext(Dispatchers.IO) { prefs.recordRecentSchool(school.id) }
                recentSchoolIds = withContext(Dispatchers.IO) { prefs.recentSchoolIds() }
            }
        },
        // 单宏直接跑；多宏弹选择器（Dart 课程导入页宏选择器同口径）。
        onQuickImportClick = {
            when {
                macroRecords.isEmpty() ->
                    toastUnavailable(context, "quick import: no saved macro records")

                macroRecords.size == 1 -> startQuickImport(macroRecords.first())
                else -> showMacroPicker = true
            }
        },
        onFeedbackClick = { onOpenPage(WarehouseRoutes.FEEDBACK) },
        onCustomDebugClick = { onOpenPage(WarehouseRoutes.CUSTOM_DEBUG) },
        // 「执行日志」入口不接（2026-11-05 死控件收口）：WarehouseCourseImportPage 的
        // onExecutionLogClick 参数在页面正文里**没有任何 UI 消费**（无按钮/菜单项渲染），
        // 之前这里传的 toastUnavailable lambda 是永远走不到的死代码。导入执行日志
        // 的生产端（WarehouseImportSessionLog，F08-8c）未移植，等移植时再把页面里的
        // 入口 UI 画出来、这里接真路由（诊断页 LogViewerEntryModel 的
        // AppLogSource.WAREHOUSE_IMPORT 配置已就位，接的就是它）。
    )

    WarehouseQuickImportPickerDialog(
        show = showMacroPicker,
        records = macroRecords,
        onPick = { record ->
            showMacroPicker = false
            startQuickImport(record)
        },
        onDismiss = { showMacroPicker = false },
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
    val scope = rememberCoroutineScope()
    // 从选校页推进来时，学校经交接件带过来（壳给每个路由条目独立的 WarehouseShellState，
    // 见 WarehouseImportHandoff）；同一组合实例内（选校页 → 本页）则直接读 state。
    val handoff = remember { WarehouseImportHandoff.take() }
    val school = state.school ?: handoff?.school
    if (school == null) {
        // 直接从页面清单 / 全功能页进来时没有选中学校：给诚实空态 + 返回键，
        // **不再跳回选校页**——那会让人以为「点了没反应、被弹回去」。
        LaunchedEffect(Unit) { Log.w(LOG_TAG, "schoolAdapters opened without school") }
        WarehouseNoTargetPage(WarehouseStrings.importMethodWarehouseTitle.zh, onBack)
        return
    }
    LaunchedEffect(Unit) { if (state.school == null) state.school = school }

    val fetchOptions = remember(context) {
        readWarehouseFetchOptions(PrefsKeyValueStore(context))
    }
    val service = remember(fetch, fetchOptions) {
        WarehouseRepositoryService(fetch, options = fetchOptions)
    }
    // 适配器清单缓存（按学校分桶，互不覆盖）：同一所学校第二次进来秒开。
    val cache = remember(context) { WarehouseRepositoryCache(PrefsKeyValueStore(context)) }
    // 宏持久化（P1）：与网页登录宿主同一套键（Dart SharedPreferences 同键共读），
    // 实例各建各的，物理上是同一份文件。
    val macroStore = remember(school.id) { WarehouseMacroStore(PrefsKeyValueStore(context)) }
    var phase by remember(school.id) { mutableStateOf(WarehouseListPhase.Loading) }
    var adapters by remember(school.id) { mutableStateOf<List<WarehouseAdapterEntry>>(emptyList()) }
    // 哪些适配器存过录制（驱动卡片上的「快捷导入」按钮显隐，D7：P1/P2 间隙用空表天然隐藏）。
    var macroMap by remember(school.id) { mutableStateOf<Map<String, Boolean>>(emptyMap()) }
    // 最近一次失败的形状（码 + 试了几个候选 + 四档分类），透传给页面的失败卡。
    // 成功 / 命中缓存时清空；**有缓存时不清列表**，但仍把原因带给页面（可通过 lastLoadIssue 出提示）。
    var failure by remember(school.id) { mutableStateOf<WarehouseLoadFailed?>(null) }
    var reloadToken by remember(school.id) { mutableStateOf(0) }

    LaunchedEffect(school.id, reloadToken) {
        // ① 缓存优先（列表 + 该列表对应的宏映射一起出，避免「先亮快捷导入入口再消失」）。
        val cached = withContext(Dispatchers.IO) { cache.readAdaptersIndex(school) }
        if (cached != null) {
            adapters = cached.value.adapters
            phase = WarehouseListPhase.Idle
            state.lastLoadIssue = null
            failure = null
            macroMap = withContext(Dispatchers.IO) {
                cached.value.adapters.associate { adapter ->
                    adapter.id to macroStore.hasMacro(school.id, adapter.id)
                }
            }
        } else {
            phase = WarehouseListPhase.Loading
        }

        // ② 6h 内同一份清单不再打网。
        if (cached != null && cache.isFresh(cached)) {
            Log.d(LOG_TAG, "adapters fresh cache hit school=${school.id} fetchedAt=${cached.fetchedAtMillis}")
            return@LaunchedEffect
        }

        // ③ 打网（或后台刷新）；成功写回缓存。
        val loaded = withContext(Dispatchers.IO) {
            service.loadAdaptersIndex(school).also { result ->
                if (result is WarehouseLoad.Ok) {
                    result.raw?.let { cache.writeAdaptersIndex(school, it) }
                }
            }
        }
        when (loaded) {
            is WarehouseLoad.Ok -> {
                adapters = loaded.value.adapters
                phase = WarehouseListPhase.Idle
                state.lastLoadIssue = null
                failure = null
                macroMap = withContext(Dispatchers.IO) {
                    loaded.value.adapters.associate { adapter ->
                        adapter.id to macroStore.hasMacro(school.id, adapter.id)
                    }
                }
            }

            is WarehouseLoad.Failed -> {
                val issue = warehouseLoadIssueOf(loaded)
                state.lastLoadIssue = issue
                failure = loaded.toLoadFailed()
                // 有缓存：保留清单（phase 已是 Idle），原因进 lastLoadIssue 与日志；
                // 没缓存才退失败页。
                if (cached == null) {
                    adapters = emptyList()
                    phase = WarehouseListPhase.Failed
                    macroMap = emptyMap()
                }
                Log.w(
                    LOG_TAG,
                    "adapters load failed school=${school.id} code=${loaded.code} " +
                        "attempts=${loaded.attempts} issue=$issue cached=${cached != null}",
                )
            }
        }
    }

    WarehouseSchoolAdaptersPage(
        school = school,
        adapters = adapters,
        // 宏映射真值（P2）：存过录制的适配器亮「快捷导入」按钮（回放引擎已接）。
        macroMap = macroMap,
        phase = phase,
        // 失败卡的具体原因：码只进日志，页面出文案用 failure.issue（四档）。
        failure = failure,
        onBack = onBack,
        onRefresh = { reloadToken += 1 },
        onRetry = { reloadToken += 1 },
        onImportAdapter = { adapter ->
            // 「网页登录导入」= 去登录页（Dart 同名按钮的语义）。
            // 首次导入（该适配器还没存过宏）自动开始录制——对齐 Dart
            // `shouldAutoRecordWarehouseImport(forceRecord = false, hasExistingMacro)`。
            val autoRecord = shouldAutoRecordWarehouseImport(
                forceRecord = false,
                hasExistingMacro = macroMap[adapter.id] ?: false,
            )
            state.adapter = adapter
            state.autoRecordMacro = autoRecord
            state.playbackMacro = null
            // 目标页拿到的是新实例：选择必须经交接件带过去，否则登录页见 null 会退回选校页。
            WarehouseImportHandoff.publish(school, adapter, autoRecordMacro = autoRecord)
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        },
        onViewAdapterDetail = { adapter ->
            state.adapter = adapter
            WarehouseImportHandoff.publish(school, adapter)
            onOpenPage(WarehouseRoutes.DETAIL)
        },
        onRecordAdapter = { adapter ->
            // 「录制导入」（P1 起可用）：显式录制，无论有没有已存宏（Dart autoRecord: true 恒真）。
            state.adapter = adapter
            state.autoRecordMacro = true
            state.playbackMacro = null
            WarehouseImportHandoff.publish(school, adapter, autoRecordMacro = true)
            onOpenPage(WarehouseRoutes.WEB_LOGIN)
        },
        onQuickImportAdapter = { adapter ->
            // 「快捷导入」（P2 起可用）：读出该适配器的宏 → 进登录页自动回放。
            scope.launch {
                val record = withContext(Dispatchers.IO) {
                    macroStore.getMacro(school.id, adapter.id)
                }
                if (record == null) {
                    // 宏在列表加载后、点击前被删等边缘：给实话，不画空转。
                    toastUnavailable(context, "quick import: macro record missing")
                } else {
                    state.adapter = adapter
                    state.autoRecordMacro = false
                    state.playbackMacro = record
                    WarehouseImportHandoff.publish(school, adapter, playbackMacro = record)
                    onOpenPage(WarehouseRoutes.WEB_LOGIN)
                }
            }
        },
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
    // 壳给每页的是独立实例：目标经交接件带过来（见 [WarehouseImportHandoff]）。
    val handoff = remember { WarehouseImportHandoff.take() }
    val school = state.school ?: handoff?.school
    val adapter = state.adapter ?: handoff?.adapter
    if (school == null || adapter == null) {
        // 拿不到目标（只可能从页面清单直接点进来）：如实说一句 + 给返回键，
        // **不再静默跳回选校页**——「点进来又被打回列表」正是那一下静默跳转造成的。
        LaunchedEffect(Unit) { Log.w(LOG_TAG, "adapter detail opened without school/adapter") }
        WarehouseNoTargetPage(WarehouseStrings.adapterInfoTitle.zh, onBack)
        return
    }

    var customImportUrl by remember(adapter.id) { mutableStateOf(prefs.customImportUrl(adapter.id)) }

    // 脚本状态卡（2026-11-05）：详情页要在**不注入脚本**的前提下说清「这个适配器的脚本能不能用」。
    // 这里拉一次正文（含 SHA-256 校验），结果降维成四态交给页面；失败码只进日志、不出文案。
    val fetchOptions = remember(context) {
        readWarehouseFetchOptions(PrefsKeyValueStore(context))
    }
    val scriptService = remember(fetchOptions) {
        WarehouseRepositoryService(WarehouseJdkFetch(), options = fetchOptions)
    }
    var scriptStatus by remember(school.id, adapter.id) {
        mutableStateOf<WarehouseScriptStatus>(WarehouseScriptStatus.Loading)
    }
    LaunchedEffect(school.id, adapter.id) {
        scriptStatus = WarehouseScriptStatus.Loading
        val loaded = withContext(Dispatchers.IO) { scriptService.loadAdapterScript(school, adapter) }
        scriptStatus = warehouseScriptStatusOf(loaded)
        if (loaded is WarehouseLoad.Failed) {
            Log.w(
                LOG_TAG,
                "adapter script load failed adapter=${adapter.id} code=${loaded.code} attempts=${loaded.attempts}",
            )
        }
    }

    WarehouseAdapterDetailPage(
        school = school,
        adapter = adapter,
        customImportUrl = customImportUrl,
        // 脚本状态四态：Loading / Loaded(length) / Empty / Failed(code, issue)。
        scriptStatus = scriptStatus,
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
            WarehouseImportHandoff.publish(school, adapter)
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

/**
 * 选校页一次本地预读的结果（都在盘上，IO 一次取回）。
 *
 * 三样分开是因为它们**出场顺序不同**：最近使用与已存宏马上要渲染（★ 分组、快捷导入入口），
 * 缓存名单决定「首帧有没有内容」，而网络是最后才补的。合成一个数据类是为了只下一次 IO。
 */
private class WarehousePickerLocalRecords(
    val recentSchoolIds: List<String>,
    val macroRecords: List<WarehouseMacroRecord>,
    val cachedRootIndex: WarehouseRepositoryCache.Cached<WarehouseRootIndex>?,
)

/**
 * 由「更新下载渠道 / 下载来源 / 镜像预设」推出适配仓拉取偏好。
 *
 * 逐字对齐 Dart `WarehouseFetchOptions.fromSettings`（`warehouse_repository_service.dart:33-45`）：
 * - `preferGitCode` = 渠道是 **GitCode 或蒲公英**（两者都国内可直连，见
 *   `preferGitCodeSync`：`timetable_settings_extensions.dart:446-450`）；
 * - 镜像前缀**只在下载来源 = mirror 时**才拼（`original` 渠道不该把请求丢给第三方代理，
 *   同 Dart `_buildCandidateUris` 的 `downloadSource != mirror → [originalUri]`）。
 *
 * 为什么读全部设置再映射、而不是只读两个键：`AppUpdateSettings.fromJson` 已经封了
 * 「缺键/非法值按默认回落」的口径，自己挑键会把那份口径抄第二遍。
 */
private fun readWarehouseFetchOptions(prefs: KeyValueStore): WarehouseFetchOptions {
    val settings = AppUpdateSettings.fromJson(TimetableStore(prefs).loadSettingsJson())
    val preferGitCode = settings.downloadChannel == AppUpdateDownloadChannel.GITCODE ||
        settings.downloadChannel == AppUpdateDownloadChannel.PGYER
    val mirrorUrlPrefix = if (settings.downloadSource == AppUpdateDownloadSource.MIRROR) {
        resolveMirrorUrlPrefix(settings.mirrorPreset, settings.mirrorUrlPrefix)
    } else {
        null
    }
    return WarehouseFetchOptions(preferGitCode = preferGitCode, mirrorUrlPrefix = mirrorUrlPrefix)
}
