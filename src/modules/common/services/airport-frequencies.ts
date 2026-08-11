/**
 * 机场通讯频率的归类与合并（纯函数）
 *
 * 不碰 React / Zustand / IO —— 机场查询页与地图机场卡都用它，
 * 两处显示的分类与配色必须是同一份，否则同一个机场在两个页面上
 * 会被归成不同的类。
 *
 * ── 为什么要合并 ──
 * 导航库里同一类频率是**逐条**存的：ZBAA 光地面就有 121.900 / 121.800 /
 * 121.700 / 121.750 / 121.850 五条，塔台三条、进近七条。原样一条一行的话，
 * 一个大机场能列出二十多行，真正要找的「塔台是多少」反而淹在里面。
 * 按类别合并成一行之后，行数固定在个位数，一眼扫得完。
 */

/** 归一化之后的频率类别 */
export type FrequencyCategory =
  | 'atis'
  | 'clearance'
  | 'ground'
  | 'tower'
  | 'approach'
  | 'departure'
  | 'center'
  | 'unicom'
  | 'other';

/** 一类频率合并后的结果 */
export interface FrequencyGroup {
  category: FrequencyCategory;
  /** 展示用的类别名（取该类第一条的原始写法，保留导航库的叫法） */
  label: string;
  /** 该类下的全部频率值，按出现顺序、已去重 */
  values: string[];
}

/** 输入形状：只要有类型和值就行，两个模块的模型都能直接喂进来 */
export interface FrequencyLike {
  type?: string;
  value?: string;
}

/**
 * 类别 → 主题令牌。
 *
 * 用的是主题变量而不是写死的色值，浅色/深色主题切换时才不会有一类颜色发虚。
 * 分配原则是「按管制流程的先后顺序走一遍色相」，并让相邻环节的颜色明显不同：
 * 放行→地面→塔台→进近/离场 是飞行员实际会依次调到的四个频率，
 * 挨着的两类撞色会让人念错频率。
 */
export const FREQUENCY_CATEGORY_COLOR: Record<FrequencyCategory, string> = {
  atis: 'var(--color-secondary)',
  clearance: '#a78bfa',
  ground: '#38bdf8',
  tower: '#34d399',
  approach: '#fbbf24',
  departure: '#fb923c',
  center: '#f472b6',
  unicom: '#94a3b8',
  other: 'var(--color-text-secondary)',
};

/**
 * 类别判定的关键词表。
 *
 * ⚠️ 顺序即优先级，不能按字母排。
 * "DEPARTURE" 必须排在 "APPROACH" 之前 —— 有些库把离场写成
 * "APPROACH/DEPARTURE"，先匹配 APPROACH 的话离场就被吞进进近里了。
 * 同理 "GROUND" 要在 "GND" 之前不重要（互不包含），但 "DEL" 属于
 * CLEARANCE DELIVERY 的简写，得跟 CLEARANCE 归一类。
 */
const CATEGORY_RULES: readonly { category: FrequencyCategory; keywords: readonly string[] }[] = [
  { category: 'atis', keywords: ['ATIS', 'AWOS', 'ASOS'] },
  { category: 'departure', keywords: ['DEPARTURE', 'DEPART', 'DEP'] },
  { category: 'clearance', keywords: ['CLEARANCE', 'DELIVERY', 'CLNC', 'DEL'] },
  { category: 'ground', keywords: ['GROUND', 'GND'] },
  { category: 'tower', keywords: ['TOWER', 'TWR'] },
  { category: 'approach', keywords: ['APPROACH', 'APPROACHDEP', 'APP', 'ARRIVAL', 'ARR'] },
  { category: 'center', keywords: ['CENTER', 'CENTRE', 'CTR', 'RADIO', 'CONTROL'] },
  { category: 'unicom', keywords: ['UNICOM', 'CTAF', 'MULTICOM'] },
];

/** 各类别在表格里的固定排列顺序：与飞行中实际调频的先后一致 */
const CATEGORY_ORDER: readonly FrequencyCategory[] = [
  'atis',
  'clearance',
  'ground',
  'tower',
  'departure',
  'approach',
  'center',
  'unicom',
  'other',
];

/** 把导航库里五花八门的类型字符串归到固定类别 */
export function classifyFrequency(rawType: string | undefined): FrequencyCategory {
  const normalized = (rawType ?? '').toUpperCase().replace(/[^A-Z]/g, '');
  if (normalized.length === 0) return 'other';
  for (const rule of CATEGORY_RULES) {
    if (rule.keywords.some((keyword) => normalized.includes(keyword))) return rule.category;
  }
  return 'other';
}

/**
 * 按类别合并频率。
 *
 * 同类的值拼在一起、去重且保持原顺序（导航库里第一条通常是主用频率，
 * 排序会把主用频率挪到后面去，所以这里只去重不排序）。
 * 类别之间按 CATEGORY_ORDER 排，让每个机场的表格结构一致。
 */
export function groupFrequencies(frequencies: readonly FrequencyLike[]): FrequencyGroup[] {
  const buckets = new Map<FrequencyCategory, FrequencyGroup>();

  for (const frequency of frequencies) {
    const value = (frequency.value ?? '').trim();
    if (value.length === 0) continue;

    const category = classifyFrequency(frequency.type);
    const label = (frequency.type ?? '').trim();

    const existing = buckets.get(category);
    if (!existing) {
      buckets.set(category, {
        category,
        // 归到 other 的保留原始写法（可能是 "FSS"、"EMERGENCY" 这类），
        // 有明确类别的则统一大写，免得同一类因大小写不同显示成两种样子
        label: category === 'other' ? label || 'OTHER' : (label || category).toUpperCase(),
        values: [value],
      });
      continue;
    }
    if (!existing.values.includes(value)) existing.values.push(value);
  }

  return CATEGORY_ORDER.map((category) => buckets.get(category)).filter(
    (group): group is FrequencyGroup => group !== undefined,
  );
}

/** 合并后的频率值拼成一行展示用的字符串 */
export function formatFrequencyValues(values: readonly string[]): string {
  return values.join(' / ');
}
