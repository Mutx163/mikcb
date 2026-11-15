package com.mutx163.qingyu.weather

import com.mutx163.qingyu.core.DartFormatException
import com.mutx163.qingyu.core.DartTime
import com.mutx163.qingyu.core.MiniJson

/**
 * Dart `lib/models/weather_forecast.dart` 的移植（泳道 D · 业务族 8 天气/壁纸）。
 *
 * JSON 契约字段名与 Dart 逐字一致（`name` / `admin1` / … / `temperature_2m` /
 * `precipitation_probability` …），供后续与 Dart 侧的落盘数据互读。
 *
 * 时间语义：Dart 的 `DateTime` 是本地墙钟，Kotlin 侧按 core/DartTime 的约定用
 * [java.time.LocalDateTime] 承载。`fetchedAt` 的 epoch 毫秒进出按系统默认时区
 * 换算（[DartTime.fromEpochMillis] / [DartTime.toEpochMillis]）。
 */

/** 一个地点（天气数据的地理坐标载体）。 */
data class WeatherLocation(
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val admin1: String? = null,
    val country: String? = null,
    val district: String? = null,
    val timezone: String? = null,
) {
    /** 经纬度差小于该值即视为同一地点（换城市判定用）。 */
    val samePlaceTolerance: Double get() = SAME_PLACE_TOLERANCE

    /** 结果列表的副标题：行政区 + 国家，跳过空值与与主标题重复的值。 */
    val regionLabel: String
        get() {
            val parts = ArrayList<String>()
            for (value in listOf(admin1, country)) {
                val trimmed = value?.trim().orEmpty()
                if (trimmed.isEmpty() || trimmed == name || parts.contains(trimmed)) continue
                parts.add(trimmed)
            }
            return parts.joinToString(" · ")
        }

    /** 设置页那一行尾随显示的紧凑地名（有 district 时「市 · 区」）。 */
    val displayName: String
        get() {
            val trimmedDistrict = district?.trim().orEmpty()
            if (trimmedDistrict.isEmpty() || trimmedDistrict == name) return name
            return "$name · $trimmedDistrict"
        }

    /** 坐标取整到落盘精度后的副本。 */
    fun coarsened(): WeatherLocation = copy(
        latitude = coarsenCoordinate(latitude),
        longitude = coarsenCoordinate(longitude),
    )

    /** 是否与 [other] 指向同一地点：只比取整后的经纬度，不比名字。 */
    fun isSamePlaceAs(other: WeatherLocation): Boolean =
        kotlin.math.abs(coarsenCoordinate(latitude) - coarsenCoordinate(other.latitude)) <
            SAME_PLACE_TOLERANCE &&
            kotlin.math.abs(coarsenCoordinate(longitude) - coarsenCoordinate(other.longitude)) <
            SAME_PLACE_TOLERANCE

    /** JSON 键序与 Dart 一致（插入序）。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "name" to name,
        "admin1" to admin1,
        "country" to country,
        "district" to district,
        "latitude" to latitude,
        "longitude" to longitude,
        "timezone" to timezone,
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        /** 取整坐标比较容差（Dart `WeatherLocation.samePlaceTolerance`）。 */
        const val SAME_PLACE_TOLERANCE: Double = 1e-4

        /** 结构性缺失抛 DartFormatException（对应 Dart `throw FormatException`）。 */
        fun fromJson(json: Map<String, Any?>): WeatherLocation {
            val name = json["name"]
            if (name !is String || name.trim().isEmpty()) {
                throw DartFormatException("weather location: missing name")
            }
            val latitude = (json["latitude"] as? Number)?.toDouble()
            val longitude = (json["longitude"] as? Number)?.toDouble()
            if (latitude == null || longitude == null) {
                throw DartFormatException("weather location: missing coordinates")
            }
            return WeatherLocation(
                name = name,
                admin1 = json["admin1"] as? String,
                country = json["country"] as? String,
                // district 是后加字段：老数据没有这个键，读到 null 即可。
                district = json["district"] as? String,
                latitude = latitude,
                longitude = longitude,
                timezone = json["timezone"] as? String,
            )
        }

        /** 解析持久化的地点；数据损坏时返回 null（不抛）。 */
        fun tryDecode(raw: String?): WeatherLocation? {
            if (raw == null || raw.trim().isEmpty()) return null
            return try {
                val decoded = MiniJson.parse(raw)
                (decoded as? Map<*, *>) ?: return null
                val map = LinkedHashMap<String, Any?>()
                for ((k, v) in decoded) map[k.toString()] = v
                fromJson(map)
            } catch (_: Exception) {
                null
            }
        }
    }
}

