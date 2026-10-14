import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../logging/app_debug_log.dart';
import '../logging/app_log_messages.dart';
import '../models/bing_wallpaper.dart';
// 鍙负 `parseBingWallpaperDateKey`锛堝垽銆岃繖鏉?dateKey 鏄笉鏄粖澶┿€嶏級寮曡繖涓€鏉°€?
// 瀹冧綇鍦ㄦ樉绀虹敤鐨勫伐鍏锋枃浠堕噷锛屼絾**涓嶅惈浠讳綍 l10n 璋冪敤**锛岀函瀛楃涓茶В鏋愶紱鎼幓 model 浼?
// 鐗靛姩涓€澶勫凡閫氳繃鐨勬祴璇曚笌绗旇閲岀殑璺緞寮曠敤锛屼负涓€涓函鍑芥暟涓嶅€煎緱銆傝嫢鏃ュ悗閭ｈ竟鐪熺殑寮€濮?
// 渚濊禆 l10n锛屾纭仛娉曟槸鎶婅繖涓В鏋愬嚱鏁版惉杩?`bing_wallpaper.dart`锛坢odel 鑷繁瑙ｆ瀽
// 鑷繁鐨勫瓧娈碉級锛岃€屼笉鏄 service 鍙嶅悜渚濊禆鐣岄潰灞傘€?
import '../utils/bing_wallpaper_date_label.dart';
import '../utils/encoded_image_size.dart';
import '../utils/home_page_background.dart';
import '../utils/managed_image_storage.dart';
import '../utils/wallpaper_history.dart';
import 'app_http_client.dart';
import 'app_log_service.dart';
import 'bing_wallpaper_store.dart';
// 鍙负娓呯悊鍙拌处婧㈠嚭鏂囦欢鏃跺彇鍏ㄥ眬銆屾渶杩戜娇鐢ㄣ€嶅綋鐧藉悕鍗曪紙瑙?[_deleteEvictedWallpapers]锛夈€?
// 涓嶈蛋 `TimetableProvider` 鏄埢鎰忕殑锛岃鏈被椤堕儴娉ㄩ噴銆?
import 'wallpaper_history_service.dart';

/// 涓€娆′笅杞界殑**缁撴灉**锛氭垚鍔熺粰 [path]锛屽け璐ョ粰 [failure] / [statusCode]銆?
///
/// [resolution] 鍙湪鎴愬姛鏃舵湁鎰忎箟锛屼笖鏄?*瀹為檯**妗ｄ綅鑰屼笉鏄敤鎴烽€夌殑閭ｆ。 鈥斺€?涓棿妗ｅ伓灏旂己
/// 锛堣 [BingWallpaperResolution.fallbackResolution]锛夛紝杩欐椂瀹冩槸閫€鍥炵殑
/// [BingWallpaperResolution.standard]銆俒downgraded] 鏄粰鐣岄潰鎻愮ず鐢ㄧ殑閭ｄ釜淇″彿銆?
///
/// 鍒绘剰鍋氭垚**闈炵┖**锛堟垚鍔熷け璐ラ兘鏄畠锛夎€屼笉鏄€屽け璐ヨ繑鍥?null銆嶏細2026-10-06 鐢ㄦ埛鎶?
/// 銆岀偣澶у浘涓嬭浇澶辫触銆嶅嵈鏌ヤ笉鍑哄師鍥狅紝鏍瑰洜灏辨槸 null 鎶娿€孊ing 璇磋繖寮犳病鏈夈€?404) 涓?
/// 銆屾柇缃戜簡銆嶅帇鎴愪簡鍚屼竴涓€笺€傚け璐ュ師鍥犺鑳戒竴璺€佸埌鐢ㄦ埛鐪煎墠涓庢棩蹇楅噷銆?
class BingWallpaperDownload {
  const BingWallpaperDownload._({
    required this.path,
    required this.resolution,
    required this.downgraded,
    this.failure,
    this.statusCode,
    this.contentType,
    this.detail,
  });

  const BingWallpaperDownload.success({
    required String path,
    required BingWallpaperResolution resolution,
    required bool downgraded,
  }) : this._(
         path: path,
         resolution: resolution,
         downgraded: downgraded,
       );

  /// 鐢变竴娆″簳灞傚皾璇曠殑缁撴灉鏋勯€狅紙澶辫触鏃舵妸**鍘熷洜**涓€骞跺甫璧帮級銆?
  ///
  /// 蹇呴』鏄?`factory` 鑰屼笉鏄?const 杞彂鏋勯€狅細杞彂鏋勯€犲櫒閲岃鍙傛暟涓婄殑瀛楁鏄潪娉曠殑
  /// 锛坄attempt.statusCode` 涓嶆槸缂栬瘧鏈熷父閲忥級銆?
  factory BingWallpaperDownload.fromAttempt(ManagedImageDownloadResult attempt) =>
      BingWallpaperDownload._(
        path: attempt.path,
        resolution: null,
        downgraded: false,
        failure: attempt.failure,
        statusCode: attempt.statusCode,
        contentType: attempt.contentType,
        detail: attempt.detail,
      );

  /// 閫€妗ｅ悗鎷垮埌鐨勯偅涓€妗ｏ紙`downgraded` 鎭掍负 true锛夈€?
  factory BingWallpaperDownload.successWithFallback({
    required String path,
    required BingWallpaperResolution resolution,
  }) => BingWallpaperDownload._(
    path: path,
    resolution: resolution,
    downgraded: true,
  );

  final String? path;

  /// 鐪熸涓嬪埌鎵嬬殑閭ｄ竴妗ｏ紙鍙拌处瑕佽瀹冿紝涓嶆槸鐢ㄦ埛閫夌殑閭ｆ。 鈥斺€?鍚﹀垯鍚屼竴涓枃浠跺悕浼氳
  /// 涓ゆ。鍏辫锛屽幓閲嶄笌灏侀《娓呯悊閮借窡鐫€绠楅敊锛夈€?
  final BingWallpaperResolution? resolution;

  /// 鏄惁鍥犳墍閫夋。浣嶇己澶辫€岄€€浜嗘。銆?
  final bool downgraded;

  /// 涓ゆ。閮芥病鎷垮埌鏃剁殑鍘熷洜锛涙垚鍔熶负 null銆?
  final ManagedImageDownloadFailure? failure;

  /// 鎷垮緱鍒板搷搴旀椂鐨?HTTP 鐘舵€佺爜锛堢敤鏉ュ尯鍒嗐€孊ing 娌¤繖寮犲浘銆嶄笌銆屾柇缃戙€嶏級銆?
  final int? statusCode;

  final String? contentType;

  /// 澶辫触鐜板満鍘熸枃锛堝紓甯哥被鍨?+ message 涔嬬被锛夛紝瑙?[ManagedImageDownloadResult.detail]銆?
  final String? detail;

  bool get succeeded => path != null;

