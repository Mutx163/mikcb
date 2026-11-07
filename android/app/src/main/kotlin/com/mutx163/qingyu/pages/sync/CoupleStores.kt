package com.mutx163.qingyu.pages.sync

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.sync.CoupleWebdavConfig

/**
 * 情侣课表设置页需要本机提供的两件事：**坚果云配置/密码** 与 **对方课表数据**。
 *
 * 为什么是两个窄接口而不是直接给 `TimetableRepository` / `SharedPreferences`：
 * 控制器要能在 JVM 单测里跑（`scripts/test-kotlin-module.ps1` 的 classpath 里没有
 * `android.*`，`platform/` 整目录也不参与 L0），所以生产实现留在 `platform/`，
 * 这里只放**接口 + 纯逻辑（绑定 JSON 编解码、单档包解析）**。
 *
 * 形态与分工照抄已交付的 `CloudSyncController` / `WebdavConfigStore` 一对。
 */
interface CoupleConfigStorePort {
    fun loadConfig(): CoupleWebdavConfig
    fun saveConfig(config: CoupleWebdavConfig)
    fun hasStoredPassword(): Boolean

    /** 已连接后拉取/上传要读回密码。解不开（换机/密钥失效）返回 null，按「没存过」处理。 */
    fun readPassword(): String?
    fun storePassword(password: String)
    fun clearPassword()
}

/**
 * 对方课表在键值存储里的落点（**唯一常量来源**）。
 *
 * `pages/sync` 与 `platform/CouplePartnerPortImpl` 都用它，别再各写一份字面量。
 * 注意 `pages/timetable` 的 L0 classpath 不含本模块，那边另有一份同值常量
 * `TimetableProfilesLogic.PARTNER_BINDING_KEY`，由
 * `CouplePartnerBindingKeyGuardTest` 逐字比对两边是否一致。
 */
object CouplePartnerStorage {
    /** Dart `storage_service.dart` 的 `_partnerTimetableBindingKey`。 */
    const val BINDING_KEY: String = "partner_timetable_binding"
}

/**
 * 解绑的分步结局（S2）。
 *
 * 发布版 `partner_timetable_service.dart:132-139` 的顺序是**先删对方档案、成功后清绑定**；
 * 反过来（先清绑定、后删档案）一旦删档失败就会留下「无绑定 + 有档案」的僵尸档——
 * 那份档案在课表管理里既删不掉也切不走。所以这里按步返回，让上层能如实说清是哪一步没成。
 */
enum class CoupleUnlinkStage {
    /** 两步都成了。 */
    DONE,

    /** 对方课表档案没删掉：**绑定仍然有效**，界面应保持「已绑定」，用户可重试。 */
    PROFILE_DELETE_FAILED,

    /** 档案已删、但绑定键没清掉：重试一次解绑即可收尾（此时只剩「清绑定」这一步）。 */
    BINDING_CLEAR_FAILED,
}

/**
 * 对方课表数据的读写口。
 *
 * 「绑定」（`partner_timetable_binding`）与「对方课表档案」（`timetable_profiles` 里
 * id=`partner-imported` 的那份）是两处存储，但**必须一起动**：
 * 只写绑定不写档案 → 页面显示「已绑定 TA 的课表」而 TA 的课节数为 0；
 * 只写档案不写绑定 → 课表页不知道要叠加谁。所以这里把它们收成一个端口。
 */
interface CouplePartnerPort {
    /** null = 未绑定（或落盘值损坏；损坏值的留档由实现负责）。 */
    fun loadBinding(): PartnerTimetableBindingModel?
    fun saveBinding(binding: PartnerTimetableBindingModel)

    /**
     * 解除绑定：**先**删对方课表档案、**成功后**再清绑定键（对齐发布版顺序）。
     *
     * @return 分步结局；失败时**不抛**，让上层按 [CoupleUnlinkStage] 给不同提示。
     */
    fun unlink(): CoupleUnlinkStage
    fun partnerCourseCount(): Int
    fun partnerProfileName(): String?

    /**
     * 导入对方课表单档包（`json`/`mikcb`）。
     *
     * @throws CouplePackageException 解析失败，`errorCode` 是 Dart 的错误码
     *   （`partner_import_requires_single_profile` / `unrecognized_mikcb_data_file` / `missing_settings_data`）。
     */
    fun importPackage(content: String): CoupleImportOutcome

