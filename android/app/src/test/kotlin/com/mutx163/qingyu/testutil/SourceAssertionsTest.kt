package com.mutx163.qingyu.testutil

import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * [SourceAssertions] 的自测：这套 API 自己必须**能红**。
 *
 * 2026-11-12 恒真断言审计的教训——「断言永远通过，而且看起来在测」。
 * 这里钉的是三件：空读拒绝通过、空白与空串可区分、失败消息带 needle 与实际内容。
 */
class SourceAssertionsTest {

    @Test
    fun `命中时直接通过`() {
        assertSourceContains("val a = 1", "val a", "A.kt")
        assertSourceLacks("val a = 1", "val b", "A.kt")
    }

    @Test
    fun `空串时 contains 失败且消息带 needle 与零字符`() {
        val error = assertThrows(AssertionError::class.java) {
            assertSourceContains("", "val a", "A.kt")
        }
        val message = error.message.orEmpty()
        assertTrue(message, message.contains("val a"))
        assertTrue(message, message.contains("空（0 字符）"))
        assertTrue(message, message.contains("[A.kt]"))
    }

    @Test
    fun `只有空白时消息说明是几个空白字符`() {
        val error = assertThrows(AssertionError::class.java) {
            assertSourceContains("   \n ", "x", "A.kt")
        }
        val message = error.message.orEmpty()
        assertTrue(message, message.contains("空白字符"))
        assertTrue(message, !message.contains("空（0 字符）"))
    }

    @Test
    fun `否定式在空串上拒绝通过`() {
        assertThrows(AssertionError::class.java) {
            assertSourceLacks("", "旧写法", "A.kt")
        }
    }

    @Test
    fun `否定式命中时给出实际前 80 字符`() {
        val error = assertThrows(AssertionError::class.java) {
            assertSourceLacks("val old = 1", "old", "A.kt")
        }
        val message = error.message.orEmpty()
        assertTrue(message, message.contains("val old = 1"))
    }
}