  /// 涓€琛屽彲鐩存帴杩涙棩蹇楃殑鎻忚堪銆?
  String describe() => succeeded
      ? 'ok tier=${resolution?.name} downgraded=$downgraded path=$path'
      : 'failed=$failure status=$statusCode contentType=$contentType '
            'detail=$detail';
}

/// 銆屼粖澶╄嚜鍔ㄦ崲銆嶈繖涓€娆″皾璇曠殑**缁撳眬**銆?
///
/// ## 涓轰粈涔堜笉璁?[BingWallpaperService.maybeApplyDaily] 缁х画鍙洖 `String?`
///
/// 鏃╁厛鐨勭鍚嶆槸銆屾垚鍔熺粰璺緞銆佸叾浣欎竴寰?null銆嶏紝鑰?null 鍘嬬潃浜旂瀵圭敤鎴锋剰涔夊畬鍏ㄤ笉鍚岀殑
/// 缁撳眬锛氭病寮€ / 浠婂ぉ宸叉崲杩?/ 鎹笂浜?/ 鎹笂鐨勬槸鏃у浘 / 娌℃崲鎴愩€傝皟鐢ㄦ柟鎷垮埌 null 鍙兘
/// 浠€涔堥兘涓嶅仛锛屼簬鏄?2026-10-06 鐢ㄦ埛鎶ャ€岀偣浜嗗紑鍏虫病鍙嶅簲銆嶁€斺€旂湡鍑舵槸
/// [appliedStale]锛圔ing 杩樻病鏀惧嚭浠婂ぉ閭ｅ紶锛夛紝鑰屽畠鍜屻€岀綉缁滄柇浜嗐€嶅湪鐣岄潰涓婇暱寰椾竴妯′竴鏍枫€?
/// 鎷嗗紑涔嬪悗锛岃缃〉鑳界粰姣忎竴绉嶈璇磋瘽鐨勫満鏅竴鍙ヨ瘽锛屽惎鍔ㄨ矾寰勪篃鑳界収鏍锋妸鍥炬崲涓娿€?
enum BingAutoApplyOutcome {
  /// 鍔熻兘娌″紑锛坄autoApplyEnabled` 涓?false锛夈€?
  disabled,

  /// 杩欏紶鍥句粖澶╁凡缁忔崲杩囦簡锛屽垽鎹湪涓嬭浇涔嬪墠灏辨嫤浣忎簡锛堝箓绛夛級銆?
  alreadyApplied,

  /// 鎹笂浜?*浠婂ぉ**閭ｅ紶銆?
  appliedToday,

  /// 鎹笂浜?Bing 鎵嬩笂**鏈€鏂?*鐨勯偅寮狅紝浣嗗畠骞朵笉鏄粖澶╃殑鍥俱€?
  ///
  /// 2026-10-06 瀹炴祴锛氬寳浜椂闂?19:20锛圔ing 鏈嶅姟鍣ㄧ殑 HTTP `Date` 澶翠笌鏈満鏃堕挓鏍稿杩囷紝
  /// 宸?1 绉掑唴锛夛紝Bing 鍒楄〃棣栭」**浠嶆槸 10-05**銆侭ing 浠€涔堟椂鍊欐斁鍑哄綋澶╅偅寮犱笉鐢辨湰 App
  /// 鎺у埗锛屾墍浠ャ€岄椤逛笉鏄粖澶┿€嶅湪缁濆ぇ澶氭暟鏃ュ瓙閲屾牴鏈笉鏄€岄敊銆嶏紝鍙槸銆岃繕娌¤疆鍒般€嶃€?
  appliedStale,

  /// 鎷変笉鍒版竻鍗曪紝鎴栧浘娌′笅涓嬫潵銆?
  failed,
}

/// 涓€娆¤嚜鍔ㄦ崲鐨勭粨鏋滐細[outcome] 璇存槑鍙戠敓浜嗕粈涔堬紱[path] 鍙湪鐪熺殑鎹笂鏃堕潪绌恒€?
class BingAutoApplyResult {
  const BingAutoApplyResult(this.outcome, [this.path, this.dateKey]);

  final BingAutoApplyOutcome outcome;

  /// 鎹笂鍘婚偅寮犲浘鐨勬湰鍦拌矾寰勩€?
  final String? path;

  /// 鎹笂鍘婚偅寮犲浘**鑷繁**鐨?`dateKey`銆?*鍙兘涓嶆槸浠婂ぉ**锛堣
  /// [BingAutoApplyOutcome.appliedStale]锛夈€?
  final String? dateKey;

  bool get succeeded => path != null;
}

/// Bing 姣忔棩澹佺焊鐨勬媺鍙栦笌涓嬭浇銆?
///
/// 涓€娆″垪琛ㄨ姹傚氨鑳芥嬁鍒版渶杩?[kBingWallpaperDays] 澶╋紙瀹炴祴 `n=8` 杩斿洖 5.2 KB锛夛紝
/// 鎵€浠ャ€屾祻瑙堝浘搴撱€嶄笌銆屾瘡澶╄嚜鍔ㄦ崲銆嶅叡鐢ㄥ悓涓€鏉￠摼璺紝宸埆鍙湪浜庤涓嶈钀界洏銆?
///
/// ## 涓夋潯鍙ｅ緞
///
/// * **娴忚涓嶄笅杞?*锛氬浘搴撻〉闈㈠彧鐢?[BingWallpaperItem.thumbnailUrl] 鐨?480脳854 灏忓浘
///   锛堢害 105 KB/寮狅紝8 寮犵害 840 KB锛夈€傚彧鏈夌敤鎴风偣鏌愪竴寮犳墠涓嬪師鍥俱€?
/// * **澶辫触涓€寰嬮潤榛?*锛氭湰绫绘寕鍦ㄥ惎鍔ㄨ矾寰勪笂锛堣嚜鍔ㄦ崲锛夛紝浠讳綍寮傚父閮借嚜宸卞悶鎺夊苟璁颁竴绗旀棩蹇楋紝
///   杩斿洖 null 琛ㄧず銆屼粖澶╂病鏈夊彲鎹㈢殑鍥俱€嶃€傜粷涓嶆妸閿欒鎶涚粰璋冪敤鏂广€?
/// * **涓嶄緷璧?[TimetableProvider]**锛氬彧璐熻矗銆岀畻鍑鸿鐢ㄥ摢涓湰鍦版枃浠躲€嶏紝鍐欒缃偅涓€姝ュ湪
///   `main.dart`銆傝繖鏄负浜嗗畧浣?`timetable_provider.dart` 鐨勬墖鍏ユ杞?
///   锛堣 `test/architecture/dependency_guards_test.dart`锛夈€?
class BingWallpaperService {
  /// 鈿狅笍 `_ownsClient` 鐨勭畻娉?*涓嶈兘**鍐欓敊锛屽惁鍒欎細鎶?*鍏ㄨ繘绋嬪叡浜?*鐨?client 鍏虫帀銆?
///
/// [createAppHttpClient] 鍦?debug/profile 涓嬭繑鍥炵殑鏄?BlackBox 閭ｄ釜**鍏变韩** client锛?
/// 鍏虫帀瀹冧箣鍚庯紝鍚岃繘绋嬪唴鎵€鏈夎蛋瀹冨垱寤?client 鐨勬湇鍔★紙澶╂皵銆佽妭鍋囨棩鍚屾銆佺増鏈鏌モ€︼級
/// 闅忓悗鐨勮姹傚叏閮ㄦ姏寮傚父銆傛墍浠ユ寜 `WeatherService` / `HolidayService` 鐨勫悓娆惧啓娉曪細
/// `client == null && !isSharedAppHttpClient(_client)` 鈥斺€?**鑷繁 new 鍑烘潵鐨?*
/// 鎵嶅綊鑷繁鍏炽€?
///
/// 锛?026-10-06 瀹炶俯锛氳繖閲屾浘鍐欐垚 `client == null || !isSharedAppHttpClient(client)`
/// 鈥斺€?涓や釜閿欏彔鍔犳垚鎭?`true`锛屼簬鏄浘搴撻〉 `loadItems()` 涓€ `dispose()` 灏辨妸鍏变韩 client
/// 鍏充簡锛岀敤鎴风揣鎺ョ潃鐐逛换浣曚竴寮犲浘閮?`failed=network`銆傝〃鐜版槸銆屽垪琛ㄨ兘鍑恒€佸浘涓嬩笉鏉ャ€嶏紝
/// 鏍瑰洜鍗村湪绂讳笅杞戒笁琛岃繙鐨勫湴鏂广€傦級
BingWallpaperService({http.Client? client})
    : this._internal(client ?? createAppHttpClient(), client == null);

BingWallpaperService._internal(this._client, bool ownsCandidate)
    : _ownsClient = ownsCandidate && !isSharedAppHttpClient(_client);

