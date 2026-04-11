# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Performance improvements
- Additional features based on community feedback

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
