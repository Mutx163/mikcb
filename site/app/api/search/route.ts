import { source } from '@/lib/source';
import { createFromSource } from 'fumadocs-core/search/server';

// 静态导出：把搜索索引构建成静态 JSON，搜索在浏览器端计算
export const revalidate = false;
export const dynamic = 'force-static';

export const { staticGET: GET } = createFromSource(source);