  /// `appDebugLog` 鐨?tag銆俫rep 杩欎釜涓插氨鑳芥嬁鍒版湰鍔熻兘鐨勫叏閮ㄦ帓闅滆建杩广€?
  static const String _tag = 'BingWallpaper';

  /// 涓€娆℃媺鍑犲ぉ鐨勫浘銆侭ing 鍦?`n=8` 涓婄粰婊★紝鍐嶅涓嶄繚璇併€?
  static const int kBingWallpaperDays = 8;

  /// 鍒楄〃璇锋眰鍦板潃妯℃澘銆?
  ///
  /// `mkt=zh-CN` 璁╃増鏉冭鏄庡彉鎴愪腑鏂囷紙瀹炴祴杩斿洖銆岄樋寰峰埄浼侀箙锛屽崡鏋佹床 (? 鈥?銆嶏紝
  /// 鍝嶅簲鏄悎娉?UTF-8锛夈€侭ing 瀵?`mkt` 鏃犻壌鏉冭姹傘€?
  static const String _listEndpoint =
      'https://www.bing.com/HPImageArchive.aspx'
      '?format=js&idx=0&n=$kBingWallpaperDays&mkt=zh-CN';

  /// 鍒楄〃璇锋眰瓒呮椂銆傜粰 8 绉掞紝涓?`holiday_service` 鍚屾。锛氳繖鏄釜銆岄敠涓婃坊鑺便€嶇殑璇锋眰锛?
  /// 鍗′綇姣斿け璐ユ洿绯熴€?
  static const Duration _listTimeout = Duration(seconds: 8);

  final http.Client _client;
  final bool _ownsClient;

  /// 鍙粰娴嬭瘯鐢ㄧ殑鏋勯€犻挬瀛愶細鎶?`maybeApplyDaily` / `loadItems` 鍐呴儴**鑷缓**鐨?
  /// service 鎸囧悜涓€涓?`MockClient`銆?
  ///
  /// ## 涓轰粈涔堥渶瑕佽繖涓挬瀛?
  ///
  /// 閭ｄ袱涓叆鍙ｅ埢鎰忚嚜宸?`BingWallpaperService()` 鍐?`dispose()`锛氳嚜鍔ㄦ崲鎸傚湪
  /// `main.dart` 鐨勫惎鍔ㄦ祦绋嬩笂锛屾病鏈夎皟鐢ㄦ柟鎸佹湁 client 鍙紶锛屼簬鏄笉鑳藉湪娴嬭瘯閲屾敞鍏ャ€?
  /// 涓庡叾鍦ㄧ敓浜т唬鐮侀噷涓烘祴璇曞紑涓€涓暱鏈熷彛瀛愶紝涓嶅鐣欎竴涓?*鍙湪娴嬭瘯閲岃祴鍊?*鐨勯挬瀛愩€?
  @visibleForTesting
  static http.Client Function()? testClientFactory;

  /// 鑷缓涓€涓?service锛涙祴璇曢挬瀛愬湪鍦烘椂鐢ㄥ畠鎻愪緵鐨?client銆?
  static BingWallpaperService _createInternal() =>
      BingWallpaperService(client: testClientFactory?.call());

  /// 鑷缓涓€涓€岀敤瀹屽嵆寮冦€嶇殑 service 鈥斺€?[loadItems] / [maybeApplyDaily] / 鍥惧簱椤?
  /// **涓夊閮借璧拌繖涓€鏉?*锛屼笉瑕佺洿鎺?`BingWallpaperService()`銆?
  ///
  /// 璧?[_createInternal] 鐨勭悊鐢憋細娴嬭瘯鐨?`testClientFactory` 閽╁瓙鍙寕鍦ㄨ繖涓€鏉¤矾涓娿€?
  /// 鏃╁墠鍥惧簱椤靛湪 `_pick` 閲岀洿鎺?`BingWallpaperService()`锛岀粫杩囦簡閽╁瓙锛屼簬鏄崟娴嬮噷閭ｆ潯
  /// 鍥剧墖璇锋眰钀藉埌浜?Flutter 娴嬭瘯鑷甫鐨?HttpClient 涓婏紙鎭掑洖 400锛夛紝琛ㄧ幇涓恒€岀偣浜嗗浘鍗?
  /// 涓嬭浇澶辫触銆佸洖璋冧篃涓嶈Е鍙戙€嶁€斺€?鐪嬬潃鍍忓姛鑳藉潖浜嗭紝鍏跺疄鏄祴璇曟病鎺ヤ笂銆?
  static BingWallpaperService createTransient() => _createInternal();

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// 鎷夋渶杩?[kBingWallpaperDays] 澶╃殑澹佺焊娓呭崟锛涘け璐ヨ繑鍥炵┖鍒楄〃銆?
  ///
  /// 瑙ｆ瀽涓婄殑涓や釜瑕佺偣锛?
  /// * `format=js` 杩斿洖鐨勬槸**鏍囧噯 JSON**锛堜笉鏄煇浜涙帴鍙ｉ偅绉?key 涓嶅甫寮曞彿鐨勪吉 JS锛夛紝
  ///   鎵€浠ヨ兘鐩存帴 `jsonDecode`锛?
  /// * 閫愭潯涓㈠純鑴忔暟鎹€屼笉鏄暣浠戒綔搴燂紙瑙?`BingWallpaperItem.listFromJson`锛夆€斺€?
  ///   Bing 鏀瑰瓧娈垫椂涓嶈璁╂暣涓浘搴撶┖鎺夈€?
  Future<List<BingWallpaperItem>> fetchRecent() async {
    try {
      appDebugLog(_tag, 'list start');
      final response = await _client
          .get(
            Uri.parse(_listEndpoint),
            headers: const {'User-Agent': 'mikcb-wallpaper'},
          )
          .timeout(_listTimeout);
      if (response.statusCode != 200) {
        appDebugLog(_tag, 'list failed status=${response.statusCode}');
        await _logWarn('bing_wallpaper_list_status', null);
        return const [];
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        appDebugLog(_tag, 'list malformed: body is not a JSON object');
        await _logWarn('bing_wallpaper_list_malformed', null);
        return const [];
      }
      final items = BingWallpaperItem.listFromJson(decoded['images']);
      appDebugLog(
        _tag,
        'list ok count=${items.length} '
        'first=${items.isEmpty ? "-" : items.first.dateKey}',
      );
      if (items.isEmpty) {
        await _logWarn('bing_wallpaper_list_empty', null);
      }
      return items;
    } on Object catch (error, stackTrace) {
      appDebugLog(_tag, 'list threw: $error');
      await _logWarn('bing_wallpaper_list_failed', error, stackTrace);
      return const [];
    }
  }

