import type { Metadata } from 'next';
import { source } from '@/lib/source';
import {
  DocsBody,
  DocsDescription,
  DocsPage,
  DocsTitle,
} from 'fumadocs-ui/page';
import { notFound } from 'next/navigation';
import { getMDXComponents } from '@/mdx-components';
import { siteConfig } from '@/lib/site';

type PageProps = {
  params: Promise<{ slug?: string[] }>;
};

export default async function Page(props: PageProps) {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const MDX = page.data.body;

  return (
    <DocsPage toc={page.data.toc} full={page.data.full}>
      <DocsTitle>{page.data.title}</DocsTitle>
      <DocsDescription>{page.data.description}</DocsDescription>
      <DocsBody>
        <MDX components={getMDXComponents()} />
      </DocsBody>
    </DocsPage>
  );
}

/**
 * 为每篇文档生成独立的 title / description / canonical / OG。
 *
 * 之前所有页面都继承根 layout 的静态 metadata，导致 18 个页面共用
 * 同一个 <title> 和 description，分享卡片与搜索引擎都拿不到有效信息。
 */
export async function generateMetadata(props: PageProps): Promise<Metadata> {
  const params = await props.params;
  const page = source.getPage(params.slug);
  if (!page) notFound();

  const title = page.data.title;
  const description = page.data.description ?? siteConfig.description;
  const url = page.url;

  // `/docs` 首页的标题与站点名相同，套上模板会变成
  // 「轻屿课表文档 · 轻屿课表文档」，这里显式用 absolute 避免重复。
  const isDocsHome = params.slug === undefined || params.slug.length === 0;

  return {
    title: isDocsHome ? { absolute: siteConfig.name } : title,
    description,
    alternates: {
      canonical: url,
    },
    openGraph: {
      type: 'article',
      siteName: siteConfig.name,
      title,
      description,
      url,
      locale: 'zh_CN',
      images: [{ url: '/app-icon.png', width: 512, height: 512, alt: title }],
    },
    twitter: {
      card: 'summary',
      title,
      description,
      images: ['/app-icon.png'],
    },
  };
}

export async function generateStaticParams() {
  return source.generateParams();
}
