package com.mutx163.qingyu.widgetdata

import com.mutx163.qingyu.app.InMemoryKeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.Course
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import java.time.LocalDateTime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * 情侣叠加数据源的装配口径（B1 第一阶段 · 2026-11-06）。
 *
 * 判据全部来自 2026-11-05 情侣域审核的 B1 缺口：合并内核与绑定模型都在
 * （`CoupleTimetableData` / `PartnerTimetableBinding`），缺的是「把绑定读进来 +
 * 对方档案挑出来」这一层——就是 [CoupleOverlaySource]。这里钉四条：
 *
 * 1. 绑定 + `partner-imported` 档案齐 ⇒ 返回 overlay（周偏移原值、三色随绑定）；
 * 2. 三种「不叠加」 ⇒ null：没绑定、绑定坏值、没有对方档 / 对方档没课；
 * 3. 解码宽松口径与 `CoupleBindingCodec.fromJson` 同款（坏项回落默认，不抛）；
 * 4. 绑定 JSON **本身**坏（不是 JSON 对象）⇒ null，**不动盘**（对比
 *    `platform/CouplePartnerPortImpl.loadBinding` 的 archive+remove 写副作用）；
 * 5. 叠加开关（`coupleTimetableOverlayEnabled`，发布版默认关、顶栏爱心按钮切换）
 *    关着时即使绑定与对方档都在也返回 null —— 发布版判据是
 *    `_isCoupleOverlayActive = _coupleOverlayEnabled && hasPartnerBinding`
 *    （`lib/screens/timetable_screen.dart:517`）。
 *
 * 夹具照 `pages/sync/TimetableSnapshotBridgeTest` 同一套：`InMemoryKeyValueStore`
 * 直接播种 → `TimetableStore` → `TimetableRepository`（`replaceAllProfiles` 落盘）。
 */
class CoupleOverlaySourceTest {

    private val t0 = LocalDateTime.of(2026, 9, 1, 8, 0)

    private fun course(
        id: String,
        name: String,
        day: Int = 1,
        start: Int = 1,
        color: String = "#2196F3",
        startWeek: Int = 1,
        endWeek: Int = 16,
    ) = Course(
        id = id,
        name = name,
        teacher = "",
        location = "",
        dayOfWeek = day,
        startSection = start,
        endSection = start + 1,
        startTime = "08:00",
        endTime = "09:40",
        color = color,
        startWeek = startWeek,
        endWeek = endWeek,
    )

    private fun repository(
        partnerCourses: List<Course>?,
        bindingJson: String?,
        /** 叠加开关（`coupleTimetableOverlayEnabled`）；默认 true = 开着，验叠加本体。 */
        overlayEnabled: Boolean = true,
    ): TimetableRepository {
        val raw = InMemoryKeyValueStore()
        val profiles = buildList {
            add(
                TimetableProfile(
                    id = "p1",
                    name = "我的课表",
                    courses = listOf(course("m1", "英语")),
                    currentWeek = 1L,
                    createdAt = t0,
                    lastUsedAt = t0,
                ),
            )
            if (partnerCourses != null) {
                add(
                    TimetableProfile(
                        id = "partner-imported",
                        name = "TA的课表",
                        courses = partnerCourses,
                        currentWeek = 1L,
                        createdAt = t0,
                        lastUsedAt = t0,
                        profileKind = TimetableProfileKind.PARTNER_IMPORTED,
                    ),
                )
            }
        }
        val store = TimetableStore(raw)
        store.saveProfiles(profiles)
        store.saveActiveProfileId("p1")
        // 叠加开关（存档键，发布版 `timetable_settings.dart:805` 默认 false）。夹具显式落盘，
        // 免得「缺键 = 关」把要验叠加本体的用例全变成 null。
        store.saveSettingsPatch(mapOf("coupleTimetableOverlayEnabled" to overlayEnabled))
        if (bindingJson != null) {
            raw.putString(CoupleOverlaySource.BINDING_KEY, bindingJson)
        }
        return TimetableRepository(store)
    }

