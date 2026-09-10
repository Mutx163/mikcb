/**
 * 文档站全局站点信息。
 *
 * 单独抽出一份，避免 layout / sitemap / robots / metadata 各写一遍，
 * 也方便部署域名变更时只改一处。
 */

/** 文档站正式域名（部署在 Cloudflare Pages 等静态托管上） */
export const siteUrl = (
  process.env.NEXT_PUBLIC_SITE_URL ?? 'https://docs.163366.xyz'
).replace(/\/$/, '');

/** 应用官网（下载、学校适配、隐私条款） */
export const websiteUrl = 'https://163366.xyz';

/** 源码仓库 */
export const githubUrl = 'https://github.com/Mutx163/mikcb';

export const siteConfig = {
  name: '轻屿课表文档',
  description: '轻屿课表的使用手册与开发者文档',
  githubUrl,
  websiteUrl,
} as const;
