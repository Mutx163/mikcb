import '../models/campus_tool_entry.dart';

/// 预置快捷入口：数据照着 QuickJump（github.com/chuhe0719/QuickJump）的
/// `ENTRIES` 抄下来，**只做数据、不做跳转逻辑**。
///
/// 为什么原样保留「多级回退」而不只留一条链接：这些页面入口都不是官方开放
/// API，菜鸟 / 淘宝 / 拼多多 / 抖音 / 京东 每次大版本更新都可能改名或换
/// scheme。QuickJump 的做法是每条入口配一串按顺序尝试的链接，全失败再拉起
/// 官方 App、最后用网页兜底 —— 用户至少不会点了没反应。这里沿用同一口径。
///
/// 维护约定：
/// - 新预置项 = 这里追加一条 + `l10n/*.arb` 加一个标题键（
///   `campus_tools_preset` 前缀），标题本地化在 `l10n/campus_tool_localizer.dart`；
/// - 改链接不需要动界面：用户长按入口即可自行改（存量用户不用等版本）；
/// - 这里的包名同时要被 `android/app/src/main/AndroidManifest.xml` 的
///   `<queries>` 覆盖，否则 Android 11+ 上查不到「装没装」。
const List<CampusToolEntry> kCampusToolPresets = <CampusToolEntry>[
  CampusToolEntry(
    id: 'campusToolsPresetCainiao',
    icon: 'cainiao',
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
    icon: 'taobao',
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
    id: 'campusToolsPresetPinduoduo',
    icon: 'pinduoduo',
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
    icon: 'jd',
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
    icon: 'douyin',
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

/// 预置项的 id 集合（用户自建项的 id 是 uuid，不在这里）。
final Set<String> kCampusToolPresetIds = <String>{
  for (final preset in kCampusToolPresets) preset.id,
};

/// 首次启动 / 用户清空后使用的默认排列。
///
/// 每条都复制一份（`copyWith` 造新实例）：预置表是 const，直接把条目交出去
/// 会让界面上的改动与常量共享引用，下一次「恢复默认」读到被改过的值。
List<CampusToolEntry> campusToolDefaultEntries() {
  return <CampusToolEntry>[
    for (final preset in kCampusToolPresets) preset.copyWith(),
  ];
}

/// 把预置表里「用户已经删掉」的条目补回末尾，已有条目原样保留。
///
/// 只补不重置：用户改过的链接、自建项、停用状态都不动 —— 「恢复默认」
/// 在这个页面的语义是「找回默认入口」，不是「清空我的配置」。
List<CampusToolEntry> campusToolRestoreMissingPresets(
  List<CampusToolEntry> current,
) {
  final existing = <String>{for (final entry in current) entry.id};
  final restored = <CampusToolEntry>[
    for (final entry in current) entry,
    for (final preset in kCampusToolPresets)
      if (!existing.contains(preset.id)) preset.copyWith(),
  ];
  return List<CampusToolEntry>.unmodifiable(restored);
}
