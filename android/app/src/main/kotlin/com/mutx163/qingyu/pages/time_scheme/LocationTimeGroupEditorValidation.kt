package com.mutx163.qingyu.pages.time_scheme

import com.mutx163.qingyu.core.LocationKeyword

/**
 * 编辑页保存前校验（照 Dart `_LocationTimeGroupEditorScreenState._save`，:1032-1072 的顺序）。
 *
 * 返回**第一条**错误文案；全部通过返回 null。顺序与 Dart 严格一致：
 * 1. 组名为空 → `locationTimeMatchNameRequired`
 * 2. 未绑定时间模板 → `locationTimeMatchNeedTimeScheme`
 * 3. 一个关键词都没有 → `locationTimeMatchKeywordRequired`
 * 4. 某关键词已被别的组占用 → `locationTimeMatchKeywordUsedByGroup`
 *
 * 关键词是否「过短」只是提示、不拦保存（Dart 同口径），所以不在拦截链里。
 * 纯函数、可测。
 */
object LocationTimeGroupEditorValidation {

    fun saveError(
        model: LocationTimeMatchModel,
        name: String,
        timeSchemeId: String,
        keywords: List<LocationKeyword>,
        editingGroupId: String?,
    ): String? {
        model.validateName(name)?.let { return it }
        if (timeSchemeId.trim().isEmpty()) return LocationTimeMatchStrings.needTimeScheme.zh
        if (keywords.isEmpty()) return LocationTimeMatchStrings.keywordRequired.zh
        for (keyword in keywords) {
            model.keywordOwnerHint(keyword.pattern, editingGroupId)?.let { return it }
        }
        return null
    }
}
