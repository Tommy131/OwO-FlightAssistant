import { create } from 'zustand';
import {
  emptyFlightDataSnapshot,
  type AirportInfo,
  type FlightDataSnapshot,
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
  /** 刷新页面后接回后端已有会话 */
  resumeSession: () => Promise<boolean>;
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

  async resumeSession() {
    return (await get().adapter?.resumeSession()) ?? false;
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


/** 创建并绑定默认的中间件适配器（应用启动时调用一次） */
export function createDefaultFlightDataAdapter(): MiddlewareFlightDataAdapter {
  const adapter = new MiddlewareFlightDataAdapter();
  useFlightDataStore.getState().attachAdapter(adapter);
  return adapter;
}
