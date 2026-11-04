package com.mutx163.qingyu.pages.import

import com.mutx163.qingyu.core.FormatException
import com.mutx163.qingyu.core.ServiceMessage
import java.io.ByteArrayInputStream
import java.time.LocalDateTime
import java.util.Locale
import java.util.zip.ZipInputStream

/**
 * `.xlsx`（zip + XML 容器）→ 行矩阵的**最小解码器**，只做「读第一个工作表」。
 *
 * ## 为什么单独一层
 *
 * [SpreadsheetImportModel.parseBytes] 的 KDoc 写得很清楚：容器解码**不在纯模型层**，
 * 模型只认已经切好的行矩阵（`parseRows` 是「格式识别 + 逐行解析」的唯一入口）。
 * 本对象补的正是这一层胶水，输出直接喂 `parseRows`——于是 xlsx 与 csv 走**同一条**
 * 解析与警告链路，不会出现「两种文件两套行为」。
 *
 * ## 依赖
 *
 * 只用 `java.util.zip`（Android 与 JVM 单测里都有），不引 POI/apache-poi 那类几十 MB 的库
 * （本仓安卓侧依赖清单里一个 xlsx 库都没有，也不打算为此加）。
 *
 * ## 能读什么 / 读不了什么（诚实边界）
 *
 * 能读：共享字符串（`t="s"` + `xl/sharedStrings.xml`）、内联字符串（`t="inlineStr"`）、
 * 公式字符串结果（`t="str"`）、布尔（`t="b"`）、数字（按原文）。
 *
 * 读不了（都是**真实会遇到**的情况，出错时给具体原因，不静默给空表）：
 * - 加密 / 带密码的 xlsx（不是合法 zip ⇒ 报 `invalid zip`）；
 * - 日期型单元格的**显示格式**（Excel 把日期存成序列号，本解码器只拿到数字）——
 *   本仓表格模板里日期不是必填列，课程名/星期/节次/周次全是文本或整数，所以不影响导入；
 * - 多工作表只读第一张：与 Dart 侧「仅读取首个工作表」的文案一致。
 *
 * ## 与 Dart 的对应
 *
 * Dart 的 `SpreadsheetImportService` 用 `excel` 包解码后同样只取第一个 sheet；
 * 报错码同源：`spreadsheet_xlsx_parse_failed`（文案在
 * [ImportServiceMessages]，中英由 ARB 决定）。
 */
object XlsxSheetDecoder {

    /** 单个 zip 条目解压后的字节上限：防止 zip 炸弹把内存吃光（20 MB 磁盘 → 展开可能几十倍）。 */
    private const val MAX_ENTRY_BYTES: Long = 64L * 1024 * 1024

    /** Excel 1900 日期系统的序列号零点（Dart `DateTime(1899, 12, 30)`；不认 `date1904`）。 */
    private val EXCEL_EPOCH: LocalDateTime = LocalDateTime.of(1899, 12, 30, 0, 0)

    /** 时间格式的基准（Dart `DateTime(0)` = 1970-01-01 本地零点）。 */
    private val UNIX_EPOCH: LocalDateTime = LocalDateTime.of(1970, 1, 1, 0, 0)

