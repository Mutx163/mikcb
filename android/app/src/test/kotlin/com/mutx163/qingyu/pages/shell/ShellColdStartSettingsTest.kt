package com.mutx163.qingyu.pages.shell

import com.mutx163.qingyu.app.TimetableSettingsModel
import com.mutx163.qingyu.core.MiniJson
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * `localeTagFromRawSettingsJson` 与全量模型读侧的**对拍矩阵**（A1 · 2026-11-03）。
 *
 * A1 把 `attachBaseContext` 的整模型反序列化换成单键读取；语言覆写是行为最敏感的一处
 * （读错 = 界面语言 / 资源语言错，且发生在 `attachBaseContext`，出错最难查）。本测试对
 * 每一份原始 JSON 同时走两条路——① 新的单键函数；② 旧的全量模型路径
 * （`TimetableSettingsModel.fromJson` 的 `appLocaleTag` 读口径，原样复刻）——断言相等。
 *
 * 旧路径的损坏留档（archiveCorrupt）是盘面副作用，不在语言读数里（见函数 KDoc），
 * 复刻时不含它；ShellWiring 那次解析仍在同一次启动里完成留档。
 */
class ShellColdStartSettingsTest {

    /** 旧路径的忠实复刻：`TimetableSettingsModelStore.load()` 去掉留档副作用。 */
    private fun legacyLoad(raw: String?): String {
        val decoded = MiniJson.tryParse(raw)
        val map = if (decoded is Map<*, *>) {
            val out = LinkedHashMap<String, Any?>()
            for ((key, value) in decoded) {
                if (key is String) out[key] = value
            }
            out
        } else {
            emptyMap()
        }
        return TimetableSettingsModel.fromJson(map).appLocaleTag
    }

    /** 两条路必须读出同一个语言标记。 */
    private fun assertSameAsLegacy(raw: String?) {
        assertEquals("raw=$raw", legacyLoad(raw), localeTagFromRawSettingsJson(raw))
    }

    @Test
    fun `空盘与损坏值都跟随系统`() {
        assertSameAsLegacy(null)
        assertSameAsLegacy("")
        assertEquals("", localeTagFromRawSettingsJson(null))
        assertEquals("", localeTagFromRawSettingsJson(""))
        // 不是 JSON 对象：整份不可用，旧路径会留档后回落默认，读数同样是空。
        assertSameAsLegacy("not json at all")
        assertSameAsLegacy("""[1,2,3]""")
        assertEquals("", localeTagFromRawSettingsJson("not json at all"))
    }

    @Test
    fun `显式语言键与规范化口径一致`() {
        assertSameAsLegacy("{}")
        assertSameAsLegacy("""{"appLocaleTag":"en"}""")
        assertSameAsLegacy("""{"appLocaleTag":"zh-CN"}""")
        assertSameAsLegacy("""{"appLocaleTag":"ja-JP"}""")
        // 规范化：`-`→`_` 后小写比对，en_us→en、zh_cn→zh，其余保留。
        assertEquals("en", localeTagFromRawSettingsJson("""{"appLocaleTag":"en-US"}"""))
        assertEquals("zh", localeTagFromRawSettingsJson("""{"appLocaleTag":"zh_CN"}"""))
        assertEquals("ko", localeTagFromRawSettingsJson("""{"appLocaleTag":"ko"}"""))
    }

    @Test
    fun `旧键回落与新键优先`() {
        // 只有旧键 appLocaleMode（Dart 早期版本的存档）：回落生效。
        assertSameAsLegacy("""{"appLocaleMode":"en_US"}""")
        assertEquals("en", localeTagFromRawSettingsJson("""{"appLocaleMode":"en-US"}"""))
        // 两键并存：新键优先，旧键被忽略。
        assertSameAsLegacy("""{"appLocaleTag":"ja","appLocaleMode":"en"}""")
        assertEquals("ja", localeTagFromRawSettingsJson("""{"appLocaleTag":"ja","appLocaleMode":"en"}"""))
        // 旧键常见值 "system"：归空串（跟随系统）。
        assertSameAsLegacy("""{"appLocaleMode":"system"}""")
        assertEquals("", localeTagFromRawSettingsJson("""{"appLocaleMode":"system"}"""))
    }

    @Test
    fun `坏值类型回落默认`() {
        // 语言键不是字符串：等价于缺键，走回落 / 默认。
        assertSameAsLegacy("""{"appLocaleTag":42}""")
        assertSameAsLegacy("""{"appLocaleTag":42,"appLocaleMode":true}""")
        assertSameAsLegacy("""{"appLocaleTag":null}""")
    }
}
