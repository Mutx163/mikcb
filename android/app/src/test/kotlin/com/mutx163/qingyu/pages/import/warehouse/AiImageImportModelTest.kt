package com.mutx163.qingyu.pages.import.warehouse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * AI 识图导入工作流模型与 JSON 解析单元测试。
 */
class AiImageImportModelTest {

    @Test
    fun `splitWorkflowArrowTitle 能够正确按 ASCII 与 Unicode 箭头拆分三步指引`() {
        val asciiSteps = splitWorkflowArrowTitle("截图课表 -> 发送给AI -> 粘贴JSON")
        assertEquals(listOf("截图课表", "发送给AI", "粘贴JSON"), asciiSteps)

        val unicodeSteps = splitWorkflowArrowTitle("复制提示词 → 豆包专家模式识别 → 复制JSON返回导入")
        assertEquals(listOf("复制提示词", "豆包专家模式识别", "复制JSON返回导入"), unicodeSteps)

        val emptySteps = splitWorkflowArrowTitle("")
        assertTrue(emptySteps.isEmpty())
    }

    @Test
    fun `parseAiImageImportJson 解析完整 JSON 且正确计算最大节次`() {
        val json = """
        {
          "schema": "mikcb_ai_import_v1",
          "courses": [
            {
              "name": "高等数学",
              "teacher": "张教授",
              "location": "理科楼101",
              "dayOfWeek": 1,
              "startSection": 1,
              "endSection": 2,
              "customWeeks": [1, 2, 3, 4]
            },
            {
              "name": "大学物理",
              "teacher": "李老师",
              "location": "物理实验中心",
              "dayOfWeek": 3,
              "startSection": 3,
              "endSection": 5,
              "customWeeks": [1, 3, 5]
            }
          ],
          "warnings": ["检测到单双周重叠"]
        }
        """.trimIndent()

        val result = parseAiImageImportJson(json)
        assertTrue(result.isValid)
        assertEquals(2, result.courses.size)
        assertEquals("高等数学", result.courses[0].name)
        assertEquals("大学物理", result.courses[1].name)
        assertEquals(5, result.requiredSectionCount)
        assertEquals(listOf("检测到单双周重叠"), result.warnings)
    }

    @Test
    fun `parseAiImageImportJson 支持兼容并剥离 markdown json 代码块围栏`() {
        val markdownWrapped = """
        ```json
        {
          "schema": "mikcb_ai_import_v1",
          "courses": [
            {
              "name": "数据结构",
              "dayOfWeek": 2,
              "startSection": 1,
              "endSection": 4
            }
          ]
        }
        ```
        """.trimIndent()

        val result = parseAiImageImportJson(markdownWrapped)
        assertTrue(result.isValid)
        assertEquals(1, result.courses.size)
        assertEquals("数据结构", result.courses[0].name)
        assertEquals(4, result.requiredSectionCount)
    }

    @Test
    fun `parseAiImageImportJson 异常输入兜底处理`() {
        val emptyResult = parseAiImageImportJson("   ")
        assertFalse(emptyResult.isValid)
        assertEquals(listOf(WarehouseStrings.aiPasteJsonFirst.zh), emptyResult.warnings)

        val invalidJsonResult = parseAiImageImportJson("{ malformed json ...")
        assertFalse(invalidJsonResult.isValid)
        assertEquals(listOf(WarehouseStrings.aiParseFailedIncompleteJson.zh), invalidJsonResult.warnings)
    }
}
