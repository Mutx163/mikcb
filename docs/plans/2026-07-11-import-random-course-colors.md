# 导入课程随机颜色

## Goal

在所有「导入课程」路径上提供统一的「随机课程颜色」能力：用户开启后，本次导入写入课表的课程从应用预设 9 色板按规则分配颜色；关闭时行为与现网一致。

## Product decisions (locked)

| 决策 | 结论 |
|------|------|
| 同名多条 Course | 按「课程名 + 教师」分组，组内同色 |
| 表格已有颜色列 | 开启随机时全部覆盖为随机色 |
| 合并导入 | 仅新课随机；已匹配旧课保留原色 |
| 开关默认 | **默认开启** |
| 偏好记忆 | 全局记忆，所有导入路径共用 |
| UI 位置 | 各导入子页（ICS / AI / 仓库 / 表格）顶部统一开关条 |
| 色源 | 手动添加课程那套 9 色预设色板 |

## Design

```
各导入子页 UI 开关 → SharedPreferences 偏好
解析 List<Course>
  → 若开启：applyRandomImportCourseColors
  → importParsedCourses（merge 仍保留 existing.color）
```

### Modules

1. `lib/utils/course_color_palette.dart` — 9 色单一来源
2. `lib/utils/import_random_course_colors.dart` — 赋色纯函数
3. 偏好 key：`import_random_course_colors_enabled`，默认 `true`
4. `lib/widgets/import_random_color_toggle.dart` — 统一开关条
5. 所有 `importParsedCourses` 调用前统一 apply

## Implement steps

1. 色板常量；add_course / lan_edit 改引用
2. 赋色纯函数 + 单测
3. 偏好 SharedPreferences，默认 true
4. Toggle widget + l10n
5. 四条子页挂 Toggle；importParsedCourses 前 apply
6. dart format / flutter analyze / 相关 test

## Acceptance Criteria

- [ ] 四条子页均有统一随机颜色开关条
- [ ] 默认开启；关闭后全局记忆
- [ ] 开启后多组 name+teacher 颜色来自 9 色板且多样
- [ ] 同 name+teacher 多条 Course 同色
- [ ] 开启覆盖表格颜色列；关闭保留
- [ ] 合并：旧课不变，新课随机
- [ ] 赋色单测通过
- [ ] dart format + flutter analyze 通过

## Notes

- Trellis 任务目录 `.trellis/tasks/07-11-import-random-course-colors` 当前对编辑器 Write 工具无写权限，计划文档放在本路径。
