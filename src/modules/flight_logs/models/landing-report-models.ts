import { toDouble, toJsonMap, toText, type JsonMap } from '../../../core/utils/parse-utils';
import {
  flightLogPointFromJson,
  flightLogPointToJson,
  landingDataFromJson,
  landingDataToJson,
  type FlightLogPoint,
  type LandingData,
} from './flight-log-models';
import {
  recordingEndReasonFromRaw,
  recordingStatusFromRaw,
  type RecordingEndReason,
  type RecordingStatus,
} from './recording-status';

export interface LandingReport {
  id: string;
  simulator: string;
  aircraftTitle?: string;
  aircraftType?: string;
  airport?: string;
  startedAt: number;
  endedAt: number;
  touchdownAt?: number;
  status: RecordingStatus;
  endReason: RecordingEndReason;
  points: FlightLogPoint[];
  landing?: LandingData;
  createdAt: number;
  updatedAt: number;
}

/**
 * A report decoded from persistence. Producers always emit `LandingReport`
 * with one of the six known reasons; older or forward-version storage may not.
 */
export type StoredLandingReport = Omit<LandingReport, 'endReason'> & {
  endReason: RecordingEndReason | undefined;
};

export function serializeLandingReport(report: StoredLandingReport): JsonMap {
  return {
    id: report.id,
    simulator: report.simulator,
    aircraft_title: report.aircraftTitle ?? null,
    aircraft_type: report.aircraftType ?? null,
    airport: report.airport ?? null,
    started_at: report.startedAt,
    ended_at: report.endedAt,
    touchdown_at: report.touchdownAt ?? null,
    status: report.status,
    end_reason: report.endReason ?? null,
    points: report.points.map(flightLogPointToJson),
    landing: report.landing ? landingDataToJson(report.landing) : null,
    created_at: report.createdAt,
    updated_at: report.updatedAt,
  };
}

export function deserializeLandingReport(json: JsonMap): StoredLandingReport {
  return {
    id: toText(json.id) || crypto.randomUUID(),
    simulator: toText(json.simulator) || 'Unknown',
    aircraftTitle: optionalText(json.aircraft_title),
    aircraftType: optionalText(json.aircraft_type),
    airport: optionalText(json.airport)?.toUpperCase(),
    startedAt: toDouble(json.started_at) ?? 0,
    endedAt: toDouble(json.ended_at) ?? 0,
    touchdownAt: toDouble(json.touchdown_at),
    status: recordingStatusFromRaw(json.status),
    endReason: recordingEndReasonFromRaw(json.end_reason),
    points: pointsFromJson(json.points),
    landing: landingDataFromJson(toJsonMap(json.landing)),
    createdAt: toDouble(json.created_at) ?? 0,
    updatedAt: toDouble(json.updated_at) ?? 0,
  };
}

function optionalText(raw: unknown): string | undefined {
  const value = toText(raw).trim();
  return value.length > 0 ? value : undefined;
}

function pointsFromJson(raw: unknown): FlightLogPoint[] {
  if (!Array.isArray(raw)) return [];
  return raw
    .map(toJsonMap)
    .filter((point): point is JsonMap => point !== null)
    .map(flightLogPointFromJson);
}
