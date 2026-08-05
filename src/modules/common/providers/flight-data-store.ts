import { create } from 'zustand';
import {
  emptyFlightDataSnapshot,
  type AirportInfo,
  type FlightData,
  type FlightDataSnapshot,
  type LiveMetarData,
  type SimulatorType,
} from '../models/common-models';
import {
  DEFAULT_POLL_INTERVAL_MS,
  MiddlewareFlightDataAdapter,
  type FlightDataAdapter,
} from './middleware-flight-data-adapter';

/**
 * 全局飞行数据 store
 *
 * 对应 Flutter 版 `flight_data_provider.dart`（即别名 `HomeProvider`）。
 * 本身不含业务逻辑，仅做适配器状态代理 —— 与桌面版职责划分一致。
 *
 * 用法：
 * ```ts
 * const isConnected = useFlightDataStore((s) => s.snapshot.isConnected);
 * ```
 */

interface FlightDataState {
  snapshot: FlightDataSnapshot;
  adapter: FlightDataAdapter | null;

  /** 绑定适配器并订阅其快照流 */
  attachAdapter: (adapter: FlightDataAdapter | null) => void;

  connect: (type: SimulatorType) => Promise<boolean>;
  disconnect: () => Promise<void>;
  refreshBackendHealth: () => Promise<boolean>;
  getFlightDataIntervalMs: () => Promise<number>;
  setFlightDataIntervalMs: (milliseconds: number) => Promise<void>;
  setFlightNumber: (value: string | null) => Promise<void>;
  setDeparture: (airport: AirportInfo | null) => Promise<void>;
  setDestination: (airport: AirportInfo | null) => Promise<void>;
  setAlternate: (airport: AirportInfo | null) => Promise<void>;
  searchAirports: (keyword: string) => Promise<AirportInfo[]>;
  refreshMetar: (airport: AirportInfo) => Promise<void>;
}

/** 适配器订阅的取消句柄 */
let unsubscribeAdapter: (() => void) | null = null;

export const useFlightDataStore = create<FlightDataState>((set, get) => ({
  snapshot: emptyFlightDataSnapshot(),
  adapter: null,

  attachAdapter(adapter) {
    unsubscribeAdapter?.();
    unsubscribeAdapter = null;
    set({ adapter });
    if (!adapter) return;
    unsubscribeAdapter = adapter.subscribe((snapshot) => set({ snapshot }));
    void adapter.refreshBackendHealth();
  },

  async connect(type) {
    return (await get().adapter?.connect(type)) ?? false;
  },

  async disconnect() {
    await get().adapter?.disconnect();
  },

  async refreshBackendHealth() {
    return (await get().adapter?.refreshBackendHealth()) ?? false;
  },

  async getFlightDataIntervalMs() {
    return (await get().adapter?.getFlightDataIntervalMs()) ?? DEFAULT_POLL_INTERVAL_MS;
  },

  async setFlightDataIntervalMs(milliseconds) {
    await get().adapter?.setFlightDataIntervalMs(milliseconds);
  },

  async setFlightNumber(value) {
    await get().adapter?.setFlightNumber(value);
  },

  async setDeparture(airport) {
    await get().adapter?.setDeparture(airport);
  },

  async setDestination(airport) {
    await get().adapter?.setDestination(airport);
  },

  async setAlternate(airport) {
    await get().adapter?.setAlternate(airport);
  },

  async searchAirports(keyword) {
    return (await get().adapter?.searchAirports(keyword)) ?? [];
  },

  async refreshMetar(airport) {
    await get().adapter?.refreshMetar(airport);
  },
}));

// ──────────────────────────────────────────────────────────────────────────
// 快照属性选择器（对应桌面版 FlightDataProvider 的一组 getter 代理）
// 直接把选择器传给 useFlightDataStore，避免整对象订阅导致的无谓重渲染。
// ──────────────────────────────────────────────────────────────────────────

export const flightDataSelectors = {
  snapshot: (s: FlightDataState): FlightDataSnapshot => s.snapshot,
  isConnected: (s: FlightDataState): boolean => s.snapshot.isConnected,
  isBackendReachable: (s: FlightDataState): boolean => s.snapshot.isBackendReachable,
  backendOutageVersion: (s: FlightDataState): number => s.snapshot.backendOutageVersion,
  simulatorType: (s: FlightDataState): SimulatorType => s.snapshot.simulatorType,
  errorMessage: (s: FlightDataState): string | undefined => s.snapshot.errorMessage,
  aircraftTitle: (s: FlightDataState): string | undefined => s.snapshot.aircraftTitle,
  isPaused: (s: FlightDataState): boolean | undefined => s.snapshot.isPaused,
  transponderState: (s: FlightDataState): string | undefined => s.snapshot.transponderState,
  transponderCode: (s: FlightDataState): string | undefined => s.snapshot.transponderCode,
  flightNumber: (s: FlightDataState): string | undefined => s.snapshot.flightNumber,
  hasFlightNumber: (s: FlightDataState): boolean =>
    s.snapshot.flightNumber !== undefined && s.snapshot.flightNumber.length > 0,
  isFuelSufficient: (s: FlightDataState): boolean | undefined => s.snapshot.isFuelSufficient,
  checklistProgress: (s: FlightDataState): number => s.snapshot.checklistProgress ?? 0,
  flightData: (s: FlightDataState): FlightData => s.snapshot.flightData,
  departureAirport: (s: FlightDataState): AirportInfo | undefined => s.snapshot.departureAirport,
  destinationAirport: (s: FlightDataState): AirportInfo | undefined =>
    s.snapshot.destinationAirport,
  alternateAirport: (s: FlightDataState): AirportInfo | undefined => s.snapshot.alternateAirport,
  nearestAirport: (s: FlightDataState): AirportInfo | undefined => s.snapshot.nearestAirport,
  suggestedAirports: (s: FlightDataState): AirportInfo[] => s.snapshot.suggestedAirports,
  metarsByIcao: (s: FlightDataState): Record<string, LiveMetarData> => s.snapshot.metarsByIcao,
  metarErrorsByIcao: (s: FlightDataState): Record<string, string> =>
    s.snapshot.metarErrorsByIcao,
  metarRefreshingIcaos: (s: FlightDataState): Set<string> => s.snapshot.metarRefreshingIcaos,
};

/** 便捷 hooks（等价于桌面版 `context.watch<HomeProvider>().xxx`） */
export const useFlightSnapshot = () => useFlightDataStore(flightDataSelectors.snapshot);
export const useFlightData = () => useFlightDataStore(flightDataSelectors.flightData);
export const useIsSimulatorConnected = () => useFlightDataStore(flightDataSelectors.isConnected);
export const useIsBackendReachable = () =>
  useFlightDataStore(flightDataSelectors.isBackendReachable);

/** 创建并绑定默认的中间件适配器（应用启动时调用一次） */
export function createDefaultFlightDataAdapter(): MiddlewareFlightDataAdapter {
  const adapter = new MiddlewareFlightDataAdapter();
  useFlightDataStore.getState().attachAdapter(adapter);
  return adapter;
}
