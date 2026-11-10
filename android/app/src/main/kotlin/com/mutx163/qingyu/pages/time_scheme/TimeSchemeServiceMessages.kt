package com.mutx163.qingyu.pages.time_scheme

/**
 * 服务层消息 payload → 屏上文案（`lib/l10n/service_message_localizer.dart` 里
 * 「时间模板」那几支的 Kotlin 侧对应物）。
 *
 * ## payload 长什么样
 *
 * Dart 的 `encodeServiceMessage(code, args)` 编码成 `code` 或 `code|key=value|...`
 * （分隔符 `|`，键值分隔符第一个 `=`）。仓储/校验函数返回的就是这种串，
 * 例如 `section_end_must_after_start|sectionNumber=3`。
 *
 * ## 为什么必须本地化而不是直接显示码
 *
 * 直接把 `invalid_time_format` 摆到 Toast 上就是「给用户看英文变量名」。Dart 侧
 * 在 UI 边界统一走 `localizeServiceMessage`，本对象是同一位置在 Kotlin 侧的落点：
 * **凡是仓储/校验返回码的地方，宿主都过一遍 [localize]**。
 *
 * ## 文案与 ARB 逐字对齐
 *
 * 每条文案都是 ARB 里已有的 `serviceMsg*` 键（`TimeSchemeServiceMessagesParityTest`
 * 机械对拍），本文件不新造任何一句。认不出的码**原样返回**整个 payload ——
 * 与 Dart 侧「不猜语义」的兜底一致（宁可露出码，也不编一句可能与真实原因不符的话）。
 */
object TimeSchemeServiceMessages {

    // ── 时间模板族 ──
    val timeSchemeNotFound = TimeSchemeManagementText("serviceMsgTimeSchemeNotFound", "时间模板不存在")
    val timeSchemeSectionsInsufficient = TimeSchemeManagementText(
        "serviceMsgTimeSchemeSectionsInsufficient",
        "所选时间模板节次数不足，无法覆盖第 {startSection}～{endSection} 节",
    )
    val sectionCountBelowUsage = TimeSchemeManagementText(
        "serviceMsgSectionCountBelowUsage",
        "有课排到第 {requiredMaxSection} 节",
    )
    val sectionCountBelowUsageDetail = TimeSchemeManagementText(
        "serviceMsgSectionCountBelowUsageDetail",
        "节次数不能小于已用最大节次 第 {requiredMaxSection} 节。正在使用：{profileName} · {courseName} 周 {dayOfWeek} 第 {startSection} 至 {endSection} 节 {usageType}",
    )

    // ── 节次表校验 ──
    val atLeastOneSectionRequired =
        TimeSchemeManagementText("serviceMsgAtLeastOneSectionRequired", "至少需要保留一节课的时间")
    val sectionEndMustAfterStart = TimeSchemeManagementText(
        "serviceMsgSectionEndMustAfterStart",
        "第 {sectionNumber} 节结束时间必须晚于开始时间，暂不支持跨 0 点课程",
    )
    val sectionStartBeforePreviousEnd = TimeSchemeManagementText(
        "serviceMsgSectionStartBeforePreviousEnd",
        "第 {sectionNumber} 节开始时间不能早于上一节的结束时间",
    )

    /**
     * 编辑期的**非阻塞**重叠提示（2026-11-10 新增，用户口径）。
     *
     * 与上面那条的区别是语义而不是措辞：上面是「服务层校验失败的码」，出现即代表这次编辑
     * 被拒；这一条只挂在编辑器页的提示行上——**允许先把时间改乱、保存时才拦**。
     * 因此句子里必须有「保存前请调整」这层意思，不能读成「不能这么改」。
     */
    val sectionTimeOverlap = TimeSchemeManagementText(
        "serviceMsgSectionTimeOverlap",
        "第 {sectionNumber} 节时间与上一节重叠，保存前请调整",
    )
    val sectionCrossesMidnight = TimeSchemeManagementText(
        "serviceMsgSectionCrossesMidnight",
        "第 {sectionNumber} 节会跨到次日，当前暂不支持跨 0 点课程",
    )
    val invalidTimeFormat = TimeSchemeManagementText("serviceMsgInvalidTimeFormat", "时间格式不正确")

    // ── 快捷生成参数校验 ──
    val classDurationMustPositive =
        TimeSchemeManagementText("serviceMsgClassDurationMustPositive", "上课时长必须大于 0")
    val breakDurationMustNonNegative =
        TimeSchemeManagementText("serviceMsgBreakDurationMustNonNegative", "课间时长不能小于 0")
    val atLeastOnePeriodSection =
        TimeSchemeManagementText("serviceMsgAtLeastOnePeriodSection", "至少需要设置一个时段的节次数")
    val periodStartTimeRequired =
        TimeSchemeManagementText("serviceMsgPeriodStartTimeRequired", "请为有节次的时段设置第一节开始时间")

    // ── 使用情况详情里的「占用方式」两个短标签 ──
    val usageTypeOverride = TimeSchemeManagementText("serviceMsgUsageTypeOverride", "副时间模板")
    val usageTypeProfile = TimeSchemeManagementText("serviceMsgUsageTypeProfile", "课表主时间模板")

