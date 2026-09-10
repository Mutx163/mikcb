import { llms } from 'fumadocs-core/source/llms';
import { source } from '@/lib/source';
import { siteConfig, siteUrl } from '@/lib/site';

export const dynamic = 'force-static';

/**
 * 输出 llms.txt —— 给 AI 抓取用的站点索引。
 *
 * `source.config.ts` 里已开启 `includeProcessedMarkdown`，
 * Fumadocs 的 `llms()` 会直接基于页面树生成 Markdown 清单。
 */
export function GET() {
  const body = [
    `# ${siteConfig.name}`,
    '',
    `> ${siteConfig.description}`,
    '',
    `官网：${siteConfig.websiteUrl}`,
    `源码：${siteConfig.githubUrl}`,
    '',
    llms(source).index(),
    '',
    '## 完整内容',
    '',
    `- [llms-full.txt](${siteUrl}/llms-full.txt): 全部文档的完整 Markdown 内容`,
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
