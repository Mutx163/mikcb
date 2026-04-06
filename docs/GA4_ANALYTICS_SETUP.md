# GA4 站点统计配置说明

## 已接入的事件
- `nav_menu_toggle`
- `nav_link_click`
- `section_view`
- `outbound_repo_click`
- `release_modal_open`
- `release_modal_close`
- `release_data_load`
- `release_channel_switch`（仅 docs 版下载弹窗）
- `release_page_click`
- `app_download_intent`
- `mirror_resolution`（仅 docs 版镜像测速下载）
- `app_download`

## 建议在 GA4 里创建的自定义维度（中文显示名）
> 管理员 -> 自定义定义 -> 创建自定义维度

### 事件级自定义维度
- `site_variant` -> 站点版本
- `ui_surface_label` -> 交互区域
- `ui_label` -> 控件文案
- `section_label` -> 区块名称
- `target_section_label` -> 目标区块
- `release_channel_label` -> 发布通道
- `release_version` -> 发布版本
- `release_title` -> 发布标题
- `release_asset_name` -> 安装包文件名
- `download_source` -> 下载来源
- `mirror_provider_label` -> 镜像线路
- `close_reason` -> 弹窗关闭原因
- `load_state` -> 版本加载状态
- `error_name` -> 错误信息

## 中文界面说明
GA4 后台界面语言**不能由网站代码强制决定**，它通常跟随：
1. Google 账号语言
2. 浏览器 / Google 服务语言偏好

如果你要中文后台：
- 把 Google 账号语言改成简体中文
- 在 GA4 中把上面的自定义维度“显示名称”填写成中文

这样后台报表里，标准字段会是中文界面，自定义字段也会是中文名。
