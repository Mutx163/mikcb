package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationKeyword
import com.mutx163.qingyu.core.LocationKeywordMatchMode

/**
 * 地点 → 楼栋聚类（移植自 Dart `lib/domain/location_building_cluster_logic.dart`，706 行，逐行等价）。
 *
 * 编辑页的「从课表识别的楼栋」区就是用它：把课表里的一堆地点串（`A1062`、`第六教学楼`、
 * `西3-201`、`腾讯会议` …）聚成「楼栋」，每个楼栋给一条建议关键词，用户一键添加。
 *
 * 这是启发式解析（不是固定校区白名单），大量正则覆盖真实脏数据：字母+数字编码、任意
 * `*楼`、`*馆`、`*厅`、`*中心`、`号楼/栋/座`、`教N`、`东/西 + 数字`、教室、在线平台、英文楼名……
 *
 * 纯函数、零依赖，JVM 可测。Dart 只读、不改。
 */

/** 自动楼栋建议的可信度。 */
enum class BuildingClusterConfidence { HIGH, MEDIUM, LOW }

/** 一组疑似同一楼栋的教室地点。 */
data class BuildingCluster(
    /** 去重/匹配用的稳定键（如 `A1` / `A主` / `一教`）。 */
    val buildingKey: String,
    /** 人类可读名（启发式，可能等于 [buildingKey]）。 */
    val displayName: String,
    /** 建议给地点组用的关键词。 */
    val suggestedKeyword: LocationKeyword,
    /** 落入本簇的样本地点（去重、已排序）。 */
    val sampleLocations: List<String>,
    val confidence: BuildingClusterConfidence,
    /** 原始串里弱信号的门/区标签（如「南门」）。 */
    val gateTags: List<String> = emptyList(),
) {
    val locationCount: Int get() = sampleLocations.size
}

private data class ParsedLocation(
    val original: String,
    val buildingKey: String,
    val confidence: BuildingClusterConfidence,
    val gateTags: List<String>,
)

private data class LetterDigitMatch(
    val buildingKey: String,
    val confidence: BuildingClusterConfidence,
)

object LocationBuildingClusterLogic {

