import { source } from '@/lib/source';
import { siteConfig, siteUrl } from '@/lib/site';

export const dynamic = 'force-static';

/**
 * 输出 llms-full.txt —— 所有文档的完整 Markdown 正文。
 *
 * 便于 AI 一次性拿到全文，而不用逐页抓取。
 * 内容来自 `includeProcessedMarkdown` 产出的 processed Markdown。
 */
export async function GET() {
  const pages = source.getPages();

  const sections = await Promise.all(
    pages.map(async (page) => {
      const content = await page.data.getText('processed');
      return [
        `# ${page.data.title}`,
        '',
        `来源：${siteUrl}${page.url}`,
        page.data.description ? `\n> ${page.data.description}` : '',
        '',
        content.trim(),
      ]
        .filter(Boolean)
        .join('\n');
    }),
  );

  const body = [
    `# ${siteConfig.name}`,
    '',
    `> ${siteConfig.description}`,
    '',
    `官网：${siteConfig.websiteUrl}`,
    '',
    '---',
    '',
    sections.join('\n\n---\n\n'),
    '',
  ].join('\n');

  return new Response(body, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
