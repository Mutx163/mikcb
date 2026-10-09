package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 导出诊断日志的 extras 脱敏口径（2026-10-08 审核修复）。
 *
 * 背景：Kotlin 侧 `UmengDiagnosticReporter.record()` / `report()` 把 extras 逐条
 * `key=value` 原样写进 `live_update_diagnostics.log`，而这份文件正是用户
 * 「导出、发群、附 issue」的那份。Dart 侧 fd4aa078 只把 `recordDiagnosticEvent`
 * 送出前脱敏了，Kotlin 自己调用的这些点没覆盖到 —— 实时活动启动失败时打的
 * `courseName=高等数学` 整份明文进了导出文件。这里把敏感键对齐 Dart 侧
 * `lib/logging/app_debug_log.dart` 的 `personalLogFieldKeys`，在出口层统一盖掉。
 *
 * 这份表与 Dart 那份**各维护一份、无法共享代码**：改这份必须同步改 Dart 那份，
 * 否则又是「改了这份、漏了那份」。下面几条把「哪些键必须被盖」钉住，改表时
 * 如果漏了某个键，测试会红。
 */
class UmengDiagnosticRedactionTest {
    @Test
    fun courseNameIsTheLeakPointAndMustBeMasked() {
        assertEquals("**", UmengDiagnosticReporter.redactExtrasValue("courseName", "高等数学"))
    }

    @Test
    fun lookupIsCaseInsensitiveLikeDartSide() {
        assertEquals("**", UmengDiagnosticReporter.redactExtrasValue("COURSENAME", "高等数学"))
        assertEquals("**", UmengDiagnosticReporter.redactExtrasValue("CourseName", "高等数学"))
        assertEquals("**", UmengDiagnosticReporter.redactExtrasValue("Teacher", "王老师"))
    }

    @Test
    fun everyPersonalFieldKeyIsMasked() {
        val personal = mapOf(
            "course" to "高等数学",
            "name" to "张三",
            "shortName" to "高数",
            "teacher" to "王老师",
            "loc" to "A101",
            "location" to "A101",
            "groupName" to "A班",
            "group" to "A班",
            "keyword" to "期中",
            "keywords" to "期中,期末",
            "className" to "软件2201",
            "studentName" to "张三",
            "overflowNames" to "高等数学,线性代数",
            "changeSamples" to "高等数学|c-1|说明",
            "sampleOverrides" to "高等数学",
        )
        personal.forEach { (key, value) ->
            assertEquals("键 $key 必须被盖成 **", "**", UmengDiagnosticReporter.redactExtrasValue(key, value))
        }
    }

    @Test
    fun nonPersonalCountersPassThroughSoDiagnosticsKeepEvidence() {
        // 计数 / 开关 / 设备字段必须原样保留，否则脱敏会把诊断能力一起废掉。
        assertEquals("3", UmengDiagnosticReporter.redactExtrasValue("page", 3))
        assertEquals("before", UmengDiagnosticReporter.redactExtrasValue("stage", "before"))
        assertEquals("true", UmengDiagnosticReporter.redactExtrasValue("hasCourseName", true))
        assertEquals("null", UmengDiagnosticReporter.redactExtrasValue("stage", null))
    }
}
