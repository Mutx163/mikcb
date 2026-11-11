package com.mutx163.qingyu.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * `core.ScheduleDateRule` 的唯一真源契约（P1-11，2026-11-11）。
 *
 * ## 为什么单独一个契约测试
 *
 * 这个模型原来有三份副本（calendar / core / pages.schedule），并库后唯一真源就在这里，
 * 两条东西必须被钉死：
 *
 * 1. **JSON 契约**：落盘键名与键序（`id` / `name` / `timeSchemeId` / `enabled` /
 *    `startDate` / `endDate`）——顺序变了，`TimetableStore` 写出的字符串就跟旧数据/备份
 *    不再逐字节一致；
 * 2. **解析口径**：并库时选的是 Dart 的严格口径（类型不符、日期缺失都拒），
 *    异常统一 [DartFormatException]，文案逐字沿用旧实现——放宽会让坏条目被静默接受，
 *    收紧更多则可能误伤已落盘数据。
 *
 * 探针口径：把 `fromJson` 里的某个类型检查临时拆掉，本文件对应用例必须红。
 */
class ScheduleDateRuleJsonContractTest {

    private fun sample() = ScheduleDateRule(
        id = "r1",
        name = " 夏令时 ",
        timeSchemeId = "s1",
        startDate = " 2026-05-01 ",
        endDate = "2026-09-30",
        enabled = false,
    )

    @Test
    fun `落盘键名与键序必须冻结`() {
        val json = sample().toJson()
        assertEquals(
            listOf("id", "name", "timeSchemeId", "enabled", "startDate", "endDate"),
            json.keys.toList(),
        )
        assertEquals("r1", json["id"])
        assertEquals(" 夏令时 ", json["name"])
        assertEquals("s1", json["timeSchemeId"])
        assertEquals(false, json["enabled"])
        assertEquals(" 2026-05-01 ", json["startDate"])
        assertEquals("2026-09-30", json["endDate"])
    }

    @Test
    fun `fromJson 默认值并 trim 名称与日期`() {
        val rule = ScheduleDateRule.fromJson(
            mapOf("startDate" to " 2026-03-01 ", "endDate" to "2026-04-30", "name" to " 春季 "),
        )
        assertEquals("", rule.id)
        assertEquals("春季", rule.name)
        assertEquals("", rule.timeSchemeId)
        assertEquals(true, rule.enabled)
        assertEquals("2026-03-01", rule.startDate)
        assertEquals("2026-04-30", rule.endDate)
    }

    @Test
    fun `日期缺失或空串要抛 文案逐字`() {
        val start = assertThrows(DartFormatException::class.java) {
            ScheduleDateRule.fromJson(mapOf("endDate" to "2026-04-30"))
        }
        assertEquals("missing schedule date rule start date", start.message)

        val end = assertThrows(DartFormatException::class.java) {
            ScheduleDateRule.fromJson(mapOf("startDate" to "2026-03-01", "endDate" to "  "))
        }
        assertEquals("missing schedule date rule end date", end.message)
    }

    @Test
    fun `字符串字段类型不符要拒绝而不是静默兜底`() {
        val cases = listOf(
            "id" to 42,
            "name" to 1.5,
            "timeSchemeId" to true,
        )
        val messages = mapOf(
            "id" to "schedule date rule id must be a string",
            "name" to "schedule date rule name must be a string",
            "timeSchemeId" to "schedule date rule timeSchemeId must be a string",
        )
        for ((field, badValue) in cases) {
            val error = assertThrows(DartFormatException::class.java) {
                ScheduleDateRule.fromJson(
                    mapOf(
                        "startDate" to "2026-03-01",
                        "endDate" to "2026-04-30",
                        field to badValue,
                    ),
                )
            }
            assertEquals(messages[field], error.message)
        }
    }

    @Test
    fun `enabled 非布尔要拒绝`() {
        val error = assertThrows(DartFormatException::class.java) {
            ScheduleDateRule.fromJson(
                mapOf(
                    "startDate" to "2026-03-01",
                    "endDate" to "2026-04-30",
                    "enabled" to "yes",
                ),
            )
        }
        assertEquals("schedule date rule enabled must be a bool", error.message)
    }

    @Test
    fun `json 字符串往返一致 且非对象要拒绝`() {
        // 往返用例必须用「已 trim」的样本：fromJson 会 trim 名称与日期（Dart 同口径）。
        val rule = ScheduleDateRule(
            id = "r1",
            name = "夏令时",
            timeSchemeId = "s1",
            startDate = "2026-05-01",
            endDate = "2026-09-30",
            enabled = false,
        )
        assertEquals(rule, ScheduleDateRule.fromJsonString(rule.toJsonString()))

        val error = assertThrows(DartFormatException::class.java) {
            ScheduleDateRule.fromJsonString("[1, 2, 3]")
        }
        assertEquals("schedule date rule json must be an object", error.message)
    }
}
