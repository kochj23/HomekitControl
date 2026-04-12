# HomekitControl

![Build](https://github.com/kochj23/HomekitControl/actions/workflows/build.yml/badge.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20tvOS%20%7C%20macOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/license-MIT-green)

A unified multi-platform smart home control application for iOS, tvOS, and macOS. HomekitControl consolidates five previous HomeKit projects into a single app with native HomeKit.framework access, a local REST API for AI integration, network discovery, device health monitoring, energy tracking, security dashboards, and more.

Written by Jordan Koch.

---

## Architecture

```
+------------------------------------------------------------------+
|                       HomekitControl                             |
|                                                                  |
|   +------------------+  +----------------+  +----------------+   |
|   |     iOS App      |  |   tvOS App     |  |   macOS App    |   |
|   | (Full features)  |  | (10-ft UI)     |  | (Mac Catalyst) |   |
|   | + WidgetKit ext  |  |                |  |                |   |
|   +--------+---------+  +-------+--------+  +-------+--------+   |
|            |                    |                    |            |
|            +--------------------+--------------------+            |
|                                 |                                |
|                    +------------+------------+                    |
|                    |     Shared Layer        |                    |
|                    |                         |                    |
|  +-----------------+-------------------------+-----------------+  |
|  |                                                             |  |
|  |  HomeKitService         - HMHomeManager delegate            |  |
|  |  NovaAPIServer          - REST API on port 37432            |  |
|  |  NetworkDiscoveryService - Bonjour/mDNS scanner             |  |
|  |  SecurityService        - Locks, sensors, zones, alerts     |  |
|  |  AIService              - Multi-backend AI assistant        |  |
|  |  ClimateService         - Thermostat zones + scheduling     |  |
|  |  EnergyMonitoringService - Watt/kWh tracking + cost         |  |
|  |  AutomationService      - Visual trigger/action builder     |  |
|  |  SceneAnalyzerService   - Scene diagnostics + repair        |  |
|  |  CodeVaultService       - Setup codes in Keychain           |  |
|  |  DeviceHealthService    - Reachability + reliability scores |  |
|  |  BackupService          - Full config backup/restore        |  |
|  |  FirmwareTrackerService - Version tracking + updates        |  |
|  |  FloorPlanService       - Device placement visualization    |  |
|  |  PresenceService        - Geofencing + occupancy            |  |
|  |  GuestModeService       - Temporary limited access          |  |
|  |  IntegrationHubService  - Matter / Thread / Zigbee / Z-Wave |  |
|  |  AdaptiveLightingService - Circadian rhythm automation      |  |
|  |  ExportService          - CSV / JSON export                 |  |
|  |  NotificationService    - Push alerts for security events   |  |
|  |  VoiceControlService    - Siri + voice commands             |  |
|  |  SiriShortcutsService   - Shortcuts integration             |  |
|  |  WidgetSyncService      - App Group data for WidgetKit      |  |
|  |                                                             |  |
|  +-----------------------+---------+---------------------------+  |
|                          |         |                              |
|                +---------+--+  +---+---------+                    |
|                |  Models    |  |  Design     |                    |
|                | UnifiedDev |  | Glassmorphic|                    |
|                | UnifiedScn |  | GlassCard   |                    |
|                | SetupCode  |  | CircGauge   |                    |
|                | DiscDevice |  | ModernColor |                    |
|                +------------+  +-------------+                    |
+------------------------------------------------------------------+
                          |
              +-----------+-----------+
              | Nova / Claude Code    |
              | REST client on        |
              | 127.0.0.1:37432       |
              +-----------------------+
```

---

## Heritage

HomekitControl unifies the functionality of five earlier projects:

| Predecessor | Capability |
|---|---|
| HomeKitAdopter | Network discovery and security audit |
| HomeKitAssistant | Basic device control |
| HomeKitRestore | Setup code vault |
| HomeKitTV | Full device and scene control |
| SceneFixer | Scene diagnostics and AI repair |

---

## Features

### Device Control
- Toggle power, set brightness, and adjust color for lights, switches, and outlets
- Room-organized accessory listing with reachability indicators
- Device health monitoring with reliability scores and response-time tracking
- Firmware version tracking with update detection
- Device comparison across manufacturers and protocols
- Device grouping for batch operations

### Scene Management
- List, execute, and analyze HomeKit scenes
- Scene repair: detect unreachable accessories in a scene and suggest fixes (iOS)
- Scene scheduling with time, sunrise/sunset, and device-state triggers
- AI-powered scene suggestions based on usage patterns

### Security Dashboard
- Unified view of locks, motion sensors, contact sensors, smoke/CO/water sensors, cameras, and alarms
- Security modes: Disarmed, Home, Away, Night
- Zone-based arming (perimeter, interior, custom zones)
- Event log with timestamps and device context
- Quiet hours configuration for alert suppression
- Lock-all-doors shortcut in Away mode
- Push notifications for triggered sensors (iOS)

### Network Discovery
- Bonjour/mDNS scanning for HomeKit, Matter, Google Cast, Philips Hue, Nanoleaf, Sonos, AirPlay, and more
- Protocol detection: HomeKit (HAP), Matter, Thread, Wi-Fi
- Manufacturer identification from TXT records
- Device category classification (light, thermostat, lock, camera, speaker, sensor, bridge, etc.)

### Climate Control
- Multi-thermostat zone coordination
- Per-zone scheduling with day-of-week granularity
- Occupancy-based setback when rooms are unoccupied
- Temperature mode management (heat, cool, auto, off)

### Energy Monitoring
- Real-time watt readings from power-reporting accessories
- Daily kWh aggregation with peak/average tracking
- Cost estimation based on configurable utility rates
- Per-device and whole-home energy views

### Adaptive Lighting
- Circadian rhythm profiles that shift color temperature throughout the day
- Motion-activated lighting with configurable timeout
- Ambient light threshold gating

### Automation Builder
- Visual trigger/condition/action workflow editor
- Trigger types: time, sunrise, sunset, device state, location, manual
- Multi-action scenes with conditional logic

### Floor Plan Visualization
- Import floor plan images and place devices on a spatial map
- Multi-level support (basement, ground, upper floors)
- Tap-to-control from the floor plan view

### Presence and Geofencing
- Configurable geofence regions with entry/exit scene triggers
- Occupancy sensor integration for room-level presence

### Guest Mode
- Temporary access codes with configurable expiration
- Per-device and per-scene access whitelisting
- Usage tracking and access logging

### Integration Hub
- Protocol dashboard for Matter, Thread, Zigbee, and Z-Wave devices
- Sync status and device counts per protocol

### Backup and Restore
- Full HomeKit configuration snapshots (accessories, rooms, scenes, automations)
- Named backups with versioning
- Restore from backup

### Setup Code Vault
- Secure Keychain storage for HomeKit setup codes (8-digit pairing codes)
- Photo attachment for physical code labels
- Search and organize codes by device name

### AI Assistant
- Multi-backend support: Ollama, TinyLLM, TinyChat, OpenWebUI, OpenAI, Claude
- Device analysis: performance insights and recommendations per accessory
- Scene analysis: reliability assessment and repair suggestions
- Network analysis: security considerations and protocol diversity review
- Smart home Q&A chat interface
- Backend health checks with auto-discovery

### Data Export
- Export device inventory to CSV or JSON
- Export scene configurations
- ISO 8601 timestamps, sorted keys, human-readable formatting

### iOS Home Screen Widget
- Small: unreachable device count and overall health status
- Medium: device health summary with quick scene buttons
- Large: full dashboard with health details, device counts, and favorite scenes
- Real-time data via App Group (`group.com.jkoch.homekitcontrol`)
- 15-minute automatic refresh cycle

### Voice and Shortcuts
- Siri voice command integration
- macOS Shortcuts app bridge for scene execution and status queries

---

## Platform Capabilities

| Feature | iOS | tvOS | macOS (Catalyst) |
|---|:---:|:---:|:---:|
| Device Control | Yes | Yes | Yes |
| Scene Execution | Yes | Yes | Yes |
| Scene Repair | Yes | -- | -- |
| Network Discovery | Yes | Yes | Yes |
| AI Assistant | Yes | Yes | Yes |
| Security Dashboard | Yes | Yes | Yes |
| Climate Zones | Yes | Yes | Yes |
| Energy Monitoring | Yes | Yes | Yes |
| Automation Builder | Yes | Yes | Yes |
| Floor Plans | Yes | -- | Yes |
| Presence / Geofencing | Yes | -- | Yes |
| Guest Mode | Yes | -- | Yes |
| Setup Code Vault | Yes | -- | Yes |
| Firmware Tracker | Yes | Yes | Yes |
| Backup / Restore | Yes | -- | Yes |
| Data Export (CSV/JSON) | Yes | -- | Yes |
| Home Screen Widget | Yes | -- | -- |
| Siri / Shortcuts | Yes | -- | Yes |
| Nova API Server | Yes | Yes | Yes |

The macOS build uses Mac Catalyst (`SUPPORTS_MACCATALYST = YES`), giving it full native `HomeKit.framework` access. No Shortcuts proxy is needed as of v1.2, though the v1.1 Shortcuts CLI bridge remains available as a fallback for the native macOS target.

---

## Nova API Server

HomekitControl exposes a local HTTP REST API on port **37432** for integration with Nova (OpenClaw AI familiar) and Claude Code. The server binds exclusively to `127.0.0.1` -- there is no external network exposure.

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/status` | App status, version, uptime, home/accessory/scene counts, backend type |
| `GET` | `/api/ping` | Health check (returns `{"pong": "true"}`) |
| `GET` | `/api/homes` | Home names and UUIDs |
| `GET` | `/api/accessories` | All accessories with room, reachability, services, and characteristics |
| `GET` | `/api/scenes` | Scene names and UUIDs |
| `POST` | `/api/scenes/execute` | Execute a scene by name (case-insensitive). Body: `{"name": "Scene Name"}` |
| `POST` | `/api/refresh` | Trigger a full HomeKit data refresh |

### Example Usage

```bash
# Health check
curl http://127.0.0.1:37432/api/ping

# App status with uptime and backend info
curl http://127.0.0.1:37432/api/status

# List all homes
curl http://127.0.0.1:37432/api/homes

# List all accessories with services and characteristics
curl http://127.0.0.1:37432/api/accessories

# List all scenes
curl http://127.0.0.1:37432/api/scenes

# Execute a scene by name
curl -X POST http://127.0.0.1:37432/api/scenes/execute \
  -H "Content-Type: application/json" \
  -d '{"name": "Good Morning"}'

# Force a data refresh
curl -X POST http://127.0.0.1:37432/api/refresh
```

### Status Response Fields

```json
{
  "status": "running",
  "app": "HomekitControl",
  "version": "1.1",
  "port": "37432",
  "platform": "native",
  "backend": "HomeKit.framework",
  "uptimeSeconds": 3600,
  "homes": 1,
  "accessories": 42,
  "scenes": 12
}
```

### Error Handling

- `400` -- Missing or malformed request body (e.g., no `name` field on scene execute)
- `404` -- Scene not found (response includes `available_scenes` array) or unknown endpoint
- `500` -- Scene execution failed (response includes error description)

### macOS Shortcuts Fallback (v1.1)

On the native macOS target (non-Catalyst), the API proxies through macOS Shortcuts. This requires three Shortcuts installed in Shortcuts.app:

| Shortcut Name | Purpose |
|---|---|
| Nova HomeKit Status | Returns JSON array of accessories |
| List HomeKit Scenes | Returns JSON array of scene names |
| Execute HomeKit Scene | Takes scene name as input, executes it |

The Mac Catalyst build (v1.2+) does not need these Shortcuts.

### Auto-Launch

A launchd agent (`com.jordankoch.homekitcontrol`) keeps the app running on macOS. It starts automatically at login and restarts the app if it crashes. The API server starts when the app launches.

---

## Requirements

| Platform | Minimum Version |
|---|---|
| iOS | 17.0+ |
| tvOS | 17.0+ |
| macOS | 14.0+ (Sonoma) |
| Xcode | 16.0+ |
| Swift | 5.9 |

---

## Installation

### macOS (DMG)

HomekitControl is distributed as a DMG installer. There is no Mac App Store distribution. The app runs without sandbox restrictions to allow full HomeKit and local network access.

1. Download the latest `.dmg` from [Releases](https://github.com/kochj23/HomekitControl/releases)
2. Open the DMG and drag HomekitControl to your Applications folder
3. Launch HomekitControl
4. Grant HomeKit permission: **System Settings > Privacy & Security > HomeKit** -- toggle HomekitControl to ON
5. Grant local network permission when prompted

### iOS / tvOS

Build from source using Xcode:

1. Clone the repository
2. Run `xcodegen generate` to create the Xcode project
3. Open `HomekitControl.xcodeproj`
4. Select the iOS or tvOS target and build to your device

### Building from Source (All Platforms)

```bash
git clone git@github.com:kochj23/HomekitControl.git
cd HomekitControl
xcodegen generate
open HomekitControl.xcodeproj
```

Select the desired scheme (`HomekitControl-iOS`, `HomekitControl-tvOS`, or `HomekitControl-macOS`) and build.

---

## Project Structure

```
HomekitControl/
|-- Shared/
|   |-- Models/
|   |   |-- UnifiedDevice.swift         # Core device model
|   |   |-- UnifiedScene.swift          # Core scene model
|   |   |-- SetupCode.swift             # Setup code vault model
|   |   |-- DiscoveredDevice.swift      # Network discovery model
|   |   +-- Enums/                      # DeviceCategory, DeviceProtocol, HealthStatus, Manufacturer
|   |-- Services/
|   |   |-- HomeKitService.swift        # HMHomeManager delegate, device/scene CRUD
|   |   |-- NovaAPIServer.swift         # REST API server (port 37432)
|   |   |-- AIService.swift             # Multi-backend AI chat + analysis
|   |   |-- NetworkDiscoveryService.swift  # Bonjour/mDNS browser
|   |   |-- SecurityService.swift       # Locks, sensors, zones, alerts
|   |   |-- ClimateService.swift        # Thermostat zones + scheduling
|   |   |-- EnergyMonitoringService.swift  # Watt/kWh tracking
|   |   |-- AutomationService.swift     # Trigger/condition/action builder
|   |   |-- SceneAnalyzerService.swift  # Scene diagnostics + repair
|   |   |-- CodeVaultService.swift      # Keychain-backed setup codes
|   |   |-- DeviceHealthService.swift   # Reachability + response time
|   |   |-- BackupService.swift         # Config backup/restore
|   |   |-- FirmwareTrackerService.swift   # Firmware version tracking
|   |   |-- FloorPlanService.swift      # Spatial device placement
|   |   |-- PresenceService.swift       # Geofencing + occupancy
|   |   |-- GuestModeService.swift      # Temporary access codes
|   |   |-- IntegrationHubService.swift # Matter/Thread/Zigbee/Z-Wave
|   |   |-- AdaptiveLightingService.swift  # Circadian rhythm profiles
|   |   |-- ExportService.swift         # CSV + JSON export
|   |   |-- NotificationService.swift   # Push alert delivery
|   |   |-- VoiceControlService.swift   # Siri voice commands
|   |   |-- SiriShortcutsService.swift  # Shortcuts integration
|   |   +-- WidgetSyncService.swift     # App Group sync for widget
|   |-- Design/
|   |   |-- GlassmorphicBackground.swift   # Glassmorphic visual style
|   |   |-- GlassCard.swift
|   |   |-- CircularGauge.swift
|   |   +-- ModernColors.swift
|   +-- Utilities/
|       +-- PlatformCapabilities.swift  # Per-platform feature flags
|-- iOS/
|   |-- HomekitControl_iOS.swift        # iOS app entry point
|   +-- Views/                          # 30 iOS-specific views
|-- tvOS/
|   |-- HomekitControl_tvOS.swift       # tvOS app entry point
|   +-- Views/                          # 8 tvOS-specific views (10-ft optimized)
|-- macOS/
|   |-- HomekitControl_macOS.swift      # macOS app entry point (starts NovaAPIServer)
|   |-- AIBackendManager.swift          # macOS AI backend management
|   +-- Views/                          # macOS-specific views
|-- HomekitControl Widget/
|   |-- HomekitControlWidget.swift      # WidgetKit (Small, Medium, Large)
|   |-- WidgetData.swift                # Widget data models
|   +-- SharedDataManager.swift         # App Group data bridge
+-- Resources/
    |-- Assets.xcassets                 # Shared assets and app icons
    |-- iOS.entitlements
    |-- tvOS.entitlements
    +-- macOS.entitlements
```

---

## Technical Details

### HomeKit Integration

- **iOS / tvOS**: Native `HomeKit.framework` via `HMHomeManager` with full delegate support
- **macOS (Catalyst)**: Native `HomeKit.framework` via Mac Catalyst -- same iOS HomeKit stack running on macOS
- **macOS (Native fallback)**: Shortcuts CLI proxy using `/usr/bin/shortcuts` for scene execution and status queries

The `HomeKitService` singleton manages the `HMHomeManager` lifecycle, publishes reactive updates via `@Published` properties, and exposes device control methods (toggle, brightness, power state, scene execution) as async/await calls.

### Nova API Server

The `NovaAPIServer` uses Apple's `Network.framework` (`NWListener`) bound to `127.0.0.1:37432`. It implements a lightweight HTTP/1.1 parser, routes requests to HomeKit data, and returns JSON responses with CORS headers. The server starts automatically in the macOS app entry point and runs for the lifetime of the process.

### Network Discovery

`NetworkDiscoveryService` uses `NWBrowser` to scan for 10 Bonjour service types simultaneously: `_hap._tcp`, `_matterc._udp`, `_matter._tcp`, `_googlecast._tcp`, `_hue._tcp`, `_nanoleaf._tcp`, `_sonos._tcp`, `_airplay._tcp`, `_raop._tcp`, and `_homekit._tcp`. Scans auto-stop after 30 seconds. TXT records are parsed for manufacturer, model, and firmware metadata.

### AI Service

The AI assistant supports six backends with automatic availability detection:

| Backend | Protocol | Default Endpoint |
|---|---|---|
| Ollama | `/api/generate` | `localhost:11434` |
| TinyLLM | OpenAI-compatible `/v1/chat/completions` | `localhost:8000` |
| TinyChat | `/api/chat/stream` | `localhost:8000` |
| OpenWebUI | `/api/chat/completions` | `localhost:8080` |
| OpenAI | OpenAI API | `api.openai.com` |
| Claude | Anthropic Messages API | `api.anthropic.com` |

All endpoints are configurable. Local backends are checked at startup with a 5-second timeout. API keys for cloud providers are stored separately from source code.

### Security

- API server binds to loopback only (`127.0.0.1`) -- never exposed to the network
- Setup codes stored in macOS Keychain via Security framework (`SecItemAdd` / `SecItemCopyMatching`)
- Guest access codes generated with CryptoKit
- No app sandbox -- required for full HomeKit and local network access on macOS
- No hardcoded credentials in source

### Design System

The UI uses a glassmorphic design system with translucent cards, circular gauges, and a modern color palette. All platforms share the same design tokens through `ModernColors` and `GlassmorphicBackground`. The macOS app uses a hidden title bar with a preferred dark color scheme.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

### Recent Versions

- **v1.2.0** -- Mac Catalyst build with native HomeKit.framework on macOS
- **v1.1.0** -- macOS Shortcuts CLI proxy, scene execution endpoint, launchd agent
- **v1.0.0** -- Initial release with iOS, tvOS, and macOS support

---

## License

MIT License. See [LICENSE](LICENSE) for the full text.

Copyright (c) 2026 Jordan Koch.

---

## More Apps by Jordan Koch

| App | Description |
|---|---|
| [MLXCode](https://github.com/kochj23/MLXCode) | Local AI coding assistant for Apple Silicon |
| [NMAPScanner](https://github.com/kochj23/NMAPScanner) | Network security scanner with AI threat detection |
| [RsyncGUI](https://github.com/kochj23/RsyncGUI) | macOS GUI for rsync backup and synchronization |
| [StreamRotator](https://github.com/kochj23/StreamRotator) | Video stream rotation and display management |
| [rtsp-rotator](https://github.com/kochj23/rtsp-rotator) | RTSP camera stream rotation and monitoring |
| [TopGUI](https://github.com/kochj23/TopGUI) | macOS system monitor with real-time metrics |

> **[View all projects](https://github.com/kochj23?tab=repositories)**

---

> **Disclaimer:** This is a personal project created on my own time. It is not affiliated with, endorsed by, or representative of my employer.
