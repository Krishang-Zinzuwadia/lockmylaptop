# LockMyLaptop Implementation Plan

## Goal
Build an Android app that connects to a Windows laptop using a laptop-generated 4-digit code, then lets the user send remote power actions.

## Project Outputs
1. Android mobile app (Flutter)
2. Mobile app to laptop connection logic (pairing + command channel)

## Scope
- Android only
- Windows laptop target
- One phone paired to one laptop for MVP
- Pairing is done by entering a 4-digit code generated on the laptop

## UI Requirements (MVP)
- Top-right Settings button:
	- Opens settings
	- Allows unpairing the connected laptop
- Main large center Power button:
	- Sends lock command (same behavior as Win+L)
- Secondary Sleep button:
	- Sends sleep command to laptop

## Non-Goals (MVP)
- iOS support
- Full shutdown, restart, file transfer, or remote desktop
- Multi-user account management

## Delivery Phases

## Phase 0: Requirements and Setup
- Confirm exact command mapping:
	- Main center button = lock workstation (Win+L equivalent)
	- Secondary button = sleep laptop
- Create repositories and baseline CI
- Define coding standards and branch strategy

Exit criteria:
- Repos ready
- CI runs lint/test shells

## Phase 1: Base App + Agent Foundation
- Create Flutter Android app shell
- Build initial UI with only two action buttons and one settings entry
- Create Windows laptop agent skeleton (service + command executor)
- Create backend or direct relay service skeleton for command routing

Exit criteria:
- Android app launches with required UI layout
- Laptop agent can start and report ready state

## Phase 2: 4-Digit Pairing Flow
- Laptop agent generates short-lived 4-digit code
- Android app has "Enter Code" screen
- User enters code from laptop into phone
- Backend/relay validates code and binds phone-laptop pair
- Persist pair state on both devices

Exit criteria:
- Valid 4-digit code pairs successfully
- Invalid or expired code is rejected with clear error

## Phase 3: Command Pipeline (Sleep + Lock)
- Implement command send from Android app
- Implement authorization check for paired phone/laptop only
- Route command to laptop agent in real time
- Agent executes:
	- Lock workstation (Win+L equivalent)
	- Sleep command
- Return success/failure status to app

Exit criteria:
- Main center power button locks laptop reliably
- Sleep button puts laptop to sleep reliably

## Phase 4: Settings and Unpair
- Implement top-right Settings screen
- Add unpair action with confirmation
- On unpair, remove local tokens/pair state and revoke pair server-side

Exit criteria:
- Unpair fully disconnects phone from laptop
- Commands are blocked after unpair

## Phase 5: Reliability + Security Hardening
- Add retries, timeout handling, and command acknowledgments
- Ensure transport encryption and secure token storage
- Add basic rate limiting and failed-attempt throttling
- Add audit logs for pairing and command actions

Exit criteria:
- Stable behavior with temporary network failures
- No unauthorized command path in review

## Phase 6: Testing and Release
- Unit tests for pairing validation and command handlers
- Integration tests for code entry -> pair -> command execution
- Windows end-to-end test for both commands
- Build Android release and laptop installer package

Exit criteria:
- Release candidate passes MVP checklist
- Setup and usage docs complete

## MVP Deliverables
- Flutter Android app with:
	- Main center lock button (Win+L equivalent)
	- Sleep button
	- Top-right settings with unpair
- Windows laptop agent with 4-digit code generation and command execution
- Pairing and command transport service
- User setup and troubleshooting guide

## Milestones
1. M1: Android UI skeleton complete
2. M2: 4-digit pairing flow complete
3. M3: Lock and sleep commands work end-to-end
4. M4: Settings unpair flow complete
5. M5: Hardening, testing, and MVP release

## Suggested Timeline (5 Weeks)
1. Week 1: Phase 0 and Phase 1
2. Week 2: Phase 2 pairing
3. Week 3: Phase 3 command pipeline
4. Week 4: Phase 4 settings/unpair + Phase 5 hardening
5. Week 5: Phase 6 testing and release prep

## Risks and Mitigations
- Code guessing risk: short expiry + attempt limits + cooldown
- Agent offline: app shows disconnected state and blocks commands
- Windows permission issues: startup diagnostics and installer checks
- Unclear power semantics: enforce label text in app (Lock and Sleep)

## Immediate Next Build Tasks
1. Scaffold Flutter Android app with two-button layout and settings icon
2. Scaffold Windows agent with 4-digit code generator
3. Build pairing endpoint/relay to validate and bind entered code
4. Wire lock and sleep commands end-to-end
5. Add settings unpair flow and verify command blocking after unpair
