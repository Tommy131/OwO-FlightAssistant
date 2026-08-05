import { useEffect, useState } from 'react';

/**
 * 响应式断点
 *
 * 对应 Flutter 版 `core/layouts/responsive.dart`，断点数值完全一致：
 *   - mobile  : < 650
 *   - tablet  : 650 – 1241（回退使用 mobile 布局，与桌面版行为相同）
 *   - desktop : >= 1242
 */

export const BREAKPOINT_TABLET = 650;
export const BREAKPOINT_DESKTOP = 1242;

export type Breakpoint = 'mobile' | 'tablet' | 'desktop';

export function resolveBreakpoint(width: number): Breakpoint {
  if (width >= BREAKPOINT_DESKTOP) return 'desktop';
  if (width >= BREAKPOINT_TABLET) return 'tablet';
  return 'mobile';
}

/** 订阅窗口宽度，返回当前断点 */
export function useBreakpoint(): Breakpoint {
  const [breakpoint, setBreakpoint] = useState<Breakpoint>(() =>
    resolveBreakpoint(typeof window === 'undefined' ? BREAKPOINT_DESKTOP : window.innerWidth),
  );

  useEffect(() => {
    const handleResize = () => setBreakpoint(resolveBreakpoint(window.innerWidth));
    handleResize();
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);

  return breakpoint;
}

/** 是否使用桌面布局（tablet 与 mobile 共用移动布局，与桌面版一致） */
export function useIsDesktopLayout(): boolean {
  return useBreakpoint() === 'desktop';
}

/** 订阅窗口宽度原始值（地图 HUD、图表等需要精确宽度的场景） */
export function useWindowWidth(): number {
  const [width, setWidth] = useState(() =>
    typeof window === 'undefined' ? BREAKPOINT_DESKTOP : window.innerWidth,
  );
  useEffect(() => {
    const handleResize = () => setWidth(window.innerWidth);
    window.addEventListener('resize', handleResize);
    return () => window.removeEventListener('resize', handleResize);
  }, []);
  return width;
}