  /// 鎶?[item] 涓嬪埌鏈湴澹佺焊鐩綍銆?
  ///
  /// 鎵€閫夋。浣嶆嬁涓嶅埌鏃舵寜 [BingWallpaperResolution.fallbackResolution] 閫€涓€妗ｉ噸璇曪紝
  /// 鑰屼笉鏄洿鎺ュけ璐?鈥斺€?Bing 骞堕潪姣忓ぉ閮介鐢熸垚 1920脳1200锛屽疄娴?24 澶╅噷缂?1 澶╋紝
  /// 鑰岄偅涓€寮犲父甯稿氨鍦ㄧ敤鎴风溂鍓嶇殑鍥惧簱閲屻€?
  Future<BingWallpaperDownload> download(
    BingWallpaperItem item,
    BingWallpaperResolution resolution,
  ) async {
    final direct = await _downloadAt(item, resolution);
    if (direct.succeeded) {
      return BingWallpaperDownload.success(
        path: direct.path!,
        resolution: resolution,
        downgraded: false,
      );
    }
    final fallback = resolution.fallbackResolution;
    // 鈿狅笍 鍙湪銆孊ing 璇磋繖寮犳病鏈?/ 缁欑殑涓嶆槸鍥俱€嶆椂閫€妗ｉ噸璇曘€傛柇缃戙€佽秴鏃躲€佺鐩樺啓涓嶈繘
    // 閮?*涓嶆槸**缂烘。锛氭崲涓昂瀵搁噸涓嬪悓涓€寮犲浘鐓ф牱浼氬け璐ワ紝鑰岄偅鎰忓懗鐫€鐢ㄦ埛瀵圭潃涓€涓?
    // 杞湀鐨勮繘搴︽潯鐧界瓑涓や釜 20 绉掕秴鏃讹紙2026-10-06 review 瀹炴祴鐨勫彛寰勶級銆?
    // 鎹㈠彞璇濊锛氶€€妗ｈВ鍐崇殑鏄€岃繖涓昂瀵镐笉瀛樺湪銆嶏紝涓嶆槸銆岀綉缁滃潖浜嗐€嶃€?
    if (fallback == null || !_isMissingTier(direct.failure)) {
      return BingWallpaperDownload.fromAttempt(direct);
    }
    final retry = await _downloadAt(item, fallback);
    if (retry.succeeded) {
      return BingWallpaperDownload.successWithFallback(
        path: retry.path!,
        resolution: fallback,
      );
    }
    // 涓ゆ。閮藉け璐ワ細鎶?*鎵€閫?*閭ｄ竴妗ｇ殑澶辫触鍘熷洜锛堢敤鎴烽€夌殑灏辨槸瀹冿紝閫€妗ｅ彧鏄唴閮ㄥ厹搴曪級銆?
    return BingWallpaperDownload.fromAttempt(direct);
  }

  /// [failure] 鏄笉鏄€岃繖涓昂瀵?Bing 鏍规湰娌＄粰銆嶉偅涓€绫汇€?
  ///
  /// 鍙湁 [ManagedImageDownloadFailure.status]锛堝涓?404锛変笌
  /// [ManagedImageDownloadFailure.notImage]锛圔ing 瀵规湭鐭ュ昂瀵稿洖 HTML 閿欒椤碉紝涓旂姸鎬佺爜
  /// 鍋跺皵浠嶆槸 200锛夋墠鍊煎緱閫€妗ｃ€俙network` / `emptyBody` / `write` 涓庡昂瀵告棤鍏筹紝閲嶈瘯鍙槸
  /// 鎶婁竴娆″け璐ユ嫋鎴愪袱娆¤秴鏃躲€?
  static bool _isMissingTier(ManagedImageDownloadFailure? failure) =>
      failure == ManagedImageDownloadFailure.status ||
      failure == ManagedImageDownloadFailure.notImage;

