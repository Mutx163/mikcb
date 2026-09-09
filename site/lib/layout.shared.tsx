import type { BaseLayoutProps } from 'fumadocs-ui/layouts/shared';

export const siteConfig = {
  name: '轻屿课表文档',
  description: '轻屿课表的使用手册与开发者文档',
  githubUrl: 'https://github.com/Mutx163/mikcb',
  websiteUrl: 'https://163366.xyz',
};

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: '轻屿课表文档',
    },
    githubUrl: siteConfig.githubUrl,
    links: [
      {
        text: '官网与下载',
        url: siteConfig.websiteUrl,
      },
    ],
  };
}
