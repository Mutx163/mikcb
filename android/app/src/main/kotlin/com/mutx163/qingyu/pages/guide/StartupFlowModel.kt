package com.mutx163.qingyu.pages.guide

import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

/**
 * 启动流程步骤枚举。
 */
enum class StartupStep {
    /** 旧版数据迁移检查（若检测到旧版包名） */
    MIGRATION_CHECK,

    /** 开学日期与周次初始化设置 */
    DATE_SETUP,

    /** 新手引导与权限指引 */
    GUIDE_TOUR,

    /** 启动流程全部就绪，进入主页 */
    COMPLETED
}

/**
 * 迁移流程操作意图。
 */
enum class MigrationFlowAction {
    /** 恢复备份 */
    RESTORE_BACKUP,

    /** 跳过迁移，作为全新应用启动 */
    SKIP
}

/**
 * 启动流程不可变状态快照。
 */
data class StartupFlowState(
    val currentStep: StartupStep = StartupStep.DATE_SETUP,
    val legacyPackageName: String? = null,
    val isOpeningOldApp: Boolean = false,
    val semesterStartDate: String? = null,
    val totalWeeks: Int = 20,
    val currentWeek: Int = 1,
    val isPrivacyAgreed: Boolean = false,
    val isCompleted: Boolean = false
)

/**
 * 开学日期与周次计算领域函数。
 */
object SemesterDateCalculator {

    const val MIN_TOTAL_WEEKS = 1
    const val MAX_TOTAL_WEEKS = 40
    const val DEFAULT_TOTAL_WEEKS = 20

    /**
     * 校验 YYYY-MM-DD 格式日期是否合法。
     */
    fun isValidDateFormat(dateStr: String?): Boolean {
        if (dateStr.isNullOrBlank()) return false
        return try {
            val parsed = LocalDate.parse(dateStr.trim())
            parsed.year in 2000..2100
        } catch (_: DateTimeParseException) {
            false
        }
    }

    /**
     * 将指定日期对齐到当周周一（周一为每周起始日）。
     */
    fun startOfWeek(date: LocalDate): LocalDate {
        val dayOfWeek = date.dayOfWeek.value // 1 (Mon) .. 7 (Sun)
        return date.minusDays((dayOfWeek - 1).toLong())
    }

    /**
     * 根据开学日期与目标日期计算自然周次。
     *
     * 规则（与 WeekCalculator 对齐）：
     * 1. 开学周的周一为第 1 周第一天。
     * 2. 目标日在开学周之前的，一律归为第 1 周。
     * 3. 超过 [totalWeeks] 的钳制到 [totalWeeks]。
     */
    fun calculateWeek(
        startDate: LocalDate,
        targetDate: LocalDate = LocalDate.now(),
        totalWeeks: Int = DEFAULT_TOTAL_WEEKS
    ): Int {
        val startMonday = startOfWeek(startDate)
        val targetMonday = startOfWeek(targetDate)
        val daysDiff = ChronoUnit.DAYS.between(startMonday, targetMonday)
        if (daysDiff < 0) {
            return 1
        }
        val calculated = (daysDiff / 7).toInt() + 1
        val safeTotal = totalWeeks.coerceIn(MIN_TOTAL_WEEKS, MAX_TOTAL_WEEKS)
        return calculated.coerceIn(1, safeTotal)
    }

    /**
     * 字符串入参版本的重载。
     */
    fun calculateWeek(
        startDateStr: String,
        targetDateStr: String? = null,
        totalWeeks: Int = DEFAULT_TOTAL_WEEKS
    ): Int {
        if (!isValidDateFormat(startDateStr)) return 1
        val startDate = LocalDate.parse(startDateStr.trim())
        val targetDate = if (targetDateStr != null && isValidDateFormat(targetDateStr)) {
            LocalDate.parse(targetDateStr.trim())
        } else {
            LocalDate.now()
        }
        return calculateWeek(startDate, targetDate, totalWeeks)
    }
}

/**
 * 启动引导状态机。
 */
class StartupFlowStateMachine(initialState: StartupFlowState = StartupFlowState()) {

    var state: StartupFlowState = initialState
        private set

    /**
     * 检测到旧版应用包名。
     */
    fun onDetectLegacyPackage(packageName: String?) {
        if (!packageName.isNullOrBlank()) {
            state = state.copy(
                legacyPackageName = packageName,
                currentStep = StartupStep.MIGRATION_CHECK
            )
        } else if (state.currentStep == StartupStep.MIGRATION_CHECK) {
            state = state.copy(
                legacyPackageName = null,
                currentStep = StartupStep.DATE_SETUP
            )
        }
    }

    /**
     * 设置打开旧版应用中状态。
     */
    fun setOpeningOldApp(opening: Boolean) {
        state = state.copy(isOpeningOldApp = opening)
    }

    /**
     * 处理迁移操作（跳过或恢复）。
     */
    fun onMigrationAction(action: MigrationFlowAction) {
        when (action) {
            MigrationFlowAction.SKIP -> {
                state = state.copy(currentStep = StartupStep.DATE_SETUP)
            }
            MigrationFlowAction.RESTORE_BACKUP -> {
                // 用户去备份后进入导入流程，引导直接切到开学日期/指南
                state = state.copy(currentStep = StartupStep.DATE_SETUP)
            }
        }
    }

    /**
     * 更新开学日期，并自动重新计算当前周次。
     * @return 日期格式是否合法
     */
    fun onUpdateSemesterStartDate(dateStr: String): Boolean {
        if (!SemesterDateCalculator.isValidDateFormat(dateStr)) {
            return false
        }
        val week = SemesterDateCalculator.calculateWeek(dateStr, totalWeeks = state.totalWeeks)
        state = state.copy(
            semesterStartDate = dateStr.trim(),
            currentWeek = week
        )
        return true
    }

    /**
     * 更新学期总周数，并自动修正当前周次。
     */
    fun onUpdateTotalWeeks(weeks: Int): Boolean {
        if (weeks !in SemesterDateCalculator.MIN_TOTAL_WEEKS..SemesterDateCalculator.MAX_TOTAL_WEEKS) {
            return false
        }
        val recalculatedWeek = state.semesterStartDate?.let {
            SemesterDateCalculator.calculateWeek(it, totalWeeks = weeks)
        } ?: state.currentWeek.coerceIn(1, weeks)

        state = state.copy(
            totalWeeks = weeks,
            currentWeek = recalculatedWeek
        )
        return true
    }

    /**
     * 确认开学日期设置，进入下一阶段（新手指南）。
     */
    fun onCompleteDateSetup(): Boolean {
        if (!canProceedFromDateSetup()) return false
        state = state.copy(currentStep = StartupStep.GUIDE_TOUR)
        return true
    }

    /**
     * 是否允许离开日期设置阶段。
     */
    fun canProceedFromDateSetup(): Boolean {
        return SemesterDateCalculator.isValidDateFormat(state.semesterStartDate) &&
            state.totalWeeks in SemesterDateCalculator.MIN_TOTAL_WEEKS..SemesterDateCalculator.MAX_TOTAL_WEEKS
    }

    /**
     * 隐私同意勾选变更。
     */
    fun onPrivacyConsentChanged(agreed: Boolean) {
        state = state.copy(isPrivacyAgreed = agreed)
    }

    /**
     * 完成全部引导流程。
     */
    fun onCompleteGuide(requirePrivacyConsent: Boolean = true): Boolean {
        if (requirePrivacyConsent && !state.isPrivacyAgreed) {
            return false
        }
        state = state.copy(
            currentStep = StartupStep.COMPLETED,
            isCompleted = true
        )
        return true
    }
}
