package com.mutx163.qingyu.pages.transfer

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.share.TransferApplyMode
import com.mutx163.qingyu.share.TransferChannel
import com.mutx163.qingyu.share.TransferScope
import com.mutx163.qingyu.sync.buildTransferPackageJson
import com.mutx163.qingyu.transfer.lan.LanEditRepositoryHost
import com.mutx163.qingyu.transfer.lan.LanTimeSchemeStep
import com.mutx163.qingyu.transfer.lan.LanTransferLogic
import com.mutx163.qingyu.transfer.lan.LanTransferUndoStore
import java.io.File
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 局域网链路的「模板表只许新建、不许改写本机模板」与「撤销整表重建」（2026-11-06 D 批）。
 *
 * 病灶与 transfer 域同源：`LanTransferApplier.executeTimeSchemes` 的同 id 分支曾调
 * `updateTimeScheme`，把本机模板的 name/sections 用包里的覆盖；`executeUndo` 曾逐个
 * delete/update，既会被引用校验拒绝（半还原）、又顺手重排课程钟点。现在：
 * - 计划仍产 [LanTimeSchemeStep.Update]（只表示引用无需重映射），**执行端只落 Create**；
 * - 撤销/回滚**整表重建**后一次写回 `replaceTimeSchemes`。
 *
 * 本文件放在 `pages/transfer`（L0 够得到：`transfer` 与 `app` 都是共享模型层），
 * 用真仓储（内存 KV → TimetableStore → TimetableRepository）+ `LanEditRepositoryHost`
 * 走一遍「应用 → 撤销」的真实路径。
 */
class LanTimeSchemeNoRewriteTest {

    private val stamp: LocalDateTime = LocalDateTime.of(2026, 11, 2, 9, 0)
    private val sectionsA = listOf(SectionTime("08:00", "08:45"), SectionTime("08:55", "09:40"))
    private val sectionsB = listOf(SectionTime("09:00", "09:45"), SectionTime("09:55", "10:40"))
    private val sectionsC = listOf(SectionTime("10:00", "10:45"), SectionTime("10:55", "11:40"))

    private fun scheme(id: String, name: String, sections: List<SectionTime>) = TimeScheme(
        id = id, name = name, sections = sections, createdAt = stamp, updatedAt = stamp,
    )

    private fun course(id: String, name: String) = Course(
        id = id, name = name, teacher = "", location = "",
        dayOfWeek = 1, startSection = 1, endSection = 2,
        startTime = "08:00", endTime = "09:40",
    )

    private fun repositoryOn(store: InMemoryKeyValueStore): TimetableRepository {
        val timetableStore = TimetableStore(store)
        timetableStore.saveProfiles(
            listOf(
                TimetableProfile(
                    id = "p1", name = "默认课表", currentWeek = 7,
                    createdAt = stamp, lastUsedAt = stamp,
                ),
            ),
        )
        timetableStore.saveActiveProfileId("p1")
        timetableStore.saveSettings(TimetableSettings.defaults())
        timetableStore.saveCurrentWeek(7)
        return TimetableRepository(timetableStore)
    }

    private fun packageJson(
        courses: List<Course> = emptyList(),
        timeSchemes: List<TimeScheme> = emptyList(),
    ): String = MiniJson.encode(
        buildTransferPackageJson(
            packageId = "transfer-test-lan",
            scope = TransferScope.CURRENT_TIMETABLE,
            exportedAtIso = "2026-11-02T09:00:00.000",
            channel = TransferChannel.LAN,
            currentWeek = 7,
            settingsJson = TimetableSettings.defaults().toJson(),
            coursesJson = courses.map { it.toJson() },
            timeSchemesJson = timeSchemes.map { it.toJson() },
        ),
    )

    // ── 1. 纯计划：Update 存在，但只有 Create 该落盘 ──────────────────

