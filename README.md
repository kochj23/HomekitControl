# HomekitControl

A unified multi-platform smart home control app for iOS, tvOS, and macOS.

## Overview

HomekitControl combines the functionality of 5 previous HomeKit projects into a single, unified app:

- **HomeKitAdopter** - Network discovery and security audit
- **HomeKitAssistant** - Basic device control
- **HomeKitRestore** - Setup code vault
- **HomeKitTV** - Full device and scene control
- **SceneFixer** - Scene diagnostics and AI repair

## Features

### iOS
- Full device control (toggle, brightness, color)
- Scene execution and repair
- Network discovery (Bonjour/mDNS)
- AI assistant for smart home insights
- Setup code vault with Keychain storage
- Export data (CSV/JSON)

### tvOS
- 10-foot optimized UI with focus navigation
- Device viewing and control
- Scene execution
- Network discovery

### macOS
- Manual device inventory (no native HomeKit framework)
- Setup code vault with Keychain and photo storage
- Network scanner
- Full export functionality

## Platform Capabilities

| Feature | iOS | tvOS | macOS |
|---------|-----|------|-------|
| Device Control | ✅ | ✅ | ❌ Manual only |
| Scene Execution | ✅ | ✅ | ❌ |
| Scene Repair | ✅ | ❌ | ❌ |
| Network Discovery | ✅ | ✅ | ✅ |
| AI Assistant | ✅ | ✅ | ✅ |
| Setup Code Vault | ✅ | ❌ | ✅ |
| Export | ✅ | ❌ | ✅ |

## Requirements

- iOS 17.0+
- tvOS 17.0+
- macOS 14.0+
- Xcode 16.0+

## Installation

1. Clone the repository
2. Run `xcodegen generate` to create the Xcode project
3. Open `HomekitControl.xcodeproj`
4. Select your target platform and build

## Architecture

```
HomekitControl/
├── Shared/
│   ├── Models/          # Unified data models
│   ├── Services/        # Core services (HomeKit, Network, AI)
│   ├── Design/          # Glassmorphic design system
│   └── Utilities/       # Platform capabilities
├── iOS/                 # iOS-specific views
├── tvOS/                # tvOS-specific views
└── macOS/               # macOS-specific views
```

## License

MIT License - See LICENSE file for details.

## Author

Jordan Koch

Copyright 2026 Jordan Koch. All rights reserved.
