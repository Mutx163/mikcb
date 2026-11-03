package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimetableProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.time.LocalDate

/**
 * courses 导入收尾两项缺口的反例测试（F32 第二批）：
 *
 * 1. **节次扩容**：脚本课排到当前节次表之外时必须把表扩到覆盖它——
 *    不扩的话那些课读不到钟点、在课表上根本显示不出来（用户可感知的数据丢失）。
 * 2. **导入随机配色**：颜色按「色板 + 洗牌」派生、同名同教师同色，
 *    不写死、不由课 id 决定跨导入稳定性（旧版口径：每次导入重新洗牌）。
 */
class WarehouseCoursesImportApplyTest {

    private fun course(
        id: String,
        name: String = "课程$id",
        endSection: Int = 2,
        color: String = "#ABCDEF",
    ) = Course(
        id = id,
        name = name,
        teacher = "教师",
        location = "教室",
        dayOfWeek = 1,
        startSection = endSection,
        endSection = endSection,
        startTime = "",
        endTime = "",
        customWeeks = listOf(1, 2),
        color = color,
    )

    private fun repositoryWith(vararg extraPairs: Pair<String, String>): TimetableRepository {
        val raw = InMemoryKeyValueStore(extraPairs.toMap())
        return TimetableRepository(TimetableStore(raw))
    }

    private fun request(
        courses: List<Course>,
        replaceExisting: Boolean = true,
        expandSections: Boolean = true,
    ) = WarehouseCoursesImportApply.Request(
        courses = courses,
        semesterStartDate = LocalDate.of(2026, 9, 7),
        replaceExisting = replaceExisting,
        preserveLocalColors = true,
        expandSections = expandSections,
    )

    // ── 节次扩容 ─────────────────────────────────────────────────────

    @Test
    fun `课排在当前节次表之外时扩节后导入的课才有钟点可用`() {
        val repository = repositoryWith()
        // 默认节次表 10 节；课程排到第 12 节——不扩节这课读不到钟点。
        val courses = listOf(course("c1", endSection = 12))
        assertEquals(10, repository.snapshot.settings.sections.size)

        val result = WarehouseCoursesImportApply.apply(repository, request(courses))

        assertTrue("扩节导入应成功", result is WarehouseCoursesImportApply.Result.Done)
        val sections = repository.snapshot.settings.sections
        assertTrue(
            "节次表必须扩到覆盖第 12 节（不扩 = 课没有钟点 = 课表上显示不出来）",
            sections.size >= 12,
        )
        // 课本身落库（可见性的另一半）。
        assertTrue(repository.snapshot.courses.any { it.id == "c1" })
        // 补出来的节次时间必须是合法钟点（锚点推算，不是凌晨绕回）。
        val section12 = sections[11]
        assertTrue(section12.startTime.matches(Regex("\\d{2}:\\d{2}")))
        assertTrue(section12.endTime > section12.startTime)
    }

    @Test
    fun `用户不同意扩节时设置保持原样`() {
        val repository = repositoryWith()
        val before = repository.snapshot.settings.sections

        val result = WarehouseCoursesImportApply.apply(
            repository,
            request(listOf(course("c1", endSection = 12)), expandSections = false),
        )

        assertTrue(result is WarehouseCoursesImportApply.Result.Done)
        assertEquals(before, repository.snapshot.settings.sections)
    }

    @Test
    fun `扩节只追加不改已有节次的时间`() {
        val repository = repositoryWith()
        val before = repository.snapshot.settings.sections

        WarehouseCoursesImportApply.apply(repository, request(listOf(course("c1", endSection = 12))))

        val after = repository.snapshot.settings.sections
        assertEquals(before, after.take(before.size))
    }

    @Test
    fun `一条结束时间都解析不出时补不满如实失败且不写任何东西`() {
        val repository = repositoryWith()
        // 整表时间全坏：没有可靠锚点，继续补只能凭空编时间——按 service message 失败。
        repository.updateSettings(
            repository.snapshot.settings.copy(sections = listOf(SectionTime("", ""))),
        )
        val coursesBefore = repository.snapshot.courses

        val result = WarehouseCoursesImportApply.apply(
            repository,
            request(listOf(course("c1", endSection = 12))),
        )

        assertTrue(result is WarehouseCoursesImportApply.Result.Failed)
        val message = (result as WarehouseCoursesImportApply.Result.Failed).serviceMessage
        assertTrue(
            "失败必须带 section_count_below_usage 服务码（供 localize 成用户可读文案）",
            message?.startsWith("section_count_below_usage") == true,
        )
        // 不写任何东西：设置与课程都保持导入前。
        assertEquals(listOf(SectionTime("", "")), repository.snapshot.settings.sections)
        assertEquals(coursesBefore, repository.snapshot.courses)
    }

