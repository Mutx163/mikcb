import Link from 'next/link';
import { buttonVariants } from 'fumadocs-ui/components/ui/button';
import { siteConfig } from '@/lib/site';

const navCards = [
  {
    title: '快速开始',
    description: '安装、权限与第一张课表——装完先看这篇。',
    href: '/docs/guide/quick-start',
    icon: 'ring',
    tone: 'blue',
  },
  {
    title: '导入与迁移',
    description: '教务网页登录一键抓取；未适配可用 ICS 或 AI 识图。',
    href: '/docs/guide/import',
    icon: 'download',
    tone: 'teal',
  },
  {
    title: '界面与课程管理',
    description: '周视图、日视图、单双周与时间模板。',
    href: '/docs/guide/interface',
    icon: 'grid',
    tone: 'violet',
  },
  {
    title: '超级岛与提醒',
    description: '课前 / 课中 / 下课三阶段，锁屏也知道下一节在哪。',
    href: '/docs/guide/super-island',
    icon: 'ring2',
    tone: 'amber',
  },
  {
    title: '桌面小组件',
    description: '今日安排、课程统计与情侣课表卡片挂在桌面。',
    href: '/docs/guide/widget',
    icon: 'grid',
    tone: 'pink',
  },
  {
    title: '课程统计',
    description: '热力图、趋势与排行，看清这学期有多忙。',
    href: '/docs/guide/statistics',
    icon: 'chart',
    tone: 'green',
  },
  {
    title: '同步与备份',
    description: '完整备份导出、WebDAV 云同步与历史快照，换机不丢课表。',
    href: '/docs/guide/sync-backup',
    icon: 'cloud',
    tone: 'blue',
  },
  {
    title: '故障排查',
    description: '通知不响、超级岛不显示、导入失败——按现象对号入座。',
    href: '/docs/guide/troubleshooting',
    icon: 'help',
    tone: 'amber',
  },
] as const;

const moreLinks = [
  { title: '常见问题', href: '/docs/guide/faq' },
  { title: '更新日志', href: '/docs/guide/changelog' },
  { title: '反馈渠道', href: '/docs/guide/feedback' },
  { title: '隐私与条款', href: '/docs/guide/privacy' },
  { title: '开发者文档', href: '/docs/dev/architecture' },
  { title: 'AI 适配教务', href: '/docs/dev/jiaowu-adapter' },
] as const;

const toneMap = {
  blue: 'bg-blue-500/12 text-blue-600 dark:text-blue-300 ring-blue-500/20',
  teal: 'bg-teal-500/12 text-teal-600 dark:text-teal-300 ring-teal-500/20',
  violet: 'bg-violet-500/12 text-violet-600 dark:text-violet-300 ring-violet-500/20',
  amber: 'bg-amber-500/12 text-amber-600 dark:text-amber-300 ring-amber-500/20',
  pink: 'bg-pink-500/12 text-pink-600 dark:text-pink-300 ring-pink-500/20',
  green: 'bg-emerald-500/12 text-emerald-600 dark:text-emerald-300 ring-emerald-500/20',
} as const;

