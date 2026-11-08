package com.mutx163.qingyu.pages.about

import com.mutx163.qingyu.core.MiniJson
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 支持作者页模型层测试。
 *
 * 期望值来源（独立于实现）：
 * - 解析/排序：逐条对照 `support_creator_service.dart` 的 `fromJson` /
 *   `_compareDonorDateDesc`（:53-103）行号语义；
 * - 文案：直读 `i18n/app_zh.arb` 对拍（不手抄）；
 * - 边界：空名单、非 Map 元素、缺 name、日期不可解析，人推得出。
 */
class SupportCreatorModelTest {

    private fun donor(name: String, date: String? = null, amount: String? = null, message: String? = null) =
        linkedMapOf<String, Any?>(
            "name" to name,
            "date" to date,
            "amount" to amount,
            "message" to message,
        )

    // ---------- 解析 ----------

    @Test
    fun `字段逐项trim且name缺省为空串`() {
        val data = parseSupportDonorData(
            mapOf(
                "title" to "  鸣谢  ",
                "subtitle" to " 说明 ",
                "subtitleNote" to " 留言说明 ",
                "updatedAt" to " 2026-10-20 ",
                "donors" to listOf(donor("  张三  ", " 2026-10-01 ", " ￥10 ", " 加油 ")),
            ),
        )
        assertEquals("鸣谢", data.title)
        assertEquals("说明", data.subtitle)
        assertEquals("留言说明", data.subtitleNote)
        assertEquals("2026-10-20", data.updatedAt)
        assertEquals("张三", data.donors[0].name)
        assertEquals("2026-10-01", data.donors[0].date)
        assertEquals("￥10", data.donors[0].amount)
        assertEquals("加油", data.donors[0].message)
    }

    @Test
    fun `name为空的条目被丢弃`() {
        val data = parseSupportDonorData(
            mapOf(
                "donors" to listOf(
                    donor("有名字"),
                    donor("   "),
                    donor(""),
                ),
            ),
        )
        assertEquals(listOf("有名字"), data.donors.map { it.name })
    }

    @Test
    fun `非Map元素被跳过且缺donors字段为空表`() {
        val data = parseSupportDonorData(
            mapOf("donors" to listOf("字符串", 42, donor("正常"))),
        )
        assertEquals(listOf("正常"), data.donors.map { it.name })
        assertTrue(parseSupportDonorData(emptyMap()).donors.isEmpty())
    }

    @Test
    fun `缺失的可选字段为null`() {
        val data = parseSupportDonorData(mapOf("donors" to listOf(mapOf("name" to "只有名字"))))
        assertNull(data.title)
        assertNull(data.subtitle)
        assertNull(data.subtitleNote)
        assertNull(data.updatedAt)
        assertNull(data.donors[0].date)
        assertNull(data.donors[0].amount)
        assertNull(data.donors[0].message)
    }

    @Test
    fun `非字符串的donors元素字段不被当成字符串`() {
        val data = parseSupportDonorData(
            mapOf("donors" to listOf(linkedMapOf<String, Any?>("name" to "甲", "amount" to 42))),
        )
        // Dart `as String?` 对 int 会抛错；Kotlin 侧 as? String 得 null——
        // 已知口径差：真实数据里 amount 恒为字符串，这条钉住的是「不崩且不误读」。
        assertNull(data.donors[0].amount)
    }

    // ---------- 排序 ----------

    @Test
    fun `可按日期解析时新的在前`() {
        val data = parseSupportDonorData(
            mapOf(
                "donors" to listOf(
                    donor("旧", "2026-01-01"),
                    donor("新", "2026-10-20"),
                    donor("中", "2026-05-05"),
                ),
            ),
        )
        assertEquals(listOf("新", "中", "旧"), data.donors.map { it.name })
    }

    @Test
    fun `带时刻的日期按时刻倒序`() {
        val data = parseSupportDonorData(
            mapOf(
                "donors" to listOf(
                    donor("早", "2026-10-20T08:00:00.000"),
                    donor("晚", "2026-10-20T20:00:00.000"),
                ),
            ),
        )
        assertEquals(listOf("晚", "早"), data.donors.map { it.name })
    }

    @Test
    fun `能解析的日期排在任何不可解析日期之前`() {
        val data = parseSupportDonorData(
            mapOf(
                "donors" to listOf(
                    donor("无日期"),
                    donor("有日期", "2020-01-01"),
                ),
            ),
        )
        // Dart :79-82 —— 一边能解析就它在前，哪怕年份很旧。
        assertEquals(listOf("有日期", "无日期"), data.donors.map { it.name })
    }

    @Test
    fun `都不可解析时按原始字符串倒序`() {
        val data = parseSupportDonorData(
            mapOf(
                "donors" to listOf(
                    donor("A", "第二期"),
                    donor("B", "第一期"),
                ),
            ),
        )
        // Dart :84-88 —— 原始串倒序："第二期" > "第一期"（按码点）。
        assertEquals(listOf("A", "B"), data.donors.map { it.name })
    }

