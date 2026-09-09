import { defineDocs } from 'fumadocs-mdx/config';

export const docs = defineDocs({
  dir: 'content/docs',
  docs: {
    postprocess: {
      // 供 llms.txt / llms-full.txt 使用
      includeProcessedMarkdown: true,
    },
  },
});
