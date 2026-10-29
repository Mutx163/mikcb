package com.mutx163.qingyu.pages.sync

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 绑定 JSON 编解码（源：`lib/models/partner_timetable_binding.dart` 的 `toJson` / `fromJson`）。
 *
 * 两条必须钉住的行为：
 * 1. **往返不丢字段**——`linkedAt` / `lastImportedAt` / `sourceFileHash` 少写一个，
 *    用户每次拖周偏移都会把「什么时候绑的、来源文件哈希」静默洗掉；
 * 2. **坏值不炸整份**——外部数据（云同步/备份恢复）里某个字段类型不对，
 *    退回默认而不是让整份绑定读不出来。
 */
class CoupleBindingCodecTest {

    @Test
    fun roundTripsEveryField() {
        val binding = PartnerTimetableBindingModel(
            partnerName = "小屿",
            lastImportedAtIso = "2026-10-26T08:15:00.000",
            weekOffset = 2,
            mineColorHex = "#111111",
            partnerColorHex = "#222222",
            togetherColorHex = "#333333",
            partnerProfileId = "partner-imported",
            linkedAtIso = "2026-10-01T00:00:00.000",
            sourceFileHash = "abc123",
        )
        val parsed = CoupleBindingCodec.parse(CoupleBindingCodec.encode(binding))!!
        assertEquals(binding.partnerName, parsed.partnerName)
        assertEquals(binding.lastImportedAtIso, parsed.lastImportedAtIso)
        assertEquals(binding.weekOffset, parsed.weekOffset)
        assertEquals(binding.mineColorHex, parsed.mineColorHex)
        assertEquals(binding.partnerColorHex, parsed.partnerColorHex)
        assertEquals(binding.togetherColorHex, parsed.togetherColorHex)
        assertEquals(binding.partnerProfileId, parsed.partnerProfileId)
        assertEquals(binding.linkedAtIso, parsed.linkedAtIso)
        assertEquals(binding.sourceFileHash, parsed.sourceFileHash)
    }

    @Test
    fun omitsOptionalNulls() {
        val encoded = CoupleBindingCodec.encode(
            PartnerTimetableBindingModel(partnerName = "小屿", linkedAtIso = "2026-10-01T00:00:00.000"),
        )
        // Dart `toJson` 里 lastImportedAt / sourceFileHash 为 null 时不写这个键。
        assert(!encoded.contains("lastImportedAt")) { "lastImportedAt 不该出现：$encoded" }
        assert(!encoded.contains("sourceFileHash")) { "sourceFileHash 不该出现：$encoded" }
        assert(encoded.contains("linkedAt")) { "linkedAt 必须写：$encoded" }
    }

    @Test
    fun fallsBackToDefaultsForMissingFields() {
        val parsed = CoupleBindingCodec.parse("""{"partnerName":"  ","weekOffset":0}""")!!
        // partnerName 是空串时 Dart 不做 trim 兜底（只有缺键才回落），这里保持同样口径：
        // 键在就照读，缺键才回落「TA的课表」。
        assertEquals("  ", parsed.partnerName)
        assertEquals(CoupleTimetableSettingsLogic.MINE_COLOR_DEFAULT, parsed.mineColorHex)
        assertEquals(CoupleTimetableSettingsLogic.PARTNER_COLOR_DEFAULT, parsed.partnerColorHex)
        assertEquals(CoupleTimetableSettingsLogic.TOGETHER_COLOR_DEFAULT, parsed.togetherColorHex)
        assertEquals(CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID, parsed.partnerProfileId)
    }

    @Test
    fun missingPartnerNameFallsBackToPlaceholder() {
        val parsed = CoupleBindingCodec.parse("""{"weekOffset":0}""")!!
        assertEquals(CoupleTimetableSettingsLogic.PARTNER_NAME_FALLBACK, parsed.partnerName)
    }

    @Test
    fun clampsOutOfRangeWeekOffset() {
        assertEquals(15, CoupleBindingCodec.parse("""{"partnerName":"a","weekOffset":99}""")!!.weekOffset)
        assertEquals(-15, CoupleBindingCodec.parse("""{"partnerName":"a","weekOffset":-99}""")!!.weekOffset)
    }

    @Test
    fun toleratesWrongTypes() {
        // 外部数据里 weekOffset 是字符串、颜色是数字：不炸，按默认/可读值收下。
        val parsed = CoupleBindingCodec.parse(
            """{"partnerName":123,"weekOffset":"3","mineColorHex":42}""",
        )!!
        assertEquals("123", parsed.partnerName)
        assertEquals(0, parsed.weekOffset)
        assertEquals("42", parsed.mineColorHex)
    }

    @Test
    fun returnsNullForEmptyOrNonObject() {
        assertNull(CoupleBindingCodec.parse(null))
        assertNull(CoupleBindingCodec.parse("   "))
        assertNull(CoupleBindingCodec.parse("[1,2,3]"))
        assertNull(CoupleBindingCodec.parse("not json"))
    }
}