    @Test
    fun `只有一边有不可解析日期时它在前`() {
        val data = parseSupportDonorData(
            mapOf(
                "donors" to listOf(
                    donor("空的"),
                    donor("有原始日期", "早期支持"),
                ),
            ),
        )
        assertEquals(listOf("有原始日期", "空的"), data.donors.map { it.name })
    }

    @Test
    fun `两条完全相等时比较结果为0`() {
        assertEquals(0, compareDonorDateDesc(SupportDonorEntry("甲"), SupportDonorEntry("乙")))
    }

    // ---------- 文案与 ARB 对拍 ----------

    private fun arbString(key: String): String {
        val candidates = listOf(
            File("../../i18n/app_zh.arb"),
            File("../i18n/app_zh.arb"),
            File("i18n/app_zh.arb"),
        )
        val file = candidates.firstOrNull { it.isFile }
            ?: error("找不到 i18n/app_zh.arb，工作目录=${File(".").absolutePath}")
        @Suppress("UNCHECKED_CAST")
        val json = MiniJson.parse(file.readText(Charsets.UTF_8)) as Map<String, Any?>
        return json[key] as? String ?: error("ARB 缺少键 $key")
    }

    @Test
    fun `arbStringsMatchModel`() {
        val pairs = listOf(
            "supportCreatorTitle" to SupportCreatorStrings.pageTitle,
            "supportHeroTitle" to SupportCreatorStrings.heroTitle,
            "supportHeroSubtitle" to SupportCreatorStrings.heroSubtitle,
            "supportMethodTitle" to SupportCreatorStrings.methodTitle,
            "wechatLabel" to SupportCreatorStrings.wechatLabel,
            "alipayLabel" to SupportCreatorStrings.alipayLabel,
            "scanQrWechatTitle" to SupportCreatorStrings.scanQrWechatTitle,
            "scanQrAlipayTitle" to SupportCreatorStrings.scanQrAlipayTitle,
            "scanQrSubtitle" to SupportCreatorStrings.scanQrSubtitle,
            "supportWeChatHint" to SupportCreatorStrings.weChatHint,
            "supportAlipayHint" to SupportCreatorStrings.alipayHint,
            "supportTapQrHint" to SupportCreatorStrings.tapQrHint,
            "supportSaveShort" to SupportCreatorStrings.saveShort,
            "saveToGallery" to SupportCreatorStrings.saveToGallery,
            "savedToGallery" to SupportCreatorStrings.savedToGallery,
            "saveToGalleryFailed" to SupportCreatorStrings.saveToGalleryFailed,
            "donorListTitle" to SupportCreatorStrings.donorListTitle,
            "donorListEmpty" to SupportCreatorStrings.donorListEmpty,
            "donorListLoadFailed" to SupportCreatorStrings.donorListLoadFailed,
            "reloadAction" to SupportCreatorStrings.reloadAction,
            "supportRunningBadge" to SupportCreatorStrings.runningBadge,
            "supportChipAdapters" to SupportCreatorStrings.chipAdapters,
            "supportChipFixes" to SupportCreatorStrings.chipFixes,
            "supportChipPolish" to SupportCreatorStrings.chipPolish,
            "supportCompleteThanks" to SupportCreatorStrings.completeThanks,
            "supportConfirmedShort" to SupportCreatorStrings.confirmedShort,
            "closeAction" to SupportCreatorStrings.closeAction,
        )
        for ((key, value) in pairs) {
            assertEquals("ARB 键 $key 与模型不一致", arbString(key), value)
        }
    }

    @Test
    fun `带参文案与ARB占位符一致`() {
        assertEquals(
            arbString("updatedAtLabel").replace("{time}", "2026-10-20"),
            SupportCreatorStrings.updatedAtLabel("2026-10-20"),
        )
        assertEquals(
            arbString("saveFailedWithError").replace("{error}", "磁盘已满"),
            SupportCreatorStrings.saveFailedWithError("磁盘已满"),
        )
    }

    @Test
    fun `支持方式切换文案`() {
        assertEquals(SupportCreatorStrings.scanQrWechatTitle, SupportCreatorStrings.scanTitleFor(SupportMethod.WECHAT))
        assertEquals(SupportCreatorStrings.scanQrAlipayTitle, SupportCreatorStrings.scanTitleFor(SupportMethod.ALIPAY))
        assertEquals(SupportCreatorStrings.weChatHint, SupportCreatorStrings.hintFor(SupportMethod.WECHAT))
        assertEquals(SupportCreatorStrings.alipayHint, SupportCreatorStrings.hintFor(SupportMethod.ALIPAY))
    }
}
