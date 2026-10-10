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

    @Test
    fun everyPersonalFieldKeyIncludesTheThreeAddedOn2026_10_10() {
        // 10-09 审查发现 2：三个真实在用的键原先不在表里 ——
        // `profileName`（课表名，用户习惯写姓名/专业）、`originalName`（改名前
        // 的真名，`lan_edit_course_group_saved` 审计行里 courseName 被盖而它
        // 原样漏出）、`clientIp`（局域网鉴权失败记录五处都带）。
        val added = mapOf(
            "profileName" to "张三的课表",
            "originalName" to "高等数学",
            "clientIp" to "192.168.1.23",
        )
        added.forEach { (key, value) ->
            assertEquals("键 $key 必须被盖成 **", "**", UmengDiagnosticReporter.redactExtrasValue(key, value))
            // 大小写不敏感，与整表口径一致。
            assertEquals("**", UmengDiagnosticReporter.redactExtrasValue(key.uppercase(), value))
        }
        // 计数同前缀字段不误伤。
        assertEquals("3", UmengDiagnosticReporter.redactExtrasValue("profileNameCount", 3))
    }

    @Test
    fun freeTextLinesGetKeyValueRedaction() {
        // 10-09 审查发现 3：`message=` / `stackTrace=` / `throwable=` 三行原先
        // 零防线。这三行现在统一走 `redactPersonalFields`，形态与 Dart 侧同口径。
        // 调用方把课名拼进 message 的形态：
        assertEquals(
            "起岛失败 course=** loc=**",
            UmengDiagnosticReporter.redactPersonalFields("起岛失败 course=高等数学 loc=A101"),
        )
        // 大小写 / 等号前后空格 / 行首（stackTrace 续行）都要命中；
        // `=` 前后空白归一化成 `key=**`（与 Dart 侧 `redactPersonalFields`
        // 的旁路测试同口径：保留空白没有取证价值，还会让同一字段出现两种写法）。
        assertEquals(
            "COURSE=**",
            UmengDiagnosticReporter.redactPersonalFields("COURSE=高等数学"),
        )
        assertEquals(
            "course=** tail",
            UmengDiagnosticReporter.redactPersonalFields("course = 高等数学 tail"),
        )
        assertEquals(
            // `)` 属于值段被一并吃掉：正则的值部分是 `[^\s&|]*`，
            // 括号不是边界字符。少一个右括号不影响取证。
            "at Course.from(name=**",
            UmengDiagnosticReporter.redactPersonalFields("at Course.from(name=高等数学)"),
        )
        // `|` / `&` 是值边界，后面的取证量原样保留：
        val redacted = UmengDiagnosticReporter.redactPersonalFields("name=线性代数|id=c-1|08:00-09:40")
        assertEquals(false, redacted.contains("线性代数"))
        assertEquals(true, redacted.contains("id=c-1"))
        assertEquals(true, redacted.contains("08:00-09:40"))
        // 不含敏感键的行原样返回（取证能力不降级）：
        assertEquals(
            "retry scheduled delay=30s attempts=2",
            UmengDiagnosticReporter.redactPersonalFields("retry scheduled delay=30s attempts=2"),
        )
    }
}
