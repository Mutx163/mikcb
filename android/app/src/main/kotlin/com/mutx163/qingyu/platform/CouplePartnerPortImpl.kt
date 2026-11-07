package com.mutx163.qingyu.platform

import com.mutx163.qingyu.app.KeyValueStore
import com.mutx163.qingyu.app.TimetableRepository
import com.mutx163.qingyu.core.TimetableProfile
import com.mutx163.qingyu.core.TimetableProfileKind
import com.mutx163.qingyu.core.clampCurrentWeekToSettings
import com.mutx163.qingyu.pages.sync.CoupleBindingCodec
import com.mutx163.qingyu.pages.sync.CoupleImportOutcome
import com.mutx163.qingyu.pages.sync.CouplePackageException
import com.mutx163.qingyu.pages.sync.CouplePartnerPackageCodec
import com.mutx163.qingyu.pages.sync.CouplePartnerParseResult
import com.mutx163.qingyu.pages.sync.CouplePartnerPort
import com.mutx163.qingyu.pages.sync.CouplePartnerStorage
import com.mutx163.qingyu.pages.sync.CoupleTimetableSettingsLogic
import com.mutx163.qingyu.pages.sync.CoupleUnlinkStage
import com.mutx163.qingyu.pages.sync.PartnerTimetableBindingModel
import com.mutx163.qingyu.pages.sync.newCouplePackageId
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDateTime
import java.util.Locale
import kotlin.random.Random

/**
 * [CouplePartnerPort] 的**生产实现**：把「对方课表绑定」与「对方课表档案」落到真存储。
 *
 * ## 两处存储，一次动作
 *
 * | 数据 | 落在哪 | 键 / 标识 |
 * |---|---|---|
 * | 绑定（周偏移 + 三色 + 上次导入时间 + 来源哈希） | `FlutterSharedPreferences` | `partner_timetable_binding` |
 * | 对方课表本体 | 课表档案列表 | `timetable_profiles` 里 `id = partner-imported`、`profileKind = partnerImported` |
 *
 * 与 Dart 完全同构（`storage_service.dart:38` 的 `_partnerTimetableBindingKey`、
 * `PartnerTimetableService.partnerProfileId`）。**只写一边**会造成两种用户可见的坏状态：
 * 有绑定没档案 → 页面写「已绑定」而 TA 的课节数是 0；有档案没绑定 → 课表页不知道叠加谁。
 *
 * ## 为什么不用 `TimetableStore.saveProfiles` 直连
 *
 * 仓储 `replaceAllProfiles` 是「先落盘、成功后才改内存并通知」的唯一入口
 * （见其 KDoc）。绕过它直接写盘，课表页的内存快照不会更新，用户返回课表看不到变化。
 *
 * ## 诚实边界
 *
 * 本类引 `app` / `core` 的纯 Kotlin 类型，但位于 `platform/`，**不参与 L0 模块编译**
 * （L0 的 classpath 只收 `pages/<域>` + 白名单共享目录）。它能被真 Gradle 编译验证，
 * 行为判据则全部下沉在 `CouplePartnerPackageCodec` / `CoupleBindingCodec`（L0 覆盖）。
 */
