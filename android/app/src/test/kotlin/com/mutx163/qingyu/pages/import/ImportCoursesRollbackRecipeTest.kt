package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课程导入「三级回滚」的**落盘级表征测试**（2026-11-05 数据安全修复）。
 *
 * ## 为什么测的是 recipe 而不是 `applyImport` 本体
 *
 * `applyImport` 是 `pages/import`（composeP1 源集）里的 private 函数，L0 不编
 * composeP1，本测试无法直调。这里按它 catch 块的**同一 recipe**（课程 → 设置 → 节次表，
 * 逐条 runCatching）在仓储层复现故障注入：`replaceActiveProfileContent` 中途抛错
 * （saveProfiles 成功、saveActiveProfileId 抛），断言三级回滚后磁盘全部回到 before。
 * 它钉住的是「回滚 recipe 在磁盘上成立」；catch 块本身的接线由 L1 编译 + 真机路径覆盖。
 *
 * ## 故障点与修复前的洞
 *
 * `replaceActiveProfileContent` 是两笔写：`saveProfiles`（课程/作业/考试）→
 * `saveActiveProfileId`。修复前的 catch 只回滚设置与节次表——saveProfiles 成功、
 * saveActiveProfileId 抛时**课程已经落盘**，盘上留下「新课表 + 旧设置」还报失败。
 * 本测试先断言这个半套状态确实出现（表征），再断言三级回滚把它收回 before。
 */
class ImportCoursesRollbackRecipeTest {

    /** 按键名注入写失败的假存储：命中 [failOnKey] 的写入直接抛，其余透传。 */
    private class FlakyKeyValueStore(
        private val delegate: KeyValueStore,
    ) : KeyValueStore by delegate {
        @Volatile
        var failOnKey: String? = null

        override fun putString(key: String, value: String) {
            if (key == failOnKey) throw IllegalStateException("injected write failure: $key")
            delegate.putString(key, value)
        }

        override fun putInt(key: String, value: Int) {
            if (key == failOnKey) throw IllegalStateException("injected write failure: $key")
            delegate.putInt(key, value)
        }
    }

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

    @Test
    fun `replace 中途失败后三级回滚_课程设置节次表全部回到 before`() {
        val delegate = InMemoryKeyValueStore()
        val flaky = FlakyKeyValueStore(delegate)
        val store = TimetableStore(flaky)
        val repository = TimetableRepository(store)

        // before：一门旧课 + 一套模板（节次数与当时设置一致）
        repository.addCourse(course("before-course"))
        val scheme = repository.createTimeScheme("导入前模板")
        val before = repository.snapshot
        val beforeActive = before.profiles.first { it.id == before.activeProfileId }
        val beforeProfilesRaw = delegate.getString(TimetableStore.KEY_PROFILES)
        val beforeSettingsView = store.loadSettingsJson()
        val beforeActiveId = delegate.getString(TimetableStore.KEY_ACTIVE_PROFILE_ID)
        val beforeWeek = before.currentWeek

        // 注入失败：active_timetable_profile_id 这笔写抛（saveProfiles 已成功的那条路径）
        flaky.failOnKey = TimetableStore.KEY_ACTIVE_PROFILE_ID

        // —— 复现 applyImport 的三段写：扩节次 → 写设置 → 写课程（第二段写注入失败）——
        val expanded = scheme.sections + listOf(SectionTime("21:00", "21:45"), SectionTime("22:00", "22:45"))
        val schemeError = repository.updateTimeScheme(scheme.id, scheme.name, expanded)
        assertEquals("扩节次应成功", null, schemeError)
        repository.updateSettings(before.settings.copy(semesterWeekCount = before.settings.semesterWeekCount + 2))
        val replaceError = runCatching {
            repository.replaceActiveProfileContent(
                courses = listOf(course("new-course")),
                tasks = beforeActive.tasks,
                exams = beforeActive.exams,
            )
        }.exceptionOrNull()
        assertTrue("注入的写失败必须抛出", replaceError is IllegalStateException)

        // —— 表征：失败后盘上是「新课表已落、设置已改」的中间态（这就是回滚要收回的洞）——
        // 设置三落点（内存投影 / 顶层镜像 / 磁盘内嵌）的一致性由
        // TimetableRepositorySettingsProjectionTest 单独钉；这里只表征课程与镜像两处。
        val halfRaw = delegate.getString(TimetableStore.KEY_PROFILES).orEmpty()
        val halfMirror = MiniJson.tryParse(delegate.getString(TimetableStore.KEY_SETTINGS).orEmpty()) as? Map<*, *>
        assertTrue("表征：失败后新课表应已落盘", halfRaw.contains("\"new-course\""))
        assertNotEquals("表征：失败后 profiles 不应还是 before 内容", beforeProfilesRaw, halfRaw)
        assertEquals(
            "表征：失败后顶层镜像应已写入扩过的周数",
            (before.settings.semesterWeekCount + 2).toLong(),
            ((halfMirror?.get("semesterWeekCount") ?: error("镜像缺 semesterWeekCount")) as Number).toLong(),
        )

        // —— 三级回滚（applyImport catch 块的同一 recipe，顺序：课程 → 设置 → 节次表）——
        flaky.failOnKey = null
        runCatching {
            repository.replaceActiveProfileContent(
                courses = before.courses,
                tasks = beforeActive.tasks,
                exams = beforeActive.exams,
            )
        }
        runCatching { repository.updateSettings(before.settings) }
        runCatching { repository.updateTimeScheme(scheme.id, scheme.name, scheme.sections) }

        // —— 落盘断言：三者全部回到 before 快照 ——
        assertEquals(
            "课程/作业/考试必须回到 before（profiles 原始串逐字节还原）",
            beforeProfilesRaw,
            delegate.getString(TimetableStore.KEY_PROFILES),
        )
        assertEquals("设置视图必须回到 before", beforeSettingsView, store.loadSettingsJson())
        assertEquals(
            "节次表必须回到 before（扩出来的两节被收回）",
            scheme.sections,
            store.loadTimeSchemes().schemes.first { it.id == scheme.id }.sections,
        )
        assertEquals("active id 不应被这次失败改动", beforeActiveId, delegate.getString(TimetableStore.KEY_ACTIVE_PROFILE_ID))
        assertEquals("current_week 不应被这次失败改动", beforeWeek, store.loadCurrentWeek())
    }
}