  /// 鍙笅涓€妗ｏ紝涓嶅仛閫€妗ｉ噸璇曘€傚け璐ユ椂缁撴灉閲屽甫鍘熷洜锛堜笉鎶涳級銆?
  ///
  /// [target] 鏄?*瀹為檯瑕佷笅鐨勫儚绱?*锛堥粯璁ゆ寜 [BingWallpaperResolution.downloadTargetSize]
  /// = 灞忓箷鍒嗚鲸鐜囦笌妗ｄ綅涓嬮檺鍙栧ぇ鑰咃級銆傚畠鍙備笌鏂囦欢鍚嶄笌鍙拌处閿?鈥斺€?鎹簡璁惧鎴栨崲浜嗘。浣嶅氨钀藉埌
  /// 涓嶅悓鏂囦欢涓婏紝涓嶄細鎶娿€屾寜 1080脳1920 涓嬭繃鐨勯偅寮犮€嶅綋鎴愩€屾寜 1206脳2622 涓嬭繃銆嶃€?
  Future<ManagedImageDownloadResult> _downloadAt(
    BingWallpaperItem item,
    BingWallpaperResolution resolution, {
    WallpaperTargetSize? target,
  }) async {
    final size = target ?? resolution.downloadTargetSize;
    final url = item.fullUrl(resolution, target: size);
    appDebugLog(
      _tag,
      'download start date=${item.dateKey} tier=${resolution.name} '
      'target=${size.width}x${size.height} $url',
    );
    final first = await _downloadVia(url, item, resolution, size);
    if (!first.succeeded) {
      return first;
    }
    // ⭐ 落盘后**验尺寸**（2026-10-14）：resize 接口会**静默降尺寸** —— 实测（两天 ×
    // 多组尺寸交叉验证）部分组合不服从请求，回一张高 ≤ 2592 的图；同参数重测结果
    // 一致（不是缓存抖动），且**带不带 qlt 都会发生**。「App 不再二次放大」的保证
    // 靠这道校验兜住。读的是编码头部（不整图解码），读不出就跳过校验，不阻断主流程。
    final expected = item.expectedSizeFor(resolution, target: size);
    final actual = await readEncodedImageSize(first.path!);
    if (actual == null) {
      appDebugLog(_tag, 'download size-check skipped (undecodable)');
      return first;
    }
    final (w, h) = actual;
    final meets = w >= expected.width && h >= expected.height;
    appDebugLog(
      _tag,
      'download size-check expected=${expected.width}x${expected.height} '
      'actual=${w}x$h meets=$meets',
    );
    if (meets) {
      return first;
    }
    // 换 **c=16** 重试一次：实测同一组合下 c=4 降尺寸时 c=16 常能给出精确尺寸
    // （例：1440×3840 —— c=4 回 1440×2592，c=16 回 1440×3840）。c=16 是另一种
    // 取样/裁切策略，构图可能与 c=4 略不同，但「不放大」的优先级更高。重试仍
    // 降尺寸就认了 —— 同一张图没有第三条路，别把用户晾在转圈里。
    final retryUrl = item.resizeUrl(
      width: size.width,
      height: size.height,
    ).replaceFirst('c=4', 'c=16');
    appDebugLog(
      _tag,
      'download retry(c=16) target=${size.width}x${size.height} $retryUrl',
    );
    final retry = await _downloadVia(retryUrl, item, resolution, size);
    if (!retry.succeeded) {
      // 重试失败：第一次那张虽小一号但真实存在，总好过什么都没有。
      return first;
    }
    final actual2 = await readEncodedImageSize(retry.path!);
    if (actual2 == null) {
      return retry;
    }
    final (w2, h2) = actual2;
    final meets2 = w2 >= expected.width && h2 >= expected.height;
    appDebugLog(_tag, 'download retry size-check actual=${w2}x$h2 meets=$meets2');
    return meets2 ? retry : first;
  }

  /// [url] 的纯下载落盘（无校验无重试），上面的尺寸校验重试共用它。
  Future<ManagedImageDownloadResult> _downloadVia(
    String url,
    BingWallpaperItem item,
    BingWallpaperResolution resolution,
    WallpaperTargetSize size,
  ) async {
    try {
      final result = await downloadToManagedImage(
        url: Uri.parse(url),
        directoryName: kHomePageWallpaperDirectoryName,
        // ⭐ 前缀必须是 `wallpaper`：既有的 `deleteEvictedWallpaperFiles` 按这个前缀
        // 判定「这张图归我管」，改名成别的开头会导致它被挤出历史后删不掉（见
        // `BingWallpaperItem.fileName` 的注释）。
        fileName: item.fileName(resolution, target: size),
        client: _client,
      );
      // 每一次尝试都留一行 —— 2026-10-06 用户报「点大图下载失败」而四条分支全都只回
      // null、且日志写进了默认关闭的 AppLogService，于是无从查起（见笔记）。
      // `appDebugLog` 在 debug 下直接进 logcat，不需要用户先开「本地诊断」。
      appDebugLog(
        _tag,
        'download result tier=${resolution.name} ${result.describe()}',
      );
      if (!result.succeeded) {
        await _logWarn('bing_wallpaper_download_failed', result.describe());
      }
      return result;
    } on Object catch (error, stackTrace) {
      appDebugLog(_tag, 'download threw: $error');
      await _logWarn('bing_wallpaper_download_failed', error, stackTrace);
      return const ManagedImageDownloadResult.failed(
        ManagedImageDownloadFailure.network,
      );
    }
  }

  /// 娓呭崟缂撳瓨澶氫箙灏遍噸鏂版媺銆?
  ///
  /// 鍙?3 灏忔椂锛欱ing 姣忓ぉ鎹竴娆★紝鑰屻€屾瘡澶╅娆℃墦寮€ App 鑷姩鎹€嶈繖鏉′富璺緞鏈潵灏卞甫
  /// 鐙珛鐨勬寜澶╁垽鎹紙[BingWallpaperStore.lastAutoAppliedDate]锛夛紝杩欓噷鐨?TTL 鍙敤鏉?
  /// 闃叉鐢ㄦ埛鍙嶅杩涘嚭璁剧疆椤垫椂鍙嶅璇锋眰銆?
  static const Duration _listCacheTtl = Duration(hours: 3);

  /// 瑕佸睍绀虹殑娓呭崟锛氬懡涓紦瀛樺氨鐩存帴缁欙紝鍚﹀垯鎷夌綉缁滃苟椤烘墜鏇存柊缂撳瓨銆?
  ///
  /// 缂撳瓨鏄?*璁惧绾у叏灞€**锛堝瓨 `BingWallpaperStore`锛夎€屼笉鏄瘡涓琛ㄤ竴浠斤細鍥惧簱鍐呭涓?
  /// 鐢ㄥ摢浠借琛ㄦ棤鍏炽€傚懡涓殑鍒ゆ嵁鏄€岀紦瀛樻椂闂村湪 TTL 鍐呬笖闈炵┖銆嶁€斺€?绌哄垪琛ㄤ篃绠楁湭鍛戒腑锛?
  /// 鍚﹀垯涓€娆″け璐ヤ細琚紦瀛?3 灏忔椂锛岀敤鎴峰綋澶╁啀涔熺湅涓嶅埌鍥惧簱銆?
  ///
  /// ## [allowStaleFallback]锛氬彧缁?*灞曠ず**鐢紝涓嶇粰鑷姩鎹㈢敤
  ///
  /// 榛樿鍏崇潃銆傚紑鐫€鏃讹紝缂撳瓨杩囨湡涓旂綉缁滄媺涓嶅埌浼?*杩斿洖杩囨湡缂撳瓨**鑰屼笉鏄┖鍒楄〃 鈥斺€?
  /// 瀹佸彲缁欐棫鐨勶紝涓嶈缁欑┖鍥惧簱銆?
  ///
  /// 鈿狅笍 鑷姩鎹㈤偅鏉¤矾寰?*涓嶈兘**寮€锛歚maybeApplyDaily` 鎷垮埌绌烘竻鍗曟椂杩斿洖 `failed`锛?
  /// 如实失败一次（记日志），而不是拿一张旧图顶上、用户毫不知情。所以只有图库页
  /// 显式传 true。
  static Future<List<BingWallpaperItem>> loadItems({
    bool forceRefresh = false,
    bool allowStaleFallback = false,
  }) async {
    final store = BingWallpaperStore.instance;
    if (!forceRefresh) {
      final cached = store.cachedItems;
      final cachedAt = store.cachedItemsFetchedAt;
      final fresh = cachedAt != null &&
          DateTime.now().difference(cachedAt) < _listCacheTtl;
      if (cached.isNotEmpty && fresh) {
        return cached;
      }
    }
    final service = _createInternal();
    final List<BingWallpaperItem> fetched;
    try {
      fetched = await service.fetchRecent();
    } finally {
      service.dispose();
    }
    if (fetched.isNotEmpty) {
      await store.saveCachedItems(fetched);
      return fetched;
    }
    // 鎷変笉鍒帮細灞曠ず璺緞缁欒繃鏈熺紦瀛橈紙瀹佸彲鏃х殑涓嶈绌哄浘搴擄級锛?
    // 鑷姩鎹㈣矾寰勫畞鍙┖ 鈥斺€?绌烘竻鍗曚細璁╁綋澶╂槑纭湴澶辫触涓€娆★紙璁版棩蹇楋級锛岃€屼笉鏄嬁鏃у浘
    // 瑁呬綔鎴愬姛銆?
    return allowStaleFallback ? store.cachedItems : const [];
  }

