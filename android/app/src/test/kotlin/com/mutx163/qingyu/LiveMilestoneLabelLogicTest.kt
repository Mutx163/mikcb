package com.mutx163.qingyu

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LiveMilestoneLabelLogicTest {
    @Test
    fun flutterKeysResolveToLabels() {
        // Flutter 以前直接送「最近下课／下节上课」两份中文，导致 App 启动的
        // 超级岛和离线调度的超级岛语言不一致；现在送的是稳定键。
        assertEquals(
            LiveMilestoneLabel.RecentEnd,
            liveMilestoneLabel("milestone_recent_end"),
        )
        assertEquals(
            LiveMilestoneLabel.NextStart,
            liveMilestoneLabel("milestone_next_start"),
        )
    }

    @Test
    fun alreadyLocalizedLabelsPassThroughUnchanged() {
        // 离线调度器送来的已经是资源文案，不能被当成键再翻一次。
        assertNull(liveMilestoneLabel("最近下课"))
        assertNull(liveMilestoneLabel("Recent break"))
        assertNull(liveMilestoneLabel("下节上课"))
        assertNull(liveMilestoneLabel("Next class"))
    }

    @Test
    fun unknownOrBlankLabelsHaveNoLabel() {
        assertNull(liveMilestoneLabel(null))
        assertNull(liveMilestoneLabel(""))
        assertNull(liveMilestoneLabel("   "))
        assertNull(liveMilestoneLabel("自定义节点"))
        assertNull(liveMilestoneLabel("milestone_unknown"))
    }
}
