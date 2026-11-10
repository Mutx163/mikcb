package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.app.TimetableSnapshot

/**
 * P3-B-2 四页的输入状态（页面构建的**唯一输入**）。
 *
 * ## 为什么不放进 `SettingsPageState.kt`
 *
 * 那个文件是设置族**共享件**：P3-B 这一轮有 4 条泳道同时写设置族，改它必然互相
 * 覆盖。所以本批四页各自带一份局部状态类，放在这里；汇合由 Lead 一次做完
 * （届时把用得上的字段并进 `SettingsPageState` 即可，本文件随页面一起改引用）。
 *
 * ## 字段口径
 *
 * 枚举一律用**落盘字符串**（`value`）而不是 Kotlin 枚举：Dart 侧这些枚举的完整
 * 设置模型移植尚未合入（见 `SettingsPageState` 头注释），用字符串既与 Dart 的
 * `value` 逐字对齐，也避免提前替设置域拍枚举命名。
 *
 * 默认值一律照抄 `lib/models/timetable_settings.dart` 的构造默认值，行号写在字段上。
 */

// ============================================================ 桌面小组件页

/**
 * 桌面小组件设置页的输入。
 *
 * 默认值来源：`timetable_settings.dart:786-795`。
 */
data class SettingsHomeWidgetState(
    /** `widgetBackgroundStyle`（:786），落盘 `glass`/`solid`/`gradient`。 */
    val backgroundStyle: String = "solid",
    /** `widgetCourseAccentMode`（:787），落盘 `off`/`bar`/`bar_and_text`。 */
    val courseAccentMode: String = "bar_and_text",
    /** `widgetShowLocation`（:788）。 */
    val showLocation: Boolean = true,
    /** `widgetShowCountdown`（Dart :789）；false 时倒计时整块不渲染，也不排每分钟心跳。 */
    val showCountdown: Boolean = false,
    /** `widgetHideCompletedCourses`（:790）。 */
    val hideCompletedCourses: Boolean = false,
    /** `widgetShowTomorrowCourses`（:791）。 */
    val showTomorrowCourses: Boolean = true,
    /** `widgetHeightAdjustment`（:792）：**存储值**，默认 -11。 */
    val heightAdjustment: Double = SettingsHomeWidgetPage.DEFAULT_HEIGHT_ADJUSTMENT,
    /** `widgetCornerRadius`（:793）。 */
    val cornerRadius: Double = SettingsHomeWidgetPage.DEFAULT_CORNER_RADIUS,
    /** `widgetCountdownLeadMinutes`（:794）。 */
    val countdownLeadMinutes: Int = 20,
    /** `widgetCountdownTextStyle`（:795），落盘串见 `timetable_settings_extensions.dart:153-167`。 */
    val countdownTextStyle: String = "smart",
    /** 桌面上真实存在的今日课程卡片（`_widgetInstances`，:59）。 */
    val widgetInstances: List<HomeWidgetInstanceSpec> = emptyList(),
    /** 全部课表（`provider.profiles`，:829）。 */
    val profiles: List<ProfileSpec> = emptyList(),
    /** 情侣课表对应的 TA 课表（`provider.partnerProfile`，:832）；null = 未导入。 */
    val partnerProfile: ProfileSpec? = null,
    /**
     * 「闹钟和提醒」权限：null = **尚未查到**（首帧不展示 `false`，避免横幅闪烁，
     * `settings_home_widget.dart:64-66`）；false 才展示引导条（:212）。
     */
    val exactAlarmGranted: Boolean? = null,
)

/** 桌面上的一张今日课程卡片（`HomeWidgetInstance`，`home_widget_binding_service.dart:45-56`）。 */
data class HomeWidgetInstanceSpec(
    val appWidgetId: Int,
    /** `HomeWidgetType.value`；null = 类型未知（回落 `compact`，:878）。 */
    val widgetTypeValue: String? = null,
    /** 绑定的课表 id；null = 未登记 = 跟随当前课表。 */
    val boundProfileId: String? = null,
)

/** 一份课表档案在设置页需要的两项（名字是用户数据，不来自 ARB）。 */
data class ProfileSpec(
    val id: String,
    val name: String,
    /** `profile.isPartnerImported`：TA 课表不进「普通课表」选项（:830）。 */
    val isPartnerImported: Boolean = false,
)

// ============================================================ 首页与导航页

/**
 * 首页与导航设置页的输入。
 *
 * 默认值来源：`timetable_settings.dart:801-812`。
 */