/** 预报序列里的一个逐小时点。 */
data class HourlyWeatherPoint(
    /** 墙钟时刻（不带时区偏移）。与课程时间同为墙钟语义，直接比较。 */
    val time: java.time.LocalDateTime,
    val temperatureC: Double? = null,
    /** 降水概率，0~100。 */
    val precipitationProbability: Int? = null,
    /** 降水量（雨 + 阵雨 + 雪的水当量），mm。 */
    val precipitationMm: Double? = null,
    /** 降雪量，cm。 */
    val snowfallCm: Double? = null,
    /** WMO 天气现象码。 */
    val weatherCode: Int? = null,
)

/** 一个地点的多日逐小时预报。 */
class WeatherForecast(
    val latitude: Double,
    val longitude: Double,
    /** 抓取时刻（本地墙钟）。 */
    val fetchedAt: java.time.LocalDateTime,
    hourly: List<HourlyWeatherPoint>,
    /**
     * 当初**请求**用的取整坐标（与 [WeatherLocation.coarsened] 同一坐标系）。
     *
     * 2026-11-15 加：`latitude`/`longitude` 是接口回填的格点中心（示例请求 39.91 →
     * 响应 39.89455），与用户取整坐标差 0.02 左右，用 1e-4 容差比对永远不相等 ⇒
     * 每次冷启动都把缓存当「换城」丢掉。现在缓存比对用请求坐标（同一坐标系），
     * 格点中心只用于数据本身。旧缓存没有这两个字段（null）⇒ 视为一次 miss。
     */
    val requestedLatitude: Double? = null,
    val requestedLongitude: Double? = null,
) {
    /** 拷贝并按时间升序排序（不可变）。 */
    val hourly: List<HourlyWeatherPoint> = hourly.sortedBy { it.time }.toList()

    override fun toString(): String =
        "WeatherForecast($latitude,$longitude,fetchedAt=$fetchedAt,hourly=${hourly.size})"

    /** 窗口起始小时。 */
    val windowStart: java.time.LocalDateTime? get() = hourly.firstOrNull()?.time

    /** 窗口结束小时。 */
    val windowEnd: java.time.LocalDateTime? get() = hourly.lastOrNull()?.time

    /** 预报是否覆盖 [time]（含端点）。 */
    fun covers(time: java.time.LocalDateTime): Boolean {
        if (hourly.isEmpty()) return false
        return !time.isBefore(hourly.first().time) && !time.isAfter(hourly.last().time)
    }

    /** 到 [now] 为止，这份预报的窗口是否已经走完（跨天后需要重拉）。 */
    fun hasLapsedAt(now: java.time.LocalDateTime): Boolean {
        val end = windowEnd ?: return true
        return now.isAfter(end)
    }

    /**
     * 是否是 [location] 的预报：**用当初的请求坐标比**（同一坐标系、取整后应完全相等）。
     *
     * 不能用 [latitude]/[longitude]（格点中心）比——那套坐标与用户取整坐标差 0.02 左右，
     * 1e-4 的容差永远判不相等，冷启动就会把缓存丢掉重拉（2026-11-15 实报的根因）。
     * 旧缓存没有请求坐标 ⇒ 视为 miss（丢一次可接受，下次取数会补上）。
     */
    fun matchesLocation(location: WeatherLocation): Boolean {
        val requestedLat = requestedLatitude ?: return false
        val requestedLon = requestedLongitude ?: return false
        return kotlin.math.abs(requestedLat - coarsenCoordinate(location.latitude)) <
            WeatherLocation.SAME_PLACE_TOLERANCE &&
            kotlin.math.abs(requestedLon - coarsenCoordinate(location.longitude)) <
            WeatherLocation.SAME_PLACE_TOLERANCE
    }

    /** 列式序列化：逐小时字段拆成 6 个平行数组（键序与 Dart 一致）。 */
    fun toJson(): Map<String, Any?> = linkedMapOf(
        "latitude" to latitude,
        "longitude" to longitude,
        "fetchedAt" to DartTime.toEpochMillis(fetchedAt),
        "time" to hourly.map { wallClockIso(it.time) },
        "temperature_2m" to hourly.map { it.temperatureC },
        "precipitation_probability" to hourly.map { it.precipitationProbability },
        "precipitation" to hourly.map { it.precipitationMm },
        "snowfall" to hourly.map { it.snowfallCm },
        "weather_code" to hourly.map { it.weatherCode },
        // 2026-11-15：请求坐标随缓存落盘，冷启动比对用同一坐标系（旧缓存无此键 = miss）。
        "requestedLatitude" to requestedLatitude,
        "requestedLongitude" to requestedLongitude,
    )

    fun toJsonString(): String = MiniJson.encode(toJson())

    companion object {
        fun fromJson(json: Map<String, Any?>): WeatherForecast {
            val latitude = (json["latitude"] as? Number)?.toDouble()
            val longitude = (json["longitude"] as? Number)?.toDouble()
            val fetchedAtMs = (json["fetchedAt"] as? Number)?.toLong()
            if (latitude == null || longitude == null || fetchedAtMs == null) {
                throw DartFormatException("weather forecast: missing header")
            }
            return fromColumns(
                latitude = latitude,
                longitude = longitude,
                fetchedAt = DartTime.fromEpochMillis(fetchedAtMs),
                columns = json,
                // 旧缓存没有这两个键 → null → matchesLocation 恒 false（当作一次 miss）。
                requestedLatitude = (json["requestedLatitude"] as? Number)?.toDouble(),
                requestedLongitude = (json["requestedLongitude"] as? Number)?.toDouble(),
            )
        }

        /**
         * 解析 Open-Meteo `/v1/forecast` 的原始响应。
         *
         * 经纬度用响应里回填的格点中心，而不是请求坐标——后续判断「缓存是不是
         * 这个城市的」时才不会因为格点偏移误判为换城。
         */
        fun fromOpenMeteoResponse(
            json: Map<String, Any?>,
            fetchedAt: java.time.LocalDateTime,
            /** 本次**请求**的取整坐标；缓存比对用，缺省 null = 不做缓存命中（测试/旧路径）。 */
            requestedLatitude: Double? = null,
            requestedLongitude: Double? = null,
        ): WeatherForecast {
            val hourly = json["hourly"] as? Map<*, *>
                ?: throw DartFormatException("weather forecast: missing hourly block")
            val latitude = (json["latitude"] as? Number)?.toDouble()
                ?: throw DartFormatException("weather forecast: missing coordinates")
            val longitude = (json["longitude"] as? Number)?.toDouble()
                ?: throw DartFormatException("weather forecast: missing coordinates")
            val columns = LinkedHashMap<String, Any?>()
            for ((k, v) in hourly) columns[k.toString()] = v
            return fromColumns(
                latitude = latitude,
                longitude = longitude,
                fetchedAt = fetchedAt,
                columns = columns,
                requestedLatitude = requestedLatitude,
                requestedLongitude = requestedLongitude,
            )
        }

        private fun fromColumns(
            latitude: Double,
            longitude: Double,
            fetchedAt: java.time.LocalDateTime,
            columns: Map<String, Any?>,
            requestedLatitude: Double? = null,
            requestedLongitude: Double? = null,
        ): WeatherForecast {
            val times = column(columns["time"])
            val temperatures = column(columns["temperature_2m"])
            val probabilities = column(columns["precipitation_probability"])
            val precipitation = column(columns["precipitation"])
            val snowfall = column(columns["snowfall"])
            val codes = column(columns["weather_code"])

            val points = ArrayList<HourlyWeatherPoint>(times.size)
            for (i in times.indices) {
                val rawTime = times[i]
                if (rawTime !is String) continue
                val time = DartTime.tryParseIso(rawTime) ?: continue
                points.add(
                    HourlyWeatherPoint(
                        time = time,
                        temperatureC = doubleAt(temperatures, i),
                        precipitationProbability = intAt(probabilities, i),
                        precipitationMm = doubleAt(precipitation, i),
                        snowfallCm = doubleAt(snowfall, i),
                        weatherCode = intAt(codes, i),
                    ),
                )
            }
            return WeatherForecast(
                latitude = latitude,
                longitude = longitude,
                fetchedAt = fetchedAt,
                hourly = points,
                requestedLatitude = requestedLatitude,
                requestedLongitude = requestedLongitude,
            )
        }

        /** 解析缓存的预报；数据损坏或没有任何小时点时返回 null。 */
        fun tryDecode(raw: String?): WeatherForecast? {
            if (raw == null || raw.trim().isEmpty()) return null
            return try {
                val decoded = MiniJson.parse(raw)
                if (decoded !is Map<*, *>) return null
                val map = LinkedHashMap<String, Any?>()
                for ((k, v) in decoded) map[k.toString()] = v
                val forecast = fromJson(map)
                if (forecast.hourly.isEmpty()) null else forecast
            } catch (_: Exception) {
                null
            }
        }

        private fun column(raw: Any?): List<Any?> = (raw as? List<Any?>) ?: emptyList()

        private fun doubleAt(column: List<Any?>, index: Int): Double? {
            if (index >= column.size) return null
            return (column[index] as? Number)?.toDouble()
        }

        private fun intAt(column: List<Any?>, index: Int): Int? {
            if (index >= column.size) return null
            val value = column[index] as? Number ?: return null
            // Dart num.round()：半远离零。
            val d = value.toDouble()
            return Math.round(d).toInt().let { rounded ->
                // Math.round 半向上；Dart round 半远离零。负半值上两者不同。
                if (d < 0 && (d + Math.floor(d)) == -0.5) -Math.round(-d).toInt() else rounded
            }
        }

        /** 不带偏移量的墙钟 ISO 串（`yyyy-MM-ddTHH:mm`，无 .SSS 无 Z）。 */
        fun wallClockIso(time: java.time.LocalDateTime): String {
            fun two(value: Int) = value.toString().padStart(2, '0')
            return "${time.year}-${two(time.monthValue)}-${two(time.dayOfMonth)}" +
                "T${two(time.hour)}:${two(time.minute)}"
        }
    }
}
