package com.mutx163.qingyu.core

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * 埋点常量表与调用点的**一致性守卫**（2026-11-03 建立，读源码文本判定）。
 *
 * 钉两条：
 * 1. 服务层 `port.logEvent(...)` / `port.logExamEvent(...)` 出现的每个事件名
 *    都必须登记在 [AnalyticsEvents.ALL] 里——**新增调用点忘登表 ⇒ 红**；
 * 2. [AnalyticsEvents.ALL] 里的每个名字都仍有一个真实调用点——**删调用点忘删
 *    常量 ⇒ 红**（棘轮：不许只进不出）。
 *
 * 照抄 `ComposeSheetGuardTest.repoRoot()` 的仓库根定位口径（从工作目录向上找
 * `i18n/app_zh.arb` + `android/app/build.gradle` 那一层；Dart 的 `lib/screens` + `pubspec.yaml`
 * 在 P4-C 后已删，不可再当锚点）;「扫描器必须真的扫到」自检防空跑假绿。
 */
class AnalyticsEventsGuardTest {

    // 事件发出的三个服务文件（全仓 logEvent 事件名的唯一来源；2026-11-03 盘点）。
    private val callerFiles = listOf(
        "android/app/src/main/kotlin/com/mutx163/qingyu/course/TimetableCourseService.kt",
        "android/app/src/main/kotlin/com/mutx163/qingyu/app/ScheduleItemService.kt",
        "android/app/src/main/kotlin/com/mutx163/qingyu/course/TimetableExamService.kt",
    )

    private fun repoRoot(): String {
        var dir: File? = File(System.getProperty("user.dir") ?: ".").absoluteFile
        while (dir != null) {
            if (File(dir, "android/app/src").isDirectory) {
                var up: File? = dir
                while (up != null) {
                    if (File(up, "i18n/app_zh.arb").isFile && File(up, "android/app/build.gradle").isFile) {
                        return up.path
                    }
                    up = up.parentFile
                }
            }
            dir = dir.parentFile
        }
        error("找不到仓库根（user.dir=${System.getProperty("user.dir")}）")
    }

    /** 从调用点源码提取全部事件名字面量。 */
    private fun scanCallerEventNames(): Map<String, Int> {
        val regex = Regex("port\\.log(?:Exam)?Event\\(\\s*\"([a-z_]+)\"")
        val counts = linkedMapOf<String, Int>()
        for (relative in callerFiles) {
            val file = File(repoRoot(), relative)
            assertTrue("调用点文件不存在：$relative", file.isFile)
            for (match in regex.findAll(file.readText())) {
                val name = match.groupValues[1]
                counts[name] = (counts[name] ?: 0) + 1
            }
        }
        return counts
    }

    @Test
    fun `扫描器必须真的扫到调用点（防空跑假绿）`() {
        val scanned = scanCallerEventNames()
        assertTrue(
            "只扫到 ${scanned.size} 个事件名（2026-11-03 盘点是 17 个），扫描判据疑似失效：" +
                "user.dir=${System.getProperty("user.dir")}",
            scanned.size >= 17,
        )
    }

    @Test
    fun `调用点出现的每个事件名都必须登记在常量表`() {
        val scanned = scanCallerEventNames()
        val unregistered = scanned.keys - AnalyticsEvents.ALL
        assertTrue(
            "这些事件名在调用点出现但没登记进 AnalyticsEvents（别让字符串散落）：" +
                unregistered.joinToString(),
            unregistered.isEmpty(),
        )
    }

    @Test
    fun `常量表里的每个名字都必须仍有真实调用点（不许只进不出）`() {
        val scanned = scanCallerEventNames()
        val dead = AnalyticsEvents.ALL - scanned.keys
        assertTrue(
            "这些常量已无任何调用点，请从 AnalyticsEvents 删掉（棘轮只许收不许放）：" +
                dead.joinToString(),
            dead.isEmpty(),
        )
    }

    @Test
    fun `事件名风格必须是 snake_case`() {
        for (name in AnalyticsEvents.ALL) {
            assertTrue(
                "事件名 $name 不合 snake_case（埋点名沿用 Dart 侧风格，不许改名）",
                name.matches(Regex("[a-z][a-z0-9_]*")),
            )
        }
    }

    @Test
    fun `常量值与常量名语义一致（防复制粘贴错名）`() {
        for (name in AnalyticsEvents.ALL) {
            val constant = AnalyticsEvents::class.java.fields
                .firstOrNull { it.name != "ALL" && it.get(null) == name }
            assertNotNull("事件名 $name 应来自某个 const val 常量", constant)
        }
    }
}

/**
 * 「参数透传」契约测试：`TimetableRepository.logEvent` 必须先脱敏再转发到**注入的** sink
 * （`find.byType` 式的间接验证不算数——这里直接断言 sink 收到的内容）。
 */
class RepositoryEventSinkContractTest {

    @Test
    fun `logEvent 先脱敏再转发到注入的 sink`() {
        val received = mutableListOf<Pair<String, Map<String, Any>>>()
        val sink = EventSink { name, params -> received.add(name to params) }
        val repo = TimetableRepository(TimetableStore(InMemoryKeyValueStore()), sink)

        repo.logEvent(
            "course_created",
            linkedMapOf(
                "day_of_week" to 1,
                "course_name" to "高等数学",
                "schedule_item_id" to "abc-123",
            ),
        )

        assertEquals(1, received.size)
        assertEquals("course_created", received[0].first)
        assertEquals("敏感参数必须被闸门剥掉，只留数值", mapOf("day_of_week" to 1), received[0].second)
    }

    @Test
    fun `默认构造汇入进程级共享环形缓冲`() {
        EventSinks.resetForTesting()
        val repo = TimetableRepository(TimetableStore(InMemoryKeyValueStore()))
        repo.logEvent("task_deleted", mapOf("remaining_task_count" to 2))
        assertEquals(1, EventSinks.shared.size)
        assertEquals("task_deleted", EventSinks.shared.snapshot().single().name)
        assertEquals(2, EventSinks.shared.snapshot().single().parameters["remaining_task_count"])
    }
}
