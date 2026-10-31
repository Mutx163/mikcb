package com.mutx163.qingyu.app

import android.util.Log
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.mutx163.qingyu.HomeWidgetInstanceInfo
import com.mutx163.qingyu.TodayWidgetSupport
import com.mutx163.qingyu.WidgetSystemActions
import com.mutx163.qingyu.components.QingyuCard
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.pages.settings.HomeWidgetInstanceSpec
import com.mutx163.qingyu.pages.settings.HomeWidgetPreviewHost
import com.mutx163.qingyu.pages.settings.LocalHomeWidgetPreviewHost
import com.mutx163.qingyu.pages.settings.ProfileSpec
import com.mutx163.qingyu.pages.settings.SettingsHomeWidgetPage
import com.mutx163.qingyu.pages.settings.SettingsPageBridge
import com.mutx163.qingyu.pages.settings.SettingsPageScreen
import com.mutx163.qingyu.pages.settings.SettingsStrings
import com.mutx163.qingyu.pages.settings.SettingsStringsExt2
import com.mutx163.qingyu.pages.settings.SettingsStringsExt4
import com.mutx163.qingyu.theme.QingyuFixedTokens
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import top.yukonga.miuix.kmp.basic.Button
import top.yukonga.miuix.kmp.basic.Text
import top.yukonga.miuix.kmp.theme.MiuixTheme

private const val LOG_TAG = "HomeWidgetHost"

/**
 * 「桌面小组件」设置页的**真宿主**（F20 接线，替代壳里 no-op 的
 * `SettingsScreen(SettingsHomeWidgetPage.spec(SettingsHomeWidgetState()), onBack)`）。
 *
 * ## 为什么必须单独一个宿主，而不是塞进 [SettingsHost]
 *
 * 本页有 4 类 `SettingsHost` 那套「读模型 → 写模型」覆盖不到的东西：
 *
 * 1. **效果预览**：位图由原生 `WidgetPreviewRenderer` 把真实 RemoteViews 渲染成
 *    PNG（Dart `settings_home_widget.dart:401-403`），渲染输入是「当前草稿设置」，
 *    不能等落盘后才发现预览还是旧档位；
 * 2. **桌面上真实卡片实例**：绑定管理下拉的行数和行标题来自
 *    `AppWidgetManager.getAppWidgetIds(...)`，不是设置模型；
 * 3. **系统能力**：请求添加到桌面（`requestPinAppWidget`）与「闹钟和提醒」授权页；
 * 4. **绑定落点**：`homeWidget.binding.<appWidgetId>` 写的是原生 `WidgetBindingStore`，
 *    不是 `timetable_settings`。
 *
 * ## 与 Dart 原版逐项对齐
 *
 * | Dart（`settings_home_widget.dart`） | 本宿主 |
 * |---|---|
 * | `_draft` + `_updateDraft` / `_enqueuePersist`（:924-958） | `model` + [saveWidgetModelVerified] |
 * | `_loadWidgetInstances`（:893-901） | [refreshInstances] |
 * | `_loadExactAlarmPermission`（:989-1008） | [refreshExactAlarm] |
 * | `_requestPinWidget`（:1095-1125） | [pinWidget] |
 * | `_requestExactAlarmPermission`（:1009-1035） | [requestExactAlarm] |
 * | `_setWidgetBinding`（:903-920） | 绑定行拦截分支 |
 * | `didChangeAppLifecycleState` 回前台重查（:156-170） | [DisposableEffect] 里的 ON_RESUME |
 *
 * 回前台时**延迟 300ms** 再查卡片实例：pin 请求是在系统弹窗里确认的，启动器完成
 * 绑定比 `ON_RESUME` 晚一拍，立刻查会拿到旧集合（Dart 同注释 :164-166）。
 */
