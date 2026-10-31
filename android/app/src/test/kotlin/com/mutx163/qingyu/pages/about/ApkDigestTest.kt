package com.mutx163.qingyu.pages.about

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.ByteArrayInputStream

/**
 * 安装包摘要判据（`ApkDigest.kt`）的行为测试。
 *
 * 期望值不是从实现里抄的：SHA-256 的期望向量用固定字符串的**公开测试向量**，
 * 判据期望值按 Dart 侧三个错误码的语义推出来：
 * `update_download_hash_mismatch`（不一致就拒装）、
 * `update_sha256_unverified_install_refused`（声明了却算不出也拒装）、
 * 没声明摘要则放行（Dart 只校验「有据可查」的那部分）。
 */
class ApkDigestTest {

    @Test
    fun `sha256 of known bytes matches the published vector`() {
        // "abc" 的 SHA-256 是公开标准向量，与实现无关。
        assertEquals(
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            sha256Hex("abc".toByteArray(Charsets.UTF_8)),
        )
        // 空输入同样是标准向量（下载 0 字节时必须落到 MISMATCH，不能算成功）。
        assertEquals(
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            sha256Hex(ByteArray(0)),
        )
    }

    @Test
    fun `stream and bytes paths agree`() {
        val payload = "qingyu-update-apk".toByteArray(Charsets.UTF_8)
        assertEquals(
            sha256Hex(payload),
            sha256Hex(ByteArrayInputStream(payload)),
        )
    }

    @Test
    fun `expected digest normalization`() {
        val hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        assertEquals(hex, normalizeExpectedSha256(hex.uppercase()))
        assertEquals(hex, normalizeExpectedSha256("sha256:$hex"))
        assertEquals(hex, normalizeExpectedSha256("  sha256:$hex  "))
        // 不是 64 位十六进制 = 没声明（不能当成「随便放行」，见下一条用例的语义说明）
        assertNull(normalizeExpectedSha256(""))
        assertNull(normalizeExpectedSha256(null))
        assertNull(normalizeExpectedSha256("hello"))
        assertNull(normalizeExpectedSha256(hex.dropLast(1)))
        assertNull(normalizeExpectedSha256("z".repeat(64)))
    }

    @Test
    fun `no expected digest means not declared`() {
        assertEquals(ApkDigestVerdict.NOT_DECLARED, apkDigestVerdict(null, null))
        assertEquals(ApkDigestVerdict.NOT_DECLARED, apkDigestVerdict("", "deadbeef"))
        // 声明里是垃圾值 ⇒ 视作没声明（GitHub 没给 digest 时本字段为 null）
        assertEquals(ApkDigestVerdict.NOT_DECLARED, apkDigestVerdict("not-a-hash", null))
    }

    @Test
    fun `matching digest allows install`() {
        val hex = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        assertEquals(ApkDigestVerdict.MATCH, apkDigestVerdict(hex, hex))
        assertEquals(ApkDigestVerdict.MATCH, apkDigestVerdict("sha256:${hex.uppercase()}", hex))
    }

    @Test
    fun `mismatch refuses install`() {
        val expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        val other = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        assertEquals(ApkDigestVerdict.MISMATCH, apkDigestVerdict(expected, other))
    }

    @Test
    fun `declared but uncomputable refuses install instead of passing`() {
        val expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        // 这一条是整套判据的核心：声明了摘要却读不到文件时**不能**当作「没要求」。
        assertEquals(ApkDigestVerdict.UNVERIFIABLE, apkDigestVerdict(expected, null))
        assertEquals(ApkDigestVerdict.UNVERIFIABLE, apkDigestVerdict(expected, "  "))
    }
}
