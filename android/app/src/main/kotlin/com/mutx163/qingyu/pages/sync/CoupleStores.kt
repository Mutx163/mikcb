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

    /** 解除绑定：删绑定键 **并且** 删对方课表档案。 */
    fun unlink()
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
