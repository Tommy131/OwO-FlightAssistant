import { useEffect, useRef, useState } from 'react';
import styles from './marquee-text.module.css';

/**
 * 溢出跑马灯文本
 *
 * 对应 Flutter 版 `selected_airport_bottom_card.dart` 里的 `_AirportHeadlineTicker`：
 * 先量一下文字宽度，放得下就当普通文本渲染，放不下才循环滚动。
 *
 * 卡片在窄屏或长机场名下经常放不下（"Muenchen Franz-Josef-Strauss" 这种），
 * 直接截断会把信息吃掉；滚动能让人看全，又不占额外高度。
 */

/** 滚动速度（像素/秒）—— 与桌面版观感一致 */
const SCROLL_SPEED_PX_PER_SEC = 32;

/** 一轮循环的时长上下限（秒），太快看不清、太慢像卡住 */
const MIN_DURATION_S = 4;
const MAX_DURATION_S = 12;

/** 首尾两份内容之间的空隙 */
const GAP_PX = 24;

export function MarqueeText({
  text,
  className,
  title,
}: {
  text: string;
  className?: string;
  title?: string;
}) {
  const viewportRef = useRef<HTMLSpanElement>(null);
  const measureRef = useRef<HTMLSpanElement>(null);
  const [distance, setDistance] = useState(0);

  useEffect(() => {
    const viewport = viewportRef.current;
    const measure = measureRef.current;
    if (!viewport || !measure) return;

    const sync = () => {
      const contentWidth = measure.scrollWidth;
      const available = viewport.clientWidth;
      // 留 1px 余量：亚像素宽度差会让刚好放得下的文字也误判成溢出
      setDistance(contentWidth > available + 1 ? contentWidth + GAP_PX : 0);
    };

    sync();
    // 卡片会随窗口和展开状态改变宽度，得跟着重新量
    const observer = new ResizeObserver(sync);
    observer.observe(viewport);
    observer.observe(measure);
    return () => observer.disconnect();
  }, [text]);

  const scrolling = distance > 0;
  const duration = Math.min(
    MAX_DURATION_S,
    Math.max(MIN_DURATION_S, distance / SCROLL_SPEED_PX_PER_SEC),
  );

  return (
    <span
      ref={viewportRef}
      className={`${styles.viewport}${className ? ` ${className}` : ''}`}
      title={title ?? text}
      style={
        scrolling
          ? ({
              '--marquee-distance': `${distance}px`,
              '--marquee-gap': `${GAP_PX}px`,
            } as React.CSSProperties)
          : undefined
      }
    >
      {scrolling ? (
        <span className={styles.track} style={{ animationDuration: `${duration}s` }}>
          <span className={styles.segment}>{text}</span>
          <span className={styles.gap} />
          {/* 第二份是为了首尾相接，读屏没必要念两遍 */}
          <span className={styles.segment} aria-hidden="true">
            {text}
          </span>
          <span className={styles.gap} aria-hidden="true" />
        </span>
      ) : (
        <span className={styles.static}>{text}</span>
      )}

      {/*
        量宽用的影子副本：脱离文档流、不可见也不可选，
        只为拿到「文字完整展开时有多宽」——
        真正显示的那份可能正在滚动或被截断，量不出真实宽度。
      */}
      <span
        ref={measureRef}
        aria-hidden="true"
        style={{
          position: 'absolute',
          visibility: 'hidden',
          whiteSpace: 'nowrap',
          pointerEvents: 'none',
          left: 0,
          top: 0,
        }}
      >
        {text}
      </span>
    </span>
  );
}