@Composable
fun HomeWidgetHost(
    store: TimetableSettingsModelStore,
    repository: TimetableRepository,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val lifecycleOwner = LocalLifecycleOwner.current

    var model by remember(store) { mutableStateOf(store.load()) }
    var instances by remember { mutableStateOf(emptyList<HomeWidgetInstanceInfo>()) }
    var profiles by remember { mutableStateOf(repository.snapshot.profiles) }
    var exactAlarmGranted by remember { mutableStateOf<Boolean?>(null) }
    var canPin by remember { mutableStateOf(false) }
    var checkingPin by remember { mutableStateOf(true) }
    /** 正在请求 pin 的卡型；null = 没有请求在飞。 */
    var pinningTarget by remember { mutableStateOf<String?>(null) }
    /**
     * 等待二次确认的重置作用域；null = 没有弹窗。
     *
     * Dart `SettingsResetTile._confirm`（`settings_reset.dart:249-258`）先弹确认框再落盘，
     * 不能点一下就把显示项与外观清空。
     */
    var pendingReset by remember { mutableStateOf<String?>(null) }
    /**
     * 预览代次：设置/绑定变一次 +1，已渲染的位图整批作废重出。
     *
     * Dart 是 `_previewGeneration++` + 180ms 防抖后清缓存（:783-800）；这里把
     * 「何时重出图」交给渲染层按 revision 自行失效，宿主只负责推进代次。
     */
    var previewRevision by remember { mutableIntStateOf(0) }

    fun refreshInstances() {
        instances = WidgetSystemActions.listTodayWidgetInstances(context)
    }

    fun refreshExactAlarm() {
        val previous = exactAlarmGranted
        val granted = WidgetSystemActions.canScheduleExactAlarms(context)
        exactAlarmGranted = granted
        // 从未授权升级为已授权：原来的刷新闹钟仍是非精确档，主动重排一次
        // （Dart `_loadExactAlarmPermission`，`settings_home_widget.dart:1001-1005`）。
        if (granted && previous == false) {
            runCatching { WidgetSystemActions.rescheduleRefresh(context) }
        }
    }

    LaunchedEffect(Unit) {
        refreshInstances()
        refreshExactAlarm()
        canPin = WidgetSystemActions.canRequestPinWidget(context)
        checkingPin = false
        // 档案可能在进页前变过（导入/切档案），重读一次快照。
        profiles = repository.snapshot.profiles
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                refreshExactAlarm()
                profiles = repository.snapshot.profiles
                scope.launch {
                    delay(PIN_CONFIRM_DELAY_MILLIS)
                    refreshInstances()
                }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    fun applyModel(next: TimetableSettingsModel) {
        if (saveWidgetModelVerified(store, model, next)) {
            model = next
            // 桌面上的卡片读的是档案内嵌 settings（save 已镜像过去），但不会自己重绘：
            // 设置一改就重绘全部卡片 + 按新外观重排刷新闹钟（Dart 的
            // `updateTimetableSettings` 之后由小组件服务同款处理）。
            runCatching {
                TodayWidgetSupport.updateAll(context)
                WidgetSystemActions.rescheduleRefresh(context)
            }.onFailure { Log.w(LOG_TAG, "widget refresh after settings save failed", it) }
            // 预览读的就是这份设置：落盘成功后才让位图重出（Dart `_invalidatePreview`）。
            previewRevision++
        } else {
            Log.e(LOG_TAG, "home widget settings save did not land")
            Toast.makeText(
                context,
                SettingsStringsExt2.saveFailed.zh,
                Toast.LENGTH_SHORT,
            ).show()
        }
    }

    fun setBinding(appWidgetId: Int, target: String?) {
        val profileId = target?.takeIf { it != SettingsHomeWidgetPage.FOLLOW_ACTIVE_VALUE }
        val ok = runCatching {
            WidgetSystemActions.setWidgetBinding(context, appWidgetId, profileId)
        }.isSuccess
        if (!ok) {
            Toast.makeText(
                context,
                SettingsStringsExt2.homeWidgetBindingSaveFailed.zh,
                Toast.LENGTH_SHORT,
            ).show()
        }
        // Dart 无论成败都重查一次列表（:904-914）：失败时界面停在旧值。
        refreshInstances()
        previewRevision++
    }

    fun pinWidget(targetId: String) {
        if (pinningTarget != null) return
        pinningTarget = targetId
        scope.launch {
            val status = runCatching {
                WidgetSystemActions.requestPinWidget(context, targetId)
            }.getOrDefault("failed")
            pinningTarget = null
            val label = SettingsHomeWidgetPage.targetLabelFor(targetId).zh
            val message = when (status) {
                "requested" -> SettingsStringsExt2.homeWidgetPinRequested.filled("label", label)
                "unsupported" -> SettingsStringsExt2.homeWidgetPinUnsupportedManual.filled("label", label)
                "invalid_widget_type" -> SettingsStringsExt2.homeWidgetInvalidType.zh
                else -> SettingsStringsExt2.homeWidgetPinFailedManual.filled("label", label)
            }
            Toast.makeText(context, message, Toast.LENGTH_LONG).show()
            // 真正「已确认添加」发生在系统弹窗之后，由 ON_RESUME 兜底重查；
            // 这里即时查一次拿到最常见的结果（Dart :1124-1125）。
            refreshInstances()
        }
    }

    fun requestExactAlarm() {
        val status = runCatching {
            WidgetSystemActions.requestScheduleExactAlarm(context)
        }.getOrDefault("failed")
        when (status) {
            "fallback" -> Toast.makeText(
                context,
                SettingsStringsExt2.homeWidgetExactAlarmFallbackHint.zh,
                Toast.LENGTH_LONG,
            ).show()

            "failed" -> Toast.makeText(
                context,
                SettingsStringsExt2.homeWidgetExactAlarmOpenFailed.zh,
                Toast.LENGTH_LONG,
            ).show()
            // launched / not_required：回到前台时 ON_RESUME 会重查授权状态。
            else -> Unit
        }
    }

    val profileSpecs = profiles.map { ProfileSpec(it.id, it.name, it.isPartnerImported) }
    val state = SettingsPageBridge.toHomeWidgetState(
        model = model,
        widgetInstances = instances.map {
            HomeWidgetInstanceSpec(
                appWidgetId = it.appWidgetId,
                widgetTypeValue = it.widgetType,
                boundProfileId = it.boundProfileId,
            )
        },
        profiles = profileSpecs,
        partnerProfile = profileSpecs.firstOrNull { it.isPartnerImported },
        exactAlarmGranted = exactAlarmGranted,
    )

    CompositionLocalProvider(
        LocalHomeWidgetPreviewHost provides HomeWidgetPreviewHost(
            // 预览覆盖用**模型全量键**而不是仅 10 个外观键：原生快照构建还会读
            // 节假日开关等键，只给 10 个会把它们一起回落成默认值。
            settingsJson = MiniJson.encode(model.toJsonPatch()),
            cornerRadius = model.widgetCornerRadius,
            revision = previewRevision,
            canPin = canPin,
            checkingPin = checkingPin || pinningTarget != null,
            onPin = { targetId -> pinWidget(targetId) },
        ),
    ) {
        SettingsPageScreen(
            spec = SettingsHomeWidgetPage.spec(state),
            onBack = onBack,
            onAction = { action, target, rowId ->
                when (SettingsPageBridge.toKind(action)) {
                    SettingsActionKind.WRITE_SETTING -> {
                        // 绑定行写的是原生 WidgetBindingStore，不是设置模型。
                        if (rowId.startsWith(BINDING_ROW_PREFIX)) {
                            rowId.removePrefix(BINDING_ROW_PREFIX).toIntOrNull()?.let { id ->
                                setBinding(id, target)
                            } ?: Log.w(LOG_TAG, "bad binding rowId=$rowId")
                        } else {
                            val result = SettingsActionDispatcher.dispatch(
                                SettingsActionKind.WRITE_SETTING,
                                target,
                                rowId,
                                model,
                            )
                            if (result is SettingsDispatch.Write) applyModel(result.model)
                        }
                    }

                    SettingsActionKind.RESET_SCOPE ->
                        // 只记下作用域，真正的写入在确认弹窗里做（Dart :249-258）。
                        target?.let { pendingReset = it }

                    SettingsActionKind.RUN_NOW -> when (rowId) {
                        SettingsActionDispatcher.ROW_HOME_WIDGET_PREVIEW_ADD ->
                            target?.let(::pinWidget)
                                ?: Log.w(LOG_TAG, "preview add without target")

                        SettingsActionDispatcher.ROW_HOME_WIDGET_ALARM_GRANT -> requestExactAlarm()

                        else -> Log.w(LOG_TAG, "unhandled RUN_NOW rowId=$rowId")
                    }

                    // 本页没有弹层/导航/剪贴板行；真出现时留痕，别让「点了没反应」无从查起。
                    else -> Log.w(LOG_TAG, "unhandled home-widget action=$action rowId=$rowId")
                }
            },
        )

        pendingReset?.let { scopeId ->
            HomeWidgetResetConfirmDialog(
                onDismiss = { pendingReset = null },
                onConfirm = {
                    SettingsActionDispatcher.applyResetScope(model, scopeId)?.let(::applyModel)
                    pendingReset = null
                },
            )
        }
    }
}

/** 绑定管理行的 rowId 前缀（`SettingsHomeWidgetPage.bindingBlock` 的 id 约定）。 */
private const val BINDING_ROW_PREFIX = "homeWidget.binding."

/** pin 请求后等启动器完成绑定的时间（Dart `:164-166` 的 300ms）。 */
private const val PIN_CONFIRM_DELAY_MILLIS = 300L

/**
 * 与 `SettingsHost.saveVerified` **同一套**「写完读回校验」：写盘后重新读，只有
 * 本次真正改动的键都落到了盘上才更新内存模型；否则界面停在旧值并报错。
 *
 * 不复用那个 private 函数：它在 `SettingsHost.kt` 里是文件级 private，本文件同包
 * 也取不到；改成 internal 会扩大它的可见面，收益不值得。
 */
private fun saveWidgetModelVerified(
    store: TimetableSettingsModelStore,
    before: TimetableSettingsModel,
    next: TimetableSettingsModel,
): Boolean {
    store.save(next)
    val disk = runCatching { store.load() }.getOrNull() ?: return false
    return SettingsActionDispatcher.persistLanded(before, next, disk)
}

/**
 * 「恢复默认设置」二次确认框（`settings_reset.dart:249-258`）。
 *
 * 正文用 **homeWidget 作用域**那一句（`settingsResetConfirmBodyHomeWidget`，
 * 与 `SettingsResetPage.HOME_WIDGET` 登记的一致）；外层 `SettingsHost` 那份弹窗的
 * `when` 没有 homeWidget 分支，会落到外观作用域的正文，所以本页自己画一份。
 *
 * 交互照官方：点遮罩 / 取消 关闭；点确认才落盘。确认色用危险色，与 Dart
 * `showHyperosConfirmDialog(destructive: true)` 对齐。
 */
@Composable
private fun HomeWidgetResetConfirmDialog(
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.45f))
            .clickable(onClick = onDismiss),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                // 内层吞掉点击，避免点卡片本身把弹窗关掉。
                .clickable(onClick = {}),
        ) {
            QingyuCard(modifier = Modifier.fillMaxWidth(), insideMargin = PaddingValues(16.dp)) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(
                        text = SettingsStringsExt4.settingsResetDefaultsConfirmTitle.zh,
                        style = MiuixTheme.textStyles.title4,
                        fontWeight = FontWeight.Bold,
                        color = MiuixTheme.colorScheme.onBackground,
                    )
                    Text(
                        text = SettingsStringsExt4.settingsResetConfirmBodyHomeWidget.zh,
                        style = MiuixTheme.textStyles.body2,
                        color = MiuixTheme.colorScheme.onSurfaceVariantSummary,
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.End,
                    ) {
                        Button(onClick = onDismiss) {
                            Text(
                                text = SettingsStringsExt4.cancelAction.zh,
                                style = MiuixTheme.textStyles.button,
                            )
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                        Button(onClick = onConfirm) {
                            Text(
                                text = SettingsStrings.settingsResetDefaultsTitle.zh,
                                style = MiuixTheme.textStyles.button,
                                color = Color(QingyuFixedTokens.DESTRUCTIVE),
                            )
                        }
                    }
                }
            }
        }
    }
}
