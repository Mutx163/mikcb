package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.MiniJson

/**
 * Dart `lib/models/bing_wallpaper.dart` 的移植（纯计算部分）。
 *
 * 覆盖：档位阶梯（含 fallback / downloadTargetSize 的**参数化**版本）、
 * URL 拼装（fullUrl / resizeUrl / thumbnailUrl / imageId / absoluteUrlBase）、
 * 预期尺寸、落盘文件名（含 safeWallpaperNameSegment 净化）、JSON 契约
 * （两套键名 urlbase|urlBase / startdate|dateKey 都认）。
 *
 * 与 Dart 的差异：`downloadTargetSize` 在 Dart 里读 PlatformDispatcher 视口
 * （引擎边界，纯逻辑层拿不到）；这里改成显式传入屏幕尺寸 [WallpaperTargetSize]，
 * 「档位是下限、屏幕是下限之上」的语义逐字保留。
 */

/** resize 接口的取图源后缀：`_UHD.jpg`（塞进 id= 的必须是纯图片 id + 这个后缀）。 */
private const val RESIZE_SOURCE_SUFFIX = "_UHD.jpg"

/**
 * Bing 每日壁纸的下载尺寸阶梯（三档，全是竖屏）。
 *
 * * [STANDARD] 有预生成后缀（体积最小）；[TALL] / [HIGH] 走 resize 现裁。
 * * 档位只是**保底阶梯**：缺档时按枚举顺序退一档（[fallbackResolution]）。
 */
enum class BingWallpaperResolution(
    val width: Int,
    val height: Int,
    val kilobytes: Int,
    val sizeSuffix: String?,
) {
    /** 1080×1920（9:16）。Bing 预生成。只作保底。 */
    STANDARD(1080, 1920, 322, "_1080x1920.jpg"),

    /** 1080×2400（9:20）。走 resize。 */
    TALL(1080, 2400, 492, null),

    /** 1440×3200。默认且唯一对外生效的一档（本 App 恒按它抬到不低于屏幕）。 */
    HIGH(1440, 3200, 764, null),
    ;

    val pixelWidth: Int get() = width
    val pixelHeight: Int get() = height
    val approximateKilobytes: Int get() = kilobytes

    /** 该档缺失时能退到哪一档（null = 无处可退）。 */
    val fallbackResolution: BingWallpaperResolution?
        get() = when (this) {
            STANDARD -> null
            TALL -> STANDARD
            HIGH -> TALL
        }

    /**
     * 实际该向 Bing 要的像素尺寸：先按屏幕真实分辨率取尺寸，再按当前档位抬到
     * 不低于档位。本 App 恒用 [HIGH]，实际语义就是「按屏幕分辨率取，最低不低于
     * 1440×3200」。
     */
    fun downloadTargetSize(screen: WallpaperTargetSize): WallpaperTargetSize =
        screen.atLeast(width, height)

    /** [kilobytes] 的人类可读写法（日志与诊断用）：不到 1 MB 保留 KB。 */
    val approximateSizeLabel: String
        get() = if (kilobytes < 1024) "$kilobytes KB" else String.format("%.1f MB", kilobytes / 1024.0)

    /** 持久化用的键（枚举名，顺序变了也不会读错旧值）。 */
    val storageKey: String
        get() = when (this) {
            STANDARD -> "standard"
            TALL -> "tall"
            HIGH -> "high"
        }

    companion object {
        /** 反解 [storageKey]；未知键回退 [STANDARD]（坏存档不炸读取方）。 */
        fun fromStorageKey(raw: String?): BingWallpaperResolution =
            entries.firstOrNull { it.storageKey == raw } ?: STANDARD
    }
}

/** 壁纸下载的目标像素（宽×高）。 */
data class WallpaperTargetSize(val width: Int, val height: Int) {

    val aspectRatio: Double get() = width.toDouble() / height

    /** 按 [aspectRatio] 由高度反推宽度，并对齐偶数（JPEG 换色度采样要偶数）。 */
    fun withHeight(newHeight: Int): WallpaperTargetSize {
        val raw = Math.round(newHeight * aspectRatio).toInt()
        return WallpaperTargetSize(even(raw), even(newHeight))
    }

    /** 按 [aspectRatio] 由宽度反推高度，并对齐偶数。 */
    fun withWidth(newWidth: Int): WallpaperTargetSize =
        withHeight(Math.round(newWidth / aspectRatio).toInt())

