// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '경屿 시간표';

  @override
  String get appTitleDebug => '경屿 시간표 디버그판';

  @override
  String get appTitleProfile => '경屿 시간표 프로필판';

  @override
  String get appearanceTitle => '외관 및 색상';

  @override
  String get previewTitle => '미리보기';

  @override
  String get timetableBackgroundPreview => '시간표 배경';

  @override
  String get displayModeTitle => '표시 모드';

  @override
  String get displayModeSubtitle => '시스템 연동, 라이트 모드, 다크 모드를 지원합니다.';

  @override
  String get themeModeLabel => '테마 모드';

  @override
  String get themeModeSystem => '시스템 연동';

  @override
  String get themeModeLight => '라이트 모드';

  @override
  String get themeModeDark => '다크 모드';

  @override
  String get fontSectionTitle => '앱 글꼴';

  @override
  String get fontSectionSubtitle =>
      '시스템 기본 글꼴과 MiSans를 지원합니다. MiSans를 사용할 수 없으면 자동으로 대체됩니다.';

  @override
  String get fontModeLabel => '글꼴 선택';

  @override
  String get fontModeSystem => '기기 기본 글꼴';

  @override
  String get fontModeMiSans => 'MiSans (우선)';

  @override
  String get languageSectionTitle => '앱 언어';

  @override
  String get languageSectionSubtitle => '시스템 연동 또는 수동으로 지원 언어를 전환할 수 있습니다.';

  @override
  String get languageModeLabel => '언어 선택';

  @override
  String get languageModeSystem => '시스템 연동';

  @override
  String get settingsTitle => '시간표 설정';

  @override
  String get dailyUsageSectionTitle => '일상 사용';

  @override
  String get appearanceEntryTitle => '외관 및 색상';

  @override
  String get appearanceEntrySubtitle => '테마 색상, 시간표 배경, 수업 카드 색상';

  @override
  String get layoutSectionEntryTitle => '레이아웃 및 교시';

  @override
  String get layoutSectionEntrySubtitle => '교시 시간, 행 높이, 시간 열, 주말 표시 및 카드 레이아웃';

  @override
  String get homeWidgetEntryTitle => '홈 위젯';

  @override
  String get homeWidgetEntrySubtitle => '오늘 수업 카드, 위젯 배경 및 표시 정보';

  @override
  String get reminderNotificationSectionTitle => '알림 및 푸시';

  @override
  String get userGuideEntryTitle => '사용 가이드 및 권한';

  @override
  String get userGuideEntrySubtitle => '약칭 설정, 알림, 자동 시작, 배터리 전략';

  @override
  String get timetableManagementSectionTitle => '시간표 관리';

  @override
  String get timeSchemeEntryTitle => '시간 템플릿';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '전환, 교시 편집, 복사 및 템플릿 관리';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '현재: $name · 전환, 교시 편집 및 복사';
  }

  @override
  String get dataTransferEntryTitle => '데이터 백업 및 마이그레이션';

  @override
  String get dataTransferEntrySubtitle => '시간표 파일을 내보내 다른 사람이 바로 가져올 수 있습니다';

  @override
  String get cloudSyncEntryTitle => '클라우드 동기화 (WEBDAV)';

  @override
  String get cloudSyncEntrySubtitle =>
      'Jianguoyun 등으로 여러 기기에서 시간표와 가져온 데이터 동기화';

  @override
  String get cloudSyncTitle => '클라우드 동기화';

  @override
  String get cloudSyncIntroTitle => '다중 기기 동기화';

  @override
  String get cloudSyncIntroSubtitle =>
      'Jianguoyun WEBDAV를 설정하면 휴대폰, 태블릿 간 시간표, 창고 계정 및 관련 설정을 자동으로 동기화할 수 있습니다.';

  @override
  String get cloudSyncSettingsSectionTitle => '동기화 설정';

  @override
  String get cloudSyncSettingsSectionSubtitle => '수동 또는 자동 동기화를 전환할 수 있습니다.';

  @override
  String get cloudSyncEnabledTitle => '클라우드 동기화 사용';

  @override
  String get cloudSyncEnabledSubtitle => '끄면 스냅샷을 업로드하거나 다운로드하지 않습니다';

  @override
  String get cloudSyncProviderTitle => '서비스 제공자';

  @override
  String get cloudSyncProviderJianguoyun => 'Jianguoyun';

  @override
  String get cloudSyncProviderCustom => '사용자 지정 WEBDAV';

  @override
  String get cloudSyncModeTitle => '동기화 방식';

  @override
  String get cloudSyncModeAuto => '자동 동기화';

  @override
  String get cloudSyncModeManual => '수동 동기화';

  @override
  String get cloudSyncAccountTitle => '계정 설정';

  @override
  String get cloudSyncAccountSubtitle =>
      'Jianguoyun 앱 전용 비밀번호를 사용하세요 (로그인 비밀번호 아님). 스냅샷에는 창고에 저장된 학교 계정도 포함됩니다.';

  @override
  String get cloudSyncUsernameLabel => '이메일 / 사용자명';

  @override
  String get cloudSyncUsernameHint => 'Jianguoyun 가입 이메일';

  @override
  String get cloudSyncPasswordLabel => '앱 전용 비밀번호';

  @override
  String get cloudSyncPasswordHint => 'Jianguoyun 계정 보안 설정에서 생성';

  @override
  String get cloudSyncPasswordStoredHint =>
      '비밀번호 저장됨. 비워 두면 저장된 비밀번호를 계속 사용합니다.';

  @override
  String get cloudSyncAdvancedTitle => '고급 설정';

  @override
  String get cloudSyncBaseUrlLabel => 'WEBDAV 주소';

  @override
  String get cloudSyncRemoteFolderLabel => '원격 폴더';

  @override
  String get cloudSyncStatusTitle => '동기화 상태';

  @override
  String get cloudSyncLastSyncedLabel => '마지막 동기화';

  @override
  String get cloudSyncLastErrorLabel => '최근 오류';

  @override
  String cloudSyncLastSyncedAt(String time) {
    return '마지막 동기화: $time';
  }

  @override
  String get cloudSyncSyncing => '동기화 중…';

  @override
  String cloudSyncLastError(String message) {
    return '최근 오류: $message';
  }

  @override
  String get cloudSyncHelpTitle => 'Jianguoyun 앱 비밀번호 받는 방법';

  @override
  String get cloudSyncHelpBody =>
      'Jianguoyun 웹 또는 클라이언트 → 계정 정보 → 보안 → 앱 비밀번호 추가. WEBDAV 주소 기본값: https://dav.jianguoyun.com/dav/';

  @override
  String get cloudSyncTestConnection => '연결 테스트';

  @override
  String get cloudSyncSyncNow => '지금 동기화';

  @override
  String get cloudSyncSyncNowSubtitle =>
      '다른 기기와 시간표를 맞춥니다: 클라우드에서 받은 뒤 기기 변경을 업로드';

  @override
  String get cloudSyncTestSuccess => 'WEBDAV 연결 성공';

  @override
  String get cloudSyncTestFailed => 'WEBDAV 연결 실패. 계정, 앱 비밀번호, 네트워크를 확인하세요';

  @override
  String get cloudSyncResultUploaded => '클라우드에 업로드됨';

  @override
  String get cloudSyncResultDownloaded => '클라우드에서 복원됨';

  @override
  String get cloudSyncResultUpToDate => '로컬과 클라우드가 일치함';

  @override
  String get cloudSyncResultCancelled => '동기화 취소됨';

  @override
  String cloudSyncResultFailed(String message) {
    return '동기화 실패: $message';
  }

  @override
  String get cloudSyncConflictTitle => '동기화 충돌 감지';

  @override
  String get cloudSyncConflictBody =>
      '이 기기와 클라우드 모두 새 변경 사항이 있습니다. 유지할 데이터를 선택하세요.';

  @override
  String get cloudSyncUseRemoteAction => '클라우드 사용';

  @override
  String get cloudSyncKeepLocalAction => '로컬 유지';

  @override
  String get cloudSyncAccountSectionTitle => '클라우드 계정';

  @override
  String get cloudSyncNotConnectedHint =>
      'Jianguoyun에 연결하면 여러 기기에서 시간표와 가져온 데이터를 동기화할 수 있습니다.';

  @override
  String get cloudSyncConnectAccount => 'Jianguoyun 연결';

  @override
  String cloudSyncConnectedAs(String email) {
    return '연결됨: $email';
  }

  @override
  String get cloudSyncDisconnect => '연결 해제';

  @override
  String get cloudSyncDisconnectTitle => '클라우드 동기화 계정 연결 해제';

  @override
  String get cloudSyncDisconnectBody =>
      '연결 해제 시 이 기기에 저장된 WEBDAV 자격 증명이 삭제됩니다. 시간표 데이터는 기기에 남습니다. 계속하시겠습니까?';

  @override
  String get cloudSyncLoginSheetTitle => 'Jianguoyun 연결';

  @override
  String get cloudSyncLoginSheetSubtitle =>
      '앱 전용 비밀번호를 사용하세요 (Jianguoyun 로그인 비밀번호 아님).';

  @override
  String get cloudSyncConfirmConnect => '연결 확인';

  @override
  String get cloudSyncConnectSuccess => '계정 연결 성공';

  @override
  String get cloudBackupSectionTitle => '버전 기록';

  @override
  String get cloudBackupSectionSubtitle => '동기화할 때 자동 저장됩니다. 탭하여 해당 버전으로 복원';

  @override
  String get cloudBackupCurrentLabel => '현재 버전';

  @override
  String get cloudBackupCurrentBadge => '현재';

  @override
  String get cloudBackupCreateNow => '지금 백업';

  @override
  String get cloudBackupViewAll => '모든 버전 보기';

  @override
  String get cloudBackupEmpty => '아직 버전 기록이 없습니다. 동기화하면 자동 저장됩니다';

  @override
  String get cloudBackupSourceAuto => '자동 백업';

  @override
  String get cloudBackupSourceManual => '수동 백업';

  @override
  String get cloudBackupDefaultDeviceLabel => '이 기기';

  @override
  String get cloudBackupDeviceLabelTitle => '기기 이름';

  @override
  String get cloudBackupDeviceLabelHint => '백업 목록에 표시됩니다. 예: 내 휴대폰';

  @override
  String cloudBackupSummary(int profileCount, int courseCount) {
    return '시간표 $profileCount개 · 강의 $courseCount개';
  }

  @override
  String get cloudBackupRestoreTitle => '이 백업으로 복원';

  @override
  String cloudBackupRestoreBody(String time) {
    return '$time 시간표로 복원합니다. 동기화되지 않은 로컬 변경은 사라집니다. 계속할까요?';
  }

  @override
  String get cloudBackupRestoreAction => '복원';

  @override
  String get cloudBackupRestoreSuccess => '백업을 복원했습니다';

  @override
  String cloudBackupRestoreFailed(String message) {
    return '복원 실패: $message';
  }

  @override
  String get cloudBackupDeleteTitle => '이 백업 삭제';

  @override
  String cloudBackupDeleteBody(String time) {
    return '$time 클라우드 백업을 삭제할까요? 되돌릴 수 없습니다.';
  }

  @override
  String get cloudBackupDeleteSuccess => '백업을 삭제했습니다';

  @override
  String cloudBackupDeleteFailed(String message) {
    return '삭제 실패: $message';
  }

  @override
  String get cloudBackupCreateSuccess => '백업을 클라우드에 저장했습니다';

  @override
  String cloudBackupCreateFailed(String message) {
    return '백업 실패: $message';
  }

  @override
  String get cloudBackupUploadAsCurrentTitle => '현재 클라우드 버전으로 설정';

  @override
  String get cloudBackupUploadAsCurrentBody =>
      '이 백업을 현재 클라우드 버전으로 업로드할까요? 동기화 충돌을 줄이려면 권장합니다.';

  @override
  String get cloudBackupUploadAsCurrentYes => '현재 버전으로 설정';

  @override
  String get cloudBackupUploadAsCurrentNo => '로컬만 복원';

  @override
  String get cloudBackupDetailDevice => '기기';

  @override
  String get cloudBackupDetailSource => '유형';

  @override
  String get cloudBackupDetailSummary => '내용';

  @override
  String get lanEditEntryTitle => 'LAN 편집';

  @override
  String get lanEditEntrySubtitle => 'PC 브라우저에서 현재 시간표 편집';

  @override
  String get lanEditTitle => 'LAN 편집';

  @override
  String get lanEditIntro =>
      '활성화하면 같은 Wi-Fi 또는 핫스팟의 PC 브라우저에서 현재 시간표를 편집할 수 있습니다.';

  @override
  String get lanEditStart => 'LAN 편집 시작';

  @override
  String get lanEditStop => '중지';

  @override
  String get lanEditStatusRunning => 'LAN 편집 세션 진행 중';

  @override
  String get lanEditAddressLabel => '접속 주소';

  @override
  String get lanEditAddressUnavailable => 'LAN IP를 찾을 수 없습니다';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => '포트';

  @override
  String get lanEditCopyAddress => '주소 복사';

  @override
  String get lanEditCopied => '주소가 복사되었습니다';

  @override
  String get lanEditHotspotHint => '기숙사 Wi-Fi에서 연결되지 않으면 휴대폰 핫스팟을 사용해 보세요.';

  @override
  String get lanEditQrHint => '같은 LAN의 PC 브라우저로 QR 코드를 스캔하세요(PIN 포함 링크).';

  @override
  String get lanEditStartFailed => '시작 실패';

  @override
  String get lanEditConnectedClientsLabel => '연결됨';

  @override
  String get lanEditConnectedClientsNone => '없음';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count대';
  }

  @override
  String get lanEditLastActivityLabel => '최근 활동';

  @override
  String get aboutSupportSectionTitle => '앱 정보 및 지원';

  @override
  String get feedbackEntryTitle => '문제 제보';

  @override
  String get feedbackEntrySubtitle => '이슈, 커뮤니티 채널 및 피드백';

  @override
  String get aboutEntryTitle => '앱 정보';

  @override
  String get aboutEntrySubtitle => '오픈소스, 버전 업데이트 및 GitHub 저장소';

  @override
  String get setSemesterStartDateAction => '학기 시작일 설정';

  @override
  String get semesterStartDateAction => '학기 시작일';

  @override
  String get syncCurrentWeekAction => '현재 주 동기화';

  @override
  String semesterWeekCountAction(int count) {
    return '$count주';
  }

  @override
  String get selectSemesterWeekCountTitle => '학기 주 수 선택';

  @override
  String get selectSemesterWeekCountSubtitle =>
      '학교에 따라 실제 수업 주 수에 맞게 조정할 수 있습니다.';

  @override
  String get unifiedCourseCardColorTitle => '수업 카드 색상 통일';

  @override
  String get unifiedCourseCardColorSubtitle => '끄면 각 수업의 개별 색상을 계속 사용합니다';

  @override
  String get courseImportTitle => '수업 가져오기';

  @override
  String get chooseImportMethodTitle => '가져오기 방법 선택';

  @override
  String get chooseImportMethodSubtitle =>
      '기존 .ics 캘린더 가져오기, 이미지 인식 가져오기, 저장소에서 어댑터를 읽어오는 교무 시스템 가져오기를 지원합니다.';

  @override
  String get importMethodIcsTitle => '.ics 캘린더 가져오기';

  @override
  String get importMethodIcsSubtitle =>
      'WakeUp 등 시간표 앱에서 내보낸 캘린더 파일에 적합하며, 절차가 가장 짧습니다.';

  @override
  String get importMethodIcsFooter =>
      '진입 후 .ics 파일을 선택하여 추가 가져오기 또는 기존 수업을 대체할 수 있습니다.';

  @override
  String get importMethodAiTitle => '이미지 인식 가져오기';

  @override
  String get importMethodAiSubtitle =>
      '시간표 스크린샷에서 바로 가져오기에 적합합니다. 1장 또는 연속 여러 장을 지원합니다.';

  @override
  String get importMethodAiFooter =>
      '프롬프트를 복사한 뒤 Doubao 전문가 모드에서 스크린샷과 프롬프트를 전송하고, 반환된 JSON을 복사하여 가져온 후 학기 시작일을 선택합니다.';

  @override
  String get importMethodWarehouseTitle => '교무 시스템 가져오기';

  @override
  String get importMethodWarehouseSubtitle =>
      'qingyu_warehouse에서 학교와 어댑터를 읽어 웹 로그인으로 수업을 가져옵니다.';

  @override
  String get importMethodWarehouseFooter =>
      '진입 후 학교와 어댑터를 선택하면 교무 웹페이지를 열어 로그인 후 가져오기를 실행할 수 있습니다.';

  @override
  String get importMethodSpreadsheetTitle => '표 가져오기';

  @override
  String get importMethodSpreadsheetSubtitle =>
      'Excel/WPS에서 경량섬 시간표 템플릿을 작성한 뒤 가져오기. .ics 사전보내기 불필요.';

  @override
  String get importMethodSpreadsheetFooter =>
      '.csv와 .xlsx 지원. 템플릿을 다운로드해 작성 후 파일을 선택하세요.';

  @override
  String get spreadsheetImportTitle => '표 가져오기';

  @override
  String get spreadsheetScenarioIntro =>
      '경량섬 템플릿은 헤더로 열을 인식합니다. 필수: 과목명, 요일, 시작/종료 절, 주차. 나머지는 선택. 전체 템플릿을 받거나 필수 열만 유지해도 됩니다. WakeUp 7열 형식도 지원.';

  @override
  String get spreadsheetStep1Subtitle =>
      '전체 템플릿을 받아 작성하거나, 필수 열과 上课周(또는 시작周+结束周)만 남겨 최소 가져오기.';

  @override
  String get spreadsheetStep2Subtitle => '작성 후 .csv로 저장하거나 .xlsx를 그대로 사용합니다.';

  @override
  String get spreadsheetStep3Subtitle =>
      '파일을 선택해 가져옵니다. 인식 경고가 있으면 먼저 표시한 뒤 추가 또는 대체를 선택합니다.';

  @override
  String get spreadsheetSupportedFilesSuffix => '.csv와 .xlsx 지원(첫 번째 시트만).';

  @override
  String get chooseSpreadsheetFileAction => '표 파일 선택';

  @override
  String get downloadSpreadsheetTemplateAction => '경량섬 시간표 템플릿 다운로드';

  @override
  String get spreadsheetImportWarningsTitle => '가져오기 알림';

  @override
  String get spreadsheetImportWarningsMessage =>
      '다음 행은 가져오지 못했습니다. 나머지 수업은 계속할 수 있습니다:';

  @override
  String get spreadsheetImportWarningsContinue => '가져오기 계속';

  @override
  String get spreadsheetFormatUnrecognized =>
      '표 형식을 인식하지 못했습니다. 경량섬 시간표 템플릿을 사용하세요. WakeUp 등 동일 열 형식도 지원합니다.';

  @override
  String get icsImportTitle => '.ics 캘린더 가져오기';

  @override
  String get applicableScenarioTitle => '적용 시나리오';

  @override
  String get icsScenarioIntro =>
      'WakeUp 등 시간표 앱에서 교무 시스템 수업을 가져온 뒤 .ics 파일로 내보낼 수 있다면, 이 방법이 가장 안정적입니다.';

  @override
  String stepLabel(String step) {
    return '단계 $step';
  }

  @override
  String get icsStep1Subtitle => '먼저 다른 시간표 앱에서 .ics 캘린더 파일을 내보냅니다.';

  @override
  String get icsStep2Subtitle =>
      '여기서 파일을 선택합니다. \'추가 가져오기\' 또는 \'기존 대체\'를 선택할 수 있습니다.';

  @override
  String get icsStep3Subtitle =>
      '가져오기 전에 학기 시작일과 시간표의 1주차가 학사일정의 몇 주차에 해당하는지 확인합니다.';

  @override
  String get supportedFilesTitle => '지원 파일';

  @override
  String get supportedFilesSuffix => '파일 확장자는 .ics여야 합니다.';

  @override
  String get supportedFilesImageHint =>
      '스크린샷만 있다면 이곳이 아닌 이전 페이지에서 \'이미지 인식 가져오기\'를 선택하세요.';

  @override
  String get chooseIcsFileAction => '.ics 파일 선택';

  @override
  String get timetableAppName => '경屿 시간표';

  @override
  String get switchProfileHint => '탭하여 시간표 전환';

  @override
  String get moreTooltip => '더 보기';

  @override
  String get pleaseSetSemesterStartDate => '시간표 설정에서 학기 시작일을 먼저 입력하세요';

  @override
  String get deleteScheduleTitle => '일정 삭제';

  @override
  String get deleteLessonTitle => '이 수업 삭제';

  @override
  String get cancelAction => '취소';

  @override
  String get confirmAction => '확인';

  @override
  String get deleteAction => '삭제';

  @override
  String deletedCourseMessage(String name) {
    return '삭제됨: $name';
  }

  @override
  String get deleteFailed => '삭제 실패';

  @override
  String get rescheduleFailed => '시간 변경 실패';

  @override
  String get timetableManagement => '시간표 관리';

  @override
  String weekLabel(int week) {
    return '제$week주';
  }

  @override
  String sectionLabel(int section) {
    return '제$section교시';
  }

  @override
  String get feedbackTitle => '문제 제보';

  @override
  String get feedbackIntro =>
      '앱 충돌, 수업 표시 오류, 가져오기 문제 또는 기능 제안이 있다면 아래 채널을 통해 피드백해 주세요.';

  @override
  String get feedbackIssueHint =>
      '재현 단계, 스크린샷, 버전 번호, 로그가 관련된 문제는 GitHub Issue를 권장합니다.';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle =>
      '저장소 Issue 페이지를 열어 문제나 제안을 제출하거나 기존 피드백을 확인할 수 있습니다.';

  @override
  String get openIssuePage => 'Issue 페이지 열기';

  @override
  String get copyAddress => '주소 복사';

  @override
  String get copiedIssueAddress => 'Issue 주소를 복사했습니다';

  @override
  String get copyXiaohongshuId => '샤오홍슈 ID 복사';

  @override
  String get copiedXiaohongshuId => '샤오홍슈 ID를 복사했습니다';

  @override
  String get copyCoolapkId => 'Coolapk ID 복사';

  @override
  String get copiedCoolapkId => 'Coolapk ID를 복사했습니다';

  @override
  String get copyQqGroupId => 'QQ 그룹 ID 복사';

  @override
  String get copiedQqGroupId => 'QQ 그룹 ID를 복사했습니다';

  @override
  String get timetableProfilesTitle => '시간표 관리';

  @override
  String get createTimetableTooltip => '새 시간표';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count과목 · 제$week주';
  }

  @override
  String get moreActionsTooltip => '더 많은 작업';

  @override
  String get switchToThisTimetable => '이 시간표로 전환';

  @override
  String get renameAction => '이름 변경';

  @override
  String get duplicateAction => '복사';

  @override
  String get clearCoursesAction => '수업 비우기';

  @override
  String get usingNow => '사용 중';

  @override
  String switchedToProfile(String name) {
    return '$name으로 전환됨';
  }

  @override
  String get createTimetableTitle => '새 시간표';

  @override
  String get timetableNameLabel => '시간표 이름';

  @override
  String get timetableNameHint => '예: 2학년 2학기';

  @override
  String get createAction => '생성';

  @override
  String createdProfile(String name) {
    return '시간표 생성됨: $name';
  }

  @override
  String get renameTimetableTitle => '시간표 이름 변경';

  @override
  String get saveAction => '저장';

  @override
  String renamedProfile(String name) {
    return '이름 변경됨: $name';
  }

  @override
  String get clearCurrentTimetableTitle => '현재 시간표 비우기';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '\"$name\"의 모든 수업을 비우시겠습니까? 시간표 설정은 유지됩니다.';
  }

  @override
  String get clearAction => '비우기';

  @override
  String clearedProfile(String name) {
    return '시간표 비움: $name';
  }

  @override
  String get noCoursesInCurrentProfile => '현재 시간표에 수업이 없습니다';

  @override
  String get deleteTimetableTitle => '시간표 삭제';

  @override
  String deleteTimetableMessage(String name) {
    return '\"$name\"을(를) 삭제하시겠습니까?';
  }

  @override
  String deletedProfile(String name) {
    return '시간표 삭제됨: $name';
  }

  @override
  String get keepAtLeastOneProfile => '최소 1개의 시간표를 유지하세요';

  @override
  String get dataTransferTitle => '데이터 백업 및 마이그레이션';

  @override
  String get fullExportTitle => '전체 내보내기';

  @override
  String get fullExportSubtitle =>
      '현재 시간표 또는 모든 시간표, 시간 템플릿, 현재 선택 상태를 한 번에 내보낼 수 있습니다.';

  @override
  String get exportCurrentTimetable => '현재 시간표 내보내기';

  @override
  String get exportAllData => '모든 데이터 내보내기';

  @override
  String get fullImportTitle => '전체 가져오기';

  @override
  String get fullImportSubtitle =>
      '가져오기 시 현재 시간표를 덮어쓰거나 새 시간표로 가져올 수 있습니다. 먼저 백업을 권장합니다.';

  @override
  String get chooseFileAndImport => '파일 선택 및 가져오기';

  @override
  String get transferOverviewTitle => '현재 마이그레이션 가능 항목';

  @override
  String courseCountBullet(int count) {
    return '수업 수: $count개';
  }

  @override
  String currentTimetableBullet(String name) {
    return '현재 시간표: $name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '전체 시간표: $count개';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return '시간 템플릿: $count세트';
  }

  @override
  String currentWeekBullet(int week) {
    return '현재 주: 제$week주';
  }

  @override
  String get semesterStartUnsetBullet => '학기 시작일: 미설정';

  @override
  String semesterStartBullet(String date) {
    return '학기 시작일: $date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return '파일 확장자: .$extension';
  }

  @override
  String get selectImportModeTitle => '가져오기 모드 선택';

  @override
  String get selectImportModeMessage =>
      '현재 시간표를 덮어쓰거나, 백업을 독립된 새 시간표로 가져올 수 있습니다.';

  @override
  String get replaceCurrentTimetable => '현재 시간표 덮어쓰기';

  @override
  String get importAsNewTimetable => '새 시간표로 가져오기';

  @override
  String get createdNewTimetableAfterImport => '가져오기 성공, 새 시간표가 생성되었습니다';

  @override
  String get backupRestoredSuccess => '가져오기 성공, 백업 데이터가 복원되었습니다';

  @override
  String get importFailedInvalidFile => '가져오기 실패, 파일이 유효한지 확인하세요';

  @override
  String get welcomeTitle => '환영합니다';

  @override
  String get welcomeAppName => '경屿 시간표';

  @override
  String get welcomeSubtitle => '바로 시작하거나 수업을 가져오거나 백업에서 복원할 수 있습니다.';

  @override
  String get thirdPartyDisclaimer =>
      '声明：본 앱은 제3자 개발자가 독립적으로 개발하였으며, 학습 및 연구 목적으로만 사용됩니다. Xiaomi(小米) 공식 소프트웨어가 아니며 Xiaomi Technology Co., Ltd.(小米科技有限責任公司)와 어떠한 종속, 협력 또는 승인 관계도 없습니다. 콘텐츠 침해가 있는 경우 권리자께서 작성자에게 연락해 주시면 즉시 관련 콘텐츠를下架 및 삭제하겠습니다.';

  @override
  String get startUsingTitle => '시작하기';

  @override
  String get startUsingSubtitle => '앱에 진입하여 첫 사용 가이드를 계속 진행';

  @override
  String get importTimetableTitle => '시간표 가져오기';

  @override
  String get importTimetableSubtitle => '.ics 파일 또는 AI 분석 결과에서 수업 가져오기';

  @override
  String get restoreBackupTitle => '백업에서 복원';

  @override
  String get restoreBackupSubtitle => '.mikcb 백업 파일에서 이전 데이터 복원';

  @override
  String get viewGuideTitle => '기능 설명 보기';

  @override
  String get viewGuideSubtitle => '권한, 슈퍼아일랜드 및 기본 설정 확인';

  @override
  String get migrationTitle => '이전 데이터 마이그레이션';

  @override
  String get migrationSafeTitle => '걱정 마세요, 데이터가 사라진 것이 아닙니다';

  @override
  String get migrationSafeSubtitle =>
      '앱 패키지명이 변경되어 홈 화면에 잠시 두 개의 아이콘이 표시됩니다. 이는 정상입니다. 이전 데이터는 이전 버전 앱에 있습니다. 먼저 이전 버전에서 백업한 뒤 새 버전에서 가져오세요.';

  @override
  String get migrationStep1Title => '이전 버전 열기';

  @override
  String get migrationStep1Subtitle =>
      '\'데이터 백업 및 마이그레이션\' 페이지에서 \'모든 데이터 내보내기\'를 탭하세요. \'현재 시간표 내보내기\'를 누르지 말고, 이전 버전을 먼저 삭제하지 마세요.';

  @override
  String get migrationStep2Title => '백업 파일 저장';

  @override
  String get migrationStep2Subtitle =>
      '이전 버전에서 내보내기 후 시스템 공유 패널이 표시됩니다. \'파일에 저장\'을 우선 선택하고, 다운로드 폴더에 저장하는 것을 권장합니다.';

  @override
  String get migrationStep3Title => '현재 버전에서 가져오기';

  @override
  String get migrationStep3Subtitle =>
      '새 버전으로 돌아와 시스템 파일 선택기로 다운로드 폴더의 .mikcb 백업 파일을 선택하여 복원합니다. 새 버전의 데이터가 정상인지 확인한 뒤 이전 버전을 삭제하세요.';

  @override
  String get migrationNoSaveToFilesTitle => '\'파일에 저장\'이 없는 경우';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      'WeChat의 아무 채팅에 공유한 뒤 WeChat에서 백업 파일을 열어 저장하세요. 저장 후 보통 Download/WeiXin 폴더에 나타납니다. 새 버전에서 이 .mikcb 파일을 선택하여 가져오세요.';

  @override
  String get openingOldApp => '이전 버전 여는 중...';

  @override
  String get openOldAppForBackup => '이전 버전에서 백업';

  @override
  String get backupDoneGoImport => '백업 완료, 가져오기로 이동';

  @override
  String get startFreshWithoutMigration => '새 앱으로 시작, 마이그레이션 안 함';

  @override
  String get openOldAppFailed => '이전 버전을 열지 못했습니다. 홈 화면에서 수동으로 이전 버전을 여세요';

  @override
  String get supportCreatorTitle => '개발자에게 커피 한 잔';

  @override
  String get supportHeroTitle => '경屿 시간표의 지속적 업데이트를 지원';

  @override
  String get supportHeroSubtitle =>
      '여러분의 지원은 시간표 유지보수, 교무 가져오기 적응 및 UX 개선에 직접 사용됩니다.';

  @override
  String get supportChipFixes => '문제 수정';

  @override
  String get supportChipAdapters => '교무 적응';

  @override
  String get supportChipPolish => 'UX 개선';

  @override
  String get supportMethodTitle => '지원 방법 선택';

  @override
  String get wechatLabel => 'WeChat';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get supportWeChatHint => 'WeChat으로 QR 코드를 스캔하여 개발자 지원';

  @override
  String get supportAlipayHint => 'Alipay로 QR 코드를 스캔하여 개발자 지원';

  @override
  String get viewLargeImage => '큰 이미지 보기';

  @override
  String get saveToGallery => '갤러리에 저장';

  @override
  String get supportCompleteThanks => '경屿 시간표의 지속적인 개선을 지원해 주셔서 감사합니다 ❤️';

  @override
  String get supportConfirmed => '지원했습니다';

  @override
  String get donorListTitle => '감사 목록';

  @override
  String get donorListLoadFailed => '온라인 감사 목록을 불러올 수 없습니다.';

  @override
  String get reloadAction => '다시 불러오기';

  @override
  String updatedAtLabel(String time) {
    return '$time에 업데이트';
  }

  @override
  String get donorListEmpty =>
      '목록이 아직 작성되지 않았습니다. docs/donors.json을 직접 편집한 뒤 재발행할 수 있습니다.';

  @override
  String get savedToGallery => '갤러리에 저장되었습니다';

  @override
  String get saveToGalleryFailed => '갤러리 저장에 실패했습니다';

  @override
  String saveFailedWithError(String error) {
    return '저장 실패: $error';
  }

  @override
  String get supportRunningBadge => '운영 중';

  @override
  String get supportTapQrHint => '탭하여 확대';

  @override
  String get supportSaveShort => '저장';

  @override
  String get supportConfirmedShort => '후원함';

  @override
  String get donorSearchHint => '닉네임/메시지 검색...';

  @override
  String get donorSortLargeFirst => '금액 높은 순';

  @override
  String get donorSortSmallFirst => '금액 낮은 순';

  @override
  String get supportMonthlyGoalLabel => '이번 달 서버·인증서 갱신 진행률';

  @override
  String supportGoalRaised(String raised, String goal) {
    return '모금: $raised / 목표 $goal';
  }

  @override
  String supportBackerCount(int count) {
    return '이미 $count명이 후원';
  }

  @override
  String get supportDonorListFooter => '명단은 영구 보존됩니다 💖';

  @override
  String supportMarqueeThanks(String name, String amount) {
    return '🎉 $name님 $amount 감사합니다';
  }

  @override
  String get supportMarqueeTail => '경屿 시간표가 안정적으로 운영 중 — 여러분의 후원을 기다립니다!';

  @override
  String get scanQrWechatTitle => 'WeChat으로 QR 코드 스캔';

  @override
  String get scanQrAlipayTitle => 'Alipay로 QR 코드 스캔';

  @override
  String get scanQrSubtitle => '스크린샷 후 스캔, 후원 감사합니다!';

  @override
  String get courseOverviewTitle => '수업 전체보기 및 편집';

  @override
  String get addNewCourseTooltip => '새 수업 추가';

  @override
  String get emptyCourseOverviewHint => '시간표를 길게 누르거나 오른쪽 위에서 수업을 추가하세요';

  @override
  String conflictDetectedMessage(int count) {
    return '$count개의 배치에 실제 충돌이 감지되었습니다. 수업 목록에 충돌 항목이 표시됩니다.';
  }

  @override
  String conflictCountLabel(int count) {
    return '충돌 $count건';
  }

  @override
  String scheduledCountLabel(int count) {
    return '배치 합계 $count건';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '배치 합계 $count건 · 펼쳐서 충돌 상세 확인';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '시간: $day요일 $start-$end교시';
  }

  @override
  String get teacherUnset => '미설정';

  @override
  String get locationUnset => '미설정';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription  교사: $teacher  강의실: $location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription  교사: $teacher  강의실: $location\n충돌 수업: $conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '삭제 확인';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '수업 \"$name\"을(를) 삭제하시겠습니까?';
  }

  @override
  String get currentScheduleTitle => '현재 배치';

  @override
  String get currentScheduleSubtitle =>
      '여기의 요일, 교시, 강의실, 주차 및 홀짝주는 이 배치에만 영향을 줍니다.';

  @override
  String get timeSchemeLabel => '수업 시간 방안';

  @override
  String followCurrentTimetableWithName(String name) {
    return '현재 시간표에 연동 ($name)';
  }

  @override
  String get followCurrentTimetableDescription =>
      '기본으로 현재 시간표의 메인 템플릿에 연동됩니다. 대부분의 수업에 적합합니다.';

  @override
  String get overrideTimeSchemeDescription =>
      '이 수업은 선택한 템플릿을 개별 사용하며 메인 템플릿에 연동되지 않습니다.';

  @override
  String get weekdayLabel => '요일';

  @override
  String get startSectionLabel => '시작 교시';

  @override
  String get endSectionLabel => '종료 교시';

  @override
  String timeRangeLabel(String start, String end) {
    return '시간: $start - $end';
  }

  @override
  String get locationLabel => '수업 장소';

  @override
  String get singleLessonWeekTitle => '수업 주차';

  @override
  String get singleLessonWeekSubtitle =>
      '단일 수업은 한 주차에만 나타납니다. 보충 수업이나 임시 추가에 적합합니다.';

  @override
  String get selectWeekLabel => '주차 선택';

  @override
  String get weekSettingsTitle => '주차 설정';

  @override
  String get rangeWeeksLabel => '연속 주';

  @override
  String get customWeeksLabel => '사용자 정의 주';

  @override
  String get startWeekLabel => '시작 주';

  @override
  String get endWeekLabel => '종료 주';

  @override
  String get allWeeksFilter => '전체';

  @override
  String get oddWeeksFilter => '홀수 주';

  @override
  String get evenWeeksFilter => '짝수 주';

  @override
  String get rangeWeeksAllHint => '시작 주부터 종료 주까지 연속으로 수업을 배치합니다.';

  @override
  String get rangeWeeksOddHint => '범위 내 홀수 주만 유지합니다.';

  @override
  String get rangeWeeksEvenHint => '범위 내 짝수 주만 유지합니다.';

  @override
  String get selectAllAction => '전체 선택';

  @override
  String get selectOddWeeksAction => '홀수 주';

  @override
  String get selectEvenWeeksAction => '짝수 주';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '$count주 선택: 제$weeks주';
  }

  @override
  String get courseColorTitle => '수업 색상';

  @override
  String get customPaletteAction => '팔레트에서 사용자 정의';

  @override
  String get colorPaletteTitle => '색상 팔레트';

  @override
  String get colorHexLabel => '색상 Hex';

  @override
  String get weekdayMon => '월요일';

  @override
  String get weekdayTue => '화요일';

  @override
  String get weekdayWed => '수요일';

  @override
  String get weekdayThu => '목요일';

  @override
  String get weekdayFri => '금요일';

  @override
  String get weekdaySat => '토요일';

  @override
  String get weekdaySun => '일요일';

  @override
  String hueLabel(int value) {
    return '색상 $value';
  }

  @override
  String saturationLabel(int value) {
    return '채도 $value%';
  }

  @override
  String brightnessLabel(int value) {
    return '명도 $value%';
  }

  @override
  String get useThisColor => '이 색상 사용';

  @override
  String get selectAtLeastOneWeek => '최소 1개의 수업 주차를 선택하세요';

  @override
  String get saveFailed => '저장 실패';

  @override
  String get courseAddedSuccess => '수업 추가 성공';

  @override
  String get courseUpdatedSuccess => '수업 업데이트 성공';

  @override
  String get aboutTitle => '앱 정보';

  @override
  String get loadingText => '불러오는 중';

  @override
  String versionLabel(String version) {
    return '버전 $version';
  }

  @override
  String get aboutHeroSubtitle =>
      '시간표 조회, 수업 알림, HyperOS 슈퍼아일랜드 경험에 집중한 Android 오픈소스 프로젝트.';

  @override
  String get platformLabel => '플랫폼';

  @override
  String get focusLabel => '중점';

  @override
  String get updateLabel => '업데이트';

  @override
  String get prereleaseIncluded => '시험판 포함';

  @override
  String get stableOnly => '정식판';

  @override
  String get aboutUpdatesTitle => '버전 업데이트';

  @override
  String get aboutUpdatesSubtitle => '업데이트 확인, 다운로드, 테스트 및 진단 항목';

  @override
  String get aboutChangelogTitle => '업데이트 로그';

  @override
  String get aboutChangelogSubtitle => '모든 버전의 업데이트 내용 확인';

  @override
  String get aboutPositioningTitle => '프로젝트 정체성';

  @override
  String get aboutPositioningSubtitle => '이것이 무엇인지, 누구를 위한 것인지, 핵심 역량은 무엇인지';

  @override
  String get aboutPositioningBullet1 => '주간 시간표 뷰, 수업 CRUD, .ics 가져오기 지원';

  @override
  String get aboutPositioningBullet2 =>
      '대응 학교의 교무 시스템 웹 로그인 가져오기 및 전체 백업 마이그레이션 지원';

  @override
  String get aboutPositioningBullet3 =>
      '실시간 알림 지원. HyperOS 3.0.300부터 슈퍼아일랜드/포커스 알림 표시 지원';

  @override
  String get aboutPositioningBullet4 =>
      '다중 시간표, 시간 템플릿, 테마 색상 및 카드 스타일 커스터마이즈 지원';

  @override
  String get aboutImportMigrationTitle => '가져오기 및 마이그레이션';

  @override
  String get aboutImportMigrationSubtitle => '현재 가져오기 방법, 백업 복원 및 마이그레이션 권장사항';

  @override
  String get aboutImportMigrationBullet1 =>
      '현재 버전은 대응 학교의 교무 시스템 웹 로그인 가져오기를 지원합니다. \'수업 가져오기 > 교무 시스템 가져오기\'에서 학교와 어댑터를 선택하세요.';

  @override
  String get aboutImportMigrationBullet2 =>
      '사용하는 학교가 아직 미대응인 경우, WakeUp 등 시간표 앱에서 수업을 가져온 뒤 캘린더 형식으로 내보내고 본 앱에서 가져올 수 있습니다.';

  @override
  String get aboutImportMigrationBullet3 =>
      '다른 사용자가 이미 본 앱을 사용 중인 경우, 전체 백업 파일을 내보내어 \'데이터 백업 및 마이그레이션\'에서 가져오면 바로 복원됩니다.';

  @override
  String get aboutImportMigrationBullet4 =>
      '패킷 캡처, 웹 디버깅, JavaScript를 할 수 있다면, qingyu_warehouse에서 교무 적응 보충에 참여해 주세요.';

  @override
  String get aboutContributorsTitle => '코드 기여자';

  @override
  String get aboutContributorsSubtitle => '개발자 및 교무 가져오기 적응자 목록';

  @override
  String get aboutRepositoryTitle => '오픈소스 저장소';

  @override
  String get aboutAppLogsTitle => '앱 로그';

  @override
  String get aboutAppLogsSubtitle =>
      'error / warn / info / debug / verbose 전 레벨의 로그 확인';

  @override
  String get appLogsShareText =>
      '경屿 시간표가 내보낸 앱 로그입니다. 로컬 실행 기록을 포함하며, 업데이트, 가져오기, 알림, 페이지, 충돌 문제의 트러블슈팅에 사용할 수 있습니다.';

  @override
  String get appLogsShareSubject => '경屿 시간표 - 앱 로그';

  @override
  String get appLogsRecordingEnabled => '앱 로그 기록 중';

  @override
  String get appLogsRecordingDisabled => '앱 로그 기록 꺼짐';

  @override
  String get appLogsCopyAction => '로그 복사';

  @override
  String get appLogsCopied => '현재 로그를 복사했습니다';

  @override
  String get appLogsExportAction => '로그 내보내기';

  @override
  String get appLogsClearAction => '로그 비우기';

  @override
  String get appLogsCleared => '앱 로그를 비웠습니다';

  @override
  String get appLogsClearFailed => '앱 로그 비우기 실패';

  @override
  String get appLogsSourceApp => '应用';

  @override
  String get appLogsSourceNative => '超级岛';

  @override
  String get appLogsRecordingPausedHint => '记录已关闭。下方为历史日志，关闭后不再新增。';

  @override
  String get aboutRepositorySubtitle => 'GitHub 저장소, 소스, Release 및 피드백';

  @override
  String get timeSchemeTitle => '시간 템플릿';

  @override
  String get newSchemeTooltip => '새 템플릿';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections교시 · $profiles개 시간표 · $courses건 수업 · $overrideCourses건 부 템플릿';
  }

  @override
  String get viewUsageAction => '사용 현황 확인';

  @override
  String get applyToCurrentTimetable => '현재 시간표에 적용';

  @override
  String get editSectionsAction => '교시 편집';

  @override
  String get createTimeSchemeTitle => '새 템플릿';

  @override
  String get timeSchemeNameLabel => '템플릿 이름';

  @override
  String get timeSchemeNameHint => '예: 본교 하절기 시간표';

  @override
  String get renameTimeSchemeTitle => '템플릿 이름 변경';

  @override
  String renamedToMessage(String name) {
    return '이름 변경됨: $name';
  }

  @override
  String get deleteTimeSchemeTitle => '템플릿 삭제';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '\"$name\"을(를) 삭제하시겠습니까? 사용 중인 템플릿은 삭제할 수 없습니다.';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return '템플릿 삭제됨: $name';
  }

  @override
  String get timeSchemeInUseMessage => '이 템플릿은 시간표에서 사용 중입니다';

  @override
  String get copiedTimeSchemeMessage => '템플릿을 복사했습니다';

  @override
  String appliedTimeSchemeMessage(String name) {
    return '템플릿 적용됨: $name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '\"$name\"의 사용 현황';
  }

  @override
  String get timeSchemeUsageIntro =>
      '먼저 전체 영향 범위를 확인한 뒤, 직접 편집할지 복사 후 변경할지 결정하세요.';

  @override
  String get profileCountLabel => '시간표';

  @override
  String get courseCountLabel => '수업';

  @override
  String get overrideTimeSchemeLabel => '부 템플릿';

  @override
  String get directlyBoundProfilesTitle => '이 템플릿에 직접 바인딩된 시간표';

  @override
  String get directlyBoundProfilesEmpty => '현재 이 템플릿을 직접 사용하는 시간표가 없습니다.';

  @override
  String get directlyBoundProfilesSubtitle =>
      '이 시간표들은 이 템플릿으로 전환 후 이 교시 시간으로 표시됩니다.';

  @override
  String get followMainSchemeCoursesTitle => '메인 템플릿에 연동되는 수업';

  @override
  String get followMainSchemeCoursesEmpty => '현재 메인 템플릿 경유로 사용하는 수업이 없습니다.';

  @override
  String get followMainSchemeCoursesSubtitle =>
      '이 수업들은 부 템플릿을 개별 설정하지 않고 소속 시간표와 함께 이 템플릿을 사용합니다.';

  @override
  String get overrideSchemeCoursesTitle => '부 템플릿으로 사용하는 수업';

  @override
  String get overrideSchemeCoursesEmpty => '현재 이 템플릿을 부 템플릿으로 사용하는 수업이 없습니다.';

  @override
  String get overrideSchemeCoursesSubtitle =>
      '이 수업들은 소속 시간표의 메인 템플릿이 변경되어도 이 템플릿을 개별 사용합니다.';

  @override
  String get closeAction => '닫기';

  @override
  String get editTimeSchemeTitle => '템플릿 편집';

  @override
  String get backToSchemeList => '템플릿 목록으로';

  @override
  String get currentInUse => '현재 사용 중';

  @override
  String get quickGenerateAction => '빠른 생성';

  @override
  String get addSectionAction => '교시 추가';

  @override
  String get removeLastSectionAction => '마지막 교시 삭제';

  @override
  String get resetDefaultAction => '기본값 복원';

  @override
  String get sectionTimesTitle => '교시 시간';

  @override
  String get sectionTimesSubtitle =>
      '현재 시간표가 이 템플릿을 사용 중이면, 교시 수는 사용된 최대 교시 이상이어야 합니다.';

  @override
  String get schemeListCurrentLabel => '현재';

  @override
  String get schemeListCountLabel => '수';

  @override
  String get sectionCountLabel => '교시 수';

  @override
  String get quickGenerateTimeSchemeTitle => '시간표 시간 빠른 생성';

  @override
  String get addBreakRuleAction => '대휴식 규칙 추가';

  @override
  String get afterSectionLabel => '몇 교시 뒤';

  @override
  String get breakDurationMinutesLabel => '휴식 시간(분)';

  @override
  String get fillNumbersValidationMessage => '교시 수와 시간을 숫자로 입력하세요';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '현재 시간표와 일부 수업이 이 템플릿을 사용 중입니다. 저장 후 관련된 모든 시간표와 수업이 동기화됩니다.';

  @override
  String get timeSchemeEditorActiveHint =>
      '현재 시간표가 이 템플릿을 사용 중입니다. 저장 후 사용 중인 모든 시간표가 동기화됩니다.';

  @override
  String get timeSchemeEditorOverrideHint =>
      '수업이 이 템플릿을 부 템플릿으로 사용 중입니다. 저장 후 참조하는 모든 수업이 동기화됩니다.';

  @override
  String get editTimeAction => '시간 편집';

  @override
  String editingSchemeLabel(String name) {
    return '편집 중: $name';
  }

  @override
  String get copiedTimeSchemeShortMessage => '템플릿을 복사했습니다';

  @override
  String get unnamedTimeScheme => '이름 없는 템플릿';

  @override
  String get unsetLabel => '미선택';

  @override
  String get timeSchemeUsageCourseRefPrefix => '수업 참조:';

  @override
  String get mainTimeSchemeLabel => '메인 템플릿';

  @override
  String get overrideTimeSchemeShortLabel => '부 템플릿';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$first 외 $count건 수업';
  }

  @override
  String get morningSectionCountLabel => '오전 교시 수';

  @override
  String get morningFirstSectionTimeLabel => '오전 1교시 시작 시간';

  @override
  String get afternoonSectionCountLabel => '오후 교시 수';

  @override
  String get afternoonFirstSectionTimeLabel => '오후 1교시 시작 시간';

  @override
  String get eveningSectionCountLabel => '야간 교시 수';

  @override
  String get eveningFirstSectionTimeLabel => '야간 1교시 시작 시간';

  @override
  String get classDurationMinutesLabel => '1교시 길이(분)';

  @override
  String get smallBreakDurationMinutesLabel => '소휴식 시간(분)';

  @override
  String get largeBreakRulesTitle => '대휴식 규칙';

  @override
  String get noLargeBreakRulesHint => '대휴식 규칙 미설정. 모두 소휴식 시간이 사용됩니다.';

  @override
  String get deleteRuleTooltip => '규칙 삭제';

  @override
  String get generateAction => '생성';

  @override
  String get liveSettingsTitle => '슈퍼아일랜드 및 알림';

  @override
  String get liveReminderTimingEntryTitle => '알림 시간대';

  @override
  String get liveReminderTimingEntrySubtitle =>
      '수업 전/수업 중/종료 알림 스위치, 종료 전 슈퍼아일랜드/포커스 알림 전환 시점';

  @override
  String get liveBeforeClassDisplayEntryTitle => '수업 전 알림 표시';

  @override
  String get liveDuringEndDisplayEntryTitle => '수업 중/종료 알림 표시';

  @override
  String get liveKeepAliveEntryTitle => '백그라운드 상주';

  @override
  String get liveKeepAliveEntrySubtitle => '숨김, 백그라운드 상주 보조 서비스 및 권한 항목';

  @override
  String get liveTestingEntryTitle => '테스트 및 진단';

  @override
  String get liveTestingEntrySubtitle => '테스트 알림 전송, 슈퍼아일랜드 및 로컬 진단 로그 확인';

  @override
  String get followBeforeClassSetting => '수업 전 알림에 연동';

  @override
  String get liveReminderTimingTitle => '알림 시간대';

  @override
  String get liveReminderSwitchesTitle => '알림 스위치';

  @override
  String get liveReminderSwitchesSubtitle =>
      '서로 다른 알림 시간대를 자유롭게 조합할 수 있습니다. 이 스위치들은 서로 대체하지 않습니다.';

  @override
  String get beforeClassReminderTitle => '수업 전 알림';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '수업 시작 $minutes분 전에 팝업';
  }

  @override
  String get duringClassReminderTitle => '수업 중/종료 알림';

  @override
  String get duringClassReminderSubtitle => '수업 시작 후부터 종료 전까지의 표시에만 영향';

  @override
  String get liveClassReminderLeadTitle => '종료 전 슈퍼아일랜드/포커스 알림 전환 시점';

  @override
  String get liveClassReminderLeadOptionImmediate => '수업 시작과 동시에 전환';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '종료 $minutes분 전에 전환';
  }

  @override
  String get liveDisplayModeTitle => '표시 모드';

  @override
  String get liveDisplayModeSubtitle => '활성화된 알림 시간대에 적용됩니다.';

  @override
  String get duringClassStatusNotificationTitle => '수업 중 상태바 알림';

  @override
  String get duringClassStatusNotificationImmediate => '수업 시작 후에도 상태바 알림 유지';

  @override
  String get duringClassStatusNotificationBeforeEnd =>
      '종료 알림 시작 전까지 일반 알림 텍스트 유지';

  @override
  String get duringClassStatusNotificationPersistent =>
      '수업 시작 후 일반 수업 중 알림을 계속 표시하고 종료 알림 전에 전환';

  @override
  String get enableIslandDisplayTitle => '슈퍼아일랜드/다이내믹아일랜드 표시 지원';

  @override
  String get enableIslandDisplaySubtitle => '끄면 시스템 슈퍼아일랜드 트리거를 중단합니다';

  @override
  String get liveTimeThresholdTitle => '시간 임계값';

  @override
  String get liveTimeThresholdSubtitle =>
      '수업 전 팝업, 종료 전 슈퍼아일랜드/포커스 알림 전환, 초 단위 카운트다운을 제어합니다.';

  @override
  String get beforeClassPopupLabel => '수업 전 팝업 시간';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes분';
  }

  @override
  String get beforeEndSecondsLabel => '종료 전 초 단위 알림 임계값';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds초';
  }

  @override
  String timeCorrectionLabel(String value) {
    return '종 시간 보정: $value';
  }

  @override
  String get timeCorrectionHelp =>
      '학교 종이 시간표보다 몇 초 빠르면 \'앞당기기\', 느리면 \'늦추기\'로 설정하세요.';

  @override
  String get duringEndTimeDisplayLabel => '수업 중/종료 알림 시간 스타일';

  @override
  String get duringEndTimeDisplayHelp =>
      '컴팩트 알림에서 최근 시간을 표시할지 전체 총 시간을 표시할지 제어합니다.';

  @override
  String get liveDisplayContentTitle => '표시 내용';

  @override
  String get liveDisplayContentSubtitle =>
      '이 설정 그룹은 현재 스테이지에만 영향을 주며, 다른 알림 표시는 변경하지 않습니다.';

  @override
  String get showCourseNameTitle => '수업명 표시';

  @override
  String get preferShortNameTitle => '약칭 우선 표시';

  @override
  String get preferShortNameSubtitle => '약칭은 3자 이내를 권장합니다';

  @override
  String get showLocationTitle => '장소 표시';

  @override
  String get showCountdownTitle => '카운트다운 표시';

  @override
  String get countdownFormatLabel => '카운트다운 형식';

  @override
  String get countdownFormatHelp => '분만 표시는 분 단위로, 초 포함 표시는 초 단위로 갱신됩니다';

  @override
  String get showStageTextTitle => '스테이지 상태 텍스트 표시';

  @override
  String get showStageTextSubtitle =>
      '카운트다운 끈 후에도 \'곧 수업/수업 중/종료 알림\'을 계속 표시할 수 있습니다';

  @override
  String get hidePrefixTextTitle => '접두사 텍스트 숨기기';

  @override
  String get hidePrefixTextSubtitle => '예: \'곧 수업\' 같은 접두사를 숨기기';

  @override
  String get beforeClassQuickActionTitle => '수업 전 빠른 작업';

  @override
  String get beforeClassQuickActionSubtitle =>
      '수업 전 알림의 펼친 알림에만 표시됩니다. 무음/방해 금지는 수업 종료 후와 재부팅 후 자동 복원됩니다. 방해 금지 모드 첫 실행 시 시스템 인증 페이지로 이동할 수 있습니다.';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '왼쪽 아이콘 및 펼친 상태';

  @override
  String get liveIslandVisualSubtitle =>
      '왼쪽 텍스트 이미지, 펼친 상태 큰 아이콘, 사용자 정의 이미지는 모두 현재 스테이지별로 개별 저장됩니다.';

  @override
  String get liveMiuiLabelImageTitle => '샤오미 아일랜드 왼쪽 텍스트 아이콘';

  @override
  String get liveMiuiLabelImageSubtitle =>
      '샤오미 기기 스타일에서만 유효합니다. 수업명 또는 장소를 왼쪽 아이콘 위치에 생성합니다.';

  @override
  String get liveMiuiLabelContentLabel => '왼쪽 텍스트 내용';

  @override
  String get liveMiuiLabelStyleLabel => '왼쪽 아이콘 스타일';

  @override
  String get liveMiuiLabelLogoTitle => '왼쪽 아이콘 로고';

  @override
  String get liveMiuiLabelLogoSubtitle =>
      '\'아이콘+텍스트\' 스타일에서만 유효합니다. 미선택 시 앱 아이콘을 계속 사용합니다.';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '왼쪽 아이콘 둥근 모서리 $value';
  }

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '왼쪽 텍스트 크기 $value';
  }

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '왼쪽 텍스트 수평 오프셋 $value';
  }

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '왼쪽 텍스트 수직 오프셋 $value';
  }

  @override
  String get liveMiuiLabelFontWeightLabel => '왼쪽 텍스트 굵기';

  @override
  String get liveMiuiLabelRenderQualityLabel => '왼쪽 텍스트 선명도';

  @override
  String get liveMiuiExpandedIconLabel => '펼친 상태 큰 아이콘';

  @override
  String get selectImageAction => '이미지 선택';

  @override
  String get replaceImageAction => '이미지 변경';

  @override
  String get liveDisplayConfigModeTitle => '설정 모드';

  @override
  String get liveDisplayConfigModeSubtitle =>
      '켜면 수업 중 및 종료 알림이 수업 전 알림 표시를 완전히 따릅니다. 아래 개별 설정은 일시적으로 편집할 수 없습니다.';

  @override
  String get followBeforeClassDisplayTitle => '수업 전 알림 설정에 연동';

  @override
  String get liveKeepAliveTitle => '백그라운드 상주';

  @override
  String get liveKeepAliveOptionsTitle => '상주 옵션';

  @override
  String get liveKeepAliveOptionsSubtitle => '슈퍼아일랜드와 알림의 백그라운드 안정성을 향상시킵니다.';

  @override
  String get hideFromRecentsTitle => '최근 작업에서 앱 숨기기';

  @override
  String get hideFromRecentsSubtitle => '켜면 최근 작업 목록에 표시되지 않도록 합니다.';

  @override
  String get keepAliveServiceTitle => '경屿 시간표 백그라운드 상주 서비스';

  @override
  String get keepAliveServiceEnabledSubtitle =>
      '현재 켜짐. 시스템이 백그라운드 상주 보조 서비스를 사용 가능한 상태로 유지합니다.';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '현재 꺼짐. 시스템 접근성 설정에서 수동으로 켤 수 있습니다.';

  @override
  String get goEnableAction => '활성화하기';

  @override
  String get layoutEntryTitle => '레이아웃 및 교시';

  @override
  String get layoutEntrySubtitle => '교시 시간, 행 높이, 시간 열, 주말 표시 및 카드 레이아웃';

  @override
  String get remindersSectionTitle => '알림 및 푸시';

  @override
  String get liveGuideEntryTitle => '사용 가이드 및 권한';

  @override
  String get liveGuideEntrySubtitle => '약칭 설정, 알림, 자동 시작, 배터리 전략';

  @override
  String get managementSectionTitle => '시간표 관리';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '현재: $name · 전환, 교시 편집 및 복사';
  }

  @override
  String get timeSchemeEntrySubtitle => '전환, 교시 편집, 복사 및 템플릿 관리';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '현재 제$current주 / 총 $total주';
  }

  @override
  String get semesterStartUnset => '학기 시작일 미설정';

  @override
  String semesterStartSet(String date) {
    return '학기 시작일: $date';
  }

  @override
  String get setSemesterStartDate => '학기 시작일 설정';

  @override
  String get semesterStartDateLabel => '학기 시작일';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '제$week주에 동기화됨';
  }

  @override
  String get pickSemesterWeekCountTitle => '학기 주 수 선택';

  @override
  String get pickSemesterWeekCountSubtitle =>
      '학교에 따라 실제 수업 주 수에 맞게 조정할 수 있습니다.';

  @override
  String weekCountItem(int count) {
    return '$count주';
  }

  @override
  String get diagnosticsLogIntro =>
      'Markdown과 원본 두 가지 보기 방식을 지원합니다. 트러블슈팅 시 스마트폰에서 전체 로그를 직접 확인할 수 있습니다.';

  @override
  String get diagnosticsRawTab => '원본';

  @override
  String get diagnosticsStructuredTab => '구조화';

  @override
  String get diagnosticsLevelLabel => '레벨';

  @override
  String get diagnosticsLevelAll => '전체';

  @override
  String get diagnosticsLevelError => '오류';

  @override
  String get diagnosticsLevelWarn => '경고';

  @override
  String get diagnosticsLevelInfo => '정보';

  @override
  String get diagnosticsLevelDebug => '디버그';

  @override
  String get diagnosticsLevelVerbose => '상세';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '$shown / $total건 로그 표시';
  }

  @override
  String get diagnosticsNoMatchingTitle => '현재 필터에 일치하는 로그 없음';

  @override
  String get diagnosticsNoMatchingSubtitle =>
      '\'전체\'로 전환하거나 원본으로 트러블슈팅을 계속하세요.';

  @override
  String get diagnosticsLevelInferred => '추정 레벨';

  @override
  String get diagnosticsRawFilteredHint =>
      '원본 뷰는 현재 레벨 필터에 연동되어 해당 로그 블록만 표시합니다.';

  @override
  String get diagnosticsEmptyTitle => '로그 없음';

  @override
  String get diagnosticsEmptySubtitle => '현재 표시할 수 있는 슈퍼아일랜드 진단 로그가 없습니다.';

  @override
  String get diagnosticsLogTitleFallback => '슈퍼아일랜드 진단 로그';

  @override
  String get diagnosticsDeviceInfoTitle => '기기 및 내보내기 정보';

  @override
  String get diagnosticsContentTitle => '로그 내용';

  @override
  String get diagnosticsRecentLogsTitle => '최근 로그';

  @override
  String get diagnosticsUnknownCategory => '미분류 이벤트';

  @override
  String get diagnosticsExportedAt => '내보내기 시간';

  @override
  String get diagnosticsTime => '시간';

  @override
  String get diagnosticsCategory => '카테고리';

  @override
  String get diagnosticsMessage => '메시지';

  @override
  String get diagnosticsStackTrace => '스택 트레이스';

  @override
  String get firstUseGuideTitle => '첫 사용 가이드';

  @override
  String get guideAndPermissionsTitle => '사용 가이드 및 권한';

  @override
  String get refreshStatusTooltip => '상태 새로고침';

  @override
  String get guideHeroTitle => '먼저 이 페이지를 완료하세요';

  @override
  String get guideHeroSubtitle =>
      '먼저 첫 화면에서 인증하세요. 아래에 시스템 버전 지원, 약칭 설정, 가져오기 방법이 설명되어 있습니다. 스크롤을 계속하세요.';

  @override
  String get guideChipPermissions => '권한 준비';

  @override
  String get guideChipShortName => '약칭 설정';

  @override
  String get guideChipImport => '수업 가져오기';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 완료';
  }

  @override
  String get guideBottomReachedHint => '마지막까지 스크롤했습니다. 확인 후 바로 시작할 수 있습니다.';

  @override
  String get guideScrollHint =>
      '아래로 스크롤하여 계속하세요. HyperOS 버전 설명, 권한 목록, 약칭 설정, 가져오기 방법이 있습니다.';

  @override
  String get guideRequestNotificationFirst => '먼저 알림 권한 요청';

  @override
  String get quickSetupTitle => '첫 화면 빠른 설정';

  @override
  String get quickSetupSubtitle => '가장 중요한 5개 항목을 먼저 배치합니다. 아래까지 스크롤할 필요 없이.';

  @override
  String get quickActionNotificationsTitle => '알림 설정';

  @override
  String get quickActionNotificationsSubtitle => '먼저 알림 전송 가능 확인';

  @override
  String get quickActionIslandTitle => '슈퍼아일랜드 권한';

  @override
  String get quickActionIslandSubtitle => 'promoted 알림 확인';

  @override
  String get quickActionAutoStartTitle => '자동 시작';

  @override
  String get quickActionAutoStartSubtitle => '백그라운드 종료 방지';

  @override
  String get quickActionBatteryTitle => '배터리 제한 없음';

  @override
  String get quickActionBatterySubtitle => '알림 중단 방지';

  @override
  String get quickActionKeepAliveTitle => '백그라운드 상주 보조';

  @override
  String get quickActionKeepAliveSubtitle => '백그라운드 안정성 향상';

  @override
  String get guidePrivacyConsentLabel => 'Umeng 관련 개인정보 처리방침을 읽고 동의합니다';

  @override
  String get guideRequireConsentHint => '먼저 아래로 스크롤하여 설명을 읽고, 동의에 체크한 후 시작하세요.';

  @override
  String get guideContinueHint => '아래로 스크롤하여 전체 가이드 내용을 확인하세요.';

  @override
  String get exitAppAction => '앱 종료';

  @override
  String get continueReadingAction => '계속 보기';

  @override
  String get agreeAndStartAction => '동의하고 시작';

  @override
  String get startUsingAction => '시작하기';

  @override
  String get editSingleLessonTitle => '단일 수업 편집';

  @override
  String get editCourseTitle => '수업 편집';

  @override
  String get addSingleLessonTitle => '단일 수업 추가';

  @override
  String get addCourseTitle => '수업 추가';

  @override
  String get deleteCourseTitle => '수업 삭제';

  @override
  String get courseDeleted => '수업이 삭제되었습니다';

  @override
  String get addMethodTitle => '추가 방법';

  @override
  String get singleLessonLabel => '단일 수업';

  @override
  String get recurringLessonLabel => '반복 수업';

  @override
  String get singleLessonHint => '보충 수업, 임시 추가에 적합합니다. 수업은 한 주차에만 표시됩니다.';

  @override
  String get recurringLessonHint => '같은 시간에 매주 연속하는 정규 수업에 적합합니다.';

  @override
  String get sharedInfoTitle => '공유 정보';

  @override
  String get sharedInfoHint => '공유 필드 설명 보기';

  @override
  String get sharedInfoSheetItemCourseName =>
      '수업명: 수업 고유 식별자. 동일한 이름의 여러 배치는 하나의 수업으로 처리됩니다. 이름을 변경하면 별도 수업 기록이 생성됩니다.';

  @override
  String get sharedInfoSheetItemShortName =>
      '수업 약칭: 슈퍼아일랜드 등 간략 표시에 사용. 수동 입력 필요, 자동 생성되지 않음. 「수업 약칭 우선 표시」 활성화 시 적용. 3자 이내 권장.';

  @override
  String get sharedInfoSheetItemSharedSync =>
      '공유 동기화: 약칭, 색상, 성격, 개요 등은 동일 수업명의 다른 배치에 동기화됩니다.';

  @override
  String get reuseExistingCourseLabel => '기존 수업 활용';

  @override
  String get reuseExistingCourseHelper =>
      '기존 수업을 선택하면 수업명, 교사와 기타 공유 정보가 자동 입력됩니다';

  @override
  String get manualInputLabel => '수동 입력';

  @override
  String get noTemplateCoursesHint =>
      '현재 시간표에 수업이 없습니다. 먼저 1개를 수동으로 등록하면 이후 임시 추가 시 바로 선택할 수 있습니다.';

  @override
  String get courseNameLabel => '수업명';

  @override
  String get courseNameHelper =>
      '수업 고유 식별자입니다. 동일한 이름의 배치는 하나의 수업으로 통합됩니다. 공식 전체 명칭을 입력하고, 표시 목적의 약칭은 사용하지 마세요.';

  @override
  String get pleaseEnterCourseName => '수업명을 입력하세요';

  @override
  String get courseShortNameOptional => '수업 약칭';

  @override
  String get courseShortNameHelper =>
      '슈퍼아일랜드 등 간략 표시에 권장. 약칭은 자동 생성되지 않으며 「수업 약칭 우선 표시」 활성화 시 적용. 3자 이내 권장.';

  @override
  String get courseShortNameAutoFillAction => '앞 2자';

  @override
  String get teacherLabel => '담당 교사';

  @override
  String get courseNatureLabel => '수업 성격';

  @override
  String get courseDescriptionOptional => '수업 개요 (선택)';

  @override
  String get currentScheduleHint =>
      '여기의 요일, 교시, 강의실, 주차 및 홀짝주는 이 배치에만 영향을 줍니다.';

  @override
  String followProfileTimeScheme(String name) {
    return '현재 시간표에 연동 ($name)';
  }

  @override
  String get timeSchemeOverrideLabel => '수업 시간 방안';

  @override
  String get lessonWeeksTitle => '수업 주차';

  @override
  String get singleLessonWeekHint =>
      '단일 수업은 한 주차에만 나타납니다. 보충 수업이나 임시 추가에 적합합니다.';

  @override
  String get rangeWeekLabel => '연속 주';

  @override
  String get customWeekLabel => '사용자 정의 주';

  @override
  String get allWeeksLabel => '전체';

  @override
  String get oddWeeksLabel => '홀수 주';

  @override
  String get evenWeeksLabel => '짝수 주';

  @override
  String get allWeeksHint => '시작 주부터 종료 주까지 연속으로 수업을 배치합니다.';

  @override
  String get oddWeeksHint => '범위 내 홀수 주만 유지합니다.';

  @override
  String get evenWeeksHint => '범위 내 짝수 주만 유지합니다.';

  @override
  String get customPaletteColor => '팔레트에서 사용자 정의';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$count세트';
  }

  @override
  String profileCountValue(int count) {
    return '$count개';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count건';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$start부터';
  }

  @override
  String get weekdayShortMonday => '월';

  @override
  String get weekdayShortTuesday => '화';

  @override
  String get weekdayShortWednesday => '수';

  @override
  String get weekdayShortThursday => '목';

  @override
  String get weekdayShortFriday => '금';

  @override
  String get weekdayShortSaturday => '토';

  @override
  String get weekdayShortSunday => '일';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '$weekday요일 $startSection-$endSection교시';
  }

  @override
  String timeSchemeUsageReference(
    String profileName,
    String courseName,
    String weekday,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return '$profileName · $courseName（$weekday요일 $startSection-$endSection교시, $usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekday요일 $startSection-$endSection교시';
  }

  @override
  String get timeRangeValidationNoCrossDay => '종료 시간은 시작 시간보다 나중이어야 합니다';

  @override
  String get timeSchemeNameEmptyValidation => '템플릿 이름은 비워둘 수 없습니다';

  @override
  String get liveTimeCorrectionNone => '보정 없음';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '전체를 $seconds초 늦추기';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '전체를 $seconds초 앞당기기';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '수업 시작과 동시에 포커스 알림 표시로 전환하고, 종료 $seconds초 전에 초 단위 카운트다운으로 전환';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '수업 후 먼저 일반 수업 중 알림을 유지하고, 종료 $minutes분 전에 포커스/종료 알림으로 전환, 마지막 $seconds초에 초 단위 카운트다운으로 전환';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '종료 $minutes분 전에 슈퍼아일랜드/포커스 알림으로 전환, 마지막 $seconds초에 초 단위 카운트다운으로 전환';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '종료 $minutes분 전에 포커스 알림 표시를 시작하고, 마지막 $seconds초에 초 단위 카운트다운으로 전환';
  }

  @override
  String get liveSettingsEntrySubtitle => '알림 시간대, 아일랜드 표시, 알림바 및 표시 내용';

  @override
  String get timetableProfilesEntrySubtitle => '새로 만들기, 전환, 복사, 이름 변경 및 삭제';

  @override
  String get homeTitleSectionTitle => '홈 제목';

  @override
  String get homeTitleSectionSubtitle => '홈 왼쪽 위 시간표 전환 항목의 스타일을 제어합니다.';

  @override
  String get homeTitleStyleLabel => '제목 스타일';

  @override
  String get themeSeedSectionTitle => '앱 테마 색상';

  @override
  String get themeSeedSectionSubtitle => '상단 바, 강조색 및 전반적인 주色调에 영향을 줍니다.';

  @override
  String get frostedSheetSectionTitle => '弹窗磨砂玻璃';

  @override
  String get frostedSheetSectionSubtitle =>
      '调节首页弹出面板的高斯模糊强度与磨砂亮度。滑块越靠右，白色磨砂层越明显。';

  @override
  String get frostedBlurEnabledTitle => '高斯模糊';

  @override
  String get frostedBlurEnabledSubtitle =>
      '关闭后，弹窗、首页模糊区域与「回本周」按钮仅保留半透明底色，不再采样模糊。';

  @override
  String get frostedSheetPreviewOpenAction => '打开弹窗预览';

  @override
  String get frostedSheetPreviewDemoTitle => '弹窗预览';

  @override
  String get frostedSheetPreviewDemoSubtitle => '与首页右上角菜单相同的磨砂玻璃效果。';

  @override
  String get frostedSheetBlurLabel => '模糊强度';

  @override
  String get frostedSheetTintLabel => '磨砂亮度';

  @override
  String get timetableBackgroundColorSectionTitle => '시간표 배경색';

  @override
  String get timetableBackgroundColorSectionSubtitle =>
      '시간표 페이지의 큰 배경에만 적용됩니다.';

  @override
  String get homePageBackgroundFillLabel => '背景填充';

  @override
  String get homePageBackgroundFillColor => '纯色';

  @override
  String get homePageBackgroundFillImage => '图片';

  @override
  String get homePageBackgroundImageTitle => '背景图';

  @override
  String get homePageBackgroundImageSubtitle => '在「图片」模式下，作用于下方勾选的显示区域。';

  @override
  String get homePageWallpaperTitle => '背景图片';

  @override
  String get homePageWallpaperSubtitle => '全屏铺底一张图；勾选下方区域决定透出范围，未勾选区域仍显示课表背景色。';

  @override
  String get homePageBackdropFollowsWeekPagerTitle => '背景随周次滑动';

  @override
  String get homePageBackdropFollowsWeekPagerSubtitle =>
      '左右切换周次时，背景图与课表页面一起移动。';

  @override
  String get homePageBackgroundScopeTitle => '背景显示区域';

  @override
  String get homePageBackgroundScopeSubtitle =>
      '从上到下依次控制各区域是否透出背景图；未勾选区域仍显示课表背景色。';

  @override
  String get homePageBackgroundScopeStatusBar => '状态栏';

  @override
  String get homePageBackgroundScopeTimetable => '课表区域';

  @override
  String get homePageBackgroundScopeWeekdayBar => '信息栏';

  @override
  String get homePageBackgroundScopeHeader => '顶栏';

  @override
  String get homePageHeaderBlurTitle => '顶栏高斯模糊';

  @override
  String get homePageHeaderBlurSubtitle => '模糊标题栏（轻屿课表）区域；勾选「状态栏」时一并模糊状态栏。';

  @override
  String get homePageWeekdayBarBlurTitle => '信息栏高斯模糊';

  @override
  String get homePageWeekdayBarBlurSubtitle => '模糊周次与星期信息栏，透出下方背景图。';

  @override
  String get homePageTimeColumnBlurTitle => '时间栏高斯模糊';

  @override
  String get homePageTimeColumnBlurSubtitle => '模糊左侧节次/时间列，透出下方背景图。';

  @override
  String get homePageRegionBlurSectionSubtitle => '需配合背景图使用；模糊强度跟随「弹窗磨砂玻璃」设置。';

  @override
  String get homePagePickImageAction => '选择图片';

  @override
  String get homePageClearImageAction => '清除图片';

  @override
  String get homePageImageNotSelected => '未选择';

  @override
  String get appearanceTextColorsSectionTitle => '文字颜色';

  @override
  String get appearanceTextColorsSectionSubtitle => '自定义课程卡片、星期栏与时间轴文字颜色。';

  @override
  String get defaultTimetablePreviewName => '기본 시간표';

  @override
  String get beforeClassDisplaySettingsTitle => '수업 전 알림 표시';

  @override
  String get duringEndDisplaySettingsTitle => '수업 중/종료 알림 표시';

  @override
  String get liveDisplaySummaryShortName => '약칭';

  @override
  String get liveDisplaySummaryCourseName => '수업명';

  @override
  String get liveDisplaySummaryLocation => '장소';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return '카운트다운（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => '스테이지 텍스트';

  @override
  String get liveDisplaySummaryLeftLabelImage => '아이콘';

  @override
  String get liveDisplaySummaryMinimal => '최소 표시';

  @override
  String get liveDisplaySummaryCountdownShort => '카운트다운';

  @override
  String liveDisplaySummaryMore(String first, int count) {
    return '$first 외 $count개';
  }

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '현재 상태';

  @override
  String get guideStatusNotificationPermission => '알림 권한';

  @override
  String get guideStatusEnabled => '활성화됨';

  @override
  String get guideStatusDisabled => '비활성화됨';

  @override
  String get guideStatusIslandSupport => '포커스 알림 / 슈퍼아일랜드';

  @override
  String get guideStatusSystemAllowed => '시스템 허용됨';

  @override
  String get guideStatusEnabledPending => '활성화됨 but 시스템 미확인';

  @override
  String get guideStatusSuggestedCheck => '확인 권장';

  @override
  String get guideStatusBatteryOptimization => '배터리 최적화';

  @override
  String get guideStatusBatteryUnrestricted => '제한 없음';

  @override
  String get guideStatusBatteryRestricted => '아직 제한됨';

  @override
  String get guideStatusKeepAlive => '백그라운드 상주 보조';

  @override
  String get guideStatusAndroidVersion => 'Android 버전';

  @override
  String get guideStatusVersionUnknown => '미인식';

  @override
  String get guideStatusIslandSystemSupport => '슈퍼아일랜드 시스템 지원';

  @override
  String get guideStatusIslandSystemRequirement => 'HyperOS 3.0.300 이상 필요';

  @override
  String get guideStatusIslandHint =>
      '슈퍼아일랜드를 주로 사용하려면, 먼저 시스템 버전이 HyperOS 3.0.300 이상인지 확인한 뒤 아래 권한 목록을 순서대로 완료하세요.';

  @override
  String get guidePermissionChecklistTitle => '권한 목록';

  @override
  String get guidePermissionChecklistSubtitle =>
      '이 순서로 확인하는 것이 가장 효율적이고 누락이 적습니다.';

  @override
  String get guideChecklistRequestNotificationTitle => '알림 권한 요청';

  @override
  String get guideChecklistRequestNotificationSubtitle => '모든 알림의 전제 조건';

  @override
  String get guideChecklistOpenNotificationTitle => '알림 설정 열기';

  @override
  String get guideChecklistOpenNotificationSubtitle =>
      '알림 마스터 스위치, 잠금 화면 표시, 실시간 알림 권한 확인';

  @override
  String get guideChecklistOpenIslandTitle => '포커스 알림 설정 열기';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300 이상에서 promoted/슈퍼아일랜드 알림 확인';

  @override
  String get guideChecklistOpenAutoStartTitle => '자동 시작 설정 열기';

  @override
  String get guideChecklistOpenAutoStartSubtitle => '앱의 자동 시작과 백그라운드 상주를 허용';

  @override
  String get guideChecklistOpenBatteryTitle => '배터리 전략 설정 열기';

  @override
  String get guideChecklistOpenBatterySubtitle =>
      '제한 없음으로 변경 권장. 수업 알림 중단을 방지합니다.';

  @override
  String get guideChecklistOpenKeepAliveTitle => '백그라운드 상주 보조 열기';

  @override
  String get guideChecklistOpenKeepAliveSubtitle =>
      '슈퍼아일랜드와 알림의 백그라운드 안정성을 더욱 향상';

  @override
  String get guideShortNameAdviceTitle => '수업 약칭 권장사항';

  @override
  String get guideShortNameAdviceSubtitle =>
      '슈퍼아일랜드는 수업 약칭 표시를 지원합니다. 약칭은 자동 생성되지 않으며 수업 편집에서 수동 입력이 필요합니다. 3자 이내를 권장합니다.';

  @override
  String get guideShortNameRecommended => '권장 예시';

  @override
  String get guideShortNameNotRecommended => '비권장';

  @override
  String get guideShortNameRecommendedExample => '미적 / 확률 / 수치';

  @override
  String get guideShortNameNotRecommendedExample => '고등수학A(1) / 수치제어기술및응용';

  @override
  String get guideSetCourseShortNameAction => '수업 약칭 설정하기';

  @override
  String get guideImportMethodsTitle => '시간표 가져오기 방법';

  @override
  String get guideImportMethodsSubtitle =>
      '현재 버전은 일부 학교의 교무 시스템 웹 로그인 가져오기를 지원합니다. 미대응 학교라도 다른 마이그레이션 방법이 있습니다.';

  @override
  String get guideImportMethodStep1 =>
      '먼저 \'수업 가져오기 > 교무 시스템 가져오기\'에서 학교와 어댑터를 선택하고, 앱 내에서 교무 웹페이지를 열어 가져오기를 완료하세요.';

  @override
  String get guideImportMethodStep2 =>
      '사용하는 학교가 아직 미대응인 경우, WakeUp 등 시간표 앱에서 수업을 가져온 뒤 캘린더 형식으로 내보내고 본 앱에서 가져오세요.';

  @override
  String get guideImportMethodStep3 =>
      '다른 사용자가 이미 본 앱을 사용 중인 경우, 전체 백업 파일을 내보내어 직접 가져오면 수업과 설정을 복원할 수 있습니다.';

  @override
  String get guideImportMethodExtra =>
      '패킷 캡처, 웹 디버깅, JavaScript를 할 수 있다면, 학교 교무 적응 보충에 참여하여 더 많은 학교가 바로 가져올 수 있도록 해주세요.';

  @override
  String get guideFinalTipsTitle => '마지막으로 이 3가지를 확인하세요';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300 이상에서 슈퍼아일랜드를 지원합니다. 시스템 버전이 부족해도 앱은 일반 알림을 정상적으로 보낼 수 있습니다.';

  @override
  String get guideFinalTip2 =>
      '2. 먼저 설정 페이지에서 \'수업 전 팝업\'과 \'수업 중/종료 임박 알림\'의 임계값을 조정하세요.';

  @override
  String get guideFinalTip3 =>
      '3. 시스템 권한 설정 완료 후 테스트 알림으로 검증하세요. 아일랜드 표시가 가끔 사라지면 자동 시작과 절전 전략을 우선 확인하세요.';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '동의에 체크하면 위의 Umeng 관련 설명, 개인정보 내용과 면책 사항을 읽고 동의한 것으로 간주됩니다.';

  @override
  String get guidePrivacyHelperViewOnly =>
      '여기서는 첫 실행 시와 동일한 개인정보, 서드파티 SDK, 면책 사항을 유지합니다. 언제든 확인 가능합니다. 현재 페이지에서 다시 동의할 필요가 없습니다.';

  @override
  String get guidePrivacySectionTitle => '개인정보, 서드파티 SDK 및 면책 사항';

  @override
  String get guidePrivacyParagraph1 =>
      '본 앱의 주요 기능은 로컬 실행 방식으로 설계되었습니다. 시간표, 템플릿, 수업 기록과 대부분의 설정은 기본적으로 기기 로컬에 저장됩니다.';

  @override
  String get guidePrivacyParagraph2 =>
      '사용자가 능동적으로 업데이트 확인, 다운로드, 가져오기/내보내기 등의 네트워크 기능을 사용하거나, 동의 후 Umeng SDK를 초기화한 경우에만 외부 서비스와 데이터 통신이 발생합니다.';

  @override
  String get guidePrivacyParagraph3 =>
      '본 앱은 Umeng Mobile Statistics SDK, Umeng APM SDK 및 고급 운영 분석 의존 라이브러리를 도입했습니다. 서비스 용도는 모바일 통계 분석, 앱 성능 모니터링 및 고급 운영 분석 관련 기능입니다. 동의 후에만 이 SDK들이 정식으로 초기화됩니다.';

  @override
  String get guidePrivacyParagraph4 =>
      'Umeng 공식 설명에 따르면, 이 SDK들이 처리할 수 있는 정보에는: 기기 정보(IMEI, MAC, Android ID, OAID, IDFA, OpenUDID, GUID, SIM IMSI 등), 네트워크 상태, 기기 식별자, 고급 운영 분석 의존 라이브러리의 앱 목록과 위치 정보가 포함됩니다.';

  @override
  String get guideRiskTitle => '면책 및 리스크 안내';

  @override
  String get guideRiskParagraph1 =>
      '1. 슈퍼아일랜드, 포커스 알림, 백그라운드 알림과 상주 효과는 시스템 버전, 기종, 제조사 전략, 권한, 자동 시작, 배터리 전략 등 외부 조건에 의존합니다. 모든 기기에서 완전히 동일한 동작을 보장할 수 없습니다.';

  @override
  String get guideRiskParagraph2 =>
      '2. 업데이트 확인, 미러 다운로드, 시스템 다운로더, 가져오기/내보내기와 공유는 네트워크 환경, 서드파티 서비스와 시스템 파일 기능에 의존합니다. 실패, 속도 제한 또는 파일 오류 시 Release 페이지, 백업 파일, 시스템 표시를 기준으로 하세요.';

  @override
  String get guideRiskParagraph3 =>
      '3. 마이그레이션, 가져오기 또는 데이터 덮어쓰기 전에 백업 파일이 완전히 사용 가능한지 직접 확인하고, 시간표 정보가 포함된 파일을 적절히 보관하세요. 사용자의 직접 삭제, 덮어쓰기, 공유 또는 보관 부주의로 인한 데이터 문제는 사용자가 직접 리스크를 부담해야 합니다.';

  @override
  String get guideUmengPrivacyLink =>
      'Umeng 개인정보 처리방침: https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '현재 볼 수 있는 슈퍼아일랜드 진단 로그가 없습니다';

  @override
  String get liveDiagnosticsViewerTitle => '슈퍼아일랜드 진단 로그';

  @override
  String get liveDiagnosticsShareText =>
      '경屿 시간표가 내보낸 슈퍼아일랜드 진단 로그입니다. \'슈퍼아일랜드가 표시되지 않는\' 등의 문제 트러블슈팅에 사용할 수 있습니다.';

  @override
  String get liveDiagnosticsShareSubject => '경屿 시간표 - 슈퍼아일랜드 진단 로그';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '경屿 시간표의 현재 테스트 진단 페이지가 내보낸 슈퍼아일랜드 상태 스냅샷입니다. \'슈퍼아일랜드가 표시되지 않는\' 등의 문제 트러블슈팅에 사용할 수 있습니다.';

  @override
  String get liveDiagnosticsSnapshotShareSubject => '경屿 시간표 - 슈퍼아일랜드 상태 스냅샷';

  @override
  String get liveDiagnosticsNothingToExport =>
      '현재 내보낼 수 있는 로그 파일이나 상태 스냅샷이 없습니다';

  @override
  String get liveDiagnosticsCleared => '슈퍼아일랜드 진단 로그를 비웠습니다. 이후 다시 수집을 시작합니다';

  @override
  String get liveDiagnosticsClearFailed => '슈퍼아일랜드 진단 로그 비우기 실패';

  @override
  String get liveTestingNotRefreshed => '아직 새로고침 안 됨';

  @override
  String get liveTestingTitle => '테스트 및 진단';

  @override
  String get liveTestingNotificationTitle => '테스트 알림';

  @override
  String get liveTestingNotificationSubtitle =>
      '슈퍼아일랜드, 알림바, 수업 약칭 등의 표시 효과를 검증합니다.';

  @override
  String get liveTestingSendAction => '테스트 알림 전송';

  @override
  String get liveTestingUmengHint =>
      '아래 두 버튼은 테스트판에만 표시됩니다. Umeng U-APM 충돌과 프리즈上报 검증용입니다.';

  @override
  String get liveTestingCrashAction => '충돌 테스트';

  @override
  String get liveTestingAnrAction => '비정상 프리즈 테스트';

  @override
  String get liveTestingIslandStatusTitle => '아일랜드 상태 진단';

  @override
  String get liveTestingIslandStatusSubtitle =>
      '네이티브 실시간 서비스, 알림 구성 결과 및 비아일랜드 사유를 직접 표시합니다.';

  @override
  String get liveTestingServiceStatusRunning => '서비스 실행 중';

  @override
  String get liveTestingServiceStatusStopped => '서비스 미실행';

  @override
  String get liveTestingNoIslandReasonTitle => '비아일랜드 사유';

  @override
  String get liveTestingNoIslandReasonEmpty => '현재 차단 사유 없음';

  @override
  String get liveTestingRefreshAction => '진단 새로고침';

  @override
  String get liveTestingRefreshing => '새로고침 중';

  @override
  String get liveTestingExportAction => '로그 내보내기 및 공유';

  @override
  String get liveTestingExporting => '내보내는 중';

  @override
  String get liveTestingAutoRefreshTitle => '자동 새로고침';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '$seconds초마다 진단 상태를 자동으로 가져옵니다';
  }

  @override
  String get liveTestingAutoRefreshOff =>
      '끄면 수동 새로고침 시에만 업데이트됩니다. 현재 상태를 안정적으로 확인할 수 있습니다.';

  @override
  String liveTestingRefreshedAt(String time) {
    return '마지막 새로고침: $time';
  }

  @override
  String get liveTestingSectionEnvironment => '환경 및 권한';

  @override
  String get liveTestingSectionService => '서비스 상태';

  @override
  String get liveTestingSectionCourse => '수업 데이터';

  @override
  String get liveTestingSectionTiming => '시간 및 스테이지';

  @override
  String get liveTestingSectionSwitches => '스테이지 스위치';

  @override
  String get liveTestingSectionDisplay => '아일랜드 표시 설정';

  @override
  String get liveTestingSectionNotification => '알림 판정 결과';

  @override
  String get liveTestingSectionRecentLogs => '최근 진단 로그';

  @override
  String get liveTestingRawDataTitle => '원시 디버그 데이터';

  @override
  String get liveTestingRawDataSubtitle =>
      '기본 접힘. 트러블슈팅 시 펼쳐서 전체 네이티브 필드를 확인하세요.';

  @override
  String get liveTestingExpandRawJson => '원시 JSON 펼치기';

  @override
  String get liveTestingExpandRawJsonSubtitle => '대량의 원시 필드가 페이지를 차지하는 것을 방지';

  @override
  String get liveTestingLocalLogsTitle => '로컬 진단 로그';

  @override
  String get liveTestingLocalLogsSubtitle =>
      '원클릭으로 로그 파일을 내보내고 시스템 공유로 개발자에게 전송. 비운 후 재수집도 가능합니다.';

  @override
  String get liveTestingClearLogsAction => '로그 비우기';

  @override
  String get liveTestingClearingLogs => '비우는 중';

  @override
  String get liveTestingViewPhoneLogsAction => '기기 로그 확인';

  @override
  String get liveTestingMoreTesterOptionsAction => '기본 테스터 옵션';

  @override
  String get yesLabel => '예';

  @override
  String get noLabel => '아니오';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '현재 네이티브 진단 필드를 표시합니다.';

  @override
  String get liveTestingCrashSoon =>
      'Umeng U-APM 테스트 충돌을 트리거합니다. 앱을 다시 열어 백그라운드에서 上报를 수신했는지 확인하세요.';

  @override
  String get liveTestingAnrSoon =>
      '약 30초간 메인 스레드 프리즈를 트리거합니다. flutter run에서 벗어나 테스트하고, 프리즈 후 앱을 다시 열어 Umeng 백그라운드를 확인하세요.';

  @override
  String get liveTestingNoCourseAvailable => '현재 테스트 가능한 수업이 없습니다';

  @override
  String get liveTestingTestCourseNote =>
      '여기에 메모가 표시됩니다. 수업 편집 페이지에서 설정할 수 있습니다.';

  @override
  String get liveTestingNotificationSent =>
      '수업 알림 테스트 알림을 전송했습니다. 약 8초 내에 수업 전 알림 단계로 진입합니다';

  @override
  String sendFailedWithError(String error) {
    return '전송 실패: $error';
  }

  @override
  String get homeWidgetSettingsTitle => '홈 위젯';

  @override
  String get homeWidgetTodayCourseTitle => '오늘 수업 위젯';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '2×2, 2×4, 4×4 세 가지 크기를 지원합니다. 위젯을 탭하면 홈을 열고, 수업 시작/종료 시 자동 갱신됩니다.';

  @override
  String get homeWidgetQuickAddTitle => '홈에 빠른 추가';

  @override
  String get homeWidgetCheckingPinSupport => '현재 홈이 앱 내 위젯 추가를 지원하는지 확인 중…';

  @override
  String get homeWidgetPinSupported =>
      '지원하면 시스템 추가 확인이 직접 팝업됩니다. 별도의 권한 팝업이 아닙니다. 확인 후 홈에 고정할 수 있습니다.';

  @override
  String get homeWidgetPinUnsupported =>
      '현재 홈이 앱 내 직접 추가를 지원하지 않으면, 홈을 길게 눌러 → 위젯 → 경屿 시간표에서 수동으로 추가할 수 있습니다.';

  @override
  String get homeWidgetBackgroundStyleLabel => '배경 스타일';

  @override
  String get homeWidgetShowLocationTitle => '장소 표시';

  @override
  String get homeWidgetShowLocationSubtitle =>
      '끄면 위젯의 부가 정보가 주차와 수업 수를 우선 표시합니다.';

  @override
  String get homeWidgetShowCountdownTitle => '카운트다운 표시';

  @override
  String get homeWidgetShowCountdownSubtitle =>
      '새로고침 스위치를 유지합니다. 다음 수업과 수업 중 남은 시간 표시에 사용됩니다.';

  @override
  String get homeWidgetCountdownLeadTitle => '카운트다운 선행량';

  @override
  String get homeWidgetCountdownLeadSubtitle =>
      '수업 전 몇 분에 카운트다운 모드로 전환할지 설정합니다.';

  @override
  String get homeWidgetCountdownLeadAlways => '항상 표시';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '수업 전 $minutes분';
  }

  @override
  String get widgetCountdownStyleTitle => '카운트다운 스타일';

  @override
  String get homeWidgetHideCompletedTitle => '완료된 수업 숨기기';

  @override
  String get homeWidgetHideCompletedSubtitle =>
      '켜면 2×2, 2×4, 4×4 수업 목록에 아직 끝나지 않은 수업만 표시됩니다.';

  @override
  String get homeWidgetShowTomorrowTitle => '수업 후 내일 수업 표시';

  @override
  String get homeWidgetShowTomorrowSubtitle =>
      '켜면 오늘 수업이 모두 끝나면 위젯이 자동으로 내일 수업을 표시합니다.';

  @override
  String get homeWidgetHeightAdjustTitle => '카드 높이 미세 조정';

  @override
  String get defaultLabel => '기본';

  @override
  String higherByValue(String value) {
    return '높게 $value';
  }

  @override
  String lowerByValue(String value) {
    return '낮게 $value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => '카드 둥근 모서리';

  @override
  String get homeWidgetDescriptionTitle => '설명';

  @override
  String get homeWidgetDescriptionText =>
      '위젯은 현재 오늘 수업을 우선 표시합니다. 수업 없음 상태는 완전한 카드를 유지하며 빈 화면이 나타나지 않습니다. 시간표 전환이나 스타일 변경 시 데스크톱 컴포넌트도 연동하여 갱신됩니다.';

  @override
  String homeWidgetPinRequested(String label) {
    return '\"$label\" 추가 요청을 보냈습니다. 시스템 팝업에서 확인하고 홈에 배치하세요.';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '현재 시스템 홈이 앱 내 직접 위젯 추가를 지원하지 않습니다. 홈을 길게 눌러 → 위젯 → 경屿 시간표에서 \"$label\"을(를) 수동으로 추가하세요.';
  }

  @override
  String get homeWidgetInvalidType => '위젯 타입이 유효하지 않습니다. 나중에 다시 시도하세요.';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '추가 요청 실패. 홈을 길게 눌러 → 위젯 → 경屿 시간표에서 \"$label\"을(를) 수동으로 추가하세요.';
  }

  @override
  String get layoutSettingsTitle => '레이아웃 및 교시';

  @override
  String get layoutDensityTitle => '시간표 밀도';

  @override
  String get layoutAutoFitHeightTitle => '화면 높이에 자동 맞춤';

  @override
  String get layoutAutoFitHeightSubtitle =>
      '켜면 현재 교시 수에 따라 페이지 하단까지 자동 맞춤됩니다. 아래 여백을 유지하지 않습니다.';

  @override
  String get layoutHideWeekendsTitle => '토요일/일요일 숨기기';

  @override
  String get layoutHideWeekendsSubtitle =>
      '켜면 홈에 월~금만 표시됩니다. 나머지 열 너비는 자동 맞춤됩니다.';

  @override
  String get layoutEnableHapticsTitle => '앱 내 진동 피드백 활성화';

  @override
  String get layoutEnableHapticsSubtitle =>
      '끄면 페이지 전환 등의 상호작용에서 가벼운 진동이 발생하지 않습니다.';

  @override
  String pageTransitionSpeedLabel(String speed) {
    return '페이지 전환 속도 $speed×';
  }

  @override
  String get pageTransitionSpeedSubtitle =>
      '하위 페이지 슬라이드 애니메이션 속도를 조절합니다. 값이 클수록 빠르고, 작을수록 느립니다. Android 시스템 \'전환 애니메이션 배율\'과 함께 적용됩니다.';

  @override
  String pageTransitionSpeedDurationHint(int milliseconds) {
    return '약 ${milliseconds}ms';
  }

  @override
  String get layoutTimeColumnDisplayLabel => '홈 시간 열 표시';

  @override
  String get layoutTimeColumnWidthLabel => '시간 열 너비';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '\"이번주로 돌아가기\" 버튼 스타일';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      '기본은 현재 인라인 스타일을 유지합니다. 주간 뷰 오른쪽 아래의 소형 플로팅 버튼으로도 변경할 수 있습니다.';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '시간 열 인라인';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '오른쪽 아래 플로팅';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return '플로팅 버튼 불투명도 $value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle =>
      '오른쪽 아래 플로팅 스타일에만 유효합니다.';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '수업 카드 간격 $value';
  }

  @override
  String layoutSectionHeightLabel(String value) {
    return '시간표 행 높이 $value';
  }

  @override
  String layoutCompactFontSizeLabel(String value) {
    return '컴팩트 폰트 크기 $value';
  }

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '수업 카드 폰트 크기 $value';
  }

  @override
  String get layoutCourseCardDisplayTitle => '수업 카드 표시';

  @override
  String get layoutCourseCardDisplaySubtitle =>
      '기본으로 수업명, 교사, 강의실을 표시합니다. 다른 정보는 시간표별로 자유롭게 조합할 수 있습니다.';

  @override
  String get layoutShowTeacherTitle => '교사 표시';

  @override
  String get layoutShowClassroomTitle => '강의실 표시';

  @override
  String get layoutShowTimeTitle => '시간 표시';

  @override
  String get layoutShowTimeLabelsTitle => '수업 시작/종료 텍스트 표시';

  @override
  String get layoutShowTimeLabelsSubtitle =>
      '끄면 시간 포인트만 표시합니다. \'수업 시작\' \'수업 종료\' 텍스트는 숨겨집니다.';

  @override
  String get layoutShowWeeksTitle => '주차 수 표시';

  @override
  String get layoutShowWeeksSubtitle => '예: 1-16주, 홀짝주';

  @override
  String get layoutShowDescriptionTitle => '수업 개요 표시';

  @override
  String get layoutShowDescriptionSubtitle => '기본 꺼짐. 공간 부족 시 가장 먼저 압축됩니다.';

  @override
  String get layoutShowOtherWeeksTitle => '비이번주 수업 표시';

  @override
  String get layoutShowOtherWeeksSubtitle =>
      '기본 꺼짐. 켜면 현재 주에 없는 수업을 회색 반투명으로 표시합니다.';

  @override
  String get layoutVerticalAlignLabel => '수직 레이아웃';

  @override
  String get layoutHorizontalAlignLabel => '수평 레이아웃';

  @override
  String get layoutShowConflictBadgeTitle => '홈에 충돌 캡슐 표시';

  @override
  String get layoutShowConflictBadgeSubtitle =>
      '끄면 홈 시간표에서 충돌 수업에 \'충돌\' 캡슐을 표시하지 않습니다.';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '충돌 수업 투명도 $value%';
  }

  @override
  String get layoutConflictOpacitySubtitle =>
      '충돌 수업은 자동으로 겹쳐 표시됩니다. 투명도를 낮추면 여러 수업을 동시에 확인할 수 있습니다.';

  @override
  String get layoutTipsText =>
      '템플릿은 설정 홈으로 이동했습니다. 여기서는 시간표의 행 높이, 시간 열, 주말 표시, 수업 카드 레이아웃을 조정합니다. 현재 시간표의 시간만 변경하려면 먼저 템플릿에서 복사한 뒤 적용하세요.';

  @override
  String currentWeekCompact(int week) {
    return '$week주';
  }

  @override
  String get sampleCourseNumericalControl => '수치';

  @override
  String get sampleCourseAdvancedMath => '미적';

  @override
  String get sampleTeacherZhang => '장 선생님';

  @override
  String get sampleCourseEnglish => '영어';

  @override
  String get sampleTeacherLi => '이 선생님';

  @override
  String get aboutRepositorySheetTitle => '오픈소스 저장소';

  @override
  String get aboutRepositorySheetHint =>
      '학교 교무 가져오기 적응을 보충하려면, 교무 적응 저장소 qingyu_warehouse도 함께 확인하는 것을 권장합니다.';

  @override
  String get aboutOpenGitHubAction => 'GitHub 열기';

  @override
  String get aboutOpenWarehouseRepoAction => '교무 적응 저장소 열기';

  @override
  String get copiedRepositoryAddress => '저장소 주소를 복사했습니다';

  @override
  String get copiedWarehouseRepositoryAddress => '교무 적응 저장소 주소를 복사했습니다';

  @override
  String get aboutUpdateScreenTitle => '버전 업데이트';

  @override
  String get aboutUpdateStatusTitle => '업데이트 상태';

  @override
  String get aboutRefreshCheckTooltip => '다시 확인';

  @override
  String get aboutCheckingLatestVersion => '최신 버전 정보 확인 중…';

  @override
  String get aboutCheckingForUpdate => '업데이트 확인 중…';

  @override
  String get aboutReadVersionFailed => '버전 정보를 일시적으로 읽을 수 없습니다. 나중에 다시 시도하세요.';

  @override
  String get aboutReadVersionFailedHint =>
      '현재 네트워크에서 GitHub 접속이 불안정하면 나중에 다시 시도하거나, 아래의 국내 다운로드 방식으로 전환한 뒤 재시도하세요.';

  @override
  String get aboutViewReleaseAction => 'Release 보기';

  @override
  String get aboutDownloadNowAction => '지금 다운로드';

  @override
  String get aboutOpenDownloadPageAction => '다운로드 페이지 열기';

  @override
  String get aboutCurrentVersionLabel => '현재 버전';

  @override
  String get aboutLatestVersionLabel => '최신 버전';

  @override
  String get aboutUnreleasedLabel => '미출시';

  @override
  String get aboutVersionChannelLabel => '버전 채널';

  @override
  String get aboutPrereleaseChannel => '시험판';

  @override
  String get aboutUpdateAvailableHint =>
      '지금은 아래의 \'지금 다운로드\'를 탭하기만 하면 됩니다. 속도 측정, 미러, 시험판은 뒤의 고급 옵션에 정리되어 있습니다.';

  @override
  String get aboutUpdateNoUpdateHint =>
      '현재 버전은 정상 사용 가능합니다. 시험판을 체험하려면 뒤의 고급 옵션에서 시험판 검출을 켜세요.';

  @override
  String aboutUpdatedAt(String time) {
    return '업데이트 시간: $time';
  }

  @override
  String get aboutUpdateNowTitle => '지금 업데이트';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '일반 사용은 \'지금 다운로드\'를 한 번 탭하기만 하면 됩니다. 다운로드 느림, 실패, 회선 변경 시 아래의 고급 옵션으로 이동하세요.';

  @override
  String get aboutUpdateNowOtherSubtitle =>
      '현재 플랫폼은 다운로드 페이지를 직접 열며 앱 내에서 설치하지 않습니다.';

  @override
  String get aboutMirrorDownloadHint =>
      '현재 국내 다운로드를 우선합니다. 대부분의 국내 네트워크에서는 \'지금 다운로드\'를 탭하기만 하면 됩니다.';

  @override
  String get aboutOriginalDownloadHint =>
      '현재 국제 소스 다운로드를 우선합니다. 다운로드가 느리거나 열리지 않으면 먼저 \'국내 다운로드\'로 전환하세요.';

  @override
  String get aboutUseSystemDownloaderAction => '시스템 다운로더로 다운로드';

  @override
  String get aboutOpenReleasePageAction => 'Release 페이지 열기';

  @override
  String get aboutDownloadMethodTitle => '다운로드 방식';

  @override
  String get aboutDownloadMethodSubtitle =>
      '기본으로 국내 다운로드를 권장합니다. GitHub에 안정적으로 접근할 수 있을 때만 국제 소스로 전환하세요.';

  @override
  String get aboutDownloadMethodMirror => '국내 다운로드';

  @override
  String get aboutDownloadMethodOriginal => '국제 소스 다운로드';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '현재 국내 다운로드 사용 중 · $current. 최근 속도 측정에서 \"$recommended\"이(가) 권장됩니다. 필요 시 뒤의 고급 옵션에서 전환할 수 있습니다.';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '현재 국내 다운로드 사용 중 · $current. 다운로드가 느리거나 실패하면 뒤의 고급 옵션에서 속도 측정, 회선 변경 또는 사용자 정의 주소를 입력하세요.';
  }

  @override
  String get aboutOriginalModeHint =>
      '현재 국제 소스 다운로드 사용 중. GitHub에 안정적으로 접근할 수 있을 때만 이 설정을 권장합니다. 그렇지 않으면 국내 다운로드로 전환하세요.';

  @override
  String get aboutReleaseNotesTitle => '이번 업데이트 내용';

  @override
  String get aboutReleaseNotesSubtitle => '현재 감지된 버전의 Release 설명을 표시합니다.';

  @override
  String get aboutAdvancedOptionsTitle => '고급 옵션';

  @override
  String get aboutAdvancedOptionsSubtitle =>
      '다운로드 느림, 수동 회선 전환, 시험판 검출 시에만 펼치세요.';

  @override
  String get aboutMirrorSectionTitle => '다운로드 회선 및 미러';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '현재 국내 다운로드 사용 중. 여기서 수동으로 회선 전환, 속도 측정 권장, 사용자 정의 다운로드 주소 입력이 가능합니다.';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '현재 국제 소스 다운로드를 사용 중입니다. 아래 회선 설정은 \'국내 다운로드\'로 전환 후에만 유효합니다.';

  @override
  String get aboutFillCustomMirrorFirst => '먼저 사용자 정의 다운로드 주소를 입력하세요';

  @override
  String get aboutCurrentCustomMirrorTitle => '현재 사용자 정의 다운로드 주소';

  @override
  String get aboutCurrentMirrorTitle => '현재 다운로드 회선 주소';

  @override
  String get aboutCurrentCustomMirrorHint => '현재 수동으로 입력한 다운로드 주소를 사용 중입니다.';

  @override
  String get aboutCurrentMirrorHint =>
      '현재 회선 접속 실패 시 다른 내장 회선으로 전환하거나 사용자 정의 주소로 변경할 수 있습니다.';

  @override
  String get aboutProbeMirrorsAction => '속도 측정 및 권장';

  @override
  String get aboutProbingMirrors => '속도 측정 중…';

  @override
  String get aboutEditCustomMirrorAction => '사용자 정의 주소 변경';

  @override
  String get aboutSetCustomMirrorAction => '사용자 정의 주소 입력';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '권장으로 전환: $label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '현재 국내 다운로드를 사용하지 않아 여기의 회선 설정이 일시적으로 유효하지 않습니다. 필요하면 위의 \'다운로드 방식\'에서 국내 다운로드로 전환하세요.';

  @override
  String get aboutRecentProbeResultsTitle => '최근 속도 측정 결과';

  @override
  String get aboutUnavailable => '사용 불가';

  @override
  String get aboutRecommended => '권장';

  @override
  String get aboutCheckPrereleaseTitle => '시험판 검출';

  @override
  String get aboutCheckPrereleaseSubtitle =>
      '켜면 시험판도 업데이트 확인에 포함됩니다. 일반 사용은 끄기를 권장합니다.';

  @override
  String get aboutDiagnosticsTitle => '테스트 및 진단';

  @override
  String get aboutDiagnosticsSubtitle =>
      '\'슈퍼아일랜드가 표시되지 않음\' 또는 개발자 피드백이 필요한 경우에만 펼치세요.';

  @override
  String get aboutRecordDiagnosticsTitle => '앱 로그 기록';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      '켜면 로컬에서 중요 로그를 지속적으로 기록합니다. \'표시되어야 할 것이 표시되지 않는\' 문제 트러블슈팅 전용입니다.';

  @override
  String get aboutExportDiagnosticsAction => '앱 로그 내보내기';

  @override
  String get aboutViewPhoneLogsAction => '로그 페이지 열기';

  @override
  String get aboutClearAndRecollectAction => '비우고 재수집';

  @override
  String get aboutLiveDiagnosticsEnabled => '슈퍼아일랜드 진단 로그 활성화됨';

  @override
  String get aboutLiveDiagnosticsDisabled => '슈퍼아일랜드 진단 로그 비활성화됨';

  @override
  String get aboutNoDiagnosticsExportYet => '내보낼 수 있는 슈퍼아일랜드 진단 로그가 아직 없습니다';

  @override
  String get aboutProbeNoMirrorFound => '속도 측정 완료. 사용 가능한 미러 회선을 찾지 못했습니다';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '속도 측정 완료. 현재 회선 \"$label\"이(가) 가장 빠른 사용 가능한 회선입니다';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '속도 측정 완료. \"$label\"(으)로 전환을 권장합니다';
  }

  @override
  String get switchAction => '전환';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error. 국내 미러로 전환 후 재시도할 수 있습니다';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error. \"$label\"(으)로 전환 후 재시도를 권장합니다';
  }

  @override
  String get aboutSetMirrorSourceTitle => '미러 소스 설정';

  @override
  String get aboutMirrorPrefixLabel => '미러 접두사';

  @override
  String get aboutMirrorPrefixInvalid =>
      '미러 소스 형식이 올바르지 않습니다. 전체 http 또는 https 주소를 입력하세요';

  @override
  String get aboutMirrorSaved => '미러 소스가 저장되었습니다';

  @override
  String get aboutDownloadCancelled => '다운로드가 취소되었습니다';

  @override
  String get aboutInstallReady =>
      '설치 패키지 준비 완료. 설치 화면을 열려고 했습니다. 시스템이 표시하지 않으면 나중에 알림 또는 파일 관리자에서 수동으로 설치하세요';

  @override
  String get aboutUpdatePackageTitle => '경屿 시간표 업데이트 패키지';

  @override
  String get aboutUpdatePackageDescription =>
      '시스템 다운로드 관리자에 전달하여 다운로드 중입니다. 완료 후 시스템 알림에서 바로 설치할 수 있습니다.';

  @override
  String get aboutSystemDownloaderQueued =>
      '시스템 다운로드 관리자에 전달했습니다. 시스템 알림 또는 다운로드 목록에서 진행 상황을 확인하세요';

  @override
  String get aboutSystemDownloaderFailed => '시스템 다운로드 관리자 호출 실패';

  @override
  String get aboutDownloadCancelling => '다운로드 취소 중…';

  @override
  String aboutDownloadingBytes(String value) {
    return '업데이트 다운로드 중 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '업데이트 다운로드 중 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint =>
      '미러 소스가 파일 총 크기를 반환하지 않아 다운로드된 크기를 먼저 표시합니다';

  @override
  String get aboutCancelDownloadAction => '다운로드 취소';

  @override
  String get aboutContributorsScreenTitle => '코드 기여자';

  @override
  String get aboutDevelopersTitle => '개발자';

  @override
  String get aboutDeveloperMaintainerSubtitle => '경屿 시간표 개발 및 유지보수';

  @override
  String get aboutWarehouseMaintainersTitle => '교무 가져오기 적응자';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '아래 목록은 qingyu_warehouse 적응 저장소의 maintainer 필드에서 집계한 것입니다. 로컬 캐시가 있으면 먼저 캐시를 표시한 뒤 백그라운드에서 갱신합니다.';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '적응자 목록을 일시적으로 읽을 수 없습니다: $error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '현재 적응자 정보를 읽지 못했습니다.';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count개 적응 항목';
  }

  @override
  String get aboutParticipateWarehouseTitle => '교무 적응에 참여';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      '패킷 캡처, 웹 디버깅, JavaScript를 할 수 있거나 자신의 학교 교무 시스템을 장기 유지보수하고 싶다면, qingyu_warehouse에서 새 학교 적응과 수정을 제출해 주세요.';

  @override
  String get importFileReadFailed => '선택한 파일을 읽을 수 없습니다';

  @override
  String get importReplaceExistingTitle => '수업 가져오기';

  @override
  String importReplaceExistingMessage(String name) {
    return '$name을(를) 가져올 때 기존 수업을 대체하시겠습니까?';
  }

  @override
  String get importNoCoursesRecognized => '가져올 수 있는 수업이 인식되지 않았습니다';

  @override
  String get importConfirmSemesterMappingTitle => '학기 시작일과 주차 대응 확인';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '학교 학사일정의 학기 시작일을 선택하세요. 파일 내 가장 이른 수업 날짜에 따라 기본 주차 대응을 제안했습니다. 수동으로 조정할 수도 있습니다.';

  @override
  String importOverwriteCount(int count) {
    return '$count건 수업을 덮어쓰기 가져왔습니다';
  }

  @override
  String importUpdatedCount(int count) {
    return '시간표 업데이트: $count건 수업을 새로 추가 또는 업데이트';
  }

  @override
  String get importNoCourseChanges => '추가 또는 업데이트할 수업이 없습니다';

  @override
  String get aiImportTitle => '이미지 인식 가져오기';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '$courseCount과목 인식, 최대 제$sectionCount교시$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return ', $count건 주의사항';
  }

  @override
  String get aiWorkflowCompactTitle => '프롬프트 복사 → Doubao 이미지 인식 → 가져오기';

  @override
  String get aiWorkflowCompactSubtitle => 'Doubao 전문가 모드 → JSON 복사 → 학기 시작일 선택';

  @override
  String get aiWorkflowTitle => '프롬프트 복사 → Doubao 이미지 인식 → JSON 붙여넣기 → 가져오기';

  @override
  String get aiWorkflowSubtitle =>
      '먼저 프롬프트를 복사하고, Doubao 왼쪽 아래에서 전문가 모드로 전환한 뒤, 시간표 스크린샷과 프롬프트를 함께 전송합니다. Doubao가 반환한 JSON을 여기에 복사하고 가져오기를 탭한 뒤 학기 시작일을 선택합니다.';

  @override
  String get aiPromptShortAction => '프롬프트';

  @override
  String get aiExpertModeSuggestion =>
      'Doubao 전문가 모드를 권장합니다. 다중 이미지 지원, 스크린샷에 요일 헤더가 필요합니다.';

  @override
  String get aiHintExpertMode => '먼저 Doubao 전문가 모드로 전환';

  @override
  String get aiHintSendScreenshot => '스크린샷과 프롬프트를 함께 전송';

  @override
  String get aiHintCopyJsonBack => '반환된 결과에서 JSON 복사';

  @override
  String get aiHintPickSemesterAfterImport => '가져오기 후 학기 시작일 선택';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => 'AI가 반환한 JSON 붙여넣기';

  @override
  String aiCourseCountChip(int count) {
    return '$count과목';
  }

  @override
  String get aiParseFailedChip => '파싱 실패';

  @override
  String get aiPasteJsonHintShort => 'AI가 반환한 JSON 붙여넣기';

  @override
  String get aiPasteJsonHintLong =>
      'Doubao가 반환한 JSON을 그대로 여기에 붙여넣고 가져오기를 탭하세요. 순수 JSON과 ```json 코드 블록 모두 지원합니다.';

  @override
  String get detailAction => '상세';

  @override
  String get aiParseErrorTitle => '파싱 오류';

  @override
  String get viewDetailsAction => '상세 보기';

  @override
  String get aiWorkflowFooter =>
      '프롬프트 복사 → Doubao에서 스크린샷과 프롬프트 전송 → JSON을 여기에 붙여넣기 → 가져오기 탭 → 학기 시작일 선택.';

  @override
  String get previewAction => '미리보기';

  @override
  String get confirmImportAction => '가져오기 확인';

  @override
  String get promptCopiedHint => '프롬프트를 복사했습니다. Doubao에서 스크린샷과 프롬프트를 전송하세요';

  @override
  String get clipboardNoText => '클립보드에 사용 가능한 텍스트가 없습니다';

  @override
  String get aiPromptSheetTitle => '이미지 인식 프롬프트';

  @override
  String get aiPromptSheetSubtitle =>
      'Doubao 사용을 권장합니다. 먼저 Doubao 왼쪽 아래에서 전문가 모드로 전환하고, 아래 프롬프트 전체와 시간표 스크린샷을 함께 전송하여 JSON만 반환하도록 합니다. 생성 후 JSON을 이 페이지에 복사하고 가져오기를 탭한 뒤 학기 시작일을 선택합니다.';

  @override
  String get aiPreviewTitle => '파싱 미리보기';

  @override
  String get aiPasteJsonFirst => '먼저 AI가 반환한 JSON을 붙여넣으세요';

  @override
  String get aiParseFailedIncompleteJson => '파싱 실패. 완전한 JSON이 붙여넣어졌는지 확인하세요';

  @override
  String get importAiResultTitle => 'AI 파싱 결과 가져오기';

  @override
  String get importAiReplaceMessage => '현재 AI 파싱 결과로 기존 수업을 대체하시겠습니까?';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '학교 학사일정의 학기 시작일을 선택하고, 시간표의 1주차가 학사일정의 몇 주차에 해당하는지 확인하세요. 학교 첫 주에 수업이 없으면 보통 2주차로 변경해야 합니다.';

  @override
  String aiWarningExtraSuffix(int count) {
    return ', 추가로 $count건 인식 주의사항';
  }

  @override
  String get pasteAction => '붙여넣기';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '교무 스크립트가 수업 주차를 반환했습니다. 학사일정 학기 시작일을 확인하세요. 학교 첫 몇 주에 수업이 없으면 \'시간표 1주차\'를 학사일정后面的 주차에 대응할 수 있습니다.';

  @override
  String aiPreviewCourseCount(int count) {
    return '수업 수: $count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '최대 교시: 제$section교시';
  }

  @override
  String get aiPreviewWarningsTitle => '인식 주의사항';

  @override
  String get aiPreviewCoursesTitle => '수업 미리보기';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '나머지 $count건은 가져오기 후 현재 시간표에 기록됩니다';
  }

  @override
  String get warehouseMissingSchoolTitle => '학교 목록에 해당 학교가 없으신가요?';

  @override
  String get warehouseMissingSchoolSubtitle =>
      '피드백 페이지에서 Issue를 제출하세요. 학교 이름, 교무 시스템 URL, 로그인 후 시간표 페이지 링크 또는 스크린샷을 함께 작성하면 적응 보충이 더 원활합니다.';

  @override
  String get laterAction => '나중에';

  @override
  String get goFeedbackAction => '피드백 페이지로';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '학교가 없으신가요? 피드백으로';

  @override
  String get warehouseCustomDebugTitle => '사용자 정의 디버그';

  @override
  String get warehouseRootLoadFailedTitle => '적응 저장소를 일시적으로 읽을 수 없습니다';

  @override
  String get searchSchoolHint => '학교 이름, 이니셜 또는 코드로 검색';

  @override
  String get clearSearchTooltip => '비우기';

  @override
  String get noMatchingSchools => '일치하는 학교가 없습니다';

  @override
  String get noAvailableSchools => '사용 가능한 학교가 없습니다';

  @override
  String get searchSchoolSuggestion => '학교 정식명칭, 이니셜 또는 저장소의 학교 코드를 시도해 보세요.';

  @override
  String get deleteDebugRecordTitle => '디버그 레코드 삭제';

  @override
  String deleteDebugRecordMessage(String name) {
    return '\"$name\"을(를) 삭제하시겠습니까? 삭제 후 이미 가져온 수업에는 영향을 주지 않습니다.';
  }

  @override
  String deletedDebugRecord(String name) {
    return '디버그 레코드 삭제됨: $name';
  }

  @override
  String get customDebugName => '사용자 정의 디버그';

  @override
  String get localDebugMaintainer => '로컬 디버그';

  @override
  String get customDebugDescription => '사용자가 저장한 사용자 정의 교무 디버그 스크립트';

  @override
  String get addDebugRecordTooltip => '디버그 레코드 추가';

  @override
  String get customDebugIntroTitle => '여기에 나만의 교무 디버그 레코드를 배치하세요';

  @override
  String get customDebugIntroSubtitle =>
      '각 레코드에 사용자 정의 URL과 스크립트 전체를 저장할 수 있습니다. 저장 후 다음에 \'디버그 시작\'을 탭하기만 하면 재사용할 수 있습니다.';

  @override
  String get addDebugRecordAction => '디버그 레코드 추가';

  @override
  String get noSavedDebugRecords => '저장된 디버그 레코드가 없습니다';

  @override
  String get noSavedDebugRecordsHint =>
      '먼저 1건 추가하고 URL과 스크립트를 붙여넣으세요. 이후 바로 재사용할 수 있습니다.';

  @override
  String debugScriptLength(int count) {
    return '스크립트 $count자';
  }

  @override
  String get startDebugAction => '디버그 시작';

  @override
  String get editAction => '편집';

  @override
  String get scriptFileReadFailed => '스크립트 파일을 읽을 수 없습니다';

  @override
  String scriptFileImported(String name) {
    return '스크립트 파일 가져옴: $name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return '스크립트 파일 가져오기 실패: $error';
  }

  @override
  String get debugRecordNameRequired => '디버그 레코드 이름을 입력하세요';

  @override
  String get invalidImportUrl => '유효한 교무 URL을 입력하세요';

  @override
  String get debugScriptRequired => '스크립트를 입력하거나 가져오세요';

  @override
  String get editDebugRecordTitle => '디버그 레코드 편집';

  @override
  String get addDebugRecordTitle => '디버그 레코드 추가';

  @override
  String get savingAction => '저장 중…';

  @override
  String get debugRecordFormula => '1레코드 = 1URL + 1스크립트';

  @override
  String get debugRecordFormulaSubtitle =>
      '같은 학교를 반복 디버그하거나, 다른 학교에 여러 스크립트 세트를 유지하는 데 적합합니다. 저장 후 언제든 수정 가능합니다.';

  @override
  String get debugRecordNameLabel => '레코드 이름';

  @override
  String get debugRecordNameHint => '예: 충칭기전-신규교무';

  @override
  String get importUrlLabel => '교무 URL';

  @override
  String get debugScriptLabel => '디버그 스크립트';

  @override
  String get importFromFileAction => '파일에서 가져오기';

  @override
  String get debugScriptHint => '브라우저 확장 프로그램이 내보낸 전체 스크립트를 여기에 붙여넣으세요';

  @override
  String get saveDebugRecordAction => '디버그 레코드 저장';

  @override
  String get fillUrlThenImport => 'URL 입력 후 가져오기';

  @override
  String get webLoginImport => '웹 로그인 가져오기';

  @override
  String get fillUrlThenRecord => 'URL 입력 후 녹화';

  @override
  String get recordImportAction => '녹화 가져오기';

  @override
  String get quickImportAction => '빠른 가져오기';

  @override
  String get quickImportTooltip => '빠른 가져오기';

  @override
  String get selectQuickImportTitle => '빠른 가져오기 선택';

  @override
  String quickImportMacroSteps(String adapterName, int stepCount) {
    return '$adapterName · $stepCount단계';
  }

  @override
  String quickImportTitle(String name) {
    return '빠른 가져오기 - $name';
  }

  @override
  String get noSavedQuickImportRecords => '저장된 빠른 가져오기 기록이 없습니다';

  @override
  String get noValidWarehouseLoginUrl => '유효한 교무 로그인 URL을 찾을 수 없습니다';

  @override
  String get noMacroRecordFound => '녹화 기록을 찾을 수 없습니다. 먼저 녹화를 완료하세요';

  @override
  String get quickImportPlayingTitle => '자동 가져오는 중…';

  @override
  String get quickImportExecutingScriptTitle => '재생 완료, 가져오기 스크립트 실행 중…';

  @override
  String get quickImportManualInputTitle => '수동 작업 필요';

  @override
  String get quickImportManualInputHint => '필요한 수동 작업을 완료한 후 계속을 탭하세요.';

  @override
  String get quickImportCancelImportAction => '가져오기 취소';

  @override
  String get quickImportContinueAction => '계속';

  @override
  String get quickImportFinishedTitle => '가져오기 완료';

  @override
  String get quickImportDismissAction => '완료';

  @override
  String get quickImportRetryAction => '재시도';

  @override
  String quickImportPlaybackStepProgress(int current, int total) {
    return '단계 $current / $total';
  }

  @override
  String get quickImportCancelPlaybackAction => '취소';

  @override
  String get quickImportUnknownError => '알 수 없는 오류가 발생했습니다';

  @override
  String get recentSchoolLabel => '최근 사용';

  @override
  String get warehouseSchoolTapHint => '탭하여 어댑터를 선택하고 가져오기';

  @override
  String get warehouseAdaptersLoadFailedTitle => '어댑터 목록을 불러올 수 없습니다';

  @override
  String get stopRecordingTooltip => '녹화 중지';

  @override
  String get startRecordingTooltip => '동작 녹화';

  @override
  String get savedImportUrlHint => '교무 URL 저장됨. 다음에 바로 가져올 수 있습니다';

  @override
  String get adapterIntroSubtitle => '어댑터 정보, 로그인 항목과 스크립트 상태를 확인할 수 있습니다.';

  @override
  String get schoolLabel => '학교';

  @override
  String get categoryLabel => '카테고리';

  @override
  String get maintainerLabel => '유지보수자';

  @override
  String get adapterInfoTitle => '어댑터 정보';

  @override
  String get scriptPathLabel => '스크립트 경로';

  @override
  String get loginEntryLabel => '로그인 항목';

  @override
  String get unsetConfigLabel => '미설정';

  @override
  String get adapterOverrideImportUrlHint => '현재 수동으로 덮어쓴 로그인 주소를 사용 중입니다';

  @override
  String get repositoryLabel => '저장소';

  @override
  String get scriptStatusTitle => '스크립트 상태';

  @override
  String scriptLoadedLength(int count) {
    return '스크립트 읽기 성공. 길이 $count자.';
  }

  @override
  String get scriptEmpty => '스크립트가 비어 있습니다';

  @override
  String get openLoginInAppAction => '앱 내에서 로그인 항목 열기';

  @override
  String get openInSystemBrowserAction => '시스템 브라우저에서 열기';

  @override
  String get copiedImportLoginUrl => '교무 로그인 주소를 복사했습니다';

  @override
  String get copyLoginAddressAction => '로그인 주소 복사';

  @override
  String get copiedScriptRawUrl => '스크립트 원본 주소를 복사했습니다';

  @override
  String get copyScriptAddressAction => '스크립트 주소 복사';

  @override
  String get customLoginAddressAction => '사용자 정의 로그인 주소';

  @override
  String get editCustomLoginAddressAction => '사용자 정의 주소 변경';

  @override
  String get clearCustomLoginAddressAction => '사용자 정의 주소 삭제';

  @override
  String get restoreRepositoryAddressAction => '저장소 주소 복원';

  @override
  String get invalidLoginEntryUrl => '로그인 항목 주소가 유효하지 않습니다';

  @override
  String get savedCustomLoginAddress => '사용자 정의 로그인 주소 저장됨';

  @override
  String get clearedCustomLoginAddress => '사용자 정의 로그인 주소 삭제됨';

  @override
  String get restoredRepositoryImportUrl => '저장소의 로그인 주소를 복원했습니다';

  @override
  String get backToCurrentWeekAction => '이번주로';

  @override
  String get nonCurrentWeekLabel => '비이번주';

  @override
  String get conflictLabel => '충돌';

  @override
  String get selectWeekTitle => '주차 선택';

  @override
  String availableWeeksCount(int count) {
    return '총 $count주';
  }

  @override
  String goToWeekLabel(int week) {
    return '제$week주';
  }

  @override
  String get homeMenuUpdateTitle => '소프트웨어 업데이트';

  @override
  String get homeMenuProfilesTitle => '시간표 관리';

  @override
  String get homeMenuOverviewTitle => '수업 전체보기';

  @override
  String get homeMenuAddCourseTitle => '수업 추가';

  @override
  String get homeMenuImportTitle => '수업 가져오기';

  @override
  String get homeMenuSettingsTitle => '시간표 설정';

  @override
  String get homeMenuCoffeeTitle => '커피 한 잔';

  @override
  String get homeMenuFeedbackTitle => '문제 제보';

  @override
  String get switchTimetableTitle => '시간표 전환';

  @override
  String get switchTimetableSubtitleEmpty => '아래 시간표를 탭하여 현재 뷰를 즉시 전환하세요.';

  @override
  String switchTimetableSubtitleCurrent(String name) {
    return '현재: $name. 아래 시간표를 탭하여 즉시 전환하세요.';
  }

  @override
  String get todayTimetableTitle => '오늘 시간표';

  @override
  String get dayTimetableTitle => '일간 타임라인';

  @override
  String get backToWeekViewAction => '주간 뷰로 돌아가기';

  @override
  String get backToTodayAction => '오늘로 돌아가기';

  @override
  String get ongoingCourseBadge => '수업 중';

  @override
  String get dayViewEmptyTitle => '수업 없음';

  @override
  String shortNamePrefix(String value) {
    return '약칭: $value';
  }

  @override
  String teacherPrefix(String value) {
    return '교사: $value';
  }

  @override
  String locationPrefix(String value) {
    return '장소: $value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '현재 제$week주를 보고 있습니다. 이 주의 이 수업을 바로 시간 변경할 수 있습니다.';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '현재 제$week주를 보고 있습니다. 이 수업은 이번 주에 없으므로 \'이번주 이 수업\'으로 시간 변경할 수 없습니다.';
  }

  @override
  String get editActionShort => '편집';

  @override
  String get rescheduleAction => '시간 변경';

  @override
  String get deleteActionShort => '삭제';

  @override
  String get deleteModeTitle => '삭제 방식';

  @override
  String get deleteModeSubtitle =>
      '배치 전체를 삭제하거나, 현재 보고 있는 이 주의 이 수업만 삭제할 수 있습니다.';

  @override
  String get deleteCourseAction => '이 수업 삭제';

  @override
  String get deleteOccurrenceAction => '이 수업 회 삭제';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '\'이 수업 삭제\'는 배치의 전체 주차를 삭제합니다. \'이 수업 회 삭제\'는 제$week주 이번만 삭제합니다.';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '현재 카드는 제$week주 실제 배치가 아니므로 배치 전체만 삭제할 수 있습니다.';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '\"$name\" 배치를 삭제하시겠습니까?\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '\"$name\"의 제$week주 이 수업을 삭제하시겠습니까?\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '제$week주 이 수업이 삭제되었습니다';
  }

  @override
  String get noChangesDetected => '변경 사항이 감지되지 않았습니다';

  @override
  String get rescheduleCurrentOccurrenceTitle => '이번주 이 수업 시간 변경';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '제$week주 이 수업만 조정합니다. 원래 수업은 이 주에서 자동으로 제거되며 다른 주는 변경 없습니다.';
  }

  @override
  String get rescheduleTargetWeekLabel => '변경할 주차';

  @override
  String get weekdayFieldLabel => '요일';

  @override
  String get startSectionFieldLabel => '시작 교시';

  @override
  String get endSectionFieldLabel => '종료 교시';

  @override
  String get courseLocationFieldLabel => '수업 장소';

  @override
  String get confirmRescheduleAction => '시간 변경 확인';

  @override
  String get homeTitleStyleClassicLabel => '클래식 텍스트';

  @override
  String get homeTitleStyleBrandLabel => '큰 로고';

  @override
  String get homeTitleStyleClassicDescription =>
      '원래 제목 스타일을 유지합니다. 텍스트만 표시하고 탭하면 시간표를 전환합니다.';

  @override
  String get homeTitleStyleBrandDescription =>
      '큰 로고와 작은 시간표 이름을 표시합니다. 브랜드 감성을 강조합니다.';

  @override
  String get widgetBackgroundStyleGlass => '반투명 유리';

  @override
  String get widgetBackgroundStyleSolid => '단색 카드';

  @override
  String get widgetBackgroundStyleGradient => '그라데이션 카드';

  @override
  String get homeWidgetTargetCompact22 => '메인 카드 2×2';

  @override
  String get homeWidgetTargetMiniList22 => '미니 목록 2×2';

  @override
  String get homeWidgetTargetMedium24 => '개요 2×4';

  @override
  String get homeWidgetTargetLarge44 => '목록 4×4';

  @override
  String get addCourseSheetTitle => '콘텐츠 추가';

  @override
  String get addCourseSheetSubtitle =>
      '빈 시간표 영역은 탭에 반응하지 않습니다. 임시 수업, 학기 전체 반복 수업, 또는 단일 일정 삽입을 명확히 선택하세요.';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription · $weekday $startSection-$endSection교시';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday $startSection-$endSection교시 · $startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '제$week주 $weekday $startSection-$endSection교시로 변경됨';
  }

  @override
  String courseCountSummary(int count) {
    return '$count과목';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '진행 중 · 남은 $minutes분';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return '곧 종료 · 남은 $minutes분';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '진행 중 · 남은 $minutes분';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return '곧 종료 · 남은 $minutes분';
  }

  @override
  String get currentBadge => '현재';

  @override
  String get feedbackXiaohongshuTitle => '샤오홍슈';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return '샤오홍슈 ID: $id';
  }

  @override
  String get feedbackCoolapkTitle => 'Coolapk';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return 'Coolapk ID: $id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQ 그룹';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return '그룹 ID: $id';
  }

  @override
  String get copiedCurrentTimetable => '현재 시간표를 복사했습니다';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '$startSection-$endSection교시';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time 시작';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time 종료';
  }

  @override
  String get invalidSectionTimeFormat => '교시 시간 형식이 올바르지 않습니다';

  @override
  String get noSectionTimesToSave => '저장할 교시 시간이 없습니다';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolName 가져온 교시';
  }

  @override
  String get unnamedScript => '이름 없는 스크립트';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return '로컬 디버그 모드: $scriptName';
  }

  @override
  String get executeImportScriptTooltip => '가져오기 스크립트 실행';

  @override
  String get switchToMobileWebTooltip => '모바일 페이지로 전환';

  @override
  String get switchToDesktopWebTooltip => '데스크톱 페이지로 전환';

  @override
  String get rememberCurrentInputTooltip => '현재 입력 기억';

  @override
  String get fillRememberedTooltip => '기억된 계정 입력';

  @override
  String get clearRememberedTooltip => '기억된 계정 삭제';

  @override
  String get copyCurrentAddressTooltip => '현재 주소 복사';

  @override
  String get copiedCurrentAddress => '현재 주소를 복사했습니다';

  @override
  String get warehouseLoginHintLocalDebug => '현재 로컬 디버그 스크립트 모드';

  @override
  String get warehouseLoginHintImport => '여기서 교무 시스템에 로그인한 뒤 가져오기를 실행합니다';

  @override
  String get currentPageModeDesktop => '현재 페이지 모드: 데스크톱';

  @override
  String get currentPageModeMobile => '현재 페이지 모드: 모바일';

  @override
  String localScriptLabel(String scriptName) {
    return '로컬 스크립트: $scriptName';
  }

  @override
  String get webAddressHint => '웹 주소 입력';

  @override
  String get goAction => '이동';

  @override
  String rememberedAccountLabel(String username) {
    return '기억된 계정: $username';
  }

  @override
  String get importingAction => '가져오는 중...';

  @override
  String get executeLocalDebugScriptAction => '로컬 디버그 스크립트 실행';

  @override
  String get executeImportScriptAction => '가져오기 스크립트 실행';

  @override
  String get invalidWebAddress => '웹 주소가 유효하지 않습니다';

  @override
  String get injectingLocalDebugScript => '로컬 디버그 스크립트 주입 중';

  @override
  String get injectingAdapterScript => '어댑터 스크립트 주입 중';

  @override
  String get localDebugScriptInjected => '로컬 디버그 스크립트 주입됨';

  @override
  String get scriptInjected => '스크립트 주입됨';

  @override
  String get scriptInjectionFailed => '스크립트 주입 실패';

  @override
  String executeFailedWithError(String error) {
    return '실행 실패: $error';
  }

  @override
  String get importFlowFinished => '가져오기 프로세스 완료';

  @override
  String get defaultContinuePrompt => '안내에 따라 계속 진행하세요';

  @override
  String get inputRequiredTitle => '입력 필요';

  @override
  String get pleaseEnterFourDigitYear => '4자리 연도를 입력하세요';

  @override
  String get pleaseChooseTitle => '선택하세요';

  @override
  String get invalidCourseConfigFormat => '수업 설정 형식이 올바르지 않습니다';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '수업 설정 저장 실패: $error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '교시 시간 저장 실패: $error';
  }

  @override
  String get invalidCourseDataFormat => '수업 데이터 형식이 올바르지 않습니다';

  @override
  String get noImportableCoursesFromScript => '스크립트가 가져올 수 있는 수업을 반환하지 않았습니다';

  @override
  String importCourseCountPrompt(int count) {
    return '$count과목을 인식했습니다. 가져오시겠습니까?';
  }

  @override
  String get importCancelledStatus => '가져오기 취소됨';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '반환된 템플릿 적용 실패: $error';
  }

  @override
  String get importInterruptedStatus => '가져오기 중단됨';

  @override
  String get importFailedStatus => '가져오기 실패';

  @override
  String importFailedWithError(String error) {
    return '가져오기 실패: $error';
  }

  @override
  String get unknownTeacher => '알 수 없는 교사';

  @override
  String get unknownLocation => '알 수 없는 장소';

  @override
  String get autofillLoginTitle => '로그인 정보 자동 입력';

  @override
  String autofillLoginMessage(String username) {
    return '기억된 계정 $username을(를) 감지했습니다. 자동 입력하시겠습니까?';
  }

  @override
  String get notNowAction => '나중에';

  @override
  String get autofillAction => '자동 입력';

  @override
  String get rememberPasswordTitle => '비밀번호 기억';

  @override
  String rememberPasswordMessage(String username) {
    return '계정 $username의 로그인 정보를 기억하고 다음에 자동 입력하시겠습니까?';
  }

  @override
  String get dontRememberAction => '기억 안 함';

  @override
  String get rememberAndAutofillAction => '기억하고 자동 입력';

  @override
  String get savedRememberedLoginStatus => '기억된 로그인 정보 저장됨';

  @override
  String get autofilledRememberedLoginStatus => '기억된 로그인 정보 자동 입력됨';

  @override
  String get noRecognizedLoginInputs => '로그인 입력 항목이 인식되지 않았습니다';

  @override
  String get noUsernameOrPasswordRecognized => '사용자 이름 또는 비밀번호가 인식되지 않았습니다';

  @override
  String get rememberedCurrentLoginStatus => '현재 로그인 정보 기억됨';

  @override
  String get rememberedCurrentLoginSuccess => '현재 로그인 정보를 기억했습니다';

  @override
  String rememberLoginFailedWithError(String error) {
    return '로그인 정보 기억 실패: $error';
  }

  @override
  String get clearedRememberedLoginStatus => '기억된 로그인 정보 삭제됨';

  @override
  String get clearedRememberedLoginSuccess => '기억된 로그인 정보를 삭제했습니다';

  @override
  String get addScheduleTitle => '일정 추가';

  @override
  String get editScheduleTitle => '일정 편집';

  @override
  String get addScheduleAction => '일정 추가';

  @override
  String get scheduleTitleLabel => '일정 제목';

  @override
  String get scheduleTitleHint => '예: 조모임, 서류 처리, 택배 수령';

  @override
  String get scheduleTitleRequired => '일정 제목을 입력하세요';

  @override
  String get scheduleInfoSectionTitle => '일정 정보';

  @override
  String get scheduleInfoSectionSubtitle =>
      '일정은 구체적인 날짜로 일간 뷰 타임라인에 삽입됩니다. 수업 자체는 변경하지 않습니다.';

  @override
  String get scheduleTimeSectionTitle => '시간 설정';

  @override
  String get scheduleTimeSectionSubtitle =>
      '이 일정이 실제로 발생하는 날짜와 시작/종료 시간을 선택하세요.';

  @override
  String get scheduleAppearanceSectionTitle => '표시 스타일';

  @override
  String get scheduleAppearanceSectionSubtitle => '수업과 쉽게 구분되는 일정 색상을 선택하세요.';

  @override
  String get scheduleLocationLabel => '장소';

  @override
  String get scheduleLocationHint => '선택사항';

  @override
  String get scheduleDateLabel => '날짜';

  @override
  String get scheduleStartGroupLabel => '시작';

  @override
  String get scheduleEndGroupLabel => '종료';

  @override
  String get scheduleStartDateLabel => '시작일';

  @override
  String get scheduleEndDateLabel => '종료일';

  @override
  String get scheduleStartTimeLabel => '시작 시간';

  @override
  String get scheduleEndTimeLabel => '종료 시간';

  @override
  String get scheduleColorLabel => '일정 색상';

  @override
  String get scheduleNoteLabel => '메모';

  @override
  String get scheduleNoteHint => '선택사항';

  @override
  String get scheduleBadgeLabel => '일정';

  @override
  String scheduleCountSummary(int count) {
    return '일정 $count건';
  }

  @override
  String get scheduleTimeRangeInvalid => '종료 시간은 시작 시간보다 나중이어야 합니다';

  @override
  String get scheduleDateRangeInvalid => '종료일은 시작일보다 이전일 수 없습니다';

  @override
  String get scheduleSingleDayHint => '같은 날 종료 시 종료 시간은 시작 시간보다 나중이어야 합니다.';

  @override
  String get scheduleCrossDayHint => '날짜 초과 일정은 당일 슬라이스로 일간 뷰에 표시됩니다.';

  @override
  String get scheduleSavedHint => '일정이 추가되었습니다';

  @override
  String get scheduleUpdatedHint => '일정이 업데이트되었습니다';

  @override
  String get crossDayBadgeLabel => '날짜 초과';

  @override
  String deleteScheduleMessage(String title) {
    return '일정 \"$title\"을(를) 삭제하시겠습니까?';
  }

  @override
  String get scheduleDeletedHint => '일정이 삭제되었습니다';

  @override
  String get examListTitle => '시험 일정';

  @override
  String get addExam => '시험 추가';

  @override
  String get editExam => '시험 편집';

  @override
  String get saveExam => '시험 저장';

  @override
  String get noExams => '시험 일정 없음';

  @override
  String get examToday => '오늘 시험 있음';

  @override
  String daysUntilExam(int days) {
    return '시험까지 $days일 남음';
  }

  @override
  String get examPassed => '종료됨';

  @override
  String get linkCourse => '수업 연결';

  @override
  String get linkCourseRequired => '연결할 수업을 선택하세요';

  @override
  String get examNameLabel => '시험명';

  @override
  String get examNameRequired => '시험명을 입력하세요';

  @override
  String get examDateLabel => '시험일';

  @override
  String get examDateHint => '날짜 선택';

  @override
  String get examDateRequired => '시험일을 선택하세요';

  @override
  String get examStartTimeLabel => '시작 시간';

  @override
  String get examEndTimeLabel => '종료 시간';

  @override
  String get examLocationLabel => '시험 장소';

  @override
  String get examLocationHint => '비워두면 수업 강의실을 사용합니다';

  @override
  String get sameAsClassroom => '수업 강의실과 동일';

  @override
  String get examSeatLabel => '좌석 번호';

  @override
  String get examReminderLabel => '알림 설정';

  @override
  String get examNoteLabel => '메모';

  @override
  String get deleteExam => '시험 삭제';

  @override
  String deleteExamConfirm(String name) {
    return '시험 \'$name\'을(를) 삭제하시겠습니까?';
  }

  @override
  String get examBadgeLabel => '시험';

  @override
  String get examCountdownToday => '오늘';

  @override
  String examCountdownDays(int days) {
    return '$days일 후';
  }

  @override
  String get sortAction => '정렬';

  @override
  String get sortByAdded => '추가 순서';

  @override
  String get sortByName => '수업명 순';

  @override
  String get sortBySchedule => '배치 시간 순';

  @override
  String scheduleEntryTitle(int index) {
    return '배치 레코드 $index';
  }

  @override
  String get scheduleEntrySingleTitle => '수업 일정';

  @override
  String get scheduleEntryCardSubtitle =>
      '이 수업이 언제, 어떤 주에, 누가 어디에서 진행되는지 설정합니다.';

  @override
  String get scheduleEntryTimeSectionTitle => '언제';

  @override
  String get scheduleEntryTimeSectionSubtitle =>
      '요일과 교시를 선택하세요. 연강은 시작·종료 교시를, 단일 교시는 같은 번호로 맞춥니다.';

  @override
  String get scheduleEntryWeeksSectionTitle => '어떤 주';

  @override
  String get scheduleEntryPeopleSectionTitle => '교수와 강의실';

  @override
  String get scheduleEntryTimeSchemeSectionTitle => '별도 시간표';

  @override
  String get scheduleEntryTimeSchemeSectionSubtitle =>
      '기본값은 현재 시간표를 따릅니다. 이 수업만 종 다른 시간이면 변경하세요.';

  @override
  String scheduleSectionNumberLabel(int section) {
    return '$section교시';
  }

  @override
  String get addScheduleEntryAction => '배치 시간 추가';

  @override
  String get deleteScheduleEntryAction => '배치 삭제';

  @override
  String get holidaySettingsEntryTitle => '공휴일 표시';

  @override
  String get holidaySettingsEntrySubtitle => '시간표에 법정 공휴일과 대체 근무일을 표시합니다';

  @override
  String get holidayMakeupWorkday => '대체 근무';

  @override
  String get holidaySettingsTitle => '공휴일 표시';

  @override
  String get holidayEnableTitle => '공휴일 표시 활성화';

  @override
  String get holidayEnableSubtitle => '켜면 시간표에 법정 공휴일과 대체 근무일을 표시합니다';

  @override
  String get holidayDataSectionTitle => '공휴일 데이터';

  @override
  String get holidayDataYear => '연도';

  @override
  String get holidayDataCount => '건수';

  @override
  String get holidayDataEmpty => '공휴일 데이터 없음';

  @override
  String get holidayCheckUpdate => '업데이트 확인';

  @override
  String get holidayUpcomingSectionTitle => '다가오는 공휴일';

  @override
  String get holidayNoUpcoming => '다가오는 공휴일 없음';

  @override
  String get holidayBadgeLabel => '휴';

  @override
  String get holidayStatusLabel => '휴일';

  @override
  String get suspendedBadgeLabel => '정';

  @override
  String get suspendedStatusLabel => '수업 중단';

  @override
  String get courseActionSuspend => '수업 중단';

  @override
  String get courseActionUnsuspend => '복구';

  @override
  String get courseActionEditPrimary => '수업 편집';

  @override
  String get courseActionRescheduleSecondary => '시간 변경';

  @override
  String get courseActionSuspendSecondary => '휴강';

  @override
  String get courseActionDeleteSecondary => '삭제';

  @override
  String courseActionSheetNotice(int week) {
    return '현재 제$week주를 보고 있습니다. 시험이나 충돌이 생기면 아래에서 바로 변경하거나 휴강할 수 있습니다.';
  }

  @override
  String get courseActionOddWeekShort => '홀수 주';

  @override
  String get courseActionEvenWeekShort => '짝수 주';

  @override
  String get suspendSheetTitle => '수업 중단';

  @override
  String get suspendSheetSubtitle => '중단 범위 선택';

  @override
  String get suspendThisWeek => '이번주 중단';

  @override
  String get suspendThisWeekDesc => '현재 주만 일시 중단';

  @override
  String get suspendAllWeeks => '전체 중단';

  @override
  String get suspendAllWeeksDesc => '모든 주차 일시 중단';

  @override
  String get unsuspendAllWeeks => '전체 복구';

  @override
  String get unsuspendAllWeeksDesc => '모든 주차 복구';

  @override
  String get customHolidayTitle => '사용자 정의 휴일';

  @override
  String get customHolidayAdd => '휴일 추가';

  @override
  String get customHolidayEdit => '휴일 편집';

  @override
  String get customHolidayDelete => '삭제';

  @override
  String get customHolidayDeleteConfirm => '이 사용자 정의 휴일을 삭제하시겠습니까?';

  @override
  String get customHolidayNameLabel => '휴일 이름';

  @override
  String get customHolidayStartDate => '시작일';

  @override
  String get customHolidayEndDate => '종료일';

  @override
  String get customHolidayType => '유형';

  @override
  String get customHolidayTypeVacation => '휴일';

  @override
  String get customHolidayTypeWorkday => '대체 근무';

  @override
  String get customHolidayEmpty => '사용자 정의 휴일 없음';

  @override
  String get customHolidayNameRequired => '휴일 이름을 입력하세요';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '교사 선택';

  @override
  String get selectLocationTitle => '강의실 선택';

  @override
  String get historyRecordsLabel => '기록';

  @override
  String get noHistoryRecords => '기록 없음';

  @override
  String get weekPickerTitle => '수업 주차 선택';

  @override
  String get selectTimeSchemeTitle => '시간 방안 선택';

  @override
  String get manageTimeSchemesAction => '시간 방안 관리';

  @override
  String get examDefaultName => '기말고사';

  @override
  String get examDateWeekPickerTitle => '시험일 선택';

  @override
  String get weekPickerCalendarTooltip => '달력으로 선택';

  @override
  String get thisWeekLabel => '이번주';

  @override
  String get guidePrivacyPageTitle => '개인정보 처리방침';

  @override
  String get guidePermissionsPageTitle => '시스템 권한';

  @override
  String get guideTipsPageTitle => '사용 팁';

  @override
  String get guidePrevButton => '이전';

  @override
  String get guideNextButton => '다음';

  @override
  String get guidePermissionsHeader => '시스템 권한 설정';

  @override
  String get guidePermissionsSubtitle => '이 설정을 완료해야 슈퍼아일랜드와 알림이 정상 작동합니다';

  @override
  String get guidePermissionsFooterHint =>
      '탭하면 시스템 설정으로 이동합니다. 앱으로 돌아오면 인식 가능한 상태가 자동으로 갱신됩니다. 자동 시작은 시스템 제한이 있으므로 시스템 페이지 스위치를 기준으로 하세요.';

  @override
  String get guideTipsHeader => '사용 팁';

  @override
  String get guideTipsSubtitle => '이것들은 언제든 \'설정\'에서 찾을 수 있습니다';

  @override
  String get guidePrivacyReadBeforeUse => '사용 전 아래 내용을 읽고 동의하세요';

  @override
  String get guidePrivacyViewOnly => '개인정보, 서드파티 SDK 및 면책 사항';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year년 법정 공휴일';
  }

  @override
  String get holidayUpdateLog => '업데이트 로그';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count건';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month월 $start일 - $end일';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month월 $day일';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth월 $startDay일 - $endMonth월 $endDay일';
  }

  @override
  String get liveTestingHolidayOverride => '휴일 상태 덮어쓰기';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      '켜면 휴일 상태를 시뮬레이션합니다. 알림과 위젯이 수업을 올바르게 숨기는지 테스트할 수 있습니다.';

  @override
  String get liveTestingHolidayModeEnabled => '휴일 모드 활성화됨';

  @override
  String get liveTestingHolidayModeDisabled => '휴일 모드 비활성화됨';

  @override
  String get liveTestingHolidayModeEnabledDesc => '수업 알림과 위젯이 모든 수업을 숨깁니다';

  @override
  String get liveTestingHolidayModeDisabledDesc => '현재 일반 휴일 데이터를 사용 중입니다';

  @override
  String get textColorTitle => '텍스트 색상';

  @override
  String get textColorSubtitle => '시간표 각 영역의 텍스트 색상 사용자 지정';

  @override
  String get textColorIndependentDetail => '세부 색상 개별 설정';

  @override
  String get textColorCourseCardTitle => '수업 카드 제목 색상';

  @override
  String get textColorCourseCardDetail => '수업 카드 세부 색상';

  @override
  String get textColorWeekdayBar => '요일 바 글꼴 색상';

  @override
  String get textColorWeekdayBarAccent => '요일 바 강조 색상';

  @override
  String get textColorTimeAxis => '시간축 글꼴 색상';

  @override
  String get textColorSelectColor => '색상 선택';

  @override
  String get textColorCurrentColor => '현재 색상';

  @override
  String get themeExport => '테마 내보내기';

  @override
  String get themeImport => '테마 가져오기';

  @override
  String get themeExportSuccess => '테마가 클립보드에 복사되었습니다';

  @override
  String get themeImportSuccess => '테마를 가져왔습니다';

  @override
  String get themeImportFailed => '클립보드 내용 형식 오류';

  @override
  String get themeManageTitle => '테마 관리';

  @override
  String get themeManageSubtitle => '테마 내보내기, 가져오기, 전환';

  @override
  String get themePreset => '프리셋 테마';

  @override
  String get themeSaved => '내 테마';

  @override
  String get themeSaveCurrent => '현재 테마 저장';

  @override
  String get themeApply => '적용';

  @override
  String get themeDelete => '삭제';

  @override
  String themeDeleteConfirmMessage(String name) {
    return '테마 \"$name\"을(를) 삭제하시겠습니까?';
  }

  @override
  String get textColorLowContrastWarning => '색상 대비가 낮아 가독성에 영향을 줄 수 있습니다';

  @override
  String get themeCurrentTheme => '현재 테마';

  @override
  String themeBasedOnModified(String baseName) {
    return '$baseName (수정됨)';
  }

  @override
  String get themeResetToPreset => '초기화';

  @override
  String get themeUnsavedChangesTitle => '저장되지 않은 변경사항';

  @override
  String get themeUnsavedChangesMessage =>
      '현재 테마에 저장되지 않은 변경사항이 있습니다. 저장하시겠습니까?';

  @override
  String get themeDiscardAndApply => '버리고 적용';

  @override
  String get themeNameHint => '테마 이름 입력';

  @override
  String get themePresetBlue => '기본 블루';

  @override
  String get themePresetPurple => '나이트 퍼플';

  @override
  String get themePresetGreen => '포레스트 그린';

  @override
  String get themePresetOrange => '웜 오렌지';

  @override
  String get themePresetEyeCare => '눈 보호';

  @override
  String get themePresetHighContrast => '고대비';

  @override
  String get themePresetDarkMinimal => '다크 미니멀';

  @override
  String get themeUndo => '실행 취소';

  @override
  String themeChanged(String themeName) {
    return '$themeName로 전환되었습니다';
  }

  @override
  String get themeRename => '이름 변경';

  @override
  String get themeDuplicate => '복사';

  @override
  String themeDuplicateCopyName(String name) {
    return '$name 복사본';
  }

  @override
  String get themeMoreActions => '더 보기';

  @override
  String get courseNatureRequired => '필수';

  @override
  String get courseNatureElective => '선택';

  @override
  String get homeMenuStatisticsTitle => '수업 통계';

  @override
  String get statisticsTitle => '수업 통계';

  @override
  String get statisticsOverview => '이번 주 개요';

  @override
  String get statisticsCourseCount => '수업 수';

  @override
  String get statisticsSectionCount => '이번 주 수업 시간';

  @override
  String get statisticsWeeklyCourses => '이번 주 수업';

  @override
  String get statisticsDailyDistribution => '요일별 수업 분포';

  @override
  String get statisticsNatureRatio => '필수 / 선택';

  @override
  String get statisticsCourseList => '수업 목록';

  @override
  String get statisticsSectionsUnit => '교시';

  @override
  String get statisticsSectionUnit => '교시';

  @override
  String get statisticsNoData => '수업 데이터 없음';

  @override
  String get statisticsCourseCountRatio => '수업 수 비율';

  @override
  String get statisticsSectionCountRatio => '수업 시간 비율';

  @override
  String statisticsWeekSelector(int week) {
    return '$week주차';
  }

  @override
  String get statisticsStoryBusiestDayTitle => '가장 바쁜 날';

  @override
  String statisticsStoryBusiestDayContent(int week, String day, String avg) {
    return '$week주차까지 가장 바쁜 날은 **$day**, 평균 **$avg** 교시';
  }

  @override
  String get statisticsStoryLightestDayTitle => '가장 여유로운 날';

  @override
  String statisticsStoryLightestDayContent(int week, String day, String avg) {
    return '$week주차까지 가장 여유로운 날은 **$day**, 단 **$avg** 교시';
  }

  @override
  String get statisticsStoryFavoriteRoomTitle => '자주 가는 강의실';

  @override
  String statisticsStoryFavoriteRoomContent(int week, String room, int count) {
    return '$week주차까지 가장 자주 간 강의실은 **$room**, **$count**회';
  }

  @override
  String get statisticsStoryBuildingCountTitle => '캠퍼스 탐험';

  @override
  String statisticsStoryBuildingCountContent(int week, int count) {
    return '$week주차까지 수업이 **$count**개 건물에 분포';
  }

  @override
  String get statisticsStoryTimeRangeTitle => '시간 범위';

  @override
  String statisticsStoryTimeRangeContent(String earliest, String latest) {
    return '가장 이른 수업 **$earliest**, 가장 늦은 수업 **$latest**';
  }

  @override
  String get statisticsSemesterLabelCourses => '과목';

  @override
  String get statisticsSemesterLabelSections => '교시';

  @override
  String get statisticsSemesterLabelWeeks => '주';

  @override
  String get statisticsSemesterLabelDayStreak => '일 연속';

  @override
  String get statisticsAchievementsTitle => '업적 배지';

  @override
  String get statisticsStoriesTitle => '데이터 스토리';

  @override
  String get statisticsRankingTitle => '과목 순위';

  @override
  String get statisticsNoDataHint => '수업을 추가하면 통계를 볼 수 있습니다';

  @override
  String get statisticsShareLabel => '통계 공유';

  @override
  String get statisticsShareTitle => '내 학기 통계';

  @override
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  ) {
    return '$day $startSection-$endSection교시';
  }

  @override
  String get statisticsAchievementEarlyBirdName => '얼리버드';

  @override
  String get statisticsAchievementEarlyBirdDescription => '8:00 수업 있음';

  @override
  String get statisticsAchievementPerfectAttendanceName => '개근상';

  @override
  String get statisticsAchievementPerfectAttendanceDescription =>
      '매주 빠짐없이 듣는 과목';

  @override
  String get statisticsAchievementWeekendWarriorName => '주말 전사';

  @override
  String get statisticsAchievementWeekendWarriorDescription => '주말 수업 있음';

  @override
  String get statisticsAchievementClassKingName => '수업왕';

  @override
  String get statisticsAchievementClassKingDescription => '하루 6교시 이상';

  @override
  String get statisticsAchievementScholarName => '학습왕';

  @override
  String get statisticsAchievementScholarDescription => '총 100교시 이상';

  @override
  String get statisticsAchievementBalancedName => '균형 마스터';

  @override
  String get statisticsAchievementBalancedDescription => '요일별 차이 2교시 이내';

  @override
  String get statisticsAchievementNightOwlName => '올빼미';

  @override
  String get statisticsAchievementNightOwlDescription => '18:00 이후 수업 있음';

  @override
  String get statisticsAchievementExplorerName => '교실 탐험가';

  @override
  String get statisticsAchievementExplorerDescription => '5개 이상 교실 이용';

  @override
  String statisticsNatureLegendDetail(int count, int sections) {
    return '$count 과목 · $sections 교시';
  }

  @override
  String get weekListSeparator => ', ';

  @override
  String courseWeekListLabel(String weeks) {
    return '제$weeks주';
  }

  @override
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode) {
    return '제$startWeek-$endWeek주$mode';
  }

  @override
  String courseWeekSuspendedLabel(String weeks) {
    return '제$weeks주 휴강';
  }

  @override
  String get importSemesterStartDateTitle => '개학일';

  @override
  String get importSemesterStartDateSubtitle =>
      'Treat the week containing this date as calendar week 1';

  @override
  String get importFirstCourseWeekMappingLabel =>
      'Timetable week 1 maps to calendar week';

  @override
  String get importFirstCourseWeekMappingSubtitle =>
      'If the first school week has no classes, choose week 2; if the first two weeks are empty, choose week 3.';

  @override
  String get importSemesterMappingNoShiftHint =>
      'After import, timetable week 1 will be treated as calendar week 1.';

  @override
  String importSemesterMappingShiftHint(int shiftedWeeks, int calendarWeek) {
    return 'All course weeks will shift forward by $shiftedWeeks so timetable week 1 lands on calendar week $calendarWeek.';
  }

  @override
  String calendarWeekOption(int week) {
    return 'Calendar week $week';
  }

  @override
  String get aboutDownloadPackageMethodTitle => 'Download install method';

  @override
  String get aboutInAppDownloadTitle => 'In-app download';

  @override
  String get aboutInAppDownloadSubtitle =>
      'Install directly in the app after download completes';

  @override
  String get aboutSystemDownloaderTitle => 'System download manager';

  @override
  String get aboutSystemDownloaderChoiceSubtitle =>
      'Hand off to the system download manager';

  @override
  String get syncErrorAuthFailed => 'Invalid username or password';

  @override
  String get syncErrorAccessDenied => 'Access denied';

  @override
  String get syncErrorCertificateError => 'Certificate error';

  @override
  String get syncErrorConnectionTimeout => 'Connection timed out';

  @override
  String get syncErrorConnectionFailed => 'Could not connect to server';

  @override
  String get syncErrorNetworkError => 'Network error';

  @override
  String get syncErrorInvalidResponse => 'Invalid server response';

  @override
  String get syncErrorLocalChangesPendingSync =>
      'Skipped auto sync because local changes are pending';

  @override
  String get syncErrorMissingCredentials => 'Configure sync account first';

  @override
  String get syncErrorBackupNotFound => 'Backup not found';

  @override
  String get syncErrorMissingBackupSnapshot => 'Backup snapshot is missing';

  @override
  String get syncErrorCannotDeleteCurrentBackup =>
      'Cannot delete the current backup';

  @override
  String get syncErrorProviderNotReady => 'Timetable is not ready';

  @override
  String get syncErrorSyncFailed => '동기화 실패';

  @override
  String get sectionTimeDisplayHidden => 'Hidden';

  @override
  String get sectionTimeDisplayStartOnly => 'Start time only';

  @override
  String get sectionTimeDisplayStartAndEnd => 'Start and end times';

  @override
  String get examReminderNone => 'No reminder';

  @override
  String get examReminderMin30 => '30 minutes before';

  @override
  String get examReminderHour1 => '1 hour before';

  @override
  String get examReminderHour1AndMin30 => '1 hour and 30 minutes before';

  @override
  String get examReminderDay1 => '1 day before';

  @override
  String get examReminderDay1AndHour1 => '1 day and 1 hour before';

  @override
  String get examReminderCustom => 'Custom';

  @override
  String get debugCopiedJson => 'JSON copied';

  @override
  String get liveDuringClassTimeNearest => 'Nearest time';

  @override
  String get liveDuringClassTimeTotal => 'Total time';

  @override
  String get liveCountdownTextStyleSmart => 'Smart (localized)';

  @override
  String get liveCountdownTextStyleSmartMinS => 'Smart (min/s)';

  @override
  String get liveCountdownTextStyleMinuteSecondCn =>
      'Minutes and seconds (5m19s)';

  @override
  String get liveCountdownTextStyleMinuteSecondColon => 'mm:ss (05:19)';

  @override
  String get liveCountdownTextStyleMinuteSecondMinS => 'min+s (5min19s)';

  @override
  String get liveCountdownTextStyleMinuteSecondMinSlashS => 'min/s (5min/19s)';

  @override
  String get liveCountdownTextStyleMinuteOnlyCn => 'Minutes only (5 min)';

  @override
  String get liveCountdownTextStyleMinuteOnlyMin => 'min (5min)';

  @override
  String get liveCountdownTextStyleMinuteOnlySlash => '/min (5/min)';

  @override
  String get liveCountdownTextStyleSecondOnlyCn => 'Seconds only (5 s)';

  @override
  String get liveCountdownTextStyleSecondOnlyShort => 's (5s)';

  @override
  String get liveCountdownTextStyleSecondOnlySlash => '/s (5/s)';

  @override
  String get miuiIslandLabelStyleTextOnly => 'Text only';

  @override
  String get miuiIslandLabelStyleIconAndText => 'Icon + text';

  @override
  String get miuiIslandLabelContentCourseName => 'Course name';

  @override
  String get miuiIslandLabelContentLocation => 'Room';

  @override
  String get miuiIslandLabelContentCourseNameAndLocation => 'Course + room';

  @override
  String get miuiIslandLabelFontWeightRegular => 'Regular';

  @override
  String get miuiIslandLabelFontWeightMedium => 'Medium';

  @override
  String get miuiIslandLabelFontWeightBold => 'Bold';

  @override
  String get miuiIslandLabelRenderQualityStandard => 'Standard';

  @override
  String get miuiIslandLabelRenderQualityHigh => 'High';

  @override
  String get miuiIslandLabelRenderQualityUltra => 'Ultra';

  @override
  String get miuiIslandExpandedIconAppIcon => 'App icon';

  @override
  String get miuiIslandExpandedIconCustomImage => 'Custom image';

  @override
  String get miuiIslandExpandedIconHidden => 'Hidden';

  @override
  String get liveBeforeClassQuickActionNone => 'Hidden';

  @override
  String get liveBeforeClassQuickActionSilent => 'Turn on silent mode';

  @override
  String get liveBeforeClassQuickActionDoNotDisturb => 'Turn on Do Not Disturb';

  @override
  String get courseCardVerticalAlignTop => 'Top';

  @override
  String get courseCardVerticalAlignCenter => 'Center';

  @override
  String get courseCardVerticalAlignBottom => 'Bottom';

  @override
  String get courseCardVerticalAlignSpaceEvenly => 'Space evenly';

  @override
  String get courseCardHorizontalAlignLeft => 'Left';

  @override
  String get courseCardHorizontalAlignCenter => 'Center';

  @override
  String get courseCardHorizontalAlignRight => 'Right';

  @override
  String get timetableTimeColumnWidthNarrow => 'Narrow';

  @override
  String get timetableTimeColumnWidthWide => 'Wide';

  @override
  String get timetableCourseSpacingNarrow => 'Narrow';

  @override
  String get timetableCourseSpacingWide => 'Wide';

  @override
  String get appUpdateDownloadSourceOriginal => 'GitHub original';

  @override
  String get appUpdateDownloadSourceMirror => 'Mirror';

  @override
  String get appUpdateDownloadChannelPgyer => 'Pgyer download';

  @override
  String get appUpdateDownloadChannelGithub => 'GitHub download';

  @override
  String get appUpdateDownloadChannelPgyerDescription =>
      'Fast download in China, recommended';

  @override
  String get appUpdateDownloadChannelGithubDescription => 'GitHub plus mirrors';

  @override
  String get holidayStatutoryLabel => '공휴일';

  @override
  String get serviceMsgImportFileUnrecognized =>
      'Import failed. The file content could not be recognized.';

  @override
  String get serviceMsgImportUseOverwriteForFullBackup =>
      'This is a full data backup. Please import using overwrite current timetable.';

  @override
  String get serviceMsgImportNoProfilesInBackup =>
      'No recoverable timetables were found in the backup file.';

  @override
  String get serviceMsgUnrecognizedMikcbDataFile =>
      'Not a recognizable mikcb data file.';

  @override
  String get serviceMsgMissingSettingsData => 'Settings data is missing.';

  @override
  String get serviceMsgUnrecognizedMikcbFullBackup =>
      'Not a recognizable mikcb full backup file.';

  @override
  String get serviceMsgMissingFullBackupData =>
      'Complete backup data is missing.';

  @override
  String get serviceMsgUseProfileBackupNotFull =>
      'Use a timetable profile backup JSON, not a full data backup.';

  @override
  String get serviceMsgUnrecognizedSyncSnapshot =>
      'Not a recognizable mikcb cloud sync snapshot.';

  @override
  String get serviceMsgMissingSyncTimetableData =>
      'Cloud sync timetable data is missing.';

  @override
  String get serviceMsgSyncSnapshotChecksumFailed =>
      'Cloud sync snapshot verification failed.';

  @override
  String get serviceMsgSyncSnapshotNoProfiles =>
      'No recoverable timetables in the cloud sync snapshot.';

  @override
  String get serviceMsgSyncSnapshotUnrecognized =>
      'Cloud sync snapshot could not be recognized.';

  @override
  String get serviceMsgTimeSchemeNotFound => 'Time scheme not found.';

  @override
  String get serviceMsgTimeSchemeConfigUnavailable =>
      'Current timetable time configuration is unavailable.';

  @override
  String get serviceMsgTimeSchemeNotFoundSelected =>
      'Selected time scheme was not found.';

  @override
  String serviceMsgTimeSchemeSectionsInsufficient(
    int startSection,
    int endSection,
  ) {
    return 'Selected time scheme does not have enough sections for sections $startSection-$endSection.';
  }

  @override
  String serviceMsgSectionCountBelowUsage(int requiredMaxSection) {
    return 'Section count cannot be less than the maximum section in use (section $requiredMaxSection).';
  }

  @override
  String serviceMsgSectionCountBelowUsageDetail(
    int requiredMaxSection,
    String profileName,
    String courseName,
    int dayOfWeek,
    int startSection,
    int endSection,
    String usageType,
  ) {
    return 'Section count cannot be less than the maximum section in use (section $requiredMaxSection). In use: $profileName · $courseName (weekday $dayOfWeek sections $startSection-$endSection, $usageType)';
  }

  @override
  String get serviceMsgAtLeastOneSectionRequired =>
      'At least one section time must be kept.';

  @override
  String serviceMsgSectionEndMustAfterStart(int sectionNumber) {
    return 'Section $sectionNumber end time must be later than start time. Overnight classes are not supported.';
  }

  @override
  String serviceMsgSectionStartBeforePreviousEnd(int sectionNumber) {
    return 'Section $sectionNumber start time cannot be earlier than the previous section end time.';
  }

  @override
  String get serviceMsgPeriodStartTimeRequired =>
      'Set the first section start time for periods that have sections.';

  @override
  String serviceMsgSectionCrossesMidnight(int sectionNumber) {
    return 'Section $sectionNumber would cross midnight. Overnight classes are not supported.';
  }

  @override
  String get serviceMsgClassDurationMustPositive =>
      'Class duration must be greater than 0.';

  @override
  String get serviceMsgBreakDurationMustNonNegative =>
      'Break duration cannot be less than 0.';

  @override
  String get serviceMsgAtLeastOnePeriodSection =>
      'At least one period must have sections.';

  @override
  String get serviceMsgInvalidTimeFormat => 'Time format is invalid.';

  @override
  String get serviceMsgLinkedCourseNotFound => 'Linked course was not found.';

  @override
  String get serviceMsgCourseNotFoundForDelete =>
      'Course to delete was not found.';

  @override
  String serviceMsgCourseNotScheduledWeek(int sourceWeek) {
    return 'This course is not scheduled in week $sourceWeek.';
  }

  @override
  String get serviceMsgCourseNotFoundForReschedule =>
      'Course to reschedule was not found.';

  @override
  String get serviceMsgTargetWeekOutOfRange =>
      'Target week is outside the current semester range.';

  @override
  String get serviceMsgAtLeastOneScheduleSlot =>
      'At least one class time slot must be kept.';

  @override
  String get serviceMsgCourseNameRequired => 'Course name cannot be empty.';

  @override
  String get serviceMsgBackupContentRequired =>
      'Backup content cannot be empty.';

  @override
  String get serviceMsgSpreadsheetFormatOrEncodingUnrecognized =>
      'Could not recognize spreadsheet format or encoding. Save CSV as UTF-8 and try again.';

  @override
  String serviceMsgSpreadsheetXlsxParseFailed(String error) {
    return 'Failed to parse XLSX file: $error';
  }

  @override
  String serviceMsgSpreadsheetRowWarning(int rowNumber, String message) {
    return 'Row $rowNumber: $message';
  }

  @override
  String serviceMsgSpreadsheetWakeupInsufficientColumns(
    int rowNumber,
    int columnCount,
  ) {
    return 'WakeUp format needs at least 7 columns, but row $rowNumber has only $columnCount.';
  }

  @override
  String get serviceMsgWeekdayMustBe1To7 => 'Weekday must be between 1 and 7.';

  @override
  String get serviceMsgCustomWeeksRequired => 'Weeks cannot be empty.';

  @override
  String get serviceMsgClassWeeksRequired => 'Class weeks cannot be empty.';

  @override
  String get serviceMsgStartWeekMustBeAtLeast1 =>
      'Start week must be at least 1.';

  @override
  String serviceMsgStartWeekExceedsSemester(
    int startWeek,
    int semesterWeekCount,
  ) {
    return 'Start week $startWeek exceeds semester week count $semesterWeekCount.';
  }

  @override
  String get serviceMsgEndWeekBeforeStartWeek =>
      'End week cannot be earlier than start week.';

  @override
  String get serviceMsgWeeksRangeRequired =>
      'Class weeks or start week + end week must be provided.';

  @override
  String serviceMsgFieldMustBeAtLeast1(String field) {
    return '$field must be at least 1.';
  }

  @override
  String serviceMsgFieldCannotBeLessThan(String startField, String endField) {
    return '$endField cannot be less than $startField.';
  }

  @override
  String serviceMsgSectionOutOfRange(int section, int maxSection) {
    return 'Section $section is outside the time scheme range (1-$maxSection).';
  }

  @override
  String serviceMsgFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgFieldCannotBeEmpty(String field) {
    return '$field cannot be empty.';
  }

  @override
  String serviceMsgSpreadsheetEndWeekClamped(
    int rowNumber,
    int endWeek,
    int semesterWeekCount,
  ) {
    return 'Row $rowNumber: end week $endWeek exceeds semester week count $semesterWeekCount; adjusted to $semesterWeekCount.';
  }

  @override
  String serviceMsgSpreadsheetOddEvenBoth(int rowNumber) {
    return 'Row $rowNumber: odd and even weeks cannot both be selected; treated as odd weeks.';
  }

  @override
  String get serviceMsgFieldCourseName => 'Course name';

  @override
  String get serviceMsgFieldWeekday => 'Weekday';

  @override
  String get serviceMsgFieldStartSection => 'Start section';

  @override
  String get serviceMsgFieldEndSection => 'End section';

  @override
  String get serviceMsgFieldCustomWeeks => 'Weeks';

  @override
  String get serviceMsgFieldClassWeeks => 'Class weeks';

  @override
  String get serviceMsgFieldStartWeek => 'Start week';

  @override
  String get serviceMsgFieldEndWeek => 'End week';

  @override
  String serviceMsgWeekStartInvalid(String itemName) {
    return '$itemName: week range start is invalid.';
  }

  @override
  String serviceMsgWeekRangeInvalid(String itemName) {
    return '$itemName: week range is invalid.';
  }

  @override
  String serviceMsgWeekRangeTooLarge(String itemName) {
    return '$itemName: week range is too large. Please check.';
  }

  @override
  String serviceMsgWeekTokenUnrecognized(String itemName, String token) {
    return '$itemName: unrecognized week token: $token';
  }

  @override
  String serviceMsgWeeksExceedSemesterClamped(
    String itemName,
    int semesterWeekCount,
    String weeks,
  ) {
    return '$itemName contains weeks beyond semester week count $semesterWeekCount ($weeks); excess weeks were ignored.';
  }

  @override
  String get serviceMsgAiResultNotObject =>
      'AI result is not a valid JSON object. Copy the full JSON again.';

  @override
  String serviceMsgAiSchemaMustBe(String schema) {
    return 'schema must be $schema';
  }

  @override
  String get serviceMsgAiCoursesMustBeArray => 'courses must be an array.';

  @override
  String get serviceMsgAiWarningsMustBeArray =>
      'warnings must be a string array.';

  @override
  String get serviceMsgAiWarningItemMustBeString =>
      'Each warnings item must be a string.';

  @override
  String serviceMsgAiCourseNotObject(int index) {
    return 'courses[$index] is not a valid object.';
  }

  @override
  String serviceMsgAiCourseNameEmpty(int index) {
    return 'courses[$index].name cannot be empty.';
  }

  @override
  String serviceMsgAiCourseDayOfWeekInvalid(int index) {
    return 'courses[$index].dayOfWeek must be between 1 and 7.';
  }

  @override
  String serviceMsgAiCourseStartSectionInvalid(int index) {
    return 'courses[$index].startSection must be at least 1.';
  }

  @override
  String serviceMsgAiCourseEndSectionInvalid(int index) {
    return 'courses[$index].endSection cannot be less than startSection.';
  }

  @override
  String serviceMsgAiCourseCustomWeeksEmpty(int index) {
    return 'courses[$index].customWeeks cannot be empty.';
  }

  @override
  String serviceMsgAiCourseNatureInvalid(int index) {
    return 'courses[$index].courseNature must be required or elective.';
  }

  @override
  String serviceMsgAiUnknownFields(String targetName, String fields) {
    return '$targetName contains unsupported fields: $fields';
  }

  @override
  String serviceMsgAiFieldMustBeString(String field) {
    return '$field must be a string.';
  }

  @override
  String serviceMsgAiFieldMustBeInteger(String field) {
    return '$field must be an integer.';
  }

  @override
  String serviceMsgAiWeekListInvalid(String itemName) {
    return '$itemName can only contain integers greater than or equal to 1.';
  }

  @override
  String serviceMsgAiWeekListTypeInvalid(String field) {
    return '$field must be an integer array or week string.';
  }

  @override
  String get serviceMsgNoReleaseAvailable =>
      'No release has been published yet.';

  @override
  String get serviceMsgNoReleaseWithPrerelease =>
      'No stable or prerelease version is available yet.';

  @override
  String serviceMsgUpdateCheckHttpFailed(int statusCode) {
    return 'Update check failed (HTTP $statusCode).';
  }

  @override
  String get serviceMsgUpdateCheckNetworkFailed =>
      'Network error. Unable to check for updates right now.';

  @override
  String get serviceMsgUpdateDownloadUrlUntrusted =>
      'Update download URL failed security validation.';

  @override
  String serviceMsgUpdateDownloadHttpFailed(int statusCode) {
    return 'Download failed (HTTP $statusCode).';
  }

  @override
  String serviceMsgUpdateOpenInstallerFailed(String detail) {
    return 'Failed to open installer: $detail';
  }

  @override
  String serviceMsgUpdateDownloadInstallError(String detail) {
    return 'Download or installation error: $detail';
  }

  @override
  String get serviceMsgInvalidUrl => 'Invalid URL.';

  @override
  String get serviceMsgUpdateAvailablePrerelease =>
      'A new prerelease version is available.';

  @override
  String get serviceMsgUpdateAvailable => 'A new version is available.';

  @override
  String get serviceMsgAlreadyLatest =>
      'You are already on the latest version.';

  @override
  String get serviceMsgShareBackupText =>
      'This is a full backup of the current timetable. Import it to restore courses and settings.';

  @override
  String get serviceMsgShareBackupSubject => 'Qingyu Timetable backup';

  @override
  String serviceMsgShareBackupSubjectNamed(String profileName) {
    return '$profileName - Qingyu Timetable backup';
  }

  @override
  String get serviceMsgShareFullBackupText =>
      'This is a full data backup containing all timetables, the active timetable, and time schemes.';

  @override
  String get serviceMsgShareFullBackupSubject =>
      'Qingyu Timetable - full data backup';

  @override
  String get serviceMsgInvalidRepositoryUrl =>
      'Repository URL format is invalid.';

  @override
  String get serviceMsgIncompleteGithubRepoUrl =>
      'GitHub repository URL is incomplete.';

  @override
  String get serviceMsgIncompleteRawGithubUrl =>
      'raw.githubusercontent.com URL is incomplete.';

  @override
  String get serviceMsgGithubOnlySupported =>
      'Only GitHub repository URLs are supported.';

  @override
  String get serviceMsgWarehouseNoSchoolsIndex =>
      'No school or tool index was found.';

  @override
  String serviceMsgWarehouseNoAdapters(String schoolName) {
    return 'No adapter information was found for $schoolName.';
  }

  @override
  String serviceMsgWarehouseFetchFailedMirror(int candidatesCount) {
    return 'Unable to read the adapter repository. Tried $candidatesCount mirror endpoints. Check your network or switch mirror in Version Update.';
  }

  @override
  String get serviceMsgWarehouseFetchFailedGithub =>
      'Unable to read the adapter repository on GitHub. Check your network or switch to a mirror in Version Update.';

  @override
  String get serviceMsgManualInputCaptcha =>
      'Enter the captcha manually, then tap Continue.';

  @override
  String get serviceMsgManualInputPassword =>
      'Enter the password manually. If it was auto-filled, tap Continue.';

  @override
  String get serviceMsgMacroNoSteps => 'No recorded steps.';

  @override
  String get serviceMsgMacroUserCancelled => 'Cancelled by user.';

  @override
  String serviceMsgMacroStepFailed(
    int stepIndex,
    int totalSteps,
    String detail,
  ) {
    return 'Step $stepIndex/$totalSteps failed: $detail';
  }

  @override
  String get serviceMsgMacroNavigateUrlEmpty => 'Navigation URL is empty.';

  @override
  String serviceMsgMacroNavigateUrlInvalid(String url) {
    return 'Invalid URL: $url';
  }

  @override
  String get serviceMsgMacroFillSelectorEmpty =>
      'Fill-field selector is empty.';

  @override
  String serviceMsgMacroElementNotFound(String selector) {
    return 'Element not found: $selector';
  }

  @override
  String get serviceMsgMacroClickSelectorEmpty => 'Click selector is empty.';

  @override
  String get serviceMsgMacroUrlPatternEmpty => 'URL pattern is empty.';

  @override
  String get serviceMsgMacroWaitSelectorEmpty => 'Wait selector is empty.';

  @override
  String get serviceMsgMacroManualInputDefault => 'Manual action required.';

  @override
  String serviceMsgMacroPollTimeout(
    String stepLabel,
    int timeoutSeconds,
    String lastError,
  ) {
    return '$stepLabel timed out (${timeoutSeconds}s)$lastError';
  }

  @override
  String get serviceMsgMacroReplayNavigate => 'Navigating…';

  @override
  String get serviceMsgMacroReplayFillField => 'Filling form…';

  @override
  String get serviceMsgMacroReplayClick => 'Clicking…';

  @override
  String get serviceMsgMacroReplayWaitUrl => 'Waiting for navigation…';

  @override
  String get serviceMsgMacroReplayWaitSelector => 'Waiting for page element…';

  @override
  String get serviceMsgMacroReplayWaitManual => 'Waiting for user action…';

  @override
  String get serviceMsgMacroReplayExecuteScript => 'Running import script…';

  @override
  String get serviceMsgMacroReplayDelay => 'Waiting…';

  @override
  String serviceMsgMacroReplayFailed(String detail) {
    return 'Failed: $detail';
  }

  @override
  String serviceMsgMacroReplayPaused(String reason) {
    return 'Waiting for manual action: $reason';
  }

  @override
  String serviceMsgSupportDonorsLoadFailed(String detail) {
    return 'Failed to load supporters list: $detail';
  }

  @override
  String serviceMsgStatisticsShareFailed(String detail) {
    return 'Share failed: $detail';
  }

  @override
  String get serviceMsgAuthFailed => 'Invalid username or password.';

  @override
  String get serviceMsgAccessDenied => 'Access denied.';

  @override
  String get serviceMsgCertificateError => 'Certificate validation failed.';

  @override
  String get serviceMsgConnectionTimeout => 'Connection timed out.';

  @override
  String get serviceMsgConnectionFailed => 'Could not connect to the server.';

  @override
  String get serviceMsgInvalidResponse => 'Invalid server response.';

  @override
  String get serviceMsgSyncFailed => 'Sync failed.';

  @override
  String get serviceMsgUsageTypeOverride => 'override time scheme';

  @override
  String get serviceMsgUsageTypeProfile => 'profile main time scheme';

  @override
  String get dataTransferProfileShareText =>
      'This is a full backup of the current timetable from Qingyu Timetable. Import it to restore courses and settings.';

  @override
  String get dataTransferProfileShareSubject => 'Qingyu Timetable backup';

  @override
  String dataTransferProfileShareSubjectNamed(String profileName) {
    return '$profileName - Qingyu Timetable backup';
  }

  @override
  String get dataTransferFullBackupShareText =>
      'This is a full data backup from Qingyu Timetable, including all timetables, the active timetable, and time schemes.';

  @override
  String get dataTransferFullBackupShareSubject =>
      'Qingyu Timetable - Full data backup';

  @override
  String courseWeekCustomDescription(String weeks) {
    return 'Weeks $weeks';
  }

  @override
  String courseWeekRangeDescription(int startWeek, int endWeek, String mode) {
    return 'Weeks $startWeek-$endWeek$mode';
  }

  @override
  String get courseWeekOddModeSuffix => ' odd weeks';

  @override
  String get courseWeekEvenModeSuffix => ' even weeks';

  @override
  String courseWeekSuspensionDescription(String weeks) {
    return 'Suspended weeks $weeks';
  }

  @override
  String get courseWeekListSeparator => ', ';

  @override
  String holidayLogMemoryCacheHit(int year, int count) {
    return '$year: memory cache hit ($count entries), refreshing in background…';
  }

  @override
  String holidayLogLocalCacheHit(int year, int count) {
    return '$year: local cache hit ($count entries), refreshing in background…';
  }

  @override
  String holidayLogNoCacheFetching(int year) {
    return '$year: no cache, fetching remote data…';
  }

  @override
  String holidayLogRemoteSuccess(int year, int count) {
    return '$year: remote fetch succeeded ($count entries), cached';
  }

  @override
  String holidayLogRemoteFailedBuiltin(int year) {
    return '$year: remote fetch failed, using built-in fallback';
  }

  @override
  String holidayLogBuiltinLoaded(int year, int count) {
    return '$year: loaded built-in data ($count entries)';
  }

  @override
  String holidayLogBackgroundSuccess(int year, int count) {
    return '$year: background update succeeded ($count entries), cache updated';
  }

  @override
  String holidayLogBackgroundNoData(int year) {
    return '$year: background update returned no new data';
  }

  @override
  String get holidayLogPrimaryApiFailed =>
      'Primary API failed, trying fallback API…';

  @override
  String holidayLogRequesting(String uri) {
    return 'Requesting $uri …';
  }

  @override
  String holidayLogPrimaryApiStatus(int statusCode) {
    return 'Primary API responded $statusCode, skipping';
  }

  @override
  String holidayLogPrimaryApiError(String message) {
    return 'Primary API error: $message';
  }

  @override
  String holidayLogPrimaryApiException(String error) {
    return 'Primary API exception: $error';
  }

  @override
  String holidayLogPrimaryApiParsing(int count) {
    return 'Primary API returned $count raw entries, parsing…';
  }

  @override
  String get holidayLogNoValidEntries =>
      'No valid entries after parsing, skipping';

  @override
  String holidayLogFallbackApiStatus(int statusCode) {
    return 'Fallback API responded $statusCode, skipping';
  }

  @override
  String get holidayLogFallbackApiError => 'Fallback API returned an error';

  @override
  String holidayLogFallbackApiParsing(int count) {
    return 'Fallback API returned $count raw entries, parsing…';
  }

  @override
  String holidayLogFallbackApiException(String error) {
    return 'Fallback API exception: $error';
  }

  @override
  String get holidayNameNewYear => 'New Year';

  @override
  String get holidayNameLaborDay => 'Labor Day';

  @override
  String get holidayNameNationalDay => 'National Day';

  @override
  String get holidayNameSpringFestival => 'Spring Festival';

  @override
  String get holidayNameQingming => 'Qingming Festival';

  @override
  String get holidayNameDragonBoat => 'Dragon Boat Festival';

  @override
  String get holidayNameMidAutumn => 'Mid-Autumn Festival';

  @override
  String macroReplayStatusFailed(String error) {
    return 'Failed: $error';
  }

  @override
  String macroReplayStatusPaused(String reason) {
    return 'Waiting for manual action: $reason';
  }

  @override
  String get macroReplayStepNavigating => 'Navigating…';

  @override
  String get macroReplayStepFilling => 'Filling form…';

  @override
  String get macroReplayStepClicking => 'Clicking…';

  @override
  String get macroReplayStepWaitUrl => 'Waiting for navigation…';

  @override
  String get macroReplayStepWaitSelector => 'Waiting for page element…';

  @override
  String get macroReplayStepWaitManual => 'Waiting for user action';

  @override
  String get macroReplayStepExecuteScript => 'Running import script…';

  @override
  String get macroReplayStepDelay => 'Waiting…';

  @override
  String get macroReplayNoSteps => 'No recorded steps';

  @override
  String get macroReplayUserCancelled => 'Cancelled by user';

  @override
  String macroReplayStepFailed(int current, int total, String error) {
    return 'Step $current/$total failed: $error';
  }

  @override
  String get macroReplayEmptyNavigateUrl => 'Navigation URL is empty';

  @override
  String macroReplayInvalidUrl(String url) {
    return 'Invalid URL: $url';
  }

  @override
  String get macroReplayEmptyFillSelector => 'Fill selector is empty';

  @override
  String macroReplayFieldNotFound(String selector) {
    return 'Form field not found: $selector';
  }

  @override
  String get macroReplayEmptyClickSelector => 'Click selector is empty';

  @override
  String macroReplayClickNotFound(String selector) {
    return 'Click target not found: $selector';
  }

  @override
  String macroReplayWaitUrlPattern(String pattern) {
    return 'Waiting for URL match: $pattern';
  }

  @override
  String get macroReplayEmptyWaitSelector => 'Wait selector is empty';

  @override
  String macroReplayWaitSelector(String selector) {
    return 'Waiting for element: $selector';
  }

  @override
  String get macroReplayManualActionRequired => 'Manual action required';

  @override
  String macroReplayNavigateTo(String url) {
    return 'Navigate to $url';
  }

  @override
  String get macroReplayWaitPageLoad => 'Waiting for page load';

  @override
  String get macroReplayWaitDomReady => 'Waiting for DOM ready';

  @override
  String get hyperosShowcaseTitle => 'HyperOS UI Kit';

  @override
  String get hyperosShowcaseSectionSummary => 'Summary card';

  @override
  String get hyperosShowcaseKitSubtitle => 'mikcb HyperOS-style components';

  @override
  String get hyperosShowcaseSectionTags => 'Tags / Accordion / Hints';

  @override
  String get hyperosShowcaseAccordionSection1 => 'Section 1';

  @override
  String get hyperosShowcaseAccordionSection1Body =>
      'Content shown after expanding.';

  @override
  String get hyperosShowcaseAccordionSection2 => 'Section 2';

  @override
  String get hyperosShowcaseAccordionSection2Body =>
      'Collapsible group replacing FAccordion.';

  @override
  String get hyperosShowcaseSectionNavRows => 'List rows · Navigation';

  @override
  String get hyperosShowcaseNavRowWithIcon => 'With icon';

  @override
  String get hyperosShowcaseNavRowNoIconSubtitle => 'No leading tinted icon';

  @override
  String get hyperosShowcaseNavRowDetails => 'Details';

  @override
  String get hyperosShowcaseSectionSwitchRows =>
      'List rows · Switch / Destructive';

  @override
  String get hyperosShowcaseSwitchRowSubtitle => 'Switch row with icon';

  @override
  String get hyperosShowcaseSwitchRowPlain => 'Plain switch row';

  @override
  String get hyperosShowcaseSectionChoiceRows =>
      'List rows · Radio / Select / Date';

  @override
  String get hyperosShowcaseOptionA => 'Option A';

  @override
  String get hyperosShowcaseOptionB => 'Option B';

  @override
  String get hyperosShowcaseOptionC => 'Option C';

  @override
  String get hyperosShowcaseSelectSizeTitle => 'Choose size';

  @override
  String get hyperosShowcaseSizeSmall => 'S';

  @override
  String get hyperosShowcaseSizeMedium => 'M';

  @override
  String get hyperosShowcaseSizeLarge => 'L';

  @override
  String get hyperosShowcaseSectionControls => 'Control card';

  @override
  String get hyperosShowcaseControlsSubtitle => 'Slider, segments, buttons';

  @override
  String get hyperosShowcaseSegmentLeft => 'Left';

  @override
  String get hyperosShowcaseSegmentRight => 'Right';

  @override
  String get hyperosShowcaseSectionInput => 'Input';

  @override
  String get hyperosShowcaseInputHint => 'Enter content';

  @override
  String get hyperosShowcaseInputCardLabel => 'Input in card';

  @override
  String get hyperosShowcaseSectionPicker => 'Wheel picker';

  @override
  String hyperosShowcasePickerCurrentValue(int value) {
    return 'Current value: $value';
  }

  @override
  String get hyperosShowcaseSectionInline => 'Inline basics';

  @override
  String get hyperosShowcaseCheckboxSubtitle => 'Multi-select preference row';

  @override
  String get hyperosShowcaseSectionNavActions => 'Navigation & actions';

  @override
  String get hyperosShowcaseTooltipButton => 'Button with tooltip';

  @override
  String get hyperosShowcaseSectionProgress => 'Progress & refresh';

  @override
  String get hyperosShowcaseSectionColorChip => 'ColorChip';

  @override
  String get hyperosShowcaseSectionNavBar => 'HyperosNavigationBar';

  @override
  String get hyperosShowcaseNavHome => 'Home';

  @override
  String get hyperosShowcaseNavTimetable => 'Timetable';

  @override
  String get hyperosShowcaseNavSettings => 'Settings';

  @override
  String get hyperosShowcaseSectionEmpty => 'Empty / Divider / Decoration';

  @override
  String get hyperosShowcaseEmptySubtitle => 'Placeholder when list is empty';

  @override
  String get hyperosShowcaseActionButton => 'Action';

  @override
  String get hyperosShowcaseDividerRowTitle =>
      'Second row (indented divider above)';

  @override
  String get hyperosShowcaseSectionPressable => 'HyperosPressableRow';

  @override
  String get hyperosShowcaseSectionShell => 'Page shell';

  @override
  String get hyperosShowcaseRootPageDetails => 'Root page without back button';

  @override
  String get hyperosShowcaseSubpageSubtitle =>
      'Current page is Subpage + HyperosListView';

  @override
  String get hyperosShowcaseAlreadyInSubpage => 'Already in Subpage';

  @override
  String get hyperosShowcaseSectionFrosted => 'Frosted header · scroll physics';

  @override
  String get hyperosShowcaseSectionFeedback => 'Feedback · overlays';

  @override
  String get hyperosShowcaseSectionIconColors => 'HyperosIconColors';

  @override
  String get hyperosShowcaseFooterNote =>
      'Visible on the settings home page in non-release builds for component QA.';

  @override
  String get hyperosShowcaseUndoAction => 'Undo';

  @override
  String get hyperosShowcaseDialogMessage => 'System-style dialog example.';

  @override
  String get hyperosShowcaseConfirmTitle => 'Confirm action';

  @override
  String get hyperosShowcaseConfirmed => 'Confirmed';

  @override
  String get hyperosShowcaseToastDescription =>
      'With icon and subtitle, same as app toast';

  @override
  String get hyperosShowcaseMenuCopy => 'Copy';

  @override
  String get hyperosShowcaseMenuShare => 'Share';

  @override
  String get hyperosShowcaseMenuDelete => 'Delete';

  @override
  String get hyperosShowcaseRefreshDone => 'Refresh complete';

  @override
  String get hyperosShowcaseSearchTooltip => 'Search';

  @override
  String get hyperosShowcaseRootShellLabel => 'Root shell';

  @override
  String get hyperosShowcasePushSubtitle => 'Enter via HyperosNavigation.push';

  @override
  String get hyperosShowcaseSampleText => 'Sample text';

  @override
  String courseImportQuickImportDescription(
    String schoolName,
    String adapterName,
  ) {
    return 'Quick import $schoolName $adapterName';
  }

  @override
  String get courseImportScriptNoCourses =>
      'Import script returned no course data';

  @override
  String get courseImportScriptFailed => 'Script execution failed';

  @override
  String get courseImportRecordingStatus => 'Recording… tap Stop to finish';

  @override
  String get courseImportRecordingStartedTip =>
      'Recording started. Continue through the academic portal as usual.';

  @override
  String get courseImportRecordingEmptyStatus => 'No actions recorded';

  @override
  String get courseImportRecordingEmptyTip => 'No actions recorded';

  @override
  String get courseImportSaveRecordingTitle => 'Save recording';

  @override
  String courseImportSaveRecordingMessage(int count) {
    return 'Recorded $count steps. Save as quick import?';
  }

  @override
  String courseImportRecordingSavedStatus(int count) {
    return 'Recording saved ($count steps)';
  }

  @override
  String get courseImportWeekNotProvided => 'Weeks not provided';

  @override
  String get courseImportLocationNotFilled => 'Location not filled';

  @override
  String courseImportPreviewLine(
    String weekday,
    int startSection,
    int endSection,
    String name,
    String location,
    String weekText,
  ) {
    return 'Weekday $weekday Sections $startSection-$endSection  $name  $location  Weeks: $weekText';
  }

  @override
  String courseImportCalendarWeekLabel(int week) {
    return 'Calendar week $week';
  }

  @override
  String get courseImportTermStartDateTitle => 'Term start date';

  @override
  String get courseImportFirstWeekMappingLabel =>
      'Which calendar week is timetable week 1';

  @override
  String get courseImportFirstWeekMappingSubtitle =>
      'If week 1 has no classes, choose week 2; if weeks 1-2 have none, choose week 3.';

  @override
  String get courseImportFirstWeekNoShift =>
      'Import will treat timetable week 1 as calendar week 1.';

  @override
  String courseImportFirstWeekShifted(int weeks, int targetWeek) {
    return 'Import will shift all course weeks by $weeks so timetable week 1 lands on calendar week $targetWeek.';
  }

  @override
  String get courseImportContinueAction => 'Continue import';

  @override
  String get courseImportUpdateRecommendedAction =>
      'Update timetable (recommended)';

  @override
  String get courseImportOverwriteAction => 'Overwrite import';

  @override
  String get courseImportSectionCountInsufficientTitle =>
      'Not enough sections in time scheme';

  @override
  String courseImportSectionCountInsufficientMessage(
    int current,
    int required,
  ) {
    return 'Current time scheme has only $current sections, but import needs up to section $required. Auto-fill and continue?';
  }

  @override
  String get courseImportAutoFillAndImportAction => 'Auto-fill and import';

  @override
  String get courseImportPortalUrlTitle => 'Enter academic portal URL';

  @override
  String get courseImportPortalUrlSaveContinue => 'Save and continue';

  @override
  String get courseImportPortalUrlLabel => 'Portal URL';

  @override
  String get courseImportPortalUrlHint =>
      'Saved URL will be reused next time. You can also edit it on the adapter info page.';

  @override
  String get courseImportPortalUrlInvalid => 'Invalid login URL format';

  @override
  String get logAppLoggerInitialized => 'App log service initialized';

  @override
  String get logPrivacyConsentUpdated => 'Privacy consent status updated';

  @override
  String get logAppLogRecordingEnabled => 'App log recording enabled';

  @override
  String get logAppLogRecordingRemainsEnabled =>
      'App log recording remains enabled';

  @override
  String get logStartupFlowStarted => 'Startup flow started';

  @override
  String get logStartupFlowCompletedNoOnboarding =>
      'Startup flow completed (no onboarding)';

  @override
  String get logStartupFlowCompletedAfterGuide =>
      'Startup flow completed (after guide)';

  @override
  String get logStartupFlowFailed =>
      'Startup flow failed; entering degraded mode';

  @override
  String get logAppLifecycleChanged => 'App lifecycle changed';

  @override
  String get logNavigatorRouteReplaced => 'Navigation route replaced';

  @override
  String get logNavigatorRouteChanged => 'Navigation route changed';

  @override
  String get logAppLogsDefaultMigrated =>
      'App log recording enabled by default during migration';

  @override
  String get logTimetableLoadSettingsFailed =>
      'Failed to load timetable settings';

  @override
  String get logTimetableLoadCoursesFailed => 'Failed to load course data';

  @override
  String get logTimetableLoadCurrentWeekFailed => 'Failed to load current week';

  @override
  String get logHomeWidgetPinSupportFailed =>
      'Failed to check home widget pin support';

  @override
  String get logHomeWidgetPinRequestFailed =>
      'Failed to request home widget pin';

  @override
  String get logHomeWidgetSyncFailed => 'Failed to sync home widget snapshot';

  @override
  String get logHomeWidgetClearFailed => 'Failed to clear home widget snapshot';

  @override
  String get logHomeWidgetScheduleFailed =>
      'Failed to schedule home widget refresh';

  @override
  String get logMiuiLiveInitializeFailed =>
      'Failed to initialize MIUI Live Island channel';

  @override
  String get logMiuiLiveOpenPromotedSettingsFailed =>
      'Failed to open Live Island permission settings';

  @override
  String get logMiuiLiveOpenNotificationSettingsFailed =>
      'Failed to open notification settings';

  @override
  String get logMiuiLiveOpenAutostartSettingsFailed =>
      'Failed to open autostart settings';

  @override
  String get logMiuiLiveOpenBatterySettingsFailed =>
      'Failed to open battery optimization settings';

  @override
  String get logMiuiLiveOpenAccessibilitySettingsFailed =>
      'Failed to open accessibility settings';

  @override
  String get logMiuiLiveHideFromRecentsFailed =>
      'Failed to update hide-from-recents';

  @override
  String get logLiveUpdateStartFailed =>
      'Failed to start Live Island from Flutter';

  @override
  String get logLiveUpdateStopFailed =>
      'Failed to stop Live Island from Flutter';

  @override
  String get logLiveUpdateDebugStatusFailed =>
      'Failed to get native Live Island debug status';

  @override
  String get logLiveUpdateSnapshotSyncFailed =>
      'Failed to sync Live Island timetable snapshot';

  @override
  String get logLiveUpdateSnapshotClearFailed =>
      'Failed to clear Live Island timetable snapshot';

  @override
  String get logLanEditAuthFailed => 'LAN edit: authentication failed';

  @override
  String get logLanEditCourseCreated => 'LAN edit: course created';

  @override
  String get logLanEditCourseUpdated => 'LAN edit: course updated';

  @override
  String get logLanEditCourseDeleted => 'LAN edit: course deleted';

  @override
  String get logLanEditCourseGroupSaved => 'LAN edit: course group saved';

  @override
  String get logLanEditMergeImported => 'LAN edit: merge backup imported';

  @override
  String get logLanEditCoursesBatchDeleted => 'LAN edit: courses batch deleted';

  @override
  String get logLanEditCurrentWeekSet => 'LAN edit: current week set';

  @override
  String get logLanEditSpreadsheetImported => 'LAN edit: spreadsheet imported';

  @override
  String get logLanEditSessionStarted => 'LAN edit: session started';

  @override
  String get logLanEditSessionStopped => 'LAN edit: session stopped';

  @override
  String get logLiveUpdateTestRequested =>
      'User requested manual Live Island test notification';

  @override
  String get logLiveUpdateTestNoSelection =>
      'Manual Live Island test: no course available';

  @override
  String get logLiveUpdateTestSelectionReady =>
      'Manual Live Island test: target course resolved';

  @override
  String get logLiveUpdateTestSuspendSync =>
      'Manual Live Island test: scheduled sync paused temporarily';

  @override
  String get logLiveUpdateTestStarting =>
      'Manual Live Island test: starting native Live Island';

  @override
  String get logLiveUpdateTestStarted =>
      'Manual Live Island test: native Live Island requested successfully';

  @override
  String get logLiveUpdateTestFailed =>
      'Manual Live Island test: failed before Live Island appeared';

  @override
  String logLiveUpdateSettingsSynced(
    String beforeClass,
    String duringClass,
    String beforeEnd,
    String promote,
    String notification,
    String countdown,
    String courseName,
    String location,
  ) {
    return 'Flutter Live Island settings synced: beforeClass=$beforeClass, duringClass=$duringClass, beforeEnd=$beforeEnd, promote=$promote, notification=$notification, countdown=$countdown, courseName=$courseName, location=$location';
  }

  @override
  String get logFieldSource => 'source';

  @override
  String get logFieldPlatform => 'platform';

  @override
  String get logFieldVersion => 'version';

  @override
  String get logFieldBuildNumber => 'build Number';

  @override
  String get logFieldLoggingEnabled => 'logging Enabled';

  @override
  String get logFieldPrivacyAccepted => 'privacy Accepted';

  @override
  String get logFieldAccepted => 'accepted';

  @override
  String get logFieldPrevious => 'previous';

  @override
  String get logFieldTruncated => 'truncated';

  @override
  String get logFieldTruncatedHint => 'truncated Hint';

  @override
  String get logFieldThrowable => 'throwable';

  @override
  String get logFieldExtras => 'extras';

  @override
  String get logFieldContext => 'context';

  @override
  String get logFieldError => 'error';

  @override
  String get logFieldBrand => 'brand';

  @override
  String get logFieldManufacturer => 'manufacturer';

  @override
  String get logFieldModel => 'model';

  @override
  String get logFieldSdkInt => 'sdk Int';

  @override
  String get logFieldVersionName => 'version Name';

  @override
  String get logFieldChannel => 'channel';

  @override
  String get logFieldHasNotificationPermission => 'has Notification Permission';

  @override
  String get logFieldHasPromotedPermissionDeclared =>
      'has Promoted Permission Declared';

  @override
  String get logFieldCanPostPromotedNotifications =>
      'can Post Promoted Notifications';

  @override
  String get logFieldIgnoringBatteryOptimizations =>
      'ignoring Battery Optimizations';

  @override
  String get logFieldKeepAliveAccessibilityEnabled =>
      'keep Alive Accessibility Enabled';

  @override
  String get logFieldHideFromRecentsEnabled => 'hide From Recents Enabled';

  @override
  String get logFieldTaskRemovedRecently => 'task Removed Recently';

  @override
  String get logFieldLastTaskRemovedAt => 'last Task Removed At';

  @override
  String get logFieldProcessImportance => 'process Importance';

  @override
  String get logFieldAutoStartStatus => 'auto Start Status';

  @override
  String get logFieldLiveEnableBeforeClass => 'live Enable Before Class';

  @override
  String get logFieldLiveEnableDuringClass => 'live Enable During Class';

  @override
  String get logFieldLiveEnableBeforeEnd => 'live Enable Before End';

  @override
  String get logFieldLivePromoteDuringClass => 'live Promote During Class';

  @override
  String get logFieldLiveShowDuringClassNotification =>
      'live Show During Class Notification';

  @override
  String get logFieldLiveShowCountdown => 'live Show Countdown';

  @override
  String get logFieldLiveShowStageText => 'live Show Stage Text';

  @override
  String get logFieldLiveShowCourseName => 'live Show Course Name';

  @override
  String get logFieldLiveShowLocation => 'live Show Location';

  @override
  String get logFieldLiveUseShortName => 'live Use Short Name';

  @override
  String get logFieldLiveHidePrefixText => 'live Hide Prefix Text';

  @override
  String get logFieldLiveDuringClassTimeDisplayMode =>
      'live During Class Time Display Mode';

  @override
  String get logFieldLiveEnableMiuiIslandLabelImage =>
      'live Enable Miui Island Label Image';

  @override
  String get logFieldLiveMiuiIslandLabelStyle => 'live Miui Island Label Style';

  @override
  String get logFieldLiveMiuiIslandLabelContent =>
      'live Miui Island Label Content';

  @override
  String get logFieldLiveMiuiIslandLabelFontColor =>
      'live Miui Island Label Font Color';

  @override
  String get logFieldLiveMiuiIslandLabelFontWeight =>
      'live Miui Island Label Font Weight';

  @override
  String get logFieldLiveMiuiIslandLabelRenderQuality =>
      'live Miui Island Label Render Quality';

  @override
  String get logFieldLiveMiuiIslandLabelFontSize =>
      'live Miui Island Label Font Size';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetX =>
      'live Miui Island Label Offset X';

  @override
  String get logFieldLiveMiuiIslandLabelOffsetY =>
      'live Miui Island Label Offset Y';

  @override
  String get logFieldLiveMiuiIslandExpandedIconMode =>
      'live Miui Island Expanded Icon Mode';

  @override
  String get logFieldLiveShowBeforeClassMinutes =>
      'live Show Before Class Minutes';

  @override
  String get logFieldLiveClassReminderStartMinutes =>
      'live Class Reminder Start Minutes';

  @override
  String get logFieldLiveEndSecondsCountdownThreshold =>
      'live End Seconds Countdown Threshold';

  @override
  String get logFieldState => 'state';

  @override
  String get logFieldRoute => 'route';

  @override
  String get logFieldPreviousRoute => 'previous Route';

  @override
  String get logFieldProfileId => 'profile Id';

  @override
  String get logFieldReason => 'reason';

  @override
  String get logFieldClientIp => 'client Ip';

  @override
  String get logFieldPort => 'port';

  @override
  String get logFieldCourseName => 'course Name';

  @override
  String get logFieldStage => 'stage';

  @override
  String get logFieldFrom => 'from';

  @override
  String get logFieldCurrentWeek => 'current Week';

  @override
  String get logFieldWeekday => 'weekday';

  @override
  String get logFieldUntilMillis => 'until Millis';

  @override
  String get logFieldStartAtMillis => 'start At Millis';

  @override
  String get logFieldMergedCourseCount => 'merged Course Count';

  @override
  String get logFieldDeletedCount => 'deleted Count';

  @override
  String get logFieldRequested => 'requested';

  @override
  String get logFieldTarget => 'target';

  @override
  String get logFieldCount => 'count';

  @override
  String get logFieldValue => 'value';

  @override
  String get logFieldSnapshotLength => 'snapshot Length';

  @override
  String get logFieldStoredSnapshotVersion => 'stored Snapshot Version';

  @override
  String get logFieldIntentIsNull => 'intent Is Null';

  @override
  String get logFieldAction => 'action';

  @override
  String get logFieldStep => 'step';

  @override
  String get logCatAppLoggerInitialized => 'app log: ger initialized';

  @override
  String get logCatPrivacyConsentUpdated => 'privacy consent updated';

  @override
  String get logCatAppLogRecordingEnabled => 'app log: recording enabled';

  @override
  String get logCatStartupFlowStarted => 'startup: started';

  @override
  String get logCatStartupFlowCompleted => 'startup: completed';

  @override
  String get logCatStartupFlowFailed => 'startup: failed';

  @override
  String get logCatAppLifecycleStateChanged => 'app lifecycle state changed';

  @override
  String get logCatRoutePushed => 'route pushed';

  @override
  String get logCatRoutePopped => 'route popped';

  @override
  String get logCatRouteReplaced => 'route replaced';

  @override
  String get logCatFlutterFrameworkError => 'flutter framework error';

  @override
  String get logCatFlutterPlatformError => 'flutter platform error';

  @override
  String get logCatFlutterZoneError => 'flutter zone error';

  @override
  String get logCatAppLogsDefaultMigrated => 'app log: s default migrated';

  @override
  String get logCatTimetableLoadSettingsFailed =>
      'timetable: load settings failed';

  @override
  String get logCatTimetableLoadCoursesFailed =>
      'timetable: load courses failed';

  @override
  String get logCatTimetableLoadCurrentWeekFailed =>
      'timetable: load current week failed';

  @override
  String get logCatHomeWidgetPinSupportFailed =>
      'home widget: pin support failed';

  @override
  String get logCatHomeWidgetPinRequestFailed =>
      'home widget: pin request failed';

  @override
  String get logCatHomeWidgetSyncFailed => 'home widget: sync failed';

  @override
  String get logCatHomeWidgetClearFailed => 'home widget: clear failed';

  @override
  String get logCatHomeWidgetScheduleFailed => 'home widget: schedule failed';

  @override
  String get logCatMiuiLiveInitializeFailed => 'live island: initialize failed';

  @override
  String get logCatMiuiLiveOpenPromotedSettingsFailed =>
      'live island: open promoted settings failed';

  @override
  String get logCatMiuiLiveOpenNotificationSettingsFailed =>
      'live island: open notification settings failed';

  @override
  String get logCatMiuiLiveOpenAutostartSettingsFailed =>
      'live island: open autostart settings failed';

  @override
  String get logCatMiuiLiveOpenBatterySettingsFailed =>
      'live island: open battery settings failed';

  @override
  String get logCatMiuiLiveOpenAccessibilitySettingsFailed =>
      'live island: open accessibility settings failed';

  @override
  String get logCatMiuiLiveHideFromRecentsFailed =>
      'live island: hide from recents failed';

  @override
  String get logCatLiveUpdateFlutterInitializeFailed =>
      'live island: flutter initialize failed';

  @override
  String get logCatLiveUpdateStartFailed => 'live island: start failed';

  @override
  String get logCatLiveUpdateStopFailed => 'live island: stop failed';

  @override
  String get logCatLiveUpdateDebugStatusFailed =>
      'live island: debug status failed';

  @override
  String get logCatLiveUpdateSettingsSynced => 'live island: settings synced';

  @override
  String get logCatLiveUpdateSnapshotSyncFailed =>
      'live island: snapshot sync failed';

  @override
  String get logCatLiveUpdateSnapshotClearFailed =>
      'live island: snapshot clear failed';

  @override
  String get logCatLanEditAuthFailed => 'lan edit auth failed';

  @override
  String get logCatLanEditCourseCreated => 'lan edit course created';

  @override
  String get logCatLanEditCourseUpdated => 'lan edit course updated';

  @override
  String get logCatLanEditCourseDeleted => 'lan edit course deleted';

  @override
  String get logCatLanEditCourseGroupSaved => 'lan edit course group saved';

  @override
  String get logCatLanEditMergeImported => 'lan edit merge imported';

  @override
  String get logCatLanEditCoursesBatchDeleted =>
      'lan edit courses batch deleted';

  @override
  String get logCatLanEditCurrentWeekSet => 'lan edit current week set';

  @override
  String get logCatLanEditSpreadsheetImported =>
      'lan edit spreadsheet imported';

  @override
  String get logCatLanEditSessionStarted => 'lan edit session started';

  @override
  String get logCatLanEditSessionStopped => 'lan edit session stopped';

  @override
  String get logCatLiveUpdateTestRequested => 'live island: test requested';

  @override
  String get logCatLiveUpdateTestNoSelection =>
      'live island: test no selection';

  @override
  String get logCatLiveUpdateTestSelectionReady =>
      'live island: test selection ready';

  @override
  String get logCatLiveUpdateTestSuspendSync =>
      'live island: test suspend sync';

  @override
  String get logCatLiveUpdateTestStarting => 'live island: test starting';

  @override
  String get logCatLiveUpdateTestStarted => 'live island: test started';

  @override
  String get logCatLiveUpdateTestFailed => 'live island: test failed';

  @override
  String get logCatLiveUpdateSnapshotSettings =>
      'live island: snapshot settings';

  @override
  String get logCatLiveUpdateSnapshotSynced => 'live island: snapshot synced';

  @override
  String get logCatLiveUpdateSnapshotCleared => 'live island: snapshot cleared';

  @override
  String get logCatLiveUpdateAlarmTriggered => 'live island: alarm triggered';

  @override
  String get logCatLiveUpdateSchedulerResume => 'live island: scheduler resume';

  @override
  String get logCatLiveUpdateRescheduleHoliday =>
      'live island: reschedule holiday';

  @override
  String get logCatLiveUpdateRescheduleActive =>
      'live island: reschedule active';

  @override
  String get logCatLiveUpdateRescheduleScheduled =>
      'live island: reschedule scheduled';

  @override
  String get logCatLiveUpdateSnapshotParseFailed =>
      'live island: snapshot parse failed';

  @override
  String get logCatLiveUpdateSnapshotInvalidatedAfterUpgrade =>
      'live island: snapshot invalidated after upgrade';

  @override
  String get logCatLiveUpdatePayloadSelected => 'live island: payload selected';

  @override
  String get logCatLiveUpdateSchedulerStartFailed =>
      'live island: scheduler start failed';

  @override
  String get logCatLiveUpdateStartRequested => 'live island: start requested';

  @override
  String get logCatLiveUpdateStopRequested => 'live island: stop requested';

  @override
  String get logCatLiveUpdateServiceMissingPayload =>
      'live island: service missing payload';

  @override
  String get logCatLiveUpdateServiceStarted => 'live island: service started';

  @override
  String get logCatLiveUpdateServiceStartFailed =>
      'live island: service start failed';

  @override
  String get logCatLiveUpdateTaskRemoved => 'live island: task removed';

  @override
  String get logCatLiveUpdateTaskRemovedResumed =>
      'live island: task removed resumed';

  @override
  String get logCatLiveUpdateBeforeClassQuickAction =>
      'live island: before class quick action';

  @override
  String get logCatLiveUpdateBeforeClassQuickActionRestored =>
      'live island: before class quick action restored';

  @override
  String get logCatLiveUpdateStatusBarDismissed =>
      'live island: status bar dismissed';

  @override
  String get logCatLiveUpdateNotPromoted => 'live island: not promoted';

  @override
  String get logCatLiveUpdatePromotedNotShown =>
      'live island: promoted not shown';

  @override
  String get logCatLiveUpdateServiceStopped => 'live island: service stopped';

  @override
  String get logCatKeepAliveAccessibilityConnected =>
      'keep-alive: accessibility connected';

  @override
  String get logCatDiagnosticsEnabled => 'diagnostics: enabled';

  @override
  String get logCatDiagnosticsCleared => 'diagnostics: cleared';

  @override
  String get logCatDiagnosticsBootstrap => 'diagnostics: bootstrap';

  @override
  String get logCatFlutterDiagnostic => 'flutter diagnostic';

  @override
  String get logCatFlutterDiagnosticEvent => 'flutter diagnostic event';

  @override
  String get logCatRenderFailed => 'render failed';

  @override
  String get logCatDebugSnapshot => 'debug snapshot';

  @override
  String get logExportTitle => 'Qingyu Timetable - App logs';

  @override
  String get appUpdateMirrorPresetGhfast => 'Default mirror';

  @override
  String get appUpdateMirrorPresetGhproxyCn => 'Backup mirror 1';

  @override
  String get appUpdateMirrorPresetGhLlkk => 'Backup mirror 2';

  @override
  String get appUpdateMirrorPresetGhProxyCom => 'Backup mirror 3';

  @override
  String get appUpdateMirrorPresetGhproxyNet => 'Backup mirror 4';

  @override
  String get appUpdateMirrorPresetCustom => 'Custom';

  @override
  String get appUpdateMirrorPresetCustomDescription =>
      'Enter a custom mirror URL prefix';

  @override
  String get cloudBackupRetentionTitle => 'Backup retention';

  @override
  String get cloudBackupMaxCountTitle => 'Maximum backups';

  @override
  String get cloudBackupMaxCountSubtitle =>
      'Oldest backups are removed when exceeded';

  @override
  String cloudBackupMaxCountOption(int count) {
    return '$count backups';
  }

  @override
  String get cloudBackupMaxAgeTitle => 'Maximum age';

  @override
  String get cloudBackupMaxAgeSubtitle => 'Backups older than this are removed';

  @override
  String cloudBackupMaxAgeOption(int days) {
    return '$days days';
  }

  @override
  String get statisticsShareText => 'Semester statistics from mikcb';

  @override
  String get aboutUpdateAvailableHeadline => 'Update available';

  @override
  String get aboutAlreadyLatestHeadline => 'Already up to date';

  @override
  String get aboutDownloadChannelSectionTitle => 'Download channel';

  @override
  String get aboutMirrorProbeFailedLabel => 'Failed';

  @override
  String timeSchemeImportSupplementName(String name) {
    return '$name (import supplement)';
  }

  @override
  String profileTimeSchemeName(String profileName) {
    return '$profileName schedule';
  }

  @override
  String get currentProfileTimeSchemeName => 'Current timetable schedule';

  @override
  String get unnamedTimetableProfile => 'Unnamed timetable';

  @override
  String get cloudBackupManualProtectedTitle => 'Protect manual backups';

  @override
  String get cloudBackupManualProtectedSubtitle =>
      'Manual backups are never auto-deleted when enabled';

  @override
  String courseImportPortalUrlMissingBody(
    String schoolName,
    String adapterName,
  ) {
    return '\"$schoolName / $adapterName\" has no default login URL. Enter the school portal URL first.';
  }

  @override
  String guidePermissionsProgressLabel(int ready, int total) {
    return 'Ready $ready/$total';
  }
}