    @Test
    fun `模板计划里同id是Update_但只有Create该落盘`() {
        val steps = LanTransferLogic.planTimeSchemes(
            local = listOf(scheme("s1", "本机作息", sectionsA)),
            incoming = listOf(
                scheme("s1", "外来名", sectionsB),
                scheme("s9", "全新模板", sectionsC),
            ),
        )
        assertTrue("同 id 必须仍是 Update 步骤", steps.any { it is LanTimeSchemeStep.Update })
        val toCreate = LanTransferLogic.lanTimeSchemeStepsToCreate(steps)
        assertEquals("只允许新建新建这一种落盘", 1, toCreate.size)
        assertEquals("s9", toCreate.single().incomingId)
        assertFalse(
            "同 id 那条绝不能进落盘列表（否则会改写本机模板）",
            toCreate.any { it.incomingId == "s1" },
        )
    }

    @Test
    fun `同id更新不改签名索引_后续同签名表复用对的那套`() {
        // 2026-11-06 三轮返工：Update 不得污染签名索引（与 transfer 侧同一病灶）。
        // 旧实现把「外来签名 → 本机 id」写进索引、挤掉本机真实签名：
        // ① 后续同签名外来表复用节次不符的本机模板；② 与本机真实签名相同的表被重复新建。
        val localA = scheme("t1", "本机A", sectionsA)
        val localB = scheme("t2", "本机B", sectionsB)
        val steps = LanTransferLogic.planTimeSchemes(
            local = listOf(localA, localB),
            incoming = listOf(
                scheme("t1", "外来A", sectionsB), // 同 id → Update
                scheme("x", "外来签名B", sectionsB), // 应复用 t2
                scheme("y", "外来签名A", sectionsA), // 应复用 t1
                scheme("z", "全新", listOf(SectionTime("11:00", "11:45"))), // 新建
            ),
        )
        assertEquals(
            "同 id 只出 Update",
            listOf("t1"),
            steps.filterIsInstance<LanTimeSchemeStep.Update>().map { it.localId },
        )
        assertEquals(
            "外来 B 必须复用 t2（不是被污染成 t1）",
            listOf("t2"),
            steps.filterIsInstance<LanTimeSchemeStep.Reuse>()
                .filter { it.incomingId == "x" }.map { it.localId },
        )
        assertEquals(
            "外来 A 必须复用 t1（本机真实签名不许被挤出索引）",
            listOf("t1"),
            steps.filterIsInstance<LanTimeSchemeStep.Reuse>()
                .filter { it.incomingId == "y" }.map { it.localId },
        )
        assertEquals(
            "只有真正全新的才新建",
            listOf("z"),
            LanTransferLogic.lanTimeSchemeStepsToCreate(steps).map { it.incomingId },
        )
    }

    // ── 2. 行为：真应用一次，本机模板一个字不改 ──────────────────────
    @Test
    fun `应用导入不改写本机已有模板`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.replaceTimeSchemes(listOf(scheme("s1", "本机作息", sectionsA)))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            // 同 id（s1）但名称/节次都被包改过 + 一个全新模板
            packageJson(
                courses = listOf(course("c1", "高数")),
                timeSchemes = listOf(
                    scheme("s1", "外来作息", sectionsB),
                    scheme("s9", "全新模板", sectionsC),
                ),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals("应用本身必须成功：$applied", true, applied["applied"])

        val localScheme = repository.snapshot.timeSchemes.first { it.id == "s1" }
        assertEquals("本机模板名不许被包里的覆盖", "本机作息", localScheme.name)
        assertEquals("本机模板节次不许被包里的覆盖", sectionsA, localScheme.sections)
        assertTrue(
            "全新模板应当被新建",
            repository.snapshot.timeSchemes.any { it.name == "全新模板" },
        )
    }

    // ── 3. 行为：撤销把导入新建的模板整份收回 ────────────────────────