    // ── 正则表（照抄 Dart，raw string 交给 Java 正则解释 \d \s \uXXXX）──
    private val whitespace = Regex("""\s+""")
    private val chineseTeachingBuilding = Regex("""(?:第)?([一二三四五六七八九十百零〇两\d]{1,3})教(?:学楼)?""")
    private val teachThenNumber =
        Regex("""教([A-Za-z]|[一二三四五六七八九十]|[0-9]{1,3})(?:号)?(?:教学)?(?:楼|栋)?""")
    private val mainBuildingChinese = Regex("""主教学楼|主教""")
    private val letterMainBuilding = Regex("""([A-Za-z]+)主""", RegexOption.IGNORE_CASE)
    private val letterChineseBuilding = Regex(
        """([A-Za-z]+)(综合楼|教学楼|实验楼|实训楼|科研楼|信息楼|综合|综|实验|实训|楼)""",
        RegexOption.IGNORE_CASE,
    )
    private val letterDigitPrefix = Regex("""([A-Za-z]+)(\d+)""", RegexOption.IGNORE_CASE)
    private val numberedBuilding = Regex(
        """(?:教学|实验|实训|综合|公共)?(?:第)?([一二三四五六七八九十百零〇两\d]{1,3})(?:号|#|＃)?(?:教学|实验|实训)?(楼|栋|幢|座)""",
    )
    private val seatBlock = Regex("""([A-Za-z\d一二三四五六七八九十]{1,3})座""", RegexOption.IGNORE_CASE)
    private val cardinalGrid =
        Regex("""([东西南北])(?:教|教学楼|楼)?([A-Za-z]?\d{1,3})(?:号)?(?:教学)?(?:楼|栋)?""")
    private val digitBuildingRoom =
        Regex("""^([A-Za-z]?\d{1,3}[A-Za-z]?)[-–—/／·.](\d{2,4}[A-Za-z]?)$""", RegexOption.IGNORE_CASE)
    private val namedFacilityBuilding = Regex(
        """([A-Za-z0-9]*[\u4e00-\u9fff]{1,16}(?:""" +
            """教学楼|实验楼|实训楼|综合楼|科研楼|行政楼|办公楼|信息楼|工学楼|理学楼|文理楼|""" +
            """艺术楼|音乐楼|体育楼|逸夫楼|求是楼|明德楼|博学楼|至善楼|知行楼|致远楼|行健楼|厚德楼|""" +
            """理工楼|基础楼|公共楼|图文中心|实验中心|实训中心|活动中心|学生中心|创新中心|""" +
            """会议中心|学术中心|报告厅|阶梯教室|多媒体教室|语音室|机房|实验室|""" +
            """图书馆|体育馆|游泳馆|礼堂|大礼堂|音乐厅|美术馆|博物馆|科技馆|""" +
            """楼|馆|厅|中心|栋|幢|院|所))""",
    )
    private val classroomLabel = Regex(
        """([A-Za-z0-9]*[\u4e00-\u9fffA-Za-z0-9]{1,20}(?:教室|阶教|阶梯教室|语音室|机房|实验室))""",
    )
    private val sportsPlace = Regex(
        """([\u4e00-\u9fffA-Za-z0-9]{0,12}(?:""" +
            """操场|田径场|足球场|篮球场|排球场|网球场|羽毛球场|乒乓球场|""" +
            """游泳馆|体育馆|运动场|风雨操场|体育场))""",
    )
    private val virtualPlatform = Regex(
        """([\u4e00-\u9fffA-Za-z0-9]{0,24}(?:""" +
            """测评平台|在线平台|学习平台|教学平台|实验平台|慕课|在线课堂|网络课堂|""" +
            """线上教室|线上|网上|网课|腾讯会议|钉钉|飞书|Zoom|Teams|ClassIn|""" +
            """平台|系统|网站|直播))""",
        RegexOption.IGNORE_CASE,
    )
    private val englishFacility = Regex(
        """((?:[A-Za-z][A-Za-z0-9.\-]{0,20}\s+){0,4}(?:Building|Bldg\.?|Hall|Tower|Block|Wing|Lab(?:oratory)?|Centre|Center|Room|Rm\.?)(?:\s+[A-Za-z0-9.\-]{1,12})?)""",
        RegexOption.IGNORE_CASE,
    )
    private val stemThenRoom = Regex(
        """^((?:[A-Za-z]{1,4})?[\u4e00-\u9fff]{2,16})(?:[-–—·./／\s]*)(?:[A-Za-z]?\d{2,5}[A-Za-z]?|\d{1,2}[-–—]\d{2,4})$""",
    )
    private val shortChinesePlace = Regex("""^[\u4e00-\u9fff]{2,16}$""")
    private val gateTagPattern = Regex(
        """南门|北门|东门|西门|正门|侧门|西区|东区|南区|北区|老校区|新校区|虎溪|沙坪坝|大学城|本部|分校|主校区|南校区|北校区|中心校区""",
    )
    private val weakZonePrefix = Regex(
        """^(?:西区|东区|南区|北区|老校区|新校区|本部|分校|大学城|主校区|南校区|北校区|中心校区|虎溪校区|沙坪坝校区)""",
    )
    private val weakSchoolPrefix = Regex("""^[\u4e00-\u9fffA-Za-z0-9]{2,20}(?:大学|学院|校区)""")
    private val trailingRoomNoise = Regex(
        """(?:[-–—·./／\s()（）]*)(?:""" +
            """[A-Za-z]?\d{1,5}[A-Za-z]?|""" +
            """\d{1,2}[-–—]\d{2,4}|""" +
            """[东南西北]?[侧]?(?:楼|层)?\d{1,3}[F层]?|""" +
            """第?\d{1,2}(?:楼|层|F|f)|""" +
            """\d{1,2}F)$""",
    )
    private val chineseTailRegex = Regex("""[\u4e00-\u9fff]$""")
    private val englishTrailingRoom = Regex("""\s+[A-Za-z]?\d{1,5}[A-Za-z]?$""")
    private val spaceRun = Regex("""\s+""")
    private val letterZongDisplay = Regex("""^([A-Za-z]+)综$""")
    private val chineseOrdinalDisplay = Regex("""^([一二三四五六七八九十百零〇两\d]+)教$""")
    private val teachNumDisplay = Regex("""^教([A-Za-z\d]+)$""")
    private val letterMainDisplay = Regex("""^([A-Za-z]+)主$""")
    private val letterDigitDisplay = Regex("""^([A-Za-z]+)(\d+)$""")
    private val numberedDisplay = Regex("""^([一二三四五六七八九十百零〇两\d]+)(楼|栋|幢|座)$""")

