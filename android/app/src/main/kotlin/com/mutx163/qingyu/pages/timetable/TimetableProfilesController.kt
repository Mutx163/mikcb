package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.pages.settings.BingWallpaperStore
import com.mutx163.qingyu.pages.settings.WallpaperEvictionSources
import java.io.File
import java.time.LocalDateTime
import java.util.UUID
import java.util.logging.Logger

/**
 * 课表档案动作的结果（纯数据，不含 Compose）。
 *
 * 页面的六个回调都是 `() -> Unit`，宿主拿不到「成没成 / 该弹什么 toast」。
 * 控制器把这件事显式化：宿主只需 `controller.xxx(...).toastOrNull()` 取出文案交给页面。
 */
sealed interface TimetableProfileActionResult {

    /** 成功：屏上应弹的成功 toast（逐字取 [TimetableStrings] 的 ARB 文案）。 */
    data class Success(val toast: String) : TimetableProfileActionResult

    /**
     * 守卫拦截 / 空操作：仓储**没有被改动**。
     * [message] 非空时宿主应作为提示弹出（如「至少保留一个课表」）；null 表示无需提示。
     */
    data class Rejected(val message: String? = null) : TimetableProfileActionResult

    /** 落盘失败：仓储已回滚、未通知（见 [TimetableRepository.replaceAllProfiles] 失败语义）。 */
    data class Failed(val message: String) : TimetableProfileActionResult
}

/** 给宿主用的便捷取值：成功 toast / 拒绝提示 / 失败提示，无需提示时返回 null。 */
fun TimetableProfileActionResult.toastOrNull(): String? = when (this) {
    is TimetableProfileActionResult.Success -> toast
    is TimetableProfileActionResult.Rejected -> message
    is TimetableProfileActionResult.Failed -> message
}

/**
 * 「课表管理」页（[TimetableProfilesPage]）的**仓储接线控制器**（纯逻辑，零 Compose / 零 Android）。
 *
 * ## 它解决什么
 *
 * Phase 3 的页面渲染层已经就绪（列表、对话框、更多操作弹层都在 `TimetableProfilesPage.kt`），
 * 但它的六个回调在壳里是空的（`ShellPageIndex.kt:283` 传 `emptyList()` + 空 lambda）——
 * 于是「新建/切换/重命名/删除/复制/清空」点了什么都不发生。仓储（[TimetableRepository]）
 * 早已带 `profiles` / `activeProfileId`，本控制器把两者接起来。
 *
 * ## 只用仓储的公开写入口，**不碰 `main: app/`**
 *
 * | 页面动作 | 落点 |
 * |---|---|
 * | 切换活动课表 | [TimetableRepository.setActiveProfile] |
 * | 新建 / 重命名 / 复制 / 删除 | [TimetableRepository.replaceAllProfiles]（原子：一次写 + 一次通知） |
 * | 清空课程 | [TimetableRepository.replaceActiveProfileContent]（保留考试，只清课与挂课作业） |
 *
 * ## 行为逐条对齐 Dart（`lib/providers/timetable_provider.dart` / `screens/timetable_profiles_screen.dart`）
 *
 * - **新建**：新档课程为空，**并立即成为激活档**（`createProfile` :1916-1954，`_activeProfileId = profile.id`）；
 *   新档默认设置沿用「当前生效作息模板的 sections」（`_buildDefaultSettingsForNewProfile` :1787-1798）。
 * - **切换**：目标是情侣导入档 / 不存在 / 已是当前档 → 不切（`switchProfile` :2011-2020）。
 * - **重命名**：名称 trim；空名或与原值相同 → 不动（`renameProfile` :2058-2083 + 屏侧守卫）。
 * - **复制**：复制来源档，名字加 `" 副本"` 后缀（`duplicateActiveProfile` :1957-1989），复制品成为激活档。
 * - **删除**：至少保留一份（`_profiles.length <= 1` 拒）；拒删情侣导入档；删的是激活档时
 *   自动激活「第一份非情侣导入档」，且**必须存在**这样的回退档（`deleteProfile` :2085-2159）。
 *   删除成功后**只在这一次流程里**回收该档案的独占用图（判定在
 *   [WallpaperEvictionSources.planProfileDeletionReclaim]）：引用来源读不到 / 读不懂时
 *   一张都不删；删文件失败只记日志，不影响档案删除结果。
 * - **清空**：只清当前激活档；课全删、挂在课上的作业（`courseId != null`）一并删，
 *   **手写作业（courseId == null）与考试保留**（`timetable_course_service.dart:460-497`，
 *   考试不清是有意为之）。
 *
 * ## 依赖注入（可测性）
 *
 * [idFactory] / [clock] 可注入，单测才能断言「新档 id / 名称 / 激活态」而不靠随机与实时钟。
 */