    @Test
    fun `撤销把导入新建的模板整份收回`() {
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        repository.replaceTimeSchemes(listOf(scheme("s1", "本机作息", sectionsA)))
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c1", "高数")),
                timeSchemes = listOf(scheme("s9", "全新模板", sectionsC)),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        assertTrue("导入后应有多出来的模板", repository.snapshot.timeSchemes.any { it.name == "全新模板" })
        val transferId = applied["transferId"] as? String
        assertNotNull("apply 成功必须回撤销点 id：$applied", transferId)

        val undone = host.undoTransferJson(transferId!!)
        assertEquals("撤销必须成功：$undone", true, undone["undo"])

        assertFalse(
            "撤销后内存里不许再有导入新建的模板",
            repository.snapshot.timeSchemes.any { it.name == "全新模板" },
        )
        assertFalse(
            "撤销后盘上也不许再有导入新建的模板",
            TimetableStore(store).loadTimeSchemes().schemes.any { it.name == "全新模板" },
        )
        val localScheme = repository.snapshot.timeSchemes.first { it.id == "s1" }
        assertEquals("本机模板必须原样还在", "本机作息", localScheme.name)
        assertEquals(sectionsA, localScheme.sections)
    }

    @Test
    fun `撤销不删仍被引用的模板_引用不留悬空`() {
        // 2026-11-06 三轮返工：整表写回绕过了 deleteTimeScheme 的 isSchemeInUse 门。
        // 构造「导入新建的模板在撤销时仍被引用」：导入后用户又加了一门课指向它。
        // 撤销只回退这一批（撤掉 c9），用户那门课保留 ⇒ 模板必须留下，不能删成悬空引用。
        val store = InMemoryKeyValueStore()
        val repository = repositoryOn(store)
        val host = LanEditRepositoryHost(repository, LanTransferUndoStore())

        val applied = host.applyTransferJson(
            packageJson(
                courses = listOf(course("c9", "外来课程")),
                timeSchemes = listOf(scheme("s9", "全新模板", sectionsC)),
            ),
            TransferApplyMode.OVERWRITE,
        )
        assertEquals(true, applied["applied"])
        val createdScheme = repository.snapshot.timeSchemes.single { it.name == "全新模板" }

        // 导入之后用户自己加了门课，绑到这套模板上（撤销不能把它的模板删了）
        repository.addCourse(
            course("c_user", "用户后加的课").copy(timeSchemeIdOverride = createdScheme.id),
        )

        val undone = host.undoTransferJson(applied["transferId"] as String)
        assertEquals("撤销仍应成功：$undone", true, undone["undo"])
        assertTrue(
            "仍被课程引用的模板不许被撤销删掉（否则留悬空引用还报成功）",
            repository.snapshot.timeSchemes.any { it.id == createdScheme.id },
        )
        assertTrue(
            "盘上也必须还在",
            TimetableStore(store).loadTimeSchemes().schemes.any { it.id == createdScheme.id },
        )
    }

    // ── 4. 源码守卫：执行端不许再改写/逐个删模板，回滚必须逐步 + 整表写回 ──
    @Test
    fun `局域网执行端不许改写本机模板且回滚要逐步`() {
        val source = stripLineComments(readRepoFile(APPLIER_PATH))
        assertTrue(
            "LanTransferApplier 里又出现了 updateTimeScheme(——会改写本机模板并重排课程钟点",
            !source.contains("updateTimeScheme("),
        )
        assertTrue(
            "模板表必须经 replaceTimeSchemes( 整份写回",
            source.contains("replaceTimeSchemes("),
        )
        val restore = source.substring(
            source.indexOf("private fun restoreState("),
            source.indexOf("private fun", source.indexOf("private fun restoreState(") + 1)
                .let { if (it < 0) source.length else it },
        )
        assertTrue("restoreState 必须逐步尽力（fun step(）", restore.contains("fun step("))
        assertTrue(
            "restoreState 必须整份写回模板表（replaceTimeSchemes）——否则回滚后模板表还是导入后的样子",
            restore.contains("replaceTimeSchemes("),
        )
        assertTrue(
            "restoreState 里不许再逐个 deleteTimeScheme(（改成整表写回）",
            !restore.contains("deleteTimeScheme("),
        )
    }

    // ------------------------------------------------------------------ 定位

    private fun readRepoFile(relative: String): String {
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到 $relative（工作目录 ${File("").absolutePath}）")
    }

    private fun stripLineComments(text: String): String =
        text.lineSequence().joinToString("\n") { line -> line.substringBefore("//") }

    private companion object {
        const val APPLIER_PATH =
            "android/app/src/main/kotlin/com/mutx163/qingyu/transfer/lan/LanTransferApplier.kt"
    }
}
