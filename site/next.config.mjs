import { createMDX } from 'fumadocs-mdx/next';

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  // 静态导出：产物写入 out/，可直接上传到 Cloudflare Pages
  output: 'export',
  // 生成 /docs/index.html 这类目录结构，任何静态服务器都能正确路由
  trailingSlash: true,
  // 静态导出下禁用 Next 图片优化（需要 Node 服务器）
  images: {
    unoptimized: true,
  },
};

const withMDX = createMDX();

export default withMDX(config);