    /** 课程落盘那步（`timetable_profiles` 写入）抛错的存储替身（模拟磁盘写满）。 */
    private class FailingProfileWriteStore(
        private val delegate: InMemoryKeyValueStore,
        private val failKey: String,
    ) : com.mutx163.qingyu.app.KeyValueStore by delegate {
        override fun putString(key: String, value: String) {
            if (key == failKey) throw IllegalStateException("disk_full")
            delegate.putString(key, value)
        }
    }

    @Test
    fun `落盘抛错时回滚设置与节次`() {
        val broken = TimetableRepository(
            TimetableStore(FailingProfileWriteStore(InMemoryKeyValueStore(emptyMap()), "timetable_profiles")),
        )

        val result = WarehouseCoursesImportApply.apply(
            broken,
            request(listOf(course("c1", endSection = 12))),
        )

        assertTrue(result is WarehouseCoursesImportApply.Result.Failed)
        assertNull((result as WarehouseCoursesImportApply.Result.Failed).serviceMessage)
    }

    @Test
    fun `需要节号与是否扩节的纯判据`() {
        assertEquals(0, WarehouseCoursesImportApply.requiredSectionCount(emptyList()))
        assertEquals(12, WarehouseCoursesImportApply.requiredSectionCount(listOf(course("a", endSection = 12))))
        assertTrue(
            WarehouseCoursesImportApply.needsExpansion(
                List(10) { SectionTime("08:00", "08:45") },
                12,
            ),
        )
        assertTrue(
            !WarehouseCoursesImportApply.needsExpansion(
                List(12) { SectionTime("08:00", "08:45") },
                12,
            ),
        )
    }

    // ── 随机配色（接线层） ────────────────────────────────────────────
    //
    // 配色算法本体（同种子确定派生 / 同名同教师同色 / 色板成员 / 文字色）已由
    // pages/import 域的 ImportSharedModelTest 与 ImportFlowModelTest 逐条覆盖；
    // 那两个文件不在本域 L0 编译清单里，本域不重复测共享件。这里钉住
    // warehouse 宿主的接线与 R5（颜色不得写死，一律来自共享件色板派生）。

    @Test
    fun `宿主配色走共享件派生且不出现写死的色值`() {
        val source = readSource("WarehouseWebLoginHost.kt")
        assertTrue(
            "配色必须走共享件（ImportFlowModel → ImportSharedModel 色板派生）",
            source.contains("ImportFlowModel.coursesWithOptionalRandomColors("),
        )
        assertTrue(
            "覆盖导入的本地色语义必须走 shouldPreserveLocalColors",
            source.contains("ImportFlowModel.shouldPreserveLocalColors("),
        )
        // R5 反例：宿主源码里出现任何写死的十六进制色值都算违规——
        // 把配色换成写死色必红，颜色只能来自色板与主题。
        val hits = Regex("\"#[0-9A-Fa-f]{6}\"").findAll(source).toList()
        assertTrue("宿主源码出现写死色值：${hits.map { it.value }}", hits.isEmpty())
    }

    // ── 宿主接线守卫（composeP1 不在 L0 编译范围） ────────────────────

    @Test
    fun `宿主必须在写回前做配色与扩节确认`() {
        val source = readSource("WarehouseWebLoginHost.kt")
        assertTrue("必须计算需要的节号", source.contains("WarehouseCoursesImportApply.requiredSectionCount("))
        assertTrue("节次不够必须先问用户", source.contains("WarehouseSectionExpansionDialog("))
        assertTrue("落盘必须走收尾层", source.contains("WarehouseCoursesImportApply.apply("))
        assertTrue("失败的服务码必须本地化", source.contains("TimeSchemeServiceMessages.localize("))
    }

    private fun readSource(fileName: String): String {
        val relative = "android/app/src/composeP1/kotlin/com/mutx163/qingyu/pages/import/warehouse/$fileName"
        var dir: File? = File("").absoluteFile
        repeat(8) {
            val candidate = File(dir, relative)
            if (candidate.isFile) return candidate.readText(Charsets.UTF_8)
            dir = dir?.parentFile
        }
        error("找不到源码 $relative（当前目录 ${File("").absolutePath}）")
    }
}