    @Test
    fun `绑定加对方档 返回完整叠加参数`() {
        val repo = repository(
            partnerCourses = listOf(course("p1", "高数", color = "#E91E63")),
            bindingJson = """{"partnerName":"小屿","weekOffset":2,"mineColorHex":"#111111",""" +
                """"partnerColorHex":"#222222","togetherColorHex":"#333333"}""",
        )

        val overlay = CoupleOverlaySource.load(repo)!!

        assertEquals(2, overlay.weekOffset)
        assertEquals("#111111", overlay.mineColorHex)
        assertEquals("#222222", overlay.partnerColorHex)
        assertEquals("#333333", overlay.togetherColorHex)
        assertEquals(listOf("p1"), overlay.partnerCourses.map { it.id })
    }

    @Test
    fun `没有绑定键返回null`() {
        val repo = repository(partnerCourses = listOf(course("p1", "高数")), bindingJson = null)
        assertNull(CoupleOverlaySource.load(repo))
    }

    @Test
    fun `叠加开关关着时即使绑定与对方档都在也返回null`() {
        val repo = repository(
            partnerCourses = listOf(course("p1", "高数")),
            bindingJson = """{"weekOffset":1}""",
            overlayEnabled = false,
        )
        assertNull(
            "开关关着（发布版默认）时不能叠对方课——修前这里是「绑了就叠、关不掉」",
            CoupleOverlaySource.load(repo),
        )
    }

    @Test
    fun `没有对方档返回null`() {
        val repo = repository(partnerCourses = null, bindingJson = """{"weekOffset":1}""")
        assertNull(CoupleOverlaySource.load(repo))
    }

    @Test
    fun `对方档没课返回null`() {
        val repo = repository(partnerCourses = emptyList(), bindingJson = """{"weekOffset":1}""")
        assertNull(CoupleOverlaySource.load(repo))
    }

    @Test
    fun `绑定坏值返回null且不动盘`() {
        val repo = repository(partnerCourses = listOf(course("p1", "高数")), bindingJson = "not-json{")
        assertNull(CoupleOverlaySource.load(repo))
        // 只读装配层的契约：坏值留在盘上，不像 platform 层那样 archive+remove。
        assertEquals(
            "not-json{",
            repo.rawStoredJson(CoupleOverlaySource.BINDING_KEY),
        )
    }

    @Test
    fun `绑定项坏时逐项回落默认色与零偏移`() {
        // 口径与 `CoupleBindingCodec.fromJson` 同款：字符串项非字符串 toString 兜底、
        // 周偏移非数字取 0、缺色项回落默认——坏一项不能带走整份绑定。
        val repo = repository(
            partnerCourses = listOf(course("p1", "高数")),
            bindingJson = """{"weekOffset":"abc","partnerColorHex":42}""",
        )

        val overlay = CoupleOverlaySource.load(repo)!!

        assertEquals(0, overlay.weekOffset)
        assertEquals(PartnerTimetableBinding.MINE_COLOR_DEFAULT, overlay.mineColorHex)
        assertEquals("42", overlay.partnerColorHex)
        assertEquals(PartnerTimetableBinding.TOGETHER_COLOR_DEFAULT, overlay.togetherColorHex)
    }

    @Test
    fun `周偏移越界钳制到正负十五`() {
        val repo = repository(
            partnerCourses = listOf(course("p1", "高数")),
            bindingJson = """{"weekOffset":99}""",
        )
        assertEquals(15, CoupleOverlaySource.load(repo)!!.weekOffset)

        val repo2 = repository(
            partnerCourses = listOf(course("p1", "高数")),
            bindingJson = """{"weekOffset":-99}""",
        )
        assertEquals(-15, CoupleOverlaySource.load(repo2)!!.weekOffset)
    }
}
