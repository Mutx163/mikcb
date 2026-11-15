package com.mutx163.qingyu.pages.live

import com.mutx163.qingyu.testutil.assertSourceContains
import com.mutx163.qingyu.testutil.assertSourceLacks
import com.mutx163.qingyu.testutil.readKotlinSourceNoStrings
import com.mutx163.qingyu.testutil.readKotlinSourceNormalized
import org.junit.Test

/**
 * 「课名不得被按字数硬截」的源码守卫（2026-11-15，用户口径）。
 *
 * ## 用户定的原则
 *
 * **用户输入的课名必须原样显示，宽度放不下只能末尾省略，绝不许删改括号内容或改写原文。**
 *
 * ## 这条守卫防什么
 *
 * 原来通知标题按 8 字切并补 `".."`（`LiveUpdateService.kt` 旧 `:2385`）、岛上按 5 字切
 * （旧 `:2391`），设置页预览又把同一套规则复制了一份（`DisplaySettingsModel.kt` 旧
 * `:653` / `:741`）。真实症状是「人工智能(AIGC…)」被切成 `人工智能(AIG..`——括号被劈开、
 * 后面的字被吃掉，而卡片右边还空着。这类规则一旦回来，通常只回来一半（改真实现不改预览，
 * 或反过来），所以四个判据必须同时立着：
 *
 * 1. **正向锚**：标题 / 岛名仍在这两处算出来（文件没被挪走、概念还在），否定式断言才有意义；
 * 2. **真实现不切**：`LiveUpdateService.kt` 与共享纯函数 `LiveNotificationTitles.kt` 里
 *    不许出现 `substring(0, 8)` / `substring(0, 5)` 这类按字数的切法；
 * 3. **预览同口径**：`DisplaySettingsModel.kt` 里同样不许有；
 * 4. **前缀不进标题**：标题只放课名（`val title = titleCourseName`），阶段前缀走副标题槽，
 *    不许再把 `title_before_*` 拼进标题字符串。
 *
 * ## 档位
 *
 * 1–3 条是接线 / 形态类，用中性化档（[readKotlinSourceNoStrings]）：注释里解释「以前怎么切」
 * 不算违规，日志文案里出现同名片段也不算。第 4 条判的是资源字面量，用默认档
 * （[readKotlinSourceNormalized]），否则字符串被抹掉就永远判不到。
 */
class CourseNameNotTruncatedGuardTest {

    private val service = readKotlinSourceNoStrings(LIVE_UPDATE)
    private val titles = readKotlinSourceNoStrings(LIVE_TITLES)
    private val preview = readKotlinSourceNoStrings(DISPLAY_SETTINGS)

    @Test
    fun `标题与岛名仍在这两处算出来`() {
        // 正向锚：先证明读到的确实是那两份文件。读错文件时下面几条否定式断言会「空集恒真」。
        assertSourceContains(service, "liveNotificationCourseName(", LIVE_UPDATE)
        assertSourceContains(service, "val title = titleCourseName", LIVE_UPDATE)
        assertSourceContains(titles, "fun liveNotificationCourseName(", LIVE_TITLES)
        assertSourceContains(preview, "fun titleCourseName(", DISPLAY_SETTINGS)
        assertSourceContains(preview, "fun islandCourseName(", DISPLAY_SETTINGS)
    }

    @Test
    fun `真实现不得按固定字数切课名`() {
        assertSourceLacks(service, "substring(0, 8)", LIVE_UPDATE)
        assertSourceLacks(service, "substring(0, 5)", LIVE_UPDATE)
        // 共享纯函数是课名唯一的格式化入口：这里一旦切，真通知与岛会一起被切。
        assertSourceLacks(titles, "substring(", LIVE_TITLES)
    }

    @Test
    fun `设置页预览不得按固定字数切课名`() {
        assertSourceLacks(preview, "substring(0, 8)", DISPLAY_SETTINGS)
        assertSourceLacks(preview, "substring(0, 5)", DISPLAY_SETTINGS)
    }

    @Test
    fun `标题不再拼接上课前缀`() {
        // 前缀在副标题槽（`subText` / `baseInfo.subTitle`）：标题那一串只能是课名。
        val serviceDefault = readKotlinSourceNormalized(LIVE_UPDATE)
        assertSourceLacks(serviceDefault, "R.string.title_before_", LIVE_UPDATE)
        assertSourceContains(serviceDefault, "R.string.stage_before_class", LIVE_UPDATE)
        assertSourceContains(serviceDefault, "R.string.stage_before_end", LIVE_UPDATE)
    }

    private companion object {
        const val LIVE_UPDATE =
            "android/app/src/main/kotlin/com/mutx163/qingyu/LiveUpdateService.kt"
        const val LIVE_TITLES =
            "android/app/src/main/kotlin/com/mutx163/qingyu/app/LiveNotificationTitles.kt"
        const val DISPLAY_SETTINGS =
            "android/app/src/main/kotlin/com/mutx163/qingyu/pages/live/DisplaySettingsModel.kt"
    }
}
