package com.mutx163.qingyu.pages.import.warehouse

/**
 * 适配仓两个索引文件的解析（移植 `WarehouseRepositoryService.fetchRootIndex` /
 * `fetchAdaptersIndex` 里「文件正文 → 模型」的那一段）。
 *
 * 失败一律抛 [WarehouseFeedException]，`code` 与 Dart 的 service message code **逐字一致**
 * （`warehouse_no_schools_index` / `warehouse_no_adapters`），这样以后要跟 Dart 日志对拍时
 * 不用再翻译一遍。
 */

/** 解析失败的分类码；`detail` 只用于拼日志，不上屏。 */
class WarehouseFeedException(
    val code: String,
    val detail: String = "",
) : RuntimeException(if (detail.isEmpty()) code else "$code:$detail")

/** 失败码常量（与 Dart `encodeServiceMessage` 的 code 对齐）。 */
object WarehouseFeedCodes {
    /** 解析后一所学校都没有（文件空 / 键错 / 全被过滤掉）。 */
    const val NO_SCHOOLS = "warehouse_no_schools_index"

    /** 解析后一个适配器都没有（同上，含学校下确实没配适配器）。 */
    const val NO_ADAPTERS = "warehouse_no_adapters"

    /** 全部候选都失败，且开着镜像（可能是镜像挂了，也可能是网断了）。 */
    const val FETCH_FAILED_MIRROR = "warehouse_fetch_failed_mirror"

    /** 全部候选都失败，且没走镜像。 */
    const val FETCH_FAILED_GITHUB = "warehouse_fetch_failed_github"

    /** 脚本声明的 SHA-256 与下载内容不一致（与 Dart `warehouse_script_checksum_failed` 同名）。 */
    const val SCRIPT_CHECKSUM_FAILED = "warehouse_script_checksum_failed"

    /**
     * 脚本正文为空。Dart 在 UI 层用 `courseImportScriptFailed` 提示，没有独立服务码；
     * 这里给一个码是为了让「注入空脚本」在数据层就被拦住（Kotlin 侧护栏）。
     */
    const val SCRIPT_EMPTY = "warehouse_script_empty"

    /** 适配器缺 `asset_js_path`、或学校缺 `resource_folder`，拼不出脚本地址。 */
    const val SCRIPT_PATH_MISSING = "warehouse_script_path_missing"
}

/**
 * `index/root_index.yaml` → 学校清单。
 *
 * 字段映射：`id` / `name` / `initial` / `resource_folder`（`category` / `code` / `province`
 * 在根索引里没有，落默认值）。**三项缺一即丢**：没有 `resource_folder` 就凑不出适配器文件
 * 地址（`resources/<folder>/adapters.yaml`），留着只会在下一页炸。
 */
fun parseWarehouseRootIndex(content: String): WarehouseRootIndex {
    val rows = WarehouseYamlList.parse(content, topLevelKey = "schools")
    val schools = rows.map { row ->
        WarehouseSchoolEntry(
            id = row["id"].orEmpty(),
            name = row["name"].orEmpty(),
            initial = row["initial"].orEmpty(),
            resourceFolder = row["resource_folder"].orEmpty(),
            category = row["category"].orEmpty().ifEmpty { "default" },
            code = row["code"].orEmpty(),
            province = row["province"].orEmpty(),
        )
    }.filter { it.id.isNotEmpty() && it.name.isNotEmpty() && it.resourceFolder.isNotEmpty() }
        // 仓库文件是手写的、CI 会合并：同一 id 出现两条 = 选校列表 items(key = id)
        // 抛 IllegalArgumentException 整页闪退。保首次、丢后续，别让一条重复行杀死整页。
        .distinctBy { it.id }

    if (schools.isEmpty()) {
        // 行数不为 0 却全被过滤 = 文件形状变了（键改名 / 缩进变了），日志里要能看出来。
        throw WarehouseFeedException(WarehouseFeedCodes.NO_SCHOOLS, detail = "rows=${rows.size}")
    }
    return WarehouseRootIndex(schools = schools)
}

/**
 * `resources/<resourceFolder>/adapters.yaml` → 该学校的适配器清单。
 *
 * 字段映射（Dart 键名 → 本仓模型字段）：
 * `adapter_id`→[WarehouseAdapterEntry.id]、`adapter_name`→`name`、`asset_js_path`→`script`、
 * `import_url`→`importUrl`、`category` / `maintainer` / `description` / `sha256` 同名。
 *
 * **`adapter_id` 与 `asset_js_path` 缺一即丢**：没有脚本路径的适配器点「导入」只能失败，
 * 冒充成一条能用的条目比不显示更糟。
 */
fun parseWarehouseAdaptersIndex(
    content: String,
    school: WarehouseSchoolEntry,
): WarehouseAdaptersIndex {
    val rows = WarehouseYamlList.parse(content, topLevelKey = "adapters")
    val adapters = rows.map { row ->
        WarehouseAdapterEntry(
            id = row["adapter_id"].orEmpty(),
            name = row["adapter_name"].orEmpty(),
            script = row["asset_js_path"].orEmpty(),
            description = row["description"].orEmpty(),
            category = row["category"].orEmpty().ifEmpty { "教务" },
            maintainer = row["maintainer"].orEmpty(),
            importUrl = row["import_url"].orEmpty(),
            sha256 = row["sha256"].orEmpty(),
        )
    }.filter { it.id.isNotEmpty() && it.script.isNotEmpty() }
        // 同 adapter_id 出现两条 = 适配器列表 items(key = id) 首屏组合即崩（与根索引同一类洞）。
        .distinctBy { it.id }

    if (adapters.isEmpty()) {
        // 带上学校名：多所学校共用同一个适配仓时，日志里必须能分清是哪一所为空。
        throw WarehouseFeedException(
            WarehouseFeedCodes.NO_ADAPTERS,
            detail = "${school.id}/rows=${rows.size}",
        )
    }
    return WarehouseAdaptersIndex(
        schoolId = school.id,
        schoolName = school.name,
        adapters = adapters,
    )
}
