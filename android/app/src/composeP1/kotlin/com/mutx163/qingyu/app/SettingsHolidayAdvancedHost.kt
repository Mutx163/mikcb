package com.mutx163.qingyu.app

import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.calendar.HolidayProvider
import com.mutx163.qingyu.calendar.HolidaySnapshot
import com.mutx163.qingyu.pages.settings.SettingsHolidayAdvancedPage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.pages.settings.SettingsStringsExt3
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** 高级页「检查更新」按钮的节点 id（`SettingsHolidayAdvancedPage.refreshCard()` 的 `SettingsInline.id`）。 */
private const val ROW_ADVANCED_REFRESH = "holidayAdvanced.card.refresh"

/**
 * 「节假日数据更新」页（`b.holidayAdvanced`）的**真宿主**。
 *
 * 壳里原来用 `SettingsScreen(SettingsHolidayAdvancedPage.spec(SettingsPageState()), onBack)`
 * 渲染空构造 —— 日志永远「暂无日志」，「检查更新」是死按钮（审计 §二 缺口 6）。
 *
 * ## 这一页只有两件事
 *
 * 1. **渲染**：日志列表 + 固定底栏都在 spec 里（模型泳道把底栏放进
 *    [com.mutx163.qingyu.pages.settings.SettingsPageSpec.footerNode]，渲染层交给
 *    `QingyuPageScaffold(bottomBar = …)` 钉在底部，不随日志滚动）。本宿主不自己拼底栏。
 * 2. **检查更新**：`RUN_NOW` ⇒ `provider.refresh()`，完成后 Toast「检查更新」
 *    （Dart `:676-697`，成功提示就是这句 `l10n.holidayCheckUpdate`）。
 *
 * ## 为什么这里也调 `initialize()`
 *
 * Dart 的数据加载挂在全局 provider 上，用户从主页面进来时已经加载过。Compose 侧允许直接
 * 深链到本页（壳的页面 id 是独立入口），那时候 provider 还是空快照、日志一片空白。
 * [HolidayProvider.initialize] 是幂等的（命中内存/本地缓存，不会发第二次网络请求），
 * 所以这里补一次不影响从主页面进来的路径，却能让深链进来也看到真实日志。
 *
 * ## 与 Flutter 的已知差异
 *
 * - **提示形态**：Dart 用 `showAppToast(success)`，这里用系统 `Toast`（同一族宿主同口径）。
 * - **刷新失败的反馈**：Dart 只在成功时提示（异常直接抛出、页面靠 `finally` 复位）；
 *   这里 `provider.refresh()` 按约定**从不外抛**，失败会落成一条日志显示在列表里，
 *   所以也不需要额外的错误提示——用户看到的是「多了一条失败日志」，而不是一句笼统的失败。
 *
 * @param provider 节假日状态机（与主页面同一个实例，壳里注入 `wiring.holiday`）。
 * @param onBack 返回键。
 */
@Composable
fun SettingsHolidayAdvancedHost(
    provider: HolidayProvider,
    onBack: () -> Unit,
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var version by remember { mutableIntStateOf(0) }
    // 首屏加载态：`initialize()` 结束前屏上不该出现「暂无日志」（详见 [buildData] 的 loading 参数）。
    // 这个完成信号只有拉起初始化的这一处知道——provider 的 snapshot 里没有 loading 位
    // （`initialize()` 走 `load(refreshing = false)`，`refreshing` 全程不亮）。
    var initialLoadDone by remember(provider) { mutableStateOf(false) }

    // 订阅 provider：刷新进度（refreshing）与新增日志都要立刻反映到界面。
    DisposableEffect(provider) {
        val listener: () -> Unit = { version++ }
        provider.addListener(listener)
        onDispose { provider.removeListener(listener) }
    }
    // 深链直接进本页时 provider 可能还没加载过；幂等，不会多打一次网络。
    // `finally` 保证异常路径也会摘掉加载态（provider 约定不外抛，但别把界面吊在半空）。
    LaunchedEffect(provider) {
        try {
            withContext(Dispatchers.IO) { provider.initialize() }
        } finally {
            initialLoadDone = true
        }
    }
    // 读取 version 建立快照订阅（值本身不参与渲染）。
    @Suppress("UNUSED_EXPRESSION")
    version

    /**
     * 检查更新（Dart `_refreshHolidayData`，`:676-697`）：刷新中不重入 → 按**结果**提示。
     *
     * Dart 侧这条动作只有「成功」一条路：`try` 里刷完必弹 `l10n.holidayCheckUpdate`
     * （就是按钮名本身），`finally` 复位，没有失败分支。这里改成两句真结果：
     * - 远端真的拉到了（[HolidaySnapshot.remoteFetchSucceeded] == true）→「节假日数据已更新」；
     * - 拉过但全失败（== false，此时数据是内置兜底）→「更新失败，已使用本地数据」；
     * - `null`（不发请求就命中缓存，理论上 forceRemote 下不会出现）→ 按成功算，不谎报失败。
     *
     * 之所以不能只看 `runCatching` 成不成功：provider 从不外抛，动作永远「成功」，
     * 真正该报给用户的是「数据有没有更新」。
     */
    fun checkUpdate() {
        // Dart `:677-679` `if (_refreshing) return;`——按钮虽然会按 refreshing 置灰，
        // 这里再兜一次，避免连点两次排队刷两遍。
        if (provider.snapshot.refreshing) return
        scope.launch {
            val outcome = runCatching {
                withContext(Dispatchers.IO) { provider.refresh() }
            }.fold(
                onSuccess = { provider.snapshot.remoteFetchSucceeded },
                onFailure = { false },
            )
            val message = if (outcome == false) {
                SettingsStringsExt3.holidayDataUpdateFailed.text
            } else {
                SettingsStringsExt3.holidayDataUpdated.text
            }
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }
    }

    val snapshot = provider.snapshot
    // 页面输入一律由模型泳道给（「一条日志 = 时刻在上、正文在下」这种行结构只在那里定义一处）。
    // 日志正文已由 provider 本地化、时刻已格式化，模型只做搬运（见 buildData 的 KDoc）。
    val data = SettingsHolidayAdvancedPage.buildData(
        logs = provider.logs,
        refreshing = snapshot.refreshing,
        loading = !initialLoadDone,
    )

    SettingsPageScreen(
        spec = SettingsHolidayAdvancedPage.spec(SettingsPageState(), data),
        onBack = onBack,
        onAction = { _, _, rowId ->
            // 底栏那颗按钮的 action 值取决于渲染层控制卡的接线，所以按 **rowId** 认，
            // 不绑死某个 SettingsAction（避免两条泳道对同一个按钮选值不一致）。
            if (rowId == ROW_ADVANCED_REFRESH) checkUpdate()
        },
    )
}
