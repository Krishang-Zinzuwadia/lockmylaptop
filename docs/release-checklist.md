# Release Checklist (MVP)

## Environment Prerequisites
- Install .NET 8 SDK
- Install Flutter SDK and Android toolchain
- Configure Android emulator or physical Android device

## Build and Test
- Run service unit tests:
  - dotnet test tests/LockMyLaptop.CommandService.Tests/LockMyLaptop.CommandService.Tests.csproj
- Build service:
  - dotnet build command_service/LockMyLaptop.CommandService.csproj
- Build laptop agent:
  - dotnet build laptop_agent/LockMyLaptop.LaptopAgent.csproj
- Build Android app:
  - flutter build apk

## Manual E2E Validation
1. Start command service.
2. Start laptop agent and verify 4-digit code appears in logs.
3. Open Android app and enter pairing code.
4. Verify connected state in app.
5. Tap center Power button and verify laptop locks (Win+L behavior).
6. Tap Sleep button and verify laptop sleeps.
7. Open settings and unpair.
8. Verify commands are blocked after unpair.

## Release Notes Template
- Features:
  - 4-digit pairing
  - Lock and sleep controls
  - Settings unpair
- Security:
  - hashed pairing/token storage
  - rate limiting and idempotency
- Known limits:
  - Android only
  - Single pair for MVP