    /** 从一个完整教室地点串推一条建议关键词；仅空串返回 null。 */
    fun suggestKeywordFromLocation(location: String?): LocationKeyword? {
        val parsed = parseOne(location) ?: return null
        return LocationKeyword(pattern = parsed.buildingKey, mode = preferredModeForKey(parsed.buildingKey))
    }

    /** 把一批地点串聚成楼栋。 */
    fun clusterLocations(locations: Iterable<String>): List<BuildingCluster> {
        val byKey = LinkedHashMap<String, MutableList<ParsedLocation>>()
        for (raw in locations) {
            val parsed = parseOne(raw) ?: continue
            byKey.getOrPut(parsed.buildingKey) { mutableListOf() }.add(parsed)
        }
        val clusters = ArrayList<BuildingCluster>(byKey.size)
        for ((key, members) in byKey) {
            val samples = members.map { it.original }.toSet().toList().sorted()
            val gateTags = members.flatMap { it.gateTags }.toSet().toList().sorted()
            val confidence = members.map { it.confidence }.reduce { a, b -> maxConfidence(a, b) }
            clusters.add(
                BuildingCluster(
                    buildingKey = key,
                    displayName = displayNameForKey(key),
                    suggestedKeyword = LocationKeyword(pattern = key, mode = preferredModeForKey(key)),
                    sampleLocations = samples,
                    confidence = confidence,
                    gateTags = gateTags,
                ),
            )
        }
        clusters.sortWith(compareByDescending<BuildingCluster> { it.locationCount }.thenBy { it.buildingKey })
        return clusters
    }

    /** 尚未被任何关键词覆盖的楼栋簇。 */
    fun uncoveredClusters(
        locations: Iterable<String>,
        existingKeywords: Iterable<LocationKeyword>,
    ): List<BuildingCluster> {
        val existingPatterns = existingKeywords
            .map { it.pattern.trim().lowercase() }
            .filter { it.isNotEmpty() }
            .toSet()
        return clusterLocations(locations).filter { !existingPatterns.contains(it.buildingKey.lowercase()) }
    }

