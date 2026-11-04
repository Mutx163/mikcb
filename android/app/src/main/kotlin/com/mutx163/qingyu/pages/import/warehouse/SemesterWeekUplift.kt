package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.transfer.maxCourseWeek

/**
 * 导入成功后「学期总周数」的**唯一抬升实现**。
 *
 * ## Dart 真值（带行号）
 *
 * - `lib/domain/import_export_logic.dart:39`
 *   `static const int maxAllowedSemesterWeekCount = 30;`
 * - `lib/domain/import_export_logic.dart:57-69` `maxCourseWeek(...)`：
 *   空课表回退当前值、否则取 `normalizedCustomWeeks?.last ?? endWeek`，
 *   两处都 `clamp(1, 30)`。
 * - `lib/services/timetable_import_export_service.dart:588-601` `importParsedCourses`：
 *   `maxCourseWeek` 后再 `clamp(1, 30)`，然后**只升不降**
 *   （`capped > 当前 ? capped : 当前`）。
 *
 * **上限是 30 周，不是 42**。早前 warehouse 交付说明里的「封顶 42」是错的——
 * 42 是月视图固定 6×7 格数，与学期周数无关。`transfer/ImportExportLogic.kt:49`
 * 的 `MAX_ALLOWED_SEMESTER_WEEK_COUNT` 也是 30，与本函数同一常量。
 *
 * ## 为什么放在 `pages/import/warehouse/`
 *
 * `scripts/test-kotlin-module.ps1` 的 `-Module pages/import/warehouse` 只收该子目录，
 * 收不到父目录的 `ImportFlowModel.kt`；而 `-Module pages/import` 会递归收子目录。
 * 放在这里，两条 L0 路径都能引用同一份实现，避免「表格导入」与「教务回传」各写一份后漂移。
 *
 * 两条调用方（[ImportFlowModel.nextSemesterWeekCount] 与
 * `WarehouseCourseWriteBack`）都必须调本对象，**不要复制这段算术**。
 */
object SemesterWeekUplift {

    /**
     * 取「当前值」与「课程最大周次」中较大者——只升不降，两者都已按 30 周封顶。
     *
     * 课程为空时保持当前值（Dart 在空导入时更早返回，此分支只为防御）。
     */
    fun nextSemesterWeekCount(currentWeekCount: Int, courses: List<Course>): Int =
        maxOf(currentWeekCount, maxCourseWeek(courses, currentWeekCount))
}
