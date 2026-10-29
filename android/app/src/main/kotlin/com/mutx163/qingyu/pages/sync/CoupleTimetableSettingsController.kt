package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.CoupleWebdavConfig
import com.mutx163.qingyu.sync.shouldSkipCouplePullAsUnchanged
import java.nio.ByteBuffer
import java.nio.charset.CharacterCodingException
import java.nio.charset.CodingErrorAction
import java.time.Instant
import java.time.ZoneId
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.random.Random

/** `connect()` 的结局：成功与否 + 成功后那次自动拉取要弹的提示（可能为 null）。 */
data class CoupleConnectOutcome(
    val ok: Boolean,
    val pullToast: SyncToast?,
)

/**
 * 情侣课表设置页的**状态持有者 + 九个动作**（纯 Kotlin，JVM 单测覆盖）。
 *
 * ## 为什么要有这一层
 *
 * 页面是纯渲染（`viewState` + 三个回调）。旧壳直接给它
 * `binding = null` / `CoupleWebdavConfig()` / 三个空回调 ⇒ 页面永远停在「尚未绑定」、
 * 点什么都毫无反应（见 `docs/plans/2026-10-29-compose-couple-audit.md` §四）。
 * 把「读哪、写哪、失败怎么说」收在这里，壳只负责构造 + 把 System 交互接上。
 *
 * ## 行为真相是 Dart（`lib/services/couple_webdav_service.dart` + 页面九个 `_xxx` 方法）
 *
 * 逐条对齐的要点（错一条就是用户可见的差别）：
 *
 * 1. **手动拉取不强制**（Dart `_pullPartnerWebdav()` 默认 `force: false`）：内容哈希一致
 *    且已有绑定 ⇒ 直接回「对方课表无变化」，不重导入；
 * 2. **连接成功后强制拉一次**（`force: true`）且不再显示进度（本层用 `showBusy=false`）；
 * 3. **404/空文件报 `partner_file_missing`**，不报通用 `pull_failed`
 *    ——所以这里直连 [WebdavRemoteTransport] 而**不用** [CoupleSyncCoordinator]：
 *    后者把「404 / 空」也归成 `couple_webdav_pull_failed`，与 Dart 不一致；
 * 4. **上传走协调器口径**（`ensureRemoteFolder` → `putBytes`），与 Dart 一致；
 * 5. 拉取/上传**从不抛**，只回错误码（Dart 该服务的显式契约）；
 * 6. 周偏移**先 clamp 再落盘**，落盘失败**不假装成功**（Dart 失败会 rethrow 给页面弹「保存失败」）；
 * 7. 换色三行的失败口径同 6。
 *
 * ## 不做的事
 *
 * 不自己起线程、不直接 `Toast`：动作是**同步阻塞**的（transport 是同步 HTTP），
 * 交给壳层放到 IO 线程跑；提示由壳层拿返回的 [SyncToast] 去弹。
 */
