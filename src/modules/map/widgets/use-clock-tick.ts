import { useEffect, useState } from 'react';

/**
 * 每秒返回一个新的 `Date`，用来驱动秒级跳动的时钟。
 *
 * 时间本身**不进 store**：它每秒都变，放进去会让所有订阅了地图状态的组件
 * 每秒重渲一次。挂在需要显示时钟的组件上，组件不在了定时器就跟着停。
 *
 * `enabled` 为 false 时不起定时器 —— 面板收起来的时候没有走时的必要。
 */
export function useClockTick(enabled = true): Date {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    if (!enabled) return;
    // 先立刻对一次时，避免面板刚展开时先显示一个最多差一秒的旧值
    setNow(new Date());
    const handle = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(handle);
  }, [enabled]);

  return now;
}