    /** 供机械化对拍：本对象拥有的全部 ARB 键。 */
    val allTexts: List<TimeSchemeManagementText> by lazy {
        listOf(
            timeSchemeNotFound,
            timeSchemeSectionsInsufficient,
            sectionCountBelowUsage,
            sectionCountBelowUsageDetail,
            atLeastOneSectionRequired,
            sectionEndMustAfterStart,
            sectionStartBeforePreviousEnd,
            sectionTimeOverlap,
            sectionCrossesMidnight,
            invalidTimeFormat,
            classDurationMustPositive,
            breakDurationMustNonNegative,
            atLeastOnePeriodSection,
            periodStartTimeRequired,
            usageTypeOverride,
            usageTypeProfile,
        )
    }

    /**
     * 本地化一条 service message payload。
     *
     * - `code` 形式与 `code|k=v|…` 形式都接受；
     * - 参数缺失按空串插值（Dart `_intArg(resolvedArgs, x) ?? 0` 的口径是 0，
     *   这里数字型参数缺省补 `0`，字符串型补空串 —— 与 Dart 逐条对齐）；
     * - 认不出的码**原样返回入参**（含参数），不猜。
     */
    fun localize(payload: String?): String {
        if (payload.isNullOrEmpty()) return ""
        val parsed = parse(payload)
        return localizeCode(parsed.code, parsed.args) ?: payload
    }

    private fun localizeCode(code: String, args: Map<String, String>): String? = when (code) {
        "time_scheme_not_found" -> timeSchemeNotFound.text
        "time_scheme_sections_insufficient" -> timeSchemeSectionsInsufficient.filled(
            "startSection" to numberArg(args, "startSection"),
            "endSection" to numberArg(args, "endSection"),
        )
        "section_count_below_usage" -> sectionCountBelowUsage.filled(
            "requiredMaxSection" to numberArg(args, "requiredMaxSection"),
        )
        "section_count_below_usage_detail" -> {
            // usageType 本身是另一条 service message 码（usage_type_override /
            // usage_type_profile），必须递归本地化再插值 —— 直接插码会把
            // `usage_type_override` 这串 ASCII 摆到用户面前。
            val usageTypeCode = args["usageType"]?.toString().orEmpty()
            val usageTypeText = if (usageTypeCode.isEmpty()) {
                ""
            } else {
                localizeCode(usageTypeCode, emptyMap()) ?: usageTypeCode
            }
            sectionCountBelowUsageDetail.filled(
                "requiredMaxSection" to numberArg(args, "requiredMaxSection"),
                "profileName" to stringArg(args, "profileName"),
                "courseName" to stringArg(args, "courseName"),
                "dayOfWeek" to numberArg(args, "dayOfWeek"),
                "startSection" to numberArg(args, "startSection"),
                "endSection" to numberArg(args, "endSection"),
                "usageType" to usageTypeText,
            )
        }
        "at_least_one_section_required" -> atLeastOneSectionRequired.text
        "section_end_must_after_start" -> sectionEndMustAfterStart.filled(
            "sectionNumber" to numberArg(args, "sectionNumber"),
        )
        "section_start_before_previous_end" -> sectionStartBeforePreviousEnd.filled(
            "sectionNumber" to numberArg(args, "sectionNumber"),
        )
        "section_crosses_midnight" -> sectionCrossesMidnight.filled(
            "sectionNumber" to numberArg(args, "sectionNumber"),
        )
        "invalid_time_format" -> invalidTimeFormat.text
        "class_duration_must_positive" -> classDurationMustPositive.text
        "break_duration_must_non_negative" -> breakDurationMustNonNegative.text
        "at_least_one_period_section" -> atLeastOnePeriodSection.text
        "period_start_time_required" -> periodStartTimeRequired.text
        "usage_type_override" -> usageTypeOverride.text
        "usage_type_profile" -> usageTypeProfile.text
        else -> null
    }

    /** Dart `parseServiceMessage` 的等价物；`key=` 之前不是正数下标时忽略该段。 */
    internal fun parse(payload: String): ParsedServiceMessage {
        val parts = payload.split(SEPARATOR)
        val code = parts.first()
        val args = LinkedHashMap<String, String>()
        for (part in parts.drop(1)) {
            val index = part.indexOf('=')
            if (index <= 0) continue
            args[part.substring(0, index)] = part.substring(index + 1)
        }
        return ParsedServiceMessage(code, args)
    }

    private fun numberArg(args: Map<String, String>, key: String): String =
        (args[key]?.toIntOrNull() ?: 0).toString()

    private fun stringArg(args: Map<String, String>, key: String): String = args[key].orEmpty()

    /** 与 core `ServiceMessage.SEPARATOR` 同一个字符（不跨包引用，保持本文件自洽）。 */
    private const val SEPARATOR = "|"
}

/** 拆开的 payload：码 + 参数表（值一律当字符串，与 Dart `parseServiceMessage` 一致）。 */
internal data class ParsedServiceMessage(val code: String, val args: Map<String, String>)
