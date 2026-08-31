package com.mutx163.qingyu

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetStatsE2ELogicTest {
    @Test
    fun buildSnapshotFromProfileJson() {
        val profile = JSONObject("""
        {
          "name": "测试课表",
          "currentWeek": 3,
          "settings": {"semesterWeekCount": 16, "semesterStartDate": 0},
          "courses": [
            {"id":"1","name":"数学","dayOfWeek":1,"startSection":1,"endSection":2,"startTime":"08:00","endTime":"09:40","startWeek":1,"endWeek":16,"courseNature":"required"},
            {"id":"2","name":"英语","dayOfWeek":3,"startSection":3,"endSection":4,"startTime":"10:00","endTime":"11:40","startWeek":1,"endWeek":8,"isEvenWeek":true,"courseNature":"elective","suspendedWeeks":[6]},
            {"id":"3","name":"体育","dayOfWeek":5,"startSection":5,"endSection":6,"startTime":"14:00","endTime":"15:40","startWeek":2,"endWeek":4,"courseNature":"elective"}
          ]
        }
        """.trimIndent())
        // semesterStartDate=0 → 无开学日期分支（takeIf { it > 0 }），用 persistedWeek=3
        val snap = WidgetStatsLogic.buildSnapshot(profile, nowMillis = 1000L)
        assertEquals("测试课表", snap!!.profileName)
        assertEquals(3, snap.currentWeek)
        // 第 3 周：数学 2 节 + 体育 2 节（英语双周不上、体育 2..4 含第 3 周）→ 4 节 2 门
        assertEquals(4, snap.weekSections)
        assertEquals(2, snap.weekCourseCount)
        // 上周（第 2 周）：数学 2 + 英语 2（双周）+ 体育 2 = 6 → delta = 4-6 = -2
        assertEquals(-2, snap.deltaVsLastWeek)
        // 学期总课时：数学 32 + 英语（1..8 双周 4 周×2=8，停课第 6 周双周 -2 → 6）+ 体育 3 周×2=6 → 44
        assertEquals(44, snap.semesterTotal)
        // 无开学日期：退回整周估算 done = 数学 3×2 + 英语（1..3 双周仅第 2 周）1×2 + 体育 2×2 = 12
        assertEquals(12, snap.semesterDone)
        assertEquals(1, snap.requiredCount)
        assertEquals(2, snap.electiveCount)
        // 每周覆盖周一/周三/周五 → 最长连续 1 天
        assertEquals(1, snap.longestStreak)
    }
}
