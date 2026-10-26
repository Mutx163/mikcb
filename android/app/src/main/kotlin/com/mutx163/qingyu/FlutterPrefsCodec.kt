package com.mutx163.qingyu

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.io.ObjectStreamClass
import java.util.Base64

/**
 * Flutter SharedPreferences 值编解码器（Compose 迁移 Phase 0 冻结件）。
 *
 * 契约见 docs/plans/2026-10-26-data-contract.md §1——与 shared_preferences_android
 * 插件（LegacySharedPreferencesPlugin.java）逐字节一致：
 * - List<String> = LIST_PREFIX + ObjectOutputStream(ArrayList<String>) + Base64(MIME 76/LF)
 * - double      = DOUBLE_PREFIX + Double.toString
 *
 * 红线：迁移期间盘上格式一个字节都不许变（回退能力依赖它）。
 * 改动本文件必须同时跑 android 侧 FlutterPrefsCodecTest（A→B）
 * 与 dart 侧 legacy_prefs_codec_test（B→A，Flutter 读回）。
 */
object FlutterPrefsCodec {

    /** LegacySharedPreferencesPlugin.java:36，逐字节冻结。 */
    const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"

    /** LegacySharedPreferencesPlugin.java:41（注意末尾句点）。 */
    const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

    /**
     * 按 Android 平台编码 List<String>。
     *
     * android.util.Base64.encodeToString(bytes, 0) 的等价 JVM 实现：
     * MIME encoder、行宽 76、换行 LF（DEFAULT 与 CRLF flag 的区别就在这）。
     * minSdk 26 = java.util.Base64 可用，且 JVM 单测不需要 Robolectric。
     */
    fun encodeStringList(list: List<String>): String {
        val bytes = ByteArrayOutputStream().use { bos ->
            ObjectOutputStream(bos).use { it.writeObject(ArrayList(list)) }
            bos.toByteArray()
        }
        return LIST_PREFIX + Base64.getMimeEncoder(76, byteArrayOf('\n'.code.toByte()))
            .encodeToString(bytes)
    }

    /** 读 Flutter 写出的 List<String>；缺前缀抛 [IllegalArgumentException]。 */
    fun decodeStringList(encoded: String): List<String> {
        require(encoded.startsWith(LIST_PREFIX)) {
            "not a flutter StringList value (missing LIST_PREFIX)"
        }
        val bytes = Base64.getMimeDecoder().decode(encoded.substring(LIST_PREFIX.length))
        RestrictedObjectInputStream(ByteArrayInputStream(bytes)).use { stream ->
            @Suppress("UNCHECKED_CAST")
            return stream.readObject() as List<String>
        }
    }

    fun encodeDouble(value: Double): String = DOUBLE_PREFIX + value.toString()

    /** 读 Flutter 写出的 double；缺前缀抛 [IllegalArgumentException]。 */
    fun decodeDouble(encoded: String): Double {
        require(encoded.startsWith(DOUBLE_PREFIX)) {
            "not a flutter double value (missing DOUBLE_PREFIX)"
        }
        return encoded.substring(DOUBLE_PREFIX.length).toDouble()
    }

    /**
     * 与插件的 StringListObjectInputStream 同口径：只放行 ArrayList/String，
     * 反序列化不可信文件内容时不给 gadget chain 留门。
     */
    private class RestrictedObjectInputStream(input: InputStream) : ObjectInputStream(input) {
        override fun resolveClass(desc: ObjectStreamClass): Class<*> {
            require(desc.name == "java.util.ArrayList" || desc.name == "java.lang.String") {
                "unexpected class in serialized list: ${desc.name}"
            }
            return super.resolveClass(desc)
        }
    }
}
