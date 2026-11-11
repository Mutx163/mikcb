package com.mutx163.qingyu.pages.timetable

import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.app.TimetableSnapshot
import com.mutx163.qingyu.app.TimetableStore
import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableSettings
import com.mutx163.qingyu.core.WeekCalculator
import com.mutx163.qingyu.weather.BingWallpaperPrefs
import com.mutx163.qingyu.weather.WallpaperEvictionSources
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
        val partnerBound = hasPartnerBinding()
        return snap.profiles
            // 孤儿对方档（有 `partner-imported` 档案、本机却没有任何绑定）不给用户看：
            // 它在 App 里既显示不出内容、又切不走，留在列表里只会让人以为数据坏了。
            // 这里只**隐藏**、不落盘删（绑定键被坏值留档清掉时档案还能救；
            // 真恢复场景由 `TimetableSnapshotBridge.applySnapshot` 在写入前一并剔掉）。
            .filterNot { isOrphanPartnerProfile(it, partnerBound) }
            .map { buildItem(it, isActive = it.id == snap.activeProfileId) }
    }

    /** 新建课表：空课程、立即激活、落盘（一条通知）。 */
    fun createProfile(name: String): TimetableProfileActionResult {
        val snap = snapshot
        val finalName = name.trim().ifEmpty { TimetableStrings.unnamedTimetableProfile.text }
        val now = clock()
        // 新档不继承源档的档案级外观（Dart `_buildDefaultSettingsForNewProfile:1787-1798` 只带
        // 作息 sections），但全局偏好是整机级、必须跟着走（`app_global_settings_service.dart:59-114`）。
        // 当前 Kotlin 的全局偏好仍寄存在活动档内嵌 settings，故先摘出白名单键再铺到新档。
        val globalPreferences = globalSettingsOf(snap)
        val newProfile = TimetableProfile(
            id = idFactory(),
            name = finalName,
            courses = emptyList(),
            settings = defaultSettingsForNewProfile(snap),
            currentWeek = 1L,
            createdAt = now,
            lastUsedAt = now,
        )
        val result = write(
            profiles = snap.profiles + newProfile,
            activeProfileId = newProfile.id,
            failureMessage = TimetableStrings.saveFailed.text,
            settings = newProfile.settings,
            currentWeek = currentWeekFor(newProfile),
        ) { TimetableStrings.formatCreatedProfile(finalName) }
        return seedActiveSettings(result, globalPreferences, snap)
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
            // 切档 = 换激活 id **并且**把全局设置换成目标档那份（Dart `_applyProfileState`）。
            // 仓储的 setActiveProfile 只换 id，设置会留在旧档，所以走合并写入口。
            // 当前周同样按**目标档**的开学日重算（不能带着上一份课表的周数）。
            // Dart `switchProfile:2034` 带 `touchLastUsedAt: true`：目标档的「最近使用」要刷新，
            // 一并塞进同一次整份替换里，保持「一次写 + 一次通知」。
            val now = clock()
            val nextProfiles = snap.profiles.map { profile ->
                if (profile.id == id) profile.copy(lastUsedAt = now) else profile
            }
            repository.replaceAllProfilesAndSettings(
                profiles = nextProfiles,
                activeProfileId = id,
                settings = target.settings,
                currentWeek = currentWeekFor(target),
            )
            TimetableProfileActionResult.Success(TimetableStrings.formatSwitchedToProfile(target.name))
        } catch (_: Exception) {
            TimetableProfileActionResult.Failed(TimetableStrings.saveFailed.text)
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
            failureMessage = TimetableStrings.saveFailed.text,
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
        // Dart `duplicateActiveProfile:1967-1972` 用 `source.copyWith(...)`，拷贝的是**整份**
        // `TimetableSettings`；Kotlin 的 `TimetableProfile.settings` 只有 core 4 键，完整外观/语言
        // 都在档案内嵌 JSON 里，所以先把源档内嵌整份取出，落盘后再铺到复制品。
        //
        // 2026-11-11 修（数据完整性）：非活动档的 44 个全局键只是**旧镜像**，裸读会把它原样写进
        // `app_global_settings_v1` 真源 ⇒ 用户当前主题/字体/语言被旧档顶掉且无提示。
        // 走 [settingsWithDeviceGlobals]：非全局键继承源档，全局键只认本机真源。
        val sourceSettings = settingsWithDeviceGlobals(source.id)
        val copy = source.copy(
            id = idFactory(),
            name = "${source.name} 副本",
            createdAt = now,
            lastUsedAt = now,
        )
        val result = write(
            profiles = snap.profiles + copy,
            activeProfileId = copy.id,
            failureMessage = TimetableStrings.saveFailed.text,
            settings = copy.settings,
            currentWeek = currentWeekFor(copy),
        ) { TimetableStrings.copiedCurrentTimetable.text }
        return seedActiveSettings(result, sourceSettings, snap)
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
            return TimetableProfileActionResult.Rejected(TimetableStrings.noCoursesInCurrentProfile.text)
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
            TimetableProfileActionResult.Failed(TimetableStrings.clearFailed.text)
        }
    }

    /**
     * 删除课表：至少留一份、拒删**仍有绑定**的情侣导入档；删激活档时自动激活第一份
     * 非情侣导入档。
     *
     * 2026-11-05（S1 自愈）：情侣导入档以前无条件拒删，于是「恢复备份后留下的孤儿档」
     * 永远删不掉。现在**没有绑定**的情侣档可以删（它就是孤儿），仍有绑定的照旧拒删——
     * 解绑入口在情侣页，删档入口在这里，两者不该互相顶牛。
     */
    fun deleteProfile(id: String): TimetableProfileActionResult {
        val snap = snapshot
        if (snap.profiles.size <= 1) {
            return TimetableProfileActionResult.Rejected(TimetableStrings.keepAtLeastOneProfile.text)
        }
        val target = snap.profiles.firstOrNull { it.id == id }
            ?: return TimetableProfileActionResult.Rejected()
        val orphanPartner = isOrphanPartnerProfile(target, hasPartnerBinding())
        if (target.isPartnerImported && !orphanPartner) {
            return TimetableProfileActionResult.Rejected()
        }
        val isActive = id == snap.activeProfileId
        // 回退档必须是非情侣导入档（Dart :2099-2108）：否则删完没有可工作的课表。
        val fallbacks = snap.profiles.filter { it.id != id && !it.isPartnerImported }
        if (isActive && fallbacks.isEmpty()) {
            return TimetableProfileActionResult.Rejected(TimetableStrings.keepAtLeastOneProfile.text)
        }
        val remaining = snap.profiles.filter { it.id != id }
        val newActiveId = if (isActive) fallbacks.first().id else snap.activeProfileId
        // 回收候选必须取**删除前**那份档案的壁纸（删完就从盘上消失了）。
        val profilesJsonBefore = readRawJson(TimetableStore.KEY_PROFILES)
        // 删激活档会自动换档，全局设置要跟着回退档走（Dart 删档后同样 `_applyProfileState`）。
        val nextActive = remaining.firstOrNull { it.id == newActiveId }
        val result = write(
            profiles = remaining,
            activeProfileId = newActiveId,
            failureMessage = TimetableStrings.deleteFailed.text,
            settings = nextActive?.settings,
            currentWeek = nextActive?.let { currentWeekFor(it) },
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
        val ledger = readRawJson(BingWallpaperPrefs.LEDGER)
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

    /**
     * 统一的「整份替换 + 落盘」：成功才取成功文案；落盘抛错 → [TimetableProfileActionResult.Failed]。
     *
     * [settings] 非空时走 `replaceAllProfilesAndSettings`：切档/新建/复制/删档回退会换激活档，
     * 全局设置必须**同步**换成新激活档的那份（Dart `_applyProfileState`，
     * `timetable_provider.dart:1139-1152`）。只换 `activeProfileId` 会出现
     * 「课程是新档的、学期/作息还是旧档的」。两次写入合并成一次，监听者只收一次通知。
     */
    private inline fun write(
        profiles: List<TimetableProfile>,
        activeProfileId: String?,
        failureMessage: String,
        settings: TimetableSettings? = null,
        currentWeek: Int? = null,
        successMessage: () -> String,
    ): TimetableProfileActionResult = try {
        if (settings != null) {
            repository.replaceAllProfilesAndSettings(profiles, activeProfileId, settings, currentWeek)
        } else {
            repository.replaceAllProfiles(profiles, activeProfileId)
        }
        TimetableProfileActionResult.Success(successMessage())
    } catch (_: Exception) {
        TimetableProfileActionResult.Failed(failureMessage)
    }

    /**
     * 把「整份/白名单」settings 铺到**新激活档**的内嵌 settings。
     *
     * 必须在 [write] 成功之后调用（此时活动档 = 新建/复制出的那份）。仓储的
     * [TimetableRepository.writeRawSettingsPatch] 与 `store.saveSettingsPatchToActiveProfile`
     * 同口径：只合并 [patch] 出现的键，其余键保留。失败时回滚到 [before] 的整份状态
     * （Dart `_rollbackProfileMutation:1991-2008`），避免留下「多一份档、外观还是默认值」的中间态。
     */
    private fun seedActiveSettings(
        result: TimetableProfileActionResult,
        patch: Map<String, Any?>,
        before: TimetableSnapshot,
    ): TimetableProfileActionResult {
        if (result !is TimetableProfileActionResult.Success || patch.isEmpty()) return result
        if (repository.writeRawSettingsPatch(patch)) return result
        runCatching {
            repository.replaceAllProfilesAndSettings(
                profiles = before.profiles,
                activeProfileId = before.activeProfileId,
                settings = before.settings,
                currentWeek = before.currentWeek,
            )
        }
        return TimetableProfileActionResult.Failed(TimetableStrings.saveFailed.text)
    }

    /** 当前活动档的完整内嵌 settings（等价 `store.loadSettingsJson()`，走只读公开入口）。 */
    private fun globalSettingsOf(snap: TimetableSnapshot): Map<String, Any?> =
        rawSettingsOf(snap.activeProfileId)
            .filterKeys { key -> key in GLOBAL_SETTINGS_KEYS }

    /**
     * 本机**整机级真源**的 44 键当前值。
     *
     * 活动档走 [rawSettingsOf]（= `readRawSettings()`，档案内嵌 + 44 键 overlay），
     * 所以取出来的全局键就是真源值，而不是某份档案的旧镜像。
     */
    private fun deviceGlobalSettings(): Map<String, Any?> =
        globalSettingsOf(snapshot)

    /**
     * 源档的完整 settings **合成视图**：档案内嵌的**非全局**键 + 本机全局真源。
     *
     * 为什么不能直接 `rawSettingsOf`：非活动档内嵌的那 44 个键是旧镜像，
     * 原样铺到新档时 `writeRawSettingsPatch` 会按 `split` 把它们写进
     * `app_global_settings_v1` 真源，等于用旧档把用户当前的主题 / 字体 / 语言覆盖掉，
     * 读侧 overlay 立刻生效、无任何提示（2026-11-11 修复，契约测试
     * `ProfileDuplicateGlobalSettingsContractTest`）。
     *
     * 读不到内嵌设置时原样返回空表：调用方会跳过铺设，不误删其它键。
     */
    private fun settingsWithDeviceGlobals(profileId: String?): Map<String, Any?> {
        val embedded = rawSettingsOf(profileId)
        if (embedded.isEmpty()) return embedded
        val out = LinkedHashMap<String, Any?>(embedded.size + GLOBAL_SETTINGS_KEYS.size)
        for ((key, value) in embedded) {
            if (key !in GLOBAL_SETTINGS_KEYS) out[key] = value
        }
        for ((key, value) in deviceGlobalSettings()) out[key] = value
        return out
    }

    /**
     * 取指定档案的完整内嵌 settings：活动档走 `readRawSettings()`，非活动档从 `profiles`
     * 原始 JSON 里按 id 找。读不到 / 读不懂时返回空表（调用方会跳过铺设，不误删其它键）。
     */
    private fun rawSettingsOf(profileId: String?): Map<String, Any?> {
        if (profileId == null) return emptyMap()
        // 读失败（含播种全局那份时的落盘失败）一律当「读不到」：铺设是可选增强，
        // 不能因为它把新建/复制本身变成异常（例如磁盘已满时创建仍应返回 Failed 而不是崩）。
        return try {
            if (profileId == snapshot.activeProfileId) {
                repository.readRawSettings()
            } else {
                val profiles = readRawJson(TimetableStore.KEY_PROFILES).let { read ->
                    if (!read.ok) return emptyMap()
                    runCatching { MiniJson.parse(read.value ?: "[]") }.getOrNull()
                } as? List<*> ?: return emptyMap()
                val settings = profiles
                    .asSequence()
                    .mapNotNull { it as? Map<*, *> }
                    .firstOrNull { it["id"] == profileId }
                    ?.get("settings") as? Map<*, *> ?: return emptyMap()
                settings.entries
                    .mapNotNull { entry -> (entry.key as? String)?.let { it to entry.value } }
                    .toMap()
            }
        } catch (error: Exception) {
            LOGGER.warning("read profile settings failed: id=$profileId, error=$error")
            emptyMap()
        }
    }

    /**
     * 换档后的「当前周」：对齐 Dart `_applyProfileState`（`timetable_provider.dart:1139-1148`）。
     *
     * - 目标档**有开学日** ⇒ 按它自己的开学日把「今天」换算成日历周，再钳进学期周数
     *   （两份课表开学日不同时，切过去必须是目标档该在的那一周，而**不是**恢复上次浏览停留的周次）；
     * - 无开学日 ⇒ 无从推导，保留目标档持久化的 `currentWeek` 再钳（v2.0 行为）。
     */
    private fun currentWeekFor(profile: TimetableProfile): Int {
        val settings = profile.settings
        val week = WeekCalculator.calendarWeekForDate(
            date = clock(),
            semesterStart = settings.semesterStartDate,
            fallback = profile.currentWeek.toInt(),
        )
        return clampCurrentWeek(week, settings.semesterWeekCount)
    }

    /** Dart `clampCurrentWeekToSettings`（`lib/models/timetable_profile.dart:27-38`）。 */
    private fun clampCurrentWeek(week: Int, semesterWeekCount: Int): Int {
        val maxWeek = semesterWeekCount.coerceAtLeast(1)
        return week.coerceIn(1, maxWeek)
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

    /**
     * 本机是否还持有对方课表绑定（`partner_timetable_binding` 有值）。
     *
     * 读的是**同一份** `FlutterSharedPreferences`：`KeyValueStore` 的逻辑 key 不带
     * `flutter.` 前缀，情侣页写进去的键在这里按同一口径读得到。
     * 只判「有没有值」、不解码：键在、值坏也算「可能还绑定着」（坏值的留档自愈在
     * `CouplePartnerPortImpl.loadBinding` 那一层，这里不该顺手删别人的键）。
     */
    private fun hasPartnerBinding(): Boolean =
        !repository.rawStoredJson(PARTNER_BINDING_KEY).isNullOrBlank()

    /** 孤儿对方档：是对方课表档案，但本机已经没有绑定（S1 自愈的判据）。 */
    private fun isOrphanPartnerProfile(profile: TimetableProfile, partnerBound: Boolean): Boolean =
        profile.isPartnerImported && !partnerBound

    private companion object {
        /**
         * 绑定键（Dart `storage_service.dart:38` 的 `_partnerTimetableBindingKey`）。
         *
         * 与 `pages/sync/CoupleStores.kt` 的 `CouplePartnerStorage.BINDING_KEY` **必须同值**：
         * 本模块的 L0 classpath 不含 `pages/sync`，没法直接引那个常量，所以重复声明一份；
         * 一致性由 `CouplePartnerBindingKeyGuardTest` 逐字比对（改两边任一就红）。
         */
        const val PARTNER_BINDING_KEY: String = "partner_timetable_binding"

        /**
         * 整机级「全局偏好」键集，逐字对齐 Dart `lib/services/app_global_settings_service.dart:59-114`。
         *
         * 新建档只从当前活动档摘出这些键铺过去（Dart 新档 settings = `defaults()`
         * + 当前作息 sections，再经 `_applyProfileState` 叠全局）；档案级外观/课表项不继承。
         *
         * 待 `app_global_settings_v1` 专线落地后，这份清单应改为共享常量并直接读全局真源。
         */
        val GLOBAL_SETTINGS_KEYS: Set<String> = setOf(
            // 首页导航 / 图标（:60-70）
            "homeNavigationForm",
            "glassDockActions",
            "glassDockShowAddButton",
            "glassDockButtonEntryId",
            "glassDockButtonIconName",
            "homeTitleStyle",
            "homeMenuStyle",
            "homeGridMenuActions",
            // 底部标签（:71-74）
            "glassDockShowDayTab",
            "glassDockShowWeekTab",
            "glassDockShowSettingsTab",
            // 材质 / 玻璃（:75-89）
            "frostedBlurEnabled",
            "liquidGlassPreset",
            "liquidGlassTuning",
            "liquidGlassTuningDark",
            "linkLiquidGlassTuning",
            "darkGlassBoostEnabled",
            "liquidGlassDockEnabled",
            "courseCardSurfaceStyle",
            "courseCardGlassTuning",
            "courseCardGlassPreset",
            "homeBandGlassMaterial",
            "homePageTimeColumnBlurEnabled",
            // 主题 / 字体 / 语言（:90-103）
            "appThemeMode",
            "appFontMode",
            "appFontWeight",
            "appTextScale",
            "themeSeedColor",
            "foruiTheme",
            "savedThemes",
            "themeCheckpointName",
            "themeCheckpointConfig",
            "appLocaleTag",
            // 通用（:104-107）
            "pageTransitionSpeed",
            "enableHaptics",
            "homePullQuickImportEnabled",
            "liveHideFromRecents",
            // 应用内更新（:108-114）
            "appUpdateDownloadSource",
            "appUpdateDownloadChannel",
            "appUpdateUseSystemDownloader",
            "appUpdateMirrorPreset",
            "appUpdateIncludePrerelease",
            "appUpdateMirrorUrlPrefix",
            "appUpdatePromptEnabled",
        )

        /**
         * 纯 JVM 日志（`java.util.logging` 在 Android 上映射到 logcat）。
         *
         * 本类刻意不引 `android.util.Log`：`pages/timetable` 在 L0 里按纯 Kotlin 编译，
         * 一旦混入 Android 依赖，整个模块的轻量单测通道会被跳过。
         */
        val LOGGER: Logger = Logger.getLogger("TimetableProfilesController")
    }
}
