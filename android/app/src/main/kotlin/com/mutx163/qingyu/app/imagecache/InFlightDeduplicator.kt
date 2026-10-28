package com.mutx163.qingyu.app.imagecache

import java.util.concurrent.ConcurrentHashMap

/**
 * 并发去重器（纯逻辑，JVM 可测，禁 android 导入）。
 *
 * 场景：列表里同一个 URL 在一屏内被请求多次（Bing 壁纸画廊里同一张图既做缩略图又做背景）。
 * 若每个请求都独立下载解码，就是 N 次网络 + N 次解码。本类把「同键并发请求」收敛成一次加载：
 * 第一个调用者当 **LEADER** 真正去加载，其余同键调用者当 **FOLLOWER** 加入等待，加载完成后
 * 由调用方统一回发结果。
 *
 * 线程安全：内部是 [ConcurrentHashMap.newKeySet]，供 `AndroidImageLoader` 的线程池并发使用。
 * 键一般是 [ImageCacheKey.of] 的返回值。
 */
class InFlightDeduplicator {

    enum class Role {
        /** 首个调用者：负责真正发起加载。 */
        LEADER,

        /** 同键并发调用者：加入已有加载，不再重复发起。 */
        FOLLOWER,
    }

    private val inFlight: MutableSet<String> = ConcurrentHashMap.newKeySet()

    /**
     * 开始一次加载。
     * @return 该键此前不在加载中 → 本次调用标记为 in-flight 并返回 [Role.LEADER]；
     *         该键已在加载中 → 返回 [Role.FOLLOWER]（不改变 in-flight 状态）。
     */
    fun begin(key: String): Role =
        if (inFlight.add(key)) Role.LEADER else Role.FOLLOWER

    /** 加载成功完成：清除 in-flight 标记。 */
    fun complete(key: String) {
        inFlight.remove(key)
    }

    /** 加载失败：清除 in-flight 标记（允许后续请求重新发起）。 */
    fun fail(key: String) {
        inFlight.remove(key)
    }

    fun isInFlight(key: String): Boolean = inFlight.contains(key)

    /** 当前处于加载中的**不同键**数量。 */
    fun inFlightCount(): Int = inFlight.size
}
