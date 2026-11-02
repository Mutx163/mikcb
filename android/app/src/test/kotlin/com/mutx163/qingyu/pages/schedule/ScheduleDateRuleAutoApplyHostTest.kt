package com.mutx163.qingyu.pages.schedule

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.calendar.ScheduleDateRuleApplyOutcome
import com.mutx163.qingyu.core.ScheduleDateRule
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.IOException
import java.time.LocalDateTime

/**
 * [ScheduleDateRuleAutoApplyHost] 宿主层单测（纯 JVM，存储走 [InMemoryKeyValueStore] 替身）。
 *
 * 只钉宿主自己加的两件事：签名键的读写契约（含与 Dart 的键名冻结）、
 * 「落盘失败吞成 NotDue 并回调 onPersistError」。到点判定 / 批量套用的纯逻辑
 * 在 `calendar/ScheduleDateRuleAutoApply` 已有单测，这里不重复。
 */
class ScheduleDateRuleAutoApplyHostTest {

    /** 可开关的写盘失败替身：种子数据先正常写入，再把闸打开模拟磁盘满。 */
    private class FlakyWriteStore(private val delegate: KeyValueStore) : KeyValueStore by delegate {
        var failWrites = false

        private fun guard() {
            if (failWrites) throw IOException("disk full (fake)")
        }

        override fun putString(key: String, value: String) {
            guard(); delegate.putString(key, value)
        }

        override fun putInt(key: String, value: Int) {
            guard(); delegate.putInt(key, value)
        }

        override fun putLong(key: String, value: Long) {
            guard(); delegate.putLong(key, value)
        }

        override fun putBool(key: String, value: Boolean) {
            guard(); delegate.putBool(key, value)
        }

        override fun putStringList(key: String, value: List<String>) {
            guard(); delegate.putStringList(key, value)
        }

        override fun remove(key: String) {
            guard(); delegate.remove(key)
        }
    }

    @Test
    fun `签名键名与 Dart 侧冻结一致`() {
        assertEquals(
            "schedule_date_rule_last_applied_signature",
            ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE,
        )
    }

    @Test
    fun `签名读写走 KeyValueStore 抽象：空白读成 null、写回空白即删键`() {
        val prefs = InMemoryKeyValueStore()
        val repository = TimetableRepository(TimetableStore(prefs))
        val port = RepositoryScheduleDateRulePort(repository, prefs)

        // 盘上是空白串时读成 null（与 Dart isNotBlank 口径一致）
        prefs.putString(ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE, "   ")
        assertEquals(null, port.scheduleDateRuleLastAppliedSignature)

        // 非空白正常读回
        port.scheduleDateRuleLastAppliedSignature = "r1|s1|2026-11-02|2027-04-30"
        assertEquals("r1|s1|2026-11-02|2027-04-30", port.scheduleDateRuleLastAppliedSignature)

        // 写回空白 = 清除该键，盘上不留空白串
        port.scheduleDateRuleLastAppliedSignature = " "
        assertEquals(
            false,
            prefs.contains(ScheduleDateRuleAutoApplyHost.KEY_LAST_APPLIED_SIGNATURE),
        )
    }

    @Test
    fun `落盘失败吞成 NotDue 并回调 onPersistError，内存保持套用前原样`() {
        val store = FlakyWriteStore(InMemoryKeyValueStore())
        val repository = TimetableRepository(TimetableStore(store))
        val scheme = repository.createTimeScheme("夏令作息")
        repository.updateScheduleDateRules(
            listOf(
                ScheduleDateRule(
                    id = "r1",
                    name = "夏令时",
                    timeSchemeId = scheme.id,
                    startDate = "2026-11-02",
                    endDate = "2026-11-02",
                ),
            ),
        )
        val settingsBefore = repository.snapshot.settings
        store.failWrites = true

        val errors = mutableListOf<IOException>()
        val result = ScheduleDateRuleAutoApplyHost.applyDue(
            repository = repository,
            prefs = store,
            now = LocalDateTime.of(2026, 11, 2, 10, 0),
            onPersistError = { errors.add(it) },
        )

        // 当天命中规则、本应套用，但落盘失败 ⇒ 吞成 NotDue，不炸调用方
        assertEquals(ScheduleDateRuleApplyOutcome.NotDue, result.outcome)
        assertEquals(1, errors.size)
        // 「先落盘、成功才改内存」：失败时内存不得被套用结果污染
        assertEquals(settingsBefore, repository.snapshot.settings)
    }
}
