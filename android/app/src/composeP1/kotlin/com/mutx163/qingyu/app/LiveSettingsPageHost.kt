package com.mutx163.qingyu.app

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import com.mutx163.qingyu.pages.live.LiveDisplayState
import com.mutx163.qingyu.pages.live.LiveDisplayStore
import com.mutx163.qingyu.pages.settings.LiveDisplayInput
import com.mutx163.qingyu.pages.settings.LivePageData
import com.mutx163.qingyu.pages.settings.SettingsAction
import com.mutx163.qingyu.pages.settings.SettingsLivePage
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsPageState
import com.mutx163.qingyu.platform.PrefsKeyValueStore

/**
 * 「设置 → 实时活动」入口页（`b.live`）的**真实宿主**。
 *
 * ## 为什么需要这一层
 *
 * 壳里原来的挂法是 `SettingsLivePage.spec(SettingsPageState())`：`data` 走默认参数
 * `LivePageData()`，于是「上课前显示 / 课中显示」两行摘要**恒为默认值**，
 * 用户改过显示设置也看不出来。`spec(state, data)` 的 `state` 参数通篇未使用，
 * 真正决定摘要的是 `data` —— 见 [SettingsLivePage] 的 `displaySummary`。
 *
 * ## 数据从哪来
 *
 * 与「显示设置」子页（`LiveDisplayHost`）**同一个源**：[LiveDisplayStore] 读
 * `timetable_settings` 里的 `liveShowCourseName` 等键。这里**只读**，不写：
 * 本页 5 行全是 `ARROW + NAVIGATE`，没有任何开关，写盘全部发生在子页宿主里。
 * 两档（上课前 / 课中）的键组不同，所以分别读 [LiveDisplayStore.loadDisplay] 两次；
 * 「课中跟随上课前」这个开关由 `duringEndFollowBeforeClass` 承载（跟随为 true 时，
 * 课中那份是从上课前派生出来的，读出来本来就与上课前一致）。
 *
 * ## 子页回跳
 *
 * `onOpenPage` 收到的是页面里的**原始 `actionTarget`（路由形态）**，与壳里其余宿主一致；
 * 路由 → 壳页面 id 的映射由调用方（壳）做，本层不重复维护那张表。
 * 只转发 [SettingsAction.NAVIGATE]：将来若本页加开关，`WRITE_SETTING` 之类的目标
 * 不是路由串，不能当页面 id 推。
 */
@Composable
fun LiveSettingsPageHost(
    onBack: () -> Unit,
    onOpenPage: (String) -> Unit,
) {
    val context = LocalContext.current
    val store = remember(context) { liveSettingsStore(context) }
    // 只读一次：本页没有可改的状态，离开本页去子页时它的组合会被拆掉，
    // 回来重新组合会重新读盘（与 `WeatherSettingsHost` 的 `remember(store)` 同口径）。
    val data = remember(store) {
        val before = store.loadDisplay(forDuringEnd = false)
        val duringEnd = store.loadDisplay(forDuringEnd = true)
        LivePageData(
            beforeClass = before.toDisplayInput(),
            duringEnd = duringEnd.toDisplayInput(),
            duringEndFollowBeforeClass = before.duringEndFollowBeforeClass,
        )
    }

    SettingsPageScreen(
        spec = SettingsLivePage.spec(SettingsPageState(), data),
        onBack = onBack,
        onAction = { action, target, _ ->
            when (action) {
                SettingsAction.NAVIGATE -> target?.let(onOpenPage)
                else -> Unit
            }
        },
    )
}

/** 显示模型 → 本页摘要用的六布尔视图（两档共用同一个映射）。 */
private fun LiveDisplayState.toDisplayInput(): LiveDisplayInput = LiveDisplayInput(
    showCourseName = showCourseName,
    showLocation = showLocation,
    showCountdown = showCountdown,
    showStageText = showStageText,
    useShortName = useShortName,
    enableMiuiIslandLabelImage = enableMiuiIslandLabelImage,
)

/** 与 `LiveDisplayHost` 同一套存储装配：`FlutterSharedPreferences` + 冻结键格式。 */
private fun liveSettingsStore(context: Context): LiveDisplayStore =
    LiveDisplayStore(TimetableStore(PrefsKeyValueStore(context)))