class CoupleTimetableSettingsController(
    private val configStore: CoupleConfigStorePort,
    private val partnerPort: CouplePartnerPort,
    private val transportFactory: (CoupleWebdavConfig, String) -> WebdavRemoteTransport? =
        { config, password -> createCoupleRemoteTransport(config, password) },
    /** 导出：把已组好的单档包正文交给宿主（壳里是 SAF「保存到…」），true = 已交给系统。 */
    private val exportSink: (content: String, fileName: String) -> Boolean = { _, _ -> false },
    private val nowIso: () -> String = { Instant.now().toString() },
    private val nowMicros: () -> Long = { System.currentTimeMillis() * 1000L },
    private val packageSalt: () -> Int = { Random.nextInt() },
    private val zone: ZoneId = ZoneId.systemDefault(),
) {

    private var binding: PartnerTimetableBindingModel? = partnerPort.loadBinding()
    private var config: CoupleWebdavConfig = configStore.loadConfig()
    private var hasPassword: Boolean = configStore.hasStoredPassword()
    private var busy: CoupleBusyState = CoupleBusyState()

    /** 每次状态变化 +1；宿主把它当 `remember` 的 key 触发重组。 */
    var revision: Int = 0
        private set

    private val listeners = CopyOnWriteArrayList<() -> Unit>()

    fun addListener(listener: () -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: () -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyChanged() {
        revision += 1
        for (listener in listeners) {
            listener()
        }
    }

    // ── 读 ──

    /** 重新从存储读一遍（省电/回前台时用；壳里目前只在构造时读）。 */
    fun refresh() {
        binding = partnerPort.loadBinding()
        config = configStore.loadConfig()
        hasPassword = configStore.hasStoredPassword()
        notifyChanged()
    }

    fun isBusy(): Boolean = busy != CoupleBusyState()

    fun sheetTexts(): CoupleWebdavSheetTexts = CoupleTimetableSettingsLogic.sheetTexts()

    fun viewState(): CoupleTimetableSettingsViewState {
        val myWeek = partnerPort.currentWeek()
        return CoupleTimetableSettingsLogic.buildViewState(
            binding = binding,
            webdavConfig = config,
            hasStoredPassword = hasPassword,
            busy = busy,
            partnerCourseCount = partnerPort.partnerCourseCount(),
            partnerProfileName = partnerPort.partnerProfileName(),
            myWeek = myWeek,
            partnerWeek = CoupleTimetableSettingsLogic.partnerWeekFor(
                myWeek,
                binding?.weekOffset ?: 0,
            ),
            zone = zone,
        )
    }

    // ── 连接 / 断开 ──

    /** 只测连接（Dart `testConnection`）：账号密码缺一即 false，"地址不可用"也是 false。 */
    fun testConnection(username: String, password: String): Boolean {
        val trimmed = username.trim()
        if (trimmed.isEmpty() || password.isEmpty()) return false
        val candidate = config.copyWith(username = trimmed)
        val transport = transportFactory(candidate, password) ?: return false
        return transport.testConnection() == null
    }

    /**
     * 连接并拉取（Dart `_connectCoupleWebdav`）：测试 → 存密码 → 存配置（账号 + 槽位）→ 强制拉一次。
     *
     * 测试失败回 `ok=false`（壳弹「连接失败…」）；存盘失败也按失败处理（不假装连上）。
     */
    fun connect(username: String, password: String, mySlot: Int): CoupleConnectOutcome {
        val trimmed = username.trim()
        if (!testConnection(trimmed, password)) {
            return CoupleConnectOutcome(ok = false, pullToast = null)
        }
        return try {
            configStore.storePassword(password)
            config = config.copyWith(username = trimmed, mySlot = if (mySlot == 2) 2 else 1)
            configStore.saveConfig(config)
            hasPassword = true
            notifyChanged()
            CoupleConnectOutcome(ok = true, pullToast = pull(force = true, showBusy = false))
        } catch (_: Exception) {
            CoupleConnectOutcome(ok = false, pullToast = null)
        }
    }

    /**
     * 断开（Dart `_disconnectCoupleWebdav`）：**先清配置**（账号 / 上次拉取 / 内容哈希），
     * 再尽力删密码——删不掉不影响「已断开」的语义（Dart 只吞 `PlatformException`，理由见那边注释）。
     *
     * @return null = 成功（Dart 成功不弹提示）；非 null = 失败提示。
     */
    fun disconnect(): SyncToast? {
        return try {
            config = config.copyWith(
                username = "",
                clearLastPulledAt = true,
                clearLastRemoteContentHash = true,
            )
            configStore.saveConfig(config)
            hasPassword = false
            runCatching { configStore.clearPassword() }
            notifyChanged()
            null
        } catch (_: Exception) {
            SyncToast(CoupleStrings.saveFailed.zh, isError = true)
        }
    }

    // ── 拉取 / 上传 ──

    /** 手动拉取（Dart 页面按钮：`force = false`，命中「无变化」短路）。 */
    fun pullNow(): SyncToast = pull(force = false, showBusy = true)

    private fun pull(force: Boolean, showBusy: Boolean): SyncToast {
        if (showBusy) setBusy(busy.copy(isPullingWebdav = true))
        try {
            val password = configStore.readPassword()
            if (config.username.trim().isEmpty() || password.isNullOrEmpty()) {
                return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_not_connected",
                )
            }
            val transport = transportFactory(config, password)
                ?: return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_invalid_base_url",
                )

            val fetched = transport.getBytes(config.partnerTimetableRemotePath)
            if (fetched.isFailed) {
                return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    fetched.errorMessage ?: "couple_webdav_pull_failed",
                )
            }
            if (fetched.isNotFound || fetched.isEmpty) {
                return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_partner_file_missing",
                )
            }
            val bytes = fetched.bytes
                ?: return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_partner_file_missing",
                )

            val content = try {
                // 严格 UTF-8：Dart `utf8.decode` 遇到非法字节会抛，这里同样要拒，
                // 不能靠 `toString(UTF_8)` 的「替换非法字节」蒙过去（那会把坏文件当课表导入）。
                Charsets.UTF_8.newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(bytes))
                    .toString()
            } catch (_: CharacterCodingException) {
                return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_partner_file_not_utf8",
                )
            }

            val decoded = MiniJson.tryParse(content)
            if (decoded !is Map<*, *>) {
                return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_partner_file_not_json",
                )
            }
            val json = LinkedHashMap<String, Any?>()
            for ((key, value) in decoded) {
                if (key is String) json[key] = value
            }
            if (CouplePartnerPackageCodec.isFullBackupJson(json)) {
                return CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    CouplePartnerPackageCodec.ERR_REQUIRES_SINGLE_PROFILE,
                )
            }

            val contentHash = WebdavSyncCoordinator.rawSha256Hex(bytes)
            if (shouldSkipCouplePullAsUnchanged(
                    lastRemoteContentHash = config.lastRemoteContentHash,
                    contentHash = contentHash,
                    force = force,
                    hasPartnerBinding = binding != null,
                )
            ) {
                return CoupleTimetableSettingsLogic.pullToast(CoupleWebdavPullStatus.UNCHANGED, null)
            }

            return try {
                val outcome = partnerPort.importPackage(content)
                config = config.copyWith(lastPulledAtIso = nowIso(), lastRemoteContentHash = contentHash)
                configStore.saveConfig(config)
                binding = partnerPort.loadBinding()
                partnerPort.notifyTimetableChanged()
                notifyChanged()
                CoupleTimetableSettingsLogic.pullToast(
                    if (outcome.updated) CoupleWebdavPullStatus.UPDATED else CoupleWebdavPullStatus.IMPORTED,
                    null,
                )
            } catch (e: CouplePackageException) {
                CoupleTimetableSettingsLogic.pullToast(CoupleWebdavPullStatus.FAILED, e.errorCode)
            } catch (_: Exception) {
                CoupleTimetableSettingsLogic.pullToast(
                    CoupleWebdavPullStatus.FAILED,
                    "couple_webdav_pull_failed",
                )
            }
        } finally {
            if (showBusy) setBusy(busy.copy(isPullingWebdav = false))
        }
    }

    /** 上传我的课表到坚果云（Dart `_uploadMyTimetableForPartner`）。 */
    fun uploadMine(): SyncToast {
        setBusy(busy.copy(isUploadingWebdav = true))
        try {
            val password = configStore.readPassword()
            if (config.username.trim().isEmpty() || password.isNullOrEmpty()) {
                return CoupleTimetableSettingsLogic.uploadToast("couple_webdav_not_connected")
            }
            val content = partnerPort.buildMyPackage()
            val transport = transportFactory(config, password)
                ?: return CoupleTimetableSettingsLogic.uploadToast("couple_webdav_invalid_base_url")
            val folder = transport.ensureRemoteFolder(config.normalizedRemoteFolder)
            if (folder.isFailed) {
                return CoupleTimetableSettingsLogic.uploadToast(folder.errorMessage ?: "sync_failed")
            }
            val put = transport.putBytes(
                config.mineTimetableRemotePath,
                content.toByteArray(Charsets.UTF_8),
            )
            if (put.isFailed) {
                return CoupleTimetableSettingsLogic.uploadToast(put.errorMessage ?: "sync_failed")
            }
            return CoupleTimetableSettingsLogic.uploadToast(null)
        } catch (_: Exception) {
            // Dart 的 catch-all 分支弹的是 `coupleWebdavPullFailed`（同一条文案，页面原样复用）。
            return CoupleTimetableSettingsLogic.uploadToast("couple_webdav_pull_failed")
        } finally {
            setBusy(busy.copy(isUploadingWebdav = false))
        }
    }

    // ── 导出 / 导入 ──

    /** 导出给对方（Dart `_exportForPartner`）：组单档包 → 交给宿主保存/分享。 */
    fun exportMine(): SyncToast? {
        setBusy(busy.copy(isExporting = true))
        return try {
            val content = partnerPort.buildMyPackage()
            val fileName = exportFileName()
            if (exportSink(content, fileName)) null else SyncToast(
                CoupleStrings.saveFailed.zh,
                isError = true,
            )
        } catch (_: Exception) {
            SyncToast(CoupleStrings.saveFailed.zh, isError = true)
        } finally {
            setBusy(busy.copy(isExporting = false))
        }
    }

    /** 导入对方课表（Dart `_importPartner` 的「拿到正文之后」那一段）。 */
    fun importFromContent(content: String): SyncToast {
        setBusy(busy.copy(isImporting = true))
        return try {
            if (content.isBlank()) {
                SyncToast(CoupleStrings.importFileReadFailed.zh, isError = true)
            } else {
                val outcome = partnerPort.importPackage(content)
                binding = partnerPort.loadBinding()
                partnerPort.notifyTimetableChanged()
                notifyChanged()
                CoupleTimetableSettingsLogic.importToast(outcome.updated, outcome.droppedTotal)
            }
        } catch (e: CouplePackageException) {
            SyncToast(CoupleStrings.localizeServiceMessage(e.errorCode), isError = true)
        } catch (_: Exception) {
            SyncToast(CoupleStrings.importFailedInvalidFile.zh, isError = true)
        } finally {
            setBusy(busy.copy(isImporting = false))
        }
    }

    // ── 解绑 ──

    /** 解除绑定（Dart `_confirmUnlink` 的「确认之后」那一段）。 */
    fun unlink(): SyncToast {
        setBusy(busy.copy(isUnlinking = true))
        return try {
            partnerPort.unlink()
            partnerPort.notifyTimetableChanged()
            binding = null
            notifyChanged()
            CoupleTimetableSettingsLogic.unlinkSuccessToast()
        } catch (_: Exception) {
            SyncToast(CoupleStrings.saveFailed.zh, isError = true)
        } finally {
            setBusy(busy.copy(isUnlinking = false))
        }
    }

    // ── 周偏移 / 换色 ──

    /**
     * ± 周偏移：clamp 后落盘；落盘失败**保持原值**并回一条「保存失败」。
     *
     * @return null = 成功（不弹）；非 null = 失败提示。
     */
    fun shiftWeekOffset(delta: Int): SyncToast? {
        val current = binding ?: return null
        val next = CoupleTimetableSettingsLogic.clampWeekOffset(current.weekOffset + delta)
        if (next == current.weekOffset) return null
        val updated = current.copy(weekOffset = next)
        return try {
            partnerPort.saveBinding(updated)
            binding = updated
            partnerPort.notifyTimetableChanged()
            notifyChanged()
            null
        } catch (_: Exception) {
            // 内存里没改过 ⇒ 界面自然保持原值；不写回、不假装成功。
            SyncToast(CoupleStrings.saveFailed.zh, isError = true)
        }
    }

    /**
     * 换叠加色：`rowIndex` 0/1/2 = 我的课 / TA的课 / 一起上课（与 viewState 的
     * `colorRows` 顺序一致）。落盘失败保持原值并回「保存失败」。
     */
    fun pickColor(rowIndex: Int, hex: String): SyncToast? {
        val current = binding ?: return null
        val updated = when (rowIndex) {
            0 -> current.copy(mineColorHex = hex)
            1 -> current.copy(partnerColorHex = hex)
            2 -> current.copy(togetherColorHex = hex)
            else -> return null
        }
        return try {
            partnerPort.saveBinding(updated)
            binding = updated
            partnerPort.notifyTimetableChanged()
            notifyChanged()
            null
        } catch (_: Exception) {
            SyncToast(CoupleStrings.saveFailed.zh, isError = true)
        }
    }

    // ── 内部 ──

    private fun setBusy(next: CoupleBusyState) {
        busy = next
        notifyChanged()
    }

    private fun exportFileName(): String {
        val stamp = java.time.LocalDateTime.ofInstant(Instant.ofEpochMilli(nowMicros() / 1000), zone)
        val text = String.format(
            "%04d%02d%02d-%02d%02d",
            stamp.year,
            stamp.monthValue,
            stamp.dayOfMonth,
            stamp.hour,
            stamp.minute,
        )
        return "mikcb-couple-$text.json"
    }
}

/** 组包时用的 packageId（Dart `TransferPackage.newPackageId` 同形）。 */
internal fun couplePackageId(micros: Long, salt: Int): String = newCouplePackageId(micros, salt)
