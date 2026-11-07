package com.mutx163.qingyu.pages.timetable

/**
 * 课表档案项数据结构（对应 `lib/models/timetable_profile.dart`）。
 */
data class TimetableProfileItem(
    val id: String,
    val name: String,
    val isActive: Boolean = false,
    val isPartnerImported: Boolean = false,
    val courseCount: Int = 0,
    val timeSchemeId: String? = null,
    /** 当前教学周：渲染层汇总行「N 门课程 · 第 N 周」要用。 */
    val currentWeek: Long = 1,
)

/**
 * 课表管理页视图状态。
 */
data class TimetableProfilesState(
    val profiles: List<TimetableProfileItem> = emptyList(),
    val activeProfileId: String? = null,
    val errorMessage: String? = null,
) {
    val activeProfile: TimetableProfileItem?
        get() = profiles.firstOrNull { it.id == activeProfileId }

    val canDeleteAny: Boolean
        get() = profiles.size > 1
}

/**
 * 课表档案状态机与业务守卫逻辑（纯函数，零 Android/UI 依赖）。
 */
class TimetableProfilesLogic {

    /**
     * 新建课表。
     * 若未提供名称或名称为空白，回落至「未命名课表」。
     */
    fun createProfile(
        state: TimetableProfilesState,
        name: String,
        id: String? = null,
        timeSchemeId: String? = null,
    ): TimetableProfilesState {
        val trimmed = name.trim()
        val finalName = if (trimmed.isEmpty()) TimetableStrings.unnamedTimetableProfile.text else trimmed
        val newId = id ?: "profile_${System.currentTimeMillis()}"

        val newItem = TimetableProfileItem(
            id = newId,
            name = finalName,
            isActive = false,
            isPartnerImported = false,
            courseCount = 0,
            timeSchemeId = timeSchemeId,
        )

        return state.copy(
            profiles = state.profiles + newItem,
            errorMessage = null,
        )
    }

    /**
     * 切换当前激活课表。
     * 拒绝切换到情侣导入的只读课表。
     */
    fun switchProfile(state: TimetableProfilesState, id: String): TimetableProfilesState {
        val target = state.profiles.firstOrNull { it.id == id }
            ?: return state.copy(errorMessage = "未找到指定课表")

        if (target.isPartnerImported) {
            return state.copy(errorMessage = "不能切换到情侣导入的只读课表")
        }

        val updated = state.profiles.map { profile ->
            profile.copy(isActive = (profile.id == id))
        }

        return state.copy(
            profiles = updated,
            activeProfileId = id,
            errorMessage = null,
        )
    }

    /**
     * 重命名课表。
     * 拒绝重命名情侣导入课表；名称不可为空白。
     */
    fun renameProfile(
        state: TimetableProfilesState,
        id: String,
        newName: String,
    ): TimetableProfilesState {
        val target = state.profiles.firstOrNull { it.id == id }
            ?: return state.copy(errorMessage = "未找到指定课表")

        if (target.isPartnerImported) {
            return state.copy(errorMessage = "不能重命名情侣导入课表")
        }

        val trimmed = newName.trim()
        if (trimmed.isEmpty()) {
            return state.copy(errorMessage = "课表名称不能为空")
        }

        val updated = state.profiles.map { profile ->
            if (profile.id == id) profile.copy(name = trimmed) else profile
        }

        return state.copy(
            profiles = updated,
            errorMessage = null,
        )
    }

    /**
     * 复制课表档案。
     * 拒绝复制情侣导入课表。
     */
    fun duplicateProfile(
        state: TimetableProfilesState,
        id: String,
        newId: String? = null,
        suffix: String = " (副本)",
    ): TimetableProfilesState {
        val target = state.profiles.firstOrNull { it.id == id }
            ?: return state.copy(errorMessage = "未找到指定课表")

        if (target.isPartnerImported) {
            return state.copy(errorMessage = "不能复制情侣导入课表")
        }

        val generatedId = newId ?: "${target.id}_copy_${System.currentTimeMillis()}"
        val duplicateItem = TimetableProfileItem(
            id = generatedId,
            name = "${target.name}$suffix",
            isActive = false,
            isPartnerImported = false,
            courseCount = target.courseCount,
            timeSchemeId = target.timeSchemeId,
        )

        return state.copy(
            profiles = state.profiles + duplicateItem,
            errorMessage = null,
        )
    }

    /**
     * 删除课表档案。
     *
     * 守卫规则：
     * 1. 至少保留一个课表（profiles.size <= 1 时拒绝删除）；
     * 2. 情侣导入课表拒绝在此删除；
     * 3. 若删除的是当前激活课表，自动将第一个剩余课表设为激活。
     */
    fun deleteProfile(state: TimetableProfilesState, id: String): TimetableProfilesState {
        if (state.profiles.size <= 1) {
            return state.copy(errorMessage = TimetableStrings.keepAtLeastOneProfile.text)
        }

        val target = state.profiles.firstOrNull { it.id == id }
            ?: return state.copy(errorMessage = "未找到指定课表")

        if (target.isPartnerImported) {
            return state.copy(errorMessage = "不能删除情侣导入课表")
        }

        val remaining = state.profiles.filter { it.id != id }
        val newActiveId = if (state.activeProfileId == id) {
            remaining.firstOrNull()?.id
        } else {
            state.activeProfileId
        }

        val updatedProfiles = remaining.map { profile ->
            profile.copy(isActive = (profile.id == newActiveId))
        }

        return state.copy(
            profiles = updatedProfiles,
            activeProfileId = newActiveId,
            errorMessage = null,
        )
    }

    /**
     * 清空指定课表的所有课程。
     * 拒绝清空情侣导入课表。
     */
    fun clearCourses(state: TimetableProfilesState, id: String): TimetableProfilesState {
        val target = state.profiles.firstOrNull { it.id == id }
            ?: return state.copy(errorMessage = "未找到指定课表")

        if (target.isPartnerImported) {
            return state.copy(errorMessage = "不能清空情侣导入课表")
        }

        val updated = state.profiles.map { profile ->
            if (profile.id == id) profile.copy(courseCount = 0) else profile
        }

        return state.copy(
            profiles = updated,
            errorMessage = null,
        )
    }

    // ── 便捷判定函数 ──

    fun canDelete(state: TimetableProfilesState, id: String): Boolean {
        if (state.profiles.size <= 1) return false
        val item = state.profiles.firstOrNull { it.id == id } ?: return false
        return !item.isPartnerImported
    }

    fun canSwitch(item: TimetableProfileItem): Boolean = !item.isPartnerImported

    fun canRename(item: TimetableProfileItem): Boolean = !item.isPartnerImported

    fun canDuplicate(item: TimetableProfileItem): Boolean = !item.isPartnerImported

    fun canClear(item: TimetableProfileItem): Boolean = !item.isPartnerImported && item.courseCount > 0
}
