import '../models/campus_tool_entry.dart';

/// 固定入口表：**这就是这个页面的全部内容**，用户不能增删改。
///
/// 数据照 QuickJump（github.com/chuhe0719/QuickJump）的 `ENTRIES` 抄下来，
/// 只做数据、不做跳转逻辑。
///
/// 为什么原样保留「多级回退」而不只留一条链接：这些页面入口都不是官方开放
/// API，菜鸟 / 淘宝 / 拼多多 / 抖音 / 京东 每次大版本更新都可能改名或换
/// scheme。QuickJump 的做法是每条入口配一串按顺序尝试的链接，全失败再拉起
/// 官方 App、最后用网页兜底 —— 用户至少不会点了没反应。这里沿用同一口径。
///
/// 维护约定：
/// - 新入口 = 这里追加一条 + `l10n/*.arb` 加一个标题键（`campusToolsPreset`
///   前缀）+ 需要时在 `widgets/campus_tool_icons.dart` 注册图标名；
/// - 改链接不需要动界面：用户长按入口即可自行改（存量用户不用等版本）；
/// - 这里的包名同时要被 `android/app/src/main/AndroidManifest.xml` 的
///   `<queries>` 覆盖，否则 Android 11+ 上查不到「装没装」。
///
/// 顺序有意义：列表按「一天里最可能用到的」从上往下排，身份码在待取快递之前
/// （去柜子跟前第一件事是出示码，不是查单）。
const List<CampusToolEntry> kCampusToolPresets = <CampusToolEntry>[
  CampusToolEntry(
    id: 'campusToolsPresetCainiao',
    icon: 'qrCode',
    links: <CampusToolLink>[
      CampusToolLink(
        uri: 'cainiao://desktop/station_code',
        package: 'com.cainiao.wireless',
      ),
      CampusToolLink(
        uri: 'cainiao://client.main',
        package: 'com.cainiao.wireless',
      ),
    ],
    appPackages: <String>['com.cainiao.wireless'],
    webUri:
        'https://market.m.taobao.com/app/cn-yz/multi-activity/authCode.html'
        '?bizEntry=ALIPAY_GUOGUO',
  ),
  CampusToolEntry(
    id: 'campusToolsPresetTaobao',
    icon: 'qrCode',
    links: <CampusToolLink>[
      CampusToolLink(
        uri:
            'taobao://m.taobao.com/tbopen/index.html?h5Url='
            'https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F'
            '1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code'
            '%3Fx-ssr%3Dtrue',
        package: 'com.taobao.taobao',
      ),
      CampusToolLink(
        uri:
            'tbopen://m.taobao.com/tbopen/index.html?h5Url='
            'https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F'
            '1011717%2Flast-mile-fe%2Fend-collect-platform%2Fidentity-code'
            '%3Fx-ssr%3Dtrue',
        package: 'com.taobao.taobao',
      ),
    ],
    appPackages: <String>['com.taobao.taobao'],
    webUri:
        'https://pages-fast.m.taobao.com/wow/z/uniapp/1011717/last-mile-fe/'
        'end-collect-platform/identity-code?x-ssr=true',
  ),
  CampusToolEntry(
    id: 'campusToolsPresetPinduoduo',
    icon: 'qrCode',
    links: <CampusToolLink>[
      CampusToolLink(
        uri:
            'pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE'
            '&entry_source=11&refer_page_name=login&refer_page_sn=10169',
        package: 'com.xunmeng.pinduoduo',
      ),
      CampusToolLink(
        uri:
            'pinduoduo://com.xunmeng.pinduoduo/mdkd/package?tab=ID_CODE'
            '&entry_source=11',
        package: 'com.xunmeng.pinduoduo',
      ),
      CampusToolLink(
        uri: 'pinduoduo://com.xunmeng.pinduoduo/mdkd/package',
        package: 'com.xunmeng.pinduoduo',
      ),
    ],
    appPackages: <String>['com.xunmeng.pinduoduo'],
    webUri:
        'https://m.pinduoduo.net/mdkd/package?entry_source=18'
        '&extra_params=from_wx_jump%3D1&p_channel=0',
  ),
  CampusToolEntry(
    id: 'campusToolsPresetTaobaoParcels',
    icon: 'parcel',
    links: <CampusToolLink>[
      CampusToolLink(
        uri:
            'taobao://m.taobao.com/tbopen/index.html?h5Url='
            'https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F'
            '1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome',
        package: 'com.taobao.taobao',
      ),
      CampusToolLink(
        uri:
            'tbopen://m.taobao.com/tbopen/index.html?h5Url='
            'https%3A%2F%2Fpages-fast.m.taobao.com%2Fwow%2Fz%2Funiapp%2F'
            '1100333%2Flast-mile-fe%2Fm-end-school-tab%2Fhome',
        package: 'com.taobao.taobao',
      ),
    ],
    appPackages: <String>['com.taobao.taobao'],
    webUri:
        'https://pages-fast.m.taobao.com/wow/z/uniapp/1100333/last-mile-fe/'
        'm-end-school-tab/home',
  ),
  CampusToolEntry(
    id: 'campusToolsPresetPinduoduoParcels',
    icon: 'parcel',
    links: <CampusToolLink>[
      CampusToolLink(
        uri: 'pinduoduo://com.xunmeng.pinduoduo/mdkd/package',
        package: 'com.xunmeng.pinduoduo',
      ),
    ],
    appPackages: <String>['com.xunmeng.pinduoduo'],
    webUri:
        'https://m.pinduoduo.net/mdkd/package?entry_source=18'
        '&extra_params=from_wx_jump%3D1&p_channel=0',
  ),
  CampusToolEntry(
    id: 'campusToolsPresetJdParcels',
    icon: 'parcel',
    links: <CampusToolLink>[
      CampusToolLink(
        uri:
            'openjd://virtual?params=%7B%22category%22%3A%22jump%22%2C'
            '%22des%22%3A%22orderlist%22%7D',
        package: 'com.jingdong.app.mall',
      ),
    ],
    appPackages: <String>['com.jingdong.app.mall'],
    webUri: 'https://order.jd.com/center/list.action',
  ),
  CampusToolEntry(
    id: 'campusToolsPresetDouyinParcels',
    icon: 'parcel',
    links: <CampusToolLink>[
      CampusToolLink(
        uri: 'snssdk1128://ecom_order_list',
        package: 'com.ss.android.ugc.aweme',
      ),
      CampusToolLink(
        uri: 'snssdk1128://wallet',
        package: 'com.ss.android.ugc.aweme',
      ),
      CampusToolLink(
        uri: 'snssdk2329://ecom_order_list',
        package: 'com.ss.android.ugc.aweme.lite',
      ),
      CampusToolLink(
        uri: 'snssdk2329://wallet',
        package: 'com.ss.android.ugc.aweme.lite',
      ),
    ],
    appPackages: <String>[
      'com.ss.android.ugc.aweme',
      'com.ss.android.ugc.aweme.lite',
    ],
  ),
];

/// 全部入口需要探测的包名（去重）：给「一次查完装没装」用，
/// 避免逐个入口各查一遍同一批包名。
List<String> campusToolAllPackages() {
  final packages = <String>[];
  for (final entry in kCampusToolPresets) {
    for (final package in entry.appPackages) {
      if (!packages.contains(package)) {
        packages.add(package);
      }
    }
  }
  return List<String>.unmodifiable(packages);
}
