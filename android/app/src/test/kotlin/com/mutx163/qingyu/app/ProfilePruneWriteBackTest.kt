package com.mutx163.qingyu.app

import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * D1：整条档案（profile 级）坏掉时才 prune 写回，且必须满足三条：
 * ① 先留档到 `timetable_profiles_unparsed_items`；
 * ② 只删确实不可解析的**整条记录**，条目级坏条目（能救）一律不删；
 * ③ 写回走仓储（`TimetableRepository.reload()` 持锁），按原始字节切除，
 *    其余档案的字节**逐字节不变**（含内嵌 settings 的 250+ 键）。
 */
class ProfilePruneWriteBackTest {

    // 故意放一个 Kotlin MiniJson 会重排成 "1.0E20" 的数字：若写回走了模型重编码，
    // 这个字节就会变，用它来证明「好档案字节不变」。
    private val good1 =
        """{"id":"p1","name":"课表一","courses":[],"tasks":[],"scheduleItems":[],"exams":[],"settings":{"semesterWeekCount":20,"exoticNumber":100000000000000000000.0}}"""
    private val good2 =
        """{"id":"p2","name":"课表二","courses":[],"tasks":[],"scheduleItems":[],"exams":[],"settings":{"semesterWeekCount":18}}"""

    private fun seed(raw: String): TimetableStore {
        val backend = InMemoryKeyValueStore(mapOf(TimetableStore.KEY_PROFILES to raw))
        return TimetableStore(backend)
    }

    @Test
    fun `整条坏档案先留档再按原始字节切除`() {
        val raw = "[$good1, 42, $good2]"
        val store = seed(raw)
        val repository = TimetableRepository(store)

        assertEquals(2, repository.snapshot.profiles.size)
        // 好档案逐字节不变；坏记录（42）被切除；分隔符规范化成紧凑逗号。
        assertEquals("[$good1,$good2]", store.rawJson(TimetableStore.KEY_PROFILES))

        val archivedText = store.rawJson(TimetableStore.KEY_PROFILES_UNPARSED_ITEMS)
        assertNotNull("坏记录必须先留档，不能静默丢", archivedText)
        val archived = MiniJson.parse(archivedText!!) as Map<*, *>
        assertEquals(1, (archived["count"] as Number).toInt())
        assertEquals(listOf("42"), archived["items"] as List<*>)
    }

    @Test
    fun `条目级坏条目不写回盘上字节完全不变`() {
        val withBadCourse =
            """{"id":"p1","name":"课表一","courses":[{"name":123}],"tasks":[],"scheduleItems":[],"exams":[],"settings":{"semesterWeekCount":20}}"""
        val raw = "[$withBadCourse]"
        val store = seed(raw)
        val repository = TimetableRepository(store)

        assertEquals(0, repository.snapshot.courses.size)
        assertEquals("条目级损坏不允许写回（能救的条目一律不删）", raw, store.rawJson(TimetableStore.KEY_PROFILES))
        // 坏条目仍然留档，供下次解析器修好后修复。
        val archived = MiniJson.parse(store.rawJson(TimetableStore.KEY_PROFILES_UNPARSED_ITEMS)!!) as Map<*, *>
        assertEquals(1, (archived["count"] as Number).toInt())
    }

    @Test
    fun `干净数据不触发任何写回`() {
        val raw = "[$good1,$good2]"
        val store = seed(raw)
        TimetableRepository(store)

        assertEquals(raw, store.rawJson(TimetableStore.KEY_PROFILES))
        assertNull(store.rawJson(TimetableStore.KEY_PROFILES_UNPARSED_ITEMS))
    }

    @Test
    fun `原生切片保留字符串里的逗号右括号与转义引号`() {
        val tricky =
            """{"id":"p1","name":"a,b]\"q","courses":[{"id":"c1","name":"x,y"}]}"""
        val raw = "[$tricky,99]"
        val store = TimetableStore(InMemoryKeyValueStore())

        assertEquals("[$tricky]", store.pruneTopLevelJsonItems(raw, setOf(1)))
        assertEquals("[99]", store.pruneTopLevelJsonItems(raw, setOf(0)))
        assertNull("没有要删的条目时不必产生写回串", store.pruneTopLevelJsonItems(raw, emptySet()))
    }

    @Test
    fun `结构不可信时放弃写回而不是写坏`() {
        val store = TimetableStore(InMemoryKeyValueStore())
        assertNull("非数组", store.pruneTopLevelJsonItems("""{"id":"p1"}""", setOf(0)))
        assertNull("下标越界", store.pruneTopLevelJsonItems("[1,2]", setOf(5)))
        assertNull("数组未闭合", store.pruneTopLevelJsonItems("""["a",{"b":1}""", setOf(0)))
        assertNull("全坏（应由整份留档路径处理）", store.pruneTopLevelJsonItems("[1,2]", setOf(0, 1)))
    }

    @Test
    fun `坏记录旁边有空白也能正确切除`() {
        val raw = """[ $good1 , "junk" , $good2 ]"""
        val store = seed(raw)
        TimetableRepository(store)
        assertEquals("[$good1,$good2]", store.rawJson(TimetableStore.KEY_PROFILES))
        assertTrue(store.rawJson(TimetableStore.KEY_PROFILES_UNPARSED_ITEMS)!!.contains("junk"))
    }
}


