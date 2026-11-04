package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.pages.import.warehouse.SemesterWeekUplift
import com.mutx163.qingyu.transfer.buildExpandedSections
import com.mutx163.qingyu.transfer.replaceImportedCoursesPreservingLocalFields
import com.mutx163.qingyu.transfer.syncImportedCourses
import kotlin.random.Random

/**
 * 导入三页的**纯逻辑**（选完文件之后的每一步判断都在这里，宿主只按顺序调）。
 *
 * ## 拆出来的理由
 *
 * 宿主（`composeP1/pages/import/ImportHosts.kt`）要 `Context` 与
 * `rememberLauncherForActivityResult`，进不了 JVM 单测；而「覆盖 / 更新到底写成
 * 什么样」「节次够不够」「配色要不要重排」这些**会改用户数据的判断**必须能测。
 * 所以判据全部下沉到本对象（与 `DataTransferHost` 把判断下沉到
 * `DataTransferImportLogic` 同一套做法）。
 *
 * ## 判据一条都不新造
 *
 * - 覆盖 / 更新：`transfer/ImportExportLogic.kt` 已迁完的
 *   [replaceImportedCoursesPreservingLocalFields] / [syncImportedCourses]（Dart
 *   `import_export_logic.dart` 的逐条对拍）；
 * - 节次补齐：[buildExpandedSections]（Dart `ensureImportSectionCapacity` 的算术部分）；
 * - 配色：[ImportSharedModel.applyRandomImportCourseColors] 与
 *   [ImportSharedModel.shouldPreserveLocalColorsOnImport]；
 * - 文案：[ImportSharedModel.buildImportResultMessage] / [ImportServiceMessages]。
 *
 * 本对象只负责「按 Dart 的顺序把这几件事串起来」，不复制任何一条判断。
 */
object ImportFlowModel {

    // ------------------------------------------------------------------
    // SAF 选文件的 MIME 候选
    // ------------------------------------------------------------------

    /**
     * `.ics` 的候选 MIME。`text/calendar` 是标准值；`text/x-vcalendar` 是很多日历应用
     * 实际写的旧值；`application/octet-stream` 兜底那些不报类型的 provider
     * （部分网盘把任意文件都当成二进制流）。
     *
     * 只放这三个：放通配符（星号斜杠星号）等于把整个文件系统摊开给用户选，Dart 侧也只允许 `.ics`。
     */
    val ICS_MIME_TYPES: List<String> = listOf(
        "text/calendar",
        "text/x-vcalendar",
        "application/octet-stream",
    )

    /**
     * 表格导入的候选 MIME：CSV 三种写法 + xlsx 一种 + 二进制兜底。
     *
     * `application/vnd.ms-excel` 是 Windows 上 `.csv` 常见的注册类型，很多 provider
     * 就是按它报的——漏了它用户会看到「文件是灰的、选不了」。
     */
    val SPREADSHEET_MIME_TYPES: List<String> = listOf(
        "text/csv",
        "text/comma-separated-values",
        "text/plain",
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "application/octet-stream",
    )

    /** 小写扩展名（不含点）；没有扩展名返回空串。 */
    fun extensionOf(fileName: String?): String {
        val name = fileName?.trim().orEmpty()
        val dot = name.lastIndexOf('.')
        if (dot < 0 || dot == name.length - 1) return ""
        return name.substring(dot + 1).lowercase()
    }

    fun isIcsFile(fileName: String?): Boolean = extensionOf(fileName) == "ics"

    /**
     * 表格导入支持的后缀：`.csv` 与 `.xlsx`。
     *
     * 后缀**不是**硬门槛（SAF 的 displayName 可能缺失或带怪后缀），它是「要不要走
     * xlsx 容器解码」的判据；内容不对由解析层给具体错误。
     */
    fun isSpreadsheetFile(fileName: String?): Boolean {
        val ext = extensionOf(fileName)
        return ext == "csv" || ext == "xlsx"
    }

    fun isXlsxFile(fileName: String?): Boolean = extensionOf(fileName) == "xlsx"

    // ------------------------------------------------------------------
    // 覆盖 / 更新：最终课程表长什么样
    // ------------------------------------------------------------------

    /**
     * 一次导入的最终结果。[importedCount] 是 toast 里的「N 条」：
     * - 覆盖导入 = 落盘后的课程总数（Dart `importOverwriteCount`）；
     * - 更新课表 = 新增 + 更新（Dart `importUpdatedCount`）。
     */
    data class ApplyPlan(
        val courses: List<Course>,
        val addedCount: Int,
        val updatedCount: Int,
        val replaceExisting: Boolean,
    ) {
        /** 屏上「多少条」的计数口径（见类注释）。 */
        val importedCount: Int
            get() = if (replaceExisting) courses.size else addedCount + updatedCount
    }

