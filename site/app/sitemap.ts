import type { MetadataRoute } from 'next';
import { source } from '@/lib/source';
import { siteUrl } from '@/lib/site';

/**
 * 静态导出的 sitemap.xml。
 *
 * 之前文档站没有任何站点地图，搜索引擎只能靠外链慢慢发现内页。
 * 这里遍历 Fumadocs 的页面树，把所有文档页 + 首页一并输出。
 *
 * 注意：`next.config.mjs` 开了 `trailingSlash: true`，
 * 站点实际地址都带结尾斜杠，sitemap 必须保持一致，否则会多一次 301。
 */
export const dynamic = 'force-static';

function absolute(path: string): string {
  const normalized = path.startsWith('/') ? path : `/${path}`;
  return `${siteUrl}${normalized.endsWith('/') ? normalized : `${normalized}/`}`;
}

export default function sitemap(): MetadataRoute.Sitemap {
  const pages = source.getPages();

  // `/docs` 首页与 `/` 之外，逐页输出；用 Map 去重，避免 `/docs` 出现两次。
  const urls = new Map<string, MetadataRoute.Sitemap[number]>();

  urls.set(absolute('/'), {
    url: absolute('/'),
    changeFrequency: 'weekly',
    priority: 1,
  });

  for (const page of pages) {
    urls.set(absolute(page.url), {
      url: absolute(page.url),
      changeFrequency: 'monthly',
      priority: page.url === '/docs' ? 0.9 : 0.8,
    });
  }

  return [...urls.values()];
}
