package com.mutx163.qingyu.pages.live

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 自检页四颗测试通知按钮的契约测试。
 *
 * 断言的是「哪颗按钮 → 调了端口的哪个方法 → 带了什么参数」，而不是按钮存在。
 * 曾经的写法四颗按钮统一 toast「不可用」，类型系统完全合法、页面也能点；只有把
 * 端口调用钉住，才能证明按钮真的接上了触发管线。
 */
class LiveSelfCheckNotificationActionsTest {

    @Test
    fun `四个 rowId 各自映射到唯一行为`() {
        assertEquals(
            LiveSelfCheckNotificationAction.START_SESSION,
            liveSelfCheckNotificationAction(LiveSelfCheckNotificationRows.START),
        )
        assertEquals(
            LiveSelfCheckNotificationAction.CANCEL_SESSION,
            liveSelfCheckNotificationAction(LiveSelfCheckNotificationRows.CANCEL),
        )
        assertEquals(
            LiveSelfCheckNotificationAction.START_COURSE_TEST,
            liveSelfCheckNotificationAction(LiveSelfCheckNotificationRows.COURSE_TEST),
        )
        assertEquals(
            LiveSelfCheckNotificationAction.STOP_COURSE_TEST,
            liveSelfCheckNotificationAction(LiveSelfCheckNotificationRows.COURSE_TEST_STOP),
        )
    }

    @Test
    fun `rowId 与设置域分派表逐字一致`() {
        // 设置域的文案键 → rowId 映射是跨域契约；这里复述字面值，改任何一边都会红。
        assertEquals("liveSelfCheck.notification.start", LiveSelfCheckNotificationRows.START)
        assertEquals("liveSelfCheck.notification.cancel", LiveSelfCheckNotificationRows.CANCEL)
        assertEquals(
            "liveSelfCheck.notification.courseTest",
            LiveSelfCheckNotificationRows.COURSE_TEST,
        )
        assertEquals(
            "liveSelfCheck.notification.courseTestStop",
            LiveSelfCheckNotificationRows.COURSE_TEST_STOP,
        )
    }

    @Test
    fun `未知 rowId 不触发任何端口调用`() {
        val port = FakePort()
        val controller = LiveSelfCheckNotificationController(port)

        assertFalse(controller.trigger("liveSelfCheck.island.refresh"))

        assertNull(liveSelfCheckNotificationAction("liveSelfCheck.island.refresh"))
        assertTrue("未知 rowId 不许调用端口：${port.calls}", port.calls.isEmpty())
    }

    @Test
    fun `开始与取消分别走会话起停`() {
        val port = FakePort()
        val controller = LiveSelfCheckNotificationController(port)

        assertTrue(controller.trigger(LiveSelfCheckNotificationRows.START))
        assertTrue(controller.trigger(LiveSelfCheckNotificationRows.CANCEL))

        assertEquals(listOf("startSession", "cancelSession"), port.calls)
    }

    @Test
    fun `选课测试把课程 id 与阶段原样交给端口`() {
        val port = FakePort()
        val controller = LiveSelfCheckNotificationController(port)

        assertTrue(
            controller.trigger(
                rowId = LiveSelfCheckNotificationRows.COURSE_TEST,
                courseId = "course-42",
                stage = LiveCourseTestStage.DURING_CLASS,
            ),
        )

        assertEquals(listOf("startCourseTest:course-42:duringClass"), port.calls)
    }

    @Test
    fun `选课测试缺课程或缺阶段时明确失败且不投递`() {
        val port = FakePort()
        val controller = LiveSelfCheckNotificationController(port)

        assertFalse(
            controller.trigger(
                LiveSelfCheckNotificationRows.COURSE_TEST,
                courseId = null,
                stage = LiveCourseTestStage.BEFORE_CLASS,
            ),
        )
        assertFalse(
            controller.trigger(
                LiveSelfCheckNotificationRows.COURSE_TEST,
                courseId = "course-42",
                stage = null,
            ),
        )
        assertFalse(
            controller.trigger(
                LiveSelfCheckNotificationRows.COURSE_TEST,
                courseId = "  ",
                stage = LiveCourseTestStage.BEFORE_CLASS,
            ),
        )

        assertTrue("缺参数时不许调用端口：${port.calls}", port.calls.isEmpty())
    }

    @Test
    fun `停止测试走收岛端口`() {
        val port = FakePort()
        val controller = LiveSelfCheckNotificationController(port)

        assertTrue(controller.trigger(LiveSelfCheckNotificationRows.COURSE_TEST_STOP))

        assertEquals(listOf("stopCourseTest"), port.calls)
    }

    private class FakePort : LiveSelfCheckNotificationPort {
        val calls = mutableListOf<String>()

        override fun startSession() {
            calls += "startSession"
        }

        override fun cancelSession() {
            calls += "cancelSession"
        }

        override fun startCourseTest(
            courseId: String,
            stage: LiveCourseTestStage,
        ) {
            calls += "startCourseTest:$courseId:${stage.wireValue}"
        }

        override fun stopCourseTest() {
            calls += "stopCourseTest"
        }
    }
}
