# LockMyLaptop System Design

## 1. Product Goal
Build an Android app that can pair with one Windows laptop using a laptop-generated 4-digit code, then send two remote actions:
- Lock workstation (Win+L equivalent)
- Put laptop to sleep

## 2. MVP Functional Requirements

Pairing:
- Laptop app/agent generates a short-lived 4-digit code.
- User enters that code in the Android app.
- If valid, the phone and laptop become paired.

UI:
- Top-right Settings button:
  - Open settings screen
  - Unpair device
- Main large center Power button:
  - Sends Lock command (same behavior as Win+L)
- Secondary Sleep button:
  - Sends Sleep command

Constraints:
- Android only
- Windows laptop only
- Single phone <-> single laptop pairing for MVP

## 3. Chosen Tech Stack
- Mobile app: Flutter (Android target only)
- Service/API + realtime command transport: ASP.NET Core (.NET 8) + SignalR
- Laptop agent: .NET Worker Service (Windows)
- Persistence: SQLite (single-node MVP) for pair records and command logs

Why this stack:
- Flutter provides fast Android UI delivery.
- SignalR gives reliable real-time command delivery.
- .NET Worker Service is a strong fit for an always-on Windows background process.
- SQLite keeps MVP deployment simple.

## 4. Monorepo Structure
Single repository with unified project root. No frontend/backend split directories by domain naming.

Proposed layout:
- mobile_android/ (Flutter Android app)
- command_service/ (ASP.NET Core API + SignalR hub)
- laptop_agent/ (.NET Worker Service)
- shared_contracts/ (shared DTOs and command enums)
- docs/ (architecture notes, setup notes)

## 5. High-Level Architecture

1. Android App (Flutter)
- Pairing screen for 4-digit code entry
- Home screen with:
  - Main center lock button
  - Sleep button
  - Top-right settings button
- Calls API to pair and send commands

2. Command Service (.NET 8)
- Exposes pair/command endpoints
- Validates pair state
- Maintains active agent connections via SignalR
- Routes lock/sleep commands to paired laptop
- Stores command outcomes

3. Windows Laptop Agent (.NET Worker)
- Generates and refreshes pairing code
- Connects to SignalR hub
- Receives lock/sleep commands
- Executes Windows lock/sleep actions
- Reports command status

## 6. Core Connection Logic

## 6.1 Pairing Flow (4-Digit)
1. Agent starts and requests/generates current 4-digit code.
2. Service stores hashed code with short TTL (for example 90 seconds) mapped to laptop ID.
3. User enters code in Android app.
4. App submits code to POST pair endpoint.
5. Service validates code + TTL + attempt limits.
6. Service marks phone-laptop pair as active.
7. App stores pair token locally.

## 6.2 Command Flow (Lock/Sleep)
1. User taps Lock or Sleep button in app.
2. App sends command with pair token.
3. Service verifies pair token and laptop online status.
4. Service dispatches command to agent through SignalR.
5. Agent executes command and replies with success/failure.
6. Service returns final status to app.

## 6.3 Unpair Flow
1. User taps Settings -> Unpair.
2. App calls unpair endpoint.
3. Service invalidates pair token and pair record.
4. App clears local pair state.
5. Further commands are rejected until new pairing.

## 7. API and Realtime Contracts

REST endpoints:
- POST /api/pair/start-code (agent only)
- POST /api/pair/confirm (app submits 4-digit code)
- POST /api/commands/lock
- POST /api/commands/sleep
- POST /api/pair/unpair
- GET /api/status

SignalR hub methods:
- AgentConnected(laptopId)
- DispatchCommand(commandId, commandType)
- CommandResult(commandId, status, error)

Command types:
- LOCK_WORKSTATION
- SLEEP

## 8. Data Model (MVP)

paired_devices:
- id (uuid)
- laptop_id
- mobile_device_id
- pair_token_hash
- paired_at
- is_active

pairing_codes:
- laptop_id
- code_hash
- expires_at
- attempts

commands:
- id (uuid)
- laptop_id
- command_type (LOCK_WORKSTATION | SLEEP)
- state (queued/sent/succeeded/failed/timeout)
- error
- created_at
- completed_at

## 9. Windows Command Execution

Lock:
- Primary: Win32 LockWorkStation (Win+L equivalent)
- Fallback: rundll32.exe user32.dll,LockWorkStation

Sleep:
- Primary: SetSuspendState API or equivalent managed wrapper
- Fallback: powercfg/rundll invocation as needed

Execution rules:
- Enforce command timeout
- Return explicit error strings for troubleshooting

## 10. Security and Abuse Controls

- TLS for all app/service/agent traffic
- 4-digit code TTL + attempt limits + cooldown window
- Store hashes of pair tokens and pairing codes (not raw values)
- Scope commands to active pair only
- Log pairing, unpairing, and command events

## 11. Reliability Design

- Agent auto-reconnect with exponential backoff
- Service tracks online/offline via SignalR connection events
- Command timeout and retry policy on transient failures
- Idempotency key support for repeated taps

## 12. UX Design Notes (MVP)

Home screen:
- Large center Power button labeled Lock
- Smaller Sleep button below or near primary action
- Settings icon in top-right

Settings screen:
- Device info
- Unpair button with confirmation modal

Error handling:
- Show clear messages for offline laptop, invalid pair, and command timeout

## 13. Delivery Mapping
1. Phase 0: Requirements and setup
2. Phase 1: Base app + agent foundation
3. Phase 2: 4-digit pairing flow
4. Phase 3: Lock/Sleep command pipeline
5. Phase 4: Settings and unpair
6. Phase 5: Reliability + security hardening
7. Phase 6: Testing and release prep
