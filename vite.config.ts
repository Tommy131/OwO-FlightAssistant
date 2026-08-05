import { defineConfig, loadEnv } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'node:path';

/**
 * Vite 配置
 *
 * ── CORS 方案 ──
 * 浏览器无法直接跨源访问中间件 (http://127.0.0.1:18080)，
 * 因此开发期由 Vite dev server 代理转发：
 *   /mw-api/*  →  http://127.0.0.1:18080/*
 *   /mw-ws     →  ws://127.0.0.1:18081/api/v1/simulator/ws
 *
 * 生产部署请参见 README「部署与 CORS」一节：
 * 要么让中间件下发 Access-Control-Allow-Origin，
 * 要么把 dist/ 静态资源同源挂载到中间件下。
 */
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), '');
  const httpTarget = env.VITE_MIDDLEWARE_HTTP ?? 'http://127.0.0.1:18080';
  const wsTarget = env.VITE_MIDDLEWARE_WS ?? 'ws://127.0.0.1:18081';

  return {
    plugins: [react()],
    resolve: {
      alias: {
        '@': path.resolve(__dirname, 'src'),
        '@core': path.resolve(__dirname, 'src/core'),
        '@modules': path.resolve(__dirname, 'src/modules'),
      },
    },
    server: {
      port: 5273,
      proxy: {
        // 中间件 HTTP API
        '/mw-api': {
          target: httpTarget,
          changeOrigin: true,
          rewrite: (p) => p.replace(/^\/mw-api/, ''),
        },
        // 模拟器实时数据 WebSocket
        '/mw-ws': {
          target: wsTarget,
          ws: true,
          changeOrigin: true,
          rewrite: () => '/api/v1/simulator/ws',
        },
        // RainViewer 天气雷达索引（该站点未开放 CORS）
        '/rainviewer': {
          target: 'https://api.rainviewer.com',
          changeOrigin: true,
          rewrite: (p) => p.replace(/^\/rainviewer/, ''),
        },
      },
    },
    build: {
      target: 'es2022',
      chunkSizeWarningLimit: 1200,
      rollupOptions: {
        output: {
          // 按依赖归组分包；用 id 判断而非静态映射，
          // 这样尚未被任何模块引用的库不会产出空 chunk。
          manualChunks(id: string) {
            if (!id.includes('node_modules')) return undefined;
            if (id.includes('react-dom') || /node_modules[\\/]react[\\/]/.test(id)) return 'react';
            if (id.includes('leaflet')) return 'leaflet';
            if (id.includes('echarts') || id.includes('zrender')) return 'echarts';
            return undefined;
          },
        },
      },
    },
  };
});