data class SettingsHomeNavigationState(
    /** `homeNavigationForm`（:803），落盘 `classic`/`glassDock`。 */
    val navigationForm: String = "classic",
    /** `glassDockShowAddButton`（:812）。 */
    val showAddButton: Boolean = false,
    /** `glassDockActions`（:809）：底栏按钮排列的原始 id 表。出厂跟发布 tag：日/周。 */
    val dockActionIds: List<String> = listOf("day", "week"),
    /** `glassDockButtonEntryId`（:810）。 */
    val dockButtonEntryId: String? = "addCourse",
    /** `glassDockButtonIconName`（:811）；null = 默认加号。 */
    val dockButtonIconName: String? = null,
    /** `homeMenuStyle`（:804），落盘 `list`/`grid`。 */
    val menuStyle: String = "list",
    /** `homeGridMenuActions`（:806）：八宫格排列的原始 id 表。出厂跟发布 tag（含 update、不含 tasks）。 */
    val gridMenuActions: List<String> =
        listOf("update", "overview", "statistics", "addCourse", "exams", "importCourses", "settings", "support"),
    /** `homeTitleStyle`（:801），落盘 `classic`/`brand`。 */
    val titleStyle: String = "classic",
    /** 诊断构建：决定 `memoryStats` 等调试条目在目录里可见（`home_menu_catalog.dart:448`）。 */
    val diagnosticsBuild: Boolean = false,
)

// ============================================================ 八宫格编辑器

/**
 * 八宫格按钮自定义编辑器的输入。
 *
 * 编辑器是**纯草稿视图**：改动即时回调 `onChanged`，落盘由宿主页负责
 * （`settings_home_menu_editor.dart:8-11`）。
 */
data class SettingsHomeMenuEditorState(
    /** 进来时的排列（`initialIds`，:19）。脏 id 会被种子清洗丢掉（:33-38）。出厂跟发布 tag。 */
    val enabledIds: List<String> =
        listOf("update", "overview", "statistics", "addCourse", "exams", "importCourses", "settings", "support"),
    /** 诊断构建：决定调试条目是否可作候选（`home_menu_catalog.dart:448`）。 */
    val diagnosticsBuild: Boolean = false,
)

// ======================================================== 设置首页（课表设置）

/**
 * 设置首页 / 课表设置 hub 与学期设置子页的输入。
 *
 * 默认值来源：`timetable_settings.dart`（开学日期无默认 = null）、
 * `TimetableProfile`（周次）、以及三个「异步查出来的状态」字段。
 */
data class SettingsTimetableState(
    /** 当前教学周（`provider.currentWeek`）；默认第 1 周（`TimetableProfile.kt:15`）。 */
    val currentWeek: Int = 1,
    /** `settings.semesterWeekCount`（`timetable_settings.dart`），默认 20。 */
    val semesterWeekCount: Int = 20,
    /** `settings.semesterStartDate`：null = 未设置（`settings_semester` 那一行据此变文案）。 */
    val semesterStartDate: Triple<Int, Int, Int>? = null,
    /** 激活课表名（`provider.activeProfile?.name`，:413）；null = 没有激活课表。 */
    val activeProfileName: String? = null,
    /** 激活时间模板名（`provider.activeTimeScheme?.name`，:433）；null = 未选择。 */
    val activeTimeSchemeName: String? = null,
    /** `settings.enableHolidayMarking`（`timetable_settings.dart:760` 默认 true）。 */
    val holidayMarkingEnabled: Boolean = true,
    /** 天气城市名（`weather?.location?.name`，:493）；null = 未设置。 */
    val weatherCityName: String? = null,
    /**
     * 通知权限：null = 还没查到（行尾留白，`_LiveEntryTileState`，:880/:920-926）。
     */
    val notificationPermissionGranted: Boolean? = null,
    /**
     * 任一实时提醒开关开着（`liveEnableBeforeClass || liveEnableDuringClass ||
     * liveEnableBeforeEnd`，:915-918）。三项默认 true（`timetable_settings.dart:830-832`）。
     */
    val liveReminderEnabled: Boolean = true,
    /**
     * 云同步入口的状态串：`loading` / `disabled` / `syncing` / `error` / `enabled`
     * （`_CloudSyncEntryTileState`，:999-1007）。
     */
    val cloudSyncState: String = "loading",
    /** `provider.hasPartnerBinding`（:602-604）。 */
    val partnerBound: Boolean = false,
    /** `kReleaseMode`（:1066）：正式发布版 + 非诊断构建时整组开发者工具不渲染。 */
    val releaseBuild: Boolean = false,
    /** `MemoryStatsService.isDiagnosticsBuild()`（:1056-1058）：是否诊断构建。 */
    val diagnosticsBuild: Boolean = false,
    /** `BlackBoxOverlayPreferences.instance.visible`（:1132）：调试叠层开关当前态。 */
    val debugOverlayVisible: Boolean = false,
)

