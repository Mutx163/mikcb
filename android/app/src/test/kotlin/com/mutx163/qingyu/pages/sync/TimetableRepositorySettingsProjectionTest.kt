package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `updateSettings` 的**内嵌投影同步**守卫（2026-11-05 数据安全修复 ②）。
 *
 * ## 守住的洞
 *
 * 修复前 `updateSettingsLocked` 只更新 `loadedSettings` 与顶层镜像
 * （`timetable_settings`），**内存档案的内嵌 settings 投影留在旧值**。下一次
 * `saveProfiles`（课程导入的 `replaceActiveProfileContent` 路径必然发生）会拿内存
 * 模型的旧 core 值**覆盖刚写进磁盘内嵌的新值**——磁盘证据：内嵌 20 / 顶层镜像 22
 * 并存；而 `loadSettingsJson()` 读内嵌优先（`TimetableStore.kt:589`），所以**成功路径
 * 上学期设置重启后回退**。
 *
 * ## 断言口径
 *
 * 三个落点必须一致（全部直接断言磁盘/内存状态，不是只看返回值）：
 * 1. 内存档案投影（`snapshot.profiles` 活动档案的 `settings`）；
 * 2. 顶层镜像（`timetable_settings` 原始 JSON）；
 * 3. 磁盘内嵌（`loadSettingsJson()` 读内嵌优先）。
 * 再补一锤：紧接 `replaceActiveProfileContent` 后，磁盘内嵌**仍**是新值（旧投影
 * 不许回魂）——这正是修复前丢设置的路径。
 */
class TimetableRepositorySettingsProjectionTest {

    private fun course(id: String): Course = Course(
        id = id,
        name = "课程-$id",
        teacher = "",
        location = "",
        dayOfWeek = 1,
        startSection = 1,
        endSection = 2,
        startTime = "08:00",
        endTime = "09:40",
    )

    private fun mirrorWeekCount(delegate: InMemoryKeyValueStore): Long {
        val mirror = MiniJson.tryParse(delegate.getString(TimetableStore.KEY_SETTINGS).orEmpty()) as? Map<*, *>
        return ((mirror?.get("semesterWeekCount") ?: error("顶层镜像缺 semesterWeekCount")) as Number).toLong()
    }

    private fun embeddedWeekCount(delegate: InMemoryKeyValueStore): Long {
        val view = TimetableStore(delegate).loadSettingsJson()
        return ((view["semesterWeekCount"] ?: error("内嵌视图缺 semesterWeekCount")) as Number).toLong()
    }

    @Test
    fun `updateSettings 后_内存投影_顶层镜像_磁盘内嵌三者一致`() {
        val delegate = InMemoryKeyValueStore()
        val store = TimetableStore(delegate)
        val repository = TimetableRepository(store)
        repository.addCourse(course("keep"))

        val before = repository.snapshot
        val next = before.settings.copy(semesterWeekCount = before.settings.semesterWeekCount + 2)
        repository.updateSettings(next)

        val active = repository.snapshot.profiles.first { it.id == repository.snapshot.activeProfileId }
        assertEquals(
            "内存档案的内嵌投影必须同步（修复前停在旧值）",
            next.semesterWeekCount.toLong(),
            active.settings.semesterWeekCount.toLong(),
        )
        assertEquals("顶层镜像必须落新值", next.semesterWeekCount.toLong(), mirrorWeekCount(delegate))
        assertEquals(
            "磁盘内嵌视图必须读出新值（loadSettingsJson 读内嵌优先）",
            next.semesterWeekCount.toLong(),
            embeddedWeekCount(delegate),
        )
    }

    @Test
    fun `updateSettings 后再 replace_内嵌投影不被内存旧值覆盖`() {
        val delegate = InMemoryKeyValueStore()
        val store = TimetableStore(delegate)
        val repository = TimetableRepository(store)
        repository.addCourse(course("keep"))

        val before = repository.snapshot
        val beforeActive = before.profiles.first { it.id == before.activeProfileId }
        val next = before.settings.copy(semesterWeekCount = before.settings.semesterWeekCount + 2)
        repository.updateSettings(next)

        // 课程导入的 replace 路径：修复前这里会用内存模型的旧 core 值（20）
        // 覆盖刚写进磁盘内嵌的 22 —— 重启后学期设置回退。
        repository.replaceActiveProfileContent(
            courses = listOf(course("after-replace")),
            tasks = beforeActive.tasks,
            exams = beforeActive.exams,
        )

        assertEquals(
            "replace 之后磁盘内嵌必须仍是新周数（旧投影覆盖 = 本断言红）",
            next.semesterWeekCount.toLong(),
            embeddedWeekCount(delegate),
        )
        assertEquals("顶层镜像必须仍是新周数", next.semesterWeekCount.toLong(), mirrorWeekCount(delegate))
        val raw = delegate.getString(TimetableStore.KEY_PROFILES).orEmpty()
        assertTrue("replace 的新课程应已落盘", raw.contains("\"after-replace\""))
    }
}
