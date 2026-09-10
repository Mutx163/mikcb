import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';
import { siteConfig } from './site';

export { siteConfig };

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: '轻屿课表文档',
    },
    githubUrl: siteConfig.githubUrl,
    links: [
      {
        text: '使用指南',
        url: '/docs/guide/quick-start',
      },
      {
        text: '开发者',
        url: '/docs/dev/architecture',
      },
      {
        text: '常见问题',
        url: '/docs/guide/faq',
      },
      {
        text: '更新日志',
        url: '/docs/guide/changelog',
      },
      {
        text: '官网与下载',
        url: siteConfig.websiteUrl,
      },
    ],
  };
}
