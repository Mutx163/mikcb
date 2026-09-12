import type { Metadata, Viewport } from 'next';
import './globals.css';
import { Provider } from './provider';
import { siteConfig, siteUrl } from '@/lib/site';

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: siteConfig.name,
    template: `%s · ${siteConfig.name}`,
  },
  description: siteConfig.description,
  applicationName: siteConfig.name,
  keywords: [
    '轻屿课表',
    '课表 App',
    'Android 课表',
    '超级岛',
    '桌面小组件',
    '教务导入',
    'WebDAV 同步',
  ],
  authors: [{ name: 'Mutx163', url: siteConfig.githubUrl }],
  creator: 'Mutx163',
  publisher: '轻屿课表',
  alternates: {
    canonical: '/',
  },
  openGraph: {
    type: 'website',
    siteName: siteConfig.name,
    title: siteConfig.name,
    description: siteConfig.description,
    url: '/',
    locale: 'zh_CN',
    images: [{ url: '/app-icon.png', width: 512, height: 512, alt: siteConfig.name }],
  },
  twitter: {
    card: 'summary',
    title: siteConfig.name,
    description: siteConfig.description,
    images: ['/app-icon.png'],
  },
  robots: {
    index: true,
    follow: true,
  },
  icons: {
    // 48 的整数倍是 Google 图标的硬性要求；app-icon.png（512、129KB）只留给 OG/分享图。
    icon: [
      { url: '/favicon.ico', sizes: '48x48' },
      { url: '/favicon-48.png', type: 'image/png', sizes: '48x48' },
      { url: '/favicon-96.png', type: 'image/png', sizes: '96x96' },
      { url: '/favicon-144.png', type: 'image/png', sizes: '144x144' },
      { url: '/favicon-192.png', type: 'image/png', sizes: '192x192' },
    ],
    apple: { url: '/apple-touch-icon.png', sizes: '180x180' },
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0a0a0a' },
  ],
};

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <body className="flex min-h-screen flex-col">
        <Provider>{children}</Provider>
      </body>
    </html>
  );
}