class TimetableProfilesController(
    private val repository: TimetableRepository,
    private val idFactory: () -> String = { UUID.randomUUID().toString() },
    private val clock: () -> LocalDateTime = { LocalDateTime.now() },
) {

    private val snapshot: TimetableSnapshot get() = repository.snapshot

    /** 当前展示条目：把仓储里的真实档案映射成渲染条目（课程数取 `courses.size`）。 */
    fun items(): List<TimetableProfileItem> {
        val snap = snapshot
        return snap.profiles.map { buildItem(it, isActive = it.id == snap.activeProfileId) }
    }

    /** 新建课表：空课程、立即激活、落盘（一条通知）。 */
    fun createProfile(name: String): TimetableProfileActionResult {
        val snap = snapshot
        val finalName = name.trim().ifEmpty { TimetableStrings.unnamedTimetableProfile.zh }
        val now = clock()
        val newProfile = TimetableProfile(
            id = idFactory(),
            name = finalName,
            courses = emptyList(),
            settings = defaultSettingsForNewProfile(snap),
            currentWeek = 1L,
            createdAt = now,
            lastUsedAt = now,
        )
        return write(
            profiles = snap.profiles + newProfile,
            activeProfileId = newProfile.id,
            failureMessage = TimetableStrings.saveFailed.zh,
        ) { TimetableStrings.formatCreatedProfile(finalName) }
    }

    /** 切换激活课表：情侣导入 / 不存在 / 已是当前 → 拒绝，否则切并落盘激活 id。 */
    fun switchProfile(id: String): TimetableProfileActionResult {
        val snap = snapshot
        val target = snap.profiles.firstOrNull { it.id == id }
            ?: return TimetableProfileActionResult.Rejected()
        if (target.isPartnerImported) {
            return TimetableProfileActionResult.Rejected()
        }
        if (id == snap.activeProfileId) {
            return TimetableProfileActionResult.Rejected()
        }
        return try {
            if (repository.setActiveProfile(id)) {
                TimetableProfileActionResult.Success(TimetableStrings.formatSwitchedToProfile(target.name))
            } else {
                TimetableProfileActionResult.Rejected()
            }
        } catch (_: Exception) {
            TimetableProfileActionResult.Failed(TimetableStrings.saveFailed.zh)
        }
    }

    /** 重命名：名称 trim；空名 / 与原值相同 / 情侣导入 → 不动。 */
    fun renameProfile(id: String, newName: String): TimetableProfileActionResult {
        val snap = snapshot
        val target = snap.profiles.firstOrNull { it.id == id }
            ?: return TimetableProfileActionResult.Rejected()
        if (target.isPartnerImported) {
            return TimetableProfileActionResult.Rejected()
        }
        val trimmed = newName.trim()
        if (trimmed.isEmpty() || trimmed == target.name) {
            return TimetableProfileActionResult.Rejected()
        }
        val newProfiles = snap.profiles.map { if (it.id == id) it.copy(name = trimmed) else it }
        return write(
            profiles = newProfiles,
            activeProfileId = snap.activeProfileId,
            failureMessage = TimetableStrings.saveFailed.zh,
        ) { TimetableStrings.formatRenamedProfile(trimmed) }
    }

    /** 复制：复制来源档（课程/作业/考试原样带过去），名字加「 副本」，复制品成为激活档。 */
    fun duplicateProfile(id: String): TimetableProfileActionResult {
        val snap = snapshot
        val source = snap.profiles.firstOrNull { it.id == id }
            ?: return TimetableProfileActionResult.Rejected()
        if (source.isPartnerImported) {
            return TimetableProfileActionResult.Rejected()
        }
        val now = clock()
        val copy = source.copy(
            id = idFactory(),
            name = "${source.name} 副本",
            createdAt = now,
            lastUsedAt = now,
        )
        return write(
            profiles = snap.profiles + copy,
            activeProfileId = copy.id,
            failureMessage = TimetableStrings.saveFailed.zh,
        ) { TimetableStrings.copiedCurrentTimetable.zh }
    }

    /** 清空当前课表：只清激活档；课全删、挂课作业删、手写作业与考试保留。 */
    fun clearCourses(id: String): TimetableProfileActionResult {
        val snap = snapshot
        val target = snap.profiles.firstOrNull { it.id == id }
            ?: return TimetableProfileActionResult.Rejected()
        if (target.isPartnerImported || id != snap.activeProfileId) {
            return TimetableProfileActionResult.Rejected()
        }
        if (target.courses.isEmpty()) {
            return TimetableProfileActionResult.Rejected(TimetableStrings.noCoursesInCurrentProfile.zh)
        }
        val remainingTasks = target.tasks.filter { it.courseId == null }
        return try {
            repository.replaceActiveProfileContent(
                courses = emptyList(),
                tasks = remainingTasks,
                exams = target.exams,
            )
            TimetableProfileActionResult.Success(TimetableStrings.formatClearedProfile(target.name))
        } catch (_: Exception) {
            TimetableProfileActionResult.Failed(TimetableStrings.clearFailed.zh)
        }
    }

    /** 删除课表：至少留一份、拒删情侣导入档；删激活档时自动激活第一份非情侣导入档。 */
    fun deleteProfile(id: String): TimetableProfileActionResult {
        val snap = snapshot
        if (snap.profiles.size <= 1) {
            return TimetableProfileActionResult.Rejected(TimetableStrings.keepAtLeastOneProfile.zh)
        }
        val target = snap.profiles.firstOrNull { it.id == id }
            ?: return TimetableProfileActionResult.Rejected()
        if (target.isPartnerImported) {
            return TimetableProfileActionResult.Rejected()
        }
        val isActive = id == snap.activeProfileId
        if (isActive && snap.profiles.none { it.id != id && !it.isPartnerImported }) {
            // 删激活档必须有「非情侣导入」的回退档，否则删完没有可工作的课表（Dart :2099-2108）。
            return TimetableProfileActionResult.Rejected(TimetableStrings.keepAtLeastOneProfile.zh)
        }
        val remaining = snap.profiles.filter { it.id != id }
        val newActiveId = if (isActive) {
            remaining.first { !it.isPartnerImported }.id
        } else {
            snap.activeProfileId
        }
        // 回收候选必须取**删除前**那份档案的壁纸（删完就从盘上消失了）。
        val profilesJsonBefore = readRawJson(TimetableStore.KEY_PROFILES)
        val result = write(
            profiles = remaining,
            activeProfileId = newActiveId,
            failureMessage = TimetableStrings.deleteFailed.zh,
        ) { TimetableStrings.formatDeletedProfile(target.name) }
        // 只在**档案真的删掉之后**回收；落盘失败（Failed）时档案还在，一张都不动。
        if (result is TimetableProfileActionResult.Success) {
            reclaimDeletedProfileWallpaper(id, profilesJsonBefore)
        }
        return result
    }

    // ---------- 内部 ----------

    /** 一次读原始串的结果：区分「键不存在（null）」与「读操作失败」。 */
    private data class RawRead(val value: String?, val ok: Boolean)

    /**
     * 读盘上原始串。
     *
     * 读失败不能当成「没有值」——那会让回收把「读不到引用」误判成「谁都没在用」。
     * 所以把成败单独带回来，由 [reclaimDeletedProfileWallpaper] 决定跳过。
     */
    private fun readRawJson(key: String): RawRead = try {
        RawRead(repository.rawStoredJson(key), ok = true)
    } catch (error: Exception) {
        LOGGER.warning("read raw settings failed: key=$key, error=$error")
        RawRead(null, ok = false)
    }

    /**
     * 删档案后的**独占用图回收**——本功能唯一的触发点。
     *
     * 候选只来自「刚被删掉的那份档案」；不扫描全盘、不在启动 / 后台触发。
     * 任一引用来源读不到或读不懂时一张都不删，只记日志（判定在
     * [WallpaperEvictionSources.planProfileDeletionReclaim]）。
     *
     * 删文件失败**不影响**档案删除结果：档案已经落盘成功，这里每一步都吞掉异常、只留日志。
     */
    private fun reclaimDeletedProfileWallpaper(
        deletedProfileId: String,
        profilesJsonBefore: RawRead,
    ) {
        if (!profilesJsonBefore.ok) {
            LOGGER.info("skip wallpaper reclaim: profiles before unreadable")
            return
        }
        val profilesAfter = readRawJson(TimetableStore.KEY_PROFILES)
        val settings = readRawJson(TimetableStore.KEY_SETTINGS)
        val ledger = readRawJson(BingWallpaperStore.PREF_LEDGER)
        if (!profilesAfter.ok || !settings.ok || !ledger.ok) {
            LOGGER.info(
                "skip wallpaper reclaim: source unreadable " +
                    "(profiles=${profilesAfter.ok}, settings=${settings.ok}, ledger=${ledger.ok})",
            )
            return
        }
        val plan = try {
            WallpaperEvictionSources.planProfileDeletionReclaim(
                deletedProfileId = deletedProfileId,
                profilesJsonBefore = profilesJsonBefore.value,
                profilesJsonAfter = profilesAfter.value,
                settingsJson = settings.value,
                ledgerJson = ledger.value,
            )
        } catch (error: Exception) {
            LOGGER.warning("skip wallpaper reclaim: plan failed, error=$error")
            return
        }
        if (!plan.referencesKnown) {
            LOGGER.info(
                "skip wallpaper reclaim: references unreadable, " +
                    "candidates=${plan.candidatePaths}",
            )
            return
        }
        for (path in plan.deletablePaths) {
            val deleted = try {
                File(path).delete()
            } catch (error: Exception) {
                LOGGER.warning("wallpaper file was not deleted: $path, error=$error")
                false
            }
            if (!deleted) LOGGER.warning("wallpaper file was not deleted: $path")
        }
    }

    /** 统一的「整份替换 + 落盘」：成功才取成功文案；落盘抛错 → [TimetableProfileActionResult.Failed]。 */
    private inline fun write(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        failureMessage: String,
        successMessage: () -> String,
    ): TimetableProfileActionResult = try {
        repository.replaceAllProfiles(profiles, activeProfileId)
        TimetableProfileActionResult.Success(successMessage())
    } catch (_: Exception) {
        TimetableProfileActionResult.Failed(failureMessage)
    }

    /** 新档默认设置：沿用「当前生效作息模板」（或第一份方案）的 sections，否则用默认模板。 */
    private fun defaultSettingsForNewProfile(snap: TimetableSnapshot): TimetableSettings {
        val base = TimetableSettings.defaults()
        val scheme = snap.timeSchemes.firstOrNull { it.id == snap.activeTimeSchemeId }
            ?: snap.timeSchemes.firstOrNull()
            ?: return base
        return base.copy(activeTimeSchemeId = scheme.id, sections = scheme.sections.toList())
    }

    private fun buildItem(profile: TimetableProfile, isActive: Boolean): TimetableProfileItem =
        TimetableProfileItem(
            id = profile.id,
            name = profile.name,
            isActive = isActive,
            isPartnerImported = profile.isPartnerImported,
            courseCount = profile.courses.size,
            timeSchemeId = profile.settings.activeTimeSchemeId,
            currentWeek = profile.currentWeek,
        )

    private companion object {
        /**
         * 纯 JVM 日志（`java.util.logging` 在 Android 上映射到 logcat）。
         *
         * 本类刻意不引 `android.util.Log`：`pages/timetable` 在 L0 里按纯 Kotlin 编译，
         * 一旦混入 Android 依赖，整个模块的轻量单测通道会被跳过。
         */
        val LOGGER: Logger = Logger.getLogger("TimetableProfilesController")
    }
}