  /// 鑷姩鎹㈢殑鍒ゆ嵁 + 涓嬭浇銆?
  ///
  /// ## 銆屼粖澶╄繕娌℃湁銆嶄笉绛変簬銆屼粈涔堥兘涓嶅仛銆?
  ///
  /// 鏃╁厛杩欓噷鍦ㄣ€屾竻鍗曢椤逛笉鏄粖澶┿€嶆椂鐩存帴 `return null`锛岀悊鐢辨槸銆屽畞鍙粖澶╀笉鎹紝涔熶笉鑳?
  /// 鏇跨敤鎴锋寕涓€寮犻殧澶滅殑鍥俱€嶃€傛柟鍚戞病閿欙紝浣?*鎵嬫閿欎簡**锛氬畠鎶娿€孊ing 杩樻病鍑轰粖澶╃殑鍥俱€嶅垽鎴?
  /// 浜嗙粓灞€锛屼簬鏄粠閭ｄ竴鍒昏捣鍒板綋澶╃粨鏉燂紝鑷姩鎹竴鐩存槸姝荤殑锛岃€屼笖**闈欓粯鏃犲弽棣?*锛?026-10-06
  /// 鐢ㄦ埛鎶ャ€岀偣浜嗗紑鍏虫病鍙嶅簲銆嶆鏄繖鏉★級銆傜幇鍦ㄦ敼鎴愶細
  ///
  /// * 鍏堝己鍒堕噸鎷変竴娆★紝鍘绘帀銆? 灏忔椂鏃х紦瀛樸€嶈繖涓師鍥狅紱
  /// * 閲嶆媺涔嬪悗棣栭」**浠嶇劧**涓嶆槸浠婂ぉ锛屽氨**鐢ㄥ畠椤朵笂**锛?
  /// * 璁拌处鐢ㄧ殑鏄?*閭ｅ紶鍥捐嚜宸辩殑** `dateKey`锛屼笉鏄€屼粖澶┿€嶁€斺€?鎵€浠?Bing 涔嬪悗鐪熺殑鏀惧嚭
  ///   浠婂ぉ閭ｅ紶鏃讹紝鍒ゆ嵁锛坄lastAutoAppliedDate` 鈮?鏈€鏂伴偅寮犵殑 `dateKey`锛変細鑷劧鏀捐锛?
  ///   褰撳ぉ鍐嶆崲涓€娆℃纭殑銆?*涓€澶╂渶澶氭崲涓ゆ锛屼笉浼氶噸澶嶃€佷篃涓嶄細閿欒繃銆?*
  ///
  /// 鎴愬姛鏃?*鍙?*璁?[BingWallpaperStore.lastAutoAppliedDate] 涓庢枃浠跺彴璐︼紝
  /// **涓嶇銆屾渶杩戜娇鐢ㄣ€嶅巻鍙?*锛堢悊鐢辫绗旇銆岃嚜鍔ㄦ崲涓嶈繘鍘嗗彶銆嶏級銆?
  ///
  /// [now] 鍙粰娴嬭瘯鐢細鍗曟祴鎶娿€屼粖澶┿€嶉拤鍦ㄥ浐瀹氭棩鏈熶笂锛屼笉蹇呰窡鐫€娴嬭瘯杩愯鏃跺埢婕?
/// 锛堜笌 `bingWallpaperDateLabel` 鐨?`now` 鍚屼竴鍙ｅ緞锛夈€?
///
/// [inUsePaths] 璇蜂紶**鎵€鏈夎琛?*褰撳墠鐨勫绾歌矾寰勶紙瑙?`inUseWallpaperPaths`锛夛細娓呯悊
/// 鍙拌处婧㈠嚭鐨勬枃浠舵椂瑕佺敤瀹冨綋鐧藉悕鍗曘€傛湰鏈嶅姟鍒绘剰涓嶄緷璧?`TimetableProvider`锛堣绫绘敞閲婏級锛?
/// 鎵€浠ヨ繖涓泦鍚堝彧鑳界敱璋冪敤鏂圭粰 鈥斺€?浼犵┖闆嗗悎鐨勫悗鏋滄槸銆屾煇寮犳琚綋澹佺焊鐨勫浘琚垹鎺夈€嶏紝
/// 琛ㄧ幇涓洪椤靛綋鍦鸿鍥俱€傚姞杞戒笌鍘嗗彶閭ｄ唤鐢辨湰鏂规硶鑷繁鍙栥€?
static Future<BingAutoApplyResult> maybeApplyDaily({
  DateTime? now,
  Set<String> inUsePaths = const <String>{},
}) async {
    final store = BingWallpaperStore.instance;
    if (!store.autoApplyEnabled) {
      return const BingAutoApplyResult(BingAutoApplyOutcome.disabled);
    }
    final clock = now ?? DateTime.now();
    final items = await loadItems();
    if (items.isEmpty) {
      return const BingAutoApplyResult(BingAutoApplyOutcome.failed);
    }
    // 娓呭崟鎸夋柊鈫掓棫鎺掞紝棣栭」灏辨槸 Bing 鎵嬩笂鏈€鏂伴偅寮犮€?
    //
    // 鈿狅笍 棣栭」**涓嶄繚璇?*鏄粖澶╋細娓呭崟鏈?3 灏忔椂缂撳瓨锛岃€?Bing 浣曟椂鏀惧嚭褰撳ぉ閭ｅ紶涓嶇敱鏈?App
    // 鎺у埗锛堝疄娴嬫櫄鍒板崄鍑犱釜灏忔椂鏄父鎬侊紝瑙?[BingAutoApplyOutcome.appliedStale]锛夈€傛墍浠?
    // 棣栭」楠屼笉杩囨椂鍏堝己鍒堕噸鎷変竴娆★紝鍘绘帀銆屾棫缂撳瓨銆嶈繖涓師鍥狅紱**閲嶆媺鍚庝粛涓嶆槸浠婂ぉ灏辩敤瀹冮《涓?*銆?
    var newest = items.first;
    if (!_isToday(newest, clock)) {
      // 娉ㄦ剰绌烘竻鍗?*涓嶅啓缂撳瓨**锛堣 [loadItems]锛夛紝鎵€浠ヨ繖閲屼笉浼氭妸涓€娆″け璐ョ紦瀛樹綇銆?
      final refreshed = await loadItems(forceRefresh: true);
      if (refreshed.isNotEmpty) {
        newest = refreshed.first;
      }
    }
    final isToday = _isToday(newest, clock);
    // 銆屼粖澶╁凡鎹㈣繃銆嶅垽鎹細姣?`lastAutoAppliedDate`锛堥偅寮犲浘鑷繁鐨?dateKey锛?*鍙兘
    // 涓嶆槸浠婂ぉ**锛岃 [BingAutoApplyOutcome.appliedStale] 鐨勬敞閲?鈥斺€?姝ｅ洜涓鸿鐨勬槸
    // 閭ｅ紶鍥剧殑鏃ユ湡锛孊ing 鏀惧嚭浠婂ぉ閭ｅ紶鏃跺垽鎹細鑷劧鏀捐锛屽綋澶╁啀鎹竴娆★級銆?
    if (store.lastAutoAppliedDate == newest.dateKey) {
      return const BingAutoApplyResult(BingAutoApplyOutcome.alreadyApplied);
    }
    final resolution = store.resolution;
    final service = _createInternal();
    final BingWallpaperDownload result;
    try {
      result = await service.download(newest, resolution);
    } finally {
      service.dispose();
    }
    if (!result.succeeded) {
      return const BingAutoApplyResult(BingAutoApplyOutcome.failed);
    }
    // 涓嬭浇鎴愬姛**涔嬪悗**鎵嶈鏃ユ湡锛氳鏃╀簡浼氬湪涓嬭浇澶辫触鏃舵妸褰撳ぉ鍒ゆ垚銆屽凡鎹㈣繃銆嶏紝
    // 浜庢槸杩欎竴澶╁啀涔熶笉浼氶噸璇曪紙瑕佺瓑鐢ㄦ埛涓嬫鎵嬪姩杩涜缃〉鎵嶅彲鑳借ˉ涓婏級銆?
    //
    // 猸?璁扮殑鏄?*閭ｅ紶鍥捐嚜宸辩殑** `dateKey`锛?*涓嶆槸**鏈満浠婂ぉ 鈥斺€?杩欐槸銆屾嬁鏃у浘椤朵笂銆嶈兘澶?
    // 鑷剤鐨?*鍏ㄩ儴**鍘熷洜锛氫箣鍚?Bing 鏀惧嚭浠婂ぉ閭ｅ紶鏃讹紝鍒ゆ嵁浼氳嚜鐒舵斁琛屽苟鍐嶆崲涓€娆°€?
    //
    // 璁扮殑涔熸槸**瀹為檯**閭ｆ。锛堥€€妗ｅ悗灏辨槸 standard锛夛細鏂囦欢鍚嶄笌鍙拌处閿兘鐢卞畠鍐冲畾锛?
    // 璁扮敤鎴烽€夌殑閭ｆ。浼氳銆屽悓涓€寮犲浘涓ゆ。銆嶅叡鐢ㄤ竴涓枃浠跺悕骞惰鍘婚噸鎺変竴娆°€?
    // 鍙拌处鎸ゅ嚭鍘荤殑鍥捐鐪熷垹锛堣 [_deleteEvictedWallpapers]锛夈€?*涓?await**锛氳繖鏄惎鍔?/
    // 鍥炲墠鍙拌矾寰勶紝鍒犳枃浠舵槸鏀跺熬宸ヤ綔锛屼笉璇ヨ鐢ㄦ埛绛夈€?
    final evicted = await store.recordApplied(
      dateKey: newest.dateKey,
      resolution: result.resolution!,
      path: result.path!,
      // 璁?*瀹為檯**涓嬬殑閭ｇ粍鍍忕礌锛堣 [BingWallpaperResolution.downloadTargetSize]锛夛細
      // 鍙拌处閿惈灏哄锛屼笉璁板氨浼氭妸銆屾寜鏃у昂瀵镐笅杩囥€嶈鍒ゆ垚銆屾寜灞忓箷灏哄涓嬭繃浜嗐€嶃€?
      // 鈿狅笍 蹇呴』鏄?`result.resolution`锛堝疄闄呴偅妗ｏ紝閫€妗ｅ悗灏辨槸 standard锛夎€屼笉鏄笂闈?
      // 閭ｄ釜 `resolution`锛?*鐢ㄦ埛閫夌殑閭ｆ。**锛夛細璁伴敊鐨勮瘽锛屽悓涓€澶╁弽澶嶇偣鍚屼竴寮犱細閲嶅涓嬭浇锛?
      // 鑰屼笖鍙拌处閲屼細姘歌繙鐣欎竴涓寚鍚戜笉瀛樺湪鏂囦欢鐨勬潯鐩?鈥斺€?涓婇潰閭ｈ娉ㄩ噴鍐欑殑灏辨槸杩欎欢浜嬶紝
      // 浠ｇ爜鍘熷厛娌＄収鍋氥€?
      targetSize: result.resolution!.downloadTargetSize,
    );
    unawaited(_deleteEvictedWallpapers(evicted, inUsePaths: inUsePaths));
    appDebugLog(_tag, 'daily applied date=${newest.dateKey} isToday=$isToday');
    return BingAutoApplyResult(
      isToday
          ? BingAutoApplyOutcome.appliedToday
          : BingAutoApplyOutcome.appliedStale,
      result.path,
      newest.dateKey,
    );
  }