    private fun parseOne(location: String?): ParsedLocation? {
        val original = (location ?: "").trim()
        if (original.isEmpty()) return null

        val normalized = normalizeLocationText(original)
        val gateTags = extractGateTags(normalized)

        var parseSource = normalized
        parseSource = weakZonePrefix.replaceFirst(parseSource, "")
        if (parseSource.length >= 4) {
            val withoutSchool = weakSchoolPrefix.replaceFirst(parseSource, "")
            if (withoutSchool.length >= 2) parseSource = withoutSchool
        }
        if (parseSource.isEmpty()) parseSource = normalized

        virtualPlatform.find(parseSource)?.let { virtual ->
            val key = virtual.groupValues[1].trim().ifEmpty { parseSource }.trim()
            if (key.length >= 2) return hit(original, key, BuildingClusterConfidence.HIGH, gateTags)
        }

        if (mainBuildingChinese.containsMatchIn(normalized)) {
            return hit(original, "主教", BuildingClusterConfidence.HIGH, gateTags)
        }

        chineseTeachingBuilding.find(parseSource)?.let { m ->
            val ordinal = m.groupValues[1]
            return hit(original, "${ordinal}教", BuildingClusterConfidence.HIGH, gateTags)
        }

        teachThenNumber.find(parseSource)?.let { m ->
            val ordinal = m.groupValues[1].uppercase()
            if (ordinal.isNotEmpty()) return hit(original, "教$ordinal", BuildingClusterConfidence.HIGH, gateTags)
        }

        letterMainBuilding.find(parseSource)?.let { m ->
            val letter = m.groupValues[1].uppercase()
            if (letter.isNotEmpty() && letter.length <= 2) {
                return hit(original, "${letter}主", BuildingClusterConfidence.HIGH, gateTags)
            }
        }

        letterChineseBuilding.find(parseSource)?.let { m ->
            val letter = m.groupValues[1].uppercase()
            val stem = m.groupValues[2]
            if (letter.isNotEmpty() && letter.length <= 2 && stem.isNotEmpty()) {
                return hit(original, normalizeLetterChineseKey(letter, stem), BuildingClusterConfidence.HIGH, gateTags)
            }
        }

        bestNamedFacility(parseSource)?.let { named ->
            return hit(original, named, BuildingClusterConfidence.HIGH, gateTags)
        }

        cardinalGrid.find(parseSource)?.let { m ->
            val dir = m.groupValues[1]
            val code = m.groupValues[2].uppercase()
            if (dir.isNotEmpty() && code.isNotEmpty()) {
                return hit(original, "$dir$code", BuildingClusterConfidence.HIGH, gateTags)
            }
        }

        numberedBuilding.find(parseSource)?.let { m ->
            val ordinal = m.groupValues[1]
            val unit = m.groupValues[2].ifEmpty { "楼" }
            if (ordinal.isNotEmpty()) return hit(original, "$ordinal$unit", BuildingClusterConfidence.HIGH, gateTags)
        }

        seatBlock.find(parseSource)?.let { m ->
            val block = m.groupValues[1].uppercase()
            if (block.isNotEmpty()) return hit(original, "${block}座", BuildingClusterConfidence.HIGH, gateTags)
        }

        classroomLabel.find(parseSource)?.let { m ->
            val key = m.groupValues[1].trim()
            if (key.length >= 2) return hit(original, key, BuildingClusterConfidence.HIGH, gateTags)
        }

        sportsPlace.find(parseSource)?.let { m ->
            val key = m.groupValues[1].trim()
            if (key.length >= 2) return hit(original, key, BuildingClusterConfidence.HIGH, gateTags)
        }

        bestLetterDigitMatch(parseSource)?.let { ld ->
            return hit(original, ld.buildingKey, ld.confidence, gateTags)
        }

        digitBuildingRoom.find(parseSource)?.let { m ->
            val building = m.groupValues[1].uppercase()
            if (building.isNotEmpty()) return hit(original, building, BuildingClusterConfidence.MEDIUM, gateTags)
        }

        val english = englishFacility.find(original) ?: englishFacility.find(parseSource)
        if (english != null) {
            val rawEnglish = collapseSpaces(english.groupValues[1])
            val key = englishTrailingRoom.replaceFirst(rawEnglish, "").trim()
            if (key.length >= 3) return hit(original, key, BuildingClusterConfidence.MEDIUM, gateTags)
        }

        stemThenRoom.find(parseSource)?.let { m ->
            val key = m.groupValues[1].trim()
            if (key.length >= 2) return hit(original, key, BuildingClusterConfidence.MEDIUM, gateTags)
        }

        if (shortChinesePlace.containsMatchIn(parseSource)) {
            return hit(original, parseSource, BuildingClusterConfidence.MEDIUM, gateTags)
        }

        val fallback = fallbackKeyword(parseSource)
        if (fallback != null) return hit(original, fallback, BuildingClusterConfidence.LOW, gateTags)
        return null
    }

    private fun hit(
        original: String,
        buildingKey: String,
        confidence: BuildingClusterConfidence,
        gateTags: List<String>,
    ): ParsedLocation = ParsedLocation(original, buildingKey, confidence, gateTags)

    /** 全角→半角，统一破折号/斜杠，去空白/中点，拆短括号。 */
    private fun normalizeLocationText(input: String): String {
        val buffer = StringBuilder(input.length)
        for (ch in input) {
            val unit = ch.code
            when {
                unit in 0xFF01..0xFF5E -> buffer.append((unit - 0xFEE0).toChar())
                unit == 0x3000 -> buffer.append(' ')
                else -> buffer.append(ch)
            }
        }
        var text = buffer.toString()
        text = whitespace.replace(text, "")
        text = text.replace('－', '-').replace('—', '-').replace('–', '-').replace('／', '/')
        text = text.replace("·", "").replace("•", "")
        text = Regex("""[（(]([^）)]{1,12})[）)]""").replace(text) { it.groupValues[1] }
        return text
    }

    private fun bestNamedFacility(text: String): String? {
        val matches = namedFacilityBuilding.findAll(text).toList()
        if (matches.isEmpty()) return null
        var best: MatchResult? = null
        for (m in matches) {
            val candidate = m.groupValues[1]
            if (candidate.length < 2) continue
            if (best == null || candidate.length > best.groupValues[1].length) best = m
        }
        val chosen = best ?: return null
        var key = chosen.groupValues[1].trim()
        if (key.length < 2) return null
        key = trailingRoomNoise.replaceFirst(key, "")
        if (key.length < 2) return null
        return key
    }

