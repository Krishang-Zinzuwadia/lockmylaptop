# lockmylaptop

Android-first remote laptop control app for Windows.

## MVP Features
- Pair Android phone with one Windows laptop using a laptop-generated 4-digit code.
- Main center power button sends Lock Workstation (Win+L equivalent).
- Secondary button puts laptop to sleep.
- Settings button supports unpairing.

## Repository Rules
- Monorepo development on branch `dev`.
- Work is delivered phase-by-phase.
- Each phase is committed and pushed before moving to the next phase.

## Repository Structure
- mobile_android/
- command_service/
- laptop_agent/
- shared_contracts/
- tests/
- docs/

## Local Prerequisites
- .NET 8 SDK
- Flutter SDK with Android toolchain

## No-VSCode Runtime (Installed Mode)
You can run LockMyLaptop like a proper installed app without opening VS Code.

1. Build deploy artifacts:
	- Run `powershell -ExecutionPolicy Bypass -File .\scripts\publish.ps1`
2. Install/start Windows services (run terminal as Administrator):
	- Run `powershell -ExecutionPolicy Bypass -File .\scripts\install-services.ps1`
	- If you do not have admin rights, install startup tasks instead:
	  - Run `powershell -ExecutionPolicy Bypass -File .\scripts\install-startup-tasks.ps1`
3. Install release app to phone:
	- APK output: `mobile_android\build\app\outputs\flutter-apk\app-release.apk`

After setup:
- The command service and laptop agent auto-start with Windows.
- You do not need VS Code terminals to run the backend.
- Pairing session is saved on the phone and reused on next app launch.
- Pairing/session state is persisted by command service to disk and survives process restarts.

Quick background runtime (no visible terminals):
- Start: `scripts\start-runtime-background.cmd`
- Stop: `scripts\stop-runtime-background.cmd`

Service control commands:
- Start: `powershell -ExecutionPolicy Bypass -File .\scripts\start-services.ps1`
- Stop: `powershell -ExecutionPolicy Bypass -File .\scripts\stop-services.ps1`
- Uninstall: `powershell -ExecutionPolicy Bypass -File .\scripts\uninstall-services.ps1`

No-admin startup task control:
- Install: `powershell -ExecutionPolicy Bypass -File .\scripts\install-startup-tasks.ps1`
- Remove: `powershell -ExecutionPolicy Bypass -File .\scripts\remove-startup-tasks.ps1`

## Pairing Code Popup Helper
If you need to pair a phone and want to see the laptop code without reading logs, use:

- Double-click `scripts\show-pairing-code.cmd`
- Or run `powershell -ExecutionPolicy Bypass -File .\scripts\show-pairing-code.ps1`

What it does:
- Shows the current 4-digit pairing code in a small always-on-top window.
- Refreshes automatically.
- Includes a `Copy Code` button.
- Auto-starts background runtime when backend is temporarily offline.

Optional arguments:
- `-BaseUrl http://localhost:5000`
- `-LaptopId laptop-local-001`
- `-RefreshSeconds 20`
