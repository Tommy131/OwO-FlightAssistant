# Flight Log UUID Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Give every newly recorded flight log an RFC 4122 UUID so repeated flights, including circuits at one airport, cannot share a persistence key and overwrite each other.

**Architecture:** Generate identity once in `startRecording`, then preserve it through JSON serialization, IndexedDB merging, backend synchronization, filenames, export, and deletion. Existing IDs remain unchanged for backward compatibility.

**Tech Stack:** TypeScript 5.7, Zustand 5, Vitest 3, Web Crypto `crypto.randomUUID()`, Go JSON-file persistence.

## Global Constraints

- Preserve the user's middleware X-Plane/telemetry changes and Web map changes.
- Do not change API routes or the `{ id, record }` request contract.
- Do not rewrite IDs on existing stored or imported logs.
- UUIDs must remain valid under the backend ID whitelist `^[A-Za-z0-9_-]{1,128}$`.

---

### Task 1: Generate collision-resistant flight log identities

**Files:**
- Modify: `src/modules/flight_logs/providers/active-log-recovery.test.ts`
- Modify: `src/modules/flight_logs/providers/flight-logs-store.ts:301`
- Modify: `README.md`
- Modify: `docs/DESIGN.md`

**Interfaces:**
- Consumes: browser `crypto.randomUUID(): string` and the existing `FlightLog.id: string` contract.
- Produces: an RFC 4122 UUID in `activeLog.id`, reused unchanged by `flightLogToJson`, `mergeById`, `pushRecord`, export, and deletion.

- [x] **Step 1: Write the failing regression test**

Fix the system clock, start two recordings at the same instant, and assert that both IDs are distinct UUIDs.

- [x] **Step 2: Run the focused test and verify RED**

Run: `npm test -- src/modules/flight_logs/providers/active-log-recovery.test.ts`

Expected: FAIL because both IDs equal the fixed millisecond timestamp and do not match the UUID pattern.

- [x] **Step 3: Implement the minimal source fix**

Change `id: String(now.getTime())` to `id: crypto.randomUUID()` in `startRecording`.

- [x] **Step 4: Run the focused test and verify GREEN**

Run: `npm test -- src/modules/flight_logs/providers/active-log-recovery.test.ts`.

- [x] **Step 5: Document the persistence invariant**

State that new flight logs use UUIDs, IDs survive synchronization/import unchanged, and backend filenames are `flight_log_<uuid>.json`.

- [x] **Step 6: Run repository quality gates**

Run `npm run check` and `npm run build` in the Web worktree. Run `gofmt -l .`, `go vet ./...`, `go test ./...`, and `go build ./...` in the middleware root.

- [x] **Step 7: Hand off without committing**

Report changed files and verification results without committing over user-owned concurrent changes.
