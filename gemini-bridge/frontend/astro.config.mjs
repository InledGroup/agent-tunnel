import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:3456',
        changeOrigin: true,
        ws: true
      }
    }
  },
  outDir: '../public',
  output: 'static',
  build: {
    format: 'file',
  }
});
