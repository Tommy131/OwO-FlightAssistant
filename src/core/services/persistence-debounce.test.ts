import { describe, expect, it, vi } from 'vitest';

/**
 * 落盘防抖
 *
 * 这里复刻 `PersistenceService.scheduleSave` 的调度骨架，用来钉死一个
 * **会永久挂死所有调用方**的写法（真实出现过）：
 *
 *     if (timer) clearTimeout(timer);
 *     pending ??= new Promise((resolve) => {
 *       timer = setTimeout(...);        // ← 只在 Promise 新建时才排定时器
 *     });
 *
 * 第二次调用 clearTimeout 掉了定时器，而 `??=` 见 pending 非空便不再进入回调，
 * 于是新的定时器压根没排：resolve 永不调用、pending 永不复位，
 * 之后每一次 await 都拿到同一个死 Promise。
 *
 * 真实服务依赖 IndexedDB，没法在 node 环境直接跑，所以这里只测调度逻辑本身 ——
 * 而 bug 恰恰就在调度逻辑里。
 */

/** 与 persistence-service.ts 中同构的实现 */
function createScheduler(flush: () => Promise<void>, delayMs = 300) {
  let timer: ReturnType<typeof setTimeout> | null = null;
  let pending: Promise<void> | null = null;
  let pendingResolve: (() => void) | null = null;

  return {
    schedule(): Promise<void> {
      if (timer !== null) clearTimeout(timer);
      pending ??= new Promise<void>((resolve) => {
        pendingResolve = resolve;
      });
      // 关键：每次调用都重新排定时器，与 Promise 的创建解耦
      timer = setTimeout(() => {
        timer = null;
        const resolve = pendingResolve;
        pending = null;
        pendingResolve = null;
        void flush().finally(() => resolve?.());
      }, delayMs);
      return pending;
    },
    cancel(): void {
      if (timer !== null) clearTimeout(timer);
      timer = null;
      pendingResolve?.();
      pending = null;
      pendingResolve = null;
    },
  };
}

describe('落盘防抖', () => {
  it('单次调用会在延迟后落盘并 resolve', async () => {
    vi.useFakeTimers();
    const flush = vi.fn(() => Promise.resolve());
    const scheduler = createScheduler(flush);

    const done = scheduler.schedule();
    expect(flush).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(300);
    await done;
    expect(flush).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });

  it('连续写入合并成一次落盘，且**每个调用方都会被放行**', async () => {
    // 这条是本文件存在的理由：旧实现下第二次 schedule 会让所有等待者永久挂起
    vi.useFakeTimers();
    const flush = vi.fn(() => Promise.resolve());
    const scheduler = createScheduler(flush);

    const first = scheduler.schedule();
    await vi.advanceTimersByTimeAsync(100);
    const second = scheduler.schedule();
    await vi.advanceTimersByTimeAsync(100);
    const third = scheduler.schedule();

    await vi.advanceTimersByTimeAsync(300);
    await Promise.all([first, second, third]);

    // 三次写入只落盘一次（防抖生效）
    expect(flush).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });

  it('防抖窗口内反复写入不会饿死落盘', async () => {
    vi.useFakeTimers();
    const flush = vi.fn(() => Promise.resolve());
    const scheduler = createScheduler(flush);

    const waits: Promise<void>[] = [];
    for (let i = 0; i < 10; i++) {
      waits.push(scheduler.schedule());
      await vi.advanceTimersByTimeAsync(50);
    }
    await vi.advanceTimersByTimeAsync(300);
    await Promise.all(waits);

    expect(flush).toHaveBeenCalledTimes(1);
    vi.useRealTimers();
  });

  it('新一轮写入会重新开始，不会复用已完成的 Promise', async () => {
    vi.useFakeTimers();
    const flush = vi.fn(() => Promise.resolve());
    const scheduler = createScheduler(flush);

    await (async () => {
      const p = scheduler.schedule();
      await vi.advanceTimersByTimeAsync(300);
      await p;
    })();

    const next = scheduler.schedule();
    await vi.advanceTimersByTimeAsync(300);
    await next;

    expect(flush).toHaveBeenCalledTimes(2);
    vi.useRealTimers();
  });

  it('取消待落盘时必须放行等待者，否则它们会永远挂着', async () => {
    vi.useFakeTimers();
    const flush = vi.fn(() => Promise.resolve());
    const scheduler = createScheduler(flush);

    const waiting = scheduler.schedule();
    scheduler.cancel();

    // 不该落盘，但等待者必须被放行
    await vi.advanceTimersByTimeAsync(500);
    await expect(waiting).resolves.toBeUndefined();
    expect(flush).not.toHaveBeenCalled();
    vi.useRealTimers();
  });
});
