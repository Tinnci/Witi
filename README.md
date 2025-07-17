# Sims-Like Game

A Sims 1-inspired life simulation game built with Dart and Flutter, featuring 2.5D isometric graphics and autonomous character behavior.

## 🎮 Features

- **2.5D Isometric View** - Classic 45-degree perspective with tile-based world
- **Need-Based AI System** - Characters autonomously make decisions based on hunger, hygiene, social needs, etc.
- **Interactive Objects** - Advertisement-scoring system where objects attract characters
- **Cross-Platform** - Runs on Windows, macOS, Linux, and Web
- **Data-Driven** - JSON configuration for easy content creation and modding
- **Deterministic Simulation** - Fixed 15Hz timestep for reproducible gameplay

## 🚀 Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (latest stable)
- [Dart SDK](https://dart.dev/get-dart) (included with Flutter)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd sims-like-game

# Install dependencies
flutter pub get

# Start build runner for code generation
dart run build_runner watch --delete-conflicting-outputs
```

### Running the Game

```bash
# Desktop (Windows/macOS/Linux)
flutter run -d windows
flutter run -d macos
flutter run -d linux

# Web
flutter run -d chrome

# With hot reload for development
flutter run -d windows --hot
```

## 🏗️ Architecture

The project follows a strict layer separation:

- **Core Simulation** (`lib/core/`) - Pure Dart logic, no Flutter dependencies
- **Presentation** (`lib/presentation/`) - Flutter/Flame rendering and UI
- **Infrastructure** (`lib/infra/`) - Cross-cutting concerns (events, serialization)

### Key Systems

- **SimulationClock** - Deterministic 15Hz fixed timestep
- **Need System** - Character needs with decay and thresholds
- **AI Decision Maker** - Advertisement-scoring algorithm for autonomous behavior
- **Pathfinding Engine** - A* pathfinding with collision avoidance
- **Component System** - Mixins for extensible object behaviors
- **Event Bus** - Decoupled communication between systems

## 🧪 Development

### Code Generation

The project uses code generation for serialization and data classes:

```bash
# Watch mode (recommended during development)
dart run build_runner watch --delete-conflicting-outputs

# One-time build
dart run build_runner build --delete-conflicting-outputs
```

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/simulation_test.dart
```

**Coverage Target**: ≥80% for core simulation logic (`lib/core/`)

### Code Quality

```bash
# Format code
dart format .

# Analyze code
flutter analyze

# Check for issues
flutter doctor
```

## 📁 Project Structure

```
lib/
├── core/                   # Pure Dart simulation engine
│   ├── simulation/         # World, Sim, needs, AI
│   ├── pathfinding/        # A* pathfinding
│   └── events/             # Event system
├── presentation/           # Flutter/Flame UI
│   ├── game/              # Flame game components
│   ├── ui/                # Flutter widgets
│   └── rendering/         # Isometric renderer
├── infra/                 # Infrastructure
│   ├── serialization/     # Save/load system
│   ├── assets/            # Asset loading
│   └── config/            # Configuration
└── main.dart              # App entry point

assets/
├── images/                # Sprites and textures
├── data/                  # JSON configuration
└── audio/                 # Sound effects

test/                      # Unit and integration tests
tools/                     # Build scripts and utilities
```

## 🎯 Roadmap

Current development follows the implementation plan in `.kiro/specs/sims-like-game/tasks.md`:

### Phase 1: Foundation (Current)
- [x] Project setup and specifications
- [ ] Bootstrap infrastructure and core foundation
- [ ] Core simulation engine with world and grid system
- [ ] Need system and character foundation

### Phase 2: Core Gameplay
- [ ] Interactive objects and component system
- [ ] AI decision system and advertisement scoring
- [ ] Pathfinding engine with A* algorithm
- [ ] Isometric rendering system

### Phase 3: Content & Polish
- [ ] Data-driven configuration system
- [ ] Save and load system
- [ ] Performance optimization and isolate integration
- [ ] User interface and HUD system

See the full [Implementation Plan](.kiro/specs/sims-like-game/tasks.md) for detailed tasks.

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for:

- Branch strategy and workflow
- Commit conventions
- Code quality standards
- Testing requirements

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - New features and improvements
- `hotfix/*` - Critical fixes

## 📚 Documentation

- [Requirements Document](.kiro/specs/sims-like-game/requirements.md)
- [Design Document](.kiro/specs/sims-like-game/design.md)
- [Implementation Tasks](.kiro/specs/sims-like-game/tasks.md)
- [Steering Documents](.kiro/steering/)

## 🛠️ Technology Stack

- **Language**: Dart
- **Framework**: Flutter
- **Game Engine**: Flame
- **Architecture**: Event-driven, component-based
- **Testing**: Built-in Flutter test framework
- **CI/CD**: GitHub Actions (planned)

## 📄 License

[Add your license here]

## 🙏 Acknowledgments

Inspired by the original The Sims (2000) by Maxis and Will Wright.

---

**Status**: 🚧 In Development - Foundation Phase