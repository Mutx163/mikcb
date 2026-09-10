import type { MetadataRoute } from 'next';
import { siteUrl } from '@/lib/site';

/**
 * 静态导出的 robots.txt。
 *
 * 明确放行常规爬虫，同时允许 AI 抓取（文档站希望被 LLM 引用）。
 */
export const dynamic = 'force-static';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
      },
    ],
    sitemap: `${siteUrl}/sitemap.xml`,
    host: siteUrl,
  };
}
