package com.mutx163.qingyu.app

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

/**
 * 通知 / 超级岛标题口径（2026-11-15）。
 *
 * 用户口径：**课名原样显示**，宽度不够只能末尾省略。上一版把通知标题截成 8 字 + `..`、
 * 岛标题截成 5 字，括号里的教室号会被吃掉；同时阶段前缀（即将上课 / 即将下课 / 上课中）
 * 挤在标题里。现在：标题只放课名（不截断），前缀进副标题槽（岛 `baseInfo.subTitle`、
 * 通知 `setSubText`）。
 *
 * 本测试钉两件事：① 拼装函数的行为（长课名原样、简称优先、副标题带前缀）；
 * ② 源码里不再出现 `substring(0, 8)` / `substring(0, 5)` / `+ ".."` 这种硬截。
 */
class LiveNotificationTitlesTest {

    @Test
    fun `长课名原样返回 不截断`() {
        val longName = "数字信号处理与系统设计实验（教三-201）"
        assertEquals(longName, liveNotificationCourseName(longName, shortName = "", useShortName = false))
        assertFalse(
            "标题里出现了硬截的省略号 —— 课名被改写，用户看到的不是自己输入的名字。",
            liveNotificationCourseName(longName, shortName = "", useShortName = false).contains(".."),
        )
    }

    @Test
    fun `开了简称且简称非空时用简称`() {
        assertEquals(
            "数信",
            liveNotificationCourseName("数字信号处理", shortName = "数信", useShortName = true),
        )
    }

    @Test
    fun `简称空白或开关关着时回全名`() {
        assertEquals(
            "数字信号处理",
            liveNotificationCourseName("数字信号处理", shortName = "   ", useShortName = true),
        )
        assertEquals(
            "数字信号处理",
            liveNotificationCourseName("数字信号处理", shortName = "数信", useShortName = false),
        )
    }

    @Test
    fun `副标题把阶段前缀放在明细前面`() {
        assertEquals(
            "即将上课  ·  08:00 - 09:40  ·  教三-201",
            liveNotificationSubText(prefix = "即将上课", detail = "08:00 - 09:40  ·  教三-201"),
        )
    }

    @Test
    fun `副标题缺一段时只留另一段`() {
        assertEquals("上课中", liveNotificationSubText(prefix = "上课中", detail = ""))
        assertEquals("教三-201", liveNotificationSubText(prefix = "", detail = "教三-201"))
        assertEquals("", liveNotificationSubText(prefix = "", detail = ""))
    }

    @Test
    fun `通知服务里不再出现硬截课名`() {
        // 走共享剥离器（R21 口径）：不剥注释的读法会被「把目标行注释掉」静默骗绿。
        val source = readKotlinSourceNoStrings(LIVE_SERVICE_PATH)
        for (pattern in HARD_CUT_PATTERNS) {
            assertSourceLacks(source, pattern, LIVE_SERVICE_PATH)
        }
        // 反向兜底：标题拼装与副标题槽确实在用这两个纯函数（否则上面只是「删掉了」）。
        assertSourceContains(source, "liveNotificationCourseName(", LIVE_SERVICE_PATH)
        assertSourceContains(source, "liveNotificationSubText(", LIVE_SERVICE_PATH)
        assertSourceContains(source, "islandSubTitle = stageTitle", LIVE_SERVICE_PATH)
        // 这一条判的是 JSON 键名（字符串字面量）：必须用保留字符串的默认档，
        // 中性化档会把 "subTitle" 抹成空格、断言永远不成立。
        assertSourceContains(
            readKotlinSourceNormalized(LIVE_SERVICE_PATH),
            """"subTitle", islandSubTitle""",
            LIVE_SERVICE_PATH,
        )
    }

    private companion object {
        const val LIVE_SERVICE_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/LiveUpdateService.kt"

        /** 旧写法：通知标题 8 字 + `..`、岛标题 5 字截断。 */
        val HARD_CUT_PATTERNS = listOf(
            "substring(0, 8)",
            "substring(0, 5)",
            "length > 8",
            "length > 5",
        )
    }
}
