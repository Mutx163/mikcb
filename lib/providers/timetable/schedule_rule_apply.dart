part of '../timetable_provider.dart';

// 日期规则 / 地点分组的批量套用实现（从 timetable_provider.dart 拆出以压行数棘轮；
// 同库 part 可访私有成员，方法体逐字未动）。
extension _ScheduleRuleApply on TimetableProvider {
    /// Single implementation of seasonal bulk-apply. Returns structured outcome
    /// for UI toasts; [applyDueScheduleDateRules] maps [didApply] to bool.
    Future<ScheduleDateRuleApplyResult> _applyDueScheduleDateRulesDetailed({
      DateTime? now,
    }) async {
      await initialize();
      final reference = now ?? DateTime.now();
      final matched = ScheduleDateRuleLogic.match(reference, _scheduleDateRules);
      if (!ScheduleDateRuleLogic.shouldBulkApply(
        matchedRule: matched,
        lastAppliedSignature: _scheduleDateRuleLastAppliedSignature,
      )) {
        return const ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.notDue,
        );
      }

      final rule = matched!;
      final scheme = _getTimeSchemeById(rule.timeSchemeId);
      if (scheme == null) {
        appDebugLog(
          'ScheduleDateRule',
          '跳过批量套用: 模板不存在 rule=${rule.name} schemeId=${rule.timeSchemeId}',
        );
        await AppLogService.instance.warn(
          'schedule_date_rule',
          '日期规则批量套用失败：时间模板不存在',
          extras: {
            'ruleId': rule.id,
            'ruleName': rule.name,
            'schemeId': rule.timeSchemeId,
          },
        );
        return const ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.schemeMissing,
        );
      }

      // Validate every profile before rewriting clocks; active-only checks can
      // leave inactive profiles pointing at a scheme that cannot represent them.
      var requiredMaxSection = 0;
      for (final profile in _profiles) {
        for (final course in profile.courses) {
          if (course.endSection > requiredMaxSection) {
            requiredMaxSection = course.endSection;
          }
        }
      }
      for (final course in _courses) {
        if (course.endSection > requiredMaxSection) {
          requiredMaxSection = course.endSection;
        }
      }
      if (requiredMaxSection > scheme.sections.length) {
        appDebugLog(
          'ScheduleDateRule',
          '跳过批量套用: 节次超出模板 rule=${rule.name} need=$requiredMaxSection '
              'has=${scheme.sections.length}',
        );
        await AppLogService.instance.warn(
          'schedule_date_rule',
          '日期规则批量套用失败：节次超出模板',
          extras: {
            'ruleId': rule.id,
            'ruleName': rule.name,
            'schemeId': scheme.id,
            'requiredMaxSection': requiredMaxSection,
            'schemeSections': scheme.sections.length,
          },
        );
        return ScheduleDateRuleApplyResult(
          outcome: ScheduleDateRuleApplyOutcome.sectionOverflow,
          requiredMaxSection: requiredMaxSection,
          schemeSectionCount: scheme.sections.length,
        );
      }

      final signature = ScheduleDateRuleLogic.appliedSignature(rule);
      appDebugLog(
        'ScheduleDateRule',
        '批量套用作息: rule=${rule.name} scheme=${scheme.name} '
            'range=${rule.startDate}~${rule.endDate} signature=$signature',
      );

      for (var index = 0; index < _profiles.length; index++) {
        final profile = _profiles[index];
        final nextSettings = profile.settings.copyWith(
          activeTimeSchemeId: scheme.id,
          sections: List<SectionTime>.from(scheme.sections),
        );
        final syncedCourses = _syncCoursesWithEffectiveTimeSchemes(
          List<Course>.from(profile.courses),
          settings: nextSettings,
        );
        _profiles[index] = profile.copyWith(
          settings: nextSettings,
          courses: syncedCourses,
        );
      }

      final activeIndex = _profiles.indexWhere(
        (profile) => profile.id == _activeProfileId,
      );
      if (activeIndex != -1) {
        _courses = List<Course>.from(_profiles[activeIndex].courses);
        _settings = _settingsFromProfile(_profiles[activeIndex]);
      } else {
        _settings = _settings.copyWith(
          activeTimeSchemeId: scheme.id,
          sections: List<SectionTime>.from(scheme.sections),
        );
        _courses = _syncCoursesWithEffectiveTimeSchemes(
          List<Course>.from(_courses),
          settings: _settings,
        );
      }

      await _profileRepository.saveProfiles(_profiles);
      _scheduleDateRuleLastAppliedSignature = signature;
      await _profileRepository.saveScheduleDateRuleLastAppliedSignature(
        signature,
      );
      notifyUserDataChangedForSync();
      _currentLiveCourseId = null;
      _notifyStateChanged();
      await _updateLiveActivity();

      unawaited(
        AppLogService.instance.info(
          'schedule_date_rule',
          '已按日期规则批量套用作息',
          extras: {
            'ruleId': rule.id,
            'ruleName': rule.name,
            'schemeId': scheme.id,
            'schemeName': scheme.name,
            'startDate': rule.startDate,
            'endDate': rule.endDate,
            'signature': signature,
          },
        ),
      );
      return const ScheduleDateRuleApplyResult(
        outcome: ScheduleDateRuleApplyOutcome.applied,
      );
    }

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