function FeatureIcon({ name }: { name: string }) {
  if (name === 'ring2') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
        <rect x="3" y="8" width="18" height="8" rx="4" />
        <circle cx="8" cy="12" r="1.6" />
        <path d="M13 10.5h5M13 13.5h3" strokeLinecap="round" />
      </svg>
    );
  }
  if (name === 'download') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
        <path d="M12 3v12" strokeLinecap="round" />
        <path d="m7 10 5 5 5-5" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M5 21h14" strokeLinecap="round" />
      </svg>
    );
  }
  if (name === 'cloud') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
        <path d="M7 18a4 4 0 0 1 .4-7.96 6 6 0 0 1 11.3 1.7A3.5 3.5 0 0 1 17.5 18H7Z" strokeLinejoin="round" />
      </svg>
    );
  }
  if (name === 'grid') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
        <rect x="3" y="3" width="7" height="7" rx="1.5" />
        <rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" />
        <rect x="14" y="14" width="7" height="7" rx="1.5" />
      </svg>
    );
  }
  if (name === 'chart') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
        <path d="M4 19V5" strokeLinecap="round" />
        <path d="M4 19h16" strokeLinecap="round" />
        <path d="M8 15v-4" strokeLinecap="round" />
        <path d="M12 15V8" strokeLinecap="round" />
        <path d="M16 15v-6" strokeLinecap="round" />
      </svg>
    );
  }
  if (name === 'help') {
    return (
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
        <circle cx="12" cy="12" r="9" />
        <path d="M9.5 9.5a2.5 2.5 0 1 1 3.6 2.25c-.7.35-1.1.9-1.1 1.75" strokeLinecap="round" />
        <path d="M12 17h.01" strokeLinecap="round" />
      </svg>
    );
  }
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
      <path d="M4 12a8 8 0 1 1 8 8" strokeLinecap="round" />
      <path d="M12 8v4l2.5 2.5" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M4 16v4h4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export default function HomePage() {
  return (
    <main className="relative flex flex-1 flex-col overflow-x-hidden">
      {/* Hero */}
      <section className="relative isolate flex flex-col items-center justify-center overflow-clip px-6 pb-16 pt-24 text-center sm:pt-28">
        <div className="docs-hero-atmosphere" aria-hidden="true" />
        <div className="docs-reveal relative z-10 flex flex-col items-center gap-3">
          <p className="inline-flex items-center gap-2 rounded-full border border-fd-border bg-fd-secondary/60 px-3 py-1 text-xs text-fd-muted-foreground sm:text-sm">
            <span className="size-1.5 rounded-full bg-emerald-500" />
            面向使用者的操作手册 · 也给贡献者
          </p>
          <h1 className="max-w-3xl text-4xl font-semibold leading-[1.1] tracking-tight sm:text-5xl md:text-6xl">
            轻屿课表
            <span className="docs-grad-text">文档</span>
          </h1>
          <p className="max-w-xl text-base leading-relaxed text-fd-foreground/90 sm:text-lg">
            不只是功能清单。从安装、导入、超级岛到故障排查——装完之后怎么用，都在这里。
          </p>
          <p className="max-w-2xl text-sm leading-relaxed text-fd-muted-foreground sm:text-base">
            官网回答「我为什么要装」；这里回答「装了之后怎么用」。应用下载与学校适配状态请访问官网。
          </p>
        </div>

        <div className="docs-reveal relative z-10 mt-7 flex flex-wrap items-center justify-center gap-3">
          <Link
            href="/docs/guide/quick-start"
            className={`${buttonVariants({ variant: 'primary' })} min-h-12 rounded-full px-6 text-sm font-semibold`}
          >
            快速上手
          </Link>
          <Link
            href="/docs"
            className={`${buttonVariants({ variant: 'secondary' })} min-h-12 rounded-full px-6 text-sm font-semibold`}
          >
            浏览全部文档
          </Link>
        </div>
        <div className="docs-reveal relative z-10 mt-3 flex flex-wrap items-center justify-center gap-3">
          <Link
            href={siteConfig.websiteUrl}
            className="inline-flex min-h-11 items-center gap-2 rounded-full px-5 text-sm font-medium text-fd-primary ring-1 ring-inset ring-fd-border transition hover:bg-fd-secondary"
          >
            官网与下载
          </Link>
          <Link
            href="/docs/dev/architecture"
            className="inline-flex min-h-11 items-center gap-2 rounded-full px-5 text-sm font-medium text-fd-primary ring-1 ring-inset ring-fd-border transition hover:bg-fd-secondary"
          >
            开发者文档
          </Link>
          <Link
            href={siteConfig.githubUrl}
            target="_blank"
            rel="noreferrer"
            className="inline-flex min-h-11 items-center gap-2 rounded-full px-5 text-sm font-medium text-fd-primary ring-1 ring-inset ring-fd-border transition hover:bg-fd-secondary"
          >
            GitHub
          </Link>
        </div>
      </section>

      {/* 主路径：一套卡片，替代原先「能力一览 + 文档分区 + 高频入口」三块 */}
      <section className="mx-auto w-full max-w-6xl px-6 pb-16">
        <div className="mb-8 text-center">
          <h2 className="text-2xl font-semibold tracking-tight sm:text-3xl">按你手上的问题找</h2>
          <p className="mt-2 text-sm text-fd-muted-foreground sm:text-base">
            八条主路径，覆盖从装应用到排故障的完整流程
          </p>
        </div>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {navCards.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="group flex h-full flex-col rounded-3xl border border-fd-border bg-fd-secondary/40 p-5 no-underline transition hover:border-fd-primary/40 hover:bg-fd-secondary"
            >
              <span
                className={`mb-4 inline-flex size-11 items-center justify-center rounded-2xl ring-1 ring-inset ${toneMap[item.tone]}`}
              >
                <FeatureIcon name={item.icon} />
              </span>
              <h3 className="mb-1 flex items-center gap-1 text-base font-medium">
                {item.title}
                <span className="text-fd-primary opacity-0 transition group-hover:opacity-100" aria-hidden="true">
                  →
                </span>
              </h3>
              <p className="text-sm leading-relaxed text-fd-muted-foreground">{item.description}</p>
            </Link>
          ))}
        </div>
      </section>

      {/* 次级入口：文档分区与工程类页面 */}
      <section className="mx-auto w-full max-w-5xl px-6 pb-20">
        <div className="grid gap-4 sm:grid-cols-2">
          <Link
            href="/docs/guide/quick-start"
            className="group flex h-full flex-col rounded-3xl border border-fd-border bg-fd-secondary/40 p-6 no-underline transition hover:border-fd-primary/40 hover:bg-fd-secondary"
          >
            <span className="mb-4 inline-flex size-12 items-center justify-center self-start rounded-2xl bg-blue-500/12 text-blue-600 ring-1 ring-inset ring-blue-500/20 dark:text-blue-300">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
                <path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5V5.5Z" strokeLinejoin="round" />
                <path d="M8 8h8M8 12h5" strokeLinecap="round" />
              </svg>
            </span>
            <h2 className="mb-1 flex items-center gap-1 text-lg font-medium">
              使用指南
              <span className="text-fd-primary opacity-0 transition group-hover:opacity-100" aria-hidden="true">
                →
              </span>
            </h2>
            <p className="text-sm leading-relaxed text-fd-muted-foreground">
              12 篇操作手册：安装、导入、界面、统计、小组件、超级岛、同步、排查、FAQ、更新日志、反馈、隐私
            </p>
          </Link>
          <Link
            href="/docs/dev/architecture"
            className="group flex h-full flex-col rounded-3xl border border-fd-border bg-fd-secondary/40 p-6 no-underline transition hover:border-fd-primary/40 hover:bg-fd-secondary"
          >
            <span className="mb-4 inline-flex size-12 items-center justify-center self-start rounded-2xl bg-violet-500/12 text-violet-600 ring-1 ring-inset ring-violet-500/20 dark:text-violet-300">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="size-6" aria-hidden="true">
                <path d="M8 7 3 12l5 5M16 7l5 5-5 5M14 4l-4 16" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
            </span>
            <h2 className="mb-1 flex items-center gap-1 text-lg font-medium">
              开发者文档
              <span className="text-fd-primary opacity-0 transition group-hover:opacity-100" aria-hidden="true">
                →
              </span>
            </h2>
            <p className="text-sm leading-relaxed text-fd-muted-foreground">
              技术栈、架构分层、超级岛实现、教务适配与站点部署
            </p>
          </Link>
        </div>

        <div className="mt-6 rounded-3xl border border-fd-border bg-fd-secondary/30 p-6">
          <h2 className="mb-3 text-sm font-medium text-fd-muted-foreground">其他常用入口</h2>
          <div className="flex flex-wrap gap-2">
            {moreLinks.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="inline-flex min-h-9 items-center rounded-full border border-fd-border bg-fd-background px-4 text-sm text-fd-foreground/90 no-underline transition hover:border-fd-primary/40 hover:text-fd-primary"
              >
                {item.title}
              </Link>
            ))}
          </div>
        </div>

        <div className="mt-8 flex flex-wrap items-center justify-center gap-3 text-sm">
          <Link href="/docs" className="font-medium text-fd-primary hover:underline">
            查看完整目录
          </Link>
          <span className="text-fd-muted-foreground">·</span>
          <Link href={siteConfig.websiteUrl} className="text-fd-muted-foreground hover:text-fd-foreground">
            官网 163366.xyz
          </Link>
          <span className="text-fd-muted-foreground">·</span>
          <Link href="/docs/dev/deployment" className="text-fd-muted-foreground hover:text-fd-foreground">
            改这个文档站
          </Link>
        </div>
      </section>
    </main>
  );
}
