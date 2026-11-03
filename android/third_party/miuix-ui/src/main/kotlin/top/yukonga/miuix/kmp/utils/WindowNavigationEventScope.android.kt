// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

package top.yukonga.miuix.kmp.utils

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalView
import androidx.navigationevent.compose.LocalNavigationEventDispatcherOwner
import androidx.navigationevent.findViewTreeNavigationEventDispatcherOwner

/**
 * Rebinds back-event handling to the platform window hosting [content].
 *
 * 本仓 fork 说明：上游是 `commonMain` 的 `expect` + 本文件 `actual` 两份；本地库不是
 * KMP 工程（单源集），这里把两份合并为一份并去掉 `actual` 修饰符，语义与上游一致。
 *
 * On Android a separate platform window (such as a platform `Dialog`) receives system back events
 * through its own dispatcher only. A `LocalNavigationEventDispatcherOwner` explicitly provided in
 * the host composition is inherited across the window boundary and would register back handlers
 * on a dispatcher that never sees this window's events, so this scope re-resolves the owner from
 * the window's view tree; when no view-tree owner exists, the inherited value is kept.
 */
@Composable
fun WindowNavigationEventScope(content: @Composable () -> Unit) {
    // Only this window's own dispatcher (resolved via its view tree) receives system back while
    // the window is focused; an inherited explicit provide must not shadow it.
    val view = LocalView.current
    val owner = remember(view) { view.findViewTreeNavigationEventDispatcherOwner() }
    if (owner != null) {
        CompositionLocalProvider(LocalNavigationEventDispatcherOwner provides owner, content = content)
    } else {
        content()
    }
}
