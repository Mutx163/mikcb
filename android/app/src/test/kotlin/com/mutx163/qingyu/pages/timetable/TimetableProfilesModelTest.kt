package com.mutx163.qingyu.pages.timetable

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 课表档案管理模型、状态机与守卫单测。
 */
class TimetableProfilesModelTest {

    private val logic = TimetableProfilesLogic()

    @Test
    fun `初始化状态与派生属性按预期工作`() {
        val p1 = TimetableProfileItem("p1", "大一上", isActive = true)
        val p2 = TimetableProfileItem("p2", "大一下", isActive = false)
        val state = TimetableProfilesState(profiles = listOf(p1, p2), activeProfileId = "p1")

        assertEquals(p1, state.activeProfile)
        assertTrue(state.canDeleteAny)

        val singleState = TimetableProfilesState(profiles = listOf(p1), activeProfileId = "p1")
        assertFalse(singleState.canDeleteAny)
    }

    @Test
    fun `createProfile 创建正常课表并支持空白名称回落至未命名课表`() {
        val initial = TimetableProfilesState(
            profiles = listOf(TimetableProfileItem("p1", "默认课表", isActive = true)),
            activeProfileId = "p1",
        )

        val state1 = logic.createProfile(initial, "大二上", id = "p2", timeSchemeId = "scheme1")
        assertEquals(2, state1.profiles.size)
        val created = state1.profiles.find { it.id == "p2" }
        assertNotNull(created)
        assertEquals("大二上", created?.name)
        assertFalse(created?.isActive ?: true)
        assertFalse(created?.isPartnerImported ?: true)
        assertEquals(0, created?.courseCount)
        assertEquals("scheme1", created?.timeSchemeId)
        assertNull(state1.errorMessage)

        // 空白名称回落
        val state2 = logic.createProfile(state1, "   ", id = "p3")
        val fallback = state2.profiles.find { it.id == "p3" }
        assertEquals(TimetableStrings.unnamedTimetableProfile.zh, fallback?.name)
    }

    @Test
    fun `switchProfile 正常切换激活课表并拒绝切换到情侣导入课表`() {
        val p1 = TimetableProfileItem("p1", "课表1", isActive = true)
        val p2 = TimetableProfileItem("p2", "课表2", isActive = false)
        val pPartner = TimetableProfileItem("p_partner", "TA的课表", isPartnerImported = true)
        val state = TimetableProfilesState(
            profiles = listOf(p1, p2, pPartner),
            activeProfileId = "p1",
        )

        // 切换到存在的课表
        val switched = logic.switchProfile(state, "p2")
        assertEquals("p2", switched.activeProfileId)
        assertFalse(switched.profiles.first { it.id == "p1" }.isActive)
        assertTrue(switched.profiles.first { it.id == "p2" }.isActive)
        assertNull(switched.errorMessage)

        // 切换到不存在的课表
        val notFound = logic.switchProfile(state, "unknown")
        assertNotNull(notFound.errorMessage)
        assertEquals("p1", notFound.activeProfileId)

        // 拒绝切换到情侣只读课表
        val partnerSwitched = logic.switchProfile(state, "p_partner")
        assertNotNull(partnerSwitched.errorMessage)
        assertEquals("p1", partnerSwitched.activeProfileId)
    }

    @Test
    fun `renameProfile 正常重命名并拒绝空白名称与情侣导入课表`() {
        val p1 = TimetableProfileItem("p1", "旧名称")
        val pPartner = TimetableProfileItem("p_partner", "TA的课表", isPartnerImported = true)
        val state = TimetableProfilesState(profiles = listOf(p1, pPartner), activeProfileId = "p1")

        // 正常重命名
        val renamed = logic.renameProfile(state, "p1", "  新名称  ")
        assertEquals("新名称", renamed.profiles.first { it.id == "p1" }.name)
        assertNull(renamed.errorMessage)

        // 空白名称拒绝
        val blank = logic.renameProfile(state, "p1", "   ")
        assertNotNull(blank.errorMessage)
        assertEquals("旧名称", blank.profiles.first { it.id == "p1" }.name)

        // 情侣导入课表拒绝
        val partnerRenamed = logic.renameProfile(state, "p_partner", "新名字")
        assertNotNull(partnerRenamed.errorMessage)
        assertEquals("TA的课表", partnerRenamed.profiles.first { it.id == "p_partner" }.name)
    }