/**
 * 设置首页（`b.settingsHome`，课表设置 hub）的**真值合成**。
 *
 * ## 为什么要有这一层
 *
 * 本页五行曾经拿 [SettingsTimetableState] 的构造默认值冒充真值（课表名空白、
 * 时间模板恒「未选择」、节假日恒「已开启」、天气恒「未设置」、情侣恒「未绑定」），
 * 子页改完回到这里**看不出来**——像真的，但没变回去。宿主
 * （`composeP1: app/SettingsSemesterHost.kt` 的 `SettingsTimetableHubHost`）现在
 * 从三处真源取数，交给本函数合成；函数本身零 Compose 依赖，JVM 单测直接钉住
 * 「哪一行的值来自哪个字段」。
 *
 * ## 五个字段的真源（与 Dart `timetable_settings_screen.dart` 逐条对应）
 *
 * | 行 | 真源 | Dart |
 * |---|---|---|
 * | 课表名 | `snapshot.profiles` + `snapshot.activeProfileId` | `provider.activeProfile?.name`（:413） |
 * | 时间模板 | `snapshot.timeSchemes` + `snapshot.activeTimeSchemeId` | `provider.activeTimeScheme?.name`（:433） |
 * | 节假日 | `settings.enableHolidayMarking`（落盘 `timetable_settings` 的键） | `settings.enableHolidayMarking`（:447） |
 * | 天气 | 调用方传进来的城市名（`WeatherProvider.location?.name`） | `weather?.location?.name`（:493） |
 * | 情侣 | 调用方传进来的绑定态（`partner_timetable_binding` 键是否可解） | `provider.hasPartnerBinding`（:602） |
 *
 * 其余字段保持 [SettingsTimetableState] 的默认值（本批不在这五行的范围内）。
 *
 * @param settings 完整设置模型（[TimetableSettingsModel]）。**不能**用
 *   `snapshot.settings` 代替：那是 `core.TimetableSettings` 的 4 键子集，
 *   `enableHolidayMarking` 根本不在里面。
 * @param weatherCityName null = 没有可用的天气 provider / 尚未选城 ⇒ 页面显示「未设置」。
 *   调用方不得拿固定字符串冒充。
 * @param partnerBound 绑定态必须由真实存储（`CouplePartnerPort.loadBinding()`）算出；
 *   null / false 都显示「未绑定」，但只有「读到了绑定」才允许给 true。
 */
object SettingsTimetableHubLogic {

    fun stateOf(
        snapshot: TimetableSnapshot,
        settings: TimetableSettingsModel,
        weatherCityName: String? = null,
        partnerBound: Boolean = false,
    ): SettingsTimetableState {
        // 档案名：仓储已经把悬空 id 回落成第一份（见 `TimetableRepository.activeProfile`），
        // 这里再回落一次只是为了「快照被外部直接构造」时也不显示空气。
        val activeProfileName = (
            snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
                ?: snapshot.profiles.firstOrNull()
            )
            ?.name
            ?.takeIf { it.isNotBlank() }

        // 时间模板：Dart `_getTimeSchemeById(settings.activeTimeSchemeId)` —— 只认 id，
        // **不要**在 id 为空时偷偷挑第一套：那会把「未选择」显示成一套具体的模板。
        val activeTimeSchemeName = snapshot.timeSchemes
            .firstOrNull { it.id == snapshot.activeTimeSchemeId }
            ?.name
            ?.takeIf { it.isNotBlank() }

        return SemesterSettingsLogic.stateOf(
            currentWeek = snapshot.currentWeek,
            semesterWeekCount = snapshot.settings.semesterWeekCount,
            startDate = snapshot.settings.semesterStartDate?.toLocalDate(),
        ).copy(
            activeProfileName = activeProfileName,
            activeTimeSchemeName = activeTimeSchemeName,
            // 开关真值：Dart 默认 true，但用户关过就是 false（不能写死 true）。
            holidayMarkingEnabled = settings.enableHolidayMarking,
            weatherCityName = weatherCityName?.takeIf { it.isNotBlank() },
            partnerBound = partnerBound,
        )
    }
}
