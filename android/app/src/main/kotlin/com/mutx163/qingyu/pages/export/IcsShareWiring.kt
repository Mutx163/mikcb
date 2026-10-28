package com.mutx163.qingyu.pages.export

import com.mutx163.qingyu.transfer.IcsCalendarEvent
import com.mutx163.qingyu.transfer.IcsSerializer
import java.time.LocalDate
import java.time.LocalDateTime

/**
 * ICS 导出「生成 → 分享」的**接线层**（I3）。
 *
 * 背景：[IcsSerializer] 产出的是 `.ics` 正文字符串（`transfer` 包）；[IcsShareLogic] 产出的是
 * 分享意图契约 [IcsShareSpec]（`pages.export` 包，含建议文件名 / `text/calendar` / extras / authority）。
 * 页面宿主如果把这两半各自 raw 拼出来（`adapter.share(content, profile.name, from, to)`），
 * 就再没有任何 JVM 测试能钉住「正文 ↔ 建议文件名 ↔ MIME」是否被正确配对——因为 `platform/`
 * 的适配器引 `android.*`，进不了单测 classpath（见 [com.mutx163.qingyu.platform.AndroidShareAdapter]
 * 的类注释）。
 *
 * 本层就是补这一刀：把「已生成的正文」和「派生出的契约」装进一个**可测的分享请求载荷**
 * [IcsShareRequest]，让契约测试能直接断言它的字段（正文 / `text/calendar` / 建议文件名）。
 *
 * 纯 Kotlin，无 Compose / Android 依赖，JVM 单测可直接跑。
 */
data class IcsShareRequest(
    /** [IcsSerializer.serializeCalendar] 的产物，**逐字节原样**传给适配器落盘（CRLF 与结尾换行都保留）。 */
    val content: String,
    /** 分享意图契约：建议文件名 / MIME / extras / authority 全在这里。 */
    val spec: IcsShareSpec,
) {
    /** 建议文件名（落盘名，同时作为分享出去的显示名）。 */
    val fileName: String
        get() = spec.fileName

    /** MIME 类型；契约恒为 [IcsShareLogic.MIME_TYPE_CALENDAR]（`text/calendar`）。 */
    val mimeType: String
        get() = spec.mimeType
}

/**
 * 分享请求的组装逻辑。
 *
 * **判据只有一份**：文件名 / MIME / authority / text / subject 全部委托给
 * [IcsShareLogic.spec]，本层不重算任何字符串（重算等于给同一件事造第二个判据来源）。
 */
object IcsShareWiring {

    /**
     * 由「已生成的 .ics 正文」+「课表名 + 区间（→ 建议文件名）」组装分享请求。
     *
     * 这是页面宿主在「导出成功 → 点分享」这一步唯一需要调用的一处。
     *
     * @throws IllegalArgumentException 正文为空白时——空文件分享出去是无效载荷
     *   （一份合法 `.ics` 至少含 `BEGIN:VCALENDAR` … `END:VCALENDAR`）。
     */
    fun requestFromSerialized(
        serializedContent: String,
        applicationId: String,
        profileName: String,
        from: LocalDate,
        to: LocalDate,
    ): IcsShareRequest {
        require(serializedContent.isNotBlank()) {
            "ICS 正文不能为空：拒绝组装分享请求（空文件分享出去是无效载荷）"
        }
        val spec = IcsShareLogic.spec(applicationId, profileName, from, to)
        return IcsShareRequest(content = serializedContent, spec = spec)
    }

    /**
     * 一步到位：先把事件序列化成 `.ics` 正文，再组装成分享请求。
     *
     * 供宿主（`ShellPageIndex` 的 `g3.icsExport` 分支）在拿到已收集事件时直接调用，
     * 避免它在自己那边重复「先 serialize 再 request」的两步串联、把中间态漏掉。
     *
     * `fromDateTime` / `toDateTime` 是给序列化器用的时刻（含时区语义，宿主按
     * `<LocalDate>.atStartOfDay()` 得到）；`from` / `to` 是给建议文件名用的日历日期。
     */
    fun requestFromEvents(
        calendarName: String,
        fromDateTime: LocalDateTime,
        toDateTime: LocalDateTime,
        generatedAt: LocalDateTime,
        events: List<IcsCalendarEvent>,
        applicationId: String,
        profileName: String,
        from: LocalDate,
        to: LocalDate,
    ): IcsShareRequest {
        val content = IcsSerializer.serializeCalendar(
            calendarName = calendarName,
            fromDate = fromDateTime,
            toDate = toDateTime,
            generatedAt = generatedAt,
            events = events,
        )
        return requestFromSerialized(content, applicationId, profileName, from, to)
    }
}
