package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.platform.CouplePartnerPortImpl
import com.mutx163.qingyu.sync.computeContentSha256
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.util.Locale

/**
 * 落盘/云端标识在非拉丁 Locale 下必须仍是 ASCII 十六进制。
 *
 * 两处曾用 `"%02x".format(...)`（隐式走默认 Locale）：`ar-EG` / `fa-IR` 等环境下
 * `%02x` 会产出非 ASCII 数字字形，同一份数据在两端算出的哈希/端点 id 不同，
 * 云同步会误判「内容被改过」。修法是显式 `Locale.ROOT`，这里锁死产物形状。
 */
class LocaleHashAsciiTest {

    private lateinit var original: Locale

    @Before
    fun switchToArabicDigitsLocale() {
        original = Locale.getDefault()
        Locale.setDefault(Locale.forLanguageTag("ar-EG"))
    }

    @After
    fun restoreLocale() {
        Locale.setDefault(original)
    }

    @Test
    fun `内容哈希在 ar-EG 下仍是 64 位 ASCII 十六进制`() {
        val hash = computeContentSha256(linkedMapOf("courses" to listOf("c1")))
        assertEquals(64, hash.length)
        assertTrue("哈希出现非 ASCII 字形：$hash", hash.isAsciiHex())
    }

    @Test
    fun `情侣端点来源哈希在 ar-EG 下仍是 ASCII`() {
        val repository = TimetableRepository(TimetableStore(InMemoryKeyValueStore()))
        val port = CouplePartnerPortImpl(repository, InMemoryKeyValueStore())
        port.importPackage(
            CouplePartnerPackageCodec.buildMine(
                profileName = "我的课表",
                courses = emptyList(),
                tasks = emptyList(),
                scheduleItems = emptyList(),
                settings = TimetableSettings.defaults(),
                currentWeek = 1,
                exportedAtIso = "2026-11-03T09:00:00.000",
                packageId = "couple-ascii-probe",
            ),
        )
        val hash = port.loadBinding()?.sourceFileHash ?: error("绑定没有落盘，拿不到端点 id")
        assertEquals(64, hash.length)
        assertTrue("端点 id 出现非 ASCII 字形：$hash", hash.isAsciiHex())
    }

    private fun String.isAsciiHex(): Boolean = all { it in '0'..'9' || it in 'a'..'f' }
}
