package com.mutx163.qingyu.pages.settings

import com.mutx163.qingyu.core.MiniJson
import com.mutx163.qingyu.weather.BingWallpaperItem
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

/**
 * Bing 每日壁纸图库的**清单数据源**（`lib/services/bing_wallpaper_service.dart` 的
 * `loadItems` 那一半：拉接口 + 解析 `images[]`）。
 *
 * ## 为什么单独一层
 *
 * 图库页的模型层（[SettingsBingWallpaperGalleryPage]）早在 `6116529c` 之前就写完了，
 * 却一直没有数据进来——壳里传的是 `BingGalleryState()` 默认构造（`ShellPageIndex.kt`
 * 的 `b.bingGallery`），于是屏幕上永远是「加载中」。这一层补的正是**唯一缺的那一环**：
 * 把接口字节变成 `BingGalleryState.items`。
 *
 * ## 口径（逐条对齐 Dart）
 *
 * 1. **一次拉 8 天、`mkt=zh-CN`**（Dart `:159` / `:201-202`）：`n` 超过 8 Bing 不保证给满；
 *    `mkt` 决定版权说明的语言（不带它拿到的是英文地名）；
 * 2. **空清单 = 失败**（Dart `_load` 的 `_failed = items.isEmpty`）：断网、Bing 改格式、
 *    接口回 `{}`，在用户眼里都是「一屏空白」，所以统一退回失败页 + 重试；
 * 3. **解析失败不抛**：这一层对上层只回答「拿到了几张」，不制造异常。图库是装饰性
 *    功能，抛异常只会把整个设置页带崩；
 * 4. **零新依赖**：只用 JDK `HttpURLConnection` + 仓内 `MiniJson`，与本包其余文件一样
 *    保持**纯 JVM**（`pages/settings` 不许出现 `android.*`，否则 `scripts/test-kotlin-module.ps1`
 *    会把整个目录跳过，全队这个模块的 L0 都会静默失效）。
 */

/** 图库一次展示几天（`kBingWallpaperDays`）。 */
const val BING_GALLERY_DAYS = 8

/**
 * 清单接口（Dart `:201-202` 逐字）。
 *
 * `format=js` 拿 JSON；`idx=0` 从最新那张往回数；`n=8` 一次 8 天。
 */
const val BING_GALLERY_LIST_URL =
    "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=$BING_GALLERY_DAYS&mkt=zh-CN"

/**
 * 「GET 一个 URL，返回 body 文本或 null」的接缝。
 *
 * 单独抽出来是为了让清单解析与失败归并能在 JVM 单测里跑（同 `weather/WeatherHttp` 的写法）。
 */
interface BingGalleryHttp {
    fun get(url: String): String?
}

/**
 * 真实 HTTP 实现：JDK [HttpURLConnection]。
 *
 * 显式按 UTF-8 读 body（中文版权说明落 latin1 会变乱码）；任何异常返回 null —— 上层把
 * null 与「解析不出条目」一视同仁当成失败，不需要区分是超时还是被墙。
 */
class JdkBingGalleryHttp(
    private val connectTimeoutMs: Int = 10_000,
    private val readTimeoutMs: Int = 15_000,
) : BingGalleryHttp {

    override fun get(url: String): String? = try {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = connectTimeoutMs
            readTimeout = readTimeoutMs
            // Bing 对没有 UA 的请求偶尔回 403；带一个能识别来源的串就够。
            setRequestProperty("User-Agent", "qingyu-kb-compose/1.0")
        }
        try {
            if (connection.responseCode !in 200..299) {
                null
            } else {
                connection.inputStream.use { String(it.readBytes(), StandardCharsets.UTF_8) }
            }
        } finally {
            connection.disconnect()
        }
    } catch (e: IOException) {
        null
    } catch (e: RuntimeException) {
        null
    }
}

/**
 * 清单数据源：`fetch()` 一次 = 一次网络请求。
 *
 * 不做缓存：图库页在**进页/下拉刷新**各调一次，而「显示的是上次那份」这条提示由宿主
 * 拿本次结果与上一次结果比出来（见 [BingGalleryApplyPlanner.stateAfterFetch]）。
 */
class BingGalleryDataSource(private val http: BingGalleryHttp = JdkBingGalleryHttp()) {

    /** 拉最近 [BING_GALLERY_DAYS] 天；失败与空清单都返回空表。 */
    fun fetch(): List<BingWallpaperItem> = parse(http.get(BING_GALLERY_LIST_URL))

    companion object {

        /**
         * 解析 `HPImageArchive.aspx?format=js` 的响应体。
         *
         * 返回空表的情形（全都不算异常）：body 为 null / 不是 JSON / 没有 `images` /
         * `images` 里每一条都缺 `startdate` 或 `urlbase`。
         *
         * 去重按 `dateKey` 保留首次出现的（Bing 偶发把同一天回两遍，重复项会让网格里
         * 出现两张一模一样的卡、点哪张都下同一个文件）。
         */
        fun parse(body: String?): List<BingWallpaperItem> {
            val root = MiniJson.tryParse(body) as? Map<*, *> ?: return emptyList()
            return BingWallpaperItem.listFromJson(root["images"])
                .filter { it.dateKey.isNotBlank() && it.urlBase.isNotBlank() }
                .distinctBy { it.dateKey }
                .take(BING_GALLERY_DAYS)
        }
    }
}