  /// 鍒犳帀鍙拌处鎸ゅ嚭鍘荤殑鍥撅紝骞舵寜銆岃皝杩樺湪鐢ㄣ€嶅姞鐧藉悕鍗曘€?
  ///
  /// 鈿狅笍 **蹇呴』鍒?*锛屽惁鍒欒嚜鍔ㄦ崲杩欐潯璺瓑浜庡彧鍐欎笉鏀讹細姣忓ぉ鎹竴寮犲氨姘镐箙澶氱暀涓€涓枃浠讹紝
  /// 鑰?[BingWallpaperStore.kMaxDownloadedEntries] 鍙崱浣?*璁拌处鏉＄洰**锛坄recordApplied`
  /// 鐨勬敞閲婁篃鍐欐槑銆屽彧璁拌处锛屼笉纰扮鐩樸€嶏級銆傛敀涓嬫潵鐨勯噺鎸夊疄娴嬩綋绉畻鏄竴骞?365 寮犮€佺害
  /// 118 MB锛堟爣鍑嗘。锛夊埌 279 MB锛堥珮娓呮。锛夆€斺€?閭ｄ釜涓婇檺褰撳垵灏辨槸涓鸿繖浠朵簨璁剧殑銆?
  ///
  /// 鍥惧簱鎵嬪姩鎸戦偅鏉¤矾鏃╁氨鎺ヤ綇婧㈠嚭娓呭崟鍦ㄥ垹锛坄bing_wallpaper_gallery_page.dart` 鐨?
  /// `_deleteEvicted`锛夛紝鍙湁杩欓噷婕忎簡锛屼簬鏄鐩樺湪鑷姩鎹㈢敤鎴疯韩涓婃棤涓婇檺鍦版定銆?
  ///
  /// 鐧藉悕鍗曚笁璺苟闆嗭紝鍙ｅ緞涓庡浘搴撻〉鍜?`_HomeBackdropFlow._inUseWallpaperPaths` 涓€鑷达細
  /// 璋冪敤鏂圭粰鐨?*鎵€鏈夎琛?*褰撳墠澹佺焊锛圼inUsePaths]锛夈€佸垰鎹笂鍘荤殑杩欏紶銆佷互鍙婂叏灞€
  /// 銆屾渶杩戜娇鐢ㄣ€嶁€斺€斿巻鍙叉槸璁惧绾у叡浜€屽绾告瘡浠借琛ㄥ悇鑷竴寮狅紝"琚彴璐︽尋鍑哄幓"骞朵笉绛変簬
  /// "娌′汉鐢?銆?
  static Future<void> _deleteEvictedWallpapers(
    List<String> paths, {
    required Set<String> inUsePaths,
  }) async {
    if (paths.isEmpty) {
      return;
    }
    try {
      final history = await WallpaperHistoryService.load();
      await deleteEvictedWallpaperFiles(
        paths,
        inUsePaths: <String>{
          ...inUsePaths,
          // 鍙拌处浠嶈鐫€鐨勮矾寰勪竴寰嬩笉鍒狅細杩欐潯鏄弻淇濋櫓锛堟尋鍑哄幓鐨勮矾寰勬寜瀹氫箟宸蹭笉鍦ㄥ彴璐﹂噷锛?
          // 鎵€浠ユ甯歌蛋涓嶅埌杩欓噷锛涚湡璧板埌浜嗭紝璇存槑璁拌处涓庢竻鐞嗙殑鍋囪鍑轰簡鍋忓樊锛屽畞鍙暀鐫€锛夈€?
          ...BingWallpaperStore.instance.downloadedPaths,
          for (final entry in history) entry.key,
        },
      );
    } on Object catch (error) {
      // 娓呯紦瀛樺け璐ヤ笉璇ユ尝鍙婅嚜鍔ㄦ崲锛氭渶鍧忓氨鏄枃浠跺鐣欎竴浠斤紝涓嬩竴娆¤璐︽椂瀹冭繕浼氳鍐嶅垽
      // 涓€娆★紙閭ｄ竴娆″悕鍗曟洿鏃э紝鐧藉悕鍗曟洿榻愶紝鍒犲緱鎺夛級銆?
      appDebugLog(_tag, 'daily evict failed: ${error.runtimeType}: $error');
    }
  }

