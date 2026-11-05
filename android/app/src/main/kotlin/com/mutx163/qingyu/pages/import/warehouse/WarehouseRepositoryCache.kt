package com.mutx163.qingyu.pages.import.warehouse

import com.mutx163.qingyu.app.KeyValueStore

/**
 * 适配仓两个索引的**磁盘缓存**（本轮新增，发布版没有）。
 *
 * ## 为什么加
 *
 * 拉一次索引要经过「主地址 → GitHub raw → 至多 4 个镜像」的候选链，弱网/镜像半死时
 * 最坏能转十几秒；而 `root_index.yaml`（200+ 所学校）与 `adapters.yaml` 一天内几乎不变。
 * 缓存后进入页面可以**先用上次的名单秒开**，再在后台静默刷新——
 * 这就是用户说的「有时能出有时出不来」的那一半：出不来时至少还有上次的名单可用。
 *
 * 发布版 Dart 侧**没有**这份缓存（`warehouse_repository_service.dart` 每次真拉），
 * 所以本类不是「对齐发布版」，是 Compose 侧的补强；口径上只借用了它
 * 「最近学校列表也落 SharedPreferences」的同一种存储习惯。
 *
 * ## 存的是什么
 *
 * **索引文件的原文 + 拉取时刻**，不是解析后的模型：
 * 1. 解析器（[parseWarehouseRootIndex] / [parseWarehouseAdaptersIndex]）是唯一的形状真源，
 *    缓存再存一份模型等于把「字段怎么读」变成两处；
 * 2. 原文能被下一版解析器重新解释——字段名改了也不会作废整份缓存；
 * 3. 体积上是几十 KB 的文本，`SharedPreferences` 放得下（与 `timetable_profiles` 同量级）。
 *
 * ## 过期的判据
 *
 * [isFresh] 只看「拉取时刻到现在是否超过 [ttlMillis]」（默认 6 小时）。
 * **过期不等于不可用**：宿主拿到过期缓存照样先渲染，只是会立刻发起一次后台刷新；
 * 只有「盘上根本没有 / 内容解析不出来」才算没缓存，那时才回到转圈态。
 *
 * @param store 与教务导入其余偏好同一份 `SharedPreferences`（[KeyValueStore] 抽象）。
 * @param ttlMillis 判「新鲜」的时长；只为上屏/日志口径服务，不影响能不能用。
 */
class WarehouseRepositoryCache(
    private val store: KeyValueStore,
    private val ttlMillis: Long = DEFAULT_TTL_MILLIS,
) {

    /** 一次缓存读取的结果。[value] 是解析后的模型，[content] 是原文（回写时不用再解析）。 */
    data class Cached<T>(
        val value: T,
        val content: String,
        val fetchedAtMillis: Long,
    )

    /** 学校清单缓存；没有 / 解析不出来都回 `null`（调用方按「没有缓存」处理）。 */
    fun readRootIndex(): Cached<WarehouseRootIndex>? =
        read(ROOT_INDEX_KEY) { content -> parseWarehouseRootIndex(content) }

    /** 写学校清单缓存。[content] 传成功候选的原文（[WarehouseLoad.Ok.raw]）。 */
    fun writeRootIndex(content: String, nowMillis: Long = System.currentTimeMillis()) =
        write(ROOT_INDEX_KEY, content, nowMillis)

    /** 某所学校的适配器清单缓存（键按 `resource_folder` 分，不同学校互不覆盖）。 */
    fun readAdaptersIndex(school: WarehouseSchoolEntry): Cached<WarehouseAdaptersIndex>? =
        read(adaptersKey(school)) { content -> parseWarehouseAdaptersIndex(content, school) }

    fun writeAdaptersIndex(
        school: WarehouseSchoolEntry,
        content: String,
        nowMillis: Long = System.currentTimeMillis(),
    ) = write(adaptersKey(school), content, nowMillis)

    /** 缓存是否还在保鲜期内。只看时刻差，不看内容对不对。 */
    fun isFresh(cached: Cached<*>, nowMillis: Long = System.currentTimeMillis()): Boolean {
        val age = nowMillis - cached.fetchedAtMillis
        return age in 0..ttlMillis
    }

    // ------------------------------------------------------------------ 内部

    private fun <T> read(
        key: String,
        parse: (String) -> T,
    ): Cached<T>? {
        val content = store.getString(key) ?: return null
        if (content.isBlank()) return null
        // 拿不出拉取时刻就按 0 处理：内容还在，只是「什么时候拉的」不可知——
        // 这种缓存宁可用（isFresh 会判成过期 → 立即后台刷新），也别整份丢掉。
        val fetchedAt = store.getLong(fetchedAtKey(key), 0L)
        val value = runCatching { parse(content) }.getOrNull() ?: return null
        return Cached(value = value, content = content, fetchedAtMillis = fetchedAt)
    }

    private fun write(key: String, content: String, nowMillis: Long) {
        if (content.isBlank()) return
        store.putString(key, content)
        store.putLong(fetchedAtKey(key), nowMillis)
    }

    /** 适配器清单的键：`resource_folder` 里可能有 `/`，落键前换成 `_`（桶名只用于区分学校）。 */
    private fun adaptersKey(school: WarehouseSchoolEntry): String {
        val folder = school.resourceFolder.ifBlank { school.id }
        return ADAPTERS_KEY_PREFIX + folder.replace('/', '_').replace('\\', '_')
    }

    private fun fetchedAtKey(key: String): String = key + FETCHED_AT_SUFFIX

    companion object {
        const val ROOT_INDEX_KEY = "warehouse_cache_root_index"
        const val ADAPTERS_KEY_PREFIX = "warehouse_cache_adapters_"
        const val FETCHED_AT_SUFFIX = "_fetched_at"

        /** 6 小时：一天里进几次导入页，最多真拉 4 次。 */
        const val DEFAULT_TTL_MILLIS: Long = 6L * 60L * 60L * 1000L
    }
}