    private val SHEET_ENTRY_PATTERN = Regex("""^xl/worksheets/sheet(\d+)\.xml$""")
    private val ROW_PATTERN = Regex("""<row(\s[^>]*)?>(.*?)</row>""", RegexOption.DOT_MATCHES_ALL)
    private val ROW_NUMBER_PATTERN = Regex("""\br="(\d+)"""")
    private val CELL_PATTERN = Regex("""<c(\s[^>]*)?>(.*?)</c>""", RegexOption.DOT_MATCHES_ALL)
    private val CELL_REF_PATTERN = Regex("""r="([A-Z]+)(\d+)"""")
    private val CELL_TYPE_PATTERN = Regex("""t="([^"]+)"""")
    private val CELL_STYLE_PATTERN = Regex("""\bs="(\d+)"""")
    private val CELL_XFS_PATTERN = Regex("""<cellXfs(?:\s[^>]*)?>(.*?)</cellXfs>""", RegexOption.DOT_MATCHES_ALL)
    private val XF_PATTERN = Regex("""<xf(?:\s[^>]*)?/?>""")
    private val NUM_FMT_ID_PATTERN = Regex("""numFmtId="(\d+)"""")
    private val VALUE_PATTERN = Regex("""<v>(.*?)</v>""", RegexOption.DOT_MATCHES_ALL)
    private val SHARED_ITEM_PATTERN = Regex("""<si>(.*?)</si>""", RegexOption.DOT_MATCHES_ALL)
    private val TEXT_PATTERN = Regex("""<t(?:\s[^>]*)?>(.*?)</t>""", RegexOption.DOT_MATCHES_ALL)
    private val PHONETIC_PATTERN = Regex("""<rPh(?:\s[^>]*)?>.*?</rPh>""", RegexOption.DOT_MATCHES_ALL)
    private val ENTITY_PATTERN = Regex("""&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);""")

    /**
     * 解出第一个工作表的行矩阵。行内单元格按 `r="B2"` 的列号摆放，缺列补空串
     * （表格模型是按列下标取的，不能因为中间空一格就整体错位）。
     *
     * 任何结构性失败都抛 [FormatException]（消息是服务层码，交给
     * [ImportServiceMessages] 出人话），**不返回空表**——空表会被上层解释成
     * 「文件里没有课」，用户会以为自己的表是空的。
     */
    fun decodeFirstSheet(bytes: ByteArray): List<List<String>> {
        val entries = readEntries(bytes)
        // 条目名在 readEntries 里统一小写，查表也必须用小写键
        // （`xl/sharedStrings.xml` → `xl/sharedstrings.xml`），否则共享字符串永远是空表，
        // 所有文本单元格都会变成空串，表格模型直接报「格式无法识别」。
        val sharedStrings = entries["xl/sharedstrings.xml"]?.let(::parseSharedStrings).orEmpty()
        val numFormats = entries["xl/styles.xml"]?.let(::parseNumFormats).orEmpty()
        val sheetEntry = entries.keys
            .mapNotNull { name -> SHEET_ENTRY_PATTERN.matchEntire(name)?.let { it to name } }
            .minByOrNull { it.first.groupValues[1].toIntOrNull() ?: Int.MAX_VALUE }
            ?.second
            ?: fail("no worksheet found in xlsx container")
        val sheetXml = String(entries.getValue(sheetEntry), Charsets.UTF_8)
        return parseRows(sheetXml, sharedStrings, numFormats)
    }

    // ------------------------------------------------------------------
    // zip
    // ------------------------------------------------------------------

    /** 把 zip 里所有条目读进内存表；条目名统一小写并去前导 `/`。 */
    private fun readEntries(bytes: ByteArray): Map<String, ByteArray> {
        val entries = LinkedHashMap<String, ByteArray>()
        try {
            ZipInputStream(ByteArrayInputStream(bytes)).use { zip ->
                while (true) {
                    val entry = zip.nextEntry ?: break
                    if (entry.isDirectory) continue
                    val name = entry.name.removePrefix("/").lowercase()
                    val read = readCapped(zip)
                    if (read == null) fail("entry too large: $name")
                    entries[name] = read
                }
            }
        } catch (error: FormatException) {
            // 自己抛的「条目太大」原样上抛，别再被折成一句 invalid zip。
            throw error
        } catch (error: Exception) {
            // ZipException / EOFException / IllegalStateException 都归结成一句「容器读不出来」，
            // 原始信息留在 error 里便于排障（文案层只会显示我们给的那段）。
            fail("invalid zip: ${error.javaClass.simpleName}")
        }
        if (entries.isEmpty()) fail("empty zip")
        return entries
    }

    /** 限长读一个 zip 条目；超过上限返回 null（不继续读，避免把内存吃满）。 */
    private fun readCapped(zip: ZipInputStream): ByteArray? {
        val out = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val read = zip.read(buffer)
            if (read < 0) break
            total += read
            if (total > MAX_ENTRY_BYTES) return null
            out.write(buffer, 0, read)
        }
        return out.toByteArray()
    }

    /**
     * 与 Dart `XlsxDecoder._parseStyles`（`xlsx.dart:257-275`）同解：
     * 只取 `<cellXfs>` 下 `xf` 的顺序列表，第 i 项即 `s="i"` 的 `numFmtId`；
     * `numFmtId` 缺失按 0（常规数字）记。
     */
    private fun parseNumFormats(bytes: ByteArray): List<Int> {
        val xml = String(bytes, Charsets.UTF_8)
        val cellXfs = CELL_XFS_PATTERN.find(xml)?.groupValues?.get(1) ?: return emptyList()
        return XF_PATTERN.findAll(cellXfs).map { match ->
            NUM_FMT_ID_PATTERN.find(match.value)?.groupValues?.get(1)?.toIntOrNull() ?: 0
        }.toList()
    }

    // ------------------------------------------------------------------
    // sharedStrings.xml
    // ------------------------------------------------------------------

    /** `<si>` 顺序 = 下标；一个 `si` 里有多个 `<t>`（富文本分片）时直接拼接。 */
    private fun parseSharedStrings(bytes: ByteArray): List<String> {
        val xml = String(bytes, Charsets.UTF_8)
        return SHARED_ITEM_PATTERN.findAll(xml).map { match ->
            val body = PHONETIC_PATTERN.replace(match.groupValues[1], "")
            TEXT_PATTERN.findAll(body).joinToString("") { unescape(it.groupValues[1]) }
        }.toList()
    }

    // ------------------------------------------------------------------
    // sheetN.xml
    // ------------------------------------------------------------------

    /**
     * 与 Dart `table_parser` 的 `XlsxDecoder._parseRow` + `Table._normalizeTable`
     * （`xlsx.dart` 行解析、`table.dart:277-303`）同解：
     *
     * - 行号 `r` 缺档时补空行（空行仍占行号，警告里的 `rowNumber` 与 Dart 一致）；
     * - 整行取不到任何值 → 记成空行，而不是塞一串空串；
     * - 列宽按**出现过非空值的最右列**定，所有行补齐到该宽度（尾部空列不算）；
     * - 尾部空行裁掉。
     */
    private fun parseRows(
        sheetXml: String,
        sharedStrings: List<String>,
        numFormats: List<Int>,
    ): List<List<String>> {
        val rows = mutableListOf<MutableList<String?>>()
        for (rowMatch in ROW_PATTERN.findAll(sheetXml)) {
            val rowNumber = ROW_NUMBER_PATTERN.find(rowMatch.groupValues[1])
                ?.groupValues?.get(1)
                ?.toIntOrNull()
            if (rowNumber != null) {
                while (rows.size < rowNumber - 1) rows.add(mutableListOf())
            }
            val row = mutableListOf<String?>()
            var hasValue = false
            for (cellMatch in CELL_PATTERN.findAll(rowMatch.groupValues[2])) {
                val attributes = cellMatch.groupValues[1]
                val body = cellMatch.groupValues[2]
                val columnIndex = CELL_REF_PATTERN.find(attributes)
                    ?.groupValues?.get(1)
                    ?.let(::columnIndex)
                    ?: row.size
                while (row.size < columnIndex) row.add(null)
                val text = cellText(attributes, body, sharedStrings, numFormats)
                if (text != null) hasValue = true
                if (row.size == columnIndex) row.add(text) else row[columnIndex] = text
            }
            rows.add(if (hasValue) row else mutableListOf())
        }

        // 行矩阵归一化，逐字对齐 Dart `table_parser-1.0.1` 的 `Table._normalizeTable`：
        // 尾部空行裁掉、按全表最右非空列补齐每一行（短行也补 `""`）。
        // **这是有意退回 Dart，不是退步**：早期 Kotlin 保留稀疏短行（按行各自列数），
        // 现已退回整表等宽。**后续不要重新实现「按表头宽度」或「保留稀疏行」**。
        val lastNonEmpty = rows.indexOfLast { row -> row.any { it != null } }
        if (lastNonEmpty < 0) return emptyList()
        val kept = rows.subList(0, lastNonEmpty + 1)
        var maxColumns = 0
        for (row in kept) {
            row.forEachIndexed { index, value ->
                if (value != null && index + 1 > maxColumns) maxColumns = index + 1
            }
        }
        if (maxColumns == 0) return emptyList()
        return kept.map { row -> List(maxColumns) { index -> row.getOrNull(index) ?: "" } }
    }

    /**
     * 单元格取值；`null` = 这个格子没有值（Dart 侧 `value == null`，不参与列宽/空行判定）。
     * 类型码见 ECMA-376 18.18.11（`t` 属性）：
     * `s` 共享字符串下标、`inlineStr` 内联富文本、`str` 公式的字符串结果、
     * `b` 布尔、`n`/缺省 数字。
     *
     * 布尔按 Dart `bool.toString()` 写成小写 `true`/`false`（Dart `_cellToString`
     * 走 `value.toString()`，不是 Excel 的 `TRUE`/`FALSE`）。
     *
     * 数字单元格若带样式 `s="i"`，按 `cellXfs[i].numFmtId` 判日期/时间，逐字对齐
     * Dart `XlsxDecoder._parseCell`（`xlsx.dart:409-437`）：
     * - 14-17、22 → ISO 本地日期时间（基准 **1899-12-30**，与 Dart 同；**不支持 1904**，
     *   Dart 也不读 `date1904`，所以工作日历一致）；
     * - 18-21、45-47 → `HH:mm:ss`（基准 `DateTime(0)` = 1970-01-01 本地零点）；
     * - 其余 → 数字文本。
     */
    private fun cellText(
        attributes: String,
        body: String,
        sharedStrings: List<String>,
        numFormats: List<Int>,
    ): String? {
        val type = CELL_TYPE_PATTERN.find(attributes)?.groupValues?.get(1)
        val rawValue = VALUE_PATTERN.find(body)?.groupValues?.get(1)?.let(::unescape)
        return when (type) {
            "s" -> rawValue
                ?.trim()
                ?.toIntOrNull()
                ?.let(sharedStrings::getOrNull)
            "inlineStr" -> TEXT_PATTERN.findAll(body).joinToString("") { unescape(it.groupValues[1]) }
            "b" -> rawValue?.let { if (it.trim() == "1") "true" else "false" }
            "e", "str" -> rawValue
            else -> rawValue?.let { numericCellText(it, attributes, numFormats) }
        }
    }

    /**
     * 数字/日期单元格 → 文本。样式下标越界时按 Dart 的行为整份失败
     * （Dart `_numFormats[int.parse(s)]` 抛 RangeError ⇒ `spreadsheet_xlsx_parse_failed`）。
     */
    private fun numericCellText(raw: String, attributes: String, numFormats: List<Int>): String {
        val styleIndex = CELL_STYLE_PATTERN.find(attributes)?.groupValues?.get(1)?.toIntOrNull()
        if (styleIndex != null) {
            val numFmtId = numFormats.getOrNull(styleIndex)
                ?: fail("missing numFmt for style index: $styleIndex")
            val serial = raw.trim().toDoubleOrNull()
            if (serial != null) {
                when {
                    numFmtId in 14..17 || numFmtId == 22 -> return excelSerialToIso(serial)
                    numFmtId in 18..21 || numFmtId in 45..47 -> return excelSerialToTime(serial)
                }
            }
        }
        return numericText(raw)
    }

    /**
     * Dart `num.parse(raw)` + `_cellToString`（`spreadsheet_import_service.dart:762-767`）：
     * 整数值（含 `1.0`/`1e3` 这类解析后为整数的）输出整数文本，其余按 double 文本。
     * 解析失败时 Dart 整份抛 `spreadsheet_xlsx_parse_failed`（`num.parse` 抛
     * FormatException），这里同样整份失败——**不要**改成「逐行兜底」，
     * 否则多缺陷包的报错优先级会和 Dart 不一致。
     */
    private fun numericText(raw: String): String {
        val value = raw.trim().toDoubleOrNull()
            ?: fail("invalid numeric cell value: $raw")
        return if (value.isFinite() && value == kotlin.math.floor(value) && kotlin.math.abs(value) <= 9_007_199_254_740_992.0) {
            value.toLong().toString()
        } else {
            value.toString()
        }
    }

    /** Dart `DateTime(1899, 12, 30).add(ms).toIso8601String()`（本地时间、毫秒三位）。 */
    private fun excelSerialToIso(serial: Double): String =
        formatIsoLocal(EXCEL_EPOCH.plusMilliseconds((serial * 86_400_000).toLong()))

    /** Dart `DateTime(0).add(ms)` 后取 `HH:mm:ss`（跨日只回绕时间部分）。 */
    private fun excelSerialToTime(serial: Double): String {
        val dateTime = UNIX_EPOCH.plusMilliseconds((serial * 86_400_000).toLong())
        return String.format(Locale.ROOT, "%02d:%02d:%02d", dateTime.hour, dateTime.minute, dateTime.second)
    }

    private fun LocalDateTime.plusMilliseconds(milliseconds: Long): LocalDateTime =
        plusSeconds(milliseconds / 1000).plusNanos((milliseconds % 1000) * 1_000_000)

    private fun formatIsoLocal(dateTime: LocalDateTime): String = buildString {
        append(dateTime.year.toString().padStart(4, '0'))
        append('-')
        append(dateTime.monthValue.toString().padStart(2, '0'))
        append('-')
        append(dateTime.dayOfMonth.toString().padStart(2, '0'))
        append('T')
        append(dateTime.hour.toString().padStart(2, '0'))
        append(':')
        append(dateTime.minute.toString().padStart(2, '0'))
        append(':')
        append(dateTime.second.toString().padStart(2, '0'))
        append('.')
        append((dateTime.nano / 1_000_000).toString().padStart(3, '0'))
    }

    /** 列字母 → 0 基下标（A=0、Z=25、AA=26）。 */
    private fun columnIndex(letters: String): Int {
        var index = 0
        for (char in letters.uppercase()) {
            index = index * 26 + (char - 'A' + 1)
        }
        return index - 1
    }

    /** XML 实体反转义（`&amp;` / `&lt;` / `&#20013;` 这类）。 */
    private fun unescape(text: String): String {
        if (!text.contains('&')) return text
        return ENTITY_PATTERN.replace(text) { match ->
            val body = match.groupValues[1]
            when {
                body == "amp" -> "&"
                body == "lt" -> "<"
                body == "gt" -> ">"
                body == "quot" -> "\""
                body == "apos" -> "'"
                body.startsWith("#x") || body.startsWith("#X") ->
                    body.substring(2).toIntOrNull(16)?.let { String(Character.toChars(it)) } ?: match.value
                body.startsWith("#") ->
                    body.substring(1).toIntOrNull()?.let { String(Character.toChars(it)) } ?: match.value
                else -> match.value
            }
        }
    }

    private fun fail(reason: String): Nothing =
        throw FormatException(ServiceMessage.encode("spreadsheet_xlsx_parse_failed", mapOf("error" to reason)))
}
