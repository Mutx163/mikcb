// Copyright 2026, compose-miuix-ui contributors
// SPDX-License-Identifier: Apache-2.0

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import top.yukonga.miuix.kmp.basic.DropdownEntry
import top.yukonga.miuix.kmp.basic.DropdownItem
import top.yukonga.miuix.kmp.basic.PopupPositionProvider
import top.yukonga.miuix.kmp.basic.TextButton
import top.yukonga.miuix.kmp.window.WindowCascadingListPopup

@Composable
fun WindowCascadingListPopupDemo() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(demoBackground()),
        contentAlignment = Alignment.Center,
    ) {
        var showPopup by remember { mutableStateOf(false) }
        var sortIndex by remember { mutableIntStateOf(0) }
        var viewIndex by remember { mutableIntStateOf(0) }
        var filterIndex by remember { mutableIntStateOf(0) }

        val sortLabels = listOf("Sort by capture date", "Sort by date added")
        val viewLabels = listOf("Group by date", "Compact")
        val filterLabels = listOf("All items", "Camera album")

        val entries = remember(sortIndex, viewIndex, filterIndex) {
            listOf(
                DropdownEntry(
                    items = sortLabels.mapIndexed { idx, label ->
                        DropdownItem(
                            text = label,
                            selected = sortIndex == idx,
                            onClick = { sortIndex = idx },
                        )
                    },
                ),
                DropdownEntry(
                    items = listOf(
                        DropdownItem(
                            text = "View mode",
                            children = viewLabels.mapIndexed { idx, label ->
                                DropdownItem(
                                    text = label,
                                    selected = viewIndex == idx,
                                    onClick = { viewIndex = idx },
                                )
                            },
                        ),
                        DropdownItem(
                            text = "Filter",
                            children = filterLabels.mapIndexed { idx, label ->
                                DropdownItem(
                                    text = label,
                                    selected = filterIndex == idx,
                                    onClick = { filterIndex = idx },
                                )
                            },
                        ),
                    ),
                ),
            )
        }

        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.TopCenter,
        ) {
            Box {
                TextButton(
                    text = "Show WindowCascadingListPopup",
                    onClick = { showPopup = true },
                    modifier = Modifier.padding(top = 16.dp),
                )
                WindowCascadingListPopup(
                    show = showPopup,
                    entries = entries,
                    onDismissRequest = { showPopup = false },
                    alignment = PopupPositionProvider.Align.TopStart,
                )
            }
        }
    }
}
