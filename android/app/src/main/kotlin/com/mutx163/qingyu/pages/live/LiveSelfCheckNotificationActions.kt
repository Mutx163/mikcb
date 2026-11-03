package com.mutx163.qingyu.pages.live

/**
 * 自检页「测试通知」卡四颗按钮的**行为分派**（纯逻辑，零 Android 依赖）。
 *
 * ## 为什么要单独一层
 *
 * 这四颗按钮在 2026-11-01 曾统一落到「原生没有入口 ⇒ 提示不可用」；触发管线迁到
 * Kotlin 之后，真正的起岛 / 收岛 / 选课测试都能做了，但判据如果只写在 Composable
 * 的 `when (rowId)` 里，JVM 单测只能读源码文本，断言不到「哪颗按钮调了哪个入口、
 * 带没带对课程和阶段」。所以把映射与参数校验抽到这里，宿主只实现
 * [LiveSelfCheckNotificationPort]（碰 Android 的那几件事），测试用 fake 端口直接
 * 断言参数。
 *
 * ## 与设置域的关系
 *
 * rowId 由 `SettingsPageRenderers` 的文案键分派表给出（`liveTestingStartAction` →
 * `liveSelfCheck.notification.start` …）。这四个字符串是跨域契约：本文件只**读**
 * 设置域产物，不改它；字符串漂了会被 `LiveSelfCheckNotificationActionsTest` 钉住。
 */
object LiveSelfCheckNotificationRows {
    /** 「开始测试」（空闲态）。 */
    const val START = "liveSelfCheck.notification.start"

    /** 「取消测试」（自检会话进行中）。 */
    const val CANCEL = "liveSelfCheck.notification.cancel"

    /** 「选课测试」。 */
    const val COURSE_TEST = "liveSelfCheck.notification.courseTest"

    /** 「停止测试」。 */
    const val COURSE_TEST_STOP = "liveSelfCheck.notification.courseTestStop"
}

/** 四颗按钮的行为身份。 */
enum class LiveSelfCheckNotificationAction {
    START_SESSION,
    CANCEL_SESSION,
    START_COURSE_TEST,
    STOP_COURSE_TEST,
}

/** rowId → 行为；不是这四颗之一时返回 null（宿主保持「未处理」）。 */
fun liveSelfCheckNotificationAction(rowId: String): LiveSelfCheckNotificationAction? =
    when (rowId) {
        LiveSelfCheckNotificationRows.START -> LiveSelfCheckNotificationAction.START_SESSION
        LiveSelfCheckNotificationRows.CANCEL -> LiveSelfCheckNotificationAction.CANCEL_SESSION
        LiveSelfCheckNotificationRows.COURSE_TEST ->
            LiveSelfCheckNotificationAction.START_COURSE_TEST
        LiveSelfCheckNotificationRows.COURSE_TEST_STOP ->
            LiveSelfCheckNotificationAction.STOP_COURSE_TEST
        else -> null
    }

/**
 * 宿主端口：只有这四件事需要碰 Android。
 *
 * 方法刻意做成非 suspending：真正的起岛要等通知回执，由实现方在
 * `rememberCoroutineScope()` 里跑并把结果 toast 出去；分派层才能在 JVM 单测里
 * 用 fake 直接驱动、不必引入 coroutines。
 */
interface LiveSelfCheckNotificationPort {
    fun startSession()

    fun cancelSession()

    fun startCourseTest(
        courseId: String,
        stage: LiveCourseTestStage,
    )

    fun stopCourseTest()
}

/**
 * 四颗按钮的唯一分派入口。
 *
 * 选课测试必须同时拿到 [courseId] 与 [stage]；缺任何一个都**不投递**并返回 false
 * ——不猜默认课程：猜错了岛会显示一门用户没选的课，比明确失败更难排查。
 *
 * @return true = 已交给端口；false = 未知 rowId / 选课测试缺参数。
 */
class LiveSelfCheckNotificationController(
    private val port: LiveSelfCheckNotificationPort,
) {

    fun trigger(
        rowId: String,
        courseId: String? = null,
        stage: LiveCourseTestStage? = null,
    ): Boolean = when (liveSelfCheckNotificationAction(rowId)) {
        LiveSelfCheckNotificationAction.START_SESSION -> {
            port.startSession()
            true
        }

        LiveSelfCheckNotificationAction.CANCEL_SESSION -> {
            port.cancelSession()
            true
        }

        LiveSelfCheckNotificationAction.START_COURSE_TEST -> {
            if (courseId.isNullOrBlank() || stage == null) {
                false
            } else {
                port.startCourseTest(courseId = courseId, stage = stage)
                true
            }
        }

        LiveSelfCheckNotificationAction.STOP_COURSE_TEST -> {
            port.stopCourseTest()
            true
        }

        null -> false
    }
}