    /**
     * 不小于给定下限的尺寸：档位是「保底质量」，但永远不小于屏幕。
     * 两维都不足时以高度为准（cover 的瓶颈永远是高度）。
     */
    fun atLeast(minWidth: Int, minHeight: Int): WallpaperTargetSize {
        if (width >= minWidth && height >= minHeight) return this
        return if (height < minHeight) withHeight(minHeight) else withWidth(minWidth)
    }

    override fun toString(): String = "${width}x$height"

    companion object {
        private fun even(value: Int): Int = if (value % 2 == 0) value else value + 1
    }
}

/** Bing 每日壁纸库里的一天（对应 HPImageArchive.aspx?format=js 的 images[] 某项）。 */
data class BingWallpaperItem(
    /** 当天的 `startdate`，形如 `20261005`。它同时是身份：同一天永远是同一张图。 */
    val dateKey: String,
    /** Bing 的图片基址，形如 `/th?id=OHR.AdelieTeacher_EN-US5343194378`。 */
    val urlBase: String,
    val title: String,
    val copyright: String,
) {
    /**
     * Bing 的图片 id（去掉 `/th?id=` 前缀）。
     *
     * ⚠️ 这一层不能省：把 urlBase 直接塞进另一个查询串会得到 `…&id=/th?id=OHR.…`，
     * 第二个 `?id=` 之后全是多余的，参数值被截成 `/th?id` 实测 404（图库整屏叉）。
     */
    val imageId: String
        get() {
            val marker = urlBase.indexOf("?id=")
            return if (marker >= 0) urlBase.substring(marker + 4) else urlBase
        }

    /** 绝对化的基址：从 [imageId] 重拼而不是拼 [urlBase]（后者会带进 /th?id=）。 */
    val absoluteUrlBase: String
        get() = "https://www.bing.com/th?id=$imageId"

    /**
     * 指定档位的原图绝对地址。
     *
     * 预生成档只在「尺寸刚好够」时走后缀：档位尺寸小于屏幕时走后缀等于主动要一张
     * 更小的图，App 还得再放大一次。否则走 resize 接口（必须带 c=4，否则补白边不裁）。
     */
    fun fullUrl(resolution: BingWallpaperResolution, target: WallpaperTargetSize? = null): String {
        val suffix = resolution.sizeSuffix
        if (suffix != null && (target == null || target.height <= resolution.height)) {
            return "$absoluteUrlBase$suffix"
        }
        val size = target ?: WallpaperTargetSize(resolution.width, resolution.height)
        return resizeUrl(width = size.width, height = size.height)
    }

    /**
     * 让 Bing 按宽×高填满裁切出一张。`c=4` 是「填满」开关：不带它时 Bing 把整张图
     * 缩进去、上下留白边。`highQuality` 追加 `qlt=95`（原图用 true，缩略图 false）。
     */
    fun resizeUrl(width: Int, height: Int, highQuality: Boolean = true): String {
        val id = "$imageId$RESIZE_SOURCE_SUFFIX"
        val quality = if (highQuality) "&qlt=95" else ""
        return "https://www.bing.com/th" +
            "?w=$width&h=$height&rs=1&c=4$quality&id=$id"
    }

    /** 这次下载预期拿到的像素；落盘后与实际尺寸比对识别静默降尺寸。口径与 [fullUrl] 严格一致。 */
    fun expectedSizeFor(resolution: BingWallpaperResolution, target: WallpaperTargetSize? = null): WallpaperTargetSize {
        val suffix = resolution.sizeSuffix
        if (suffix != null && (target == null || target.height <= resolution.height)) {
            return WallpaperTargetSize(resolution.width, resolution.height)
        }
        return target ?: WallpaperTargetSize(resolution.width, resolution.height)
    }

    /** 浏览图库用的小图地址（默认 480×854 竖屏、不带 qlt）。 */
    fun thumbnailUrl(width: Int = 480, height: Int = 854): String =
        resizeUrl(width = width, height = height, highQuality = false)

    /**
     * 落盘文件名（不含目录）：`wallpaper_bing_20261005_standard.jpg`。
     *
     * * 前缀必须是 `wallpaper`：删除守卫按它判定「这张图归我管」，改名会变成
     *   永不回收的孤儿文件。
     * * 用 dateKey + 档位而不是时间戳：同一天同一档位天然同文件名，重复下载直接覆盖。
     * * 实际像素与档位默认不同时写进名字（换设备/换档位落到不同文件）。
     * * dateKey 来自服务端，必须先净化（`safeWallpaperNameSegment`）。
     */
    fun fileName(resolution: BingWallpaperResolution, target: WallpaperTargetSize? = null): String {
        val size = target ?: WallpaperTargetSize(resolution.width, resolution.height)
        val base = WallpaperTargetSize(resolution.width, resolution.height)
        val suffix = if (size == base) "" else "_${size.width}x${size.height}"
        return "wallpaper_bing_" +
            safeWallpaperNameSegment(dateKey, "day") +
            "_${resolution.storageKey}$suffix.jpg"
    }

    /** 下载请求 URL（download 链路的取图地址；与 [fullUrl] 同口径的语义别名）。 */
    fun downloadUrl(resolution: BingWallpaperResolution, target: WallpaperTargetSize? = null): String =
        fullUrl(resolution, target)

    /** 下载后校验用的期望尺寸（download 链路视角的 [expectedSizeFor]）。 */
    fun expectedDownloadSize(resolution: BingWallpaperResolution, target: WallpaperTargetSize? = null): WallpaperTargetSize =
        expectedSizeFor(resolution, target)

    /** JSON 键序与 Dart 一致。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "dateKey" to dateKey,
        "urlBase" to urlBase,
        "title" to title,
        "copyright" to copyright,
    )

    companion object {
        /**
         * 非法输入返回 null 而不是抛错：接口 JSON 可能被 Bing 改字段或手改存档。
         * 两个键都要读：接口叫 `urlbase`/`startdate`，本模型缓存写 `urlBase`/`dateKey`。
         */
        fun fromJson(raw: Any?): BingWallpaperItem? {
            if (raw !is Map<*, *>) return null
            val urlBase = raw["urlBase"] ?: raw["urlbase"]
            val dateKey = raw["dateKey"] ?: raw["startdate"]
            if (urlBase !is String || dateKey !is String) return null
            val trimmedBase = urlBase.trim()
            val trimmedDate = dateKey.trim()
            if (trimmedBase.isEmpty() || trimmedDate.isEmpty()) return null
            return BingWallpaperItem(
                dateKey = trimmedDate,
                urlBase = trimmedBase,
                title = stringOrEmpty(raw["title"]),
                copyright = stringOrEmpty(raw["copyright"]),
            )
        }

        /** 只放行 String；其余类型一律当空串（副标题可以不显示，条目本身仍有效）。 */
        private fun stringOrEmpty(value: Any?): String = value as? String ?: ""

        fun listFromJson(raw: Any?): List<BingWallpaperItem> {
            if (raw !is List<*>) return emptyList()
            return raw.mapNotNull { fromJson(it) }
        }

        /** 测试辅助：按 dateKey 构造最小条目。 */
        fun itemOf(dateKey: String): BingWallpaperItem =
            BingWallpaperItem(
                dateKey = dateKey,
                urlBase = "/th?id=OHR.Test_ZH-CN1",
                title = "",
                copyright = "",
            )
    }
}

/**
 * 把一段外部标识符收敛成能安全进文件名的片段
 * （Dart `lib/utils/wallpaper_file_name.dart` 的移植）。
 *
 * 只保留 `[A-Za-z0-9._-]`，其余（含 `/` `\` 空格、任何控制字符）一律替换成 `_`；
 * 再截断到 48，避免超长名在部分文件系统上失败。清洗后为空（或 `.` / `..`
 * 这两个路径特例）退回 [fallback] 占位——宁可两张图撞名，也不让整条记录消失。
 */
fun safeWallpaperNameSegment(raw: String, fallback: String = "item"): String {
    val buffer = StringBuilder()
    for (ch in raw) {
        val isSafe = ch in '0'..'9' || ch in 'A'..'Z' || ch in 'a'..'z' ||
            ch == '.' || ch == '_' || ch == '-'
        buffer.append(if (isSafe) ch else '_')
        if (buffer.length >= 48) break
    }
    val cleaned = buffer.toString()
    return if (cleaned.isEmpty() || cleaned == "." || cleaned == "..") fallback else cleaned
}
