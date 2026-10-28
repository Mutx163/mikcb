package com.mutx163.qingyu.pages.export

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.util.TimeZone

/**
 * ICS 分享契约（[IcsShareLogic]）单元测试 —— I3A。
 *
 * **期望值全部手推，不从 Kotlin 实现里抄**：
 * - 文件名：Dart `IcsExportService.buildFileName`（`lib/services/ics_export_service.dart:268-281`）
 *   + `_sanitizeFileNameSegment`（`:726-740`）：空白折 `_`、控制字符与 `<>:"/\|?*` 换 `_`、
 *   连续 `_` 压成一个、去首尾 ` ._`、洗完为空退回 `timetable`；日期 `yyyyMMdd`（`:651-655`）。
 * - MIME / action / extras 键：Android 框架 `Intent` 的公开常量字符串（`text/calendar` 是 RFC 5545）。
 * - authority：manifest 的 `${applicationId}.fileprovider`，`applicationId` 见
 *   `android/app/build.gradle:48`，变体后缀见同文件 `applicationIdSuffix`。
 * - text / subject：ARB `icsExportShareText` / `icsExportShareSubject` 的 zh 值。
 */
class IcsShareLogicTest {

    private val appId = "com.mutx163.qingyu"

    // 2026-03-02 是周一，2026-07-05 是周日（学期 18 周的末周日）。
    private val from = LocalDate.of(2026, 3, 2)
    private val to = LocalDate.of(2026, 7, 5)

    // ── 文件名：正常 / 非法字符 / 跨时区 ──

    @Test
    fun `文件名是课表名加起止日期`() {
        // "2026 春" 里的空格按 Dart 规则折成下划线 → 2026_春；日期补零成 8 位
        val spec = IcsShareLogic.spec(appId, "2026 春", from, to)
        assertEquals("2026_春-20260302-20260705.ics", spec.fileName)
    }

    @Test
    fun `文件名把非法字符换成下划线`() {
        // 以下 10 个字符全在 Dart 的禁用集合 <>:"/\|?* 里，逐个换成 _（相邻的不产生连续 __）
        val name = "a/b:c*d?e\"f<g>h|i\\j"
        val spec = IcsShareLogic.spec(appId, name, LocalDate.of(2026, 1, 1), LocalDate.of(2026, 1, 2))
        assertEquals("a_b_c_d_e_f_g_h_i_j-20260101-20260102.ics", spec.fileName)
    }

    @Test
    fun `文件名把连续下划线压成一个并去掉首尾空白`() {
        // 先折空白（"第1学期 / 2026" → "第1学期_/_2026"），再把 / 换 _ 得到三个相连下划线 → 压成一个
        val spec = IcsShareLogic.spec(appId, "第1学期 / 2026", from, to)
        assertEquals("第1学期_2026-20260302-20260705.ics", spec.fileName)
    }

    @Test
    fun `课表名全是空白时退回 timetable`() {
        val spec = IcsShareLogic.spec(appId, "   ", from, to)
        assertEquals("timetable-20260302-20260705.ics", spec.fileName)
    }

