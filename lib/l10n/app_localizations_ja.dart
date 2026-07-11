// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '軽屿時間割';

  @override
  String get appTitleDebug => '軽屿時間割 デバッグ版';

  @override
  String get appTitleProfile => '軽屿時間割 プロファイル版';

  @override
  String get appearanceTitle => '外観と配色';

  @override
  String get previewTitle => 'プレビュー';

  @override
  String get timetableBackgroundPreview => '時間割背景';

  @override
  String get displayModeTitle => '表示モード';

  @override
  String get displayModeSubtitle => 'システム連携、ライトモード、ダークモードに対応。';

  @override
  String get themeModeLabel => 'テーマモード';

  @override
  String get themeModeSystem => 'システム連携';

  @override
  String get themeModeLight => 'ライトモード';

  @override
  String get themeModeDark => 'ダークモード';

  @override
  String get fontSectionTitle => 'アプリフォント';

  @override
  String get fontSectionSubtitle => 'Inter を標準とし、端末に入っているフォントも選べます。';

  @override
  String get fontSectionFootnote =>
      'メーカーフォントは同梱されず、端末に入っている場合のみ有効です。Xiaomi では MiSans だけ目立ちやすいです。変化がなければ自動代替で、通常は自分でインストール不要です。';

  @override
  String get fontModeLabel => 'フォント選択';

  @override
  String get fontModeSystem => 'アプリ標準（Inter）';

  @override
  String get fontModeSansSerif => 'システムサンセリフ';

  @override
  String get fontModeMiSans => 'MiSans';

  @override
  String get fontModeHarmonyOS => 'HarmonyOS Sans';

  @override
  String get fontModeOppoSans => 'OPPO Sans';

  @override
  String get fontModePingFang => 'PingFang SC';

  @override
  String get fontModeNotoSans => 'Noto Sans';

  @override
  String get fontModeSerif => 'セリフ体';

  @override
  String get fontModeSongti => '宋体';

  @override
  String get fontModeMonospace => '等幅';

  @override
  String get languageSectionTitle => 'アプリ言語';

  @override
  String get languageSectionSubtitle => 'システム連携または手動で対応言語に切り替え可能。';

  @override
  String get languageModeLabel => '言語選択';

  @override
  String get languageModeSystem => 'システム連携';

  @override
  String get settingsTitle => '時間割設定';

  @override
  String get dailyUsageSectionTitle => '日常使い';

  @override
  String get appearanceEntryTitle => '外観と配色';

  @override
  String get appearanceEntrySubtitle => 'テーマカラー、時間割背景、授業カードの色';

  @override
  String get layoutSectionEntryTitle => 'レイアウトと時限';

  @override
  String get layoutSectionEntrySubtitle => '時限時間、行高さ、時間列、週末表示とカードレイアウト';

  @override
  String get homeWidgetEntryTitle => 'ホームウィジェット';

  @override
  String get homeWidgetEntrySubtitle => '今日の授業カード、ウィジェット背景と表示情報';

  @override
  String get reminderNotificationSectionTitle => 'リマインダーと通知';

  @override
  String get userGuideEntryTitle => '使用ガイドと権限';

  @override
  String get userGuideEntrySubtitle => '略称設定、通知、自動起動、バッテリー戦略';

  @override
  String get timetableManagementSectionTitle => '時間割管理';

  @override
  String get timeSchemeEntryTitle => '時間テンプレート';

  @override
  String get timeSchemeEntrySubtitleNoneSelected => '切替、時限編集、コピーとテンプレート管理';

  @override
  String timeSchemeEntrySubtitleSelected(String name) {
    return '現在：$name・切替、時限編集とコピー';
  }

  @override
  String get dataTransferEntryTitle => 'データバックアップと移行';

  @override
  String get dataTransferEntrySubtitle => '時間割ファイルをエクスポートして、他の人が直接インポート可能';

  @override
  String get coupleTimetableEntryTitle => '情侣课表';

  @override
  String get coupleTimetableEntryBound => '已绑定';

  @override
  String get coupleTimetableModeEnableTooltip => '开启情侣课表';

  @override
  String get coupleTimetableModeDisableTooltip => '关闭情侣课表';

  @override
  String get coupleTimetableTitle => '情侣课表';

  @override
  String get coupleTimetableIntro =>
      '导出你的课表发给 TA，或导入 TA 分享的课表文件。导入后可在叠加视图中查看双方课程。';

  @override
  String get coupleTimetableBoundTitle => '已绑定对方课表';

  @override
  String get coupleTimetableUnboundTitle => '尚未绑定对方课表';

  @override
  String get coupleTimetablePartnerNameLabel => '对方名称';

  @override
  String coupleTimetableLastImportedAt(String time) {
    return '上次导入：$time';
  }

  @override
  String get coupleTimetableExportForPartner => '导出我的课表给对方';

  @override
  String get coupleTimetableImportPartner => '导入对方课表';

  @override
  String get coupleTimetableUnlink => '解除绑定';

  @override
  String get coupleTimetableOpenOverlay => '进入叠加视图';

  @override
  String get coupleTimetableImportSuccess => '已导入对方课表';

  @override
  String get coupleTimetableImportUpdated => '已更新对方课表';

  @override
  String get coupleTimetableUnlinkConfirmTitle => '解除情侣课表绑定？';

  @override
  String get coupleTimetableUnlinkConfirmMessage => '解除后将删除本地保存的对方课表，叠加视图也会关闭。';

  @override
  String get coupleTimetableUnlinkSuccess => '已解除绑定';

  @override
  String get coupleTimetablePrivacyHint => '对方只能看到你导出文件中包含的课表内容。';

  @override
  String get coupleTimetableOverlayTitle => '情侣叠加';

  @override
  String get coupleTimetableLegendMine => '我的课';

  @override
  String get coupleTimetableLegendPartner => 'TA的课';

  @override
  String get coupleTimetableLegendTogether => '一起上课';

  @override
  String get coupleTimetableLegendFree => '共同空闲';

  @override
  String get coupleTimetableSharedFreeTitle => '今日共同空闲';

  @override
  String get coupleTimetableNoSharedFree => '今天没有共同空闲时段';

  @override
  String get coupleTimetablePartnerReadOnlyBadge => '对方课表（只读）';

  @override
  String get coupleTimetableNotBoundMessage => '请先导入对方课表后再查看叠加视图。';

  @override
  String get coupleTimetableShareText => '这是我的课表，导入到轻屿课表的情侣课表即可一起查看。';

  @override
  String get coupleTimetableShareSubject => '轻屿课表 · 情侣课表分享';

  @override
  String get coupleTimetableWeekOffsetTitle => '周次偏移';

  @override
  String get coupleTimetableWeekOffsetSubtitle =>
      '查看你的第 N 周时，读取对方课表的第 N+偏移 周。例如 +1 表示对方学期进度比你快一周。';

  @override
  String get coupleTimetableWeekOffsetZero => '无偏移';

  @override
  String coupleTimetableWeekOffsetSigned(String offset) {
    return '$offset 周';
  }

  @override
  String coupleTimetableWeekOffsetPreview(int myWeek, int partnerWeek) {
    return '查看你的第 $myWeek 周时，显示对方第 $partnerWeek 周的课';
  }

  @override
  String get coupleTimetableColorsTitle => '叠加颜色';

  @override
  String get coupleTimetableColorsSubtitle =>
      '自定义「我的课」「TA的课」「一起上课」在叠加视图中的显示颜色，可按喜好自由搭配。';

  @override
  String get partnerImportRequiresSingleProfile => '请导入单课表备份文件，不支持全量备份';

  @override
  String get coupleWebdavTitle => '坚果云拉取';

  @override
  String get coupleWebdavSubtitle =>
      '登录对方（或你们共用的）坚果云账号，自动下载对方上传的课表文件。与「云同步」账号独立，互不影响。';

  @override
  String get coupleWebdavNotConnected => '尚未连接坚果云';

  @override
  String coupleWebdavConnectedAs(String username) {
    return '已连接：$username';
  }

  @override
  String coupleWebdavRemotePathHint(String path) {
    return '远程文件路径：$path';
  }

  @override
  String coupleWebdavLastPulledAt(String time) {
    return '上次拉取：$time';
  }

  @override
  String get coupleWebdavConnect => '连接坚果云';

  @override
  String get coupleWebdavDisconnect => '断开连接';

  @override
  String get coupleWebdavPullNow => '立即拉取对方课表';

  @override
  String get coupleWebdavUploadForPartner => '上传我的课表到坚果云';

  @override
  String get coupleWebdavLoginSheetTitle => '连接坚果云（情侣课表）';

  @override
  String get coupleWebdavLoginSheetSubtitle =>
      '请使用应用专用密码。对方需先将课表上传到约定路径，或由你在对方设备上登录同一账号并上传。';

  @override
  String get coupleWebdavConfirmConnect => '连接并拉取';

  @override
  String get coupleWebdavTestSuccess => '坚果云连接成功';

  @override
  String get coupleWebdavTestFailed => '连接失败，请检查账号、应用专用密码与网络';

  @override
  String get coupleWebdavPullImported => '已从坚果云导入对方课表';

  @override
  String get coupleWebdavPullUpdated => '已从坚果云更新对方课表';

  @override
  String get coupleWebdavPullUnchanged => '对方课表无变化';

  @override
  String get coupleWebdavUploadSuccess => '已上传课表，对方可拉取';

  @override
  String get coupleWebdavPartnerFileMissing => '未找到对方课表文件，请让对方先上传';

  @override
  String get coupleWebdavPullFailed => '拉取对方课表失败，请稍后重试';

  @override
  String get coupleWebdavNotConnectedError => '请先连接坚果云';

  @override
  String get cloudSyncEntryTitle => 'クラウド同期（WEBDAV）';

  @override
  String get cloudSyncEntrySubtitle => 'Jianguoyun などで時間割とインポートデータを複数端末同期';

  @override
  String get cloudSyncTitle => 'クラウド同期';

  @override
  String get cloudSyncIntroTitle => '複数端末同期';

  @override
  String get cloudSyncIntroSubtitle =>
      'Jianguoyun WEBDAV を設定すると、スマホやタブレット間で時間割、倉庫アカウント、関連設定を自動同期できます。';

  @override
  String get cloudSyncSettingsSectionTitle => '同期設定';

  @override
  String get cloudSyncSettingsSectionSubtitle => '手動または自動同期を切り替えられます。';

  @override
  String get cloudSyncEnabledTitle => 'クラウド同期を有効にする';

  @override
  String get cloudSyncEnabledSubtitle => 'オフにすると、スナップショットのアップロード・ダウンロードは行われません';

  @override
  String get cloudSyncProviderTitle => 'サービスプロバイダ';

  @override
  String get cloudSyncProviderJianguoyun => 'Jianguoyun';

  @override
  String get cloudSyncProviderCustom => 'カスタム WEBDAV';

  @override
  String get cloudSyncModeTitle => '同期方式';

  @override
  String get cloudSyncModeAuto => '自動同期';

  @override
  String get cloudSyncModeManual => '手動同期';

  @override
  String get cloudSyncAccountTitle => 'アカウント設定';

  @override
  String get cloudSyncAccountSubtitle =>
      'Jianguoyun のアプリ専用パスワードを使用してください（ログインパスワードではありません）。スナップショットには倉庫に保存された学校アカウントも含まれます。';

  @override
  String get cloudSyncUsernameLabel => 'メール / ユーザー名';

  @override
  String get cloudSyncUsernameHint => 'Jianguoyun 登録メール';

  @override
  String get cloudSyncPasswordLabel => 'アプリ専用パスワード';

  @override
  String get cloudSyncPasswordHint => 'Jianguoyun アカウントのセキュリティ設定で生成';

  @override
  String get cloudSyncPasswordStoredHint =>
      'パスワードを保存済み。空欄のままにすると保存済みのパスワードを使用します。';

  @override
  String get cloudSyncAdvancedTitle => '詳細設定';

  @override
  String get cloudSyncBaseUrlLabel => 'WEBDAV URL';

  @override
  String get cloudSyncRemoteFolderLabel => 'リモートフォルダ';

  @override
  String get cloudSyncStatusTitle => '同期状態';

  @override
  String get cloudSyncLastSyncedLabel => '最終同期';

  @override
  String get cloudSyncLastErrorLabel => '最新のエラー';

  @override
  String cloudSyncLastSyncedAt(String time) {
    return '最終同期：$time';
  }

  @override
  String get cloudSyncSyncing => '同期中…';

  @override
  String cloudSyncLastError(String message) {
    return '最新のエラー：$message';
  }

  @override
  String get cloudSyncHelpTitle => 'Jianguoyun アプリパスワードの取得方法';

  @override
  String get cloudSyncHelpBody =>
      'Jianguoyun ウェブまたはクライアント → アカウント情報 → セキュリティ → アプリパスワードを追加。WEBDAV URL デフォルト：https://dav.jianguoyun.com/dav/';

  @override
  String get cloudSyncTestConnection => '接続テスト';

  @override
  String get cloudSyncSyncNow => '今すぐ同期';

  @override
  String get cloudSyncSyncNowSubtitle =>
      '他の端末と時間割を揃えます：クラウドを取得してから端末の変更をアップロード';

  @override
  String get cloudSyncTestSuccess => 'WEBDAV 接続成功';

  @override
  String get cloudSyncTestFailed =>
      'WEBDAV 接続に失敗しました。アカウント、アプリパスワード、ネットワークを確認してください';

  @override
  String get cloudSyncResultUploaded => 'クラウドにアップロードしました';

  @override
  String get cloudSyncResultDownloaded => 'クラウドから復元しました';

  @override
  String get cloudSyncResultUpToDate => 'ローカルとクラウドは一致しています';

  @override
  String get cloudSyncResultCancelled => '同期をキャンセルしました';

  @override
  String cloudSyncResultFailed(String message) {
    return '同期に失敗しました：$message';
  }

  @override
  String get cloudSyncConflictTitle => '同期の競合が検出されました';

  @override
  String get cloudSyncConflictBody =>
      'この端末とクラウドの両方に新しい変更があります。どちらのデータを保持するか選択してください。';

  @override
  String get cloudSyncUseRemoteAction => 'クラウドを使用';

  @override
  String get cloudSyncKeepLocalAction => 'ローカルを保持';

  @override
  String get cloudSyncAccountSectionTitle => 'クラウドアカウント';

  @override
  String get cloudSyncNotConnectedHint =>
      'Jianguoyun に接続すると、複数端末間で時間割とインポートデータを同期できます。';

  @override
  String get cloudSyncConnectAccount => 'Jianguoyun に接続';

  @override
  String cloudSyncConnectedAs(String email) {
    return '接続済み：$email';
  }

  @override
  String get cloudSyncDisconnect => '接続を解除';

  @override
  String get cloudSyncDisconnectTitle => 'クラウド同期アカウントの切断';

  @override
  String get cloudSyncDisconnectBody =>
      '切断すると、この端末に保存された WEBDAV 認証情報が削除されます。時間割データは端末に残ります。続行しますか？';

  @override
  String get cloudSyncLoginSheetTitle => 'Jianguoyun に接続';

  @override
  String get cloudSyncLoginSheetSubtitle =>
      'アプリ専用パスワードを使用してください（Jianguoyun ログインパスワードではありません）。';

  @override
  String get cloudSyncConfirmConnect => '接続を確認';

  @override
  String get cloudSyncConnectSuccess => 'アカウント接続成功';

  @override
  String get cloudBackupSectionTitle => '履歴バージョン';

  @override
  String get cloudBackupSectionSubtitle => '同期時に自動保存。タップしてこのバージョンに復元できます';

  @override
  String get cloudBackupCurrentLabel => '現在のバージョン';

  @override
  String get cloudBackupCurrentBadge => '現在';

  @override
  String get cloudBackupCreateNow => '今すぐバックアップ';

  @override
  String get cloudBackupViewAll => 'すべての履歴を表示';

  @override
  String get cloudBackupEmpty => '履歴はまだありません。同期すると自動保存されます';

  @override
  String get cloudBackupSourceAuto => '自動バックアップ';

  @override
  String get cloudBackupSourceManual => '手動バックアップ';

  @override
  String get cloudBackupDefaultDeviceLabel => 'この端末';

  @override
  String get cloudBackupDeviceLabelTitle => 'デバイス名';

  @override
  String get cloudBackupDeviceLabelHint => 'バックアップ一覧に表示されます（例：私のスマホ）';

  @override
  String cloudBackupSummary(int profileCount, int courseCount) {
    return '時間割 $profileCount 件 · 授業 $courseCount 件';
  }

  @override
  String get cloudBackupRestoreTitle => 'このバックアップに復元';

  @override
  String cloudBackupRestoreBody(String time) {
    return '$time の時間割に復元します。未同期のローカル変更は失われます。続行しますか？';
  }

  @override
  String get cloudBackupRestoreAction => '復元';

  @override
  String get cloudBackupRestoreSuccess => 'バックアップを復元しました';

  @override
  String cloudBackupRestoreFailed(String message) {
    return '復元に失敗しました：$message';
  }

  @override
  String get cloudBackupDeleteTitle => 'このバックアップを削除';

  @override
  String cloudBackupDeleteBody(String time) {
    return '$time のクラウドバックアップを削除しますか？元に戻せません。';
  }

  @override
  String get cloudBackupDeleteSuccess => 'バックアップを削除しました';

  @override
  String cloudBackupDeleteFailed(String message) {
    return '削除に失敗しました：$message';
  }

  @override
  String get cloudBackupCreateSuccess => 'バックアップをクラウドに保存しました';

  @override
  String cloudBackupCreateFailed(String message) {
    return 'バックアップに失敗しました：$message';
  }

  @override
  String get cloudBackupUploadAsCurrentTitle => '現在のクラウド版に設定';

  @override
  String get cloudBackupUploadAsCurrentBody =>
      'このバックアップを現在のクラウド版にしますか？同期の競合を避けるために推奨します。';

  @override
  String get cloudBackupUploadAsCurrentYes => '現在の版に設定';

  @override
  String get cloudBackupUploadAsCurrentNo => 'ローカルのみ復元';

  @override
  String get cloudBackupDetailDevice => 'デバイス';

  @override
  String get cloudBackupDetailSource => '種類';

  @override
  String get cloudBackupDetailSummary => '内容';

  @override
  String get lanEditEntryTitle => 'LAN編集';

  @override
  String get lanEditEntrySubtitle => 'PCブラウザから現在の時間割を編集';

  @override
  String get lanEditTitle => 'LAN編集';

  @override
  String get lanEditIntro =>
      '有効にすると、同じWi-Fiまたはテザリング中のPCブラウザから現在の時間割を編集できます。データはクラウドに送信されず、停止するとアクセスできなくなります。';

  @override
  String get lanEditStart => 'LAN編集を開始';

  @override
  String get lanEditStop => '停止';

  @override
  String get lanEditStatusRunning => 'LAN編集セッション実行中';

  @override
  String get lanEditAddressLabel => 'アクセスURL';

  @override
  String get lanEditAddressUnavailable =>
      'LAN IPが見つかりません。Wi-Fiまたはテザリングを確認してください';

  @override
  String get lanEditPinLabel => 'PIN';

  @override
  String get lanEditPortLabel => 'ポート';

  @override
  String get lanEditCopyAddress => 'URLをコピー';

  @override
  String get lanEditCopied => 'コピーしました';

  @override
  String get lanEditHotspotHint => '寮Wi-Fiで接続できない場合は、スマホのテザリングを試してください。';

  @override
  String get lanEditQrHint => '同じLANのPCブラウザでQRコードを読み取ってください（PIN付きリンク）。';

  @override
  String get lanEditStartFailed => '開始に失敗しました';

  @override
  String get lanEditConnectedClientsLabel => '接続中';

  @override
  String get lanEditConnectedClientsNone => 'なし';

  @override
  String lanEditConnectedClientsValue(int count) {
    return '$count 台';
  }

  @override
  String get lanEditLastActivityLabel => '最終アクティビティ';

  @override
  String get aboutSupportSectionTitle => 'アプリ情報とサポート';

  @override
  String get feedbackEntryTitle => '問題報告';

  @override
  String get feedbackEntrySubtitle => 'Issue、コミュニティチャネルとフィードバック';

  @override
  String get aboutEntryTitle => 'アプリ情報';

  @override
  String get aboutEntrySubtitle => 'オープンソース、バージョン更新とGitHubリポジトリ';

  @override
  String get setSemesterStartDateAction => '学期開始日を設定';

  @override
  String get semesterStartDateAction => '学期開始日';

  @override
  String get syncCurrentWeekAction => '現在の週を同期';

  @override
  String semesterWeekCountAction(int count) {
    return '$count週';
  }

  @override
  String get selectSemesterWeekCountTitle => '学期週数を選択';

  @override
  String get selectSemesterWeekCountSubtitle => '学校に合わせて実際の授業週数に調整可能。';

  @override
  String get unifiedCourseCardColorTitle => '授業カードの色を統一';

  @override
  String get unifiedCourseCardColorSubtitle => 'オフにすると各授業の個別カラーを使用';

  @override
  String get importRandomCourseColorTitle => '授業カラーをランダム';

  @override
  String get importRandomCourseColorSubtitle =>
      'オンにすると授業名と教員でプリセット色を割り当て、一括で同じ青になるのを防ぎます';

  @override
  String get courseImportTitle => '授業インポート';

  @override
  String get chooseImportMethodTitle => 'インポート方法を選択';

  @override
  String get chooseImportMethodSubtitle =>
      '従来の.icsカレンダーインポート、画像認識インポート、リポジトリからアダプタを読み込む教務システムインポートに対応。';

  @override
  String get importMethodIcsTitle => '.icsカレンダーインポート';

  @override
  String get importMethodIcsSubtitle =>
      'WakeUpなどの時間割アプリからエクスポートしたカレンダーファイルに最適。';

  @override
  String get importMethodIcsFooter => '進入後、.icsファイルを選択して追加インポートまたは既存授業を置換可能。';

  @override
  String get importMethodAiTitle => '画像認識インポート';

  @override
  String get importMethodAiSubtitle => '時間割のスクリーンショットから直接インポート。1枚または連続複数枚に対応。';

  @override
  String get importMethodAiFooter =>
      'プロンプトをコピーし、Doubaoのエキスパートモードでスクリーンショットとプロンプトを送信、返されたJSONをコピペしてインポート、最後に学期開始日を選択。';

  @override
  String get importMethodWarehouseTitle => '教務システムインポート';

  @override
  String get importMethodWarehouseSubtitle =>
      'qingyu_warehouseから学校とアダプタを読み込み、Webログインで授業をインポート。';

  @override
  String get importMethodWarehouseFooter =>
      '進入後、学校とアダプタを選択し、教務Webページでログインしてインポートを実行。';

  @override
  String get importMethodSpreadsheetTitle => '表インポート';

  @override
  String get importMethodSpreadsheetSubtitle =>
      'Excel/WPSで軽嶼課表テンプレートを記入してインポート。.icsの事前エクスポートは不要。';

  @override
  String get importMethodSpreadsheetFooter =>
      '.csvと.xlsxに対応。テンプレートをダウンロードして記入後、ファイルを選択。';

  @override
  String get spreadsheetImportTitle => '表インポート';

  @override
  String get spreadsheetScenarioIntro =>
      '軽嶼テンプレートはヘッダーで列を識別。必須は科目名・曜日・開始節・終了節・週次、他は任意。完全版をDLするか、必須列のみでも可。WakeUp 7列形式にも対応。';

  @override
  String get spreadsheetStep1Subtitle =>
      '完全テンプレートをDLして記入するか、必須列と上课周（または開始週+終了週）だけで最小インポート。';

  @override
  String get spreadsheetStep2Subtitle => '記入後、.csvとして保存するか.xlsxのまま使用。';

  @override
  String get spreadsheetStep3Subtitle =>
      'ファイルを選択してインポート。警告がある場合は先に表示し、追加または置換を選択。';

  @override
  String get spreadsheetSupportedFilesSuffix => '.csvと.xlsxに対応（最初のシートのみ）。';

  @override
  String get chooseSpreadsheetFileAction => '表ファイルを選択';

  @override
  String get downloadSpreadsheetTemplateAction => '軽嶼課表テンプレートをダウンロード';

  @override
  String get spreadsheetImportWarningsTitle => 'インポート警告';

  @override
  String get spreadsheetImportWarningsMessage => '以下の行はスキップされました。残りの授業は続行できます：';

  @override
  String get spreadsheetImportWarningsContinue => 'インポートを続行';

  @override
  String get spreadsheetFormatUnrecognized =>
      '表形式を認識できません。軽嶼課表テンプレートを使用してください。WakeUpなど同列形式にも対応。';

  @override
  String get icsImportTitle => '.icsカレンダーインポート';

  @override
  String get applicableScenarioTitle => '適用シナリオ';

  @override
  String get icsScenarioIntro =>
      'WakeUpなどの時間割アプリで教務システムの授業をインポート済みで、.icsファイルにエクスポートできる場合、この方法が最も安定しています。';

  @override
  String stepLabel(String step) {
    return 'ステップ$step';
  }

  @override
  String get icsStep1Subtitle => 'まず他の時間割アプリで.icsカレンダーファイルをエクスポート。';

  @override
  String get icsStep2Subtitle => 'ここでファイルを選択。「追加インポート」または「既存を置換」から選択可能。';

  @override
  String get icsStep3Subtitle => 'インポート前に学期開始日と、時間割の第1週が校暦の第何週に対応するかを確認。';

  @override
  String get supportedFilesTitle => '対応ファイル';

  @override
  String get supportedFilesSuffix => 'ファイル拡張子は.icsである必要があります。';

  @override
  String get supportedFilesImageHint =>
      'スクリーンショットしかない場合は、前のページに戻って「画像認識インポート」を選択してください。';

  @override
  String get chooseIcsFileAction => '.icsファイルを選択';

  @override
  String get timetableAppName => '軽屿時間割';

  @override
  String get switchProfileHint => 'タップで時間割切替';

  @override
  String get moreTooltip => 'もっと見る';

  @override
  String get pleaseSetSemesterStartDate => '時間割設定で学期開始日を入力してください';

  @override
  String get deleteScheduleTitle => 'スケジュール削除';

  @override
  String get deleteLessonTitle => 'この授業を削除';

  @override
  String get cancelAction => 'キャンセル';

  @override
  String get confirmAction => '確認';

  @override
  String get deleteAction => '削除';

  @override
  String deletedCourseMessage(String name) {
    return '削除済み：$name';
  }

  @override
  String get deleteFailed => '削除失敗';

  @override
  String get rescheduleFailed => '時間変更失敗';

  @override
  String get timetableManagement => '時間割管理';

  @override
  String weekLabel(int week) {
    return '第$week週';
  }

  @override
  String sectionLabel(int section) {
    return '第$section時限';
  }

  @override
  String get feedbackTitle => '問題報告';

  @override
  String get feedbackIntro =>
      'クラッシュ、授業表示の異常、インポートの問題、または機能提案がある場合は、以下のチャネルからフィードバックしてください。';

  @override
  String get feedbackIssueHint =>
      '再現手順、スクリーンショット、バージョン番号、ログに関する問題は、GitHub Issueを推奨。';

  @override
  String get githubIssueTitle => 'GitHub Issue';

  @override
  String get githubIssueSubtitle =>
      'リポジトリのIssueページを開き、問題や提案の送信、既存のフィードバックを確認可能。';

  @override
  String get openIssuePage => 'Issueページを開く';

  @override
  String get copyAddress => 'アドレスをコピー';

  @override
  String get copiedIssueAddress => 'Issueアドレスをコピーしました';

  @override
  String get copyXiaohongshuId => 'Xiaohongshu IDをコピー';

  @override
  String get copiedXiaohongshuId => 'Xiaohongshu IDをコピーしました';

  @override
  String get copyCoolapkId => 'Coolapk IDをコピー';

  @override
  String get copiedCoolapkId => 'Coolapk IDをコピーしました';

  @override
  String get copyQqGroupId => 'QQグループIDをコピー';

  @override
  String get copiedQqGroupId => 'QQグループIDをコピーしました';

  @override
  String get timetableProfilesTitle => '時間割管理';

  @override
  String get createTimetableTooltip => '新規時間割';

  @override
  String coursesAndWeekSummary(int count, int week) {
    return '$count科目・第$week週';
  }

  @override
  String get moreActionsTooltip => 'その他の操作';

  @override
  String get switchToThisTimetable => 'この時間割に切替';

  @override
  String get renameAction => '名前変更';

  @override
  String get duplicateAction => '複製';

  @override
  String get clearCoursesAction => '授業をクリア';

  @override
  String get usingNow => '使用中';

  @override
  String switchedToProfile(String name) {
    return '$nameに切替済み';
  }

  @override
  String get createTimetableTitle => '新規時間割';

  @override
  String get timetableNameLabel => '時間割名';

  @override
  String get timetableNameHint => '例：2年次後期';

  @override
  String get createAction => '作成';

  @override
  String createdProfile(String name) {
    return '時間割作成済み：$name';
  }

  @override
  String get renameTimetableTitle => '時間割名変更';

  @override
  String get saveAction => '保存';

  @override
  String renamedProfile(String name) {
    return '名前変更済み：$name';
  }

  @override
  String get clearCurrentTimetableTitle => '現在の時間割をクリア';

  @override
  String clearCurrentTimetableMessage(String name) {
    return '「$name」の全授業をクリアしますか？時間割設定は保持されます。';
  }

  @override
  String get clearAction => 'クリア';

  @override
  String clearedProfile(String name) {
    return '時間割クリア済み：$name';
  }

  @override
  String get noCoursesInCurrentProfile => '現在の時間割に授業がありません';

  @override
  String get deleteTimetableTitle => '時間割削除';

  @override
  String deleteTimetableMessage(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String deletedProfile(String name) {
    return '時間割削除済み：$name';
  }

  @override
  String get keepAtLeastOneProfile => '少なくとも1つの時間割を保持してください';

  @override
  String get dataTransferTitle => 'データバックアップと移行';

  @override
  String get fullExportTitle => '完全エクスポート';

  @override
  String get fullExportSubtitle => '現在の時間割、または全時間割・テンプレート・選択状態を一括エクスポート。';

  @override
  String get exportCurrentTimetable => '現在の時間割をエクスポート';

  @override
  String get exportAllData => '全データをエクスポート';

  @override
  String get fullImportTitle => '完全インポート';

  @override
  String get fullImportSubtitle =>
      'インポート時に現在の時間割を上書きするか、新しい時間割としてインポート可能。事前にバックアップを推奨。';

  @override
  String get chooseFileAndImport => 'ファイルを選択してインポート';

  @override
  String get transferOverviewTitle => '現在の移行可能コンテンツ';

  @override
  String courseCountBullet(int count) {
    return '授業数：$count科目';
  }

  @override
  String currentTimetableBullet(String name) {
    return '現在の時間割：$name';
  }

  @override
  String allTimetablesBullet(int count) {
    return '全時間割：$count個';
  }

  @override
  String timeSchemeCountBullet(int count) {
    return 'テンプレート：$countセット';
  }

  @override
  String currentWeekBullet(int week) {
    return '現在の週：第$week週';
  }

  @override
  String get semesterStartUnsetBullet => '学期開始日：未設定';

  @override
  String semesterStartBullet(String date) {
    return '学期開始日：$date';
  }

  @override
  String fileExtensionBullet(String extension) {
    return 'ファイル拡張子：.$extension';
  }

  @override
  String get selectImportModeTitle => 'インポートモード選択';

  @override
  String get selectImportModeMessage =>
      '現在の時間割を上書きするか、バックアップを新しい独立した時間割としてインポート可能。';

  @override
  String get replaceCurrentTimetable => '現在の時間割を上書き';

  @override
  String get importAsNewTimetable => '新しい時間割としてインポート';

  @override
  String get createdNewTimetableAfterImport => 'インポート成功、新しい時間割を作成しました';

  @override
  String get backupRestoredSuccess => 'インポート成功、バックアップデータを復元しました';

  @override
  String get importFailedInvalidFile => 'インポート失敗、ファイルが有効か確認してください';

  @override
  String get welcomeTitle => 'ようこそ';

  @override
  String get welcomeAppName => '軽屿時間割';

  @override
  String get welcomeSubtitle => 'そのまま使い始めることも、授業をインポートしたりバックアップから復元することもできます。';

  @override
  String get thirdPartyDisclaimer =>
      '声明：本アプリは第三者開発者が独立して開発したものであり、学習・研究目的のみに使用されます。Xiaomi（小米）公式ソフトウェアではなく、Xiaomi Technology Co., Ltd.（小米科技有限責任公司）とは一切の隶属、協力、授权関係がありません。コンテンツの侵权がある場合は、権利者より作者までご連絡ください。確認次第、速やかに下架・削除いたします。';

  @override
  String get startUsingTitle => '使い始める';

  @override
  String get startUsingSubtitle => 'アプリに入り、初回使用ガイドを続行';

  @override
  String get importTimetableTitle => '時間割インポート';

  @override
  String get importTimetableSubtitle => '.icsファイルまたはAI解析結果から授業をインポート';

  @override
  String get restoreBackupTitle => 'バックアップから復元';

  @override
  String get restoreBackupSubtitle => '.mikcbバックアップファイルから旧データを復元';

  @override
  String get viewGuideTitle => '機能説明を見る';

  @override
  String get viewGuideSubtitle => '権限、スーパーアイランドと基本設定を確認';

  @override
  String get migrationTitle => '旧データ移行';

  @override
  String get migrationSafeTitle => 'ご安心ください、データ消失ではありません';

  @override
  String get migrationSafeSubtitle =>
      'アプリのパッケージ名が変更されたため、一時的にホーム画面に2つのアイコンが表示されます。旧データは旧バージョンのアプリにあります。まず旧バージョンでバックアップを取ってから、新版でインポートしてください。';

  @override
  String get migrationStep1Title => '旧バージョンを開く';

  @override
  String get migrationStep1Subtitle =>
      '「データバックアップと移行」ページで「全データをエクスポート」をタップ。「現在の時間割をエクスポート」は押さず、旧バージョンを先にアンインストールしないでください。';

  @override
  String get migrationStep2Title => 'バックアップファイルを保存';

  @override
  String get migrationStep2Subtitle =>
      '旧バージョンでエクスポート後、システム共有パネルが表示されます。「ファイルに保存」を優先し、ダウンロードフォルダへの保存を推奨。';

  @override
  String get migrationStep3Title => '現在のバージョンでインポート';

  @override
  String get migrationStep3Subtitle =>
      '新版に戻り、システムファイルセレクターでダウンロードフォルダの.mikcbバックアップファイルを選択して復元。新版のデータが正常であることを確認してから、旧バージョンをアンインストールしてください。';

  @override
  String get migrationNoSaveToFilesTitle => '「ファイルに保存」がない場合';

  @override
  String get migrationNoSaveToFilesSubtitle =>
      'WeChatの任意のチャットに共有し、WeChatでバックアップファイルを開いて保存。保存後、通常Download/WeiXinフォルダに表示されます。新版でこの.mikcbファイルを選択してインポート。';

  @override
  String get openingOldApp => '旧バージョンを開いています...';

  @override
  String get openOldAppForBackup => '旧バージョンでバックアップ';

  @override
  String get backupDoneGoImport => 'バックアップ完了、インポートへ';

  @override
  String get startFreshWithoutMigration => '新規アプリとして開始、移行しない';

  @override
  String get openOldAppFailed => '旧バージョンを開けませんでした。手動でホーム画面から旧バージョンを開いてください';

  @override
  String get supportCreatorTitle => '作者にコーヒーをおごる';

  @override
  String get supportHeroTitle => '軽屿時間割の継続的更新を支援';

  @override
  String get supportHeroSubtitle =>
      'あなたの支援は時間割のメンテナンス、教務インポート適応とUX改善に直接活用されます。';

  @override
  String get supportChipFixes => '問題修正';

  @override
  String get supportChipAdapters => '教務適応';

  @override
  String get supportChipPolish => 'UX改善';

  @override
  String get supportMethodTitle => '支援方法を選択';

  @override
  String get wechatLabel => 'WeChat';

  @override
  String get alipayLabel => 'Alipay';

  @override
  String get supportWeChatHint => 'WeChatでQRコードをスキャンして作者を支援';

  @override
  String get supportAlipayHint => 'AlipayでQRコードをスキャンして作者を支援';

  @override
  String get viewLargeImage => '大きな画像を見る';

  @override
  String get saveToGallery => 'ギャラリーに保存';

  @override
  String get supportCompleteThanks => '軽屿時間割の継続的な改善を支援していただきありがとうございます ❤️';

  @override
  String get supportConfirmed => '支援しました';

  @override
  String get donorListTitle => '謝辞リスト';

  @override
  String get donorListLoadFailed => 'オンライン謝辞リストを読み込めません。';

  @override
  String get reloadAction => '再読み込み';

  @override
  String updatedAtLabel(String time) {
    return '$timeに更新';
  }

  @override
  String get donorListEmpty =>
      'リストがまだ記入されていません。docs/donors.jsonを直接編集して再公開できます。';

  @override
  String get savedToGallery => 'ギャラリーに保存しました';

  @override
  String get saveToGalleryFailed => 'ギャラリーへの保存に失敗しました';

  @override
  String saveFailedWithError(String error) {
    return '保存失敗：$error';
  }

  @override
  String get supportRunningBadge => '稼働中';

  @override
  String get supportTapQrHint => 'タップで拡大';

  @override
  String get supportSaveShort => '保存';

  @override
  String get supportConfirmedShort => '支援済み';

  @override
  String get donorSearchHint => '名前/メッセージ検索...';

  @override
  String get donorSortLargeFirst => '高額順';

  @override
  String get donorSortSmallFirst => '低額順';

  @override
  String get supportMonthlyGoalLabel => '今月のサーバー・証明書更新進捗';

  @override
  String supportGoalRaised(String raised, String goal) {
    return '集まった: $raised / 目標 $goal';
  }

  @override
  String supportBackerCount(int count) {
    return 'すでに $count 人が支援';
  }

  @override
  String get supportDonorListFooter => '名前は永久に残ります 💖';

  @override
  String supportMarqueeThanks(String name, String amount) {
    return '🎉 $name さん $amount ありがとう';
  }

  @override
  String get supportMarqueeTail => '軽屿時間割は安定稼働中 — あなたの支援を待っています！';

  @override
  String get scanQrWechatTitle => 'WeChatでQRコードをスキャン';

  @override
  String get scanQrAlipayTitle => 'AlipayでQRコードをスキャン';

  @override
  String get scanQrSubtitle => 'スクリーンショットしてスキャン、支援ありがとう！';

  @override
  String get courseOverviewTitle => '授業一覧と編集';

  @override
  String get addNewCourseTooltip => '新規授業追加';

  @override
  String get emptyCourseOverviewHint => '時間割を長押しするか、右上のボタンから授業を追加';

  @override
  String conflictDetectedMessage(int count) {
    return '$count件の排課に実際の競合が検出されました。授業リストに競合項目をマーク済み。';
  }

  @override
  String conflictCountLabel(int count) {
    return '競合$count件';
  }

  @override
  String scheduledCountLabel(int count) {
    return '排課合計$count件';
  }

  @override
  String scheduledCountWithConflictHint(int count) {
    return '排課合計$count件・展開して競合詳細を確認';
  }

  @override
  String courseTimeSummary(int day, int start, int end) {
    return '時間：$day曜$start〜$end時限';
  }

  @override
  String get teacherUnset => '未設定';

  @override
  String get locationUnset => '未設定';

  @override
  String courseDetailSummary(
    String weekDescription,
    String teacher,
    String location,
  ) {
    return '$weekDescription　教師：$teacher　教室：$location';
  }

  @override
  String courseDetailSummaryWithConflict(
    String weekDescription,
    String teacher,
    String location,
    String conflictSummary,
  ) {
    return '$weekDescription　教師：$teacher　教室：$location\n競合授業：$conflictSummary';
  }

  @override
  String get confirmDeleteTitle => '削除確認';

  @override
  String confirmDeleteCourseMessage(String name) {
    return '授業「$name」を削除しますか？';
  }

  @override
  String get currentScheduleTitle => '現在の排課';

  @override
  String get currentScheduleSubtitle => '这里的曜日、時限、教室、週次と奇数偶数週はこの排課のみに影響。';

  @override
  String get timeSchemeLabel => '授業時間方案';

  @override
  String followCurrentTimetableWithName(String name) {
    return '現在の時間割に連携（$name）';
  }

  @override
  String get followCurrentTimetableDescription =>
      'デフォルトで現在の時間割のメインテンプレートに連携。ほとんどの授業に最適。';

  @override
  String get overrideTimeSchemeDescription =>
      'この授業は選択したテンプレートを個別使用し、メインテンプレートに連携しません。';

  @override
  String get weekdayLabel => '曜日';

  @override
  String get startSectionLabel => '開始時限';

  @override
  String get endSectionLabel => '終了時限';

  @override
  String timeRangeLabel(String start, String end) {
    return '時間：$start - $end';
  }

  @override
  String get locationLabel => '授業場所';

  @override
  String get singleLessonWeekTitle => '授業週次';

  @override
  String get singleLessonWeekSubtitle => '単一授業は1つの週次にのみ表示。振替授業や臨時追加に最適。';

  @override
  String get selectWeekLabel => '週次を選択';

  @override
  String get weekSettingsTitle => '週次設定';

  @override
  String get rangeWeeksLabel => '連続週';

  @override
  String get customWeeksLabel => 'カスタム週';

  @override
  String get startWeekLabel => '開始週';

  @override
  String get endWeekLabel => '終了週';

  @override
  String get allWeeksFilter => '全週';

  @override
  String get oddWeeksFilter => '奇数週';

  @override
  String get evenWeeksFilter => '偶数週';

  @override
  String get rangeWeeksAllHint => '開始週から終了週まで連続で授業を配置。';

  @override
  String get rangeWeeksOddHint => '範囲内の奇数週のみ保持。';

  @override
  String get rangeWeeksEvenHint => '範囲内の偶数週のみ保持。';

  @override
  String get selectAllAction => '全選択';

  @override
  String get selectOddWeeksAction => '奇数週';

  @override
  String get selectEvenWeeksAction => '偶数週';

  @override
  String selectedWeeksSummary(int count, String weeks) {
    return '$count週選択：第$weeks週';
  }

  @override
  String get courseColorTitle => '授業カラー';

  @override
  String get customPaletteAction => 'カラーパレットでカスタム';

  @override
  String get colorPaletteTitle => 'カラーパレット';

  @override
  String get colorHexLabel => 'カラーHex';

  @override
  String get weekdayMon => '月曜';

  @override
  String get weekdayTue => '火曜';

  @override
  String get weekdayWed => '水曜';

  @override
  String get weekdayThu => '木曜';

  @override
  String get weekdayFri => '金曜';

  @override
  String get weekdaySat => '土曜';

  @override
  String get weekdaySun => '日曜';

  @override
  String hueLabel(int value) {
    return '色相$value';
  }

  @override
  String saturationLabel(int value) {
    return '彩度$value%';
  }

  @override
  String brightnessLabel(int value) {
    return '明度$value%';
  }

  @override
  String get useThisColor => 'この色を使用';

  @override
  String get selectAtLeastOneWeek => '少なくとも1つの授業週次を選択してください';

  @override
  String get saveFailed => '保存失敗';

  @override
  String get courseAddedSuccess => '授業追加成功';

  @override
  String get courseUpdatedSuccess => '授業更新成功';

  @override
  String get aboutTitle => 'アプリ情報';

  @override
  String get loadingText => '読み込み中';

  @override
  String versionLabel(String version) {
    return 'バージョン$version';
  }

  @override
  String get aboutHeroSubtitle =>
      '時間割閲覧、授業リマインダー、HyperOSスーパーアイランド体験に磨きをかけたAndroidオープンソースプロジェクト。';

  @override
  String get platformLabel => 'プラットフォーム';

  @override
  String get focusLabel => '重点';

  @override
  String get updateLabel => '更新';

  @override
  String get prereleaseIncluded => 'プレリリース含む';

  @override
  String get stableOnly => '正式版';

  @override
  String get aboutUpdatesTitle => 'バージョン更新';

  @override
  String get aboutUpdatesSubtitle => '更新確認とダウンロード';

  @override
  String get aboutChangelogTitle => '更新履歴';

  @override
  String get aboutChangelogSubtitle => '全バージョンの更新内容を確認';

  @override
  String get aboutPositioningTitle => 'プロジェクトの位置づけ';

  @override
  String get aboutPositioningSubtitle => 'これは何か、誰向けか、コア機能は何か';

  @override
  String get aboutPositioningBullet1 => '週表示時間割、授業CRUD、.icsインポート対応';

  @override
  String get aboutPositioningBullet2 => '対応学校の教務システムWebログインインポートと完全バックアップ移行に対応';

  @override
  String get aboutPositioningBullet3 =>
      'リアルタイム通知対応。HyperOS 3.0.300以降でスーパーアイランド/フォーカス通知表示に対応';

  @override
  String get aboutPositioningBullet4 => '複数時間割、テンプレート、テーマカラーとカードスタイルのカスタマイズに対応';

  @override
  String get aboutImportMigrationTitle => 'インポートと移行';

  @override
  String get aboutImportMigrationSubtitle => '現在のインポート方法、バックアップ復元と移行提案';

  @override
  String get aboutImportMigrationBullet1 =>
      '現在のバージョンは対応学校の教務システムWebログインインポートに対応。「授業インポート > 教務システムインポート」から学校とアダプタを選択してください。';

  @override
  String get aboutImportMigrationBullet2 =>
      'お使いの学校がまだ未対応の場合、WakeUpなどの時間割アプリで授業をインポートし、カレンダー形式でエクスポートしてから本アプリでインポート可能。';

  @override
  String get aboutImportMigrationBullet3 =>
      '他のユーザーが本アプリを使用している場合、完全バックアップファイルをエクスポートしてもらい、「データバックアップと移行」からインポートして復元可能。';

  @override
  String get aboutImportMigrationBullet4 =>
      'パケットキャプチャ、Webデバッグ、JavaScriptができる場合は、qingyu_warehouseで教務適応の補充に参加歓迎。';

  @override
  String get aboutContributorsTitle => 'コード貢献者';

  @override
  String get aboutContributorsSubtitle => '開発者と教務インポート適応者の一覧';

  @override
  String get aboutRepositoryTitle => 'オープンソースリポジトリ';

  @override
  String get aboutAppLogsTitle => 'アプリログ';

  @override
  String get aboutAppLogsSubtitle =>
      'error / warn / info / debug / verbose全レベルのログを確認';

  @override
  String get appLogsShareText =>
      '軽屿時間割がエクスポートしたアプリログです。ローカル実行記録を含み、更新、インポート、通知、ページ、クラッシュ問題のトラブルシュートに使用できます。';

  @override
  String get appLogsShareSubject => '軽屿時間割 - アプリログ';

  @override
  String get appLogsRecordingEnabled => 'アプリログを記録中';

  @override
  String get appLogsRecordingDisabled => 'アプリログ記録がオフ';

  @override
  String get appLogsCopyAction => 'ログをコピー';

  @override
  String get appLogsCopied => '現在のログをコピーしました';

  @override
  String get appLogsExportAction => 'ログをエクスポート';

  @override
  String get appLogsClearAction => 'ログをクリア';

  @override
  String get appLogsCleared => 'アプリログをクリアしました';

  @override
  String get appLogsClearFailed => 'アプリログのクリアに失敗しました';

  @override
  String get appLogsSourceApp => '应用';

  @override
  String get appLogsSourceNative => '超级岛';

  @override
  String get appLogsRecordingPausedHint => '记录已关闭。下方为历史日志，关闭后不再新增。';

  @override
  String get aboutRepositorySubtitle => 'GitHubリポジトリ、ソース、Releaseとフィードバック';

  @override
  String get timeSchemeTitle => '時間テンプレート';

  @override
  String get newSchemeTooltip => '新規テンプレート';

  @override
  String timeSchemeSummary(
    int sections,
    int profiles,
    int courses,
    int overrideCourses,
  ) {
    return '$sections時限・$profiles個の時間割・$courses件の授業・$overrideCourses件の副テンプレート';
  }

  @override
  String get viewUsageAction => '使用状況を確認';

  @override
  String get applyToCurrentTimetable => '現在の時間割に適用';

  @override
  String get editSectionsAction => '時限を編集';

  @override
  String get createTimeSchemeTitle => '新規テンプレート';

  @override
  String get timeSchemeNameLabel => 'テンプレート名';

  @override
  String get timeSchemeNameHint => '例：夏季時間割';

  @override
  String get renameTimeSchemeTitle => 'テンプレート名変更';

  @override
  String renamedToMessage(String name) {
    return '名前変更済み：$name';
  }

  @override
  String get deleteTimeSchemeTitle => 'テンプレート削除';

  @override
  String deleteTimeSchemeMessage(String name) {
    return '「$name」を削除しますか？使用中のテンプレートは削除できません。';
  }

  @override
  String deletedTimeSchemeMessage(String name) {
    return 'テンプレート削除済み：$name';
  }

  @override
  String get timeSchemeInUseMessage => 'このテンプレートは時間割で使用中です';

  @override
  String get copiedTimeSchemeMessage => 'テンプレートをコピーしました';

  @override
  String appliedTimeSchemeMessage(String name) {
    return 'テンプレート適用済み：$name';
  }

  @override
  String timeSchemeUsageTitle(String name) {
    return '「$name」の使用状況';
  }

  @override
  String get timeSchemeUsageIntro => 'まず影響範囲を確認してから、直接編集するかコピーしてから変更するか判断。';

  @override
  String get profileCountLabel => '時間割';

  @override
  String get courseCountLabel => '授業';

  @override
  String get overrideTimeSchemeLabel => '副テンプレート';

  @override
  String get directlyBoundProfilesTitle => 'このテンプレートに直接バインドされた時間割';

  @override
  String get directlyBoundProfilesEmpty => '現在このテンプレートを直接使用している時間割はありません。';

  @override
  String get directlyBoundProfilesSubtitle => 'これらの時間割はこのテンプレートに切替後、この時限時間で表示。';

  @override
  String get followMainSchemeCoursesTitle => 'メインテンプレートに連携する授業';

  @override
  String get followMainSchemeCoursesEmpty => '現在メインテンプレート経由で使用している授業はありません。';

  @override
  String get followMainSchemeCoursesSubtitle =>
      'これらの授業は個別に副テンプレートを設定しておらず、所属時間割と一緒にこのテンプレートを使用。';

  @override
  String get overrideSchemeCoursesTitle => '副テンプレートとして使用する授業';

  @override
  String get overrideSchemeCoursesEmpty =>
      '現在このテンプレートを副テンプレートとして使用している授業はありません。';

  @override
  String get overrideSchemeCoursesSubtitle =>
      'これらの授業は所属時間割のメインテンプレートが変わっても、引き続きこのテンプレートを個別使用。';

  @override
  String get closeAction => '閉じる';

  @override
  String get editTimeSchemeTitle => 'テンプレート編集';

  @override
  String get backToSchemeList => 'テンプレート一覧に戻る';

  @override
  String get currentInUse => '現在使用中';

  @override
  String get quickGenerateAction => 'クイック生成';

  @override
  String get addSectionAction => '時限を追加';

  @override
  String get removeLastSectionAction => '末尾の時限を削除';

  @override
  String get resetDefaultAction => 'デフォルトに戻す';

  @override
  String get sectionTimesTitle => '時限時間';

  @override
  String get sectionTimesSubtitle =>
      '現在の時間割がこのテンプレートを使用中の場合、時限数は使用済みの最大時限以上である必要があります。';

  @override
  String get schemeListCurrentLabel => '現在';

  @override
  String get schemeListCountLabel => '数';

  @override
  String get sectionCountLabel => '時限数';

  @override
  String get quickGenerateTimeSchemeTitle => '時間割時間をクイック生成';

  @override
  String get addBreakRuleAction => '大休憩ルールを追加';

  @override
  String get afterSectionLabel => '何時限目の後';

  @override
  String get breakDurationMinutesLabel => '休憩時間（分）';

  @override
  String get fillNumbersValidationMessage => '時限数と時間を数字で入力してください';

  @override
  String get timeSchemeEditorActiveAndCoursesHint =>
      '現在の時間割と一部の授業がこのテンプレートを使用中。保存後、関連する全ての時間割と授業が同期更新されます。';

  @override
  String get timeSchemeEditorActiveHint =>
      '現在の時間割がこのテンプレートを使用中。保存後、使用中の全ての時間割が同期更新されます。';

  @override
  String get timeSchemeEditorOverrideHint =>
      '授業がこのテンプレートを副テンプレートとして使用中。保存後、参照する全ての授業が同期更新されます。';

  @override
  String get editTimeAction => '時間を編集';

  @override
  String editingSchemeLabel(String name) {
    return '編集中：$name';
  }

  @override
  String get copiedTimeSchemeShortMessage => 'テンプレートをコピーしました';

  @override
  String get unnamedTimeScheme => '名前未設定テンプレート';

  @override
  String get unsetLabel => '未選択';

  @override
  String get timeSchemeUsageCourseRefPrefix => '授業参照：';

  @override
  String get mainTimeSchemeLabel => 'メインテンプレート';

  @override
  String get overrideTimeSchemeShortLabel => '副テンプレート';

  @override
  String timeSchemeBottomUsageSingle(String first) {
    return '$first';
  }

  @override
  String timeSchemeBottomUsageMulti(String first, int count) {
    return '$firstなど$count件の授業';
  }

  @override
  String get morningSectionCountLabel => '午前の時限数';

  @override
  String get morningFirstSectionTimeLabel => '午前1時限目の開始時間';

  @override
  String get afternoonSectionCountLabel => '午後の時限数';

  @override
  String get afternoonFirstSectionTimeLabel => '午後1時限目の開始時間';

  @override
  String get eveningSectionCountLabel => '夜間の時限数';

  @override
  String get eveningFirstSectionTimeLabel => '夜間1時限目の開始時間';

  @override
  String get classDurationMinutesLabel => '1時限の長さ（分）';

  @override
  String get smallBreakDurationMinutesLabel => '小休憩時間（分）';

  @override
  String get largeBreakRulesTitle => '大休憩ルール';

  @override
  String get noLargeBreakRulesHint => '大休憩ルール未設定。全て小休憩時間が使用されます。';

  @override
  String get deleteRuleTooltip => 'ルール削除';

  @override
  String get generateAction => '生成';

  @override
  String get liveSettingsTitle => 'スーパーアイランドと通知';

  @override
  String get liveReminderTimingEntryTitle => 'リマインダー時間帯';

  @override
  String get liveReminderTimingEntrySubtitle =>
      '授業前・授業中/終了リマインダーの切替、および終了前にスーパーアイランド/フォーカスリマインダーに切り替え';

  @override
  String get liveBeforeClassDisplayEntryTitle => '授業前リマインダー表示';

  @override
  String get liveDuringEndDisplayEntryTitle => '授業中/終了リマインダー表示';

  @override
  String get liveKeepAliveEntryTitle => 'バックグラウンド常駐';

  @override
  String get liveKeepAliveEntrySubtitle => '非表示、バックグラウンド常駐補助サービスと権限エントリ';

  @override
  String get liveTestingEntryTitle => 'テストと診断';

  @override
  String get liveTestingEntrySubtitle => 'テスト通知送信、スーパーアイランドとローカル診断ログの確認';

  @override
  String get followBeforeClassSetting => '授業前リマインダーに連携';

  @override
  String get liveReminderTimingTitle => 'リマインダー時間帯';

  @override
  String get liveReminderSwitchesTitle => 'リマインダー切替';

  @override
  String get liveReminderSwitchesSubtitle =>
      '異なるリマインダー時間帯を自由に組み合わせ可能。これらの切替は相互に代替しません。';

  @override
  String get beforeClassReminderTitle => '授業前リマインダー';

  @override
  String beforeClassReminderSubtitle(int minutes) {
    return '授業開始$minutes分前にポップアップ';
  }

  @override
  String get duringClassReminderTitle => '授業中/終了リマインダー';

  @override
  String get duringClassReminderSubtitle => '授業開始後から終了前までの表示にのみ影響';

  @override
  String get liveClassReminderLeadTitle => '終了前にスーパーアイランド/フォーカスリマインダーに切り替え';

  @override
  String get liveClassReminderLeadOptionImmediate => '授業開始と同時に切替';

  @override
  String liveClassReminderLeadOptionMinutes(int minutes) {
    return '終了$minutes分前に切替';
  }

  @override
  String get liveDisplayModeTitle => '表示モード';

  @override
  String get liveDisplayModeSubtitle => '有効なリマインダー時間帯に適用。';

  @override
  String get duringClassStatusNotificationTitle => '授業中ステータスバー通知';

  @override
  String get duringClassStatusNotificationImmediate => '授業開始後もステータスバー通知を保持';

  @override
  String get duringClassStatusNotificationBeforeEnd =>
      '終了リマインダー開始前まで通常通知テキストを保持';

  @override
  String get duringClassStatusNotificationPersistent =>
      '授業開始後も通常授業中通知を継続表示し、終了リマインダー前に切替';

  @override
  String get enableIslandDisplayTitle => 'スーパーアイランド/ダイナミックアイランド表示対応';

  @override
  String get enableIslandDisplaySubtitle => 'オフにするとシステムスーパーアイランドのトリガーを停止';

  @override
  String get liveTimeThresholdTitle => '時間しきい値';

  @override
  String get liveTimeThresholdSubtitle =>
      '授業前ポップアップ、終了前のスーパーアイランド/フォーカスリマインダー切替、および秒単位カウントダウンを制御。';

  @override
  String get beforeClassPopupLabel => '授業前ポップアップ時間';

  @override
  String beforeClassMinutesOption(int minutes) {
    return '$minutes分';
  }

  @override
  String get beforeEndSecondsLabel => '終了前秒単位リマインダーしきい値';

  @override
  String beforeEndSecondsOption(int seconds) {
    return '$seconds秒';
  }

  @override
  String timeCorrectionLabel(String value) {
    return 'チャイム時間補正：$value';
  }

  @override
  String get timeCorrectionTitle => '铃声时间矫正';

  @override
  String get timeCorrectionHelp => '学校のチャイムが時間割より数秒早い場合は「早める」、遅い場合は「遅らせる」に設定。';

  @override
  String get duringEndTimeDisplayLabel => '授業中/終了リマインダーの時間スタイル';

  @override
  String get duringEndTimeDisplayHelp =>
      'コンパクトリマインダーで直近の時間を表示するか、全体の合計時間を表示するかを制御。';

  @override
  String get liveDisplayContentTitle => '表示内容';

  @override
  String get liveDisplayContentSubtitle =>
      'この設定グループは現在のステージのみに影響し、他のリマインダー表示は変更しません。';

  @override
  String get showCourseNameTitle => '授業名を表示';

  @override
  String get preferShortNameTitle => '略称を優先表示';

  @override
  String get preferShortNameSubtitle => '略称は3文字以内を推奨';

  @override
  String get showLocationTitle => '場所を表示';

  @override
  String get showCountdownTitle => 'カウントダウンを表示';

  @override
  String get countdownFormatLabel => 'カウントダウン形式';

  @override
  String get countdownFormatHelp => '分のみスタイルは分単位で更新、秒付きスタイルは秒単位で更新';

  @override
  String get showStageTextTitle => 'ステージステータステキストを表示';

  @override
  String get showStageTextSubtitle => 'カウントダウンオフ後も「もうすぐ授業/授業中/終了リマインダー」を継続表示可能';

  @override
  String get hidePrefixTextTitle => 'プレフィックステキストを非表示';

  @override
  String get hidePrefixTextSubtitle => '例：「もうすぐ授業」などのプレフィックスを非表示';

  @override
  String get beforeClassQuickActionTitle => '授業前クイックアクション';

  @override
  String get beforeClassQuickActionSubtitle =>
      '授業前リマインダーの展開通知にのみ表示。サイレント/おやすみモードは授業終了後と端末再起動後に自動復元。おやすみモード初回はシステム認証ページに飛ぶ場合あり。';

  @override
  String liveMiuiLabelSizePreview(String value) {
    return '$value';
  }

  @override
  String get liveIslandVisualTitle => '左側アイコンと展開状態';

  @override
  String get liveIslandVisualSubtitle =>
      '左側テキスト画像、展開状態の大きなアイコンとカスタム画像は全て現在のステージ別に保存。';

  @override
  String get liveMiuiLabelImageTitle => '小米アイランド左側テキストアイコン';

  @override
  String get liveMiuiLabelImageSubtitle => '小米端末スタイルのみ有効。授業名または場所を左側アイコン位置に生成。';

  @override
  String get liveMiuiLabelContentLabel => '左側テキスト内容';

  @override
  String get liveMiuiLabelStyleLabel => '左側アイコンスタイル';

  @override
  String get liveMiuiLabelLogoTitle => '左側アイコンLogo';

  @override
  String get liveMiuiLabelLogoSubtitle =>
      '「アイコン+テキスト」スタイルでのみ有効。未選択時はアプリアイコンを継続使用。';

  @override
  String liveMiuiLabelLogoCornerRadiusLabel(String value) {
    return '左側アイコン角丸$value';
  }

  @override
  String get liveMiuiLabelLogoCornerRadiusTitle => '左侧图标圆角';

  @override
  String liveMiuiLabelFontSizeLabel(String value) {
    return '左側テキストサイズ$value';
  }

  @override
  String get liveMiuiLabelFontSizeTitle => '左侧文字大小';

  @override
  String liveMiuiLabelOffsetXLabel(String value) {
    return '左側テキスト水平オフセット$value';
  }

  @override
  String get liveMiuiLabelOffsetXTitle => '左侧文字水平偏移';

  @override
  String liveMiuiLabelOffsetYLabel(String value) {
    return '左側テキスト垂直オフセット$value';
  }

  @override
  String get liveMiuiLabelOffsetYTitle => '左侧文字垂直偏移';

  @override
  String get liveMiuiLabelFontWeightLabel => '左側テキスト太さ';

  @override
  String get liveMiuiLabelRenderQualityLabel => '左側テキスト鮮明度';

  @override
  String get liveMiuiExpandedIconLabel => '展開状態の大きなアイコン';

  @override
  String get selectImageAction => '画像を選択';

  @override
  String get replaceImageAction => '画像を変更';

  @override
  String get liveDisplayConfigModeTitle => '設定モード';

  @override
  String get liveDisplayConfigModeSubtitle =>
      'オンにすると、授業中と終了リマインダーが授業前リマインダー表示に完全連携。下の個別設定は一時的に編集不可。';

  @override
  String get followBeforeClassDisplayTitle => '授業前リマインダー設定に連携';

  @override
  String get liveKeepAliveTitle => 'バックグラウンド常駐';

  @override
  String get liveKeepAliveOptionsTitle => '常駐オプション';

  @override
  String get liveKeepAliveOptionsSubtitle => 'スーパーアイランドとリマインダーのバックグラウンド安定性を向上。';

  @override
  String get hideFromRecentsTitle => '最近のタスクからアプリを非表示';

  @override
  String get hideFromRecentsSubtitle => 'オンにすると最近のタスクリストに表示されないようにします。';

  @override
  String get keepAliveServiceTitle => '軽屿時間割バックグラウンド常駐サービス';

  @override
  String get keepAliveServiceEnabledSubtitle =>
      '現在オン。システムがバックグラウンド常駐補助サービスを利用可能な状態に維持。';

  @override
  String get keepAliveServiceDisabledSubtitle =>
      '現在オフ。システムのアクセシビリティ設定で手動でオンにできます。';

  @override
  String get goEnableAction => '有効にする';

  @override
  String get layoutEntryTitle => 'レイアウトと時限';

  @override
  String get layoutEntrySubtitle => '時限時間、行高さ、時間列、週末表示とカードレイアウト';

  @override
  String get remindersSectionTitle => 'リマインダーと通知';

  @override
  String get liveGuideEntryTitle => '使用ガイドと権限';

  @override
  String get liveGuideEntrySubtitle => '略称設定、通知、自動起動、バッテリー戦略';

  @override
  String get managementSectionTitle => '時間割管理';

  @override
  String timeSchemeEntryCurrentPrefix(String name) {
    return '現在：$name・切替、時限編集とコピー';
  }

  @override
  String get timeSchemeEntrySubtitle => '切替、時限編集、コピーとテンプレート管理';

  @override
  String semesterOverviewCurrentWeek(int current, int total) {
    return '現在第$current週 / 全$total週';
  }

  @override
  String get semesterStartUnset => '学期開始日未設定';

  @override
  String semesterStartSet(String date) {
    return '学期開始日：$date';
  }

  @override
  String get setSemesterStartDate => '学期開始日を設定';

  @override
  String get semesterStartDateLabel => '学期開始日';

  @override
  String syncedCurrentWeekMessage(int week) {
    return '第$week週に同期済み';
  }

  @override
  String get pickSemesterWeekCountTitle => '学期週数を選択';

  @override
  String get pickSemesterWeekCountSubtitle => '学校に合わせて実際の授業週数に調整可能。';

  @override
  String weekCountItem(int count) {
    return '$count週';
  }

  @override
  String get diagnosticsLogIntro =>
      'Markdownと原文の2つの表示方式に対応。トラブルシュート時にスマホで完全なログを直接確認可能。';

  @override
  String get diagnosticsRawTab => '原文';

  @override
  String get diagnosticsStructuredTab => '構造化';

  @override
  String get diagnosticsLevelLabel => 'レベル';

  @override
  String get diagnosticsLevelAll => '全て';

  @override
  String get diagnosticsLevelError => 'エラー';

  @override
  String get diagnosticsLevelWarn => '警告';

  @override
  String get diagnosticsLevelInfo => '情報';

  @override
  String get diagnosticsLevelDebug => 'デバッグ';

  @override
  String get diagnosticsLevelVerbose => '詳細';

  @override
  String diagnosticsShowingCount(int shown, int total) {
    return '$shown / $total件のログを表示';
  }

  @override
  String get diagnosticsNoMatchingTitle => '現在のフィルターに一致するログなし';

  @override
  String get diagnosticsNoMatchingSubtitle => '「全て」に切替えるか、原文でトラブルシュートを続行。';

  @override
  String get diagnosticsLevelInferred => '推定レベル';

  @override
  String get diagnosticsRawFilteredHint =>
      '原文ビューは現在のレベルフィルターに連携し、対応するログブロックのみ表示。';

  @override
  String get diagnosticsTimeSortAscending => '昇順';

  @override
  String get diagnosticsTimeSortDescending => '降順';

  @override
  String get diagnosticsDisplayOptionsTitle => '表示と並び順';

  @override
  String get diagnosticsStreamingHint => 'リアルタイム更新中。新しいログが自動的に表示されます。';

  @override
  String get diagnosticsEmptyTitle => 'ログなし';

  @override
  String get diagnosticsEmptySubtitle => '現在表示可能なスーパーアイランド診断ログがありません。';

  @override
  String get diagnosticsLogTitleFallback => 'スーパーアイランド診断ログ';

  @override
  String get diagnosticsDeviceInfoTitle => 'デバイスとエクスポート情報';

  @override
  String get diagnosticsContentTitle => 'ログ内容';

  @override
  String get diagnosticsRecentLogsTitle => '最近のログ';

  @override
  String get diagnosticsUnknownCategory => '未分類イベント';

  @override
  String get diagnosticsExportedAt => 'エクスポート時間';

  @override
  String get diagnosticsTime => '時間';

  @override
  String get diagnosticsCategory => 'カテゴリ';

  @override
  String get diagnosticsMessage => 'メッセージ';

  @override
  String get diagnosticsStackTrace => 'スタックトレース';

  @override
  String get firstUseGuideTitle => '初回使用ガイド';

  @override
  String get guideAndPermissionsTitle => '使用ガイドと権限';

  @override
  String get refreshStatusTooltip => 'ステータス更新';

  @override
  String get guideHeroTitle => 'まずこのページを完了してから使い始めましょう';

  @override
  String get guideHeroSubtitle =>
      'まず最初の画面で認証。下にシステムバージョン対応、略称設定とインポート方法の説明があります。スクロールを続けてください。';

  @override
  String get guideChipPermissions => '権限準備';

  @override
  String get guideChipShortName => '略称設定';

  @override
  String get guideChipImport => '授業インポート';

  @override
  String guideChipReadyCount(int count) {
    return '$count/3 完了';
  }

  @override
  String get guideBottomReachedHint => '最後までスクロールしました。内容を確認して使い始められます。';

  @override
  String get guideScrollHint =>
      '下にスクロールして続行。HyperOSバージョン説明、権限リスト、略称設定とインポート方法があります。';

  @override
  String get guideRequestNotificationFirst => 'まず通知権限を申請';

  @override
  String get quickSetupTitle => '初回画面クイック設定';

  @override
  String get quickSetupSubtitle => '最も重要な5つのエントリを先に配置。下までスクロールして探す必要なし。';

  @override
  String get quickActionNotificationsTitle => '通知設定';

  @override
  String get quickActionNotificationsSubtitle => 'まず通知が送信できるか確認';

  @override
  String get quickActionIslandTitle => 'スーパーアイランド権限';

  @override
  String get quickActionIslandSubtitle => 'promoted通知を確認';

  @override
  String get quickActionAutoStartTitle => '自動起動';

  @override
  String get quickActionAutoStartSubtitle => 'バックグラウンド終了を防止';

  @override
  String get quickActionBatteryTitle => 'バッテリー制限なし';

  @override
  String get quickActionBatterySubtitle => 'リマインダー中断を防止';

  @override
  String get quickActionKeepAliveTitle => 'バックグラウンド常駐補助';

  @override
  String get quickActionKeepAliveSubtitle => 'バックグラウンド安定性を向上';

  @override
  String get guidePrivacyConsentLabel => 'Umeng関連のプライバシー説明を読み同意します';

  @override
  String get guideRequireConsentHint =>
      'まず下までスクロールして説明を読み、同意にチェックを入れてから使い始めてください。';

  @override
  String get guideContinueHint => '下にスクロールして完全なガイド内容を確認。';

  @override
  String get exitAppAction => 'アプリ終了';

  @override
  String get continueReadingAction => '閲覧を続ける';

  @override
  String get agreeAndStartAction => '同意して使い始める';

  @override
  String get startUsingAction => '使い始める';

  @override
  String get editSingleLessonTitle => '単一授業を編集';

  @override
  String get editCourseTitle => '授業を編集';

  @override
  String get addSingleLessonTitle => '単一授業を追加';

  @override
  String get addCourseTitle => '授業を追加';

  @override
  String get deleteCourseTitle => '授業を削除';

  @override
  String get courseDeleted => '授業を削除しました';

  @override
  String get addMethodTitle => '追加方法';

  @override
  String get singleLessonLabel => '単一授業';

  @override
  String get recurringLessonLabel => '繰り返し授業';

  @override
  String get singleLessonHint => '振替授業や臨時追加に最適。授業は1つの週次にのみ表示。';

  @override
  String get recurringLessonHint => '同じ時間に毎週連続する通常授業に最適。';

  @override
  String get sharedInfoTitle => '共有情報';

  @override
  String get sharedInfoHint => '共有フィールドの説明を表示';

  @override
  String get sharedInfoSheetItemCourseName =>
      '授業名：授業の一意識別子。同名の複数排課は同一授業として扱われます。名称を変更すると別授業として記録されます。';

  @override
  String get sharedInfoSheetItemShortName =>
      '授業略称：スーパーアイランド等での簡略表示に使用。手動入力が必要で、自動生成されません。「授業略称を優先表示」を有効にした場合に反映。3 文字以内を推奨。';

  @override
  String get sharedInfoSheetItemSharedSync =>
      '共有同期：略称、色、性質、概要等は同名授業の他排課へ同期されます。';

  @override
  String get reuseExistingCourseLabel => '既存授業を流用';

  @override
  String get reuseExistingCourseHelper => '既存授業を選択すると、授業名、教師とその他の共有情報が自動入力';

  @override
  String get manualInputLabel => '手動入力';

  @override
  String get noTemplateCoursesHint =>
      '現在の時間割に授業がありません。まず1つ手動で登録すると、以降の臨時追加で直接選択可能。';

  @override
  String get courseNameLabel => '授業名';

  @override
  String get courseNameHelper =>
      '授業の一意識別子。同名の複数排課は同一授業に統合されます。正式名称を入力し、表示目的での略称は避けてください。';

  @override
  String get pleaseEnterCourseName => '授業名を入力してください';

  @override
  String get courseShortNameOptional => '授業略称';

  @override
  String get courseShortNameHelper =>
      'スーパーアイランド等での簡略表示に推奨。略称は自動生成されません。「授業略称を優先表示」を有効にした場合に反映。3 文字以内を推奨。';

  @override
  String get courseShortNameAutoFillAction => '先頭2文字';

  @override
  String get teacherLabel => '担当教師';

  @override
  String get courseNatureLabel => '授業性質';

  @override
  String get courseDescriptionOptional => '授業概要（任意）';

  @override
  String get currentScheduleHint => '这里的曜日、時限、教室、週次と奇数偶数週はこの排課のみに影響。';

  @override
  String followProfileTimeScheme(String name) {
    return '現在の時間割に連携（$name）';
  }

  @override
  String get timeSchemeOverrideLabel => '授業時間方案';

  @override
  String get lessonWeeksTitle => '授業週次';

  @override
  String get singleLessonWeekHint => '単一授業は1つの週次にのみ表示。振替授業や臨時追加に最適。';

  @override
  String get rangeWeekLabel => '連続週';

  @override
  String get customWeekLabel => 'カスタム週';

  @override
  String get allWeeksLabel => '全週';

  @override
  String get oddWeeksLabel => '奇数週';

  @override
  String get evenWeeksLabel => '偶数週';

  @override
  String get allWeeksHint => '開始週から終了週まで連続で授業を配置。';

  @override
  String get oddWeeksHint => '範囲内の奇数週のみ保持。';

  @override
  String get evenWeeksHint => '範囲内の偶数週のみ保持。';

  @override
  String get customPaletteColor => 'カラーパレットでカスタム';

  @override
  String timeSchemeSetCountValue(int count) {
    return '$countセット';
  }

  @override
  String profileCountValue(int count) {
    return '$count個';
  }

  @override
  String courseSectionCountValue(int count) {
    return '$count件';
  }

  @override
  String timeSchemeStartsAt(String start) {
    return '$startから';
  }

  @override
  String get weekdayShortMonday => '月';

  @override
  String get weekdayShortTuesday => '火';

  @override
  String get weekdayShortWednesday => '水';

  @override
  String get weekdayShortThursday => '木';

  @override
  String get weekdayShortFriday => '金';

  @override
  String get weekdayShortSaturday => '土';

  @override
  String get weekdayShortSunday => '日';

  @override
  String weekdaySectionRange(String weekday, int startSection, int endSection) {
    return '$weekday曜$startSection-$endSection時限';
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
    return '$profileName・$courseName（$weekday曜$startSection-$endSection時限、$usageType）';
  }

  @override
  String weekdaySectionSummary(
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekday曜$startSection-$endSection時限';
  }

  @override
  String get timeRangeValidationNoCrossDay => '終了時間は開始時間より後である必要があります';

  @override
  String get timeSchemeNameEmptyValidation => 'テンプレート名は空にできません';

  @override
  String get liveTimeCorrectionNone => '補正なし';

  @override
  String liveTimeCorrectionDelay(int seconds) {
    return '全体を$seconds秒遅らせる';
  }

  @override
  String liveTimeCorrectionAdvance(int seconds) {
    return '全体を$seconds秒早める';
  }

  @override
  String liveClassReminderLeadSummaryImmediate(int seconds) {
    return '授業開始と同時にフォーカスリマインダー表示に移行し、終了$seconds秒前に秒単位カウントダウンに切替';
  }

  @override
  String liveClassReminderLeadSummaryKeepNormal(int minutes, int seconds) {
    return '授業後はまず通常授業中通知を保持し、終了$minutes分前にフォーカスリマインダー/終了リマインダーに切替、最後の$seconds秒で秒単位カウントダウンに切替';
  }

  @override
  String liveClassReminderLeadSummaryIsland(int minutes, int seconds) {
    return '終了$minutes分前にスーパーアイランド/フォーカスリマインダーに切替、最後の$seconds秒で秒単位カウントダウンに切替';
  }

  @override
  String liveClassReminderLeadSummaryFocused(int minutes, int seconds) {
    return '終了$minutes分前にフォーカスリマインダー表示を開始し、最後の$seconds秒で秒単位カウントダウンに切替';
  }

  @override
  String get liveSettingsEntrySubtitle => 'リマインダー時間帯、アイランド表示、通知バーと表示内容';

  @override
  String get timetableProfilesEntrySubtitle => '新規作成、切替、コピー、名前変更と削除';

  @override
  String get homeTitleSectionTitle => 'ホームタイトル';

  @override
  String get homeTitleSectionSubtitle => 'ホーム左上の時間割切替エントリのスタイルを制御。';

  @override
  String get homeTitleStyleLabel => 'タイトルスタイル';

  @override
  String get themeSeedSectionTitle => 'アプリテーマカラー';

  @override
  String get themeSeedSectionSubtitle => 'トップバー、アクセントカラーとグローバルメインカラーに影響。';

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
  String get timetableBackgroundColorSectionTitle => '時間割背景色';

  @override
  String get timetableBackgroundColorSectionSubtitle => '時間割ページの大背景にのみ作用。';

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
  String get defaultTimetablePreviewName => 'デフォルト時間割';

  @override
  String get beforeClassDisplaySettingsTitle => '授業前リマインダー表示';

  @override
  String get duringEndDisplaySettingsTitle => '授業中/終了リマインダー表示';

  @override
  String get liveDisplaySummaryShortName => '略称';

  @override
  String get liveDisplaySummaryCourseName => '授業名';

  @override
  String get liveDisplaySummaryLocation => '場所';

  @override
  String liveDisplaySummaryCountdown(String style) {
    return 'カウントダウン（$style）';
  }

  @override
  String get liveDisplaySummaryStageText => 'ステージテキスト';

  @override
  String get liveDisplaySummaryLeftLabelImage => 'アイコン';

  @override
  String get liveDisplaySummaryMinimal => '最小表示';

  @override
  String get liveDisplaySummaryCountdownShort => 'カウントダウン';

  @override
  String liveDisplaySummaryMore(String first, int count) {
    return '$firstほか$count項目';
  }

  @override
  String get guideHyperOsChip => 'HyperOS 3.0.300+';

  @override
  String get guideStatusTitle => '現在のステータス';

  @override
  String get guideStatusNotificationPermission => '通知権限';

  @override
  String get guideStatusEnabled => '有効';

  @override
  String get guideStatusDisabled => '無効';

  @override
  String get guideStatusIslandSupport => 'フォーカス通知 / スーパーアイランド';

  @override
  String get guideStatusSystemAllowed => 'システム許可済み';

  @override
  String get guideStatusEnabledPending => '有効だがシステム未確認';

  @override
  String get guideStatusSuggestedCheck => '確認推奨';

  @override
  String get guideStatusBatteryOptimization => 'バッテリー最適化';

  @override
  String get guideStatusBatteryUnrestricted => '制限なし';

  @override
  String get guideStatusBatteryRestricted => 'まだ制限あり';

  @override
  String get guideStatusKeepAlive => 'バックグラウンド常駐補助';

  @override
  String get guideStatusAndroidVersion => 'Androidバージョン';

  @override
  String get guideStatusVersionUnknown => '未認識';

  @override
  String get guideStatusIslandSystemSupport => 'スーパーアイランドシステム対応';

  @override
  String get guideStatusIslandSystemRequirement => 'HyperOS 3.0.300以上が必要';

  @override
  String get guideStatusIslandHint =>
      'スーパーアイランドを主に使用する場合、まずシステムバージョンがHyperOS 3.0.300以上であることを確認し、その後以下の権限リストを順番に完了してください。';

  @override
  String get guidePermissionChecklistTitle => '権限リスト';

  @override
  String get guidePermissionChecklistSubtitle => 'この順序で確認するのが最も効率的で、見落としが少ない。';

  @override
  String get guideChecklistRequestNotificationTitle => '通知権限を申請';

  @override
  String get guideChecklistRequestNotificationSubtitle => '全リマインダーの前提条件';

  @override
  String get guideChecklistOpenNotificationTitle => '通知設定を開く';

  @override
  String get guideChecklistOpenNotificationSubtitle =>
      '通知マスタースイッチ、ロック画面表示とリアルタイム通知権限を確認';

  @override
  String get guideChecklistOpenIslandTitle => 'フォーカス通知設定を開く';

  @override
  String get guideChecklistOpenIslandSubtitle =>
      'HyperOS 3.0.300以上でpromoted/スーパーアイランド通知を確認';

  @override
  String get guideChecklistOpenAutoStartTitle => '自動起動設定を開く';

  @override
  String get guideChecklistOpenAutoStartSubtitle => 'アプリの自動起動とバックグラウンド常駐を許可';

  @override
  String get guideChecklistOpenBatteryTitle => 'バッテリー戦略設定を開く';

  @override
  String get guideChecklistOpenBatterySubtitle => '制限なしへの変更を推奨。授業リマインダーの中断を防止。';

  @override
  String get guideChecklistOpenKeepAliveTitle => 'バックグラウンド常駐補助を開く';

  @override
  String get guideChecklistOpenKeepAliveSubtitle =>
      'スーパーアイランドとリマインダーのバックグラウンド安定性をさらに向上';

  @override
  String get guideShortNameAdviceTitle => '授業略称の提案';

  @override
  String get guideShortNameAdviceSubtitle =>
      'スーパーアイランドは授業略称の表示に対応。略称は自動生成されず、授業編集で手動入力が必要。3文字以内を推奨。表示がより安定します。';

  @override
  String get guideShortNameRecommended => '推奨例';

  @override
  String get guideShortNameNotRecommended => '非推奨';

  @override
  String get guideShortNameRecommendedExample => '高数 / 確率 / 数控';

  @override
  String get guideShortNameNotRecommendedExample => '高等数学A(1) / 数控技術及應用';

  @override
  String get guideSetCourseShortNameAction => '授業略称を設定';

  @override
  String get guideImportMethodsTitle => '時間割インポート方法';

  @override
  String get guideImportMethodsSubtitle =>
      '現在のバージョンは一部学校の教務システムWebログインインポートに対応。未対応の学校でも他の移行方法があります。';

  @override
  String get guideImportMethodStep1 =>
      'まず「授業インポート > 教務システムインポート」から学校とアダプタを選択し、アプリ内で教務Webページを開いてインポート完了。';

  @override
  String get guideImportMethodStep2 =>
      'お使いの学校がまだ未対応の場合、WakeUpなどの時間割アプリで授業をインポートし、カレンダー形式でエクスポートしてから本アプリでインポート。';

  @override
  String get guideImportMethodStep3 =>
      '他のユーザーが本アプリを使用している場合、完全バックアップファイルをエクスポートしてもらい、直接インポートで授業と設定を復元。';

  @override
  String get guideImportMethodExtra =>
      'パケットキャプチャ、Webデバッグ、JavaScriptができる場合は、学校教務適応の補充に参加して、より多くの学校が直接インポートできるように歓迎。';

  @override
  String get guideFinalTipsTitle => '最後にこの3点を確認';

  @override
  String get guideFinalTip1 =>
      '1. HyperOS 3.0.300以上でスーパーアイランドに対応。システムバージョンが不足していても、アプリは通常のリマインダーを送信可能。';

  @override
  String get guideFinalTip2 =>
      '2. まず設定ページで「授業前ポップアップ」と「授業中/終了間近リマインダー」のしきい値を調整。';

  @override
  String get guideFinalTip3 =>
      '3. システム権限設定完了後、テスト通知で検証。アイランド表示がたまに消える場合は、自動起動と省電力戦略を優先確認。';

  @override
  String get guidePrivacyHelperRequireConsent =>
      '同意にチェックを入れると、上記のUmeng関連説明、プライバシー内容と免責事項を読み同意したものとみなされます。';

  @override
  String get guidePrivacyHelperViewOnly =>
      'ここでは初回起動時と同じプライバシー、サードパーティSDKと免責事項を保持。いつでも確認可能。現在のページで再度同意する必要はありません。';

  @override
  String get guidePrivacySectionTitle => 'プライバシー、サードパーティSDKと免責事項';

  @override
  String get guidePrivacyParagraph1 =>
      '本アプリの主要機能はローカル実行方式で設計。時間割、テンプレート、授業記録とほとんどの設定はデフォルトでデバイスのローカルに保存。';

  @override
  String get guidePrivacyParagraph2 =>
      'ユーザーが能動的に更新確認、ダウンロード、インポート/エクスポートなどのネットワーク機能を使用するか、同意後にUmeng SDKを初期化した場合のみ、外部サービスとデータ通信が発生。';

  @override
  String get guidePrivacyParagraph3 =>
      '本アプリはUmeng Mobile Statistics SDK、Umeng APM SDK、および高度な运营分析依存ライブラリを導入。サービス用途はモバイル統計分析、アプリ性能監視と高度な运营分析関連機能。同意後にのみこれらのSDKが正式に初期化。';

  @override
  String get guidePrivacyParagraph4 =>
      'Umeng公式説明によると、これらのSDKが処理する可能性のある情報には：デバイス情報（IMEI、MAC、Android ID、OAID、IDFA、OpenUDID、GUID、SIM IMSI等）、ネットワーク状態、デバイス識別子、および高度な运营分析依存ライブラリのアプリリストと位置情報が含まれる。';

  @override
  String get guideRiskTitle => '免責とリスクに関する注意';

  @override
  String get guideRiskParagraph1 =>
      '1. スーパーアイランド、フォーカス通知、バックグラウンドリマインダーと常駐効果はシステムバージョン、機種、メーカー戦略、権限、自動起動、バッテリー戦略などの外部条件に依存。全デバイスで完全に同じ動作を保証できない。';

  @override
  String get guideRiskParagraph2 =>
      '2. 更新確認、ミラーダウンロード、システムダウンローダー、インポート/エクスポートと共有はネットワーク環境、サードパーティサービスとシステムファイル機能に依存。失敗、速度制限またはファイル異常の場合は、Releaseページ、バックアップファイルとシステム表示を参照。';

  @override
  String get guideRiskParagraph3 =>
      '3. 移行、インポートまたはデータ上書き前に、バックアップファイルが完全に使用可能であることを自行確認し、時間割情報を含むファイルを適切に保管。ユーザーの自行削除、上書き、共有または保管不備によるデータ問題は、ユーザーが自行でリスクを負担。';

  @override
  String get guideUmengPrivacyLink =>
      'Umengプライバシーポリシー：https://www.umeng.com/page/policy';

  @override
  String get liveDiagnosticsUnavailable => '現在表示可能なスーパーアイランド診断ログがありません';

  @override
  String get liveDiagnosticsViewerTitle => 'スーパーアイランド診断ログ';

  @override
  String get liveDiagnosticsShareText =>
      '軽屿時間割がエクスポートしたスーパーアイランド診断ログです。「スーパーアイランドが表示されない」などの問題のトラブルシュートに使用可能。';

  @override
  String get liveDiagnosticsShareSubject => '軽屿時間割 - スーパーアイランド診断ログ';

  @override
  String get liveDiagnosticsSnapshotShareText =>
      '軽屿時間割の現在のテスト診断ページがエクスポートしたスーパーアイランドステータススナップショットです。「スーパーアイランドが表示されない」などの問題のトラブルシュートに使用可能。';

  @override
  String get liveDiagnosticsSnapshotShareSubject =>
      '軽屿時間割 - スーパーアイランドステータススナップショット';

  @override
  String get liveDiagnosticsNothingToExport =>
      '現在エクスポート可能なログファイルもステータススナップショットもありません';

  @override
  String get liveDiagnosticsCleared => 'スーパーアイランド診断ログをクリアしました。以降再び収集を開始';

  @override
  String get liveDiagnosticsClearFailed => 'スーパーアイランド診断ログのクリアに失敗';

  @override
  String get liveTestingNotRefreshed => '未更新';

  @override
  String get liveTestingTitle => 'テストと診断';

  @override
  String get liveTestingNotificationTitle => 'テスト通知';

  @override
  String get liveTestingNotificationSubtitle =>
      'スーパーアイランド、通知バーと授業略称などの表示効果を検証。';

  @override
  String get liveTestingSendAction => 'テスト通知を送信';

  @override
  String get liveTestingUmengHint =>
      '以下の2つのボタンはテスト版のみ表示。Umeng U-APMクラッシュとフリーズ上报の検証用。';

  @override
  String get liveTestingCrashAction => 'クラッシュテスト';

  @override
  String get liveTestingAnrAction => '異常フリーズテスト';

  @override
  String get liveTestingIslandStatusTitle => 'アイランドステータス診断';

  @override
  String get liveTestingIslandStatusSubtitle =>
      'ネイティブリアルタイムサービス、通知構築結果と非アイランド理由を直接表示。';

  @override
  String get liveTestingServiceStatusRunning => 'サービス実行中';

  @override
  String get liveTestingServiceStatusStopped => 'サービス未実行';

  @override
  String get liveTestingNoIslandReasonTitle => '非アイランド理由';

  @override
  String get liveTestingNoIslandReasonEmpty => '現在ブロック理由なし';

  @override
  String get liveTestingRefreshAction => '診断を更新';

  @override
  String get liveTestingRefreshing => '更新中';

  @override
  String get liveTestingExportAction => 'ログをエクスポートして共有';

  @override
  String get liveTestingExporting => 'エクスポート中';

  @override
  String get liveTestingAutoRefreshTitle => '自動更新';

  @override
  String liveTestingAutoRefreshOn(int seconds) {
    return '$seconds秒ごとに診断ステータスを自動取得';
  }

  @override
  String get liveTestingAutoRefreshOff => 'オフにすると手動更新時のみ更新。現在のステータスを安定して確認可能。';

  @override
  String liveTestingRefreshedAt(String time) {
    return '前回更新：$time';
  }

  @override
  String get liveTestingSectionEnvironment => '環境と権限';

  @override
  String get liveTestingSectionService => 'サービスステータス';

  @override
  String get liveTestingSectionCourse => '授業データ';

  @override
  String get liveTestingSectionTiming => '時間とステージ';

  @override
  String get liveTestingSectionSwitches => 'ステージ切替';

  @override
  String get liveTestingSectionDisplay => 'アイランド表示設定';

  @override
  String get liveTestingSectionNotification => '通知判定結果';

  @override
  String get liveTestingSectionRecentLogs => '最近の診断ログ';

  @override
  String get liveTestingRawDataTitle => '生のデバッグデータ';

  @override
  String get liveTestingRawDataSubtitle =>
      'デフォルト折りたたみ。トラブルシュート時に展開して完全なネイティブフィールドを確認。';

  @override
  String get liveTestingExpandRawJson => '生のJSONを展開';

  @override
  String get liveTestingExpandRawJsonSubtitle => '大量の生フィールドがページを占拠するのを防止';

  @override
  String get liveTestingLocalLogsTitle => 'ローカル診断ログ';

  @override
  String get liveTestingLocalLogsSubtitle =>
      'ワンクリックでログファイルをエクスポートし、システム共有で開発者に送信。クリア後に再収集も可能。';

  @override
  String get liveTestingClearLogsAction => 'ログをクリア';

  @override
  String get liveTestingClearingLogs => 'クリア中';

  @override
  String get liveTestingViewPhoneLogsAction => 'スマホのログを確認';

  @override
  String get liveTestingMoreTesterOptionsAction => 'その他のテスターオプション';

  @override
  String get yesLabel => 'はい';

  @override
  String get noLabel => 'いいえ';

  @override
  String get liveTestingCurrentNativeFieldsSubtitle => '現在のネイティブ診断フィールドを表示。';

  @override
  String get liveTestingCrashSoon =>
      'Umeng U-APMテストクラッシュをトリガーします。アプリを再起動してバックグラウンドで上报を受信したか確認してください。';

  @override
  String get liveTestingAnrSoon =>
      '約30秒のメインスレッドフリーズをトリガーします。flutter runから離れてテストし、フリーズ後にアプリを再起動してUmengバックグラウンドを確認。';

  @override
  String get liveTestingNoCourseAvailable => '現在テスト可能な授業がありません';

  @override
  String get liveTestingTestCourseNote => 'ここにメモを表示。授業編集ページで設定可能。';

  @override
  String get liveTestingNotificationSent =>
      '授業リマインダーテスト通知を送信しました。約8秒以内に授業前リマインダーステージに移行';

  @override
  String sendFailedWithError(String error) {
    return '送信失敗：$error';
  }

  @override
  String get homeWidgetSettingsTitle => 'ホームウィジェット';

  @override
  String get homeWidgetTodayCourseTitle => '今日の授業ウィジェット';

  @override
  String get homeWidgetTodayCourseSubtitle =>
      '2×2、2×4、4×4の3サイズに対応。ウィジェットをタップでホームを開き、授業開始/終了時に自動更新。';

  @override
  String get homeWidgetQuickAddTitle => 'ホームにクイック追加';

  @override
  String get homeWidgetCheckingPinSupport => '現在のホームがアプリ内ウィジェット追加に対応しているか確認中…';

  @override
  String get homeWidgetPinSupported =>
      '対応している場合、システム追加確認が直接ポップアップ。個別の権限ポップアップではない。確認後にホームに固定可能。';

  @override
  String get homeWidgetPinUnsupported =>
      '現在のホームがアプリ内直接追加に未対応の場合、ホームを長押し → ウィジェット → 轻屿時間割で手動追加可能。';

  @override
  String get homeWidgetBackgroundStyleLabel => '背景スタイル';

  @override
  String get homeWidgetShowLocationTitle => '場所を表示';

  @override
  String get homeWidgetShowLocationSubtitle =>
      'オフにすると、ウィジェットのサブ情報は週次と授業数を優先表示。';

  @override
  String get homeWidgetShowCountdownTitle => 'カウントダウンを表示';

  @override
  String get homeWidgetShowCountdownSubtitle =>
      '更新スイッチを保持。次回の授業と授業中の残り時間表示に使用。';

  @override
  String get homeWidgetCountdownLeadTitle => 'カウントダウン先行量';

  @override
  String get homeWidgetCountdownLeadSubtitle => '授業前に何分でカウントダウンモードに切替るかを設定。';

  @override
  String get homeWidgetCountdownLeadAlways => '常に表示';

  @override
  String homeWidgetCountdownLeadMinutes(String minutes) {
    return '授業前$minutes分';
  }

  @override
  String get widgetCountdownStyleTitle => 'カウントダウンスタイル';

  @override
  String get homeWidgetHideCompletedTitle => '完了済み授業を非表示';

  @override
  String get homeWidgetHideCompletedSubtitle =>
      'オンにすると、2×2、2×4、4×4の授業リストは終了前の授業のみ表示。';

  @override
  String get homeWidgetShowTomorrowTitle => '授業後に明日の授業を表示';

  @override
  String get homeWidgetShowTomorrowSubtitle =>
      'オンにすると、今日の授業が全て終了時にウィジェットが自動的に明日の授業に切替。';

  @override
  String get homeWidgetHeightAdjustTitle => 'カード高さ微調整';

  @override
  String get defaultLabel => 'デフォルト';

  @override
  String higherByValue(String value) {
    return '高く$value';
  }

  @override
  String lowerByValue(String value) {
    return '低く$value';
  }

  @override
  String get homeWidgetCornerRadiusTitle => 'カード角丸';

  @override
  String get homeWidgetDescriptionTitle => '説明';

  @override
  String get homeWidgetDescriptionText =>
      'ウィジェットは現在今日の授業を優先表示。授業なし状態は完全なカードを維持し、空白にならない。時間割切替やスタイル変更時、デスクトップコンポーネントも連動して更新。';

  @override
  String homeWidgetPinRequested(String label) {
    return '「$label」の追加リクエストを送信しました。システムポップアップで確認してホームに配置してください。';
  }

  @override
  String homeWidgetPinUnsupportedManual(String label) {
    return '現在のシステムホームがアプリ内直接ウィジェット追加に未対応。ホームを長押し → ウィジェット → 轻屿時間割で「$label」を手動追加。';
  }

  @override
  String get homeWidgetInvalidType => 'ウィジェットタイプが無効。後でもう一度お試しください。';

  @override
  String homeWidgetPinFailedManual(String label) {
    return '追加リクエスト失敗。ホームを長押し → ウィジェット → 轻屿時間割で「$label」を手動追加。';
  }

  @override
  String get layoutSettingsTitle => 'レイアウトと時限';

  @override
  String get layoutDensityTitle => '時間割密度';

  @override
  String get layoutAutoFitHeightTitle => '画面高さに自動フィット';

  @override
  String get layoutAutoFitHeightSubtitle =>
      'オンにすると現在の時限数に応じてページ下部まで自動フィット。下部の余白を保持しない。';

  @override
  String get layoutHideWeekendsTitle => '土日を非表示';

  @override
  String get layoutHideWeekendsSubtitle => 'オンにすると月〜金のみ表示。残りの列幅は自動フィット。';

  @override
  String get layoutEnableHapticsTitle => 'アプリ内バイブレーションを有効化';

  @override
  String get layoutEnableHapticsSubtitle =>
      'オフにするとページ切替などの操作で軽いバイブレーションが発生しなくなる。';

  @override
  String pageTransitionSpeedLabel(String speed) {
    return 'ページ遷移速度 $speed×';
  }

  @override
  String get pageTransitionSpeedTitle => '页面转场速度';

  @override
  String get pageTransitionSpeedSubtitle =>
      'サブページのスライドアニメーションの速さを調整します。数値が大きいほど速く、小さいほど遅くなります。Android のシステム「遷移アニメーションのスケール」と掛け合わされます。';

  @override
  String pageTransitionSpeedDurationHint(int milliseconds) {
    return '約 $milliseconds ミリ秒';
  }

  @override
  String get layoutTimeColumnDisplayLabel => 'ホーム時間列表示';

  @override
  String get layoutTimeColumnWidthLabel => '時間列幅';

  @override
  String get layoutBackToCurrentWeekButtonStyleLabel => '「今週に戻る」ボタンスタイル';

  @override
  String get layoutBackToCurrentWeekButtonStyleHelper =>
      'デフォルトは現在のインラインスタイルを維持。週表示右下の小型フローティングボタンにも変更可能。';

  @override
  String get layoutBackToCurrentWeekButtonStyleInline => '時間列インライン';

  @override
  String get layoutBackToCurrentWeekButtonStyleFloating => '右下フローティング';

  @override
  String layoutBackToCurrentWeekButtonOpacityLabel(int value) {
    return 'フローティングボタン不透明度$value%';
  }

  @override
  String get layoutBackToCurrentWeekButtonOpacityTitle => '悬浮按钮不透明度';

  @override
  String get layoutBackToCurrentWeekButtonOpacitySubtitle =>
      '右下フローティングスタイルにのみ有効。';

  @override
  String layoutCourseCardGapLabel(String value) {
    return '授業カード間隔$value';
  }

  @override
  String get layoutCourseCardGapTitle => '课程卡片间距';

  @override
  String layoutSectionHeightLabel(String value) {
    return '時間割行高さ$value';
  }

  @override
  String get layoutSectionHeightTitle => '课表行高';

  @override
  String layoutCompactFontSizeLabel(String value) {
    return 'コンパクトフォントサイズ$value';
  }

  @override
  String get layoutCompactFontSizeTitle => '紧凑字号';

  @override
  String layoutCourseCardFontSizeLabel(String value) {
    return '授業カードフォントサイズ$value';
  }

  @override
  String get layoutCourseCardFontSizeTitle => '课程卡片字号';

  @override
  String get layoutCourseCardDisplayTitle => '授業カード表示';

  @override
  String get layoutCourseCardDisplaySubtitle =>
      'デフォルトで授業名、教師と教室を表示。他の情報は時間割ごとに自由に切替可能。';

  @override
  String get layoutShowTeacherTitle => '教師を表示';

  @override
  String get layoutShowClassroomTitle => '教室を表示';

  @override
  String get layoutShowTimeTitle => '時間を表示';

  @override
  String get layoutShowTimeLabelsTitle => '授業開始/終了テキストを表示';

  @override
  String get layoutShowTimeLabelsSubtitle =>
      'オフにすると時間ポイントのみ表示。「授業開始」「授業終了」テキストは非表示。';

  @override
  String get layoutShowWeeksTitle => '週数を表示';

  @override
  String get layoutShowWeeksSubtitle => '例：第1-16週、奇数偶数週';

  @override
  String get layoutShowDescriptionTitle => '授業概要を表示';

  @override
  String get layoutShowDescriptionSubtitle => 'デフォルトオフ。スペース不足時に最初に圧縮される。';

  @override
  String get layoutShowOtherWeeksTitle => '非今週の授業を表示';

  @override
  String get layoutShowOtherWeeksSubtitle =>
      'デフォルトオフ。オンにすると現在週にない授業をグレー半透明で表示。';

  @override
  String get layoutVerticalAlignLabel => '垂直レイアウト';

  @override
  String get layoutHorizontalAlignLabel => '水平レイアウト';

  @override
  String get layoutShowConflictBadgeTitle => 'ホームに競合カプセルを表示';

  @override
  String get layoutShowConflictBadgeSubtitle =>
      'オフにすると、ホームの時間割で競合授業に「競合」カプセルを表示しない。';

  @override
  String layoutConflictOpacityLabel(int value) {
    return '競合授業透明度$value%';
  }

  @override
  String get layoutConflictOpacitySubtitle =>
      '競合授業は自動的に重ね表示。透明度を下げると複数の授業を同時に確認可能。';

  @override
  String get layoutTipsText =>
      'テンプレートは設定ホームに移動済み。ここでは主に時間割の行高さ、時間列、週末表示と授業カードレイアウトを調整。現在の時間割の時間のみ変更する場合、まずテンプレートでコピーしてから適用。';

  @override
  String currentWeekCompact(int week) {
    return '$week週';
  }

  @override
  String get sampleCourseNumericalControl => '数控';

  @override
  String get sampleCourseAdvancedMath => '高数';

  @override
  String get sampleTeacherZhang => '張先生';

  @override
  String get sampleCourseEnglish => '英語';

  @override
  String get sampleTeacherLi => '李先生';

  @override
  String get aboutRepositorySheetTitle => 'オープンソースリポジトリ';

  @override
  String get aboutRepositorySheetHint =>
      '学校の教務インポート適応を補充したい場合、教務適応倉庫qingyu_warehouseも確認推奨。';

  @override
  String get aboutOpenGitHubAction => 'GitHubを開く';

  @override
  String get aboutOpenWarehouseRepoAction => '教務適応倉庫を開く';

  @override
  String get copiedRepositoryAddress => 'リポジトリアドレスをコピーしました';

  @override
  String get copiedWarehouseRepositoryAddress => '教務適応倉庫アドレスをコピーしました';

  @override
  String get aboutUpdateScreenTitle => 'バージョン更新';

  @override
  String get aboutUpdateStatusTitle => '更新ステータス';

  @override
  String get aboutRefreshCheckTooltip => '再確認';

  @override
  String get aboutCheckingLatestVersion => '最新バージョン情報を確認中…';

  @override
  String get aboutCheckingForUpdate => '更新を確認中…';

  @override
  String get aboutReadVersionFailed => 'バージョン情報を一時的に読み込めません。後でもう一度お試しください。';

  @override
  String get aboutReadVersionFailedHint =>
      '現在のネットワークでGitHubへのアクセスが不安定な場合、後でもう一度お試しいただくか、下の国内ダウンロード方式に切替えてから再試行。';

  @override
  String get aboutViewReleaseAction => 'Releaseを確認';

  @override
  String get aboutDownloadNowAction => '今すぐダウンロード';

  @override
  String get aboutOpenDownloadPageAction => 'ダウンロードページを開く';

  @override
  String get aboutCurrentVersionLabel => '現在のバージョン';

  @override
  String get aboutLatestVersionLabel => '最新バージョン';

  @override
  String get aboutUnreleasedLabel => '未リリース';

  @override
  String get aboutVersionChannelLabel => 'バージョンチャネル';

  @override
  String get aboutPrereleaseChannel => 'テスト版';

  @override
  String get aboutUpdateAvailableHint =>
      '下の「今すぐダウンロード」をタップするだけ。速度テスト、ミラーとテスト版は後方の高度なオプションに収納済み。';

  @override
  String get aboutUpdateNoUpdateHint =>
      '現在のバージョンは正常に使用可能。テスト版を体験する場合は、後方の高度なオプションでテスト版検出をオンに。';

  @override
  String aboutUpdatedAt(String time) {
    return '更新時間：$time';
  }

  @override
  String get aboutUpdateNowTitle => '今すぐ更新';

  @override
  String get aboutUpdateNowAndroidSubtitle =>
      '通常使用は一度「今すぐダウンロード」をタップするだけ。ダウンロード遅い、失敗、回線変更時は下の高度なオプションへ。';

  @override
  String get aboutUpdateNowOtherSubtitle =>
      '現在のプラットフォームはダウンロードページを直接開き、アプリ内ではインストールしない。';

  @override
  String get aboutMirrorDownloadHint =>
      '現在国内ダウンロードを優先。ほとんどの国内ネットワークでは「今すぐダウンロード」をタップするだけ。';

  @override
  String get aboutOriginalDownloadHint =>
      '現在国際ソースダウンロードを優先。ダウンロードが遅いまたは開けない場合、まず「国内ダウンロード」に切替推奨。';

  @override
  String get aboutUseSystemDownloaderAction => 'システムダウンローダーでダウンロード';

  @override
  String get aboutOpenReleasePageAction => 'Releaseページを開く';

  @override
  String get aboutDownloadMethodTitle => 'ダウンロード方式';

  @override
  String get aboutDownloadMethodSubtitle =>
      'デフォルトで国内ダウンロードを推奨。GitHubに安定アクセスできる場合のみ国際ソースに切替。';

  @override
  String get aboutDownloadMethodMirror => '国内ダウンロード';

  @override
  String get aboutDownloadMethodOriginal => '国際ソースダウンロード';

  @override
  String aboutMirrorModeHintRecommended(String current, String recommended) {
    return '現在国内ダウンロード使用中・$current。最近の速度テストで「$recommended」が推奨。必要時に後方の高度なオプションで切替可能。';
  }

  @override
  String aboutMirrorModeHintCurrent(String current) {
    return '現在国内ダウンロード使用中・$current。ダウンロードが遅いまたは失敗した場合、後方の高度なオプションで速度テスト、回線変更またはカスタムアドレス入力。';
  }

  @override
  String get aboutOriginalModeHint =>
      '現在国際ソースダウンロード使用中。GitHubに安定アクセスできる場合のみこの設定を推奨。それ以外は国内ダウンロードに切替。';

  @override
  String get aboutReleaseNotesTitle => '今回の更新内容';

  @override
  String get aboutReleaseNotesSubtitle => '現在検出されたバージョンのRelease説明を表示。';

  @override
  String get aboutAdvancedOptionsTitle => '高度なオプション';

  @override
  String get aboutAdvancedOptionsSubtitle => 'ダウンロード遅い、手動で回線切替、テスト版検出時にのみ展開。';

  @override
  String get aboutMirrorSectionTitle => 'ダウンロード回線とミラー';

  @override
  String get aboutMirrorSectionMirrorHint =>
      '現在国内ダウンロード使用中。ここで手動で回線切替、速度テスト推奨、またはカスタムダウンロードアドレス入力可能。';

  @override
  String get aboutMirrorSectionOriginalHint =>
      '現在国際ソースダウンロード使用中。下の回線設定は「国内ダウンロード」に切替後にのみ有効。';

  @override
  String get aboutFillCustomMirrorFirst => 'まずカスタムダウンロードアドレスを入力';

  @override
  String get aboutCurrentCustomMirrorTitle => '現在のカスタムダウンロードアドレス';

  @override
  String get aboutCurrentMirrorTitle => '現在のダウンロード回線アドレス';

  @override
  String get aboutCurrentCustomMirrorHint => '現在手動で入力したダウンロードアドレスを使用中。';

  @override
  String get aboutCurrentMirrorHint =>
      '現在の回線がアクセス失敗した場合、他の組み込み回線に切替るか、カスタムアドレスに変更可能。';

  @override
  String get aboutProbeMirrorsAction => '速度テストと推奨';

  @override
  String get aboutProbingMirrors => '速度テスト中…';

  @override
  String get aboutEditCustomMirrorAction => 'カスタムアドレスを変更';

  @override
  String get aboutSetCustomMirrorAction => 'カスタムアドレスを入力';

  @override
  String aboutSwitchToRecommendedAction(String label) {
    return '推奨に切替：$label';
  }

  @override
  String get aboutMirrorDisabledHint =>
      '現在国内ダウンロード未使用のため、ここでの回線設定は一時的に無効。必要であれば、上の「ダウンロード方式」で国内ダウンロードに切替。';

  @override
  String get aboutRecentProbeResultsTitle => '最近の速度テスト結果';

  @override
  String get aboutUnavailable => '利用不可';

  @override
  String get aboutRecommended => '推奨';

  @override
  String get aboutCheckPrereleaseTitle => 'テスト版を検出';

  @override
  String get aboutCheckPrereleaseSubtitle => 'オンにするとテスト版も更新確認に含む。通常使用はオフ推奨。';

  @override
  String get aboutDiagnosticsTitle => 'テストと診断';

  @override
  String get aboutDiagnosticsSubtitle =>
      '「スーパーアイランドが表示されない」または開発者へのフィードバックが必要な場合のみ展開。';

  @override
  String get aboutRecordDiagnosticsTitle => 'アプリログを記録';

  @override
  String get aboutRecordDiagnosticsSubtitle =>
      'オンにするとローカルで重要ログを継続記録。「表示されるべきものが表示されない」問題のトラブルシュート専用。';

  @override
  String get aboutExportDiagnosticsAction => 'アプリログをエクスポート';

  @override
  String get aboutViewPhoneLogsAction => 'ログページを開く';

  @override
  String get aboutClearAndRecollectAction => 'クリアして再収集';

  @override
  String get aboutLiveDiagnosticsEnabled => 'スーパーアイランド診断ログを有効化済み';

  @override
  String get aboutLiveDiagnosticsDisabled => 'スーパーアイランド診断ログを無効化済み';

  @override
  String get aboutNoDiagnosticsExportYet => 'エクスポート可能なスーパーアイランド診断ログがまだありません';

  @override
  String get aboutProbeNoMirrorFound => '速度テスト完了。利用可能なミラー回線が見つかりません';

  @override
  String aboutProbeCurrentFastest(String label) {
    return '速度テスト完了。現在の回線「$label」が最速の利用可能回線';
  }

  @override
  String aboutProbeRecommendSwitch(String label) {
    return '速度テスト完了。「$label」への切替を推奨';
  }

  @override
  String get switchAction => '切替';

  @override
  String aboutSwitchToMirrorAfterError(String error) {
    return '$error。国内ミラーに切替えて再試行可能';
  }

  @override
  String aboutSwitchPresetAfterError(String error, String label) {
    return '$error。「$label」への切替を推奨';
  }

  @override
  String get aboutSetMirrorSourceTitle => 'ミラーソース設定';

  @override
  String get aboutMirrorPrefixLabel => 'ミラープレフィックス';

  @override
  String get aboutMirrorPrefixInvalid =>
      'ミラーソースの形式が正しくありません。完全なhttpまたはhttpsアドレスを入力';

  @override
  String get aboutMirrorSaved => 'ミラーソースを保存しました';

  @override
  String get aboutDownloadCancelled => 'ダウンロードをキャンセルしました';

  @override
  String get aboutInstallReady =>
      'インストールパッケージ準備完了。インストール画面を開こうとしました。システムが表示しない場合、通知またはファイルマネージャーから手動インストール';

  @override
  String get aboutUpdatePackageTitle => '軽屿時間割更新パッケージ';

  @override
  String get aboutUpdatePackageDescription =>
      'システムダウンロードマネージャーに渡してダウンロード。完了後、システム通知から直接インストール可能。';

  @override
  String get aboutSystemDownloaderQueued =>
      'システムダウンロードマネージャーに渡しました。システム通知またはダウンロードリストで進捗を確認';

  @override
  String get aboutSystemDownloaderFailed => 'システムダウンロードマネージャーの呼び出しに失敗';

  @override
  String get aboutDownloadCancelling => 'ダウンロードをキャンセル中…';

  @override
  String aboutDownloadingBytes(String value) {
    return '更新をダウンロード中 $value';
  }

  @override
  String aboutDownloadingPercent(String value) {
    return '更新をダウンロード中 $value%';
  }

  @override
  String get aboutMirrorUnknownSizeHint =>
      'ミラーソースがファイル総サイズを返さないため、ダウンロード済みサイズを先に表示';

  @override
  String get aboutCancelDownloadAction => 'ダウンロードをキャンセル';

  @override
  String get aboutContributorsScreenTitle => 'コード貢献者';

  @override
  String get aboutDevelopersTitle => '開発者';

  @override
  String get aboutDeveloperMaintainerSubtitle => '軽屿時間割の開発とメンテナンス';

  @override
  String get aboutWarehouseMaintainersTitle => '教務インポート適応者';

  @override
  String get aboutWarehouseMaintainersIntro =>
      '以下のリストはqingyu_warehouse適応倉庫のmaintainerフィールドからの集計。ローカルキャッシュがある場合はキャッシュを先に表示し、バックグラウンドで更新。';

  @override
  String aboutWarehouseMaintainersLoadFailed(String error) {
    return '適応者リストを一時的に読み込めません：$error';
  }

  @override
  String get aboutWarehouseMaintainersEmpty => '現在適応者情報を読み取れていません。';

  @override
  String aboutWarehouseMaintainerCount(int count) {
    return '$count件の適応項目';
  }

  @override
  String get aboutParticipateWarehouseTitle => '教務適応に参加';

  @override
  String get aboutParticipateWarehouseSubtitle =>
      'パケットキャプチャ、Webデバッグ、JavaScriptができる場合、または自分の学校の教務システムを長期メンテナンスしたい場合は、qingyu_warehouseで新しい学校適応と修正の提出歓迎。';

  @override
  String get importFileReadFailed => '選択したファイルを読み込めません';

  @override
  String get importReplaceExistingTitle => '授業インポート';

  @override
  String importReplaceExistingMessage(String name) {
    return '$nameをインポートする際、既存の授業を置換しますか？';
  }

  @override
  String get importNoCoursesRecognized => 'インポート可能な授業が認識されませんでした';

  @override
  String get importConfirmSemesterMappingTitle => '学期開始日と週次対応を確認';

  @override
  String get importConfirmSemesterMappingSubtitleIcs =>
      '学校の校暦の学期開始日を選択。ファイル内の最も早い授業日からデフォルトの週次対応を提案済み。手動調整も可能。';

  @override
  String importOverwriteCount(int count) {
    return '$count件の授業を上書きインポート済み';
  }

  @override
  String importUpdatedCount(int count) {
    return '時間割更新済み：$count件の授業を新規追加または更新';
  }

  @override
  String get importNoCourseChanges => '新規追加または更新が必要な授業なし';

  @override
  String get aiImportTitle => '画像認識インポート';

  @override
  String aiPreviewSummary(
    int courseCount,
    int sectionCount,
    String warningSuffix,
  ) {
    return '$courseCount科目を認識。最大第$sectionCount時限$warningSuffix';
  }

  @override
  String aiWarningCountSuffix(int count) {
    return '、$count件の注意事項';
  }

  @override
  String get aiWorkflowCompactTitle => 'プロンプトコピー → Doubao画像認識 → インポート';

  @override
  String get aiWorkflowCompactSubtitle => 'Doubaoエキスパートモード → JSONコピー → 学期開始日選択';

  @override
  String get aiWorkflowTitle => 'プロンプトコピー → Doubao画像認識 → JSON貼付 → インポート';

  @override
  String get aiWorkflowSubtitle =>
      'まずプロンプトをコピーし、Doubaoの左下でエキスパートモードに切替、時間割のスクリーンショットとプロンプトを一緒に送信。返されたJSONをここにコピーし、インポート後に学期開始日を選択。';

  @override
  String get aiPromptShortAction => 'プロンプト';

  @override
  String get aiExpertModeSuggestion =>
      'Doubaoエキスパートモードを推奨。複数画像対応。スクリーンショットには曜日ヘッダーが必要。';

  @override
  String get aiHintExpertMode => 'まずDoubaoエキスパートモードに切替';

  @override
  String get aiHintSendScreenshot => 'スクリーンショットとプロンプトを一緒に送信';

  @override
  String get aiHintCopyJsonBack => '返されたJSONをコピー';

  @override
  String get aiHintPickSemesterAfterImport => 'インポート後に学期開始日を選択';

  @override
  String get jsonLabelShort => 'JSON';

  @override
  String get aiPasteJsonTitle => 'AIが返したJSONを貼付';

  @override
  String aiCourseCountChip(int count) {
    return '$count科目';
  }

  @override
  String get aiParseFailedChip => '解析失敗';

  @override
  String get aiPasteJsonHintShort => 'AIが返したJSONを貼付';

  @override
  String get aiPasteJsonHintLong =>
      'Doubaoが返したJSONをそのままここに貼付し、インポートをタップ。純JSONと```jsonコードブロックの両方に対応。';

  @override
  String get detailAction => '詳細';

  @override
  String get aiParseErrorTitle => '解析エラー';

  @override
  String get viewDetailsAction => '詳細を確認';

  @override
  String get aiWorkflowFooter =>
      'プロンプトコピー → Doubaoでスクリーンショットとプロンプト送信 → JSONをここに貼付 → インポートタップ → 学期開始日選択。';

  @override
  String get previewAction => 'プレビュー';

  @override
  String get confirmImportAction => 'インポート確認';

  @override
  String get promptCopiedHint => 'プロンプトをコピーしました。Doubaoでスクリーンショットとプロンプトを送信';

  @override
  String get clipboardNoText => 'クリップボードに利用可能なテキストがありません';

  @override
  String get aiPromptSheetTitle => '画像認識プロンプト';

  @override
  String get aiPromptSheetSubtitle =>
      'Doubaoの使用を推奨。まずDoubaoの左下でエキスパートモードに切替、下のプロンプト全体と時間割のスクリーンショットを一緒に送信してJSONのみを返すよう依頼。生成後、JSONをこのページにコピーし、インポート後に学期開始日を選択。';

  @override
  String get aiPreviewTitle => '解析プレビュー';

  @override
  String get aiPasteJsonFirst => 'まずAIが返したJSONを貼付してください';

  @override
  String get aiParseFailedIncompleteJson => '解析失敗。完全なJSONが貼付されているか確認';

  @override
  String get importAiResultTitle => 'AI解析結果をインポート';

  @override
  String get importAiReplaceMessage => '現在のAI解析結果で既存の授業を置換しますか？';

  @override
  String get importConfirmSemesterMappingSubtitleAi =>
      '学校の校暦の学期開始日を選択し、時間割の第1週が校暦の第何週に対応するかを確認。学校の第1週に授業がない場合、通常第2週に変更。';

  @override
  String aiWarningExtraSuffix(int count) {
    return '、さらに$count件の認識注意事項';
  }

  @override
  String get pasteAction => '貼付';

  @override
  String get importConfirmSemesterMappingSubtitleWarehouse =>
      '教務スクリプトが授業週次を返しました。校暦の学期開始日を確認。学校の最初の数週間に授業がない場合、「時間割第1週」を校暦の後の週次に対応可能。';

  @override
  String aiPreviewCourseCount(int count) {
    return '授業数：$count';
  }

  @override
  String aiPreviewMaxSection(int section) {
    return '最大時限：第$section時限';
  }

  @override
  String get aiPreviewWarningsTitle => '認識注意事項';

  @override
  String get aiPreviewCoursesTitle => '授業プレビュー';

  @override
  String aiPreviewRemainingCourses(int count) {
    return '残り$count件はインポート後に現在の時間割に書き込み';
  }

  @override
  String get warehouseMissingSchoolTitle => '学校リストにあなたの学校がない？';

  @override
  String get warehouseMissingSchoolSubtitle =>
      'フィードバックページでIssueを提出するだけ。学校名、教務システムURL、ログイン後の時間割ページリンクまたはスクリーンショットを一緒に書くと、適応補充がよりスムーズ。';

  @override
  String get laterAction => '後で';

  @override
  String get goFeedbackAction => 'フィードバックページへ';

  @override
  String get warehouseFeedbackMissingSchoolTitle => '学校がない？フィードバックへ';

  @override
  String get warehouseCustomDebugTitle => 'カスタムデバッグ';

  @override
  String get warehouseRootLoadFailedTitle => '適応倉庫を一時的に読み込めません';

  @override
  String get searchSchoolHint => '学校名、頭文字またはコードで検索';

  @override
  String get clearSearchTooltip => 'クリア';

  @override
  String get noMatchingSchools => '一致する学校が見つかりません';

  @override
  String get noAvailableSchools => '利用可能な学校がありません';

  @override
  String get searchSchoolSuggestion => '学校の正式名称、頭文字または倉庫の学校コードをお試しください。';

  @override
  String get deleteDebugRecordTitle => 'デバッグレコード削除';

  @override
  String deleteDebugRecordMessage(String name) {
    return '「$name」を削除しますか？削除後もインポート済みの授業には影響しません。';
  }

  @override
  String deletedDebugRecord(String name) {
    return 'デバッグレコード削除済み：$name';
  }

  @override
  String get customDebugName => 'カスタムデバッグ';

  @override
  String get localDebugMaintainer => 'ローカルデバッグ';

  @override
  String get customDebugDescription => 'ユーザーが保存したカスタム教務デバッグスクリプト';

  @override
  String get addDebugRecordTooltip => 'デバッグレコード追加';

  @override
  String get customDebugIntroTitle => 'ここに自分の教務デバッグレコードを配置';

  @override
  String get customDebugIntroSubtitle =>
      '各レコードにカスタムURLとスクリプト全体を保存可能。保存後、次回は「デバッグ開始」をタップするだけで再利用可能。特定の学校詳細ページを探す必要なし。';

  @override
  String get addDebugRecordAction => 'デバッグレコード追加';

  @override
  String get noSavedDebugRecords => '保存済みのデバッグレコードがありません';

  @override
  String get noSavedDebugRecordsHint => 'まず1件追加し、URLとスクリプトを貼付。以降直接再利用可能。';

  @override
  String debugScriptLength(int count) {
    return 'スクリプト$count文字';
  }

  @override
  String get startDebugAction => 'デバッグ開始';

  @override
  String get editAction => '編集';

  @override
  String get scriptFileReadFailed => 'スクリプトファイルを読み込めません';

  @override
  String scriptFileImported(String name) {
    return 'スクリプトファイルインポート済み：$name';
  }

  @override
  String scriptFileImportFailed(String error) {
    return 'スクリプトファイルのインポート失敗：$error';
  }

  @override
  String get debugRecordNameRequired => 'デバッグレコード名を入力してください';

  @override
  String get invalidImportUrl => '有効な教務URLを入力してください';

  @override
  String get debugScriptRequired => 'スクリプトを入力またはインポートしてください';

  @override
  String get editDebugRecordTitle => 'デバッグレコード編集';

  @override
  String get addDebugRecordTitle => 'デバッグレコード追加';

  @override
  String get savingAction => '保存中…';

  @override
  String get debugRecordFormula => '1レコード = 1URL + 1スクリプト';

  @override
  String get debugRecordFormulaSubtitle =>
      '同じ学校を繰り返しデバッグする場合や、異なる学校に複数のスクリプトセットを保持するのに最適。保存後もいつでも変更可能。';

  @override
  String get debugRecordNameLabel => 'レコード名';

  @override
  String get debugRecordNameHint => '例：重慶機電-新版教務';

  @override
  String get importUrlLabel => '教務URL';

  @override
  String get debugScriptLabel => 'デバッグスクリプト';

  @override
  String get importFromFileAction => 'ファイルからインポート';

  @override
  String get debugScriptHint => 'ブラウザ拡張機能がエクスポートした完全なスクリプトをここに貼付';

  @override
  String get saveDebugRecordAction => 'デバッグレコードを保存';

  @override
  String get fillUrlThenImport => 'URL入力後にインポート';

  @override
  String get webLoginImport => 'Webログインインポート';

  @override
  String get fillUrlThenRecord => 'URL入力後に録画';

  @override
  String get recordImportAction => '録画インポート';

  @override
  String get quickImportAction => 'クイックインポート';

  @override
  String get quickImportTooltip => 'クイックインポート';

  @override
  String get selectQuickImportTitle => 'クイックインポートを選択';

  @override
  String quickImportMacroSteps(String adapterName, int stepCount) {
    return '$adapterName · $stepCount ステップ';
  }

  @override
  String quickImportTitle(String name) {
    return 'クイックインポート - $name';
  }

  @override
  String get noSavedQuickImportRecords => '保存済みのクイックインポート記録がありません';

  @override
  String get noValidWarehouseLoginUrl => '有効な教務ログインURLが見つかりません';

  @override
  String get noMacroRecordFound => '録画記録が見つかりません。先に録画を完了してください';

  @override
  String get quickImportPlayingTitle => '自動インポート中…';

  @override
  String get quickImportExecutingScriptTitle => '再生完了、インポートスクリプトを実行中…';

  @override
  String get quickImportManualInputTitle => '手動操作が必要';

  @override
  String get quickImportManualInputHint => '必要な手動操作を完了してから「続行」をタップしてください。';

  @override
  String get quickImportCancelImportAction => 'インポートをキャンセル';

  @override
  String get quickImportContinueAction => '続行';

  @override
  String get quickImportFinishedTitle => 'インポート完了';

  @override
  String get quickImportDismissAction => '完了';

  @override
  String get quickImportRetryAction => '再試行';

  @override
  String quickImportPlaybackStepProgress(int current, int total) {
    return 'ステップ $current / $total';
  }

  @override
  String get quickImportCancelPlaybackAction => 'キャンセル';

  @override
  String get quickImportUnknownError => '不明なエラーが発生しました';

  @override
  String get recentSchoolLabel => '最近使用';

  @override
  String get warehouseSchoolTapHint => 'タップしてアダプタを選びインポート';

  @override
  String get warehouseAdaptersLoadFailedTitle => 'アダプタ一覧を読み込めません';

  @override
  String get stopRecordingTooltip => '録画停止';

  @override
  String get startRecordingTooltip => '操作を録画';

  @override
  String get savedImportUrlHint => '教務URLを保存済み。次回直接インポート可能';

  @override
  String get adapterIntroSubtitle => 'アダプタ情報、ログインエントリとスクリプトステータスを確認可能。';

  @override
  String get schoolLabel => '学校';

  @override
  String get categoryLabel => 'カテゴリ';

  @override
  String get maintainerLabel => 'メンテナー';

  @override
  String get adapterInfoTitle => 'アダプタ情報';

  @override
  String get scriptPathLabel => 'スクリプトパス';

  @override
  String get loginEntryLabel => 'ログインエントリ';

  @override
  String get unsetConfigLabel => '未設定';

  @override
  String get adapterOverrideImportUrlHint => '現在手動で上書きしたログインアドレスを使用中';

  @override
  String get repositoryLabel => 'リポジトリ';

  @override
  String get scriptStatusTitle => 'スクリプトステータス';

  @override
  String scriptLoadedLength(int count) {
    return 'スクリプト読み取り成功。長さ$count文字。';
  }

  @override
  String get scriptEmpty => 'スクリプトが空';

  @override
  String get openLoginInAppAction => 'アプリ内でログインエントリを開く';

  @override
  String get openInSystemBrowserAction => 'システムブラウザで開く';

  @override
  String get copiedImportLoginUrl => '教務ログインアドレスをコピーしました';

  @override
  String get copyLoginAddressAction => 'ログインアドレスをコピー';

  @override
  String get copiedScriptRawUrl => 'スクリプトの生アドレスをコピーしました';

  @override
  String get copyScriptAddressAction => 'スクリプトアドレスをコピー';

  @override
  String get customLoginAddressAction => 'カスタムログインアドレス';

  @override
  String get editCustomLoginAddressAction => 'カスタムアドレスを変更';

  @override
  String get clearCustomLoginAddressAction => 'カスタムアドレスをクリア';

  @override
  String get restoreRepositoryAddressAction => 'リポジトリアドレスを復元';

  @override
  String get invalidLoginEntryUrl => 'ログインエントリアドレスが無効';

  @override
  String get savedCustomLoginAddress => 'カスタムログインアドレスを保存済み';

  @override
  String get clearedCustomLoginAddress => 'カスタムログインアドレスをクリア済み';

  @override
  String get restoredRepositoryImportUrl => 'リポジトリのログインアドレスを復元済み';

  @override
  String get backToCurrentWeekAction => '今週に戻る';

  @override
  String get nonCurrentWeekLabel => '非今週';

  @override
  String get conflictLabel => '競合';

  @override
  String get selectWeekTitle => '週次を選択';

  @override
  String availableWeeksCount(int count) {
    return '全$count週';
  }

  @override
  String goToWeekLabel(int week) {
    return '第$week週';
  }

  @override
  String get homeMenuUpdateTitle => 'ソフトウェア更新';

  @override
  String get homeMenuProfilesTitle => '時間割管理';

  @override
  String get homeMenuOverviewTitle => '授業一覧';

  @override
  String get homeMenuAddCourseTitle => '授業追加';

  @override
  String get homeMenuImportTitle => '授業インポート';

  @override
  String get homeMenuSettingsTitle => '時間割設定';

  @override
  String get homeMenuCoffeeTitle => 'コーヒーをおごる';

  @override
  String get homeMenuFeedbackTitle => '問題報告';

  @override
  String get switchTimetableTitle => '時間割切替';

  @override
  String get switchTimetableSubtitleEmpty => '下の時間割をタップして現在のビューを即時切替。';

  @override
  String switchTimetableSubtitleCurrent(String name) {
    return '現在：$name。下の時間割をタップして即時切替。';
  }

  @override
  String get todayTimetableTitle => '今日の時間割';

  @override
  String get dayTimetableTitle => '日別タイムライン';

  @override
  String get backToWeekViewAction => '週表示に戻る';

  @override
  String get backToTodayAction => '今日に戻る';

  @override
  String get ongoingCourseBadge => '授業中';

  @override
  String get dayViewEmptyTitle => '授業なし';

  @override
  String shortNamePrefix(String value) {
    return '略称：$value';
  }

  @override
  String teacherPrefix(String value) {
    return '教師：$value';
  }

  @override
  String locationPrefix(String value) {
    return '場所：$value';
  }

  @override
  String courseDialogCurrentWeekHint(int week) {
    return '現在第$week週を閲覧中。この週のこの授業を直接時間変更可能。';
  }

  @override
  String courseDialogNotThisWeekHint(int week) {
    return '現在第$week週を閲覧中。この授業は今週ないため、「今週のこの授業」として時間変更できない。';
  }

  @override
  String get editActionShort => '編集';

  @override
  String get rescheduleAction => '時間変更';

  @override
  String get deleteActionShort => '削除';

  @override
  String get deleteModeTitle => '削除方式';

  @override
  String get deleteModeSubtitle => '排課全体を削除するか、現在表示中のこの週のこの授業のみ削除可能。';

  @override
  String get deleteCourseAction => 'この授業を削除';

  @override
  String get deleteOccurrenceAction => 'この授業回を削除';

  @override
  String deleteModeHintCurrentWeek(int week) {
    return '「この授業を削除」は排課の全週次を削除。「この授業回を削除」は第$week週の今回のみ削除。';
  }

  @override
  String deleteModeHintUnavailable(int week) {
    return '現在のカードは第$week週の実際の排課ではないため、排課全体のみ削除可能。';
  }

  @override
  String deleteScheduleConfirmMessage(String name, String detail) {
    return '「$name」の排課を削除しますか？\n$detail';
  }

  @override
  String deleteOccurrenceConfirmMessage(String name, int week, String detail) {
    return '「$name」の第$week週のこの授業を削除しますか？\n$detail';
  }

  @override
  String occurrenceDeletedMessage(int week) {
    return '第$week週のこの授業を削除済み';
  }

  @override
  String get noChangesDetected => '変更が検出されませんでした';

  @override
  String get rescheduleCurrentOccurrenceTitle => '今週のこの授業を時間変更';

  @override
  String rescheduleCurrentOccurrenceSubtitle(int week) {
    return '第$week週のこの授業のみ調整。元の授業はこの週から自動的に削除され、他の週は変更なし。';
  }

  @override
  String get rescheduleTargetWeekLabel => '変更先の週';

  @override
  String get weekdayFieldLabel => '曜日';

  @override
  String get startSectionFieldLabel => '開始時限';

  @override
  String get endSectionFieldLabel => '終了時限';

  @override
  String get courseLocationFieldLabel => '授業場所';

  @override
  String get confirmRescheduleAction => '時間変更確認';

  @override
  String get homeTitleStyleClassicLabel => 'クラシックテキスト';

  @override
  String get homeTitleStyleBrandLabel => '大Logo';

  @override
  String get homeTitleStyleClassicDescription =>
      '元のタイトルスタイルを維持。テキストのみ表示。タップで時間割切替。';

  @override
  String get homeTitleStyleBrandDescription => '大Logoと小さな時間割名を表示。ブランド感を強調。';

  @override
  String get widgetBackgroundStyleGlass => '半透明ガラス';

  @override
  String get widgetBackgroundStyleSolid => '単色カード';

  @override
  String get widgetBackgroundStyleGradient => 'グラデーションカード';

  @override
  String get homeWidgetTargetCompact22 => 'メインカード2×2';

  @override
  String get homeWidgetTargetMiniList22 => 'ミニリスト2×2';

  @override
  String get homeWidgetTargetMedium24 => '概要2×4';

  @override
  String get homeWidgetTargetLarge44 => 'リスト4×4';

  @override
  String get addCourseSheetTitle => 'コンテンツ追加';

  @override
  String get addCourseSheetSubtitle =>
      '空白の時間割エリアはタップに反応しません。臨時授業、学期通しの繰り返し授業、または単回スケジュールの挿入を選択してください。';

  @override
  String courseWeekdaySectionSummary(
    String weekDescription,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '$weekDescription・$weekday $startSection-$endSection時限';
  }

  @override
  String weekdaySectionTimeSummary(
    String weekday,
    int startSection,
    int endSection,
    String startTime,
    String endTime,
  ) {
    return '$weekday $startSection-$endSection時限・$startTime-$endTime';
  }

  @override
  String rescheduledToMessage(
    int week,
    String weekday,
    int startSection,
    int endSection,
  ) {
    return '第$week週$weekday $startSection-$endSection時限に変更済み';
  }

  @override
  String courseCountSummary(int count) {
    return '$count科目';
  }

  @override
  String dayAgendaInProgressStatus(int minutes) {
    return '進行中・残り$minutes分';
  }

  @override
  String dayAgendaEndingSoonStatus(int minutes) {
    return 'もうすぐ終了・残り$minutes分';
  }

  @override
  String scheduleAgendaInProgressStatus(int minutes) {
    return '進行中・残り$minutes分';
  }

  @override
  String scheduleAgendaEndingSoonStatus(int minutes) {
    return 'もうすぐ終了・残り$minutes分';
  }

  @override
  String get currentBadge => '現在';

  @override
  String get feedbackXiaohongshuTitle => 'Xiaohongshu';

  @override
  String feedbackXiaohongshuSubtitle(String id) {
    return 'Xiaohongshu ID：$id';
  }

  @override
  String get feedbackCoolapkTitle => 'Coolapk';

  @override
  String feedbackCoolapkSubtitle(String id) {
    return 'Coolapk ID：$id';
  }

  @override
  String get feedbackQqGroupTitle => 'QQグループ';

  @override
  String feedbackQqGroupSubtitle(String id) {
    return 'グループID：$id';
  }

  @override
  String get copiedCurrentTimetable => '現在の時間割をコピーしました';

  @override
  String sectionRangeLabel(int startSection, int endSection) {
    return '$startSection-$endSection時限';
  }

  @override
  String classStartsAtLabel(String time) {
    return '$time開始';
  }

  @override
  String classEndsAtLabel(String time) {
    return '$time終了';
  }

  @override
  String get invalidSectionTimeFormat => '時限時間の形式が正しくありません';

  @override
  String get noSectionTimesToSave => '保存可能な時限時間がありません';

  @override
  String warehouseImportedTimeSchemeName(String schoolName) {
    return '$schoolNameインポート時限';
  }

  @override
  String get unnamedScript => '名前未設定スクリプト';

  @override
  String localDebugModeScriptStatus(String scriptName) {
    return 'ローカルデバッグモード：$scriptName';
  }

  @override
  String get executeImportScriptTooltip => 'インポートスクリプトを実行';

  @override
  String get switchToMobileWebTooltip => 'モバイルページに切替';

  @override
  String get switchToDesktopWebTooltip => 'デスクトップページに切替';

  @override
  String get rememberCurrentInputTooltip => '現在の入力を記憶';

  @override
  String get fillRememberedTooltip => '記憶済みアカウントを入力';

  @override
  String get clearRememberedTooltip => '記憶済みアカウントをクリア';

  @override
  String get copyCurrentAddressTooltip => '現在のアドレスをコピー';

  @override
  String get copiedCurrentAddress => '現在のアドレスをコピーしました';

  @override
  String get warehouseLoginHintLocalDebug => '現在ローカルデバッグスクリプトモード';

  @override
  String get warehouseLoginHintImport => 'ここで教務システムにログインしてインポートを実行';

  @override
  String get currentPageModeDesktop => '現在のページモード：デスクトップ';

  @override
  String get currentPageModeMobile => '現在のページモード：モバイル';

  @override
  String localScriptLabel(String scriptName) {
    return 'ローカルスクリプト：$scriptName';
  }

  @override
  String get webAddressHint => 'Webアドレスを入力';

  @override
  String get goAction => '移動';

  @override
  String rememberedAccountLabel(String username) {
    return '記憶済みアカウント：$username';
  }

  @override
  String get importingAction => 'インポート中...';

  @override
  String get executeLocalDebugScriptAction => 'ローカルデバッグスクリプトを実行';

  @override
  String get executeImportScriptAction => 'インポートスクリプトを実行';

  @override
  String get invalidWebAddress => 'Webアドレスが無効';

  @override
  String get injectingLocalDebugScript => 'ローカルデバッグスクリプトを注入中';

  @override
  String get injectingAdapterScript => 'アダプタスクリプトを注入中';

  @override
  String get localDebugScriptInjected => 'ローカルデバッグスクリプト注入済み';

  @override
  String get scriptInjected => 'スクリプト注入済み';

  @override
  String get scriptInjectionFailed => 'スクリプト注入失敗';

  @override
  String executeFailedWithError(String error) {
    return '実行失敗：$error';
  }

  @override
  String get importFlowFinished => 'インポートフロー完了';

  @override
  String get defaultContinuePrompt => 'プロンプトに従って操作を続行';

  @override
  String get inputRequiredTitle => '入力が必要';

  @override
  String get pleaseEnterFourDigitYear => '4桁の年号を入力してください';

  @override
  String get pleaseChooseTitle => '選択してください';

  @override
  String get invalidCourseConfigFormat => '授業設定の形式が正しくありません';

  @override
  String saveCourseConfigFailedWithError(String error) {
    return '授業設定の保存失敗：$error';
  }

  @override
  String saveSectionTimesFailedWithError(String error) {
    return '時限時間の保存失敗：$error';
  }

  @override
  String get invalidCourseDataFormat => '授業データの形式が正しくありません';

  @override
  String get noImportableCoursesFromScript => 'スクリプトがインポート可能な授業を返しませんでした';

  @override
  String importCourseCountPrompt(int count) {
    return '$count科目を認識。インポートしますか？';
  }

  @override
  String get importCancelledStatus => 'インポートをキャンセル済み';

  @override
  String applyReturnedTimeSchemeFailed(String error) {
    return '返されたテンプレートの適用失敗：$error';
  }

  @override
  String get importInterruptedStatus => 'インポート中断';

  @override
  String get importFailedStatus => 'インポート失敗';

  @override
  String importFailedWithError(String error) {
    return 'インポート失敗：$error';
  }

  @override
  String get unknownTeacher => '不明な教師';

  @override
  String get unknownLocation => '不明な場所';

  @override
  String get autofillLoginTitle => 'ログイン情報自動入力';

  @override
  String autofillLoginMessage(String username) {
    return '記憶済みアカウント$usernameを検出。自動入力しますか？';
  }

  @override
  String get notNowAction => '今はしない';

  @override
  String get autofillAction => '自動入力';

  @override
  String get rememberPasswordTitle => 'パスワードを記憶';

  @override
  String rememberPasswordMessage(String username) {
    return 'アカウント$usernameのログイン情報を記憶し、次回自動入力しますか？';
  }

  @override
  String get dontRememberAction => '記憶しない';

  @override
  String get rememberAndAutofillAction => '記憶して自動入力';

  @override
  String get savedRememberedLoginStatus => '記憶済みログイン情報を保存しました';

  @override
  String get autofilledRememberedLoginStatus => '記憶済みログイン情報を自動入力しました';

  @override
  String get noRecognizedLoginInputs => 'ログイン入力項目が認識されません';

  @override
  String get noUsernameOrPasswordRecognized => 'ユーザー名またはパスワードが認識されません';

  @override
  String get rememberedCurrentLoginStatus => '現在のログイン情報を記憶しました';

  @override
  String get rememberedCurrentLoginSuccess => '現在のログイン情報を記憶しました';

  @override
  String rememberLoginFailedWithError(String error) {
    return 'ログイン情報の記憶失敗：$error';
  }

  @override
  String get clearedRememberedLoginStatus => '記憶済みログイン情報をクリアしました';

  @override
  String get clearedRememberedLoginSuccess => '記憶済みログイン情報をクリアしました';

  @override
  String get addScheduleTitle => 'スケジュール追加';

  @override
  String get editScheduleTitle => 'スケジュール編集';

  @override
  String get addScheduleAction => 'スケジュール追加';

  @override
  String get scheduleTitleLabel => 'スケジュールタイトル';

  @override
  String get scheduleTitleHint => '例：グループミーティング、書類手続き、荷物受取';

  @override
  String get scheduleTitleRequired => 'スケジュールタイトルを入力してください';

  @override
  String get scheduleInfoSectionTitle => 'スケジュール情報';

  @override
  String get scheduleInfoSectionSubtitle =>
      'スケジュールは具体的な日付で日別ビューのタイムラインに挿入。授業自体は変更しない。';

  @override
  String get scheduleTimeSectionTitle => '時間設定';

  @override
  String get scheduleTimeSectionSubtitle => 'このスケジュールが実際に発生する日付と開始/終了時間を選択。';

  @override
  String get scheduleAppearanceSectionTitle => '表示スタイル';

  @override
  String get scheduleAppearanceSectionSubtitle => '授業と区別しやすいスケジュールカラーを選択。';

  @override
  String get scheduleLocationLabel => '場所';

  @override
  String get scheduleLocationHint => '任意';

  @override
  String get scheduleDateLabel => '日付';

  @override
  String get scheduleStartGroupLabel => '開始';

  @override
  String get scheduleEndGroupLabel => '終了';

  @override
  String get scheduleStartDateLabel => '開始日';

  @override
  String get scheduleEndDateLabel => '終了日';

  @override
  String get scheduleStartTimeLabel => '開始時間';

  @override
  String get scheduleEndTimeLabel => '終了時間';

  @override
  String get scheduleColorLabel => 'スケジュールカラー';

  @override
  String get scheduleNoteLabel => 'メモ';

  @override
  String get scheduleNoteHint => '任意';

  @override
  String get scheduleBadgeLabel => 'スケジュール';

  @override
  String scheduleCountSummary(int count) {
    return 'スケジュール$count件';
  }

  @override
  String get scheduleTimeRangeInvalid => '終了時間は開始時間より後である必要があります';

  @override
  String get scheduleDateRangeInvalid => '終了日は開始日より前にすることはできません';

  @override
  String get scheduleSingleDayHint => '同日終了の場合、終了時間は開始時間より後である必要があります。';

  @override
  String get scheduleCrossDayHint => '日跨ぎスケジュールは当日のスライスで日別ビューに表示。';

  @override
  String get scheduleSavedHint => 'スケジュール追加済み';

  @override
  String get scheduleUpdatedHint => 'スケジュール更新済み';

  @override
  String get crossDayBadgeLabel => '日跨ぎ';

  @override
  String deleteScheduleMessage(String title) {
    return 'スケジュール「$title」を削除しますか？';
  }

  @override
  String get scheduleDeletedHint => 'スケジュール削除済み';

  @override
  String get examListTitle => '試験スケジュール';

  @override
  String get addExam => '試験追加';

  @override
  String get editExam => '試験編集';

  @override
  String get saveExam => '試験保存';

  @override
  String get noExams => '試験スケジュールなし';

  @override
  String get examToday => '今日試験あり';

  @override
  String daysUntilExam(int days) {
    return '試験まであと$days日';
  }

  @override
  String get examPassed => '終了済み';

  @override
  String get linkCourse => '授業を関連付け';

  @override
  String get linkCourseRequired => '関連授業を選択してください';

  @override
  String get examNameLabel => '試験名';

  @override
  String get examNameRequired => '試験名を入力してください';

  @override
  String get examDateLabel => '試験日';

  @override
  String get examDateHint => '日付を選択';

  @override
  String get examDateRequired => '試験日を選択してください';

  @override
  String get examStartTimeLabel => '開始時間';

  @override
  String get examEndTimeLabel => '終了時間';

  @override
  String get examLocationLabel => '試験会場';

  @override
  String get examLocationHint => '空欄の場合は授業教室を使用';

  @override
  String get sameAsClassroom => '授業教室と同じ';

  @override
  String get examSeatLabel => '席番号';

  @override
  String get examReminderLabel => 'リマインダー設定';

  @override
  String get examNoteLabel => 'メモ';

  @override
  String get deleteExam => '試験削除';

  @override
  String deleteExamConfirm(String name) {
    return '試験「$name」を削除しますか？';
  }

  @override
  String get examBadgeLabel => '試験';

  @override
  String get examCountdownToday => '今日';

  @override
  String examCountdownDays(int days) {
    return '$days日後';
  }

  @override
  String get sortAction => '並べ替え';

  @override
  String get sortByAdded => '追加順';

  @override
  String get sortByName => '授業名順';

  @override
  String get sortBySchedule => '排課時間順';

  @override
  String scheduleEntryTitle(int index) {
    return '排課レコード$index';
  }

  @override
  String get scheduleEntrySingleTitle => '授業スケジュール';

  @override
  String get scheduleEntryCardSubtitle => 'この授業の曜日・時限・週次・教員・教室を設定します。';

  @override
  String get scheduleEntryTimeSectionTitle => 'いつ';

  @override
  String get scheduleEntryTimeSectionSubtitle =>
      '曜日と時限を選びます。連続時限は開始と終了を、単時限は同じ番号にします。';

  @override
  String get scheduleEntryWeeksSectionTitle => 'どの週';

  @override
  String get scheduleEntryPeopleSectionTitle => '教員と教室';

  @override
  String get scheduleEntryTimeSchemeSectionTitle => '特別な時間割';

  @override
  String get scheduleEntryTimeSchemeSectionSubtitle =>
      '既定は時間割に従います。ベル時刻が異なる場合のみ変更してください。';

  @override
  String scheduleSectionNumberLabel(int section) {
    return '$section時限';
  }

  @override
  String get addScheduleEntryAction => '排課時間を追加';

  @override
  String get deleteScheduleEntryAction => '排課を削除';

  @override
  String get holidaySettingsEntryTitle => '休日マーク';

  @override
  String get holidaySettingsEntrySubtitle => '時間割に法定休日と振替出勤日をマーク';

  @override
  String get holidayMakeupWorkday => '振替出勤';

  @override
  String get holidaySettingsTitle => '休日マーク';

  @override
  String get holidayEnableTitle => '休日マークを有効化';

  @override
  String get holidayEnableSubtitle => 'オンにすると時間割に法定休日と振替出勤日をマーク';

  @override
  String get holidayDataSectionTitle => '休日データ';

  @override
  String get holidayDataYear => '年';

  @override
  String get holidayDataCount => '件数';

  @override
  String get holidayDataEmpty => '休日データなし';

  @override
  String get holidayCheckUpdate => '更新を確認';

  @override
  String get holidayUpcomingSectionTitle => '近日の休日';

  @override
  String get holidayNoUpcoming => '近日休日なし';

  @override
  String get holidayBadgeLabel => '休';

  @override
  String get holidayStatusLabel => '休日';

  @override
  String get suspendedBadgeLabel => '停';

  @override
  String get suspendedStatusLabel => '授業停止';

  @override
  String get courseActionSuspend => '授業停止';

  @override
  String get courseActionUnsuspend => '復旧';

  @override
  String get courseActionEditPrimary => '授業を編集';

  @override
  String get courseActionRescheduleSecondary => '時間変更';

  @override
  String get courseActionSuspendSecondary => '休講';

  @override
  String get courseActionDeleteSecondary => '削除';

  @override
  String courseActionSheetNotice(int week) {
    return '第$week週を表示中です。試験や重複が発生した場合は、下からすぐに変更または休講できます。';
  }

  @override
  String get courseActionOddWeekShort => '奇数週';

  @override
  String get courseActionEvenWeekShort => '偶数週';

  @override
  String get courseActionConflictExpandHint => '他の競合授業を表示して、操作対象を切り替えます';

  @override
  String get courseActionConflictCollapseHint => 'タップして競合リストを閉じる';

  @override
  String get courseActionConflictSwitchAction => '切替';

  @override
  String courseActionCoupleRelatedCount(int count) {
    return '还有 $count 节情侣课表课程';
  }

  @override
  String get courseActionCoupleExpandHint => '展开查看 TA 的课或一起上课，点击可切换预览';

  @override
  String get courseActionCoupleCollapseHint => '点击收起情侣课表课程列表';

  @override
  String courseActionMixedRelatedCount(int count) {
    return '还有 $count 节相关课程';
  }

  @override
  String get courseActionPartnerReadOnlyNotice => '这是对方课表中的课程，仅供查看，无法编辑或调课。';

  @override
  String get suspendSheetTitle => '授業停止';

  @override
  String get suspendSheetSubtitle => '停止範囲を選択';

  @override
  String get suspendThisWeek => '今週停止';

  @override
  String get suspendThisWeekDesc => '現在の週のみ一時停止';

  @override
  String get suspendAllWeeks => '全週停止';

  @override
  String get suspendAllWeeksDesc => '全週次を一時停止';

  @override
  String get unsuspendAllWeeks => '全週復旧';

  @override
  String get unsuspendAllWeeksDesc => '全週次を復旧';

  @override
  String get customHolidayTitle => 'カスタム休日';

  @override
  String get customHolidayAdd => '休日追加';

  @override
  String get customHolidayEdit => '休日編集';

  @override
  String get customHolidayDelete => '削除';

  @override
  String get customHolidayDeleteConfirm => 'このカスタム休日を削除しますか？';

  @override
  String get customHolidayNameLabel => '休日名';

  @override
  String get customHolidayStartDate => '開始日';

  @override
  String get customHolidayEndDate => '終了日';

  @override
  String get customHolidayType => 'タイプ';

  @override
  String get customHolidayTypeVacation => '休日';

  @override
  String get customHolidayTypeWorkday => '振替出勤';

  @override
  String get customHolidayEmpty => 'カスタム休日なし';

  @override
  String get customHolidayNameRequired => '休日名を入力してください';

  @override
  String customHolidayDateRange(Object start, Object end) {
    return '$start ~ $end';
  }

  @override
  String get selectTeacherTitle => '教師を選択';

  @override
  String get selectLocationTitle => '教室を選択';

  @override
  String get historyRecordsLabel => '履歴';

  @override
  String get noHistoryRecords => '履歴なし';

  @override
  String get weekPickerTitle => '授業週次を選択';

  @override
  String get selectTimeSchemeTitle => '時間方案を選択';

  @override
  String get manageTimeSchemesAction => '時間方案を管理';

  @override
  String get examDefaultName => '期末試験';

  @override
  String get examDateWeekPickerTitle => '試験日を選択';

  @override
  String get weekPickerCalendarTooltip => 'カレンダーで選択';

  @override
  String get thisWeekLabel => '今週';

  @override
  String get guidePrivacyPageTitle => 'プライバシーポリシー';

  @override
  String get guidePermissionsPageTitle => 'システム権限';

  @override
  String get guideTipsPageTitle => '使い方のコツ';

  @override
  String get guidePrevButton => '前へ';

  @override
  String get guideNextButton => '次へ';

  @override
  String get guidePermissionsHeader => 'システム権限設定';

  @override
  String get guidePermissionsSubtitle =>
      'これらの設定を完了すると、スーパーアイランドとリマインダーが正常に使用可能';

  @override
  String get guidePermissionsFooterHint =>
      'タップ後にシステム設定に移動。アプリに戻ると認識可能なステータスが自動更新。自動起動はシステム制限あり。システムページのスイッチを基準にしてください。';

  @override
  String get guideTipsHeader => '使い方のコツ';

  @override
  String get guideTipsSubtitle => 'これらはいつでも「設定」から確認可能';

  @override
  String get guidePrivacyReadBeforeUse => '使用前に以下を読み同意してください';

  @override
  String get guidePrivacyViewOnly => 'プライバシー、サードパーティSDKと免責事項';

  @override
  String holidayDataYearLabel(Object year) {
    return '$year年法定休日';
  }

  @override
  String get holidayUpdateLog => '更新ログ';

  @override
  String holidayUpdateLogCount(int count) {
    return '$count件';
  }

  @override
  String holidayDateSameMonth(int month, int start, int end) {
    return '$month月$start日 - $end日';
  }

  @override
  String holidayDateSameDay(int month, int day) {
    return '$month月$day日';
  }

  @override
  String holidayDateDiffMonth(
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$startMonth月$startDay日 - $endMonth月$endDay日';
  }

  @override
  String get liveTestingHolidayOverride => '休日ステータス上書き';

  @override
  String get liveTestingHolidayOverrideSubtitle =>
      'オンにすると休日ステータスをシミュレート。リマインダーとウィジェットが授業を正しく非表示にするかテスト可能。';

  @override
  String get liveTestingHolidayModeEnabled => '休日モード有効';

  @override
  String get liveTestingHolidayModeDisabled => '休日モード無効';

  @override
  String get liveTestingHolidayModeEnabledDesc => '授業リマインダーとウィジェットは全授業を非表示';

  @override
  String get liveTestingHolidayModeDisabledDesc => '現在通常の休日データを使用';

  @override
  String get textColorTitle => 'テキストの色';

  @override
  String get textColorSubtitle => '時間割の各エリアのテキスト色をカスタマイズ';

  @override
  String get textColorIndependentDetail => '詳細色を個別に設定';

  @override
  String get textColorCourseCardTitle => '授業カードタイトル色';

  @override
  String get textColorCourseCardDetail => '授業カード詳細色';

  @override
  String get textColorWeekdayBar => '曜日バーのフォント色';

  @override
  String get textColorWeekdayBarAccent => '曜日バーのアクセント色';

  @override
  String get textColorTimeAxis => '時間軸のフォント色';

  @override
  String get textColorSelectColor => '色を選択';

  @override
  String get textColorCurrentColor => '現在の色';

  @override
  String get themeExport => 'テーマをエクスポート';

  @override
  String get themeImport => 'テーマをインポート';

  @override
  String get themeExportSuccess => 'テーマをクリップボードにコピーしました';

  @override
  String get themeImportSuccess => 'テーマをインポートしました';

  @override
  String get themeImportFailed => 'クリップボードの内容の形式が正しくありません';

  @override
  String get themeManageTitle => 'テーマ管理';

  @override
  String get themeManageSubtitle => 'テーマのエクスポート、インポート、切り替え';

  @override
  String get themePreset => 'プリセットテーマ';

  @override
  String get themeSaved => 'マイテーマ';

  @override
  String get themeSaveCurrent => '現在のテーマを保存';

  @override
  String get themeApply => '適用';

  @override
  String get themeDelete => '削除';

  @override
  String themeDeleteConfirmMessage(String name) {
    return 'テーマ「$name」を削除してもよろしいですか？';
  }

  @override
  String get textColorLowContrastWarning => '色のコントラストが低く、可読性に影響する可能性があります';

  @override
  String get themeCurrentTheme => '現在のテーマ';

  @override
  String themeBasedOnModified(String baseName) {
    return '$baseName（変更済み）';
  }

  @override
  String get themeResetToPreset => 'リセット';

  @override
  String get themeUnsavedChangesTitle => '未保存の変更';

  @override
  String get themeUnsavedChangesMessage => '現在のテーマに未保存の変更があります。保存しますか？';

  @override
  String get themeDiscardAndApply => '破棄して適用';

  @override
  String get themeNameHint => 'テーマ名を入力';

  @override
  String get themePresetBlue => 'デフォルトブルー';

  @override
  String get themePresetPurple => 'ナイトパープル';

  @override
  String get themePresetGreen => 'フォレストグリーン';

  @override
  String get themePresetOrange => 'ウォームオレンジ';

  @override
  String get themePresetEyeCare => 'アイケア';

  @override
  String get themePresetHighContrast => 'ハイコントラスト';

  @override
  String get themePresetDarkMinimal => 'ダークミニマル';

  @override
  String get themeUndo => '元に戻す';

  @override
  String themeChanged(String themeName) {
    return '$themeName に切り替えました';
  }

  @override
  String get themeRename => '名前を変更';

  @override
  String get themeDuplicate => '複製';

  @override
  String themeDuplicateCopyName(String name) {
    return '$name のコピー';
  }

  @override
  String get themeMoreActions => 'その他の操作';

  @override
  String get courseNatureRequired => '必修';

  @override
  String get courseNatureElective => '選択';

  @override
  String get homeMenuStatisticsTitle => '授業統計';

  @override
  String get statisticsTitle => '授業統計';

  @override
  String get statisticsOverview => '今週の概要';

  @override
  String get statisticsCourseCount => '科目数';

  @override
  String get statisticsSectionCount => '今週の授業時間';

  @override
  String get statisticsWeeklyCourses => '今週の授業';

  @override
  String get statisticsDailyDistribution => '日別授業分布';

  @override
  String get statisticsNatureRatio => '必修 / 選択';

  @override
  String get statisticsCourseList => '授業リスト';

  @override
  String get statisticsSectionsUnit => 'コマ';

  @override
  String get statisticsSectionUnit => 'コマ';

  @override
  String get statisticsNoData => '授業データがありません';

  @override
  String get statisticsCourseCountRatio => '科目数の割合';

  @override
  String get statisticsSectionCountRatio => '授業時間の割合';

  @override
  String statisticsWeekSelector(int week) {
    return '第 $week 週';
  }

  @override
  String get statisticsStoryBusiestDayTitle => '最忙しい日';

  @override
  String statisticsStoryBusiestDayContent(int week, String day, String avg) {
    return '第$week週まで、最も忙しい日は **$day** で、平均 **$avg** コマ';
  }

  @override
  String get statisticsStoryLightestDayTitle => '最も楽な日';

  @override
  String statisticsStoryLightestDayContent(int week, String day, String avg) {
    return '第$week週まで、最も楽な日は **$day** で、わずか **$avg** コマ';
  }

  @override
  String get statisticsStoryFavoriteRoomTitle => 'よく行く教室';

  @override
  String statisticsStoryFavoriteRoomContent(int week, String room, int count) {
    return '第$week週まで、最もよく行く教室は **$room** で、**$count** 回';
  }

  @override
  String get statisticsStoryBuildingCountTitle => 'キャンパス探検';

  @override
  String statisticsStoryBuildingCountContent(int week, int count) {
    return '第$week週まで、授業は **$count** 棟の建物に分散';
  }

  @override
  String get statisticsStoryTimeRangeTitle => '時間帯';

  @override
  String statisticsStoryTimeRangeContent(String earliest, String latest) {
    return '最も早い授業は **$earliest**、最も遅い授業は **$latest**';
  }

  @override
  String get statisticsSemesterLabelCourses => '科目';

  @override
  String get statisticsSemesterLabelSections => 'コマ';

  @override
  String get statisticsSemesterLabelWeeks => '週';

  @override
  String get statisticsSemesterLabelDayStreak => '日連続';

  @override
  String get statisticsAchievementsTitle => '実績バッジ';

  @override
  String get statisticsStoriesTitle => 'データストーリー';

  @override
  String get statisticsRankingTitle => '科目ランキング';

  @override
  String get statisticsNoDataHint => '授業を追加すると統計を表示できます';

  @override
  String get statisticsShareLabel => '統計を共有';

  @override
  String get statisticsShareTitle => '学期の統計';

  @override
  String statisticsRankingSlotDetail(
    String day,
    int startSection,
    int endSection,
  ) {
    return '$day $startSection-$endSection限';
  }

  @override
  String get statisticsAchievementEarlyBirdName => '早八戦士';

  @override
  String get statisticsAchievementEarlyBirdDescription => '8:00の授業あり';

  @override
  String get statisticsAchievementPerfectAttendanceName => '皆勤賞';

  @override
  String get statisticsAchievementPerfectAttendanceDescription => '毎週欠席なしの科目';

  @override
  String get statisticsAchievementWeekendWarriorName => '週末戦士';

  @override
  String get statisticsAchievementWeekendWarriorDescription => '週末に授業あり';

  @override
  String get statisticsAchievementClassKingName => '授業王';

  @override
  String get statisticsAchievementClassKingDescription => '1日6コマ以上';

  @override
  String get statisticsAchievementScholarName => '勉強家';

  @override
  String get statisticsAchievementScholarDescription => '総コマ数100以上';

  @override
  String get statisticsAchievementBalancedName => 'バランスマスター';

  @override
  String get statisticsAchievementBalancedDescription => '曜日間の差が2コマ以内';

  @override
  String get statisticsAchievementNightOwlName => '夜型';

  @override
  String get statisticsAchievementNightOwlDescription => '18:00以降の授業あり';

  @override
  String get statisticsAchievementExplorerName => '教室探検家';

  @override
  String get statisticsAchievementExplorerDescription => '5つ以上の教室を使用';

  @override
  String statisticsNatureLegendDetail(int count, int sections) {
    return '$count 科目 · $sections コマ';
  }

  @override
  String get weekListSeparator => '、';

  @override
  String courseWeekListLabel(String weeks) {
    return '第$weeks週';
  }

  @override
  String courseWeekRangeLabel(int startWeek, int endWeek, String mode) {
    return '第$startWeek-$endWeek週$mode';
  }

  @override
  String courseWeekSuspendedLabel(String weeks) {
    return '第$weeks週休講';
  }

  @override
  String get importSemesterStartDateTitle => '学期開始日';

  @override
  String get importSemesterStartDateSubtitle => 'この日を含む週を校歴第1週として扱います';

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
  String get syncErrorSyncFailed => '同期に失敗しました';

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
  String get holidayStatutoryLabel => '祝日';

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
  String get logLiveUpdateSuspendTriggersFailed =>
      'Failed to suspend Live Island schedule triggers';

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
  String get logLanEditProfileSwitched =>
      'LAN edit: timetable profile switched';

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