    /** 组「我的课表」单档包正文（导出给对方 + 上传到坚果云**共用同一份**，与 Dart 一致）。 */
    fun buildMyPackage(): String

    /** 当前浏览周（周偏移预览句里的「你的第 N 周」）。 */
    fun currentWeek(): Int

    /** 数据已变（导入/解绑/周偏移/换色）→ 让课表页重读叠加数据。 */
    fun notifyTimetableChanged()
}

/** 导入结局：新建还是更新 + 被跳过的坏条目数（Dart `PartnerImportResult`）。 */
data class CoupleImportOutcome(
    val updated: Boolean,
    val droppedTotal: Int,
)

/** 单档包解析失败（携带 Dart 错误码，交给 `CoupleStrings.localizeServiceMessage` 出文案）。 */
class CouplePackageException(val errorCode: String) : RuntimeException(errorCode)

/**
 * 绑定 JSON 编解码（Dart `PartnerTimetableBinding.toJson/fromJson`）。
 *
 * 键名、可选键（`lastImportedAt` / `sourceFileHash` 为 null 时不写）、坏值回落口径
 * 全部照 Dart：外部数据（云同步/备份恢复）里任何一项类型不对都不能把整份绑定读没。
 */
object CoupleBindingCodec {

    fun encode(binding: PartnerTimetableBindingModel): String {
        val json = LinkedHashMap<String, Any?>()
        json["partnerProfileId"] = binding.partnerProfileId
        json["partnerName"] = binding.partnerName
        binding.linkedAtIso?.let { json["linkedAt"] = it }
        binding.lastImportedAtIso?.let { json["lastImportedAt"] = it }
        binding.sourceFileHash?.let { json["sourceFileHash"] = it }
        json["weekOffset"] = binding.weekOffset
        json["mineColorHex"] = binding.mineColorHex
        json["partnerColorHex"] = binding.partnerColorHex
        json["togetherColorHex"] = binding.togetherColorHex
        return MiniJson.encode(json)
    }

    /** @return null = 没有值 / 不是 JSON 对象（调用方按「未绑定」处理，留档由存储实现做）。 */
    fun parse(raw: String?): PartnerTimetableBindingModel? {
        val text = raw?.trim().orEmpty()
        if (text.isEmpty()) return null
        val decoded = MiniJson.tryParse(text)
        if (decoded !is Map<*, *>) return null
        val json = LinkedHashMap<String, Any?>()
        for ((key, value) in decoded) {
            if (key is String) json[key] = value
        }
        return fromJson(json)
    }

    private fun fromJson(json: Map<String, Any?>): PartnerTimetableBindingModel {
        fun readStr(key: String, fallback: String): String {
            val raw = json[key]
            return if (raw is String) raw else raw?.toString() ?: fallback
        }

        fun readStrOrNull(key: String): String? {
            val raw = json[key] ?: return null
            return if (raw is String) raw else raw.toString()
        }

        val rawOffset = (json["weekOffset"] as? Number)?.toInt() ?: 0
        return PartnerTimetableBindingModel(
            partnerName = readStr("partnerName", CoupleTimetableSettingsLogic.PARTNER_NAME_FALLBACK),
            lastImportedAtIso = readStrOrNull("lastImportedAt"),
            weekOffset = rawOffset.coerceIn(
                CoupleTimetableSettingsLogic.MIN_WEEK_OFFSET,
                CoupleTimetableSettingsLogic.MAX_WEEK_OFFSET,
            ),
            mineColorHex = readStr(
                "mineColorHex",
                CoupleTimetableSettingsLogic.MINE_COLOR_DEFAULT,
            ),
            partnerColorHex = readStr(
                "partnerColorHex",
                CoupleTimetableSettingsLogic.PARTNER_COLOR_DEFAULT,
            ),
            togetherColorHex = readStr(
                "togetherColorHex",
                CoupleTimetableSettingsLogic.TOGETHER_COLOR_DEFAULT,
            ),
            partnerProfileId = readStr(
                "partnerProfileId",
                CoupleTimetableSettingsLogic.PARTNER_PROFILE_ID,
            ),
            linkedAtIso = readStrOrNull("linkedAt"),
            sourceFileHash = readStrOrNull("sourceFileHash"),
        )
    }
}
