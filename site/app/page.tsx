import Link from 'next/link';
import { buttonVariants } from 'fumadocs-ui/components/ui/button';
import { siteConfig } from '@/lib/layout.shared';

export default function HomePage() {
  return (
    <main className="flex flex-1 flex-col items-center justify-center gap-5 px-6 text-center">
      <h1 className="text-3xl font-semibold">{siteConfig.name}</h1>
      <p className="max-w-md text-sm text-fd-muted-foreground">
        {siteConfig.description}。应用下载、学校适配与隐私条款请访问官网。
      </p>
      <div className="flex flex-wrap items-center justify-center gap-3">
        <Link href="/docs" className={buttonVariants({ variant: 'primary' })}>
          进入文档
        </Link>
        <Link
          href={siteConfig.websiteUrl}
          className={buttonVariants({ variant: 'secondary' })}
        >
          官网与下载
        </Link>
      </div>
    </main>
  );
}