  /// [item] 鏄笉鏄?*浠婂ぉ**锛堟寜鏈満鏃ユ湡锛夐偅涓€寮犮€?
  ///
  /// ## 杩欎釜鍒ゆ嵁鐜板湪鍙喅瀹氥€岀畻涓嶇畻浠婂ぉ銆嶏紝涓嶅啀鍐冲畾銆岃涓嶈鎹€?
  ///
  /// 瀹冩渶鍒濇槸涓€閬?*纭椄闂?*锛氶獙涓嶈繃灏辨暣娈垫斁寮冿紝浜庢槸銆孊ing 杩樻病鏀惧嚭浠婂ぉ閭ｅ紶銆嶄細
  /// 璁╄嚜鍔ㄦ崲鍦ㄥ綋澶╁墿涓嬬殑鏃堕棿鍏ㄧ▼闈欓粯澶辨晥锛?026-10-06 鐢ㄦ埛鎶ャ€岀偣浜嗗紑鍏虫病鍙嶅簲銆嶏級銆?
  /// 鐜板湪瀹冨彧鐢ㄦ潵鍐冲畾涓や欢浜嬶細瑕佷笉瑕佸己鍒堕噸鎷変竴娆°€佷互鍙婃崲瀹屼箣鍚庢姤
  /// [BingAutoApplyOutcome.appliedToday] 杩樻槸 [BingAutoApplyOutcome.appliedStale]銆?
  ///
  /// 娓呭崟鏈?3 灏忔椂缂撳瓨锛圼_listCacheTtl]锛夎€?Bing 浣曟椂鏀惧浘涓嶇敱鏈?App 鎺у埗锛屼袱杈归殢鏃?
  /// 鍙兘閿欏紑锛堝疄娴嬫櫄鍒板崄鍑犱釜灏忔椂鏄父鎬侊級銆傘€岀紦瀛橀噷鐨勬槰澶┿€嶄笌銆孊ing 鐪熷氨鍙湁鏄ㄥぉ銆?
  /// 閮介潬杩欓亾鍒ゆ柇**鍒嗕笉寮€**锛屾墍浠ヤ唬鐮侀噷涓嶅啀鎹鏀惧純 鈥斺€?鎹㈡垚鍥惧苟濡傚疄鍛婅瘔鐢ㄦ埛鏄摢涓€澶╋紝
  /// 璁拌处鐢ㄥ浘鑷繁鐨?`dateKey`锛堣 [maybeApplyDaily]锛夈€?
  ///
  /// 瑙ｆ瀽涓嶄簡 `dateKey` 涓€寰嬫寜銆屼笉鏄粖澶┿€嶅鐞嗭細瀹佸彲鏍囨垚銆屼笉鏄粖澶┿€嶅瀹炶涓€鍙ワ紝
  /// 涔熶笉鍦ㄨ剰鏁版嵁涓婅祵瀹冩槸浠婂ぉ銆?
  ///
  /// [now] 鐢?[maybeApplyDaily] 缁熶竴娉ㄥ叆锛堢敓浜у彇 `DateTime.now()`锛屾祴璇曞彇鍥哄畾鏃ユ湡锛夛紝
  /// 鎵€浠ュ垽鎹湪鍗曟祴閲屽彲澶嶇幇銆?
  static bool _isToday(BingWallpaperItem item, DateTime now) {
    final parsed = parseBingWallpaperDateKey(item.dateKey);
    if (parsed == null) {
      return false;
    }
    return parsed.year == now.year &&
        parsed.month == now.month &&
        parsed.day == now.day;
  }

  static Future<void> _logWarn(
    String category,
    Object? error, [
    StackTrace? stackTrace,
  ]) async {
    try {
      await AppLogService.instance.warn(
        category,
        AppLogMessages.bingWallpaperRequestFailed,
        error: error,
        stackTrace: stackTrace,
      );
    } on Object {
      // 鏃ュ織鏈韩澶辫触蹇呴』褰诲簳闈欓粯 鈥斺€?杩欐潯璺緞鐨勮皟鐢ㄦ柟鍦ㄥ惎鍔ㄦ祦绋嬩笂銆?
    }
  }

  }
