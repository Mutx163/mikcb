part of '../timetable_provider.dart';

// 地点分组的批量套用实现（从 timetable_provider.dart 拆出以压行数棘轮；
// 同库 part 可访私有成员，方法体逐字未动）。
//
// 日期规则那条 `_applyDueScheduleDateRulesDetailed` 没有搬进来：它在本分支已移入
// `schedule_date_rule_repository.dart` 并补上「落盘失败整体回滚」，provider 侧只留
// 转发壳。两处都留会撞成同库重复定义，故这里只保留地点族。
extension _ScheduleRuleApply on TimetableProvider {
    Future<LocationTimeApplyStats>
    _applyLocationTimeRulesToActiveProfileImpl() async {
      await initialize();
      const debugTag = 'LocationTimeApply';
      var unlockedCount = 0;
      var matchedCount = 0;
      var updatedCount = 0;
      var alreadySameClockCount = 0;
      var sectionOverflowCount = 0;
      final sectionOverflowCourseNames = <String>[];
      var noMatchCount = 0;
      var matchMissingSchemeCount = 0;
      var autoReleasedCount = 0;
      var clockRewriteCount = 0;
      final changeSamples = <String>[];

      void audit(String message, {Map<String, Object?> extras = const {}}) {
        appDebugLog(debugTag, message);
        unawaited(
          AppLogService.instance.info(
            'location_time_apply',
            message,
            extras: extras,
          ),
        );
      }

      final activeScheme = activeTimeScheme;
      audit(
        '===== 开始应用到当前课表 ===== '
        'profile=${activeProfile?.name ?? "null"}(${_activeProfileId ?? "-"}) '
        'courses=${_courses.length} '
        'locationGroups=${_locationTimeGroups.length} '
        'activeScheme=${activeScheme?.name ?? "null"}(${activeScheme?.id ?? "-"}) '
        'activeSections=${activeScheme?.sections.length ?? _settings.sections.length} '
        'manualOverridesBefore=${_courses.where((c) => c.timeSchemeIdOverride != null).length}',
        extras: {
          'profileId': _activeProfileId,
          'courseCount': _courses.length,
          'groupCount': _locationTimeGroups.length,
          'activeSchemeId': activeScheme?.id,
          'manualOverridesBefore': _courses
              .where((course) => course.timeSchemeIdOverride != null)
              .length,
        },
      );
      for (final group in _locationTimeGroups) {
        final scheme = _getTimeSchemeById(group.timeSchemeId);
        final keywords = group.keywords
            .map((keyword) => '${keyword.pattern}(${keyword.mode.name})')
            .join('|');
        audit(
          '地点组: id=${group.id} name=${group.name} enabled=${group.enabled} '
          'priority=${group.priority} scheme=${scheme?.name ?? "MISSING"}(${group.timeSchemeId}) '
          'schemeSections=${scheme?.sections.length ?? 0} keywords=[$keywords]',
          extras: {
            'groupId': group.id,
            'groupName': group.name,
            'enabled': group.enabled,
            'schemeId': group.timeSchemeId,
            'schemeName': scheme?.name,
            'schemeSections': scheme?.sections.length ?? 0,
            'keywords': keywords,
          },
        );
        if (scheme != null && scheme.sections.isNotEmpty) {
          final first = scheme.sections.first;
          final last = scheme.sections.last;
          audit(
            '  模板首末节: ${first.startTime}-${first.endTime} ... '
            '${last.startTime}-${last.endTime}',
          );
        }
      }
      if (activeScheme != null && activeScheme.sections.isNotEmpty) {
        final first = activeScheme.sections.first;
        final last = activeScheme.sections.last;
        audit(
          '主课表模板首末节: ${first.startTime}-${first.endTime} ... '
          '${last.startTime}-${last.endTime}',
        );
      }

      final synced = <Course>[];
      for (final course in _courses) {
        unlockedCount += 1;
        final beforeOverride = course.timeSchemeIdOverride;
        final beforeClock = '${course.startTime}-${course.endTime}';
        final match = matchLocationTime(course.location);
        final matchedScheme = match == null
            ? null
            : _getTimeSchemeById(match.timeSchemeId);

        Course courseToSync = course;

        // 适配脚本下发的真实钟点是权威值，地点分组不得覆盖，否则用户改一次分组
        // 就会把早读/连堂这类自定义时间冲掉。
        if (course.hasCustomTime) {
          synced.add(course);
          continue;
        }

        if (match == null) {
          noMatchCount += 1;
          if (changeSamples.length < 40) {
            audit(
              '未命中地点: course=${course.name} id=${course.id} loc=${course.location} '
              'sections=${course.startSection}-${course.endSection} '
              'override=${beforeOverride ?? "null"} clock=$beforeClock',
              extras: {
                'action': 'no_match',
                'courseId': course.id,
                'courseName': course.name,
                'location': course.location,
                'beforeOverride': beforeOverride,
                'beforeClock': beforeClock,
              },
            );
          }
          synced.add(course);
          continue;
        }

        if (matchedScheme == null) {
          matchMissingSchemeCount += 1;
          audit(
            '命中但模板不存在: course=${course.name} id=${course.id} loc=${course.location} '
            'group=${match.groupName} schemeId=${match.timeSchemeId} '
            'keyword=${match.matchedKeyword.pattern}/${match.matchedKeyword.mode.name}',
            extras: {
              'action': 'match_missing_scheme',
              'courseId': course.id,
              'courseName': course.name,
              'location': course.location,
              'groupName': match.groupName,
              'schemeId': match.timeSchemeId,
              'beforeOverride': beforeOverride,
            },
          );
          synced.add(course);
          continue;
        }

        final startIndex = course.startSection - 1;
        final endIndex = course.endSection - 1;
        final sectionCount = matchedScheme.sections.length;
        // HARD RULE: only fully seat-mapable courses may be synchronized.
        // Applying a short scheme to a later section would produce nonsense
        // clocks, so leave the course untouched and report it.
        if (startIndex < 0 || endIndex < startIndex || endIndex >= sectionCount) {
          sectionOverflowCount += 1;
          if (sectionOverflowCourseNames.length < 5) {
            sectionOverflowCourseNames.add(course.name);
          }
          audit(
            '拒绝套用(节次无法对号入座): course=${course.name} id=${course.id} '
            'loc=${course.location} need=${course.startSection}-${course.endSection} '
            'scheme=${matchedScheme.name} has=$sectionCount '
            'beforeOverride=${beforeOverride ?? "null"} clock=$beforeClock '
            '→ 不写 override、不改钟点',
            extras: {
              'action': 'overflow_reject_no_sync',
              'courseId': course.id,
              'courseName': course.name,
              'location': course.location,
              'startSection': course.startSection,
              'endSection': course.endSection,
              'schemeId': matchedScheme.id,
              'schemeName': matchedScheme.name,
              'schemeSections': sectionCount,
              'beforeOverride': beforeOverride,
              'beforeClock': beforeClock,
            },
          );
          // Leave course completely unchanged.
          synced.add(course);
          if (changeSamples.length < 30) {
            changeSamples.add(
              '${course.name}|${course.id}|REJECT overflow '
              'need=${course.startSection}-${course.endSection} schemeHas=$sectionCount',
            );
          }
          continue;
        }

        // Only fully seat-mapped courses count as matched/synchronized.
        matchedCount += 1;
        // Return the course to automatic mode, then resolve it through the
        // current location rule. This keeps future rule edits automatic instead
        // of turning a rematch into another permanent manual override.
        courseToSync = course.copyWith(timeSchemeIdOverride: null);
        if (beforeOverride != null) {
          autoReleasedCount += 1;
        }

        final expectedStart = matchedScheme.sections[startIndex].startTime;
        final expectedEnd = matchedScheme.sections[endIndex].endTime;
        final sameClock =
            course.startTime == expectedStart && course.endTime == expectedEnd;
        if (sameClock) {
          alreadySameClockCount += 1;
        }

        final next = _syncCourseWithEffectiveTimeScheme(
          courseToSync,
          settings: _settings,
          debugTrace: true,
        );
        synced.add(next);

        final clockChanged =
            next.startTime != course.startTime || next.endTime != course.endTime;
        final overrideChanged =
            next.timeSchemeIdOverride != course.timeSchemeIdOverride;
        if (clockChanged || overrideChanged) {
          updatedCount += 1;
          if (clockChanged) {
            clockRewriteCount += 1;
          }
          if (changeSamples.length < 30) {
            changeSamples.add(
              '${course.name}|${course.id}|'
              'override ${beforeOverride ?? "null"}->${next.timeSchemeIdOverride ?? "null"}|'
              'clock $beforeClock->${next.startTime}-${next.endTime}',
            );
          }
        }
        audit(
          '${sameClock ? "SAME" : "DIFF"} course=${course.name} id=${course.id} '
          'loc=${course.location} group=${match.groupName} '
          'scheme=${matchedScheme.name} '
          'beforeOverride=${beforeOverride ?? "null"} '
          'afterOverride=${next.timeSchemeIdOverride ?? "null"} '
          'beforeClock=$beforeClock afterClock=${next.startTime}-${next.endTime} '
          'clockChanged=$clockChanged overrideChanged=$overrideChanged',
          extras: {
            'action': sameClock
                ? 'auto_match_same_clock'
                : 'auto_match_and_rewrite_clock',
            'courseId': course.id,
            'courseName': course.name,
            'location': course.location,
            'groupName': match.groupName,
            'schemeId': matchedScheme.id,
            'schemeName': matchedScheme.name,
            'beforeOverride': beforeOverride,
            'afterOverride': next.timeSchemeIdOverride,
            'beforeClock': beforeClock,
            'afterClock': '${next.startTime}-${next.endTime}',
            'expectedClock': '$expectedStart-$expectedEnd',
            'sameClock': sameClock,
            'clockChanged': clockChanged,
            'overrideChanged': overrideChanged,
          },
        );
      }

      if (updatedCount > 0) {
        _courses = synced;
        await _persistActiveProfileState();
        _currentLiveCourseId = null;
        _notifyStateChanged();
        await _updateLiveActivity();
      }

      final overridesAfter = _courses
          .where((course) => course.timeSchemeIdOverride != null)
          .length;
      final profileOverrides =
          activeProfile?.courses
              .where((course) => course.timeSchemeIdOverride != null)
              .length ??
          -1;
      audit(
        '===== 应用结束 ===== unlocked=$unlockedCount matched=$matchedCount '
        'updated=$updatedCount sameClock=$alreadySameClockCount '
        'overflow=$sectionOverflowCount noMatch=$noMatchCount '
        'missingScheme=$matchMissingSchemeCount '
        'autoReleased=$autoReleasedCount clockRewrite=$clockRewriteCount '
        'overridesInMemoryAfter=$overridesAfter overridesInActiveProfile=$profileOverrides '
        'didPersist=${updatedCount > 0} '
        'overflowNames=${sectionOverflowCourseNames.join(",")} '
        'samples=${changeSamples.take(12).join(" || ")}',
        extras: {
          'unlocked': unlockedCount,
          'matched': matchedCount,
          'updated': updatedCount,
          'sameClock': alreadySameClockCount,
          'overflow': sectionOverflowCount,
          'noMatch': noMatchCount,
          'missingScheme': matchMissingSchemeCount,
          'autoReleased': autoReleasedCount,
          'clockRewrite': clockRewriteCount,
          'overridesInMemoryAfter': overridesAfter,
          'overridesInActiveProfile': profileOverrides,
          'didPersist': updatedCount > 0,
          'changeSamples': changeSamples,
          'overflowNames': sectionOverflowCourseNames,
        },
      );
      if (matchedCount > 0 && updatedCount == 0) {
        audit(
          '结论: 地点规则已命中，但课程未改写（钟点已相同且未绑定 override，或全部节次越界）。'
          'sameClock=$alreadySameClockCount overflow=$sectionOverflowCount。'
          '请对比地点组绑定模板 vs 主课表模板各节起止时间是否完全一致。',
        );
      }
      if (overridesAfter != profileOverrides && profileOverrides >= 0) {
        audit(
          '严重异常: 内存课表与 activeProfile 的模板覆盖数量不一致。持久化/合并失败。',
          extras: {
            'fatal': true,
            'overridesInMemoryAfter': overridesAfter,
            'overridesInActiveProfile': profileOverrides,
          },
        );
      }

      return LocationTimeApplyStats(
        unlockedCount: unlockedCount,
        matchedCount: matchedCount,
        updatedCount: updatedCount,
        alreadySameClockCount: alreadySameClockCount,
        sectionOverflowCount: sectionOverflowCount,
        sectionOverflowCourseNames: sectionOverflowCourseNames,
      );
    }
}
