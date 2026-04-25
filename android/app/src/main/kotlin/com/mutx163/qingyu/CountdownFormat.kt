package com.mutx163.qingyu

object CountdownFormat {

    fun formatDuration(
        durationMillis: Long,
        style: String,
        secondsThresholdMillis: Long = 60_000L,
    ): String {
        return when (style) {
            "smart_min_s" -> formatSmartDuration(
                durationMillis = durationMillis,
                secondsThresholdMillis = secondsThresholdMillis,
                minuteSuffix = "min",
                secondSuffix = "s",
            )
            "minute_second_cn" -> formatMinuteSecondCn(durationMillis)
            "minute_second_colon" -> formatMinuteSecondColon(durationMillis)
            "minute_second_min_s" -> formatMinuteSecond(durationMillis, minuteSuffix = "min", secondSuffix = "s")
            "minute_second_min_slash_s" -> formatMinuteSecond(durationMillis, minuteSuffix = "min/", secondSuffix = "s")
            "minute_only_cn" -> formatMinuteOnly(durationMillis, "分钟")
            "minute_only_min" -> formatMinuteOnly(durationMillis, "min")
            "minute_only_slash" -> formatMinuteOnly(durationMillis, "/min")
            "second_only_cn" -> formatSecondOnly(durationMillis, "秒")
            "second_only_short" -> formatSecondOnly(durationMillis, "s")
            "second_only_slash" -> formatSecondOnly(durationMillis, "/s")
            else -> formatSmartDuration(durationMillis, secondsThresholdMillis)
        }
    }

    fun formatSmartDuration(
        durationMillis: Long,
        secondsThresholdMillis: Long,
        minuteSuffix: String = "分钟",
        secondSuffix: String = "秒",
    ): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val flooredMinutes = (totalSeconds / 60L).coerceAtLeast(1L)
        val roundedUpMinutes = ((totalSeconds + 59L) / 60L).coerceAtLeast(1L)

        return when {
            durationMillis <= secondsThresholdMillis -> "${totalSeconds}${secondSuffix}"
            totalSeconds > 120L -> "${flooredMinutes}${minuteSuffix}"
            totalSeconds > 60L -> "${roundedUpMinutes}${minuteSuffix}"
            else -> "${totalSeconds}${secondSuffix}"
        }
    }

    fun formatMinuteSecondCn(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L
        return when {
            minutes > 0L && seconds > 0L -> "${minutes}分钟${seconds}秒"
            minutes > 0L -> "${minutes}分钟"
            else -> "${seconds}秒"
        }
    }

    fun formatMinuteSecond(
        durationMillis: Long,
        minuteSuffix: String,
        secondSuffix: String,
    ): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L
        return when {
            minutes > 0L && seconds > 0L -> "${minutes}${minuteSuffix}${seconds}${secondSuffix}"
            minutes > 0L -> "${minutes}${minuteSuffix.trimEnd('/')}"
            else -> "${seconds}${secondSuffix}"
        }
    }

    fun formatMinuteSecondColon(durationMillis: Long): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = totalSeconds / 60L
        val seconds = totalSeconds % 60L
        return "${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}"
    }

    fun formatMinuteOnly(durationMillis: Long, suffix: String): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        val minutes = (totalSeconds / 60L).coerceAtLeast(1L)
        return "$minutes$suffix"
    }

    fun formatSecondOnly(durationMillis: Long, suffix: String): String {
        val totalSeconds = (durationMillis / 1000L).coerceAtLeast(0L)
        return "$totalSeconds$suffix"
    }
}