    @Test
    fun `duplicateProfile 正常复制并保留课程数与时间模板且拒绝复制情侣课表`() {
        val p1 = TimetableProfileItem("p1", "原课表", courseCount = 15, timeSchemeId = "scheme_a")
        val pPartner = TimetableProfileItem("p_partner", "TA课表", isPartnerImported = true)
        val state = TimetableProfilesState(profiles = listOf(p1, pPartner), activeProfileId = "p1")

        val dup = logic.duplicateProfile(state, "p1", newId = "p1_dup")
        assertEquals(3, dup.profiles.size)
        val copy = dup.profiles.find { it.id == "p1_dup" }
        assertNotNull(copy)
        assertEquals("原课表 (副本)", copy?.name)
        assertEquals(15, copy?.courseCount)
        assertEquals("scheme_a", copy?.timeSchemeId)
        assertFalse(copy?.isActive ?: true)
        assertNull(dup.errorMessage)

        val partnerDup = logic.duplicateProfile(state, "p_partner")
        assertNotNull(partnerDup.errorMessage)
        assertEquals(2, partnerDup.profiles.size)
    }

    @Test
    fun `deleteProfile 守卫规则生效：唯一课表拒绝删除并返回至少保留一个课表`() {
        val p1 = TimetableProfileItem("p1", "唯一课表", isActive = true)
        val singleState = TimetableProfilesState(profiles = listOf(p1), activeProfileId = "p1")

        val result = logic.deleteProfile(singleState, "p1")
        assertEquals(1, result.profiles.size)
        assertEquals(TimetableStrings.keepAtLeastOneProfile.zh, result.errorMessage)
        assertFalse(logic.canDelete(singleState, "p1"))
    }

    @Test
    fun `deleteProfile 守卫规则生效：情侣导入课表拒绝删除`() {
        val p1 = TimetableProfileItem("p1", "我的课表", isActive = true)
        val pPartner = TimetableProfileItem("p_partner", "对方课表", isPartnerImported = true)
        val state = TimetableProfilesState(profiles = listOf(p1, pPartner), activeProfileId = "p1")

        val result = logic.deleteProfile(state, "p_partner")
        assertEquals(2, result.profiles.size)
        assertNotNull(result.errorMessage)
        assertFalse(logic.canDelete(state, "p_partner"))
    }

    @Test
    fun `deleteProfile 正常删除：若删除当前激活课表则自动激活剩余课表`() {
        val p1 = TimetableProfileItem("p1", "课表1", isActive = true)
        val p2 = TimetableProfileItem("p2", "课表2", isActive = false)
        val state = TimetableProfilesState(profiles = listOf(p1, p2), activeProfileId = "p1")

        val deletedActive = logic.deleteProfile(state, "p1")
        assertEquals(1, deletedActive.profiles.size)
        assertEquals("p2", deletedActive.activeProfileId)
        assertTrue(deletedActive.profiles.first().isActive)
        assertNull(deletedActive.errorMessage)

        // 若删除非激活课表，激活状态保持不变
        val state2 = TimetableProfilesState(profiles = listOf(p1, p2), activeProfileId = "p1")
        val deletedInactive = logic.deleteProfile(state2, "p2")
        assertEquals(1, deletedInactive.profiles.size)
        assertEquals("p1", deletedInactive.activeProfileId)
        assertTrue(deletedInactive.profiles.first().isActive)
    }

    @Test
    fun `clearCourses 正常清空课程数且拒绝情侣导入课表`() {
        val p1 = TimetableProfileItem("p1", "课表1", courseCount = 8)
        val pPartner = TimetableProfileItem("p_partner", "对方课表", courseCount = 5, isPartnerImported = true)
        val state = TimetableProfilesState(profiles = listOf(p1, pPartner), activeProfileId = "p1")

        val cleared = logic.clearCourses(state, "p1")
        assertEquals(0, cleared.profiles.first { it.id == "p1" }.courseCount)
        assertNull(cleared.errorMessage)

        val partnerClear = logic.clearCourses(state, "p_partner")
        assertNotNull(partnerClear.errorMessage)
        assertEquals(5, partnerClear.profiles.first { it.id == "p_partner" }.courseCount)
    }

    @Test
    fun `便捷判定函数逻辑正确`() {
        val pNormal = TimetableProfileItem("p1", "课表1", courseCount = 3)
        val pEmpty = TimetableProfileItem("p2", "课表2", courseCount = 0)
        val pPartner = TimetableProfileItem("p3", "TA", isPartnerImported = true, courseCount = 2)

        assertTrue(logic.canSwitch(pNormal))
        assertFalse(logic.canSwitch(pPartner))

        assertTrue(logic.canRename(pNormal))
        assertFalse(logic.canRename(pPartner))

        assertTrue(logic.canDuplicate(pNormal))
        assertFalse(logic.canDuplicate(pPartner))

        assertTrue(logic.canClear(pNormal))
        assertFalse(logic.canClear(pEmpty))
        assertFalse(logic.canClear(pPartner))
    }
}
