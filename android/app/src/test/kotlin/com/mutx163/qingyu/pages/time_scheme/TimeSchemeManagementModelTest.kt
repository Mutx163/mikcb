package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.SectionTime
import com.mutx163.qingyu.core.TimeScheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime

/**
 * 时间模板管理页纯逻辑层（[TimeSchemeManagementModel]）的单测。
 *
 * 这一层不碰 Compose、不碰 Context、不查仓库，所以每条判定都能在这里钉死。
 * 测的是 Dart 版行为契约里最容易写错的地方：
 *
 * 1. 课程数口径——副模板 + 跟随主模板 + 地点匹配三种占用都算（漏一种就会出现
 *    「摘要说 0 节课程，删除却告诉你有 3 门在用」）；
 * 2. 菜单顺序与「应用到当前课表」的出现条件；
 * 3. 删除拦截的占用清单顺序固定、当前使用中的模板一律不可删；
 * 4. 使用情况页三段各自成段、空态各自不同；
 * 5. 编辑器影响提示按真实引用关系挑句子，而不是一律吓人。
 */
class TimeSchemeManagementModelTest {

    // ────────────────────────── 基础 ──────────────────────────

    @Test
    fun `空清单时入口提示先建模板`() {
        val model = TimeSchemeManagementModel()
        assertTrue(model.isEmpty)
        assertTrue(model.rows.isEmpty())
        assertEquals("请先创建一套时间模板", model.locationEntrySubtitle)
        assertEquals("时间模板", model.title)
        assertEquals("新建模板", model.newSchemeTooltip)
    }