    /**
     * 把导入侧课程合进本地课程表。
     *
     * - `replaceExisting = true`（覆盖导入）：本地课程**整份换掉**，但同名课的本地
     *   共享字段（颜色、文字色等）按 [preserveLocalColors] 决定留不留；
     * - `replaceExisting = false`（更新课表）：本地全留，逐条软匹配更新，没匹配的新增。
     *
     * 两条分支都走 Dart 逐条对拍过的实现，这里只切换分支。
     */
    fun planApply(
        existingCourses: List<Course>,
        importedCourses: List<Course>,
        replaceExisting: Boolean,
        preserveLocalColors: Boolean,
    ): ApplyPlan {
        if (replaceExisting) {
            val replaced = replaceImportedCoursesPreservingLocalFields(
                existingCourses = existingCourses,
                importedCourses = importedCourses,
                preserveLocalColors = preserveLocalColors,
            )
            return ApplyPlan(
                courses = replaced,
                addedCount = replaced.size,
                updatedCount = 0,
                replaceExisting = true,
            )
        }
        val synced = syncImportedCourses(
            existingCourses = existingCourses,
            importedCourses = importedCourses,
            preserveLocalColors = preserveLocalColors,
        )
        return ApplyPlan(
            courses = synced.mergedCourses,
            addedCount = synced.addedCount,
            updatedCount = synced.updatedCount,
            replaceExisting = false,
        )
    }

    // ------------------------------------------------------------------
    // 节次容量
    // ------------------------------------------------------------------

    /** 最终课程表要用到的最大节次；没有课返回 0。 */
    fun requiredSectionCount(courses: List<Course>): Int = courses.maxOfOrNull { it.endSection } ?: 0

    /** 现有节次是否够用（配额判据：`required > current.size` 才要补）。 */
    fun needsSectionExpansion(currentSections: List<SectionTime>, requiredCount: Int): Boolean =
        requiredCount > currentSections.size

    /**
     * 补节后的节次表（不补时原样返回同一份内容的拷贝）。
     *
     * 补节算术在 [buildExpandedSections]：锚点是「最后一条能解析的结束时间」，
     * 推不出就停、超过当天 24:00 也停——绝不造出绕回凌晨的节次。
     */
    fun sectionsForImport(currentSections: List<SectionTime>, requiredCount: Int): List<SectionTime> =
        buildExpandedSections(currentSections, requiredCount)

    /**
     * 导入成功后要写入的学期总周数（Dart `timetable_import_export_service.dart:588-601`）：
     * 取「当前值」与「合并后课程的最大周次」中较大者——**只升不降**，封顶 **30** 周
     * （Dart `lib/domain/import_export_logic.dart:39` `maxAllowedSemesterWeekCount = 30`；
     * 不是 42——42 是月视图格数）。
     *
     * 算术**只在 [SemesterWeekUplift] 一处**，本函数是转发；教务回传
     * `WarehouseCourseWriteBack` 也调同一个对象，两处不得各写一份。
     */
    fun nextSemesterWeekCount(currentWeekCount: Int, courses: List<Course>): Int =
        SemesterWeekUplift.nextSemesterWeekCount(currentWeekCount, courses)

    // ------------------------------------------------------------------
    // 随机配色
    // ------------------------------------------------------------------

    /**
     * 按偏好给导入课程配色（Dart `coursesWithOptionalRandomColors`）。
     *
     * 关掉随机配色 ⇒ **原样返回**（连 copy 都不做）：覆盖导入时 `preserveLocalColors`
     * 还要按原色保留本地课程的颜色，这里先改一遍会把它冲掉。
     */
    fun coursesWithOptionalRandomColors(
        courses: List<Course>,
        prefs: ImportRandomColorPrefs,
        random: Random = Random.Default,
    ): List<Course> {
        if (!prefs.enabled) return courses
        return ImportSharedModel.applyRandomImportCourseColors(
            courses = courses,
            palette = ImportSharedModel.courseColorGroupPalette(prefs.groupId),
            assignMatchingTextColor = prefs.textColorEnabled,
            random = random,
        )
    }

    /** 覆盖导入时是否保留本地课程颜色（Dart `shouldPreserveLocalColorsOnImport`）。 */
    fun shouldPreserveLocalColors(replaceExisting: Boolean, randomColorsEnabled: Boolean): Boolean =
        ImportSharedModel.shouldPreserveLocalColorsOnImport(
            replaceExisting = replaceExisting,
            randomColorsEnabled = randomColorsEnabled,
        )

    // ------------------------------------------------------------------
    // 大小上限提示
    // ------------------------------------------------------------------

    /** 「20 MB」这种人类可读的体积（唯一出处是 [ImportSharedModel.formatByteBudget]）。 */
    fun formatSizeLimit(maxBytes: Int): String = ImportSharedModel.formatByteBudget(maxBytes.toLong())
}
