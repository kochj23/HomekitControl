# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.4.0] - 2026-11-11

### Changed
- AI: migrated to NovaAIKit 1.0.0 on iOS, macOS and tvOS (AI on/off, Auto failover across Ollama, MLX, TinyLLM,
  TinyChat, OpenWebUI, Nova Gateway, OpenRouter and OpenAI, model picker and editable URLs, Keychain-only keys under
  com.jkoch.homekitcontrol.*, https-only keys, status indicator, timeouts/retries, validated replies).
- The assistant sends a home summary with each request and answers from home data when AI is off or offline;
  every answer shows its source.

### Added
- macOS AI Assistant sidebar tab; tvOS AI Settings card; NovaAISettingsView in every platform's settings.
- macOS test target (HomekitControlTests) restored in project.yml; 25 AI tests in 7 categories (354 tests total).

### Removed
- AIService (own Ollama/TinyLLM/TinyChat/OpenWebUI/OpenAI/Claude clients), macOS AIBackendManager and
  AIBackendStatusMenu. Claude, Google Cloud, Azure, AWS and IBM Watson backends dropped.

### Security
- One-time migration: the OpenAI key moves to the new Keychain item (old items deleted after a verified copy);
  the Claude key and Google/Azure/AWS/IBM Keychain items are deleted; plaintext AI keys in UserDefaults are removed.

### Fixed
- Unused-result warnings in EncryptedCloudKitSync; hard-coded version strings in Settings/About.

## [1.3.0] - 2026-05-01

### Added
- **Comprehensive XCTest suite** -- 329 tests across 25 test files
- Unit tests for all data models: UnifiedDevice, UnifiedScene, SetupCode, DiscoveredDevice
- Unit tests for all enums: DeviceCategory, Manufacturer, HealthStatus, DeviceProtocol
- Service tests: ExportService (CSV escaping, JSON roundtrip), SceneAnalyzer, ClimateService
- NovaAPIServer HTTP parser tests: request parsing, body JSON, edge cases
- Functional tests: scene execution flow, lookup, health assessment, dangerous device classification
- Security audit tests: credential scanning, Keychain verification, loopback binding, entitlements
- Live API integration tests against port 37432 (skip gracefully if not running)
- Test documentation section in README with run instructions

### Fixed
- Widget extension CFBundleVersion mismatch with parent app (was 2, now aligned to 1)
- Unused variable warning in DeviceHealthRecordTests causing build failure with SWIFT_TREAT_WARNINGS_AS_ERRORS

### Changed
- Version bump to 1.3.0 across all targets (macOS app, widget extension)

## [1.2.0] - 2026-04-11

### Changed
- **macOS build is now Mac Catalyst** — iOS target with `SUPPORTS_MACCATALYST = YES`
- Native `HomeKit.framework` access on macOS via Catalyst (no Shortcuts proxy needed)
- Full device discovery, scene execution, and accessory control on macOS — same as iOS
- API status endpoint now reports `"backend": "HomeKit.framework"` and `"platform": "native"` on macOS
- Requires HomeKit permission in System Settings > Privacy & Security > HomeKit

### Notes
- The v1.1 Shortcuts CLI proxy (in the native macOS target) is still available as a fallback
- Mac Catalyst uses the iOS UI on macOS — all iOS features available

## [1.1.0] - 2026-04-11

### Added
- **macOS Shortcuts CLI proxy** — All HomeKit API endpoints now work on macOS by proxying through macOS Shortcuts app
- **Scene execution endpoint** — `POST /api/scenes/execute` accepts `{"name":"Scene Name"}` with case-insensitive matching
- **Scene listing on macOS** — `GET /api/scenes` returns scene data via "List HomeKit Scenes" Shortcut
- **Accessories on macOS** — `GET /api/accessories` returns device data via "Nova HomeKit Status" Shortcut
- **launchd agent** — `com.jordankoch.homekitcontrol` auto-starts app on login and keeps it alive
- **`runShortcut` helper** — Reusable async Shortcuts CLI bridge in NovaAPIServer for macOS

### Fixed
- **Linker error on macOS** — Removed `-framework HomeKit` from macOS target (HomeKit.framework is not available for native macOS apps, only Mac Catalyst)
- **Broken `-Fsystem` flag** — Removed malformed `-Fsystem /System/Library/Frameworks` from macOS linker flags

### Changed
- **macOS PlatformCapabilities** — `canControlDevices` and `canModifyScenes` now `true` (via Shortcuts proxy)
- **API version** — Bumped to 1.1, status endpoint now reports `platform` and `backend` fields
- **`POST /api/refresh`** — Now properly guarded with `#if canImport(HomeKit)` on the HomeKitService call

## [1.0.0] - 2025-01-01

### Added
- Initial release
- Core functionality
- macOS native interface
- MIT License

---

*For detailed release notes, see [GitHub Releases](https://github.com/kochj23/HomekitControl/releases).*