class CouplePartnerPortImpl(
    private val repository: TimetableRepository,
    private val store: KeyValueStore,
    private val nowMicros: () -> Long = { System.currentTimeMillis() * 1000L },
) : CouplePartnerPort {

    override fun loadBinding(): PartnerTimetableBindingModel? {
        val raw = store.getString(BINDING_KEY)
        if (raw.isNullOrEmpty()) return null
        val parsed = CoupleBindingCodec.parse(raw)
        if (parsed == null) {
            // 坏值留档再删（与 TimetableStore / WebdavConfigStoreImpl 同一自愈口径）。
            store.archiveCorruptAndRemove(BINDING_KEY, nowMicros())
            return null
        }
        return parsed
    }

    override fun saveBinding(binding: PartnerTimetableBindingModel) {
        store.putString(BINDING_KEY, CoupleBindingCodec.encode(binding))
    }

    /**
     * 解除绑定（S2，2026-11-05 复核修复）：**先删对方课本档案、成功后清绑定键**。
     *
     * 顺序照抄发布版 `partner_timetable_service.dart:132-139`：`updateProfiles(去掉情侣档)`
     * 成功之后才 `savePartnerTimetableBinding(null)`。反过来（旧实现先 `remove` 绑定再删档）
     * 一旦删档落盘失败，就留下「无绑定 + 有档案」的孤儿档——`timetable_profiles` 里那份
     * `partnerImported` 在课表管理页既删不掉（`TimetableProfilesController` 拒删）也切不走。
     *
     * 两步各自 try：失败不抛、按 [CoupleUnlinkStage] 如实回报，由控制器给不同提示
     * （旧实现一律「保存失败」，用户看不出「档案还在」还是「绑定没清」）。
     */
    override fun unlink(): CoupleUnlinkStage {
        val snapshot = repository.snapshot
        val next = snapshot.profiles.filter { it.id != CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID }
        if (next.size != snapshot.profiles.size) {
            // 发布版 `timetable_partner_service.dart:161-184`：active 正是被删的情侣档时，
            // 切回第一份非情侣档并落盘；否则界面会停在一份已删除的课表上。
            val nextActiveId = if (snapshot.activeProfileId == CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID) {
                next.firstOrNull { !it.isPartnerImported }?.id ?: next.firstOrNull()?.id
                ?: snapshot.activeProfileId
            } else {
                snapshot.activeProfileId
            }
            try {
                // 落盘失败会抛（仓储 replaceAllProfiles 的契约）；此时绑定一个字节都没动。
                repository.replaceAllProfiles(next, nextActiveId)
            } catch (_: Exception) {
                return CoupleUnlinkStage.PROFILE_DELETE_FAILED
            }
        }
        return try {
            store.remove(CouplePartnerStorage.BINDING_KEY)
            CoupleUnlinkStage.DONE
        } catch (_: Exception) {
            CoupleUnlinkStage.BINDING_CLEAR_FAILED
        }
    }

    override fun partnerCourseCount(): Int =
        partnerProfile()?.courses?.size ?: 0

    override fun partnerProfileName(): String? =
        partnerProfile()?.name?.takeIf { it.isNotBlank() }

    override fun importPackage(content: String): CoupleImportOutcome {
        val parsed = CouplePartnerPackageCodec.parse(content)
        if (parsed is CouplePartnerParseResult.Failed) {
            throw CouplePackageException(parsed.errorCode)
        }
        val pkg = (parsed as CouplePartnerParseResult.Ok).pkg
        val snapshot = repository.snapshot
        val existingProfile = partnerProfile()
        val previousBinding = loadBinding()
        val nowIso = Instant.now().toString()
        val now = LocalDateTime.now()

        val displayName = pkg.profileName
            ?: previousBinding?.partnerName?.takeIf { it.isNotBlank() }
            ?: CoupleTimetableSettingsLogic.PARTNER_NAME_FALLBACK

        val profile = TimetableProfile(
            id = CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID,
            name = displayName,
            courses = pkg.courses,
            settings = pkg.settings,
            currentWeek = clampCurrentWeekToSettings(pkg.currentWeek, pkg.settings),
            // 已有档案要保留原始创建时间（Dart `importFromContent` 同口径）。
            createdAt = existingProfile?.createdAt ?: now,
            lastUsedAt = now,
            profileKind = TimetableProfileKind.PARTNER_IMPORTED,
        )
        val nextProfiles = snapshot.profiles
            .filter { it.id != CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID } + profile
        // 落盘 + 通知（内部会 notifyStateChanged），课表页据此重读叠加数据。
        repository.replaceAllProfiles(nextProfiles, snapshot.activeProfileId)

        saveBinding(
            PartnerTimetableBindingModel(
                partnerName = displayName,
                lastImportedAtIso = nowIso,
                weekOffset = previousBinding?.weekOffset ?: 0,
                mineColorHex = previousBinding?.mineColorHex
                    ?: CoupleTimetableSettingsLogic.MINE_COLOR_DEFAULT,
                partnerColorHex = previousBinding?.partnerColorHex
                    ?: CoupleTimetableSettingsLogic.PARTNER_COLOR_DEFAULT,
                togetherColorHex = previousBinding?.togetherColorHex
                    ?: CoupleTimetableSettingsLogic.TOGETHER_COLOR_DEFAULT,
                partnerProfileId = CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID,
                linkedAtIso = previousBinding?.linkedAtIso ?: nowIso,
                sourceFileHash = sha256Hex(content),
            ),
        )
        // Dart：isUpdate = 已有绑定 **且** 已有对方档案（两个条件都成立才叫「更新」）。
        return CoupleImportOutcome(
            updated = previousBinding != null && existingProfile != null,
            droppedTotal = pkg.droppedTotal,
        )
    }

    override fun buildMyPackage(): String {
        val snapshot = repository.snapshot
        val active = snapshot.profiles.firstOrNull { it.id == snapshot.activeProfileId }
            ?: snapshot.profiles.firstOrNull()
        return CouplePartnerPackageCodec.buildMine(
            profileName = active?.name,
            courses = active?.courses.orEmpty(),
            tasks = active?.tasks.orEmpty(),
            scheduleItems = active?.scheduleItems.orEmpty(),
            settings = snapshot.settings,
            currentWeek = snapshot.currentWeek,
            exportedAtIso = Instant.now().toString(),
            packageId = newCouplePackageId(
                epochMicros = nowMicros(),
                random32 = Random.nextInt(),
            ),
        )
    }

    override fun currentWeek(): Int = repository.snapshot.currentWeek

    override fun notifyTimetableChanged() {
        repository.notifyStateChanged()
    }

    private fun partnerProfile(): TimetableProfile? =
        repository.snapshot.profiles.firstOrNull {
            it.id == CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID
        }

    private fun sha256Hex(content: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(content.toByteArray(Charsets.UTF_8))
        // 来源哈希会作为对方端点 id 落盘；默认 Locale 下 `%02x` 可能产出非 ASCII 数字，
        // 会让同一份内容在两端得到不同 id，必须固定 ASCII 十六进制。
        return digest.joinToString("") { String.format(Locale.ROOT, "%02x", it) }
    }

    companion object {
        /**
         * 绑定键（Dart `storage_service.dart:38` 的 `_partnerTimetableBindingKey`）。
         *
         * 值只有一个来源：[CouplePartnerStorage.BINDING_KEY]——`pages/timetable` 读绑定态、
         * 快照桥判孤儿档都要用同一个字符串，散落成几份字面量迟早对不上。
         */
        const val BINDING_KEY: String = CouplePartnerStorage.BINDING_KEY
    }
}