    @Test
    fun `文件名只吃日历日期，不吃默认时区`() {
        // 钉的是「判据是日历日期而不是带时刻的时间戳」：把默认时区从 UTC+14 换到 UTC-11，
        // 同一对 LocalDate 必须给出同一个文件名。（LocalDate 本身无时区，这条防的是
        // 实现改用 Instant/ZoneId.systemDefault() 后在某些时区把日期算偏一天。）
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Pacific/Kiritimati")) // UTC+14
            val east = IcsShareLogic.spec(appId, "2026 春", from, to)
            TimeZone.setDefault(TimeZone.getTimeZone("Pacific/Niue")) // UTC-11
            val west = IcsShareLogic.spec(appId, "2026 春", from, to)

            assertEquals("2026_春-20260302-20260705.ics", east.fileName)
            assertEquals(east.fileName, west.fileName)
        } finally {
            TimeZone.setDefault(original)
        }
    }

    // ── MIME / action / extras ──

    @Test
    fun `MIME 是 text-calendar 且 action 是 SEND`() {
        val spec = IcsShareLogic.spec(appId, "2026 春", from, to)
        assertEquals("text/calendar", spec.mimeType)
        assertEquals("android.intent.action.SEND", spec.action)
    }

    @Test
    fun `extras 键用 Android 框架常量值`() {
        val spec = IcsShareLogic.spec(appId, "2026 春", from, to)
        assertEquals("android.intent.extra.STREAM", spec.extraStreamKey)
        assertEquals("android.intent.extra.TEXT", spec.extraTextKey)
        assertEquals("android.intent.extra.SUBJECT", spec.extraSubjectKey)
    }

    @Test
    fun `附言与主题沿用 ARB 文案`() {
        // 已存在的 ARB 文案，本批不新造：`这是来自轻屿课表的日历文件` / `轻屿课表日历`
        val spec = IcsShareLogic.spec(appId, "2026 春", from, to)
        assertEquals("这是来自轻屿课表的日历文件", spec.text)
        assertEquals("轻屿课表日历", spec.subject)
    }

    @Test
    fun `不设选择器标题以便不新造文案`() {
        val spec = IcsShareLogic.spec(appId, "2026 春", from, to)
        assertNull(spec.chooserTitle)
        assertTrue(spec.grantReadPermission)
        assertEquals("2026_春-20260302-20260705.ics", spec.clipDataLabel)
    }

    // ── FileProvider authority 契约 ──

    @Test
    fun `authority 由 applicationId 加 fileprovider 后缀组成`() {
        assertEquals("com.mutx163.qingyu.fileprovider", IcsShareLogic.fileProviderAuthority(appId))
        // 变体后缀必须跟着走，否则只有正式包能分享（build.gradle 的 applicationIdSuffix）
        assertEquals(
            "com.mutx163.qingyu.debug.fileprovider",
            IcsShareLogic.fileProviderAuthority("com.mutx163.qingyu.debug"),
        )
        assertEquals(
            "com.mutx163.qingyu.ui.fileprovider",
            IcsShareLogic.fileProviderAuthority("com.mutx163.qingyu.ui"),
        )
        assertEquals(
            "com.mutx163.qingyu.fileprovider",
            IcsShareLogic.spec(appId, "2026 春", from, to).providerAuthority,
        )
    }

    @Test
    fun `空的 applicationId 直接拒绝而不是生成假 authority`() {
        assertThrows(IllegalArgumentException::class.java) {
            IcsShareLogic.fileProviderAuthority("   ")
        }
    }

    // ── 缓存目录与 content Uri 拼装规则 ──

    @Test
    fun `文件写进被 provider 路径覆盖的 ics-export 目录`() {
        val spec = IcsShareLogic.spec(appId, "2026 春", from, to)
        // 相对 cacheDir 的路径
        assertEquals("ics-export/2026_春-20260302-20260705.ics", spec.localRelativePath)
        // <cache-path path="ics-export/"> 必须覆盖我们写入的目录，否则 getUriForFile 找不到根
        assertEquals("ics-export/", IcsShareLogic.providerCachePath())
        assertTrue(spec.localRelativePath.startsWith(IcsShareLogic.providerCachePath()))
        assertEquals("ics-export/x.ics", IcsShareLogic.shareRelativePath("x.ics"))
    }

    @Test
    fun `content Uri 形状判据认 authority 加 cache-path 的 name`() {
        val authority = "com.mutx163.qingyu.fileprovider"
        // FileProvider 生成的是 content://<authority>/<cache-path name>/<相对路径>
        assertTrue(IcsShareLogic.contentUriMatches(authority, authority, "ics_export"))
        // authority 漂了（比如忘了带变体后缀）
        assertFalse(IcsShareLogic.contentUriMatches(authority, "com.mutx163.qingyu.debug.fileprovider", "ics_export"))
        // 第一段不是 xml 里 cache-path 的 name
        assertFalse(IcsShareLogic.contentUriMatches(authority, authority, "cache"))
        assertFalse(IcsShareLogic.contentUriMatches(authority, authority, null))
        assertFalse(IcsShareLogic.contentUriMatches(authority, null, "ics_export"))
    }
}
