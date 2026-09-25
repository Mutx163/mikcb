package com.mutx163.qingyu

import android.content.Context

/** Break-milestone labels the Flutter side may hand over as stable keys. */
internal enum class LiveMilestoneLabel {
    RecentEnd,
    NextStart,
}

/**
 * Resolves a live-activity break-milestone label to the built-in label it
 * stands for.
 *
 * The identifier set mirrors the `milestone*LabelKey` constants in
 * `lib/domain/live_activity_logic.dart`. Anything else returns null — including
 * the already-localized text the offline scheduler produces — so callers keep
 * such labels verbatim.
 */
internal fun liveMilestoneLabel(label: String?): LiveMilestoneLabel? {
    return when (label?.trim()) {
        "milestone_recent_end" -> LiveMilestoneLabel.RecentEnd
        "milestone_next_start" -> LiveMilestoneLabel.NextStart
        else -> null
    }
}

/**
 * Turns a break-milestone label into text the island can display.
 *
 * Both producers of these labels have to end up in the same language: Flutter
 * sends keys, the offline scheduler sends resource strings. Translating here —
 * where the labels are taken off the intent — makes the two paths agree with
 * each other and with every other native string, instead of with whichever
 * language the starting path happened to hard-code.
 */
internal fun localizeLiveMilestoneLabel(context: Context, label: String): String {
    val resId = when (liveMilestoneLabel(label)) {
        LiveMilestoneLabel.RecentEnd -> R.string.milestone_recent_end
        LiveMilestoneLabel.NextStart -> R.string.milestone_next_start
        null -> return label
    }
    return context.getString(resId)
}