    @Test
    fun `有模板时入口副标题是模板入口名`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("a", "夏季")))
        assertFalse(model.isEmpty)
        assertEquals("时间模板", model.locationEntrySubtitle)
    }

    @Test
    fun `行的摘要按三种课程占用一起计数`() {
        val usage = TimeSchemeUsageIndex(
            directProfiles = mapOf("s1" to listOf(profile("p1", "三年级"), profile("p2", "四年级"))),
            followMainCourses = mapOf("s1" to listOf(course("高数"))),
            overrideCourses = mapOf("s1" to listOf(course("物理"), course("化学"))),
            locationCourses = mapOf("s1" to listOf(course("英语"))),
        )
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")), usage = usage)
        val row = model.rows.single()

        assertEquals("夏季", row.title)
        assertEquals(3, row.sectionCount)
        assertEquals(2, row.profileCount)
        // 1 跟随主模板 + 2 副模板 + 1 地点匹配
        assertEquals(4, row.courseCount)
        assertEquals(2, row.overrideCourseCount)
        assertEquals("3 节 · 2 个课表 · 4 节课程 · 2 节副时间模板", row.summary)
    }

    @Test
    fun `副标题在当前模板与普通模板之间切换`() {
        val schemes = listOf(scheme("s1", "夏季"), scheme("s2", "冬季"))
        val active = TimeSchemeManagementModel(schemes = schemes, activeSchemeId = "s1")

        val activeRow = active.row("s1")!!
        assertTrue(activeRow.isActive)
        assertEquals("正在使用", activeRow.statusLabel)
        assertEquals("正在使用", activeRow.subtitle)

        val otherRow = active.row("s2")!!
        assertFalse(otherRow.isActive)
        assertEquals("", otherRow.statusLabel)
        assertEquals("08:00 起", otherRow.subtitle)
    }

    @Test
    fun `一节都没有的模板不显示起始时间`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "空模板", sections = emptyList())))
        val row = model.rows.single()
        assertNull(row.startsAt)
        assertEquals("", row.subtitle)
        assertEquals("0 节 · 0 个课表 · 0 节课程 · 0 节副时间模板", row.summary)
    }

    @Test
    fun `未知模板的取值一律返回空而不是抛异常`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        assertNull(model.row("nope"))
        assertTrue(model.menu("nope").isEmpty())
        assertNull(model.renameSheet("nope"))
        assertNull(model.deleteCheck("nope"))
        assertNull(model.usageView("nope"))
        assertNull(model.shareSheet("nope"))
        assertNull(model.editor("nope"))
    }

    // ────────────────────────── 菜单 ──────────────────────────

    @Test
    fun `非当前模板的菜单含应用到当前课表且顺序与 Dart 逐项一致`() {
        val model = TimeSchemeManagementModel(
            schemes = listOf(scheme("s1", "夏季")),
            usage = TimeSchemeUsageIndex(directProfiles = mapOf("s1" to listOf(profile("p1", "三年级")))),
            activeSchemeId = "other",
        )
        val menu = model.menu("s1")
        assertEquals(
            listOf(
                TimeSchemeAction.VIEW_USAGE,
                TimeSchemeAction.APPLY_TO_CURRENT,
                TimeSchemeAction.EDIT_SECTIONS,
                TimeSchemeAction.RENAME,
                TimeSchemeAction.DUPLICATE,
                TimeSchemeAction.SHARE,
                TimeSchemeAction.DELETE,
            ),
            menu.map { it.action },
        )
        assertEquals("查看使用情况", menu.first().label)
        assertEquals("应用到当前课表", menu[1].label)
        assertEquals("删除", menu.last().label)
    }

    @Test
    fun `没人用时不摆查看使用情况`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        assertTrue(model.isUnused("s1"))
        assertEquals(
            listOf(
                TimeSchemeAction.APPLY_TO_CURRENT,
                TimeSchemeAction.EDIT_SECTIONS,
                TimeSchemeAction.RENAME,
                TimeSchemeAction.DUPLICATE,
                TimeSchemeAction.SHARE,
                TimeSchemeAction.DELETE,
            ),
            model.menu("s1").map { it.action },
        )
    }

    @Test
    fun `当前使用中的模板不再提供应用到当前课表`() {
        val model = TimeSchemeManagementModel(
            schemes = listOf(scheme("s1", "夏季")),
            usage = TimeSchemeUsageIndex(followMainCourses = mapOf("s1" to listOf(course("高数")))),
            activeSchemeId = "s1",
        )
        val actions = model.menu("s1").map { it.action }
        assertFalse(actions.contains(TimeSchemeAction.APPLY_TO_CURRENT))
        assertFalse(model.isUnused("s1"))
        assertEquals(
            listOf(
                TimeSchemeAction.VIEW_USAGE,
                TimeSchemeAction.EDIT_SECTIONS,
                TimeSchemeAction.RENAME,
                TimeSchemeAction.DUPLICATE,
                TimeSchemeAction.SHARE,
                TimeSchemeAction.DELETE,
            ),
            actions,
        )
    }

    // ────────────────────────── 新建 / 重命名 / 复制 ──────────────────────────

    @Test
    fun `新建与重命名表单的取值`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        val create = model.createSheet
        assertEquals("新建时间模板", create.title)
        assertEquals("模板名称", create.nameLabel)
        assertEquals("例如：本校夏季作息", create.nameHint)
        assertEquals("", create.initialName)
        assertEquals("创建", create.confirmLabel)
        assertEquals("请填写名称", create.nameError)

        val rename = model.renameSheet("s1")!!
        assertEquals("重命名时间模板", rename.title)
        assertEquals("夏季", rename.initialName)
        assertEquals("保存", rename.confirmLabel)
    }

    @Test
    fun `名称校验只拦全空白`() {
        val model = TimeSchemeManagementModel()
        assertEquals("请填写名称", model.validateName(""))
        assertEquals("请填写名称", model.validateName("   ").orEmpty())
        assertEquals("请填写名称", model.validateName("\n\t").orEmpty())
        assertNull(model.validateName("夏季"))
        assertNull(model.validateName("  夏季  "))
    }

    @Test
    fun `复制名字用 Dart 的副本后缀且重名才退化成数字`() {
        val model = TimeSchemeManagementModel(
            schemes = listOf(scheme("s1", "夏季"), scheme("s2", "夏季 副本"), scheme("s3", "夏季 副本 2")),
        )
        // Dart 的默认复制名是 '<原名> 副本'，重名才加数字（Dart 侧不去重，
        // 本侧保留去重是为了列表里能分清两套同名模板）。
        assertEquals("夏季 副本 3", model.copyName("夏季"))
        assertEquals("冬季 副本", model.copyName("冬季"))
        assertEquals("已复制时间模板", model.copiedMessage)
    }

    @Test
    fun `消息类文案带名字`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        assertEquals("已重命名为 夏季", model.renamedMessage("夏季"))
        assertEquals("已应用时间模板：夏季", model.appliedMessage("s1"))
        assertEquals("已应用时间模板：", model.appliedMessage("nope"))
        assertEquals("已删除时间模板：夏季", model.deletedMessage("夏季"))
        assertEquals("发送失败：蓝牙未开启", model.sendFailedMessage("蓝牙未开启"))
        assertTrue(model.qrResourceLimitMessage.startsWith("接收数据超过二维码传输资源上限"))
    }

    // ────────────────────────── 删除拦截 ──────────────────────────

    @Test
    fun `没人使用的模板可以删除`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        val check = model.deleteCheck("s1")!!
        assertTrue(check.canDelete)
        assertTrue(check.blockers.isEmpty())
        assertEquals("", check.inUseNote)
        assertEquals("", check.blockerIntro)
        assertEquals("确定删除作息 夏季？删除后无法恢复", check.message)
        assertEquals("删除", check.confirmLabel)
        // 两个删除弹层的取消按钮都是「取消」（Dart :683/:793）；「关闭」只属于使用情况弹层。
        assertEquals("取消", check.cancelLabel)
    }

    @Test
    fun `当前课表正在使用的模板不可删并顶一句占用说明`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")), activeSchemeId = "s1")
        val check = model.deleteCheck("s1")!!
        assertFalse(check.canDelete)
        assertEquals("当前课表正在使用这套模板", check.inUseNote)
        // 没有任何具体引用方时，不摆「还有下面的地方在用」这句抬头。
        assertEquals("", check.blockerIntro)
    }

    @Test
    fun `占用清单顺序固定且逐条列全`() {
        val usage = TimeSchemeUsageIndex(
            directProfiles = mapOf("s1" to listOf(profile("p1", "三年级"), profile("p2", "四年级"))),
            overrideCourses = mapOf("s1" to listOf(course("物理"))),
            locationCourses = mapOf("s1" to listOf(course("英语"), course("化学"))),
            locationGroups = mapOf("s1" to listOf(TimeSchemeNameRef("g1", "教学楼 A"))),
            dateRules = mapOf("s1" to listOf(TimeSchemeNameRef("d1", "期中周"))),
        )
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")), usage = usage)

        assertEquals(
            listOf(
                "作为主时间模板的课表：三年级、四年级",
                "把它设为副时间模板的课程：1 门",
                "按上课地点自动匹配到它的课程：2 门",
                "绑定了它的地点组：教学楼 A",
                "绑定了它的日期作息规则：期中周",
            ),
            model.blockers("s1"),
        )

        val check = model.deleteCheck("s1")!!
        assertFalse(check.canDelete)
        assertEquals("还有下面的地方在用这套模板，解除后才能删除：", check.blockerIntro)
        // 被占用时唯一可点的按钮是「取消」，不出现「删除」以外的第二个危险动作。
        assertEquals("取消", check.cancelLabel)
    }

    // ────────────────────────── 使用情况 ──────────────────────────

    @Test
    fun `使用情况三段各自成段且空态互不相同`() {
        val usage = TimeSchemeUsageIndex(
            directProfiles = mapOf("s1" to listOf(profile("p1", "三年级"))),
            overrideCourses = mapOf("s1" to listOf(course("物理"))),
            locationGroups = mapOf("s1" to listOf(TimeSchemeNameRef("g1", "教学楼 A"))),
        )
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")), usage = usage)
        val view = model.usageView("s1")!!

        assertEquals("夏季 的使用情况", view.title)
        assertEquals("课表", view.profileCountLabel)
        assertEquals("1 个", view.profileCountValue)
        assertEquals("课程", view.courseCountLabel)
        // 副模板 1 + 地点匹配 0（此例没有 locationCourses）+ 跟随 0
        assertEquals("1 节", view.courseCountValue)
        assertEquals("1 节", view.overrideCountValue)

        assertEquals("三年级", view.directProfiles.single().title)
        assertEquals("", view.directProfiles.single().summary)
        assertTrue(view.followLines.isEmpty())
        assertEquals("当前没有课程通过课表主时间模板间接使用它", view.followEmpty)

        val overrideLine = view.overrideLines.single()
        assertEquals("三年级 · 物理 周 一 第 1 至 2 节 副时间模板", overrideLine.title)
        assertEquals("周 一 1～2 节", overrideLine.summary)

        assertEquals("地点作息匹配", view.locationTitle)
        assertEquals("需先改绑到别的模板才能删除", view.locationSubtitle)
        assertEquals("教学楼 A", view.locationLines.single().title)

        // 只有一门课时不摆「… 等 N 节课程」汇总。
        assertEquals("", view.bottomSummary)
        assertFalse(view.canDelete)
    }

    @Test
    fun `课程多于一条时给出等 N 节汇总`() {
        val usage = TimeSchemeUsageIndex(
            followMainCourses = mapOf("s1" to listOf(course("高数"))),
            overrideCourses = mapOf("s1" to listOf(course("物理"), course("化学"))),
        )
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")), usage = usage)
        val view = model.usageView("s1")!!
        assertEquals("高数 等 3 节课程", view.bottomSummary)
        assertEquals("3 节", view.courseCountValue)
    }

    @Test
    fun `无人使用的模板在使用情况页可删`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        val view = model.usageView("s1")!!
        assertTrue(view.canDelete)
        assertTrue(view.blockers.isEmpty())
        assertEquals("0 个", view.profileCountValue)
        assertEquals("0 节", view.courseCountValue)
        assertEquals("当前没有课表直接使用这套模板", view.directProfilesEmpty)
        assertEquals("当前没有课程把它作为副时间模板", view.overrideEmpty)
    }

    // ────────────────────────── 两个入口行的行尾 ──────────────────────────

    @Test
    fun `地点入口行尾等于分组条数且零条时不显示`() {
        assertEquals(null, TimeSchemeManagementModel().locationEntryDetails)
        assertEquals(
            "3",
            TimeSchemeManagementModel(locationGroupCount = 3).locationEntryDetails,
        )
    }

    @Test
    fun `日期规则行尾在今天是区间内时换成今天在区间内`() {
        assertEquals(null, TimeSchemeManagementModel().dateRuleEntryDetails)
        assertEquals("2", TimeSchemeManagementModel(dateRuleCount = 2).dateRuleEntryDetails)
        assertEquals(
            "今天在区间内",
            TimeSchemeManagementModel(dateRuleCount = 2, hasActiveDateRule = true).dateRuleEntryDetails,
        )
        // 没有规则时「今天在区间内」不该凭空出现（hasActiveDateRule 与条数矛盾时的兜底）。
        assertEquals(null, TimeSchemeManagementModel(hasActiveDateRule = true).dateRuleEntryDetails)
    }

    // ────────────────────────── 行上的首节与「没有节次」 ──────────────────────────

    @Test
    fun `首节起止与没有节次两种渲染分支`() {
        val normal = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        assertEquals("08:00-08:45", normal.row("s1")!!.firstSectionText)
        assertFalse(normal.row("s1")!!.hasNoSections)

        val empty = TimeSchemeManagementModel(schemes = listOf(scheme("s2", "空模板", emptyList())))
        assertEquals(null, empty.row("s2")!!.firstSectionText)
        assertTrue(empty.row("s2")!!.hasNoSections)
    }

    // ────────────────────────── 使用情况：日期规则可选段 ──────────────────────────

    @Test
    fun `使用情况页带日期规则可选段`() {
        val usage = TimeSchemeUsageIndex(dateRules = mapOf("s1" to listOf(TimeSchemeNameRef("d1", "期中周"))))
        val view = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")), usage = usage).usageView("s1")!!
        assertEquals("日期作息规则", view.dateRuleTitle)
        assertEquals("需先改绑到别的模板才能删除", view.dateRuleSubtitle)
        assertEquals(listOf("期中周"), view.dateRuleLines.map { it.title })

        // 没有日期规则时是空段（渲染层据此不画这一段）。
        val emptyView = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季"))).usageView("s1")!!
        assertTrue(emptyView.dateRuleLines.isEmpty())
    }

    // ────────────────────────── 分享 ──────────────────────────

    @Test
    fun `分享面板两条路与随带说明`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        val sheet = model.shareSheet("s1")!!
        assertEquals("s1", sheet.schemeId)
        assertEquals("夏季", sheet.schemeName)
        assertEquals("分享时间模板", sheet.title)
        assertEquals("二维码分享", sheet.viaQrLabel)
        assertEquals("系统分享文件", sheet.viaSystemLabel)
        assertEquals("取消", sheet.cancelLabel)
        assertEquals("轻屿课表时间模板 夏季，导入后即可使用", sheet.shareText)
        assertEquals("轻屿课表 · 时间模板", sheet.shareSubject)
    }

    // ────────────────────────── 编辑器 ──────────────────────────

    @Test
    fun `影响提示按真实引用关系挑句子`() {
        val schemes = listOf(scheme("s1", "夏季"))

        // 既被当前课表用、又有课程当副模板 → 最长那句
        val both = TimeSchemeManagementModel(
            schemes = schemes,
            usage = TimeSchemeUsageIndex(overrideCourses = mapOf("s1" to listOf(course("物理")))),
            activeSchemeId = "s1",
        )
        assertEquals(
            "当前课表和部分课程正在使用这套时间模板，保存后会同步更新所有相关课表和课程",
            both.editor("s1")!!.impactHint,
        )

        // 只被当前课表用
        val activeOnly = TimeSchemeManagementModel(schemes = schemes, activeSchemeId = "s1")
        assertEquals(
            "当前课表正在使用这套时间模板，保存后会同步更新所有使用它的课表",
            activeOnly.editor("s1")!!.impactHint,
        )

        // 只有课程把它当副模板
        val overrideOnly = TimeSchemeManagementModel(
            schemes = schemes,
            usage = TimeSchemeUsageIndex(overrideCourses = mapOf("s1" to listOf(course("物理")))),
        )
        assertEquals(
            "有课程正在把这套模板作为副时间模板使用，保存后会同步更新所有引用课程",
            overrideOnly.editor("s1")!!.impactHint,
        )

        // 没人在用 → 不吓人
        assertEquals("", TimeSchemeManagementModel(schemes = schemes).editor("s1")!!.impactHint)
    }

    @Test
    fun `编辑器节次行按序号从 1 开始`() {
        val model = TimeSchemeManagementModel(schemes = listOf(scheme("s1", "夏季")))
        val sheet = model.editor("s1")!!
        assertEquals("编辑时间模板", sheet.title)
        assertEquals("夏季", sheet.name)
        assertEquals("节次时间", sheet.sectionTimesTitle)
        assertEquals("保存", sheet.saveLabel)
        assertEquals("结束时间必须晚于开始时间", sheet.crossDayError)
        assertEquals(3, sheet.rows.size)

        val first = sheet.rows.first()
        assertEquals(0, first.index)
        assertEquals("第 1 节", first.label)
        assertEquals("08:00", first.startTime)
        assertEquals("08:45", first.endTime)
        assertEquals("08:00-08:45", first.rangeText)

        val third = sheet.rows.last()
        assertEquals("第 3 节", third.label)
        assertEquals("10:00-10:45", third.rangeText)
    }

    // ────────────────────────── 测试夹具 ──────────────────────────

    private fun scheme(
        id: String,
        name: String,
        sections: List<SectionTime> = DEFAULT_SECTIONS,
    ): TimeScheme {
        val now = LocalDateTime.of(2026, 10, 26, 8, 0)
        return TimeScheme(id = id, name = name, sections = sections, createdAt = now, updatedAt = now)
    }

    private fun profile(id: String, name: String) = TimeSchemeProfileRef(id = id, name = name)

    private fun course(
        name: String,
        dayOfWeek: Int = 1,
        startSection: Int = 1,
        endSection: Int = 2,
    ) = TimeSchemeCourseRef(
        profileId = "p1",
        profileName = "三年级",
        courseId = "c-$name",
        courseName = name,
        dayOfWeek = dayOfWeek,
        startSection = startSection,
        endSection = endSection,
    )

    private companion object {
        val DEFAULT_SECTIONS = listOf(
            SectionTime("08:00", "08:45"),
            SectionTime("08:55", "09:40"),
            SectionTime("10:00", "10:45"),
        )
    }
}
