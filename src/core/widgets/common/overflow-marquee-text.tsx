import { useEffect, useRef, useState, type CSSProperties } from 'react';
import styles from './overflow-marquee-text.module.css';

/**
 * 溢出跑马灯文本
 *
 * 对应 Flutter 版 `core/widgets/common/overflow_marquee_text.dart`：
 * 文本未超出容器时静态显示，超出后循环滚动。
 * 侧边栏折叠、机场长名称、METAR 报文等处使用。
 */
export interface OverflowMarqueeTextProps {
  text: string;
  /** 每秒滚动像素数 */
  speed?: number;
  /** 一轮结束后的停顿（毫秒） */
  pauseMs?: number;
  /** 仅在鼠标悬停时滚动 */
  onHoverOnly?: boolean;
  className?: string;
  style?: CSSProperties;
  title?: string;
}

export function OverflowMarqueeText({
  text,
  speed = 30,
  pauseMs = 1200,
  onHoverOnly = false,
  className,
  style,
  title,
}: OverflowMarqueeTextProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const contentRef = useRef<HTMLSpanElement>(null);
  const [overflowPx, setOverflowPx] = useState(0);

  // 文本或容器尺寸变化时重新测量溢出量
  useEffect(() => {
    const container = containerRef.current;
    const content = contentRef.current;
    if (!container || !content) return;

    const measure = () => {
      const overflow = content.scrollWidth - container.clientWidth;
      setOverflowPx(overflow > 1 ? overflow : 0);
    };

    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(container);
    observer.observe(content);
    return () => observer.disconnect();
  }, [text]);

  const shouldScroll = overflowPx > 0;
  // 往返一轮的时长 = 滚动距离 / 速度 + 两端停顿
  const durationSec = shouldScroll ? overflowPx / speed + (pauseMs * 2) / 1000 : 0;

  return (
    <div
      ref={containerRef}
      className={[
        styles.container,
        shouldScroll ? styles.scrollable : '',
        onHoverOnly ? styles.hoverOnly : '',
        className,
      ]
        .filter(Boolean)
        .join(' ')}
      style={style}
      title={title ?? (shouldScroll ? text : undefined)}
    >
      <span
        ref={contentRef}
        className={styles.content}
        style={
          shouldScroll
            ? ({
                '--marquee-shift': `-${overflowPx}px`,
                '--marquee-duration': `${durationSec}s`,
              } as CSSProperties)
            : undefined
        }
      >
        {text}
      </span>
    </div>
  );
}
