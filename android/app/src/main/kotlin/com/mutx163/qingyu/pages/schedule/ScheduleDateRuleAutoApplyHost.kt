package com.mutx163.qingyu.pages.schedule

import android.util.Log
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.calendar.ScheduleDateRuleAutoApply
import com.mutx163.qingyu.calendar.ScheduleDateRuleAutoApplyPort
import com.mutx163.qingyu.calendar.ScheduleDateRuleApplyResult
import com.mutx163.qingyu.calendar.ScheduleDateRuleApplyOutcome
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.LocationTimeGroup
import com.mutx163.qingyu.core.ScheduleDateRule
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.platform.PrefsKeyValueStore
import java.io.IOException
import java.time.LocalDateTime

/**
 * 把 [ScheduleDateRuleAutoApplyPort] 接到 `TimetableRepository` + 存档 prefs 上。
 *
 * 纯逻辑在 `calendar/ScheduleDateRuleAutoApply.kt`（已 L0 单测钉住）；这里只做两件事：
 * 读仓储快照、把「已套用签名」按 Dart 的原键写到盘上，方便壳在冷启动 / 规则保存后调用。
 *
 * 为什么签名单独存 prefs 而不是塞进设置模型：Dart 侧也是独立的
 * `schedule_date_rule_last_applied_signature` 键（`timetable_provider.dart`），
 * 同一档期只套一次靠的就是它；放进设置模型会被「设置重置」顺手清掉，导致重启后再套一遍。
 */
class RepositoryScheduleDateRulePort(
    private val repository: TimetableRepository,
    private val prefs: PrefsKeyValueStore,
) : ScheduleDateRuleAutoApplyPort {

    private val snapshot get() = repository.snapshot

    override val scheduleDateRules: List<ScheduleDateRule> get() = snapshot.scheduleDateRules
    override val timeSchemes: List<TimeScheme> get() = snapshot.timeSchemes
    override val profiles: List<TimetableProfile> get() = snapshot.profiles
    override val activeProfileId: String? get() = snapshot.activeProfileId
    override val courses: List<Course> get() = snapshot.courses
    override val settings: TimetableSettings get() = snapshot.settings
    override val locationTimeGroups: List<LocationTimeGroup> get() = snapshot.locationTimeGroups

    override var scheduleDateRuleLastAppliedSignature: String?
        get() = prefs.getString(ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE)
            ?.takeIf { it.isNotBlank() }
        set(value) {
            if (value.isNullOrBlank()) {
                prefs.remove(ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE)
            } else {
                prefs.putString(ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE, value)
            }
        }

    override fun persistTimetableState(
        profiles: List<TimetableProfile>,
        settings: TimetableSettings,
    ) {
        repository.replaceAllProfilesAndSettings(
            profiles = profiles,
            activeProfileId = repository.snapshot.activeProfileId,
            settings = settings,
        )
    }

    override fun saveScheduleDateRuleLastAppliedSignature(signature: String) {
        prefs.putString(ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE, signature)
    }

    /**
     * 云同步不需要单独通知：仓储变更本身会通过 `observe` 推给已经订阅它的
     * `CloudSyncController`（[persistTimetableState] 里已经 `notifyStateChanged`）。
     * 在这里再调一次只会让 UI 重渲染两遍。
     */
    override fun notifySyncDataChanged() = Unit

    override fun notifyStateChanged() {
        repository.notifyStateChanged()
    }

    override fun clearCurrentLiveCourseId() {
        repository.clearCurrentLiveCourseId()
    }
}

/**
 * 壳侧入口：到了日期规则的生效日就套用作息。
 *
 * 调用点（与 Dart `timetable_provider.dart` 对齐）：
 * - 冷启动首帧后一次；
 * - 日期规则新增 / 修改 / 删除保存成功之后各一次。
 */
object ScheduleDateRuleAutoApplyHost {

    /** 与 Dart `schedule_date_rule_last_applied_signature` 同一个键。 */
    const val KEY_LAST_APPLIED_SIGNATURE = "schedule_date_rule_last_applied_signature"

    fun applyDue(
        repository: TimetableRepository,
        prefs: PrefsKeyValueStore,
        now: LocalDateTime = LocalDateTime.now(),
    ): ScheduleDateRuleApplyResult {
        return try {
            ScheduleDateRuleAutoApply.applyDue(
                port = RepositoryScheduleDateRulePort(repository, prefs),
                now = now,
            )
        } catch (error: IOException) {
            // 落盘失败（磁盘满）：不能让冷启动 LaunchedEffect / 规则保存后的后台协程炸掉
            // （两处调用点都不在本文件的写作用域内，只能在共同入口兜）。
            // 签名没写成功 ⇒ 下次冷启动仍判「该套」自动重试；内存已被仓储契约保持原样。
            // NotDue 在这里表示「本次未生效」，调用方目前不消费返回值。
            Log.e("ScheduleDateRuleAutoApply", "applyDue persist failed; will retry next launch", error)
            ScheduleDateRuleApplyResult(ScheduleDateRuleApplyOutcome.NotDue)
        }
    }
}