    private fun fallbackKeyword(normalized: String): String? {
        var value = trailingRoomNoise.replaceFirst(normalized, "").trim()
        if (value.length < 2) {
            if (normalized.length >= 2) {
                return if (normalized.length > 24) normalized.substring(0, 24) else normalized
            }
            return null
        }
        if (value.length > 24) value = value.substring(0, 24)
        return value
    }

    private fun collapseSpaces(value: String): String = spaceRun.replace(value.trim(), " ")

    private fun normalizeLetterChineseKey(letter: String, stem: String): String {
        val upperLetter = letter.uppercase()
        return when {
            stem.startsWith("综") -> "${upperLetter}综"
            stem.startsWith("教学") -> "${upperLetter}教学楼"
            stem.startsWith("实验") -> "${upperLetter}实验楼"
            stem.startsWith("实训") -> "${upperLetter}实训楼"
            stem == "楼" -> "${upperLetter}楼"
            else -> "$upperLetter$stem"
        }
    }

    private fun bestLetterDigitMatch(normalized: String): LetterDigitMatch? {
        val matches = letterDigitPrefix.findAll(normalized).toList()
        if (matches.isEmpty()) return null
        for (m in matches) {
            val letter = m.groupValues[1].uppercase()
            val digits = m.groupValues[2]
            if (letter.isEmpty() || digits.isEmpty() || letter.length > 2) continue
            val prefix = normalized.substring(0, m.range.first)
            if (chineseTailRegex.containsMatchIn(prefix)) continue
            val buildingDigits = splitBuildingDigits(digits)
            val key = "$letter$buildingDigits"
            val confidence = if (digits.length >= 3) BuildingClusterConfidence.HIGH else BuildingClusterConfidence.MEDIUM
            return LetterDigitMatch(key, confidence)
        }
        return null
    }

    private fun splitBuildingDigits(digits: String): String {
        if (digits.length <= 2) return digits
        val oneDigitRoom = digits.substring(1)
        if (oneDigitRoom.length in 3..4) return digits.substring(0, 1)
        if (digits.length >= 5) {
            val twoDigitRoom = digits.substring(2)
            if (twoDigitRoom.length in 3..4) return digits.substring(0, 2)
        }
        return digits.substring(0, 1)
    }

    private fun extractGateTags(normalized: String): List<String> =
        gateTagPattern.findAll(normalized).map { it.value }.toSet().toList().sorted()

    private fun preferredModeForKey(key: String): LocationKeywordMatchMode {
        val hasLetterOrDigit = Regex("""[A-Za-z0-9]""").containsMatchIn(key)
        if (!hasLetterOrDigit) return LocationKeywordMatchMode.CONTAINS
        val lower = key.lowercase()
        return if (
            key.contains(' ') || key.contains("平台") || key.contains("系统") ||
            key.contains("教室") || key.contains("会议") ||
            lower.contains("zoom") || lower.contains("teams")
        ) {
            LocationKeywordMatchMode.CONTAINS
        } else {
            LocationKeywordMatchMode.PREFIX
        }
    }

    private fun displayNameForKey(key: String): String {
        if (key == "主教") return "主教学楼"
        letterZongDisplay.find(key)?.let { return "${it.groupValues[1].uppercase()}综合楼" }
        chineseOrdinalDisplay.find(key)?.let { return "第${it.groupValues[1]}教学楼" }
        teachNumDisplay.find(key)?.let { return "教${it.groupValues[1]}" }
        letterMainDisplay.find(key)?.let { return "${it.groupValues[1].uppercase()}主教学楼" }
        letterDigitDisplay.find(key)?.let { return "${it.groupValues[1].uppercase()}${it.groupValues[2]}栋" }
        numberedDisplay.find(key)?.let { return "${it.groupValues[1]}号${it.groupValues[2]}" }
        return key
    }

    private fun maxConfidence(left: BuildingClusterConfidence, right: BuildingClusterConfidence): BuildingClusterConfidence {
        val order = mapOf(
            BuildingClusterConfidence.LOW to 0,
            BuildingClusterConfidence.MEDIUM to 1,
            BuildingClusterConfidence.HIGH to 2,
        )
        return if ((order[left] ?: 0) >= (order[right] ?: 0)) left else right
    }
}
